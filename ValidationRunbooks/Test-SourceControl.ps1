Param(
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud", # "AzureCloud", "AzureUSGovernment", "AzureChinaCloud"
    [Parameter(Mandatory = $true)]
    [string] $AccountName , # <region> + "-RunnerAutomationAccount"
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName
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
    Write-Verbose "Logging in to Azure..." -verbose
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

function CheckSyncJob {
    param (
        $repoName,
        $runbookNameOnTheGit
    )
    Write-Output "Starting Sync job on $repoName"
    ($syncJob = Start-AzAutomationSourceControlSyncJob -ResourceGroupName $ResourceGroupName `
                                                    -AutomationAccountName $AccountName `
                                                    -Name $repoName ) | Out-Null

    $jobId = $syncJob.SourceControlSyncJobId
    Write-Output "Sync JobId : $jobId"
    Start-Sleep -Seconds 300

   ( $runbookInTheAA = Get-AzAutomationRunbook -Name $runbookNameOnTheGit -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName) | Out-Null

    if($runbookInTheAA.Name -eq $runbookNameOnTheGit){
        Write-Output "Sync job succeeded on $repoName"
    }
    else{
        Write-Error "Sync job failed on $repoName"
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
                                      -PublishRunbook $false | Out-Null
    
    Start-Sleep -s 60
    ($gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $repoName ) | Out-Null
    
    if($gitSourceControl.PublishRunbook -eq $false){
        Write-Output "$repoName - Source Control Update Successful"
    }
    else{
        Write-Error "$repoName - Source Control Update Failed"
    }
}

function VerifyDeleteSC {
    param (
        $scName
    )
    # Delete the source control
    Remove-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName `
                                    -AutomationAccountName $AccountName `
                                    -Name $scName   | Out-Null

    Start-Sleep -s 60
    ($sourceControlsInTheAcc = Get-AzAutomationSourceControl -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName) | Out-Null
    foreach ($sc in $sourceControlsInTheAcc) {
        if($sc.Name -eq $gitSourceControl){
            Write-Error "$scName - Delete failed"
            return
        }
    }
    Write-Output "$scName - Delete Successful"
}

function TestSourceControlForGitRepo {
    $githubRepoName = "krmanupaGitHub"
    $githubAccessToken = "6d608f5a5ed54ebd75277a7d3260faca79a27485"
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
                                           -EnableAutoSync | Out-Null
    Start-Sleep -s 60                     
    ($gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $githubRepoName ) | Out-Null
    
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
    VerifyDeleteSC -scName $githubRepoName
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
    -EnableAutoSync | Out-Null

    Start-Sleep -s 60                     
    ($gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type1 ) | Out-Null
    
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
    
    #Delete the source control
    VerifyDeleteSC -scName $vsoGitName_Type1
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
    -EnableAutoSync | Out-Null

    
    Start-Sleep -s 60                     
    ($gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type2 ) | Out-Null
    
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
    VerifyDeleteSC -scName $vsoGitName_Type2
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
    -EnableAutoSync | Out-Null

    
    Start-Sleep -s 60                     
    ($gitSourceControl = Get-AzAutomationSourceControl   -ResourceGroupName $ResourceGroupName `
                                                        -AutomationAccountName $AccountName `
                                                        -Name $vsoGitName_Type3 ) | Out-Null
    
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
    VerifyDeleteSC -scName $vsoGitName_Type3
}
function TestSourceControlVsoGitRepo {
    TestSourceControlForVsoGitUrlType1
    TestSourceControlForVsoGitUrlType2
    TestSourceControlForVsoGitUrlType3
}

TestSourceControlForGitRepo
Write-Output "GitHub Repo Type SC Validation Completed"

TestSourceControlVsoGitRepo
Write-Output "VSOGit Repo Type SC Validation Completed"

Write-Output "Source Control Verified"



