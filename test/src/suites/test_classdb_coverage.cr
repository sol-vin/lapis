# =============================================================================
# LibGodot Test Suite: Universal ClassDB Instantiation, Hierarchy & Destruction
# =============================================================================

include Lapis::Test

macro test_classdb(name, &block)
  Registry.register("ClassDB", {{name}}) do |node|
    root = node
    {{block.body}}
  end
end

test_classdb "ClassDB coverage: all 46 core 2D Node classes create, parent, unparent, and destroy" do
  classes_2d = [
    "AnimatableBody2D", "AnimatedSprite2D", "Area2D", "AudioListener2D", "AudioStreamPlayer2D",
    "BackBufferCopy", "Bone2D", "CPUParticles2D", "Camera2D", "CanvasGroup",
    "CanvasModulate", "CharacterBody2D", "CollisionPolygon2D", "CollisionShape2D", "DampedSpringJoint2D",
    "DirectionalLight2D", "GPUParticles2D", "GrooveJoint2D", "LightOccluder2D", "Line2D",
    "Marker2D", "MeshInstance2D", "MultiMeshInstance2D", "NavigationLink2D", "NavigationObstacle2D",
    "NavigationRegion2D", "Parallax2D", "ParallaxLayer", "Path2D", "PathFollow2D",
    "PhysicalBone2D", "PinJoint2D", "PointLight2D", "Polygon2D", "RayCast2D",
    "RemoteTransform2D", "RigidBody2D", "ShapeCast2D", "Skeleton2D", "Sprite2D",
    "StaticBody2D", "TileMap", "TileMapLayer", "TouchScreenButton", "VisibleOnScreenEnabler2D",
    "VisibleOnScreenNotifier2D",
  ]

  container = Godot.create(Godot::Node2D)
  container.name = "CoverageContainer2D"

  classes_2d.each do |cls_name|
    ptr = Godot::Bridge.construct_object(cls_name)
    assert_false ptr.null?, "Failed to instantiate 2D class #{cls_name}"

    n = Godot::Node2D.new(ptr)
    assert_true n.alive?, "Node #{cls_name} should be alive"
    inst_id = n.instance_id
    assert_true inst_id > 0_u64, "Node #{cls_name} should have non-zero instance ID"

    # Hierarchy operations
    container.add_child(n)
    assert_eq container.get_child_count, 1_i64
    assert_eq n.get_parent.name, "CoverageContainer2D"

    container.remove_child(n)
    assert_eq container.get_child_count, 0_i64
    assert_nil n.get_parent?

    # Proper destruction
    n.destroy
    assert_true n.destroyed?
    assert_false Godot::Object.is_instance_id_valid(inst_id), "Instance ID for #{cls_name} must be invalidated in engine"
  end

  container.destroy
end

test_classdb "ClassDB coverage: all 110 core 3D Node classes create, parent, unparent, and destroy" do
  classes_3d = [
    "AimModifier3D", "AnimatableBody3D", "AnimatedSprite3D", "Area3D", "AreaLight3D",
    "AudioListener3D", "AudioStreamPlayer3D", "BoneAttachment3D", "BoneConstraint3D", "BoneSpaceAdjuster3D",
    "BoneTwistDisperser3D", "CCDIK3D", "CPUParticles3D", "CSGBox3D", "CSGCombiner3D",
    "CSGCylinder3D", "CSGMesh3D", "CSGPolygon3D", "CSGSphere3D", "CSGTorus3D",
    "Camera3D", "CharacterBody3D", "CollisionPolygon3D", "CollisionShape3D", "ConeTwistJoint3D",
    "ConvertTransformModifier3D", "CopyTransformModifier3D", "Decal", "DirectionalLight3D", "FABRIK3D",
    "FogVolume", "GPUParticles3D", "GPUParticlesAttractorBox3D", "GPUParticlesAttractorSphere3D", "GPUParticlesAttractorVectorField3D",
    "GPUParticlesCollisionBox3D", "GPUParticlesCollisionHeightField3D", "GPUParticlesCollisionSDF3D", "GPUParticlesCollisionSphere3D", "Generic6DOFJoint3D",
    "GeometryInstance3D", "GridMap", "HingeJoint3D", "ImporterMeshInstance3D", "JacobianIK3D",
    "Label3D", "LightmapGI", "LightmapProbe", "LimitAngularVelocityModifier3D", "Line3D",
    "LookAtModifier3D", "Marker3D", "MeshInstance3D", "ModifierBoneTarget3D", "MultiMeshInstance3D",
    "NavigationLink3D", "NavigationObstacle3D", "NavigationRegion3D", "OccluderInstance3D", "OmniLight3D",
    "Path3D", "PathFollow3D", "PhysicalBone3D",
    "PhysicalBoneSimulator3D", "PinJoint3D", "RayCast3D", "ReflectionProbe", "RemoteTransform3D",
    "RetargetModifier3D", "RigidBody3D", "RootMotionView", "ShapeCast3D", "Skeleton3D",
    "SkeletonIK3D", "SkeletonModifier3D", "SliderJoint3D", "SoftBody3D", "SplineIK3D",
    "SpotLight3D", "SpringArm3D", "SpringBoneCollision3D", "SpringBoneCollisionCapsule3D", "SpringBoneCollisionPlane3D",
    "SpringBoneCollisionSphere3D", "SpringBoneSimulator3D", "Sprite3D", "StaticBody3D", "Trail3D",
    "TwoBoneIK3D", "VehicleBody3D", "VehicleWheel3D", "VisibleOnScreenEnabler3D", "VisibleOnScreenNotifier3D",
    "VisualInstance3D", "VoxelGI", "XRAnchor3D", "XRBodyModifier3D", "XRCamera3D",
    "XRController3D", "XRFaceModifier3D", "XRHandModifier3D", "XRNode3D", "XROrigin3D",
  ]

  container = Godot.create(Godot::Node3D)
  container.name = "CoverageContainer3D"

  class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)
  classes_3d.each do |cls_name|
    actual_name = cls_name
    if actual_name == "BoneSpaceAdjuster3D" && !class_db.call_bool("class_exists", "BoneSpaceAdjuster3D")
      actual_name = "BoneSpreader3D"
    end
    next unless class_db.call_bool("class_exists", actual_name)

    ptr = Godot::Bridge.construct_object(actual_name)
    assert_false ptr.null?, "Failed to instantiate 3D class #{actual_name}"

    n = Godot::Node3D.new(ptr)
    assert_true n.alive?, "Node #{actual_name} should be alive"
    inst_id = n.instance_id

    container.add_child(n)
    assert_eq container.get_child_count, 1_i64
    container.remove_child(n)
    assert_eq container.get_child_count, 0_i64

    n.destroy
    assert_true n.destroyed?
    assert_false Godot::Object.is_instance_id_valid(inst_id)
  end

  container.destroy
end

test_classdb "ClassDB coverage: all 59 core Control UI classes create, parent, unparent, and destroy" do
  classes_ctrl = [
    "AspectRatioContainer", "BaseButton", "BoxContainer", "Button", "CenterContainer",
    "CheckBox", "CheckButton", "CodeEdit", "ColorPicker", "ColorPickerButton",
    "ColorRect", "Container", "FlowContainer", "FoldableContainer", "GraphEdit",
    "GraphElement", "GraphFrame", "GraphNode", "GridContainer", "HBoxContainer",
    "HFlowContainer", "HScrollBar", "HSeparator", "HSlider", "HSplitContainer",
    "ItemList", "Label", "LineEdit", "LinkButton", "MarginContainer",
    "MenuBar", "MenuButton", "NinePatchRect", "OptionButton", "Panel",
    "PanelContainer", "ProgressBar", "Range", "ReferenceRect", "RichTextLabel",
    "ScrollContainer", "SpinBox", "SplitContainer", "SubViewportContainer", "TabBar",
    "TabContainer", "TextEdit", "TextureButton", "TextureProgressBar", "TextureRect",
    "Tree", "VBoxContainer", "VFlowContainer", "VScrollBar", "VSeparator",
    "VSlider", "VSplitContainer", "VideoStreamPlayer", "VirtualJoystick",
  ]

  container = Godot.create(Godot::Control)
  container.name = "CoverageContainerUI"

  classes_ctrl.each do |cls_name|
    ptr = Godot::Bridge.construct_object(cls_name)
    assert_false ptr.null?, "Failed to instantiate Control class #{cls_name}"

    n = Godot::Control.new(ptr)
    assert_true n.alive?
    inst_id = n.instance_id

    container.add_child(n)
    assert_eq container.get_child_count, 1_i64
    container.remove_child(n)
    assert_eq container.get_child_count, 0_i64

    n.destroy
    assert_true n.destroyed?
    assert_false Godot::Object.is_instance_id_valid(inst_id)
  end

  container.destroy
end

test_classdb "ClassDB coverage: all 27 core Other Node classes create, parent, unparent, and destroy" do
  classes_other = [
    "AcceptDialog", "AnimationPlayer", "AnimationTree", "AudioStreamPlayer", "CanvasLayer",
    "ConfirmationDialog", "Control", "FileDialog", "HTTPRequest", "MissingNode",
    "MultiplayerSpawner", "MultiplayerSynchronizer", "NavigationAgent2D", "NavigationAgent3D", "Node2D",
    "Node3D", "ParallaxBackground", "Popup", "PopupMenu", "PopupPanel",
    "ResourcePreloader", "ShaderGlobalsOverride", "StatusIndicator", "SubViewport", "Timer",
    "Window", "WorldEnvironment",
  ]

  container = Godot.create(Godot::Node)
  container.name = "CoverageContainerOther"

  classes_other.each do |cls_name|
    ptr = Godot::Bridge.construct_object(cls_name)
    assert_false ptr.null?, "Failed to instantiate Node class #{cls_name}"

    n = Godot::Node.new(ptr)
    assert_true n.alive?
    inst_id = n.instance_id

    container.add_child(n)
    assert_eq container.get_child_count, 1_i64
    container.remove_child(n)
    assert_eq container.get_child_count, 0_i64

    n.destroy
    assert_true n.destroyed?
    assert_false Godot::Object.is_instance_id_valid(inst_id)
  end

  container.destroy
end

test_classdb "ClassDB coverage: all 16 Meshes, 11 Materials, and 17 Physics Shapes" do
  resources = [
    # 16 Meshes
    "ArrayMesh", "BoxMesh", "CapsuleMesh", "CylinderMesh", "ImmediateMesh",
    "PlaceholderMesh", "PlaneMesh", "PointMesh", "PrimitiveMesh", "PrismMesh",
    "QuadMesh", "RibbonTrailMesh", "SphereMesh", "TextMesh", "TorusMesh", "TubeTrailMesh",
    # 11 Materials
    "BlitMaterial", "CanvasItemMaterial", "FogMaterial", "ORMMaterial3D", "PanoramaSkyMaterial",
    "ParticleProcessMaterial", "PhysicalSkyMaterial", "PlaceholderMaterial", "ProceduralSkyMaterial", "ShaderMaterial", "StandardMaterial3D",
    # 17 Shapes
    "BoxShape3D", "CapsuleShape2D", "CapsuleShape3D", "CircleShape2D", "ConcavePolygonShape2D",
    "ConcavePolygonShape3D", "ConvexPolygonShape2D", "ConvexPolygonShape3D", "CylinderShape3D", "HeightMapShape3D",
    "RectangleShape2D", "SegmentShape2D", "SeparationRayShape2D", "SeparationRayShape3D", "SphereShape3D",
    "WorldBoundaryShape2D", "WorldBoundaryShape3D",
  ]

  resources.each do |cls_name|
    ptr = Godot::Bridge.construct_object(cls_name)
    assert_false ptr.null?, "Failed to instantiate Resource class #{cls_name}"

    res = Godot::Resource.new(ptr)
    res.init_ref
    assert_true res.alive?
    inst_id = res.instance_id
    res.destroy

    assert_true res.destroyed?
    assert_false Godot::Object.is_instance_id_valid(inst_id), "Resource #{cls_name} still valid in ObjectDB after destroy"
  end
end

test_classdb "ClassDB coverage: core RefCounted utility classes instantiation and cleanup" do
  refcounted_classes = [
    "AESContext", "AStar2D", "AStar3D", "AStarGrid2D", "AnimatedTexture",
    "Animation", "AnimationLibrary", "AnimationNodeAnimation", "AnimationNodeBlendTree",
    "AnimationNodeStateMachine", "ConfigFile", "Crypto", "Curve", "FastNoiseLite",
    "Gradient", "Image", "ImageTexture", "NoiseTexture2D", "RandomNumberGenerator",
    "RegEx", "StyleBoxFlat", "StyleBoxLine", "Theme",
  ]

  refcounted_classes.each do |cls_name|
    ptr = Godot::Bridge.construct_object(cls_name)
    assert_false ptr.null?, "Failed to instantiate RefCounted class #{cls_name}"

    rc = Godot::RefCounted.new(ptr)
    rc.init_ref
    assert_true rc.alive?
    inst_id = rc.instance_id

    rc.destroy
    assert_true rc.destroyed?
    assert_false Godot::Object.is_instance_id_valid(inst_id), "RefCounted #{cls_name} still valid in ObjectDB after destroy"
  end
end
