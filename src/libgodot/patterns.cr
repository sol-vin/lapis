# =============================================================================
# Lapis Gameplay Patterns: Bundled Opt-In Patterns Prelude
# =============================================================================
# OPTIONAL REQUIRE: require "libgodot/patterns" or require "lapis/patterns"
#
# Bundles all optional gameplay architecture patterns:
# - Zero-Allocation Finite State Machine (`fsm`)
# - Type-Safe Signal Bus (`signal_bus`)
# - Zero-Allocation Object Pool (`Lapis::Pool`, `node_pool`)

require "./fsm"
require "./signal_bus"
require "./pool"
