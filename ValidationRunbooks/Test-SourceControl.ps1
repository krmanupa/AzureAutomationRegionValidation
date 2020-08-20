Param(
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud", # "AzureCloud", "AzureUSGovernment", "AzureChinaCloud"
    [Parameter(Mandatory = $true)]
    [string] $AccountName , # <region> + "-RunnerAutomationAccount"
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName
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
        -Environment "AzureCloud"
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





function TestSourceControlForGitRepo {
    $githubRepoName = "vinkumarGithub"
    $githubAccessToken = "48d726ce238b58ae39c28312e96d3bb1cf6210f3"
    $githubAccessTokenStr = ConvertTo-SecureString -String $githubAccessToken -AsPlainText -Force
    # Create the Source Control
    New-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                           -AutomationAccountName $AccountName `
                                           -Name  $githubRepoName `
                                           -RepoUrl "https://github.com/Vinkumar-ms/AzureAutomation.git" `
                                           -SourceType "Github" `
                                           -Branch "master" `
                                           -FolderPath "/AzureAutomation/Runbooks/PowershellScripts" `
                                           -AccessToken $githubAccessTokenStr `
                                           -EnableAutoSync
    Start-Sleep -s 60                     
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $githubRepoName 
    
    if($gitSourceControl.FolderPath -like "/AzureAutomation/Runbooks/PowershellScripts"){
        Write-Output "GitHub Repo - Source Control Creation Successful"
    }
    else{
        Write-Error "GitHub Repo - Source Control Creation Failed"
    }

    # Update the source control
    Update-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                      -AutomationAccountName $AccountName `
                                      -Name $githubRepoName `
                                      -PublishRunbook $false
    
    Start-Sleep -s 60
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $githubRepoName 
    
    if($gitSourceControl.PublishRunbook -eq $false){
        Write-Output "GitHub Repo - Source Control Update Successful"
    }
    else{
        Write-Error "GitHub Repo - Source Control Update Failed"
    }   
    
    # Delete the source control
    Remove-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                              -AutomationAccountName $AccountName `
                                              -Name $githubRepoName `
    
    Start-Sleep -s 60
    try {
        $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $githubRepoName
    }
    catch {
        if($_.Exception.Message -contains "'$githubRepoName' does not exist"){
            Write-Output "GitHub Repo - Deleted SourceControl successfully."
        }
        else{
            Write-Error $_.Exception.Message
        }
    }
}


function TestSourceControlForVsoGitUrlType1 {
    $vsoGitName_Type1 = "vinkumarRepoVsoGitPowershellAllAccessToken"
    $allaccesstoken2 = "lxvaiexxou7hr5o4x76cy7dz7t3s3jjgctia32p4ster5ot2swhq"
    $allaccessToken2Str = ConvertTo-SecureString -String $allaccesstoken2 -AsPlainText -Force

    New-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
    -AutomationAccountName $AccountName `
    -Name  $vsoGitName_Type1 `
    -RepoUrl "https://dev.azure.com/vinkumar0563/_git/VinKumar-AzureAutomation" `
    -SourceType "VsoGit" `
    -Branch "master" `
    -FolderPath "/Runbooks/PowershellScripts" `
    -AccessToken $allaccessToken2Str `
    -EnableAutoSync 

    Start-Sleep -s 60                     
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type1 
    
    if($gitSourceControl.FolderPath -like "/Runbooks/PowershellScripts"){
        Write-Output "VSO Git Type1 - Source Control Creation Successful"
    }
    else{
        Write-Error "VSO Git Type1 - Source Control Creation Failed"
    }

    # Update the source control
    Update-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                      -AutomationAccountName $AccountName `
                                      -Name $vsoGitName_Type1 `
                                      -PublishRunbook $false
    
    Start-Sleep -s 60
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type1 
    
    if($gitSourceControl.PublishRunbook -eq $false){
        Write-Output "VSO Git Type1 - Source Control Update Successful"
    }
    else{
        Write-Error "VSO Git Type1 - Source Control Update Failed"
    }   
    
    # Delete the source control
    Remove-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                              -AutomationAccountName $AccountName `
                                              -Name $vsoGitName_Type1   
    
    Start-Sleep -s 60
    try {
        $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type1
    }
    catch {
        if($_.Exception.Message -contains "'$vsoGitName_Type1' does not exist"){
            Write-Output "VSO Git Type1 - Deleted SourceControl successfully."
        }
        else{
            Write-Error $_.Exception.Message
        }
    }

}

function TestSourceControlForVsoGitUrlType2 {
    $vsoGitName_Type2 = "vinkumarRepoVsoGitPowershellDocPermOmair"
    $omairdoctoken = "hmd4vrqg7ylqtqco4pe5ya6oxpylaczvzsu3o3b43e5vrfk5rbva"
    $omairdocaccessTokenStr = ConvertTo-SecureString -String $omairdoctoken -AsPlainText -Force
    
    New-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
    -AutomationAccountName $AccountName `
    -Name  $vsoGitName_Type2 `
    -RepoUrl "https://omabdull.visualstudio.com/_git/testProject" `
    -SourceType "VsoGit" `
    -Branch "master" `
    -FolderPath "/" `
    -AccessToken $omairdocaccessTokenStr `
    -EnableAutoSync

    
    Start-Sleep -s 60                     
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type2 
    
    if($gitSourceControl.FolderPath -like "/"){
        Write-Output "VSO Git Type2 - Source Control Creation Successful"
    }
    else{
        Write-Error "VSO Git Type2 - Source Control Creation Failed"
    }

    # Update the source control
    Update-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                      -AutomationAccountName $AccountName `
                                      -Name $vsoGitName_Type2 `
                                      -PublishRunbook $false
    
    Start-Sleep -s 60
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type2 
    
    if($gitSourceControl.PublishRunbook -eq $false){
        Write-Output "VSO Git Type2 - Source Control Update Successful"
    }
    else{
        Write-Error "VSO Git Type2 - Source Control Update Failed"
    }   
    
    # Delete the source control
    Remove-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                              -AutomationAccountName $AccountName `
                                              -Name $vsoGitName_Type2   
    
    Start-Sleep -s 60
    try {
        $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type2
    }
    catch {
        if($_.Exception.Message -contains "'$vsoGitName_Type2' does not exist"){
            Write-Output "VSO Git Type2 - Deleted SourceControl successfully."
        }
        else{
            Write-Error $_.Exception.Message
        }
    }

}

function TestSourceControlForVsoGitUrlType3 {
    $vsoGitName_Type3 = "vinkumarRepoVsoGitPowershellRepo2"
    $allaccesstoken2 = "lxvaiexxou7hr5o4x76cy7dz7t3s3jjgctia32p4ster5ot2swhq"
    $allaccessToken2Str = ConvertTo-SecureString -String $allaccesstoken2 -AsPlainText -Force
    
    New-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
    -AutomationAccountName $AccountName `
    -Name  $vsoGitName_Type3 `
    -RepoUrl "https://dev.azure.com/vinkumar0563/VinKumar-AzureAutomation/_git/TestRepo2" `
    -SourceType "VsoGit" `
    -Branch "master" `
    -FolderPath "/PSScripts" `
    -AccessToken $allaccessToken2Str `
    -EnableAutoSync

    
    Start-Sleep -s 60                     
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type3 
    
    if($gitSourceControl.FolderPath -like "/PSScripts"){
        Write-Output "VSO Git Type3 - Source Control Creation Successful"
    }
    else{
        Write-Error "VSO Git Type3 - Source Control Creation Failed"
    }

    # Update the source control
    Update-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                      -AutomationAccountName $AccountName `
                                      -Name $vsoGitName_Type3 `
                                      -PublishRunbook $false
    
    Start-Sleep -s 60
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type3 
    
    if($gitSourceControl.PublishRunbook -eq $false){
        Write-Output "VSO Git Type3 - Source Control Update Successful"
    }
    else{
        Write-Error "VSO Git Type3 - Source Control Update Failed"
    }   
    
    # Delete the source control
    Remove-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                              -AutomationAccountName $AccountName `
                                              -Name $vsoGitName_Type3   
    
    Start-Sleep -s 60
    try {
        $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type3
    }
    catch {
        if($_.Exception.Message -contains "'$vsoGitName_Type3' does not exist"){
            Write-Output "VSO Git Type3 - Deleted SourceControl successfully."
        }
        else{
            Write-Error $_.Exception.Message
        }
    }

}
function TestSourceControlVsoGitRepo {
    TestSourceControlForVsoGitUrlType1
    TestSourceControlForVsoGitUrlType2
    TestSourceControlForVsoGitUrlType3
}

TestSourceControlForGitRepo




