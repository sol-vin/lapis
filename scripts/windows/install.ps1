# =============================================================================
# Lapis Toolchain - Windows Standalone Installer
# =============================================================================
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\windows\install.ps1
#   irm https://raw.githubusercontent.com/sol-vin/lapis/main/scripts/windows/install.ps1 | iex
# =============================================================================

[CmdletBinding()]
param (
    [string]$InstallDir = "",
    [switch]$SkipDeps,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-LapisHeader {
    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Magenta
    Write-Host "   Lapis: Unified Crystal Engine Toolchain for Godot - Windows Setup   " -ForegroundColor Magenta
    Write-Host "========================================================================" -ForegroundColor Magenta
    Write-Host ""
}

function Write-LapisLog {
    param (
        [string]$Level,
        [string]$Message
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Level) {
        "INFO"    { Write-Host "[$timestamp] [INFO]    $Message" -ForegroundColor Cyan }
        "SUCCESS" { Write-Host "[$timestamp] [SUCCESS] $Message" -ForegroundColor Green }
        "WARN"    { Write-Host "[$timestamp] [WARN]    $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "[$timestamp] [ERROR]   $Message" -ForegroundColor Red }
        default   { Write-Host "[$timestamp] $Message" }
    }
}

Write-LapisHeader

# 1. Dependency Resolution
if (-not $SkipDeps) {
    Write-LapisLog "INFO" "Verifying prerequisite tools (Crystal, LLDB, Make, Git, Crystalline)..."
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
    $depsScript = if ($scriptDir) { Join-Path $scriptDir "install_deps.ps1" } else { $null }

    if ($depsScript -and (Test-Path $depsScript)) {
        & $depsScript -Tools @("crystal", "lldb", "make", "git", "crystalline")
    } else {
        # Remote execution or standalone: download install_deps.ps1
        $tempDeps = Join-Path $env:TEMP "lapis_install_deps_$(Get-Random).ps1"
        $depsUrl = "https://raw.githubusercontent.com/sol-vin/lapis/main/scripts/windows/install_deps.ps1"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $depsUrl -OutFile $tempDeps -UseBasicParsing
            & $tempDeps -Tools @("crystal", "lldb", "make", "git", "crystalline")
        } catch {
            Write-LapisLog "WARN" "Could not execute automated dependency installer. Proceeding with Lapis installation..."
        } finally {
            Remove-Item $tempDeps -Force -ErrorAction SilentlyContinue
        }
    }
}

# 2. Determine Installation Directory
if (-not $InstallDir) {
    $InstallDir = Join-Path $env:LOCALAPPDATA "Programs\Lapis\bin"
}
$targetDir = [System.IO.Path]::GetFullPath($InstallDir)
$destExe = Join-Path $targetDir "lapis.exe"

Write-LapisLog "INFO" "Target installation path: $destExe"
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# 3. Locate or Download lapis.exe
$foundSource = $null

# Check local repository builds first
$repoRoot = $PSScriptRoot
if ($repoRoot) {
    $candidate1 = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "..\..\bin\lapis.exe"))
    $candidate2 = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "..\..\bin\windows\lapis.exe"))
    if (Test-Path $candidate1) { $foundSource = $candidate1 }
    elseif (Test-Path $candidate2) { $foundSource = $candidate2 }
}

if ($foundSource) {
    Write-LapisLog "INFO" "Installing from local binary: $foundSource"
    Copy-Item $foundSource $destExe -Force
} else {
    Write-LapisLog "INFO" "Downloading latest lapis-windows-x86_64 release..."
    $zipTemp = Join-Path $env:TEMP "lapis_release_temp.zip"
    $stageDir = Join-Path $env:TEMP "lapis_stage_temp"
    $downloadUrl = "https://github.com/sol-vin/lapis/releases/latest/download/lapis-windows-x86_64.zip"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipTemp -UseBasicParsing
        Expand-Archive -Path $zipTemp -DestinationPath $stageDir -Force
        
        $sourceExe = (Get-ChildItem -Path $stageDir -Filter "lapis.exe" -Recurse | Select-Object -First 1).FullName
        if ($sourceExe -and (Test-Path $sourceExe)) {
            Copy-Item $sourceExe $destExe -Force
        } else {
            throw "lapis.exe was not found inside downloaded archive."
        }
    } catch {
        Write-LapisLog "ERROR" "Failed to download Lapis release archive: $_"
        exit 1
    } finally {
        Remove-Item $zipTemp -Force -ErrorAction SilentlyContinue
        Remove-Item $stageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 4. Configure User PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
$pathParts = $userPath.Split(';') | Where-Object { $_.Trim() -ne "" }
$normalizedTarget = $targetDir.TrimEnd('\').ToLower()

$alreadyInPath = $false
foreach ($p in $pathParts) {
    if ($p.TrimEnd('\').ToLower() -eq $normalizedTarget) {
        $alreadyInPath = $true
        break
    }
}

if (-not $alreadyInPath) {
    Write-LapisLog "INFO" "Adding $targetDir to User PATH environment variable..."
    $newUserPath = "$userPath;$targetDir"
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, [EnvironmentVariableTarget]::User)
    $env:Path = "$env:Path;$targetDir"
    Write-LapisLog "SUCCESS" "PATH successfully updated."
} else {
    Write-LapisLog "SUCCESS" "Installation directory is already in User PATH."
}

# 5. Verification
Write-Host ""
if (Test-Path $destExe) {
    Write-LapisLog "SUCCESS" "Lapis CLI installed successfully!"
    Write-Host "  Binary Location: " -NoNewline; Write-Host $destExe -ForegroundColor Green
    Write-Host "  Run 'lapis --version' or 'lapis help' to get started." -ForegroundColor Cyan
} else {
    Write-LapisLog "ERROR" "Installation failed: $destExe was not created."
    exit 1
}
Write-Host ""
