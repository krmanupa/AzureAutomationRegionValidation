### All variables needed
Param(  
[Parameter(Mandatory = $false)]
[string] $Environment = "AzureCloud", 
[Parameter(Mandatory = $false)]
[string] $ResourceGroupName = "test-auto-creation",
[Parameter(Mandatory = $false)]
[string] $AccountName = "Test-auto-creation-aa",
[Parameter(Mandatory = $false)]
[Boolean] $IsEnableCMK = $true,
[Parameter(Mandatory = $false)]
[string] $SubId = "cd45f23b-b832-4fa4-a434-1bf7e6f14a5a"
)

$ErrorActionPreference = "Stop"
if($Environment -eq "USNat"){
    Add-AzEnvironment -Name USNat -ServiceManagementUrl 'https://management.core.eaglex.ic.gov/' -ActiveDirectoryAuthority 'https://login.microsoftonline.eaglex.ic.gov/' -ActiveDirectoryServiceEndpointResourceId 'https://management.azure.eaglex.ic.gov/' -ResourceManagerEndpoint 'https://usnateast.management.azure.eaglex.ic.gov' -GraphUrl 'https://graph.cloudapi.eaglex.ic.gov' -GraphEndpointResourceId 'https://graph.cloudapi.eaglex.ic.gov/' -AdTenant 'Common' -AzureKeyVaultDnsSuffix 'vault.cloudapi.eaglex.ic.gov' -AzureKeyVaultServiceEndpointResourceId 'https://vault.cloudapi.eaglex.ic.gov' -EnableAdfsAuthentication 'False'
}
function GetAuthToken{
    # Write-Verbose "Get auth token" -verbose
    $currentAzureContext = Get-AzContext
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    $Token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)

    return $Token
}

function InvokePatchRestMethod{
    param (
        $Uri,
        $Body,
        $ContentType
    )
    $Token = GetAuthToken
     # Write-Verbose "Draft runbooks" -verbose
     try{
        $Headers = @{}
        $Headers.Add("Authorization","bearer "+ " " + "$($Token.AccessToken)")  
        return Invoke-RestMethod -Uri $Uri -Method Patch -ContentType $ContentType -Headers $Headers -Body $Body
    }
    catch{
        Write-Error -Message $_.Exception
    }
}

function EnableAMK{
    param (
        $UriStart,
        $SubId,
        $ResourceGroupName,
        $AutomationAccName
    )
    $Uri = @"
    https://$UriStart/subscriptions/$SubId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/test-krmanupa-eap?api-version=2020-01-13-preview
"@
    $ContentType = "application/json"

    #Enable MSI
    $body = @"
    { "identity": { "type": "SystemAssigned" } }
"@
    InvokePatchRestMethod -Uri $Uri -Body $body -ContentType $ContentType 

    #Enable AMK
    $amkBody = @"
    { "properties" : { "encryption": { "keySource": "Microsoft.Automation" } } }
"@
    InvokePatchRestMethod -Uri $Uri -Body $amkBody -ContentType $ContentType 
}


function DisableCMK{
    param (
        $UriStart,
        $SubId,
        $ResourceGroupName,
        $AutomationAccName
    )
    $Uri = "https://$UriStart/subscriptions/$SubId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/"+$AccountName+"?api-version=2020-01-13-preview"
    $ContentType = "application/json"


    #Enable AMK
    $amkBody = @"
    { "properties" : { "encryption": { "keySource": "Microsoft.Automation" } } }
"@
    InvokePatchRestMethod -Uri $Uri -Body $amkBody -ContentType $ContentType 
}


function EnableCMK{
    param (
        $UriStart,
        $SubId,
        $ResourceGroupName,
        $AutomationAccName
    )
    $Uri = "https://$UriStart/subscriptions/$SubId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/"+$AccountName+"?api-version=2020-01-13-preview"
    $ContentType = "application/json"
    
    #Enable CMK
    # update the body according to the generated key
    $cmkBody = @"
    { "properties" : { "encryption": { "keySource": "Microsoft.Keyvault", "keyvaultProperties": { "keyName": "testKey", "keyvaultUri": "https://gatest.vault.azure.net", "keyVersion": "2aab885143cd4463a1f82b6eb6bb567e" } } } }
"@
    InvokePatchRestMethod -Uri $Uri -Body $cmkBody -ContentType $ContentType 
}


# Connect using RunAs account connection
$connectionName = "AzureRunAsConnection"
try
{
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName      
    Write-Verbose "Logging in to Azure..." -verbose
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
        -Environment $Environment | Out-Null
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}


$uri = "management.azure.com"
if($Environment -eq "USNat"){
    $uri = "management.core.eaglex.ic.gov"
}

if($IsEnableCMK -eq $true){
    #add the account's service principal in the key vault to provide account the access to the KeyVault with all the required permissions
    # generate a key to apply that to the automation account as CMK.
    EnableCMK -UriStart $uri -SubId $SubId -ResourceGroupName $ResourceGroupName -AutomationAccName $AccountName
    Write-Output "CMK Validation :: Enable CMK Successful"
}
else{
    DisableCMK -UriStart $uri -SubId $SubId -ResourceGroupName $ResourceGroupName -AutomationAccName $AccountName
    Write-Output "CMK Validation :: Disabl CMK Successful"
}
