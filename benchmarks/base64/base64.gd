extends SceneTree

func _init() -> void:
	# Self verification
	var pairs: Array = [
		["hello", "aGVsbG8="],
		["world", "d29ybGQ="]
	]
	for pair in pairs:
		var src: String = pair[0]
		var dst: String = pair[1]
		var raw_src: PackedByteArray = src.to_ascii_buffer()
		var encoded: String = Marshalls.raw_to_base64(raw_src)
		if encoded != dst:
			printerr("Verification failed: %s != %s" % [encoded, dst])
			quit(1)
			return
		var decoded_raw: PackedByteArray = Marshalls.base64_to_raw(dst)
		var decoded: String = decoded_raw.get_string_from_ascii()
		if decoded != src:
			printerr("Verification failed: %s != %s" % [decoded, src])
			quit(1)
			return

	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var str_size: int = 65536
	var tries: int = 200
	if user_args.size() > 0:
		str_size = int(user_args[0])
	if user_args.size() > 1:
		tries = int(user_args[1])

	var raw_buffer: PackedByteArray = PackedByteArray()
	raw_buffer.resize(str_size)
	raw_buffer.fill(97) # 'a'

	var str2: String = Marshalls.raw_to_base64(raw_buffer)
	var str3_raw: PackedByteArray = Marshalls.base64_to_raw(str2)
	if str3_raw.size() != str_size:
		printerr("Roundtrip size mismatch!")
		quit(1)
		return

	var start_ticks: int = Time.get_ticks_usec()
	var s_encoded: int = 0
	for i in range(tries):
		var enc: String = Marshalls.raw_to_base64(raw_buffer)
		s_encoded += enc.length()

	var s_decoded: int = 0
	for i in range(tries):
		var dec: PackedByteArray = Marshalls.base64_to_raw(str2)
		s_decoded += dec.size()
	var end_ticks: int = Time.get_ticks_usec()
	var elapsed_ms: float = float(end_ticks - start_ticks) / 1000.0

	print("RESULT: encoded=%d, decoded=%d" % [s_encoded, s_decoded])
	print("ELAPSED_MS: %.2f" % elapsed_ms)
	quit(0)
