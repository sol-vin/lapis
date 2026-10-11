# =============================================================================
# Lapis Extras: DSL Pipeline & Hierarchy Operators (>, >>, <<, /)
# =============================================================================
# Expressive syntactic sugar operators for scene instantiation, signal piping,
# node hierarchy mutation, and path traversal.

# -----------------------------------------------------------------------------
# 1. Scene & Resource Pipeline Operators (> and >> on String and PackedScene)
# -----------------------------------------------------------------------------

class String
  # Preload Operator (>): Cached retrieval from PreloadCache.
  # If T is nilable (e.g. BossEnemy?), returns nil on failure instead of raising.
  # If T < Godot::Node, preloads PackedScene, instantiates it, and returns typed Node T.
  # If T < Godot::Resource, preloads and returns cached Resource T.
  def >(type : T.class) : T forall T
    {% if T.union? %}
      {% non_nil = T.union_types.reject { |t| t == Nil }.first %}
      {% if non_nil < Godot::Node %}
        scene = ::Godot::PreloadCache.get_or_load?(self, ::Godot::PackedScene)
        return nil unless scene
        scene.instantiate_as?( {{non_nil}} )
      {% else %}
        ::Godot::PreloadCache.get_or_load?(self, {{non_nil}} )
      {% end %}
    {% elsif T < Godot::Node %}
      scene = ::Godot::PreloadCache.get_or_load(self, ::Godot::PackedScene)
      scene.instantiate_as(T)
    {% else %}
      ::Godot::PreloadCache.get_or_load(self, T)
    {% end %}
  end

  # Preload Operator (>) with configuration block:
  def >(type : T.class, &block : T -> Void) : T forall T
    res = self > type
    if res
      with res yield res
    end
    res
  end

  # Dynamic Load Operator (>>): Dynamic runtime loading without caching.
  # If T is nilable (e.g. BossEnemy?), returns nil on failure instead of raising.
  # If T < Godot::Node, loads PackedScene dynamically, instantiates it, and returns typed Node T.
  # If T < Godot::Resource, dynamically loads and returns Resource T.
  def >>(type : T.class) : T forall T
    {% if T.union? %}
      {% non_nil = T.union_types.reject { |t| t == Nil }.first %}
      {% if non_nil < Godot::Node %}
        scene = ::Godot.load_scene?(self)
        return nil unless scene
        scene.instantiate_as?( {{non_nil}} )
      {% else %}
        ::Godot.load?(self, {{non_nil}} )
      {% end %}
    {% elsif T < Godot::Node %}
      scene = ::Godot.load_scene(self)
      scene.instantiate_as(T)
    {% else %}
      ::Godot.load(self, as: T)
    {% end %}
  end

  # Dynamic Load Operator (>>) with configuration block:
  def >>(type : T.class, &block : T -> Void) : T forall T
    res = self >> type
    if res
      with res yield res
    end
    res
  end
end

module Godot
  class PackedScene < Resource
    # Pipeline operator (>): Instantiates the scene directly typed as T (or T? returning nil on failure)
    def >(type : T.class) : T forall T
      {% if T.union? %}
        {% non_nil = T.union_types.reject { |t| t == Nil }.first %}
        instantiate_as?( {{non_nil}} )
      {% else %}
        instantiate_as(type)
      {% end %}
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Signal Pipeline Operators (> and >> on BoundSignal and TypedSignal)
  # ---------------------------------------------------------------------------

  class BoundSignal
    # Operator `<<` syntactic sugar for `connect` with a block
    def <<(&block : ::Array(Variant) -> Void) : SignalSubscription
      connect(&block)
    end

    # Operator `<<` syntactic sugar for `connect` with a Proc
    def <<(proc : Proc(::Array(Variant), R)) : SignalSubscription forall R
      connect do |args|
        proc.call(args)
      end
    end

    # Operator `<<` syntactic sugar for `connect` with a 0-argument Proc
    def <<(proc : Proc(R)) : SignalSubscription forall R
      connect do
        proc.call
      end
    end

    # Strict pipe (>): Dispatches to target signal passing raw arguments
    def >(target_signal : BoundSignal) : SignalSubscription
      pipe_to(target_signal, strict: true)
    end

    # Loose / adaptive pipe (>>): Dispatches with arity trimming and type downcasting
    def >>(target_signal : BoundSignal) : SignalSubscription
      pipe_to(target_signal, strict: false)
    end

    # Loose pipe (>>) to a strongly-typed TypedSignal(*U) with automatic downcasting & arity adaptation
    def >>(target_signal : TypedSignal(*U)) : SignalSubscription forall U
      target_obj = target_signal.target
      connect(receiver: target_obj) do |args|
        next unless target_obj.active?
        {% begin %}
          {% target_size = U.size %}
          {% if target_size == 0 %}
            target_signal.emit
          {% else %}
            if args.size >= {{ target_size }}
              {% for i in 0...target_size %}
                %matched_{{i}} = false
                %val_{{i}} = nil
                %raw_{{i}} = args[{{i}}].raw
                if %raw_{{i}}.is_a?({{ U[i] }})
                  %val_{{i}} = %raw_{{i}}
                  %matched_{{i}} = true
                {% if U[i] <= Godot::Object %}
                  elsif %obj_{{i}} = %raw_{{i}}.as?(::Godot::Object)
                    if %casted_{{i}} = %obj_{{i}}.as_a?({{ U[i] }})
                      %val_{{i}} = %casted_{{i}}
                      %matched_{{i}} = true
                    end
                {% end %}
                {% if U[i] <= Int32 || U[i] <= Int64 %}
                  elsif %raw_{{i}}.is_a?(Int)
                    %val_{{i}} = {{ U[i] }}.new(%raw_{{i}})
                    %matched_{{i}} = true
                {% elsif U[i] <= Float32 || U[i] <= Float64 %}
                  elsif %raw_{{i}}.is_a?(Number)
                    %val_{{i}} = {{ U[i] }}.new(%raw_{{i}})
                    %matched_{{i}} = true
                {% end %}
                end
              {% end %}

              if {% for i in 0...target_size %}%matched_{{i}} && {% end %} true
                target_signal.emit(
                  {% for i in 0...target_size %}
                    %val_{{i}}.as({{ U[i] }}),
                  {% end %}
                )
              end
            end
          {% end %}
        {% end %}
      end
    end

    # Loose pipe (>>) to a 0-argument Proc (adaptive arity trimming)
    def >>(proc : Proc(R)) : SignalSubscription forall R
      sub = @target.connect(@name) do
        proc.call
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      sub
    end

    # Loose pipe (>>) to a Proc accepting raw Variant array
    def >>(proc : Proc(::Array(Variant), R)) : SignalSubscription forall R
      sub = @target.connect(@name) do |args|
        proc.call(args)
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      sub
    end

    # Loose pipe (>>) to a 1-argument Proc with downcasting support
    def >>(proc : Proc(U0, R)) : SignalSubscription forall U0, R
      sub = @target.connect(@name) do |args|
        if args.size >= 1
          raw = args[0].raw
          if raw.is_a?(Godot::Object)
            if casted = raw.as_a?(U0)
              proc.call(casted)
            end
          elsif raw.is_a?(U0)
            proc.call(raw)
          elsif raw.is_a?(Int) && (num = raw.to_i32.as?(U0) || raw.to_i64.as?(U0))
            proc.call(num)
          elsif raw.is_a?(Float) && (flt = raw.to_f32.as?(U0) || raw.to_f64.as?(U0))
            proc.call(flt)
          end
        end
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      sub
    end

    # Loose pipe (>>) to a 2-argument Proc with downcasting support
    def >>(proc : Proc(U0, U1, R)) : SignalSubscription forall U0, U1, R
      sub = @target.connect(@name) do |args|
        if args.size >= 2
          c0 : U0? = nil
          raw0 = args[0].raw
          if raw0.is_a?(Godot::Object)
            c0 = raw0.as_a?(U0)
          elsif raw0.is_a?(U0)
            c0 = raw0
          elsif raw0.is_a?(Int)
            c0 = raw0.to_i32.as?(U0) || raw0.to_i64.as?(U0)
          elsif raw0.is_a?(Float)
            c0 = raw0.to_f32.as?(U0) || raw0.to_f64.as?(U0)
          end

          c1 : U1? = nil
          raw1 = args[1].raw
          if raw1.is_a?(Godot::Object)
            c1 = raw1.as_a?(U1)
          elsif raw1.is_a?(U1)
            c1 = raw1
          elsif raw1.is_a?(Int)
            c1 = raw1.to_i32.as?(U1) || raw1.to_i64.as?(U1)
          elsif raw1.is_a?(Float)
            c1 = raw1.to_f32.as?(U1) || raw1.to_f64.as?(U1)
          end

          if !c0.nil? && !c1.nil?
            proc.call(c0, c1)
          end
        end
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      sub
    end

    # Loose pipe (>>) to a 3-argument typed Proc with automatic downcasting & arity adaptation
    def >>(proc : Proc(U0, U1, U2, R)) : SignalSubscription forall U0, U1, U2, R
      sub = @target.connect(@name) do |args|
        if args.size >= 3
          c0 : U0? = nil
          raw0 = args[0].raw
          if raw0.is_a?(Godot::Object)
            c0 = raw0.as_a?(U0)
          elsif raw0.is_a?(U0)
            c0 = raw0
          elsif raw0.is_a?(Int)
            c0 = raw0.to_i32.as?(U0) || raw0.to_i64.as?(U0)
          elsif raw0.is_a?(Float)
            c0 = raw0.to_f32.as?(U0) || raw0.to_f64.as?(U0)
          end

          c1 : U1? = nil
          raw1 = args[1].raw
          if raw1.is_a?(Godot::Object)
            c1 = raw1.as_a?(U1)
          elsif raw1.is_a?(U1)
            c1 = raw1
          elsif raw1.is_a?(Int)
            c1 = raw1.to_i32.as?(U1) || raw1.to_i64.as?(U1)
          elsif raw1.is_a?(Float)
            c1 = raw1.to_f32.as?(U1) || raw1.to_f64.as?(U1)
          end

          c2 : U2? = nil
          raw2 = args[2].raw
          if raw2.is_a?(Godot::Object)
            c2 = raw2.as_a?(U2)
          elsif raw2.is_a?(U2)
            c2 = raw2
          elsif raw2.is_a?(Int)
            c2 = raw2.to_i32.as?(U2) || raw2.to_i64.as?(U2)
          elsif raw2.is_a?(Float)
            c2 = raw2.to_f32.as?(U2) || raw2.to_f64.as?(U2)
          end

          if !c0.nil? && !c1.nil? && !c2.nil?
            proc.call(c0, c1, c2)
          end
        end
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      sub
    end

    # Loose pipe (>>) to a 4-argument typed Proc with automatic downcasting & arity adaptation
    def >>(proc : Proc(U0, U1, U2, U3, R)) : SignalSubscription forall U0, U1, U2, U3, R
      sub = @target.connect(@name) do |args|
        if args.size >= 4
          c0 : U0? = nil
          raw0 = args[0].raw
          if raw0.is_a?(Godot::Object)
            c0 = raw0.as_a?(U0)
          elsif raw0.is_a?(U0)
            c0 = raw0
          elsif raw0.is_a?(Int)
            c0 = raw0.to_i32.as?(U0) || raw0.to_i64.as?(U0)
          elsif raw0.is_a?(Float)
            c0 = raw0.to_f32.as?(U0) || raw0.to_f64.as?(U0)
          end

          c1 : U1? = nil
          raw1 = args[1].raw
          if raw1.is_a?(Godot::Object)
            c1 = raw1.as_a?(U1)
          elsif raw1.is_a?(U1)
            c1 = raw1
          elsif raw1.is_a?(Int)
            c1 = raw1.to_i32.as?(U1) || raw1.to_i64.as?(U1)
          elsif raw1.is_a?(Float)
            c1 = raw1.to_f32.as?(U1) || raw1.to_f64.as?(U1)
          end

          c2 : U2? = nil
          raw2 = args[2].raw
          if raw2.is_a?(Godot::Object)
            c2 = raw2.as_a?(U2)
          elsif raw2.is_a?(U2)
            c2 = raw2
          elsif raw2.is_a?(Int)
            c2 = raw2.to_i32.as?(U2) || raw2.to_i64.as?(U2)
          elsif raw2.is_a?(Float)
            c2 = raw2.to_f32.as?(U2) || raw2.to_f64.as?(U2)
          end

          c3 : U3? = nil
          raw3 = args[3].raw
          if raw3.is_a?(Godot::Object)
            c3 = raw3.as_a?(U3)
          elsif raw3.is_a?(U3)
            c3 = raw3
          elsif raw3.is_a?(Int)
            c3 = raw3.to_i32.as?(U3) || raw3.to_i64.as?(U3)
          elsif raw3.is_a?(Float)
            c3 = raw3.to_f32.as?(U3) || raw3.to_f64.as?(U3)
          end

          if !c0.nil? && !c1.nil? && !c2.nil? && !c3.nil?
            proc.call(c0, c1, c2, c3)
          end
        end
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      sub
    end

    # Loose pipe (>>) to a target object and method tuple: `sig >> {target, :on_event}`
    def >>(receiver_method : Tuple(Godot::Object, String | Symbol)) : SignalSubscription
      receiver = receiver_method[0]
      method_name = receiver_method[1].to_s
      @target.connect(@name, receiver: receiver) do |args|
        if receiver.alive?
          receiver.call(method_name, args)
        end
      end
    end
  end

  class TypedSignal(*T) < BoundSignal
    # Operator `<<` syntactic sugar for type-safe connect with a block
    def <<(&block : *T -> Void) : SignalSubscription
      connect(&block)
    end

    # Operator `<<` syntactic sugar for type-safe connect with a Proc
    def <<(proc : Proc(*T, R)) : SignalSubscription forall R
      {% begin %}
        {% if T.size == 0 %}
          connect do
            proc.call
          end
        {% else %}
          connect do |{% for i in 0...T.size %}arg{{i}},{% end %}|
            proc.call({% for i in 0...T.size %}arg{{i}},{% end %})
          end
        {% end %}
      {% end %}
    end

    # Operator `<<` syntactic sugar for 0-argument Proc
    def <<(proc : Proc(R)) : SignalSubscription forall R
      connect do
        proc.call
      end
    end

    # Strict pipe (>): Exact signature match required at compile-time!
    def >(target_signal : TypedSignal(*T)) : SignalSubscription
      target_obj = target_signal.target
      {% begin %}
        {% if T.size == 0 %}
          connect(receiver: target_obj) do
            if target_obj.active?
              target_signal.emit
            end
          end
        {% else %}
          connect(receiver: target_obj) do |{% for i in 0...T.size %}arg{{i}},{% end %}|
            if target_obj.active?
              target_signal.emit({% for i in 0...T.size %}arg{{i}},{% end %})
            end
          end
        {% end %}
      {% end %}
    end

    # Loose / adaptive pipe (>>): Accepts ANY TypedSignal(*U)!
    def >>(target_signal : TypedSignal(*U)) : SignalSubscription forall U
      target_obj = target_signal.target
      {% begin %}
        {% target_size = U.size %}
        {% if T.size < target_size %}
          {% raise "Cannot loosely pipe signal with #{T.size} arguments to signal requiring #{target_size} arguments (#{T} to #{U})" %}
        {% else %}
          {% if T.size == 0 %}
            connect(receiver: target_obj) do
              next unless target_obj.active?
              target_signal.emit
            end
          {% else %}
            connect(receiver: target_obj) do |{% for i in 0...T.size %}arg{{i}},{% end %}|
              next unless target_obj.active?
              {% if target_size == 0 %}
                target_signal.emit
              {% else %}
                {% for i in 0...target_size %}
                  %matched_{{i}} = false
                  %val_{{i}} = nil
                  %raw_{{i}} = arg{{i}}
                  if %raw_{{i}}.is_a?({{ U[i] }})
                    %val_{{i}} = %raw_{{i}}
                    %matched_{{i}} = true
                  {% if U[i] <= Godot::Object %}
                    elsif %obj_{{i}} = %raw_{{i}}.as?(::Godot::Object)
                      if %casted_{{i}} = %obj_{{i}}.as_a?({{ U[i] }})
                        %val_{{i}} = %casted_{{i}}
                        %matched_{{i}} = true
                      end
                  {% end %}
                  {% if U[i] <= Int32 || U[i] <= Int64 %}
                    elsif %raw_{{i}}.is_a?(Int)
                      %val_{{i}} = {{ U[i] }}.new(%raw_{{i}})
                      %matched_{{i}} = true
                  {% elsif U[i] <= Float32 || U[i] <= Float64 %}
                    elsif %raw_{{i}}.is_a?(Number)
                      %val_{{i}} = {{ U[i] }}.new(%raw_{{i}})
                      %matched_{{i}} = true
                  {% end %}
                  end
                {% end %}

                if {% for i in 0...target_size %}%matched_{{i}} && {% end %} true
                  target_signal.emit(
                    {% for i in 0...target_size %}
                      %val_{{i}}.as({{ U[i] }}),
                    {% end %}
                  )
                end
              {% end %}
            end
          {% end %}
        {% end %}
      {% end %}
    end

      # Loose pipe (>>) to a dynamic BoundSignal:
      def >>(target_signal : BoundSignal) : SignalSubscription
        target_obj = target_signal.target
        target_name = target_signal.name
        {% begin %}
          {% if T.size == 0 %}
            connect(receiver: target_obj) do
              if target_obj.active?
                target_obj.emit_signal(target_name)
              end
            end
          {% else %}
            connect(receiver: target_obj) do |{% for i in 0...T.size %}arg{{i}},{% end %}|
              if target_obj.active?
                target_obj.emit_signal(target_name, {% for i in 0...T.size %}arg{{i}},{% end %})
              end
            end
          {% end %}
        {% end %}
      end
  end
  # ---------------------------------------------------------------------------
  # 3. Node Hierarchy & Navigation Operators (<<, /, %)
  # ---------------------------------------------------------------------------

  class Node < Object
    # Appends child to this node, enabling fluent chaining (parent << child1 << child2)
    def <<(child : Godot::Node) : self
      add_child(child)
      self
    end

    # Typed ancestor navigation: hitbox << Player
    def <<(type : T.class) forall T
      {% if T.union? %}
        {% non_nil = T.union_types.reject { |t| t.stringify == "Nil" || t.stringify == "::Nil" }.first %}
        ancestor?({{non_nil}})
      {% else %}
        ancestor(T)
      {% end %}
    end

    # Path traversal operator: node / "Camera3D" or node / node_path!("Camera3D")
    def /(path : String | NodePath) : Node
      get_node(path.to_s)
    end

    # Typed path traversal operator: node / Sprite2D
    def /(type : T.class) : T forall T
      get_node_as(T.name.split("::").last, type)
    end

    # Scene Unique Node operator (mirrors GDScript %): node % "HealthBar"
    def %(unique_name : String | NodePath) : Node
      n = unique_name.to_s
      path = n.starts_with?("%") ? n : "%#{n}"
      get_node(path)
    end

    # Typed Scene Unique Node operator: node % ProgressBar
    def %(type : T.class) : T forall T
      get_node_as("%" + T.name.split("::").last, type)
    end
  end
end
