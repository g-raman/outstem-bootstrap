param (
    [switch]$Recommended
    [string]$test
)
Write-Output "$test"

$fileName = "outstem_bootstrap.json"
$filePath = Join-Path -Path $env:USERPROFILE -ChildPath $fileName

# Check if config file exists
if (Test-Path $filePath) {
    Write-Output "Config File found at: $filePath"
}
else {
    Write-Output "Error: Outstem bootstrap config file not found in the home directory."
    exit
}

# Convert config file content to JSON object
$jsonContent = Get-Content -Path $filePath -Raw
$data = $jsonContent | ConvertFrom-Json

$requiredFields = @("githubEmail", "githubUsername", "githubToken", "outstemAwsAccessKeyId", "outstemAwsAccessKeySecret")
$missingFields = $requiredFields | Where-Object { $_ -notin $data.PSObject.Properties.Name }

# Ensure all mandatory fields are present
if ($missingFields.Count -eq 0) {
    Write-Output "All fields exist. Continuing with setup"
}
else {
    Write-Output "The following required fields are missing in your config:"
    Write-Output "$($missingFields -join ', ')."
    exit
}

# Setting up SSH
ssh-keygen -t ed25519 -C $data.githubEmail
Write-Output ""
Write-Output "Add this key below to your GitHub account"
$sshKeyFile = $data.sshKeyLocation + ".pub"
cat $sshKeyFile
Write-Output ""

do {
    $userInput = Read-Host "Type anything to test your connection or 'c' to continue"
    if ($userInput -ieq "c") {
        Write-Output "Continuing with installation"
        break
    }

    ssh -T git@github.com
} while ($true)


# Reset Environment variables
[Environment]::SetEnvironmentVariable("GH_TOKEN", $null, "Machine")
[Environment]::SetEnvironmentVariable("GH_USERNAME", $null, "Machine")
[Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_ID", $null, "Machine")
[Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_SECRET", $null, "Machine")

[Environment]::SetEnvironmentVariable("GH_TOKEN", $null, "User")
[Environment]::SetEnvironmentVariable("GH_USERNAME", $null, "User")
[Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_ID", $null, "User")
[Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_SECRET", $null, "User")

[System.Environment]::SetEnvironmentVariable("GH_TOKEN", $data.githubToken, "Machine")
[System.Environment]::SetEnvironmentVariable("GH_USERNAME", $data.githubUsername, "Machine")
[System.Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_ID", $data.outstemAwsAccessKeyId, "Machine")
[System.Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_SECRET", $data.outstemAwsAccessKeyId, "Machine")

# Add Chocolatey
Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
refreshenv

# Set execution policy to allow script running
Set-ExecutionPolicy Bypass -Scope Process -Force

# Install Chocolatey if not already installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Output "Installing Chocolatey..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Output "Chocolatey installation completed."
}
else {
    Write-Output "Chocolatey is already installed."
}

# List of packages to install
$basePackages = @('git', 'nvm', 'openjdk11', 'maven', 'ruby', 'docker')
$recommendedPackages = @('tabby', 'intellijidea-community', 'dbeaver', 'vscode')

$packages = $basePackages
if ($Recommended) {
    $packages += $recommendedPackages
}

# Install basic packages
foreach ($package in $packages) {
    Write-Output ""
    Write-Output "========================================"
    Write-Output "Installing $package..."
    Write-Output "========================================"
    
    choco install $package -y *>$null

    if ($?) {
        Write-Output "$package installation succeeded."
    }
    else {
        Write-Output "$package installation failed."
    }
    Write-Output ""
}

# Instal Nvm
Write-Output ""
Write-Output "========================================"
Write-Output "Installing node via nvm "
Write-Output "========================================"
nvm use latest *>$null

if ($?) {
    Write-Output "node installation succeeded."
}
else {
    Write-Output "node installation failed."
}
Write-Output ""


# Setup .npmrc for Outstem CLI
Write-Output ""
Write-Output "========================================"
Write-Output "Configuring .npmrc"
Write-Output "========================================"
$npmrcFilename = ".npmrc"
$npmrcFilepath = Join-Path -Path $env:USERPROFILE -ChildPath $npmrcFilename
$npmrcConfig = "@aes-outreach:registry=https://npm.pkg.github.com/
//npm.pkg.github.com/:_authToken=" + $data.githubToken

Add-Content -Path $npmrcFilepath -Value $npmrcConfig
Write-Output ".npmrc configured"

Write-Output ""
Write-Output "========================================"
Write-Output "Install Oustem CLI"
Write-Output "========================================"
npm i -g @aes-outreach/outstem-cli *>$null

if ($?) {
    Write-Output "Outstem CLI installation succeeded."
}
else {
    Write-Output "Outstem CLI installation failed."
}
Write-Output ""

# Enable WSL
Write-Output ""
Write-Output "========================================"
Write-Output "Enabling WSL"
Write-Output "========================================"

# Check if WSL 2 is already enabled
$wsl2Enabled = (dism.exe /Online /Get-FeatureInfo /FeatureName:Microsoft-Windows-Subsystem-Linux-WSL2).State

if ($wsl2Enabled -eq "Enabled") {
    Write-Output "WSL 2 is already enabled."
}
else {
    dism.exe /Online /Enable-Feature /FeatureName:VirtualMachinePlatform /NoRestart *>$null
    dism.exe /Online /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux /NoRestart *>$null

    wsl --set-default-version 2 *>$null
    wsl --install --no-launch *>$null

    if ($?) {
        Write-Output "WSL 2 enabled successfully."
    }
    else {
        Write-Output "WSL setup failed."
    }
}
