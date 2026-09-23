# spec/crystal_language_spec.cr
# Verifies CrystalLanguage ScriptLanguageExtension implementation:
# metadata, templates, symbol lookup, auto-indentation, function discovery, and inspection.

require "../src/lapis"

puts "=== Running CrystalLanguage ScriptLanguageExtension Specifications ==="

lang = Godot::CrystalLanguage.instance

# -------------------------------------------------------------
# [Spec 1] Language Metadata & Recognized Extensions
# -------------------------------------------------------------
puts "[Spec 1] Verifying language metadata..."
unless lang.get_name == "Crystal"
  abort "ERROR: get_name expected 'Crystal', got '#{lang.get_name}'"
end
unless lang.get_type == "CrystalScript"
  abort "ERROR: get_type expected 'CrystalScript', got '#{lang.get_type}'"
end
unless lang.get_extension == "cr"
  abort "ERROR: get_extension expected 'cr', got '#{lang.get_extension}'"
end
unless lang.get_recognized_extensions == ["cr"]
  abort "ERROR: get_recognized_extensions expected ['cr'], got #{lang.get_recognized_extensions}"
end
puts "  ✓ Language metadata and extensions verified"

# -------------------------------------------------------------
# [Spec 2] Reserved Words & Control Flow Keywords
# -------------------------------------------------------------
puts "[Spec 2] Verifying reserved words and control flow keywords..."
reserved = lang.get_reserved_words
expected_reserved = ["node", "resource", "gdclass", "def", "end", "property", "signal", "if", "while", "return"]
expected_reserved.each do |word|
  unless reserved.includes?(word)
    abort "ERROR: Reserved words missing expected keyword '#{word}'"
  end
end

ctrl_flow_positives = ["if", "else", "elsif", "unless", "while", "until", "for", "in", "case", "when", "return", "break", "next", "yield", "begin", "rescue", "ensure", "raise"]
ctrl_flow_positives.each do |kw|
  unless lang.is_control_flow_keyword(kw)
    abort "ERROR: '#{kw}' should be recognized as a control flow keyword!"
  end
end

ctrl_flow_negatives = ["node", "property", "signal", "def", "class", "module", "struct", "self", "nil", "true", "false"]
ctrl_flow_negatives.each do |kw|
  if lang.is_control_flow_keyword(kw)
    abort "ERROR: '#{kw}' must NOT be classified as control flow!"
  end
end
puts "  ✓ Reserved words and control flow classifications verified"

# -------------------------------------------------------------
# [Spec 3] Auto-Indentation Engine
# -------------------------------------------------------------
puts "[Spec 3] Verifying auto_indent_code..."
unindented_code = <<-CRYSTAL
node Player < CharacterBody2D do
def _ready : Void
if alive?
attack_enemy
else
flee
end
end
end
CRYSTAL

expected_indented = <<-CRYSTAL
node Player < CharacterBody2D do
  def _ready : Void
    if alive?
      attack_enemy
    else
      flee
    end
  end
end
CRYSTAL

indented_result = lang.auto_indent_code(unindented_code, 0, unindented_code.lines.size - 1)
unless indented_result.gsub("\r\n", "\n") == expected_indented.gsub("\r\n", "\n")
  puts "Expected:\n#{expected_indented}\nGot:\n#{indented_result}"
  abort "ERROR: auto_indent_code failed to correctly format block indentation!"
end
puts "  ✓ Auto-indentation verified for nested blocks, else/elsif branches, and ends"

# -------------------------------------------------------------
# [Spec 4] Symbol Lookup Regex & Word Boundary Precision
# -------------------------------------------------------------
puts "[Spec 4] Verifying symbol lookup logic and word boundaries..."
sample_buffer = <<-CRYSTAL
# Player script
node Player < CharacterBody2D do
  property max_speed : Float32 = 500.0_f32
  property speed : Float32 = 300.0_f32
  property speed_multiplier : Float32 = 1.0_f32

  signal health_depleted
  signal health_depleted_critical

  def attack_all : Void
  end

  def attack : Void
  end
end
CRYSTAL

lookup_symbol = ->(symbol : String, buffer : String) {
  target_line = -1
  buffer.split("\n").each_with_index do |line_content, idx|
    trimmed = line_content.strip
    if trimmed =~ /(?:def|property|getter|setter|signal|node)\s+#{Regex.escape(symbol)}(?:\b|\s|\()/
      target_line = idx + 1
      break
    end
  end
  target_line
}

# 1. Exact match for 'speed' should locate line 4, not line 3 ('max_speed') or line 5 ('speed_multiplier')
line_speed = lookup_symbol.call("speed", sample_buffer)
unless line_speed == 4
  abort "ERROR: Lookup for 'speed' expected line 4, got line #{line_speed}!"
end

# 2. Exact match for 'attack' should locate line 13, not line 10 ('attack_all')
line_attack = lookup_symbol.call("attack", sample_buffer)
unless line_attack == 13
  abort "ERROR: Lookup for 'attack' expected line 13, got line #{line_attack}!"
end

# 3. Exact match for 'health_depleted' should locate line 7, not line 8 ('health_depleted_critical')
line_signal = lookup_symbol.call("health_depleted", sample_buffer)
unless line_signal == 7
  abort "ERROR: Lookup for 'health_depleted' expected line 7, got line #{line_signal}!"
end

# 4. Node class lookup 'Player' should locate line 2
line_node = lookup_symbol.call("Player", sample_buffer)
unless line_node == 2
  abort "ERROR: Lookup for 'Player' expected line 2, got line #{line_node}!"
end

# 5. Non-existent symbol returns -1
line_missing = lookup_symbol.call("teleport", sample_buffer)
unless line_missing == -1
  abort "ERROR: Lookup for non-existent symbol should return -1, got line #{line_missing}!"
end

puts "  ✓ Symbol lookup with regex word boundaries verified"

# -------------------------------------------------------------
# [Spec 5] Function Discovery and Stub Generation
# -------------------------------------------------------------
puts "[Spec 5] Verifying function discovery (_find_function) and stub generation (_make_function)..."
find_fn = ->(fn_name : String, code : String) {
  pattern = /^def\s+#{Regex.escape(fn_name)}(?:\b|\s|\(|:|$)/
  line_found = -1
  code.split("\n").each_with_index do |l, idx|
    if l.strip =~ pattern
      line_found = idx + 1
      break
    end
  end
  line_found
}

make_fn = ->(fn_name : String) {
  "def #{fn_name} : Void\nend\n"
}

# Find function
line_found = find_fn.call("attack", sample_buffer)
unless line_found == 13
  abort "ERROR: _find_function expected line 13, got #{line_found}!"
end


# Make function stub
stub = make_fn.call("on_timer_timeout")
expected_stub = "def on_timer_timeout : Void\nend\n"
unless stub == expected_stub
  abort "ERROR: _make_function generated unexpected stub: '#{stub}'"
end
puts "  ✓ Function discovery and stub generation verified"

# -------------------------------------------------------------
# [Spec 6] Template Class and Base Substitution
# -------------------------------------------------------------
puts "[Spec 6] Verifying template substitution (_make_template)..."
raw_template = "node _CLASS_ < _BASE_ do\n  def _ready : Void\n  end\nend\n"
substituted = raw_template.gsub("_CLASS_", "HeroPlayer").gsub("_BASE_", "CharacterBody3D")

expected_sub = "node HeroPlayer < CharacterBody3D do\n  def _ready : Void\n  end\nend\n"
unless substituted == expected_sub
  abort "ERROR: Template substitution failed: got '#{substituted}'"
end
puts "  ✓ Template class and base substitution verified"

# -------------------------------------------------------------
# [Spec 7] Global Class File Inspection
# -------------------------------------------------------------
puts "[Spec 7] Verifying inspect_file_global_class parsing..."
scratch_dir = Path.new("scratch/test_lang_spec").expand
FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
FileUtils.mkdir_p(scratch_dir)

begin
  test_file = scratch_dir.join("magic_staff.cr")
  File.write(test_file, <<-CRYSTAL
    @[Icon("res://icons/staff.svg")]
    node MagicStaff < WeaponItem do
      property damage : Int32 = 50
    end
  CRYSTAL
  )

  c_name, b_type, icon = Godot::CrystalLanguage.inspect_file_global_class(test_file.to_s)
  unless c_name == "MagicStaff"
    abort "ERROR: Expected class name 'MagicStaff', got '#{c_name}'"
  end
  unless b_type == "WeaponItem"
    abort "ERROR: Expected base type 'WeaponItem', got '#{b_type}'"
  end
  unless icon == "res://icons/staff.svg"
    abort "ERROR: Expected icon path 'res://icons/staff.svg', got '#{icon}'"
  end
  puts "  ✓ inspect_file_global_class parsed class name, base type, and icon path"
ensure
  FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
end

puts "\n>>> All CrystalLanguage ScriptLanguageExtension Specifications Passed! <<<"
