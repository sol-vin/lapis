# =============================================================================
# Lapis Toolchain - Windows Dependency Installer
# =============================================================================
# Detects and installs required dependencies for Lapis on Windows:
#   - Crystal compiler (crystal.exe)
#   - LLDB / LLVM debugger (lldb.exe)
#   - GNU Make (make.exe)
#   - Git (git.exe)
#   - Crystalline LSP (crystalline.exe)
#   - Inno Setup Compiler (iscc.exe)
# =============================================================================

[CmdletBinding()]
param (
    [string[]]$Tools = @("crystal", "lldb", "make", "git", "crystalline", "innosetup"),
    [switch]$Silent,
    [switch]$Force
)

$ErrorActionPreference = "Continue"

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

function Test-ExecutableExists {
    param ([string]$CommandName, [string[]]$ExtraPaths = @())
    
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        return (Get-Command $CommandName).Source
    }
    
    foreach ($path in $ExtraPaths) {
        if ($path -and (Test-Path $path)) {
            return (Resolve-Path $path).Path
        }
    }
    return $null
}

function Refresh-EnvironmentPath {
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    $env:Path = "$userPath;$machinePath"
}

# --- Detection Functions ---

function Find-Crystal {
    $userProfile = $env:USERPROFILE
    $candidates = @(
        "$userProfile\scoop\apps\crystal\current\bin\crystal.exe",
        "C:\Program Files\Crystal\bin\crystal.exe",
        "C:\Crystal\bin\crystal.exe"
    )
    return Test-ExecutableExists -CommandName "crystal.exe" -ExtraPaths $candidates
}

function Find-Lldb {
    $userProfile = $env:USERPROFILE
    $candidates = @(
        "C:\Program Files\LLVM\bin\lldb.exe",
        "C:\Program Files (x86)\LLVM\bin\lldb.exe",
        "C:\ProgramData\llvm\bin\lldb.exe",
        "$userProfile\scoop\apps\llvm\current\bin\lldb.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\bin\lldb.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\Llvm\bin\lldb.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\Llvm\bin\lldb.exe",
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\Llvm\bin\lldb.exe"
    )
    return Test-ExecutableExists -CommandName "lldb.exe" -ExtraPaths $candidates
}

function Find-Make {
    $userProfile = $env:USERPROFILE
    $candidates = @(
        "$userProfile\scoop\apps\make\current\make.exe",
        "C:\Program Files (x86)\GnuWin32\bin\make.exe",
        "C:\Program Files\Git\usr\bin\make.exe",
        "C:\msys64\usr\bin\make.exe",
        "C:\msys64\mingw64\bin\mingw32-make.exe"
    )
    $found = Test-ExecutableExists -CommandName "make.exe" -ExtraPaths $candidates
    if (-not $found) {
        $found = Test-ExecutableExists -CommandName "mingw32-make.exe"
    }
    return $found
}

function Find-Git {
    $candidates = @(
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files\Git\bin\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )
    return Test-ExecutableExists -CommandName "git.exe" -ExtraPaths $candidates
}

function Find-Crystalline {
    $userProfile = $env:USERPROFILE
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Lapis\bin\crystalline.exe",
        "$userProfile\scoop\shims\crystalline.exe",
        "$userProfile\scoop\apps\crystalline\current\crystalline.exe",
        "C:\Program Files\crystalline\bin\crystalline.exe",
        "C:\crystalline\bin\crystalline.exe",
        "C:\Program Files\Lapis\bin\crystalline.exe"
    )
    return Test-ExecutableExists -CommandName "crystalline.exe" -ExtraPaths $candidates
}

function Find-InnoSetup {
    $userProfile = $env:USERPROFILE
    $localAppData = $env:LOCALAPPDATA
    $candidates = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 7\ISCC.exe",
        "C:\Program Files\Inno Setup 7\ISCC.exe",
        "$localAppData\Programs\Inno Setup 6\ISCC.exe",
        "$localAppData\Programs\Inno Setup 7\ISCC.exe",
        "$userProfile\scoop\apps\innosetup\current\ISCC.exe",
        "C:\ProgramData\chocolatey\bin\iscc.exe"
    )
    $found = Test-ExecutableExists -CommandName "iscc.exe" -ExtraPaths $candidates
    if (-not $found) {
        $found = Test-ExecutableExists -CommandName "iscc" -ExtraPaths $candidates
    }
    return $found
}

# --- Installation Methods ---

$hasWinget = (Get-Command winget.exe -ErrorAction SilentlyContinue) -ne $null
$hasScoop = (Get-Command scoop -ErrorAction SilentlyContinue) -ne $null -or (Test-Path "$env:USERPROFILE\scoop\shims\scoop.ps1")

function Install-WithWinget {
    param (
        [string]$PackageId,
        [string]$DisplayName
    )
    Write-LapisLog "INFO" "Installing $DisplayName via winget ($PackageId)..."
    $wingetArgs = @("install", "--id", $PackageId, "--exact", "--accept-package-agreements", "--accept-source-agreements")
    if ($Silent) {
        $wingetArgs += "--silent"
    }
    $proc = Start-Process -FilePath "winget.exe" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
    return ($proc.ExitCode -eq 0)
}

function Install-WithScoop {
    param (
        [string]$PackageName,
        [string]$DisplayName
    )
    Write-LapisLog "INFO" "Installing $DisplayName via Scoop ($PackageName)..."
    $scoopCmd = if (Get-Command scoop -ErrorAction SilentlyContinue) { "scoop" } else { "$env:USERPROFILE\scoop\shims\scoop.ps1" }
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "& $scoopCmd install $PackageName") -Wait -PassThru -NoNewWindow
    return ($proc.ExitCode -eq 0)
}

# --- Execution ---

Write-LapisLog "INFO" "=== Lapis Toolchain Windows Dependency Verifier ==="
Refresh-EnvironmentPath

$results = @{}

foreach ($tool in $Tools) {
    $toolLower = $tool.ToLower().Trim()
    
    switch ($toolLower) {
        "crystal" {
            $existing = Find-Crystal
            if ($existing -and -not $Force) {
                Write-LapisLog "SUCCESS" "Crystal is already installed at: $existing"
                $results["crystal"] = $true
            } else {
                Write-LapisLog "WARN" "Crystal compiler not found. Initiating automated installation..."
                $installed = $false
                if ($hasWinget) {
                    $installed = Install-WithWinget -PackageId "CrystalLang.Crystal" -DisplayName "Crystal Compiler"
                }
                if (-not $installed -and $hasScoop) {
                    $installed = Install-WithScoop -PackageName "crystal" -DisplayName "Crystal Compiler"
                }
                if (-not $installed) {
                    Write-LapisLog "INFO" "Downloading official Crystal Windows installer..."
                    $tmpExe = Join-Path $env:TEMP "crystal-installer.exe"
                    $url = "https://github.com/crystal-lang/crystal/releases/download/1.15.1/crystal-1.15.1-1-windows-x86_64-msvc.exe"
                    try {
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Invoke-WebRequest -Uri $url -OutFile $tmpExe -UseBasicParsing
                        $proc = Start-Process -FilePath $tmpExe -ArgumentList @("/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES") -Wait -PassThru
                        $installed = ($proc.ExitCode -eq 0)
                    } catch {
                        Write-LapisLog "ERROR" "Failed to download/run Crystal installer: $_"
                    } finally {
                        Remove-Item $tmpExe -Force -ErrorAction SilentlyContinue
                    }
                }
                Refresh-EnvironmentPath
                $verified = Find-Crystal
                if ($verified) {
                    Write-LapisLog "SUCCESS" "Crystal successfully installed at: $verified"
                    $results["crystal"] = $true
                } else {
                    Write-LapisLog "ERROR" "Crystal installation could not be verified in PATH."
                    $results["crystal"] = $false
                }
            }
        }

        "lldb" {
            $existing = Find-Lldb
            if ($existing -and -not $Force) {
                Write-LapisLog "SUCCESS" "LLDB debugger is already installed at: $existing"
                $results["lldb"] = $true
            } else {
                Write-LapisLog "WARN" "LLDB debugger not found. Initiating LLVM automated installation..."
                $installed = $false
                if ($hasWinget) {
                    $installed = Install-WithWinget -PackageId "LLVM.LLVM" -DisplayName "LLVM & LLDB Debugger"
                }
                if (-not $installed -and $hasScoop) {
                    $installed = Install-WithScoop -PackageName "llvm" -DisplayName "LLVM & LLDB Debugger"
                }
                Refresh-EnvironmentPath
                $verified = Find-Lldb
                if ($verified) {
                    Write-LapisLog "SUCCESS" "LLDB successfully verified at: $verified"
                    $results["lldb"] = $true
                } else {
                    Write-LapisLog "ERROR" "LLDB installation could not be verified in PATH."
                    $results["lldb"] = $false
                }
            }
        }

        "make" {
            $existing = Find-Make
            if ($existing -and -not $Force) {
                Write-LapisLog "SUCCESS" "GNU Make is already installed at: $existing"
                $results["make"] = $true
            } else {
                Write-LapisLog "WARN" "GNU Make not found. Initiating automated installation..."
                $installed = $false
                if ($hasWinget) {
                    $installed = Install-WithWinget -PackageId "ezwinports.make" -DisplayName "GNU Make"
                    if (-not $installed) {
                        $installed = Install-WithWinget -PackageId "GnuWin32.Make" -DisplayName "GnuWin32 Make"
                    }
                }
                if (-not $installed -and $hasScoop) {
                    $installed = Install-WithScoop -PackageName "make" -DisplayName "GNU Make"
                }
                Refresh-EnvironmentPath
                $verified = Find-Make
                if ($verified) {
                    Write-LapisLog "SUCCESS" "GNU Make successfully verified at: $verified"
                    $results["make"] = $true
                } else {
                    Write-LapisLog "ERROR" "GNU Make installation could not be verified in PATH."
                    $results["make"] = $false
                }
            }
        }

        "git" {
            $existing = Find-Git
            if ($existing -and -not $Force) {
                Write-LapisLog "SUCCESS" "Git is already installed at: $existing"
                $results["git"] = $true
            } else {
                Write-LapisLog "WARN" "Git not found. Initiating automated installation..."
                $installed = $false
                if ($hasWinget) {
                    $installed = Install-WithWinget -PackageId "Git.Git" -DisplayName "Git for Windows"
                }
                if (-not $installed -and $hasScoop) {
                    $installed = Install-WithScoop -PackageName "git" -DisplayName "Git for Windows"
                }
                Refresh-EnvironmentPath
                $verified = Find-Git
                if ($verified) {
                    Write-LapisLog "SUCCESS" "Git successfully verified at: $verified"
                    $results["git"] = $true
                } else {
                    Write-LapisLog "ERROR" "Git installation could not be verified in PATH."
                    $results["git"] = $false
                }
            }
        }

        "crystalline" {
            $existing = Find-Crystalline
            if ($existing -and -not $Force) {
                Write-LapisLog "SUCCESS" "Crystalline LSP is already installed at: $existing"
                $results["crystalline"] = $true
            } else {
                Write-LapisLog "WARN" "Crystalline LSP not found. Initiating automated download from GitHub releases..."
                $installed = $false

                $targetDir = Join-Path $env:LOCALAPPDATA "Programs\Lapis\bin"
                if (-not (Test-Path $targetDir)) {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                }
                $destExe = Join-Path $targetDir "crystalline.exe"

                # Check if local build or repository artifact exists
                $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
                $repoRoot = if ($scriptDir) { Split-Path -Parent (Split-Path -Parent $scriptDir) } else { $null }
                $localCandidates = @(
                    (if ($repoRoot) { Join-Path $repoRoot "bin\crystalline.exe" } else { $null }),
                    (if ($repoRoot) { Join-Path $repoRoot "scratch\crystalline\bin\crystalline.exe" } else { $null })
                )
                foreach ($cand in $localCandidates) {
                    if ($cand -and (Test-Path $cand)) {
                        Copy-Item $cand $destExe -Force
                        $installed = $true
                        Write-LapisLog "INFO" "Configured Crystalline LSP from local artifact: $cand"
                        break
                    }
                }

                if (-not $installed) {
                    Write-LapisLog "INFO" "Downloading Crystalline binary from GitHub releases..."
                    $releaseUrl = "https://github.com/elbywan/crystalline/releases/latest/download/crystalline_x86_64-windows.zip"
                    $tmpZip = Join-Path $env:TEMP "crystalline_release_$(Get-Random).zip"
                    $stageDir = Join-Path $env:TEMP "crystalline_stage_$(Get-Random)"
                    try {
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Invoke-WebRequest -Uri $releaseUrl -OutFile $tmpZip -UseBasicParsing
                        Expand-Archive -Path $tmpZip -DestinationPath $stageDir -Force
                        $extractedExe = (Get-ChildItem -Path $stageDir -Filter "crystalline.exe" -Recurse | Select-Object -First 1).FullName
                        if ($extractedExe -and (Test-Path $extractedExe)) {
                            Copy-Item $extractedExe $destExe -Force
                            $installed = $true
                        }
                    } catch {
                        Write-LapisLog "WARN" "Direct release archive download failed: $_"
                    } finally {
                        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
                        Remove-Item $stageDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }

                # Ensure targetDir is registered in User PATH
                $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
                if ($userPath -notmatch [regex]::Escape($targetDir)) {
                    [Environment]::SetEnvironmentVariable("Path", "$userPath;$targetDir", [EnvironmentVariableTarget]::User)
                }

                Refresh-EnvironmentPath
                $verified = Find-Crystalline
                if ($verified) {
                    Write-LapisLog "SUCCESS" "Crystalline LSP successfully verified at: $verified"
                    $results["crystalline"] = $true
                } else {
                    Write-LapisLog "ERROR" "Crystalline LSP installation could not be verified in PATH."
                    $results["crystalline"] = $false
                }
            }
        }

        "innosetup" {
            $existing = Find-InnoSetup
            if ($existing -and -not $Force) {
                Write-LapisLog "SUCCESS" "Inno Setup Compiler is already installed at: $existing"
                $results["innosetup"] = $true
            } else {
                Write-LapisLog "WARN" "Inno Setup Compiler not found. Initiating automated installation..."
                $installed = $false

                # 1. Check if installer executable was staged alongside this script (in {tmp} or stage dir)
                $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
                $bundledCandidates = @(
                    (if ($scriptDir) { Join-Path $scriptDir "innosetup-installer.exe" } else { $null }),
                    (if ($scriptDir) { Join-Path $scriptDir "innosetup-setup.exe" } else { $null }),
                    (Join-Path $env:TEMP "innosetup-installer.exe")
                )
                foreach ($cand in $bundledCandidates) {
                    if ($cand -and (Test-Path $cand)) {
                        Write-LapisLog "INFO" "Running staged Inno Setup installer from $cand..."
                        $proc = Start-Process -FilePath $cand -ArgumentList @("/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES") -Wait -PassThru
                        $installed = ($proc.ExitCode -eq 0)
                        if ($installed) { break }
                    }
                }

                # 2. Try winget
                if (-not $installed -and $hasWinget) {
                    $installed = Install-WithWinget -PackageId "JRSoftware.InnoSetup" -DisplayName "Inno Setup Compiler"
                }

                # 3. Try scoop
                if (-not $installed -and $hasScoop) {
                    $installed = Install-WithScoop -PackageName "innosetup" -DisplayName "Inno Setup Compiler"
                }

                # 4. Fallback to direct official installer download
                if (-not $installed) {
                    Write-LapisLog "INFO" "Downloading official Inno Setup installer from jrsoftware.org..."
                    $tmpExe = Join-Path $env:TEMP "innosetup-installer.exe"
                    $url = "https://files.jrsoftware.org/is/6/innosetup-6.3.3.exe"
                    try {
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Invoke-WebRequest -Uri $url -OutFile $tmpExe -UseBasicParsing
                        $proc = Start-Process -FilePath $tmpExe -ArgumentList @("/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES") -Wait -PassThru
                        $installed = ($proc.ExitCode -eq 0)
                    } catch {
                        Write-LapisLog "ERROR" "Failed to download/run Inno Setup installer: $_"
                    } finally {
                        Remove-Item $tmpExe -Force -ErrorAction SilentlyContinue
                    }
                }

                Refresh-EnvironmentPath
                $verified = Find-InnoSetup
                if ($verified) {
                    # Ensure directory containing ISCC.exe is in user's PATH so 'iscc' command works everywhere
                    $isccDir = Split-Path -Parent $verified
                    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
                    if ($userPath -notmatch [regex]::Escape($isccDir)) {
                        [Environment]::SetEnvironmentVariable("Path", "$userPath;$isccDir", [EnvironmentVariableTarget]::User)
                    }
                    Refresh-EnvironmentPath
                    Write-LapisLog "SUCCESS" "Inno Setup Compiler successfully installed at: $verified"
                    $results["innosetup"] = $true
                } else {
                    Write-LapisLog "ERROR" "Inno Setup Compiler installation could not be verified in PATH or standard directories."
                    $results["innosetup"] = $false
                }
            }
        }
    }
}

Refresh-EnvironmentPath
Write-LapisLog "SUCCESS" "Dependency verification completed."
exit 0
