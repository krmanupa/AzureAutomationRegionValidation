workflow BaseScript_remote {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $location = "Switzerland North",  
        [Parameter(Mandatory = $false)]
        [string] $Environment = "AzureCloud", 
        [Parameter(Mandatory = $true)]
        [string] $SubscriptionId = "cd45f23b-b832-4fa4-a434-1bf7e6f14a5a", 
        [Parameter(Mandatory = $false)]
        [string] $ResourceGroupName = "region_autovalidate_dd34",
        [Parameter(Mandatory = $false)]
        [string] $AccountName = "egion-test-aadd34",
        [Parameter (Mandatory = $false)]
        [string] $NewResourceGroupName = "region_autovalidate_moveto_dd34"
    )
     
    $guid_val = [guid]::NewGuid()
    $guid = $guid_val.ToString()
    $UriStart = "https://management.azure.com/subscriptions/" + $SubscriptionId


    if ($Environment -eq "USNat" -and $location -eq "USNat East") {
        Add-AzEnvironment -Name USNat -ServiceManagementUrl 'https://management.core.eaglex.ic.gov/' -ActiveDirectoryAuthority 'https://login.microsoftonline.eaglex.ic.gov/' -ActiveDirectoryServiceEndpointResourceId 'https://management.azure.eaglex.ic.gov/' -ResourceManagerEndpoint 'https://usnateast.management.azure.eaglex.ic.gov' -GraphUrl 'https://graph.cloudapi.eaglex.ic.gov' -GraphEndpointResourceId 'https://graph.cloudapi.eaglex.ic.gov/' -AdTenant 'Common' -AzureKeyVaultDnsSuffix 'vault.cloudapi.eaglex.ic.gov' -AzureKeyVaultServiceEndpointResourceId 'https://vault.cloudapi.eaglex.ic.gov' -EnableAdfsAuthentication 'False'

        $UriStart = "https://management.core.eaglex.ic.gov/subscriptions/" + $SubscriptionId
    }

    $vmName = "Test-VM-" + $guid.SubString(0, 4) 
    $linuxVmName = "Test-LinuxVM-" + $guid.SubString(0, 4) 
    $workerGroupName = "test-auto-create"
    $linuxWorkerGroupName = "test-auto-create-linux"


    $assetVerificationRunbookParams = @{"guid" = $guid }
    $CreateHWGRunbookName = "CreateHWG"
    $CreateLinuxHWGRunbookName = "CreateLinuxHWG"
    $StartCloudHybridJobsRunbookName = "Test-JobSpecific"


    $ScenarioStatus = New-Object 'system.collections.generic.dictionary[string,string]'
    
    function Connect-To-AzAccount {
        # Connect using RunAs account connection
        $connectionName = "AzureRunAsConnection"
        try {
            $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName      
            Write-Verbose "Logging in to Azure..." -verbose
            Connect-AzAccount `
                -ServicePrincipal `
                -TenantId $servicePrincipalConnection.TenantId `
                -ApplicationId $servicePrincipalConnection.ApplicationId `
                -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                -Environment $using:Environment 
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


    function Start-AccountSpecificRunbook {
        param (
            $ScenarioStatus
        )
        Write-Output "Starting Account Specific Validation...."

        $accountParams = @{"location" = $using:location ; "Environment" = $using:Environment; "ResourceGroupName" = $using:ResourceGroupName; "NewResourceGroupName" = $using:NewResourceGroupName }

        $job = Start-AzAutomationRunbook -Name "Test-AutomationAccount-Creation" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $accountParams 
        
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


        $ScenarioStatus.Add("AccountSpecific", $jobStatus.ToString())
        Write-Output "Account Specific Validation $jobStatus"
        
    }

    function Start-RunbookSpecificOperations {
        param (
            $ScenarioStatus
        )
    
        Write-Output "Starting Runbook Specific Validations..."

        $runbookParams = @{"location" = $using:location ; "Environment" = $using:Environment; "UriStart" = $using:UriStart; "AccountName" = $using:AccountName; "ResourceGroupName" = $using:ResourceGroupName }

        $job = Start-AzAutomationRunbook -Name "Test-Runbooks-Creation" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $runbookParams 

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

        $ScenarioStatus.Add("RunbookSpecific", $jobStatus.ToString())
        Write-Output "Runbook Specific Validation $jobStatus"
    }

    function Start-AssetCreation {
        param (
            $ScenarioStatus
        )
        Write-Output "Starting Asset Creation ..."
    
        $automationAssetsCreationsParams = @{"guid" = $using:guid; "ResourceGroupName" = $using:ResourceGroupName; "AccountName" = $using:AccountName; "Environment" = $using:Environment; "UriStart" = $using:UriStart }
    
        $job = Start-AzAutomationRunbook -Name "Test-AutomationAssets-Creation" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $automationAssetsCreationsParams 

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

        $ScenarioStatus.Add("AssetCreation", $jobStatus.ToString())
        Write-Output "Asset Creation $jobStatus"
    }

    function Start-HybridWorkerGroupCreation {
        param (
            $ScenarioStatus
        )
        Write-Output "Starting Hybrid Worker Group Creation...."
    
        function Wait-JobReachTerminalState {
            param (
                $jobId
            )
            $terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
            $retryCount = 1
            $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
            while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 30) {
                Start-Sleep -s 60
                $retryCount++
                $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
            }
    
            $jobStatus = $jobDetails.Status
            return $jobStatus
        }

        $hwgCreationParams = @{"location" = $using:location; "Environment" = $using:Environment; "ResourceGroupName" = $using:ResourceGroupName; "AccountName" = $using:AccountName; "WorkerType" = "Windows"; "vmName" = $using:vmName; "WorkerGroupName" = $using:workerGroupName }

        $job = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Name $using:CreateHWGRunbookName -Parameters $hwgCreationParams 
        
        $jobId = $job.JobId
        $jobStatus = Wait-JobReachTerminalState -jobId $jobId
        
        $ScenarioStatus.Add("WindowsHWGCreation", $jobStatus.ToString())
        Write-Output "Windows Hybrid Worker Group Creation $jobStatus"

        $linuxHwgCreationParams = @{"location" = $using:location; "Environment" = $using:Environment; "ResourceGroupName" = $using:ResourceGroupName; "AccountName" = $using:AccountName; "WorkerType" = "Linux"; "vmName" = $using:linuxVmName; "WorkerGroupName" = $using:linuxWorkerGroupName }

        $job = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Name $using:CreateLinuxHWGRunbookName -Parameters $linuxHwgCreationParams
        
        $jobId = $job.JobId
        $jobStatus = Wait-JobReachTerminalState -jobId $jobId
        $ScenarioStatus.Add("LinuxHWGCreation", $jobStatus.ToString())
        Write-Output "Linux Hybrid Worker Group Creation $jobStatus"
    }

    function Start-CloudAndHybridJobsValidation {
        param (
            $ScenarioStatus
        )
        Write-Output "Starting Cloud and Hybrid Jobs Validation..."
    

        if ($ScenarioStatus["AssetCreation"] -ne "Completed") {
            $CloudAssetVerification = $false
            $RunWindowsAssetVerificationTests = $false
            $RunLinuxAssetVerificationTests = $false
        }

        if ($ScenarioStatus["WindowsHWGCreation"] -ne "Completed") {
            $RunWindowsHybridTests = $false
        }
        if ($ScenarioStatus["LinuxHWGCreation"] -ne "Completed") {
            $RunLinuxHybridTests = $false
        }

        $startCloudHybridJobsParams = @{"Environment" = $using:Environment; "ResourceGroupName" = $using:ResourceGroupName; "AccountName" = $using:AccountName; "workerGroupName" = $using:workerGroupName; "linuxWorkerGroupName" = $using:linuxWorkerGroupName; "guid" = $using:guid; "CloudAssetVerification" = $CloudAssetVerification; "RunWindowsHybridTests" = $RunWindowsHybridTests; "RunLinuxHybridTests" = $RunLinuxHybridTests; "RunWindowsAssetVerificationTests" = $RunWindowsAssetVerificationTests; "RunLinuxAssetVerificationTests" = $RunLinuxAssetVerificationTests }

        $job = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Name $using:StartCloudHybridJobsRunbookName -Parameters $startCloudHybridJobsParams 

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

        Write-Output "Cloud and Hybrid Jobs Validation $jobStatus"
    }

    function Start-DSCSpecificRunbook {
        Write-Output "Starting DSC Validation..."

        $dscParams = @{"location" = $using:location; "Environment" = $using:Environment; "UriStart" = $using:UriStart; "AccountDscName" = $using:AccountName; "ResourceGroupName" = $using:ResourceGroupName }
        $job = Start-AzAutomationRunbook -Name "Test-dsc" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $dscParams

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

        Write-Output "DSC Validation $jobStatus"
    }


    function Start-SourceControl {
        Write-Output "Starting SourceControl Validation...."
    
        $sourceControlParams = @{"Environment" = $using:Environment; "AccountName" = $using:AccountName; "ResourceGroupName" = $using:ResourceGroupName }
        
        $job = Start-AzAutomationRunbook -Name "Test-SourceControl" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $sourceControlParams

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
        
        Write-Output "SourceControl Validation $jobStatus"
    }

    function Start-Webhook {

        function Wait-JobReachTerminalState {
            param (
                $jobId
            )
            $terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
            $retryCount = 1
            $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
            while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 30) {
                Start-Sleep -s 60
                $retryCount++
                $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
            }
            return $jobDetails.Status
        }

        Write-Output "Starting Webhook Validation..."
        $webhookParamsForCloud = @{"Environment" = $using:Environment; "AccountName" = $using:AccountName; "ResourceGroupName" = $using:ResourceGroupName }
        $job = Start-AzAutomationRunbook -Name "Test-Webhook" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $webhookParamsForCloud

        $jobStatus = Wait-JobReachTerminalState -jobId $job.JobId

        Write-Output "Webhook Validation for cloud jobs $jobStatus"

        $webhookParamsForHybrid = @{"Environment" = $using:Environment; "AccountName" = $using:AccountName; "ResourceGroupName" = $using:ResourceGroupName; "WorkerGroup" = $using:workerGroupName }
        $job = Start-AzAutomationRunbook -Name "Test-Webhook" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $webhookParamsForHybrid 
        
        $jobStatus = Wait-JobReachTerminalState -jobId $job.JobId
        
        Write-Output "Webhook Validation for hybrid jobs $jobStatus"
    }

    function Start-Schedule {
        Write-Output "Starting JobSchedule Validation..."

        function Wait-JobReachTerminalState {
            param (
                $jobId
            )
            $terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
            $retryCount = 1
            $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
            while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 30) {
                Start-Sleep -s 60
                $retryCount++
                $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
            }
            return $jobDetails.Status
        }

        $scheduleParamsForCloud = @{"Environment" = $using:Environment; "AccountName" = $using:AccountName; "ResourceGroupName" = $using:ResourceGroupName; "UriStart" = $using:UriStart }
        $job = Start-AzAutomationRunbook -Name "Test-Schedule" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $scheduleParamsForCloud 

        $jobStatus = Wait-JobReachTerminalState -jobId $job.JobId
        Write-Output "JobSchedule Validation for Cloud jobs $jobStatus"

        $scheduleParamsForHybrid = @{"Environment" = $using:Environment; "AccountName" = $using:AccountName; "ResourceGroupName" = $using:ResourceGroupName; "WorkerGroup" = $using:workerGroupName; "UriStart" = $using:UriStart }
        $job = Start-AzAutomationRunbook -Name "Test-Schedule" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $scheduleParamsForHybrid 

        
        $jobStatus = Wait-JobReachTerminalState -jobId $job.JobId
        Write-Output "JobSchedule Validation for Hybrid jobs $jobStatus"
    }


    function Start-AssetVerificationJob {
        Param(
            [Parameter(Mandatory = $false)]
            [string] $runOn = ""
        )


        $job = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:AssetVerificationRunbookPSName  -ResourceGroupName $using:ResourceGroupName -Parameters $using:assetVerificationRunbookParams -RunOn $runOn

        $jobId = $job.JobId
        $terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
        $retryCount = 1
        $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
        while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 30) {
            Start-Sleep -s 60
            $retryCount++
            $jobDetails = Get-AzAutomationJob -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Id $jobId
        }
        return $jobDetails.Status
    }

    function Start-CMK {
        param (
            $ScenarioStatus
        )

        Write-Output "Starting CMK Validation.."

        #Enable CMK 
        $creationParams = @{"Environment" = $using:Environment; "ResourceGroupName" = $using:ResourceGroupName; "AccountName" = $using:AccountName }
        $jobOutput = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name "Test-CMK" -Parameters $creationParams -ResourceGroupName $using:ResourceGroupName -MaxWaitSeconds 1800 -Wait

        if ($jobOutput -eq "Enabled CMK") {
            if ($ScenarioStatus["AssetCreation"] -ne "Completed") {
                Write-Output "Asset Verification after enabling CMK Skipped because Assets Cretion didn't Succeed"
                return
            }

            $jobStatus = Start-AssetVerificationJob
            Write-Output "AssetVerification after enabling CMK on Cloud $jobStatus"

            $jobStatus = Start-AssetVerificationJob -runOn $workerGroupName
            Write-Output "AssetVerification after enabling CMK on Hybrid $jobStatus"
        }
        else {
            Write-Error "Enabling CMK Failed"
        }

    
        #Disable CMK 
        $creationParams = @{"Environment" = $using:Environment; "ResourceGroupName" = $using:ResourceGroupName; "AccountName" = $using:AccountName; "IsEnableCMK" = $false }
        $jobOutput = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name "Test-CMK" -Parameters $creationParams -ResourceGroupName $using:ResourceGroupName -MaxWaitSeconds 1800 -Wait

        if ($jobOutput -eq "Disabled CMK") {
            if ($ScenarioStatus["AssetCreation"] -ne "Completed") {
                Write-Output "Asset Verification after disabling CMK Skipped because Assets Cretion didn't Succeed"
                return
            }

            $jobStatus = Start-AssetVerificationJob
            Write-Output "AssetVerification after disabling CMK on Cloud $jobStatus"

            $jobStatus = Start-AssetVerificationJob -runOn $workerGroupName
            Write-Output "AssetVerification after disabling CMK on Hybrid $jobStatus"
        }
        else {
            Write-Error "Disable CMK Failed"
        }
    }

    Connect-To-AzAccount
    Checkpoint-Workflow

    Start-AccountSpecificRunbook
    Checkpoint-Workflow

    Start-RunbookSpecificOperations
    Checkpoint-Workflow

    Start-AssetCreation
    Checkpoint-Workflow

    Start-HybridWorkerGroupCreation
    Checkpoint-Workflow

    Start-CloudAndHybridJobsValidation
    Checkpoint-Workflow

    Start-DSCSpecificRunbook
    Checkpoint-Workflow

    Start-SourceControl
    Checkpoint-Workflow

    Start-Webhook
    Checkpoint-Workflow

    Start-Schedule
    Checkpoint-Workflow

    Start-CMK
    Checkpoint-Workflow
}