# =============================================================================
# Lapis Gameplay Patterns: Unified Finite State Machine (FSM)
# =============================================================================
# OPTIONAL REQUIRE: require "libgodot/fsm" or require "lapis/fsm"
#
# Provides compile-time checked, zero-allocation finite state machines for Lapis.
# Supports two ergonomic paradigms:
#
# ### Paradigm A: Zero-Allocation Typed Union FSM
# Uses Crystal structs, union types, and pattern matching for high-performance entities.
# ```crystal
# require "libgodot"
# require "libgodot/fsm"
#
# struct Idle; end
# struct Walking
#   getter speed : Float32
#   def initialize(@speed : Float32 = 5.0_f32); end
# end
# struct Jumping; end
#
# alias PlayerState = Idle | Walking | Jumping
#
# node Player < CharacterBody2D do
#   fsm PlayerState, initial: Idle.new do
#     on_enter Walking do |state|
#       Godot.print("Started walking at speed #{state.speed}")
#     end
#
#     on_exit Jumping do
#       Godot.print("Landed on ground!")
#     end
#   end
#
#   def _physics_process(delta : Float64) : Void
#     case s = state
#     when Idle
#       # handle idle
#     when Walking
#       # move with s.speed
#     when Jumping
#       # handle airborne
#     end
#   end
# end
# ```
#
# ### Paradigm B: Symbol-Based Macro FSM
# Lightweight symbol-dispatched state machine with declarative state blocks.
# ```crystal
# require "libgodot"
# require "libgodot/fsm"
#
# class Monster
#   fsm :state, initial: :idle do
#     state :idle do
#       enter { Godot.print("Entering idle") }
#       update { |dt| Godot.print("Idle delta #{dt}") }
#       exit { Godot.print("Exiting idle") }
#     end
#
#     state :chase do
#       enter { Godot.print("Chasing player!") }
#     end
#   end
# end
# ```

# =============================================================================
# Symbol-Based FSM Sub-Macros
# =============================================================================

macro state(state_name, &block)
  def _fsm_enter_{{state_name.id}} : Nil
  end

  def _fsm_exit_{{state_name.id}} : Nil
  end

  def _fsm_update_{{state_name.id}}(delta : Float64) : Nil
  end

  {%
    subs = [] of ASTNode
    if block.body.is_a?(Expressions)
      block.body.expressions.each do |sub|
        subs << sub
      end
    elsif block.body.is_a?(Call)
      subs << block.body
    end
  %}
  {% for exp in subs %}
    {% if exp.name == "enter" %}
      def _fsm_enter_{{state_name.id}} : Nil
        {{exp.block.body}}
      end
    {% elsif exp.name == "update" %}
      def _fsm_update_{{state_name.id}}(delta : Float64) : Nil
        {% if exp.block.args.size > 0 %}
          {{exp.block.args.first}} = delta
        {% end %}
        {{exp.block.body}}
      end
    {% elsif exp.name == "exit" %}
      def _fsm_exit_{{state_name.id}} : Nil
        {{exp.block.body}}
      end
    {% end %}
  {% end %}
end

# =============================================================================
# Typed Union FSM Sub-Macros
# =============================================================================

macro on_enter(state_type, &block)
  if s.is_a?({{state_type}})
    {% if block.args.size > 0 %}
      {{block.args.first}} = s
    {% end %}
    {{block.body}}
  end
end

macro on_exit(state_type, &block)
  if s.is_a?({{state_type}})
    {% if block.args.size > 0 %}
      {{block.args.first}} = s
    {% end %}
    {{block.body}}
  end
end

# =============================================================================
# Unified FSM Macro
# =============================================================================

# Simple FSM declaration without block
macro fsm(first_arg, initial = nil)
  {% if first_arg.is_a?(SymbolLiteral) || (initial && initial.is_a?(SymbolLiteral)) %}
    {% name = first_arg.is_a?(SymbolLiteral) ? first_arg : :state %}
    {% init_sym = initial ? initial : :idle %}
    @{{name.id}} : Symbol = {{init_sym}}
    @_fsm_initialized : Bool = false
    @_fsm_transition_listeners : Array(Proc(Symbol, Symbol, Nil)) = [] of Proc(Symbol, Symbol, Nil)

    def {{name.id}} : Symbol
      @{{name.id}}
    end

    def current_state : Symbol
      @{{name.id}}
    end

    def in_{{name.id}}?(s : Symbol) : Bool
      @{{name.id}} == s
    end

    def in_state?(s : Symbol) : Bool
      @{{name.id}} == s
    end

    def on_state_changed(&callback : Symbol, Symbol -> Nil) : Nil
      @_fsm_transition_listeners << callback
    end

    def transition_to(new_state : Symbol) : Nil
      return if @{{name.id}} == new_state && @_fsm_initialized
      @_fsm_initialized = true
      old_state = @{{name.id}}
      @{{name.id}} = new_state
      @_fsm_transition_listeners.each { |cb| cb.call(old_state, new_state) }
    end

    def update_{{name.id}}(delta : Float64 = 0.0) : Nil
    end

    {% if name.id != "state" %}
      def update_state(delta : Float64 = 0.0) : Nil
        update_{{name.id}}(delta)
      end
    {% end %}
  {% else %}
    property state : {{first_arg}} = {{initial}}
    getter previous_state : {{first_arg}}? = nil

    def transition_to(next_state : {{first_arg}}) : Bool
      @previous_state = @state
      @state = next_state
      true
    end

    def in_state?(type : Class) : Bool
      @state.class == type
    end
  {% end %}
end

# FSM declaration with configuration block
macro fsm(first_arg, initial = nil, &block)
  {% if first_arg.is_a?(SymbolLiteral) || (initial && initial.is_a?(SymbolLiteral)) %}
    {% name = first_arg.is_a?(SymbolLiteral) ? first_arg : :state %}
    {% init_sym = initial ? initial : :idle %}
    @{{name.id}} : Symbol = {{init_sym}}
    @_fsm_initialized : Bool = false
    @_fsm_transition_listeners : Array(Proc(Symbol, Symbol, Nil)) = [] of Proc(Symbol, Symbol, Nil)

    def {{name.id}} : Symbol
      @{{name.id}}
    end

    def current_state : Symbol
      @{{name.id}}
    end

    def in_{{name.id}}?(s : Symbol) : Bool
      @{{name.id}} == s
    end

    def in_state?(s : Symbol) : Bool
      @{{name.id}} == s
    end

    def on_state_changed(&callback : Symbol, Symbol -> Nil) : Nil
      @_fsm_transition_listeners << callback
    end

    {{block.body}}

    {%
      states = [] of ASTNode
      if block.body.is_a?(Expressions)
        block.body.expressions.each do |exp|
          if exp.is_a?(Call) && exp.name == "state"
            states << exp
          end
        end
      elsif block.body.is_a?(Call) && block.body.name == "state"
        states << block.body
      end
    %}

    def transition_to(new_state : Symbol) : Nil
      return if @{{name.id}} == new_state && @_fsm_initialized
      @_fsm_initialized = true
      old_state = @{{name.id}}

      case old_state
      {% for st in states %}
        when {{st.args[0]}}
          _fsm_exit_{{st.args[0].id}}
      {% end %}
      end

      @{{name.id}} = new_state

      case new_state
      {% for st in states %}
        when {{st.args[0]}}
          _fsm_enter_{{st.args[0].id}}
      {% end %}
      end

      @_fsm_transition_listeners.each { |cb| cb.call(old_state, new_state) }
    end

    def update_{{name.id}}(delta : Float64 = 0.0) : Nil
      case @{{name.id}}
      {% for st in states %}
        when {{st.args[0]}}
          _fsm_update_{{st.args[0].id}}(delta)
      {% end %}
      end
    end

    {% if name.id != "state" %}
      def update_state(delta : Float64 = 0.0) : Nil
        update_{{name.id}}(delta)
      end
    {% end %}
  {% else %}
    property state : {{first_arg}} = {{initial}}
    getter previous_state : {{first_arg}}? = nil

    {%
      enter_blocks = [] of ASTNode
      exit_blocks = [] of ASTNode
      class_level_exprs = [] of ASTNode

      exprs = block.body.is_a?(Expressions) ? block.body.expressions : [block.body]
    %}
    {% for exp in exprs %}
      {% if exp.is_a?(Call) && exp.name == "on_enter" %}
        {% enter_blocks << exp %}
      {% elsif exp.is_a?(Call) && exp.name == "on_exit" %}
        {% exit_blocks << exp %}
      {% elsif exp.is_a?(Def) || exp.is_a?(Assign) || exp.is_a?(TypeDeclaration) %}
        {% class_level_exprs << exp %}
      {% else %}
        {% enter_blocks << exp %}
      {% end %}
    {% end %}

    {% for cle in class_level_exprs %}
      {{cle}}
    {% end %}

    def transition_to(next_state : {{first_arg}}) : Bool
      old_state = @state
      _fsm_on_exit(old_state)
      @previous_state = old_state
      @state = next_state
      _fsm_on_enter(next_state)
      true
    end

    def in_state?(type : Class) : Bool
      @state.class == type
    end

    protected def _fsm_on_enter(s : {{first_arg}}) : Void
      {% for exp in enter_blocks %}
        {{exp}}
      {% end %}
    end

    protected def _fsm_on_exit(s : {{first_arg}}) : Void
      {% for exp in exit_blocks %}
        {{exp}}
      {% end %}
    end
  {% end %}
end
