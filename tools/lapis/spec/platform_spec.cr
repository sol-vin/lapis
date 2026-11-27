# tools/lapis/spec/platform_spec.cr
require "./spec_helper"

describe "Lapis Platform-Specific Operations" do
  describe "platform identification and extensions" do
    it "identifies the current host platform" do
      plat = Lapis::Core::Env.current_platform
      ["windows", "linux", "macos"].should contain(plat)
    end

    it "resolves the appropriate dynamic library extension" do
      ext = Lapis::Core::Env.dll_ext
      if Lapis::Core::Env.windows?
        ext.should eq("dll")
      elsif Lapis::Core::Env.macos?
        ext.should eq("dylib")
      else
        ext.should eq("so")
      end
    end

    it "resolves the appropriate executable extension" do
      ext = Lapis::Core::Env.exe_ext
      if Lapis::Core::Env.windows?
        ext.should eq(".exe")
      else
        ext.should eq("")
      end
    end

    it "resolves the appropriate path separator" do
      sep = Lapis::Core::Env.path_sep
      if Lapis::Core::Env.windows?
        sep.should eq(";")
      else
        sep.should eq(":")
      end
    end

    it "resolves appropriate linker flags" do
      flags = Lapis::Core::Env.link_flags
      if Lapis::Core::Env.windows?
        flags.should contain("/DLL")
        flags.should contain("crystal_godot_init")
      elsif Lapis::Core::Env.macos?
        flags.should eq("-dynamiclib")
      else
        flags.should eq("-shared")
      end
    end
  end

  describe "foreign and native binary classification" do
    it "classifies native and foreign binaries correctly" do
      if Lapis::Core::Env.windows?
        Lapis::Core::Env.is_native_binary?("game.dll").should be_true
        Lapis::Core::Env.is_native_binary?("game.exe").should be_true
        Lapis::Core::Env.is_foreign_binary?("game.so").should be_true
        Lapis::Core::Env.is_foreign_binary?("game.dylib").should be_true
        Lapis::Core::Env.is_foreign_binary?("game.deb").should be_true
      elsif Lapis::Core::Env.linux?
        Lapis::Core::Env.is_native_binary?("game.so").should be_true
        Lapis::Core::Env.is_foreign_binary?("game.dll").should be_true
        Lapis::Core::Env.is_foreign_binary?("game.exe").should be_true
        Lapis::Core::Env.is_foreign_binary?("game.dylib").should be_true
      elsif Lapis::Core::Env.macos?
        Lapis::Core::Env.is_native_binary?("game.dylib").should be_true
        Lapis::Core::Env.is_foreign_binary?("game.dll").should be_true
        Lapis::Core::Env.is_foreign_binary?("game.so").should be_true
      end
    end

    it "purges foreign binaries without removing native ones" do
      LapisSpecHelper.with_temp_dir("purge_test") do |dir|
        # Create a mock native file and mock foreign file
        native_file = dir.join(Lapis::Core::Env.windows? ? "test.dll" : (Lapis::Core::Env.macos? ? "test.dylib" : "test.so"))
        foreign_file = dir.join(Lapis::Core::Env.windows? ? "test.so" : "test.dll")

        File.write(native_file, "dummy native content")
        File.write(foreign_file, "dummy foreign content")

        File.exists?(native_file).should be_true
        File.exists?(foreign_file).should be_true

        purged = Lapis::Core::Env.purge_foreign_binaries(dir)
        purged.should be >= 1

        File.exists?(native_file).should be_true
        File.exists?(foreign_file).should be_false
      end
    end
  end

  describe "Windows installer and Crystal environment registration definitions" do
    it "verifies install_deps.ps1 installs Crystal 1.21.0 and registers CRYSTAL_ENV and crystal env paths" do
      deps_ps1 = LapisSpecHelper.repo_root.join("scripts/windows/install_deps.ps1")
      File.exists?(deps_ps1).should be_true
      content = File.read(deps_ps1)
      content.should contain("$TargetCrystalVersion = \"1.21.0\"")
      content.should contain("crystal-$TargetCrystalVersion-windows-x86_64-msvc-unsupported.zip")
      content.should_not contain("1.15.1")
      content.should_not contain("CrystalLang.Crystal")
      content.should contain("Programs\\Crystal\\crystal.exe")
      content.should contain("scoop\\apps\\crystal\\current\\crystal.exe")
      content.should contain("Register-CrystalEnvironment")
      content.should contain("CRYSTAL_ENV")
      content.should contain("CRYSTAL_PATH")
      content.should contain("CRYSTAL_LIBRARY_PATH")
      content.should contain("CRYSTAL_CACHE_DIR")
      content.should contain("CRYSTAL_EXEC_PATH")
      content.should contain("SendMessageTimeout")
    end

    it "verifies lapis_installer.iss and install.ps1 always invoke Crystal environment configuration" do
      iss_path = LapisSpecHelper.repo_root.join("packaging/windows/lapis_installer.iss")
      iss_content = File.read(iss_path)
      iss_content.should contain("HasCrystalEnv")
      iss_content.should contain("CheckCrystalEnvConfigured")
      iss_content.should contain("CheckMSVCInstalled")
      iss_content.should contain("\\Programs\\Crystal\\crystal.exe")
      iss_content.should contain("\\scoop\\apps\\crystal\\current\\crystal.exe")
      iss_content.should contain("-ConfigureCrystalEnv")

      install_ps1 = LapisSpecHelper.repo_root.join("scripts/windows/install.ps1")
      install_content = File.read(install_ps1)
      install_content.should contain("raw.githubusercontent.com/sol-vin/lapis/master/scripts/windows/install_deps.ps1")
      install_content.should_not contain("raw.githubusercontent.com/sol-vin/lapis/main/")
      install_content.should contain("-ConfigureCrystalEnv")
    end
  end

  # Platform-specific conditional suites
  {% if flag?(:windows) %}
    describe "Windows-Specific Features" do
      it "validates PowerShell AST syntax for Windows installer scripts" do
        ["scripts/windows/install_deps.ps1", "scripts/windows/install.ps1"].each do |rel|
          ps_file = LapisSpecHelper.repo_root.join(rel).to_s.gsub("'", "''")
          cmd = "$errs = $null; [void][System.Management.Automation.Language.Parser]::ParseFile('#{ps_file}', [ref]$null, [ref]$errs); if ($errs.Count -gt 0) { $errs | ForEach-Object { Write-Error $_.ToString() }; exit 1 }"
          res = Lapis::Core::ProcessRunner.capture("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", cmd])
          res[:status].success?.should be_true, "PowerShell syntax error in #{rel}:\n#{res[:output]}\n#{res[:error]}"
        end
      end
      it "has valid Inno Setup installer script definition" do
        iss_path = LapisSpecHelper.repo_root.join("packaging/windows/lapis_installer.iss")
        File.exists?(iss_path).should be_true
        content = File.read(iss_path)
        content.should contain("[Setup]")
        content.should contain("AppName=Lapis")
        content.should contain("DefaultDirName={autopf}\\Lapis")
        content.should contain("lapis.exe")
        content.should contain("HasCrystal")
        content.should contain("crystalline.exe")
        content.should contain("HasCrystalline")
        content.should contain("CheckCrystallineInstalled")
        content.should contain("radare2.exe")
        content.should contain("HasRadare2")
        content.should contain("CheckRadare2Installed")
      end

      it "lists complete Windows runtime dependencies" do
        bins = Lapis::Core::Env.platform_bin_files
        bins.should contain("crystal_bridge.dll")
        bins.should contain("gc.dll")
        bins.should contain("iconv-2.dll")
        bins.should contain("pcre2-8.dll")
        bins.should contain("libgodot.dll")
      end

      it "verifies find_iscc runs safely on Windows" do
        # Should return String if installed, or nil if not installed, without crashing
        iscc = Lapis::Commands::Package.find_iscc
        (iscc.nil? || iscc.is_a?(String)).should be_true
      end

      it "verifies ToolChecker finds Inno Setup and reports status" do
        iscc = Lapis::Core::ToolChecker.find_inno_setup
        status = Lapis::Core::ToolChecker.check_inno_setup
        status.name.should eq("innosetup")
        status.required.should be_false
        if iscc
          status.installed.should be_true
          status.path.should eq(iscc)
        end
      end

      it "verifies lapis_installer.iss includes Inno Setup prerequisite" do
        iss_path = LapisSpecHelper.repo_root.join("packaging/windows/lapis_installer.iss")
        File.exists?(iss_path).should be_true
        content = File.read(iss_path)
        content.should contain("HasInnoSetup: Boolean;")
        content.should contain("CheckInnoSetupInstalled")
        content.should contain("Inno Setup Compiler")
        content.should contain("innosetup")
      end
    end
  {% elsif flag?(:linux) %}
    describe "Linux-Specific Features" do
      it "lists complete Linux runtime dependencies" do
        bins = Lapis::Core::Env.platform_bin_files
        bins.should contain("crystal_bridge.so")
        bins.should contain("libgodot.so")
      end
    end
  {% elsif flag?(:darwin) %}
    describe "macOS-Specific Features" do
      it "lists complete macOS runtime dependencies" do
        bins = Lapis::Core::Env.platform_bin_files
        bins.should contain("crystal_bridge.dylib")
        bins.should contain("libgodot.dylib")
      end
    end
  {% end %}
end
