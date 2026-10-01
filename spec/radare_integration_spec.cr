require "spec"
require "../src/libgodot/debugger/radare_driver"

describe "radare2 Integration" do
  it "detects radare2 binary on system PATH or configured location" do
    if Lapis::Debugger::RadareDriver.available?
      r2_path = Lapis::Debugger::RadareDriver.find_radare2
      r2_path.should_not be_nil
      if path = r2_path
        path.should_not be_empty
        File.exists?(path).should be_true
      end
    else
      pending! "radare2 not installed on system PATH"
    end
  end

  it "spawns radare2 process and verifies version non-blockingly" do
    unless Lapis::Debugger::RadareDriver.available?
      pending! "radare2 not installed on system PATH"
    end

    r2_path = Lapis::Debugger::RadareDriver.find_radare2 || "radare2"
    stdout = IO::Memory.new
    status = Process.run(
      r2_path,
      ["-v"],
      output: stdout
    )

    status.success?.should be_true
    stdout.to_s.downcase.should contain("radare2")
  end

  it "correctly manages pre-attach breakpoints without active process" do
    driver = Lapis::Debugger::RadareDriver.new
    driver.state.should eq(Lapis::Debugger::DriverState::Detached)

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
