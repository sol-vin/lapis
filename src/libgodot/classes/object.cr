module Godot
  # Base class for all Godot engine objects and extension classes.
  # Provides identity, lifecycle dispatch hooks, and signal emission functionality.
  class Object
    property pointer : Void* = Pointer(Void).null
    getter instance_id : UInt64 = 0_u64
    getter? destroyed : Bool = false

    def initialize(@pointer : Void* = Pointer(Void).null)
      if !@pointer.null?
        @instance_id = Bridge.object_get_instance_id(@pointer)
        ::Godot::LeakTracker.register(@instance_id, self.class.name, __FILE__, __LINE__)
      end
    end

    def pointer=(val : Void*)
      @pointer = val
      if !@pointer.null?
        @instance_id = Bridge.object_get_instance_id(@pointer)
        ::Godot::LeakTracker.register(@instance_id, self.class.name, __FILE__, __LINE__)
      else
        @instance_id = 0_u64
      end
    end

    # Configures this existing object in-place using with-yield semantics
    def configure(& : self ->) : self
      with self yield self
      self
    end

    # Instantiates a new native Godot object and configures it in a block
    def self.new(&block : self ->) : self
      inst = ::Godot.create(self)
      with inst yield inst
      inst
    end

    # Class-level constructor returning a new native Godot instance
    def self.create : self
      ::Godot.create(self)
    end

    # Class-level constructor configuring a new native Godot instance in a block
    def self.create(&block : self ->) : self
      inst = ::Godot.create(self)
      with inst yield inst
      inst
    end

    macro inherited
      {% if @type.annotation(::GodotClass) %}
        {% unless @type.class.methods.map(&.name.stringify).includes?("godot_class_name") %}
          def self.godot_class_name : String
            {{ @type.name.stringify.split("::").last }}
          end

          def self.godot_parent_class_name : String
            {{ @type.superclass ? @type.superclass.name.stringify.split("::").last : "Object" }}
          end

          def self._godot_has_virtual_method(method_name : String) : Bool
            norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
            \{% for m in @type.methods %}
              \{% if m.name.stringify.starts_with?("_") %}
                return true if norm == \{{ m.name.stringify }}
              \{% end %}
            \{% end %}
            super
          end

          def _godot_call_virtual(method_name : String, delta : Float64) : Void
            case method_name
            when "_enter_tree"
              _enter_tree if responds_to?(:_enter_tree)
            when "_exit_tree"
              _exit_tree if responds_to?(:_exit_tree)
            when "_ready"
              _ready if responds_to?(:_ready)
            when "_process"
              ::Godot::ThreadSafety.flush_main_thread_queue!
              _process(delta) if responds_to?(:_process)
            when "_physics_process"
              ::Godot::ThreadSafety.flush_main_thread_queue!
              _physics_process(delta) if responds_to?(:_physics_process)
            else
              super
            end
          end

          def _godot_set_property(prop_name : String, val_ptr : Void*) : Void
            \{% for ivar in @type.instance_vars %}
              \{% if ivar.annotation(::Export) %}
                if prop_name == \{{ ivar.name.stringify }}
                  \{% ivar_type = ivar.type.stringify.gsub(/^(::)?Godot::/, "") %}
                  \{% if ivar_type == "Float32" %}
                    self.\{{ ivar.name.id }} = val_ptr.as(Float64*).value.to_f32
                  \{% elsif ivar_type == "Float64" %}
                    self.\{{ ivar.name.id }} = val_ptr.as(Float64*).value
                  \{% elsif ivar_type == "Int32" %}
                    self.\{{ ivar.name.id }} = val_ptr.as(Int64*).value.to_i32
                  \{% elsif ivar_type == "Int64" %}
                    self.\{{ ivar.name.id }} = val_ptr.as(Int64*).value
                  \{% elsif ivar_type == "Bool" %}
                    self.\{{ ivar.name.id }} = val_ptr.as(UInt8*).value != 0_u8
                  \{% elsif ivar_type == "String" %}
                    c_str = val_ptr.as(Pointer(UInt8)*).value
                    self.\{{ ivar.name.id }} = c_str.null? ? "" : String.new(c_str)
                  \{% elsif ivar_type == "Vector2" %}
                    self.\{{ ivar.name.id }} = val_ptr.as(::Godot::Vector2*).value
                  \{% elsif ivar_type == "Vector3" %}
                    self.\{{ ivar.name.id }} = val_ptr.as(::Godot::Vector3*).value
                  \{% elsif ivar_type == "Color" %}
                    self.\{{ ivar.name.id }} = val_ptr.as(::Godot::Color*).value
                  \{% end %}
                  return
                end
              \{% end %}
            \{% end %}
            super
          end

          def _godot_get_property(prop_name : String, ret_ptr : Void*) : Void
            \{% for ivar in @type.instance_vars %}
              \{% if ivar.annotation(::Export) %}
                if prop_name == \{{ ivar.name.stringify }}
                  \{% ivar_type = ivar.type.stringify.gsub(/^(::)?Godot::/, "") %}
                  \{% if ivar_type == "Float32" || ivar_type == "Float64" %}
                    ret_ptr.as(Float64*).value = self.\{{ ivar.name.id }}.to_f64
                  \{% elsif ivar_type == "Int32" || ivar_type == "Int64" %}
                    ret_ptr.as(Int64*).value = self.\{{ ivar.name.id }}.to_i64
                  \{% elsif ivar_type == "Bool" %}
                    ret_ptr.as(UInt8*).value = self.\{{ ivar.name.id }} ? 1_u8 : 0_u8
                  \{% elsif ivar_type == "String" %}
                    ret_ptr.as(Pointer(UInt8)*).value = self.\{{ ivar.name.id }}.to_unsafe
                  \{% elsif ivar_type == "Vector2" %}
                    ret_ptr.as(::Godot::Vector2*).value = self.\{{ ivar.name.id }}
                  \{% elsif ivar_type == "Vector3" %}
                    ret_ptr.as(::Godot::Vector3*).value = self.\{{ ivar.name.id }}
                  \{% elsif ivar_type == "Color" %}
                    ret_ptr.as(::Godot::Color*).value = self.\{{ ivar.name.id }}
                  \{% end %}
                  return
                end
              \{% end %}
            \{% end %}
            super
          end

          def self._godot_auto_register_class : Void
            props = ::Array(::Godot::PropertyInfo).new
            \{% for ivar in @type.instance_vars %}
              \{% if ivar.annotation(::Export) %}
                \{% ivar_type = ivar.type.stringify.gsub(/^(::)?Godot::/, "") %}
                \{%
                  vtype = 0
                  if ivar_type == "Bool"
                    vtype = 1
                  elsif ivar_type == "Int32" || ivar_type == "Int64"
                    vtype = 2
                  elsif ivar_type == "Float32" || ivar_type == "Float64"
                    vtype = 3
                  elsif ivar_type == "String"
                    vtype = 4
                  elsif ivar_type == "Vector2"
                    vtype = 5
                  elsif ivar_type == "Vector3"
                    vtype = 9
                  elsif ivar_type == "Color"
                    vtype = 20
                  end
                %}
                props << ::Godot::PropertyInfo.new(
                  \{{ ivar.name.stringify }},
                  \{{ ivar_type }},
                  \{{ vtype }},
                  0_u32,
                  "",
                  6_u32
                )
              \{% end %}
            \{% end %}

            is_tool_class = \{{ @type.annotation(::Tool) != nil }}
            base_name = \{{ @type.superclass ? @type.superclass.name.stringify.split("::").last : "Object" }}

            ::Godot::ClassRegistry.register(
              ::Godot::ClassRegistry::Entry.new(
                \{{ @type.name.stringify.split("::").last }},
                base_name,
                ->(godot_ptr : Void*) {
                  inst = \{{@type}}.new
                  inst.pointer = godot_ptr
                  inst.as(::Godot::Object)
                },
                is_tool_class,
                _godot_has_virtual_method("_ready"),
                _godot_has_virtual_method("_process"),
                _godot_has_virtual_method("_physics_process"),
                _godot_has_virtual_method("_enter_tree"),
                _godot_has_virtual_method("_exit_tree"),
                _godot_has_virtual_method("_input"),
                _godot_has_virtual_method("_unhandled_input"),
                _godot_has_virtual_method("_unhandled_key_input"),
                _godot_has_virtual_method("_shortcut_input"),
                _godot_has_virtual_method("_gui_input"),
                props,
                ::Array(::Godot::SignalInfo).new,
                "",
                false,
                ([] of NamedTuple(name: String, rpc_mode: Int32, transfer_mode: Int32, call_local: Bool, channel: Int32)),
                has_virtual_proc: ->(m : String) { _godot_has_virtual_method(m) }
              )
            )
          end
        {% end %}
      {% end %}
    end

    # Idiomatic Crystal pointer conversion
    def to_unsafe : Void*
      @pointer
    end

    # Identifier used for signal routing and lifecycle tracking (engine instance ID or Crystal object_id)
    def signal_target_id : UInt64
      @instance_id > 0 ? @instance_id : object_id.to_u64
    end

    # Value equality based on Godot engine identity (instance ID, underlying pointer, or reference identity)
    def ==(other : Godot::Object) : Bool
      if @instance_id > 0 && other.instance_id > 0
        @instance_id == other.instance_id
      elsif !@pointer.null? || !other.pointer.null?
        @pointer == other.pointer
      else
        same?(other)
      end
    end

    def ==(other : Nil) : Bool
      @pointer.null?
    end

    # Hashing based on engine instance ID for use in Sets and Hash keys
    def hash(hasher)
      if @instance_id > 0
        @instance_id.hash(hasher)
      else
        @pointer.address.hash(hasher)
      end
    end

    # Returns true if this object instance has a valid engine pointer and is alive in Godot's ObjectDB
    def alive? : Bool
      return false if @destroyed || @pointer.null? || @instance_id == 0_u64
      Bridge.is_instance_valid(@instance_id)
    end

    # Returns true if the object is active and not destroyed (works in both engine and standalone unit specs)
    def active? : Bool
      if !@pointer.null? && @instance_id > 0
        alive?
      else
        !@destroyed
      end
    end

    def is_valid? : Bool
      alive?
    end

    # Convenient nil-coalescing helper: returns self if alive, otherwise nil
    def if_alive : self?
      alive? ? self : nil
    end

    # Safe nil-coalescing check: returns self if alive in Godot's ObjectDB, otherwise nil.
    def try? : self?
      alive? ? self : nil
    end

    # Evaluates the given block with self if this object is alive and valid in Godot's ObjectDB.
    # Returns nil if this object has been destroyed or freed, preventing dead pointer crashes.
    def try?(&block)
      return nil unless alive?
      yield self
    end

    # Re-wraps or downcasts this Godot object pointer to the requested Godot wrapper class T,
    # verifying that the underlying native object inherits from T. Returns nil if invalid or incompatible.
    def as_a?(type : T.class) : T? forall T
      {% if T <= Godot::Object %}
        return nil unless active?
        if self.is_a?(T)
          return self
        end
        if !@pointer.null?
          if alive = Bridge.find_alive_instance(@pointer)
            if typed = alive.as?(T)
              return typed
            end
          end
          class_name = {{ T.name.stringify.split("::").last }}
          if Bridge.object_is_class(@pointer, class_name)
            res = T.new(@pointer)
            if res.is_a?(RefCounted) && res.get_reference_count == 0
              res.init_ref
            end
            return res
          end
        end
        nil
      {% else %}
        nil
      {% end %}
    end

    # Re-wraps or downcasts this Godot object pointer to the requested Godot wrapper class T,
    # raising TypeCastError if incompatible.
    def as_a(type : T.class) : T forall T
      if casted = as_a?(type)
        casted
      else
        raise TypeCastError.new("Cannot cast Godot object #{self.class.name} to #{T}")
      end
    end

    # Shorthand alias for as_a?(T)
    def cast_to?(type : T.class) : T? forall T
      as_a?(type)
    end

    # Shorthand alias for as_a(T)
    def cast_to(type : T.class) : T forall T
      as_a(type)
    end

    # Shorthand alias matching Variant#as_t(T)
    def as_t(type : T.class) : T forall T
      as_a(type)
    end

    # Shorthand alias for as_t?(T)
    def as_t?(type : T.class) : T? forall T
      as_a?(type)
    end

    # Class-level casting helper
    def self.cast_to?(obj : Object, type : T.class) : T? forall T
      obj.as_a?(type)
    end

    # Class-level casting helper raising TypeCastError
    def self.cast_to(obj : Object, type : T.class) : T forall T
      obj.as_a(type)
    end

    def destroyed? : Bool
      @destroyed || !alive?
    end

    def explicitly_freed? : Bool
      @destroyed
    end

    # Returns true if running inside the Godot Editor
    def editor_hint? : Bool
      Godot.editor_hint?
    end

    # Validates that the underlying engine object is still alive before executing bridge calls.
    # Raises `DisposedObjectError` if the object was destroyed by GDScript, engine, or Crystal.
    def check_alive! : Void
      if @destroyed || (@instance_id > 0 && !Bridge.is_instance_valid(@instance_id))
        @pointer = Pointer(Void).null
        {% if flag?(:trace_dead_pointers) %}
          msg = ::Godot::TombstoneTracker.format_disposed_message(@instance_id)
          raise DisposedObjectError.new(@instance_id, msg)
        {% else %}
          raise DisposedObjectError.new(@instance_id)
        {% end %}
      end
    end

    # Destroys this Object in the Godot engine and invalidates the Crystal pointer.
    def destroy : Void
      return if @destroyed
      @destroyed = true
      ::Godot::TombstoneTracker.record_freed(@instance_id, self.class.name)
      ::Godot::LeakTracker.unregister(@instance_id)
      Godot.clear_signal_subscriptions(signal_target_id)
      if !@pointer.null?
        target_ptr = @pointer
        inst_id = @instance_id
        @pointer = Pointer(Void).null
        Bridge.unregister_alive_instance_by_ptr(target_ptr)
        if self.is_a?(RefCounted)
          # RefCounted instances are managed by Godot's atomic reference counter;
          # calling memdelete directly corrupts engine memory and causes heap corruption.
          return
        end
        if inst_id == 0 || Bridge.is_instance_valid(inst_id)
          Bridge.object_destroy(target_ptr)
        end
      end
    end

    # Destroys this Object in the Godot engine (alias to #destroy).
    def free : Void
      destroy
    end

    # Checks if a 64-bit instance ID is currently valid in Godot's ObjectDB
    def self.is_instance_id_valid(id : Int | UInt64) : Bool
      Bridge.is_instance_valid(id.to_u64)
    end

    @@discovered_script_paths = Hash(String, String).new

    # Discovers a .cr source file corresponding to a custom node/class
    def self.find_script_path_for_class(target_cls : String) : String
      return "" if target_cls.empty?
      if cached = @@discovered_script_paths[target_cls]?
        return cached
      end

      src_dir = if !Godot::ProjectSettings.singleton_ptr.null?
                  ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
                  glob = ps.call_str("globalize_path", "res://src").gsub('\\', '/')
                  Dir.exists?(glob) ? glob : (Dir.exists?("src") ? "src" : "")
                else
                  Dir.exists?("src") ? "src" : ""
                end

      snake = target_cls.underscore
      candidates = [
        "src/#{snake}.cr",
        "src/#{snake.sub(/_node$/, "")}.cr",
        "src/#{snake.sub(/^my_/, "")}.cr",
        "src/#{snake.sub(/^my_/, "").sub(/_node$/, "")}.cr",
        "src/#{snake.gsub("_crystal_", "_")}.cr",
        "src/#{snake.sub(/^my_crystal_/, "my_")}.cr",
      ]
      candidates.each do |c|
        rel_c = c.sub(/^src\//, "")
        fs_path = !src_dir.empty? ? "#{src_dir}/#{rel_c}" : c
        if File.exists?(fs_path) || File.exists?(c)
          path = "res://#{c}"
          @@discovered_script_paths[target_cls] = path
          return path
        end
      end

      # Scan src/**/*.cr for node/class definition matching target_cls
      begin
        search_dir = !src_dir.empty? ? src_dir : "src"
        if Dir.exists?(search_dir)
          Dir.glob("#{search_dir}/**/*.cr") do |file|
            content = File.read(file) rescue ""
            if content =~ /(?:node|class)\s+#{Regex.escape(target_cls)}\b/
              norm = file.gsub('\\', '/')
              res_path = if !src_dir.empty? && norm.starts_with?(src_dir)
                           "res://src" + norm[src_dir.size..-1]
                         else
                           "res://#{norm.sub(/^\.\//, "")}"
                         end
              @@discovered_script_paths[target_cls] = res_path
              return res_path
            end
          end
        end
      rescue
      end

      @@discovered_script_paths[target_cls] = ""
      ""
    end

    # Automatically links this node's registered CrystalScript resource if running inside the Godot Editor
    def link_class_script : Void
      return unless Godot.editor_hint?
      return if @pointer.null?
      return if self.is_a?(Godot::Script) || self.class.name.includes?("Script") || self.class.name.includes?("Plugin")

      # Guard against linking script to nodes that are not inside the active scene tree (prevents 'Cannot get path of node' error)
      is_node = self.call_bool("is_class", "Node") rescue false
      if is_node
        return unless (self.call_bool("is_inside_tree") rescue false)
      end

      curr_script = self.get_script
      return if !curr_script.null?

      c_name = self.class.name.split("::").last
      entry = ClassRegistry.find(c_name)
      if !entry
        godot_cls = self.call_str("get_class") rescue ""
        entry = ClassRegistry.find(godot_cls) unless godot_cls.empty?
      end

      target_cls = if entry
                     entry.class_name
                   else
                     godot_cls = self.call_str("get_class") rescue ""
                     (!godot_cls.empty? && godot_cls != "Node" && godot_cls != "Object") ? godot_cls : c_name
                   end
      return if target_cls.empty? || target_cls.includes?("Script") || target_cls.includes?("Plugin") || target_cls == "Node" || target_cls == "Object"

      path = entry.try(&.script_path) || ""
      parent_name = entry.try(&.parent_name) || ""
      is_tool = entry.try(&.is_tool) || false

      if path.empty? || path == "res://" || path == "res:///"
        path = Godot::Object.find_script_path_for_class(target_cls)
      end
      return if path.empty? || path == "res://" || path == "res:///"

      if parent_name.empty?
        cdb_ptr = Bridge.get_singleton("ClassDB")
        if !cdb_ptr.null?
          cdb = Godot::ClassDB.new(cdb_ptr)
          parent_name = cdb.get_parent_class(target_cls) rescue "Node"
        else
          parent_name = "Node"
        end
      end

      if script = ClassRegistry.get_or_load_script(path, target_cls, parent_name, is_tool)
        self.call("set_script", script)
        self.call("update_configuration_warnings") rescue nil
      end
    rescue ex
      Godot.print("[LibGodot] Notice: could not link script for #{self.class.name}: #{ex.message}")
    end

    # Virtual method and property dispatch hooks overridden by class registration macros.
    # Delta timestep is received with 64-bit precision (`Float64`).
    def _godot_call_virtual(method_name : String, delta : Float64) : Void
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

    # Invoked by the GDExtension bridge when setting an exposed `@export` property.
    def _godot_set_property(prop_name : String, val_ptr : Void*) : Void
    end

    # Invoked by the GDExtension bridge when retrieving an exposed `@export` property.
    def _godot_get_property(prop_name : String, ret_ptr : Void*) : Void
    end

    # Checks if this object class overrides a generic virtual method.
    def self._godot_has_virtual_method(method_name : String) : Bool
      false
    end

    # Dispatches generic virtual methods with raw arguments and return buffer.
    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
    end

    # Dispatches inspector tool button clicks on this object.
    def _godot_call_tool_button(button_name : String) : Void
    end

    # Emits a parameterless signal on this Godot object.
    def emit_signal(name : String) : Void
      check_alive!
      ::Godot::SignalSpy.record(self.class.name, name, 0)
      if !@pointer.null? && Bridge.available?
        Bridge.emit_signal(@pointer, name)
      else
        Godot.notify_signal(signal_target_id, name, [] of Variant)
      end
    end

    # Emits a signal with variable arguments on this Godot object.
    def emit_signal(name : String, *args) : Void
      check_alive!
      ::Godot::SignalSpy.record(self.class.name, name, args.size)
      if !@pointer.null? && Bridge.available?
        Bridge.emit_signal(@pointer, name, *args)
      else
        var_args = args.map { |a| Variant.new(a) }.to_a
        Godot.notify_signal(signal_target_id, name, var_args)
      end
    end

    # Cooperatively awaits a signal emitted on this object.
    def await_signal(signal_name : String, timeout_sec : Float64? = nil) : ::Array(Variant)
      Godot.await(self, signal_name, timeout_sec)
    end

    # Returns a bound signal representation for the named signal.
    # Enables idiomatic usage: `enemy.signal("died").await` or `button.signal(:pressed).connect { ... }`.
    def signal(name : String) : Godot::BoundSignal
      Godot::BoundSignal.new(self, name)
    end

    # Returns a bound signal representation for the named signal symbol.
    def signal(sym : Symbol) : Godot::BoundSignal
      signal(sym.to_s)
    end

    # Calls the named method on the object during idle time.
    def call_deferred(method : String, *args) : Void*
      check_alive!
      Bridge.object_call_deferred(@pointer, method, *args)
      Pointer(Void).null
    end

    # Calls the named method on the object with variable arguments.
    def call(method : String, *args) : Void*
      check_alive!
      Bridge.object_call(@pointer, method, *args)
      Pointer(Void).null
    end

    # Calls the named method on the object with an array of Variants.
    def call(method : String, args : ::Array(Variant)) : Void*
      check_alive!
      case args.size
      when 0
        call(method)
      when 1
        call(method, args[0].raw)
      when 2
        call(method, args[0].raw, args[1].raw)
      when 3
        call(method, args[0].raw, args[1].raw, args[2].raw)
      when 4
        call(method, args[0].raw, args[1].raw, args[2].raw, args[3].raw)
      else
        call(method, args[0].raw, args[1].raw, args[2].raw, args[3].raw, args[4].raw)
      end
    end

    # Dynamically sets a property value on this object.
    def set(property : String | Symbol, value : T) : Void forall T
      check_alive!
      if !@pointer.null?
        call("set", property.to_s, value)
      end
    end

    # Sets arbitrary metadata on this object with automatic Variant conversion.
    #
    # Supports both `String` and `Symbol` keys.
    #
    # ### Example:
    # ```crystal
    # node.set_meta(:enemy_tier, 3)
    # node.set_meta("spawner_id", "wave_01")
    # ```
    def set_meta(key : String | Symbol, value : String | Int32 | Int64 | Float32 | Float64 | Bool | Symbol) : Void
      check_alive!
      if !@pointer.null?
        call("set_meta", key.to_s, value)
      end
    end

    # Retrieves string metadata stored on this object.
    #
    # ### Example:
    # ```crystal
    # id = node.get_meta_str(:spawner_id)
    # ```
    def get_meta_str(key : String | Symbol) : String
      check_alive!
      call_str("get_meta", key.to_s)
    end

    # Retrieves integer metadata stored on this object as an `Int64`.
    #
    # ### Example:
    # ```crystal
    # tier = node.get_meta_i64(:enemy_tier)
    # ```
    def get_meta_i64(key : String | Symbol) : Int64
      check_alive!
      call_i64("get_meta", key.to_s)
    end

    # Retrieves floating-point metadata stored on this object as a `Float64`.
    #
    # ### Example:
    # ```crystal
    # multiplier = node.get_meta_f64(:difficulty_multiplier)
    # ```
    def get_meta_f64(key : String | Symbol) : Float64
      check_alive!
      call_f64("get_meta", key.to_s)
    end

    # Returns `true` if this object has metadata stored under `key`.
    #
    # ### Example:
    # ```crystal
    # if node.has_meta(:quest_target)
    #   highlight_target(node)
    # end
    # ```
    def has_meta(key : String | Symbol) : Bool
      check_alive!
      call_bool("has_meta", key.to_s)
    end

    # Removes the metadata entry under `key` from this object.
    #
    # ### Example:
    # ```crystal
    # node.remove_meta(:temporary_status)
    # ```
    def remove_meta(key : String | Symbol) : Void
      check_alive!
      if !@pointer.null?
        call("remove_meta", key.to_s)
      end
    end

    # Calls the named method and returns an Object/Node (or nil if null)
    def call_obj(method : String, *args) : Node?
      check_alive!
      ptr = Bridge.object_call_ret_object(@pointer, method, *args)
      ptr.null? ? nil : Node.new(ptr)
    end

    # Calls the named method and returns the result cast to T (or nil if null)
    def call_obj_as(type : T.class, method : String, *args) : T? forall T
      check_alive!
      ptr = Bridge.object_call_ret_object(@pointer, method, *args)
      return nil if ptr.null?
      if inst = Bridge.find_alive_instance(ptr)
        if casted = inst.as?(T)
          return casted
        end
      end
      T.new(ptr)
    end

    # Calls the named method and returns the result as Int64
    def call_i64(method : String, *args) : Int64
      check_alive!
      Bridge.object_call_ret_int(@pointer, method, *args)
    end

    # Calls the named method and returns the result as Float64
    def call_f64(method : String, *args) : Float64
      check_alive!
      Bridge.object_call_ret_float(@pointer, method, *args)
    end

    # Calls the named method and returns the result as Bool
    def call_bool(method : String, *args) : Bool
      check_alive!
      Bridge.object_call_ret_bool(@pointer, method, *args)
    end

    # Calls the named method and returns the result as String
    def call_str(method : String, *args) : String
      check_alive!
      Bridge.object_call_ret_string(@pointer, method, *args)
    end

    # Fluent inline configuration block yielding self and returning self
    def build(&block : self -> Void) : self
      with self yield self
      self
    end

    # Fluent configuration block alias
    def configure(&block : self -> Void) : self
      with self yield self
      self
    end

    # Connects a callback proc to the named signal.
    def connect(signal_name : String, flags : ::Godot::ConnectFlags = ::Godot::ConnectFlags::None, callback : Proc(::Array(Variant), Void)? = nil, receiver : Godot::Object? = nil) : SignalSubscription
      check_alive!
      sub = Godot.subscribe_signal(signal_target_id, signal_name, flags, callback, receiver)
      if !@pointer.null? && @instance_id > 0
        Bridge.object_connect_signal(@pointer, signal_name, flags.value)
      end
      sub
    end

    # Connects a callback block accepting Array(Variant) to the named signal.
    def connect(signal_name : String, flags : ::Godot::ConnectFlags = ::Godot::ConnectFlags::None, receiver : Godot::Object? = nil, &block : ::Array(Variant) -> Void) : SignalSubscription
      check_alive!
      sub = Godot.subscribe_signal(signal_target_id, signal_name, flags, block, receiver)
      if !@pointer.null? && @instance_id > 0
        Bridge.object_connect_signal(@pointer, signal_name, flags.value)
      end
      sub
    end

    # Connects a callback block to the named signal symbol.
    def connect(signal_name : Symbol, flags : ::Godot::ConnectFlags = ::Godot::ConnectFlags::None, &block : ::Array(Variant) -> Void) : SignalSubscription
      connect(signal_name.to_s, flags, &block)
    end

    # Connects a one-shot callback block to the named signal (backwards compatibility).
    def connect_one_shot(signal_name : String, &block : ::Array(Variant) -> Void) : SignalSubscription
      connect(signal_name, flags: ::Godot::ConnectFlags::OneShot, &block)
    end

    # Connects the named signal to a method call on a listener target by symbol name.
    def connect(signal_name : String, listener_target : Godot::Object, method_name : Symbol, flags : ::Godot::ConnectFlags = ::Godot::ConnectFlags::None) : SignalSubscription
      signal(signal_name).connect(listener_target, method_name, flags)
    end

    # Disconnects all signal subscriptions for the named signal on this object.
    def disconnect(signal_name : String) : Void
      key = {signal_target_id, signal_name}
      Godot.signal_subs_mutex.synchronize do
        Godot.signal_subs.delete(key)
      end
      if !@pointer.null? && @instance_id > 0
        Bridge.object_disconnect_signal(@pointer, signal_name)
      end
    end

    # Disconnects all subscriptions for the specified signal (Symbol overload)
    def disconnect(signal_name : Symbol) : Void
      disconnect(signal_name.to_s)
    end

    # Disconnects all subscriptions for the specified signal, returning self
    def disconnect_all(signal_name : String | Symbol) : self
      disconnect(signal_name.to_s)
      self
    end

    # Disconnects all subscriptions across ALL signals on this object, returning self
    def disconnect_all : self
      tid = signal_target_id
      keys_to_delete = [] of Tuple(UInt64, String)
      Godot.signal_subs_mutex.synchronize do
        Godot.signal_subs.each_key do |k|
          keys_to_delete << k if k[0] == tid
        end
        keys_to_delete.each do |k|
          Godot.signal_subs.delete(k)
        end
      end
      if !@pointer.null? && @instance_id > 0
        keys_to_delete.each do |k|
          Bridge.object_disconnect_signal(@pointer, k[1])
        end
      end
      self
    end

    # Emits the named signal with arguments, returning self
    def emit(signal_name : String | Symbol, *args) : self
      emit_signal(signal_name.to_s, *args)
      self
    end

    # Emits a bound or typed signal with arguments, returning self
    def emit(signal : BoundSignal, *args) : self
      signal.emit(*args)
      self
    end

    # Returns true if this object or its registered class defines the given signal.
    def has_signal?(signal_name : String) : Bool
      check_alive!
      if !@pointer.null? && @instance_id > 0
        return true if has_signal(signal_name)
      end
      class_name = self.class.name.split("::").last
      if entry = Godot::ClassRegistry.find(class_name)
        return true if entry.signals.any? { |s| s.name == signal_name }
      end
      key = {signal_target_id, signal_name}
      Godot.signal_subs_mutex.synchronize do
        return true if Godot.signal_subs.has_key?(key)
      end
      false
    end

    # Returns the count of active subscriptions for the given signal on this object.
    def signal_connection_count(signal_name : String) : Int32
      key = {signal_target_id, signal_name}
      Godot.signal_subs_mutex.synchronize do
        if list = Godot.signal_subs[key]?
          list.size
        else
          0
        end
      end
    end

    # Prints a message to Godot's debug console.
    def print(*args)
      Godot.print(*args)
    end

    # Prints an error message to Godot's error console.
    def printerr(*args)
      Godot.printerr(*args)
    end

    # Prints a message to Godot's debug console.
    def puts(*args)
      Godot.print(*args)
    end

    def to_s(io : IO) : Void
      io << "<Godot::" << self.class.name << " #" << @instance_id << " @" << @pointer << ">"
    end
  end

  # Base class for reference-counted engine objects.
end
