extends SceneTree

# ConfigFile Benchmark in GDScript
# Parsing, querying and encoding 1,000 section INI config

func _init():
	var args = OS.get_cmdline_user_args()
	var sections = 1000
	if args.size() > 0:
		sections = int(args[0])

	var lines = []
	for s in range(sections):
		lines.append("[entity_section_%d]" % s)
		lines.append("name = \"Entity_%d\"" % s)
		lines.append("health = %d" % (100 + s % 500))
		lines.append("speed = %f" % (5.5 + float(s % 10) * 0.5))
		lines.append("active = true\n")
	var raw_ini = "\n".join(lines)

	var start_time = Time.get_ticks_usec()

	var cf = ConfigFile.new()
	cf.parse(raw_ini)

	var hits: int = 0
	for s in range(sections):
		if cf.has_section_key("entity_section_%d" % s, "health"):
			hits += 1

	var encoded = cf.encode_to_text()
	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("ConfigFileOps %d sections: %.2f ms (hits=%d, len=%d)" % [sections, elapsed, hits, encoded.length()])
	print("ELAPSED_MS: %.2f" % elapsed)
	quit(0)
