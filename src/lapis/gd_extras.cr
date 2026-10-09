# =============================================================================
# Lapis GDScript Extras
# =============================================================================
# Modules and DSL extensions providing GDScript parity in Crystal:
# - Unary tilde (~) scene queries and tuple path lookup (~{"$MyNode", MyNodeType})
# - Expression-oriented match pattern matching macro

require "./gd_extras/node_queries"
require "./gd_extras/match"
