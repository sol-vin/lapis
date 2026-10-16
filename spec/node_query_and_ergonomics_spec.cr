require "./spec_helper"

class SpecEnemyMob < Godot::Node
  @[Export]
  property mob_type : String = "minion"

  signal alert(level : Int32)

  def shout(msg : String) : String
    "#{mob_type}: #{msg}"
  end

  def set(property : String | Symbol, value : T) : Void forall T
    if property.to_s == "mob_type"
      @mob_type = value.to_s
    else
      super
    end
  end
end

class SpecItemDrop < Godot::Node
  property value : Int32 = 10
end

describe "Scene Tree Glob Queries & Ergonomics" do
  describe "get_nodes with single-level wildcard (*)" do
    it "matches all direct children with *" do
      root = Godot::Node.new
      root.name = "Root"

      c1 = Godot::Node.new; c1.name = "Child1"; root.add_child(c1)
      c2 = Godot::Node.new; c2.name = "Child2"; root.add_child(c2)
      c3 = Godot::Node.new; c3.name = "Child3"; root.add_child(c3)

      matched = root.get_nodes("*")
      matched.size.should eq(3)
      matched.map(&.name).should eq(["Child1", "Child2", "Child3"])
    end

    it "matches pattern prefixes and suffixes with *" do
      root = Godot::Node.new
      root.name = "Root"

      e1 = Godot::Node.new; e1.name = "EnemyGoblin"; root.add_child(e1)
      e2 = Godot::Node.new; e2.name = "EnemyOrc"; root.add_child(e2)
      p = Godot::Node.new; p.name = "Player"; root.add_child(p)

      enemies = root.get_nodes("Enemy*")
      enemies.size.should eq(2)
      enemies.map(&.name).should eq(["EnemyGoblin", "EnemyOrc"])

      goblin = root.get_nodes("*Goblin")
      goblin.size.should eq(1)
      goblin.first.name.should eq("EnemyGoblin")
    end

    it "resolves mid-path wildcards like NodePath/SomeDir/*/Mesh" do
      root = Godot::Node.new; root.name = "World"
      world_nodes = Godot::Node.new; world_nodes.name = "WorldNodes"; root.add_child(world_nodes)

      zone1 = Godot::Node.new; zone1.name = "ZoneA"; world_nodes.add_child(zone1)
      zone2 = Godot::Node.new; zone2.name = "ZoneB"; world_nodes.add_child(zone2)

      m1 = Godot::Node.new; m1.name = "Mesh"; zone1.add_child(m1)
      m2 = Godot::Node.new; m2.name = "Mesh"; zone2.add_child(m2)
      other = Godot::Node.new; other.name = "Light"; zone1.add_child(other)

      meshes = root.get_nodes("WorldNodes/*/Mesh")
      meshes.size.should eq(2)
      meshes.map(&.name).should eq(["Mesh", "Mesh"])
    end
  end

  describe "get_nodes with recursive globstar (**)" do
    it "collects all descendants when querying **" do
      root = Godot::Node.new; root.name = "Root"
      l1_a = Godot::Node.new; l1_a.name = "A"; root.add_child(l1_a)
      l1_b = Godot::Node.new; l1_b.name = "B"; root.add_child(l1_b)
      l2_a = Godot::Node.new; l2_a.name = "A_Child"; l1_a.add_child(l2_a)
      l3_a = Godot::Node.new; l3_a.name = "A_Grandchild"; l2_a.add_child(l3_a)

      all_nodes = root.get_nodes("**")
      all_nodes.size.should eq(4)
      all_nodes.map(&.name).should eq(["A", "A_Child", "A_Grandchild", "B"])
    end

    it "matches deeply nested nodes matching a pattern like Enemies/**/Hitbox" do
      root = Godot::Node.new; root.name = "Scene"
      enemies = Godot::Node.new; enemies.name = "Enemies"; root.add_child(enemies)

      mob1 = Godot::Node.new; mob1.name = "Goblin"; enemies.add_child(mob1)
      h1 = Godot::Node.new; h1.name = "Hitbox"; mob1.add_child(h1)

      mob2 = Godot::Node.new; mob2.name = "Boss"; enemies.add_child(mob2)
      sub_rig = Godot::Node.new; sub_rig.name = "Armature"; mob2.add_child(sub_rig)
      h2 = Godot::Node.new; h2.name = "Hitbox"; sub_rig.add_child(h2)

      direct_h = Godot::Node.new; direct_h.name = "Hitbox"; enemies.add_child(direct_h)

      hitboxes = root.get_nodes("Enemies/**/Hitbox")
      hitboxes.size.should eq(3)
      hitboxes.all? { |h| h.name == "Hitbox" }.should be_true
    end

    it "collects all descendants of a subtree when using trailing **" do
      root = Godot::Node.new; root.name = "World"
      spawns = Godot::Node.new; spawns.name = "Spawns"; root.add_child(spawns)

      s1 = Godot::Node.new; s1.name = "S1"; spawns.add_child(s1)
      s2 = Godot::Node.new; s2.name = "S2"; spawns.add_child(s2)
      s1_sub = Godot::Node.new; s1_sub.name = "Marker"; s1.add_child(s1_sub)

      nodes = root.get_nodes("Spawns/**")
      nodes.size.should eq(3)
      nodes.map(&.name).should eq(["S1", "Marker", "S2"])
    end
  end

  describe "Typed get_nodes and type filtering" do
    it "returns Array(T) containing only nodes matching the requested type" do
      root = Godot::Node.new; root.name = "Arena"

      p = SpecPlayer.new; p.name = "Hero"; root.add_child(p)
      m1 = SpecEnemyMob.new; m1.name = "Mob1"; root.add_child(m1)
      m2 = SpecEnemyMob.new; m2.name = "Mob2"; root.add_child(m2)
      item = SpecItemDrop.new; item.name = "Potion"; root.add_child(item)

      players = root.get_nodes("*", SpecPlayer)
      players.should be_a(Array(SpecPlayer))
      players.size.should eq(1)
      players.first.name.should eq("Hero")
      players.first.speed.should eq(300.0_f32)

      mobs = root.get_nodes("*", SpecEnemyMob)
      mobs.should be_a(Array(SpecEnemyMob))
      mobs.size.should eq(2)
      mobs.map(&.name).should eq(["Mob1", "Mob2"])
    end
  end

  describe "first_node and first_node? lookups" do
    it "finds first node matching pattern or returns nil" do
      root = Godot::Node.new; root.name = "Root"
      c1 = Godot::Node.new; c1.name = "ItemGold"; root.add_child(c1)
      c2 = Godot::Node.new; c2.name = "ItemSilver"; root.add_child(c2)

      root.first_node?("Item*").not_nil!.name.should eq("ItemGold")
      root.first_node?("NonExistent*").should be_nil
    end

    it "raises NodeNotFoundError on first_node when not found" do
      root = Godot::Node.new; root.name = "Root"
      expect_raises(Godot::NodeNotFoundError) do
        root.first_node("Missing*")
      end
    end

    it "supports wildcard routing in indexer subscript syntax self[pattern]?" do
      root = Godot::Node.new; root.name = "Root"
      c1 = Godot::Node.new; c1.name = "TargetAlpha"; root.add_child(c1)

      root["Target*"]?.should_not be_nil
      root["Target*"]?.not_nil!.name.should eq("TargetAlpha")
      root["Missing*"]?.should be_nil
    end

    it "returns nil for self['Enemies/*/Hitbox', Area2D]? when result array would have been empty" do
      root = Godot::Node.new; root.name = "Root"
      enemies = Godot::Node.new; enemies.name = "Enemies"; root.add_child(enemies)

      # 1. No children matching path -> returns nil
      hitbox = root["Enemies/*/Hitbox", Godot::Area2D]?
      hitbox.should be_nil

      # 2. Matching node path exists, but NONE are Area2D -> returns nil (not a false-positive untyped first node)
      e1 = Godot::Node.new; e1.name = "Goblin"; enemies.add_child(e1)
      h1 = Godot::Node.new; h1.name = "Hitbox"; e1.add_child(h1)

      hitbox2 = root["Enemies/*/Hitbox", Godot::Area2D]?
      hitbox2.should be_nil

      # 3. Add an Area2D hitbox under a second enemy -> successfully resolves typed match
      e2 = Godot::Node.new; e2.name = "Orc"; enemies.add_child(e2)
      h2 = Godot::Area2D.new; h2.name = "Hitbox"; e2.add_child(h2)

      found = root["Enemies/*/Hitbox", Godot::Area2D]?
      found.should_not be_nil
      found.should eq(h2)
      found.should be_a(Godot::Area2D)

      # 4. Non-nilable variant returns h2 or raises NodeNotFoundError when empty
      root["Enemies/*/Hitbox", Godot::Area2D].should eq(h2)
      expect_raises(Godot::NodeNotFoundError) do
        root["Missing/*/Hitbox", Godot::Area2D]
      end

      # 5. Type-first syntax self[Area2D, path]?
      root[Godot::Area2D, "Enemies/*/Hitbox"]?.should eq(h2)
      root[Godot::Area2D, "NonExistent/*"]?.should be_nil

      # 6. Array(T) overloads returning nil if empty or Array if matched
      root["Enemies/*/Hitbox", Array(Godot::Area2D)]?.should eq([h2])
      root["NonExistent/*", Array(Godot::Area2D)]?.should be_nil
      root["Enemies/*/Hitbox", Array(Godot::Area2D)].should eq([h2])

      # 7. Leading $ notation works cleanly
      root["$Enemies/*/Hitbox", Godot::Area2D]?.should eq(h2)
    end
  end

  describe "Family & Hierarchy Navigation" do
    it "navigates ancestors" do
      grandparent = Godot::Node.new; grandparent.name = "GrandParent"
      parent = SpecEnemyMob.new; parent.name = "ParentMob"; grandparent.add_child(parent)
      child = Godot::Node.new; child.name = "Child"; parent.add_child(child)

      child.ancestor?(SpecEnemyMob).should eq(parent)
      child.ancestor?(Godot::Node).should eq(parent)
      child.ancestor?("GrandParent").should eq(grandparent)
      child.ancestors.map(&.name).should eq(["ParentMob", "GrandParent"])
      child.topmost_parent.name.should eq("GrandParent")
      child.scene_root.name.should eq("GrandParent")
    end

    it "navigates siblings" do
      parent = Godot::Node.new; parent.name = "Parent"
      s1 = Godot::Node.new; s1.name = "S1"; parent.add_child(s1)
      s2 = Godot::Node.new; s2.name = "S2"; parent.add_child(s2)
      s3 = Godot::Node.new; s3.name = "S3"; parent.add_child(s3)

      s2.siblings.map(&.name).should eq(["S1", "S3"])
      s2.previous_sibling?.not_nil!.name.should eq("S1")
      s2.next_sibling?.not_nil!.name.should eq("S3")

      s1.previous_sibling?.should be_nil
      s3.next_sibling?.should be_nil

      parent.first_child?.not_nil!.name.should eq("S1")
      parent.last_child?.not_nil!.name.should eq("S3")
    end
  end

  describe "Group Helpers" do
    it "queries and filters nodes in groups" do
      root = Godot::Node.new; root.name = "World"
      e1 = SpecEnemyMob.new; e1.name = "Orc"; e1.add_to_group("enemies"); root.add_child(e1)
      e2 = SpecEnemyMob.new; e2.name = "Goblin"; e2.add_to_group("enemies"); root.add_child(e2)
      p = SpecPlayer.new; p.name = "Player"; p.add_to_group("allies"); root.add_child(p)

      e1.in_group?("enemies").should be_true
      e1.in_group?("allies").should be_false
      e1.in_group?("bosses", "enemies").should be_true

      enemies = root.nodes_in_group("enemies", SpecEnemyMob)
      enemies.size.should eq(2)
      enemies.map(&.name).should eq(["Orc", "Goblin"])

      first_enemy = root.first_node_in_group?("enemies", SpecEnemyMob)
      first_enemy.should_not be_nil
      first_enemy.not_nil!.name.should eq("Orc")
    end
  end

  describe "Streaming Node Traversal & Collection Filtering" do
    it "filters collections with filter_as" do
      items = [SpecPlayer.new, SpecEnemyMob.new, SpecPlayer.new] of Godot::Node
      players = items.filter_as(SpecPlayer)
      players.size.should eq(2)
      players.all? { |p| p.is_a?(SpecPlayer) }.should be_true
    end

    it "traverses nodes using each_node with receiver scoping and block parameters" do
      root = Godot::Node.new
      m1 = SpecEnemyMob.new; m1.name = "Mob1"; m1.mob_type = "orc"
      m2 = SpecEnemyMob.new; m2.name = "Mob2"; m2.mob_type = "goblin"
      root.add_child(m1)
      root.add_child(m2)

      root.each_node("Mob*", SpecEnemyMob) do |mob|
        mob.mob_type = "mutant"
      end

      m1.mob_type.should eq("mutant")
      m2.mob_type.should eq("mutant")
    end

    it "destroys nodes cleanly via each iteration" do
      root = Godot::Node.new
      c1 = Godot::Node.new; root.add_child(c1)
      c2 = Godot::Node.new; root.add_child(c2)

      kids = root.children
      kids.size.should eq(2)

      kids.each(&.destroy)
      kids.all?(&.destroyed?).should be_true
    end
  end

  describe "Vector Directional Class Methods" do
    it "provides directional accessors matching constants" do
      Godot::Vector2.zero.should eq(Godot::Vector2::ZERO)
      Godot::Vector2.one.should eq(Godot::Vector2::ONE)
      Godot::Vector2.up.should eq(Godot::Vector2::UP)
      Godot::Vector2.down.should eq(Godot::Vector2::DOWN)
      Godot::Vector2.left.should eq(Godot::Vector2::LEFT)
      Godot::Vector2.right.should eq(Godot::Vector2::RIGHT)

      Godot::Vector3.zero.should eq(Godot::Vector3::ZERO)
      Godot::Vector3.one.should eq(Godot::Vector3::ONE)
      Godot::Vector3.up.should eq(Godot::Vector3::UP)
      Godot::Vector3.down.should eq(Godot::Vector3::DOWN)
      Godot::Vector3.left.should eq(Godot::Vector3::LEFT)
      Godot::Vector3.right.should eq(Godot::Vector3::RIGHT)
      Godot::Vector3.forward.should eq(Godot::Vector3::FORWARD)
      Godot::Vector3.back.should eq(Godot::Vector3::BACK)
    end
  end
end
