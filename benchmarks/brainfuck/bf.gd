extends SceneTree

enum OpType { INC, MOVE, PRINT, LOOP }

class Op:
	var type: int
	var val: int
	var loop_ops: Array

	func _init(p_type: int, p_val: int = 0, p_loop: Array = []) -> void:
		type = p_type
		val = p_val
		loop_ops = p_loop

class Tape:
	var tape: Array = [0]
	var pos: int = 0

	func get_val() -> int:
		return tape[pos]

	func inc(x: int) -> void:
		tape[pos] += x

	func move_pos(x: int) -> void:
		pos += x
		while pos >= tape.size():
			tape.append(0)

class Printer:
	var quiet: bool
	var sum1: int = 0
	var sum2: int = 0

	func _init(p_quiet: bool = true) -> void:
		quiet = p_quiet

	func print_val(n: int) -> void:
		if quiet:
			sum1 = (sum1 + n) % 255
			sum2 = (sum2 + sum1) % 255
		else:
			printraw(char(n))

	func checksum() -> int:
		return (sum2 << 8) | sum1

class Program:
	var ops: Array = []
	var printer: Printer

	func _init(code: String, p_printer: Printer) -> void:
		printer = p_printer
		var parse_result: Array = parse_slice(code, 0)
		ops = parse_result[0]

	func parse_slice(code: String, idx: int) -> Array:
		var res: Array = []
		var i: int = idx
		var n: int = code.length()
		while i < n:
			var c: String = code[i]
			if c == "+":
				res.append(Op.new(OpType.INC, 1))
			elif c == "-":
				res.append(Op.new(OpType.INC, -1))
			elif c == ">":
				res.append(Op.new(OpType.MOVE, 1))
			elif c == "<":
				res.append(Op.new(OpType.MOVE, -1))
			elif c == ".":
				res.append(Op.new(OpType.PRINT))
			elif c == "[":
				var inner: Array = parse_slice(code, i + 1)
				res.append(Op.new(OpType.LOOP, 0, inner[0]))
				i = inner[1]
			elif c == "]":
				return [res, i]
			i += 1
		return [res, i]

	func run() -> void:
		var tape: Tape = Tape.new()
		_run(ops, tape)

	func _run(prog: Array, tape: Tape) -> void:
		for op in prog:
			if op.type == OpType.INC:
				tape.inc(op.val)
			elif op.type == OpType.MOVE:
				tape.move_pos(op.val)
			elif op.type == OpType.LOOP:
				while tape.get_val() > 0:
					_run(op.loop_ops, tape)
			elif op.type == OpType.PRINT:
				printer.print_val(tape.get_val())

func _init() -> void:
	# Self verification
	var text: String = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>\n---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
	var p_left: Printer = Printer.new(true)
	Program.new(text, p_left).run()
	var left: int = p_left.checksum()

	var p_right: Printer = Printer.new(true)
	var hw: String = "Hello World!\n"
	for i in range(hw.length()):
		p_right.print_val(hw.unicode_at(i))
	var right: int = p_right.checksum()

	if left != right:
		printerr("Verification failed: %d != %d" % [left, right])
		quit(1)
		return

	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var file_path: String = "benchmarks/brainfuck/bench.b"
	if user_args.size() > 0:
		file_path = user_args[0]

	if not FileAccess.file_exists(file_path):
		printerr("File not found: %s" % file_path)
		quit(1)
		return

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	var code: String = file.get_as_text()
	file.close()

	var printer_inst: Printer = Printer.new(true)
	var prog: Program = Program.new(code, printer_inst)

	var start_ticks: int = Time.get_ticks_usec()
	prog.run()
	var end_ticks: int = Time.get_ticks_usec()
	var elapsed_ms: float = float(end_ticks - start_ticks) / 1000.0

	print("RESULT: checksum=%d" % printer_inst.checksum())
	print("ELAPSED_MS: %.2f" % elapsed_ms)
	quit(0)
