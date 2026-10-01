require "spec"
require "../src/libgodot/debugger/plugin_forensics"

describe Lapis::Debugger::PluginForensics do
  describe ".classify_module" do
    it "accurately classifies module names into domain origins" do
      classify = ->(name : String) { Lapis::Debugger::PluginForensics.classify_module(name) }

      classify.call("game.dll").should eq(Lapis::Debugger::ModuleOrigin::GameCode)
      classify.call("game_loaded_12345_67890.dll").should eq(Lapis::Debugger::ModuleOrigin::GameCode)
      classify.call("game.exe").should eq(Lapis::Debugger::ModuleOrigin::GameCode)
      classify.call("plugin.dll").should eq(Lapis::Debugger::ModuleOrigin::LapisPlugin)
      classify.call("crystal_bridge.dll").should eq(Lapis::Debugger::ModuleOrigin::GDExtensionBridge)
      classify.call("godot.windows.editor.x86_64.exe").should eq(Lapis::Debugger::ModuleOrigin::GodotCore)
      classify.call("libgodot.dll").should eq(Lapis::Debugger::ModuleOrigin::GodotCore)
      classify.call("gc.dll").should eq(Lapis::Debugger::ModuleOrigin::BoehmGC)
      classify.call("ntdll.dll").should eq(Lapis::Debugger::ModuleOrigin::SystemCRT)
      classify.call("kernel32.dll").should eq(Lapis::Debugger::ModuleOrigin::SystemCRT)
      classify.call("random_third_party.dll").should eq(Lapis::Debugger::ModuleOrigin::Unknown)
    end
  end

  describe Lapis::Debugger::CrashReport do
    it "generates clean forensics report for dead pointer dereference" do
      report = Lapis::Debugger::CrashReport.new(
        origin: Lapis::Debugger::ModuleOrigin::GameCode,
        faulting_pc: 0x140023450_u64,
        faulting_module: "game.dll",
        is_dead_pointer: true,
        dead_pointer_instance_id: 123456789_u64,
        dead_pointer_class_name: "Enemy",
        decompiled_crash_site: "void Player::attack() { ((Node*)rcx)->queue_free(); }",
        demangled_backtrace: ["Player#attack at player.cr:45", "Main#_process at main.cr:12"]
      )

      summary = report.summary
      summary.should contain("DEAD POINTER DEREFERENCE DETECTED")
      summary.should contain("123456789")
      summary.should contain("Target Class:     Enemy")
      summary.should contain("Player#attack at player.cr:45")
      summary.should contain("Decompiled Crash Site (pdc)")
    end

    it "generates clean forensics report for null pointer dereference" do
      report = Lapis::Debugger::CrashReport.new(
        origin: Lapis::Debugger::ModuleOrigin::GameCode,
        faulting_pc: 0x8_u64,
        faulting_module: "game.dll",
        is_dead_pointer: false
      )

      summary = report.summary
      summary.should contain("NULL POINTER DEREFERENCE")
      summary.should contain("Faulting PC:      0x8")
    end
  end
end
