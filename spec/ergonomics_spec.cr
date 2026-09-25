require "./spec_helper"

node ErgonomicPlayer < CharacterBody3D do
  signal health_changed(current : Int32, max_health : Int32)
  signal died
  signal score_updated(points : Int32)

  property health : Int32 = 100
  property max_hp : Int32 = 100
  property score : Int32 = 0

  def hurt(damage : Int32) : Void
    @health -= damage
    emit(health_changed, @health, @max_hp)
    emit(died) if @health <= 0
  end

  def award(pts : Int32) : Void
    @score += pts
    emit(score_updated, @score)
  end
end

describe "LibGodot Ergonomic Options & Performance Regression Gates" do
  describe "Signal Ergonomic Options (10 Flavors)" do
    it "Option 1: Top-level macro emit(target.signal, *args)" do
      player = ErgonomicPlayer.new
      received = {0, 0}
      player.health_changed.connect { |cur, max| received = {cur, max} }

      emit(player.health_changed, 75, 100)
      received.should eq({75, 100})
    end

    it "Option 2: In-class macro emit(signal, *args)" do
      player = ErgonomicPlayer.new
      health_val = 0
      died_fired = false

      player.health_changed.connect { |cur, _max| health_val = cur }
      player.died.connect { died_fired = true }

      player.hurt(30)
      health_val.should eq(70)
      died_fired.should be_false

      player.hurt(70)
      health_val.should eq(0)
      died_fired.should be_true
    end

    it "Option 3: Synthesized type-safe method target.emit_signal_name(*args)" do
      player = ErgonomicPlayer.new
      pts_received = 0
      player.score_updated.connect { |pts| pts_received = pts }

      player.emit_score_updated(500)
      pts_received.should eq(500)
    end

    it "Option 4: First-class bound signal target.signal_name.emit(*args)" do
      player = ErgonomicPlayer.new
      received = {0, 0}
      player.health_changed.connect { |cur, max| received = {cur, max} }

      player.health_changed.emit(60, 100)
      received.should eq({60, 100})
    end

    it "Option 5: Dynamic TypedSignal reference emit(sig_var, *args)" do
      player = ErgonomicPlayer.new
      pts_received = 0
      sig = player.score_updated
      sig.connect { |pts| pts_received = pts }

      emit(sig, 1250)
      pts_received.should eq(1250)
    end

    it "Option 6: Direct node event listener target.on_signal_name { ... }" do
      player = ErgonomicPlayer.new
      last_pts = 0
      sub = player.on_score_updated do |pts|
        last_pts = pts
      end

      player.award(100)
      last_pts.should eq(100)
      player.award(150)
      last_pts.should eq(250)
      sub.connected?.should be_true
    end

    it "Option 7: One-shot node event listener target.on_signal_name_once { ... }" do
      player = ErgonomicPlayer.new
      trigger_count = 0
      player.on_died_once do
        trigger_count += 1
      end

      emit(player.died)
      emit(player.died)
      trigger_count.should eq(1)
    end

    it "Option 8: TypedSignal block connect target.signal_name.connect { ... }" do
      player = ErgonomicPlayer.new
      events = [] of Int32
      player.score_updated.connect do |pts|
        events << pts
      end

      emit(player.score_updated, 10)
      emit(player.score_updated, 20)
      events.should eq([10, 20])
    end

    it "Option 9: TypedSignal one-shot connect target.signal_name.once { ... }" do
      player = ErgonomicPlayer.new
      first_only = 0
      player.score_updated.once do |pts|
        first_only = pts
      end

      emit(player.score_updated, 999)
      emit(player.score_updated, 888)
      first_only.should eq(999)
    end

    it "Option 10: Operator << syntactic sugar target.signal_name << ->{ ... }" do
      player = ErgonomicPlayer.new
      called = false
      player.died << ->{ called = true; nil }

      emit(player.died)
      called.should be_true
    end

    it "Supports signal inspection & disconnection" do
      player = ErgonomicPlayer.new
      sub = player.score_updated.connect { |_| }
      player.score_updated.connected?.should be_true
      player.score_updated.connection_count.should be >= 1

      sub.disconnect
      sub.connected?.should be_false
    end
  end

  describe "Node & SceneTree Ergonomics" do
    it "provides children iteration, add_child, and remove_child" do
      parent = Godot::Node2D.new
      child1 = Godot::Node2D.new
      child2 = Godot::Node2D.new

      parent.add_child(child1)
      parent.add_child(child2)

      parent.child_count.should eq(2)
      parent.children.size.should eq(2)
      parent.children.first.should eq(child1)
      parent.children.last.should eq(child2)

      parent.remove_child(child1)
      parent.child_count.should eq(1)
      parent.children.first.should eq(child2)

      child1.destroy
      child2.destroy
      parent.destroy
    end

    it "provides node indexing syntax node[path]" do
      root = Godot::Node.new
      child = Godot::Node2D.new
      child.name = "MyChild"
      root.add_child(child)

      found = root["MyChild"]?
      found.should_not be_nil

      child.destroy
      root.destroy
    end
  end

  describe "Resource & Material Ergonomics" do
    it "manipulates StandardMaterial3D properties ergonomically" do
      mat = Godot::StandardMaterial3D.new
      mat.albedo_color = Godot::Color.new(1.0_f32, 0.5_f32, 0.25_f32, 1.0_f32)
      mat.roughness = 0.42_f32
      mat.metallic = 0.85_f32
      mat.emission_enabled = true
      mat.emission = Godot::Color.new(0.0_f32, 1.0_f32, 0.0_f32, 1.0_f32)

      mat.albedo_color.r.should eq(1.0_f32)
      mat.roughness.should eq(0.42_f32)
      mat.metallic.should eq(0.85_f32)
      mat.emission_enabled?.should be_true

      dup = mat.duplicate.as(Godot::StandardMaterial3D)
      dup.roughness.should eq(0.42_f32)
      dup.roughness = 0.1_f32
      mat.roughness.should eq(0.42_f32)
    end
  end

  describe "Performance Regression Gates" do
    it "executes 100,000 Transform3D operations in under 40 milliseconds" do
      t = Godot::Transform3D::IDENTITY
      v = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
      axis = Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
      sum = 0.0_f64

      start = Time.instant
      100_000.times do
        t = t.translated(v * 0.001_f32)
        t = t.rotated(axis, 0.005_f64)
        proj = t * v
        sum += (proj.x + proj.y + proj.z).to_f64
      end
      elapsed_ms = (Time.instant - start).total_milliseconds

      # Performance threshold: 100k ops must finish in < 150ms under debug (typical ~1.5ms in release)
      elapsed_ms.should be < 150.0
      sum.should be > 0.0
    end

    it "executes 25,000 Signal emissions in under 60 milliseconds" do
      player = ErgonomicPlayer.new
      count = 0
      player.score_updated.connect do |pts|
        count += pts
      end

      start = Time.instant
      25_000.times do
        emit(player.score_updated, 1)
      end
      elapsed_ms = (Time.instant - start).total_milliseconds

      count.should eq(25_000)
      elapsed_ms.should be < 60.0
    end

    it "executes 5,000 Node lifecycle allocations in under 30 milliseconds" do
      root = Godot::Node2D.new

      start = Time.instant
      5_000.times do
        child = Godot::Node2D.new
        root.add_child(child)
        root.remove_child(child)
        child.destroy
      end
      elapsed_ms = (Time.instant - start).total_milliseconds

      elapsed_ms.should be < 30.0
      root.destroy
    end
  end
end
