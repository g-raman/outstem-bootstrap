param(
  [switch]$Recommended,
  [switch]$SkipSSH,
  [switch]$SkipEnv,
  [switch]$SkipWSL,
  [switch]$SkipDeps,
  [switch]$SkipRepos
)

function Write-SuccessMessage {
  param(
    [string]$Message
  )
  Write-Host $Message -ForegroundColor Green
}

function Write-ErrorMessage {
  param(
    [string]$Message
  )
  Write-Host $Message -ForegroundColor Red
}

function Write-InfoMessage {
  param(
    [string]$Message
  )
  Write-Host $Message -ForegroundColor Cyan
}

function Write-Header {
  param(
    [string]$Message
  )
  Write-Output "========================================"
  Write-Output "$Message"
  Write-Output "========================================"
}

function Invoke-CommandIf {
  param(
    [boolean]$condition,
    [string]$message,
    [string]$command
  )

  if ($condition) {
    Write-InfoMessage $message
    Write-Output ""
  } else {
    Invoke-Expression $command
  }
}

function Write-MessageIfError () {
  param(
    [string]$successMessage,
    [string]$errorMessage
  )

  if ($?) {
    Write-SuccessMessage $successMessage
  } else {
    Write-ErrorMessage $errorMessage
  }
  Write-Output ""
}

$fileName = "outstem_bootstrap.json"
$filePath = Join-Path -Path $env:USERPROFILE -ChildPath $fileName

# Check if config file exists
Write-Header "Looking for config file"
if (Test-Path $filePath) {
  Write-SuccessMessage "Config file found at: $filePath"
}
else {
  Write-ErrorMessage "Error: Outstem bootstrap config file not found in the home directory."
  exit
}
Write-Output ""

# Convert config file content to JSON object
$jsonContent = Get-Content -Path $filePath -Raw
$data = $jsonContent | ConvertFrom-Json

$requiredFields = @("githubEmail","githubUsername","githubToken","outstemAwsAccessKeyId","outstemAwsAccessKeySecret")
$missingFields = $requiredFields | Where-Object { $_ -notin $data.PSObject.Properties.Name }

# Ensure all mandatory fields are present
Write-Header "Ensuring all fields Exist"
if ($missingFields.Count -eq 0) {
  Write-SuccessMessage "All fields exist. Continuing with setup"
}
else {
  Write-ErrorMessage "The following required fields are missing in your config:"
  Write-ErrorMessage "$($missingFields -join ', ')."
  exit
}
Write-Output ""

# Setting up SSH
function setupSSH () {
  Write-Header "Setting up SSH"
  ssh-keygen -t ed25519 -C $data.githubEmail
  Write-Output ""

  Write-Output "On GitHub, go to Settings > SSH and GPG keys > New SSH key."
  Write-Output "Add a title to describe the key like 'Work laptop'"
  Write-Output "Paste the key below in the 'key' area and add the key."

  $sshKeyFile = Join-Path -Path $env:USERPROFILE -ChildPath ".ssh/id_ed25519.pub"
  $sshKey = Get-Content "$sshKeyFile" -Raw
  Write-InfoMessage $sshKey

  do {
    Write-Output ""
    $userInput = Read-Host "Type anything to test your connection or 'c' to continue"
    if ($userInput -ieq "c") {
      Write-Output "Continuing with installation"
      break
    }

    ssh -t git@github.com
  } while ($true)
  Write-Output ""
}

Invoke-CommandIf $SkipSSH "Skipping SSH Setup" "setupSSH"

function setupEnv () {
  Write-Header "Setting up environment variables"
  # Reset Environment variables
  [Environment]::SetEnvironmentVariable("GH_TOKEN",$null,"Machine")
  [Environment]::SetEnvironmentVariable("GH_USERNAME",$null,"Machine")
  [Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_ID",$null,"Machine")
  [Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_SECRET",$null,"Machine")

  [Environment]::SetEnvironmentVariable("GH_TOKEN",$null,"User")
  [Environment]::SetEnvironmentVariable("GH_USERNAME",$null,"User")
  [Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_ID",$null,"User")
  [Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_SECRET",$null,"User")

  # Add environment variables
  [System.Environment]::SetEnvironmentVariable("GH_TOKEN",$data.githubToken,"Machine")
  [System.Environment]::SetEnvironmentVariable("GH_USERNAME",$data.githubUsername,"Machine")
  [System.Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_ID",$data.outstemAwsAccessKeyId,"Machine")
  [System.Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_SECRET",$data.outstemAwsAccessKeyId,"Machine")
  Write-SuccessMessage "Environment variables are set"
  Write-Output ""
}

Invoke-CommandIf $SkipEnv "Skipping Environment variable Setup" "setupEnv"

function setupDeps () {
  # Add Chocolatey
  Write-Header "Installing Chocolatey"
  Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
  refreshenv *> $null

  # Set execution policy to allow script running
  Set-ExecutionPolicy Bypass -Scope Process -Force

  # Install Chocolatey if not already installed
  if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-SuccessMessage "Chocolatey installation completed."
  }
  else {
    Write-SuccessMessage "Chocolatey is already installed."
  }

  # List of packages to install
  $basePackages = @('git','nvm','openjdk11','maven','ruby','docker')
  $recommendedPackages = @('tabby','intellijidea-community','dbeaver','vscode')

  $packages = $basePackages
  if ($Recommended) {
    $packages += $recommendedPackages
  }

  # Install basic packages
  foreach ($package in $packages) {
    Write-Output ""
    Write-Header "Install $package..."

    choco install $package -y *> $null

    Write-MessageIfError "$package installation succeeded" "$package installation failed"
  }
  refreshenv *> $null


  # Instal Nvm
  Write-Header "Installing node via nvm "
  nvm install latest
  nvm use latest

  Write-MessageIfError "Node installation succeeded" "Node installation failed"
  refreshenv *> $null

  # Setup .npmrc for Outstem CLI
  Write-Header "Configuring .npmrc"
  $npmrcFilename = ".npmrc"
  $npmrcFilepath = Join-Path -Path $env:USERPROFILE -ChildPath $npmrcFilename
  $npmrcConfig = "@aes-outreach:registry=https://npm.pkg.github.com/
    //npm.pkg.github.com/:_authToken=" + $data.githubToken

  Add-Content -Path $npmrcFilepath -Value $npmrcConfig
  Write-MessageIfError "npmrc setup succeeded" "npmrc setup failed"

  Write-Header "Install Oustem CLI"
  npm i -g @aes-outreach/outstem-cli *> $null

  Write-MessageIfError "Oustem CLI installation succeeded" "Outstem CLI installation failed"

  Write-Header "Installing Yarn"
  npm i -g yarn *> $null

  Write-MessageIfError "Yarn installed successfully" "Yarn installation failed"
}

Invoke-CommandIf $SkipDeps "Skipping installation of dependencies" "setupDeps"
refreshenv *> $null

function setupRepos () {
  Write-Header "Setting up outreach codebase"
  $outreachPath = Join-Path -Path $env:USERPROFILE -ChildPath "outstem"
  if (-not (Test-Path -Path $outreachPath)) {
    mkdir $outreachPath
  }
  Set-Location $outreachPath
  outstem init
}

Invoke-CommandIf $SkipRepos "Skipping Codebase setup" "setupRepos"

function setupWSL () {
  # Enable WSL
  Write-Header "Enabling WSL"

  # Check if WSL 2 is already enabled
  $wsl2Enabled = (dism.exe /Online /Get-FeatureInfo /FeatureName:Microsoft-Windows-Subsystem-Linux-WSL2).State

  if ($wsl2Enabled -eq "Enabled") {
    Write-Output "WSL 2 is already enabled."
  }
  else {
    dism.exe /Online /Enable-Feature /FeatureName:VirtualMachinePlatform /NoRestart *> $null
    dism.exe /Online /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux /NoRestart *> $null

    wsl --set-default-version 2 *> $null
    wsl --install --no-launch *> $null

    Write-MessageIfError "WSL 2 enabled successfulyy" "WSL setup failed"
  }
}

Invoke-CommandIf $SkipWSL "Skipping WSL setup" "setupWSL"

