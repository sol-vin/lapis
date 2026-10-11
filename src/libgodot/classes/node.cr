module Godot
  # Base class for all scene tree nodes in Godot.
  # Provides hierarchy management, node traversal, and lifecycle hooks (`_ready`, `_process`, `_physics_process`).
  class Node < Object
    @name : String = "Node"

    def name : String
      if @pointer.null?
        @name
      else
        godot_name = Bridge.node_get_name(@pointer)
        godot_name.empty? ? @name : godot_name
      end
    end

    # Returns the node name
    def get_name : String
      name
    end

    def name=(val : String)
      @name = val
      if !@pointer.null?
        self.call("set_name", val)
      end
    end

    # Sets the name of the node safely via dynamic reflection
    def set_name(val : String) : Void
      self.name = val
    end

    # Returns the scene owner node responsible for serialization packing.
    def owner : Node?
      if !@pointer.null?
        n = get_owner
        n.pointer.null? ? nil : n
      else
        nil
      end
    end

    # Sets the scene owner node for serialization packing.
    def owner=(o : Node?)
      if !@pointer.null? && o
        set_owner(o)
      end
    end

    # Decomposes a raw path string, stripping leading '$' and extracting
    # unique root prefix if present.
    # Returns {is_unique, root_name, subpath}
    def self.decompose_node_path(raw_path : String) : Tuple(Bool, String, String?)
      p = raw_path.starts_with?('$') ? raw_path[1..] : raw_path
      if p.starts_with?('%')
        remainder = p[1..]
        if slash_idx = remainder.index('/')
          unique_root = remainder[0...slash_idx]
          subpath = remainder[(slash_idx + 1)..]
          {true, unique_root, subpath.empty? ? nil : subpath}
        else
          {true, remainder, nil}
        end
      else
        {false, p, nil}
      end
    end

    # Executes block with this node as the active NodeContext
    def with_context(&)
      ::Godot::NodeContext.scope(self) do
        yield
      end
    end

    # Instance unary ~ returns self, allowing ~self or nested unary chaining
    def ~ : self
      self
    end

    # Class unary ~ returns typed instance looked up from active NodeContext (by name first, then searching children)
    def self.~ : self
      ::Godot::NodeContext.resolve_active_node_as(self)
    end

    # Calls an RPC method on this node across the multiplayer network.
    def rpc(method : String | Symbol, *args) : Godot::Error
      check_alive!
      err_code = call_i64("rpc", method.to_s, *args)
      Godot::Error.new(err_code)
    end

    # Calls an RPC method on a specific peer ID across the multiplayer network.
    def rpc_id(peer_id : Int32 | Int64, method : String | Symbol, *args) : Godot::Error
      check_alive!
      err_code = call_i64("rpc_id", peer_id.to_i64, method.to_s, *args)
      Godot::Error.new(err_code)
    end

    # Returns the SceneTree containing this node.
    def get_tree : SceneTree
      SceneTree.new
    end

    # Retrieves a child or sibling node by NodePath string.
    # Returns the Node if found, or produces an error if the node does not exist.
    def get_node(path : String) : Node
      if found = get_node?(path)
        return found
      end

      child_names = [] of String
      if @pointer.null?
        child_names = children.map(&.name)
      else
        child_count = Bridge.object_call_ret_int(@pointer, "get_child_count") rescue 0_i64
        child_count.times do |i|
          child_ptr = Bridge.object_call_ret_object(@pointer, "get_child", i) rescue nil
          if child_ptr && !child_ptr.null?
            cname = Bridge.node_get_name(child_ptr) rescue ""
            child_names << cname unless cname.empty?
          end
        end
      end
      hint = if child_names.empty?
               "Node '#{self.name}' has no direct children."
             else
               "Direct children: #{child_names.inspect}."
             end
      tip = if path.starts_with?('%')
              "💡 Tip: To search anywhere in the subtree, use find_child('#{path[1..]}')."
            else
              "💡 Tip: To search anywhere in the subtree, use find_child('#{path}') or scene unique name '%#{path}'."
            end
      raise NodeNotFoundError.new("Node not found: '#{path}' (relative to '#{self.name}'). #{hint} #{tip}")
    end

    # Headless / standalone recursive search for a scene unique node by name
    protected def find_unique_node_headless(pattern : String) : Node?
      self.children.each do |c|
        return c if c.name == pattern || c.name.downcase == pattern.downcase
        if found = c.find_unique_node_headless(pattern)
          return found
        end
      end
      nil
    end

    # Retrieves a child or sibling node by NodePath string, or returns nil if not found.
    # Transparently supports leading '$', scene-unique '%' prefixes, '%UniqueRoot/sub/path', and wildcard patterns.
    def get_node?(path : String) : Node?
      if path.includes?('*') || path.includes?('?')
        if self.is_a?(Node)
          return self.as(Node).first_node?(path)
        elsif !@pointer.null? && Bridge.object_is_class(@pointer, "Node")
          node_wrapper = Node.new(@pointer)
          return node_wrapper.first_node?(path)
        else
          return nil
        end
      end

      is_unique, root_name, subpath = Node.decompose_node_path(path)
      if is_unique
        # 1. Resolve unique root node
        unique_node = if @pointer.null?
          find_unique_node_headless(root_name)
        else
          ptr = Bridge.node_get_node(@pointer, "%" + root_name)
          if ptr.null?
            if (found = find_child(root_name, recursive: true, owned: false)) && !found.pointer.null?
              found
            else
              # Case-insensitive direct children check
              child_count = Bridge.object_call_ret_int(@pointer, "get_child_count") rescue 0_i64
              matched_ptr : LibGodot::GDExtensionObjectPtr = Pointer(Void).null
              child_count.times do |i|
                child_ptr = Bridge.object_call_ret_object(@pointer, "get_child", i) rescue nil
                if child_ptr && !child_ptr.null?
                  cname = Bridge.node_get_name(child_ptr) rescue ""
                  if cname.compare(root_name, case_insensitive: true) == 0
                    matched_ptr = child_ptr
                    break
                  end
                end
              end
              if matched_ptr.null?
                nil
              else
                if alive = Bridge.find_alive_instance(matched_ptr)
                  if n = alive.as?(Node)
                    n
                  else
                    Node.new(matched_ptr)
                  end
                else
                  Node.new(matched_ptr)
                end
              end
            end
          else
            if alive = Bridge.find_alive_instance(ptr)
              if n = alive.as?(Node)
                n
              else
                Node.new(ptr)
              end
            else
              Node.new(ptr)
            end
          end
        end

        return nil unless unique_node
        if sub = subpath
          return unique_node.get_node?(sub)
        else
          return unique_node
        end
      end

      clean_path = root_name
      if clean_path.empty? || clean_path == "."
        return self.is_a?(Node) ? self.as(Node) : Node.new(@pointer)
      end

      if @pointer.null?
        return nil unless self.is_a?(Node)
        curr : Node? = self
        parts = clean_path.split('/')
        parts.each do |segment|
          return nil unless curr
          if segment == ".."
            curr = curr.get_parent?
          elsif segment == "." || segment.empty?
            # stay on curr
          else
            curr = curr.as(Node).children.find { |c| c.name == segment || c.name.downcase == segment.downcase }
          end
        end
        return curr
      end

      ptr = Bridge.node_get_node(@pointer, clean_path)
      if ptr.null? && !clean_path.includes?('/')
        # Case-insensitive direct child check (e.g. :node_2d -> "Node2d" matching "Node2D")
        child_count = Bridge.object_call_ret_int(@pointer, "get_child_count") rescue 0_i64
        child_count.times do |i|
          child_ptr = Bridge.object_call_ret_object(@pointer, "get_child", i) rescue nil
          if child_ptr && !child_ptr.null?
            cname = Bridge.node_get_name(child_ptr) rescue ""
            if cname.compare(clean_path, case_insensitive: true) == 0
              ptr = child_ptr
              break
            end
          end
        end
      end
      return nil if ptr.null?
      if alive = Bridge.find_alive_instance(ptr)
        if node = alive.as?(Node)
          return node
        end
      end
      Node.new(ptr)
    end

    # Fetches a node by String path. Similar to `#get_node`, but returns nil if `path` does not point to a valid node.
    def get_node_or_null(path : String) : Node?
      get_node?(path)
    end

    # Overloads for NodePath
    def get_node(path : NodePath) : Node
      get_node(path.to_s)
    end

    def get_node?(path : NodePath) : Node?
      get_node?(path.to_s)
    end

    def get_node_or_null(path : NodePath) : Node?
      get_node?(path.to_s)
    end

    # Retrieves a child node cast to the specified Crystal class type `T`.
    # Returns the node cast to `T`, or produces an error if the node does not exist or cannot be cast.
    def get_node_as(path : String | NodePath, type : T.class) : T forall T
      p = path.to_s
      if p.includes?('*') || p.includes?('?')
        return first_node(p, type)
      end

      node = get_node(p)
      if !@pointer.null? && node.pointer.null?
        raise NodeNotFoundError.new("Node not found: '#{p}' (relative to '#{self.name}').")
      end
      if node.is_a?(T)
        return node
      end
      if !node.pointer.null?
        if alive = Bridge.find_alive_instance(node.pointer)
          if typed = alive.as?(T)
            return typed
          end
        end
        if Bridge.object_is_class(node.pointer, T.name.split("::").last)
          return T.new(node.pointer)
        end
      end
      raise TypeCastError.new("Node '#{node.name}' at path '#{p}' (#{node.class.name}) cannot be cast to #{T.name}")
    end

    # Retrieves a child node cast to the specified Crystal class type `T`, or nil if not found or type mismatch.
    def get_node_as?(path : String | NodePath, type : T.class) : T? forall T
      p = path.to_s
      if p.includes?('*') || p.includes?('?')
        return first_node?(p, type)
      end

      if node = get_node?(p)
        return nil if !@pointer.null? && node.pointer.null?
        if node.is_a?(T)
          return node
        end
        if !node.pointer.null?
          if alive = Bridge.find_alive_instance(node.pointer)
            if typed = alive.as?(T)
              return typed
            end
          end
          {% if T.union? %}
            {% non_nil = T.union_types.reject { |t| t == Nil }.first %}
            if Bridge.object_is_class(node.pointer, {{non_nil}}.name.split("::").last)
              return {{non_nil}}.new(node.pointer)
            end
          {% else %}
            if Bridge.object_is_class(node.pointer, T.name.split("::").last)
              return T.new(node.pointer)
            end
          {% end %}
        end
        nil
      end
    end

    # Shorthand for retrieving a scene unique node cast to type `T`
    def unique_as(name : String | NodePath, type : T.class) : T forall T
      n = name.to_s
      path = n.starts_with?('%') ? n : "%#{n}"
      get_node_as(path, type)
    end

    # Safe shorthand for retrieving a scene unique node cast to type `T`, or nil if not found or type mismatch
    def unique_as?(name : String | NodePath, type : T.class) : T? forall T
      n = name.to_s
      path = n.starts_with?('%') ? n : "%#{n}"
      get_node_as?(path, type)
    end

    # Indexer syntactic sugar for retrieving a child node by path (e.g. self["Camera3D"])
    def [](path : String) : Node
      get_node(path)
    end

    # Safe indexer returning nil if node not found (e.g. self["Camera3D"]?)
    def []?(path : String) : Node?
      get_node?(path)
    end

    # NodePath indexers
    def [](path : NodePath) : Node
      get_node(path.to_s)
    end

    def []?(path : NodePath) : Node?
      get_node?(path.to_s)
    end

    # Type-inferred typed indexer: self[Sprite2D] -> looks up "Sprite2D" cast to Sprite2D
    def [](type : T.class) : T forall T
      get_node_as(T.name.split("::").last, type)
    end

    # Safe type-inferred indexer: self[Sprite2D]? -> returns Sprite2D? or nil if not found
    def []?(type : T.class) : T? forall T
      get_node_as?(T.name.split("::").last, type)
    end

    # Typed path lookup: self["Visuals/Sprite2D", Sprite2D]
    def [](path : String | NodePath, type : T.class) : T forall T
      get_node_as(path, type)
    end

    # Safe typed path lookup: self["Visuals/Sprite2D", Sprite2D]?
    def []?(path : String | NodePath, type : T.class) : T? forall T
      get_node_as?(path, type)
    end

    # Flexible type-first overload: self[Sprite2D, "Visuals/Sprite2D"]
    def [](type : T.class, path : String | NodePath) : T forall T
      get_node_as(path, type)
    end

    # Safe flexible type-first overload: self[Sprite2D, "Visuals/Sprite2D"]?
    def []?(type : T.class, path : String | NodePath) : T? forall T
      get_node_as?(path, type)
    end

    # Multi-node typed glob query returning Array(T)
    def [](path : String | NodePath, type : ::Array(T).class) : ::Array(T) forall T
      p = path.to_s
      get_nodes(p, T)
    end

    # Safe multi-node typed glob query returning nil if the result array would have been empty
    def []?(path : String | NodePath, type : ::Array(T).class) : ::Array(T)? forall T
      p = path.to_s
      nodes = get_nodes(p, T)
      nodes.empty? ? nil : nodes
    end

    # Flexible type-first overloads for Array(T)
    def [](type : ::Array(T).class, path : String | NodePath) : ::Array(T) forall T
      p = path.to_s
      get_nodes(p, T)
    end

    def []?(type : ::Array(T).class, path : String | NodePath) : ::Array(T)? forall T
      p = path.to_s
      nodes = get_nodes(p, T)
      nodes.empty? ? nil : nodes
    end

    # Returns all nodes matching the glob pattern (supports '*' and '**').
    def get_nodes(pattern : String, case_sensitive : Bool = true) : ::Array(Node)
      if self.is_a?(Node)
        self.as(Node).get_nodes(pattern, case_sensitive)
      elsif !@pointer.null? && Bridge.object_is_class(@pointer, "Node")
        Node.new(@pointer).get_nodes(pattern, case_sensitive)
      else
        ::Array(Node).new
      end
    end

    # Returns all nodes matching the glob pattern filtered and cast to Array(T).
    def get_nodes(pattern : String, type : T.class, case_sensitive : Bool = true) : ::Array(T) forall T
      {% begin %}
        {% if T.nilable? || T == Nil %}
          {% raise "Lapis Error: get_nodes cannot take a nillable type (#{T}). Multi-node queries return empty arrays (Array(T)), not arrays of nils." %}
        {% end %}
      {% end %}
      if self.is_a?(Node)
        self.as(Node).get_nodes(pattern, type, case_sensitive)
      elsif !@pointer.null? && Bridge.object_is_class(@pointer, "Node")
        Node.new(@pointer).get_nodes(pattern, type, case_sensitive)
      else
        ::Array(T).new
      end
    end

    # Multi-node wildcard glob query operator: self * "Node/*/Mesh"
    def *(pattern : String) : ::Array(Node)
      get_nodes(pattern)
    end

    # Multi-node typed wildcard glob query operator: self * {"Node/*/Mesh", MeshInstance3D}
    def *(tuple : Tuple(String, T.class)) : ::Array(T) forall T
      {% begin %}
        {% if T.nilable? || T == Nil %}
          {% raise "Lapis Error: Scene query operator '*' cannot take a nillable type (#{T}). Multi-node queries return empty arrays (Array(T)), not arrays of nils." %}
        {% end %}
      {% end %}
      get_nodes(tuple[0], tuple[1])
    end

    # Multi-node regex query operator: self * /^HitBox_\d+$/
    def *(regex : Regex) : ::Array(Node)
      if self.is_a?(Node)
        self.as(Node).find_children(regex)
      elsif !@pointer.null? && Bridge.object_is_class(@pointer, "Node")
        Node.new(@pointer).find_children(regex)
      else
        ::Array(Node).new
      end
    end

    # Multi-node typed regex query operator: self * {/^HitBox_\d+$/, Area3D}
    def *(tuple : Tuple(Regex, T.class)) : ::Array(T) forall T
      {% begin %}
        {% if T.nilable? || T == Nil %}
          {% raise "Lapis Error: Scene query operator '*' cannot take a nillable type (#{T}). Multi-node queries return empty arrays (Array(T)), not arrays of nils." %}
        {% end %}
      {% end %}
      if self.is_a?(Node)
        self.as(Node).find_children(tuple[0], tuple[1])
      elsif !@pointer.null? && Bridge.object_is_class(@pointer, "Node")
        Node.new(@pointer).find_children(tuple[0], tuple[1])
      else
        ::Array(T).new
      end
    end

    # Returns the first node matching the glob pattern, or nil if not found.
    def first_node?(pattern : String, case_sensitive : Bool = true) : Node?
      if self.is_a?(Node)
        self.as(Node).first_node?(pattern, case_sensitive)
      elsif !@pointer.null? && Bridge.object_is_class(@pointer, "Node")
        Node.new(@pointer).first_node?(pattern, case_sensitive)
      else
        nil
      end
    end

    # Returns the first node matching the glob pattern cast to type T, or nil if not found.
    def first_node?(pattern : String, type : T.class, case_sensitive : Bool = true) : T? forall T
      if self.is_a?(Node)
        self.as(Node).first_node?(pattern, type, case_sensitive)
      elsif !@pointer.null? && Bridge.object_is_class(@pointer, "Node")
        Node.new(@pointer).first_node?(pattern, type, case_sensitive)
      else
        nil
      end
    end

    # Returns the first node matching the glob pattern, raising NodeNotFoundError if not found.
    def first_node(pattern : String, case_sensitive : Bool = true) : Node
      if self.is_a?(Node)
        self.as(Node).first_node(pattern, case_sensitive)
      elsif !@pointer.null? && Bridge.object_is_class(@pointer, "Node")
        Node.new(@pointer).first_node(pattern, case_sensitive)
      else
        raise NodeNotFoundError.new("No node found matching pattern '#{pattern}' (relative to '#{self.name}').")
      end
    end

    # Returns the first node matching the glob pattern cast to type T, raising NodeNotFoundError if not found.
    def first_node(pattern : String, type : T.class, case_sensitive : Bool = true) : T forall T
      if self.is_a?(Node)
        self.as(Node).first_node(pattern, type, case_sensitive)
      elsif !@pointer.null? && Bridge.object_is_class(@pointer, "Node")
        Node.new(@pointer).first_node(pattern, type, case_sensitive)
      else
        raise NodeNotFoundError.new("No node of type #{T.name} found matching pattern '#{pattern}' (relative to '#{self.name}').")
      end
    end

    # Shorthand for get_node_as
    def node_as(path : String | NodePath, type : T.class) : T forall T
      get_node_as(path, type)
    end

    # Shorthand for get_node_as?
    def node_as?(path : String | NodePath, type : T.class) : T? forall T
      get_node_as?(path, type)
    end

    # Finds an existing child node matching `pattern`.
    def find_child(pattern : String, recursive : Bool = true, owned : Bool = false) : Node?
      if @pointer.null?
        self.children.each do |c|
          return c if c.name == pattern
          if recursive && (found = c.find_child(pattern, recursive, owned))
            return found
          end
        end
        return nil
      end
      ptr = Bridge.node_find_child(@pointer, pattern, recursive, owned)
      return nil if ptr.null?
      if alive = Bridge.find_alive_instance(ptr)
        if node = alive.as?(Node)
          return node
        end
      end
      Node.new(ptr)
    end

    # Lifecycle callback called when the node enters the tree hierarchy.
    def _enter_tree : Void
    end

    # Lifecycle callback called when the node exits the tree hierarchy.
    def _exit_tree : Void
    end

    # Lifecycle callback called when the node enters the active scene tree.
    def _ready : Void
    end

    # Per-frame process callback receiving delta timestep in seconds (`Float64`).
    def _process(delta : Float64) : Void
    end

    # Fixed-rate physics process callback receiving delta timestep in seconds (`Float64`).
    def _physics_process(delta : Float64) : Void
    end
  end

  # Base class for all 2D canvas items, UI elements, and 2D nodes.
end
