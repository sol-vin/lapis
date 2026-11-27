# =============================================================================
# Lapis Toolchain - Windows Standalone Installer
# =============================================================================
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\windows\install.ps1
#   irm https://raw.githubusercontent.com/sol-vin/lapis/master/scripts/windows/install.ps1 | iex
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

# 1. Dependency Resolution & Crystal Environment Configuration
if (-not $SkipDeps) {
    Write-LapisLog "INFO" "Verifying prerequisite tools (Crystal 1.21.0, CRYSTAL_ENV, radare2, Make, Git)..."
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
    $depsScript = if ($scriptDir) { Join-Path $scriptDir "install_deps.ps1" } else { $null }

    if ($depsScript -and (Test-Path $depsScript)) {
        & $depsScript -Tools @("crystal", "radare2", "make", "git") -ConfigureCrystalEnv
    } else {
        # Remote execution or standalone: download install_deps.ps1 from master
        $tempDeps = Join-Path $env:TEMP "lapis_install_deps_$(Get-Random).ps1"
        $depsUrl = "https://raw.githubusercontent.com/sol-vin/lapis/master/scripts/windows/install_deps.ps1"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $depsUrl -OutFile $tempDeps -UseBasicParsing
            & $tempDeps -Tools @("crystal", "radare2", "make", "git") -ConfigureCrystalEnv
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

# 3. Locate or Download lapis.exe and companion GDExtension/CRT DLLs
$foundSource = $null
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
    $localBinDir = Split-Path -Parent $foundSource
    $addonBinDir = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "..\..\addons\crystal_integration\bin"))
    foreach ($dir in @($localBinDir, $addonBinDir)) {
        if ($dir -and (Test-Path $dir)) {
            Get-ChildItem -Path $dir -Filter "*.dll" -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -notmatch "_loaded_" -and $_.Name -ne "game.dll"
            } | ForEach-Object {
                Copy-Item $_.FullName (Join-Path $targetDir $_.Name) -Force
            }
        }
    }
} else {
    Write-LapisLog "INFO" "Downloading latest lapis-windows-x86_64 release..."
    $zipTemp = Join-Path $env:TEMP "lapis_release_temp_$(Get-Random).zip"
    $stageDir = Join-Path $env:TEMP "lapis_stage_temp_$(Get-Random)"
    $downloadUrl = "https://github.com/sol-vin/lapis/releases/latest/download/lapis-windows-x86_64.zip"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipTemp -UseBasicParsing
        Expand-Archive -Path $zipTemp -DestinationPath $stageDir -Force

        $sourceExe = (Get-ChildItem -Path $stageDir -Filter "lapis.exe" -Recurse | Select-Object -First 1).FullName
        if ($sourceExe -and (Test-Path $sourceExe)) {
            Copy-Item $sourceExe $destExe -Force
            # Also stage bundled crystal_bridge.dll, plugin.dll, and CRT DLLs alongside lapis.exe
            Get-ChildItem -Path $stageDir -Filter "*.dll" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item $_.FullName (Join-Path $targetDir $_.Name) -Force
            }
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
if (-not $userPath) { $userPath = "" }
$pathParts = @($userPath.Split(';') | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() })
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
    $pathParts += $targetDir
    $newUserPath = $pathParts -join ";"
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
    Write-Host "  Run 'lapis --version' or 'lapis doctor' to get started." -ForegroundColor Cyan
} else {
    Write-LapisLog "ERROR" "Installation failed: $destExe was not created."
    exit 1
}
Write-Host ""
