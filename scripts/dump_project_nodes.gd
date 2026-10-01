# =============================================================================
# LibGodot Project Node Dumper (GDScript & Compiled Plugin Introspection)
# =============================================================================
# Runs in headless Godot to dump all custom GDScript nodes and compiled
# GDExtension plugin nodes defined in the project to a JSON manifest.
#
# Usage:
#   godot.exe --headless --path <project_dir> -s tools/api_generator/dump_project_nodes.gd -- --output <out_path>
# =============================================================================

extends SceneTree

func _init():
	var args = OS.get_cmdline_user_args()
	var out_path = "project_nodes.json"
	var engine_api_path = ""
	var scan_local_scripts = true
	
	for i in range(args.size()):
		if args[i] == "--output" and i + 1 < args.size():
			out_path = args[i + 1]
		elif args[i] == "--engine-api" and i + 1 < args.size():
			engine_api_path = args[i + 1]
		elif args[i] == "--no-local-scripts":
			scan_local_scripts = false

	if not out_path.begins_with("res://") and not out_path.begins_with("user://") and not out_path.is_absolute_path():
		out_path = "res://".path_join(out_path)

	# Resolve engine_api.json location if not specified
	if engine_api_path.is_empty():
		var candidates = [
			"res://../extension_api.json",
			"res://extension_api.json",
			"extension_api.json",
			"../extension_api.json"
		]
		for c in candidates:
			if FileAccess.file_exists(c):
				engine_api_path = c
				break

	var core_classes = {}
	if not engine_api_path.is_empty() and FileAccess.file_exists(engine_api_path):
		var api_file = FileAccess.open(engine_api_path, FileAccess.READ)
		if api_file:
			var json = JSON.new()
			if json.parse(api_file.get_as_text()) == OK:
				var data = json.get_data()
				if data is Dictionary and data.has("classes"):
					for cls in data["classes"]:
						core_classes[cls["name"]] = true
			api_file.close()

	var result = {
		"project_name": ProjectSettings.get_setting("application/config/name", "GodotProject"),
		"gdscript_classes": [],
		"plugin_classes": []
	}

	var processed_script_paths = {}

	# 1. Global GDScript Classes (declared with class_name)
	var global_classes = ProjectSettings.get_global_class_list()
	for c in global_classes:
		var script_path = c["path"]
		if not script_path.ends_with(".gd"):
			continue
		processed_script_paths[script_path] = true
		var cls_info = inspect_gdscript(c["class"], script_path, c.get("base", "Node"))
		if cls_info != null:
			result["gdscript_classes"].append(cls_info)

	# 2. Local GDScript files (without global class_name)
	if scan_local_scripts:
		var all_scripts = find_gdscripts_recursive("res://")
		var is_engine_repo = ProjectSettings.get_setting("application/config/name", "") == "LibGodot Test Suite"
		for script_path in all_scripts:
			if processed_script_paths.has(script_path):
				continue
			var file_name = script_path.get_file().get_basename()
			# Skip test files, fixtures, targets, probes, and emitters
			if file_name.begins_with("test_") or file_name.ends_with("_test") or file_name.contains("_target") or file_name.contains("_probe") or file_name.contains("_emitter") or file_name.contains("_caller") or file_name.contains("_freer"):
				continue
			if script_path.contains("/spec/") or script_path.contains("/tests/") or script_path.contains("/fixtures/"):
				continue
			# Check if script declares an explicit class_name
			var explicit_class_name = ""
			var file = FileAccess.open(script_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				var regex = RegEx.new()
				if regex.compile("(?m)^class_name\\s+([A-Za-z0-9_]+)") == OK:
					var m = regex.search(content)
					if m:
						explicit_class_name = m.get_string(1)

			if not explicit_class_name.is_empty():
				processed_script_paths[script_path] = true
				var cls_info = inspect_gdscript(explicit_class_name, script_path, "")
				if cls_info != null:
					result["gdscript_classes"].append(cls_info)
				continue

			# In LibGodot engine repo, local scripts are internal test fixtures - only dump scripts declaring explicit class_name
			if is_engine_repo:
				continue
			# Derive a PascalCase class name from the file name
			var inferred_name = to_pascal_case(file_name)
			var cls_info = inspect_gdscript(inferred_name, script_path, "")
			if cls_info != null:
				result["gdscript_classes"].append(cls_info)

	# 3. Compiled GDExtension Plugin Nodes (registered in ClassDB)
	var is_engine_repo = ProjectSettings.get_setting("application/config/name", "") == "LibGodot Test Suite"
	if not is_engine_repo:
		var local_cr_classes = find_local_crystal_classes()
		var all_classes = ClassDB.get_class_list()
		for cls_name in all_classes:
			var api_type = ClassDB.class_get_api_type(cls_name)
			if api_type != ClassDB.API_EXTENSION and api_type != ClassDB.API_EDITOR_EXTENSION:
				continue

			# Skip classes defined in this project's own Crystal source files
			if local_cr_classes.has(cls_name):
				continue

			# Skip internal Crystal runtime binding types
			if cls_name.begins_with("Crystal") or cls_name == "GodotChannel" or cls_name.begins_with("ResourceFormat"):
				continue

			# Skip dummy test addons, tool testers, and test runners
			if cls_name.begins_with("Dummy") or cls_name.begins_with("TestRunner") or cls_name.begins_with("ToolTester") or cls_name == "RunTesterPanel":
				continue

			var parent = ClassDB.get_parent_class(cls_name)
			if parent.is_empty():
				continue

			var ext_info = {
				"name": cls_name,
				"inherits": parent,
				"is_instantiable": ClassDB.can_instantiate(cls_name),
				"properties": [],
				"methods": [],
				"signals": [],
				"constants": {}
			}

			# ClassDB properties (declared by this class only)
			for p in ClassDB.class_get_property_list(cls_name, true):
				if p["name"].ends_with(".gd"):
					continue
				ext_info["properties"].append({
					"name": p["name"],
					"type": p["type"],
					"type_name": type_string(p["type"]),
					"class_name": p.get("class_name", ""),
					"hint": p["hint"],
					"hint_string": p["hint_string"]
				})

			# ClassDB methods (declared by this class only)
			for m in ClassDB.class_get_method_list(cls_name, true):
				var ret = m.get("return", {})
				var ret_type = ret.get("type", 0)
				var args_list = []
				for a in m.get("args", []):
					args_list.append({
						"name": a["name"],
						"type": a["type"],
						"type_name": type_string(a["type"]),
						"class_name": a.get("class_name", "")
					})
				ext_info["methods"].append({
					"name": m["name"],
					"return_type": ret_type,
					"return_type_name": type_string(ret_type),
					"return_class_name": ret.get("class_name", ""),
					"args": args_list,
					"flags": m.get("flags", 0)
				})

			# ClassDB signals (declared by this class only)
			for s in ClassDB.class_get_signal_list(cls_name, true):
				var s_args = []
				for a in s.get("args", []):
					s_args.append({
						"name": a["name"],
						"type": a["type"],
						"type_name": type_string(a["type"]),
						"class_name": a.get("class_name", "")
					})
				ext_info["signals"].append({
					"name": s["name"],
					"args": s_args
				})

			# ClassDB constants
			for c_name in ClassDB.class_get_integer_constant_list(cls_name, true):
				ext_info["constants"][c_name] = ClassDB.class_get_integer_constant(cls_name, c_name)

			result["plugin_classes"].append(ext_info)

	# 4. Save JSON Manifest
	var out_dir = out_path.get_base_dir()
	if not out_dir.is_empty():
		var da = DirAccess.open("res://")
		if da != null:
			da.make_dir_recursive(out_dir)

	var f = FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(result, "\t"))
		f.close()
		print("[ProjectDumper] Extracted ", result["gdscript_classes"].size(), " GDScript node(s) and ", result["plugin_classes"].size(), " compiled plugin node(s) -> ", out_path)
	else:
		printerr("[ProjectDumper] Error opening output file: ", out_path)
		quit(1)

	quit(0)

func inspect_gdscript(cls_name: String, script_path: String, base_hint: String) -> Dictionary:
	var script_res = load(script_path) as GDScript
	if not script_res:
		return {}

	var global_name = script_res.get_global_name()
	if not global_name.is_empty():
		cls_name = global_name
	else:
		var src = script_res.get_source_code()
		var regex = RegEx.new()
		if regex.compile("class_name\\s+([A-Za-z0-9_]+)") == OK:
			var match = regex.search(src)
			if match:
				cls_name = match.get_string(1)

	var base_type = script_res.get_instance_base_type()
	if base_type.is_empty():
		base_type = base_hint
	if base_type.is_empty():
		base_type = "Node"

	var info = {
		"name": cls_name,
		"language": "GDScript",
		"path": script_path,
		"inherits": base_type,
		"properties": [],
		"methods": [],
		"signals": [],
		"constants": {}
	}

	for p in script_res.get_script_property_list():
		if p["name"].ends_with(".gd") or p["name"].begins_with("@"):
			continue
		info["properties"].append({
			"name": p["name"],
			"type": p["type"],
			"type_name": type_string(p["type"]),
			"class_name": p.get("class_name", ""),
			"hint": p["hint"],
			"hint_string": p["hint_string"]
		})

	for m in script_res.get_script_method_list():
		var ret = m.get("return", {})
		var ret_type = ret.get("type", 0)
		var args_list = []
		for a in m.get("args", []):
			args_list.append({
				"name": a["name"],
				"type": a["type"],
				"type_name": type_string(a["type"]),
				"class_name": a.get("class_name", "")
			})
		info["methods"].append({
			"name": m["name"],
			"return_type": ret_type,
			"return_type_name": type_string(ret_type),
			"return_class_name": ret.get("class_name", ""),
			"args": args_list,
			"flags": m.get("flags", 0)
		})

	for s in script_res.get_script_signal_list():
		var s_args = []
		for a in s.get("args", []):
			s_args.append({
				"name": a["name"],
				"type": a["type"],
				"type_name": type_string(a["type"]),
				"class_name": a.get("class_name", "")
			})
		info["signals"].append({
			"name": s["name"],
			"args": s_args
		})

	var const_map = script_res.get_script_constant_map()
	for k in const_map:
		info["constants"][k] = const_map[k]

	return info

func find_gdscripts_recursive(dir_path: String) -> Array:
	var scripts = []
	var dir = DirAccess.open(dir_path)
	if not dir:
		return scripts

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var skip_dirs = ["addons", "bin", "lib", "export", "dist", "godot-src", "benchmarks", "examples", "template", "template-addon", "scratch", "docs"]
	while file_name != "":
		if file_name.begins_with(".") or file_name in skip_dirs or file_name.ends_with("dump_project_nodes.gd"):
			file_name = dir.get_next()
			continue

		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			scripts.append_array(find_gdscripts_recursive(full_path))
		elif file_name.ends_with(".gd"):
			scripts.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return scripts

func find_files_recursive(dir_path: String, ext: String) -> Array:
	var files = []
	var dir = DirAccess.open(dir_path)
	if not dir:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var skip_dirs = ["bin", "lib", "export", "dist", "godot-src", "examples", "template", "template-addon", "scratch", "docs"]
	while file_name != "":
		if file_name.begins_with(".") or file_name in skip_dirs:
			file_name = dir.get_next()
			continue

		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			files.append_array(find_files_recursive(full_path, ext))
		elif file_name.ends_with(ext):
			files.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return files

func find_local_crystal_classes() -> Dictionary:
	var classes = {}
	var cr_files = find_files_recursive("res://", ".cr")
	var regex = RegEx.new()
	if regex.compile("^\\s*(?:node|class|struct)\\s+([A-Za-z0-9_]+)") != OK:
		return classes

	for f in cr_files:
		if f.contains("/generated/") or f.contains("/.godot/") or f.contains("/addons/"):
			continue
		var fa = FileAccess.open(f, FileAccess.READ)
		if fa:
			while not fa.eof_reached():
				var line = fa.get_line()
				var match = regex.search(line)
				if match:
					classes[match.get_string(1)] = true
			fa.close()

	return classes

func to_pascal_case(snake: String) -> String:
	var parts = snake.split("_")
	var res = ""
	for part in parts:
		if part.length() > 0:
			res += part.substr(0, 1).to_upper() + part.substr(1)
	return res
