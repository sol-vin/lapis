# =============================================================================
# LibGodot Core Exception Types
# =============================================================================

module Godot
  # Raised when an operation is attempted on a Godot Object that has been deleted or freed.
  class DisposedObjectError < Exception
    getter instance_id : UInt64

    def initialize(@instance_id : UInt64 = 0_u64, msg : String? = nil)
      message = msg || "Attempted to operate on a deleted or freed Godot Object (instance ID: #{@instance_id})\n💡 Hint: Check '#alive?' or '#if_alive' before accessing transient nodes, or use 'node.queue_free' instead of manual free."
      super(message)
    end
  end

  # Raised when an asynchronous operation or await condition exceeds its configured timeout duration.
  class TimeoutError < Exception
  end

  # Raised when a child or sibling node cannot be located by path or scene unique name.
  class NodeNotFoundError < KeyError
  end
end
