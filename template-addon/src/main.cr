require "lapis"

# In non-release builds, load in-editor test suites so they register with Lapis::Test
# and appear in the Crystal Editor Hub (Unit Test Runner tab)
{% unless flag?(:release) %}
  require "../spec/editor/**"
  require "./docs"
{% end %}

# =============================================================================
# Crystal Addon - Custom Control Node
# =============================================================================
# A custom Godot Control node implemented entirely in Crystal.
# Regular Godot projects can instantiate this node in scenes or via GDScript.
node CrystalAddonBanner < Control do
  # Message displayed by the custom banner
  @[Export]
  property message : String = "Hello from Compiled Crystal Addon!"

  # Accent tint color for the banner text
  @[Export]
  property text_color : Color = Color.new(0.3_f32, 0.9_f32, 1.0_f32, 1.0_f32)

  # Display scale multiplier for the banner
  @[Export(range: 0.5_f32..3.0_f32, step: 0.1_f32)]
  property banner_scale : Float32 = 1.0_f32

  # Emitted when the banner is clicked or triggered
  signal banner_clicked(message : String)

  def _ready : Void
    Godot.print("[LapisAddon] CrystalAddonBanner initialized with message: '#{@message}' (scale: #{@banner_scale})")
  end

  def trigger_click : Void
    banner_clicked.emit(@message)
  end

  # Demonstrates connecting signals via Lapis piping operator (>>)
  def setup_click_logger(target : Godot::Object, method_name : String) : Void
    banner_clicked >> {target, method_name}
  end
end

# =============================================================================
# Crystal Addon - EditorPlugin Definition
# =============================================================================
# An EditorPlugin compiled into native code. When enabled in the Godot Editor
# (Project Settings -> Plugins), it hooks into editor events and lifecycle.
@[Tool]
node CrystalAddonPlugin < EditorPlugin do
  # Called when the plugin is activated or added to the editor scene tree
  def _enter_tree : Void
    Godot.print("==================================================================")
    Godot.print("  [LapisAddon] [CrystalAddonPlugin] Plugin activated in Godot Editor!")
    Godot.print("  [CRYSTAL_ADDON_VERIFIED_SUCCESS_8A3F1E] Custom compiled GDExtension plugin running in editor!")
    Godot.print("  [LapisAddon] Compiled Crystal GDExtension is running without Crystal installed.")
    Godot.print("==================================================================")
  end

  # Called when the plugin is deactivated or removed from the editor scene tree
  def _exit_tree : Void
    Godot.print("  [LapisAddon] [CrystalAddonPlugin] Plugin deactivated in Godot Editor.")
  end
end
