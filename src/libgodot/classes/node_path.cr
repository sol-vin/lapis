module Godot
  # Represents a path to a node or property in the Godot scene tree.
  struct NodePath
    property path : String

    def initialize(@path : String = "")
    end

    def initialize(pointer : Void*)
      @path = ""
    end

    def to_s(io : IO) : Void
      io << @path
    end

    def to_s : String
      @path
    end

    def ==(other : NodePath) : Bool
      @path == other.@path
    end

    def ==(other : String) : Bool
      @path == other
    end

    def empty? : Bool
      @path.empty?
    end

    # Returns the subname count (number of colon-separated property paths after node)
    def get_subname_count : Int64
      parts = @path.split(':')
      parts.size > 1 ? (parts.size - 1).to_i64 : 0_i64
    end

    # Returns the subname at the given index
    def get_subname(idx : Int64) : String
      parts = @path.split(':')
      idx + 1 < parts.size ? parts[idx + 1] : ""
    end
  end
end
