param (
    [switch]$Recommended
)

$fileName = "outstem_bootstrap.json"
$filePath = Join-Path -Path $env:USERPROFILE -ChildPath $fileName

# Check if config file exists
if (Test-Path $filePath) {
    Write-Output "Config File found at: $filePath"
} else {
    Write-Output "Error: Outstem bootstrap config file not found in the home directory."
    exit
}

$jsonContent = Get-Content -Path $filePath -Raw
$data = $jsonContent | ConvertFrom-Json

$requiredFields = @("githubEmail", "githubUsername", "githubToken", "outstemAwsAccessKeyId", "outstemAwsAccessKeySecret")
$missingFields = $requiredFields | Where-Object { $_ -notin $data.PSObject.Properties.Name }

if ($missingFields.Count -eq 0) {
    Write-Output "All fields exist."
} else {
    Write-Output "The following required fields are missing in your config:"
    Write-Output "$($missingFields -join ', ')."
    exit
}


# Set execution policy to allow script running
Set-ExecutionPolicy Bypass -Scope Process -Force

# Install Chocolatey if not already installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Output "Installing Chocolatey..."
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Output "Chocolatey installation completed."
} else {
    Write-Output "Chocolatey is already installed."
}


[Environment]::SetEnvironmentVariable("TEST", "NEW TEST", [System.EnvironmentVariableTarget]::Machine)
Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
refreshenv


# List of packages to install
$basePackages = @('git', 'nvm', 'openjdk11', 'maven', 'ruby', 'docker-desktop')
$recommendedPackages = @('tabby', 'intellijidea-community', 'dbeaver', 'vscode')

$packages = $basePackages
if ($Recommended) {
    $packages += $recommendedPackages
}

foreach ($package in $packages) {
    Write-Output ""
    Write-Output "========================================"
    Write-Output "Installing $package..."
    Write-Output "========================================"
    
    choco install $package -y *>$null

    if ($?) {
        Write-Output "$package installation succeeded."
    } else {
        Write-Output "$package installation failed."
    }
    Write-Output ""
}

Write-Output "All installations completed."

Write-Output ""
Write-Output "========================================"
Write-Output "Installing node via nvm "
Write-Output "========================================"
nvm use latest *>$null

if ($?) {
    Write-Output "node installation succeeded."
} else {
    Write-Output "node installation failed."
}
Write-Output ""


Write-Output ""
Write-Output "========================================"
Write-Output "Enabling WSL"
Write-Output "========================================"
Write-Output ""

# Check if WSL 2 is already enabled
$wsl2Enabled = (dism.exe /Online /Get-FeatureInfo /FeatureName:Microsoft-Windows-Subsystem-Linux-WSL2).State

if ($wsl2Enabled -eq "Enabled") {
    Write-Output "WSL 2 is already enabled."
} else {
    dism.exe /Online /Enable-Feature /FeatureName:VirtualMachinePlatform /NoRestart *>$null
    dism.exe /Online /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux /NoRestart *>$null

    wsl --set-default-version 2 *>$null
    wsl --install --no-launch *>$null

    if ($?) {
        Write-Output "WSL 2 enabled successfully."
    } else {
        Write-Output "WSL setup failed."
    }
}
