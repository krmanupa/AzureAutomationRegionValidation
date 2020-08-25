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
        [String] $WorkerType = "Windows",
        [Parameter(Mandatory=$true)]
        [String] $vmName,
        [Parameter(Mandatory=$true)]
        [String] $WorkerGroupName
        )
 
$guid_val = [guid]::NewGuid()
$guid = $guid_val.ToString()

$ErrorActionPreference = "Stop"

# Connect using RunAs account connection
$connectionName = "AzureRunAsConnection"
$agentEndpoint = ""
$aaPrimaryKey = ""
$workspaceId = ""
$workspacePrimaryKey = ""

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


#Get-Automation Account
Write-Verbose "Getting Automation Account....."

# Write-Verbose "Create account" -verbose
try {
    $Account = Get-AzAutomationAccount -Name $AccountName -ResourceGroupName $ResourceGroupName 
    if($Account.AutomationAccountName -like $AccountName) {
        Write-Verbose "Account retrieved successfully"
        $accRegInfo = Get-AzAutomationRegistrationInfo -ResourceGroup $ResourceGroupName -AutomationAccountName  $AccountName
        $agentEndpoint = $accRegInfo.Endpoint
        $aaPrimaryKey = $accRegInfo.PrimaryKey

        Write-Verbose "AgentService endpoint: $agentEndpoint  Primary key : $aaPrimaryKey"
    } 
    else{
        Write-Error "Account retrieval failed"
    }
}
catch {
    Write-Error "Account retrieval failed"
}


### Create an LA workspace
Write-Verbose "Creating LA Workspace...."
$workspace_guid = [guid]::NewGuid()
$WorkspaceName = $WorkspaceName + $workspace_guid.ToString()

# Create a new Log Analytics workspace if needed
try {
    Write-Verbose "Creating new workspace named $WorkspaceName in region $Location..."
    $Workspace = New-AzOperationalInsightsWorkspace -Location $Location -Name $WorkspaceName -Sku Standard -ResourceGroupName $ResourceGroupName
    Write-Verbose $workspace
    Start-Sleep -s 60

    Write-Verbose "Enabling Automation for the created workspace...."
    Set-AzOperationalInsightsIntelligencePack -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -IntelligencePackName "AzureAutomation" -Enabled $true

    $workspaceDetails = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName
    $workspaceId = $workspaceDetails.CustomerId

    $workspaceSharedKey = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $ResourceGroupName -Name $WorkspaceName
    $workspacePrimaryKey = $workspaceSharedKey.PrimarySharedKey

    Write-Verbose "Workspace Details to be used to register machine are WorkspaceId : $workspaceId and WorkspaceKey : $workspacePrimaryKey"
} 
catch {
    Write-Error "Error creating LA workspace"
}


if($WorkerType -eq "Windows"){
    #Create a VM
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
    }

    #Run the VM Extension to register the Hybrid worker
    ## Run AZ VM Extension to download and Install MMA Agent
    $commandToExecute = "powershell .\WorkerDownloadAndRegister.ps1 -workspaceId $workspaceId -workspaceKey $workspacePrimaryKey -workerGroupName $WorkerGroupName -agentServiceEndpoint $agentEndpoint -aaToken $aaPrimaryKey"

    $settings = @{"fileUris" =  @("https://raw.githubusercontent.com/krmanupa/AutoRegisterHW/master/VMExtensionScripts/WorkerDownloadAndRegister.ps1"); "commandToExecute" = $commandToExecute};
    $protectedSettings = @{"storageAccountName" = ""; "storageAccountKey" = ""};

    # Run Az VM Extension to download and register worker.
    Write-Verbose "Running Az VM Extension...."
    Write-Verbose "Command executing ... $commandToExecute"
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
    }
}