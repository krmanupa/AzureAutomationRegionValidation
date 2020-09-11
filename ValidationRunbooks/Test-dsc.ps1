Param(
    [Parameter(Mandatory = $false)]
    [string] $location = "Switzerland North",  # "West Central US", "USGov Arizona"
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud", # "AzureCloud", "AzureUSGovernment", "AzureChinaCloud"
    [Parameter(Mandatory = $false)]
    [string] $UriStart = "https://management.azure.com/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a",  # "https://management.azure.com/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a", "https://management.usgovcloudapi.net/subscriptions/a1d148ea-c45e-45f7-acc5-b7bcc10813af"
    [Parameter(Mandatory = $false)]
    [string] $AccountDscName = "region-test-aadd34" , # <region> + "-RunnerAutomationAccount"
    [Parameter(Mandatory = $false)]
    [string] $VMDscName = "TestDSCVM" , # <region> + "-TestDscVM"
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "region_autovalidate_dd34"
)

$ErrorActionPreference = "Continue"

if($Environment -eq "USNat"){
    Add-AzEnvironment -Name USNat -ServiceManagementUrl 'https://management.core.eaglex.ic.gov/' -ActiveDirectoryAuthority 'https://login.microsoftonline.eaglex.ic.gov/' -ActiveDirectoryServiceEndpointResourceId 'https://management.azure.eaglex.ic.gov/' -ResourceManagerEndpoint 'https://usnateast.management.azure.eaglex.ic.gov' -GraphUrl 'https://graph.cloudapi.eaglex.ic.gov' -GraphEndpointResourceId 'https://graph.cloudapi.eaglex.ic.gov/' -AdTenant 'Common' -AzureKeyVaultDnsSuffix 'vault.cloudapi.eaglex.ic.gov' -AzureKeyVaultServiceEndpointResourceId 'https://vault.cloudapi.eaglex.ic.gov' -EnableAdfsAuthentication 'False'
}
# Connect using RunAs account connection
$connectionName = "AzureRunAsConnection"
try
{
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName      
    Write-Output  "Logging in to Azure..." -verbose
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

Write-Output  "Create VM" -verbose
$User = "TestDscVMUser"
$Password = ConvertTo-SecureString "SecurePassword12345" -AsPlainText -Force
$VMCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password

$guid_val = [guid]::NewGuid()
$guid = $guid_val.ToString()
$testVirtualNwName = "TestDscVnet"+ $guid.SubString(0,4)
$testSubnetName = "TestDscSubnet"+$guid.SubString(0,4)
$testSgName = "TestDscNetworkSecurityGroup"+$guid.SubString(0,4)
$testPublicIpName = "TestDscPublicIpAddress"+$guid.SubString(0,4)
$VMDscName = "TestDSCVM"+$guid.SubString(0,4)
New-AzVm `
    -ResourceGroupName $ResourceGroupName `
    -Name $VMDscName `
    -Location "West Central US" `
    -VirtualNetworkName  $testVirtualNwName `
    -SubnetName  $testSubnetName `
    -SecurityGroupName  $testSgName `
    -PublicIpAddressName  $testPublicIpName `
    -Credential $VMCredential | Out-Null

    Write-Output  "Get auth token" -verbose
    $currentAzureContext = Get-AzContext
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    $Token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)

    $configName = "SetupServer"+ $guid.SubString(0,4)
    Write-Output " ConfigName is $configName"
    Write-Output  "Create configuration" -verbose
    try{
        $Headers = @{}
        $Headers.Add("Authorization","bearer "+ " " + "$($Token.AccessToken)")
        $contentType3 = "application/json"
        $body = @"
                {
  "properties": {
    "source": {
      "hash": {
        "algorithm": "sha256",
        "value": "A9E5DB56BA21513F61E0B3868816FDC6D4DF5131F5617D7FF0D769674BD5072F"
      },
      "type": "embeddedContent",
      "value": "Configuration $configName {\r\n    Node localhost {\r\n                               WindowsFeature IIS {\r\n                               Name = \"Web-Server\";\r\n            Ensure = \"Present\"\r\n        }\r\n    }\r\n}"
    },
    "description": "sample configuration"
  },
  "name": "$configName",
  "location": "$location"
}
"@
    $body1 = $body | ConvertFrom-Json
    $body1.location = $location
    $bodyDsc = $body1 | ConvertTo-Json -Depth 5
    $PutUri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountDscName/configurations/"+$configName+"?api-version=2015-10-31"
    
    Write-Output "Body - $body"
    Invoke-RestMethod -Uri $PutUri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyDsc
    }
    catch{
        Write-Error -Message $_.Exception
    }

Write-Output  "Compile configuration" -verbose
Start-AzAutomationDscCompilationJob -ConfigurationName $configName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName | Out-Null
($CompilationJobs = Get-AzAutomationDscCompilationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName) | Out-Null
$compilationJob = $CompilationJobs[0].Id 

Write-Output "Compilation Job Id : $compilationJob"
$jobDetails = Get-AzAutomationJob -AutomationAccountName $AccountDscName -ResourceGroupName $ResourceGroupName -Id $compilationJob
$terminalStates = @("Completed", "Failed", "Stopped", "Suspended")
$retryCount = 1
while ($terminalStates -notcontains $jobDetails.Status -and $retryCount -le 20) {
    Start-Sleep -s 30
    $retryCount++
    $jobDetails = Get-AzAutomationJob -AutomationAccountName $AccountDscName -ResourceGroupName $ResourceGroupName -Id $compilationJob
}

if($jobDetails.Status -eq "Completed"){
    Write-Output  "Register DSC node" -verbose
    Register-AzAutomationDscNode -AutomationAccountName $AccountDscName -AzureVMName $VMDscName -ResourceGroupName $ResourceGroupName -NodeConfigurationName "$configName.localhost" -AzureVMLocation "West Central US"
    ($Node = Get-AzAutomationDscNode -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName -ConfigurationName "$configName.localhost")  | Out-Null
    if($Node.Name -like $VMDscName) {
        Write-Output  "Node registered successfully"
    } 
    else{
        Write-Error "DSC Validation :: Node registration failed"
    }

    Start-Sleep -Seconds 100

    Write-Output  "Get node report" -verbose
    Write-Output "Node ID :  "$Node.Id
    $nodeId = $Node.Id
    $nodeId = [System.guid]::New($nodeId)
    ($NodeReport = Get-AzAutomationDscNodeReport -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName -NodeId $nodeId -Latest) | Out-Null
    if($NodeReport.Status -like "Compliant") {
        Write-Output  "Node status compliant"
    } 
    else{
        Write-Error "DSC Validation :: Node not in compliant state"
    }
}

Write-Output  "Unregister node" -verbose
Unregister-AzAutomationDscNode -AutomationAccountName $AccountDscName -ResourceGroupName $ResourceGroupName -Id $nodeId  -Force | Out-Null

Write-Output  "Delete VM" -verbose
Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VMDscName -Force | Out-Null

Write-Output  "Remove node configuration" -verbose
Remove-AzAutomationDscNodeConfiguration -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName -Name "$configName.localhost" -Force | Out-Null

Write-Output  "Remove configuration" -verbose
Remove-AzAutomationDscConfiguration -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName -Name "$configName" -Force | Out-Null

Write-Output "DSC Validation :: DSC Scenarios Validation Completed"


