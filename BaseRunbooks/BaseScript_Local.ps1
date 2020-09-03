# This will create the Automation Account in the region specified and imports all the required modules and runbooks to that account.
# Runs that runbook on the new account.
# Pre-Requsites : 
Param(
    [Parameter(Mandatory = $false)]
    [string] $location = "Japan East",  
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud",
    [Parameter(Mandatory = $false)]
    [string] $SubId = "cd45f23b-b832-4fa4-a434-1bf7e6f14a5a"
)

if($Environment -eq "USNat" -and $location -eq "USNat East"){
    Add-AzEnvironment -Name USNat -ServiceManagementUrl 'https://management.core.eaglex.ic.gov/' -ActiveDirectoryAuthority 'https://login.microsoftonline.eaglex.ic.gov/' -ActiveDirectoryServiceEndpointResourceId 'https://management.azure.eaglex.ic.gov/' -ResourceManagerEndpoint 'https://usnateast.management.azure.eaglex.ic.gov' -GraphUrl 'https://graph.cloudapi.eaglex.ic.gov' -GraphEndpointResourceId 'https://graph.cloudapi.eaglex.ic.gov/' -AdTenant 'Common' -AzureKeyVaultDnsSuffix 'vault.cloudapi.eaglex.ic.gov' -AzureKeyVaultServiceEndpointResourceId 'https://vault.cloudapi.eaglex.ic.gov' -EnableAdfsAuthentication 'False'
    }
    
# Connect-AzAccount -Environment $Environment
function CreateResourceGroupToWorkOn {
    param (
        $resourceGroupName
    )
    #HardCoded ResourceGroups
    New-AzResourceGroup -Name $resourceGroupName -Location $location | Out-Null
    return $resourceGroupToWorkOn
}

function CreateResourceGroupToMoveAccsTo {
    param (
        $resourceGroupName
    )
    New-AzResourceGroup -Name $resourceGroupName -Location $location | Out-Null
    return $resourceGroupToMoveAccs
}

function CreateAutomationAccount {
    param (
        $accName,
        $resourceGroupName
    )
    #HardCoded Account
    New-AzAutomationAccount -Name $accName -Location $location -ResourceGroupName $resourceGroupName | Out-Null
    return $automationAccountName
}

function ImportRequiredModules {
    param (
        $accName,
        $resourceGroupName,
        $orderedModuleUris
    )
    Write-Output $orderedModuleUris
    $orderedModuleUris.Keys | % {
        $moduleName = $_
        
        Write-Output "uploading $moduleName"
        Write-Output "Value name " $orderedModuleUris.$moduleName

        New-AzAutomationModule -AutomationAccountName $accName -ResourceGroupName $resourceGroupName -Name $moduleName -ContentLinkUri $orderedModuleUris.$moduleName
        Start-Sleep -s 100
    }
}

function AddVMExtensionScriptsToStorageAccount {
    param(
        $resourceGroupName,
        $storageAccName,
        $automationAccountName
    )

    $ctx=(Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccName).Context 
    ## Creates an file share  
    $containerName = "workerregisterscriptscontainer"
    New-AzStorageContainer -Name $containerName -Context $ctx -Permission Container 

    Start-Sleep -s 60

    $vmExtensionsPath = "..\VMExtensionScripts"
    Get-ChildItem $vmExtensionsPath | 
    ForEach-Object{
        Write-Output "Uploading " + $_.Name
        if($_.Name -eq "AutoRegisterLinuxHW.py" -or $_.Name -eq "WorkerDownloadAndRegister.ps1"){
            Set-AzStorageBlobContent -Container $containerName -Context $ctx -File $_.FullName
        }
    }

    #CreateAutomationVariables
    Get-AzStorageBlob -Container $containerName -Context $ctx |
    ForEach-Object{
        $absoluteUri = $_.ICloudBlob.Uri.AbsoluteUri
        [string] $extensionUri = $absoluteUri
        New-AzAutomationVariable -Name $_.Name.split('.')[0] -Value $extensionUri -Encrypted $False -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName | Out-Null
    } 
}

function ImportRunbooksGivenTheFolder {
    param (
        $accName,
        $resourceGroupName,
        $folderPath,
        $isPSWFRbFolder = $false
    )

    if($isPSWFRbFolder -eq $true){
        Get-ChildItem $folderPath -Filter *.ps1 |
        Foreach-Object{
            $fileNameWithExtension = $_.Name
            $fileName =  $fileNameWithExtension.Split('.')[0]
            $fullPath = "$folderPath\$fileNameWithExtension"
            Import-AzAutomationRunbook -Name $fileName -Path $fullPath  -ResourceGroupName $resourceGroupName -AutomationAccountName $accName -Type PowerShellWorkflow -Published
        }
    }

    else{
        Write-Output "$folderPath"
        Get-ChildItem $folderPath -Filter *.ps1 |
        Foreach-Object{
            $fileNameWithExtension = $_.Name
            $fileName =  $fileNameWithExtension.Split('.')[0]
            $fullPath = "$folderPath\$fileNameWithExtension"
            Import-AzAutomationRunbook -Name $fileName -Path $fullPath  -ResourceGroupName $resourceGroupName -AutomationAccountName $accName -Type PowerShell -Published
        }

        Get-ChildItem $folderPath -Filter *.py |
        Foreach-Object{
            $fileNameWithExtension = $_.Name
            $fileName =  $fileNameWithExtension.Split('.')[0]
            $fullPath = "$folderPath\$fileNameWithExtension"
            Import-AzAutomationRunbook -Name $fileName -Path $fullPath  -ResourceGroupName $resourceGroupName -AutomationAccountName $accName -Type Python2 -Published
        }
    }
}

function ImportRequiredRunbooks {
    param (
        $accName,
        $resourceGroupName
    )

    ImportRunbooksGivenTheFolder -accName $accName -resourceGroupName $resourceGroupName -folderPath "..\UtilityRunbooks"
    ImportRunbooksGivenTheFolder -accName $accName -resourceGroupName $resourceGroupName -folderPath "..\ValidationRunbooks"
    ImportRunbooksGivenTheFolder -accName $accName -resourceGroupName $resourceGroupName -folderPath "..\UtilityRunbooks\powershellWFRunbooks" -isPSWFRbFolder $true
    ImportRunbooksGivenTheFolder -accName $accName -resourceGroupName $resourceGroupName -folderPath "..\ValidationRunbooks\powershellWorkflowScripts" -isPSWFRbFolder $true
    ImportRunbooksGivenTheFolder -accName $accName -resourceGroupName $resourceGroupName -folderPath "..\BaseRunbooks"
}

function CreateStorageAccount {
    param (
        $storageAccName,
        $resourceGroupName,
        $automationAccountName,
        $location
    )

    New-AzStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccName -Location $location -SkuName Standard_GRS
    Start-Sleep -s 120
    #Create File Share
    $ctx=(Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccName).Context  
    ## Creates an file share  
    $fileShareName = "testfileshare"
    New-AzStorageShare -Context $ctx -Name $fileShareName 

    # Start-Sleep -s 120
    $ctx=(Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccName).Context 
    $sasToken = New-AzStorageAccountSASToken -Context $ctx -Service Blob,File,Table,Queue -ResourceType Service,Container,Object -Permission "racwdlup"
    Write-Output "SAS Token : $sasToken"

    #upload the files to the fileshare
    $fileShareName = "testfileshare"
    
    $folderPath = "..\Modules"
    Get-ChildItem $folderPath -Filter *.zip |
    Foreach-Object{
        Write-Output "Uploading  " + $_.Name
        Set-AzStorageFileContent -ShareName $fileShareName -Context $ctx -Source $_.FullName -Force
    }
    Start-Sleep -s 30
    
    $orderedUris =  New-Object 'system.collections.generic.dictionary[string,string]'
    $orderOfModules = "az.accounts", "az.resources", "az.compute", "az.automation", "az.operationalinsights"
    Write-Output "$orderOfModules"
    Foreach ($module in $orderOfModules) {
        Get-AzStorageFile -ShareName $fileShareName -Context $ctx | 
        Foreach-Object {
            if($_.Name.StartsWith($module)){
                Write-Output $_.Name
                $absoluteUri = $_.CloudFile.Uri.AbsoluteUri
                $uriWithSAS = $absoluteUri+$sasToken
                Write-Output "URI WITH SAS : $uriWithSAS" 
                $orderedUris.Add($module, $uriWithSAS)
            }
        }
    }
    return $orderedUris
}

Select-AzSubscription -SubscriptionId $SubId

# $guid_val = [guid]::NewGuid()
# $guid = $guid_val.ToString()

# $resourceGroupToWorkOn = "region_autovalidate_" + $guid.SubString(0,4)
# CreateResourceGroupToWorkOn -resourceGroupName $resourceGroupToWorkOn
# Write-Output "Resource Group - 1 : $resourceGroupToWorkOn"


# $resourceGroupToMoveAccs = "region_autovalidate_moveto_" + $guid.SubString(0,4)
# CreateResourceGroupToMoveAccsTo -resourceGroupName $resourceGroupToMoveAccs
# Write-Output "Resource Group - 2 : $resourceGroupToMoveAccs"

# $automationAccountName = "region-test-aa" + $guid.SubString(0,4) 
# CreateAutomationAccount -accName $automationAccountName -resourceGroupName $resourceGroupToWorkOn
# Write-Output "Automation Account : $automationAccountName"

# $resourceGroupToWorkOn = "NewRegionRG"
# $automationAccountName = "NewRegionTesting"
#ImportRequiredRunbooks -accName $automationAccountName -resourceGroupName $resourceGroupToWorkOn

$resourceGroupToWorkOn = "anthos"
$automationAccountName = "gosdk1"
$orderedModuleUris = CreateStorageAccount -storageAccName "teststoragesakrma" -resourceGroupName $resourceGroupToWorkOn -automationAccountName $automationAccountName -location $location 

ImportRequiredModules -accName $automationAccountName -resourceGroupName $resourceGroupToWorkOn -orderedModuleUris $orderedModuleUris
AddVMExtensionScriptsToStorageAccount -resourceGroupName $resourceGroupToWorkOn -storageAccName "teststoragesa1" -automationAccountName $automationAccountName