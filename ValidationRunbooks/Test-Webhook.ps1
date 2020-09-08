
Param( 
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
    
    $ErrorActionPreference = "Stop"
    if($Environment -eq "USNat"){
        Add-AzEnvironment -Name USNat -ServiceManagementUrl 'https://management.core.eaglex.ic.gov/' -ActiveDirectoryAuthority 'https://login.microsoftonline.eaglex.ic.gov/' -ActiveDirectoryServiceEndpointResourceId 'https://management.azure.eaglex.ic.gov/' -ResourceManagerEndpoint 'https://usnateast.management.azure.eaglex.ic.gov' -GraphUrl 'https://graph.cloudapi.eaglex.ic.gov' -GraphEndpointResourceId 'https://graph.cloudapi.eaglex.ic.gov/' -AdTenant 'Common' -AzureKeyVaultDnsSuffix 'vault.cloudapi.eaglex.ic.gov' -AzureKeyVaultServiceEndpointResourceId 'https://vault.cloudapi.eaglex.ic.gov' -EnableAdfsAuthentication 'False'
    }
    $guid = New-Guid
    $WebhookName = $WebhookName + "-" + $guid.ToString()
    
    # Connect using RunAs account connection
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
    
    # Write-Output "Create webhook" 
    ($Webhook = New-AzAutomationWebhook -Name $WebhookName -IsEnabled $True -ExpiryTime $([datetime]::now.AddYears(1)) -RunbookName $RunbookName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName -Force -RunOn $WorkerGroup) | Out-Null
    if($Webhook.Name -like $WebhookName) {
        Write-Output "Webhook created successfully"
    } 
    else{
        Write-Error "Webhook :: Webhook creation failed"
    }
    
    # Write-Output "Invoke webhook" 
    try{
        $JobDetails = Invoke-WebRequest $Webhook.WebhookURI -Method Post -UseBasicParsing
        $Job = $JobDetails.Content | ConvertFrom-Json
        $JobId = $Job.JobIds | Out-String
        Start-Sleep -Seconds 60
        ($JobOutput = Get-AzAutomationJobOutput -AutomationAccountName $AccountName -Id $JobId -ResourceGroupName $ResourceGroupName -Stream "Output") | Out-Null
        $Output = $JobOutput.Summary
        if($Output -like "Hello") { 
            Write-Output "Webhook invoked successfully" 
        } 
        else{
            Write-Error "Webhook :: Job invoked through webhook couldn't complete"
        }
    }
    catch{
        Write-Error "Webhook :: Webhook invocation failed $_"
    }
    
    #Try getting the webhook 
    ($Webhook = Get-AzAutomationWebhook -RunbookName $RunbookName -ResourceGroup $ResourceGroupName -AutomationAccountName $AccountName) | Out-Null
    if($Webhook.Name -like $WebhookName) {
        Write-Output "Webhook Get successful"
    } 
    else{
        Write-Error "Webhook :: Webhook Get failed"
    }
    
    #update the webhook
    (Set-AzAutomationWebhook -Name $WebhookName -IsEnabled $False -ResourceGroup $ResourceGroupName -AutomationAccountName $AccountName) | Out-Null
    #check if the webhook is disabled
    ($Webhook = Get-AzAutomationWebhook -RunbookName $RunbookName -ResourceGroup $ResourceGroupName -AutomationAccountName $AccountName) | Out-Null
    if($Webhook.IsEnabled -eq $false) {
        Write-Output "Webhook updated successfully"
    } 
    else{
        Write-Error "Webhook :: Update failed"
    }
    
    try{
        $response = Invoke-WebRequest $Webhook.WebhookURI -Method Post -UseBasicParsing | $_.Content
        Write-Output $response
    }
    catch{
        Write-Error "Webhook :: Webhook invocation failed"
        Write-Error -Message $_.Exception
    }


    # Write-Output "Delete webhook" 
    Remove-AzAutomationWebhook -Name $WebhookName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName | Out-Null
    
    Write-Output "Webhook Scenario Validation Completed"
    
    