workflow BaseScript_remote{
    Param(
    [Parameter(Mandatory = $false)]
    [string] $location = "West Central US",  
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud", 
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "krmanupa-test-auto",
    [Parameter(Mandatory = $false)]
    [string] $AccountName = "krmanupa-base-aa",
    [Parameter (Mandatory= $false)]
    [string] $NewResourceGroupName = "TestRG",
    [Parameter (Mandatory=$false)]
    [string] $guid
    )

if($guid -eq ""){
    $guid_val = [guid]::NewGuid()
    $guid = $guid_val.ToString()
}

$vmName = "Test-VM-" + $guid.SubString(0,4) 
$workerGroupName = "test-auto-create"


$assetVerificationRunbookParams = @{"guid" = $guid}
$CreateHWGRunbookName = "CreateHWG"
$StartCloudHybridJobsRunbookName = "Test-JobSpecific"

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

function Start-AccountSpecificRunbook {

    Write-Output "Starting Account Specific Validation...."

    $accountParams =  @{"location"= $using:location ;"Environment" = $using:Environment;"ResourceGroupName"=$using:ResourceGroupName;"NewResourceGroupName" = $using:NewResourceGroupName}

    Start-AzAutomationRunbook -Name "Test-AutomationAccount-Creation" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $accountParams -MaxWaitSeconds 600 -Wait 

    Write-Output "Account Specific Validation Completed"
}

function Start-RunbookSpecificOperations {
    
    Write-Output "Starting Runbook Specific Validations..."

    $runbookParams =  @{"location"= $using:location ;"Environment" = $using:Environment;"AccountName"=$using:AccountName;"ResourceGroupName"=$using:ResourceGroupName}

    Start-AzAutomationRunbook -Name "Test-Runbooks-Creation" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $runbookParams -MaxWaitSeconds 600 -Wait 

    Write-Output "Runbook Specific Validation Completed"
}

function Start-AssetCreation {
    Write-Output "Starting Asset Creation ..."
    
    $automationAssetsCreationsParams =  @{"guid" = $using:guid;"ResourceGroupName"=$using:ResourceGroupName; "AccountName"= $using:AccountName;"Environment" = $using:Environment }
    
    Start-AzAutomationRunbook -Name "Test-AutomationAssets-Creation" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $automationAssetsCreationsParams -MaxWaitSeconds 2400 -Wait

    Write-Output "Asset Creation Completed"
}

function Start-HybridWorkerGroupCreation {
    Write-Output "Starting Hybrid Worker Group Creation...."
    
    $hwgCreationParams = @{"location" = $using:location; "Environment" = $using:Environment; "ResourceGroupName" = $using:ResourceGroupName; "AccountName" = $using:AccountName;"WorkerType" = "Windows"; "vmName" = $using:vmName; "WorkerGroupName" = $using:workerGroupName}

    Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Name $using:CreateHWGRunbookName -Parameters $hwgCreationParams -MaxWaitSeconds 1800 -Wait

    Write-Output "Hybrid Worker Group Creation Completed"
}

function Start-CloudAndHybridJobsValidation {
    Write-Output "Starting Cloud and Hybrid Jobs Validation..."
    
    $startCloudHybridJobsParams = @{"Environment"=$using:Environment;"ResourceGroupName" = $using:ResourceGroupName; "AccountName" = $using:AccountName; "workerGroupName" = $using:workerGroupName; "guid"=$using:guid}

    Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Name $using:StartCloudHybridJobsRunbookName -Parameters $startCloudHybridJobsParams -MaxWaitSeconds 1800 -Wait

    Write-Output "Cloud and Hybrid Jobs Validation Completed"
}

function Start-DSCSpecificRunbook {
    Write-Output "Starting DSC Validation..."

    $dscParams = @{"location"=$using:location; "Environment"=$using:Environment;"AccountDscName" = $using:AccountName; "ResourceGroupName"=$using:ResourceGroupName}
    Start-AzAutomationRunbook -Name "Test-dsc" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $dscParams -MaxWaitSeconds 1800 -Wait

    Write-Output "DSC Validation Completed"
}


function Start-SourceControl {
    Write-Output "Starting SourceControl Validation...."
    
    $sourceControlParams = @{"Environment"=$using:Environment;"AccountName"=$using:AccountName; "ResourceGroupName"=$using:ResourceGroupName}
    Start-AzAutomationRunbook -Name "Test-SourceControl" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $sourceControlParams -MaxWaitSeconds 1800 -Wait

    Write-Output "SourceControl Validation Completed"
}

function Start-Webhook {
    Write-Output "Starting Webhook Validation..."
    $webhookParamsForCloud = @{"Environment"=$using:Environment;"AccountName"=$using:AccountName; "ResourceGroupName"=$using:ResourceGroupName}
    Start-AzAutomationRunbook -Name "Test-Webhook" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $webhookParamsForCloud -MaxWaitSeconds 1800 -Wait

    $webhookParamsForHybrid = @{"Environment"=$using:Environment;"AccountName"=$using:AccountName; "ResourceGroupName"=$using:ResourceGroupName; "WorkerGroup" = $using:workerGroupName}
    Start-AzAutomationRunbook -Name "Test-Webhook" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $webhookParamsForHybrid -MaxWaitSeconds 1800 -Wait
    Write-Output "Webhook Validation Completed"
}

function Start-Schedule {
    Write-Output "Starting JobSchedule Validation..."

    $scheduleParamsForCloud = @{"Environment"=$using:Environment;"AccountName"=$using:AccountName; "ResourceGroupName"=$using:ResourceGroupName}
    Start-AzAutomationRunbook -Name "Test-Schedule" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $scheduleParamsForCloud -MaxWaitSeconds 1800 -Wait

    $scheduleParamsForHybrid = @{"Environment"=$using:Environment;"AccountName"=$using:AccountName; "ResourceGroupName"=$using:ResourceGroupName; "WorkerGroup" = $using:workerGroupName}
    Start-AzAutomationRunbook -Name "Test-Schedule" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $scheduleParamsForHybrid -MaxWaitSeconds 1800 -Wait

    Write-Output "JobSchedule Validation Completed"
}


function Start-AssetVerificationJob {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $runOn = ""
    )
    Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:AssetVerificationRunbookPSName  -ResourceGroupName $using:ResourceGroupName -Parameters $using:assetVerificationRunbookParams -RunOn $runOn  -MaxWaitSeconds 1200 -Wait
}

function Start-CMK {

    Write-Output "Starting CMK Validation.."

    #Enable CMK 
    $creationParams = @{"Environment" = $using:Environment;"ResourceGroupName"=$using:ResourceGroupName; "AccountName"= $using:AccountName}
    $jobOutput = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name "Test-CMK" -Parameters $creationParams -ResourceGroupName $using:ResourceGroupName -MaxWaitSeconds 1800 -Wait

    if($jobOutput -eq "Enabled CMK"){
        Start-AssetVerificationJob
        Start-AssetVerificationJob -runOn $workerGroupName
    }

    
    #Disable CMK 
    $creationParams = @{"Environment" = $using:Environment;"ResourceGroupName"=$using:ResourceGroupName; "AccountName"= $using:AccountName; "IsEnableCMK" = $false}
    $jobOutput = Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name "Test-CMK" -Parameters $creationParams -ResourceGroupName $using:ResourceGroupName -MaxWaitSeconds 1800 -Wait

    if($jobOutput -eq "Disabled CMK"){
        Start-AssetVerificationJob
        Start-AssetVerificationJob -runOn $workerGroupName
    }
    
    Write-Output "CMK Validation Completed"
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