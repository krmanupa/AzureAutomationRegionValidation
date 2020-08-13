workflow E2EHWTest
{
### All variables needed
Param(
[Parameter(Mandatory = $true)]
[string] $location ,  
[Parameter(Mandatory = $true)]
[string] $Environment , 
[Parameter(Mandatory = $false)]
[string] $ResourceGroupName = "krmanupa-test-auto",
[Parameter(Mandatory = $false)]
[string] $AccountName = "Test-Account",
[Parameter(Mandatory = $false)]
[string] $WorkspaceName = "Test-LAWorkspace"
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

$vmName = "Test-VM-1234" 
$workspaceId = ""
$workspacePrimaryKey = ""
$agentEndpoint = ""
$aaPrimaryKey = ""

parallel {

    sequence {
        ### Create an automation account
        Write-Output "Creating Automation Account....."
        $guid = [guid]::NewGuid()
        $AccountName = $AccountName + $guid.ToString()
        
        # Write-Verbose "Create account" -verbose
        try {
            $Account = New-AzAutomationAccount -Name $AccountName -Location $location -ResourceGroupName $ResourceGroupName -Plan "Free"
            if($Account.AutomationAccountName -like $AccountName) {
                Write-Output "Account created successfully"
                $accRegInfo = Get-AzAutomationRegistrationInfo -ResourceGroup $ResourceGroupName -AutomationAccountName  $AccountName
                $WORKFLOW:agentEndpoint = $accRegInfo.Endpoint
                $WORKFLOW:aaPrimaryKey = $accRegInfo.PrimaryKey

                Write-Output "AgentService endpoint: $agentEndpoint  Primary key : $aaPrimaryKey"
            } 
            else{
                Write-Error "Account creation failed"
            }
        }
        catch {
            Write-Error "Account creation failed"
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
        $User = "TestVMUser"
        $Password = ConvertTo-SecureString "SecurePassword12345" -AsPlainText -Force
        $VMCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password
        New-AzVm `
            -ResourceGroupName $ResourceGroupName `
            -Name $vmName `
            -Location $location `
            -VirtualNetworkName "TestVnet123" `
            -SubnetName "TestSubnet123" `
            -SecurityGroupName "TestNetworkSecurityGroup123" `
            -PublicIpAddressName "TestPublicIpAddress123" `
            -Credential $VMCredential
        }
        catch{
            Write-Error "Error creating VM"
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
}


## Run AZ VM Extension to download and Install MMA Agent
$workerGroupName = 'test-auto-create'
$commandToExecute = "powershell .\WorkerDownloadAndRegister.ps1 -workspaceId $WORKFLOW:workspaceId -workspaceKey $WORKFLOW:workspacePrimaryKey -workerGroupName $workerGroupName -agentServiceEndpoint $WORKFLOW:agentEndpoint -aaToken $WORKFLOW:aaPrimaryKey"

$settings = @{"fileUris" =  @("https://raw.githubusercontent.com/krmanupa/AutoRegisterHW/master/WorkerDownloadAndRegister.ps1"); "commandToExecute" = $commandToExecute};
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
