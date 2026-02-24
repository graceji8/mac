# setup_windows_desktop.ps1
# This script sets up a virtual display and remote access tools on Windows

$ErrorActionPreference = "Stop"

Write-Host "--- Starting Windows Desktop Setup ---"

# 1. Install Virtual Display Driver (Indirect Display Driver)
Write-Host "Installing Virtual Display Driver..."
$vrootDir = Join-Path $PSScriptRoot "VirtualDisplayDriver"
if (!(Test-Path $vrootDir)) { New-Item -ItemType Directory -Path $vrootDir }

# Attempt winget installation first for better reliability
Write-Host "Trying winget to install Virtual-Display-Driver..."
try {
    winget install --id VirtualDrivers.Virtual-Display-Driver --exact --accept-package-agreements --accept-source-agreements --silent
    Write-Host "Winget installation successful."
}
catch {
    Write-Host "Winget failed or not found. Falling back to direct download."
    $zipUrl = "https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/download/v25.07.23/VirtualDisplayDriver-x86.Driver.Only.zip"
    $zipPath = Join-Path $vrootDir "VirtualDisplayDriver.zip"

    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $vrootDir -Force
}

# Note: In a headless environment, we need to install the certificate first
$certFile = Get-ChildItem -Path $vrootDir -Filter "*.cer" -Recurse | Select-Object -First 1
if ($certFile) {
    Write-Host "Installing driver certificate: $($certFile.FullName)..."
    Import-Certificate -FilePath $certFile.FullName -CertStoreLocation Cert:\LocalMachine\TrustedPublisher
    Import-Certificate -FilePath $certFile.FullName -CertStoreLocation Cert:\LocalMachine\Root
}

# Install NefCon (helper for driver installation if needed, but often silent-install.ps1 is provided)
$setupScript = Get-ChildItem -Path $vrootDir -Filter "silent-install.ps1" -Recurse | Select-Object -First 1
if ($setupScript) {
    Write-Host "Running driver silent-install script: $($setupScript.FullName)..."
    powershell.exe -ExecutionPolicy Bypass -File $setupScript.FullName
}
else {
    $infFile = Get-ChildItem -Path $vrootDir -Filter "*.inf" -Recurse | Select-Object -First 1
    if ($infFile) {
        Write-Host "Attempting manual driver installation via PnPUtil: $($infFile.FullName)..."
        pnputil /add-driver $infFile.FullName /install
    }
    else {
        Write-Error "No .inf or silent-install.ps1 found in driver package."
    }
}

# 2. Configure Resolution (Optional, driver usually defaults to 1080p)
Write-Host "Virtual display should be active. Defaulting to 1920x1080."

# 3. Install NoMachine
Write-Host "Installing NoMachine..."
winget install --id NoMachine.NoMachine --exact --accept-package-agreements --accept-source-agreements --silent

# 4. Setup OpenSSH Server
Write-Host "Configuring OpenSSH Server..."
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# 5. Set Runner Password (for NoMachine/SSH access)
Write-Host "Setting runner password to 'runner'..."
$Password = ConvertTo-SecureString "runner" -AsPlainText -Force
$User = "runneradmin"
Set-LocalUser -Name $User -Password $Password

Write-Host "--- Windows Desktop Setup Complete ---"
