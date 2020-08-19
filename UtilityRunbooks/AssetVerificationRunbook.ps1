Param(
[Parameter(Mandatory = $true)]
[string] $guid
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


$expectedFieldValuesAzureConnection = @{"AutomationCertificateName"="TestCert";"SubscriptionID"="SubId"}
$expectedFieldValuesAzureSP = @{"ApplicationId"="AppId"; "TenantId"="TenantId"; "CertificateThumbprint"="Thumbprint"; "SubscriptionId"="SubId"}
$expectedFieldValuesAzureCC = @{"SubscriptionName"="SubName"; "SubscriptionId"="SubId"; "CertificateAssetName"="ClassicRunAsAccountCertifcateAssetName"}


$expectedUser = "Automation\TestCredential"

[string] $expectedStringVariableValueUnEn = "Test String Variable"
[int] $expectedIntVariableValue = 12345
[bool] $expectedBoolVariableValue = $false
# [DateTime] $expectedDateTimeVariableValue = ("Thursday, August 13, 2020 10:14:25 AM") | get-date -Format "yyyy-MM-ddTHH:mm:ssZ"
$expectedUnspecifiedVariableValue = "Some Unspecified Value"
[string] $expectedEncryptedVariableValue = "Test Encrypted String Variable"

[int]$ExpectedIntVariableNameEn = 5678
[bool]$ExpectedBoolVariableNameEn = $true
# [DateTime]$ExpectedDateTimeVariableNameEn = ("Thursday, August 1, 2020 10:14:25 AM") | get-date -Format "yyyy-MM-ddTHH:mm:ssZ"
$ExpectedUnspecifiedVariableNameEn = "Some Encrypted Unspecified Value"

#Try getting variables 

###string variable
function VerifyStringVariable {
    $actualOutput = Get-AutomationVariable -Name $StringVariableName
    if($actualOutput -like $expectedStringVariableValueUnEn) {
        Write-Output "Get UnEncrypted variable succesfull - String"
    } 
    else{
        Write-Error "Get UnEncrypted variable Failed - String"
    } 

    ### Set and Test Unencrypted variable
    $updatedStringVarValue = "Updated String Variable Value"
    Set-AutomationVariable -Name $StringVariableName -Value $updatedStringVarValue
    Start-Sleep -s 120

    $actualOutput = Get-AutomationVariable -Name $StringVariableName
    if($actualOutput -like $updatedStringVarValue) {
        Write-Output "Get UnEncrypted variable succesfull - String"
    } 
    else{
        Write-Error "Get UnEncrypted variable Failed - String"
    } 
    Set-AutomationVariable -Name $StringVariableName -Value $expectedStringVariableValueUnEn
}
function VerifyIntVariable {
    ###Int variable
    $actualOutput = Get-AutomationVariable -Name $IntVariableName
    if($actualOutput -eq $expectedIntVariableValue) {
        Write-Output "Get variable succesfull - Int"
    } 
    else{
        Write-Error "Get variable Failed - Int"
    }

    ### Set and Test Unencrypted variable
    $updatedIntVarValue = 12
    Set-AutomationVariable -Name $IntVariableName -Value $updatedIntVarValue
    Start-Sleep -s 120

    $actualOutput = Get-AutomationVariable -Name $IntVariableName
    if($actualOutput -eq $updatedIntVarValue) {
        Write-Output "Get variable succesfull - Int"
    } 
    else{
        Write-Error "Get variable Failed - Int"
    }

    Set-AutomationVariable -Name $IntVariableName -Value $expectedIntVariableValue
}

function VerifyEncryptedIntVariable {
    ###Int variable
    $actualOutput = Get-AutomationVariable -Name $IntVariableNameEn
    if($actualOutput -eq $ExpectedIntVariableNameEn) {
        Write-Output "Get variable succesfull - Int"
    } 
    else{
        Write-Error "Get variable Failed - Int"
    }

    ### Set and Test Unencrypted variable
    $updatedIntVarValue = 12
    Set-AutomationVariable -Name $IntVariableNameEn -Value $updatedIntVarValue
    Start-Sleep -s 120

    $actualOutput = Get-AutomationVariable -Name $IntVariableNameEn
    if($actualOutput -eq $updatedIntVarValue) {
        Write-Output "Get variable succesfull - Int"
    } 
    else{
        Write-Error "Get variable Failed - Int"
    }

    Set-AutomationVariable -Name $IntVariableNameEn -Value $ExpectedIntVariableNameEn
}

function VerifyBoolVariable {
    ###Bool variable
    $actualOutput = Get-AutomationVariable -Name $BoolVariableName
    if($actualOutput -eq $expectedBoolVariableValue) {
        Write-Output "Get variable succesfull - Bool"
    } 
    else{
        Write-Error "Get variable Failed - Bool"
    }

    $updatedBoolVar = $true
    Set-AutomationVariable -Name $BoolVariableName -Value $updatedBoolVar
    Start-Sleep -s 120

    $actualOutput = Get-AutomationVariable -Name $BoolVariableName
    if($actualOutput -eq $updatedBoolVar) {
        Write-Output "Get variable succesfull - Bool"
    } 
    else{
        Write-Error "Get variable Failed - Bool"
    }

    Set-AutomationVariable -Name $BoolVariableName -Value $expectedBoolVariableValue
}

function VerifyEncryptedBoolVariable {
    ###Bool variable
    $actualOutput = Get-AutomationVariable -Name $BoolVariableNameEn
    if($actualOutput -eq $ExpectedBoolVariableNameEn) {
        Write-Output "Get variable succesfull - Bool"
    } 
    else{
        Write-Error "Get variable Failed - Bool"
    }

    $updatedBoolVar = $true
    Set-AutomationVariable -Name $BoolVariableNameEn -Value $updatedBoolVar
    Start-Sleep -s 120

    $actualOutput = Get-AutomationVariable -Name $BoolVariableNameEn
    if($actualOutput -eq $updatedBoolVar) {
        Write-Output "Get variable succesfull - Bool"
    } 
    else{
        Write-Error "Get variable Failed - Bool"
    }

    Set-AutomationVariable -Name $BoolVariableNameEn -Value $ExpectedBoolVariableNameEn
}

function VerifyDateTimeVariable {
    #TODO: Fix this
    $actualOutput = Get-AutomationVariable -Name $DateTimeVariableName
    if($actualOutput -eq $expectedDateTimeVariableValue) {
        Write-Output "Get variable succesfull - DateTime"
    } 
    else{
        Write-Error "Get variable Failed - DateTime"
    }

    [DateTime] $updatedDateTimeVariableValue = ("Thursday, August 15, 2020 10:14:25 AM") | get-date -Format "yyyy-MM-ddTHH:mm:ssZ"
    Set-AutomationVariable -Name $DateTimeVariableName -Value $updatedDateTimeVariableValue

    $actualOutput = Get-AutomationVariable -Name $DateTimeVariableName
    if($actualOutput -eq $updatedDateTimeVariableValue) {
        Write-Output "Get variable succesfull - DateTime"
    } 
    else{
        Write-Error "Get variable Failed - DateTime"
    }
    Set-AutomationVariable -Name $DateTimeVariableName -Value $expectedDateTimeVariableValue
}
function VerifyEncryptedDateTimeVariable {
    #TODO: Fix this
    $actualOutput = Get-AutomationVariable -Name $DateTimeVariableNameEn
    if($actualOutput -eq $ExpectedDateTimeVariableNameEn) {
        Write-Output "Get variable succesfull - DateTime"
    } 
    else{
        Write-Error "Get variable Failed - DateTime"
    }

    [DateTime] $updatedDateTimeVariableValue = ("Thursday, August 16, 2020 10:14:25 AM") | get-date -Format "yyyy-MM-ddTHH:mm:ssZ"
    Set-AutomationVariable -Name $DateTimeVariableNameEn -Value $updatedDateTimeVariableValue

    $actualOutput = Get-AutomationVariable -Name $DateTimeVariableNameEn
    if($actualOutput -eq $updatedDateTimeVariableValue) {
        Write-Output "Get variable succesfull - DateTime"
    } 
    else{
        Write-Error "Get variable Failed - DateTime"
    }
    Set-AutomationVariable -Name $DateTimeVariableNameEn -Value $ExpectedDateTimeVariableNameEn
}

function VerifyUnspecifiedVariable {
    ### Unspecified variable
    $actualOutput = Get-AutomationVariable -Name $UnspecifiedVariableName
    if($actualOutput -like $expectedUnspecifiedVariableValue) {
        Write-Output "Get variable succesfull - Unspecified Var"
    } 
    else{
        Write-Error "Get variable Failed - Unspecified Var"
    }

    $updatedUnspecifiedVar = "Updated the unspecified var"
    Set-AutomationVariable -Name $UnspecifiedVariableName -Value $updatedUnspecifiedVar
    Start-Sleep -s 120

    $actualOutput = Get-AutomationVariable -Name $UnspecifiedVariableName
    if($actualOutput -like $updatedUnspecifiedVar) {
        Write-Output "Get variable succesfull - Unspecified Var"
    } 
    else{
        Write-Error "Get variable Failed - Unspecified Var"
    }
    Set-AutomationVariable -Name $UnspecifiedVariableName -Value $expectedUnspecifiedVariableValue
}

function VerifyEncryptedUnspecifiedVariable {
    ### Unspecified variable
    $actualOutput = Get-AutomationVariable -Name $UnspecifiedVariableNameEn
    if($actualOutput -like $ExpectedUnspecifiedVariableNameEn) {
        Write-Output "Get variable succesfull - Unspecified Var"
    } 
    else{
        Write-Error "Get variable Failed - Unspecified Var"
    }

    $updatedUnspecifiedVar = "Updated the encrypted unspecified var"
    Set-AutomationVariable -Name $UnspecifiedVariableNameEn -Value $updatedUnspecifiedVar
    Start-Sleep -s 120

    $actualOutput = Get-AutomationVariable -Name $UnspecifiedVariableNameEn
    if($actualOutput -like $updatedUnspecifiedVar) {
        Write-Output "Get variable succesfull - Unspecified Var"
    } 
    else{
        Write-Error "Get variable Failed - Unspecified Var"
    }
    Set-AutomationVariable -Name $UnspecifiedVariableNameEn -Value $ExpectedUnspecifiedVariableNameEn
}

function VerifyEncryptedVariable {
    ###Encrypted variable
    $actualOutput = Get-AutomationVariable -Name $EncryptedVariableName
    if($actualOutput -like $expectedEncryptedVariableValue) {
        Write-Output "Get variable succesfull - Encrypted String"
    } 
    else{
        Write-Error "Get variable Failed - Encrypted String"
    }

    ### Set and Test Encrypted variable
    $updatedEncryptedVarValue = "Updated Encrypted Variable Value"
    Set-AutomationVariable -Name $EncryptedVariableName -Value $updatedEncryptedVarValue
    Start-Sleep -s 120

    $actualOutput = Get-AutomationVariable -Name $EncryptedVariableName
    if($actualOutput -like $updatedEncryptedVarValue) {
        Write-Output "Get Encrypted variable succesfull - String"
    } 
    else{
        Write-Error "Get Encrypted variable Failed - String"
    } 
    Set-AutomationVariable -Name $EncryptedVariableName -Value $expectedEncryptedVariableValue
}

function VerifyCredential {
    ### verify credential
    $actualCred = Get-AutomationPSCredential -Name $CredentialName
    if($actualCred.UserName -like $expectedUser) {
        Write-Output "Credential Get successful"
    } 
    else{
        Write-Error "Credential Get failed"
    }
}

function VerifyConnecion {
    ### verify connections
    $actualConnection = Get-AutomationConnection -Name $AzureConnectionName
    if($actualConnection.AzureCertificateName -like $expectedFieldValuesAzureConnection.AzureCertificateName){
        Write-Output "Azure connection Get Successfull"
    }
    else{
        Write-Error "Azure connection Get Failed"
    }

    $actualConnection = Get-AutomationConnection -Name $AzureSPConnectionName
    if($actualConnection.CertificateThumbprint -like $expectedFieldValuesAzureSP.CertificateThumbprint){
        Write-Output "Azure Service Principal connection Get Successfull"
    }
    else{
        Write-Error "Azure Service Principal connection Get Failed"
    }

    $actualConnection = Get-AutomationConnection -Name $AzureClassicCertConnectionName
    if($actualConnection.CertificateAssetName -like $expectedFieldValuesAzureCC.CertificateAssetName){
        Write-Output "Azure classic certificate connection Get Successfull"
    }
    else{
        Write-Error "Azure classic certificate connection Get Failed"
    }
}

VerifyStringVariable
VerifyIntVariable
VerifyBoolVariable
# VerifyDateTimeVariable
VerifyUnspecifiedVariable

VerifyEncryptedVariable
VerifyEncryptedIntVariable
VerifyEncryptedBoolVariable
# VerifyEncryptedDateTimeVariable
VerifyEncryptedUnspecifiedVariable

