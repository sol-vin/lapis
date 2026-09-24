extends SceneTree

func matmul(a: Array, b: Array) -> Array:
	var m: int = a.size()
	var n: int = a[0].size()
	var p: int = b[0].size()
	
	# Transpose
	var b2: Array = []
	b2.resize(p)
	for j in range(p):
		var row: Array = []
		row.resize(n)
		row.fill(0.0)
		b2[j] = row
	
	for i in range(n):
		for j in range(p):
			b2[j][i] = b[i][j]
	
	# Multiplication
	var c: Array = []
	c.resize(m)
	for i in range(m):
		var row: Array = []
		row.resize(p)
		row.fill(0.0)
		c[i] = row
	
	for i in range(m):
		var ai: Array = a[i]
		var ci: Array = c[i]
		for j in range(p):
			var b2j: Array = b2[j]
			var s: float = 0.0
			for k in range(n):
				s += ai[k] * b2j[k]
			ci[j] = s
	return c

func matgen(n: int, seed_val: float) -> Array:
	var tmp: float = seed_val / float(n) / float(n)
	var a: Array = []
	a.resize(n)
	for i in range(n):
		var row: Array = []
		row.resize(n)
		for j in range(n):
			row[j] = tmp * float(i - j) * float(i + j)
		a[i] = row
	return a

func calc(n: int) -> float:
	n = (n >> 1) << 1
	var a: Array = matgen(n, 1.0)
	var b: Array = matgen(n, 2.0)
	var c: Array = matmul(a, b)
	var mid: int = n >> 1
	return c[mid][mid]

func _init() -> void:
	# Self verification
	var left: float = calc(101)
	var right: float = -18.67
	if abs(left - right) > 0.1:
		printerr("Verification failed: %f != %f" % [left, right])
		quit(1)
		return

	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var n: int = 400
	if user_args.size() > 0:
		n = int(user_args[0])
	
	var start_ticks: int = Time.get_ticks_usec()
	var res: float = calc(n)
	var end_ticks: int = Time.get_ticks_usec()
	var elapsed_ms: float = float(end_ticks - start_ticks) / 1000.0

	print("RESULT: %f" % res)
	print("ELAPSED_MS: %.2f" % elapsed_ms)
	quit(0)
