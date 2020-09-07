import sys
import time
import automationassets

guid = sys.argv[1]


AzureConnectionName = "TestAzConnectionName"  + "-" + guid
AzureSPConnectionName = "TestAzSPConnectionName"  + "-" + guid
AzureClassicCertConnectionName = "TestAzClassicCertConnectionName"  + "-" + guid

CredentialName = "TestCredential" + "-" + guid

StringVariableName = "TestStringVariable" + "-" + guid
IntVariableName = "TestIntVariable" + "-" + guid
BoolVariableName = "TestBoolVariable" + "-" + guid
DateTimeVariableName = "TestDateTimeVariable" + "-" + guid
UnspecifiedVariableName = "TestUnspecifiedVariable" + "-" + guid
EncryptedVariableName = "TestEncryptedVariable" + "-" + guid

IntVariableNameEn = "TestEnIntVariable" + "-" + guid
BoolVariableNameEn = "TestEnBoolVariable" + "-" + guid
DateTimeVariableNameEn = "TestEnDateTimeVariable" + "-" + guid
UnspecifiedVariableNameEn = "TestEnUnspecifiedVariable" + "-" + guid


expectedFieldValuesAzureConnection = {"AutomationCertificateName":"TestCert","SubscriptionID":"SubId"}
expectedFieldValuesAzureSP = {"ApplicationId":"AppId", "TenantId":"TenantId", "CertificateThumbprint":"Thumbprint", "SubscriptionId":"SubId"}
expectedFieldValuesAzureCC = {"SubscriptionName":"SubName","SubscriptionId":"SubId","CertificateAssetName":"ClassicRunAsAccountCertifcateAssetName"}

certName = "testCert"
expectedCertThumbprint = "edfab8580e873bbc2ac188ed6d02411019b7d8d3"

expectedUser = "Automation\TestCredential"

expectedStringVariableValueUnEn = "Test String Variable"
expectedIntVariableValue = 12345
expectedBoolVariableValue = False
# [DateTime] $expectedDateTimeVariableValue = ("Thursday, August 13, 2020 10:14:25 AM") | get-date -Format "yyyy-MM-ddTHH:mm:ssZ"
expectedUnspecifiedVariableValue = "Some Unspecified Value"
expectedEncryptedVariableValue = "Test Encrypted String Variable"

ExpectedIntVariableValEn = 5678
ExpectedBoolVariableValEn = True
# [DateTime]$ExpectedDateTimeVariableNameEn = ("Thursday, August 1, 2020 10:14:25 AM") | get-date -Format "yyyy-MM-ddTHH:mm:ssZ"
ExpectedUnspecifiedVariableValEn = "Some Encrypted Unspecified Value"


def verify_string_var():
    actualoutput = automationassets.get_automation_variable(StringVariableName)
    if actualoutput == expectedStringVariableValueUnEn:
        print "Get UnEncrypted Variable Successful - String"
    else:
        print "ERROR: Get UnEncrypted Variable Failed - String"
    
    updatedstrvariableval = "Updated string variable value"
    automationassets.set_automation_variable(StringVariableName, updatedstrvariableval)
    time.sleep(60)

    actualoutput = automationassets.get_automation_variable(StringVariableName)
    if actualoutput == updatedstrvariableval:
        print "Update UnEncrypted Variable Successful - String"
    else:
        print "ERROR: Update UnEncrypted Variable Failed - String"

    automationassets.set_automation_variable(StringVariableName, expectedStringVariableValueUnEn)

def verify_int_var():
    actualoutput = automationassets.get_automation_variable(IntVariableName)
    if actualoutput == expectedIntVariableValue:
        print "Get UnEncrypted Variable Successful - Int"
    else:
        print "ERROR: Get UnEncrypted Variable Failed - Int"
    
    updatedintvariableval = 99000
    automationassets.set_automation_variable(IntVariableName, updatedintvariableval)
    time.sleep(60)

    actualoutput = automationassets.get_automation_variable(IntVariableName)
    if actualoutput == updatedintvariableval:
        print "Update UnEncrypted Variable Successful - Int"
    else:
        print "ERROR: Update UnEncrypted Variable Failed - Int"

    automationassets.set_automation_variable(IntVariableName, expectedIntVariableValue)

def verify_bool_var():
    actualoutput = automationassets.get_automation_variable(BoolVariableName)
    if actualoutput == expectedBoolVariableValue:
        print "Get UnEncrypted Variable Successful - Bool"
    else:
        print "ERROR: Get UnEncrypted Variable Failed - Bool"
    
    updatedboolvariableval = True
    automationassets.set_automation_variable(BoolVariableName, updatedboolvariableval)
    time.sleep(60)

    actualoutput = automationassets.get_automation_variable(BoolVariableName)
    if actualoutput == updatedboolvariableval:
        print "Update UnEncrypted Variable Successful - Bool"
    else:
        print "ERROR: Update UnEncrypted Variable Failed - Bool"

    automationassets.set_automation_variable(BoolVariableName, expectedBoolVariableValue)    

def verify_unspecified_var():
    actualoutput = automationassets.get_automation_variable(UnspecifiedVariableName)
    if actualoutput == expectedUnspecifiedVariableValue:
        print "Get UnEncrypted Variable Successful - Unspecified"
    else:
        print "ERROR: Get UnEncrypted Variable Failed - Unspecified"
    
    updatedunspecifiedvariableval = "Updated unspecified variable"
    automationassets.set_automation_variable(UnspecifiedVariableName, updatedunspecifiedvariableval)
    time.sleep(60)

    actualoutput = automationassets.get_automation_variable(UnspecifiedVariableName)
    if actualoutput == updatedunspecifiedvariableval:
        print "Update UnEncrypted Variable Successful - Unspecified"
    else:
        print "ERROR: Update UnEncrypted Variable Failed - Unspecified"

    automationassets.set_automation_variable(UnspecifiedVariableName, expectedUnspecifiedVariableValue)    

def verify_enc_str_var():
    actualoutput = automationassets.get_automation_variable(EncryptedVariableName)
    if actualoutput == expectedEncryptedVariableValue:
        print "Get Encrypted Variable Successful - String"
    else:
        print "ERROR: Get Encrypted Variable Failed - String"
    
    updatedstrvariableval = "Updated string variable value"
    automationassets.set_automation_variable(EncryptedVariableName, updatedstrvariableval)
    time.sleep(60)

    actualoutput = automationassets.get_automation_variable(EncryptedVariableName)
    if actualoutput == updatedstrvariableval:
        print "Update Encrypted Variable Successful - String"
    else:
        print "ERROR: Update Encrypted Variable Failed - String"

    automationassets.set_automation_variable(EncryptedVariableName, expectedEncryptedVariableValue)   

def verify_enc_int_var():
    actualoutput = automationassets.get_automation_variable(IntVariableNameEn)
    if actualoutput == ExpectedIntVariableValEn:
        print "Get Encrypted Variable Successful - Int"
    else:
        print "ERROR: Get Encrypted Variable Failed - Int"
    
    updatedintvariableval = 8877
    automationassets.set_automation_variable(IntVariableNameEn, updatedintvariableval)
    time.sleep(60)

    actualoutput = automationassets.get_automation_variable(IntVariableNameEn)
    if actualoutput == updatedintvariableval:
        print "Update Encrypted Variable Successful - Int"
    else:
        print "ERROR: Update Encrypted Variable Failed - Int"

    automationassets.set_automation_variable(IntVariableNameEn, ExpectedIntVariableValEn)

def verify_enc_bool_var():
    actualoutput = automationassets.get_automation_variable(BoolVariableNameEn)
    if actualoutput == ExpectedBoolVariableValEn:
        print "Get Encrypted Variable Successful - Bool"
    else:
        print "ERROR: Get Encrypted Variable Failed - Bool"
    
    updatedboolvariableval = False
    automationassets.set_automation_variable(BoolVariableNameEn, updatedboolvariableval)
    time.sleep(60)

    actualoutput = automationassets.get_automation_variable(BoolVariableNameEn)
    if actualoutput == updatedboolvariableval:
        print "Update Encrypted Variable Successful - Bool"
    else:
        print "ERROR: Update Encrypted Variable Failed - Bool"

    automationassets.set_automation_variable(BoolVariableNameEn, ExpectedBoolVariableValEn)

def verify_enc_unspecified_var():
    actualoutput = automationassets.get_automation_variable(UnspecifiedVariableNameEn)
    if actualoutput == ExpectedUnspecifiedVariableValEn:
        print "Get Encrypted Variable Successful - Unspecified"
    else:
        print "ERROR: Get Encrypted Variable Failed - Unspecified"
    
    updatedunspecifiedvariableval = "Enc Unspecified value updated"
    automationassets.set_automation_variable(UnspecifiedVariableNameEn, updatedunspecifiedvariableval)
    time.sleep(60)

    actualoutput = automationassets.get_automation_variable(UnspecifiedVariableNameEn)
    if actualoutput == updatedunspecifiedvariableval:
        print "Update Encrypted Variable Successful - Unspecified"
    else:
        print "ERROR: Update Encrypted Variable Failed - Unspecified"

    automationassets.set_automation_variable(UnspecifiedVariableNameEn, ExpectedUnspecifiedVariableValEn)


def verify_credential():
    actualcredential = automationassets.get_automation_credential(CredentialName)
    if actualcredential["username"] == expectedUser:
        print "Get Automation Credential Successful"
    else:
        print "ERROR: Get Automation Credential Failed" 


def verify_connection():
    actualconnection = automationassets.get_automation_connection(AzureConnectionName)
    if actualconnection["AutomationCertificateName"] == expectedFieldValuesAzureConnection["AutomationCertificateName"]:
        print "Get Azure connection Successful"
    else:
        print "ERROR: Get Azure Connection Failed"
    
    actualconnection = automationassets.get_automation_connection(AzureSPConnectionName)
    if actualconnection["CertificateThumbprint"] == expectedFieldValuesAzureSP["CertificateThumbprint"]:
        print "Get Azure SP connection Successful"
    else:
        print "ERROR: Get Azure SP connection Failed"

    actualconnection = automationassets.get_automation_connection(AzureClassicCertConnectionName)
    if actualconnection["CertificateAssetName"] == expectedFieldValuesAzureCC["CertificateAssetName"]:
        print "Get Azure Classic connection Successful"
    else:
        print "ERROR: Get Azure Classic connection Failed"
        
verify_string_var()
verify_int_var()
verify_bool_var()
verify_unspecified_var()

verify_enc_str_var()
verify_enc_int_var()
verify_enc_bool_var()
verify_enc_unspecified_var()

verify_credential()
verify_connection()