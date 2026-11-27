; =============================================================================
; Lapis Toolchain - Inno Setup Installer Script
; =============================================================================
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

#ifndef SourceDir
  #define SourceDir "..\..\scratch\installer_stage"
#endif

#ifndef OutputDir
  #define OutputDir "..\..\bin\windows"
#endif

#ifndef OutputBaseFilename
  #define OutputBaseFilename "lapis-setup-windows-x86_64"
#endif

[Setup]
AppId={{D1A2E3B4-5C6D-7E8F-9A0B-1C2D3E4F5A6B}
AppName=Lapis
AppVersion={#AppVersion}
AppPublisher=LibGodot Crystal Contributors
AppPublisherURL=https://github.com/sol-vin/lapis
AppSupportURL=https://github.com/sol-vin/lapis/issues
AppUpdatesURL=https://github.com/sol-vin/lapis/releases
DefaultDirName={autopf}\Lapis
DefaultGroupName=Lapis Toolchain
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ChangesEnvironment=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\bin\lapis.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "envPath"; Description: "Add Lapis to PATH environment variable"; GroupDescription: "Environment Settings:"; Flags: checkedonce

[Files]
Source: "{#SourceDir}\lapis.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "{#SourceDir}\crystalline.exe"; DestDir: "{app}\bin"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\radare2.exe"; DestDir: "{app}\bin"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\r2.exe"; DestDir: "{app}\bin"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\*.dll"; DestDir: "{app}\bin"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\README.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\install_deps.ps1"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "{#SourceDir}\innosetup-installer.exe"; DestDir: "{tmp}"; Flags: ignoreversion skipifsourcedoesntexist deleteafterinstall

[Icons]
Name: "{group}\Lapis Command Prompt"; Filename: "{cmd}"; Parameters: "/k ""{app}\bin\lapis.exe --help"""
Name: "{group}\Uninstall Lapis"; Filename: "{uninstallexe}"

[Code]
var
  PrereqPage: TInputOptionWizardPage;
  HasCrystal: Boolean;
  HasCrystalEnv: Boolean;
  HasMSVC: Boolean;
  HasRadare2: Boolean;
  HasMake: Boolean;
  HasGit: Boolean;
  HasCrystalline: Boolean;
  HasInnoSetup: Boolean;

function IsCommandInPath(const Cmd: string): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec(ExpandConstant('{cmd}'), '/c where ' + Cmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

function FindCrystalExecutable(): string;
var
  UserProf: string;
  LocalApp: string;
  Cand: string;
begin
  Result := '';
  UserProf := GetEnv('USERPROFILE');
  LocalApp := ExpandConstant('{localappdata}');

  Cand := LocalApp + '\Programs\Crystal\crystal.exe';
  if FileExists(Cand) then begin Result := Cand; Exit; end;
  Cand := LocalApp + '\Programs\Crystal\bin\crystal.exe';
  if FileExists(Cand) then begin Result := Cand; Exit; end;

  if UserProf <> '' then
  begin
    Cand := UserProf + '\scoop\apps\crystal\current\crystal.exe';
    if FileExists(Cand) then begin Result := Cand; Exit; end;
    Cand := UserProf + '\scoop\apps\crystal\current\bin\crystal.exe';
    if FileExists(Cand) then begin Result := Cand; Exit; end;
    Cand := UserProf + '\scoop\shims\crystal.exe';
    if FileExists(Cand) then begin Result := Cand; Exit; end;
  end;

  if FileExists('C:\Program Files\Crystal\crystal.exe') then begin Result := 'C:\Program Files\Crystal\crystal.exe'; Exit; end;
  if FileExists('C:\Program Files\Crystal\bin\crystal.exe') then begin Result := 'C:\Program Files\Crystal\bin\crystal.exe'; Exit; end;
  if FileExists('C:\Crystal\crystal.exe') then begin Result := 'C:\Crystal\crystal.exe'; Exit; end;
  if FileExists('C:\Crystal\bin\crystal.exe') then begin Result := 'C:\Crystal\bin\crystal.exe'; Exit; end;

  if IsCommandInPath('crystal.exe') then
    Result := 'crystal.exe';
end;

function CheckCrystalInstalled(): Boolean;
var
  CrystalExe: string;
  VerFile: string;
  VerOut: AnsiString;
  VerStr: string;
  ResultCode: Integer;
begin
  CrystalExe := FindCrystalExecutable();
  if CrystalExe = '' then
  begin
    Result := False;
    Exit;
  end;

  VerFile := ExpandConstant('{tmp}\crystal_ver_check.txt');
  DeleteFile(VerFile);
  if Exec(ExpandConstant('{cmd}'), '/c ""' + CrystalExe + '" --version > "' + VerFile + '" 2>&1"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and
     (ResultCode = 0) and LoadStringFromFile(VerFile, VerOut) then
  begin
    VerStr := String(VerOut);
    // Require Crystal 1.20+ (e.g. 1.20.x, 1.21.x, 1.22.x)
    Result := (Pos('Crystal 1.2', VerStr) > 0) or (Pos('Crystal 1.3', VerStr) > 0) or (Pos('Crystal 2.', VerStr) > 0);
  end
  else
    Result := False;
  DeleteFile(VerFile);
end;

function HasEnvVarRegistered(const VarName: string): Boolean;
var
  Val: string;
begin
  Result := (RegQueryStringValue(HKCU, 'Environment', VarName, Val) and (Trim(Val) <> '')) or
            (RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', VarName, Val) and (Trim(Val) <> ''));
end;

function CheckCrystalEnvConfigured(): Boolean;
begin
  Result := HasEnvVarRegistered('CRYSTAL_ENV') and
            HasEnvVarRegistered('CRYSTAL_PATH') and
            HasEnvVarRegistered('CRYSTAL_LIBRARY_PATH');
end;

function CheckMSVCInstalled(): Boolean;
var
  PF86: string;
  PF: string;
  VsWhere: string;
  OutFile: string;
  OutText: AnsiString;
  ResultCode: Integer;
begin
  PF86 := GetEnv('ProgramFiles(x86)');
  PF := GetEnv('ProgramFiles');
  VsWhere := '';
  if (PF86 <> '') and FileExists(PF86 + '\Microsoft Visual Studio\Installer\vswhere.exe') then
    VsWhere := PF86 + '\Microsoft Visual Studio\Installer\vswhere.exe'
  else if (PF <> '') and FileExists(PF + '\Microsoft Visual Studio\Installer\vswhere.exe') then
    VsWhere := PF + '\Microsoft Visual Studio\Installer\vswhere.exe';

  if VsWhere <> '' then
  begin
    OutFile := ExpandConstant('{tmp}\vswhere_check.txt');
    DeleteFile(OutFile);
    if Exec(ExpandConstant('{cmd}'), '/c ""' + VsWhere + '" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath > "' + OutFile + '" 2>&1"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and
       (ResultCode = 0) and LoadStringFromFile(OutFile, OutText) then
    begin
      DeleteFile(OutFile);
      if Trim(String(OutText)) <> '' then
      begin
        Result := True;
        Exit;
      end;
    end;
    DeleteFile(OutFile);
  end;

  Result := DirExists('C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC') or
            DirExists('C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC') or
            DirExists('C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC') or
            DirExists('C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC') or
            DirExists('C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC') or
            DirExists('C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC') or
            DirExists('C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC');
end;

function CheckRadare2Installed(): Boolean;
var
  UserProf: string;
begin
  UserProf := GetEnv('USERPROFILE');
  Result := IsCommandInPath('radare2.exe') or
            FileExists('C:\radare2\bin\radare2.exe') or
            FileExists('C:\ProgramData\chocolatey\bin\radare2.exe') or
            ((UserProf <> '') and FileExists(UserProf + '\scoop\shims\radare2.exe')) or
            ((UserProf <> '') and FileExists(UserProf + '\scoop\apps\radare2\current\bin\radare2.exe'));
end;

function CheckMakeInstalled(): Boolean;
var
  UserProf: string;
begin
  UserProf := GetEnv('USERPROFILE');
  Result := IsCommandInPath('make.exe') or
            IsCommandInPath('mingw32-make.exe') or
            FileExists('C:\Program Files (x86)\GnuWin32\bin\make.exe') or
            FileExists('C:\Program Files\Git\usr\bin\make.exe') or
            FileExists('C:\msys64\usr\bin\make.exe') or
            FileExists('C:\msys64\mingw64\bin\mingw32-make.exe') or
            ((UserProf <> '') and FileExists(UserProf + '\scoop\apps\make\current\make.exe')) or
            ((UserProf <> '') and FileExists(UserProf + '\scoop\apps\make\current\bin\make.exe'));
end;

function CheckGitInstalled(): Boolean;
begin
  Result := IsCommandInPath('git.exe') or
            FileExists('C:\Program Files\Git\cmd\git.exe') or
            FileExists('C:\Program Files\Git\bin\git.exe') or
            FileExists(ExpandConstant('{localappdata}\Programs\Git\cmd\git.exe'));
end;

function CheckCrystallineInstalled(): Boolean;
var
  UserProf: string;
  ProgFiles: string;
begin
  UserProf := GetEnv('USERPROFILE');
  ProgFiles := GetEnv('ProgramFiles');
  Result := IsCommandInPath('crystalline.exe') or
            ((ProgFiles <> '') and FileExists(ProgFiles + '\Lapis\bin\crystalline.exe')) or
            FileExists('C:\Program Files\Lapis\bin\crystalline.exe') or
            FileExists('C:\Program Files\crystalline\bin\crystalline.exe') or
            FileExists('C:\crystalline\bin\crystalline.exe') or
            ((UserProf <> '') and FileExists(UserProf + '\scoop\shims\crystalline.exe')) or
            ((UserProf <> '') and FileExists(UserProf + '\scoop\apps\crystalline\current\crystalline.exe')) or
            FileExists(ExpandConstant('{localappdata}\Programs\Lapis\bin\crystalline.exe'));
end;

function CheckInnoSetupInstalled(): Boolean;
var
  UserProf: string;
  LocalApp: string;
begin
  UserProf := GetEnv('USERPROFILE');
  LocalApp := GetEnv('LOCALAPPDATA');
  Result := IsCommandInPath('iscc.exe') or
            IsCommandInPath('iscc') or
            FileExists('C:\Program Files (x86)\Inno Setup 6\ISCC.exe') or
            FileExists('C:\Program Files\Inno Setup 6\ISCC.exe') or
            FileExists('C:\Program Files (x86)\Inno Setup 7\ISCC.exe') or
            FileExists('C:\Program Files\Inno Setup 7\ISCC.exe') or
            FileExists('C:\ProgramData\chocolatey\bin\iscc.exe') or
            ((LocalApp <> '') and FileExists(LocalApp + '\Programs\Inno Setup 6\ISCC.exe')) or
            ((LocalApp <> '') and FileExists(LocalApp + '\Programs\Inno Setup 7\ISCC.exe')) or
            ((UserProf <> '') and FileExists(UserProf + '\scoop\apps\innosetup\current\ISCC.exe'));
end;

function AppendPathSafely(const ExistingPath: string; const Entry: string): string;
begin
  if Trim(ExistingPath) = '' then
    Result := Entry
  else if ExistingPath[Length(ExistingPath)] = ';' then
    Result := ExistingPath + Entry
  else
    Result := ExistingPath + ';' + Entry;
end;

procedure InitializeWizard;
var
  Desc: string;
begin
  HasCrystal := CheckCrystalInstalled();
  HasCrystalEnv := CheckCrystalEnvConfigured();
  HasMSVC := CheckMSVCInstalled();
  HasRadare2 := CheckRadare2Installed();
  HasMake := CheckMakeInstalled();
  HasGit := CheckGitInstalled();
  HasCrystalline := CheckCrystallineInstalled();
  HasInnoSetup := CheckInnoSetupInstalled();

  PrereqPage := CreateInputOptionPage(
    wpSelectDir,
    'Prerequisite Development Tools',
    'Detect and install essential toolchain dependencies',
    'Lapis relies on external command-line tools to build, debug, and provide editor intelligence for Godot Crystal games.' + #13#10 +
    'Select any missing tools below to have the installer automatically configure them.',
    False, False
  );

  // 0: Crystal Compiler & CRYSTAL_ENV
  if HasCrystal and HasCrystalEnv then
    Desc := 'Crystal Compiler 1.20+ & CRYSTAL_ENV (Found on system)'
  else if HasCrystal then
    Desc := 'Configure Crystal Environment & CRYSTAL_ENV (Crystal found; env vars missing)'
  else
    Desc := 'Install Crystal 1.21.0 & Configure CRYSTAL_ENV (Required for compiling game libraries)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[0] := (not HasCrystal) or (not HasCrystalEnv);

  // 1: MSVC C++ Build Tools & Linker
  if HasMSVC then
    Desc := 'MSVC C++ Build Tools & Linker (Found on system)'
  else
    Desc := 'Install MSVC C++ Build Tools (Required by Crystal on Windows to link DLLs)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[1] := not HasMSVC;

  // 2: radare2 Debugger
  if HasRadare2 then
    Desc := 'radare2 Native Debugger & Decompiler (Found on system)'
  else
    Desc := 'Install radare2 Native Debugger (Required for in-editor debugging & decompilation)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[2] := not HasRadare2;

  // 3: GNU Make
  if HasMake then
    Desc := 'GNU Make (Found on system)'
  else
    Desc := 'Install GNU Make (Required for project builds and build automation)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[3] := not HasMake;

  // 4: Git
  if HasGit then
    Desc := 'Git for Windows (Found on system)'
  else
    Desc := 'Install Git (Required for shards dependency resolution)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[4] := not HasGit;

  // 5: Crystalline LSP
  if HasCrystalline then
    Desc := 'Crystalline Language Server (Found on system)'
  else
    Desc := 'Install Crystalline LSP (Enables in-editor Crystal autocompletion & diagnostics)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[5] := not HasCrystalline;

  // 6: Inno Setup Compiler
  if HasInnoSetup then
    Desc := 'Inno Setup Compiler (Found on system)'
  else
    Desc := 'Install Inno Setup Compiler (Required for packaging Windows game installers)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[6] := not HasInnoSetup;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  DepsToInstall: string;
  ToolsArg: string;
  ResultCode: Integer;
  ScriptPath: string;
  PowerShellExe: string;
  AppBinDir: string;
  OrigPath: string;
  NewPath: string;
begin
  if CurStep = ssPostInstall then
  begin
    // 1. PATH Registration (before dependency script so {app}\bin is discoverable)
    if WizardIsTaskSelected('envPath') then
    begin
      AppBinDir := ExpandConstant('{app}\bin');
      if IsAdminInstallMode then
      begin
        if RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', OrigPath) then
        begin
          if Pos(Uppercase(AppBinDir), Uppercase(OrigPath)) = 0 then
          begin
            NewPath := AppendPathSafely(OrigPath, AppBinDir);
            if not RegWriteStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', NewPath) then
            begin
              if RegQueryStringValue(HKCU, 'Environment', 'Path', OrigPath) then
              begin
                if Pos(Uppercase(AppBinDir), Uppercase(OrigPath)) = 0 then
                  RegWriteStringValue(HKCU, 'Environment', 'Path', AppendPathSafely(OrigPath, AppBinDir));
              end
              else
                RegWriteStringValue(HKCU, 'Environment', 'Path', AppBinDir);
            end;
          end;
        end;
      end
      else
      begin
        if RegQueryStringValue(HKCU, 'Environment', 'Path', OrigPath) then
        begin
          if Pos(Uppercase(AppBinDir), Uppercase(OrigPath)) = 0 then
            RegWriteStringValue(HKCU, 'Environment', 'Path', AppendPathSafely(OrigPath, AppBinDir));
        end
        else
        begin
          RegWriteStringValue(HKCU, 'Environment', 'Path', AppBinDir);
        end;
      end;
    end;

    // 2. Dependency Auto-Installation & Crystal Environment Registration
    DepsToInstall := '';
    if PrereqPage.Values[0] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'crystal';
    end;
    if (not HasMSVC) and PrereqPage.Values[1] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'vctools';
    end;
    if (not HasRadare2) and PrereqPage.Values[2] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'radare2';
    end;
    if (not HasMake) and PrereqPage.Values[3] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'make';
    end;
    if (not HasGit) and PrereqPage.Values[4] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'git';
    end;
    if (not HasCrystalline) and PrereqPage.Values[5] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'crystalline';
    end;
    if (not HasInnoSetup) and PrereqPage.Values[6] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'innosetup';
    end;

    ScriptPath := ExpandConstant('{tmp}\install_deps.ps1');
    if FileExists(ScriptPath) then
    begin
      PowerShellExe := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
      if not FileExists(PowerShellExe) then
        PowerShellExe := 'powershell.exe';

      if Length(DepsToInstall) > 0 then
      begin
        ToolsArg := DepsToInstall;
        WizardForm.StatusLabel.Caption := 'Installing prerequisite development tools & configuring CRYSTAL_ENV...';
      end
      else
      begin
        ToolsArg := 'none';
        WizardForm.StatusLabel.Caption := 'Configuring Crystal environment variables (CRYSTAL_ENV)...';
      end;

      Exec(PowerShellExe, '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath + '" -Tools "' + ToolsArg + '" -ConfigureCrystalEnv -Silent', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppBinDir: string;
  OrigPath: string;
  PosIdx: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    AppBinDir := ExpandConstant('{app}\bin');
    // Remove from HKCU
    if RegQueryStringValue(HKCU, 'Environment', 'Path', OrigPath) then
    begin
      PosIdx := Pos(';' + AppBinDir, OrigPath);
      if PosIdx > 0 then
      begin
        Delete(OrigPath, PosIdx, Length(';' + AppBinDir));
        RegWriteStringValue(HKCU, 'Environment', 'Path', OrigPath);
      end
      else
      begin
        PosIdx := Pos(AppBinDir + ';', OrigPath);
        if PosIdx > 0 then
        begin
          Delete(OrigPath, PosIdx, Length(AppBinDir + ';'));
          RegWriteStringValue(HKCU, 'Environment', 'Path', OrigPath);
        end
        else if OrigPath = AppBinDir then
        begin
          RegWriteStringValue(HKCU, 'Environment', 'Path', '');
        end;
      end;
    end;
    // Remove from HKLM if installed in admin mode
    if IsAdminInstallMode and RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', OrigPath) then
    begin
      PosIdx := Pos(';' + AppBinDir, OrigPath);
      if PosIdx > 0 then
      begin
        Delete(OrigPath, PosIdx, Length(';' + AppBinDir));
        RegWriteStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', OrigPath);
      end
      else
      begin
        PosIdx := Pos(AppBinDir + ';', OrigPath);
        if PosIdx > 0 then
        begin
          Delete(OrigPath, PosIdx, Length(AppBinDir + ';'));
          RegWriteStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', OrigPath);
        end
        else if OrigPath = AppBinDir then
        begin
          RegWriteStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', '');
        end;
      end;
    end;
  end;
end;
