# AzureAutomation Region Validation
1. BaseRunbooks contains runbooks to trigger verification of different Use Cases for any new region validation
2. UtilityRunbooks contains runbooks to verify scripts execution on Automation Account
3. ValidationRunbooks contains runbooks to verify various Use Cases.
4. VMExtensionScripts contains scripts to be executed on the newly created VMs for Hybrid worker Scenarios.


Gaps:
Webhook:
1. Disabled Webhook invocation
2. Parametrized invocation
Schedule:
1. Disabled Check
2. Montly, Hourly, Daily, Advance Schedule(Month days, Week days) - Cases need to be covered (Invoke the immediate run and verify next run)
Private Link:
1. Is Enabled - Public network access flag (false - webhook must fail unless invoked by VNET)
Accounts:
1. Move to another sub


DSC:
1. Sensitive?


1. UriStart
2. Add-AzEnvironment
3. AzureEnvironment in all the connect-ToAzAccount
4. Import-Module
5. Invoke-Webrequest gets forbidden error
6. Trigger child runbook