# VSTS Personal access token
$token = "hycc5zv5ksjjf346znszpciysx4hu5mijss2hy3q2o3c75o2p6pa"
$accessToken = ConvertTo-SecureString -String $token -AsPlainText -Force 

$allaccesstoken = "3juat7cksat4fv3ou7txu5k3gbgjyue4f5p4fm3gjenvxuqig32a"
$allaccessTokenStr = ConvertTo-SecureString -String $allaccesstoken -AsPlainText -Force 

$allaccesstoken2 = "lxvaiexxou7hr5o4x76cy7dz7t3s3jjgctia32p4ster5ot2swhq"
$allaccessToken2Str = ConvertTo-SecureString -String $allaccesstoken2 -AsPlainText -Force

$doctoken = "bucniccgdstqxcemhegpadskyvyr7wzie7fpwhnxophkbrgena3q"
$docaccessTokenStr = ConvertTo-SecureString -String $doctoken -AsPlainText -Force 

$omairdoctoken = "hmd4vrqg7ylqtqco4pe5ya6oxpylaczvzsu3o3b43e5vrfk5rbva"
$omairdocaccessTokenStr = ConvertTo-SecureString -String $omairdoctoken -AsPlainText -Force

$githubAccessToken = "031e1838d5a77fe32fa3ffc13b5265fecd0cf346"
$githubAccessTokenStr = ConvertTo-SecureString -String $githubAccessToken -AsPlainText -Force

$automationAccountName = "vinkumar-OaasSubLib22-EUAP-AA"
$resourceGroupName = "vinkumar-rg"

New-AzAutomationSourceControl -ResourceGroupName $resourceGroupName `
                                           -AutomationAccountName $automationAccountName `
                                           -Name  "vinkumarGithub" `
                                           -RepoUrl "https://github.com/Vinkumar-ms/AzureAutomation.git" `
                                           -SourceType "Github" `
                                           -Branch "master" `
                                           -FolderPath "/AzureAutomation/Runbooks/PowershellScripts" `
                                           -AccessToken $githubAccessTokenStr `
					                       -EnableAutoSync

New-AzAutomationSourceControl -ResourceGroupName $resourceGroupName `
                                           -AutomationAccountName $automationAccountName `
                                           -Name  "vinkumarRepoVsoGitPowershellAllAccessToken" `
                                           -RepoUrl "https://dev.azure.com/vinkumar0563/_git/VinKumar-AzureAutomation" `
                                           -SourceType "VsoGit" `
                                           -Branch "master" `
                                           -FolderPath "/Runbooks/PowershellScripts" `
                                           -AccessToken $allaccessToken2Str `
                                           -EnableAutoSync 


New-AzAutomationSourceControl -ResourceGroupName $resourceGroupName `
                                          -AutomationAccountName $automationAccountName `
                                          -Name  "vinkumarRepoVsoGitPowershellDocPermOmair" `
                                          -RepoUrl "https://omabdull.visualstudio.com/_git/testProject" `
                                          -SourceType "VsoGit" `
                                          -Branch "master" `
                                          -FolderPath "/" `
                                          -AccessToken $omairdocaccessTokenStr `
					                      -EnableAutoSync


New-AzAutomationSourceControl -ResourceGroupName $resourceGroupName `
                                           -AutomationAccountName $automationAccountName `
                                           -Name  "vinkumarRepoVsoGitPowershellRepo2" `
                                           -RepoUrl "https://dev.azure.com/vinkumar0563/VinKumar-AzureAutomation/_git/TestRepo2" `
                                           -SourceType "VsoGit" `
                                           -Branch "master" `
                                           -FolderPath "/PSScripts" `
                                           -AccessToken $allaccessToken2Str `
                                           -EnableAutoSync

