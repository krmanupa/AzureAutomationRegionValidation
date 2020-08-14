Param(
    [Parameter(Mandatory = $true)]
    [string] $agentServiceEndpoint,
    [Parameter(Mandatory = $true)]
    [string] $aaToken   
)


# wait until the MMA Agent downloads AzureAutomation on to the machine
$workerFolder = "C:\\Program Files\\Microsoft Monitoring Agent\\Agent\\AzureAutomation\\7.3.837.0\\HybridRegistration"
$i = 0
$azureAutomationPresent = $false
while($i -le 5)
{
    $i++
    if(!(Test-Path -path $workerFolder))  
    {  
        Start-Sleep -s 100
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
    $azureAutomationDirectory = "cd '$workerFolder'"
    Invoke-Expression $azureAutomationDirectory

    Import-Module .\HybridRegistration.psd1
    Remove-HybridRunbookWorker -EndPoint $agentServiceEndpoint -Token $aaToken
}
