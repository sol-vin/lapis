require "./spec_helper"

class ExtrasSpecDummyNode < Godot::Node
  signal test_sig(val : Int32)
  signal multi_sig(a : Int32, b : String)
end

class ExtrasSpecEnemy < Godot::Node
  property health : Int32 = 100

  def take_damage(dmg : Int32)
    @health -= dmg
  end
end

class ExtrasSpecPlayer < Godot::Node
  property name_str : String = "Hero"
end

describe "Lapis DSL Extras, GD Extras, and CS Extras" do
  describe "GD Extras: Scene Queries (~)" do
    it "supports ~{\"$NodeName\", Type} with leading $ sign" do
      parent = Godot::Node.new
      parent.name = "Root"
      child = ExtrasSpecEnemy.new
      child.name = "Goblin"
      parent.add_child(child)

      Godot::NodeContext.scope(parent) do
        res = ~{"$Goblin", ExtrasSpecEnemy}
        res.should be_a(ExtrasSpecEnemy)
        res.name.should eq("Goblin")
      end
    end

    it "supports ~{\"NodeName\", Type} without leading $ sign" do
      parent = Godot::Node.new
      parent.name = "Root"
      child = ExtrasSpecPlayer.new
      child.name = "PlayerOne"
      parent.add_child(child)

      Godot::NodeContext.scope(parent) do
        res = ~{"PlayerOne", ExtrasSpecPlayer}
        res.should be_a(ExtrasSpecPlayer)
        res.name_str.should eq("Hero")
      end
    end

    it "supports nilable ~{\"$NodeName\", Type?} returning nil on missing node" do
      parent = Godot::Node.new
      parent.name = "Root"

      Godot::NodeContext.scope(parent) do
        res = ~{"$NonExistent", ExtrasSpecEnemy?}
        res.should be_nil
      end
    end

    it "raises NodeNotFoundError when non-nilable ~{\"$NodeName\", Type} is missing" do
      parent = Godot::Node.new
      parent.name = "Root"

      Godot::NodeContext.scope(parent) do
        expect_raises(Godot::NodeNotFoundError) do
          ~{"$NonExistent", ExtrasSpecEnemy}
        end
      end
    end

    it "supports unary ~ on String path" do
      parent = Godot::Node.new
      parent.name = "Root"
      child = Godot::Node.new
      child.name = "ChildA"
      parent.add_child(child)

      Godot::NodeContext.scope(parent) do
        found = ~"ChildA"
        found.should be_a(Godot::Node)
        found.name.should eq("ChildA")
      end
    end

    it "supports match macro" do
      val = 42
      matched = false
      match val do
        is String do
          matched = false
        end
        is Int32 do
          matched = true
        end
      end
      matched.should be_true
    end
  end

  describe "CS Extras: Event Subscription (+ / -)" do
    it "subscribes and unsubscribes using += and -= on BoundSignal" do
      node = ExtrasSpecDummyNode.new
      sig = node.test_sig
      calls = 0

      handler = ->(args : Array(Godot::Variant)) do
        calls += 1
      end

      sig += handler
      sig.connected?.should be_true

      node.emit_signal("test_sig", 10)
      calls.should eq(1)

      sig -= handler
      node.emit_signal("test_sig", 20)
      calls.should eq(1)
    end
  end

  describe "Extras: Operators & Wildcards" do
    it "supports Node#/ for path traversal" do
      parent = Godot::Node.new
      parent.name = "Parent"
      child = Godot::Node.new
      child.name = "SubNode"
      parent.add_child(child)

      traversed = parent / "SubNode"
      traversed.name.should eq("SubNode")
    end

    it "supports Node#<< for adding children" do
      parent = Godot::Node.new
      c1 = Godot::Node.new
      c1.name = "Child1"
      c2 = Godot::Node.new
      c2.name = "Child2"

      parent << c1 << c2
      parent.get_child_count.should eq(2)
      parent.get_child(0).name.should eq("Child1")
      parent.get_child(1).name.should eq("Child2")
    end

    it "supports Node#<< for typed ancestor resolution" do
      grandparent = ExtrasSpecPlayer.new
      grandparent.name = "PlayerRoot"
      parent = Godot::Node.new
      parent.name = "Body"
      child = Godot::Node.new
      child.name = "Arm"

      grandparent.add_child(parent)
      parent.add_child(child)

      found = child << ExtrasSpecPlayer
      found.should be_a(ExtrasSpecPlayer)
      found.name_str.should eq("Hero")

      missing = child << ExtrasSpecEnemy?
      missing.should be_nil
    end

    it "supports get_nodes, *, and each_node wildcards" do
      root = Godot::Node.new
      root.name = "Root"
      e1 = ExtrasSpecEnemy.new
      e1.name = "Enemy_1"
      e2 = ExtrasSpecEnemy.new
      e2.name = "Enemy_2"
      p1 = ExtrasSpecPlayer.new
      p1.name = "Player_1"

      root.add_child(e1)
      root.add_child(e2)
      root.add_child(p1)

      # get_nodes
      enemies = root.get_nodes("Enemy_*", ExtrasSpecEnemy)
      enemies.size.should eq(2)

      # * operator
      glob_nodes = root * "Enemy_*"
      glob_nodes.size.should eq(2)

      # typed * operator
      typed_glob = root * {"Enemy_*", ExtrasSpecEnemy}
      typed_glob.size.should eq(2)

      # each_node
      total_hp = 0
      root.each_node("Enemy_*", ExtrasSpecEnemy) do |e|
        total_hp += e.health
      end
      total_hp.should eq(200)
    end
  end
end
