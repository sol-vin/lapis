require "./libgodot/types"
require "./libgodot/variant"
require "./libgodot/system_io"
require "./libgodot/object"
require "./libgodot/doc_macro"
require "./libgodot/macros"
require "./libgodot/binding_macros"
require "./libgodot/bridge"
require "./libgodot/channel"
require "./libgodot/collections"
require "./libgodot/gdextension_interface"
require "./libgodot/c_api"
require "./libgodot/instance"
require "./libgodot/generated/global_enums"
require "./libgodot/generated/classes/all_classes"
require "./libgodot/generated/singletons"
require "./libgodot/extensions"
require "./libgodot/docs"
require "./libgodot/testing"
{% unless flag?(:libgodot_addon) %}
require "./libgodot/script"
require "./libgodot/debugger/lldb_driver"
require "./libgodot/debugger/agent"
require "./libgodot/editor"
{% end %}

module Lapis
  include Godot
end

# # LibGodot for Crystal
#
# High-performance Crystal bindings and 2-way host language integration for Godot Engine 4.8+.
#
# ## Overview
#
# LibGodot enables Crystal to act as the primary host language for Godot games, combining Crystal's
# LLVM-compiled speed and Ruby-like elegance with Godot's powerful scene tree, rendering, and editor tooling.
#
# ### Key Features
# - **Native LibGodot Host (Option C)**: Crystal owns the executable (`game.exe`), initializing its runtime
#   and Boehm GC cleanly before booting Godot in-memory via `libgodot.dll`.
# - **Clean Macro Syntax**:
#   - `node MyNode do ... end` (defaults to inheriting `Godot::Node`)
#   - `node Player < CharacterBody3D do ... end` (inherits specified Godot node type)
#   - `signal health_changed(new_health : Int32)`
#   - `@[Export]` with full Godot Inspector hints (ranges, sliders, enums, bitflags, resource pickers, files, colors, arrays).
# - **Compile Button Hook**: The Godot Editor's Play (F5) and Build buttons invoke `crystal build` via an `EditorPlugin._build()` hook.
#
# ### Basic Example
#
# ```crystal
# require "libgodot"
#
# node Player < CharacterBody3D do
#   @[Export(range: 50.0_f32..800.0_f32, step: 10.0_f32)]
#   property speed : Float32 = 300.0_f32
#
#   @[Export(range: 100.0_f32..1000.0_f32, step: 25.0_f32)]
#   property jump_velocity : Float32 = 450.0_f32
#
#   signal health_changed(new_health : Int32, max_health : Int32)
#   signal died
#
#   def _ready
#     puts "Player ready!"
#   end
#
#   def _physics_process(delta : Float64) : Void
#     vel = velocity
#     unless is_on_floor
#       vel.y -= 980.0_f32 * delta.to_f32
#     end
#     if Input.is_action_just_pressed("jump") && is_on_floor
#       vel.y = @jump_velocity
#     end
#     self.velocity = vel
#     move_and_slide
#   end
# end
# ```
module Godot
  VERSION = "0.1.0"
  TARGET_GODOT_VERSION = {{
    read_file("#{__DIR__}/../godot-version.yml").split("\n").find(&.includes?("version:")).split(":")[1].gsub(/["'\r\n]/, "").strip
  }}
  {% begin %}
    {%
      shard_content = read_file("#{__DIR__}/../shard.yml")
      crystal_line = ""
      lines = shard_content.split("\n")
    %}
    {% for line in lines %}
      {% if line.strip.starts_with?("crystal:") %}
        {% crystal_line = line.strip %}
      {% end %}
    {% end %}
    {%
      min_ver = "1.20.0"
      target_ver = "1.21.0"
      if crystal_line.size > 0
        val = crystal_line.split(":")[1].gsub(/["'\r\n]/, "").strip
        if val.includes?(">=")
          parts = val.split(",")
        else
          parts = [val]
        end
      else
        parts = [] of String
      end
    %}
    {% for p in parts %}
      {%
        trimmed = p.strip
        if trimmed.starts_with?(">=")
          min_ver = trimmed.gsub(/>=/, "").strip
        elsif trimmed.starts_with?("<=")
          target_ver = trimmed.gsub(/<=/, "").strip
        elsif trimmed.size > 0 && !trimmed.includes?(">") && !trimmed.includes?("<")
          min_ver = trimmed
          target_ver = trimmed
        end
      %}
    {% end %}
    MIN_CRYSTAL_VERSION = {{ min_ver }}
    TARGET_CRYSTAL_VERSION = {{ target_ver }}
  {% end %}
end

# Core math and transform value-type aliases
alias Vector2 = Godot::Vector2
alias Vector2i = Godot::Vector2i
alias Vector3 = Godot::Vector3
alias Vector3i = Godot::Vector3i
alias Vector4 = Godot::Vector4
alias Vector4i = Godot::Vector4i
alias Rect2 = Godot::Rect2
alias Rect2i = Godot::Rect2i
alias Color = Godot::Color
alias Basis = Godot::Basis
alias Transform2D = Godot::Transform2D
alias Transform3D = Godot::Transform3D
alias Quaternion = Godot::Quaternion
alias Plane = Godot::Plane
alias AABB = Godot::AABB
alias Bridge = Godot::Bridge





