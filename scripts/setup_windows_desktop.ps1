# setup_windows_desktop.ps1
# This script sets up a virtual display and remote access tools on Windows

$ErrorActionPreference = "Stop"

Write-Host "--- Starting Windows Desktop Setup ---"

# 1. Install Virtual Display Driver (Indirect Display Driver)
Write-Host "Installing Virtual Display Driver..."
$vrootDir = Join-Path $PSScriptRoot "VirtualDisplayDriver"
if (!(Test-Path $vrootDir)) { New-Item -ItemType Directory -Path $vrootDir }

$zipUrl = "https://github.com/itsmikethetech/Virtual-Display-Driver/releases/download/v2.3/VirtualDisplayDriver.zip"
$zipPath = Join-Path $vrootDir "VirtualDisplayDriver.zip"

Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $vrootDir -Force

# Note: In a headless environment, we need to install the certificate first
$certPath = Join-Path $vrootDir "VirtualDisplayDriver.cer"
if (Test-Path $certPath) {
    Write-Host "Installing driver certificate..."
    Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\TrustedPublisher
    Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root
}

# Install NefCon (helper for driver installation if needed, but often silent-install.ps1 is provided)
$setupScript = Join-Path $vrootDir "silent-install.ps1"
if (Test-Path $setupScript) {
    Write-Host "Running driver silent-install script..."
    powershell.exe -ExecutionPolicy Bypass -File $setupScript
}
else {
    Write-Host "Attempting manual driver installation via PnPUtil..."
    pnputil /add-driver "$vrootDir\IddSampleDriver.inf" /install
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
