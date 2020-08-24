workflow Test-E2E{
    Param(
    [Parameter(Mandatory = $false)]
    [string] $location = "West Europe",  
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud", 
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "krmanupa-test-auto",
    [Parameter(Mandatory = $false)]
    [string] $AccountName = "krmanupa-base-aa",
    [Parameter(Mandatory = $false)]
    [string] $WorkspaceName = "Test-LAWorkspace",
    [Parameter(Mandatory = $false)]
    [string] $RunbookPSName = "ps-job-test",
    [Parameter(Mandatory = $false)]
    [string] $RunbookPSWFName = "psWF-job-test",
    [Parameter(Mandatory = $false)]
    [string] $RunbookPython2Name = "py2-job-test",
    [Parameter(Mandatory=$false)]
    [string]$AssetVerificationRunbookPSName = "AssetVerificationRunbook"
    )

function Connect-To-AzAccount{
    Param(
    [Parameter(Mandatory = $false)]
    [string] $Environment = "AzureCloud"
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
}

function Start-JobSpecificRunbook{
    Param(
    # ResourceGroup Name
    [Parameter(Mandatory = $true)]
    [string] $resourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $accName
    )
    Start-AzAutomationRunbook -Name "Test-JobSpecific" -ResourceGroupName $resourceGroupName -AutomationAccountName $accName
}

function Start-AccountSpecificRunbook {
    Param(
    # ResourceGroup Name
    [Parameter(Mandatory = $true)]
    [string] $resourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $accName
    )
    Start-AzAutomationRunbook -Name "Test-AutomationAccount-Creation" -ResourceGroupName $resourceGroupName -AutomationAccountName $accName
}

function Start-DSCSpecificRunbook {
    Param(
    # ResourceGroup Name
    [Parameter(Mandatory = $true)]
    [string] $resourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $accName
    )
    Start-AzAutomationRunbook -Name "Test-dsc" -ResourceGroupName RunnerRG -AutomationAccountName $accName
}

function Start-SourceControl {
    Param(
    # ResourceGroup Name
    [Parameter(Mandatory = $true)]
    [string] $resourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $accName
    )
    Start-AzAutomationRunbook -Name "Test-SourceControl" -ResourceGroupName RunnerRG -AutomationAccountName $accName
}

function Start-Webhook {
    Param(
    # ResourceGroup Name
    [Parameter(Mandatory = $true)]
    [string] $resourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $accName
    )
    Start-AzAutomationRunbook -Name "Test-Webhook" -ResourceGroupName RunnerRG -AutomationAccountName $accName
}

function Start-Schedule {
    Param(
    # ResourceGroup Name
    [Parameter(Mandatory = $true)]
    [string] $resourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $accName
    )
    Start-AzAutomationRunbook -Name "Test-Schedule" -ResourceGroupName RunnerRG -AutomationAccountName $accName
}

}