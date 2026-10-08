# =============================================================================
# LibGodot Test Suite: Fluent Tween & Animation DSL
# =============================================================================

include Lapis::Test

node TweenProbeNode < Godot::Node2D do
  property speed : Float32 = 100.0_f32
  property health : Int32 = 100
end

test_suite "TweenDsl" do
  test "Pillar 1: basic tween(node) and node.tween block execution" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)

    # 1. Macro tween(target) do ... end
    tw = tween(probe) do
      animate(position, to: Godot::Vector2.new(100.0_f32, 200.0_f32), duration: 0.2)
    end

    assert_not_nil tw
    assert_true tw.is_valid
    assert_true tw.is_running
    assert_true tw.has_tweeners

    tw.kill
    assert_false tw.is_valid

    # 2. Block method probe.tween do ... end
    tw2 = probe.tween do
      animate(:scale, to: Godot::Vector2.new(2.0_f32, 2.0_f32), in: 0.15.seconds)
    end

    assert_not_nil tw2
    assert_true tw2.is_valid
    tw2.kill

    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 2: statement peeling and automatic chaining with chain() and parallel()" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)

    tw = tween(probe) do
      animate(position, from: Godot::Vector2::ZERO, to: Godot::Vector2.new(50.0_f32, 50.0_f32), in: 0.3.seconds)
      trans(Trans.Cubic)
      ease(Ease.Out)
      chain()
      animate(modulate, from: Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32), to: Godot::Color.new(0.0_f32, 0.0_f32, 1.0_f32, 1.0_f32), in: 0.2.seconds)
      parallel()
      animate(scale, to: Godot::Vector2.new(1.5_f32, 1.5_f32), in: 0.2.seconds)
      chain()
      animate(modulate.a, to: 0.5_f32, in: 0.1.seconds)
    end

    assert_not_nil tw
    assert_true tw.is_valid
    assert_true tw.is_running

    tw.kill
    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 2b: compile-time type verification, unquoted position, and dot-syntax constant sugar" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)

    # Test unquoted position, Vector2.ZERO dot-syntax, and nested modulate.a
    tw = tween(probe) do
      target_pos = Godot::Vector2.new(30.0_f32, 40.0_f32)
      animate(position, from: Godot::Vector2.ZERO, to: target_pos, in: 0.2.seconds)
        .chain.animate(scale, to: Godot::Vector2.new(2.0_f32, 2.0_f32), in: 0.15.seconds)
        .chain.animate(modulate.a, to: 0.0_f32, in: 0.1.seconds)
      loops(2)
      speed_scale(1.2)
    end

    assert_not_nil tw
    assert_true tw.is_valid
    assert_true tw.is_running
    assert_eq tw.get_loops_left, 2_i64

    tw.kill
    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 2c: user requested tween syntax with automatic statement peeling and method chaining" do
    hero = Godot.create(TweenProbeNode)
    root.call("add_child", hero)

    tw = tween(hero) do
      animate(speed, to: 120.0_f32, in: 4.seconds)
      chain()
      animate(health, from: 120, to: 400, in: 10.seconds)
      parallel()
      ease(Ease.Out)
    end

    assert_not_nil tw
    assert_true tw.is_valid
    assert_true tw.is_running
    assert_true tw.has_tweeners

    tw.kill
    root.call("remove_child", hero)
    hero.destroy
  end

  test "Pillar 3: starting value and relative steps (.from, .from_current, .as_relative)" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)

    tw = tween(probe) do
      animate(position, to: Godot::Vector2.new(20.0_f32, 0.0_f32), duration: 0.1)
        .from_current
        .chain.animate(position, to: Godot::Vector2.new(10.0_f32, 10.0_f32), duration: 0.1)
        .as_relative
    end

    assert_not_nil tw
    assert_true tw.is_valid
    tw.kill

    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 4: transition and ease symbol parsing across types" do
    # Transition symbols
    assert_eq Godot::Tween.parse_trans(:linear), Godot::Tween::TransitionType::TransLinear
    assert_eq Godot::Tween.parse_trans(:sine), Godot::Tween::TransitionType::TransSine
    assert_eq Godot::Tween.parse_trans(:quint), Godot::Tween::TransitionType::TransQuint
    assert_eq Godot::Tween.parse_trans(:quart), Godot::Tween::TransitionType::TransQuart
    assert_eq Godot::Tween.parse_trans(:quad), Godot::Tween::TransitionType::TransQuad
    assert_eq Godot::Tween.parse_trans(:expo), Godot::Tween::TransitionType::TransExpo
    assert_eq Godot::Tween.parse_trans(:elastic), Godot::Tween::TransitionType::TransElastic
    assert_eq Godot::Tween.parse_trans(:cubic), Godot::Tween::TransitionType::TransCubic
    assert_eq Godot::Tween.parse_trans(:circ), Godot::Tween::TransitionType::TransCirc
    assert_eq Godot::Tween.parse_trans(:bounce), Godot::Tween::TransitionType::TransBounce
    assert_eq Godot::Tween.parse_trans(:back), Godot::Tween::TransitionType::TransBack
    assert_eq Godot::Tween.parse_trans(:spring), Godot::Tween::TransitionType::TransSpring

    # Ease symbols
    assert_eq Godot::Tween.parse_ease(:in), Godot::Tween::EaseType::EaseIn
    assert_eq Godot::Tween.parse_ease(:out), Godot::Tween::EaseType::EaseOut
    assert_eq Godot::Tween.parse_ease(:in_out), Godot::Tween::EaseType::EaseInOut
    assert_eq Godot::Tween.parse_ease(:out_in), Godot::Tween::EaseType::EaseOutIn

    # Direct enum pass-through
    assert_eq Godot::Tween.parse_trans(Godot::Tween::TransitionType::TransCubic), Godot::Tween::TransitionType::TransCubic
    assert_eq Godot::Tween.parse_ease(Godot::Tween::EaseType::EaseOut), Godot::Tween::EaseType::EaseOut

    # Type-safe Trans and Ease enums
    assert_eq Godot::Tween.parse_trans(Trans::Cubic), Godot::Tween::TransitionType::TransCubic
    assert_eq Godot::Tween.parse_ease(Ease::Out), Godot::Tween::EaseType::EaseOut
  end

  test "Pillar 5: alpha syntactic sugar mapping to modulate:a on CanvasItem" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)

    tw = tween(probe) do
      animate(alpha, to: 0.0_f32, in: 0.25.seconds)
    end

    assert_not_nil tw
    assert_true tw.is_valid
    tw.kill

    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 6: interval delays, loops, and speed scale control" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)

    tw = tween(probe) do
      delay(0.1.seconds)
        .chain.animate(position, to: Godot::Vector2.new(10.0_f32, 10.0_f32), duration: 0.2)
        .delay(0.05.seconds)
      loops(2)
      speed_scale(1.5)
    end

    assert_not_nil tw
    assert_true tw.is_valid
    assert_true tw.is_running
    assert_eq tw.get_loops_left, 2_i64

    tw.kill
    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 7: tween lifecycle, invalidation on kill, and orphan-free cleanup" do
    assert_no_new_orphans("Fluent Tween Cleanup") do
      20.times do |i|
        probe = Godot.create(TweenProbeNode)
        root.call("add_child", probe)

        tw = tween(probe) do
          animate(position, from: Godot::Vector2.new(0.0_f32, 0.0_f32), to: Godot::Vector2.new(10.0_f32, 20.0_f32), in: 0.1.seconds)
            .trans(Trans.Cubic).ease(Ease.Out)
            .chain.animate(scale, to: Godot::Vector2.new(1.1_f32, 1.1_f32), in: 0.05.seconds)
            .parallel.animate(alpha, to: 0.8_f32, in: 0.05.seconds)
        end

        assert_true tw.is_valid
        assert_true tw.is_running

        tw.kill
        assert_false tw.is_valid
        assert_false tw.is_running

        root.call("remove_child", probe)
        probe.destroy
      end
    end
  end

  test "Pillar 8: deterministic multi-frame property stepping via custom_step" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)
    probe.set_position(Godot::Vector2.new(0.0_f32, 0.0_f32))

    tw = tween(probe) do
      animate(position, from: Godot::Vector2.new(0.0_f32, 0.0_f32), to: Godot::Vector2.new(100.0_f32, 200.0_f32), duration: 1.0)
        .trans(:linear).ease(:in)
    end
    tw.pause

    # Assert initial position
    assert_in_delta probe.get_position.x, 0.0_f32, 0.01_f32
    assert_in_delta probe.get_position.y, 0.0_f32, 0.01_f32

    # Step 1: 0.1s (10%)
    running = tw.custom_step(0.1)
    assert_true running
    assert_in_delta probe.get_position.x, 10.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 20.0_f32, 0.5_f32

    # Step 4 more times to reach 0.5s (50%)
    4.times { tw.custom_step(0.1) }
    assert_in_delta probe.get_position.x, 50.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 100.0_f32, 0.5_f32

    # Step 5 more times to reach 1.0s (100% completion)
    4.times { tw.custom_step(0.1) }
    assert_in_delta probe.get_position.x, 90.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 180.0_f32, 0.5_f32

    tw.custom_step(0.1)
    assert_in_delta probe.get_position.x, 100.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 200.0_f32, 0.5_f32

    # Stepping past completion maintains target clamp values
    tw.custom_step(0.5)
    assert_in_delta probe.get_position.x, 100.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 200.0_f32, 0.5_f32

    tw.kill
    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 9: chained step progression and temporal isolation across frames" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)
    probe.set_position(Godot::Vector2.new(0.0_f32, 0.0_f32))

    tw = tween(probe) do
      animate(position, from: Godot::Vector2.new(0.0_f32, 0.0_f32), to: Godot::Vector2.new(50.0_f32, 0.0_f32), duration: 0.5)
        .trans(:linear).ease(:in)
        .chain.animate(position, to: Godot::Vector2.new(50.0_f32, 50.0_f32), duration: 0.5)
        .trans(:linear).ease(:in)
    end
    tw.pause

    # Step through Phase 1 (0.0s -> 0.5s): only X should change, Y remains 0
    tw.custom_step(0.25)
    assert_in_delta probe.get_position.x, 25.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 0.0_f32, 0.01_f32

    tw.custom_step(0.25)
    assert_in_delta probe.get_position.x, 50.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 0.0_f32, 0.01_f32

    # Step into Phase 2 (0.5s -> 1.0s): X stays at 50, Y advances to 50
    tw.custom_step(0.25)
    assert_in_delta probe.get_position.x, 50.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 25.0_f32, 0.5_f32

    tw.custom_step(0.25)
    assert_in_delta probe.get_position.x, 50.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 50.0_f32, 0.5_f32

    tw.kill
    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 10: parallel step concurrency across frames" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)
    probe.set_position(Godot::Vector2.new(0.0_f32, 0.0_f32))
    probe.set_scale(Godot::Vector2.new(1.0_f32, 1.0_f32))

    tw = tween(probe) do
      animate(position, from: Godot::Vector2.new(0.0_f32, 0.0_f32), to: Godot::Vector2.new(100.0_f32, 100.0_f32), duration: 0.5)
        .trans(:linear).ease(:in)
        .parallel.animate(scale, from: Godot::Vector2.new(1.0_f32, 1.0_f32), to: Godot::Vector2.new(3.0_f32, 3.0_f32), duration: 0.5)
        .trans(:linear).ease(:in)
    end
    tw.pause

    # Halfway tick (0.25s): both position and scale must have advanced simultaneously
    tw.custom_step(0.25)
    assert_in_delta probe.get_position.x, 50.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 50.0_f32, 0.5_f32
    assert_in_delta probe.get_scale.x, 2.0_f32, 0.1_f32
    assert_in_delta probe.get_scale.y, 2.0_f32, 0.1_f32

    # Full completion tick (0.25s)
    tw.custom_step(0.25)
    assert_in_delta probe.get_position.x, 100.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 100.0_f32, 0.5_f32
    assert_in_delta probe.get_scale.x, 3.0_f32, 0.1_f32
    assert_in_delta probe.get_scale.y, 3.0_f32, 0.1_f32

    tw.kill
    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 11: interval delay temporal freezing across frames" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)
    probe.set_position(Godot::Vector2.new(0.0_f32, 0.0_f32))

    tw = tween(probe) do
      delay(0.2.seconds)
        .chain.animate(position, from: Godot::Vector2.new(0.0_f32, 0.0_f32), to: Godot::Vector2.new(60.0_f32, 60.0_f32), duration: 0.2)
        .trans(:linear).ease(:in)
    end
    tw.pause

    # At 0.1s and 0.2s: delay is active, position must remain frozen at (0, 0)
    tw.custom_step(0.1)
    assert_in_delta probe.get_position.x, 0.0_f32, 0.01_f32
    assert_in_delta probe.get_position.y, 0.0_f32, 0.01_f32

    tw.custom_step(0.1)
    assert_in_delta probe.get_position.x, 0.0_f32, 0.01_f32
    assert_in_delta probe.get_position.y, 0.0_f32, 0.01_f32

    # At 0.3s (0.1s into animation, halfway): position advances to (30, 30)
    tw.custom_step(0.1)
    assert_in_delta probe.get_position.x, 30.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 30.0_f32, 0.5_f32

    # At 0.4s: animation finishes at (60, 60)
    tw.custom_step(0.1)
    assert_in_delta probe.get_position.x, 60.0_f32, 0.5_f32
    assert_in_delta probe.get_position.y, 60.0_f32, 0.5_f32

    tw.kill
    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 12: multi-frame easing curves mathematical divergence" do
    probe_lin = Godot.create(TweenProbeNode)
    probe_cub = Godot.create(TweenProbeNode)
    root.call("add_child", probe_lin)
    root.call("add_child", probe_cub)
    probe_lin.set_position(Godot::Vector2.new(0.0_f32, 0.0_f32))
    probe_cub.set_position(Godot::Vector2.new(0.0_f32, 0.0_f32))

    tw_lin = tween(probe_lin) do
      animate(position, from: Godot::Vector2.new(0.0_f32, 0.0_f32), to: Godot::Vector2.new(100.0_f32, 0.0_f32), duration: 1.0)
        .trans(Trans.Linear).ease(Ease.In)
    end
    tw_lin.pause

    tw_cub = tween(probe_cub) do
      animate(position, from: Godot::Vector2.new(0.0_f32, 0.0_f32), to: Godot::Vector2.new(100.0_f32, 0.0_f32), duration: 1.0)
        .trans(Trans.Cubic).ease(Ease.In)
    end
    tw_cub.pause

    # Step both 0.2s (20% elapsed time)
    tw_lin.custom_step(0.2)
    tw_cub.custom_step(0.2)

    lin_x = probe_lin.get_position.x
    cub_x = probe_cub.get_position.x

    # Linear should be ~20.0, Cubic EaseIn should be 100 * (0.2)^3 = ~0.8
    assert_in_delta lin_x, 20.0_f32, 1.0_f32
    assert_true cub_x < 5.0_f32, "Cubic ease-in at 20% must be slow (was #{cub_x})"
    assert_true cub_x < lin_x, "Cubic ease-in position must lag linear position during early phase"

    tw_lin.kill
    tw_cub.kill
    root.call("remove_child", probe_lin)
    root.call("remove_child", probe_cub)
    probe_lin.destroy
    probe_cub.destroy
  end

  test "Pillar 13: timed signal emissions (step_finished, finished) at exact boundaries" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)

    step_count = 0
    finished_count = 0

    tw = tween(probe) do
      animate(position, to: Godot::Vector2.new(10.0_f32, 10.0_f32), duration: 0.2)
        .chain.animate(position, to: Godot::Vector2.new(20.0_f32, 20.0_f32), duration: 0.2)
    end
    tw.pause

    tw.step_finished.connect do |_idx|
      step_count += 1
    end
    tw.finished.connect do
      finished_count += 1
    end

    # Step 0.1s (middle of step 1): no signals
    tw.custom_step(0.1)
    assert_eq step_count, 0
    assert_eq finished_count, 0

    # Step 0.1s (completes step 1): step_finished fires once
    tw.custom_step(0.1)
    assert_eq step_count, 1
    assert_eq finished_count, 0

    # Step 0.1s (middle of step 2): no new signal
    tw.custom_step(0.1)
    assert_eq step_count, 1
    assert_eq finished_count, 0

    # Step 0.1s (completes step 2 and whole tween): step_finished fires again, finished fires
    tw.custom_step(0.1)
    assert_eq step_count, 2
    assert_eq finished_count, 1

    tw.kill
    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 14: mid-run invalidation and tween destruction across frames" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)
    probe.set_position(Godot::Vector2.new(0.0_f32, 0.0_f32))

    tw = tween(probe) do
      animate(position, from: Godot::Vector2.new(0.0_f32, 0.0_f32), to: Godot::Vector2.new(100.0_f32, 100.0_f32), duration: 1.0)
        .trans(Trans.Linear).ease(Ease.In)
    end
    tw.pause

    # Step 5 ticks (0.5s): halfway
    5.times { tw.custom_step(0.1) }
    assert_in_delta probe.get_position.x, 50.0_f32, 0.5_f32

    # Kill tween mid-run
    tw.kill
    assert_false tw.is_valid
    assert_false tw.is_running

    # Subsequent custom_step calls must safely return false without advancing position
    res = tw.custom_step(0.1)
    assert_false res
    assert_in_delta probe.get_position.x, 50.0_f32, 0.5_f32

    root.call("remove_child", probe)
    probe.destroy
  end

  test "Pillar 15: target node destruction mid-tween across frames" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)
    probe.set_position(Godot::Vector2.new(0.0_f32, 0.0_f32))

    tw = tween(probe) do
      animate(position, from: Godot::Vector2.new(0.0_f32, 0.0_f32), to: Godot::Vector2.new(100.0_f32, 100.0_f32), duration: 1.0)
    end
    tw.pause

    # Advance 2 ticks
    2.times { tw.custom_step(0.1) }

    # Destroy target node mid-flight
    root.call("remove_child", probe)
    probe.destroy
    assert_false probe.alive?

    # Advance subsequent ticks: must not crash with SIGSEGV or memory corruption
    3.times do
      tw.custom_step(0.1)
    end

    tw.kill
    assert_false tw.is_valid
  end

  test "Pillar 16: zero leak multi-frame tween stress run" do
    assert_no_new_orphans("MultiFrameTweenStress") do
      20.times do
        probe = Godot.create(TweenProbeNode)
        root.call("add_child", probe)
        probe.set_position(Godot::Vector2.new(0.0_f32, 0.0_f32))

        tw = tween(probe) do
          animate(position, from: Godot::Vector2.new(0.0_f32, 0.0_f32), to: Godot::Vector2.new(20.0_f32, 40.0_f32), duration: 0.2)
            .trans(Trans.Cubic).ease(Ease.Out)
            .chain.animate(scale, to: Godot::Vector2.new(1.2_f32, 1.2_f32), duration: 0.1)
        end
        tw.pause

        # Step to completion
        3.times { tw.custom_step(0.1) }

        tw.kill
        root.call("remove_child", probe)
        probe.destroy
      end
    end
  end

  test "Pillar 17: single-property macro tween with dot navigation and target resolution" do
    probe = Godot.create(TweenProbeNode)
    root.call("add_child", probe)

    # 1. Targeting external object: tween(probe.position.y, to: ...)
    tw1 = tween(probe.position.y, to: 150.0_f32, in: 0.4.seconds)
    assert_not_nil tw1
    assert_true tw1.is_valid
    tw1.kill

    # 2. Targeting external object with from: tween(probe.speed, from: 50.0_f32, to: 200.0_f32)
    tw2 = tween(probe.speed, from: 50.0_f32, to: 200.0_f32, in: 0.3.seconds)
    assert_not_nil tw2
    assert_true tw2.is_valid
    tw2.kill

    # 3. Verify Node does not define tween_to
    assert_false probe.responds_to?(:tween_to)

    root.call("remove_child", probe)
    probe.destroy
  end
end
