module Godot
  # ===========================================================================
  # Node Idiomatic & Generic Extensions
  # ===========================================================================
  class Node
    alias Node = Godot::Node
    getter local_groups : Set(String) = Set(String).new
    @local_children : Array(Node)?

    # Returns the array of child nodes (locally tracked if standalone/unparented)
    def children : Array(Node)
      @local_children ||= Array(Node).new
    end

    # Adds a child node. Falls back to local children array when running standalone.
    def add_child(node : Node, force_readable_name : Bool = false, internal : InternalMode | Int = 0) : Void
      if @pointer.null?
        children << node
        return
      end
      previous_def(node, force_readable_name, internal)
    end

    # Removes a child node. Falls back to local children array when running standalone.
    def remove_child(node : Node) : Void
      if @pointer.null?
        children.delete(node)
        return
      end
      previous_def(node)
    end

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

    # Alias for `get_children`
    def children(include_internal : Bool = false) : ::Array(Node)
      get_children(include_internal)
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

    # Removes this node from its parent if currently inside a parent hierarchy.
    def remove_from_tree : Void
      return unless alive?
      if p = get_parent?
        p.remove_child(self)
      end
    end

    # Removes and frees all child nodes under this node.
    def clear_children(include_internal : Bool = false) : Void
      return unless alive?
      get_children(include_internal).each do |child|
        child.queue_free if child.alive?
      end
    end

    # Safe queue free that checks alive? before dispatching
    def safe_queue_free : Void
      queue_free if alive?
    end
  end
end
