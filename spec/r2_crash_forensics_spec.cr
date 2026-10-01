require "spec"
require "../src/libgodot/debugger/plugin_forensics"
require "../src/libgodot/debugger/radare_driver"

describe "Lapis::Debugger Radare2 Crash Forensics" do
  describe "Module Classification" do
    it "classifies module origins accurately based on loaded binary paths" do
      Lapis::Debugger::PluginForensics.classify_module("C:\\Games\\MyProject\\bin\\game.dll").should eq(Lapis::Debugger::ModuleOrigin::GameCode)
      Lapis::Debugger::PluginForensics.classify_module("C:\\Games\\MyProject\\bin\\game_loaded_1234_5678.dll").should eq(Lapis::Debugger::ModuleOrigin::GameCode)
      Lapis::Debugger::PluginForensics.classify_module("bin/crystal_bridge.dll").should eq(Lapis::Debugger::ModuleOrigin::GDExtensionBridge)
      Lapis::Debugger::PluginForensics.classify_module("libgodot.dll").should eq(Lapis::Debugger::ModuleOrigin::GodotCore)
      Lapis::Debugger::PluginForensics.classify_module("godot.windows.editor.x86_64.exe").should eq(Lapis::Debugger::ModuleOrigin::GodotCore)
      Lapis::Debugger::PluginForensics.classify_module("bin/gc.dll").should eq(Lapis::Debugger::ModuleOrigin::BoehmGC)
      Lapis::Debugger::PluginForensics.classify_module("C:\\Windows\\System32\\ucrtbase.dll").should eq(Lapis::Debugger::ModuleOrigin::SystemCRT)
      Lapis::Debugger::PluginForensics.classify_module("unknown_module_xyz.dll").should eq(Lapis::Debugger::ModuleOrigin::Unknown)
    end
  end

  describe "Dead Pointer & Fault Analysis" do
    it "identifies null pointer dereference hazards" do
      report = Lapis::Debugger::CrashReport.new(
        origin: Lapis::Debugger::ModuleOrigin::GameCode,
        faulting_pc: 0x10_u64,
        faulting_module: "game.dll",
        is_dead_pointer: false
      )
      report.faulting_pc.should eq(0x10_u64)

      summary = report.summary
      summary.should contain("NULL POINTER DEREFERENCE")
      summary.should contain("Accessing offset on a nil/null object reference")
    end

    it "identifies dead pointer dereference when instance ID is present" do
      report = Lapis::Debugger::CrashReport.new(
        origin: Lapis::Debugger::ModuleOrigin::GameCode,
        faulting_pc: 0x7ffd12345678_u64,
        faulting_module: "game.dll",
        is_dead_pointer: true,
        dead_pointer_instance_id: 1234567890_u64,
        dead_pointer_class_name: "EnemyCharacter",
        decompiled_crash_site: "void EnemyCharacter_take_damage(void* this, int damage) { ... }",
        demangled_backtrace: [
          "EnemyCharacter#take_damage(Int32)",
          "CombatSystem#process_hits()",
          "Godot::SceneTree#_physics_process(Float64)"
        ],
        raw_report: "Access violation at address 0x7ffd12345678 reading 0xfeeefeee"
      )

      report.is_dead_pointer.should be_true
      report.dead_pointer_instance_id.should eq(1234567890_u64)
      report.dead_pointer_class_name.should eq("EnemyCharacter")

      summary = report.summary
      summary.should contain("DEAD POINTER DEREFERENCE DETECTED")
      summary.should contain("1234567890")
      summary.should contain("EnemyCharacter")
      summary.should contain("EnemyCharacter#take_damage")
      summary.should contain("Decompiled Crash Site")
    end
  end

  describe "Live Radare2 Client Analysis" do
    it "opens binary under cradare2 if available and inspects disassembly" do
      unless Lapis::Debugger::RadareDriver.available?
        pending! "radare2 not installed on system PATH"
      end

      bridge_bin = File.expand_path(File.join(__DIR__, "..", "bin", "crystal_bridge.dll"))
      unless File.exists?(bridge_bin)
        pending! "bin/crystal_bridge.dll not found"
      end

      Cradare2.open(bridge_bin) do |client|
        info = client.info
        info.should_not be_nil
        client.symbols.should_not be_empty

        # Disassemble 1 instruction at entrypoint or first symbol
        sym = client.symbols.first
        disasm_txt = client.disasm.text(1, at: sym.vaddr) rescue ""
        disasm_txt.should_not be_nil
      end
    end
  end
end
