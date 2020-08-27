
Param( 
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud", 
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "krmanupa-test-auto",
    [Parameter(Mandatory = $false)]
    [string] $AccountName = "krmanupa-base-aa",
    [Parameter(Mandatory = $false)]
    [string] $RunbookName = "test-runbook",
    [Parameter(Mandatory = $false)]
    [string] $ScheduleName = "Test-Schedule",
    [Parameter(Mandatory = $false)]
    [string] $WorkerGroup = "" ,
    [Parameter(Mandatory = $false)]
    [string] $UriStart = "https://management.azure.com/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a" 
    )
    
    #Import-Module Az.Accounts
    #Import-Module Az.Resources
    #Import-Module Az.Automation
    
    $ErrorActionPreference = "Stop"
    
    $guid = New-Guid
    $ScheduleName = $ScheduleName + "-" + $guid.ToString()
    $RunbookName = $RunbookName + "-" + $guid.ToString()
    
    # Connect using RunAs account connection
    $connectionName = "AzureRunAsConnection"
    try
    {
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName      
    Write-Output  "Logging in to Azure..." -verbose
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
    
    # Write-Output  "Create schedule" 
    $TimeZone = ([System.TimeZoneInfo]::Local).Id
    $StartTime = (Get-Date).AddMinutes(6)
    New-AzAutomationSchedule -AutomationAccountName $AccountName -Name $ScheduleName -StartTime $StartTime -OneTime -ResourceGroupName $ResourceGroupName -TimeZone $TimeZone | Out-Null 
    
    # Write-Output  "Create runbook" 
    New-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookName -ResourceGroupName $ResourceGroupName -Type "PowerShell" | Out-Null
    # Write-Output  "Get auth token" 
    $currentAzureContext = Get-AzContext
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    $Token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    # Write-Output  "Draft runbook" 
    try{
        $Headers = @{}
        $Headers.Add("Authorization","bearer "+ " " + "$($Token.AccessToken)")
        $contentType3 = "application/text"
        $bodyPS = 'Write-Output "TestingScheduler" '        
        $PutContentPSUri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountName/runbooks/$RunbookName/draft/content?api-version=2015-10-31"
        Invoke-RestMethod -Uri $PutContentPSUri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyPS
    }
    catch{
        Write-Error -Message $_.Exception
    }    
    # Write-Output  "Publish runbook" 
    Publish-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookName -ResourceGroupName $ResourceGroupName | Out-Null
    
    
    # Write-Output  "Register runbook with schedule" 
    Register-AzAutomationScheduledRunbook -AutomationAccountName $AccountName -Name $RunbookName -ScheduleName $ScheduleName  -ResourceGroupName $ResourceGroupName -RunOn $WorkerGroup | Out-Null
    
    #Try getting the schedule
    ($schedule = Get-AzAutomationSchedule -AutomationAccountName $AccountName -Name $ScheduleName -ResourceGroupName $ResourceGroupName) | Out-Null
    
    if($schedule.Name -like $ScheduleName){
        Write-Output  "Schedule retrieved successfully"
    }
    else{
        Write-Error "Schedule retrieval failed"
    }
    
    Start-Sleep -Seconds 400
    $Jobs = Get-AzAutomationJob -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName -RunbookName $RunbookName
    $JobId = $Jobs[0].JobId
    ($JobOutput = Get-AzAutomationJobOutput -AutomationAccountName $AccountName -Id $JobId -ResourceGroupName $ResourceGroupName -Stream "Output") | Out-Null
    $Output = $JobOutput.Summary
    if($Output -like "TestingScheduler") { 
        Write-Output  "Scheduled job ran successfully" 
    } 
    else{
        Write-Error "Scheduled job couldn't complete"
    }
    
    $DescriptionToBeUpdated = "Automation Schedule Updated" 
    Set-AzAutomationSchedule -AutomationAccountName $AccountName -Name $ScheduleName -Description $DescriptionToBeUpdated -ResourceGroupName $ResourceGroupName | Out-Null
    #Try getting the schedule
    ($schedule = Get-AzAutomationSchedule -AutomationAccountName $AccountName -Name $ScheduleName -ResourceGroupName $ResourceGroupName) | Out-Null
    
    if($schedule.Description -like $DescriptionToBeUpdated){
        Write-Output  "Schedule updated successfully"
    }
    else{
        Write-Error "Schedule update failed"
    }
    
    # Write-Output  "Delete runbook" 
    Remove-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookName -ResourceGroupName $ResourceGroupName -Force | Out-Null
    # Write-Output  "Delete schedule" 
    Remove-AzAutomationSchedule -AutomationAccountName $AccountName -Name $ScheduleName -ResourceGroupName $ResourceGroupName -Force | Out-Null
    
    Write-Output "Job Schedule Scenario Validation Completed"
    
    