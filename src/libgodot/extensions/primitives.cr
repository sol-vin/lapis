module Godot
  # ===========================================================================
  # TreeItem Extensions
  # ===========================================================================
  class TreeItem
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

class Object
  # Evaluates the given block with self, returning the block's value.
  def try?(&block)
    yield self
  end

  # Returns self.
  def try?
    self
  end
end

struct Nil
  # Returns nil without yielding to the block.
  def try?(&block)
    nil
  end

  # Returns nil.
  def try?
    nil
  end

  # Returns nil.
  def if_alive : Nil
    nil
  end
end

