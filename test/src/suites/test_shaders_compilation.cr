# =============================================================================
# LibGodot Test Suite: Shaders, VisualShaders & Uniform Pipelines
# =============================================================================

include Lapis::Test

test_shader "CanvasItem 2D shader compilation and ShaderMaterial binding" do
  shader = Godot.create(Godot::Shader)
  code = <<-GLSL
  shader_type canvas_item;
  void fragment() {
      COLOR = vec4(1.0, 0.5, 0.25, 1.0);
  }
  GLSL

  shader.set_code(code)
  assert_true shader.get_code.includes?("shader_type canvas_item"), "Shader code should be stored"

  mat = Godot.create(Godot::ShaderMaterial)
  mat.set_shader(shader)

  ret_shader = mat.get_shader
  assert_not_nil ret_shader
  assert_false ret_shader.pointer.null?
  assert_eq ret_shader.get_instance_id, shader.get_instance_id
end

test_shader "Spatial 3D shader compilation with vertex and fragment stages" do
  shader = Godot.create(Godot::Shader)
  code = <<-GLSL
  shader_type spatial;
  render_mode cull_disabled, unshaded;
  void vertex() {
      VERTEX.y += sin(TIME * 2.0);
  }
  void fragment() {
      ALBEDO = vec3(0.2, 0.8, 0.4);
      ROUGHNESS = 0.1;
      METALLIC = 0.9;
  }
  GLSL

  shader.set_code(code)
  assert_true shader.get_code.includes?("shader_type spatial"), "Spatial shader code should be stored"

  mat = Godot.create(Godot::ShaderMaterial)
  mat.set_shader(shader)

  mesh_inst = Godot.create(Godot::MeshInstance3D)
  box = Godot.create(Godot::BoxMesh)
  mesh_inst.set_mesh(box)
  mesh_inst.set_surface_override_material(0_i64, mat)

  override_mat = mesh_inst.get_surface_override_material(0_i64)
  assert_not_nil override_mat
  assert_false override_mat.pointer.null?

  mesh_inst.destroy
end

test_shader "Particle and Sky shader types compilation" do
  part_shader = Godot.create(Godot::Shader)
  part_code = <<-GLSL
  shader_type particles;
  void start() {
      VELOCITY = vec3(0.0, 10.0, 0.0);
  }
  GLSL
  part_shader.set_code(part_code)
  assert_true part_shader.get_code.includes?("shader_type particles")

  sky_shader = Godot.create(Godot::Shader)
  sky_code = <<-GLSL
  shader_type sky;
  void sky() {
      COLOR = vec3(0.1, 0.2, 0.5);
  }
  GLSL
  sky_shader.set_code(sky_code)
  assert_true sky_shader.get_code.includes?("shader_type sky")
end

test_shader "ShaderMaterial uniform parameter round-trip across Variant types" do
  shader = Godot.create(Godot::Shader)
  code = <<-GLSL
  shader_type canvas_item;
  uniform float u_speed = 2.5;
  uniform vec2 u_offset = vec2(10.0, 20.0);
  uniform vec3 u_tint = vec3(1.0, 0.5, 0.25);
  uniform vec4 u_color = vec4(0.1, 0.2, 0.3, 1.0);
  uniform bool u_active = true;
  void fragment() {
      COLOR = u_color;
  }
  GLSL
  shader.set_code(code)

  mat = Godot.create(Godot::ShaderMaterial)
  mat.set_shader(shader)

  # 1. Float uniform
  mat.call("set_shader_parameter", "u_speed", 5.75_f64)
  val_float = mat.call_f64("get_shader_parameter", "u_speed")
  assert_approx_eq val_float, 5.75

  # 2. Vector2 uniform
  mat.call("set_shader_parameter", "u_offset", Godot::Vector2.new(42.0, 84.0))

  # 3. Vector3 uniform
  mat.call("set_shader_parameter", "u_tint", Godot::Vector3.new(0.1, 0.4, 0.9))

  # 4. Color uniform
  mat.call("set_shader_parameter", "u_color", Godot::Color.new(0.8, 0.2, 0.4, 0.9))

  # 5. Bool uniform
  mat.call("set_shader_parameter", "u_active", false)
  val_bool = mat.call_bool("get_shader_parameter", "u_active")
  assert_false val_bool
end

test_shader "VisualShader node graph creation and port connection" do
  vs = Godot.create(Godot::VisualShader)
  vs.set_mode(Godot::Shader::Mode::ModeSpatial)

  stage = Godot::VisualShader::Type::TypeFragment

  color_node = Godot.create(Godot::VisualShaderNodeColorConstant)
  color_node.set_constant(Godot::Color.new(0.75, 0.25, 0.5, 1.0))

  # Add color constant node at ID 2 within Fragment stage
  node_id = 2_i64
  vs.add_node(stage, color_node, Godot::Vector2.new(100.0, 100.0), node_id)
  ret_node = vs.get_node(stage, node_id)
  assert_not_nil ret_node
  assert_false ret_node.pointer.null?

  # Node position configuration
  vs.set_node_position(stage, node_id, Godot::Vector2.new(150.0, 200.0))
  node_pos = vs.get_node_position(stage, node_id)
  assert_approx_eq node_pos.x, 150.0_f32
  assert_approx_eq node_pos.y, 200.0_f32

  # Connect Color output (port 0) to Albedo input (port 0 of output node 0)
  output_node_id = 0_i64
  from_port = 0_i64
  to_port = 0_i64
  vs.connect_nodes(stage, node_id, from_port, output_node_id, to_port)
  assert_true vs.is_node_connection(stage, node_id, from_port, output_node_id, to_port), "VisualShader connection should exist"

  vs.disconnect_nodes(stage, node_id, from_port, output_node_id, to_port)
  assert_false vs.is_node_connection(stage, node_id, from_port, output_node_id, to_port), "VisualShader connection should be severed"

  vs.remove_node(stage, node_id)
end
