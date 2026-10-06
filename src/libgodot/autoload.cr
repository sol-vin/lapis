# =============================================================================
# LibGodot Autoload & Engine Singleton Manager
# =============================================================================
#
# Provides seamless lifecycle orchestration, Engine singleton registration,
# SceneTree root mounting, and hot-reload teardown for all user-defined
# `@[Autoload]` nodes.
# =============================================================================

require "./types"

module Godot
  # Manages the lifecycle, Engine singleton registration, SceneTree root mounting,
  # and hot-reload teardown for all user-defined @[Autoload] nodes.
  module AutoloadManager
    extend self

    # Metadata record tracking an active autoload node
    class Record
      getter class_name : String
      getter autoload_name : String
      getter singleton : Bool
      getter mount_tree : Bool
      property instance : Godot::Node?
      property mounted : Bool = false
      def mounted? : Bool; @mounted; end
      getter set_autoload_proc : (Godot::Object? -> Void)?

      def initialize(
        @class_name : String,
        @autoload_name : String,
        @singleton : Bool,
        @mount_tree : Bool,
        @instance : Godot::Node? = nil,
        @set_autoload_proc : (Godot::Object? -> Void)? = nil
      )
      end
    end

    @@records = Hash(String, Record).new
    @@mutex = ::Thread::Mutex.new
    @@all_mounted : Bool = false

    # Returns true if all registered autoload nodes requiring SceneTree mounting have been mounted
    def mounted? : Bool
      @@all_mounted
    end

    # Returns true if an autoload record exists for the given name
    def has_autoload?(name : String) : Bool
      @@mutex.synchronize { @@records.has_key?(name) }
    end

    # Returns the autoload Record for the given name, or raises KeyError if not registered
    def [](name : String) : Record
      @@mutex.synchronize { @@records[name] }
    end

    # Returns the autoload Record for the given name, or nil if not registered
    def []?(name : String) : Record?
      @@mutex.synchronize { @@records[name]? }
    end

    # Returns all active autoload records
    def records : Array(Record)
      @@mutex.synchronize { @@records.values }
    end

    # Returns the total count of registered autoload nodes
    def size : Int32
      @@mutex.synchronize { @@records.size }
    end

    # Initializes and instantiates all registered @[Autoload] classes.
    # Registers each node with Godot's Engine singleton registry (if singleton: true)
    # and sets the typed Class.instance accessor.
    def setup_autoloads : Void
      @@mutex.synchronize do
        Godot::ClassRegistry.entries.each do |entry|
          next unless entry.is_autoload
          target_name = entry.autoload_name.empty? ? entry.class_name : entry.autoload_name

          # If an active alive instance already exists, skip reconstruction
          if existing = @@records[target_name]?
            if (n = existing.instance) && n.alive?
              next
            end
          end

          # Construct the Godot object via ClassDB
          ptr = Bridge.construct_object(entry.class_name)
          if ptr.null?
            Godot.printerr("[AutoloadManager] Failed to construct object for autoload class '#{entry.class_name}'")
            next
          end

          alive_node = Bridge.find_alive_instance(ptr).as?(Godot::Node)
          inst = alive_node || Godot::Node.new(ptr)
          inst.name = target_name

          # Bind the typed instance on the Crystal class
          entry.set_autoload_proc.try(&.call(inst))

          # Register with Godot Engine singleton registry
          if entry.autoload_singleton
            begin
              has_old = begin
                Godot.engine.has_singleton(target_name)
              rescue
                false
              end
              if has_old
                begin
                  Godot.engine.unregister_singleton(target_name)
                rescue
                end
              end
              Godot.engine.register_singleton(target_name, inst)
              Godot.log_info("AutoloadManager", "Registered Engine singleton '#{target_name}' (#{entry.class_name})")
            rescue ex
              Godot.printerr("[AutoloadManager] Failed to register Engine singleton '#{target_name}': #{ex.message}")
            end
          end

          rec = Record.new(
            entry.class_name,
            target_name,
            entry.autoload_singleton,
            entry.autoload_mount_tree,
            inst,
            entry.set_autoload_proc
          )
          @@records[target_name] = rec
        end
      end

      # Attempt immediate tree mounting if SceneTree is already available
      begin
        mount_to_tree
      rescue
      end
    end

    # Mounts any pending autoload nodes to the SceneTree root (/root/<name>)
    # if not already mounted.
    def mount_to_tree(target_tree : SceneTree? = nil) : Void
      return if @@all_mounted

      tree = target_tree || Godot.get_tree?
      return unless tree && !tree.pointer.null?

      root = begin
        tree.get_root
      rescue
        nil
      end
      return unless root && !root.pointer.null?

      @@mutex.synchronize do
        @@records.each_value do |rec|
          next unless rec.mount_tree
          node = rec.instance
          next unless node && node.alive?

          if rec.mounted || node.is_inside_tree || (node.get_parent? rescue nil)
            rec.mounted = true
            next
          end

          has_child = begin
            root.has_node(Godot::NodePath.new(rec.autoload_name))
          rescue
            false
          end
          if has_child
            rec.mounted = true
            next
          end

          rec.mounted = true
          # When root is setting up children, add_child fails synchronously; call_deferred ensures safe attachment
          root.add_child(node) rescue nil
          if node.is_inside_tree
            Godot.log_info("AutoloadManager", "Mounted autoload node '#{rec.autoload_name}' to SceneTree root (/root/#{rec.autoload_name})")
          else
            root.call_deferred("add_child", node)
            Godot.log_info("AutoloadManager", "Queued autoload node '#{rec.autoload_name}' mounting to SceneTree root (/root/#{rec.autoload_name})")
          end
        end

        @@all_mounted = @@records.values.all? { |r| !r.mount_tree || r.mounted }
      end
    end

    # Tears down all autoload nodes: unregisters them from Engine,
    # removes them from SceneTree, clears references, and ensures no
    # dead-pointer or DLL unload crashes occur.
    def teardown_autoloads : Void
      @@mutex.synchronize do
        @@records.each_value do |rec|
          if rec.singleton
            begin
              if Godot.engine.has_singleton(rec.autoload_name)
                Godot.engine.unregister_singleton(rec.autoload_name)
                Godot.log_info("AutoloadManager", "Unregistered Engine singleton '#{rec.autoload_name}'")
              end
            rescue
            end
          end

          if node = rec.instance
            if node.alive?
              parent = begin
                node.get_parent?
              rescue
                nil
              end
              if parent && parent.alive?
                begin
                  parent.remove_child(node)
                rescue
                end
              end
            end
          end

          rec.set_autoload_proc.try(&.call(nil))
          rec.mounted = false
          rec.instance = nil
        end
        @@records.clear
        @@all_mounted = false
      end
    end
  end

  # Convenience query for the global SceneTree (or nil if not yet booted)
  def self.get_tree? : SceneTree?
    loop = begin
      Godot.engine.get_main_loop
    rescue
      nil
    end
    if loop && !loop.pointer.null?
      SceneTree.new(loop.pointer)
    else
      nil
    end
  end

  # Returns the global SceneTree, or raises if not yet booted
  def self.get_tree : SceneTree
    get_tree? || raise "SceneTree is not yet available (Godot MainLoop has not initialized)"
  end

  # Retrieves an autoload singleton instance by class type
  def self.autoload(type : T.class) : T forall T
    target_name = type.name.split("::").last
    if rec = AutoloadManager[target_name]?
      if inst = rec.instance
        return inst.as(T)
      end
    end
    raise "No active autoload instance found for type #{T}"
  end

  # Retrieves an autoload singleton instance by name
  def self.autoload(name : String) : Godot::Node?
    AutoloadManager[name]?.try(&.instance)
  end
end
