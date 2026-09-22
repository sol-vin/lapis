require "./object"
require "./types"

module Godot
  # A high-level Crystal wrapper around Godot's native Dictionary type.
  # Provides seamless indexing, Enumerable iteration, and conversion to/from Crystal Hash.
  class Dictionary
    include Enumerable({String, String})

    @store : ::Hash(String, String)

    def initialize
      @store = ::Hash(String, String).new
    end

    def initialize(initial_hash : ::Hash(String, String))
      @store = initial_hash.dup
    end

    # Creates a Godot::Dictionary from any Crystal Hash
    def self.from(hash : ::Hash(K, V)) : Dictionary forall K, V
      d = new
      hash.each do |k, v|
        d[k.to_s] = v.to_s
      end
      d
    end

    # Retrieves value by key, or produces KeyError if missing
    def [](key : String) : String
      @store[key]
    end

    # Retrieves value by key, or returns nil if missing
    def []?(key : String) : String?
      @store[key]?
    end

    # Sets or updates a key-value pair
    def []=(key : String, value : String) : String
      @store[key] = value
    end

    def has_key?(key : String) : Bool
      @store.has_key?(key)
    end

    def size : Int32
      @store.size
    end

    def empty? : Bool
      @store.empty?
    end

    def keys : ::Array(String)
      @store.keys
    end

    def values : ::Array(String)
      @store.values
    end

    def delete(key : String) : String?
      @store.delete(key)
    end

    def clear : Void
      @store.clear
    end

    def each(&block : Tuple(String, String) -> Void) : Void
      @store.each do |k, v|
        block.call({k, v})
      end
    end

    # Converts back to a standard Crystal Hash
    def to_h : ::Hash(String, String)
      @store.dup
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

    def pop : T?
      @store.pop?
    end

    def shift : T?
      @store.shift?
    end

    def size : Int32
      @store.size
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
