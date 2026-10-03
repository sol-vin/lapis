require "./spec_helper"

node ErgoPlayer < Godot::Node do
  property name_tag : String = "Hero"
  signal hit(player : Godot::Node, amount : Int32)
  signal equipped(player : Godot::Node, weapon : Godot::Node)
end

node ErgoEnemy < Godot::Node do
  property hp : Int32 = 100
end

node ErgoSword < Godot::Node do
  property power : Int32 = 25
end

describe "Next-Generation Gameplay Ergonomics" do
  describe "Pillar 1: Direct Tree Instantiation" do
    it "instantiates and yields node class in add_child" do
      parent = Godot::Node.new
      child = parent.add_child(ErgoPlayer) do |p|
        p.name_tag = "Champion"
      end
      child.should be_a(ErgoPlayer)
      child.name_tag.should eq("Champion")
      parent.get_child_count.should eq(1)
    end

    it "adds sibling node class with config block" do
      parent = Godot::Node.new
      first = parent.add_child(ErgoPlayer)
      sibling = first.add_sibling(ErgoEnemy) do |e|
        e.hp = 250
      end
      sibling.should be_a(ErgoEnemy)
      sibling.hp.should eq(250)
      parent.get_child_count.should eq(2)
    end
  end

  describe "Pillar 2: Dictionary Ergonomics" do
    it "initializes from kwargs" do
      dict = Godot::Dictionary.new(health: 100, speed: 7.5_f32, hero: "Lapis")
      dict[:health].raw.should eq(100)
      dict[:speed].raw.should eq(7.5_f32)
      dict[:hero].raw.should eq("Lapis")
    end

    it "supports Symbol key indexing and assignment" do
      dict = Godot::Dictionary.new
      dict[:score] = 500
      dict[:score].raw.should eq(500)
      dict[:score] = 750
      dict[:score].raw.should eq(750)
      dict.has(:score).should be_true
      dict.has_key?(:score).should be_true
    end

    it "retrieves typed values with get and defaults" do
      dict = Godot::Dictionary.new(score: 42, name: "Warrior", active: true)
      dict.get(:score, as: Int32, default: 0).should eq(42)
      dict.get(:missing, as: Int32, default: 999).should eq(999)
      dict.get(:name, as: String, default: "").should eq("Warrior")
      dict.get(:active, as: Bool, default: false).should be_true
    end

    it "safely retrieves nilable typed values with get?" do
      dict = Godot::Dictionary.new(score: 100)
      dict.get?(:score, as: Int32).should eq(100)
      dict.get?(:missing, as: Int32).should be_nil
    end

    it "digs through nested dictionaries with dig?" do
      inner = Godot::Dictionary.new(base: 30)
      outer = Godot::Dictionary.new(attack: inner)
      root = Godot::Dictionary.new(stats: outer)

      root.dig?(:stats, :attack, :base, as: Int32).should eq(30)
      root.dig?(:stats, :defense, :base, as: Int32).should be_nil
    end

    it "converts Crystal Hash to Godot::Dictionary" do
      h = {"key1" => "val1", "key2" => "val2"}
      d = h.to_godot
      d.should be_a(Godot::Dictionary)
      d["key1"].raw.should eq("val1")
    end
  end

  describe "Pillar 3: Array & Collection Ergonomics" do
    it "converts Crystal Array to GodotArray" do
      arr = [10, 20, 30].to_godot
      arr.should be_a(Godot::GodotArray(Int32))
      arr.size.should eq(3)
      arr[0].should eq(10)
      arr[-1].should eq(30)
    end

    it "filters array items by concrete type with filter_as" do
      parent = Godot::Node.new
      p1 = parent.add_child(ErgoPlayer)
      e1 = parent.add_child(ErgoEnemy)
      e2 = parent.add_child(ErgoEnemy)

      children = parent.get_children
      enemies = children.filter_as(ErgoEnemy)
      enemies.size.should eq(2)
      enemies.each do |e|
        e.should be_a(ErgoEnemy)
      end

      players = children.filter_as(ErgoPlayer)
      players.size.should eq(1)
      players.first.should eq(p1)
    end

    it "supports first?, last?, and sample" do
      arr = [100, 200, 300].to_godot
      arr.first?.should eq(100)
      arr.last?.should eq(300)
      [100, 200, 300].includes?(arr.sample.not_nil!).should be_true

      empty_arr = Godot::GodotArray(Int32).new
      empty_arr.first?.should be_nil
      empty_arr.last?.should be_nil
      empty_arr.sample.should be_nil
    end
  end

  describe "Pillar 4: Positional Type-Filtered Signals & Proc Dispatch" do
    it "connects and fires with positional type filter via on macro" do
      player = ErgoPlayer.new
      enemy = ErgoEnemy.new
      sword = ErgoSword.new

      received_sword : ErgoSword? = nil
      received_player : ErgoPlayer? = nil

      on player.equipped, ErgoPlayer, ErgoSword do |p, s|
        received_player = p
        received_sword = s
      end

      # Emit with non-matching types (ErgoEnemy instead of ErgoSword)
      player.emit_equipped(player, enemy)
      received_player.should be_nil
      received_sword.should be_nil

      # Emit with matching types
      player.emit_equipped(player, sword)
      received_player.should eq(player)
      received_sword.should eq(sword)
    end

    it "supports Any wildcard in positional matching" do
      player = ErgoPlayer.new
      matched_player : ErgoPlayer? = nil
      matched_raw : Godot::VariantValue? = nil

      on player.hit, ErgoPlayer, Any do |p, raw|
        matched_player = p
        matched_raw = raw
      end

      player.emit_hit(player, 42)
      matched_player.should eq(player)
      matched_raw.should eq(42_i64)
    end

    it "supports typed Proc literals with += and -=" do
      player = ErgoPlayer.new
      sword = ErgoSword.new

      handled_count = 0
      handler = ->(p : ErgoPlayer, s : ErgoSword) {
        handled_count += 1
      }

      player.equipped += handler
      player.emit_equipped(player, sword)
      handled_count.should eq(1)

      player.equipped -= handler
      player.emit_equipped(player, sword)
      handled_count.should eq(1)
    end

    it "supports 1-argument Proc and 0-argument Proc with += and -=" do
      player = ErgoPlayer.new
      hit_count = 0

      hit_proc = ->(p : Godot::Node) {
        hit_count += 1
      }

      player.hit += hit_proc
      player.emit_hit(player, 50)
      hit_count.should eq(1)

      player.hit -= hit_proc
      player.emit_hit(player, 50)
      hit_count.should eq(1)

      zero_count = 0
      zero_proc = -> { zero_count += 10 }

      player.hit += zero_proc
      player.emit_hit(player, 25)
      zero_count.should eq(10)

      player.hit -= zero_proc
      player.emit_hit(player, 25)
      zero_count.should eq(10)
    end

    it "supports += and -= on dynamic BoundSignal" do
      player = ErgoPlayer.new
      bound = player.signal("hit")
      fire_count = 0

      on_hit_var = ->(args : ::Array(Godot::Variant)) {
        fire_count += 1
      }

      bound += on_hit_var
      player.emit_hit(player, 100)
      fire_count.should eq(1)

      bound -= on_hit_var
      player.emit_hit(player, 100)
      fire_count.should eq(1)
    end

    it "disconnects all signal handlers with disconnect_all" do
      player = ErgoPlayer.new
      count = 0
      player.hit.connect { count += 1 }
      player.hit.connect { count += 1 }

      player.emit_hit(player, 10)
      count.should eq(2)

      player.hit.disconnect_all
      player.emit_hit(player, 10)
      count.should eq(2)
    end
  end

  describe "Pillar 5: Direct Space Physics Structures" do
    it "creates PhysicsHit2D and casts collider" do
      enemy = ErgoEnemy.new
      hit = Godot::PhysicsHit2D.new(
        point: Godot::Vector2.new(10.0_f32, 20.0_f32),
        normal: Godot::Vector2.new(0.0_f32, -1.0_f32),
        collider: enemy
      )
      hit.point.x.should eq(10.0_f32)
      hit.point.y.should eq(20.0_f32)
      hit.collider_as(ErgoEnemy).should eq(enemy)
      hit.collider_as(ErgoPlayer).should be_nil
    end

    it "creates PhysicsHit3D and casts collider" do
      player = ErgoPlayer.new
      hit = Godot::PhysicsHit3D.new(
        point: Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32),
        normal: Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32),
        collider: player
      )
      hit.point.z.should eq(3.0_f32)
      hit.collider_as(ErgoPlayer).should eq(player)
      hit.collider_as(ErgoEnemy).should be_nil
    end
  end

  describe "Pillar 6: Node-Bound Cooperative Timers" do
    it "creates TimerHandle and cancels properly" do
      handle = Godot::TimerHandle.new(1.0)
      handle.running?.should be_true
      handle.cancelled?.should be_false

      handle.pause
      handle.paused?.should be_true

      handle.resume
      handle.paused?.should be_false

      handle.cancel
      handle.cancelled?.should be_true
      handle.running?.should be_false
    end

    it "advances tick counter and elapsed time" do
      handle = Godot::TimerHandle.new(0.5)
      handle.advance(0.2).should be_false
      handle.advance(0.3).should be_true
      handle.tick_count.should eq(1)

      handle.reset
      handle.tick_count.should eq(0)
      handle.elapsed_time.should eq(0.0)
    end
  end

  describe "Pillar 7: Resource & ConfigFile Ergonomics" do
    it "defines ResourceSaveError and ConfigFile get methods" do
      cfg = Godot::ConfigFile.new
      cfg.set_value("audio", "volume", 0.75)
      cfg.get("audio", "volume", as: Float64, default: 1.0).should eq(0.75)
      cfg.get("audio", "missing", as: Float64, default: 1.0).should eq(1.0)
    end
  end

  describe "Pillar 8: SceneTree Scene Operations" do
    it "defines SceneChangeError" do
      err = Godot::SceneChangeError.new("Test scene change error")
      err.message.should eq("Test scene change error")
    end
  end
end
