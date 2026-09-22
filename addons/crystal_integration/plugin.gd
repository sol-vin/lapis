@tool
extends CrystalIntegrationPlugin

var _main_panel: Control = null

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Crystal"

var _icon_cache: Texture2D = null

func _get_plugin_icon() -> Texture2D:
	if _icon_cache and is_instance_valid(_icon_cache):
		return _icon_cache

	# 1. First preference: check if Theme already has registered Crystal icon
	var theme = EditorInterface.get_editor_theme()
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

var _highlighter: EditorSyntaxHighlighter = null
var _loader: RefCounted = null
var _saver: RefCounted = null
var _language: Object = null

func _enter_tree() -> void:
	# Ensure first-class Crystal language, resource loader, and saver are active
	if ClassDB.can_instantiate("ResourceFormatLoaderCrystal") and not _loader:
		_loader = ClassDB.instantiate("ResourceFormatLoaderCrystal")
		if _loader and ResourceLoader.has_method("add_resource_format_loader"):
			ResourceLoader.add_resource_format_loader(_loader, true)
	if ClassDB.can_instantiate("ResourceFormatSaverCrystal") and not _saver:
		_saver = ClassDB.instantiate("ResourceFormatSaverCrystal")
		if _saver and ResourceSaver.has_method("add_resource_format_saver"):
			ResourceSaver.add_resource_format_saver(_saver, true)
	if ClassDB.can_instantiate("CrystalLanguage") and not _language:
		_language = ClassDB.instantiate("CrystalLanguage")
		if _language and Engine.has_method("register_script_language"):
			Engine.register_script_language(_language)

	# 1. Register Crystal syntax highlighter with ScriptEditor
	if ClassDB.can_instantiate("CrystalHighlighter"):
		_highlighter = ClassDB.instantiate("CrystalHighlighter")
		if _highlighter:
			var se = EditorInterface.get_script_editor()
			if se:
				se.register_syntax_highlighter(_highlighter)
				if not se.editor_script_changed.is_connected(_apply_highlighter_to_current_script):
					se.editor_script_changed.connect(_apply_highlighter_to_current_script)
				_apply_highlighter_to_all_scripts()
				_apply_highlighter_to_all_scripts.call_deferred()

	# 2. Main screen panel
	var main_screen = EditorInterface.get_editor_main_screen()
	if main_screen:
		var base_ctrl = EditorInterface.get_base_control()
		if not _main_panel or not is_instance_valid(_main_panel):
			if base_ctrl:
				_main_panel = base_ctrl.find_child("CrystalPanel", true, false)
		if not _main_panel or not is_instance_valid(_main_panel):
			if ClassDB.can_instantiate("CrystalPanel"):
				_main_panel = ClassDB.instantiate("CrystalPanel")
			else:
				_main_panel = Control.new()
			_main_panel.name = "CrystalPanel"

		_main_panel.set_v_size_flags(Control.SIZE_EXPAND_FILL)
		_main_panel.set_h_size_flags(Control.SIZE_EXPAND_FILL)

		if _main_panel.get_parent() != null:
			_main_panel.get_parent().remove_child(_main_panel)

		main_screen.add_child(_main_panel)
		_make_visible(false)

func _exit_tree() -> void:
	if _loader and is_instance_valid(_loader):
		if ResourceLoader.has_method("remove_resource_format_loader"):
			ResourceLoader.remove_resource_format_loader(_loader)
		_loader = null
	if _saver and is_instance_valid(_saver):
		if ResourceSaver.has_method("remove_resource_format_saver"):
			ResourceSaver.remove_resource_format_saver(_saver)
		_saver = null
	if _language and is_instance_valid(_language):
		if Engine.has_method("unregister_script_language"):
			Engine.unregister_script_language(_language)
		_language = null

	if _highlighter and is_instance_valid(_highlighter):
		var se = EditorInterface.get_script_editor()
		if se:
			if se.editor_script_changed.is_connected(_apply_highlighter_to_current_script):
				se.editor_script_changed.disconnect(_apply_highlighter_to_current_script)
			se.unregister_syntax_highlighter(_highlighter)
		_highlighter = null

	if _main_panel and is_instance_valid(_main_panel):
		if _main_panel.get_parent() != null:
			_main_panel.get_parent().remove_child(_main_panel)
		_main_panel.queue_free()
		_main_panel = null

func _make_visible(visible: bool) -> void:
	if not _main_panel or not is_instance_valid(_main_panel):
		var base_ctrl = EditorInterface.get_base_control()
		if base_ctrl:
			_main_panel = base_ctrl.find_child("CrystalPanel", true, false)
	if _main_panel and is_instance_valid(_main_panel):
		_main_panel.visible = visible

func _apply_highlighter_to_current_script(_script: Script = null) -> void:
	var se = EditorInterface.get_script_editor()
	if not se or not _highlighter:
		return
	var cur_ed = se.get_current_editor()
	if not cur_ed:
		return
	var script = se.get_current_script()
	if script and (script.resource_path.ends_with(".cr") or script.get_path().ends_with(".cr") or script.get_class() == "CrystalScript"):
		var base_ed = cur_ed.get_base_editor()
		if base_ed and base_ed is CodeEdit:
			if not base_ed.syntax_highlighter or base_ed.syntax_highlighter.get_class() != "CrystalHighlighter":
				var hl = ClassDB.instantiate("CrystalHighlighter") if ClassDB.can_instantiate("CrystalHighlighter") else _highlighter
				base_ed.set_syntax_highlighter(hl)
				base_ed.queue_redraw()

func _apply_highlighter_to_all_scripts() -> void:
	var se = EditorInterface.get_script_editor()
	if not se or not _highlighter:
		return
	for ed in se.get_open_script_editors():
		if not ed:
			continue
		var script = ed.get_current_script()
		if script and (script.resource_path.ends_with(".cr") or script.get_path().ends_with(".cr") or script.get_class() == "CrystalScript"):
			var base_ed = ed.get_base_editor()
			if base_ed and base_ed is CodeEdit:
				if not base_ed.syntax_highlighter or base_ed.syntax_highlighter.get_class() != "CrystalHighlighter":
					var hl = ClassDB.instantiate("CrystalHighlighter") if ClassDB.can_instantiate("CrystalHighlighter") else _highlighter
					base_ed.set_syntax_highlighter(hl)
					base_ed.queue_redraw()
