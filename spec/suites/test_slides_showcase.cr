# =============================================================================
# LibGodot Test Suite: Slides Code Showcase & Best Practices Parity
# =============================================================================

include Lapis::Test

# GModule Trait from Slide 20d
gmodule SlidesShowcaseDamageable do
  signal health_changed(current : Int32, max_health : Int32)
  signal died

  @[Export(range: 0..500)]
  property health : Int32 = 100

  @[Export]
  property max_health : Int32 = 100

  @[ExportToolButton("Reset Stats")]
  def reset_stats : Void
    self.health = self.max_health
  end

  def heal(amount : Int32) : Void
    self.health = Math.min(self.max_health, self.health + amount)
    emit(health_changed, self.health, self.max_health)
  end

  def take_damage(amount : Int32) : Void
    self.health = Math.max(0, self.health - amount)
    emit(health_changed, self.health, self.max_health)
    emit(died) if self.health == 0
  end
end

# Custom Hero node including the trait
node SlidesShowcaseHero < Godot::Node2D do
  include SlidesShowcaseDamageable

  property ready_called : Bool = false

  def _ready : Void
    @ready_called = true
  end
end

# Enemy node for query & combat tests (Slides 20i, 20j, 27e)
node SlidesShowcaseEnemy < Godot::Node2D do
  property alerted : Bool = false
  property hp : Int32 = 100

  def alert! : Void
    @alerted = true
  end

  def take_damage(amount : Int32) : Void
    @hp = Math.max(0, @hp - amount)
  end

  def take_damage(amount : Float32, origin : Godot::Vector2) : Void
    @hp = Math.max(0, @hp - amount.to_i32)
  end
end

# Unit testing player node (Slide 27k)
node SlidesShowcasePlayer < Godot::CharacterBody2D do
  property health : Float32 = 100.0_f32
  property max_health : Float32 = 100.0_f32

  signal health_changed(current : Float32, max : Float32)
  signal died

  def take_damage(amount : Float32) : Void
    @health = Math.max(0.0_f32, @health - amount)
    emit(health_changed, @health, @max_health)
    emit(died) if @health <= 0.0_f32
  end
end

test_suite "SlidesShowcase" do
  test "Slide 27k: C# vs Crystal Unit Testing Parity with Signal Await" do
    player = Godot.create(SlidesShowcasePlayer)
    assert_not_nil player

    # Spawn background task to trigger damage after brief tick
    spawn do
      player.take_damage(20.0_f32)
    end

    # Await signal directly in Crystal with typed unpacking
    hp, max = player.health_changed.await(timeout_sec: 2.0)
    assert_approx_eq hp, 80.0_f32
    assert_approx_eq max, 100.0_f32
    assert_approx_eq player.health, 80.0_f32

    player.destroy
  end

  test "Slide 20i: each_node receiver scoping, block param, and symbol group check" do
    root = Godot.create(Godot::Node2D)
    enemies_container = Godot.create(Godot::Node2D)
    enemies_container.name = "Enemies"
    root.add_child(enemies_container)

    e1 = Godot.create(SlidesShowcaseEnemy)
    e1.name = "Enemy1"
    e1.add_to_group("network_synced")
    enemies_container.add_child(e1)

    e2 = Godot.create(SlidesShowcaseEnemy)
    e2.name = "Enemy2"
    e2.add_to_group("network_synced")
    enemies_container.add_child(e2)

    # 1. Receiver scoping: with node yield node allows calling alert! directly
    root.each_node("Enemies/*", SlidesShowcaseEnemy) do
      alert!
    end
    assert_true e1.alerted
    assert_true e2.alerted

    # 2. Block parameter form
    root.each_node("Enemies/*", SlidesShowcaseEnemy) do |enemy|
      enemy.take_damage(25)
    end
    assert_eq e1.hp, 75
    assert_eq e2.hp, 75

    # 3. Symbol group check parity
    assert_true e1.in_group?(:network_synced)
    assert_true e1.in_group?("network_synced")
    assert_false e1.in_group?(:unrelated_group)

    root.destroy
  end

  test "Slide 20l: Expression pattern matching with implicit variable narrowing" do
    # 1. Test Int64 branch with implicit variable narrowing
    val_int = Godot::Variant.new(42_i64)
    res_int = match val_int do
      is Int64          do "Integer: #{val_int * 2}" end
      is String         do "Text: #{val_int.upcase}" end
      is Godot::Vector2 do "Vector: (#{val_int.x}, #{val_int.y})" end
      default           do "Unsupported Variant" end
    end
    assert_eq res_int, "Integer: 84"

    # 2. Test String branch with implicit variable narrowing
    val_str = Godot::Variant.new("lapis")
    res_str = match val_str do
      is Int64          do "Integer: #{val_str * 2}" end
      is String         do "Text: #{val_str.upcase}" end
      is Godot::Vector2 do "Vector: (#{val_str.x}, #{val_str.y})" end
      default           do "Unsupported Variant" end
    end
    assert_eq res_str, "Text: LAPIS"

    # 3. Test Vector2 branch
    val_vec = Godot::Variant.new(Godot::Vector2.new(10.0_f32, 20.0_f32))
    res_vec = match val_vec do
      is Int64          do "Integer: #{val_vec * 2}" end
      is String         do "Text: #{val_vec.upcase}" end
      is Godot::Vector2 do "Vector: (#{val_vec.x.to_i}, #{val_vec.y.to_i})" end
      default           do "Unsupported Variant" end
    end
    assert_eq res_vec, "Vector: (10, 20)"

    # 4. Test explicit block parameter form compatibility
    res_param = match val_int do
      is Int64 do |num| "Num: #{num + 10}" end
      default  do "other" end
    end
    assert_eq res_param, "Num: 52"
  end

  test "Slide 20j: Direct Space Physics Query hit.collider aliveness check" do
    enemy = Godot.create(SlidesShowcaseEnemy)
    enemy.name = "TargetEnemy"

    # Create a synthetic PhysicsHit2D with living collider
    hit = Godot::PhysicsHit2D.new(
      point: Godot::Vector2.new(100.0_f32, 50.0_f32),
      normal: Godot::Vector2.new(0.0_f32, -1.0_f32),
      collider: enemy
    )

    # Clean collider access via as?(Type)
    casted = hit.collider.as?(SlidesShowcaseEnemy)
    assert_not_nil casted
    if e = casted
      e.take_damage(25)
      assert_eq e.hp, 75
    end

    # Test dead-pointer safety: if collider is destroyed, hit.collider returns nil
    enemy.destroy
    assert_nil hit.collider
    assert_nil hit.collider.as?(SlidesShowcaseEnemy)
  end

  test "Slide 20d: gmodule Damageable trait methods, exports, and signals" do
    hero = Godot.create(SlidesShowcaseHero)
    assert_not_nil hero
    assert_eq hero.health, 100
    assert_eq hero.max_health, 100

    # Test take_damage
    hero.take_damage(30)
    assert_eq hero.health, 70

    # Test heal up to max_health
    hero.heal(20)
    assert_eq hero.health, 90
    hero.heal(50) # should clamp to max_health
    assert_eq hero.health, 100

    # Test reset_stats
    hero.take_damage(90)
    assert_eq hero.health, 10
    hero.reset_stats
    assert_eq hero.health, 100

    hero.destroy
  end

  test "Slide 27e: CombatRadar zero-allocation non-destructive target iteration" do
    origin = Godot::Vector2.new(0.0_f32, 0.0_f32)
    range_sq = 400.0_f32 * 400.0_f32

    targets = Array(SlidesShowcaseEnemy).new
    close_enemy = Godot.create(SlidesShowcaseEnemy)
    close_enemy.position = Godot::Vector2.new(100.0_f32, 100.0_f32)
    targets << close_enemy

    far_enemy = Godot.create(SlidesShowcaseEnemy)
    far_enemy.position = Godot::Vector2.new(500.0_f32, 500.0_f32)
    targets << far_enemy

    # Inlined non-destructive loop
    targets.each do |target|
      next if target.position.distance_squared_to(origin) > range_sq
      target.take_damage(35.0_f32, origin)
    end

    # Close enemy was damaged, far enemy was skipped
    assert_eq close_enemy.hp, 65
    assert_eq far_enemy.hp, 100

    # Crucial: targets array was NOT mutated (both enemies still present)
    assert_eq targets.size, 2

    close_enemy.destroy
    far_enemy.destroy
  end

  test "Slide 25 & 26c: Background worker channel and non-blocking drain" do
    channel = Channel(Int32).new(capacity: 32)
    worker = Thread.new do
      # Background worker sends 5 processed items
      5.times do |i|
        channel.send((i + 1) * 10)
      end
    end
    worker.join

    # Simulate main-thread non-blocking drain
    collected = [] of Int32
    loop do
      select
      when val = channel.receive
        collected << val
      else
        break
      end
    end

    assert_eq collected, [10, 20, 30, 40, 50]
  end

  test "Slide 28: Dynamic interop set, get, and metadata" do
    node = Godot.create(Godot::Node)

    # Non-existent property set is safely handled without errors or crashes
    node.set("not_a_real_variable", "dummy_value")

    # Metadata key-value storage
    node.set_meta("custom_data", "persisted_value")
    meta_val = node.get_meta_str("custom_data")
    assert_eq meta_val, "persisted_value"

    node.destroy
  end
end
