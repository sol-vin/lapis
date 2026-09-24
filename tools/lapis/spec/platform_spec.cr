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

  # Platform-specific conditional suites
  {% if flag?(:windows) %}
    describe "Windows-Specific Features" do
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
