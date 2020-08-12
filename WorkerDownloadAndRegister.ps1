Param(
    [Parameter(Mandatory = $true)]
    [string] $Environment = "AzureCloud" , # "AzureCloud", "AzureUSGovernment", "AzureChinaCloud"
    [Parameter(Mandatory = $true)]
    [string] $workspaceId ,
    [Parameter(Mandatory = $true)]
    [string] $workspaceKey ,
    [Parameter(Mandatory = $false)]
    [string] $agentServiceEndpoint,
    [Parameter(Mandatory = $false)]
    [string] $aaToken,
    [Parameter(Mandatory = $false)]
    [string] $workerGroupName = "Test-Auto-Created-Worker"   
)


$User = "TestDscVMUser"
$Password = ConvertTo-SecureString "SecurePassword12345" -AsPlainText -Force
$VMCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password
New-AzVm `
    -ResourceGroupName "krmanupa-int" `
    -Name "TestVM123" `
    -Location "West Europe" `
    -VirtualNetworkName "TestDscVnet123" `
    -SubnetName "TestDscSubnet123" `
    -SecurityGroupName "TestDscNetworkSecurityGroup123" `
    -PublicIpAddressName "TestDscPublicIpAddress123" `
    -Credential $VMCredential

# To install and register hybrid worker on the new VM

$workspaceId = "8f3681a5-f0f2-4af7-96a6-f5cd159c88bc"
$workspaceKey = "xYIVe5fDyi4Eu9PGEggcORXeW2K9XJ2LkaWTldIayKMUEN6fs6JTl1aNlWub9Tqk78KLPHLJe7b5erMckjHUdA=="
$workerFolder = "C:\Program Files\Microsoft Monitoring Agent\Agent\AzureAutomation\7.3.837.0\HybridRegistration"
$agentServiceEndpoint = "https://edbaa296-824a-4683-95c7-026f4cbfae97.agentsvc.jpe.azure-automation.net/accounts/edbaa296-824a-4683-95c7-026f4cbfae97"
$aaToken = "nd98PpX/rkW4JnScDPzJdxI8CzTiArDGcRklM9rn3PqPCEXShUbnot+Fg/YfzKOz6MDPo1KvADQSukVymP56NQ=="


#Create path for the MMA agent download
$directoryPathForMMADownload="C:\temp"
if(!(Test-Path -path $directoryPathForLog))  
{  
     New-Item -ItemType directory -Path $directoryPathForMMADownload
     Write-Host "Folder path has been created successfully at: " $directoryPathForMMADownload    
}
else 
{ 
    Write-Host "The given folder path $directoryPathForMMADownload already exists"; 
}

$outputPath = $directoryPathForMMADownload + "\MMA.exe"
# need to update the MMA Agent exe link
Invoke-WebRequest "https://go.microsoft.com/fwlink/?LinkId=828603" -Out $outputPath

$changeDirectoryToMMALocation = 'cd ' + $directoryPathForMMADownload + ' '
iex $changeDirectoryToMMALocation

$commandToInstallMMAAgent = ".\MMA.exe /c /t:c:\windows\temp\oms"
iex $commandToInstallMMAAgent

Start-Sleep -s 60

$tmpFolderOfMMA = "cd c:\windows\temp\oms"
iex $tmpFolderOfMMA

$cloudType = 0
if($Environment -eq "AzureUSGovernment"){
   $cloudType = 1
}

$commandToConnectoToLAWorkspace = '.\setup.exe /qn NOAPM=1 ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_AZURE_CLOUD_TYPE=' + $cloudType + ' OPINSIGHTS_WORKSPACE_ID="'+ $workspaceId +'" OPINSIGHTS_WORKSPACE_KEY="'+ $workspaceKey+'" AcceptEndUserLicenseAgreement=1'
iex $commandToConnectoToLAWorkspace

Start-Sleep -Seconds 60*10

$azureAutomationDirectory = "cd '+ $workerFolder +'"
iex $azureAutomationDirectory

Import-Module .\HybridRegistration.psd1
Add-HybridRunbookWorker -GroupName test-autocreate -EndPoint $agentServiceEndpoint -Token $aaToken