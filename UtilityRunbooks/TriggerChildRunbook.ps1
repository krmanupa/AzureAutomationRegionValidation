Param(
    [Parameter(Mandatory = $true)]
    [string] $AccountName,
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName   
)

try
{
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName      
    Write-Output "Logging in to Azure..." -verbose
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
        -Environment "AzureCloud"
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

$testPsRb = "ps-job-test"
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