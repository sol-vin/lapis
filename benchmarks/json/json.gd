extends SceneTree

func calc(text: String) -> Vector3:
	var jobj = JSON.parse_string(text)
	if jobj == null or not jobj.has("coordinates"):
		return Vector3.ZERO
	var coordinates: Array = jobj["coordinates"]
	var length: int = coordinates.size()
	if length == 0:
		return Vector3.ZERO

	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0

	for coord in coordinates:
		x += float(coord["x"])
		y += float(coord["y"])
		z += float(coord["z"])

	var flen: float = float(length)
	return Vector3(x / flen, y / flen, z / flen)

func _init() -> void:
	# Self verification
	var right: Vector3 = Vector3(2.0, 0.5, 0.25)
	var checks: Array = [
		"{\"coordinates\":[{\"x\":2.0,\"y\":0.5,\"z\":0.25}]}",
		"{\"coordinates\":[{\"y\":0.5,\"x\":2.0,\"z\":0.25}]}"
	]
	for v in checks:
		var left: Vector3 = calc(v)
		if (left - right).length() > 0.001:
			printerr("Verification failed: %s != %s" % [str(left), str(right)])
			quit(1)
			return

	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var file_path: String = "benchmarks/json/1.json"
	if user_args.size() > 0:
		file_path = user_args[0]

	if not FileAccess.file_exists(file_path):
		printerr("File not found: %s" % file_path)
		quit(1)
		return

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var start_ticks: int = Time.get_ticks_usec()
	var res: Vector3 = calc(text)
	var end_ticks: int = Time.get_ticks_usec()
	var elapsed_ms: float = float(end_ticks - start_ticks) / 1000.0

	print("RESULT: x=%.4f, y=%.4f, z=%.4f" % [res.x, res.y, res.z])
	print("ELAPSED_MS: %.2f" % elapsed_ms)
	quit(0)
