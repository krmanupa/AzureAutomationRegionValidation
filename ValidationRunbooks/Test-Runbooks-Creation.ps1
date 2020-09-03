Param(
    [Parameter(Mandatory = $false)]
    [string] $location = "West Central US" ,  # "West Central US", "USGov Arizona"
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud", # "AzureCloud", "AzureUSGovernment", "AzureChinaCloud"
    [Parameter(Mandatory = $false)]
    [string] $UriStart = "https://management.azure.com/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a" ,  # "https://management.azure.com/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a", "https://management.usgovcloudapi.net/subscriptions/a1d148ea-c45e-45f7-acc5-b7bcc10813af"
    [Parameter(Mandatory = $false)]
    [string] $AccountName = "RunnerAcc",
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "RunnerRG"
)

$ErrorActionPreference = "Stop"
if($Environment -eq "USNat"){
    Add-AzEnvironment -Name USNat -ServiceManagementUrl 'https://management.core.eaglex.ic.gov/' -ActiveDirectoryAuthority 'https://login.microsoftonline.eaglex.ic.gov/' -ActiveDirectoryServiceEndpointResourceId 'https://management.azure.eaglex.ic.gov/' -ResourceManagerEndpoint 'https://usnateast.management.azure.eaglex.ic.gov' -GraphUrl 'https://graph.cloudapi.eaglex.ic.gov' -GraphEndpointResourceId 'https://graph.cloudapi.eaglex.ic.gov/' -AdTenant 'Common' -AzureKeyVaultDnsSuffix 'vault.cloudapi.eaglex.ic.gov' -AzureKeyVaultServiceEndpointResourceId 'https://vault.cloudapi.eaglex.ic.gov' -EnableAdfsAuthentication 'False'
}
$guid_val = [guid]::NewGuid()
$guid = $guid_val.ToString()

$powershellRunbookName = "ps-job-test-rb" + $guid
$python2RunbookName = "py2-job-test-rb" + $guid
$powershellWorkflowRunbookName = "pswf-job-test-rb" + $guid

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

# Write-Output "Create runbooks" -verbose
New-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellRunbookName -ResourceGroupName $ResourceGroupName -Type "PowerShell" | Out-Null
New-AzAutomationRunbook -AutomationAccountName $AccountName -Name $python2RunbookName -ResourceGroupName $ResourceGroupName -Type "Python2" | Out-Null
New-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellWorkflowRunbookName -ResourceGroupName $ResourceGroupName -Type "PowerShellWorkflow" | Out-Null


# Write-Output "Get auth token" -verbose
$currentAzureContext = Get-AzContext
$azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
$Token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)

# Write-Output "Draft runbooks" -verbose
try{
    $Headers = @{}
    $Headers.Add("Authorization","bearer "+ " " + "$($Token.AccessToken)")
    $contentType3 = "application/text"

    $bodyPS = 'Write-Output "Hello" ' 
    $PutContentPSUri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountName/runbooks/$powershellRunbookName/draft/content?api-version=2015-10-31"
    Invoke-RestMethod -Uri $PutContentPSUri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyPS
    
    $bodyPy2 = 'print "Hello" '        
    $PutContentPy2Uri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountName/runbooks/$python2RunbookName/draft/content?api-version=2015-10-31"
    Invoke-RestMethod -Uri $PutContentPy2Uri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyPy2

    $bodyPswf = 'workflow pswf-job-test-rb{Write-Output "Hello"}'        
    $PutContentPswfUri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountName/runbooks/$powershellWorkflowRunbookName/draft/content?api-version=2015-10-31"
    Invoke-RestMethod -Uri $PutContentPswfUri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyPswf
}
catch{
    Write-Error -Message "Runbook Operations :: $_.Exception"
}

# Write-Output "Publish runbooks" -verbose
Publish-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellRunbookName -ResourceGroupName $ResourceGroupName | Out-Null
Publish-AzAutomationRunbook -AutomationAccountName $AccountName -Name $python2RunbookName -ResourceGroupName $ResourceGroupName | Out-Null
Publish-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellWorkflowRunbookName -ResourceGroupName $ResourceGroupName | Out-Null

# Write-Output "Start cloud jobs" -verbose
$JobCloud = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellRunbookName -ResourceGroupName $ResourceGroupName -MaxWaitSeconds 300 -Wait
if($JobCloud -like "Hello") {
    Write-Output "Cloud job for PowerShell runbook ran successfully"
}
else{
    Write-Error "Runbook Operations :: Job for the PowerShell runbook couldn't complete"
}

$JobCloud = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $python2RunbookName -ResourceGroupName $ResourceGroupName -MaxWaitSeconds 300 -Wait
if($JobCloud -like "Hello") {
    Write-Output "Cloud job for Python2 runbook ran successfully"
}
else{
    Write-Error "Runbook Operations :: Job for the Python2 runbook couldn't complete"
}

$JobCloud = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellWorkflowRunbookName -ResourceGroupName $ResourceGroupName -MaxWaitSeconds 300 -Wait
if($JobCloud -like "Hello") {
    Write-Output "Cloud job for PowerShellWorkflow runbook ran successfully"
}
else{
    Write-Error "Runbook Operations :: Job for the PowerShellWorkflow runbook couldn't complete"
}

#update runbook Metadata
Set-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellRunbookName -LogVerbose $True -ResourceGroupName $ResourceGroupName | Out-Null
Set-AzAutomationRunbook -AutomationAccountName $AccountName -Name $python2RunbookName -LogVerbose $True -ResourceGroupName $ResourceGroupName | Out-Null
Set-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellWorkflowRunbookName -LogVerbose $True -ResourceGroupName $ResourceGroupName | Out-Null
Start-Sleep -s 300

#Get the runbook data
$powershellRbData = Get-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellRunbookName -ResourceGroupName $ResourceGroupName
if($powershellRbData.LogVerbose -ne $true){
    Write-Error "Runbook Operations :: PS Runbook Update failed"
}

$python2RbData = Get-AzAutomationRunbook -AutomationAccountName $AccountName -Name $python2RunbookName -ResourceGroupName $ResourceGroupName
if($python2RbData.LogVerbose -ne $true){
    Write-Error "Runbook Operations :: Python2 Runbook Update failed"
}

$powershellWFRbData = Get-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellWorkflowRunbookName -ResourceGroupName $ResourceGroupName
if($powershellWFRbData.LogVerbose -ne $true){
    Write-Error "Runbook Operations :: PWSF Runbook Update failed"
}



# Write-Output "Delete runbooks" -verbose
Remove-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellRunbookName -ResourceGroupName $ResourceGroupName -Force
Remove-AzAutomationRunbook -AutomationAccountName $AccountName -Name $python2RunbookName -ResourceGroupName $ResourceGroupName -Force
Remove-AzAutomationRunbook -AutomationAccountName $AccountName -Name $powershellWFRbData -ResourceGroupName $ResourceGroupName -Force

Write-Output "Runbook Operations :: Automation Runbooks verification completed"
