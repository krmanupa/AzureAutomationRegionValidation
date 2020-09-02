#region install MSI if available
    # TASK-ITEM: Convert to function?
    $localPackageFile = "PowerShell-7.0.3-win-x64.msi"
    $localPackagePath = "C:\Users\Public\Downloads"
    $localPackageFilePath = Join-Path $localPackagePath -ChildPath $localPackageFile
    $installationPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    $packageName = "PowerShell7"
    Write-Output "$env:ComputerName: Checking for package $packageName" -Verbose
    If (-not(Test-Path -Path $installationPath))
    {
        Write-Output "Package is not already installed. Installing now" -Verbose
        msiexec.exe /package $localPackageFilePath /qn ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1
    } # end if
    else
    {
        Write-Output "Package $packageName has already been installed" -Verbose
    } # else
#endregion

# Wait for silent MSI installation to complete
Start-Sleep -Seconds 100

# TASK-ITEM: Convert to function?
#region Install pre-requisties and Az.Storage module
If(-not(Get-InstalledModule Az.Storage -ErrorAction SilentlyContinue))
{
    # Set execution policy to allow script execution
    # Set-ExecutionPolicy -ExecutionPolicy unrestricted -Scope CurrentUser -Force
    # Set-ExecutionPolicy -ExecutionPolicy unrestricted -Scope CurrentUser -Force -ErrorAction SilentlyContinue -Verbose

    # Set TLS to 1.2 if required
    Write-Output "Configuring Tls1.2 support."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Install NuGet package provider if required.
    Write-Output "Checking for NuGet package"
    # Install-Module -Name PackageManagement -Force -MinimumVersion 1.4.6 -Scope CurrentUser -AllowClobber
    # nuget may be manually downloaded from https://onegetcdn.azureedge.net/providers/Microsoft.PackageManagement.NuGetProvider-2.8.5.208.dll
    Get-PackageProvider -Name Nuget -Force
    if (!($?))
    {
         Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$False -Force -Verbose
    } # end if
    # Register PS repository and set it to trusted if required
    Write-Output "Checking for PSGallery as the default module repository."
    Get-PSRepository -Name PSGallery
    if (!($?))
    {
        Register-PSRepository -Default -InstallationPolicy Trusted -Verbose
    } # end if
    else
    {
        Get-PSRepository -Name PSGallery -Verbose
    } # end else
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -Verbose
    # Install storage module in current user profile
    Install-Module Az.storage -Confirm:$False -Force -AllowClobber -Scope CurrentUser -Verbose
} # end if
#endregion