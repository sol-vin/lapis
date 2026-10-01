# ==============================================================================
# Lapis::Docs - Custom Editor Inspector Plugins & Controls
# ==============================================================================

{% unless flag?(:release) %}
module Lapis
  module Docs
    module F_SCRIPTING_AND_INTEROPERABILITY
      # # Custom Editor Inspector Plugins & Controls
      #
      # Comprehensive guide to authoring custom `EditorInspectorPlugin` and `EditorProperty`
      # controls in 100% pure Crystal to customize Godot's Inspector panel for game nodes and resources.
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
      #       <td><strong>Inspector Plugin Architecture</strong></td>
      #       <td><code>.topic_00_inspector_plugin_architecture</code></td>
      #       <td>Understanding EditorInspectorPlugin lifecycle and virtual method hooks.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Authoring Custom Inspector Controls</strong></td>
      #       <td><code>.topic_01_custom_controls_and_property_editors</code></td>
      #       <td>Building custom sliders, buttons, and property controls in Crystal.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Registering via EditorPlugin</strong></td>
      #       <td><code>.topic_02_registration_and_cleanup</code></td>
      #       <td>Registering and unregistering inspector plugins cleanly in EditorPlugin lifecycle.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # ### Related Guides & Source References
      # - **Live Specs**: `spec/suites/test_inspector_plugin.cr`
      # - **Editor Plugin Lifecycle**: `src/libgodot/editor.cr`
      #
      module D_CUSTOM_INSPECTOR_PLUGINS
        # **Inspector Plugin Architecture**: Understanding EditorInspectorPlugin lifecycle and virtual method hooks.
        #
        # #### Virtual Method Lifecycle
        #
        # <table>
        #   <thead>
        #     <tr>
        #       <th>Virtual Method</th>
        #       <th>Signature</th>
        #       <th>Purpose</th>
        #     </tr>
        #   </thead>
        #   <tbody>
        #     <tr>
        #       <td><code>_can_handle</code></td>
        #       <td><code>_can_handle(object : Godot::Object) : Bool</code></td>
        #       <td>Returns true if this inspector plugin should parse properties for the given object.</td>
        #     </tr>
        #     <tr>
        #       <td><code>_parse_begin</code></td>
        #       <td><code>_parse_begin(object : Godot::Object) : Void</code></td>
        #       <td>Called before property parsing; ideal for adding header controls or tool buttons.</td>
        #     </tr>
        #     <tr>
        #       <td><code>_parse_category</code></td>
        #       <td><code>_parse_category(object : Godot::Object, category : String) : Bool</code></td>
        #       <td>Invoked for each property category; return true to override default category rendering.</td>
        #     </tr>
        #     <tr>
        #       <td><code>_parse_property</code></td>
        #       <td><code>_parse_property(object, type, name, hint, hint_string, usage, wide) : Bool</code></td>
        #       <td>Customizes or replaces the inspector control for an individual exported property.</td>
        #     </tr>
        #     <tr>
        #       <td><code>_parse_end</code></td>
        #       <td><code>_parse_end(object : Godot::Object) : Void</code></td>
        #       <td>Called after all properties are parsed; ideal for adding footer widgets or diagnostic telemetry.</td>
        #     </tr>
        #   </tbody>
        # </table>
        #
        def self.topic_00_inspector_plugin_architecture : Nil; end

        # **Authoring Custom Inspector Controls**: Building custom sliders, buttons, and property controls in Crystal.
        #
        # ```crystal
        # require "libgodot"
        #
        # # Custom inspector plugin enhancing WeaponData resource inspection
        # node WeaponInspectorPlugin < EditorInspectorPlugin do
        #   def _can_handle(object : Godot::Object) : Bool
        #     object.is_class("WeaponData")
        #   end
        #
        #   def _parse_begin(object : Godot::Object) : Void
        #     # Add a quick test-fire button at the top of the Weapon inspector
        #     btn = Godot.create(Godot::Button)
        #     if btn && !btn.pointer.null?
        #       btn.call("set_text", "⚡ Test Fire Weapon")
        #       btn.connect("pressed") do |_args|
        #         Godot.print("Weapon test fire triggered from custom inspector panel!")
        #       end
        #       add_custom_control(btn)
        #     end
        #   end
        #
        #   def _parse_property(object : Godot::Object, type : Int64, name : String,
        #                       hint_type : Int64, hint_string : String, usage_flags : Int64, wide : Bool) : Bool
        #     if name == "damage_multiplier"
        #       # Embed custom visual slider for damage multiplier
        #       slider = Godot.create(Godot::HSlider)
        #       if slider && !slider.pointer.null?
        #         add_custom_control(slider)
        #       end
        #       return true # Return true to replace the default property line
        #     end
        #     false
        #   end
        # end
        # ```
        #
        def self.topic_01_custom_controls_and_property_editors : Nil; end

        # **Registering via EditorPlugin**: Registering and unregistering inspector plugins cleanly in EditorPlugin lifecycle.
        #
        # ```crystal
        # node WeaponToolPlugin < EditorPlugin do
        #   @inspector_plugin : WeaponInspectorPlugin? = nil
        #
        #   def _enter_tree : Void
        #     plugin = Godot.create(WeaponInspectorPlugin)
        #     if plugin
        #       @inspector_plugin = plugin
        #       add_inspector_plugin(plugin)
        #       Godot.print("[WeaponToolPlugin] Custom weapon inspector plugin registered.")
        #     end
        #   end
        #
        #   def _exit_tree : Void
        #     if plugin = @inspector_plugin
        #       remove_inspector_plugin(plugin)
        #       @inspector_plugin = nil
        #       Godot.print("[WeaponToolPlugin] Custom weapon inspector plugin unregistered.")
        #     end
        #   end
        # end
        # ```
        #
        def self.topic_02_registration_and_cleanup : Nil; end
      end
    end
  end
end
{% end %}
