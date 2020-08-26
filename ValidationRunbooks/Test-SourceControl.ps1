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
    Write-Output "Logging in to Azure..." -verbose
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

function CheckSyncJob {
    param (
        $repoName,
        $runbookNameOnTheGit
    )
    Write-Output "Starting Sync job on $repoName"
    $syncJob = Start-AzAutomationSourceControlSyncJob -ResourceGroupName $ResourceGroupName `
                                                    -AutomationAccountName $AccountName `
                                                    -Name $repoName

    $jobId = $syncJob.JobId
    Write-Output "Sync JobId : $jobId"
    Start-Sleep -Seconds 300

    $runbookInTheAA = Get-AzAutomationRunbook -Name $runbookNameOnTheGit -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    if($runbookInTheAA.Name -eq $runbookNameOnTheGit){
        Write-Output "Sync job succeeded"
    }
    else{
        Write-Error "Sync job failed"
    }
}

function VerifyUpdateOfSC {
    param (
        $repoName
    )
    # Update the source control
    Update-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                      -AutomationAccountName $AccountName `
                                      -Name $repoName `
                                      -PublishRunbook $false
    
    Start-Sleep -s 60
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $repoName 
    
    if($gitSourceControl.PublishRunbook -eq $false){
        Write-Output "GitHub Repo - Source Control Update Successful"
    }
    else{
        Write-Error "GitHub Repo - Source Control Update Failed"
    }
}

function TestSourceControlForGitRepo {
    $githubRepoName = "krmanupaGitHub"
    $githubAccessToken = "8664c0eea4fe6b1801c77d653325ac10e8b2b458"
    $githubAccessTokenStr = ConvertTo-SecureString -String $githubAccessToken -AsPlainText -Force
    # Create the Source Control
    New-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                           -AutomationAccountName $AccountName `
                                           -Name  $githubRepoName `
                                           -RepoUrl "https://github.com/krmanupa/SourceControlValidation.git" `
                                           -SourceType "Github" `
                                           -Branch "master" `
                                           -FolderPath "/" `
                                           -AccessToken $githubAccessTokenStr `
                                           -EnableAutoSync
    Start-Sleep -s 60                     
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $githubRepoName 
    
    if($gitSourceControl.FolderPath -like "/"){
        Write-Output "GitHub Repo - Source Control Creation Successful"
    }
    else{
        Write-Error "GitHub Repo - Source Control Creation Failed"
    }

    # Check the sync job
    $runbookOnTheGit = "TestRunbook"
    CheckSyncJob -repoName $githubRepoName -runbookNameOnTheGit $runbookOnTheGit

    # Update the source control
    VerifyUpdateOfSC -repoName $githubRepoName   
    
    # Delete the source control
    Remove-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                              -AutomationAccountName $AccountName `
                                              -Name $githubRepoName `
    
    Start-Sleep -s 60
    $gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $githubRepoName
    
    if($null -eq $gitSourceControl){
        Write-Output "GitHub Repo - Deleted SourceControl successfully."
    }
    else{
        Write-Error "GitHub Repo - Delete SourceControl failed."
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

    # Check the sync job
    $runbookNameOnTheVSOGit = "SimpleHelloScriptRepo1"
    CheckSyncJob -repoName $vsoGitName_Type1 -runbookNameOnTheGit $runbookNameOnTheVSOGit

    # Update the source control
    VerifyUpdateOfSC -repoName $vsoGitName_Type1  
    
    # Delete the source control
    Remove-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                              -AutomationAccountName $AccountName `
                                              -Name $vsoGitName_Type1   
    
    Start-Sleep -s 60
    if($null -eq $gitSourceControl){
        Write-Output "VsoGit-1 Repo - Deleted SourceControl successfully."
    }
    else{
        Write-Error "VsoGit-1 Repo - Delete SourceControl failed."
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

    # check the sync job 
    $runbookNameOnTheVsoGit_type2 = "VSOTestProjectRunbook"
    CheckSyncJob -repoName $vsoGitName_Type2 -runbookNameOnTheGit $runbookNameOnTheVsoGit_type2

    # Update the source control
    VerifyUpdateOfSC -repoName $vsoGitName_Type2   
    
    # Delete the source control
    Remove-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                              -AutomationAccountName $AccountName `
                                              -Name $vsoGitName_Type2   
    
    Start-Sleep -s 60
    if($null -eq $gitSourceControl){
        Write-Output "VsoGit-2 Repo - Deleted SourceControl successfully."
    }
    else{
        Write-Error "VsoGit-2 Repo - Delete SourceControl failed."
    }=
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

    # Check the sync 
    $runbookNameOnTheVsoGit_Type3 = "SimpleHelloScriptRepo2"
    CheckSyncJob -repoName $vsoGitName_Type3 -runbookNameOnTheGit $runbookNameOnTheVsoGit_Type3

    # Update the source control
    VerifyUpdateOfSC -repoName $vsoGitName_Type3   
    
    # Delete the source control
    Remove-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                              -AutomationAccountName $AccountName `
                                              -Name $vsoGitName_Type3   
    
    Start-Sleep -s 60
    if($null -eq $gitSourceControl){
        Write-Output "VsoGit-3 Repo - Deleted SourceControl successfully."
    }
    else{
        Write-Error "VsoGit-3 Repo - Delete SourceControl failed."
    }
}
function TestSourceControlVsoGitRepo {
    TestSourceControlForVsoGitUrlType1
    TestSourceControlForVsoGitUrlType2
    TestSourceControlForVsoGitUrlType3
}

TestSourceControlForGitRepo
TestSourceControlVsoGitRepo

Write-Output "Source Control Verified"



