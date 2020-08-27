### All variables needed
Param(
[Parameter(Mandatory = $false)]
[string] $location = "Canada Central",  
[Parameter(Mandatory = $false)]
[string] $Environment = "AzureCloud", 
[Parameter(Mandatory = $false)]
[string] $ResourceGroupName = "krmanupa-int",
[Parameter(Mandatory = $false)]
[string] $AccountName = "Test-CreateRunAs"
)

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
        -Environment $Environment
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

### Create an automation account
Write-Output "Creating Automation Account....."
$guid_val = [guid]::NewGuid()
$guid = $guid_val.ToString()
#$AccountName = $AccountName + $guid.ToString()

# Write-Verbose "Create account" -verbose
try {
    $Account = Get-AzAutomationAccount -Name $AccountName -ResourceGroupName $ResourceGroupName 
    if($Account.AutomationAccountName -like $AccountName) {
        Write-Output "Account retrieved successfully"
        $accRegInfo = Get-AzAutomationRegistrationInfo -ResourceGroup $ResourceGroupName -AutomationAccountName  $AccountName
        $agentEndpoint = $accRegInfo.Endpoint
        $aaPrimaryKey = $accRegInfo.PrimaryKey

        Write-Output "AgentService endpoint: $agentEndpoint  Primary key : $aaPrimaryKey"
    } 
    else{
        Write-Error "Account retrieval failed"
    }
}
catch {
    Write-Error "Account retrieval failed"
    Write-Error -Message $_.Exception
    throw $_.Exception
}


function GetAuthToken{
    # Write-Verbose "Get auth token" -verbose
    $currentAzureContext = Get-AzContext
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    $Token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)

    return $Token
}

function InvokeRestMethod{
    param (
        $Uri,
        $Body,
        $Method,
        $ContentType
    )
    $Token = GetAuthToken
     # Write-Verbose "Draft runbooks" -verbose
     try{
        $Headers = @{}
        $Headers.Add("Authorization","bearer "+ " " + "$($Token.AccessToken)")  
        return Invoke-RestMethod -Uri $Uri -Method $Method -ContentType $ContentType -Headers $Headers -Body $Body
    }
    catch{
        Write-Error -Message $_.Exception
    }
}

$ResourceId = "%2Fsubscriptions%2Fcd45f23b-b832-4fa4-a434-1bf7e6f14a5a%2FresourceGroups%2F$ResourceGroupName%2Fproviders%2FMicrosoft.Automation%2FautomationAccounts%2F$AccountName"
$CreateRunAsAccountUri = "https://s2.automation.ext.azure.com/api/Orchestrator/CreateAzureRunAsAccountForExistingAccount?accountResourceId=$ResourceId"
$Body = @"
{
    "accountResourceId": "/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a/resourceGroups/krmanupa-int/providers/Microsoft.Automation/automationAccounts/krmanupa-eap-cus",
    "servicePrincipalScopeId": "/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a"
}
"@ 
Write-Output $Body

$ContentType = "application/json"


$responseData =  InvokeRestMethod -Method Post -Uri $CreateRunAsAccountUri -Body $Body -ContentType $ContentType

Write-Output "Response : $responseData"


$CreateRunAsAccountWithTutorialRunbook = "https://s2.automation.ext.azure.com/api/Orchestrator/CreateAzureRunAsAccountRolesAssetsAndTutorialRunbookForExistingAccountUsingArmToken?accountResourceId=%2Fsubscriptions%2Fcd45f23b-b832-4fa4-a434-1bf7e6f14a5a%2FresourceGroups%2Fkrmanupa-int%2Fproviders%2FMicrosoft.Automation%2FautomationAccounts%2FTest-CreateRunAs&region=centraluseuap"
?accountResourceId=%2Fsubscriptions%2Fcd45f23b-b832-4fa4-a434-1bf7e6f14a5a%2FresourceGroups%2Fkrmanupa-int%2Fproviders%2FMicrosoft.Automation%2FautomationAccounts%2FTest-CreateRunAs