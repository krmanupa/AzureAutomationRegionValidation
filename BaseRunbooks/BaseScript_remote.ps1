workflow BaseScript_remote{
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
    [string] $WorkspaceName = "Test-LAWorkspace",
    [Parameter(Mandatory = $false)]
    [string] $RunbookPSName = "ps-job-test",
    [Parameter(Mandatory = $false)]
    [string] $RunbookPSWFName = "psWF-job-test",
    [Parameter(Mandatory = $false)]
    [string] $RunbookPython2Name = "py2-job-test",
    [Parameter(Mandatory=$false)]
    [string]$AssetVerificationRunbookPSName = "AssetVerificationRunbook",
    [Parameter (Mandatory= $true)]
    [string] $NewResourceGroupName
    )

$guid_val = [guid]::NewGuid()
$guid = $guid_val.ToString()

$vmName = "Test-VM-" + $guid.SubString(0,4) 
$workerGroupName = "test-auto-create"


$assetVerificationRunbookParams = @{"guid" = $guid}
$CreateHWGRunbookName = "CreateHWG"
$StartCloudHybridJobsRunbookName = "Test-JoSpecific"

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

function Start-JobSpecificRunbook{
    Param(
    # ResourceGroup Name
    [Parameter(Mandatory = $true)]
    [string] $resourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $accName
    )
    Start-AzAutomationRunbook -Name "Test-JobSpecific" -ResourceGroupName $resourceGroupName -AutomationAccountName $accName
}

function Start-AccountSpecificRunbook {
    $accountParams =  @{"location"= $using:location ;"Environment" = $using:Environment;"ResourceGroupName"=$using:ResourceGroupName; "AccountName"= $using:AccountName;"NewResourceGroupName" = $using:NewResourceGroupName; }

    Start-AzAutomationRunbook -Name "Test-AutomationAccount-Creation" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $accountParams -MaxWaitSeconds 600 -Wait
}

function Start-AssetCreation {
    $automationAssetsCreationsParams =  @{"guid" = $using:guid;"ResourceGroupName"=$using:ResourceGroupName; "AccountName"= $using:AccountName;"Environment" = $using:Environment; }
    
    Start-AzAutomationRunbook -Name "Test-AutomationAssets-Creation" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $automationAssetsCreationsParams -MaxWaitSeconds 600 -Wait
}

function Start-HybridWorkerGroupCreation {
    $hwgCreationParams = @{"location" = $using:location; "Environment" = $using:Environment; "ResourceGroupName" = $using:ResourceGroupName; "AccountName" = $using:AccountName;"WorkerType" = "Windows"; "vmName" = $using:vmName; "WorkerGroupName" = $using:workerGroupName}

    Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Name $using:CreateHWGRunbookName -Parameters $hwgCreationParams -MaxWaitSeconds 1800 -Wait
}

function Start-CloudAndHybridJobsValidation {
    $startCloudHybridJobsParams = @{"ResourceGroupName" = $using:ResourceGroupName; "AccountName" = $using:AccountName; "workerGroupName" = $using:workerGroupName; "guid"=$using:guid}

    Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -ResourceGroupName $using:ResourceGroupName -Name $using:StartCloudHybridJobsRunbookName -Parameters $startCloudHybridJobsParams -MaxWaitSeconds 1800 -Wait
}

function Start-DSCSpecificRunbook {
    $dscParams = @{"AccountDscName" = $using:AccountName; "ResourceGroupName"=$using:ResourceGroupName}
    Start-AzAutomationRunbook -Name "Test-dsc" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $dscParams -MaxWaitSeconds 1800 -Wait
}


function Start-SourceControl {
    $sourceControlParams = @{"AccountName"=$using:AccountName; "ResourceGroupName"=$using:ResourceGroupName}
    Start-AzAutomationRunbook -Name "Test-SourceControl" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $sourceControlParams -MaxWaitSeconds 1800 -Wait
}

function Start-Webhook {
    $webhookParamsForCloud = @{"AccountName"=$using:AccountName; "ResourceGroupName"=$using:ResourceGroupName}
    Start-AzAutomationRunbook -Name "Test-Webhook" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $webhookParamsForCloud -MaxWaitSeconds 1800 -Wait

    $webhookParamsForHybrid = @{"AccountName"=$using:AccountName; "ResourceGroupName"=$using:ResourceGroupName; "WorkerGroup" = $using:workerGroupName}
    Start-AzAutomationRunbook -Name "Test-Webhook" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $webhookParamsForHybrid -MaxWaitSeconds 1800 -Wait
}

function Start-Schedule {
    $scheduleParamsForCloud = @{"AccountName"=$using:AccountName; "ResourceGroupName"=$using:ResourceGroupName}
    Start-AzAutomationRunbook -Name "Test-Schedule" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $scheduleParamsForCloud -MaxWaitSeconds 1800 -Wait

    $scheduleParamsForHybrid = @{"AccountName"=$using:AccountName; "ResourceGroupName"=$using:ResourceGroupName; "WorkerGroup" = $using:workerGroupName}
    Start-AzAutomationRunbook -Name "Test-Schedule" -ResourceGroupName $using:ResourceGroupName -AutomationAccountName $using:AccountName -Parameters $scheduleParamsForHybrid -MaxWaitSeconds 1800 -Wait
}


function Start-AssetVerificationJob {
    Param(
        [Parameter(Mandatory = $false)]
        [string] $runOn = ""
    )
    Start-AzAutomationRunbook -AutomationAccountName $using:AccountName -Name $using:AssetVerificationRunbookPSName  -ResourceGroupName $using:ResourceGroupName -Parameters $using:assetVerificationRunbookParams -RunOn $runOn  -MaxWaitSeconds 1200 -Wait
}

function Start-CMK {
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
}

}