@tool
extends CrystalIntegrationPlugin

var _main_panel: Control = null

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Crystal"

func _get_plugin_icon():
	if ResourceLoader.exists("res://addons/crystal_integration/crystal_icon.svg"):
		return load("res://addons/crystal_integration/crystal_icon.svg")
	var theme = EditorInterface.get_editor_theme()
	if theme and theme.has_icon("Crystal", "EditorIcons"):
		return theme.get_icon("Crystal", "EditorIcons")
	return null

func _make_visible(visible: bool) -> void:
	if not _main_panel or not is_instance_valid(_main_panel):
		var main_screen = EditorInterface.get_editor_main_screen()
		if main_screen:
			_main_panel = main_screen.find_child("CrystalPanel", false, false)
	if _main_panel and is_instance_valid(_main_panel):
		_main_panel.visible = visible

func _build() -> bool:
	var base_ctrl = EditorInterface.get_base_control()
	if base_ctrl:
		var btn = base_ctrl.find_child("BuildCrystalToolbarButton", true, false)
		if btn:
			btn.emit_signal("pressed")
	return true
