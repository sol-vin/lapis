require "../src/lapis"

puts "=== Running Crystalline LSP & Code Intelligence Specifications ==="

# -------------------------------------------------------------
# [Spec 1] CrystalLSP Instance & Path Resolution
# -------------------------------------------------------------
puts "[Spec 1] Verifying CrystalLSP discovery and singleton..."
lsp = Lapis::CrystalLSP.instance
puts "  - Available: #{lsp.available?}"
if File.exists?("bin/crystalline.exe") || File.exists?("bin/crystalline") || Process.find_executable("crystalline")
  unless lsp.available?
    abort "ERROR: Crystalline binary exists but CrystalLSP.available? returned false!"
  end
end
puts "  ✓ CrystalLSP discovery verified"

# -------------------------------------------------------------
# [Spec 2] CrystalLanguage Built-in Completion Proposals
# -------------------------------------------------------------
puts "[Spec 2] Verifying CrystalLanguage.complete_code proposals..."
lang = Godot::CrystalLanguage.instance

completions = lang.complete_code("", "res://test.cr")
if completions.empty?
  abort "ERROR: complete_code returned an empty list of completions!"
end

# Check for required categories
has_node_macro = completions.any? { |c| c.display_text.includes?("node") && c.kind_id == 10_i64 }
has_export_ann = completions.any? { |c| c.display_text.includes?("Export") && c.kind_id == 10_i64 }
has_ready_cb = completions.any? { |c| c.display_text.includes?("_ready") && c.kind_id == 1_i64 }
has_classes = completions.any? { |c| c.display_text == "CharacterBody2D" && c.kind_id == 0_i64 }
has_keywords = completions.any? { |c| c.display_text == "def" && c.kind_id == 10_i64 }

unless has_node_macro
  abort "ERROR: complete_code missing 'node' DSL macro proposal!"
end
unless has_export_ann
  abort "ERROR: complete_code missing '@[Export]' annotation proposal!"
end
unless has_ready_cb
  abort "ERROR: complete_code missing '_ready' callback proposal!"
end
unless has_classes
  abort "ERROR: complete_code missing Godot engine classes!"
end
unless has_keywords
  abort "ERROR: complete_code missing core Crystal keywords!"
end
puts "  ✓ complete_code proposals verified with accurate kind_id metadata"

# -------------------------------------------------------------
# [Spec 3] Local Symbol Completion Extraction
# -------------------------------------------------------------
puts "[Spec 3] Verifying local symbol extraction from source buffer..."
code_sample = <<-CRYSTAL
node Player < CharacterBody2D do
  property speed : Float32 = 300.0_f32
  signal health_depleted(final_score : Int32)

  def attack_enemy : Void
  end
end
CRYSTAL

local_completions = lang.complete_code(code_sample, "res://player.cr")
has_local_speed = local_completions.any? { |c| c.display_text == "speed" && c.kind_id == 4_i64 }
has_local_signal = local_completions.any? { |c| c.display_text == "health_depleted" && c.kind_id == 2_i64 }
has_local_method = local_completions.any? { |c| c.display_text == "attack_enemy()" && c.kind_id == 1_i64 }

unless has_local_speed
  abort "ERROR: Local property 'speed' was not extracted into completions!"
end
unless has_local_signal
  abort "ERROR: Local signal 'health_depleted' was not extracted into completions!"
end
unless has_local_method
  abort "ERROR: Local method 'attack_enemy()' was not extracted into completions!"
end
puts "  ✓ Local symbol extraction from active buffer verified"

# -------------------------------------------------------------
# [Spec 4] BridgeCompletionOption C-ABI Layout
# -------------------------------------------------------------
puts "[Spec 4] Verifying BridgeCompletionOption C-ABI structure..."
display_str = "test_method"
insert_str = "test_method()"
default_val = "void"

opt = Lapis::Bridge::BridgeCompletionOption.new(
  1_i64, # Function
  display_str.to_unsafe,
  insert_str.to_unsafe,
  default_val.to_unsafe,
  0_i64  # LocationLocal
)

unless opt.kind == 1_i64 && opt.location == 0_i64
  abort "ERROR: BridgeCompletionOption fields corrupted!"
end
puts "  ✓ BridgeCompletionOption C-ABI layout verified"

# -------------------------------------------------------------
# [Spec 5] IDE Setup Configuration Verification
# -------------------------------------------------------------
puts "[Spec 5] Verifying lapis ide setup generation..."
require "../tools/lapis/src/commands/ide"

scratch_ide = Path.new("scratch/test_ide_lsp").expand
FileUtils.rm_rf(scratch_ide) if Dir.exists?(scratch_ide)
FileUtils.mkdir_p(scratch_ide)

begin
  res = Lapis::Commands::Ide.setup_vscode(scratch_ide, force: true)
  unless res == 0
    abort "ERROR: setup_vscode returned non-zero exit code!"
  end

  # Verify settings.json
  settings_path = scratch_ide.join(".vscode/settings.json")
  unless File.exists?(settings_path)
    abort "ERROR: .vscode/settings.json was not generated!"
  end
  settings_json = File.read(settings_path)
  unless settings_json.includes?("crystal-lang.server") && settings_json.includes?("--stdio")
    abort "ERROR: settings.json missing crystalline --stdio configuration!"
  end

  # Verify extensions.json
  ext_path = scratch_ide.join(".vscode/extensions.json")
  unless File.exists?(ext_path)
    abort "ERROR: .vscode/extensions.json was not generated!"
  end
  ext_json = File.read(ext_path)
  unless ext_json.includes?("crystal-lang.crystal-lang") && ext_json.includes?("geequlim.godot-tools")
    abort "ERROR: extensions.json missing recommended extension IDs!"
  end

  # Verify Zed setup
  res_zed = Lapis::Commands::Ide.setup_zed(scratch_ide, force: true)
  unless res_zed == 0
    abort "ERROR: setup_zed returned non-zero exit code!"
  end
  zed_path = scratch_ide.join(".zed/settings.json")
  unless File.exists?(zed_path)
    abort "ERROR: .zed/settings.json was not generated!"
  end
  zed_json = File.read(zed_path)
  unless zed_json.includes?("crystalline") && zed_json.includes?("--stdio")
    abort "ERROR: zed settings.json missing --stdio arguments!"
  end

  puts "  ✓ IDE configuration generation for VS Code and Zed verified with --stdio"
ensure
  FileUtils.rm_rf(scratch_ide) if Dir.exists?(scratch_ide)
end

puts "\n>>> All Crystalline LSP & Code Intelligence Specifications Passed! <<<"
