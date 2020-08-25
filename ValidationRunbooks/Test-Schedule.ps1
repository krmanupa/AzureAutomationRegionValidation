
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
    
    # Write-Verbose "Create schedule" 
    $TimeZone = ([System.TimeZoneInfo]::Local).Id
    $StartTime = (Get-Date).AddMinutes(6)
    New-AzAutomationSchedule -AutomationAccountName $AccountName -Name $ScheduleName -StartTime $StartTime -OneTime -ResourceGroupName $ResourceGroupName -TimeZone $TimeZone 
    
    # Write-Verbose "Create runbook" 
    New-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookName -ResourceGroupName $ResourceGroupName -Type "PowerShell"
    # Write-Verbose "Get auth token" 
    $currentAzureContext = Get-AzContext
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    $Token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    # Write-Verbose "Draft runbook" 
    try{
        $Headers = @{}
        $Headers.Add("Authorization","bearer "+ " " + "$($Token.AccessToken)")
        $contentType3 = "application/text"
        $bodyPS = 'Write-Verbose "TestingScheduler" '        
        $PutContentPSUri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountName/runbooks/$RunbookName/draft/content?api-version=2015-10-31"
        Invoke-RestMethod -Uri $PutContentPSUri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyPS
    }
    catch{
        Write-Error -Message $_.Exception
    }    
    # Write-Verbose "Publish runbook" 
    Publish-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookName -ResourceGroupName $ResourceGroupName
    
    
    # Write-Verbose "Register runbook with schedule" 
    Register-AzAutomationScheduledRunbook -AutomationAccountName $AccountName -Name $RunbookName -ScheduleName $ScheduleName -ResourceGroupName $ResourceGroupName -RunOn $WorkerGroup
    
    #Try getting the schedule
    $schedule = Get-AzAutomationSchedule -AutomationAccountName $AccountName -Name $ScheduleName -ResourceGroupName $ResourceGroupName
    
    if($schedule.Name -like $ScheduleName){
        Write-Verbose "Schedule retrieved successfully"
    }
    else{
        Write-Error "Schedule retrieval failed"
    }
    
    Start-Sleep -Seconds 400
    $Jobs = Get-AzAutomationJob -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName -RunbookName $RunbookName
    $JobId = $Jobs[0].JobId
    $JobOutput = Get-AzAutomationJobOutput -AutomationAccountName $AccountName -Id $JobId -ResourceGroupName $ResourceGroupName -Stream "Output"
    $Output = $JobOutput.Summary
    if($Output -like "TestingScheduler") { 
        Write-Verbose "Scheduled job ran successfully" 
    } 
    else{
        Write-Error "Scheduled job couldn't complete"
    }
    
    $DescriptionToBeUpdated = "Automation Schedule Updated" 
    Set-AzAutomationSchedule -AutomationAccountName $AccountName -Name $ScheduleName -Description $DescriptionToBeUpdated -ResourceGroupName $ResourceGroupName
    #Try getting the schedule
    $schedule = Get-AzAutomationSchedule -AutomationAccountName $AccountName -Name $ScheduleName -ResourceGroupName $ResourceGroupName
    
    if($schedule.Description -like $DescriptionToBeUpdated){
        Write-Verbose "Schedule updated successfully"
    }
    else{
        Write-Error "Schedule update failed"
    }
    
    # Write-Verbose "Delete runbook" 
    Remove-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookName -ResourceGroupName $ResourceGroupName -Force
    # Write-Verbose "Delete schedule" 
    Remove-AzAutomationSchedule -AutomationAccountName $AccountName -Name $ScheduleName -ResourceGroupName $ResourceGroupName -Force
    
    Write-Output "Schedule Scenario Verified"
    
    