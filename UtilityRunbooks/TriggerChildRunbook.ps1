Param(
    [Parameter(Mandatory = $true)]
    [string] $AccountName,
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,
    [Parameter (Mandatory=$false)] 
    [string] $Environment
)
if($Environment -eq "USNat"){
    Add-AzEnvironment -Name USNat -ServiceManagementUrl 'https://management.core.eaglex.ic.gov/' -ActiveDirectoryAuthority 'https://login.microsoftonline.eaglex.ic.gov/' -ActiveDirectoryServiceEndpointResourceId 'https://management.azure.eaglex.ic.gov/' -ResourceManagerEndpoint 'https://usnateast.management.azure.eaglex.ic.gov' -GraphUrl 'https://graph.cloudapi.eaglex.ic.gov' -GraphEndpointResourceId 'https://graph.cloudapi.eaglex.ic.gov/' -AdTenant 'Common' -AzureKeyVaultDnsSuffix 'vault.cloudapi.eaglex.ic.gov' -AzureKeyVaultServiceEndpointResourceId 'https://vault.cloudapi.eaglex.ic.gov' -EnableAdfsAuthentication 'False'
}
$connectionName = "AzureRunAsConnection"
try
{
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName      
    Write-Output "Logging in to Azure..." -verbose
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


Write-Output "Triggering Child Runbook"

$testPsRb = "ps-webhook-test"
$childJob = Start-AutomationRunbook -Name $testPsRb
$childJobId = $childJob.Guid

Write-Output "Polling for job completion for job Id : $childJobId"
$terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
$jobDetails = Get-AzAutomationJob -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName -Id $childJobId
$retryCount = 1
while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 20) {
    Start-Sleep -s 30
    $retryCount++
    $jobDetails = Get-AzAutomationJob -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName -Id $childJobId
}

$jobStatus = $jobDetails.Status
if($jobStatus -eq "Completed"){
    Write-Output "Child job execution succeeded"
}
else{
    Write-Error "Child job execution ended with status : $jobStatus"
}