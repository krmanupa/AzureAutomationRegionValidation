workflow Test-JobSpecific {
    Param( 
        [Parameter(Mandatory = $false)]
        [string] $Environment = "AzureCloud", 
        [Parameter(Mandatory = $true)]
        [string] $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string] $AccountName,
        [Parameter(Mandatory = $false)]
        [string] $workerGroupName = "",
        [Parameter(Mandatory = $false)]
        [string] $linuxWorkerGroupName = "",
        [Parameter(Mandatory = $true)]
        [string] $guid,
        [Parameters (Mandatory = $false)]
        [Boolean] $RunCloudTests = $true, 
        [Parameters (Mandatory = $false)]
        [Boolean] $CloudAssetVerification = $true,
        [Parameters (Mandatory = $false)]
        [Boolean] $RunWindowsHybridTests = $true,
        [Parameters (Mandatory = $false)]
        [Boolean] $RunLinuxHybridTests = $true,
        [Parameters (Mandatory = $false)]
        [Boolean] $RunWindowsAssetVerificationTests = $true, 
        [Parameters (Mandatory = $false)]
        [Boolean] $RunLinuxAssetVerificationTests = $true,
        [Parameter(Mandatory = $false)]
        [string] $RunbookPSName = "ps-job-test",
        [Parameter(Mandatory = $false)]
        [string] $ChildJobTriggeringRunbookName = "TriggerChildRunbook",
        [Parameter(Mandatory = $false)]
        [string] $RunbookPSWFName = "psWF-job-test",
        [Parameter(Mandatory = $false)]
        [string] $RunbookPython2Name = "py2-job-test",
        [Parameter(Mandatory = $false)]
        [string]$AssetVerificationRunbookPSName = "AssetVerificationRunbook",
        [Parameter(Mandatory = $false)]
        [string]$AssetVerificationRunbookPythonName = "PythonAutomationAssetsVerification"
    )


    $assetVerificationRunbookParams = @{"guid" = $guid }

    if ($Environment -eq "USNat") {
        Add-AzEnvironment -Name USNat -ServiceManagementUrl 'https://management.core.eaglex.ic.gov/' -ActiveDirectoryAuthority 'https://login.microsoftonline.eaglex.ic.gov/' -ActiveDirectoryServiceEndpointResourceId 'https://management.azure.eaglex.ic.gov/' -ResourceManagerEndpoint 'https://usnateast.management.azure.eaglex.ic.gov' -GraphUrl 'https://graph.cloudapi.eaglex.ic.gov' -GraphEndpointResourceId 'https://graph.cloudapi.eaglex.ic.gov/' -AdTenant 'Common' -AzureKeyVaultDnsSuffix 'vault.cloudapi.eaglex.ic.gov' -AzureKeyVaultServiceEndpointResourceId 'https://vault.cloudapi.eaglex.ic.gov' -EnableAdfsAuthentication 'False'
    }

    function Connect-To-AzAccount {
        # Connect using RunAs account connection
        $connectionName = "AzureRunAsConnection"
        try {
            $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName      
            Write-Output  "Logging in to Azure..." -verbose
            Connect-AzAccount `
                -ServicePrincipal `
                -TenantId $servicePrincipalConnection.TenantId `
                -ApplicationId $servicePrincipalConnection.ApplicationId `
                -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                -Environment $using:Environment | Out-Null
        }
        catch {
            if (!$servicePrincipalConnection) {
                $ErrorMessage = "Connection $connectionName not found."
                throw $ErrorMessage
            }
            else {
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
        ($JobHybridPy2 = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:RunbookPython2Name  -ResourceGroupName $using:ResourceGroupName -RunOn $runOn ) | Out-Null
        $jobId = $JobHybridPy2.JobId
    
        Write-Output  "Polling for job completion for job Id : $jobId"
        $terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
        $retryCount = 1
    
        $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
        while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 20) {
            Start-Sleep -s 30
            $retryCount++
            $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
        }

        $jobStatus = $jobDetails.Status

        if ($jobStatus -eq "Completed") {
            $JobOutput = Get-AzAutomationJobOutput -Id $jobId -Stream "Output" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
            if ($JobOutput.Summary -like "SampleOutput") {
                Write-Output  "Hybrid job for Python runbook ran successfully and output stream is visible"
            }    
            $JobError = Get-AzAutomationJobOutput -Id $jobId -Stream "Error" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
            if ($JobError.Summary -like "Some Error") {
                Write-Output  "Error stream is visible"
            }    
            $JobWarning = Get-AzAutomationJobOutput -Id $jobId -Stream "Warning" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
            if ($JobWarning.Summary -like "Some Warning") {
                Write-Output  "Warning stream is visible"
            } 
        }
        else {
            Write-Error "Cloud and Hybrid Jobs Validation :: Python Runbook Job execution status after 10 minutes of waiting is $jobStatus"
        }
    }

    function Start-PsJob {
        Param(
            [Parameter(Mandatory = $false)]
            [string] $runOn = ""
        )
    
        ($JobCloudPS = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:RunbookPSName  -ResourceGroupName $using:ResourceGroupName -RunOn $runOn) | Out-Null
        $jobId = $JobCloudPS.JobId
    
        $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
        $terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
        $retryCount = 1
        while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 20) {
            Start-Sleep -s 30
            $retryCount++
            $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
        }
    
        $jobStatus = $jobDetails.Status

        if ($jobStatus -eq "Completed") {
            $JobOutput = Get-AzAutomationJobOutput -Id $jobId -Stream "Output" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
            if ($JobOutput.Summary -like "SampleOutput") {
                Write-Output  "Job for PS runbook ran successfully on $runOn and output stream is visible"
            }    
            $JobError = Get-AzAutomationJobOutput -Id $jobId -Stream "Error" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
            if ($JobError.Summary -like "SampleError") {
                Write-Output  "Job for PS runbook ran successfully on $runOn and Error stream is visible"
            }    
            $JobWarning = Get-AzAutomationJobOutput -Id $jobId -Stream "Warning" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
            if ($JobWarning.Summary -like "SampleWarning") {
                Write-Output  "Job for PS runbook ran successfully on $runOn and Warning stream is visible"
            }
        }
        else {
            Write-Error "Cloud and Hybrid Jobs Validation :: PS Runbook Job execution status after reaching the terminal state is $jobStatus"
        }
    }

    function Start-ChildJobTriggeringRunbook {
        Param(
            [Parameter(Mandatory = $false)]
            [string] $runOn = ""
        )
    
        $params = @{"AccountName" = $using:AccountName ; "ResourceGroupName" = $using:ResourceGroupName; "Environment" = $using:Environment }
        ($JobCloudPS = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:ChildJobTriggeringRunbookName  -ResourceGroupName $using:ResourceGroupName -RunOn $runOn -Parameters $params) | Out-Null
        $jobId = $JobCloudPS.JobId
    
        $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
        $terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
        $retryCount = 1
        while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 20) {
            Start-Sleep -s 30
            $retryCount++
            $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
        }
    
        $jobStatus = $jobDetails.Status

        if ($jobStatus -eq "Completed") {
            Write-Output  "Job for PS runbook to tirgger Child runbook ran successfully on $runOn and output stream is visible"
        }
        else {
            Write-Error "Cloud and Hybrid Jobs Validation :: PS Trigger child Runbook Job execution status after reaching the terminal state is $jobStatus"
        }
    }

    function Start-PsWFJob {
        Param(
            [Parameter(Mandatory = $false)]
            [string] $runOn = ""
        )

        function Wait-JobReachTerminalState {
            param (
                $jobId,
                $expectedStatus,
                $noOfRetries = 20
            )
            $expectedStatusReached = $false
            $retryCount = 1
            $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
            while ($jobDetails.Status -ne $expectedStatus -and $retryCount -le $noOfRetries) {
                Start-Sleep -s 20
                $retryCount++
                $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
            }
            
            if ($jobDetails.Status -eq $expectedStatus) {
                $expectedStatusReached = $true
            }
            return $expectedStatusReached
        }

        $JobCloudPSWF = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:RunbookPSWFName -ResourceGroupName $using:ResourceGroupName -RunOn $runOn
        $pswfRbJobId = $JobCloudPSWF.JobId
        $hasStatusReached = Wait-JobReachTerminalState -jobId $pswfRbJobId -expectedStatus "Running"

        if ($hasStatusReached -ne $true) {
            Write-Output "ERROR: PSWF job has not started running..."
            return
        }

        Write-Output  "Suspending PSWF runbook"
        Suspend-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        $hasStatusReached = Wait-JobReachTerminalState -jobId $pswfRbJobId -expectedStatus "Suspended" -noOfRetries 6

        if ($hasStatusReached -ne $true) {
            Write-Output "ERROR: Error while suspending PSWF job..."
        }
        else {
            Write-Output  "Resuming PSWF runbook"
            Resume-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
            $hasStatusReached = Wait-JobReachTerminalState -jobId $pswfRbJobId -expectedStatus "Running" -noOfRetries 6

            if ($hasStatusReached -ne $true) {
                Write-Output "ERROR: Error while Resuming PSWF job..."
            }
        }

        Write-Output  "Stopping PSWF runbook"
        Stop-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        $hasStatusReached = Wait-JobReachTerminalState -jobId $pswfRbJobId -expectedStatus "Stopped" -noOfRetries 6

        if ($hasStatusReached -ne $true) {
            Write-Output "ERROR: Error while Stopping PSWF job..."
        }   
    }

    function Start-AssetVerificationJob {
        Param(
            $runOn = "",
            $runbookName = $using:AssetVerificationRunbookPSName
        )
        # PS assets verification
        ($job = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $runbookName  -ResourceGroupName $using:ResourceGroupName -Parameters $using:assetVerificationRunbookParams -RunOn $runOn ) | Out-Null

        $jobId = $job.JobId
        $terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
        $retryCount = 1
        $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
        while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 30) {
            Start-Sleep -s 60
            $retryCount++
            $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
        }
    
        $jobStatus = $jobDetails.Status
        Write-Output "Asset Verification status run on $runOn is $jobStatus"
    }

    Connect-To-AzAccount

    #Execute cloud and hybrid jobs
    sequence {
        if ($RunCloudTests -eq $true) {
            Write-Output  "Starting Cloud Jobs..."

            Start-PythonJob 
            Write-Output "Cloud and Hybrid Jobs Validation :: Python Cloud Job validation completed"

            Start-PsJob 
            Write-Output "Cloud and Hybrid Jobs Validation :: Powershell Cloud Job validation completed"

            Start-PsWFJob 
            Write-Output "Cloud and Hybrid Jobs Validation :: Powershell WORKFLOW Cloud Job validation completed"

            Start-ChildJobTriggeringRunbook
            Write-Output "Cloud and Hybrid Jobs Validation :: Trigger Child Runbook  Cloud Job validation completed"

            if ($CloudAssetVerification -eq $true) {
                Start-AssetVerificationJob 
                Write-Output "Cloud and Hybrid Jobs Validation :: AssetVerification Cloud Job validation completed"
            }
        }
    }

    sequence {
        if ($RunWindowsHybridTests -eq $true -and $workerGroupName -ne "") {
            Write-Output  "Starting Hybrid Jobs..."
    
            #Start-PythonJob -runOn $workerGroupName

            Start-PsJob -runOn $workerGroupName
            Write-Output "Cloud and Hybrid Jobs Validation :: Powershell Hybrid Job validation completed"

            Start-PsWFJob -runOn $workerGroupName
            Write-Output "Cloud and Hybrid Jobs Validation :: Powershell WORKFLOW Hybrid Job validation completed"

            Start-ChildJobTriggeringRunbook -runOn $workerGroupName
            Write-Output "Cloud and Hybrid Jobs Validation :: Trigger Child Runbook Hybrid Job validation completed"

            if ($RunWindowsAssetVerificationTests -eq $true) {
                Start-AssetVerificationJob -runOn $workerGroupName
                Write-Output "Cloud and Hybrid Jobs Validation :: AssetVerification Hybrid Job validation completed"
            }
        
        }
        else {
            Write-Output "Cloud and Hybrid Jobs Validation :: Check the hybrid related params passed, RunHybridTests should be True and WorkerGroupName should not be Empty"
        }
    }

    sequence {
        if ($RunLinuxHybridTests -eq $true -and $linuxWorkerGroupName -ne "") {
            Write-Output  "Starting Hybrid Jobs..."
    
            Start-PythonJob -runOn $linuxWorkerGroupName

            
            if ($RunWindowsAssetVerificationTests -eq $true) {
                Start-AssetVerificationJob -runOn $linuxWorkerGroupName -runbookName $using:AssetVerificationRunbookPythonName
                Write-Output "Cloud and Hybrid Jobs Validation :: AssetVerification Hybrid Job validation completed"
            }
        
        }
        else {
            Write-Output "Cloud and Hybrid Jobs Validation :: Check the hybrid related params passed, RunLinuxHybridTests should be True and linuxWorkerGroupName should not be Empty"
        }
    }
    Write-Output "Cloud and Hybrid Jobs Validation :: Validation Completed"
}