require "spec"
require "../src/libgodot/debugger/radare_driver"
require "../src/libgodot/debugger/decompiler"

describe Lapis::Debugger::Decompiler do
  it "initializes decompiler with active Cradare2 client" do
    if Lapis::Debugger::RadareDriver.available?
      test_bin = File.join(__DIR__, "..", "bin", "game.dll")
      if File.exists?(test_bin)
        Cradare2.open(test_bin) do |client|
          decompiler = Lapis::Debugger::Decompiler.new(client)
          decompiler.client.should eq(client)
        end
      else
        pending! "bin/game.dll not found for decompiler test"
      end
    else
      pending! "radare2 not installed on system PATH"
    end
  end

  it "disassembles instructions via disassemble_function" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    test_bin = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(test_bin)
      pending! "bin/game.dll not found for decompiler test"
    end

    Cradare2.open(test_bin) do |client|
      decompiler = Lapis::Debugger::Decompiler.new(client)
      # Query entry point or first symbol
      entry = (client.crystal.entrypoint rescue nil) || 0_u64
      if entry > 0
        disasm = decompiler.disassemble_function(entry)
        disasm.should_not be_empty
      end
    end
  end

  it "handles missing method symbols gracefully with informative comment" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    test_bin = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(test_bin)
      pending! "bin/game.dll not found for decompiler test"
    end

    Cradare2.open(test_bin) do |client|
      decompiler = Lapis::Debugger::Decompiler.new(client)
      res = decompiler.decompile_method("NonExistentClass", "missing_method")
      res.should contain("not found in analyzed binary symbols")
    end
  end

  it "discovers Crystal classes and structures via crystal_classes" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    test_bin = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(test_bin)
      pending! "bin/game.dll not found for decompiler test"
    end

    Cradare2.open(test_bin) do |client|
      decompiler = Lapis::Debugger::Decompiler.new(client)
      classes = decompiler.crystal_classes
      classes.should be_a(Array(String))
      # In compiled Crystal binary game.dll, client.crystal recognizes Crystal binary & classes
      client.crystal.crystal_binary?.should be_true

      # Test parsing symbol information via client.crystal
      sym_info = client.crystal.parse_symbol("*Player#_physics_process:Float64")
      sym_info.class_name.should eq("Player")
      sym_info.method_name.not_nil!.should contain("_physics_process")
      sym_info.is_instance_method.should be_true
    end
  end

  it "queries source location and source interleaved disassembly" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    test_bin = File.join(__DIR__, "..", "bin", "game.dll")
    unless File.exists?(test_bin)
      pending! "bin/game.dll not found for decompiler test"
    end

    Cradare2.open(test_bin) do |client|
      decompiler = Lapis::Debugger::Decompiler.new(client)
      entry = (client.crystal.entrypoint rescue nil) || 0_u64
      if entry > 0
        # Source location query shouldn't crash
        loc = decompiler.source_location_at(entry)
        (loc.nil? || loc.is_a?(String)).should be_true

        # Interleaved disassembly query should return a string
        dis = decompiler.source_disassembly_at(entry, count: 5)
        dis.should be_a(String)

        # Source location model query using Cradare2 Lines helper
        loc_model = decompiler.source_location_model(entry)
        (loc_model.nil? || loc_model.is_a?(Cradare2::Lines::SourceLocation)).should be_true

        # Source context lines query
        ctx = decompiler.source_context_at(entry, window: 3)
        ctx.should be_a(Array(NamedTuple(line: Int32, text: String, current: Bool)))
      end
    end
  end

  it "caches and reads virtual and local source context via SourceReader" do
    reader = Cradare2::Lines::SourceReader.new
    reader.register_source("virtual_player.cr", <<-CR)
      class VirtualPlayer < CharacterBody3D
        def _ready : Void
          puts "ready"
        end

        def _physics_process(delta : Float64) : Void
          move_and_slide
        end
      end
    CR

    reader.exists?("virtual_player.cr").should be_true
    reader.line_count("virtual_player.cr").should eq(9)
    reader.read_line("virtual_player.cr", 2).not_nil!.should contain("def _ready")

    ctx = reader.read_context("virtual_player.cr", 6, before: 1, after: 1)
    ctx.size.should eq(3)
    ctx[1][:line].should eq(6)
    ctx[1][:current].should be_true
    ctx[1][:text].should contain("def _physics_process")
  end
end
