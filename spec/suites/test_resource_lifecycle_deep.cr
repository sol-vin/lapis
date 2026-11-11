# =============================================================================
# LibGodot Test Suite: Deep Resource Lifecycle, Server RID & Zero-Leak Verification
# =============================================================================

include Lapis::Test


test_suite "ResourceDeep" do
  test "RefCounted atomic lifecycle and ObjectDB cleanup" do
  ref_obj = Godot.create(Godot::RefCounted)
  inst_id = ref_obj.instance_id
  assert_true Godot::Object.is_instance_id_valid(inst_id)

  # Starts with 1 reference
  assert_eq ref_obj.get_reference_count, 1_i64

  # Explicitly reference once more
  ref_obj.reference
  assert_eq ref_obj.get_reference_count, 2_i64

  # First unreference decrements count back to 1
  ref_obj.unreference
  assert_eq ref_obj.get_reference_count, 1_i64
  assert_true Godot::Object.is_instance_id_valid(inst_id)

  # Destroy unreferences final reference and deallocates native object
  ref_obj.destroy
  assert_false Godot::Object.is_instance_id_valid(inst_id)
end

  test "StandardMaterial3D with child ImageTexture cleans up all server RIDs" do
  # Create backing image and image texture
  img = Godot.create(Godot::Image)
  assert_not_nil img
  img_id = img.instance_id
  assert_true Godot::Object.is_instance_id_valid(img_id)

  tex = Godot.create(Godot::ImageTexture)
  assert_not_nil tex
  tex_id = tex.instance_id
  assert_true Godot::Object.is_instance_id_valid(tex_id)

  # Create StandardMaterial3D and assign texture
  mat = Godot.create(Godot::StandardMaterial3D)
  mat_id = mat.instance_id
  assert_true Godot::Object.is_instance_id_valid(mat_id)
  mat.set_texture(Godot::BaseMaterial3D::TextureParam::TextureAlbedo.to_i64, tex)

  # Unreference texture and material
  tex.destroy
  mat.destroy
  img.destroy

  assert_false Godot::Object.is_instance_id_valid(mat_id)
  assert_false Godot::Object.is_instance_id_valid(tex_id)
  assert_false Godot::Object.is_instance_id_valid(img_id)
end

  test "Raw Godot.create(Image) survives ImageTexture#set_image and unreferences safely without double-free" do
  svg = %(<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8" viewBox="0 0 8 8"><rect width="8" height="8" fill="#ffffff"/></svg>)
  img = Godot.create(Godot::Image)
  img_id = img.instance_id
  assert_true Godot::Object.is_instance_id_valid(img_id)

  err = img.load_svg_from_string(svg, 1.0_f64)
  assert_eq err, Godot::Error::Ok

  itex = Godot.create(Godot::ImageTexture)
  itex_id = itex.instance_id
  itex.set_image(img)

  # Image must still be alive after transient const Ref<Image>& upload
  assert_true img.alive?
  assert_true Godot::Object.is_instance_id_valid(img_id)

  # Unreferencing the final reference destroys native Image and nullifies wrapper
  assert_true img.unreference
  assert_false img.alive?
  assert_false Godot::Object.is_instance_id_valid(img_id)

  # Redundant unreference on already-freed RefCounted is a safe no-op returning false
  assert_false img.unreference

  itex.destroy
  assert_false Godot::Object.is_instance_id_valid(itex_id)
end

  test "Physics 3D collision shapes allocate and release server RIDs cleanly" do
  shapes = [
    Godot.create(Godot::BoxShape3D).as(Godot::Shape3D),
    Godot.create(Godot::SphereShape3D).as(Godot::Shape3D),
    Godot.create(Godot::CapsuleShape3D).as(Godot::Shape3D),
    Godot.create(Godot::CylinderShape3D).as(Godot::Shape3D),
  ]

  shape_ids = shapes.map(&.instance_id)
  shape_ids.each do |sid|
    assert_true Godot::Object.is_instance_id_valid(sid)
  end

  # Assign shapes to CollisionShape3D nodes
  col_nodes = shapes.map do |s|
    cs = Godot.create(Godot::CollisionShape3D)
    cs.set_shape(s)
    cs
  end

  # Verify shapes are linked
  col_nodes.each_with_index do |cs, idx|
    ret_shape = cs.get_shape
    assert_not_nil ret_shape
    assert_eq ret_shape.instance_id, shape_ids[idx]
    ret_shape.destroy
  end

  # Cleanup collision nodes and shapes
  col_nodes.each(&.destroy)
  shapes.each(&.destroy)

  shape_ids.each do |sid|
    assert_false Godot::Object.is_instance_id_valid(sid)
  end
end

  test "Zero-accumulation high-churn allocation loop leaves baseline ObjectDB count" do
  GC.collect

  perf = Godot::Performance.new(Godot::Performance.singleton_ptr)
  baseline_objs = perf.get_monitor(Godot::Performance::Monitor::ObjectCount.to_i64)

  # Churn 500 RefCounted / Resource instances
  500.times do
    b = Godot.create(Godot::BoxShape3D)
    b.destroy

    m = Godot.create(Godot::StandardMaterial3D)
    m.destroy

    c = Godot.create(Godot::RefCounted)
    c.destroy
  end

  GC.collect
  final_objs = perf.get_monitor(Godot::Performance::Monitor::ObjectCount.to_i64)

  # Difference in object count must be 0 (no native leak)
  delta = final_objs - baseline_objs
  assert_true delta <= 0.0, "ObjectDB leaked #{delta} objects after 500-iteration churn loop!"
end

end
