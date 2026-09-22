require "lapis"

# In non-release builds, load in-editor test suites so they register with Lapis::Test
# and appear in the Crystal Editor Hub (Unit Test Runner tab)
{% unless flag?(:release) %}
  require "../spec/editor/**"
{% end %}

# =============================================================================
# Crystal Addon - Custom Node Definition
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

  def _ready : Void
    Godot.print("[CrystalAddonBanner] Initialized with message: #{@message}")
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
    Godot.print("  [CrystalAddonPlugin] Plugin activated in Godot Editor!")
    Godot.print("  [CRYSTAL_ADDON_VERIFIED_SUCCESS_8A3F1E] Custom compiled GDExtension plugin running in editor!")
    Godot.print("  Compiled Crystal GDExtension is running without Crystal installed.")
    Godot.print("==================================================================")
  end

  # Called when the plugin is deactivated or removed from the editor scene tree
  def _exit_tree : Void
    Godot.print("  [CrystalAddonPlugin] Plugin deactivated in Godot Editor.")
  end
end
