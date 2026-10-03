module Godot
  # A handle for a Godot Resource ID.
  # Wraps the engine's 64-bit internal resource identifier.
  struct RID
    getter id : UInt64

    def initialize(@id : UInt64 = 0_u64)
    end

    def initialize(id : Int)
      @id = id.to_u64
    end

    def is_valid : Bool
      @id != 0_u64
    end

    def valid? : Bool
      @id != 0_u64
    end

    def to_i64 : Int64
      @id.to_i64
    end

    def to_u64 : UInt64
      @id
    end

    def ==(other : RID) : Bool
      @id == other.id
    end

    def to_s(io : IO) : Void
      io << "RID(" << @id << ")"
    end
  end

  alias Rid = RID
end

alias RID = Godot::RID
alias Rid = Godot::RID
