workflow Test-JobSpecific {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $location = "West Central US",  
        [Parameter(Mandatory = $false)]
        [string] $Environment = "AzureCloud", 
        [Parameter(Mandatory = $false)]
        [string] $ResourceGroupName = "Test-auto-creation",
        [Parameter(Mandatory = $false)]
        [string] $AccountName = "Test-auto-creation-aa",
        [Parameter(Mandatory = $false)]
        [string] $WorkspaceName = "Test-LAWorkspace",
        [Parameter(Mandatory = $false)]
        [string] $RunbookPSName = "ps-job-test",
        [Parameter(Mandatory = $false)]
        [string] $RunbookPSWFName = "psWF-job-test",
        [Parameter(Mandatory = $false)]
        [string] $RunbookPython2Name = "py2-job-test",
        [Parameter(Mandatory=$false)]
        [string]$AssetVerificationRunbookPSName = "AssetVerificationRunbook"
        )

$workspaceId = ""
$workspacePrimaryKey = ""
$agentEndpoint = ""
$aaPrimaryKey = ""
$workerGroupName = "test-auto-create"

$guid_val = [guid]::NewGuid()
$guid = $guid_val.ToString()

$vmName = "Test-VM-" + $guid.SubString(0,4) 
$assetVerificationRunbookParams = @{"guid" = $guid}

function Connect-To-AzAccount{
    Param(
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud"
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
}

function Start-PythonJob {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $runOn = ""
    )
    # Python2
    $JobHybridPy2 = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:RunbookPython2Name  -ResourceGroupName $using:ResourceGroupName -RunOn $runOn 
    Write-Output "Python Job : $JobHybridPy2"
    $jobId = $JobHybridPy2.JobId
    
    Write-Output "Polling for job completion for job Id : $jobId"
    $terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
    $retryCount = 1
    while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 6) {
        Start-Sleep -s 20
        $retryCount++
        $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
    }

    $jobStatus = $jobDetails.Status

    if($jobStatus -eq "Completed"){
        $JobOutput = Get-AzAutomationJobOutput -Id $jobId -Stream "Output" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        if($JobOutput.Summary -like "SampleOutput") {
            Write-Output "Hybrid job for Python runbook ran successfully and output stream is visible"
        }    
        $JobError = Get-AzAutomationJobOutput -Id $jobId -Stream "Error" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        if($JobError.Summary -like "Some Error") {
            Write-Output "Error stream is visible"
        }    
        $JobWarning = Get-AzAutomationJobOutput -Id $jobId -Stream "Warning" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        if($JobWarning.Summary -like "Some Warning") {
            Write-Output "Warning stream is visible"
        } 
    }
    else{
        Write-Error "Python Runbook Job execution status after 10 minutes of waiting is $jobStatus"
    }
}

function Start-PsJob {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $runOn = ""
    )
    
    $JobCloudPS = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:RunbookPSName  -ResourceGroupName $using:ResourceGroupName -RunOn $runOn
    $jobId = $JobCloudPS.JobId
    
    $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
    $terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
    $retryCount = 1
    while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 6) {
        Start-Sleep -s 20
        $retryCount++
        $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
    }
    
    $jobStatus = $jobDetails.Status

    if($jobStatus -eq "Completed"){
        $JobOutput = Get-AzAutomationJobOutput -Id $jobId -Stream "Output" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        if($JobOutput.Summary -like "SampleOutput") {
            Write-Output "Hybrid job for PS runbook ran successfully and output stream is visible"
        }    
        $JobError = Get-AzAutomationJobOutput -Id $jobId -Stream "Error" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        if($JobError.Summary -like "SampleError") {
            Write-Output "Error stream is visible"
        }    
        $JobWarning = Get-AzAutomationJobOutput -Id $jobId -Stream "Warning" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        if($JobWarning.Summary -like "SampleWarning") {
            Write-Output "Warning stream is visible"
        }
    }
    else{
        Write-Error "PS Runbook Job execution status after 10 minutes of waiting is $jobStatus"
    }
}

function Start-PsWFJob {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $runOn = ""
    )
    $JobCloudPSWF = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:RunbookPSWFName -ResourceGroupName $using:ResourceGroupName -RunOn $runOn
    $pswfRbJobId = $JobCloudPSWF.JobId
    Start-Sleep -Seconds 400
    $Job1 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    if($Job1.Status -like "Running") {
        Write-Output "Cloud job for PS WF runbook is running"
    }  
    elseif($Job1.Status -like "Queued") {
        Write-Warning "Cloud job for PS WF runbook didn't start in 5 mins"
        Start-Sleep -Seconds 100
    }

    Write-Output "Suspending PSWF runbook"
    Suspend-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    Start-Sleep -Seconds 30
    $Job2 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    if($Job2.Status -like "Suspended") {
        Write-Output "Cloud job for PS WF runbook is suspended"
    } 

    Write-Output "Resuming PSWF runbook"
    Resume-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    Start-Sleep -Seconds 30
    $Job3 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    if($Job3.Status -like "Running") {
        Write-Output "Cloud job for PS WF runbook has resumed running"
    } 

    Write-Output "Stopping PSWF runbook"
    Stop-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    Start-Sleep -Seconds 30
    $Job4 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    if($Job4.Status -like "Stopping" -or $Job4.Status -like "Stopped") {
        Write-Output "Cloud job for PS WF runbook is stopping"
    }     
}

function Start-AssetVerificationJob {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $runOn = ""
    )
    Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:AssetVerificationRunbookPSName  -ResourceGroupName $using:ResourceGroupName -Parameters $using:assetVerificationRunbookParams -RunOn $runOn  -MaxWaitSeconds 1200 -Wait
}

Connect-To-AzAccount

parallel {

    sequence {
        ### Create an automation account
        Write-Output "Getting Automation Account....."
        #$AccountName = $AccountName + $guid.ToString()
        
        # Write-Verbose "Create account" -verbose
        try {
            $Account = Get-AzAutomationAccount -Name $AccountName -ResourceGroupName $ResourceGroupName 
            if($Account.AutomationAccountName -like $AccountName) {
                Write-Output "Account retrieved successfully"
                $accRegInfo = Get-AzAutomationRegistrationInfo -ResourceGroup $ResourceGroupName -AutomationAccountName  $AccountName
                $WORKFLOW:agentEndpoint = $accRegInfo.Endpoint
                $WORKFLOW:aaPrimaryKey = $accRegInfo.PrimaryKey

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
    }

    sequence {
        Write-Output "Creating LA Workspace...."
        ### Create an LA workspace
        $workspace_guid = [guid]::NewGuid()
        $WorkspaceName = $WorkspaceName + $workspace_guid.ToString()

        # Create a new Log Analytics workspace if needed
        try {
            Write-Output "Creating new workspace named $WorkspaceName in region $Location..."
            $Workspace = New-AzOperationalInsightsWorkspace -Location $Location -Name $WorkspaceName -Sku Standard -ResourceGroupName $ResourceGroupName
            Write-Output $workspace
            Start-Sleep -s 60

            Write-Output "Enabling Automation for the created workspace...."
            Set-AzOperationalInsightsIntelligencePack -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -IntelligencePackName "AzureAutomation" -Enabled $true

            $workspaceDetails = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName
            $WORKFLOW:workspaceId = $workspaceDetails.CustomerId

            $workspaceSharedKey = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $ResourceGroupName -Name $WorkspaceName
            $WORKFLOW:workspacePrimaryKey = $workspaceSharedKey.PrimarySharedKey

            Write-Output "Workspace Details to be used to register machine are WorkspaceId : $workspaceId and WorkspaceKey : $workspacePrimaryKey"
        } catch {
            Write-Verbose "Error creating LA workspace"
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

    sequence {
        ##Create an AZ VM  
        try{
            
        $vmNetworkName = "TestVnet" + $guid.SubString(0,4)
        $subnetName = "TestSubnet"+ $guid.SubString(0,4)
        $newtworkSG = "TestNetworkSecurityGroup" + $guid.SubString(0,4)
        $ipAddressName = "TestPublicIpAddress" + $guid.SubString(0,4)
        $User = "TestVMUser"
        $Password = ConvertTo-SecureString "SecurePassword12345" -AsPlainText -Force
        $VMCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password
        New-AzVm `
            -ResourceGroupName $ResourceGroupName `
            -Name $vmName `
            -Location $location `
            -VirtualNetworkName $vmNetworkName `
            -SubnetName $subnetName `
            -SecurityGroupName $newtworkSG `
            -PublicIpAddressName $ipAddressName `
            -Credential $VMCredential

        Start-Sleep -s 120
        }
        catch{
            Write-Error "Error creating VM"
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
}

#run az vm extesion
sequence {
        
    ## Run AZ VM Extension to download and Install MMA Agent
    $WORKFLOW:workerGroupName = 'test-auto-create'
    $commandToExecute = "powershell .\WorkerDownloadAndRegister.ps1 -workspaceId $WORKFLOW:workspaceId -workspaceKey $WORKFLOW:workspacePrimaryKey -workerGroupName $workerGroupName -agentServiceEndpoint $WORKFLOW:agentEndpoint -aaToken $WORKFLOW:aaPrimaryKey"

    $settings = @{"fileUris" =  @("https://raw.githubusercontent.com/krmanupa/AutoRegisterHW/master/VMExtensionScripts/WorkerDownloadAndRegister.ps1"); "commandToExecute" = $commandToExecute};
    $protectedSettings = @{"storageAccountName" = ""; "storageAccountKey" = ""};

    # Run Az VM Extension to download and register worker.
    Write-Output "Running Az VM Extension...."
    Write-Output "Command executing ... $commandToExecute"
    try {
        Set-AzVMExtension -ResourceGroupName $ResourceGroupName `
        -Location $location `
            -VMName $vmName `
            -Name "Register-HybridWorker" `
            -Publisher "Microsoft.Compute" `
            -ExtensionType "CustomScriptExtension" `
            -TypeHandlerVersion "1.10" `
            -Settings $settings `
            -ProtectedSettings $protectedSettings

    }
    catch {
        Write-Error "Error running VM extension"
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Execute the runbook to create required Automation assets on this account.
sequence {
    #Create required assets
    try{
        $creationParams = @{"guid" = $guid; "ResourceGroupName"=$ResourceGroupName; "AccountName"= $AccountName }
        Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name "Test-AutomationAssets-Creation" -Parameters $creationParams -ResourceGroupName $ResourceGroupName -MaxWaitSeconds 1800 -Wait
    }
    catch{
        Write-Error "Error creating assets..."
    }
}

#Execute cloud and hybrid jobs
sequence {
    Write-Output "Starting Cloud Jobs..."
    
    Start-PythonJob 
    Start-PsJob 
    # Start-PsWFJob 
    Start-AssetVerificationJob 
}

sequence {
    Write-Output "Starting Hybrid Jobs..."
    
    #Start-PythonJob -runOn $workerGroupName
    Start-PsJob -runOn $workerGroupName
    # Start-PsWFJob -runOn $workerGroupName
    Start-AssetVerificationJob -runOn $workerGroupName
}

#Run Jobs using Schedules and Webhooks
parallel {
    #Cloud
    sequence {
        Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name "Test-Schedule"  -ResourceGroupName $ResourceGroupName -MaxWaitSeconds 900 -Wait
    }
    sequence {
        Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name "Test-Webhook"  -ResourceGroupName $ResourceGroupName -MaxWaitSeconds 900 -Wait 
    }
    #hybrid
    sequence {
        $params = @{"WorkerGroup" = $workerGroupName}
        Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name "Test-Schedule"  -ResourceGroupName $ResourceGroupName -Parameters $params -MaxWaitSeconds 900 -Wait
    }
    sequence {
        $params = @{"WorkerGroup" = $workerGroupName}
        Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name "Test-Webhook"  -ResourceGroupName $ResourceGroupName -Parameters $params -MaxWaitSeconds 900 -Wait
    }
}


# De register the HW
sequence {
    # Start-Sleep -s 600
    # $deregisterParams = @{"agentServiceEndpoint" = $WORKFLOW:agentEndpoint; "aaToken" = $WORKFLOW:aaPrimaryKey}
    # Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name "DeregisterHW"  -ResourceGroupName $ResourceGroupName -Parameters $deregisterParams -RunOn $WORKFLOW:workerGroupName
    #TODO: Delete the HWG cmdlet also
}

#Delete all the resources
sequence {
    #Remove-AzVm -ResourceGroupName $ResourceGroupName -Name $vmName -Force
    #Remove-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -Force
}
}