# spec/crshader_editor_spec.cr
# Verifies CrShader in-editor GDExtension plugin, bottom-panel CrShader Studio GUI controls,
# and live shader transpilation via EditorDriver.

require "./spec_helper"
require "../bin/crshader/src/crshader/compiler"

describe "CrShader In-Editor Plugin & Studio GUI" do
  ext = {% if flag?(:windows) %} "dll" {% elsif flag?(:darwin) %} "dylib" {% else %} "so" {% end %}
  bridge_name = {% if flag?(:windows) %} "crystal_bridge.dll" {% elsif flag?(:darwin) %} "crystal_bridge.dylib" {% else %} "crystal_bridge.so" {% end %}

  it "resolves Godot engine executable" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    godot.should_not be_nil
  end

  it "verifies crshader addon binary deliverables exist" do
    crshader_dir = "bin/crshader"
    addon_bin = File.join(crshader_dir, "addons", "crshader", "bin")

    File.exists?(File.join(addon_bin, bridge_name)).should be_true, "Missing #{bridge_name} in #{addon_bin}"
    File.exists?(File.join(addon_bin, "game.#{ext}")).should be_true, "Missing game.#{ext} in #{addon_bin}"
    {% if flag?(:windows) %}
      File.exists?(File.join(addon_bin, "gc.dll")).should be_true
      File.exists?(File.join(addon_bin, "iconv-2.dll")).should be_true
      File.exists?(File.join(addon_bin, "pcre2-8.dll")).should be_true
    {% end %}
    # Confirm architectural invariant: libgodot.dll must NEVER be in an addon
    File.exists?(File.join(addon_bin, "libgodot.dll")).should be_false
  end

  it "launches headless Godot editor, initializes CrShaderPlugin, and mounts CrShader Studio GUI" do
    godot = Lapis::Test::EditorDriver.resolve_godot
    next unless godot && File.exists?(godot)

    crshader_dir = "bin/crshader"
    next unless Dir.exists?(crshader_dir)

    addon_bridge = File.join(crshader_dir, "addons", "crshader", "bin", bridge_name)
    addon_game = File.join(crshader_dir, "addons", "crshader", "bin", "game.#{ext}")
    next unless File.exists?(addon_bridge) && File.exists?(addon_game)

    res = Lapis::Test::EditorDriver.run_tool_tests(project: crshader_dir, quit_frames: 120)
    res.exit_code.should eq(0), "Headless editor exited with non-zero code #{res.exit_code}:\n#{res.output}"

    # 1. Verify GDExtension initialization token
    res.output.should contain("[CRShader] Crystal GDExtension EditorPlugin initialized!")

    # 2. Verify project scanning and background shader compilation
    res.output.should contain("[CRShader] Scanning project and compiling .crshader files...")
    res.output.should contain("Initial compilation complete:")

    # 3. Verify CrShaderStudioPanel instantiated and mounted into editor bottom panel
    res.output.should contain("[CRShader] CrShader Studio GUI mounted (Toolbar, SourceEdit, TargetEdit ready)")

    # 4. Verify clean deactivation on editor quit
    res.output.should contain("[CRShader] Crystal GDExtension EditorPlugin deactivated.")
  end

  it "performs live DSL transpilation from .crshader to valid Godot 4 .gdshader" do
    sample_crshader = <<-CRSHADER
shader_type :canvas_item

render_mode :unshaded

uniform wave_speed : Float32 = 1.5, hint: hint_range(0.1, 5.0)
uniform wave_frequency : Float32 = 10.0, hint: hint_range(1.0, 30.0)
uniform wave_amplitude : Float32 = 0.05, hint: hint_range(0.0, 0.2)
uniform water_color : Color = Color.new(0.1, 0.4, 0.8, 0.85), hint: :source_color

def fragment
  uv = UV
  wave = sin(uv.y * wave_frequency + TIME * wave_speed) * wave_amplitude
  distorted_uv = vec2(uv.x + wave, uv.y)
  COLOR = water_color
end
CRSHADER

    compiler = CrShader::Compiler.new
    gdshader = compiler.compile_source(sample_crshader, filename: "water.crshader")

    # Verify transpiled Godot 4 shader syntax
    gdshader.should contain("shader_type canvas_item;")
    gdshader.should contain("render_mode unshaded;")
    gdshader.should contain("uniform float wave_speed : hint_range(0.1, 5.0) = 1.5;")
    gdshader.should contain("uniform float wave_frequency : hint_range(1.0, 30.0) = 10.0;")
    gdshader.should contain("uniform float wave_amplitude : hint_range(0.0, 0.2) = 0.05;")
    gdshader.should contain("uniform vec4 water_color : source_color = vec4(0.1, 0.4, 0.8, 0.85);")
    gdshader.should contain("void fragment()")
    gdshader.should contain("COLOR = water_color;")
  end
end
