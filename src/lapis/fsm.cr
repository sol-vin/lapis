# =============================================================================
# Lapis - Optional Finite State Machine DSL (require "lapis/fsm")
# =============================================================================
# Provides a lightweight, zero-allocation, compile-time dispatched Finite State
# Machine macro DSL for gameplay entities.
#
# ```
# require "lapis/fsm"
#
# class Monster < CharacterBody2D
#   fsm :state, initial: :idle do
#     state :idle do
#       enter do
#         play_animation("idle")
#       end
#       update do |delta|
#         if player_detected?
#           transition_to :chase
#         end
#       end
#       exit do
#         stop_animation
#       end
#     end
#
#     state :chase do
#       enter do
#         play_animation("run")
#       end
#       update do |delta|
#         move_toward_target(delta)
#       end
#     end
#   end
#
#   def _physics_process(delta : Float64) : Void
#     update_state(delta)
#   end
# end
# ```

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

macro fsm(name = :state, initial = :idle, &block)
  @{{name.id}} : Symbol = {{initial}}
  @_fsm_initialized : Bool = false
  @_fsm_transition_listeners : Array(Proc(Symbol, Symbol, Nil)) = [] of Proc(Symbol, Symbol, Nil)

  # Returns the current active state
  def {{name.id}} : Symbol
    @{{name.id}}
  end

  # Returns the current active state (standard getter)
  def current_state : Symbol
    @{{name.id}}
  end

  # Returns true if currently in state `s`
  def in_{{name.id}}?(s : Symbol) : Bool
    @{{name.id}} == s
  end

  # Returns true if currently in state `s` (standard predicate)
  def in_state?(s : Symbol) : Bool
    @{{name.id}} == s
  end

  # Registers a listener called whenever a state transition occurs
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

  # Transitions the state machine to `new_state`, invoking exit and enter callbacks.
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

  # Dispatches update logic for the current state with frame `delta`.
  def update_{{name.id}}(delta : Float64 = 0.0) : Nil
    case @{{name.id}}
    {% for st in states %}
      when {{st.args[0]}}
        _fsm_update_{{st.args[0].id}}(delta)
    {% end %}
    end
  end

  {% if name.id != "state" %}
    # Dispatches update logic for the current state (standard alias)
    def update_state(delta : Float64 = 0.0) : Nil
      update_{{name.id}}(delta)
    end
  {% end %}
end
