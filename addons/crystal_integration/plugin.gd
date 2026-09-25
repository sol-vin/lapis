@tool
extends CrystalIntegrationPlugin

var _main_panel: Control = null

func _ready() -> void:
	var script_editor = EditorInterface.get_script_editor()
	if script_editor:
		if not script_editor.editor_script_changed.is_connected(_on_editor_script_changed):
			script_editor.editor_script_changed.connect(_on_editor_script_changed)
		_on_editor_script_changed(script_editor.get_current_script())

func _on_editor_script_changed(script: Script) -> void:
	if not script:
		return
	var path: String = script.resource_path
	if path.ends_with(".cr") or script.get_class() == "CrystalScript":
		_configure_code_editor.call_deferred()

func _configure_code_editor() -> void:
	var script_editor = EditorInterface.get_script_editor()
	if not script_editor:
		return
	var current_editor = script_editor.get_current_editor()
	if current_editor and current_editor.has_method("get_base_editor"):
		var base_editor = current_editor.get_base_editor()
		if base_editor and base_editor is CodeEdit:
			base_editor.code_completion_enabled = true
			var prefixes = base_editor.get_code_completion_prefixes()
			var desired = [".", "::", "@", "<", "_", "$", ":"]
			var changed = false
			for p in desired:
				if not prefixes.has(p):
					prefixes.append(p)
					changed = true
			if changed:
				base_editor.set_code_completion_prefixes(prefixes)

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Crystal"

var _icon_cache: Texture2D = null

func _get_plugin_icon() -> Texture2D:
	if _icon_cache and is_instance_valid(_icon_cache):
		return _icon_cache

	# 1. First preference: check if Theme already has registered Crystal icon (skip in headless mode to prevent null theme dereference)
	if DisplayServer.get_name() != "headless":
		var theme = EditorInterface.get_editor_theme() if EditorInterface else null
		if theme and theme.has_icon("Crystal", "EditorIcons"):
			var icon = theme.get_icon("Crystal", "EditorIcons")
			if icon and is_instance_valid(icon):
				_icon_cache = icon
				return _icon_cache

	# 2. Second preference: create ImageTexture directly from raw SVG on disk (no .ctex dependency)
	var icon_path = "res://addons/crystal_integration/crystal_icon.svg"
	if FileAccess.file_exists(icon_path):
		var img = Image.load_from_file(icon_path)
		if img and not img.is_empty():
			_icon_cache = ImageTexture.create_from_image(img)
			if _icon_cache:
				return _icon_cache

	# 3. Third preference: generate directly from embedded SVG buffer (guarantees zero broken icons)
	var svg_str = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 193.2 206.7" width="16" height="16"><path fill="#e0e0e0" d="m165.4 122-50 49.9c-.2.2-.5.3-.7.2l-68.3-18.3c-.3-.1-.5-.3-.5-.5L27.5 85.1c-.1-.3 0-.5.2-.7l50-49.9c.2-.2.5-.3.7-.2l68.3 18.3c.3.1.5.3.5.5l18.3 68.2c.2.3.1.5-.1.7zm-67-54.3L31.3 85.6c-.1 0-.2.2-.1.3l49.1 49c.1.1.3.1.3-.1l18-67c.1 0-.1-.2-.2-.1z"/></svg>'
	var img_buf = Image.new()
	var err = img_buf.load_svg_from_buffer(svg_str.to_utf8_buffer(), 1.0)
	if err == OK and not img_buf.is_empty():
		_icon_cache = ImageTexture.create_from_image(img_buf)
		if _icon_cache:
			return _icon_cache

	return null

func _make_visible(visible: bool) -> void:
	if not _main_panel or not is_instance_valid(_main_panel):
		var main_screen = EditorInterface.get_editor_main_screen()
		if main_screen:
			_main_panel = main_screen.find_child("CrystalPanel", false, false)
	if not _main_panel or not is_instance_valid(_main_panel):
		var base_ctrl = EditorInterface.get_base_control()
		if base_ctrl:
			_main_panel = base_ctrl.find_child("CrystalPanel", true, false)
	if _main_panel and is_instance_valid(_main_panel):
		_main_panel.visible = visible
