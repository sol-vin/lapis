# =============================================================================
# Lapis Toolchain - Windows Dependency & Crystal Environment Installer
# =============================================================================
# Detects, installs, and registers required dependencies for Lapis on Windows:
#   - Crystal compiler 1.21.x (crystal.exe + CRYSTAL_ENV & crystal env vars)
#   - GNU Make 4.4.1 (make.exe — bundled offline + portable zip fallback)
#   - MSVC C++ Build Tools & vswhere.exe (vctools — winget + vs_buildtools.exe)
#   - Git for Windows (git.exe — winget + scoop + portable MinGit zip)
#   - radare2 native debugger (radare2.exe — scoop + winget + GitHub zip)
#   - Crystalline LSP (crystalline.exe — optional)
#   - Inno Setup Compiler (iscc.exe — optional)
# =============================================================================

[CmdletBinding()]
param (
    [string[]]$Tools = @("crystal", "vctools", "radare2", "make", "git", "innosetup"),
    [string]$InstallBinDir = "",
    [string]$LogPath = "",
    [switch]$ConfigureCrystalEnv,
    [switch]$Silent,
    [switch]$Force
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
}

$TargetCrystalVersion = "1.21.1"
$FallbackCrystalVersion = "1.21.0"
$MinCrystalVersion = [version]"1.20.0"
$CrystalZipUrl = "https://github.com/crystal-lang/crystal/releases/download/$TargetCrystalVersion/crystal-$TargetCrystalVersion-windows-x86_64-msvc-unsupported.zip"
$CrystalFallbackZipUrl = "https://github.com/crystal-lang/crystal/releases/download/$FallbackCrystalVersion/crystal-$FallbackCrystalVersion-windows-x86_64-msvc-unsupported.zip"
$CrystalExeUrl = "https://github.com/crystal-lang/crystal/releases/download/$FallbackCrystalVersion/crystal-$FallbackCrystalVersion-windows-x86_64-msvc-unsupported.exe"
$MakeZipUrl = "https://downloads.sourceforge.net/project/ezwinports/make-4.4.1-without-guile-w32-bin.zip"
$MinGitFallbackUrl = "https://github.com/git-for-windows/git/releases/download/v2.56.1.windows.1/MinGit-2.56.1-64-bit.zip"
$Radare2FallbackUrl = "https://github.com/radareorg/radare2/releases/download/6.2.6/radare2-6.2.6-w64.zip"
$VsBuildToolsUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"
$VsWhereUrl = "https://github.com/microsoft/vswhere/releases/latest/download/vswhere.exe"

$EffectiveLapisBin = if (-not [string]::IsNullOrWhiteSpace($InstallBinDir)) {
    $InstallBinDir
} else {
    Join-Path $env:LOCALAPPDATA "Programs\Lapis\bin"
}

if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $logDir = Split-Path -Parent $LogPath -ErrorAction SilentlyContinue
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Set-Content -Path $LogPath -Value "=== Lapis Dependency Installer Log ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) ===" -Encoding UTF8 -ErrorAction SilentlyContinue
}

# Normalize comma-separated tool strings (e.g. -Tools "crystal,make,git")
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
    $formatted = "[$timestamp] [$Level] $Message"
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        Add-Content -Path $LogPath -Value $formatted -Encoding UTF8 -ErrorAction SilentlyContinue
    }
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
    if (-not [string]::IsNullOrWhiteSpace($EffectiveLapisBin) -and (Test-Path $EffectiveLapisBin)) {
        $parts += $EffectiveLapisBin
    }
    foreach ($seg in (@($userPath, $machinePath) -join ";" -split ";")) {
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
    if (-not (Test-Path $cleanEntry)) { return }

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
        Write-LapisLog "INFO" "Added '$($Entry.Trim())' to User PATH."
    }
    Refresh-EnvironmentPath
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
    }
}

function Download-ArchiveFast {
    param (
        [string]$Url,
        [string]$DestFile
    )
    if (Test-Path $DestFile) {
        Remove-Item $DestFile -Force -ErrorAction SilentlyContinue
    }
    $curlExe = Join-Path $env:SystemRoot "System32\curl.exe"
    if (Test-Path $curlExe) {
        $proc = Start-Process -FilePath $curlExe -ArgumentList @("-fSL", "--retry", "3", "--connect-timeout", "20", "-o", $DestFile, $Url) -Wait -PassThru -NoNewWindow
        if (($proc.ExitCode -eq 0) -and (Test-Path $DestFile) -and ((Get-Item $DestFile).Length -gt 1024)) {
            return $true
        }
    }
    try {
        Invoke-WebRequest -Uri $Url -OutFile $DestFile -UseBasicParsing
        return ((Test-Path $DestFile) -and ((Get-Item $DestFile).Length -gt 1024))
    } catch {
        Write-LapisLog "WARN" "Download failed for $Url : $_"
        return $false
    }
}

function Extract-ZipFast {
    param (
        [string]$ZipPath,
        [string]$DestDir
    )
    if (Test-Path $DestDir) {
        Remove-Item $DestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $DestDir)
        return $true
    } catch {
    }

    $tarExe = Join-Path $env:SystemRoot "System32\tar.exe"
    if (Test-Path $tarExe) {
        $proc = Start-Process -FilePath $tarExe -ArgumentList @("-xf", $ZipPath, "-C", $DestDir) -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) {
            return $true
        }
    }

    try {
        Expand-Archive -Path $ZipPath -DestinationPath $DestDir -Force
        return $true
    } catch {
        Write-LapisLog "WARN" "Archive extraction failed for $ZipPath : $_"
        return $false
    }
}

function Test-ToolRuns {
    param (
        [string]$ExePath,
        [string[]]$CheckArgs = @("--version")
    )
    if ([string]::IsNullOrWhiteSpace($ExePath) -or -not (Test-Path $ExePath)) {
        return $false
    }
    try {
        $proc = Start-Process -FilePath $ExePath -ArgumentList $CheckArgs -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $env:TEMP "lapis_tool_out_$PID.txt") -RedirectStandardError (Join-Path $env:TEMP "lapis_tool_err_$PID.txt")
        Remove-Item (Join-Path $env:TEMP "lapis_tool_out_$PID.txt") -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $env:TEMP "lapis_tool_err_$PID.txt") -Force -ErrorAction SilentlyContinue
        return ($proc.ExitCode -eq 0)
    } catch {
        return $false
    }
}

function Test-ExecutableExists {
    param (
        [string]$CommandName,
        [string[]]$ExtraPaths = @(),
        [string[]]$VerifyArgs = @()
    )

    foreach ($path in $ExtraPaths) {
        if ($path -and (Test-Path $path)) {
            $resolved = (Resolve-Path $path).Path
            if (($VerifyArgs.Count -eq 0) -or (Test-ToolRuns -ExePath $resolved -CheckArgs $VerifyArgs)) {
                return $resolved
            }
        }
    }

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
        if (($VerifyArgs.Count -eq 0) -or (Test-ToolRuns -ExePath $cmd.Source -CheckArgs $VerifyArgs)) {
            return $cmd.Source
        }
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
    return Test-ExecutableExists -CommandName "crystal.exe" -ExtraPaths $candidates -VerifyArgs @("--version")
}

function Resolve-CrystalRoot {
    param ([string]$CrystalExePath)
    if ([string]::IsNullOrWhiteSpace($CrystalExePath)) { return $null }

    $fullExe = [System.IO.Path]::GetFullPath($CrystalExePath)
    $parent = Split-Path -Parent $fullExe

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
        (Join-Path $EffectiveLapisBin "vswhere.exe"),
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
    if ($existing) {
        Add-UserPathEntry -Entry (Split-Path -Parent $existing)
        return $existing
    }

    $targetDir = $EffectiveLapisBin
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    $destExe = Join-Path $targetDir "vswhere.exe"
    Write-LapisLog "INFO" "Downloading vswhere.exe for Crystal MSVC toolchain discovery..."
    if (Download-ArchiveFast -Url $VsWhereUrl -DestFile $destExe) {
        Add-UserPathEntry -Entry $targetDir
        return $destExe
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

    if (Test-Path (Join-Path $crystalRoot "crystal.exe")) {
        Add-UserPathEntry -Entry $crystalRoot
    } elseif (Test-Path (Join-Path $crystalBin "crystal.exe")) {
        Add-UserPathEntry -Entry $crystalBin
    }
    if (Test-Path $crystalLib) {
        Add-UserPathEntry -Entry $crystalLib
    }

    $currentCrystalEnv = [Environment]::GetEnvironmentVariable("CRYSTAL_ENV", [EnvironmentVariableTarget]::User)
    if ($Force -or [string]::IsNullOrWhiteSpace($currentCrystalEnv)) {
        $currentCrystalEnv = "development"
        [Environment]::SetEnvironmentVariable("CRYSTAL_ENV", $currentCrystalEnv, [EnvironmentVariableTarget]::User)
    }
    $env:CRYSTAL_ENV = $currentCrystalEnv

    $execDir = if (Test-Path (Join-Path $crystalRoot "crystal.exe")) { $crystalRoot } else { $crystalBin }
    [Environment]::SetEnvironmentVariable("CRYSTAL_EXEC_PATH", $execDir, [EnvironmentVariableTarget]::User)
    $env:CRYSTAL_EXEC_PATH = $execDir

    $cacheDir = [Environment]::GetEnvironmentVariable("CRYSTAL_CACHE_DIR", [EnvironmentVariableTarget]::User)
    if ($Force -or [string]::IsNullOrWhiteSpace($cacheDir)) {
        $cacheDir = $defaultCache
        [Environment]::SetEnvironmentVariable("CRYSTAL_CACHE_DIR", $cacheDir, [EnvironmentVariableTarget]::User)
    }
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    $env:CRYSTAL_CACHE_DIR = $cacheDir

    $existingCrystalPath = [Environment]::GetEnvironmentVariable("CRYSTAL_PATH", [EnvironmentVariableTarget]::User)
    $cpathParts = @("lib")
    if (Test-Path $crystalSrc) {
        $cpathParts += $crystalSrc
    }
    if (-not [string]::IsNullOrWhiteSpace($existingCrystalPath)) {
        foreach ($seg in ($existingCrystalPath -split ";")) {
            $t = $seg.Trim()
            if ($t -eq "" -or $t -eq "lib") { continue }
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

    [void](Ensure-VsWhere)
    Refresh-EnvironmentPath
    Broadcast-EnvironmentChange

    Write-LapisLog "SUCCESS" "Registered Crystal environment (CRYSTAL_ENV=$currentCrystalEnv, CRYSTAL_PATH=$newCrystalPath)"
    return $true
}

function Install-PortableCrystal {
    $destRoot = Join-Path $env:LOCALAPPDATA "Programs\Crystal"
    foreach ($zipUrl in @($CrystalZipUrl, $CrystalFallbackZipUrl)) {
        $tmpZip = Join-Path $env:TEMP "crystal-portable-$(Get-Random).zip"
        $stageDir = Join-Path $env:TEMP "crystal-stage-$(Get-Random)"
        try {
            Write-LapisLog "INFO" "Downloading official Crystal portable archive ($zipUrl)..."
            if (-not (Download-ArchiveFast -Url $zipUrl -DestFile $tmpZip)) {
                continue
            }
            if (-not (Extract-ZipFast -ZipPath $tmpZip -DestDir $stageDir)) {
                continue
            }

            $foundExe = Get-ChildItem -Path $stageDir -Filter "crystal.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $foundExe) {
                continue
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
            $destExe = Join-Path $destRoot "crystal.exe"
            if (Test-ToolRuns -ExePath $destExe -CheckArgs @("--version")) {
                Add-UserPathEntry -Entry $destRoot
                return $true
            }
        } catch {
            Write-LapisLog "WARN" "Portable Crystal archive attempt failed: $_"
        } finally {
            Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
            Remove-Item $stageDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    return $false
}

function Install-PortableMake {
    $targetDir = $EffectiveLapisBin
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    $destExe = Join-Path $targetDir "make.exe"
    $tmpZip = Join-Path $env:TEMP "make-portable-$(Get-Random).zip"
    $stageDir = Join-Path $env:TEMP "make-stage-$(Get-Random)"

    try {
        Write-LapisLog "INFO" "Downloading standalone GNU Make 4.4.1 portable archive..."
        if (-not (Download-ArchiveFast -Url $MakeZipUrl -DestFile $tmpZip)) {
            return $false
        }
        if (-not (Extract-ZipFast -ZipPath $tmpZip -DestDir $stageDir)) {
            return $false
        }
        $foundMake = Get-ChildItem -Path $stageDir -Filter "make.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($foundMake -and (Test-Path $foundMake.FullName)) {
            Copy-Item $foundMake.FullName $destExe -Force
            Add-UserPathEntry -Entry $targetDir
            return (Test-ToolRuns -ExePath $destExe -CheckArgs @("--version"))
        }
    } catch {
        Write-LapisLog "WARN" "Portable GNU Make setup failed: $_"
    } finally {
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item $stageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $false
}

function Install-PortableGit {
    $destRoot = Join-Path $env:LOCALAPPDATA "Programs\Git"
    $tmpZip = Join-Path $env:TEMP "mingit-portable-$(Get-Random).zip"
    $stageDir = Join-Path $env:TEMP "mingit-stage-$(Get-Random)"

    $gitUrl = $MinGitFallbackUrl
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest" -Headers @{ "User-Agent" = "Lapis-Installer" } -TimeoutSec 10
        $asset = $rel.assets | Where-Object { $_.name -match "^MinGit-.*-64-bit\.zip$" -and $_.name -notmatch "busybox" } | Select-Object -First 1
        if ($asset -and $asset.browser_download_url) {
            $gitUrl = $asset.browser_download_url
        }
    } catch {
    }

    try {
        Write-LapisLog "INFO" "Downloading official Portable Git ($gitUrl)..."
        if (-not (Download-ArchiveFast -Url $gitUrl -DestFile $tmpZip)) {
            return $false
        }
        if (-not (Extract-ZipFast -ZipPath $tmpZip -DestDir $stageDir)) {
            return $false
        }
        if (Test-Path $destRoot) {
            Remove-Item -Path $destRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
        Copy-Item -Path (Join-Path $stageDir "*") -Destination $destRoot -Recurse -Force
        $gitCmdDir = Join-Path $destRoot "cmd"
        $gitExe = Join-Path $gitCmdDir "git.exe"
        if (Test-ToolRuns -ExePath $gitExe -CheckArgs @("--version")) {
            Add-UserPathEntry -Entry $gitCmdDir
            return $true
        }
    } catch {
        Write-LapisLog "WARN" "Portable Git setup failed: $_"
    } finally {
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item $stageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $false
}

function Install-PortableRadare2 {
    $destRoot = Join-Path $env:LOCALAPPDATA "Programs\radare2"
    $tmpZip = Join-Path $env:TEMP "radare2-portable-$(Get-Random).zip"
    $stageDir = Join-Path $env:TEMP "radare2-stage-$(Get-Random)"

    $r2Url = $Radare2FallbackUrl
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/radareorg/radare2/releases/latest" -Headers @{ "User-Agent" = "Lapis-Installer" } -TimeoutSec 10
        $asset = $rel.assets | Where-Object { $_.name -match "^radare2-.*-w64\.zip$" -and $_.name -notmatch "arm64" } | Select-Object -First 1
        if ($asset -and $asset.browser_download_url) {
            $r2Url = $asset.browser_download_url
        }
    } catch {
    }

    try {
        Write-LapisLog "INFO" "Downloading official radare2 Windows archive ($r2Url)..."
        if (-not (Download-ArchiveFast -Url $r2Url -DestFile $tmpZip)) {
            return $false
        }
        if (-not (Extract-ZipFast -ZipPath $tmpZip -DestDir $stageDir)) {
            return $false
        }
        $foundR2 = Get-ChildItem -Path $stageDir -Filter "radare2.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $foundR2) { return $false }

        $extractedRoot = Split-Path -Parent (Split-Path -Parent $foundR2.FullName)
        if (Test-Path $destRoot) {
            Remove-Item -Path $destRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
        Copy-Item -Path (Join-Path $extractedRoot "*") -Destination $destRoot -Recurse -Force
        $r2BinDir = Join-Path $destRoot "bin"
        $r2Exe = Join-Path $r2BinDir "radare2.exe"
        if (Test-ToolRuns -ExePath $r2Exe -CheckArgs @("-v")) {
            Add-UserPathEntry -Entry $r2BinDir
            return $true
        }
    } catch {
        Write-LapisLog "WARN" "Portable radare2 setup failed: $_"
    } finally {
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item $stageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $false
}

function Find-Radare2 {
    $userProfile = $env:USERPROFILE
    $localApp = $env:LOCALAPPDATA
    $candidates = @(
        "$localApp\Programs\radare2\bin\radare2.exe",
        (Join-Path $EffectiveLapisBin "radare2.exe"),
        "$userProfile\scoop\apps\radare2\current\bin\radare2.exe",
        "$userProfile\scoop\shims\radare2.exe",
        "C:\ProgramData\chocolatey\bin\radare2.exe",
        "C:\radare2\bin\radare2.exe"
    )
    return Test-ExecutableExists -CommandName "radare2.exe" -ExtraPaths $candidates -VerifyArgs @("-v")
}

function Find-Make {
    $userProfile = $env:USERPROFILE
    $localApp = $env:LOCALAPPDATA
    $wingetLinks = "$localApp\Microsoft\WinGet\Links\make.exe"
    $wingetPkgExe = $null
    $wingetPkgsDir = "$localApp\Microsoft\WinGet\Packages"
    if (Test-Path $wingetPkgsDir) {
        $foundPkg = Get-ChildItem -Path $wingetPkgsDir -Filter "make.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($foundPkg) { $wingetPkgExe = $foundPkg.FullName }
    }

    $candidates = @(
        (Join-Path $EffectiveLapisBin "make.exe"),
        "$localApp\Programs\Lapis\bin\make.exe",
        $wingetLinks,
        $wingetPkgExe,
        "$userProfile\scoop\apps\make\current\bin\make.exe",
        "$userProfile\scoop\apps\make\current\make.exe",
        "C:\Program Files (x86)\GnuWin32\bin\make.exe",
        "C:\Program Files\Git\usr\bin\make.exe",
        "C:\msys64\usr\bin\make.exe",
        "C:\msys64\mingw64\bin\mingw32-make.exe"
    )
    $found = Test-ExecutableExists -CommandName "make.exe" -ExtraPaths $candidates -VerifyArgs @("--version")
    if (-not $found) {
        $found = Test-ExecutableExists -CommandName "mingw32-make.exe" -VerifyArgs @("--version")
    }
    return $found
}

function Find-Git {
    $userProfile = $env:USERPROFILE
    $candidates = @(
        "C:\Program Files\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
        "$userProfile\scoop\apps\git\current\cmd\git.exe",
        "$userProfile\scoop\shims\git.exe",
        "C:\Program Files\Git\bin\git.exe"
    )
    return Test-ExecutableExists -CommandName "git.exe" -ExtraPaths $candidates -VerifyArgs @("--version")
}

function Find-Crystalline {
    $userProfile = $env:USERPROFILE
    $candidates = @(
        (Join-Path $EffectiveLapisBin "crystalline.exe"),
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

# --- Package Manager Helpers ---

$hasWinget = (Get-Command winget.exe -ErrorAction SilentlyContinue) -ne $null
$hasScoop = (Get-Command scoop -ErrorAction SilentlyContinue) -ne $null -or (Test-Path "$env:USERPROFILE\scoop\shims\scoop.ps1")

function Install-WithWinget {
    param (
        [string]$PackageId,
        [string]$DisplayName,
        [string[]]$ExtraArgs = @()
    )
    if (-not $hasWinget) { return $false }
    Write-LapisLog "INFO" "Installing $DisplayName via winget ($PackageId)..."
    $wingetArgs = @("install", "--id", $PackageId, "--exact", "--source", "winget", "--accept-package-agreements", "--accept-source-agreements")
    if ($Silent -and $ExtraArgs.Count -eq 0) {
        $wingetArgs += "--silent"
    }
    if ($ExtraArgs.Count -gt 0) {
        $wingetArgs += $ExtraArgs
    }
    try {
        $proc = Start-Process -FilePath "winget.exe" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
        return ($proc.ExitCode -eq 0)
    } catch {
        Write-LapisLog "WARN" "winget invocation failed for $PackageId : $_"
        return $false
    }
}

function Install-WithScoop {
    param (
        [string]$PackageName,
        [string]$DisplayName,
        [string]$Subcommand = "install"
    )
    if (-not $hasScoop) { return $false }
    Write-LapisLog "INFO" "Running Scoop $Subcommand for $DisplayName ($PackageName)..."
    $scoopCmd = if (Get-Command scoop -ErrorAction SilentlyContinue) { "scoop" } else { "$env:USERPROFILE\scoop\shims\scoop.ps1" }
    try {
        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "& '$scoopCmd' $Subcommand $PackageName") -Wait -PassThru -NoNewWindow
        return ($proc.ExitCode -eq 0)
    } catch {
        Write-LapisLog "WARN" "Scoop invocation failed for $PackageName : $_"
        return $false
    }
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
                Write-LapisLog "SUCCESS" "Crystal $existingVer verified at: $existing"
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
                    Write-LapisLog "INFO" "Falling back to official Crystal $FallbackCrystalVersion Windows installer..."
                    $destRoot = Join-Path $env:LOCALAPPDATA "Programs\Crystal"
                    $tmpExe = Join-Path $env:TEMP "crystal-$FallbackCrystalVersion-installer.exe"
                    try {
                        if (Download-ArchiveFast -Url $CrystalExeUrl -DestFile $tmpExe) {
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
                        }
                    } catch {
                        Write-LapisLog "ERROR" "Failed to run Crystal installer: $_"
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
                    Write-LapisLog "ERROR" "Crystal installation could not be verified."
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
                $vsOverride = "--passive --norestart --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
                if ($hasWinget) {
                    $installed = Install-WithWinget -PackageId "Microsoft.VisualStudio.2022.BuildTools" -DisplayName "Visual Studio 2022 C++ Build Tools" -ExtraArgs @("--override", $vsOverride)
                }
                if (-not $installed -and -not (Test-MsvcBuildTools)) {
                    $tmpVsExe = Join-Path $env:TEMP "vs_buildtools_$(Get-Random).exe"
                    try {
                        Write-LapisLog "INFO" "Downloading Microsoft Visual Studio BuildTools bootstrapper ($VsBuildToolsUrl)..."
                        if (Download-ArchiveFast -Url $VsBuildToolsUrl -DestFile $tmpVsExe) {
                            $proc = Start-Process -FilePath $tmpVsExe -ArgumentList @("--passive", "--norestart", "--wait", "--add", "Microsoft.VisualStudio.Workload.VCTools", "--includeRecommended") -Wait -PassThru
                            $installed = ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010)
                        }
                    } catch {
                        Write-LapisLog "WARN" "Direct Visual Studio BuildTools bootstrapper failed: $_"
                    } finally {
                        Remove-Item $tmpVsExe -Force -ErrorAction SilentlyContinue
                    }
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

        "make" {
            $existing = Find-Make
            if ($existing -and -not $Force) {
                Add-UserPathEntry -Entry (Split-Path -Parent $existing)
                Write-LapisLog "SUCCESS" "GNU Make verified and registered in PATH: $existing"
                $results["make"] = $true
            } else {
                Write-LapisLog "WARN" "GNU Make not found in PATH. Installing GNU Make..."
                $installed = $false
                if ($hasScoop) {
                    $installed = Install-WithScoop -PackageName "make" -DisplayName "GNU Make"
                }
                if (-not $installed -and $hasWinget) {
                    $installed = Install-WithWinget -PackageId "ezwinports.make" -DisplayName "GNU Make"
                }
                Refresh-EnvironmentPath
                $verified = Find-Make
                if (-not $verified) {
                    [void](Install-PortableMake)
                    Refresh-EnvironmentPath
                    $verified = Find-Make
                }
                if ($verified) {
                    Add-UserPathEntry -Entry (Split-Path -Parent $verified)
                    Write-LapisLog "SUCCESS" "GNU Make successfully verified at: $verified"
                    $results["make"] = $true
                } else {
                    Write-LapisLog "ERROR" "GNU Make installation could not be verified."
                    $results["make"] = $false
                }
            }
        }

        "git" {
            $existing = Find-Git
            if ($existing -and -not $Force) {
                Add-UserPathEntry -Entry (Split-Path -Parent $existing)
                Write-LapisLog "SUCCESS" "Git verified and registered in PATH: $existing"
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
                if (-not $verified) {
                    [void](Install-PortableGit)
                    Refresh-EnvironmentPath
                    $verified = Find-Git
                }
                if ($verified) {
                    Add-UserPathEntry -Entry (Split-Path -Parent $verified)
                    Write-LapisLog "SUCCESS" "Git successfully verified at: $verified"
                    $results["git"] = $true
                } else {
                    Write-LapisLog "ERROR" "Git installation could not be verified."
                    $results["git"] = $false
                }
            }
        }

        "radare2" {
            $existing = Find-Radare2
            if ($existing -and -not $Force) {
                Add-UserPathEntry -Entry (Split-Path -Parent $existing)
                Write-LapisLog "SUCCESS" "radare2 debugger verified and registered in PATH: $existing"
                $results["radare2"] = $true
            } else {
                Write-LapisLog "WARN" "radare2 debugger not found. Initiating automated installation..."
                $installed = $false
                if ($hasScoop) {
                    $installed = Install-WithScoop -PackageName "radare2" -DisplayName "radare2 Native Debugger"
                }
                if (-not $installed -and $hasWinget) {
                    $installed = Install-WithWinget -PackageId "radare2.radare2" -DisplayName "radare2 Native Debugger"
                }
                Refresh-EnvironmentPath
                $verified = Find-Radare2
                if (-not $verified) {
                    [void](Install-PortableRadare2)
                    Refresh-EnvironmentPath
                    $verified = Find-Radare2
                }
                if ($verified) {
                    Add-UserPathEntry -Entry (Split-Path -Parent $verified)
                    Write-LapisLog "SUCCESS" "radare2 successfully verified at: $verified"
                    $results["radare2"] = $true
                } else {
                    Write-LapisLog "WARN" "radare2 installation could not be verified."
                    $results["radare2"] = $false
                }
            }
        }

        "crystalline" {
            $existing = Find-Crystalline
            if ($existing -and -not $Force) {
                Add-UserPathEntry -Entry (Split-Path -Parent $existing)
                Write-LapisLog "SUCCESS" "Crystalline LSP verified at: $existing"
                $results["crystalline"] = $true
            } else {
                $targetDir = $EffectiveLapisBin
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
                        break
                    }
                }

                if (-not (Test-Path $destExe) -and $hasScoop) {
                    [void](Install-WithScoop -PackageName "crystalline" -DisplayName "Crystalline LSP")
                }

                Refresh-EnvironmentPath
                $verified = Find-Crystalline
                if ($verified) {
                    Add-UserPathEntry -Entry (Split-Path -Parent $verified)
                    Write-LapisLog "SUCCESS" "Crystalline LSP verified at: $verified"
                    $results["crystalline"] = $true
                } else {
                    Write-LapisLog "INFO" "Crystalline LSP prebuilt binaries are optional on Windows (upstream publishes Linux/macOS releases)."
                    $results["crystalline"] = $false
                }
            }
        }

        "innosetup" {
            $existing = Find-InnoSetup
            if ($existing -and -not $Force) {
                Add-UserPathEntry -Entry (Split-Path -Parent $existing)
                Write-LapisLog "SUCCESS" "Inno Setup Compiler verified at: $existing"
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
                        $proc = Start-Process -FilePath $cand -ArgumentList @("/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES", "/CURRENTUSER") -Wait -PassThru
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
                        if (Download-ArchiveFast -Url $url -DestFile $tmpExe) {
                            $proc = Start-Process -FilePath $tmpExe -ArgumentList @("/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES", "/CURRENTUSER") -Wait -PassThru
                            $installed = ($proc.ExitCode -eq 0)
                        }
                    } catch {
                        Write-LapisLog "ERROR" "Failed to run Inno Setup installer: $_"
                    } finally {
                        Remove-Item $tmpExe -Force -ErrorAction SilentlyContinue
                    }
                }

                Refresh-EnvironmentPath
                $verified = Find-InnoSetup
                if ($verified) {
                    Add-UserPathEntry -Entry (Split-Path -Parent $verified)
                    Write-LapisLog "SUCCESS" "Inno Setup Compiler successfully installed at: $verified"
                    $results["innosetup"] = $true
                } else {
                    Write-LapisLog "WARN" "Inno Setup Compiler installation could not be verified."
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

$criticalFailed = $false
foreach ($crit in @("crystal", "make")) {
    if (($NormalizedTools -contains $crit) -and ($results[$crit] -eq $false)) {
        $criticalFailed = $true
    }
}

if ($criticalFailed) {
    Write-LapisLog "ERROR" "One or more required tools (Crystal / Make) failed verification."
    exit 1
}

Write-LapisLog "SUCCESS" "Dependency verification completed."
exit 0
