workflow Test-hybrid-pswf
{
### All variables needed
Param(
[Parameter(Mandatory = $true)]
[string] $location ,  
[Parameter(Mandatory = $true)]
[string] $Environment , 
[Parameter(Mandatory = $false)]
[string] $ResourceGroupName = "krmanupa-test-auto-aa",
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

        Start-Sleep -s 120
        }
        catch{
            Write-Error "Error creating VM"
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }
}

# run az vm extesion
sequence {
        
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

#create all the required automation assets for this new account
parallel {

    $ModuleName = "TestModule" + "-" + $guid

    $AzureConnectionName = "TestAzConnectionName"  + "-" + $guid
    $AzureSPConnectionName = "TestAzSPConnectionName"  + "-" + $guid
    $AzureClassicCertConnectionName = "TestAzClassicCertConnectionName"  + "-" + $guid

    $CredentialName = "TestCredential" + "-" + $guid

    $StringVariableName = "TestStringVariable" + "-" + $guid
    $IntVariableName = "TestIntVariable" + "-" + $guid
    $BoolVariableName = "TestBoolVariable" + "-" + $guid
    $DateTimeVariableName = "TestDateTimeVariable" + "-" + $guid
    $UnspecifiedVariableName = "TestUnspecifiedVariable" + "-" + $guid
    $EncryptedVariableName = "TestEncryptedVariable" + "-" + $guid


    sequence {
        Write-Verbose "Import module" -verbose
        $TestModule = New-AzAutomationModule -AutomationAccountName $AccountName -Name $ModuleName -ContentLink "http://contosostorage.blob.core.windows.net/modules/ContosoModule.zip" -ResourceGroupName $ResourceGroupName
        if($TestModule.Name -like $ModuleName) {
            Write-Output "Module creation successful"
        } 
        else{
            Write-Error "Module creation failed"
        }
    }
    
    ############ Connection ##################
    sequence {
        Write-Verbose "Create connections" -verbose

        # ConnectionTypeName=Azure
        $FieldValues = @{"AutomationCertificateName"="TestCert";"SubscriptionID"="SubId"}
        $TestAzConnection = New-AzAutomationConnection -Name $AzureConnectionName -ConnectionTypeName Azure -ConnectionFieldValues $FieldValues -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
        if($TestAzConnection.Name -eq $AzureConnectionName) {
            Write-Output "Azure connection creation successful"
        } 
        else{
            Write-Error "Azure connection creation failed"
        }
        
        # ConnectionTypeName=AzureServicePrincipal
        $FieldValues = @{"ApplicationId"="AppId"; "TenantId"="TenantId"; "CertificateThumbprint"="Thumbprint"; "SubscriptionId"="SubId"}
        $TestAzSPConnection = New-AzAutomationConnection -Name $AzureSPConnectionName -ConnectionTypeName AzureServicePrincipal -ConnectionFieldValues $FieldValues -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
        if($TestAzSPConnection.Name -like $AzureSPConnectionName) {
            Write-Output "AzureServicePrincipal connection creation successful"
        } 
        else{
            Write-Error "AzureServicePrincipal connection creation failed"
        }

        # ConnectionTypeName=AzureClassicCertificate
        $FieldValues = @{"SubscriptionName"="SubName"; "SubscriptionId"="SubId"; "CertificateAssetName"="ClassicRunAsAccountCertifcateAssetName"}
        $TestAzClassicCertConnection = New-AzAutomationConnection -Name $AzureClassicCertConnectionName -ConnectionTypeName AzureClassicCertificate -ConnectionFieldValues $FieldValues -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
        if($TestAzClassicCertConnection.Name -like $AzureClassicCertConnectionName) {
            Write-Output "AzureClassicCertificate connection creation successful"
        } 
        else{
            Write-Error "AzureClassicCertificate connection creation failed"
        }
    }
    
    ############ Credential ##################

    sequence {
        Write-Verbose "Create credential" -verbose
        $User = "Automation\TestCredential"
        $Password = ConvertTo-SecureString "SecurePassword" -AsPlainText -Force
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password
        $TestCredential = New-AzAutomationCredential -AutomationAccountName $AccountName -Name $CredentialName -Value $Credential -ResourceGroupName $ResourceGroupName
        if($TestCredential.UserName -like $User) {
            Write-Output "Credential creation successful"
        } 
        else{
            Write-Error "Credential creation failed"
        }
    }

    ############ Variable ##################

    parallel {
        Write-Verbose "Create variables" -verbose
        # string variable, unencryped 
        sequence {
            [string] $StringVariableValue = "Test String Variable"
            $TestStringVariable = New-AzAutomationVariable -Name $StringVariableName -Value $StringVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($TestStringVariable.Value -like $StringVariableValue) {
                Write-Output "String variable creation successful"
            } 
            else{
                Write-Error "String variable creation failed"
            }
        }
    
        
        # Int variable
        sequence {
            [int] $IntVariableValue = 12345
            $TestIntVariable = New-AzAutomationVariable -Name $IntVariableName -Value $IntVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($TestIntVariable.Value -eq $IntVariableValue) {
                Write-Output "Int variable creation successful"
            } 
            else{
                Write-Error "Int variable creation failed"
            }
        }

        # Bool variable
        sequence {
            [bool] $BoolVariableValue = $false
            $TestBoolVariable = New-AzAutomationVariable -Name $BoolVariableName -Value $BoolVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($TestBoolVariable.Value -eq $BoolVariableValue) {
                Write-Output "Bool variable creation successful"
            } 
            else{
                Write-Error "Bool variable creation failed"
            }
        }
    
        # DateTime variable
        sequence {
            [DateTime] $DateTimeVariableValue = [DateTime]::UtcNow | get-date -Format "yyyy-MM-ddTHH:mm:ssZ"
            $TestDateTimeVariable = New-AzAutomationVariable -Name $DateTimeVariableName -Value $DateTimeVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($TestDateTimeVariable.Value -eq $DateTimeVariableValue) {
                Write-Output "DateTime variable creation successful"
            } 
            else{
                Write-Error "DateTime variable creation failed"
            }
        }
    
        # Unspecified variable
        sequence{
            $UnspecifiedVariableValue = Get-AzAutomationAccount -Name $AccountName -ResourceGroupName $ResourceGroupName 
            $TestUnspecifiedVariable = New-AzAutomationVariable -Name $UnspecifiedVariableName -Value $UnspecifiedVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName    
            if($TestUnspecifiedVariable.Value.AutomationAccountName -like $UnspecifiedVariableValue.AutomationAccountName) {
                Write-Output "Unspecified variable creation successful"
            } 
            else{
                Write-Error "Unspecified variable creation failed"
            }
        }

        # Encrypted variable
        sequence {
            [string] $EncryptedVariableValue = "Test Encrypted String Variable"
            $TestEncryptedVariable = New-AzAutomationVariable -Name $EncryptedVariableName -Encrypted $True -Value $EncryptedVariableValue -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($TestEncryptedVariable.Encrypted -eq $True) {
                Write-Output "Encrypted variable creation successful"
            } 
            else{
                Write-Error "Encrypted variable creation failed"
            }
        }

    ############ Certificate ##################
    sequence{
     
        Write-Verbose "Get auth token" -verbose
    $currentAzureContext = Get-AzContext
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    $Token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)

    Write-Verbose "Create certificate" -verbose
    try{
        $Headers = @{}
        $Headers.Add("Authorization","bearer "+ " " + "$($Token.AccessToken)")
        $contentType3 = "application/json"
        $bodyCert = @"
                {
  "name": "testCert",
  "properties": {
    "base64Value": "MIIC5DCCAcygAwIBAgIQRHw/PpDU95xN9GYFa5vUHTANBgkqhkiG9w0BAQ0FADAuMSwwKgYDVQQDEyNHZW5ldmEgVGVzdCBTdXNiY3JpcHRpb24gTWFuYWdlbWVudDAeFw0xNTEwMDkxODA3MDNaFw0xNzEwMDgxODA3MDNaMC4xLDAqBgNVBAMTI0dlbmV2YSBUZXN0IFN1c2JjcmlwdGlvbiBNYW5hZ2VtZW50MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAjV+X9b/qeFNffLUL/TayLAA5GYoNsvLsVvBebezrdiwi/KeSD3uS0rw8X0QrMn6LWH/RxKs1S8A7UxMZjR6pse5FAZv9A3SHT2dmW5CYDQ7vKyqTB/BeOZch02GMqAkyr3KV7zl0Uj6RYq4Avx0PA2AAg73RXf7s0UtB7e7GnzgKR83/Gj/EaXas21x78IF8sDBVqT3LvvPNSTOlB2/jlwQ9pOijvVpPmvTeChfRmaU8o+oIUJJGLhFDQJkKNw7ZkwkNmY0hijovi63J+hO6ikA9cKvQh4sOiNwKWEIhzxnNmI7O2uDidV4knpV7JbuejrKJemy4rTb0VLuEPpIq0QIDAQABMA0GCSqGSIb3DQEBDQUAA4IBAQAx8ai4hl5GuwPYQMC2V+jzgyROjasvygm+bpo5pWwIr47hbHkN6r5N6Dmp1Vf8xo7uQudzUAS3YVdMakSRQNOzo9mFTKqYLmSA2NI9l2J+TlJnAIbJhqVHCRoQ0Fn2kC5mBb4unQbIVTurb75EGQTHf55LDk3GPrZwpNVsw6nHM+Gy5GL6Vz1J30ZoAaAnNzOfyrJ4J352pCx9FgH3TzD3fhvZODjDrQfankb/yHCBlYx3WyiR+3n8K01qg4L3V9Z+PeFS4pDMN+2zfuOqNCefKKKn1wMyHbXDq1/29OrqJQvueStZ8l3X39umKrhnDwriGIwlgPevuSp23alpF9BY"
  }
}
"@
        $PutUri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountName/certificates/testCert?api-version=2015-10-31"
        Invoke-RestMethod -Uri $PutUri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyCert
    }
    catch{
        Write-Error -Message $_.Exception
    }

    $Cert = Get-AzAutomationCertificate -Name "testCert" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
    if($Cert.Thumbprint -like "edfab8580e873bbc2ac188ed6d02411019b7d8d3") {
        Write-Output "Certificate asset creation successful"
    } 
    else{
        Write-Error "Certificate asset creation failed"
    }


    }
    }
}

# check cloud and hybrid jobs behavior
parallel {
    #cloud jobs verification
    # verify all the get/set of the automation assets
    parallel{
        sequence {
            Write-Output "Start hybrid jobs" 
            # Python2
            $JobHybridPy2 = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookPython2Name  -ResourceGroupName $ResourceGroupName -MaxWaitSeconds 600 -Wait
            $pythonRbJobId = $JobHybridPy2.JobId
            Start-Sleep -Seconds 600
            $JobOutput = Get-AzAutomationJobOutput -Id $pythonRbJobId -Stream "Output" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($JobOutput.Summary -like "SampleOutput") {
                Write-Output "Hybrid job for PS runbook ran successfully and output stream is visible"
            }    
            $JobError = Get-AzAutomationJobOutput -Id $pythonRbJobId -Stream "Error" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($JobError.Summary -like "SampleError") {
                Write-Output "Error stream is visible"
            }    
            $JobWarning = Get-AzAutomationJobOutput -Id $pythonRbJobId -Stream "Warning" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($JobWarning.Summary -like "SampleWarning") {
                Write-Output "Warning stream is visible"
            }
        }
        
        sequence {
            # PowerShell - Test job stream
            $JobHybridPS = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookPSName  -ResourceGroupName $ResourceGroupName
            $psRbJobId = $JobHybridPS.JobId
            Start-Sleep -Seconds 600
            $JobOutput = Get-AzAutomationJobOutput -Id $psRbJobId -Stream "Output" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($JobOutput.Summary -like "SampleOutput") {
                Write-Output "Hybrid job for PS runbook ran successfully and output stream is visible"
            }    
            $JobError = Get-AzAutomationJobOutput -Id $psRbJobId -Stream "Error" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($JobError.Summary -like "SampleError") {
                Write-Output "Error stream is visible"
            }    
            $JobWarning = Get-AzAutomationJobOutput -Id $psRbJobId -Stream "Warning" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($JobWarning.Summary -like "SampleWarning") {
                Write-Output "Warning stream is visible"
            }
        }

        sequence {
            
            # PowerShell Workflow - Test job status
            $JobHybridPSWF = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookPSWFName -ResourceGroupName $ResourceGroupName
            $pswfRbJobId = $JobHybridPSWF.JobId
            Start-Sleep -Seconds 400
            $Job1 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($Job1.Status -like "Running") {
                Write-Output "Hybrid job for PS WF runbook is running"
            }  
            elseif($Job1.Status -like "Queued") {
                Write-Warning "Hybrid job for PS WF runbook didn't start in 5 mins"
                Start-Sleep -Seconds 100
            }

            Write-Output "Suspending PSWF runbook"
            Suspend-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            Start-Sleep -Seconds 30
            $Job2 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($Job2.Status -like "Suspended") {
                Write-Output "Hybrid job for PS WF runbook is suspended"
            } 

            Write-Output "Resuming PSWF runbook"
            Resume-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            Start-Sleep -Seconds 30
            $Job3 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($Job3.Status -like "Running") {
                Write-Output "Hybrid job for PS WF runbook has resumed running"
            } 

            Write-Output "Stoppin PSWF runbook"
            Stop-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            Start-Sleep -Seconds 30
            $Job4 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($Job4.Status -like "Stopping" -or $Job4.Status -like "Stopped") {
                Write-Output "Hybrid job for PS WF runbook is stopping"
            }      
        }
    }

    #Hybrid jobs verification
    # verify all the get/set of the automation assets
    parallel {
        
        # sequence {
        #     Write-Output "Start hybrid jobs" 
        #     # Python2
        #     $JobHybridPy2 = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookPython2Name -RunOn $workerGroupName -ResourceGroupName $ResourceGroupName -MaxWaitSeconds 600 -Wait
        #     $pythonRbJobId = $JobHybridPy2.JobId
        #     Start-Sleep -Seconds 600
        #     $JobOutput = Get-AzAutomationJobOutput -Id $pythonRbJobId -Stream "Output" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
        #     if($JobOutput.Summary -like "SampleOutput") {
        #         Write-Output "Hybrid job for PS runbook ran successfully and output stream is visible"
        #     }    
        #     $JobError = Get-AzAutomationJobOutput -Id $pythonRbJobId -Stream "Error" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
        #     if($JobError.Summary -like "SampleError") {
        #         Write-Output "Error stream is visible"
        #     }    
        #     $JobWarning = Get-AzAutomationJobOutput -Id $pythonRbJobId -Stream "Warning" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
        #     if($JobWarning.Summary -like "SampleWarning") {
        #         Write-Output "Warning stream is visible"
        #     }
        # }
        
        sequence {
            # PowerShell - Test job stream
            $JobHybridPS = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookPSName -RunOn $workerGroupName -ResourceGroupName $ResourceGroupName
            $psRbJobId = $JobHybridPS.JobId
            Start-Sleep -Seconds 600
            $JobOutput = Get-AzAutomationJobOutput -Id $psRbJobId -Stream "Output" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($JobOutput.Summary -like "SampleOutput") {
                Write-Output "Hybrid job for PS runbook ran successfully and output stream is visible"
            }    
            $JobError = Get-AzAutomationJobOutput -Id $psRbJobId -Stream "Error" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($JobError.Summary -like "SampleError") {
                Write-Output "Error stream is visible"
            }    
            $JobWarning = Get-AzAutomationJobOutput -Id $psRbJobId -Stream "Warning" -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($JobWarning.Summary -like "SampleWarning") {
                Write-Output "Warning stream is visible"
            }
        }

        sequence {
            
            # PowerShell Workflow - Test job status
            $JobHybridPSWF = Start-AzAutomationRunbook -AutomationAccountName $AccountName -Name $RunbookPSWFName -RunOn $workerGroupName -ResourceGroupName $ResourceGroupName
            $pswfRbJobId = $JobHybridPSWF.JobId
            Start-Sleep -Seconds 400
            $Job1 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($Job1.Status -like "Running") {
                Write-Output "Hybrid job for PS WF runbook is running"
            }  
            elseif($Job1.Status -like "Queued") {
                Write-Warning "Hybrid job for PS WF runbook didn't start in 5 mins"
                Start-Sleep -Seconds 100
            }

            Write-Output "Suspending PSWF runbook"
            Suspend-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            Start-Sleep -Seconds 30
            $Job2 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($Job2.Status -like "Suspended") {
                Write-Output "Hybrid job for PS WF runbook is suspended"
            } 

            Write-Output "Resuming PSWF runbook"
            Resume-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            Start-Sleep -Seconds 30
            $Job3 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($Job3.Status -like "Running") {
                Write-Output "Hybrid job for PS WF runbook has resumed running"
            } 

            Write-Output "Stoppin PSWF runbook"
            Stop-AzAutomationJob  -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            Start-Sleep -Seconds 30
            $Job4 = Get-AzAutomationJob -Id $pswfRbJobId -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
            if($Job4.Status -like "Stopping" -or $Job4.Status -like "Stopped") {
                Write-Output "Hybrid job for PS WF runbook is stopping"
            }      
        }

        }
    
    }

#Delete all the resources
sequence {
    Remove-AzVm -ResourceGroupName $ResourceGroupName -Name $vmName -Force
    Remove-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -Force
    Remove-AzAutomationAccount -Name $AccountName -ResourceGroupName $ResourceGroupName -Force
}

}
