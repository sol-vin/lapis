module Godot
  # Traversal and pattern matching engine for scene tree glob queries.
  module NodeQuery
    # Searches the scene tree hierarchy from origin matching the glob pattern.
    # Supports single-level wildcard '*' and recursive subtree wildcard '**'.
    def self.find_nodes(origin : Node, pattern : String, case_sensitive : Bool = true) : ::Array(Node)
      return ::Array(Node).new unless origin.active?

      clean_pattern = pattern.strip
      return ::Array(Node).new if clean_pattern.empty?

      start_node = origin

      if clean_pattern == "." || clean_pattern == "./"
        return [origin] of Node
      end

      # Absolute path starting with /
      if clean_pattern.starts_with?("/")
        start_node = origin.topmost_parent
        clean_pattern = clean_pattern.lchop("/")
        return [start_node] of Node if clean_pattern.empty?
      end

      # Unique node prefix %
      if clean_pattern.starts_with?("%")
        parts = clean_pattern.split('/', 2)
        unique_name = parts[0].lchop("%")
        if unique = find_unique_node(origin, unique_name)
          if parts.size > 1 && !parts[1].empty?
            start_node = unique
            clean_pattern = parts[1]
          else
            return [unique] of Node
          end
        else
          return ::Array(Node).new
        end
      end

      # Normalize path segments (ignore redundant . or empty segments)
      raw_segments = clean_pattern.split('/')
      segments = ::Array(String).new
      raw_segments.each do |seg|
        next if seg.empty? || seg == "."
        segments << seg
      end

      return [start_node] of Node if segments.empty?

      results = ::Array(Node).new
      visited = Set(UInt64).new

      match_step(start_node, segments, 0, results, visited, case_sensitive)
      results
    end

    private def self.collect_all_descendants(node : Node, results : ::Array(Node), visited : Set(UInt64)) : Void
      node.each_child do |child|
        id = child.signal_target_id
        id = child.object_id if id == 0
        if visited.add?(id)
          results << child
        end
        collect_all_descendants(child, results, visited)
      end
    end

    private def self.match_step(
      node : Node,
      segments : ::Array(String),
      seg_idx : Int32,
      results : ::Array(Node),
      visited : Set(UInt64),
      case_sensitive : Bool
    ) : Void
      if seg_idx >= segments.size
        id = node.signal_target_id
        id = node.object_id if id == 0
        if visited.add?(id)
          results << node
        end
        return
      end

      seg = segments[seg_idx]

      if seg == ".."
        if p = node.get_parent?
          match_step(p, segments, seg_idx + 1, results, visited, case_sensitive)
        end
        return
      end

      if seg == "**"
        # Case A: 0 levels (test remainder starting on current node)
        if seg_idx + 1 < segments.size
          match_step(node, segments, seg_idx + 1, results, visited, case_sensitive)
        end

        # Case B: 1 or more levels
        is_terminal = (seg_idx == segments.size - 1)
        node.each_child do |child|
          if is_terminal
            id = child.signal_target_id
            id = child.object_id if id == 0
            if visited.add?(id)
              results << child
            end
            collect_all_descendants(child, results, visited)
          else
            match_step(child, segments, seg_idx, results, visited, case_sensitive)
          end
        end
        return
      end

      node.each_child do |child|
        child_name = child.name
        matches = if seg == "*"
          true
        elsif seg.includes?('*') || seg.includes?('?')
          if case_sensitive
            File.match?(seg, child_name)
          else
            File.match?(seg.downcase, child_name.downcase)
          end
        else
          if case_sensitive
            child_name == seg
          else
            child_name.compare(seg, case_insensitive: true) == 0
          end
        end

        if matches
          match_step(child, segments, seg_idx + 1, results, visited, case_sensitive)
        end
      end
    end

    private def self.find_unique_node(origin : Node, unique_name : String) : Node?
      if !origin.pointer.null?
        if n = origin.get_node?("%#{unique_name}")
          return n
        end
        if n = origin.find_child?(unique_name, recursive: true)
          return n
        end
      end
      origin.topmost_parent.get_nodes("**").find { |n| n.name == unique_name }
    end
  end

  class Node
    # Attempts to downcast or wrap this node as type T. Returns nil if node does not inherit from T.
    def self.cast_to?(node : Node, type : T.class) : T? forall T
      {% if T <= Godot::Node %}
        return nil unless node.active?
        if node.is_a?(T)
          return node
        end
        if !node.pointer.null?
          if alive = Bridge.find_alive_instance(node.pointer)
            if typed = alive.as?(T)
              return typed
            end
          end
          class_name = T.name.split("::").last
          if Bridge.object_is_class(node.pointer, class_name)
            return T.new(node.pointer)
          end
        end
        nil
      {% else %}
        nil
      {% end %}
    end

    # Returns all nodes matching the glob pattern as Array(Node).
    # Supports single-level wildcard '*' and recursive globstar '**'.
    def get_nodes(pattern : String, case_sensitive : Bool = true) : ::Array(Node)
      NodeQuery.find_nodes(self, pattern, case_sensitive)
    end

    # Returns all nodes matching the glob pattern filtered and cast to Array(T).
    def get_nodes(pattern : String, type : T.class, case_sensitive : Bool = true) : ::Array(T) forall T
      res = ::Array(T).new
      get_nodes(pattern, case_sensitive).each do |n|
        if typed = Node.cast_to?(n, type)
          res << typed
        end
      end
      res
    end

    # Streaming iteration over all nodes matching pattern without intermediate allocation.
    def each_node(pattern : String, case_sensitive : Bool = true, &block : Node -> Void) : Void
      get_nodes(pattern, case_sensitive).each(&block)
    end

    # Streaming iteration over all nodes matching pattern filtered and cast to type T.
    def each_node(pattern : String, type : T.class, case_sensitive : Bool = true, &block : T -> Void) : Void forall T
      get_nodes(pattern, type, case_sensitive).each(&block)
    end

    # Returns the first node matching pattern, or nil if none found.
    def first_node?(pattern : String, case_sensitive : Bool = true) : Node?
      get_nodes(pattern, case_sensitive).first?
    end

    # Returns the first node matching pattern cast to type T, or nil if none found or type mismatch.
    def first_node?(pattern : String, type : T.class, case_sensitive : Bool = true) : T? forall T
      get_nodes(pattern, type, case_sensitive).first?
    end

    # Returns the first node matching pattern, raising NodeNotFoundError if not found.
    def first_node(pattern : String, case_sensitive : Bool = true) : Node
      first_node?(pattern, case_sensitive) || raise NodeNotFoundError.new("No node found matching pattern '#{pattern}' (relative to '#{name}').")
    end

    # Returns the first node matching pattern cast to type T, raising NodeNotFoundError if not found.
    def first_node(pattern : String, type : T.class, case_sensitive : Bool = true) : T forall T
      first_node?(pattern, type, case_sensitive) || raise NodeNotFoundError.new("No node of type #{T.name} found matching pattern '#{pattern}' (relative to '#{name}').")
    end

    # Walks upward to find the topmost ancestor node, or the SceneTree root if attached.
    def topmost_parent : Node
      curr = self
      while parent = curr.get_parent?
        curr = parent
      end
      curr
    end

    # Alias to `topmost_parent`
    def scene_root : Node
      topmost_parent
    end

    # Walks up the parent hierarchy to find the nearest ancestor of type T, returning nil if not found.
    def ancestor?(type : T.class) : T? forall T
      curr = get_parent?
      while curr
        if typed = Node.cast_to?(curr, type)
          return typed
        end
        curr = curr.get_parent?
      end
      nil
    end

    # Walks up the parent hierarchy to find the nearest ancestor of type T, raising NodeNotFoundError if not found.
    def ancestor(type : T.class) : T forall T
      ancestor?(type) || raise NodeNotFoundError.new("No ancestor of type #{T.name} found for '#{name}'.")
    end

    # Walks up the parent hierarchy to find the nearest ancestor matching pattern.
    def ancestor?(pattern : String, case_sensitive : Bool = true) : Node?
      ancestor?(pattern, Node, case_sensitive)
    end

    # Walks up the parent hierarchy to find the nearest ancestor matching the pattern and type.
    def ancestor?(pattern : String, type : T.class, case_sensitive : Bool = true) : T? forall T
      curr = get_parent?
      while curr
        matched = if pattern == "*"
          true
        elsif pattern.includes?('*') || pattern.includes?('?')
          case_sensitive ? File.match?(pattern, curr.name) : File.match?(pattern.downcase, curr.name.downcase)
        else
          case_sensitive ? curr.name == pattern : curr.name.compare(pattern, case_insensitive: true) == 0
        end

        if matched
          if typed = Node.cast_to?(curr, type)
            return typed
          end
        end
        curr = curr.get_parent?
      end
      nil
    end

    # Returns an Array containing all ancestor nodes up to the root.
    def ancestors : ::Array(Node)
      ancestors(Node)
    end

    # Returns an Array containing all ancestor nodes up to the root cast to type T.
    def ancestors(type : T.class) : ::Array(T) forall T
      res = ::Array(T).new
      curr = get_parent?
      while curr
        if typed = Node.cast_to?(curr, type)
          res << typed
        end
        curr = curr.get_parent?
      end
      res
    end

    # Returns all descendant nodes of this node as Array(Node).
    def descendants : ::Array(Node)
      get_nodes("**")
    end

    # Returns all descendant nodes of this node matching or cast to type T.
    def descendants(type : T.class) : ::Array(T) forall T
      get_nodes("**", type)
    end

    # Streaming iteration over all descendants.
    def each_descendant(&block : Node -> Void) : Void
      get_nodes("**").each(&block)
    end

    # Streaming iteration over all descendants cast to type T.
    def each_descendant(type : T.class, &block : T -> Void) : Void forall T
      get_nodes("**", type).each(&block)
    end

    # Returns all sibling nodes sharing this node's parent, excluding this node.
    def siblings : ::Array(Node)
      if p = get_parent?
        p.children.reject { |c| c == self || c.signal_target_id == signal_target_id }
      else
        ::Array(Node).new
      end
    end

    # Returns all sibling nodes cast to type T, excluding this node.
    def siblings(type : T.class) : ::Array(T) forall T
      res = ::Array(T).new
      siblings.each do |s|
        if typed = Node.cast_to?(s, type)
          res << typed
        end
      end
      res
    end

    # Returns the previous sibling node in the parent's child list, or nil if this is the first child or an orphan.
    def previous_sibling? : Node?
      if p = get_parent?
        kids = p.children
        idx = kids.index { |c| c == self || c.signal_target_id == signal_target_id }
        if idx && idx > 0
          return kids[idx - 1]?
        end
      end
      nil
    end

    # Returns the previous sibling node cast to type T, or nil if none found.
    def previous_sibling?(type : T.class) : T? forall T
      if s = previous_sibling?
        Node.cast_to?(s, type)
      end
    end

    # Returns the next sibling node in the parent's child list, or nil if this is the last child or an orphan.
    def next_sibling? : Node?
      if p = get_parent?
        kids = p.children
        idx = kids.index { |c| c == self || c.signal_target_id == signal_target_id }
        if idx && idx + 1 < kids.size
          return kids[idx + 1]?
        end
      end
      nil
    end

    # Returns the next sibling node cast to type T, or nil if none found.
    def next_sibling?(type : T.class) : T? forall T
      if s = next_sibling?
        Node.cast_to?(s, type)
      end
    end

    # Returns the first child node, or nil if this node has no children.
    def first_child? : Node?
      children.first?
    end

    # Returns the first child node cast to type T, or nil if none found.
    def first_child?(type : T.class) : T? forall T
      children.each do |c|
        if typed = Node.cast_to?(c, type)
          return typed
        end
      end
      nil
    end

    # Returns the last child node, or nil if this node has no children.
    def last_child? : Node?
      children.last?
    end

    # Returns the last child node cast to type T, or nil if none found.
    def last_child?(type : T.class) : T? forall T
      children.reverse_each do |c|
        if typed = Node.cast_to?(c, type)
          return typed
        end
      end
      nil
    end

    # Returns all nodes in the given group from the active scene tree (or local subtree in standalone mode) as Array(Node).
    def nodes_in_group(group : String) : ::Array(Node)
      nodes_in_group(group, Node)
    end

    # Returns all nodes in the given group from the active scene tree (or local subtree in standalone mode) cast to type T.
    def nodes_in_group(group : String, type : T.class) : ::Array(T) forall T
      res = ::Array(T).new
      topmost_parent.get_nodes("**").each do |n|
        if n.in_group?(group)
          if typed = Node.cast_to?(n, type)
            res << typed
          end
        end
      end
      res
    end

    # Returns the first node in the given group, or nil if none found.
    def first_node_in_group?(group : String) : Node?
      first_node_in_group?(group, Node)
    end

    # Returns the first node in the given group cast to type T, or nil if none found.
    def first_node_in_group?(group : String, type : T.class) : T? forall T
      nodes_in_group(group, type).first?
    end

    # Returns the first node in the given group, raising NodeNotFoundError if none found.
    def first_node_in_group(group : String) : Node
      first_node_in_group(group, Node)
    end

    # Returns the first node in the given group cast to type T, raising NodeNotFoundError if none found.
    def first_node_in_group(group : String, type : T.class) : T forall T
      first_node_in_group?(group, type) || raise NodeNotFoundError.new("No node of type #{T.name} found in group '#{group}'.")
    end

    # Returns true if this node belongs to any of the specified groups.
    def in_group?(*groups : String) : Bool
      groups.any? { |g| in_group?(g) }
    end
  end

  module ClassMethods
    # Returns all nodes in the given group as Array(Node).
    def get_nodes_in_group(group : String) : ::Array(Node)
      get_nodes_in_group(group, Node)
    end

    # Returns all nodes in the given group cast to type T.
    def get_nodes_in_group(group : String, type : T.class) : ::Array(T) forall T
      if tree = Godot.get_tree?
        if root = tree.get_root
          return root.nodes_in_group(group, type)
        end
      end
      ::Array(T).new
    end

    # Returns the first node in the given group, or nil if none found.
    def first_node_in_group?(group : String) : Node?
      first_node_in_group?(group, Node)
    end

    # Returns the first node in the given group cast to type T, or nil if none found.
    def first_node_in_group?(group : String, type : T.class) : T? forall T
      get_nodes_in_group(group, type).first?
    end
  end
  extend ClassMethods
end
