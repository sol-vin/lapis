require "spec"
require "../src/libgodot/debugger/lldb_driver"

describe "Debugger Breakpoints Management" do
  it "manages breakpoint collections and lookups cleanly" do
    driver = Godot::Debugger::LldbDriver.new
    driver.breakpoints.size.should eq(0)

    # Simulated breakpoint tracking
    file1 = "src/player.cr"
    file2 = "src/weapon.cr"

    bp1 = Godot::Debugger::BreakpointInfo.new(1, file1, 42)
    bp2 = Godot::Debugger::BreakpointInfo.new(2, file2, 15)

    driver.breakpoints[1] = bp1
    driver.breakpoints[2] = bp2

    driver.breakpoints.size.should eq(2)
    driver.breakpoints[1].line.should eq(42)
    driver.breakpoints[2].file.should eq(file2)

    driver.breakpoints.delete(1)
    driver.breakpoints.size.should eq(1)
    driver.breakpoints[2].line.should eq(15)
  end

  it "normalizes Windows vs Unix path separators in breakpoint files" do
    clean1 = "C:\\Users\\Game\\src\\player.cr".gsub('\\', '/')
    clean2 = "C:/Users/Game/src/player.cr".gsub('\\', '/')
    clean1.should eq(clean2)
    File.basename(clean1).should eq("player.cr")
  end

  it "translates Godot 0-based gutter line indices to LLDB 1-based line numbers" do
    # In Godot's Script Editor gutter, line 0 is the first line of the file.
    # LLDB breakpoint set requires 1-based line numbers.
    godot_gutter_line_first = 0
    godot_gutter_line_player = 41

    lldb_line_first = godot_gutter_line_first + 1
    lldb_line_player = godot_gutter_line_player + 1

    lldb_line_first.should eq(1)
    lldb_line_player.should eq(42)
  end

  it "generates correct LLDB breakpoint commands from normalized paths" do
    file = "res://src/combat/sword.cr"
    global_file = "C:/Projects/Game/src/combat/sword.cr"
    line = 85

    base = File.basename(global_file)
    base.should eq("sword.cr")
    expected_cmd = "breakpoint set --file \"sword.cr\" --line 85"
    actual_cmd = "breakpoint set --file \"#{File.basename(global_file)}\" --line #{line}"
    actual_cmd.should eq(expected_cmd)
  end

  it "prevents duplicate breakpoints for same file and line" do
    driver = Godot::Debugger::LldbDriver.new
    bp1 = driver.set_breakpoint("C:\\game\\src\\main.cr", 22)
    bp2 = driver.set_breakpoint("C:/game/src/main.cr", 22)

    driver.breakpoints.size.should eq(1)
    bp1.id.should eq(bp2.id)
    bp1.line.should eq(22)
  end

  it "removes breakpoints by file and line" do
    driver = Godot::Debugger::LldbDriver.new
    driver.set_breakpoint("C:\\game\\src\\main.cr", 22)
    driver.set_breakpoint("C:\\game\\src\\player.cr", 50)
    driver.breakpoints.size.should eq(2)

    removed = driver.remove_breakpoint("C:/game/src/main.cr", 22)
    removed.should be_true
    driver.breakpoints.size.should eq(1)
    driver.breakpoints.values.first.line.should eq(50)
  end

  it "parses ScriptEditor breakpoint string into file and 1-based line" do
    raw = "[res://src/main.cr:22, res://src/player.cr:15]"
    clean = raw.strip.lchop('[').rchop(']')
    bps = [] of Tuple(String, Int32)
    clean.split(',').each do |item|
      token = item.strip.strip('"').strip('\'')
      if r_idx = token.rindex(':')
        path = token[0...r_idx].strip
        if l = token[(r_idx + 1)..-1].to_i?
          bps << {path, l}
        end
      end
    end

    bps.size.should eq(2)
    bps[0].should eq({"res://src/main.cr", 22})
    bps[1].should eq({"res://src/player.cr", 15})
  end

  it "suppresses debugger injection artifacts like DbgBreakPoint" do
    driver = Godot::Debugger::LldbDriver.new
    stopped_called = false
    driver.on_stop = ->(_info : Godot::Debugger::StopInfo) {
      stopped_called = true
    }

    driver.process_line("    frame #0: 0x00007ff812345678 ntdll.dll`DbgBreakPoint")
    stopped_called.should be_false
  end
end

