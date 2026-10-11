{% unless flag?(:release) %}
module Lapis
  module Docs
    module C_GAMEPLAY_AND_DECLARATIVE_DSL
      # # Next-Generation Gameplay Ergonomics & Engine Usability
      #
      # Comprehensive guide to Lapis high-velocity gameplay APIs, eliminating engine friction across
      # node instantiations, typed collections, signals, direct space raycasting, lifecycle timers,
      # and optional standalone modules.
      #
      # ### Executive Summary & Key Topics
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Topic</th>
      #       <th>Method / Anchor</th>
      #       <th>Description</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>Ergonomics Overview</strong></td>
      #       <td><code>.topic_00_overview</code></td>
      #       <td>Summary of gameplay usability additions and design philosophy.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Direct Tree Instantiation</strong></td>
      #       <td><code>.topic_01_tree_instantiation</code></td>
      #       <td>Instantiating nodes, PackedScenes, and scene paths directly inside add_child and add_sibling.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Dictionary Ergonomics</strong></td>
      #       <td><code>.topic_02_dictionary_ergonomics</code></td>
      #       <td>Frictionless Godot::Dictionary with kwargs, Symbol keys, typed getters, and dig?.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Array & Collection Utilities</strong></td>
      #       <td><code>.topic_03_array_ergonomics</code></td>
      #       <td>Fluent Array/Hash to_godot conversions, typed filter_as downcasting, and bounds-safe sampling.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Type-Filtered Signals & Proc Dispatch</strong></td>
      #       <td><code>.topic_04_signal_ergonomics</code></td>
      #       <td>Positional class filtering with on and compile-time typed Proc literal connections via +=.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Direct Space Physics Queries</strong></td>
      #       <td><code>.topic_05_direct_physics</code></td>
      #       <td>One-liner raycast_to and raycast queries returning typed PhysicsHit2D / PhysicsHit3D structures.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Node-Bound Cooperative Timers</strong></td>
      #       <td><code>.topic_06_lifecycle_timers</code></td>
      #       <td>Lifecycle-safe after and every execution with cancellable TimerHandle instances.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Resource & ConfigFile Safety</strong></td>
      #       <td><code>.topic_07_resource_config</code></td>
      #       <td>Class-level T.load, verified resource.save!, and typed ConfigFile get/get? methods.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Scene Operations</strong></td>
      #       <td><code>.topic_08_scene_tree_ops</code></td>
      #       <td>Verified change_scene!, reload_scene!, and typed current_scene_as helpers.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Optional Standalone Modules</strong></td>
      #       <td><code>.topic_09_optional_modules</code></td>
      #       <td>Modular gameplay helpers via require 'lapis/math' and require 'lapis/fsm'.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Scene Pipeline & Builders</strong></td>
      #       <td><code>.topic_10_scene_pipeline_and_builders</code></td>
      #       <td>Pipeline operator (>), static type retention on add_child, and Object#build.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Type-Safe Tweening & Animations</strong></td>
      #       <td><code>.topic_11_tween_ergonomics</code></td>
      #       <td>Compile-time type-checked tween macro, multi-symbol paths, and Time::Span duration.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Pattern Matching (match)</strong></td>
      #       <td><code>.topic_12_pattern_matching</code></td>
      #       <td>Expression-oriented pattern matching with downcasting, Variant unboxing, and destructuring.</td>
      #     </tr>
      #   </tbody>
      # </table>
      module K_GAMEPLAY_ERGONOMICS
        # **Overview**: Next-generation gameplay usability and friction reduction in Lapis.
        #
        # Lapis provides high-level gameplay APIs designed to eliminate repetitive boilerplate
        # when dealing with the Godot engine hierarchy, Variant collections, signals, and physics.
        #
        # #### Core Design Principles
        # 1. **Zero Unnecessary Downcasts**: Engine collections and signal arguments cast safely into concrete types.
        # 2. **Config-Yielding Constructors**: Tree instantiation operations accept configuration blocks yielding the new node.
        # 3. **Automatic Lifecycle Guards**: Node-bound operations (timers, awaits) track monotonic ObjectDB instance IDs.
        def self.topic_00_overview : Nil; end

        # **Direct Tree Instantiation**: Instantiating and configuring nodes directly via add_child and add_sibling.
        #
        # ```crystal
        # # 1. Instantiate by Node Class with config block:
        # sprite = add_child(Sprite2D) do |s|
        #   s.position = Vector2.new(100, 200)
        # end
        #
        # # 2. Instantiate by PackedScene:
        # bullet = add_child(bullet_scene, as: Bullet) do |b|
        #   b.global_position = muzzle_pos
        # end
        #
        # # 3. Instantiate directly by scene path:
        # hud = add_child("res://scenes/hud.tscn", as: GameHUD)
        #
        # # 4. Sibling instantiation:
        # marker = add_sibling(Marker2D) do |m|
        #   m.position = self.position
        # end
        #
        # # 5. Class-level typed scene instantiation:
        # marker = Marker2D.instantiate("res://scenes/marker.tscn") do |m|
        #   m.position = Vector2.new(0, 50)
        # end
        #
        # # 6. Positional scene instantiation into sibling or child:
        # marker = add_sibling("res://scenes/marker.tscn", Marker2D) do |m|
        #   m.position = Vector2.new(0, 50)
        # end
        # bullet = add_child("res://scenes/bullet.tscn", Bullet) do |b|
        #   b.global_position = muzzle_pos
        # end
        # ```
        def self.topic_01_tree_instantiation : Nil; end


        # **Dictionary Ergonomics**: Seamless Symbol keys, kwargs initialization, and typed getters.
        #
        # ```crystal
        # # Kwargs initialization:
        # dict = Godot::Dictionary.new(health: 100, speed: 7.5_f32, name: "Hero")
        #
        # # Symbol key access:
        # dict[:health] = 100
        # hp = dict.get(:health, as: Int32, default: 0)
        #
        # # Nested digging:
        # damage = dict.dig?(:stats, :attack, :base, as: Int32)
        #
        # # Fluent conversion:
        # {"score" => 500, "level" => 3}.to_godot
        # ```
        def self.topic_02_dictionary_ergonomics : Nil; end

        # **Array & Collection Utilities**: Fluent GodotArray helpers and typed filtering.
        #
        # ```crystal
        # # Convert Crystal arrays:
        # g_arr = [1, 2, 3].to_godot
        #
        # # Filter engine node arrays to concrete types:
        # enemies = area.get_overlapping_bodies.filter_as(Enemy)
        #
        # # Safe bounds and sampling:
        # first = g_arr.first?
        # last  = g_arr.last?
        # pick  = g_arr.sample
        # ```
        def self.topic_03_array_ergonomics : Nil; end

        # **Type-Filtered Signals & Proc Dispatch**: Type matching on signal connections.
        #
        # ```crystal
        # # Macro block filtering:
        # on body_entered, Player do |player|
        #   player.collect_coin
        # end
        #
        # # Positional multi-type matching:
        # on item_equipped, Player, Sword do |player, sword|
        #   player.play_sound
        # end
        #
        # # Strongly typed Proc literals:
        # body_entered += ->(player : Player) {
        #   player.collect_coin
        # }
        #
        # # Disconnecting all listeners:
        # body_entered.disconnect_all
        # ```
        def self.topic_04_signal_ergonomics : Nil; end

        # **Direct Space Physics Queries**: Performing direct raycasting without RayCast nodes.
        #
        # ```crystal
        # if hit = raycast_to(target_pos, mask: 0b0001)
        #   hit.point  # Vector2
        #   hit.normal # Vector2
        #   if enemy = hit.collider.as?(Enemy)
        #     enemy.take_damage(25)
        #   end
        # end
        #
        # hit3d = raycast(Vector3::FORWARD, distance: 20.0)
        # ```
        def self.topic_05_direct_physics : Nil; end

        # **Node-Bound Cooperative Timers**: Cancellable timers with automatic lifecycle guards.
        #
        # ```crystal
        # node Bomb < Area2D do
        #   def _ready : Void
        #     after(3.0.seconds) do
        #       explode!
        #     end
        #
        #     @tick = every(0.5.seconds) do
        #       play_beep
        #     end
        #   end
        #
        #   def explode! : Void
        #     @tick.try(&.cancel)
        #     queue_free
        #   end
        # end
        # ```
        def self.topic_06_lifecycle_timers : Nil; end

        # **Resource & ConfigFile Safety**: Class-level loaders and verified file operations.
        #
        # ```crystal
        # scene  = PackedScene.load("res://scenes/player.tscn")
        # weapon = WeaponConfig.load("res://data/sword.tres")
        # weapon.save!("res://data/sword.tres")
        #
        # cfg = ConfigFile.new
        # cfg.load("user://settings.cfg")
        # vol = cfg.get("audio", "master_volume", as: Float32, default: 0.8_f32)
        # ```
        def self.topic_07_resource_config : Nil; end

        # **Scene Operations**: Convenient scene changes with verified error reporting.
        #
        # ```crystal
        # change_scene!("res://scenes/level2.tscn")
        # reload_scene!
        #
        # if level = current_scene_as(MainLevel)
        #   level.start_wave(1)
        # end
        # ```
        def self.topic_08_scene_tree_ops : Nil; end

        # **Optional Standalone Modules**: Value-type math helpers and finite state machines.
        #
        # ```crystal
        # require "lapis/math"
        # dir = Vector2.random_dir
        # rot = 90.degrees
        # cur = cur.approach(100.0, 5.0)
        #
        # require "lapis/fsm"
        # class Enemy < CharacterBody2D
        #   fsm :state, initial: :idle do
        #     state :idle do
        #       enter { play_anim("idle") }
        #       update { |dt| transition_to :chase if player_seen? }
        #     end
        #     state :chase do
        #       enter { play_anim("run") }
        #     end
        #   end
        # end
        # ```
        def self.topic_09_optional_modules : Nil; end

        # **Scene Pipeline & Builders**: Pipeline operator (>), static type retention on add_child, and Object#build.
        #
        # ```crystal
        # # 1. Pipeline operator (>) on scene path or PackedScene:
        # enemy = add_child("res://scenes/enemy.tscn" > Enemy)
        # typeof(enemy) # => Enemy (concrete static type preserved!)
        #
        # # 2. Inline configuration via add_child block:
        # boss = add_child("res://scenes/boss.tscn" > Boss) do |b|
        #   b.position = Vector2.new(500, 200)
        #   b.phase = 2
        # end
        #
        # # 3. Fluent configuration via Object#build and Object#configure:
        # player = ("res://scenes/player.tscn" > Player).build do |p|
        #   p.speed = 12.0_f32
        # end
        # add_child(player)
        # ```
        def self.topic_10_scene_pipeline_and_builders : Nil; end

        # **Type-Safe Tweening & Animations**: Compile-time type-checked tween macro, automatic statement peeling, and Ease/Trans enums.
        #
        # ```crystal
        # # 1. Pure compile-time type-checked macro (catches typos like boss.positiom.y at compile time!):
        # tween(boss.position.y, to: 150.0, in: 0.4.seconds)
        #
        # # 2. Implicit self dot-syntax tweening:
        # tween(position.y, to: 150.0, in: 0.4.seconds)
        #
        # # 3. Statement-based tween block with automatic peeling, chaining, and type-safe enums:
        # tween(hero) do
        #   animate(position, to: Vector2.new(200.0, 100.0), in: 0.5.seconds)
        #   chain()
        #   animate(modulate.a, to: 0.0, in: 0.2.seconds)
        #   parallel()
        #   animate(scale, to: Vector2.one * 1.5, in: 0.2.seconds)
        #   ease(Ease.Out)
        #   trans(Trans.Quad)
        # end
        # ```
        def self.topic_11_tween_ergonomics : Nil; end

        # **Pattern Matching (match)**: Expression-oriented pattern matching with downcasting, unboxing, and destructuring.
        #
        # ```crystal
        # # 1. Polymorphic class downcasting with pattern guards:
        # greeting = match entity do
        #   is Player, if: p.is_boss do |p|
        #     "Defeat the champion #{p.name}!"
        #   end
        #   is Player do |p|
        #     "Welcome, #{p.name}!"
        #   end
        #   is Enemy do |e|
        #     "Encountered #{e.class.name}"
        #   end
        #   default do
        #     "Unknown entity"
        #   end
        # end
        #
        # # 2. Array rest pattern matching:
        # action = match tokens do
        #   is ["teleport", x, y] do |_, tx, ty|
        #     "Teleporting to #{tx}, #{ty}"
        #   end
        #   is [first, .., last] do |f, l|
        #     "Sequence from #{f} to #{l}"
        #   end
        #   is rest(cmd, _, _, arg) do |c, a|
        #     "Command #{c} with arg #{a}"
        #   end
        #   default { "Invalid command" }
        # end
        #
        # # 3. Partial dictionary matching:
        # match packet do
        #   is dict(type: "chat", user: u, msg: m) do |_, user, text|
        #     Godot.print("#{user}: #{text}")
        #   end
        #   default { }
        # end
        # ```
        def self.topic_12_pattern_matching : Nil; end
      end
    end
  end
end
{% end %}
