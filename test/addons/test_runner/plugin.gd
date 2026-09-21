@tool
extends EditorPlugin

# =============================================================================
# LibGodot Test Suite - In-Editor @tool Test Runner Plugin
# =============================================================================
# Dedicated test harness plugin residing strictly in the test consumer project.
# Automatically tickles ToolTester2D and ToolTester3D scenes when invoked with
# GODOT_RUN_TOOL_TESTS=1 or --run-tool-tests.

func _enter_tree():
	var settings = EditorInterface.get_editor_settings()
	if settings:
		settings.set_setting("text_editor/appearance/gutters/highlight_type_safe_lines", false)
		settings.set_setting("text_editor/appearance/guidelines/highlight_type_safe_lines", false)
	if OS.get_environment("GODOT_RUN_TOOL_TESTS") == "1" or OS.get_environment("CRYSTAL_TOOL_TEST") == "1" or "--run-tool-tests" in OS.get_cmdline_args():
		call_deferred("_run_in_editor_tool_tests")

func _run_in_editor_tool_tests():
	print("==================================================================")
	print("[CrystalToolTester] Headless Editor Mode: Tickling @tool Tests...")
	print("==================================================================")
	var errors = 0
	var error_messages = []
	var is_headless = DisplayServer.get_name() == "headless" or OS.get_environment("GODOT_HEADLESS") == "1" or "--headless" in OS.get_cmdline_args()

	var settings = EditorInterface.get_editor_settings()
	if settings:
		settings.set_setting("text_editor/appearance/gutters/highlight_type_safe_lines", false)
		settings.set_setting("text_editor/appearance/guidelines/highlight_type_safe_lines", false)

	for i in range(5):
		await get_tree().process_frame
	if EditorInterface.get_resource_filesystem():
		while EditorInterface.get_resource_filesystem().is_scanning():
			await get_tree().process_frame

	# 1. Tickle ToolTester2D
	print("[CrystalToolTester] Instantiating and executing ToolTester2D...")
	var scene_2d = load("res://scenes/test_tool_2d.tscn")
	if scene_2d:
		var node_2d = scene_2d.instantiate()
		if node_2d:
			var tester_2d = node_2d if node_2d.get_class() == "ToolTester2D" else node_2d.find_child("ToolTester2D", true, false)
			if tester_2d:
				if tester_2d.has_method("run_tool_tests"):
					tester_2d.call("run_tool_tests")
				var status_2d = str(tester_2d.get("test_status"))
				print("[CrystalToolTester] ToolTester2D status: " + status_2d)
				if status_2d.contains("Failed") or status_2d.contains("Error"):
					var msg = "[CrystalToolTester] ToolTester2D failed: " + status_2d
					printerr(msg)
					error_messages.append(msg)
					errors += 1
			else:
				var msg = "[CrystalToolTester] ToolTester2D node not found in test_tool_2d.tscn"
				printerr(msg)
				error_messages.append(msg)
				errors += 1
			node_2d.free()
	else:
		var msg = "[CrystalToolTester] Failed to load res://scenes/test_tool_2d.tscn"
		printerr(msg)
		error_messages.append(msg)
		errors += 1

	# 2. Tickle ToolTester3D
	print("[CrystalToolTester] Instantiating and executing ToolTester3D...")
	var scene_3d = load("res://scenes/test_tool_3d.tscn")
	if scene_3d:
		var node_3d = scene_3d.instantiate()
		if node_3d:
			var tester_3d = node_3d if node_3d.get_class() == "ToolTester3D" else node_3d.find_child("ToolTester3D", true, false)
			if tester_3d:
				if tester_3d.has_method("run_tool_tests"):
					tester_3d.call("run_tool_tests")
				print("[CrystalToolTester] run_tool_tests completed. Getting test_status...")
				var status_3d = str(tester_3d.get("test_status"))
				print("[CrystalToolTester] ToolTester3D status: " + status_3d)
				if status_3d.contains("Failed") or status_3d.contains("Error"):
					var msg = "[CrystalToolTester] ToolTester3D failed: " + status_3d
					printerr(msg)
					error_messages.append(msg)
					errors += 1
			else:
				var msg = "[CrystalToolTester] ToolTester3D node not found in test_tool_3d.tscn"
				printerr(msg)
				error_messages.append(msg)
				errors += 1
			print("[CrystalToolTester] Freeing node_3d...")
			node_3d.free()
			print("[CrystalToolTester] node_3d freed successfully!")
	else:
		var msg = "[CrystalToolTester] Failed to load res://scenes/test_tool_3d.tscn"
		printerr(msg)
		error_messages.append(msg)
		errors += 1

	# 3. Verify Multi-Addon EditorPlugin Classes in ClassDB during in-editor execution
	print("[CrystalToolTester] Verifying multi-addon EditorPlugin classes in ClassDB...")
	var required_editor_classes = [
		"CrystalIntegrationPlugin",
		"DummyDialoguePlugin",
		"DummyInventoryPlugin",
		"DummyAudioPlugin"
	]
	for cls in required_editor_classes:
		if not ClassDB.class_exists(cls):
			var msg = "[CrystalToolTester] Required editor plugin class '%s' missing from ClassDB!" % cls
			printerr(msg)
			error_messages.append(msg)
			errors += 1
		elif not ClassDB.is_parent_class(cls, "EditorPlugin"):
			var msg = "[CrystalToolTester] Class '%s' does not inherit from EditorPlugin!" % cls
			printerr(msg)
			error_messages.append(msg)
			errors += 1
		else:
			print("[CrystalToolTester]   ✔ %s registered as EditorPlugin" % cls)

	# 3b. Verify Crystal Main Screen Editor Tab and Panel
	print("[CrystalToolTester] Verifying Crystal main screen editor plugin configuration...")
	var plugin_script = load("res://addons/crystal_integration/plugin.gd")
	var crystal_plugin = plugin_script.new() if plugin_script else null
	var has_main = false
	var plugin_name = ""
	if crystal_plugin:
		if crystal_plugin.has_method("_has_main_screen"):
			has_main = crystal_plugin._has_main_screen()
		elif crystal_plugin.has_method("has_main_screen"):
			has_main = crystal_plugin.has_main_screen()
		if crystal_plugin.has_method("_get_plugin_name"):
			plugin_name = crystal_plugin._get_plugin_name()
		elif crystal_plugin.has_method("get_plugin_name"):
			plugin_name = crystal_plugin.get_plugin_name()

	if not has_main or plugin_name != "Crystal":
		var msg = "[CrystalToolTester] FAILED: CrystalIntegrationPlugin does not report main screen tab (has_main_screen=%s, name='%s')!" % [str(has_main), plugin_name]
		printerr(msg)
		error_messages.append(msg)
		errors += 1
	else:
		print("[CrystalToolTester]   ✔ CrystalIntegrationPlugin reports main screen tab correctly: name='%s', has_main_screen=true" % plugin_name)

	var icon = crystal_plugin._get_plugin_icon() if crystal_plugin else null
	if not icon or not (icon is Texture2D) or icon.get_size().x <= 0:
		var msg = "[CrystalToolTester] FAILED: CrystalIntegrationPlugin does not return a valid icon Texture2D (got %s)!" % str(icon)
		printerr(msg)
		error_messages.append(msg)
		errors += 1
	else:
		print("[CrystalToolTester]   ✔ CrystalIntegrationPlugin returns valid icon Texture2D: %s (size=%s)" % [icon.get_class(), str(icon.get_size())])


	# In GUI editor mode (non-headless), also verify actual UI controls and docking
	if not is_headless:
		var base_control = EditorInterface.get_base_control()
		var crystal_tab_btn: Button = null
		var crystal_tab_idx: int = -1
		var main_tab_bar: TabBar = null
		if base_control:
			# 1. Check for TabBar tabs (Godot 4.4+)
			var all_tab_bars = base_control.find_children("*", "TabBar", true, false)
			for tb in all_tab_bars:
				for i in range(tb.get_tab_count()):
					if tb.get_tab_title(i) == "Crystal":
						main_tab_bar = tb
						crystal_tab_idx = i
						break
				if main_tab_bar:
					break

			# 2. Check for legacy Button tabs (Godot 4.0-4.3)
			var all_buttons = base_control.find_children("*", "Button", true, false)
			for btn in all_buttons:
				if btn.name != "BuildCrystalToolbarButton" and (btn.text == "Crystal" or btn.name == "Crystal"):
					crystal_tab_btn = btn
					break

		if not crystal_tab_btn and crystal_tab_idx == -1:
			var msg = "[CrystalToolTester] FAILED: 'Crystal' main screen tab not found in Editor interface (checked TabBar and Button)!"
			printerr(msg)
			error_messages.append(msg)
			errors += 1
		elif main_tab_bar and crystal_tab_idx >= 0:
			print("[CrystalToolTester]   ✔ Found 'Crystal' main screen tab in TabBar at index %d: %s" % [crystal_tab_idx, str(main_tab_bar.get_path())])
		elif crystal_tab_btn:
			print("[CrystalToolTester]   ✔ Found 'Crystal' editor tab button: %s" % str(crystal_tab_btn.get_path()))

		var crystal_panel = null
		if base_control:
			crystal_panel = base_control.find_child("CrystalPanel", true, false)
		if not crystal_panel:
			var main_screen = EditorInterface.get_editor_main_screen()
			if main_screen:
				crystal_panel = main_screen.find_child("CrystalPanel", false, false)

		if not crystal_panel:
			var msg = "[CrystalToolTester] FAILED: 'CrystalPanel' Control node not docked in Editor interface!"
			printerr(msg)
			error_messages.append(msg)
			errors += 1
		else:
			print("[CrystalToolTester]   ✔ Verified 'CrystalPanel' docked in editor: %s" % str(crystal_panel.get_path()))

			if main_tab_bar and crystal_tab_idx >= 0:
				main_tab_bar.current_tab = crystal_tab_idx
				main_tab_bar.emit_signal("tab_changed", crystal_tab_idx)
				await get_tree().process_frame
				if not crystal_panel.is_visible_in_tree():
					EditorInterface.set_main_screen_editor("Crystal")
					await get_tree().process_frame
				if not crystal_panel.is_visible_in_tree():
					var msg = "[CrystalToolTester] FAILED: Switching to 'Crystal' tab did not make CrystalPanel visible!"
					printerr(msg)
					error_messages.append(msg)
					errors += 1
				else:
					print("[CrystalToolTester]   ✔ Switching to 'Crystal' tab successfully displayed CrystalPanel (visible=true)!")
			elif crystal_tab_btn:
				crystal_tab_btn.emit_signal("pressed")
				await get_tree().process_frame
				if not crystal_panel.visible:
					var msg = "[CrystalToolTester] FAILED: Pressing 'Crystal' tab button did not make CrystalPanel visible!"
					printerr(msg)
					error_messages.append(msg)
					errors += 1
				else:
					print("[CrystalToolTester]   ✔ Switching to 'Crystal' tab successfully displayed CrystalPanel (visible=true)!")

	# 4. Open a .cr script in the editor to verify Script tab integration and saving
	print("[CrystalToolTester] Testing Script Tab: Loading, editing, and saving res://src/main.cr...")
	var cr_script = load("res://src/main.cr")
	if cr_script:
		print("[CrystalToolTester]   ✔ Loaded %s as %s" % [cr_script.resource_path, cr_script.get_class()])
		EditorInterface.edit_script(cr_script, -1, 0, false)
		print("[CrystalToolTester]   ✔ Successfully opened %s in EditorInterface.edit_script!" % cr_script.resource_path)
		
		var script_editor = EditorInterface.get_script_editor()
		if script_editor:
			var current_script = script_editor.get_current_script()
			if current_script:
				print("[CrystalToolTester]   ✔ ScriptEditor current script verified: %s (%s)" % [current_script.resource_path, current_script.get_class()])
			else:
				print("[CrystalToolTester]   ⚠ Note: ScriptEditor.get_current_script() returned null in headless batch mode")
		
		# Test saving the existing script via ResourceSaver
		var save_err = ResourceSaver.save(cr_script, cr_script.resource_path)
		if save_err != OK:
			var msg = "[CrystalToolTester] Failed to save %s via ResourceSaver (error code: %d)!" % [cr_script.resource_path, save_err]
			printerr(msg)
			error_messages.append(msg)
			errors += 1
		else:
			print("[CrystalToolTester]   ✔ Successfully saved %s via ResourceSaver (OK)!" % cr_script.resource_path)

		# Test creating, saving, and reloading a new CrystalScript
		print("[CrystalToolTester] Testing creation and saving of new CrystalScript resource...")
		var new_script = ClassDB.instantiate("CrystalScript")
		if new_script:
			var test_save_path = "res://bin/test_editor_created_script.cr"
			var test_source = "require \"lapis\"\n\nnode EditorSavedNode < Node do\n  def _ready : Void\n  end\nend\n"
			new_script.set("source_code", test_source)
			new_script.resource_path = test_save_path
			var new_save_err = ResourceSaver.save(new_script, test_save_path)
			if new_save_err != OK:
				var msg = "[CrystalToolTester] Failed to save new CrystalScript to %s (error code: %d)!" % [test_save_path, new_save_err]
				printerr(msg)
				error_messages.append(msg)
				errors += 1
			else:
				print("[CrystalToolTester]   ✔ Successfully saved new CrystalScript to %s" % test_save_path)
				var reloaded = load(test_save_path)
				if reloaded and reloaded.get("source_code").contains("EditorSavedNode"):
					print("[CrystalToolTester]   ✔ Successfully reloaded and verified source of %s" % test_save_path)
				else:
					var msg = "[CrystalToolTester] Reloaded CrystalScript from %s has invalid content!" % test_save_path
					printerr(msg)
					error_messages.append(msg)
					errors += 1
				DirAccess.remove_absolute(test_save_path)
		else:
			var msg = "[CrystalToolTester] Failed to instantiate CrystalScript from ClassDB!"
			printerr(msg)
			error_messages.append(msg)
			errors += 1
	else:
		var msg = "[CrystalToolTester] Failed to load CrystalScript resource"
		printerr(msg)
		error_messages.append(msg)
		errors += 1

	# 5. Verify all @Export annotations on Crystal nodes show up in the Editor Inspector properly
	print("[CrystalToolTester] Verifying @Export properties on ExhaustiveExportMacroNode in Editor Inspector...")
	if ClassDB.class_exists("ExhaustiveExportMacroNode"):
		var exp_node = ClassDB.instantiate("ExhaustiveExportMacroNode")
		if exp_node:
			var props = exp_node.get_property_list()
			var prop_map = {}
			for p in props:
				prop_map[p["name"]] = p
			
			var expected_props = [
				"skills", "range_val", "file_val", "dir_val", "multiline_val",
				"placeholder_val", "opaque_color", "easing_val", "camera_path",
				"hidden_storage", "render2d_flags", "physics2d_flags", "physics3d_flags",
				"combat_power", "combat_def_armor"
			]
			
			for pname in expected_props:
				if not prop_map.has(pname):
					var msg = "[CrystalToolTester] Export property '%s' missing from ExhaustiveExportMacroNode!" % pname
					printerr(msg)
					error_messages.append(msg)
					errors += 1
				else:
					var pinfo = prop_map[pname]
					var usage = int(pinfo["usage"])
					if pname in ["hidden_storage", "combat_power", "combat_def_armor"]:
						if (usage & PROPERTY_USAGE_STORAGE) == 0:
							var msg = "[CrystalToolTester] Property '%s' missing PROPERTY_USAGE_STORAGE!" % pname
							printerr(msg)
							error_messages.append(msg)
							errors += 1
					else:
						if (usage & PROPERTY_USAGE_EDITOR) == 0:
							var msg = "[CrystalToolTester] Property '%s' missing PROPERTY_USAGE_EDITOR flag (usage=%d)!" % [pname, usage]
							printerr(msg)
							error_messages.append(msg)
							errors += 1
			
			# Verify hints for specific annotations
			if prop_map.has("range_val"):
				var rhint = int(prop_map["range_val"]["hint"])
				if rhint != PROPERTY_HINT_RANGE:
					var msg = "[CrystalToolTester] 'range_val' hint is %d, expected PROPERTY_HINT_RANGE (%d)!" % [rhint, PROPERTY_HINT_RANGE]
					printerr(msg)
					error_messages.append(msg)
					errors += 1
			
			if prop_map.has("file_val"):
				var fhint = int(prop_map["file_val"]["hint"])
				if fhint != PROPERTY_HINT_FILE:
					var msg = "[CrystalToolTester] 'file_val' hint is %d, expected PROPERTY_HINT_FILE (%d)!" % [fhint, PROPERTY_HINT_FILE]
					printerr(msg)
					error_messages.append(msg)
					errors += 1

			# Test getting and setting exported properties via Godot reflection
			exp_node.set("range_val", 75.0)
			var new_val = float(exp_node.get("range_val"))
			if abs(new_val - 75.0) > 0.001:
				var msg = "[CrystalToolTester] Failed get/set roundtrip on 'range_val' (got %f)!" % new_val
				printerr(msg)
				error_messages.append(msg)
				errors += 1
			
			print("[CrystalToolTester]   ✔ All @Export properties verified in Inspector with proper usage, hints, and roundtrip values!")
			exp_node.free()
	else:
		var msg = "[CrystalToolTester] ClassDB does not contain 'ExhaustiveExportMacroNode'!"
		printerr(msg)
		error_messages.append(msg)
		errors += 1

	# 6. Phase 2b: In-Editor Regular Test Suite Execution via 'Press Play' (EditorInterface.play_main_scene())
	print("------------------------------------------------------------------")
	print("[CrystalToolTester] Phase 2b: 'Pressing Play' on game in editor game window...")
	print("------------------------------------------------------------------")
	if EditorInterface.has_method("play_main_scene"):
		# Ensure previous markers are cleared
		if FileAccess.file_exists("res://.runtime_tests_passed"):
			DirAccess.remove_absolute("res://.runtime_tests_passed")
		if FileAccess.file_exists("res://.runtime_tests_failed"):
			DirAccess.remove_absolute("res://.runtime_tests_failed")
		if FileAccess.file_exists("res://bin/.runtime_tests_passed"):
			DirAccess.remove_absolute("res://bin/.runtime_tests_passed")
		if FileAccess.file_exists("res://bin/.runtime_tests_failed"):
			DirAccess.remove_absolute("res://bin/.runtime_tests_failed")

		var has_passed = false
		var has_failed = false

		if is_headless:
			print("[CrystalToolTester] Headless editor environment detected: Running test scene synchronously...")
			var out = []
			var exit_code = OS.execute(OS.get_executable_path(), ["--headless", "--audio-driver", "Dummy", "--path", ".", "res://scenes/main_test_runner.tscn", "--", "--autorun"], out, true)
			print("[CrystalToolTester] Direct headless run exited with code: %d" % exit_code)
			has_passed = FileAccess.file_exists("res://.runtime_tests_passed") or FileAccess.file_exists("res://bin/.runtime_tests_passed")
			has_failed = FileAccess.file_exists("res://.runtime_tests_failed") or FileAccess.file_exists("res://bin/.runtime_tests_failed")
		else:
			OS.set_environment("GODOT_TEST_AUTORUN", "1")
			EditorInterface.play_main_scene()
			print("[CrystalToolTester]   ✔ EditorInterface.play_main_scene() triggered!")

			# Wait for scene to start playing
			var start_wait = 0
			while not EditorInterface.is_playing_scene() and start_wait < 180:
				await get_tree().process_frame
				start_wait += 1

			# Wait while playing until game finishes tests and exits
			var elapsed_frames = 0
			var max_frames = 2400
			while EditorInterface.is_playing_scene() and elapsed_frames < max_frames:
				await get_tree().process_frame
				elapsed_frames += 1

			if EditorInterface.is_playing_scene():
				print("[CrystalToolTester] Notice: Game still running after timeout, stopping scene.")
				EditorInterface.stop_playing_scene()
				for i in range(10):
					await get_tree().process_frame

			print("[CrystalToolTester] Checking in-editor game window test results...")
			has_passed = FileAccess.file_exists("res://.runtime_tests_passed") or FileAccess.file_exists("res://bin/.runtime_tests_passed")
			has_failed = FileAccess.file_exists("res://.runtime_tests_failed") or FileAccess.file_exists("res://bin/.runtime_tests_failed")

		if has_passed and not has_failed:
			print("[CrystalToolTester]   ✔ In-editor game window regular test suite PASSED!")
		else:
			var msg = "[CrystalToolTester] In-editor game window regular test suite did not report success (passed=%s, failed=%s)" % [str(has_passed), str(has_failed)]
			printerr(msg)
			error_messages.append(msg)
			errors += 1

	print("==================================================================")
	if not DirAccess.dir_exists_absolute("res://bin"):
		DirAccess.make_dir_absolute("res://bin")

	if errors > 0:
		printerr("[CrystalToolTester] IN-EDITOR TESTS (TOOL & PLAY MODE) FAILED (%d errors)!" % errors)
		var fail_msg = "FAILED: %d errors\n%s\n" % [errors, "\n".join(error_messages)]
		var f_bin = FileAccess.open("res://bin/.tool_tests_failed", FileAccess.WRITE)
		if f_bin:
			f_bin.store_string(fail_msg)
			f_bin.close()
		var f_root = FileAccess.open("res://.tool_tests_failed", FileAccess.WRITE)
		if f_root:
			f_root.store_string(fail_msg)
			f_root.close()
		var f_g_bin = FileAccess.open("res://bin/.editor_game_failed", FileAccess.WRITE)
		if f_g_bin:
			f_g_bin.store_string(fail_msg)
			f_g_bin.close()
		var f_g_root = FileAccess.open("res://.editor_game_failed", FileAccess.WRITE)
		if f_g_root:
			f_g_root.store_string(fail_msg)
			f_g_root.close()
		if FileAccess.file_exists("res://.tool_tests_passed"):
			DirAccess.remove_absolute("res://.tool_tests_passed")
		if FileAccess.file_exists("res://bin/.tool_tests_passed"):
			DirAccess.remove_absolute("res://bin/.tool_tests_passed")
		if FileAccess.file_exists("res://.editor_game_passed"):
			DirAccess.remove_absolute("res://.editor_game_passed")
		if FileAccess.file_exists("res://bin/.editor_game_passed"):
			DirAccess.remove_absolute("res://bin/.editor_game_passed")
	else:
		print("[CrystalToolTester] ALL IN-EDITOR TESTS (TOOL & PLAY MODE) PASSED CLEANLY!")
		var f_bin = FileAccess.open("res://bin/.tool_tests_passed", FileAccess.WRITE)
		if f_bin:
			f_bin.store_string("PASSED\n")
			f_bin.close()
		var f_root = FileAccess.open("res://.tool_tests_passed", FileAccess.WRITE)
		if f_root:
			f_root.store_string("PASSED\n")
			f_root.close()
		var f_g_bin = FileAccess.open("res://bin/.editor_game_passed", FileAccess.WRITE)
		if f_g_bin:
			f_g_bin.store_string("PASSED\n")
			f_g_bin.close()
		var f_g_root = FileAccess.open("res://.editor_game_passed", FileAccess.WRITE)
		if f_g_root:
			f_g_root.store_string("PASSED\n")
			f_g_root.close()
		if FileAccess.file_exists("res://.tool_tests_failed"):
			DirAccess.remove_absolute("res://.tool_tests_failed")
		if FileAccess.file_exists("res://bin/.tool_tests_failed"):
			DirAccess.remove_absolute("res://bin/.tool_tests_failed")
		if FileAccess.file_exists("res://.editor_game_failed"):
			DirAccess.remove_absolute("res://.editor_game_failed")
		if FileAccess.file_exists("res://bin/.editor_game_failed"):
			DirAccess.remove_absolute("res://bin/.editor_game_failed")

	if errors > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
