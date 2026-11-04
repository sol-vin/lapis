# =============================================================================
# Lapis GDScript Extras
# =============================================================================
# Modules and DSL extensions providing GDScript parity in Crystal:
# - Unary tilde (~) scene queries and tuple path lookup (~{"$MyNode", MyNodeType})
# - Expression-oriented match pattern matching macro
# - EditorPlugin 3D viewport, camera, selection, and unshaded overlay helpers

require "./gd_extras/node_queries"
require "./gd_extras/match"
require "./gd_extras/editor_extras"
