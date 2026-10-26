# =============================================================================
# LibGodot Test Suite: AwaitStatus, await!, and await? Predicate Ergonomics
# =============================================================================

include Lapis::Test

# Dedicated node for testing typed signal await variants
node AwaitProbeEmitterNode < Godot::Node do
  signal ping
  signal scored(points : Int32)
  signal detailed_score(points : Int32, multiplier : Float32, tag : String)
  signal custom_ev(payload : String)
end

test_suite "AwaitStatus" do
  test "Pillar 1: AwaitState and AwaitStatus(T) struct ergonomics" do
    # Completed state
    s_comp = Godot::AwaitStatus(Int32).completed(100)
    assert_true s_comp.completed?
    assert_false s_comp.timed_out?
    assert_true s_comp.ok?
    assert_eq s_comp.status, Godot::AwaitState::Completed
    assert_eq s_comp.value, 100
    assert_eq s_comp.value!, 100
    assert_eq s_comp.value?, 100
    assert_true (s_comp == :completed)
    assert_false (s_comp == :timed_out)
    assert_true (s_comp == 100)

    # Timed out state
    s_to = Godot::AwaitStatus(Int32).timed_out
    assert_false s_to.completed?
    assert_true s_to.timed_out?
    assert_false s_to.ok?
    assert_eq s_to.status, Godot::AwaitState::TimedOut
    assert_nil s_to.value
    assert_nil s_to.value?
    assert_true (s_to == :timed_out)
    assert_false (s_to == :completed)

    caught_to_error = false
    begin
      s_to.value!
    rescue ex : Godot::TimeoutError
      caught_to_error = true
    end
    assert_true caught_to_error, "value! must raise Godot::TimeoutError on timed out status"

    # Tuple destructuring
    s_tuple = Godot::AwaitStatus(Tuple(Int32, String)).completed({42, "Bonus"})
    p1, p2 = s_tuple
    assert_eq p1, 42
    assert_eq p2, "Bonus"

    # Freed / disposed state
    s_freed = Godot::AwaitStatus(Int32).freed(8888_u64)
    assert_false s_freed.completed?
    assert_false s_freed.timed_out?
    assert_true s_freed.freed?
    assert_true s_freed.disposed?
    assert_false s_freed.ok?
    assert_eq s_freed.status, Godot::AwaitState::Freed
    assert_eq s_freed.instance_id, 8888_u64
    assert_nil s_freed.value
    assert_nil s_freed.value?
    assert_true (s_freed == :freed)
    assert_true (s_freed == :disposed)

    caught_freed_error = false
    begin
      s_freed.value!
    rescue ex : Godot::DisposedObjectError
      caught_freed_error = (ex.instance_id == 8888_u64)
    end
    assert_true caught_freed_error, "value! must raise Godot::DisposedObjectError on freed status"
  end

  test "Pillar 2: TypedSignal 0-arg await, await!, and await?" do
    node = Godot.create(AwaitProbeEmitterNode)
    root.add_child(node)

    # 1. await completion
    completed_status = false
    Godot.spawn do
      st = node.ping.await
      completed_status = st.completed?
    end
    3.times { Fiber.yield }
    node.ping.emit
    5.times { Fiber.yield }
    assert_true completed_status, "0-arg await must return completed status"

    # 2. await! completion
    bang_completed = false
    Godot.spawn do
      node.ping.await!
      bang_completed = true
    end
    3.times { Fiber.yield }
    node.ping.emit
    5.times { Fiber.yield }
    assert_true bang_completed, "0-arg await! must complete successfully"

    # 3. await? completion
    pred_res : Bool? = false
    Godot.spawn do
      pred_res = node.ping.await?
    end
    3.times { Fiber.yield }
    node.ping.emit
    5.times { Fiber.yield }
    assert_true pred_res, "0-arg await? must return true on completion"

    # 4. Timeout behavior
    to_st = false
    to_bang_raised = false
    to_pred_res : Bool? = true

    Godot.spawn do
      st = node.ping.await(timeout_sec: 0.02)
      to_st = st.timed_out?
    end

    Godot.spawn do
      begin
        node.ping.await!(timeout_sec: 0.02)
      rescue ex : Godot::TimeoutError
        to_bang_raised = true
      end
    end

    Godot.spawn do
      to_pred_res = node.ping.await?(timeout_sec: 0.02)
    end

    # Pump frames past timeout until spawned fibers wake up
    start = ::Time.instant
    while (!(to_st && to_bang_raised && !to_pred_res)) && (::Time.instant - start).total_seconds < 0.5
      Fiber.yield
    end
    2.times { Fiber.yield }

    assert_true to_st, "0-arg await must return timed_out? on timeout"
    assert_true to_bang_raised, "0-arg await! must raise TimeoutError on timeout"
    assert_false to_pred_res, "0-arg await? must return false on timeout"

    root.remove_child(node)
    node.destroy
  end

  test "Pillar 3: TypedSignal single-arg and multi-arg await, await!, await?" do
    node = Godot.create(AwaitProbeEmitterNode)
    root.add_child(node)

    # 1. Single arg: scored(points : Int32)
    rec_val = 0
    rec_bang = 0
    rec_pred : Int32? = nil

    Godot.spawn do
      st = node.scored.await
      rec_val = st.value!
    end

    Godot.spawn do
      rec_bang = node.scored.await!
    end

    Godot.spawn do
      rec_pred = node.scored.await?
    end

    3.times { Fiber.yield }
    node.scored.emit(777)
    5.times { Fiber.yield }

    assert_eq rec_val, 777, "Single-arg await must unbox payload"
    assert_eq rec_bang, 777, "Single-arg await! must return payload directly"
    assert_eq rec_pred, 777, "Single-arg await? must return payload directly"

    # Single arg timeout
    rec_to_st = false
    rec_to_bang = false
    rec_to_pred : Int32? = 999

    Godot.spawn do
      st = node.scored.await(timeout_sec: 0.02)
      rec_to_st = st.timed_out?
    end

    Godot.spawn do
      begin
        node.scored.await!(timeout_sec: 0.02)
      rescue ex : Godot::TimeoutError
        rec_to_bang = true
      end
    end

    Godot.spawn do
      rec_to_pred = node.scored.await?(timeout_sec: 0.02)
    end

    start = ::Time.instant
    while (!(rec_to_st && rec_to_bang && rec_to_pred.nil?)) && (::Time.instant - start).total_seconds < 0.5
      Fiber.yield
    end
    2.times { Fiber.yield }

    assert_true rec_to_st, "Single-arg await must time out"
    assert_true rec_to_bang, "Single-arg await! must raise TimeoutError"
    assert_nil rec_to_pred, "Single-arg await? must return nil on timeout"

    # 2. Multi-arg: detailed_score(points : Int32, multiplier : Float32, tag : String)
    tuple_pts = 0
    tuple_mul = 0.0_f32
    tuple_tag = ""

    Godot.spawn do
      pts, mul, tag = node.detailed_score.await!
      tuple_pts = pts
      tuple_mul = mul
      tuple_tag = tag
    end

    3.times { Fiber.yield }
    node.detailed_score.emit(250, 1.5_f32, "Combo")
    5.times { Fiber.yield }

    assert_eq tuple_pts, 250, "Multi-arg tuple destructuring element 0"
    assert_approx_eq tuple_mul, 1.5_f32, 0.001, "Multi-arg tuple destructuring element 1"
    assert_eq tuple_tag, "Combo", "Multi-arg tuple destructuring element 2"

    root.remove_child(node)
    node.destroy
  end

  test "Pillar 4: BoundSignal and Object#await_signal variants" do
    node = Godot.create(AwaitProbeEmitterNode)
    root.add_child(node)

    # 1. Successful emission via BoundSignal#await
    bs_rec = ""
    fiber_done = false
    Godot.spawn do
      st = node.signal("custom_ev").await
      bs_rec = st.first?.try(&.as_str) || ""
      fiber_done = true
    end

    3.times { Fiber.yield }
    node.emit_signal("custom_ev", "PayloadAlpha")
    50.times do
      break if fiber_done
      Fiber.yield
    end
    assert_true fiber_done, "BoundSignal#await fiber must finish"
    assert_eq bs_rec, "PayloadAlpha", "BoundSignal#await receives emitted argument"

    # 2. BoundSignal#await! and #await? timeout
    bs_bang_raised = false
    bs_pred_nil = false

    Godot.spawn do
      begin
        node.signal("nonexistent").await!(timeout_sec: 0.02)
      rescue ex : Godot::TimeoutError
        bs_bang_raised = true
      end
    end

    Godot.spawn do
      res = node.signal("nonexistent").await?(timeout_sec: 0.02)
      bs_pred_nil = res.nil?
    end

    start = ::Time.instant
    while (!(bs_bang_raised && bs_pred_nil)) && (::Time.instant - start).total_seconds < 0.5
      Fiber.yield
    end
    2.times { Fiber.yield }

    assert_true bs_bang_raised, "BoundSignal#await! raises TimeoutError on timeout"
    assert_true bs_pred_nil, "BoundSignal#await? returns nil on timeout"

    root.remove_child(node)
    node.destroy
  end

  test "Pillar 5: Godot.await, await!, await? for durations and spans" do
    # Duration completion
    st = Godot.await(0.001)
    assert_true st.completed?
    assert_false st.timed_out?

    bang_ok = false
    Godot.await!(0.001)
    bang_ok = true
    assert_true bang_ok

    assert_true Godot.await?(0.001)

    # Duration timeout
    st_to = Godot.await(0.2, timeout_sec: 0.005)
    assert_true st_to.timed_out?

    caught_dur_to = false
    begin
      Godot.await!(0.2, timeout_sec: 0.005)
    rescue ex : Godot::TimeoutError
      caught_dur_to = true
    end
    assert_true caught_dur_to

    assert_false Godot.await?(0.2, timeout_sec: 0.005)
  end

  test "Pillar 6: Macro await, await!, await? top-level ergonomics" do
    node = Godot.create(AwaitProbeEmitterNode)
    root.add_child(node)

    done_macro_await = false
    Godot.spawn do
      st = await(node.ping)
      done_macro_await = st.completed?
    end

    3.times { Fiber.yield }
    node.ping.emit
    5.times { Fiber.yield }
    assert_true done_macro_await, "macro await works with TypedSignal"

    root.remove_child(node)
    node.destroy
  end

  test "Pillar 7: Dead-pointer safety invariant on await, await!, and await?" do
    node = Godot.create(AwaitProbeEmitterNode)
    node_id = node.instance_id

    await_freed_flag = false
    await_value_bang_raised = false
    caught_bang = false
    pred_bound_nil = false
    pred_typed0_nil = false
    pred_typed1_nil = false

    Godot.spawn do
      st = node.signal("ghost").await
      await_freed_flag = st.freed? && st.disposed? && (st.instance_id == node_id) && st.value?.nil?
      begin
        st.value!
      rescue ex : Godot::DisposedObjectError
        await_value_bang_raised = (ex.instance_id == node_id)
      end
    end

    Godot.spawn do
      begin
        node.signal("ghost").await!
      rescue ex : Godot::DisposedObjectError
        caught_bang = (ex.instance_id == node_id)
      end
    end

    Godot.spawn do
      res = node.signal("ghost").await?
      pred_bound_nil = res.nil?
    end

    Godot.spawn do
      res0 = node.ping.await?
      pred_typed0_nil = res0.nil?
    end

    Godot.spawn do
      res1 = node.scored.await?
      pred_typed1_nil = res1.nil?
    end

    10.times { Fiber.yield }
    # Destroy node while awaiting: should immediately unblock awaiting fibers on the main thread
    node.destroy
    assert_false node.alive?

    assert_true await_freed_flag, "await must immediately unblock with freed? == true when node is destroyed"
    assert_true await_value_bang_raised, "status.value! on freed AwaitStatus must raise DisposedObjectError"
    assert_true caught_bang, "await! must raise DisposedObjectError when node is destroyed"
    assert_true pred_bound_nil, "BoundSignal#await? must return nil when node is destroyed"
    assert_true pred_typed0_nil, "0-arg TypedSignal#await? must return nil when node is destroyed"
    assert_true pred_typed1_nil, "1-arg TypedSignal#await? must return nil when node is destroyed"

    # Also verify pre-disposed node behavior (calling await / await! / await? after destroy)
    pre_st = node.scored.await
    assert_true pre_st.freed?, "await on already-destroyed node must return freed? status"
    assert_nil node.scored.await?, "await? on already-destroyed node must return nil"
    assert_nil node.ping.await?, "0-arg await? on already-destroyed node must return nil"
    pre_bang_raised = false
    begin
      node.scored.await!
    rescue ex : Godot::DisposedObjectError
      pre_bang_raised = (ex.instance_id == node_id)
    end
    assert_true pre_bang_raised, "await! on already-destroyed node must raise DisposedObjectError"

    # Also verify queue_free immediately unblocks awaiting fibers
    qnode = Godot.create(AwaitProbeEmitterNode)
    root.add_child(qnode)
    q_unblocked_freed = false
    q_pred_nil = false
    Godot.spawn do
      q_unblocked_freed = qnode.ping.await.freed?
    end
    Godot.spawn do
      q_pred_nil = qnode.scored.await?.nil?
    end
    10.times { Fiber.yield }
    qnode.queue_free
    assert_true q_unblocked_freed, "queue_free must immediately unblock await with freed? == true"
    assert_true q_pred_nil, "queue_free must immediately unblock await? with nil"
  end
end
