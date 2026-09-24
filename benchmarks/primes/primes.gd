extends SceneTree

class TrieNode:
	var children: Dictionary = {}
	var terminal: bool = false

class Sieve:
	var limit: int
	var prime: PackedByteArray

	func _init(p_limit: int) -> void:
		limit = p_limit
		prime = PackedByteArray()
		prime.resize(limit + 1)
		prime.fill(0)

	func to_list() -> Array:
		var result: Array = [2, 3]
		for p in range(5, limit + 1):
			if prime[p] == 1:
				result.append(p)
		return result

	func omit_squares() -> Sieve:
		var r: int = 5
		while r * r < limit:
			if prime[r] == 1:
				var i: int = r * r
				while i < limit:
					prime[i] = 0
					i += r * r
			r += 1
		return self

	func step1(x: int, y: int) -> void:
		var n: int = (4 * x * x) + (y * y)
		if n <= limit:
			var m: int = n % 12
			if m == 1 or m == 5:
				prime[n] = 1 if prime[n] == 0 else 0

	func step2(x: int, y: int) -> void:
		var n: int = (3 * x * x) + (y * y)
		if n <= limit and (n % 12 == 7):
			prime[n] = 1 if prime[n] == 0 else 0

	func step3(x: int, y: int) -> void:
		var n: int = (3 * x * x) - (y * y)
		if x > y and n <= limit and (n % 12 == 11):
			prime[n] = 1 if prime[n] == 0 else 0

	func loop_y(x: int) -> void:
		var y: int = 1
		while y * y < limit:
			step1(x, y)
			step2(x, y)
			step3(x, y)
			y += 1

	func loop_x() -> void:
		var x: int = 1
		while x * x < limit:
			loop_y(x)
			x += 1

	func calc() -> Sieve:
		loop_x()
		omit_squares()
		return self

func generate_trie(l: Array) -> TrieNode:
	var root: TrieNode = TrieNode.new()
	for el in l:
		var head: TrieNode = root
		var s: String = str(el)
		for ch in s:
			if not head.children.has(ch):
				head.children[ch] = TrieNode.new()
			head = head.children[ch]
		head.terminal = true
	return root

func find_primes(upper_bound: int, prefix: int) -> Array:
	var sieve: Sieve = Sieve.new(upper_bound).calc()
	var str_prefix: String = str(prefix)
	var head: TrieNode = generate_trie(sieve.to_list())
	for ch in str_prefix:
		if not head.children.has(ch):
			return []
		head = head.children[ch]

	var queue: Array = [[head, str_prefix]]
	var result: Array = []
	while queue.size() > 0:
		var item: Array = queue.pop_back()
		var top: TrieNode = item[0]
		var cur_prefix: String = item[1]
		if top.terminal:
			result.append(int(cur_prefix))
		for ch in top.children:
			queue.push_front([top.children[ch], cur_prefix + ch])
	result.sort()
	return result

func _init() -> void:
	var left: Array = [2, 23, 29]
	var right: Array = find_primes(100, 2)
	if left != right:
		printerr("Verification failed: %s != %s" % [str(left), str(right)])
		quit(1)
		return

	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var upper_bound: int = 1000000
	var prefix: int = 3233
	if user_args.size() > 0:
		upper_bound = int(user_args[0])
	if user_args.size() > 1:
		prefix = int(user_args[1])

	var start_ticks: int = Time.get_ticks_usec()
	var res: Array = find_primes(upper_bound, prefix)
	var end_ticks: int = Time.get_ticks_usec()
	var elapsed_ms: float = float(end_ticks - start_ticks) / 1000.0

	var sample: Array = res.slice(0, 5) if res.size() >= 5 else res
	print("RESULT: %d primes found (first 5: %s)" % [res.size(), str(sample)])
	print("ELAPSED_MS: %.2f" % elapsed_ms)
	quit(0)
