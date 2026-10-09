# =============================================================================
# Lapis Extras: Wildcard Queries & Iteration DSL (*, get_nodes, each_node)
# =============================================================================
# High-ergonomics wildcard glob queries and streaming iteration over scene hierarchies.

module Godot
  class Node < Object
    # Returns all child/descendant nodes matching the glob pattern.
    #
    # ### Example:
    # ```crystal
    # all_coins = get_nodes("Coins/*")
    # ```
    def get_nodes(pattern : String, case_sensitive : Bool = true) : ::Array(Node)
      NodeQuery.find_nodes(self, pattern, case_sensitive)
    end

    # Returns all nodes matching the glob pattern filtered and cast to `Array(T)`.
    # Only nodes inheriting from or matching type `T` are returned.
    #
    # ### Example:
    # ```crystal
    # enemies = get_nodes("Enemies/*", Enemy)
    # enemies.each(&.alert!)
    # ```
    def get_nodes(pattern : String, type : T.class, case_sensitive : Bool = true) : ::Array(T) forall T
      {% begin %}
        {% if T.nilable? || T == Nil %}
          {% raise "Lapis Error: get_nodes cannot take a nillable type (#{T}). Multi-node queries return empty arrays (Array(T)), not arrays of nils." %}
        {% end %}
      {% end %}
      res = ::Array(T).new
      get_nodes(pattern, case_sensitive).each do |n|
        if typed = Node.cast_to?(n, type)
          res << typed
        end
      end
      res
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
      find_children(regex)
    end

    # Multi-node typed regex query operator: self * {/^HitBox_\d+$/, Area3D}
    def *(tuple : Tuple(Regex, T.class)) : ::Array(T) forall T
      {% begin %}
        {% if T.nilable? || T == Nil %}
          {% raise "Lapis Error: Scene query operator '*' cannot take a nillable type (#{T}). Multi-node queries return empty arrays (Array(T)), not arrays of nils." %}
        {% end %}
      {% end %}
      find_children(tuple[0], tuple[1])
    end

    # Streams through all nodes matching `pattern`, scoping each node as both `self` and the block argument.
    #
    # Uses `with node yield node`, allowing three distinct calling styles:
    # 1. Receiver-scoped block (implicit `self` dispatch):
    #    ```crystal
    #    each_node("Enemies/*") do
    #      queue_free
    #    end
    #    ```
    # 2. Block parameter syntax:
    #    ```crystal
    #    each_node("Enemies/*") do |enemy|
    #      enemy.queue_free
    #    end
    #    ```
    # 3. Block-pass shorthand:
    #    ```crystal
    #    each_node("Enemies/*", &.queue_free)
    #    ```
    def each_node(pattern : String, case_sensitive : Bool = true, &) : Void
      get_nodes(pattern, case_sensitive).each do |node|
        with node yield node
      end
    end

    # Streams through all nodes matching `pattern` cast to type `T`, scoping each node as both `self` and the block argument.
    def each_node(pattern : String, type : T.class, case_sensitive : Bool = true, &) : Void forall T
      get_nodes(pattern, type, case_sensitive).each do |node|
        with node yield node
      end
    end
  end
end
