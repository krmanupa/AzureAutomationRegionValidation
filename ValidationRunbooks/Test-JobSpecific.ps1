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
        [Parameter(Mandatory=$true)]
        [string] $guid ,
        [Parameters (Mandatory=$false)]
        [Boolean] $RunCloudTests = $true,
        [Parameters (Mandatory=$false)]
        [Boolean] $RunHybridTests = $true,
        [Parameter(Mandatory = $false)]
        [string] $RunbookPSName = "ps-job-test",
        [Parameter(Mandatory = $false)]
        [string] $ChildJobTriggeringRunbookName = "TriggerChildRunbook",
        [Parameter(Mandatory = $false)]
        [string] $RunbookPSWFName = "psWF-job-test",
        [Parameter(Mandatory = $false)]
        [string] $RunbookPython2Name = "py2-job-test",
        [Parameter(Mandatory=$false)]
        [string]$AssetVerificationRunbookPSName = "AssetVerificationRunbook"
        )


$workerGroupName = "test-auto-create"

$assetVerificationRunbookParams = @{"guid" = $guid}
$assetCreationSucceeded = $false


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
    Write-Verbose "Python Job : $JobHybridPy2"
    $jobId = $JobHybridPy2.JobId
    
    Write-Verbose "Polling for job completion for job Id : $jobId"
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
            Write-Verbose "Hybrid job for Python runbook ran successfully and output stream is visible"
        }    
        $JobError = Get-AzAutomationJobOutput -Id $jobId -Stream "Error" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        if($JobError.Summary -like "Some Error") {
            Write-Verbose "Error stream is visible"
        }    
        $JobWarning = Get-AzAutomationJobOutput -Id $jobId -Stream "Warning" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        if($JobWarning.Summary -like "Some Warning") {
            Write-Verbose "Warning stream is visible"
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
            Write-Verbose "Job for PS runbook ran successfully on $runOn and output stream is visible"
        }    
        $JobError = Get-AzAutomationJobOutput -Id $jobId -Stream "Error" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        if($JobError.Summary -like "SampleError") {
            Write-Verbose "Job for PS runbook ran successfully on $runOn and Error stream is visible"
        }    
        $JobWarning = Get-AzAutomationJobOutput -Id $jobId -Stream "Warning" -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
        if($JobWarning.Summary -like "SampleWarning") {
            Write-Verbose "Job for PS runbook ran successfully on $runOn and Warning stream is visible"
        }
    }
    else{
        Write-Error "PS Runbook Job execution status after 10 minutes of waiting is $jobStatus"
    }
}

function Start-ChildJobTriggeringRunbook {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $runOn = ""
    )
    
    $params = @{"AccountName" = $using:AccountName ; "ResourceGroupName" = $using:ResourceGroupName}
    $JobCloudPS = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:ChildJobTriggeringRunbookName  -ResourceGroupName $using:ResourceGroupName -RunOn $runOn -Parameters $params
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
        Write-Verbose "Job for PS runbook to tirgger Child runbook ran successfully on $runOn and output stream is visible"
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
        Write-Verbose "Cloud job for PS WF runbook is running"
    }  
    elseif($Job1.Status -like "Queued") {
        Write-Warning "Cloud job for PS WF runbook didn't start in 5 mins"
        Start-Sleep -Seconds 100
    }

    Write-Verbose "Suspending PSWF runbook"
    Suspend-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    Start-Sleep -Seconds 30
    $Job2 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    if($Job2.Status -like "Suspended") {
        Write-Verbose "Cloud job for PS WF runbook is suspended"
    } 

    Write-Verbose "Resuming PSWF runbook"
    Resume-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    Start-Sleep -Seconds 30
    $Job3 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    if($Job3.Status -like "Running") {
        Write-Verbose "Cloud job for PS WF runbook has resumed running"
    } 

    Write-Verbose "Stopping PSWF runbook"
    Stop-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    Start-Sleep -Seconds 30
    $Job4 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName
    if($Job4.Status -like "Stopping" -or $Job4.Status -like "Stopped") {
        Write-Verbose "Cloud job for PS WF runbook is stopping"
    }     
}

function Start-AssetVerificationJob {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $runOn = ""
    )
    if($assetCreationSucceeded -eq $true){
        Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:AssetVerificationRunbookPSName  -ResourceGroupName $using:ResourceGroupName -Parameters $using:assetVerificationRunbookParams -RunOn $runOn  -MaxWaitSeconds 1200 -Wait
    }
    
}

Connect-To-AzAccount

#Execute cloud and hybrid jobs
sequence {
    if($RunCloudTests -eq $true){
        Write-Verbose "Starting Cloud Jobs..."

        Start-PythonJob 
        Start-PsJob 
        # Start-PsWFJob 
        Start-ChildJobTriggeringRunbook
        Start-AssetVerificationJob 
    }
}

sequence {
    if($RunHybridTests -eq $true -and $workerGroupName -ne ""){
        Write-Verbose "Starting Hybrid Jobs..."
    
        #Start-PythonJob -runOn $workerGroupName
        Start-PsJob -runOn $workerGroupName
        # Start-PsWFJob -runOn $workerGroupName
        Start-ChildJobTriggeringRunbook -runOn $workerGroupName
        Start-AssetVerificationJob -runOn $workerGroupName
    }
    else{
        Write-Output "Check the hybrid related params passed, RunHybridTests should be True and WorkerGroupName should not be Empty"
    }
}
}