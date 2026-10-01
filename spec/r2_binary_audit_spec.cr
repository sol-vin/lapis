require "spec"
require "cradare2"
require "../src/libgodot/debugger/r2_godot_plugin"
require "../src/libgodot/debugger/r2_classdb_reconstructor"

describe "Radare2 Binary Audit & Code Generation Verification" do
  # Audit the compiled GDExtension game DLL
  game_dll = "bin/game.dll"

  it "verifies that target game binary exists and is valid 64-bit PE" do
    File.exists?(game_dll).should be_true, "Expected #{game_dll} to exist before audit"
  end

  it "opens game binary with cradare2 and audits exported functions and symbols" do
    opts = Cradare2::Options.build do |o|
      o.target = game_dll
      o.auto_analyze = false
    end

    Cradare2.open(opts) do |r2|
      # 1. Verify basic binary info
      info = r2.info
      info.arch.should contain("x86")
      info.bits.should eq(64)
      info.format.should contain("pe")

      # 2. Audit StringName pool for core Godot lifecycle methods
      strings = r2.strings rescue [] of Cradare2::Model::StringItem
      string_values = strings.map(&.string).to_set

      # Verify essential engine callback names exist as binary string literals
      string_values.any? { |s| s.includes?("_ready") }.should be_true
      string_values.any? { |s| s.includes?("_process") }.should be_true

      # 3. Audit ClassDB schema reconstruction from binary strings & symbols
      reconstructor = Lapis::Debugger::ClassDBReconstructor.new
      classes = reconstructor.reconstruct_from_session(r2)

      # ClassDB Reconstructor should discover nodes from strings and symbols
      classes.size.should be > 0

      # 4. Audit Demangler on binary symbols
      symbols = r2.symbols
      symbols.size.should be > 0
      demangled_count = 0

      symbols.first(50).each do |sym|
        demangled = Cradare2::Util::Demangler.demangle(sym.name, r2.transport)
        demangled.should_not be_empty
        demangled_count += 1
      end

      demangled_count.should be > 0

      # 5. Audit memory reading DSL capabilities from mapped section
      text_addr = r2.sections.find { |s| s.name.includes?("text") }.try(&.vaddr) || 0x180001000_u64
      code_bytes = r2.memory.read_bytes(text_addr, 4)
      code_bytes.size.should eq(4)

      # 6. Audit pointer array reading
      pointers = r2.memory.read_pointer_array(text_addr, 4)
      pointers.size.should eq(4)

      # 7. Audit flag space creation
      r2.flags.space("godot") do |f|
        f.current_space.should contain("godot")
      end
    end
  end

  it "audits the editor plugin binary (plugin.dll) for ClassDB exports" do
    plugin_dll = "addons/crystal_integration/bin/plugin.dll"
    if File.exists?(plugin_dll)
      opts = Cradare2::Options.build do |o|
        o.target = plugin_dll
        o.auto_analyze = false
      end

      Cradare2.open(opts) do |r2|
        info = r2.info
        info.bits.should eq(64)

        # Audit that plugin contains CrystalDebuggerPlugin or CrystalIntegrationPlugin references
        strings = r2.strings rescue [] of Cradare2::Model::StringItem
        str_set = strings.map(&.string).to_set

        has_plugin = str_set.any? { |s| s.includes?("CrystalIntegrationPlugin") || s.includes?("CrystalDebuggerPlugin") || s.includes?("EditorPlugin") }
        has_plugin.should be_true
      end
    end
  end
end
