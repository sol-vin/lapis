require "spec"
require "../src/libgodot/debugger/context_classifier"

describe Godot::Debugger::ContextClassifier do
  classifier = Godot::Debugger::ContextClassifier.new

  it "classifies User Game code accurately" do
    ctx = classifier.classify("src/entities/player.cr", "Player#move_and_slide", "game.dll")
    ctx.domain.should eq(Godot::Debugger::ContextDomain::Game)
    ctx.badge.should eq("[Context: Game]")

    ctx2 = classifier.classify("src/main.cr", "__crystal_main", "game.exe")
    ctx2.domain.should eq(Godot::Debugger::ContextDomain::Game)
  end

  it "classifies Addon code with extracted addon name" do
    ctx = classifier.classify("addons/fancy_particles/emitter.cr", "Emitter#burst", "fancy_particles.dll")
    ctx.domain.should eq(Godot::Debugger::ContextDomain::Addon)
    ctx.addon_name.should eq("fancy_particles")
    ctx.badge.should eq("[Context: Addon 'fancy_particles']")
  end

  it "classifies Editor Plugin code" do
    ctx = classifier.classify("addons/crystal_integration/crystal_debugger_plugin.cr", "CrystalDebuggerPlugin#setup", "crystal_integration.dll")
    ctx.domain.should eq(Godot::Debugger::ContextDomain::Plugin)
    ctx.badge.should eq("[Context: Editor Plugin]")
  end

  it "classifies GDExtension C++ loader bridge" do
    ctx = classifier.classify("src/bridge/crystal_bridge.cpp", "crystal_godot_init", "crystal_bridge.dll")
    ctx.domain.should eq(Godot::Debugger::ContextDomain::Bridge)
    ctx.badge.should eq("[Context: GDExtension Bridge]")
  end

  it "classifies Godot Engine Core" do
    ctx = classifier.classify(nil, "godot_object_method_bind_ptrcall", "godot.windows.editor.x86_64.exe")
    ctx.domain.should eq(Godot::Debugger::ContextDomain::Engine)
    ctx.badge.should eq("[Context: Godot Core]")

    ctx2 = classifier.classify(nil, "ObjectDB::get_instance", "libgodot.dll")
    ctx2.domain.should eq(Godot::Debugger::ContextDomain::Engine)
  end

  it "classifies Boehm GC and Crystal Runtime" do
    ctx = classifier.classify(nil, "GC_malloc", "gc.dll")
    ctx.domain.should eq(Godot::Debugger::ContextDomain::Runtime)
    ctx.badge.should eq("[Context: Crystal Runtime]")

    ctx2 = classifier.classify(nil, "pcre2_compile_8", "pcre2-8.dll")
    ctx2.domain.should eq(Godot::Debugger::ContextDomain::Runtime)
  end

  it "classifies System CRT and NTDLL" do
    ctx = classifier.classify(nil, "KiUserExceptionDispatcher", "ntdll.dll")
    ctx.domain.should eq(Godot::Debugger::ContextDomain::System)
    ctx.badge.should eq("[Context: System CRT]")

    ctx2 = classifier.classify(nil, "RaiseException", "kernel32.dll")
    ctx2.domain.should eq(Godot::Debugger::ContextDomain::System)
  end

  it "provides clean string formatting for ExecutionContext" do
    ctx = classifier.classify("src/player.cr", "Player#jump", "game.dll")
    str = ctx.to_s
    str.should contain("[Context: Game]")
    str.should contain("in game.dll")
    str.should contain("(src/player.cr)")
    str.should contain("-> Player#jump")
  end
end
