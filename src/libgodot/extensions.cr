module Godot
  # ===========================================================================
  # Key & InputEventKey Extensions
  # ===========================================================================
  class InputEventKey < Godot::InputEventWithModifiers
    # Returns the pressed keycode as a strongly-typed `Godot::Key` enum
    def key : Godot::Key
      Godot::Key.new(keycode)
    end

    # Returns the physical keycode as a strongly-typed `Godot::Key` enum
    def physical_key : Godot::Key
      Godot::Key.new(physical_keycode)
    end
  end

  enum Key : Int64
    # Allows direct equality comparison between Godot::Key and integer keycodes
    def ==(other : Int) : Bool
      value == other.to_i64
    end
  end

  # ===========================================================================
  # PackedScene Generic Extensions
  # ===========================================================================
  class PackedScene < Resource
    # Convenience zero-argument instantiate defaulting edit_state to 0
    def instantiate : Node
      instantiate(0_i64)
    end

    # Instantiates the scene and casts directly to wrapper type T
    def instantiate_as(type : T.class, edit_state : Int64 = 0_i64) : T forall T
      node = instantiate(edit_state)
      if alive = Bridge.find_alive_instance(node.pointer)
        if typed = alive.as?(T)
          return typed
        end
      end
      T.new(node.pointer)
    end

    # Instantiates the scene and casts directly to wrapper type T (named argument alias)
    def instantiate(as type : T.class, edit_state : Int64 = 0_i64) : T forall T
      instantiate_as(type, edit_state)
    end
  end

  # ===========================================================================
  # SceneTree Ergonomic Extensions
  # ===========================================================================
  class SceneTree < MainLoop
    # Creates a SceneTreeTimer with integer seconds
    def create_timer(time_sec : Int, process_always : Bool = true, process_in_physics : Bool = false, ignore_time_scale : Bool = false) : SceneTreeTimer
      create_timer(time_sec.to_f64, process_always, process_in_physics, ignore_time_scale)
    end
  end

  # ===========================================================================
  # Node Idiomatic & Generic Extensions
  # ===========================================================================
  class Node < Object
    # Returns true if this node is currently a member of the active SceneTree.
    def inside_tree? : Bool
      is_inside_tree
    end

    getter local_groups : Set(String) = Set(String).new

    # Adds this node to the specified group (with default non-persistent flag)
    def add_to_group(group : String, persistent : Bool = false) : Void
      @local_groups.add(group)
      return if @pointer.null?
      previous_def(group, persistent)
    end

    # Returns true if this node belongs to the given node group.
    def in_group?(group_name : String) : Bool
      return true if @local_groups.includes?(group_name)
      return false unless alive?
      is_in_group(group_name)
    end

    # Returns the parent node cast to T, or nil if parent is not of type T or is null
    def get_parent_as(type : T.class) : T? forall T
      if parent = get_parent?
        if alive = Bridge.find_alive_instance(parent.pointer)
          if typed = alive.as?(T)
            return typed
          end
        end
        T.new(parent.pointer)
      end
    end

    # Returns the parent Node, or nil if orphan
    def get_parent? : Node?
      return nil unless alive?
      p = get_parent
      p.pointer.null? ? nil : p
    end

    # Retrieves child at specified index, or nil if not found
    def get_child?(idx : Int, include_internal : Bool = false) : Node?
      return nil unless alive?
      return nil if @pointer.null?
      c = get_child(idx.to_i64, include_internal)
      c.pointer.null? ? nil : c
    end

    # Retrieves child at specified index cast to type T, or nil if not found or not matching type
    def get_child_as(type : T.class, idx : Int, include_internal : Bool = false) : T? forall T
      if child = get_child?(idx, include_internal)
        if !child.pointer.null? && (alive = Bridge.find_alive_instance(child.pointer))
          if typed = alive.as?(T)
            return typed
          end
        end
        if child.is_a?(T)
          return child
        elsif !child.pointer.null? && Bridge.object_is_class(child.pointer, T.name.split("::").last)
          return T.new(child.pointer)
        end
      end
    end

    # Finds child node matching pattern and casts to T, returning nil if not found
    def find_child_as(type : T.class, pattern : String, recursive : Bool = true, owned : Bool = false) : T? forall T
      ptr = Bridge.node_find_child(@pointer, pattern, recursive, owned)
      return nil if ptr.null?
      if alive = Bridge.find_alive_instance(ptr)
        if typed = alive.as?(T)
          return typed
        end
      end
      if Bridge.object_is_class(ptr, T.name.split("::").last)
        T.new(ptr)
      else
        nil
      end
    end

    # Returns the scene unique node with name `%unique_name` cast to T
    def get_unique_node_as(type : T.class, unique_name : String) : T? forall T
      path = unique_name.starts_with?("%") ? unique_name : "%#{unique_name}"
      ptr = Bridge.node_get_node(@pointer, path)
      ptr = Bridge.node_find_child(@pointer, unique_name.lchop("%"), true, false) if ptr.null?
      return nil if ptr.null?
      if alive = Bridge.find_alive_instance(ptr)
        if typed = alive.as?(T)
          return typed
        end
      end
      if Bridge.object_is_class(ptr, T.name.split("::").last)
        T.new(ptr)
      else
        nil
      end
    end

    # Returns an Array containing all child nodes belonging to this node.
    def get_children(include_internal : Bool = false) : ::Array(Node)
      check_alive!
      return ::Array(Node).new if @pointer.null?
      count = get_child_count(include_internal)
      return ::Array(Node).new if count <= 0
      children = ::Array(Node).new(count.to_i32)
      0.upto(count - 1) do |i|
        child = get_child(i.to_i64, include_internal)
        if !child.pointer.null? && (alive = Bridge.find_alive_instance(child.pointer))
          if alive_node = alive.as?(Node)
            children << alive_node
            next
          end
        end
        children << child
      end
      children
    end

    # Yields each child node without allocating an intermediate array.
    def each_child(include_internal : Bool = false, &block : Node -> Void) : Void
      check_alive!
      return if @pointer.null?
      count = get_child_count(include_internal)
      0.upto(count - 1) do |i|
        child = get_child(i.to_i64, include_internal)
        if !child.pointer.null? && (alive = Bridge.find_alive_instance(child.pointer))
          if alive_node = alive.as?(Node)
            yield alive_node
            next
          end
        end
        yield child
      end
    end

    # Returns all children of this node matching or cast to type T.
    def get_children_as(type : T.class, include_internal : Bool = false) : ::Array(T) forall T
      check_alive!
      res = ::Array(T).new
      class_name = T.name.split("::").last
      get_children(include_internal).each do |child|
        if !child.pointer.null? && (alive = Bridge.find_alive_instance(child.pointer))
          if typed = alive.as?(T)
            res << typed
            next
          end
        end
        if child.is_a?(T)
          res << child
        elsif !child.pointer.null? && Bridge.object_is_class(child.pointer, class_name)
          res << T.new(child.pointer)
        end
      end
      res
    end
  end

  # ===========================================================================
  # TreeItem Extensions
  # ===========================================================================
  class TreeItem < Object
    # Returns an Array containing all child TreeItems of this item.
    def get_children : ::Array(TreeItem)
      check_alive!
      return ::Array(TreeItem).new if @pointer.null?
      count = get_child_count
      return ::Array(TreeItem).new if count <= 0
      children = ::Array(TreeItem).new(count.to_i32)
      0.upto(count - 1) do |i|
        child = get_child(i.to_i64)
        children << child unless child.pointer.null?
      end
      children
    end
  end

  # ===========================================================================
  # SceneTree Group Extensions
  # ===========================================================================
  class SceneTree < MainLoop
    def get_first_node_in_group_as(type : T.class, group_name : String) : T? forall T
      return nil if @pointer.null?
      node = get_first_node_in_group(group_name)
      return nil if node.nil? || node.pointer.null?
      node.as?(T)
    end
  end

  # ===========================================================================
  # SceneTreeTimer Cooperative Await
  # ===========================================================================
  # Cooperatively awaits a SceneTreeTimer until its countdown expires
  def self.await(timer : SceneTreeTimer) : Void
    while timer.alive? && timer.get_time_left > 0.0
      Fiber.yield
    end
  end

  # ===========================================================================
  # Resource & Scene Loading Helpers
  # ===========================================================================
  def self.load(path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : Resource
    ptr = Bridge.resource_loader_load(path, type_hint, cache_mode)
    Resource.new(ptr)
  end

  def self.load(path : String, as type : T.class, type_hint : String = "", cache_mode : Int64 = 0_i64) : T forall T
    res = load(path, type_hint, cache_mode)
    if res.pointer.null?
      raise NilAssertionError.new("Failed to load resource at '#{path}' as #{T}")
    end
    if alive = Bridge.find_alive_instance(res.pointer)
      if typed = alive.as?(T)
        return typed
      end
    end
    T.new(res.pointer)
  end

  def self.load_as(type : T.class, path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : T forall T
    load(path, as: type, type_hint: type_hint, cache_mode: cache_mode)
  end

  def self.load_scene(path : String) : PackedScene
    load(path, as: PackedScene)
  end

  def self.instantiate_scene(path : String, type : T.class) : T forall T
    scene = load_scene(path)
    inst = scene.instantiate
    type.new(inst.pointer)
  end

  class ResourceSaver < Godot::Object
    # Saves a resource to disk using dynamic reflection to ensure valid Ref<Resource> and string marshalling.
    def save(resource : Resource, path : String = "", flags : SaverFlags | Int = 0) : Godot::Error
      flag_val = flags.is_a?(Int) ? flags.to_i64 : flags.value.to_i64
      err_code = call_i64("save", resource, path, flag_val)
      godot_return_enum(Godot::Error, err_code)
    end
  end

  # ===========================================================================
  # Input Delegators
  # ===========================================================================
  class Input < Godot::Object
    def action_pressed?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_pressed(action, exact_match)
    end

    def action_just_pressed?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_just_pressed(action, exact_match)
    end

    def action_just_released?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_just_released(action, exact_match)
    end

    def axis(negative_action : String, positive_action : String) : Float32
      Bridge.get_axis(negative_action, positive_action)
    end

    def get_vector(negative_x : String, positive_x : String, negative_y : String, positive_y : String, deadzone : Float64 = -1.0_f64) : Vector2
      Bridge.get_vector(negative_x, positive_x, negative_y, positive_y, deadzone)
    end

    def is_mouse_button_pressed(button : MouseButton | Int32 | Int64) : Bool
      Bridge.is_mouse_button_pressed(button.to_i64)
    end

    def mouse_button_pressed?(button : MouseButton | Int32 | Int64) : Bool
      Bridge.is_mouse_button_pressed(button.to_i64)
    end

    def use_accumulated_input : Bool
      Bridge.use_accumulated_input
    end

    def use_accumulated_input=(enable : Bool) : Void
      Bridge.use_accumulated_input = enable
    end

    def self.action_pressed?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_pressed(action, exact_match)
    end

    def self.action_just_pressed?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_just_pressed(action, exact_match)
    end

    def self.action_just_released?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_just_released(action, exact_match)
    end

    def self.axis(negative_action : String, positive_action : String) : Float32
      Bridge.get_axis(negative_action, positive_action)
    end

    def self.get_vector(negative_x : String, positive_x : String, negative_y : String, positive_y : String, deadzone : Float64 = -1.0_f64) : Vector2
      Bridge.get_vector(negative_x, positive_x, negative_y, positive_y, deadzone)
    end

    def self.is_mouse_button_pressed(button : MouseButton | Int32 | Int64) : Bool
      Bridge.is_mouse_button_pressed(button.to_i64)
    end

    def self.mouse_button_pressed?(button : MouseButton | Int32 | Int64) : Bool
      Bridge.is_mouse_button_pressed(button.to_i64)
    end

    def self.use_accumulated_input : Bool
      Bridge.use_accumulated_input
    end

    def self.use_accumulated_input=(enable : Bool) : Void
      Bridge.use_accumulated_input = enable
    end
  end

  # ===========================================================================
  # RayCast & ShapeCast Query Extensions
  # ===========================================================================
  godot_collider_query RayCast2D, indexed: false
  godot_collider_query RayCast3D, indexed: false
  godot_collider_query ShapeCast2D, indexed: true
  godot_collider_query ShapeCast3D, indexed: true

  # ===========================================================================
  # Image Extensions
  # ===========================================================================
  class Image < Resource
    # Returns the format of the image
    def format : Format
      get_format
    end
  end
end

struct Enum
  def ==(other : Int) : Bool
    value == other
  end

  def !=(other : Int) : Bool
    value != other
  end
end

struct Int
  def ==(other : Enum) : Bool
    self == other.value
  end

  def !=(other : Enum) : Bool
    self != other.value
  end

  def ==(other : Godot::Key) : Bool
    to_i64 == other.value
  end
end

