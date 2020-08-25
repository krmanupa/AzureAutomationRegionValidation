
Param(
    [Parameter(Mandatory = $false)]
    [string] $location = "West Europe",  
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud", 
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "krmanupa-test-auto",
    [Parameter(Mandatory = $false)]
    [string] $AccountName = "krmanupa-base-aa",
    [Parameter(Mandatory = $false)]
    [string] $RunbookName = "ps-webhook-test",
    [Parameter(Mandatory = $false)]
    [string] $WebhookName = "Test-Webhook",
    [Parameter(Mandatory = $false)]
    [string] $WorkerGroup = ""     
    )
    
    #Import-Module Az.Accounts
    #Import-Module Az.Resources
    #Import-Module Az.Automation
    
    $guid = New-Guid
    $WebhookName = $WebhookName + "-" + $guid.ToString()
    
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
    
    # Write-Verbose "Create webhook" 
    $Webhook = New-AzAutomationWebhook -Name $WebhookName -IsEnabled $True -ExpiryTime $([datetime]::now.AddYears(1)) -RunbookName $RunbookName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName -Force -RunOn $WorkerGroup
    if($Webhook.Name -like $WebhookName) {
        Write-Verbose "Webhook created successfully"
    } 
    else{
        Write-Error "Webhook creation failed"
    }
    
    # Write-Verbose "Invoke webhook" 
    try{
        $JobDetails = Invoke-WebRequest $Webhook.WebhookURI -Method Post -UseBasicParsing
        $Job = $JobDetails.Content | ConvertFrom-Json
        $JobId = $Job.JobIds | Out-String
        Start-Sleep -Seconds 60
        $JobOutput = Get-AzAutomationJobOutput -AutomationAccountName $AccountName -Id $JobId -ResourceGroupName $ResourceGroupName -Stream "Output"
        $Output = $JobOutput.Summary
        if($Output -like "Hello") { 
            Write-Verbose "Webhook invoked successfully" 
        } 
        else{
            Write-Error "Job invoked through webhook couldn't complete"
        }
    }
    catch{
        Write-Error "Webhook invocation failed"
        Write-Error -Message $_.Exception
    }
    
    #Try getting the webhook 
    $Webhook = Get-AzAutomationWebhook -RunbookName $RunbookName -ResourceGroup $ResourceGroupName -AutomationAccountName $AccountName
    if($Webhook.Name -like $WebhookName) {
        Write-Verbose "Webhook Get successful"
    } 
    else{
        Write-Error "Webhook Get failed"
    }
    
    #update the webhook
    Set-AzAutomationWebhook -Name $WebhookName -IsEnabled $False -ResourceGroup $ResourceGroupName -AutomationAccountName $AccountName
    #check if the webhook is disabled
    $Webhook = Get-AzAutomationWebhook -RunbookName $RunbookName -ResourceGroup $ResourceGroupName -AutomationAccountName $AccountName
    if($Webhook.IsEnabled -eq $false) {
        Write-Verbose "Webhook updated successfully"
    } 
    else{
        Write-Error "Webhook update failed"
    }
    
    # Write-Verbose "Delete webhook" 
    Remove-AzAutomationWebhook -Name $WebhookName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName 
    
    Write-Output "Webhook Scenario Verified"
    
    