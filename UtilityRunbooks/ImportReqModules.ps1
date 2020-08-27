Param(  
[Parameter(Mandatory = $false)]
[string] $Environment = "AzureCloud", 
[Parameter(Mandatory = $false)]
[string] $resourceGroupName = "test-auto-creation",
[Parameter(Mandatory = $false)]
[string] $accName = "Test-auto-creation-aa"
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
        -Environment $Environment 
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


New-AzAutomationModule -AutomationAccountName $accName -ResourceGroupName $resourceGroupName -Name "Az.Accounts" -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/Az.Accounts/1.9.3"
Start-Sleep -s 100
New-AzAutomationModule -AutomationAccountName $accName -ResourceGroupName $resourceGroupName -Name "Az.Resources" -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/Az.Resources/2.4.0"
Start-Sleep -s 100
New-AzAutomationModule -AutomationAccountName $accName -ResourceGroupName $resourceGroupName -Name "Az.Automation" -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/Az.Automation/1.3.7"
Start-Sleep -s 100
New-AzAutomationModule -AutomationAccountName $accName -ResourceGroupName $resourceGroupName -Name "Az.Compute" -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/Az.Compute/4.2.1"
Start-Sleep -s 100
New-AzAutomationModule -AutomationAccountName $accName -ResourceGroupName $resourceGroupName -Name "Az.OperationalInsights" -ContentLinkUri "https://www.powershellgallery.com/packages/Az.OperationalInsights/2.3.0"