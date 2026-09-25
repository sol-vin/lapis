module Lapis
  module Docs
    # ## Macro DSL Reference & In-Editor Reflection Manual
    #
    # LibGodot provides a expressive, compile-time checked Domain Specific Language (DSL)
    # for declaring Godot engine classes, resources, refcounted objects, inspector exports,
    # signals, RPC endpoints, and editor tools.
    #
    # All macros expand into native Godot `ClassDB` registrations during library initialization
    # without runtime reflection overhead.
    #
    # ---
    #
    # ### 1. Class Declaration Macros
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Macro</th>
    #       <th>Default Superclass</th>
    #       <th>Zero-Block Syntax</th>
    #       <th>Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><code>node Name &lt; Parent do ... end</code></td>
    #       <td><code>Godot::Node</code></td>
    #       <td><code>node Name</code> or <code>node Name &lt; Parent</code></td>
    #       <td>Declares a scene graph Node class exposed to Godot's ClassDB.</td>
    #     </tr>
    #     <tr>
    #       <td><code>resource Name &lt; Parent do ... end</code></td>
    #       <td><code>Resource</code></td>
    #       <td><code>resource Name</code> or <code>resource Name &lt; Parent</code></td>
    #       <td>Declares a serializable Godot Resource class (.tres / .res).</td>
    #     </tr>
    #     <tr>
    #       <td><code>gdclass Name &lt; Parent do ... end</code></td>
    #       <td><code>RefCounted</code></td>
    #       <td><code>gdclass Name</code> or <code>gdclass Name &lt; Parent</code></td>
    #       <td>Declares a reference-counted engine class managed by ObjectDB.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # #### Syntax Examples
    #
    # ```
    # require "libgodot"
    #
    # # 1. Node with explicit parent and block
    # node PlayerController < CharacterBody3D do
    #   @[Export]
    #   property speed : Float32 = 7.5_f32
    #
    #   def _physics_process(delta : Float64) : Void
    #     # Movement code
    #   end
    # end
    #
    # # 2. Zero-block node inheriting default Godot::Node
    # node WorldManager
    #
    # # 3. Zero-block node with explicit parent
    # node CustomCamera < Camera3D
    #
    # # 4. Resource inheriting default Resource
    # resource InventoryItem do
    #   @[Export]
    #   property item_name : String = "Health Potion"
    #
    #   @[Export]
    #   property power : Int32 = 50
    # end
    #
    # # 5. Zero-block resource defaulting to Resource
    # resource QuestData
    #
    # # 6. RefCounted class using gdclass
    # gdclass StateMachine do
    #   property state : String = "idle"
    # end
    #
    # # 7. RefCounted class using gdclass (zero-block)
    # gdclass DataPacket
    # ```
    #
    # ---
    #
    # ### 2. Property Export Annotations
    #
    # Export annotations configure how Crystal properties are presented in the Godot Inspector,
    # serialized to disk (.tscn / .tres), and exposed to GDScript.
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Annotation</th>
    #       <th>Arguments</th>
    #       <th>Inspector Widget</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><code>@[Export]</code></td>
    #       <td>None</td>
    #       <td>Standard typed editor (number, string, color, vector)</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportRange]</code></td>
    #       <td><code>min..max, step: n, or_greater: bool, or_less: bool</code></td>
    #       <td>Numeric slider bar with bounds and step increments</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportEnum]</code></td>
    #       <td><code>EnumType</code></td>
    #       <td>Dropdown selection list of named enum values</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportFile]</code></td>
    #       <td><code>filter: "*.png,*.jpg"</code></td>
    #       <td>File system picker dialog with extension filter</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportDir]</code></td>
    #       <td>None</td>
    #       <td>Directory path picker dialog</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportMultiline]</code></td>
    #       <td>None</td>
    #       <td>Multi-line expandable text area</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportPlaceholder]</code></td>
    #       <td><code>text: "Placeholder..."</code></td>
    #       <td>Text field with gray placeholder text when empty</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportColorNoAlpha]</code></td>
    #       <td>None</td>
    #       <td>Color picker with alpha/opacity channel locked at 1.0</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportExpEasing]</code></td>
    #       <td><code>attenuation: bool, positive_only: bool</code></td>
    #       <td>Interactive exponential easing curve visualization widget</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportNodePath]</code></td>
    #       <td><code>type: "Camera3D"</code></td>
    #       <td>NodePath picker constrained to matching node types in scene</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportFlags]</code></td>
    #       <td><code>FlagEnumType</code></td>
    #       <td>Multi-select checkbox list for bitfield flags</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportFlags2DRender]</code></td>
    #       <td>None</td>
    #       <td>Godot 2D render layer visibility bitmask checkboxes</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportFlags2DPhysics]</code></td>
    #       <td>None</td>
    #       <td>Godot 2D physics collision layer bitmask checkboxes</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportFlags3DPhysics]</code></td>
    #       <td>None</td>
    #       <td>Godot 3D physics collision layer bitmask checkboxes</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportGroup]</code></td>
    #       <td><code>name: "Combat", prefix: "combat_"</code></td>
    #       <td>Collapsible category grouping header in Inspector</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportSubgroup]</code></td>
    #       <td><code>name: "Defenses", prefix: "combat_def_"</code></td>
    #       <td>Nested subcategory header within an inspector group</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportStorage]</code></td>
    #       <td>None</td>
    #       <td>Serialized with scene/resource but hidden from the Inspector</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[ExportToolButton]</code></td>
    #       <td><code>text: "Execute Action", icon: "res://icon.png"</code></td>
    #       <td>Clickable push button rendered directly in the Inspector</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # #### Export Example
    #
    # ```
    # enum CharacterClass
    #   Warrior = 1
    #   Mage    = 2
    #   Rogue   = 4
    # end
    #
    # node Hero < CharacterBody2D do
    #   @[ExportGroup("Attributes", prefix: "attr_")]
    #   @[ExportRange(1..100, step: 1)]
    #   property attr_level : Int32 = 1
    #
    #   @[ExportEnum(CharacterClass)]
    #   property attr_hero_class : CharacterClass = CharacterClass::Warrior
    #
    #   @[ExportGroup("Media", prefix: "media_")]
    #   @[ExportFile("*.png,*.tres")]
    #   property media_avatar : String = "res://avatar.png"
    #
    #   @[ExportColorNoAlpha]
    #   property theme_color : Godot::Color = Godot::Color.new(0.2, 0.6, 1.0, 1.0)
    #
    #   @[ExportToolButton("Recalculate Stats")]
    #   def recalculate_stats : Void
    #     Godot.print("Recalculating stats for level #{attr_level}...")
    #   end
    # end
    # ```
    #
    # ---
    #
    # ### 3. Signal Declaration & Ergonomic Listeners
    #
    # Signals connect nodes loosely across Crystal, GDScript, and C++.
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Declaration</th>
    #       <th>Generated Emission Method</th>
    #       <th>Generated Listener</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><code>signal died</code></td>
    #       <td><code>emit_died</code></td>
    #       <td><code>on_died { ... }</code>, <code>on_died_once { ... }</code></td>
    #     </tr>
    #     <tr>
    #       <td><code>signal damage_taken(amount : Int32, source : String)</code></td>
    #       <td><code>emit_damage_taken(amount, source)</code></td>
    #       <td><code>on_damage_taken { |amt, src| ... }</code></td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # #### First-Class Signal Awaiting
    #
    # ```
    # # Await bound signal directly:
    # await(hero.died, timeout_sec: 10.0)
    # hero.died.await(timeout_sec: 10.0)
    #
    # # Await by string name:
    # await(hero, "damage_taken", timeout_sec: 5.0)
    # hero.await_signal("damage_taken", timeout_sec: 5.0)
    # ```
    #
    # ---
    #
    # ### 4. Behavioral & Execution Directives
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Directive</th>
    #       <th>Scope</th>
    #       <th>Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><code>@[Tool]</code> or <code>tool</code></td>
    #       <td>Class level</td>
    #       <td>Enables execution inside the Godot Editor in real time (for gizmos, previews, tool buttons).</td>
    #     </tr>
    #     <tr>
    #       <td><code>@[RPC]</code></td>
    #       <td>Method level</td>
    #       <td>Configures multiplayer network replication (call_local, mode, channel).</td>
    #     </tr>
    #     <tr>
    #       <td><code>onready name : Type = path</code></td>
    #       <td>Property level</td>
    #       <td>Lazy node lookup evaluated during <code>_ready</code>.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    module L_MACRO_DSL_REFERENCE
      def self.features : Array(String)
        [
          "node macro for scene nodes defaulting to Godot::Node",
          "resource macro for custom resources defaulting to Resource",
          "gdclass macro for RefCounted engine classes",
          "Complete @[Export] annotations: ranges, enums, files, flags, groups, buttons",
          "Type-safe signal emission, ergonomic on_<signal> listeners, and first-class await",
          "@[Tool] in-editor execution, @[RPC] networking, and onready lazy node binding",
        ]
      end
    end
  end
end

