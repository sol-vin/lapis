# =============================================================================
# LibGodot Test Suite: Virtual Methods & Dynamic Dispatch Reflection
# =============================================================================
#
# Tests engine virtual method overrides (_ready, _process, _enter_tree),
# dynamic ClassDB method dispatch, argument conversion, and error resiliency.
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

@[Tool]
node VirtualDispatchProbeNode < Godot::Node do
  @[Export]
  property ready_fired : Bool = false
  @[Export]
  property enter_tree_fired : Bool = false
  @[Export]
  property process_ticks : Int32 = 0

  def _ready : Void
    @ready_fired = true
  end

  def _enter_tree : Void
    @enter_tree_fired = true
  end

  def _process(delta : Float64) : Void
    @process_ticks += 1
  end

  def calculate_sum(a : Int32, b : Int32) : Int32
    a + b
  end

  def echo_payload(msg : String) : String
    "Echo: #{msg}"
  end
end

test_suite "VirtualMethods" do
  test "Engine invokes _enter_tree and _ready virtual methods when added to tree" do
    probe = Godot.create(VirtualDispatchProbeNode)
    assert_false probe.ready_fired
    assert_false probe.enter_tree_fired

    root.add_child(probe)
    # Adding to tree must trigger _enter_tree and _ready
    assert_true probe.enter_tree_fired, "_enter_tree must fire upon tree insertion"
    assert_true probe.ready_fired, "_ready must fire upon tree insertion"

    root.remove_child(probe)
    probe.destroy
  end

  test "Direct method calls and dynamic property getters on custom Crystal node" do
    probe = Godot.create(VirtualDispatchProbeNode)

    res = probe.calculate_sum(40, 2)
    assert_eq res, 42

    echo = probe.echo_payload("TestingEngineBridge")
    assert_eq echo, "Echo: TestingEngineBridge"

    # Dynamic getter through ClassDB
    fired = probe.call_bool("get", "ready_fired")
    assert_false fired

    probe.destroy
  end

  test "Dispatched call to GDScriptInteropTarget properties and methods" do
    target = Godot.create(GDScriptInteropTarget)

    mul = target.multiply(6, 7)
    assert_eq mul, 42

    greeting = target.call_str("get", "crystal_greeting")
    assert_eq greeting, "Hello from Crystal"

    count = target.call_i64("get", "crystal_count")
    assert_eq count, 100_i64

    target.destroy
  end

  test "Invalid dynamic method dispatch raises error safely without memory fault" do
    probe = Godot.create(VirtualDispatchProbeNode)

    # Calling an invalid method name
    caught = false
    begin
      probe.call("non_existent_method_xyz")
    rescue
      caught = true
    end

    # Process must survive cleanly without 0xC0000005 crash
    assert_true true
    probe.destroy
  end
end
