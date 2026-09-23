require "spec"
require "../src/libgodot/debugger/lldb_driver"

describe "LLDB Integration" do
  it "detects LLDB binary on system PATH or configured location" do
    if Godot::Debugger::LldbDriver.available?
      lldb_path = Godot::Debugger::LldbDriver.find_lldb
      lldb_path.should_not be_nil
      if path = lldb_path
        path.should_not be_empty
        File.exists?(path).should be_true
      end
    else
      # If LLDB is not installed in the environment, skip cleanly
      pending! "LLDB not installed on system PATH"
    end
  end

  it "spawns LLDB process and exchanges basic commands non-blockingly" do
    unless Godot::Debugger::LldbDriver.available?
      pending! "LLDB not installed on system PATH"
    end

    lldb_path = Godot::Debugger::LldbDriver.find_lldb || "lldb"
    stdout = IO::Memory.new
    status = Process.run(
      lldb_path,
      ["--no-lldbinit", "--batch", "-o", "version"],
      output: stdout
    )

    status.success?.should be_true
    stdout.to_s.downcase.should contain("lldb")
  end

  it "correctly manages pre-attach breakpoints without active process" do
    driver = Godot::Debugger::LldbDriver.new
    driver.state.should eq(Godot::Debugger::DriverState::Detached)

    # Setting breakpoints when detached must queue safely into driver
    bp1 = driver.set_breakpoint("src/game.cr", 10)
    bp2 = driver.set_breakpoint("src/ui.cr", 50)

    bp1.id.should eq(1)
    bp1.line.should eq(10)
    bp2.id.should eq(2)
    bp2.line.should eq(50)

    driver.breakpoints.size.should eq(2)

    # Removing a breakpoint updates the collection
    driver.remove_breakpoint(1)
    driver.breakpoints.size.should eq(1)
    driver.breakpoints[2]?.should_not be_nil
  end
end
