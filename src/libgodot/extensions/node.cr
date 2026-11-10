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

    # Returns the SceneTree containing this node, or nil if not inside the tree
    def get_tree? : SceneTree?
      return nil if @pointer.null?
      tree = get_tree
      (tree.nil? || tree.pointer.null?) ? nil : tree
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

    # Returns true if Godot currently has this parent node locked (`data.blocked > 0`) while propagating
    # `_enter_tree` or `_ready` to its descendants, during which synchronous `add_child` fails in Godot.
    def busy_setting_up_children? : Bool
      return false if @pointer.null?
      return false unless (is_inside_tree rescue false)
      curr = ::Godot::NodeContext.current?
      return false if curr && curr.pointer == @pointer
      return true unless (is_node_ready rescue true)
      if curr && !curr.pointer.null? && !(curr.is_node_ready rescue true)
        return (is_ancestor_of(curr) rescue false)
      end
      false
    end

    # Adds a child node. Falls back to local children array when running standalone.
    # Enforces thread-safety: off-thread calls raise ThreadAffinityError when attached to SceneTree.
    # Returns concrete instance type T for seamless chaining and assignment.
    def add_child(node : T, force_readable_name : Bool = false, internal : InternalMode | Int = 0) : T forall T
      Godot::ThreadSafety.assert_main_thread!("add_child", "Node", self, node)
      if @pointer.null?
        children << node.as(Node)
        STANDALONE_PARENTS[node.object_id] = self
        return node
      end
      if busy_setting_up_children?
        defer_add_child(node.as(Node), force_readable_name, internal)
      else
        engine_add_child(node.as(Node), force_readable_name, internal)
      end
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

    # Overload: Instantiates a scene at path or PackedScene as type T, configures in block, adds as child, and returns it.
    def add_child(path_or_scene : String | PackedScene, type : T.class, force_readable_name : Bool = false, internal : InternalMode | Int = 0, &block : T -> Void) : T forall T
      node = type.instantiate(path_or_scene)
      with node yield node
      add_child(node.as(Node), force_readable_name, internal)
      node
    end

    # Overload: Instantiates a scene at path or PackedScene as type T, adds as child, and returns it.
    def add_child(path_or_scene : String | PackedScene, type : T.class, force_readable_name : Bool = false, internal : InternalMode | Int = 0) : T forall T
      node = type.instantiate(path_or_scene)
      add_child(node.as(Node), force_readable_name, internal)
      node
    end



    # Explicit cross-thread helper that safely defers addition via Godot's MessageQueue
    def defer_add_child(node : Node, force_readable_name : Bool = false, internal : InternalMode | Int = 0) : Void
      internal_val = internal.is_a?(Int) ? internal.to_i64 : internal.value.to_i64
      call_deferred("add_child", node, force_readable_name, internal_val)
    end

    # Removes a child node. Falls back to local children array when running standalone.
    # Enforces thread-safety: off-thread calls raise ThreadAffinityError when attached to SceneTree.
    def remove_child(node : Node?) : Void
      return unless node
      Godot::ThreadSafety.assert_main_thread!("remove_child", "Node", self, node)
      if @pointer.null?
        children.delete(node)
        STANDALONE_PARENTS.delete(node.object_id)
        return
      end
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
    def reparent(new_parent : Node?, keep_global_transform : Bool = true) : Void
      return unless new_parent
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
    def replace_by(node : Node?, keep_groups : Bool = false) : Void
      return unless node
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
      if (p = get_parent?) && p.busy_setting_up_children?
        call_deferred("add_sibling", sibling.as(Node), force_readable_name)
      else
        engine_add_sibling(sibling.as(Node), force_readable_name)
      end
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

    # Overload: Instantiates a scene at path or PackedScene as type T, configures in block, adds as sibling, and returns it.
    def add_sibling(path_or_scene : String | PackedScene, type : T.class, force_readable_name : Bool = false, &block : T -> Void) : T forall T
      node = type.instantiate(path_or_scene)
      with node yield node
      add_sibling(node.as(Node), force_readable_name)
      node
    end

    # Overload: Instantiates a scene at path or PackedScene as type T, adds as sibling, and returns it.
    def add_sibling(path_or_scene : String | PackedScene, type : T.class, force_readable_name : Bool = false) : T forall T
      node = type.instantiate(path_or_scene)
      add_sibling(node.as(Node), force_readable_name)
      node
    end



    # Moves child node to a new index in the parent's child list.
    # Enforces thread-safety: off-thread calls raise ThreadAffinityError when attached to SceneTree.
    def move_child(child_node : Node?, to_index : Int64) : Void
      return unless child_node
      Godot::ThreadSafety.assert_main_thread!("move_child", "Node", self, child_node)
      return if @pointer.null?
      previous_def(child_node, to_index)
    end

    def move_child(child_node : Node?, to_index : Int) : Void
      move_child(child_node, to_index.to_i64)
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

    # Returns the viewport this node is attached to, or nil if detached/orphan
    def get_viewport? : Viewport?
      return nil unless alive?
      return nil if @pointer.null?
      vp = get_viewport
      vp.pointer.null? ? nil : vp
    end

    # Checks if this node, or any ancestor above it in the scene tree, belongs to `group`.
    def in_group_or_ancestor?(group : String) : Bool
      curr : Node? = self
      while curr && curr.alive?
        return true if curr.in_group?(group)
        curr = curr.get_parent?
      end
      false
    end

    def in_group_or_ancestor?(group : Symbol) : Bool
      in_group_or_ancestor?(group.to_s)
    end

    # Returns the nearest ancestor node (or nil) belonging to `group`.
    def ancestor_in_group?(group : String) : Node?
      curr = get_parent?
      while curr && curr.alive?
        return curr if curr.in_group?(group)
        curr = curr.get_parent?
      end
      nil
    end

    def ancestor_in_group?(group : Symbol) : Node?
      ancestor_in_group?(group.to_s)
    end

    # Traverses upward starting from self, returning the first node matching type T, or nil if none found.
    def self_or_ancestor?(type : T.class) : T? forall T
      curr : Node? = self
      while curr && curr.alive?
        if typed = curr.as_a?(T)
          return typed
        end
        curr = curr.get_parent?
      end
      nil
    end

    # Traverses upward starting from self, returning the first node matching type T, or raising NilAssertionError.
    def self_or_ancestor(type : T.class) : T forall T
      self_or_ancestor?(type) || raise NilAssertionError.new("No #{T.name} ancestor found for node '#{name}'")
    end

    # Traverses upward starting from parent, returning the first ancestor matching type T, or nil.
    def ancestor?(type : T.class) : T? forall T
      curr = get_parent?
      while curr && curr.alive?
        if typed = curr.as_a?(T)
          return typed
        end
        curr = curr.get_parent?
      end
      nil
    end

    # Traverses upward starting from parent, returning the first ancestor matching type T, or raising NilAssertionError.
    def ancestor(type : T.class) : T forall T
      ancestor?(type) || raise NilAssertionError.new("No #{T.name} ancestor found for node '#{name}'")
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
      tid = signal_target_id
      previous_def
      Godot.notify_object_queued_for_deletion(tid, yield_awaiters: true)
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

    # ===========================================================================
    # Class-Level Scene Instantiation Ergonomics
    # ===========================================================================

    # Instantiates a PackedScene (.tscn) from path or scene instance directly as this Node type.
    # When cached is true (default), leverages PreloadCache to prevent redundant disk I/O.
    def self.instantiate(path_or_scene : String | PackedScene, edit_state : Int64 = 0_i64, cached : Bool = true) : self
      scene = case path_or_scene
      in String
        cached ? ::Godot::PreloadCache.get_or_load(path_or_scene, ::Godot::PackedScene) : ::Godot.load_scene(path_or_scene)
      in PackedScene
        path_or_scene
      end
      scene.instantiate_as(self, edit_state)
    end

    # Instantiates a PackedScene (.tscn) from path or scene instance directly as this Node type and configures it in a block.
    def self.instantiate(path_or_scene : String | PackedScene, edit_state : Int64 = 0_i64, cached : Bool = true, &block : self -> Void) : self
      node = instantiate(path_or_scene, edit_state, cached)
      with node yield node
      node
    end

    # Safe nilable variant: instantiates a PackedScene directly as this Node type, returning nil on load failure or type mismatch.
    def self.instantiate?(path_or_scene : String | PackedScene, edit_state : Int64 = 0_i64, cached : Bool = true) : self?
      scene = case path_or_scene
      in String
        cached ? ::Godot::PreloadCache.get_or_load?(path_or_scene, ::Godot::PackedScene) : ::Godot.load_scene?(path_or_scene)
      in PackedScene
        path_or_scene
      end
      return nil unless scene
      scene.instantiate_as?(self, edit_state)
    end

    # Safe nilable variant configuring the instance in a block when not nil.
    def self.instantiate?(path_or_scene : String | PackedScene, edit_state : Int64 = 0_i64, cached : Bool = true, &block : self -> Void) : self?
      if node = instantiate?(path_or_scene, edit_state, cached)
        with node yield node
        node
      end
    end

    # Resolves the effective scene root owner for dynamically spawned children:
    # checks `get_owner`, then `get_tree.get_edited_scene_root` (in editor), then `get_tree.get_current_scene`.
    def effective_scene_owner : Node?
      return nil if @pointer.null?
      owner_node = get_owner
      return owner_node if owner_node && !owner_node.pointer.null? && owner_node.alive?
      if is_inside_tree && (tree = get_tree?)
        edited = tree.get_edited_scene_root
        return edited if edited && !edited.pointer.null? && edited.alive?
        curr_scene = tree.get_current_scene
        return curr_scene if curr_scene && !curr_scene.pointer.null? && curr_scene.alive?
      end
      nil
    end

    # Finds an existing alive child node with `name` of type `T` (including across hot-reloads),
    # or creates, names, adds it as a child, and optionally sets its `owner` to `effective_scene_owner`.
    def ensure_child(name : String, type : T.class, set_owner : Bool = false, internal : InternalMode | Int = 0) : T forall T
      if !@pointer.null?
        if existing = get_node_or_null(NodePath.new(name))
          if !existing.pointer.null? && existing.alive? && !existing.is_queued_for_deletion?
            if casted = existing.godot_as?(T)
              if set_owner && (own = effective_scene_owner) && own.pointer != casted.pointer
                casted.set_owner(own)
              end
              return casted
            else
              remove_child(existing)
              existing.queue_free
            end
          end
        end
      else
        children.each do |c|
          if c.name == name && (casted = c.as?(T))
            return casted
          end
        end
      end

      child = ::Godot.create(type)
      child.name = name
      add_child(child, false, internal)
      if set_owner && !@pointer.null? && (own = effective_scene_owner) && own.pointer != child.pointer
        child.set_owner(own)
      end
      child
    end

    def ensure_child(name : String, type : T.class, set_owner : Bool = false, internal : InternalMode | Int = 0, &block : T -> Void) : T forall T
      child = ensure_child(name, type, set_owner: set_owner, internal: internal)
      with child yield child
      child
    end

    # Removes and frees all direct children (or only those whose name starts with `prefix`).
    def clear_children!(prefix : String? = nil) : Void
      if @pointer.null?
        if pfx = prefix
          children.reject! { |c| c.name.starts_with?(pfx) }
        else
          children.clear
        end
        return
      end
      cnt = get_child_count
      (cnt - 1).downto(0) do |i|
        c = get_child(i)
        next if c.pointer.null? || !c.alive?
        if pfx = prefix
          next unless c.name.starts_with?(pfx)
        end
        remove_child(c)
        c.queue_free
      end
    end
  end

  # ===========================================================================
  # Procedural Geometry, MultiMesh & Collision Helpers
  # ===========================================================================
  class CollisionObject3D < Node3D
    # Ensures a `CollisionShape3D` child with a `BoxShape3D` of `size` and local `position` exists on this body.
    # If `!enabled`, disables an existing collider if present and returns nil.
    def ensure_box_collider!(name : String, size : Vector3, position : Vector3 = Vector3.zero, enabled : Bool = true) : CollisionShape3D?
      if !enabled
        if !@pointer.null? && (existing = get_node_or_null(NodePath.new(name))) && !existing.pointer.null?
          if cs = existing.godot_as?(CollisionShape3D)
            cs.set_disabled(true)
          end
        end
        return nil
      end
      cs = ensure_child(name, CollisionShape3D)
      box = cs.get_shape.try(&.godot_as?(BoxShape3D)) || ::Godot.create(BoxShape3D)
      box.set_size(size)
      cs.set_shape(box)
      cs.position = position
      cs.set_disabled(false)
      cs
    end

    # Ensures a `CollisionShape3D` child with a `CylinderShape3D` of `radius` and `height` exists on this body.
    def ensure_cylinder_collider!(name : String, radius : Float32, height : Float32, position : Vector3 = Vector3.zero, enabled : Bool = true) : CollisionShape3D?
      if !enabled
        if !@pointer.null? && (existing = get_node_or_null(NodePath.new(name))) && !existing.pointer.null?
          if cs = existing.godot_as?(CollisionShape3D)
            cs.set_disabled(true)
          end
        end
        return nil
      end
      cs = ensure_child(name, CollisionShape3D)
      cyl = cs.get_shape.try(&.godot_as?(CylinderShape3D)) || ::Godot.create(CylinderShape3D)
      cyl.set_radius(radius.to_f64)
      cyl.set_height(height.to_f64)
      cs.set_shape(cyl)
      cs.position = position
      cs.set_disabled(false)
      cs
    end

    # Ensures a `CollisionShape3D` child with a `ConvexPolygonShape3D` exists on this body.
    def ensure_convex_collider!(name : String, points : PackedVector3Array, position : Vector3 = Vector3.zero, enabled : Bool = true) : CollisionShape3D?
      if !enabled
        if !@pointer.null? && (existing = get_node_or_null(NodePath.new(name))) && !existing.pointer.null?
          if cs = existing.godot_as?(CollisionShape3D)
            cs.set_disabled(true)
          end
        end
        return nil
      end
      cs = ensure_child(name, CollisionShape3D)
      conv = cs.get_shape.try(&.godot_as?(ConvexPolygonShape3D)) || ::Godot.create(ConvexPolygonShape3D)
      conv.set_points(points)
      cs.set_shape(conv)
      cs.position = position
      cs.set_disabled(false)
      cs
    end
  end

  class SurfaceTool < RefCounted
    # Block-scoped `SurfaceTool` builder that calls `begin(primitive)`, yields the `SurfaceTool`,
    # commits to `target` (or a new `ArrayMesh`), and returns the resulting `ArrayMesh`.
    def self.build(primitive : Mesh::PrimitiveType = Mesh::PrimitiveType::PrimitiveTriangles, target : ArrayMesh? = nil, &block : SurfaceTool -> Void) : ArrayMesh
      st = ::Godot.create(SurfaceTool)
      st.begin(primitive)
      yield st
      mesh = target || ::Godot.create(ArrayMesh)
      st.commit(mesh)
      mesh
    end
  end

  class MeshDataTool < RefCounted
    # Block-scoped `MeshDataTool` helper that loads `surface` from `array_mesh` and yields the tool if `Error::Ok`.
    def self.with_surface(array_mesh : ArrayMesh, surface : Int = 0, &block : MeshDataTool -> Void) : Bool
      mdt = ::Godot.create(MeshDataTool)
      err = mdt.create_from_surface(array_mesh, surface.to_i64)
      return false unless err == Error::Ok
      yield mdt
      true
    end
  end

  class MultiMeshInstance3D < GeometryInstance3D
    # Populates this `MultiMeshInstance3D` with 3D `transforms` (and optional per-instance `colors`),
    # automatically configuring `transform_format`, `instance_count`, and `custom_aabb`.
    def populate_3d!(
      mesh : Mesh,
      transforms : Indexable(Transform3D),
      colors : Indexable(Color)? = nil,
      padding : Float32 = 0.5_f32
    ) : AABB
      mm = get_multimesh
      if mm.pointer.null? || !mm.alive?
        mm = ::Godot.create(MultiMesh)
        mm.set_transform_format(MultiMesh::TransformFormat::Transform3d)
        mm.set_use_colors(!colors.nil?)
        set_multimesh(mm)
      else
        mm.set_instance_count(0_i64)
        mm.set_transform_format(MultiMesh::TransformFormat::Transform3d)
        mm.set_use_colors(!colors.nil?)
      end
      mm.set_mesh(mesh)
      count = transforms.size
      mm.set_instance_count(count.to_i64)
      return AABB.new if count == 0

      first_p = transforms[0].origin
      min_x = first_p.x; max_x = first_p.x
      min_y = first_p.y; max_y = first_p.y
      min_z = first_p.z; max_z = first_p.z

      count.times do |i|
        xf = transforms[i]
        mm.set_instance_transform(i.to_i64, xf)
        if cols = colors
          mm.set_instance_color(i.to_i64, cols[i]) if i < cols.size
        end
        p = xf.origin
        min_x = p.x if p.x < min_x; max_x = p.x if p.x > max_x
        min_y = p.y if p.y < min_y; max_y = p.y if p.y > max_y
        min_z = p.z if p.z < min_z; max_z = p.z if p.z > max_z
      end

      aabb_pos = Vector3.new(min_x - padding, min_y - padding, min_z - padding)
      aabb_size = Vector3.new(
        (max_x - min_x) + padding * 2.0_f32,
        (max_y - min_y) + padding * 2.0_f32,
        (max_z - min_z) + padding * 2.0_f32
      )
      bounds = AABB.new(aabb_pos, aabb_size)
      set_custom_aabb(bounds)
      bounds
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
