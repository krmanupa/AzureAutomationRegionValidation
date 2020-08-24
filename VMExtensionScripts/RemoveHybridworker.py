import subprocess
import os
from datetime import datetime
import time
from optparse import OptionParser

def run_command(cmd):
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    return proc.returncode, stdout, stderr

def deregister_woker(options):

    workspaceId = options.workspace_id
    automationSharedKey = options.automation_account_key
    hybridGroupName = options.hybrid_worker_group_name
    automationEndpoint = options.registration_endpoint

    if(not os.path.isdir("/opt/microsoft/omsconfig/modules/nxOMSAutomationWorker/DSCResources/MSFT_nxOMSAutomationWorkerResource/automationworker")):
        print("No Hybrid worker found to deregister...")
    else:
        cmdToRegisterUserHW = ["sudo", "python", "/opt/microsoft/omsconfig/modules/nxOMSAutomationWorker/DSCResources/MSFT_nxOMSAutomationWorkerResource/automationworker/scripts/onboarding.py", "--deregister", "--endpoint", automationEndpoint,"--key", automationSharedKey, "--groupname",hybridGroupName,"--workspaceid", workspaceId]

        returncode, _, stderr = run_command(cmdToRegisterUserHW)
        if(returncode == 0):
            print("Successfully De-Registerd the worker.")
        else:
            print("De-Registration failed because of " + str(stderr))


def main():
    parser = OptionParser(
        usage="usage: %prog -e endpoint -k key -g groupname -w workspaceid -wk workspacekey")

    parser.add_option("-e", "--endpoint", dest="registration_endpoint", help="Agent service registration endpoint.")
    parser.add_option("-k", "--key", dest="automation_account_key", help="Automation account primary/secondary key.")
    parser.add_option("-g", "--groupname", dest="hybrid_worker_group_name", help="Hybrid worker group name.")
    parser.add_option("-w", "--workspaceid", dest="workspace_id", help="Workspace id.")
    parser.add_option("-l", "--workspacekey", dest="workspace_key", help="Workspace Key.")

    (options, _) = parser.parse_args()
    deregister_woker(options)

if __name__ == "__main__":
    main()
