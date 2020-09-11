
## Create cert .cer and .pfx files
## Modify the cert, app and connection name

$SubscriptionId = "cd45f23b-b832-4fa4-a434-1bf7e6f14a5a"
Select-AzSubscription -SubscriptionId $SubscriptionId
$AutomationAccountName = "region-test-aa4894"
$ResourceGroupName = "region_autovalidate_4894"

$cer = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$cer.Import("C:\RegionAutoValidation\AzureAutomationRegionValidation\BaseRunbooks\cert.cer")
$binCert = $cer.GetRawCertData()
$credValue = [System.Convert]::ToBase64String($binCert)
$Application = New-AzADApplication -DisplayName "test-localrunas" -HomePage "http://www.microsoft.com" -IdentifierUris ("http://" + "test-localrunas")
New-AzADAppCredential -ApplicationId $Application.ApplicationId -CertValue $credValue -StartDate $cer.NotBefore -EndDate $cer.NotAfter
 
New-AzADServicePrincipal -ApplicationId $Application.ApplicationId 

# Sleep here for a few seconds to allow the service principal application to become active (should only take a couple of seconds normally)
Start-Sleep -s 15

$NewRole = $null
$Retries = 0;
While ($NewRole -eq $null -and $Retries -le 6) {
    New-AzRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId -scope ("/subscriptions/" + $subscriptionId) -ErrorAction SilentlyContinue
    Start-Sleep -s 10
    $NewRole = Get-AzRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
    $Retries++;
}


$Password = ConvertTo-SecureString -String "kranthi123" -AsPlainText -Force
New-AzAutomationCertificate -AutomationAccountName $AutomationAccountName -Name "TestAzureRunAsCertificate" -Path "C:\RegionAutoValidation\AzureAutomationRegionValidation\BaseRunbooks\test.pfx" -Password $Password -ResourceGroupName $ResourceGroupName


# Populate the ConnectionFieldValues
$ConnectionTypeName = "AzureServicePrincipal"
$ConnectionAssetName = "TestAzureRunAsConnection"
$ApplicationId = $Application.ApplicationId 
$SubscriptionInfo = Get-AzSubscription -SubscriptionId $SubscriptionId 
$TenantID = $SubscriptionInfo | Select-Object TenantId -First 1
$Thumbprint = $cer.Thumbprint
$ConnectionFieldValues = @{"ApplicationId" = $ApplicationID; "TenantId" = $TenantID.TenantId; "CertificateThumbprint" = $Thumbprint; "SubscriptionId" = $SubscriptionId } 
# Create a Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.
   
Write-Output "Creating Connection in the Asset..."
New-AzAutomationConnection -ResourceGroupName $ResourceGroupName -automationAccountName $AutomationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues 
