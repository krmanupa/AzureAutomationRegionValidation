# AzureAutomation Region Validation
1. BaseRunbooks contains runbooks to trigger verification of different Use Cases for any new region validation
2. UtilityRunbooks contains runbooks to verify scripts execution on Automation Account
3. ValidationRunbooks contains runbooks to verify various Use Cases.
4. VMExtensionScripts contains scripts to be executed on the newly created VMs for Hybrid worker Scenarios.


Usage:
- BaseRunbooks folder contains 2 runbooks 
    - BaseLocal : This runbook needs to run on the local machine which contains Az.Accounts and Az.Automation modules installed.
                  This runbook needs Location, Environment and the Subscription in which we would want to carry out the validaiton.
                  This runbook takes care of creating a ResourceGroup in which a test automation account will be created and all the required pre-requisite modules and runbooks from this particular project will be imported. 
    - BaseRemote : This runbook runs on the Automation Account created by the BaseLocal runbook.
                   This runbook contains methods to run all different kinds of scenarios possible in Azure Automation. Ideally this gets 
                   this should be triggered by the BaseLocal script, since there are a few gaps today, we invoke this script manually.
- All the scripts under validation runbooks verify various scenarios supported by Azure Automation.

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


1. UriStart - Done
2. Add-AzEnvironment - Done
3. AzureEnvironment in all the connect-ToAzAccount - Done
4. Import-Module - Done 
5. Invoke-Webrequest gets forbidden error - Need to check
6. Trigger child runbook - Done