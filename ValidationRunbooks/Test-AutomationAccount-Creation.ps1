
Param(
    [Parameter(Mandatory = $false)]
    [string] $location = "West Central US" ,  # "West Central US", "USGov Arizona"
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud", # "AzureCloud", "AzureUSGovernment", "AzureChinaCloud"
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "RunnerRG",
    [Parameter(Mandatory = $false)]
    [string] $NewResourceGroupName = "RunnerMoveToRG",
    [Parameter(Mandatory = $false)]
    [string] $AccountName = "Test-Account",
    [Parameter(Mandatory = $false)]
    [string] $RunbookName = "ps-job-test",
    [Parameter(Mandatory = $false)]
    [string] $RunbookPython2Name = "py2-job-test"
)

#Import-Module Az.Accounts
#Import-Module Az.Resources
#Import-Module Az.Automation

$ErrorActionPreference = "Stop"
if($Environment -eq "USNat"){
    Add-AzEnvironment -Name USNat -ServiceManagementUrl 'https://management.core.eaglex.ic.gov/' -ActiveDirectoryAuthority 'https://login.microsoftonline.eaglex.ic.gov/' -ActiveDirectoryServiceEndpointResourceId 'https://management.azure.eaglex.ic.gov/' -ResourceManagerEndpoint 'https://usnateast.management.azure.eaglex.ic.gov' -GraphUrl 'https://graph.cloudapi.eaglex.ic.gov' -GraphEndpointResourceId 'https://graph.cloudapi.eaglex.ic.gov/' -AdTenant 'Common' -AzureKeyVaultDnsSuffix 'vault.cloudapi.eaglex.ic.gov' -AzureKeyVaultServiceEndpointResourceId 'https://vault.cloudapi.eaglex.ic.gov' -EnableAdfsAuthentication 'False'
}
$guid = New-Guid
$AccountName = $AccountName + $guid.ToString()

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

# Write-Output "Create account" -verbose
($Account = New-AzAutomationAccount -Name $AccountName -Location $location -ResourceGroupName $ResourceGroupName -Plan "Free") | Out-Null

if($Account.AutomationAccountName -like $AccountName) {
    Write-Output "Account created successfully"
} 
else{
    Write-Error "Account Operations :: Account creation failed"
}

#update the Automation Account
$Tags = @{"tag01"="value01"}
Set-AzAutomationAccount -Name $AccountName -ResourceGroupName $ResourceGroupName -Tags $Tags | Out-Null
Start-Sleep -s 100
($Account = Get-AzAutomationAccount -Name $AccountName -ResourceGroupName $ResourceGroupName ) | Out-Null

#verify tags have been added or not
if($null -ne $Account.Tags){
    if($Account.Tags["tag01"] -eq "value01"){
        Write-Output "Account Updated Successfully"
    }
    else{
        Write-Error "Account Operations :: Account Update Failed"
    }
}
else{
    Write-Error "Account Update Failed"
}

# Write-Output "Move account" -verbose 
$AutomationAccount = Get-AzResource -ResourceName $AccountName
Move-AzResource -ResourceId $AutomationAccount.ResourceId -DestinationResourceGroupName $NewResourceGroupName -Force
$Account1 = Get-AzAutomationAccount -Name $AccountName -ResourceGroupName $NewResourceGroupName 
if($Account1.AutomationAccountName -like $AccountName) {
    Write-Output "Account moved to new resource group successfully"
} 
else{
    Write-Error "Account Operations :: Account move operation failed"
}

# Write-Output "Delete account" -verbose
Remove-AzAutomationAccount -Name $AccountName -ResourceGroupName $NewResourceGroupName -Force

Write-Output "Account Operations :: Automation Account Operations Verified"



