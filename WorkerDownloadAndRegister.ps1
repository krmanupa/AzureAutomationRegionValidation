Param(
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


#Create path for the MMA agent download
$directoryPathForMMADownload="C:\temp"
if(!(Test-Path -path $directoryPathForMMADownload))  
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
#Invoke-WebRequest "https://go.microsoft.com/fwlink/?LinkId=828603" -Out $outputPath

$changeDirectoryToMMALocation = "cd  $directoryPathForMMADownload"
iex $changeDirectoryToMMALocation

$commandToInstallMMAAgent = ".\MMA.exe /c /t:c:\windows\temp\oms"
#iex $commandToInstallMMAAgent

Start-Sleep -s 60

$tmpFolderOfMMA = "cd c:\windows\temp\oms"
iex $tmpFolderOfMMA

$cloudType = 0
if($Environment -eq "AzureUSGovernment"){
   $cloudType = 1
}

$commandToConnectoToLAWorkspace = '.\setup.exe /qn NOAPM=1 ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_AZURE_CLOUD_TYPE=' + $cloudType + ' OPINSIGHTS_WORKSPACE_ID="'+ $workspaceId +'" OPINSIGHTS_WORKSPACE_KEY="'+ $workspaceKey+'" AcceptEndUserLicenseAgreement=1'
Write-Output $commandToConnectoToLAWorkspace
iex $commandToConnectoToLAWorkspace

Start-Sleep -Seconds 600

# wait until the MMA Agent downloads AzureAutomation on to the machine
$workerFolder = "C:\\Program Files\\Microsoft Monitoring Agent\\Agent\\AzureAutomation\\7.3.837.0\\HybridRegistration"
$i = 0
$azureAutomationPresent = $false
while($i -le 5)
{
    $i++
    if(!(Test-Path -path $workerFolder))  
    {  
        Start-Sleep -s 300
        Write-Host "Folder path is not present waiting..:  $workerFolder"    
    }
    else 
    { 
        $azureAutomationPresent = $true
        Write-Host "The given folder path $workerFolder already exists"
        break
    }
    Write-Verbose 'Timedout waiting for Automation folder.'
}

if($azureAutomationPresent){
    
    $azureAutomationDirectory = "cd $workerFolder"
    iex $azureAutomationDirectory

    Import-Module .\HybridRegistration.psd1
    Add-HybridRunbookWorker -GroupName $workerGroupName -EndPoint $agentServiceEndpoint -Token $aaToken
}
