# =============================================================================
# Lapis Toolchain - Windows Dependency & Crystal Environment Installer
# =============================================================================
# Detects, installs, and configures required dependencies for Lapis on Windows:
#   - Crystal compiler 1.21.0 (crystal.exe + CRYSTAL_ENV & crystal env vars)
#   - MSVC C++ Build Tools & vswhere.exe (vctools)
#   - radare2 native debugger (radare2.exe)
#   - GNU Make (make.exe)
#   - Git (git.exe)
#   - Crystalline LSP (crystalline.exe)
#   - Inno Setup Compiler (iscc.exe)
# =============================================================================

[CmdletBinding()]
param (
    [string[]]$Tools = @("crystal", "vctools", "radare2", "make", "git", "crystalline", "innosetup"),
    [switch]$ConfigureCrystalEnv,
    [switch]$Silent,
    [switch]$Force
)

$ErrorActionPreference = "Continue"

$TargetCrystalVersion = "1.21.0"
$MinCrystalVersion = [version]"1.20.0"
$CrystalZipUrl = "https://github.com/crystal-lang/crystal/releases/download/$TargetCrystalVersion/crystal-$TargetCrystalVersion-windows-x86_64-msvc-unsupported.zip"
$CrystalExeUrl = "https://github.com/crystal-lang/crystal/releases/download/$TargetCrystalVersion/crystal-$TargetCrystalVersion-windows-x86_64-msvc-unsupported.exe"
$VsWhereUrl = "https://github.com/microsoft/vswhere/releases/latest/download/vswhere.exe"

# Normalize comma-separated tool strings (e.g. -Tools "crystal,radare2")
$NormalizedTools = @()
foreach ($entry in $Tools) {
    if (-not [string]::IsNullOrWhiteSpace($entry)) {
        foreach ($part in ($entry -split ",")) {
            $trimmed = $part.Trim().ToLower()
            if ($trimmed -and $trimmed -ne "none") {
                $NormalizedTools += $trimmed
            }
        }
    }
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

function Refresh-EnvironmentPath {
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    $parts = @()
    foreach ($seg in @($userPath, $machinePath) -join ";" -split ";") {
        if (-not [string]::IsNullOrWhiteSpace($seg)) {
            $parts += $seg.Trim()
        }
    }
    $env:Path = ($parts | Select-Object -Unique) -join ";"
}

function Add-UserPathEntry {
    param ([string]$Entry)
    if ([string]::IsNullOrWhiteSpace($Entry)) { return }
    $cleanEntry = $Entry.Trim().TrimEnd('\')
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    if (-not $userPath) { $userPath = "" }

    $parts = @()
    $exists = $false
    foreach ($p in ($userPath -split ";")) {
        $trimmed = $p.Trim()
        if ($trimmed -ne "") {
            $parts += $trimmed
            if ($trimmed.TrimEnd('\').ToLower() -eq $cleanEntry.ToLower()) {
                $exists = $true
            }
        }
    }

    if (-not $exists) {
        $parts += $Entry.Trim()
        $newPath = $parts -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    }
}

function Broadcast-EnvironmentChange {
    try {
        if (-not ("LapisWin32.NativeMethods" -as [type])) {
            Add-Type -Namespace "LapisWin32" -Name "NativeMethods" -MemberDefinition @"
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd,
    uint Msg,
    UIntPtr wParam,
    string lParam,
    uint fuFlags,
    uint uTimeout,
    out UIntPtr lpdwResult);
"@
        }
        $result = [UIntPtr]::Zero
        [void][LapisWin32.NativeMethods]::SendMessageTimeout(
            [IntPtr]0xFFFF,
            0x001A,
            [UIntPtr]::Zero,
            "Environment",
            2,
            5000,
            [ref]$result
        )
    } catch {
        # Best-effort WM_SETTINGCHANGE broadcast
    }
}

function Test-ExecutableExists {
    param ([string]$CommandName, [string[]]$ExtraPaths = @())

    foreach ($path in $ExtraPaths) {
        if ($path -and (Test-Path $path)) {
            return (Resolve-Path $path).Path
        }
    }

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
        return $cmd.Source
    }
    return $null
}

# --- Detection & Resolution Functions ---

function Find-Crystal {
    $userProfile = $env:USERPROFILE
    $localAppData = $env:LOCALAPPDATA
    $candidates = @(
        "$localAppData\Programs\Crystal\crystal.exe",
        "$localAppData\Programs\Crystal\bin\crystal.exe",
        "$userProfile\scoop\apps\crystal\current\crystal.exe",
        "$userProfile\scoop\apps\crystal\current\bin\crystal.exe",
        "$userProfile\scoop\shims\crystal.exe",
        "C:\Program Files\Crystal\crystal.exe",
        "C:\Program Files\Crystal\bin\crystal.exe",
        "C:\Crystal\crystal.exe",
        "C:\Crystal\bin\crystal.exe"
    )
    return Test-ExecutableExists -CommandName "crystal.exe" -ExtraPaths $candidates
}

function Resolve-CrystalRoot {
    param ([string]$CrystalExePath)
    if ([string]::IsNullOrWhiteSpace($CrystalExePath)) { return $null }

    $fullExe = [System.IO.Path]::GetFullPath($CrystalExePath)
    $parent = Split-Path -Parent $fullExe

    # Map Scoop shim (...\scoop\shims\crystal.exe) to real Scoop app root
    if ($parent -match "(?i)[\\/]scoop[\\/]shims$") {
        $scoopRoot = Split-Path -Parent $parent
        $appCurrent = Join-Path $scoopRoot "apps\crystal\current"
        if (Test-Path (Join-Path $appCurrent "crystal.exe")) {
            return $appCurrent
        }
    }

    if ((Split-Path -Leaf $parent).ToLower() -eq "bin") {
        $grandParent = Split-Path -Parent $parent
        if ($grandParent -and ((Test-Path (Join-Path $grandParent "src")) -or (Test-Path (Join-Path $grandParent "lib")))) {
            return $grandParent
        }
    }

    return $parent
}

function Get-CrystalVersion {
    param ([string]$CrystalExePath)
    if (-not $CrystalExePath -or -not (Test-Path $CrystalExePath)) { return $null }
    try {
        $out = & $CrystalExePath --version 2>$null | Out-String
        if ($out -match "Crystal\s+(\d+\.\d+\.\d+)") {
            return [version]$Matches[1]
        }
    } catch {
    }
    return $null
}

function Find-VsWhere {
    $pf86 = ${env:ProgramFiles(x86)}
    $pf = $env:ProgramFiles
    $userProfile = $env:USERPROFILE
    $localApp = $env:LOCALAPPDATA
    $candidates = @(
        (if ($pf86) { "$pf86\Microsoft Visual Studio\Installer\vswhere.exe" } else { $null }),
        (if ($pf) { "$pf\Microsoft Visual Studio\Installer\vswhere.exe" } else { $null }),
        "$userProfile\scoop\apps\vswhere\current\vswhere.exe",
        "$userProfile\scoop\shims\vswhere.exe",
        "$localApp\Programs\Lapis\bin\vswhere.exe"
    )
    return Test-ExecutableExists -CommandName "vswhere.exe" -ExtraPaths $candidates
}

function Ensure-VsWhere {
    $existing = Find-VsWhere
    if ($existing) { return $existing }

    $targetDir = Join-Path $env:LOCALAPPDATA "Programs\Lapis\bin"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    $destExe = Join-Path $targetDir "vswhere.exe"
    try {
        Write-LapisLog "INFO" "Downloading vswhere.exe for Crystal MSVC toolchain discovery..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $VsWhereUrl -OutFile $destExe -UseBasicParsing
        if (Test-Path $destExe) {
            Add-UserPathEntry -Entry $targetDir
            Refresh-EnvironmentPath
            return $destExe
        }
    } catch {
        Write-LapisLog "WARN" "Could not download vswhere.exe: $_"
    }
    return $null
}

function Test-MsvcBuildTools {
    $vswhere = Find-VsWhere
    if ($vswhere -and (Test-Path $vswhere)) {
        try {
            $instPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null | Select-Object -First 1
            if ($instPath -and (Test-Path (Join-Path $instPath.Trim() "VC\Tools\MSVC"))) {
                return $instPath.Trim()
            }
        } catch {
        }
    }

    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
    foreach ($r in $roots) {
        $vsBase = Join-Path $r "Microsoft Visual Studio"
        if (Test-Path $vsBase) {
            $found = Get-ChildItem -Path $vsBase -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                Get-ChildItem -Path $_.FullName -Directory -ErrorAction SilentlyContinue | Where-Object {
                    Test-Path (Join-Path $_.FullName "VC\Tools\MSVC")
                }
            } | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    return $null
}

function Register-CrystalEnvironment {
    param ([string]$CrystalExePath)
    $crystalRoot = Resolve-CrystalRoot -CrystalExePath $CrystalExePath
    if (-not $crystalRoot -or -not (Test-Path $crystalRoot)) {
        Write-LapisLog "WARN" "Unable to resolve Crystal root directory from '$CrystalExePath'."
        return $false
    }

    $crystalSrc = Join-Path $crystalRoot "src"
    $crystalLib = Join-Path $crystalRoot "lib"
    $crystalBin = Join-Path $crystalRoot "bin"
    $defaultCache = Join-Path $env:LOCALAPPDATA "crystal\cache"

    # 1. Ensure Crystal executable & companion DLL directories are on User PATH
    if (Test-Path (Join-Path $crystalRoot "crystal.exe")) {
        Add-UserPathEntry -Entry $crystalRoot
    } elseif (Test-Path (Join-Path $crystalBin "crystal.exe")) {
        Add-UserPathEntry -Entry $crystalBin
    }
    if (Test-Path $crystalLib) {
        Add-UserPathEntry -Entry $crystalLib
    }

    # 2. Register CRYSTAL_ENV (defaulting to 'development' if unset)
    $currentCrystalEnv = [Environment]::GetEnvironmentVariable("CRYSTAL_ENV", [EnvironmentVariableTarget]::User)
    if ($Force -or [string]::IsNullOrWhiteSpace($currentCrystalEnv)) {
        $currentCrystalEnv = "development"
        [Environment]::SetEnvironmentVariable("CRYSTAL_ENV", $currentCrystalEnv, [EnvironmentVariableTarget]::User)
    }
    $env:CRYSTAL_ENV = $currentCrystalEnv

    # 3. Register CRYSTAL_EXEC_PATH
    $execDir = if (Test-Path (Join-Path $crystalRoot "crystal.exe")) { $crystalRoot } else { $crystalBin }
    [Environment]::SetEnvironmentVariable("CRYSTAL_EXEC_PATH", $execDir, [EnvironmentVariableTarget]::User)
    $env:CRYSTAL_EXEC_PATH = $execDir

    # 4. Register CRYSTAL_CACHE_DIR and ensure directory exists
    $cacheDir = [Environment]::GetEnvironmentVariable("CRYSTAL_CACHE_DIR", [EnvironmentVariableTarget]::User)
    if ($Force -or [string]::IsNullOrWhiteSpace($cacheDir)) {
        $cacheDir = $defaultCache
        [Environment]::SetEnvironmentVariable("CRYSTAL_CACHE_DIR", $cacheDir, [EnvironmentVariableTarget]::User)
    }
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    $env:CRYSTAL_CACHE_DIR = $cacheDir

    # 5. Register CRYSTAL_PATH (always guaranteeing 'lib' and '<CrystalRoot>\src')
    $existingCrystalPath = [Environment]::GetEnvironmentVariable("CRYSTAL_PATH", [EnvironmentVariableTarget]::User)
    $cpathParts = @("lib")
    if (Test-Path $crystalSrc) {
        $cpathParts += $crystalSrc
    }
    if (-not [string]::IsNullOrWhiteSpace($existingCrystalPath)) {
        foreach ($seg in ($existingCrystalPath -split ";")) {
            $t = $seg.Trim()
            if ($t -eq "" -or $t -eq "lib") { continue }
            # Skip stale Crystal stdlib src paths that no longer match the active Crystal root
            if ($t -match "(?i)crystal.*[\\/]src$" -and $t.TrimEnd('\').ToLower() -ne $crystalSrc.TrimEnd('\').ToLower()) {
                continue
            }
            if (-not ($cpathParts | Where-Object { $_.TrimEnd('\').ToLower() -eq $t.TrimEnd('\').ToLower() })) {
                $cpathParts += $t
            }
        }
    }
    $newCrystalPath = $cpathParts -join ";"
    [Environment]::SetEnvironmentVariable("CRYSTAL_PATH", $newCrystalPath, [EnvironmentVariableTarget]::User)
    $env:CRYSTAL_PATH = $newCrystalPath

    # 6. Register CRYSTAL_LIBRARY_PATH (guaranteeing '<CrystalRoot>\lib' for gc.lib, iconv.lib, pcre2-8.lib)
    if (Test-Path $crystalLib) {
        $existingLibPath = [Environment]::GetEnvironmentVariable("CRYSTAL_LIBRARY_PATH", [EnvironmentVariableTarget]::User)
        $libParts = @($crystalLib)
        if (-not [string]::IsNullOrWhiteSpace($existingLibPath)) {
            foreach ($seg in ($existingLibPath -split ";")) {
                $t = $seg.Trim()
                if ($t -eq "") { continue }
                if ($t -match "(?i)crystal.*[\\/]lib$" -and $t.TrimEnd('\').ToLower() -ne $crystalLib.TrimEnd('\').ToLower()) {
                    continue
                }
                if (-not ($libParts | Where-Object { $_.TrimEnd('\').ToLower() -eq $t.TrimEnd('\').ToLower() })) {
                    $libParts += $t
                }
            }
        }
        $newLibPath = $libParts -join ";"
        [Environment]::SetEnvironmentVariable("CRYSTAL_LIBRARY_PATH", $newLibPath, [EnvironmentVariableTarget]::User)
        $env:CRYSTAL_LIBRARY_PATH = $newLibPath
    }

    # 7. Ensure vswhere.exe is present so Crystal can locate MSVC link.exe
    [void](Ensure-VsWhere)

    Refresh-EnvironmentPath
    Broadcast-EnvironmentChange

    Write-LapisLog "SUCCESS" "Registered Crystal environment (CRYSTAL_ENV=$currentCrystalEnv, CRYSTAL_PATH=$newCrystalPath)"
    return $true
}

function Install-PortableCrystal {
    $destRoot = Join-Path $env:LOCALAPPDATA "Programs\Crystal"
    $tmpZip = Join-Path $env:TEMP "crystal-$TargetCrystalVersion-$(Get-Random).zip"
    $stageDir = Join-Path $env:TEMP "crystal-stage-$(Get-Random)"

    try {
        Write-LapisLog "INFO" "Downloading official Crystal $TargetCrystalVersion Windows archive..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $CrystalZipUrl -OutFile $tmpZip -UseBasicParsing
        Expand-Archive -Path $tmpZip -DestinationPath $stageDir -Force

        $foundExe = Get-ChildItem -Path $stageDir -Filter "crystal.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $foundExe) {
            throw "crystal.exe was not found inside downloaded Crystal $TargetCrystalVersion archive."
        }

        $extractedRoot = Split-Path -Parent $foundExe.FullName
        if ((Split-Path -Leaf $extractedRoot).ToLower() -eq "bin") {
            $extractedRoot = Split-Path -Parent $extractedRoot
        }

        if (Test-Path $destRoot) {
            Remove-Item -Path $destRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
        Copy-Item -Path (Join-Path $extractedRoot "*") -Destination $destRoot -Recurse -Force
        return (Test-Path (Join-Path $destRoot "crystal.exe"))
    } catch {
        Write-LapisLog "WARN" "Portable Crystal archive setup failed: $_"
        return $false
    } finally {
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item $stageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Find-Radare2 {
    $userProfile = $env:USERPROFILE
    $candidates = @(
        "$userProfile\scoop\shims\radare2.exe",
        "$userProfile\scoop\apps\radare2\current\bin\radare2.exe",
        "C:\ProgramData\chocolatey\bin\radare2.exe",
        "C:\radare2\bin\radare2.exe"
    )
    return Test-ExecutableExists -CommandName "radare2.exe" -ExtraPaths $candidates
}

function Find-Make {
    $userProfile = $env:USERPROFILE
    $candidates = @(
        "$userProfile\scoop\apps\make\current\make.exe",
        "$userProfile\scoop\apps\make\current\bin\make.exe",
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
        [string]$DisplayName,
        [string[]]$ExtraArgs = @()
    )
    Write-LapisLog "INFO" "Installing $DisplayName via winget ($PackageId)..."
    $wingetArgs = @("install", "--id", $PackageId, "--exact", "--accept-package-agreements", "--accept-source-agreements")
    if ($Silent -and $ExtraArgs.Count -eq 0) {
        $wingetArgs += "--silent"
    }
    if ($ExtraArgs.Count -gt 0) {
        $wingetArgs += $ExtraArgs
    }
    $proc = Start-Process -FilePath "winget.exe" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
    return ($proc.ExitCode -eq 0)
}

function Install-WithScoop {
    param (
        [string]$PackageName,
        [string]$DisplayName,
        [string]$Subcommand = "install"
    )
    Write-LapisLog "INFO" "Running Scoop $Subcommand for $DisplayName ($PackageName)..."
    $scoopCmd = if (Get-Command scoop -ErrorAction SilentlyContinue) { "scoop" } else { "$env:USERPROFILE\scoop\shims\scoop.ps1" }
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "& '$scoopCmd' $Subcommand $PackageName") -Wait -PassThru -NoNewWindow
    return ($proc.ExitCode -eq 0)
}

# --- Execution ---

Write-LapisLog "INFO" "=== Lapis Toolchain Windows Dependency Verifier ==="
Refresh-EnvironmentPath

$results = @{}
$crystalEnvConfigured = $false

foreach ($toolLower in $NormalizedTools) {
    switch ($toolLower) {
        "crystal" {
            $existing = Find-Crystal
            $existingVer = if ($existing) { Get-CrystalVersion -CrystalExePath $existing } else { $null }

            if ($existing -and $existingVer -and ($existingVer -ge $MinCrystalVersion) -and -not $Force) {
                Write-LapisLog "SUCCESS" "Crystal $existingVer is already installed at: $existing"
                [void](Register-CrystalEnvironment -CrystalExePath $existing)
                $crystalEnvConfigured = $true
                $results["crystal"] = $true
            } else {
                if ($existing -and $existingVer) {
                    Write-LapisLog "WARN" "Detected Crystal $existingVer at $existing (requires >= $MinCrystalVersion). Upgrading to Crystal $TargetCrystalVersion..."
                } else {
                    Write-LapisLog "WARN" "Crystal compiler not found. Installing Crystal $TargetCrystalVersion..."
                }

                $installed = $false
                if ($hasScoop) {
                    [void](Install-WithScoop -PackageName "vswhere" -DisplayName "vswhere")
                    if ($existing -and $existing -match "(?i)scoop") {
                        $installed = Install-WithScoop -PackageName "crystal" -DisplayName "Crystal Compiler" -Subcommand "update"
                    } else {
                        $installed = Install-WithScoop -PackageName "crystal" -DisplayName "Crystal Compiler"
                    }
                    Refresh-EnvironmentPath
                    $scoopCheck = Find-Crystal
                    $scoopVer = if ($scoopCheck) { Get-CrystalVersion -CrystalExePath $scoopCheck } else { $null }
                    if (-not ($scoopCheck -and $scoopVer -and ($scoopVer -ge $MinCrystalVersion))) {
                        $installed = $false
                    }
                }

                if (-not $installed) {
                    $installed = Install-PortableCrystal
                }

                if (-not $installed) {
                    Write-LapisLog "INFO" "Falling back to official Crystal $TargetCrystalVersion Windows installer..."
                    $destRoot = Join-Path $env:LOCALAPPDATA "Programs\Crystal"
                    $tmpExe = Join-Path $env:TEMP "crystal-$TargetCrystalVersion-installer.exe"
                    try {
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Invoke-WebRequest -Uri $CrystalExeUrl -OutFile $tmpExe -UseBasicParsing
                        $installerArgs = @(
                            "/SP-",
                            "/VERYSILENT",
                            "/SUPPRESSMSGBOXES",
                            "/NORESTART",
                            "/CURRENTUSER",
                            "/DIR=`"$destRoot`""
                        )
                        $proc = Start-Process -FilePath $tmpExe -ArgumentList $installerArgs -Wait -PassThru
                        $installed = ($proc.ExitCode -eq 0)
                    } catch {
                        Write-LapisLog "ERROR" "Failed to download/run Crystal $TargetCrystalVersion installer: $_"
                    } finally {
                        Remove-Item $tmpExe -Force -ErrorAction SilentlyContinue
                    }
                }

                Refresh-EnvironmentPath
                $verified = Find-Crystal
                $verifiedVer = if ($verified) { Get-CrystalVersion -CrystalExePath $verified } else { $null }
                if ($verified -and $verifiedVer -and ($verifiedVer -ge $MinCrystalVersion)) {
                    [void](Register-CrystalEnvironment -CrystalExePath $verified)
                    $crystalEnvConfigured = $true
                    Write-LapisLog "SUCCESS" "Crystal $verifiedVer configured at: $verified"
                    $results["crystal"] = $true
                } else {
                    Write-LapisLog "ERROR" "Crystal $TargetCrystalVersion installation could not be verified."
                    $results["crystal"] = $false
                }
            }
        }

        "vctools" {
            [void](Ensure-VsWhere)
            $existingVs = Test-MsvcBuildTools
            if ($existingVs -and -not $Force) {
                Write-LapisLog "SUCCESS" "MSVC C++ Build Tools verified at: $existingVs"
                $results["vctools"] = $true
            } else {
                Write-LapisLog "WARN" "MSVC C++ Build Tools (link.exe / Windows SDK) not found. Initiating installation..."
                $installed = $false
                if ($hasWinget) {
                    $vsOverride = "--passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
                    $installed = Install-WithWinget -PackageId "Microsoft.VisualStudio.2022.BuildTools" -DisplayName "Visual Studio 2022 C++ Build Tools" -ExtraArgs @("--override", $vsOverride)
                }
                Refresh-EnvironmentPath
                $verifiedVs = Test-MsvcBuildTools
                if ($verifiedVs) {
                    Write-LapisLog "SUCCESS" "MSVC C++ Build Tools verified at: $verifiedVs"
                    $results["vctools"] = $true
                } else {
                    Write-LapisLog "WARN" "MSVC C++ Build Tools not detected. Install 'Desktop development with C++' via Visual Studio Build Tools so Crystal can link DLLs."
                    $results["vctools"] = $false
                }
            }
        }

        "radare2" {
            $existing = Find-Radare2
            if ($existing -and -not $Force) {
                Write-LapisLog "SUCCESS" "radare2 debugger is already installed at: $existing"
                $results["radare2"] = $true
            } else {
                Write-LapisLog "WARN" "radare2 debugger not found. Initiating radare2 automated installation..."
                $installed = $false
                if ($hasScoop) {
                    $installed = Install-WithScoop -PackageName "radare2" -DisplayName "radare2 Native Debugger"
                }
                if (-not $installed -and $hasWinget) {
                    $installed = Install-WithWinget -PackageId "radare2.radare2" -DisplayName "radare2 Native Debugger"
                }
                Refresh-EnvironmentPath
                $verified = Find-Radare2
                if ($verified) {
                    Write-LapisLog "SUCCESS" "radare2 successfully verified at: $verified"
                    $results["radare2"] = $true
                } else {
                    Write-LapisLog "ERROR" "radare2 installation could not be verified in PATH."
                    $results["radare2"] = $false
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

                Add-UserPathEntry -Entry $targetDir
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

                if (-not $installed -and $hasWinget) {
                    $installed = Install-WithWinget -PackageId "JRSoftware.InnoSetup" -DisplayName "Inno Setup Compiler"
                }

                if (-not $installed -and $hasScoop) {
                    $installed = Install-WithScoop -PackageName "innosetup" -DisplayName "Inno Setup Compiler"
                }

                if (-not $installed) {
                    Write-LapisLog "INFO" "Downloading official Inno Setup installer from jrsoftware.org..."
                    $tmpExe = Join-Path $env:TEMP "innosetup-installer.exe"
                    $url = "https://files.jrsoftware.org/is/6/innosetup-6.3.3.exe"
                    try {
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Invoke-WebRequest -Uri $url -OutFile $tmpExe -UseBasicParsing
                        $proc = Start-Process -FilePath $tmpExe -ArgumentList @("/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES", "/CURRENTUSER") -Wait -PassThru
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
                    $isccDir = Split-Path -Parent $verified
                    Add-UserPathEntry -Entry $isccDir
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

# Always configure Crystal environment variables if requested and Crystal is present on the host
if ($ConfigureCrystalEnv -and -not $crystalEnvConfigured) {
    $detectedCrystal = Find-Crystal
    if ($detectedCrystal) {
        [void](Register-CrystalEnvironment -CrystalExePath $detectedCrystal)
    }
}

Refresh-EnvironmentPath
Broadcast-EnvironmentChange
Write-LapisLog "SUCCESS" "Dependency verification completed."
exit 0
