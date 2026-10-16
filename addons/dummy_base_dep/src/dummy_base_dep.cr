# Expressive loader macro to ensure Lapis engine bindings are loaded
macro ensure_lapis
  {% unless @top_level.has_constant?(:Godot) %}
    require "lapis"
  {% end %}
end

ensure_lapis

# =============================================================================
# Dummy Base Dependency Addon: Reusable Library Interface (Mixins & Utilities)
# =============================================================================
# This file provides shared modules, mixins, and utilities that can be required
# by multiple consumer plugins without duplicating ClassDB class registrations.

# Shared mixin module included into multiple consumer plugin nodes
gmodule DummyBaseMixin do
  @[Export]
  property shared_tag : String = "shared_mixin_tag"

  signal mixin_triggered(tag : String)

  def trigger_mixin : String
    mixin_triggered.emit(@shared_tag)
    "mixin_ok:#{@shared_tag}"
  end
end

# Pure Crystal shared utilities usable across all consumer plugins
module DummyBaseUtils
  def self.format_action(plugin_name : String, action : String) : String
    "#{plugin_name}::#{action.upcase}"
  end

  def self.compute_hash(input : String) : Int32
    input.chars.reduce(0) { |acc, ch| ((acc * 31) + ch.ord) % 10007 }
  end
end
