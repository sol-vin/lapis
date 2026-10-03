# =============================================================================
# LibGodot Pattern Matching DSL (match)
# =============================================================================

module Lapis
  # Type-safe casting helper for match expressions
  def self.match_cast?(target, type : T.class) : T? forall T
    if target.responds_to?(:active?) && !target.active?
      return nil
    end

    if target.is_a?(T)
      return target
    end

    {% if T < Godot::Node %}
      if target.is_a?(Godot::Node)
        return nil unless target.active?
        return Godot::Node.cast_to?(target, T)
      end
    {% end %}

    {% if T < Godot::Object %}
      if target.is_a?(Godot::Object)
        return nil unless target.active?
        return target.as?(T)
      end
    {% end %}

    if target.is_a?(Godot::Variant)
      {% if T < Godot::Node %}
        if raw = target.raw.as?(Godot::Node)
          return nil unless raw.alive?
          return Godot::Node.cast_to?(raw, T)
        end
      {% elsif T < Godot::Object %}
        if raw = target.raw.as?(Godot::Object)
          return nil unless raw.alive?
          return raw.as?(T)
        end
      {% else %}
        raw = target.raw
        {% if T == Int32 %}
          if raw.is_a?(Int)
            return raw.to_i32
          end
        {% elsif T == Int64 %}
          if raw.is_a?(Int)
            return raw.to_i64
          end
        {% elsif T == Float32 %}
          if raw.is_a?(Float)
            return raw.to_f32
          end
        {% elsif T == Float64 %}
          if raw.is_a?(Float)
            return raw.to_f64
          end
        {% else %}
          if raw.is_a?(T)
            return raw
          end
        {% end %}
      {% end %}
    end

    target.as?(T)
  end

  # Value equality helper supporting symbol/string equivalence
  def self.match_eq?(target, pattern) : Bool
    if pattern.is_a?(Symbol) && target.is_a?(String)
      target == pattern.to_s
    elsif pattern.is_a?(String) && target.is_a?(Symbol)
      target.to_s == pattern
    else
      target == pattern
    end
  end
end

# Expression-oriented pattern matching macro designed for concise, expressive gameplay scripting.
#
# Supports:
# 1. Polymorphic node downcasting: `is Player do |p| ... end` (validates `#alive?` automatically)
# 2. Variant unboxing: `is Vector2 do |v| ... end`
# 3. Guard clauses: `is Player, if: p.health < 20 do |p| ... end`
# 4. Multi-pattern splats: `is :idle, :crouch { ... }`
# 5. Tuple destructuring: `match {state, on_floor?} do is :jump, false { ... } end`
# 6. Array Rest matching: `is [first, .., last] do |f, l| ... end`
# 7. Array Rest with wildcards: `is rest(head, _, _, tail) do |h, t| ... end`
# 8. Partial Dictionary matching: `is dict(type: "chat", body: msg) do |_, text| ... end`
# 9. Wildcard fallback: `is _ { ... }` or `default { ... }`
macro match(target, &block)
  %target = {{ target }}
  %matched = false
  %result = nil

  {% exps = block.body.is_a?(Expressions) ? block.body.expressions : [block.body] %}

  {% for exp in exps %}
    {% if exp.is_a?(Call) && (exp.name == "is" || exp.name == "default") %}
      {% if exp.name == "default" || (exp.args.size == 1 && exp.args[0].is_a?(Underscore)) %}
        if !%matched
          %matched = true
          %result = begin
            {{ exp.block.body if exp.block }}
          end
        end
      {% else %}
        if !%matched
          {% blk = exp.block %}
          {% guard = nil %}
          {% pattern_args = [] of ASTNode %}

          # Check for guard named argument (if: cond)
          {% if exp.named_args %}
            {% for narg in exp.named_args %}
              {% if narg.name == "if" %}
                {% guard = narg.value %}
              {% end %}
            {% end %}
          {% end %}

          {% for a in exp.args %}
            {% pattern_args << a %}
          {% end %}

          # Case 1: Array pattern with '..' [first, .., last]
          {% if pattern_args.size == 1 && pattern_args[0].is_a?(ArrayLiteral) %}
            {% pat = pattern_args[0] %}
            {% has_range = false %}
            {% prefix = [] of ASTNode %}
            {% suffix = [] of ASTNode %}
            {% for el in pat %}
              {% if el.is_a?(RangeLiteral) %}
                {% has_range = true %}
              {% elsif has_range %}
                {% suffix << el %}
              {% else %}
                {% prefix << el %}
              {% end %}
            {% end %}

            if %target.responds_to?(:size) && %target.size >= ({{ prefix.size }} + {{ suffix.size }})
              {% if blk && blk.args.size > 0 %}
                {% arg_idx = 0 %}
                {% for p_el, idx in prefix %}
                  {% if !p_el.is_a?(Underscore) && arg_idx < blk.args.size %}
                    {{ blk.args[arg_idx] }} = %target[{{ idx }}]
                    {% arg_idx = arg_idx + 1 %}
                  {% end %}
                {% end %}
                {% for s_el, idx in suffix %}
                  {% neg_idx = idx - suffix.size %}
                  {% if !s_el.is_a?(Underscore) && arg_idx < blk.args.size %}
                    {{ blk.args[arg_idx] }} = %target[{{ neg_idx }}]
                    {% arg_idx = arg_idx + 1 %}
                  {% end %}
                {% end %}
              {% end %}

              {% if guard %}
                if {{ guard }}
                  %matched = true
                  %result = begin
                    {{ blk.body if blk }}
                  end
                end
              {% else %}
                %matched = true
                %result = begin
                  {{ blk.body if blk }}
                end
              {% end %}
            end

          # Case 2: rest(head, _, _, tail)
          {% elsif pattern_args.size == 1 && pattern_args[0].is_a?(Call) && pattern_args[0].name == "rest" %}
            {% pat = pattern_args[0] %}
            if %target.responds_to?(:size) && %target.size >= {{ pat.args.size }}
              {% if blk && blk.args.size > 0 %}
                {% arg_idx = 0 %}
                {% for r_arg, idx in pat.args %}
                  {% if !r_arg.is_a?(Underscore) && arg_idx < blk.args.size %}
                    {{ blk.args[arg_idx] }} = %target[{{ idx }}]
                    {% arg_idx = arg_idx + 1 %}
                  {% end %}
                {% end %}
              {% end %}

              {% if guard %}
                if {{ guard }}
                  %matched = true
                  %result = begin
                    {{ blk.body if blk }}
                  end
                end
              {% else %}
                %matched = true
                %result = begin
                  {{ blk.body if blk }}
                end
              {% end %}
            end

          # Case 3: dict(type: "chat", body: msg)
          {% elsif pattern_args.size == 1 && pattern_args[0].is_a?(Call) && pattern_args[0].name == "dict" %}
            {% pat = pattern_args[0] %}
            if %target.responds_to?(:[])
              %dict_match = true
              {% if pat.named_args %}
                {% for narg in pat.named_args %}
                  %val_{{ narg.name }} = %target[{{ narg.name.stringify }}]? || %target[{{ narg.name.symbolize }}]?
                  if %val_{{ narg.name }}.nil?
                    %dict_match = false
                  {% if narg.value.is_a?(StringLiteral) || narg.value.is_a?(NumberLiteral) || narg.value.is_a?(SymbolLiteral) || narg.value.is_a?(BoolLiteral) %}
                    elsif %val_{{ narg.name }} != {{ narg.value }}
                      %dict_match = false
                  {% end %}
                  end
                {% end %}

                if %dict_match
                  {% if blk && blk.args.size > 0 %}
                    {% for narg, idx in pat.named_args %}
                      {% if idx < blk.args.size %}
                        {{ blk.args[idx] }} = %val_{{ narg.name }}.not_nil!
                      {% end %}
                    {% end %}
                  {% end %}

                  {% if guard %}
                    if {{ guard }}
                      %matched = true
                      %result = begin
                        {{ blk.body if blk }}
                      end
                    end
                  {% else %}
                    %matched = true
                    %result = begin
                      {{ blk.body if blk }}
                    end
                  {% end %}
                end
              {% end %}
            end

          # Case 4: Single Pattern with Block Argument (Type Downcasting: is Player do |p|)
          {% elsif pattern_args.size == 1 && blk && blk.args.size == 1 %}
            {% var_name = blk.args[0] %}
            if ({{ var_name }} = ::Lapis.match_cast?(%target, {{ pattern_args[0] }}))
              {% if guard %}
                if {{ guard }}
                  %matched = true
                  %result = begin
                    {{ blk.body }}
                  end
                end
              {% else %}
                %matched = true
                %result = begin
                  {{ blk.body }}
                end
              {% end %}
            end

          # Case 5: Value / Symbol / Multi-pattern equality (is :idle, :crouch) or Tuple
          {% else %}
            %cond = false
            {% if pattern_args.size > 1 %}
              if %target.is_a?(Tuple) && %target.size == {{ pattern_args.size }}
                %tuple_match = true
                {% for el, idx in pattern_args %}
                  {% if !el.is_a?(Underscore) %}
                    unless ::Lapis.match_eq?(%target[{{ idx }}], {{ el }})
                      %tuple_match = false
                    end
                  {% end %}
                {% end %}
                %cond = %tuple_match
              else
                if false
                {% for p in pattern_args %}
                  elsif ::Lapis.match_eq?(%target, {{ p }})
                    %cond = true
                {% end %}
                end
              end
            {% else %}
              # Single pattern without block arg: could be a Type check or equality
              {% if pattern_args[0].is_a?(Path) %}
                %cast_check = ::Lapis.match_cast?(%target, {{ pattern_args[0] }})
                if %cast_check
                  %cond = true
                else
                  %cond = ::Lapis.match_eq?(%target, {{ pattern_args[0] }})
                end
              {% else %}
                %cond = ::Lapis.match_eq?(%target, {{ pattern_args[0] }})
              {% end %}
            {% end %}

            if %cond
              {% if guard %}
                if {{ guard }}
                  %matched = true
                  %result = begin
                    {{ blk.body if blk }}
                  end
                end
              {% else %}
                %matched = true
                %result = begin
                  {{ blk.body if blk }}
                end
              {% end %}
            end
          {% end %}
        end
      {% end %}
    {% end %}
  {% end %}

  %result
end
