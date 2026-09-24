require "crystalline"
require "../lapis"
require "../libgodot/editor"
require "./crystal_panel"
require "./debugger/debugger_session_tab"
require "./debugger/session_controller"
require "./debugger/crystal_debugger_plugin"
require "./script_create_dialog"

# Entry point for the Crystal Integration GDExtension editor plugin module.
# Compiles into addons/crystal_integration/bin/plugin.dll.
# Classes registered here (CrystalIntegrationPlugin, CrystalPanel, CrystalDebuggerPlugin, CrystalLldbSessionTab)
# are automatically registered into Godot's ClassDB via crystal_godot_init.
