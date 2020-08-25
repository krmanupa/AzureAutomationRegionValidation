
Param(
    [Parameter(Mandatory = $true)]
    [string] $location ,  # "West Central US", "USGov Arizona"
    [Parameter(Mandatory = $true)]
    [string] $Environment , # "AzureCloud", "AzureUSGovernment", "AzureChinaCloud"
    [Parameter(Mandatory = $true)]
    [string] $UriStart ,  # "https://management.azure.com/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a", "https://management.usgovcloudapi.net/subscriptions/a1d148ea-c45e-45f7-acc5-b7bcc10813af"
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "RunnerRG",
    [Parameter(Mandatory = $false)]
    [string] $NewResourceGroupName = "RunnerMoveToRG",
    [Parameter(Mandatory = $false)]
    [string] $AccountName = "Test-Account",
    [Parameter(Mandatory = $false)]
    [string] $RunbookName = "Test-Runbook-ps",
    [Parameter(Mandatory = $false)]
    [string] $RunbookPython2Name = "Test-Runbook-py2"
)

#Import-Module Az.Accounts
#Import-Module Az.Resources
#Import-Module Az.Automation

$ErrorActionPreference = "Stop"

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

    # Write-Verbose "Create account" -verbose
    $Account = New-AzAutomationAccount -Name $AccountName -Location $location -ResourceGroupName $ResourceGroupName -Plan "Free"
    if($Account.AutomationAccountName -like $AccountName) {
        Write-Verbose "Account created successfully"
    } 
    else{
        Write-Error "Account creation failed"
    }

    # Write-Verbose "Create runbooks" -verbose
    New-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookName -ResourceGroupName $ResourceGroupName -Type "PowerShell"
    New-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookPython2Name -ResourceGroupName $ResourceGroupName -Type "Python2"

    # Write-Verbose "Get auth token" -verbose
    $currentAzureContext = Get-AzContext
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    $Token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)

    # Write-Verbose "Draft runbooks" -verbose
    try{
        $Headers = @{}
        $Headers.Add("Authorization","bearer "+ " " + "$($Token.AccessToken)")
        $contentType3 = "application/text"
        $bodyPS = 'Write-Verbose "Hello" '        
        $PutContentPSUri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountName/runbooks/$RunbookName/draft/content?api-version=2015-10-31"
        Invoke-RestMethod -Uri $PutContentPSUri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyPS
        $bodyPy2 = 'print "Hello" '        
        $PutContentPy2Uri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountName/runbooks/$RunbookPython2Name/draft/content?api-version=2015-10-31"
        Invoke-RestMethod -Uri $PutContentPy2Uri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyPy2
    }
    catch{
        Write-Error -Message $_.Exception
    }
    
    # Write-Verbose "Publish runbooks" -verbose
    Publish-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookName -ResourceGroupName $ResourceGroupName
    Publish-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookPython2Name -ResourceGroupName $ResourceGroupName

    # Write-Verbose "Start cloud jobs" -verbose
    $JobCloud = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookName -ResourceGroupName $ResourceGroupName -MaxWaitSeconds 300 -Wait
    if($JobCloud -like "Hello") {
        Write-Verbose "Cloud job for PowerShell runbook ran successfully"
    }
    else{
        Write-Error "Job for the PowerShell runbook couldn't complete"
    }
    $JobCloud = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookPython2Name -ResourceGroupName $ResourceGroupName -MaxWaitSeconds 300 -Wait
    if($JobCloud -like "Hello") {
        Write-Verbose "Cloud job for Python2 runbook ran successfully"
    }
    else{
        Write-Error "Job for the Python2 runbook couldn't complete"
    }

    # Write-Verbose "Delete runbooks" -verbose
    Remove-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookName -ResourceGroupName $ResourceGroupName -Force
    Remove-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookPython2Name -ResourceGroupName $ResourceGroupName -Force
    
    # Write-Verbose "Move account" -verbose 
    $AutomationAccount = Get-AzResource -ResourceName $AccountName
    Move-AzResource -ResourceId $AutomationAccount.ResourceId -DestinationResourceGroupName $NewResourceGroupName -Force
    $Account1 = Get-AzAutomationAccount -Name $AccountName -ResourceGroupName $NewResourceGroupName 
    if($Account1.AutomationAccountName -like $AccountName) {
        Write-Verbose "Account moved to new resource group successfully"
    } 
    else{
        Write-Error "Account move operation failed"
    }

    # Write-Verbose "Delete account" -verbose
    Remove-AzAutomationAccount -Name $AccountName -ResourceGroupName $NewResourceGroupName -Force

    Write-Output "Automation Account Operations Verified"



