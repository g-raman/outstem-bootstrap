Set-ExecutionPolicy Bypass -Scope Process -Force

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

# Uninstall all packages
Write-Header "Uninstalling packages"
$packages = @('git','nvm','openjdk11','maven','ruby','docker', 'tabby','intellijidea-community','dbeaver','vscode')
foreach ($package in $packages) {
  Write-Output ""
  Write-Header "Uninstalling $package..."

  # -y agrees to all questions
  # -x removes all dependencies
  choco uninstall $package -y -x *> $null

  Write-MessageIfError "$package uninstallation succeeded" "$package uninstallation failed"
}
refreshenv *> $null

# Reset environment variables
Write-Header "Resetting environment variables"
[Environment]::SetEnvironmentVariable("GH_TOKEN",$null,"Machine")
[Environment]::SetEnvironmentVariable("GH_USERNAME",$null,"Machine")
[Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_ID",$null,"Machine")
[Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_SECRET",$null,"Machine")

[Environment]::SetEnvironmentVariable("GH_TOKEN",$null,"User")
[Environment]::SetEnvironmentVariable("GH_USERNAME",$null,"User")
[Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_ID",$null,"User")
[Environment]::SetEnvironmentVariable("OUTSTEM_AWS_ACCESS_KEY_SECRET",$null,"User")
Write-SuccessMessage "Environment variables reset"

Write-Header "Clearing SSH keys"
$homePath = [System.Environment]::GetFolderPath("UserProfile")
$sshPath = Join-path -Path $homePath -ChildPath ".ssh\*"
Remove-Item -Path $sshPath -Force -Recurse
Write-MessageIfError "Something went wrong when removing ssh keys" "SSH keys removed successfully" 
