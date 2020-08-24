Param(
[Parameter(Mandatory = $true)]
[string] $guid,
[Parameter(Mandatory = $true)]
[string] $ResourceGroupName,
[Parameter(Mandatory = $true)]
[string] $AccountName,
[Parameter(Mandatory = $false)]
[string] $Environment="AzureCloud",
[Parameter(Mandatory = $false)]
[string] $UriStart = "https://management.azure.com/subscriptions/cd45f23b-b832-4fa4-a434-1bf7e6f14a5a"
)
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
#create all the required automation assets for this new account
$ModuleName = "TestModule" + "-" + $guid

$AzureConnectionName = "TestAzConnectionName"  + "-" + $guid
$AzureSPConnectionName = "TestAzSPConnectionName"  + "-" + $guid
$AzureClassicCertConnectionName = "TestAzClassicCertConnectionName"  + "-" + $guid

$CredentialName = "TestCredential" + "-" + $guid

$StringVariableName = "TestStringVariable" + "-" + $guid
$IntVariableName = "TestIntVariable" + "-" + $guid
$BoolVariableName = "TestBoolVariable" + "-" + $guid
$DateTimeVariableName = "TestDateTimeVariable" + "-" + $guid
$UnspecifiedVariableName = "TestUnspecifiedVariable" + "-" + $guid
$EncryptedVariableName = "TestEncryptedVariable" + "-" + $guid

$IntVariableNameEn = "TestEnIntVariable" + "-" + $guid
$BoolVariableNameEn = "TestEnBoolVariable" + "-" + $guid
$DateTimeVariableNameEn = "TestEnDateTimeVariable" + "-" + $guid
$UnspecifiedVariableNameEn = "TestEnUnspecifiedVariable" + "-" + $guid



Write-Verbose "Import module" -verbose
$TestModule = New-AzAutomationModule -AutomationAccountName $AccountName -Name $ModuleName -ContentLink "http://contosostorage.blob.core.windows.net/modules/ContosoModule.zip" -ResourceGroupName $ResourceGroupName
if($TestModule.Name -like $ModuleName) {
Write-Output "Module creation successful"
} 
else{
Write-Error "Module creation failed"
}


############ Connection ##################
function CreateAzureConnection {
    # ConnectionTypeName=Azure
    $FieldValues = @{"AutomationCertificateName"="TestCert-V1";"SubscriptionID"="SubId"}
    New-AzAutomationConnection -Name $AzureConnectionName -ConnectionTypeName Azure -ConnectionFieldValues $FieldValues -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
    
    Start-Sleep -s 60
    $TestAzConnection = Get-AzAutomationConnection -Name $AzureConnectionName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
    if($TestAzConnection.Name -eq $AzureConnectionName) {
    Write-Output "Azure connection creation successful"
    } 
    else{
    Write-Error "Azure connection creation failed"
    }

    Set-AzAutomationConnectionFieldValue -Name $AzureConnectionName -ConnectionFieldName "AutomationCertificateName" -Value "TestCert" -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName

    Start-Sleep -s 60
    $TestAzConnection = Get-AzAutomationConnection -Name $AzureConnectionName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
    if($TestAzConnection.AutomationCertificateName -eq "TestCert") {
    Write-Output "Azure connection update successful"
    } 
    else{
    Write-Error "Azure connection update failed"
    }
}

function CreateAzureServicePrincipalConnection {
    # ConnectionTypeName=AzureServicePrincipal
    $FieldValues = @{"ApplicationId"="AppId-V1"; "TenantId"="TenantId"; "CertificateThumbprint"="Thumbprint"; "SubscriptionId"="SubId"}
    New-AzAutomationConnection -Name $AzureSPConnectionName -ConnectionTypeName AzureServicePrincipal -ConnectionFieldValues $FieldValues -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName

    Start-Sleep -s 60
    $TestAzSPConnection = Get-AzAutomationConnection -Name $AzureSPConnectionName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
    if($TestAzSPConnection.Name -like $AzureSPConnectionName) {
    Write-Output "AzureServicePrincipal connection creation successful"
    } 
    else{
    Write-Error "AzureServicePrincipal connection creation failed"
    }
    
    Set-AzAutomationConnectionFieldValue -Name $AzureSPConnectionName -ConnectionFieldName "ApplicationId" -Value "AppId"  -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName

    Start-Sleep -s 60
    $TestAzSPConnection = Get-AzAutomationConnection -Name $AzureSPConnectionName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
    if($TestAzSPConnection.ApplicationId -like "AppId") {
    Write-Output "AzureServicePrincipal connection update successful"
    } 
    else{
    Write-Error "AzureServicePrincipal connection update failed"
    }

}

function CreateAzureClassicCertConnection {
    # ConnectionTypeName=AzureClassicCertificate
    $FieldValues = @{"SubscriptionName"="SubName"; "SubscriptionId"="SubId"; "CertificateAssetName"="ClassicRunAsAccountCertifcateAssetName-V1"}
    New-AzAutomationConnection -Name $AzureClassicCertConnectionName -ConnectionTypeName AzureClassicCertificate -ConnectionFieldValues $FieldValues -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
    
    Start-Sleep -s 60
    $TestAzClassicCertConnection = Get-AzAutomationConnection -Name $AzureClassicCertConnectionName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
    if($TestAzClassicCertConnection.Name -like $AzureClassicCertConnectionName) {
    Write-Output "AzureClassicCertificate connection creation successful"
    } 
    else{
    Write-Error "AzureClassicCertificate connection creation failed"
    }

    Set-AzAutomationConnectionFieldValue -Name $AzureClassicCertConnectionName -ConnectionFieldName "CertificateAssetName" -Value "ClassicRunAsAccountCertifcateAssetName" -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
    
    Start-Sleep -s 60
    $TestAzClassicCertConnection = Get-AzAutomationConnection -Name $AzureClassicCertConnectionName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AccountName
    if($TestAzClassicCertConnection.CertificateAssetName -like "ClassicRunAsAccountCertifcateAssetName") {
    Write-Output "AzureClassicCertificate connection update successful"
    } 
    else{
    Write-Error "AzureClassicCertificate connection update failed"
    }
}


function CreateConnection {
    Write-Verbose "Create connections" -verbose
    CreateAzureConnection
    CreateAzureServicePrincipalConnection
    CreateAzureClassicCertConnection   
}

############ Credential ##################
function CreateCredential {
    Write-Verbose "Create credential" -verbose
    $User = "Automation\TestCredential-1"
    $Password = ConvertTo-SecureString "SecurePassword-1" -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password
    New-AzAutomationCredential -AutomationAccountName $AccountName -Name $CredentialName -Value $Credential -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestCredential = Get-AzAutomationCredential -AutomationAccountName $AccountName -Name $CredentialName -ResourceGroupName $ResourceGroupName
    if($TestCredential.UserName -like $User) {
    Write-Output "Credential creation successful"
    } 
    else{
    Write-Error "Credential creation failed"
    }

    $User = "Automation\TestCredential"
    $Password = ConvertTo-SecureString "SecurePassword" -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password
    Set-AzAutomationCredential -AutomationAccountName $AccountName -Name $CredentialName -Value $Credential -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestCredential = Get-AzAutomationCredential -AutomationAccountName $AccountName -Name $CredentialName -ResourceGroupName $ResourceGroupName
    if($TestCredential.UserName -like $User) {
    Write-Output "Credential creation successful"
    } 
    else{
    Write-Error "Credential creation failed"
    }
}


############ Variable ##################
function CreateStringVariable {
    # string variable, unencryped 
    [string] $StringVariableValue = "Test String Variable - V1"
    New-AzAutomationVariable -Name $StringVariableName -Value $StringVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
    
    Start-Sleep -s 60
    $TestStringVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $StringVariableName -ResourceGroupName $ResourceGroupName
    if($TestStringVariable.Value -like $StringVariableValue) {
        Write-Output "String variable creation successful"
    } 
    else{
        Write-Error "String variable creation failed"
    }

    [string] $StringVariableValue = "Test String Variable"
    Set-AzAutomationVariable -Name $StringVariableName -Value $StringVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestStringVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $StringVariableName -ResourceGroupName $ResourceGroupName
    if($TestStringVariable.Value -like $StringVariableValue) {
        Write-Output "String variable update successful"
    } 
    else{
        Write-Error "String variable update failed"
    }
}

function CreateIntVariable {
    [int] $IntVariableValue = 12345123
    New-AzAutomationVariable -Name $IntVariableName -Value $IntVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    $TestIntVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $IntVariableName -ResourceGroupName $ResourceGroupName
    if($TestIntVariable.Value -eq $IntVariableValue) {
        Write-Output "Int variable creation successful"
    } 
    else{
        Write-Error "Int variable creation failed"
    }
    
    [int] $IntVariableValue = 12345
    Set-AzAutomationVariable -Name $IntVariableName -Value $IntVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    $TestIntVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $IntVariableName -ResourceGroupName $ResourceGroupName
    if($TestIntVariable.Value -eq $IntVariableValue) {
        Write-Output "Int variable update successful"
    } 
    else{
        Write-Error "Int variable update failed"
    }
}

function CreateBoolVariable {
    # Bool variable
    [bool] $BoolVariableValue = $true
    New-AzAutomationVariable -Name $BoolVariableName -Value $BoolVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestBoolVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $BoolVariableName -ResourceGroupName $ResourceGroupName
    if($TestBoolVariable.Value -eq $BoolVariableValue) {
        Write-Output "Bool variable creation successful"
    } 
    else{
        Write-Error "Bool variable creation failed"
    }
    
    [bool] $BoolVariableValue = $false
    Set-AzAutomationVariable -Name $BoolVariableName -Value $BoolVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestBoolVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $BoolVariableName -ResourceGroupName $ResourceGroupName
    if($TestBoolVariable.Value -eq $BoolVariableValue) {
        Write-Output "Bool variable update successful"
    } 
    else{
        Write-Error "Bool variable update failed"
    }
}

function CreateDateTimeVariable {
    # DateTime variable
    #TODO: Fix this

    $date = '08/24/2020'
    $DateTimeVariableValue = [Datetime]::ParseExact($date, 'MM/dd/yyyy', $null)

    New-AzAutomationVariable -Name $DateTimeVariableName -Value $DateTimeVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestDateTimeVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $DateTimeVariableValue -ResourceGroupName $ResourceGroupName
    if($TestDateTimeVariable.Value -eq $DateTimeVariableValue) {
        Write-Output "DateTime variable creation successful"
    } 
    else{
        Write-Error "DateTime variable creation failed"
    }

    [DateTime] $DateTimeVariableValue = ("Thursday, August 13, 2020 10:14:25 AM") | get-date -Format "yyyy-MM-ddTHH:mm:ssZ"
    Set-AzAutomationVariable -Name $DateTimeVariableName -Value $DateTimeVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestDateTimeVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $DateTimeVariableValue -ResourceGroupName $ResourceGroupName
    if($TestDateTimeVariable.Value -eq $DateTimeVariableValue) {
        Write-Output "DateTime variable update successful"
    } 
    else{
        Write-Error "DateTime variable update failed"
    }
}

function CreateUnspecifiedVariable {
    # Unspecified variable
    $UnspecifiedVariableValue = "Some Unspecified Value - V1"
    New-AzAutomationVariable -Name $UnspecifiedVariableName -Value $UnspecifiedVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName  

    Start-Sleep -s 60
    $TestUnspecifiedVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $UnspecifiedVariableName -ResourceGroupName $ResourceGroupName
    if($TestUnspecifiedVariable.Value.AutomationAccountName -like $UnspecifiedVariableValue.AutomationAccountName) {
        Write-Output "Unspecified variable creation successful"
    } 
    else{
        Write-Error "Unspecified variable creation failed"
    }
    
    $UnspecifiedVariableValue = "Some Unspecified Value"
    Set-AzAutomationVariable -Name $UnspecifiedVariableName -Value $UnspecifiedVariableValue -Encrypted $False -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName 

    Start-Sleep -s 60
    $TestUnspecifiedVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $UnspecifiedVariableName -ResourceGroupName $ResourceGroupName
    if($TestUnspecifiedVariable.Value.AutomationAccountName -like $UnspecifiedVariableValue.AutomationAccountName) {
        Write-Output "Unspecified variable update successful"
    } 
    else{
        Write-Error "Unspecified variable update failed"
    }
}

function CreateEncryptedStringVariable {
    # Encrypted variable
    [string] $EncryptedVariableValue = "Test Encrypted String Variable - V1"
    New-AzAutomationVariable -Name $EncryptedVariableName -Encrypted $True -Value $EncryptedVariableValue -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
    
    Start-Sleep -s 60
    $TestEncryptedVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $EncryptedVariableName -ResourceGroupName $ResourceGroupName
    if($TestEncryptedVariable.Encrypted -eq $True) {
        Write-Output "Encrypted string variable creation successful"
    } 
    else{
        Write-Error "Encrypted string variable creation failed"
    }

    
    [string] $EncryptedVariableValue = "Test Encrypted String Variable"
    Set-AzAutomationVariable -Name $EncryptedVariableName -Encrypted $True -Value $EncryptedVariableValue -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestEncryptedVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $EncryptedVariableName -ResourceGroupName $ResourceGroupName
    if($TestEncryptedVariable.Encrypted -eq $True) {
        Write-Output "Encrypted string variable update successful"
    } 
    else{
        Write-Error "Encrypted string variable update failed"
    }
}

function CreateEncryptedIntVariable {
    [int] $IntVariableValue = 5678123
    New-AzAutomationVariable -Name $IntVariableNameEn -Value $IntVariableValue -Encrypted $True -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 120
    $TestIntVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $IntVariableNameEn -ResourceGroupName $ResourceGroupName
    if($TestIntVariable.Value -eq $IntVariableValue) {
        Write-Output "Encrypted Int variable creation successful"
    } 
    else{
        Write-Error "Encrypted Int variable creation failed"
    }

    
    [int] $IntVariableValue = 5678
    Set-AzAutomationVariable -Name $IntVariableNameEn -Value $IntVariableValue -Encrypted $True -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 120
    $TestIntVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $IntVariableNameEn -ResourceGroupName $ResourceGroupName
    if($TestIntVariable.Value -eq $IntVariableValue) {
        Write-Output "Encrypted Int variable update successful"
    } 
    else{
        Write-Error "Encrypted Int variable update failed"
    }
}

function CreateEncryptedBoolVariable {
    # Bool variable
    [bool] $BoolVariableValue = $false
    New-AzAutomationVariable -Name $BoolVariableNameEn -Value $BoolVariableValue -Encrypted $True -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 120
    $TestBoolVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $BoolVariableNameEn -ResourceGroupName $ResourceGroupName
    if($TestBoolVariable.Value -eq $BoolVariableValue) {
        Write-Output "Encrypted Bool variable creation successful"
    } 
    else{
        Write-Error "Encrypted Bool variable creation failed"
    }
    
    [bool] $BoolVariableValue = $true
    Set-AzAutomationVariable -Name $BoolVariableNameEn -Value $BoolVariableValue -Encrypted $True -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 120
    $TestBoolVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $BoolVariableNameEn -ResourceGroupName $ResourceGroupName
    if($TestBoolVariable.Value -eq $BoolVariableValue) {
        Write-Output "Encrypted Bool variable update successful"
    } 
    else{
        Write-Error "Encrypted Bool variable update failed"
    }
}

function CreateEncryptedDateTimeVariable {
    # DateTime variable
    #TODO: Fix this
    [DateTime] $DateTimeVariableValue = ("Thursday, August 2, 2020 10:14:25 AM") | get-date -Format "yyyy-MM-ddTHH:mm:ssZ"
    New-AzAutomationVariable -Name $DateTimeVariableNameEn -Value $DateTimeVariableValue -Encrypted $True -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestDateTimeVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $DateTimeVariableNameEn -ResourceGroupName $ResourceGroupName
    if($TestDateTimeVariable.Value -eq $DateTimeVariableValue) {
        Write-Output "Encrypted DateTime variable creation successful"
    } 
    else{
        Write-Error "Encrypted DateTime variable creation failed"
    }
    
    [DateTime] $DateTimeVariableValue = ("Thursday, August 1, 2020 10:14:25 AM") | get-date -Format "yyyy-MM-ddTHH:mm:ssZ"
    Set-AzAutomationVariable -Name $DateTimeVariableNameEn -Value $DateTimeVariableValue -Encrypted $True -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestDateTimeVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $DateTimeVariableNameEn -ResourceGroupName $ResourceGroupName
    if($TestDateTimeVariable.Value -eq $DateTimeVariableValue) {
        Write-Output "Encrypted DateTime variable update successful"
    } 
    else{
        Write-Error "Encrypted DateTime variable update failed"
    }
}

function CreateEncryptedUnspecifiedVariable {
    # Unspecified variable
    $UnspecifiedVariableValue = "Some Encrypted Unspecified Value - V1"
    New-AzAutomationVariable -Name $UnspecifiedVariableNameEn -Value $UnspecifiedVariableValue -Encrypted $True -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName    

    Start-Sleep -s 60
    $TestUnspecifiedVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $UnspecifiedVariableNameEn -ResourceGroupName $ResourceGroupName
    if($TestUnspecifiedVariable.Value.AutomationAccountName -like $UnspecifiedVariableValue.AutomationAccountName) {
        Write-Output "Encrypted Unspecified variable creation successful"
    } 
    else{
        Write-Error "Encrypted Unspecified variable creation failed"
    }

    $UnspecifiedVariableValue = "Some Encrypted Unspecified Value"
    Set-AzAutomationVariable -Name $UnspecifiedVariableNameEn -Value $UnspecifiedVariableValue -Encrypted $True -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName

    Start-Sleep -s 60
    $TestUnspecifiedVariable = Get-AzAutomationVariable -AutomationAccountName $AccountName -Name $UnspecifiedVariableNameEn -ResourceGroupName $ResourceGroupName
    if($TestUnspecifiedVariable.Value.AutomationAccountName -like $UnspecifiedVariableValue.AutomationAccountName) {
        Write-Output "Encrypted Unspecified variable update successful"
    } 
    else{
        Write-Error "Encrypted Unspecified variable update failed"
    }
}

function CreateCertificate {
    Write-Verbose "Get auth token" -verbose
    $currentAzureContext = Get-AzContext
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    $Token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)

    Write-Verbose "Create certificate" -verbose
    $certName = "testCert"
    try{
    $Headers = @{}
    $Headers.Add("Authorization","bearer "+ " " + "$($Token.AccessToken)")
    $contentType3 = "application/json"
    $bodyCert = @"
            {
    "name": "testCert",
    "properties": {
    "base64Value": "MIIC5DCCAcygAwIBAgIQRHw/PpDU95xN9GYFa5vUHTANBgkqhkiG9w0BAQ0FADAuMSwwKgYDVQQDEyNHZW5ldmEgVGVzdCBTdXNiY3JpcHRpb24gTWFuYWdlbWVudDAeFw0xNTEwMDkxODA3MDNaFw0xNzEwMDgxODA3MDNaMC4xLDAqBgNVBAMTI0dlbmV2YSBUZXN0IFN1c2JjcmlwdGlvbiBNYW5hZ2VtZW50MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAjV+X9b/qeFNffLUL/TayLAA5GYoNsvLsVvBebezrdiwi/KeSD3uS0rw8X0QrMn6LWH/RxKs1S8A7UxMZjR6pse5FAZv9A3SHT2dmW5CYDQ7vKyqTB/BeOZch02GMqAkyr3KV7zl0Uj6RYq4Avx0PA2AAg73RXf7s0UtB7e7GnzgKR83/Gj/EaXas21x78IF8sDBVqT3LvvPNSTOlB2/jlwQ9pOijvVpPmvTeChfRmaU8o+oIUJJGLhFDQJkKNw7ZkwkNmY0hijovi63J+hO6ikA9cKvQh4sOiNwKWEIhzxnNmI7O2uDidV4knpV7JbuejrKJemy4rTb0VLuEPpIq0QIDAQABMA0GCSqGSIb3DQEBDQUAA4IBAQAx8ai4hl5GuwPYQMC2V+jzgyROjasvygm+bpo5pWwIr47hbHkN6r5N6Dmp1Vf8xo7uQudzUAS3YVdMakSRQNOzo9mFTKqYLmSA2NI9l2J+TlJnAIbJhqVHCRoQ0Fn2kC5mBb4unQbIVTurb75EGQTHf55LDk3GPrZwpNVsw6nHM+Gy5GL6Vz1J30ZoAaAnNzOfyrJ4J352pCx9FgH3TzD3fhvZODjDrQfankb/yHCBlYx3WyiR+3n8K01qg4L3V9Z+PeFS4pDMN+2zfuOqNCefKKKn1wMyHbXDq1/29OrqJQvueStZ8l3X39umKrhnDwriGIwlgPevuSp23alpF9BY"
    }
    }
"@
    $PutUri = "$UriStart/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AccountName/certificates/testCert?api-version=2015-10-31"
    Invoke-RestMethod -Uri $PutUri -Method Put -ContentType $contentType3 -Headers $Headers -Body $bodyCert
    }
    catch{
    Write-Error -Message $_.Exception
    }

    $Cert = Get-AzAutomationCertificate -Name $certName -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
    if($Cert.Thumbprint -like "edfab8580e873bbc2ac188ed6d02411019b7d8d3") {
        Write-Output "Certificate asset creation successful"
    } 
    else{
        Write-Error "Certificate asset creation failed"
    }

    $updatedDesc = "Description Updated"
    Set-AzAutomationCertificate -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName -Name $certName -Description $updatedDesc

    $updatedCert = Get-AzAutomationCertificate -Name $certName -AutomationAccountName $AccountName -ResourceGroupName $ResourceGroupName
    if($updatedCert.Description -eq $updatedDesc){
        Write-Output "Automation Certificate Update successful"
    }
    else{
        Write-Error "Automation Certificate Update failed"
    }
}

function CreateVariables {
    Write-Verbose "Create variables" -verbose
    
    #Create unencrypted variables
    CreateStringVariable
    CreateIntVariable
    CreateBoolVariable
    # CreateDateTimeVariable
    CreateUnspecifiedVariable

    #Create Encrypted variable
    CreateEncryptedStringVariable
    CreateEncryptedIntVariable
    CreateEncryptedBoolVariable
    # CreateEncryptedDateTimeVariable
    CreateEncryptedUnspecifiedVariable
}


CreateVariables
CreateConnection
CreateCredential







