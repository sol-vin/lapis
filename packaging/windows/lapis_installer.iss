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
Source: "{#SourceDir}\*.dll"; DestDir: "{app}\bin"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\README.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\install_deps.ps1"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\Lapis Command Prompt"; Filename: "{cmd}"; Parameters: "/k ""{app}\bin\lapis.exe --help"""
Name: "{group}\Uninstall Lapis"; Filename: "{uninstallexe}"

[Code]
var
  PrereqPage: TInputOptionWizardPage;
  HasCrystal: Boolean;
  HasLldb: Boolean;
  HasMake: Boolean;
  HasGit: Boolean;

function IsCommandInPath(const Cmd: string): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec(ExpandConstant('{cmd}'), '/c where ' + Cmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

function CheckCrystalInstalled(): Boolean;
var
  UserProf: string;
begin
  UserProf := GetEnv('USERPROFILE');
  Result := IsCommandInPath('crystal.exe') or
            FileExists('C:\Program Files\Crystal\bin\crystal.exe') or
            FileExists('C:\Crystal\bin\crystal.exe') or
            ((UserProf <> '') and FileExists(UserProf + '\scoop\apps\crystal\current\bin\crystal.exe'));
end;

function CheckLldbInstalled(): Boolean;
var
  UserProf: string;
begin
  UserProf := GetEnv('USERPROFILE');
  Result := IsCommandInPath('lldb.exe') or
            FileExists('C:\Program Files\LLVM\bin\lldb.exe') or
            FileExists('C:\Program Files (x86)\LLVM\bin\lldb.exe') or
            FileExists('C:\ProgramData\llvm\bin\lldb.exe') or
            ((UserProf <> '') and FileExists(UserProf + '\scoop\apps\llvm\current\bin\lldb.exe')) or
            FileExists('C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\bin\lldb.exe') or
            FileExists('C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\Llvm\bin\lldb.exe') or
            FileExists('C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\Llvm\bin\lldb.exe') or
            FileExists('C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\Llvm\bin\lldb.exe');
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
            ((UserProf <> '') and FileExists(UserProf + '\scoop\apps\make\current\make.exe'));
end;

function CheckGitInstalled(): Boolean;
begin
  Result := IsCommandInPath('git.exe') or
            FileExists('C:\Program Files\Git\cmd\git.exe') or
            FileExists('C:\Program Files\Git\bin\git.exe') or
            FileExists(ExpandConstant('{localappdata}\Programs\Git\cmd\git.exe'));
end;

procedure InitializeWizard;
var
  Desc: string;
begin
  HasCrystal := CheckCrystalInstalled();
  HasLldb := CheckLldbInstalled();
  HasMake := CheckMakeInstalled();
  HasGit := CheckGitInstalled();

  PrereqPage := CreateInputOptionPage(
    wpSelectDir,
    'Prerequisite Development Tools',
    'Detect and install essential toolchain dependencies',
    'Lapis relies on external command-line tools to build, debug, and provide editor intelligence for Godot Crystal games.' + #13#10 +
    'Select any missing tools below to have the installer automatically configure them.',
    False, False
  );

  // Crystal Compiler
  if HasCrystal then
    Desc := 'Crystal Compiler (Found on system)'
  else
    Desc := 'Install Crystal Compiler (Required for compiling game libraries)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[0] := not HasCrystal;

  // LLDB Debugger
  if HasLldb then
    Desc := 'LLDB Native Debugger (Found on system)'
  else
    Desc := 'Install LLVM & LLDB Debugger (Required for in-editor and native debugging)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[1] := not HasLldb;

  // GNU Make
  if HasMake then
    Desc := 'GNU Make (Found on system)'
  else
    Desc := 'Install GNU Make (Required for project builds and build automation)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[2] := not HasMake;

  // Git
  if HasGit then
    Desc := 'Git for Windows (Found on system)'
  else
    Desc := 'Install Git (Required for shards dependency resolution)';
  PrereqPage.Add(Desc);
  PrereqPage.Values[3] := not HasGit;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  DepsToInstall: string;
  ResultCode: Integer;
  ScriptPath: string;
  PowerShellExe: string;
  AppBinDir: string;
  OrigPath: string;
  NewPath: string;
begin
  if CurStep = ssPostInstall then
  begin
    // 1. Dependency Auto-Installation
    DepsToInstall := '';
    if (not HasCrystal) and PrereqPage.Values[0] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'crystal';
    end;
    if (not HasLldb) and PrereqPage.Values[1] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'lldb';
    end;
    if (not HasMake) and PrereqPage.Values[2] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'make';
    end;
    if (not HasGit) and PrereqPage.Values[3] then
    begin
      if Length(DepsToInstall) > 0 then DepsToInstall := DepsToInstall + ',';
      DepsToInstall := DepsToInstall + 'git';
    end;

    if Length(DepsToInstall) > 0 then
    begin
      ScriptPath := ExpandConstant('{tmp}\install_deps.ps1');
      if FileExists(ScriptPath) then
      begin
        PowerShellExe := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
        if not FileExists(PowerShellExe) then
          PowerShellExe := 'powershell.exe';

        WizardForm.StatusLabel.Caption := 'Installing prerequisite development tools...';
        Exec(PowerShellExe, '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath + '" -Tools ' + DepsToInstall + ' -Silent', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
      end;
    end;

    // 2. PATH Registration
    if WizardIsTaskSelected('envPath') then
    begin
      AppBinDir := ExpandConstant('{app}\bin');
      if IsAdminInstallMode then
      begin
        if RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', OrigPath) then
        begin
          if Pos(Uppercase(AppBinDir), Uppercase(OrigPath)) = 0 then
          begin
            NewPath := OrigPath + ';' + AppBinDir;
            if not RegWriteStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', NewPath) then
            begin
              // Fallback to HKCU if writing to HKLM was rejected
              if RegQueryStringValue(HKCU, 'Environment', 'Path', OrigPath) then
              begin
                if Pos(Uppercase(AppBinDir), Uppercase(OrigPath)) = 0 then
                  RegWriteStringValue(HKCU, 'Environment', 'Path', OrigPath + ';' + AppBinDir);
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
          begin
            NewPath := OrigPath + ';' + AppBinDir;
            RegWriteStringValue(HKCU, 'Environment', 'Path', NewPath);
          end;
        end
        else
        begin
          RegWriteStringValue(HKCU, 'Environment', 'Path', AppBinDir);
        end;
      end;
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

