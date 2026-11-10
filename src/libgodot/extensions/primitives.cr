module Godot
  class Object
    # Overrides auto-generated raw `Pointer(Void)` metadata setter so `value` is stored safely
    # as a 64-bit integer address via `Variant::INT` rather than passing an 8-byte stack `Void*`
    # to `godot_ptrcall_void` expecting a 24-byte `Variant`.
    def set_meta(name : String, value : Pointer(Void)) : Void
      check_alive!
      if !@pointer.null? && Bridge.init_done?
        call("set_meta", name, value.address.to_i64)
      end
    end

    def set_meta(key : Symbol, value : Pointer(Void)) : Void
      set_meta(key.to_s, value)
    end

    # Overrides auto-generated raw `Pointer(Void)` metadata getter to avoid passing an 8-byte
    # stack `Void*` as a 24-byte `Variant` default argument in `godot_ptrcall`.
    def get_meta(name : String, default : Pointer(Void)? = nil) : Pointer(Void)
      fallback = default || Pointer(Void).null
      return fallback if @pointer.null? || !Bridge.init_done?
      check_alive!
      return fallback unless has_meta(name)
      addr = call_i64("get_meta", name)
      return Pointer(Void).new(addr.to_u64) if addr != 0_i64
      ptr = Bridge.object_call_ret_object(@pointer, "get_meta", name)
      !ptr.null? ? ptr : fallback
    end

    def get_meta(key : Symbol, default : Pointer(Void)? = nil) : Pointer(Void)
      get_meta(key.to_s, default)
    end

    # Checks both Crystal-defined methods on the live instance and native Godot methods.
    def has_method(method : String) : Bool
      return true if live_instance._godot_has_crystal_method?(method)
      return false if @pointer.null? || !Bridge.init_done?
      previous_def(method)
    end
  end

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

  # ===========================================================================
  # Time Extensions (Crystal stdlib ::Time compatibility when `include Godot` is active)
  # ===========================================================================
  class Time
    alias Instant = ::Time::Instant
    alias Span = ::Time::Span
    alias Format = ::Time::Format
    alias Location = ::Time::Location

    def self.instant : ::Time::Instant
      ::Time.instant
    end

    def self.monotonic : ::Time::Span
      ::Time.monotonic
    end

    def self.utc : ::Time
      ::Time.utc
    end

    def self.utc(*args, **kwargs) : ::Time
      ::Time.utc(*args, **kwargs)
    end

    def self.local : ::Time
      ::Time.local
    end

    def self.local(*args, **kwargs) : ::Time
      ::Time.local(*args, **kwargs)
    end

    def self.unix(seconds : Int) : ::Time
      ::Time.unix(seconds)
    end

    def self.unix_ms(milliseconds : Int) : ::Time
      ::Time.unix_ms(milliseconds)
    end

    def self.measure(&block) : ::Time::Span
      ::Time.measure { yield }
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
