Param(
    [Parameter(Mandatory = $false)]
    [string] $location = "West Central US",  # "West Central US", "USGov Arizona"
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud", # "AzureCloud", "AzureUSGovernment", "AzureChinaCloud"
    [Parameter(Mandatory = $false)]
    [string] $UriStart = "https://management.azure.com/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a",  # "https://management.azure.com/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a", "https://management.usgovcloudapi.net/subscriptions/a1d148ea-c45e-45f7-acc5-b7bcc10813af"
    [Parameter(Mandatory = $true)]
    [string] $AccountDscName , # <region> + "-RunnerAutomationAccount"
    [Parameter(Mandatory = $false)]
    [string] $VMDscName = "TestDSCVM" , # <region> + "-TestDscVM"
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "RunnerRG"
)
$ErrorActionPreference = "Stop"
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
New-AzVm `
    -ResourceGroupName $ResourceGroupName `
    -Name $VMDscName `
    -Location $location `
    -VirtualNetworkName "TestDscVnet123" `
    -SubnetName "TestDscSubnet123" `
    -SecurityGroupName "TestDscNetworkSecurityGroup123" `
    -PublicIpAddressName "TestDscPublicIpAddress123" `
    -Credential $VMCredential | Out-Null

    Write-Output  "Get auth token" -verbose
    $currentAzureContext = Get-AzContext
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    $Token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)

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
      "value": "Configuration SetupServer {\r\n    Node localhost {\r\n                               WindowsFeature IIS {\r\n                               Name = \"Web-Server\";\r\n            Ensure = \"Present\"\r\n        }\r\n    }\r\n}"
    },
    "description": "sample configuration"
  },
  "name": "SetupServer",
  "location": "West Central US"
}
"@
    $body1 = $body | ConvertFrom-Json
    $body1.location = $location
    $bodyDsc = $body1 | ConvertTo-Json -Depth 5
    $PutUri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountDscName/configurations/SetupServer?api-version=2015-10-31"
    Invoke-RestMethod -Uri $PutUri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyDsc
    }
    catch{
        Write-Error -Message $_.Exception
    }

Write-Output  "Compile configuration" -verbose
Start-AzAutomationDscCompilationJob -ConfigurationName "SetupServer" -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName | Out-Null
($CompilationJobs = Get-AzAutomationDscCompilationJob -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName) | Out-Null
$JobStream = $CompilationJobs[0] | Get-AzAutomationDscCompilationJobOutput -Stream "Any"

Start-Sleep -Seconds 100

Write-Output  "Register DSC node" -verbose
Register-AzAutomationDscNode -AutomationAccountName $AccountDscName -AzureVMName $VMDscName -ResourceGroupName $ResourceGroupName -NodeConfigurationName "SetupServer.localhost" | Out-Null
($Node = Get-AzAutomationDscNode -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName -ConfigurationName "SetupServer.localhost")  | Out-Null
if($Node.Name -like $VMDscName) {
    Write-Output  "Node registered successfully"
} 
else{
    Write-Error "DSC Validation :: Node registration failed"
}

Start-Sleep -Seconds 100

Write-Output  "Get node report" -verbose
($NodeReport = Get-AzAutomationDscNodeReport -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName -NodeId $Node.Id -Latest) | Out-Null
$NodeReport.Status -like "Compliant"
if($NodeReport.Status -like "Compliant") {
    Write-Output  "Node status compliant"
} 
else{
    Write-Error "DSC Validation :: Node not in compliant state"
}

Write-Output  "Unregister node" -verbose
Unregister-AzAutomationDscNode -AutomationAccountName $AccountDscName -ResourceGroupName $ResourceGroupName -Id $Node.Id -Force | Out-Null

Write-Output  "Delete VM" -verbose
Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VMDscName -Force | Out-Null

Write-Output  "Remove node configuration" -verbose
Remove-AzAutomationDscNodeConfiguration -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName -Name "SetupServer.localhost" -Force | Out-Null

Write-Output  "Remove configuration" -verbose
Remove-AzAutomationDscConfiguration -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountDscName -Name "SetupServer" -Force | Out-Null


Write-Output "DSC Validation :: DSC Scenarios Validation Completed"


