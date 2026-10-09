module Godot
  # ===========================================================================
  # Node Idiomatic & Generic Extensions
  # ===========================================================================
  class Node
    alias Node = Godot::Node
    getter local_groups : Set(String) = Set(String).new
    @local_children : Array(Node)?
    STANDALONE_PARENTS = Hash(UInt64, Node).new

    # Idiomatic child count getter
    def child_count : Int32
      return children.size.to_i32 if @pointer.null?
      get_child_count.to_i32
    end

    @local_name : String?

    def name : String
      return @local_name || "" if @pointer.null?
      get_name
    end

    def name=(val : String)
      if @pointer.null?
        @local_name = val
        return
      end
      set_name(val)
    end

    # Overload: Instantiates a Node of class T, configures it in block, adds it as child, and returns it.
    def add_child(type : T.class, force_readable_name : Bool = false, internal : InternalMode | Int = 0, &block : T -> Void) : T forall T
      node = ::Godot.create(type)
      with node yield node
      add_child(node.as(Node), force_readable_name, internal)
      node
    end

    # Overload: Instantiates a Node of class T, adds it as child, and returns it.
    def add_child(type : T.class, force_readable_name : Bool = false, internal : InternalMode | Int = 0) : T forall T
      node = ::Godot.create(type)
      add_child(node.as(Node), force_readable_name, internal)
      node
    end

    # Adds a child node. Falls back to local children array when running standalone.
    # Enforces thread-safety: off-thread calls raise ThreadAffinityError when attached to SceneTree.
    # Returns concrete instance type T for seamless chaining and assignment.
    def add_child(node : T, force_readable_name : Bool = false, internal : InternalMode | Int = 0) : T forall T
      Godot::ThreadSafety.assert_main_thread!("add_child", "Node", self, node)
      children << node.as(Node)
      STANDALONE_PARENTS[node.object_id] = self if @pointer.null?
      return node if @pointer.null?
      engine_add_child(node.as(Node), force_readable_name, internal)
      node
    end

    # Overload: Adds an existing child node, configures it in block, and returns concrete instance type T.
    def add_child(node : T, force_readable_name : Bool = false, internal : InternalMode | Int = 0, &block : T -> Void) : T forall T
      with node yield node
      add_child(node, force_readable_name, internal)
      node
    end

    # Overload: Instantiates a PackedScene as type T, configures it in block, adds it as child, and returns it.
    def add_child(scene : PackedScene, *, as type : T.class, force_readable_name : Bool = false, internal : InternalMode | Int = 0, &block : T -> Void) : T forall T
      node = scene.instantiate_as(type)
      with node yield node
      add_child(node.as(Node), force_readable_name, internal)
      node
    end

    # Overload: Instantiates a PackedScene as type T, adds it as child, and returns it.
    def add_child(scene : PackedScene, *, as type : T.class, force_readable_name : Bool = false, internal : InternalMode | Int = 0) : T forall T
      node = scene.instantiate_as(type)
      add_child(node.as(Node), force_readable_name, internal)
      node
    end

    # Overload: Instantiates a PackedScene as Node, configures it in block, adds it as child, and returns it.
    def add_child(scene : PackedScene, force_readable_name : Bool = false, internal : InternalMode | Int = 0, &block : Node -> Void) : Node
      node = scene.instantiate
      with node yield node
      add_child(node, force_readable_name, internal)
      node
    end

    # Overload: Instantiates a PackedScene as Node, adds it as child, and returns it.
    def add_child(scene : PackedScene, force_readable_name : Bool = false, internal : InternalMode | Int = 0) : Node
      node = scene.instantiate
      add_child(node, force_readable_name, internal)
      node
    end

    # Overload: Loads scene at path, instantiates as type T, configures in block, adds as child, and returns it.
    def add_child(scene_path : String, *, as type : T.class, force_readable_name : Bool = false, internal : InternalMode | Int = 0, &block : T -> Void) : T forall T
      scene = ::Godot.load_scene(scene_path)
      add_child(scene, as: type, force_readable_name: force_readable_name, internal: internal, &block)
    end

    # Overload: Loads scene at path, instantiates as type T, adds as child, and returns it.
    def add_child(scene_path : String, *, as type : T.class, force_readable_name : Bool = false, internal : InternalMode | Int = 0) : T forall T
      scene = ::Godot.load_scene(scene_path)
      add_child(scene, as: type, force_readable_name: force_readable_name, internal: internal)
    end


    # Explicit cross-thread helper that safely defers addition via Godot's MessageQueue
    def defer_add_child(node : Node, force_readable_name : Bool = false, internal : InternalMode | Int = 0) : Void
      internal_val = internal.is_a?(Int) ? internal.to_i64 : internal.value.to_i64
      call_deferred("add_child", node, force_readable_name, internal_val)
    end

    # Removes a child node. Falls back to local children array when running standalone.
    # Enforces thread-safety: off-thread calls raise ThreadAffinityError when attached to SceneTree.
    def remove_child(node : Node) : Void
      Godot::ThreadSafety.assert_main_thread!("remove_child", "Node", self, node)
      children.delete(node)
      STANDALONE_PARENTS.delete(node.object_id) if @pointer.null?
      return if @pointer.null?
      previous_def(node)
    end

    # Explicit cross-thread helper that safely defers removal via Godot's MessageQueue
    def defer_remove_child(node : Node) : Void
      call_deferred("remove_child", node)
    end

    # Explicit cross-thread helper that safely defers moving child via Godot's MessageQueue
    def defer_move_child(child_node : Node, to_position : Int64 | Int32) : Void
      call_deferred("move_child", child_node, to_position.to_i64)
    end

    # Reparents this node to a new parent.
    # Enforces thread-safety: off-thread calls raise ThreadAffinityError when attached to SceneTree.
    def reparent(new_parent : Node, keep_global_transform : Bool = true) : Void
      Godot::ThreadSafety.assert_main_thread!("reparent", "Node", self, new_parent)
      if @pointer.null?
        if lp = STANDALONE_PARENTS[object_id]?
          lp.remove_child(self)
        end
        new_parent.add_child(self)
        return
      end
      previous_def(new_parent, keep_global_transform)
    end

    # Safely destroys this node, unregistering parent references in standalone mode.
    def destroy : Void
      if @pointer.null?
        STANDALONE_PARENTS.delete(object_id)
        if loc_kids = @local_children
          loc_kids.each do |c|
            STANDALONE_PARENTS.delete(c.object_id)
          end
        end
      end
      super
    end

    # Explicit cross-thread helper that safely defers reparenting via Godot's MessageQueue
    def defer_reparent(new_parent : Node, keep_global_transform : Bool = true) : Void
      call_deferred("reparent", new_parent, keep_global_transform)
    end

    # Replaces this node with another node in the tree.
    # Enforces thread-safety: off-thread calls raise ThreadAffinityError when attached to SceneTree.
    def replace_by(node : Node, keep_groups : Bool = false) : Void
      Godot::ThreadSafety.assert_main_thread!("replace_by", "Node", self, node)
      return if @pointer.null?
      previous_def(node, keep_groups)
    end

    # Overload: Instantiates a Node of class T, configures it in block, adds it as sibling, and returns it.
    def add_sibling(type : T.class, force_readable_name : Bool = false, &block : T -> Void) : T forall T
      node = ::Godot.create(type)
      with node yield node
      add_sibling(node.as(Node), force_readable_name)
      node
    end

    # Overload: Instantiates a Node of class T, adds it as sibling, and returns it.
    def add_sibling(type : T.class, force_readable_name : Bool = false) : T forall T
      node = ::Godot.create(type)
      add_sibling(node.as(Node), force_readable_name)
      node
    end

    def add_sibling(sibling : T, force_readable_name : Bool = false) : T forall T
      Godot::ThreadSafety.assert_main_thread!("add_sibling", "Node", self, sibling)
      if @pointer.null?
        if p = get_parent?
          p.add_child(sibling.as(Node))
        end
        return sibling
      end
      engine_add_sibling(sibling.as(Node), force_readable_name)
      sibling
    end

    # Overload: Adds an existing sibling node, configures it in block, and returns concrete type T.
    def add_sibling(sibling : T, force_readable_name : Bool = false, &block : T -> Void) : T forall T
      add_sibling(sibling, force_readable_name)
      with sibling yield sibling
      sibling
    end

    # Overload: Instantiates a PackedScene as type T, configures it in block, adds it as sibling, and returns it.
    def add_sibling(scene : PackedScene, *, as type : T.class, force_readable_name : Bool = false, &block : T -> Void) : T forall T
      node = scene.instantiate_as(type)
      with node yield node
      add_sibling(node.as(Node), force_readable_name)
      node
    end

    # Overload: Instantiates a PackedScene as type T, adds it as sibling, and returns it.
    def add_sibling(scene : PackedScene, *, as type : T.class, force_readable_name : Bool = false) : T forall T
      node = scene.instantiate_as(type)
      add_sibling(node.as(Node), force_readable_name)
      node
    end

    # Overload: Instantiates a PackedScene as Node, configures it in block, adds it as sibling, and returns it.
    def add_sibling(scene : PackedScene, force_readable_name : Bool = false, &block : Node -> Void) : Node
      node = scene.instantiate
      with node yield node
      add_sibling(node, force_readable_name)
      node
    end

    # Overload: Instantiates a PackedScene as Node, adds it as sibling, and returns it.
    def add_sibling(scene : PackedScene, force_readable_name : Bool = false) : Node
      node = scene.instantiate
      add_sibling(node, force_readable_name)
      node
    end

    # Overload: Loads scene at path, instantiates as type T, configures in block, adds as sibling, and returns it.
    def add_sibling(scene_path : String, *, as type : T.class, force_readable_name : Bool = false, &block : T -> Void) : T forall T
      scene = ::Godot.load_scene(scene_path)
      add_sibling(scene, as: type, force_readable_name: force_readable_name, &block)
    end

    # Overload: Loads scene at path, instantiates as type T, adds as sibling, and returns it.
    def add_sibling(scene_path : String, *, as type : T.class, force_readable_name : Bool = false) : T forall T
      scene = ::Godot.load_scene(scene_path)
      add_sibling(scene, as: type, force_readable_name: force_readable_name)
    end


    # Moves child node to a new index in the parent's child list.
    # Enforces thread-safety: off-thread calls raise ThreadAffinityError when attached to SceneTree.
    def move_child(child_node : Node, to_index : Int | Int64) : Void
      Godot::ThreadSafety.assert_main_thread!("move_child", "Node", self, child_node)
      return if @pointer.null?
      previous_def(child_node, to_index.to_i64)
    end

    # Adds this node to the specified group (with default non-persistent flag)
    def add_to_group(group : String, persistent : Bool = false) : Void
      @local_groups.add(group)
      return if @pointer.null?
      previous_def(group, persistent)
    end

    # Removes this node from the specified group
    def remove_from_group(group : String) : Void
      @local_groups.delete(group)
      return if @pointer.null?
      previous_def(group)
    end

    # Returns true if this node belongs to the given node group.
    def in_group?(group_name : String) : Bool
      return true if @local_groups.includes?(group_name)
      return false unless alive?
      is_in_group(group_name)
    end

    # Returns true if this node belongs to the given node group specified as a Symbol.
    def in_group?(group_name : Symbol) : Bool
      in_group?(group_name.to_s)
    end

    # Returns true if this node belongs to the given node group specified as String or Symbol.
    def in_group?(group_name : String | Symbol) : Bool
      in_group?(group_name.to_s)
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

    # Returns the parent Node. Falls back to local standalone parents map when running without engine host.
    def get_parent : Node
      if @pointer.null?
        if standalone_p = STANDALONE_PARENTS[object_id]?
          return standalone_p
        end
      end
      previous_def
    end

    # Returns the parent Node, or nil if orphan
    def get_parent? : Node?
      return STANDALONE_PARENTS[object_id]? if @pointer.null?
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

    # Finds child node matching pattern, returning nil if not found
    def find_child?(pattern : String, recursive : Bool = true, owned : Bool = false) : Node?
      ptr = Bridge.node_find_child(@pointer, pattern, recursive, owned)
      return nil if ptr.null?
      if alive = Bridge.find_alive_instance(ptr)
        if node = alive.as?(Node)
          return node
        end
      end
      Node.new(ptr)
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
    def get_unique_node_as(unique_name : String, type : T.class) : T? forall T
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

    # Returns the child node at index `idx`.
    # Falls back to local standalone children list when unparented/headless.
    def get_child(idx : Int64, include_internal : Bool = false) : Node
      if @pointer.null?
        if kids = @local_children
          if idx >= 0 && idx < kids.size
            return kids[idx]
          end
        end
        return Node.new
      end
      previous_def(idx, include_internal)
    end

    def get_child(idx : Int, include_internal : Bool = false) : Node
      get_child(idx.to_i64, include_internal)
    end

    # Returns the number of child nodes belonging to this node.
    # Falls back to local standalone children list when unparented/headless.
    def get_child_count(include_internal : Bool = false) : Int64
      if @pointer.null?
        return (@local_children.try(&.size) || 0).to_i64
      end
      previous_def(include_internal)
    end

    # Returns an Array containing all child nodes belonging to this node.
    def get_children(include_internal : Bool = false) : ::Array(Node)
      check_alive!
      if @pointer.null?
        return @local_children ||= ::Array(Node).new
      end
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

    # Alias for `get_children` (falls back to local children array when running standalone)
    def children(include_internal : Bool = false) : ::Array(Node)
      if @pointer.null?
        return @local_children ||= ::Array(Node).new
      end
      get_children(include_internal)
    end

    # Yields each child node without allocating an intermediate array.
    def each_child(include_internal : Bool = false, &block : Node -> Void) : Void
      check_alive!
      if @pointer.null?
        if loc = @local_children
          loc.each { |c| yield c }
        end
        return
      end
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

    # Removes this node from its parent if currently inside a parent hierarchy.
    def remove_from_tree : Void
      return unless alive?
      Godot::ThreadSafety.assert_main_thread!("remove_from_tree", "Node", self)
      if p = get_parent?
        p.remove_child(self)
      end
    end

    # Removes and frees all child nodes under this node.
    def clear_children(include_internal : Bool = false) : Void
      return unless alive?
      Godot::ThreadSafety.assert_main_thread!("clear_children", "Node", self)
      get_children(include_internal).each do |child|
        child.queue_free if child.alive?
      end
    end

    # Deallocates node cleanly at frame end on the Main Thread.
    # Enforces thread-safety: off-thread calls on SceneTree nodes either raise ThreadAffinityError or auto-defer.
    def queue_free : Void
      if !Godot::ThreadSafety.main_thread?
        if alive? && (is_inside_tree? rescue false)
          case Godot::ThreadSafety.policy
          when .raise?
            raise ThreadAffinityError.new("queue_free", "Node", Godot::ThreadSafety.context_description, self)
          when .warn?
            Godot.printerr("[ThreadSafety] WARNING: 'Node#queue_free' called off Main Thread; automatically dispatching via call_deferred.")
            call_deferred("queue_free")
            return
          when .defer?
            call_deferred("queue_free")
            return
          when .disabled?
          end
        end
      end
      return if @pointer.null?
      previous_def
    end

    # Explicit cross-thread helper that safely queues deletion via Godot's MessageQueue
    def defer_queue_free : Void
      return unless alive?
      call_deferred("queue_free")
    end

    # Safe queue free that checks alive? before dispatching
    def safe_queue_free : Void
      queue_free if alive?
    end

    # Spawns a child node of type T, configures it in a block, and attaches it to this node
    def spawn_child(type : T.class, &block : T ->) : T forall T
      inst = ::Godot.create(type)
      with inst yield inst
      add_child(inst)
      inst
    end

    # Spawns a child node of type T and attaches it to this node
    def spawn_child(type : T.class) : T forall T
      inst = ::Godot.create(type)
      add_child(inst)
      inst
    end

    # Appends child to this node, enabling fluent chaining (parent << child1 << child2)
    def <<(child : Godot::Node) : self
      add_child(child)
      self
    end

    # Fluent alias for spawn_child
    def spawn(type : T.class, &block : T ->) : T forall T
      spawn_child(type, &block)
    end

    # Fluent alias for spawn_child
    def spawn(type : T.class) : T forall T
      spawn_child(type)
    end

    # Idiomatic alias for spawn_child
    def create_child(type : T.class, &block : T ->) : T forall T
      spawn_child(type, &block)
    end

    # Idiomatic alias for spawn_child
    def create_child(type : T.class) : T forall T
      spawn_child(type)
    end

    # Idiomatic alias for spawn_child
    def spawn_node(type : T.class, &block : T ->) : T forall T
      spawn_child(type, &block)
    end

    # Idiomatic alias for spawn_child
    def spawn_node(type : T.class) : T forall T
      spawn_child(type)
    end

    # Context-aware one-shot audio playback helper on Node
    def play_sound(
      stream_or_path : AudioStream | String,
      at : Vector2 | Vector3 | Nil = nil,
      pitch_scale : Float64 = 1.0,
      volume_db : Float64 = 0.0,
      bus : String = "Master",
      &block : Node -> Void
    ) : Node?
      return nil if @pointer.null?
      stream = stream_or_path.is_a?(String) ? (::Godot::PreloadCache.get_or_load(stream_or_path, AudioStream)) : stream_or_path
      player = if at.is_a?(Vector3) || (at.nil? && self.is_a?(Node3D))
                 p3d = ::Godot.create(AudioStreamPlayer3D)
                 p3d.global_position = at.as?(Vector3) || (self.as?(Node3D).try(&.global_position) || Vector3.zero)
                 p3d.as(Node)
               elsif at.is_a?(Vector2) || (at.nil? && self.is_a?(Node2D))
                 p2d = ::Godot.create(AudioStreamPlayer2D)
                 p2d.global_position = at.as?(Vector2) || (self.as?(Node2D).try(&.global_position) || Vector2.zero)
                 p2d.as(Node)
               else
                 ::Godot.create(AudioStreamPlayer).as(Node)
               end
      player.call("set_stream", stream)
      player.call("set_pitch_scale", pitch_scale.to_f32)
      player.call("set_volume_db", volume_db.to_f32)
      player.call("set_bus", bus)
      yield player
      host = if tree = ::Godot.get_tree?
               tree.current_scene || tree.root
             else
               topmost_parent
             end
      host.add_child(player)
      player.signal("finished").once { player.queue_free }
      player.call("play")
      player
    end

    def play_sound(
      stream_or_path : AudioStream | String,
      at : Vector2 | Vector3 | Nil = nil,
      pitch_scale : Float64 = 1.0,
      volume_db : Float64 = 0.0,
      bus : String = "Master"
    ) : Node?
      play_sound(stream_or_path, at, pitch_scale, volume_db, bus) { |_| }
    end
  end

  # ===========================================================================
  # CanvasItem Visual & Opacity Ergonomics
  # ===========================================================================
  class CanvasItem < Node
    @local_modulate : Color = Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)

    def set_modulate(modulate : Color) : Void
      @local_modulate = modulate
      return if @pointer.null?
      previous_def(modulate)
    end

    def get_modulate : Color
      return @local_modulate if @pointer.null?
      previous_def
    end

    def alpha : Float32
      get_modulate.a
    end

    def alpha=(val : Number) : Void
      m = get_modulate
      m.a = val.to_f32
      set_modulate(m)
    end
  end
end
