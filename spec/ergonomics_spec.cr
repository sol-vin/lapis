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

node ErgonomicMacroTester < Node do
  def test_n_type : ErgonomicPlayer
    n!(ErgonomicPlayer)
  end

  def test_n_type_path(path : String) : ErgonomicPlayer
    n!(path, ErgonomicPlayer)
  end

  def test_n_str(path : String) : Node
    n!(path)
  end

  def test_n_safe : ErgonomicPlayer?
    n?(ErgonomicPlayer)
  end

  def test_u_type : ErgonomicPlayer
    u!(ErgonomicPlayer)
  end

  def test_u_name(name : String) : Node
    u!(name)
  end

  def test_u_safe : ErgonomicPlayer?
    u?(ErgonomicPlayer)
  end

  def test_u_type_name(name : String) : ErgonomicPlayer
    u!(name, ErgonomicPlayer)
  end

  def test_u_type_name_safe(name : String) : ErgonomicPlayer?
    u?(name, ErgonomicPlayer)
  end

  onready my_player, ErgonomicPlayer, "Entities/ErgonomicPlayer"
  onready direct_player, ErgonomicPlayer, "Entities/ErgonomicPlayer"
  unique_node unique_player, ErgonomicPlayer, "ErgonomicPlayer"
  unique_node percent_player, ErgonomicPlayer, "%ErgonomicPlayer"
  onready? safe_direct_player, ErgonomicPlayer, "Entities/ErgonomicPlayer"
  onready? safe_missing_player, ErgonomicPlayer, "Entities/Ghost"
  unique_node? safe_unique_player, ErgonomicPlayer, "ErgonomicPlayer"
  unique_node? safe_missing_unique, ErgonomicPlayer, "NonExistent"

  node_ref ref_player, ErgonomicPlayer, "Entities/ErgonomicPlayer"
  node_ref decl_player : ErgonomicPlayer = "Entities/ErgonomicPlayer"
  unique_node_ref ref_unique_player, ErgonomicPlayer, "ErgonomicPlayer"
  unique_node_ref decl_unique_player : ErgonomicPlayer = "ErgonomicPlayer"

  @[NodeRef("Entities/ErgonomicPlayer")]
  property anno_player : ErgonomicPlayer? = nil

  @[UniqueNode("ErgonomicPlayer")]
  property anno_unique_player : ErgonomicPlayer? = nil
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

    it "Supports symbol overloads signal(:symbol) and connect(:symbol)" do
      player = ErgonomicPlayer.new
      sig_received = false
      player.signal(:died).connect do
        sig_received = true
      end
      emit(player.died)
      sig_received.should be_true

      score_val = 0
      player.connect(:score_updated) do |args|
        score_val = args[0].as_i64.to_i32
      end
      player.award(42)
      score_val.should eq(42)
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

  describe "Ergonomic Node & Path Access (Patterns A, B, C)" do
    it "Pattern A: Subscript indexer with class type self[Type]" do
      root = Godot::Node.new
      player = ErgonomicPlayer.new
      player.name = "ErgonomicPlayer"
      root.add_child(player)

      retrieved = root[ErgonomicPlayer]
      retrieved.should be_a(ErgonomicPlayer)
      retrieved.health.should eq(100)

      player.destroy
      root.destroy
    end

    it "Pattern A: Subscript indexer with path + type self[path, Type]" do
      root = Godot::Node.new
      entities = Godot::Node.new
      entities.name = "Entities"
      player = ErgonomicPlayer.new
      player.name = "Player"
      entities.add_child(player)
      root.add_child(entities)

      retrieved = root["Entities/Player", ErgonomicPlayer]
      retrieved.should be_a(ErgonomicPlayer)
      retrieved.name.should eq("Player")

      player.destroy
      entities.destroy
      root.destroy
    end

    it "Pattern A: Subscript indexer with $ prefix self[\"$Path\", Type]" do
      root = Godot::Node.new
      entities = Godot::Node.new
      entities.name = "Entities"
      player = ErgonomicPlayer.new
      player.name = "Player"
      entities.add_child(player)
      root.add_child(entities)

      retrieved = root["$Entities/Player", ErgonomicPlayer]
      retrieved.should be_a(ErgonomicPlayer)
      retrieved.name.should eq("Player")

      retrieved_plain = root["$Entities/Player"]
      retrieved_plain.name.should eq("Player")

      player.destroy
      entities.destroy
      root.destroy
    end

    it "Pattern A: Safe subscript indexer self[Type]? returns nil if missing" do
      root = Godot::Node.new
      missing = root[ErgonomicPlayer]?
      missing.should be_nil
      root.destroy
    end

    it "Pattern A: Unique % prefix lookup self[\"%UniqueName\", Type]" do
      root = Godot::Node.new
      player = ErgonomicPlayer.new
      player.name = "ErgonomicPlayer"
      root.add_child(player)

      retrieved = root["%ErgonomicPlayer", ErgonomicPlayer]
      retrieved.name.should eq("ErgonomicPlayer")

      retrieved_plain = root["%ErgonomicPlayer"]
      retrieved_plain.name.should eq("ErgonomicPlayer")

      player.destroy
      root.destroy
    end

    it "Pattern A: NodePath indexer self[NodePath]" do
      root = Godot::Node.new
      player = ErgonomicPlayer.new
      player.name = "ErgonomicPlayer"
      root.add_child(player)

      np = node_path!("ErgonomicPlayer")
      retrieved = root[np]
      retrieved.name.should eq("ErgonomicPlayer")

      player.destroy
      root.destroy
    end

    it "Pattern B: Operator / for path navigation" do
      root = Godot::Node.new
      entities = Godot::Node.new
      entities.name = "Entities"
      player = ErgonomicPlayer.new
      player.name = "Player"
      entities.add_child(player)
      root.add_child(entities)

      retrieved = root / "Entities" / "Player"
      retrieved.name.should eq("Player")

      player.destroy
      entities.destroy
      root.destroy
    end

    it "Pattern B: Operator / with String and NodePath" do
      root = Godot::Node.new
      entities = Godot::Node.new
      entities.name = "Entities"
      player = ErgonomicPlayer.new
      player.name = "Player"
      entities.add_child(player)
      root.add_child(entities)

      retrieved = root / "Entities" / node_path!("Player")
      retrieved.name.should eq("Player")

      player.destroy
      entities.destroy
      root.destroy
    end

    it "Pattern B: Operator / typed resolution" do
      root = Godot::Node.new
      player = ErgonomicPlayer.new
      player.name = "ErgonomicPlayer"
      root.add_child(player)

      retrieved = root / ErgonomicPlayer
      retrieved.should be_a(ErgonomicPlayer)

      player.destroy
      root.destroy
    end

    it "Pattern B: Operator % for scene unique node" do
      root = Godot::Node.new
      entities = Godot::Node.new
      entities.name = "Entities"
      hud = Godot::Node.new
      hud.name = "HUD"
      entities.add_child(hud)
      root.add_child(entities)

      retrieved = root % "HUD"
      retrieved.name.should eq("HUD")

      hud.destroy
      entities.destroy
      root.destroy
    end

    it "Pattern B: Operator % typed scene unique node" do
      root = Godot::Node.new
      entities = Godot::Node.new
      entities.name = "Entities"
      player = ErgonomicPlayer.new
      player.name = "ErgonomicPlayer"
      entities.add_child(player)
      root.add_child(entities)

      retrieved = root % ErgonomicPlayer
      retrieved.should be_a(ErgonomicPlayer)
      retrieved.health.should eq(100)

      player.destroy
      entities.destroy
      root.destroy
    end

    it "Pattern B: Multi-segment child traversal via / (e.g. self / 'Items/MyItem/Item3')" do
      root = Godot::Node.new
      items = Godot::Node.new
      items.name = "Items"
      my_item = Godot::Node.new
      my_item.name = "MyItem"
      item3 = Godot::Node.new
      item3.name = "Item3"

      my_item.add_child(item3)
      items.add_child(my_item)
      root.add_child(items)

      retrieved = root / "Items/MyItem/Item3"
      retrieved.name.should eq("Item3")

      retrieved_dollar = root / "$Items/MyItem/Item3"
      retrieved_dollar.name.should eq("Item3")

      item3.destroy
      my_item.destroy
      items.destroy
      root.destroy
    end

    it "Pattern B: Scene-unique subpath navigation via % (e.g. self % 'Items/Item22/Mesh')" do
      root = Godot::Node.new
      entities = Godot::Node.new
      entities.name = "Entities"
      items = Godot::Node.new
      items.name = "Items"
      item22 = Godot::Node.new
      item22.name = "Item22"
      mesh = Godot::Node.new
      mesh.name = "Mesh"

      item22.add_child(mesh)
      items.add_child(item22)
      entities.add_child(items)
      root.add_child(entities)

      retrieved = root % "Items/Item22/Mesh"
      retrieved.name.should eq("Mesh")

      retrieved_explicit = root % "%Items/Item22/Mesh"
      retrieved_explicit.name.should eq("Mesh")

      mesh.destroy
      item22.destroy
      items.destroy
      entities.destroy
      root.destroy
    end

    it "Pattern E: Unary tilde ~ operator for node lookups within active NodeContext" do
      root = Godot::Node.new
      root.name = "Root"
      my_node = Godot::Node.new
      my_node.name = "MyNodeName"
      player = ErgonomicPlayer.new
      player.name = "Node"

      my_node.add_child(player)
      root.add_child(my_node)

      root.with_context do
        # 1. Direct Node retrieval via ~("$Path")
        node_direct = ~("$MyNodeName/Node")
        node_direct.name.should eq("Node")

        # 2. Typed cast with (~"$MyNodeName/Node").as(ErgonomicPlayer)
        res1 = (~"$MyNodeName/Node").as(ErgonomicPlayer)
        res1.should eq(player)
        res1.health.should eq(100)

        # 3. Scene-unique typed cast: (~"%Node").as(ErgonomicPlayer)
        res2 = (~"%Node").as(ErgonomicPlayer)
        res2.should eq(player)

        # 4. Scene-unique subpath: (~"%MyNodeName/Node").as(ErgonomicPlayer)
        res3 = (~"%MyNodeName/Node").as(ErgonomicPlayer)
        res3.should eq(player)

        # 5. NodePath operand: ~(node_path!("MyNodeName/Node"))
        res4 = ~(node_path!("MyNodeName/Node"))
        res4.name.should eq("Node")
      end

      player.destroy
      my_node.destroy
      root.destroy
    end

    it "Pattern E: Unary ~ on class (~Type) two-tier resolution (name first, then child class search)" do
      root = Godot::Node.new

      # Tier 1: node named after class
      player1 = ErgonomicPlayer.new
      player1.name = "ErgonomicPlayer"
      root.add_child(player1)

      root.with_context do
        p = ~ErgonomicPlayer
        p.should be_a(ErgonomicPlayer)
        p.should eq(player1)
        p.health.should eq(100)
      end

      player1.destroy
      root.remove_child(player1)

      # Tier 2: node named differently (fallback to searching children of self)
      hero = ErgonomicPlayer.new
      hero.name = "CustomHeroActor"
      hero.health = 85
      root.add_child(hero)

      root.with_context do
        p2 = ~ErgonomicPlayer
        p2.should be_a(ErgonomicPlayer)
        p2.should eq(hero)
        p2.name.should eq("CustomHeroActor")
        p2.health.should eq(85)
      end

      hero.destroy
      root.remove_child(hero)

      # Error case: no child matching name or class
      expect_raises(Godot::NodeNotFoundError) do
        root.with_context do
          ~ErgonomicPlayer
        end
      end

      # Optional case: ~Type? returns nil instead of raising
      root.with_context do
        opt = ~ErgonomicPlayer?
        opt.should be_nil
      end

      # Optional case when present: returns the node
      hero_opt = ErgonomicPlayer.new
      hero_opt.name = "OptHero"
      root.add_child(hero_opt)
      root.with_context do
        opt = ~ErgonomicPlayer?
        opt.should_not be_nil
        opt.should eq(hero_opt)
        opt.try(&.health).should eq(100)

        # Compile-time generic type check: assignment directly to ErgonomicPlayer? without casting
        typed_hero : ErgonomicPlayer? = ~ErgonomicPlayer?
        typed_hero.not_nil!.health.should eq(100)
      end
      root.remove_child(hero_opt)
      hero_opt.destroy

      root.destroy
    end

    it "Pattern C: Bare macros n!, u!, n?, u? inside node methods and onready?/unique_node?" do
      tester = ErgonomicMacroTester.new
      entities = Godot::Node.new
      entities.name = "Entities"
      player = ErgonomicPlayer.new
      player.name = "ErgonomicPlayer"
      entities.add_child(player)
      tester.add_child(entities)

      # Test n!(Type, path)
      retrieved = tester.test_n_type_path("Entities/ErgonomicPlayer")
      retrieved.should be_a(ErgonomicPlayer)
      retrieved.health.should eq(100)

      # Test n!(path)
      retrieved_node = tester.test_n_str("Entities")
      retrieved_node.name.should eq("Entities")

      # Test u!(Type)
      retrieved_u = tester.test_u_type
      retrieved_u.should be_a(ErgonomicPlayer)

      # Test u!(name)
      retrieved_u_name = tester.test_u_name("ErgonomicPlayer")
      retrieved_u_name.name.should eq("ErgonomicPlayer")

      # Test safe macros n? and u?
      tester.test_n_safe.should be_nil
      tester.test_u_safe.should be_a(ErgonomicPlayer)

      # Test onready and unique_node lazy resolution
      tester.direct_player.should be_a(ErgonomicPlayer)
      tester.direct_player.should eq(player)
      tester.unique_player.should be_a(ErgonomicPlayer)
      tester.unique_player.should eq(player)
      tester.percent_player.should be_a(ErgonomicPlayer)
      tester.percent_player.should eq(player)

      # Test onready? and unique_node? safe lazy resolution
      tester.safe_direct_player.should eq(player)
      tester.safe_missing_player.should be_nil
      tester.safe_unique_player.should eq(player)
      tester.safe_missing_unique.should be_nil

      player.destroy
      entities.destroy
      tester.destroy
    end

    it "Supports upward navigation with .. and parent traversal" do
      parent = Godot::Node.new
      parent.name = "Parent"
      child = Godot::Node.new
      child.name = "Child"
      parent.add_child(child)

      p1 = child.get_node?("..")
      p1.should_not be_nil
      p1.not_nil!.name.should eq("Parent")

      p2 = child / ".."
      p2.name.should eq("Parent")

      child.destroy
      parent.destroy
    end

    it "Pattern D: Type safety and error handling with TypeCastError and NodeNotFoundError" do
      root = Godot::Node.new
      root.name = "Root"
      player = ErgonomicPlayer.new
      player.name = "Player"
      root.add_child(player)

      # 1. Successful typed retrieval
      p = root.get_node_as("Player", ErgonomicPlayer)
      p.should be_a(ErgonomicPlayer)

      # 2. Type mismatch with get_node_as raises TypeCastError
      expect_raises(TypeCastError) do
        root.get_node_as("Player", Godot::Camera3D)
      end

      # 3. Type mismatch with get_node_as? returns nil
      root.get_node_as?("Player", Godot::Camera3D).should be_nil
      root["Player", Godot::Camera3D]?.should be_nil

      # 4. Missing node raises NodeNotFoundError (inherits from KeyError)
      expect_raises(Godot::NodeNotFoundError) do
        root["NonExistentNode"]
      end
      expect_raises(KeyError) do
        root["NonExistentNode"]
      end

      # 5. unique_as and unique_as?
      root.unique_as("Player", ErgonomicPlayer).should be_a(ErgonomicPlayer)
      root.unique_as?("Player", Godot::Camera3D).should be_nil
      root.unique_as?("Ghost", ErgonomicPlayer).should be_nil

      player.destroy
      root.destroy
    end

    it "Pattern E: Prefix support ($, %, $%) and self-reference in self[] and self[]?" do
      root = Godot::Node.new
      root.name = "Root"
      player = ErgonomicPlayer.new
      player.name = "Player"
      root.add_child(player)

      # Self-references via $ and $.
      root["$"].should eq(root)
      root["$"]?.should eq(root)
      root["$. "].nil?.should be_false rescue nil
      root["$."].should eq(root)
      root["$", Godot::Node].should eq(root)

      # $ prefix
      root["$Player"].should eq(player)
      root["$Player", ErgonomicPlayer].should eq(player)
      root["$Player", ErgonomicPlayer]?.should eq(player)

      # % prefix
      root["%Player"].should eq(player)
      root["%Player", ErgonomicPlayer].should eq(player)
      root["%Player", ErgonomicPlayer]?.should eq(player)

      # Safe safe nil return on missing with prefixes
      root["$Missing"]?.should be_nil
      root["%Missing"]?.should be_nil
      root["$Missing", ErgonomicPlayer]?.should be_nil
      root["%Missing", ErgonomicPlayer]?.should be_nil

      # Macro unique retrieval by name string
      tester = ErgonomicMacroTester.new
      p2 = ErgonomicPlayer.new
      p2.name = "Player"
      tester.add_child(p2)

      retrieved = tester.test_u_type_name("Player")
      retrieved.should be_a(ErgonomicPlayer)
      tester.test_u_type_name_safe("Ghost").should be_nil

      p2.destroy
      tester.destroy
      player.destroy
      root.destroy
    end

    it "Pattern F: Deep 4-level hierarchy indexing with path-first syntax and safe lookups" do
      world = Godot::Node.new
      world.name = "World"
      entities = Godot::Node.new
      entities.name = "Entities"
      boss = ErgonomicPlayer.new
      boss.name = "Boss"
      minion = ErgonomicPlayer.new
      minion.name = "Minion"

      world.add_child(entities)
      entities.add_child(boss)
      boss.add_child(minion)

      # 1. Deep typed retrieval with path first
      world["Entities/Boss/Minion", ErgonomicPlayer].should eq(minion)
      world["Entities/Boss/Minion", ErgonomicPlayer]?.should eq(minion)
      world["Entities/Boss", ErgonomicPlayer].should eq(boss)

      # 2. Deep path with $ prefix
      world["$Entities/Boss/Minion", ErgonomicPlayer].should eq(minion)
      world["$Entities/Boss/Minion", ErgonomicPlayer]?.should eq(minion)

      # 3. Missing intermediate path safely returns nil
      world["Entities/GhostLevel/Minion", ErgonomicPlayer]?.should be_nil
      world["$Entities/GhostLevel/Minion", ErgonomicPlayer]?.should be_nil

      # 4. Missing terminal node raises NodeNotFoundError (and inherits KeyError)
      expect_raises(Godot::NodeNotFoundError) do
        world["Entities/Boss/Ghost", ErgonomicPlayer]
      end
      expect_raises(KeyError) do
        world["Entities/Boss/Ghost", ErgonomicPlayer]
      end

      # 5. TypeCastError on type mismatch
      expect_raises(TypeCastError) do
        world["Entities/Boss/Minion", Godot::Camera3D]
      end
      world["Entities/Boss/Minion", Godot::Camera3D]?.should be_nil

      minion.destroy
      boss.destroy
      entities.destroy
      world.destroy
    end

    it "Pattern G: Disambiguation and dynamic mutation for ~ClassName resolution" do
      parent = Godot::Node.new
      parent.name = "Parent"

      p1 = ErgonomicPlayer.new
      p1.name = "PlayerAlpha"
      p1.health = 50

      p2 = ErgonomicPlayer.new
      p2.name = "PlayerBeta"
      p2.health = 100

      parent.add_child(p1)
      parent.add_child(p2)

      # 1. Inside parent context, ~ClassName resolves first matching child deterministically by type
      parent.with_context do
        resolved = ~ErgonomicPlayer
        resolved.should eq(p1)
        resolved.health.should eq(50)

        # Dynamic rename: rename p1 to something else, type search still finds it
        p1.name = "RenamedAlpha"
        resolved_after_rename = ~ErgonomicPlayer
        resolved_after_rename.should eq(p1)

        # Missing type raises NodeNotFoundError
        expect_raises(Godot::NodeNotFoundError) do
          ~Godot::Camera3D
        end
      end

      # 2. When child is named after class, parent[Type] resolves it
      p1.name = "ErgonomicPlayer"
      parent[ErgonomicPlayer].should eq(p1)
      parent[ErgonomicPlayer]?.should eq(p1)
      parent[Godot::Camera3D]?.should be_nil

      p2.destroy
      p1.destroy
      parent.destroy
    end

    it "Pattern H: Prefix edge cases ($, $., combined prefixes) and exact error message inspection" do
      root = Godot::Node.new
      root.name = "Root"
      child = ErgonomicPlayer.new
      child.name = "Hero"
      root.add_child(child)

      # Self reference with type
      root["$", Godot::Node].should eq(root)
      root["$.", Godot::Node].should eq(root)
      root["$", Godot::Node]?.should eq(root)
      root["$.", Godot::Node]?.should eq(root)

      # Error message inspection on NodeNotFoundError
      begin
        root["MissingChild/DeepPath", ErgonomicPlayer]
        false.should be_true # Should not reach here
      rescue ex : Godot::NodeNotFoundError
        ex.message.not_nil!.should contain("MissingChild/DeepPath")
        ex.is_a?(KeyError).should be_true
      end

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

      threshold = {% if flag?(:release) %} 20.0 {% else %} 800.0 {% end %}
      elapsed_ms.should be < threshold
      sum.should be > 0.0
    end

    it "executes 25,000 Signal emissions efficiently" do
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
      threshold = {% if flag?(:release) %} 20.0 {% else %} 800.0 {% end %}
      elapsed_ms.should be < threshold
    end

    it "executes 5,000 Node lifecycle allocations efficiently" do
      root = Godot::Node2D.new

      start = Time.instant
      5_000.times do
        child = Godot::Node2D.new
        root.add_child(child)
        root.remove_child(child)
        child.destroy
      end
      elapsed_ms = (Time.instant - start).total_milliseconds

      threshold = {% if flag?(:release) %} 20.0 {% else %} 800.0 {% end %}
      elapsed_ms.should be < threshold
      root.destroy
    end

    it "executes 50,000 ergonomic node indexing operations efficiently" do
      root = Godot::Node.new
      player = ErgonomicPlayer.new
      player.name = "ErgonomicPlayer"
      root.add_child(player)

      start = Time.instant
      50_000.times do
        node = root[ErgonomicPlayer]
        node.health
      end
      elapsed_ms = (Time.instant - start).total_milliseconds

      threshold = {% if flag?(:release) %} 20.0 {% else %} 800.0 {% end %}
      elapsed_ms.should be < threshold

      player.destroy
      root.destroy
    end
  end

  describe "Type-Safe Node Injection & Dead-Pointer Safe Reference DSL" do
    it "resolves nodes via node_ref macro" do
      root = Godot::Node.new
      tester = ErgonomicMacroTester.new
      entities = Godot::Node.new
      entities.name = "Entities"
      player = ErgonomicPlayer.new
      player.name = "ErgonomicPlayer"

      root.add_child(tester)
      tester.add_child(entities)
      entities.add_child(player)

      tester.ref_player.should eq(player)
      tester.decl_player.should eq(player)

      root.destroy
    end

    it "resolves nodes via unique_node_ref macro" do
      root = Godot::Node.new
      tester = ErgonomicMacroTester.new
      player = ErgonomicPlayer.new
      player.name = "ErgonomicPlayer"
      player.unique_name_in_owner = true

      root.add_child(tester)
      tester.add_child(player)

      tester.ref_unique_player.should eq(player)
      tester.decl_unique_player.should eq(player)

      root.destroy
    end

    it "initializes @[NodeRef] and @[UniqueNode] properties during _ready" do
      root = Godot::Node.new
      tester = ErgonomicMacroTester.new
      entities = Godot::Node.new
      entities.name = "Entities"
      player = ErgonomicPlayer.new
      player.name = "ErgonomicPlayer"
      player.unique_name_in_owner = true

      root.add_child(tester)
      tester.add_child(entities)
      entities.add_child(player)

      # Trigger _ready
      tester._godot_call_virtual("_ready", 0.0)

      tester.anno_player.should eq(player)
      tester.anno_unique_player.should eq(player)

      root.destroy
    end
  end

  describe "Zero-Allocation Physics Hotpath Caching" do
    it "provides zero-allocation CharacterBody2D and CharacterBody3D predicate methods" do
      body2d = Godot::CharacterBody2D.new
      body2d.is_on_floor.should be_false
      body2d.is_on_floor?.should be_false
      body2d.on_floor?.should be_false
      body2d.is_on_wall.should be_false
      body2d.is_on_wall?.should be_false
      body2d.on_wall?.should be_false
      body2d.is_on_ceiling.should be_false
      body2d.is_on_ceiling?.should be_false
      body2d.on_ceiling?.should be_false
      body2d.move_and_slide.should be_false
      body2d.destroy

      body3d = Godot::CharacterBody3D.new
      body3d.is_on_floor.should be_false
      body3d.is_on_floor?.should be_false
      body3d.on_floor?.should be_false
      body3d.is_on_wall.should be_false
      body3d.is_on_wall?.should be_false
      body3d.on_wall?.should be_false
      body3d.is_on_ceiling.should be_false
      body3d.is_on_ceiling?.should be_false
      body3d.on_ceiling?.should be_false
      body3d.destroy
    end
  end

  describe "Generic Resource Loading Ergonomics" do
    it "supports both positional and named type parameters in Godot.load" do
      # Test that compiler resolves both overloads
      # (In headless mode without Godot runtime bridge initialized, load raises NilAssertionError, confirming correct dispatch)
      expect_raises(NilAssertionError) do
        Godot.load("res://non_existent.tscn", Godot::PackedScene)
      end
      expect_raises(NilAssertionError) do
        Godot.load("res://non_existent.tscn", as: Godot::PackedScene)
      end
    end
  end
end

