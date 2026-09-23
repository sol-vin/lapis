require "./object"
require "./types"

module Godot
  # A high-level Crystal wrapper around Godot's native Dictionary type.
  # Provides seamless indexing, Enumerable iteration, and conversion to/from Crystal Hash.
  class Dictionary
    include Enumerable({Variant, Variant})

    @store : ::Hash(Variant, Variant)

    def initialize
      @store = ::Hash(Variant, Variant).new
    end

    def initialize(initial_hash : ::Hash(K, V)) forall K, V
      @store = ::Hash(Variant, Variant).new
      initial_hash.each do |k, v|
        @store[Variant.new(k)] = Variant.new(v)
      end
    end

    # Creates a Godot::Dictionary from any Crystal Hash
    def self.from(hash : ::Hash(K, V)) : Dictionary forall K, V
      d = new
      hash.each do |k, v|
        d[Variant.new(k)] = Variant.new(v)
      end
      d
    end

    # Retrieves value by key, or produces KeyError if missing
    def [](key : Variant) : Variant
      @store[key]
    end

    def [](key : String) : Variant
      @store[Variant.new(key)]
    end

    # Retrieves value by key, or returns nil if missing
    def []?(key : Variant) : Variant?
      @store[key]?
    end

    def []?(key : String) : Variant?
      @store[Variant.new(key)]?
    end

    # Sets or updates a key-value pair
    def []=(key : Variant, value : Variant) : Variant
      @store[key] = value
    end

    def []=(key : String, value : Variant) : Variant
      @store[Variant.new(key)] = value
    end

    def []=(key : String, value : String) : String
      @store[Variant.new(key)] = Variant.new(value)
      value
    end

    def []=(key : Variant, value : String) : String
      @store[key] = Variant.new(value)
      value
    end

    def has(key : Variant) : Bool
      @store.has_key?(key)
    end

    def has(key : String) : Bool
      @store.has_key?(Variant.new(key))
    end

    def has_key?(key : Variant) : Bool
      @store.has_key?(key)
    end

    def has_key?(key : String) : Bool
      @store.has_key?(Variant.new(key))
    end

    def erase(key : Variant) : Void
      @store.delete(key)
    end

    def erase(key : String) : Void
      @store.delete(Variant.new(key))
    end

    def size : Int64
      @store.size.to_i64
    end

    def is_empty : Bool
      @store.empty?
    end

    def empty? : Bool
      @store.empty?
    end

    def keys : ::Array(Variant)
      @store.keys
    end

    def values : ::Array(Variant)
      @store.values
    end

    def delete(key : Variant) : Variant?
      @store.delete(key)
    end

    def delete(key : String) : Variant?
      @store.delete(Variant.new(key))
    end

    def clear : Void
      @store.clear
    end

    def each(&block : Tuple(Variant, Variant) -> Void) : Void
      @store.each do |k, v|
        block.call({k, v})
      end
    end

    # Converts back to a standard Crystal Hash
    def to_h : ::Hash(String, String)
      h = ::Hash(String, String).new
      @store.each do |k, v|
        h[k.to_s] = v.to_s
      end
      h
    end

    def to_s(io : IO) : Void
      io << "Godot::Dictionary{"
      @store.each_with_index do |(k, v), i|
        io << ", " if i > 0
        io << k.inspect << ": " << v.inspect
      end
      io << "}"
    end
  end

  alias GodotDictionary = Dictionary

  # A high-level Crystal wrapper around Godot's native Array type.
  # Named GodotArray to avoid shadowing Crystal's top-level `::Array`.
  # Implements Enumerable and provides seamless conversion to/from Crystal Array.
  class GodotArray(T)
    include Enumerable(T)

    @store : ::Array(T)

    def initialize(ptr : Void* = Pointer(Void).null)
      @store = ::Array(T).new
    end

    def initialize(initial_items : ::Array(T))
      @store = initial_items.dup
    end

    def self.from(items : ::Array(T)) : GodotArray(T)
      new(items)
    end

    def [](index : Int32) : T
      @store[index]
    end

    def [](index : Int64) : T
      @store[index.to_i32]
    end

    def []?(index : Int32) : T?
      @store[index]?
    end

    def []?(index : Int64) : T?
      @store[index.to_i32]?
    end

    def []=(index : Int32, value : T) : T
      @store[index] = value
    end

    def []=(index : Int64, value : T) : T
      @store[index.to_i32] = value
    end

    def <<(value : T) : self
      @store << value
      self
    end

    def push(value : T) : self
      self << value
    end

    def append(value : T) : self
      self << value
    end

    def pop : T?
      @store.pop?
    end

    def shift : T?
      @store.shift?
    end

    def size : Int64
      @store.size.to_i64
    end

    def is_empty : Bool
      @store.empty?
    end

    def empty? : Bool
      @store.empty?
    end

    def clear : Void
      @store.clear
    end

    def each(&block : T -> Void) : Void
      @store.each(&block)
    end

    def to_a : ::Array(T)
      @store.dup
    end

    def to_array : ::Array(T)
      @store.dup
    end

    def to_s(io : IO) : Void
      io << "Godot::GodotArray["
      @store.each_with_index do |item, i|
        io << ", " if i > 0
        io << item.inspect
      end
      io << "]"
    end
  end

  alias GArray = GodotArray

  # ===========================================================================
  # PackedArray Wrappers
  # ===========================================================================

  macro define_packed_array(name, elem_type, default_val)
    class {{name}}
      include Enumerable({{elem_type}})

      @store : ::Array({{elem_type}})

      def initialize
        @store = ::Array({{elem_type}}).new
      end

      def initialize(size : Int, initial_value : {{elem_type}} = {{default_val}})
        @store = ::Array({{elem_type}}).new(size.to_i32, initial_value)
      end

      def initialize(initial_items : ::Array({{elem_type}}))
        @store = initial_items.dup
      end

      def self.from(items : ::Array({{elem_type}})) : {{name}}
        new(items)
      end

      def size : Int64
        @store.size.to_i64
      end

      def is_empty : Bool
        @store.empty?
      end

      def empty? : Bool
        @store.empty?
      end

      def [](index : Int) : {{elem_type}}
        @store[index.to_i32]
      end

      def []?(index : Int) : {{elem_type}}?
        @store[index.to_i32]?
      end

      def []=(index : Int, value : {{elem_type}}) : {{elem_type}}
        @store[index.to_i32] = value
      end

      def append(value : {{elem_type}}) : self
        @store << value
        self
      end

      def push(value : {{elem_type}}) : self
        append(value)
      end

      def <<(value : {{elem_type}}) : self
        append(value)
      end

      def resize(new_size : Int) : Void
        diff = new_size.to_i32 - @store.size
        if diff > 0
          diff.times { @store << {{default_val}} }
        elsif diff < 0
          (-diff).times { @store.pop? }
        end
      end

      def clear : Void
        @store.clear
      end

      def each(&block : {{elem_type}} -> Void) : Void
        @store.each(&block)
      end

      def to_a : ::Array({{elem_type}})
        @store.dup
      end
    end
  end

  define_packed_array(PackedByteArray, UInt8, 0_u8)
  define_packed_array(PackedInt32Array, Int32, 0_i32)
  define_packed_array(PackedInt64Array, Int64, 0_i64)
  define_packed_array(PackedFloat32Array, Float32, 0.0_f32)
  define_packed_array(PackedFloat64Array, Float64, 0.0)
  define_packed_array(PackedStringArray, String, "")
  define_packed_array(PackedVector2Array, Vector2, Vector2.new)
  define_packed_array(PackedVector3Array, Vector3, Vector3.new)
  define_packed_array(PackedColorArray, Color, Color.new)
end

# Crystal Standard Library Extensions for Godot Collections
class Hash(K, V)
  def to_godot_dict : Godot::Dictionary
    Godot::Dictionary.from(self)
  end
end

class Array(T)
  def to_godot_array : Godot::GodotArray(T)
    Godot::GodotArray(T).from(self)
  end
end
