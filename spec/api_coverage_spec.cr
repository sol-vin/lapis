require "json"
require "../src/lapis"

puts "=== Running API Definition & Class Coverage Specifications ==="

# -----------------------------------------------------------------------------
# 1. Load extension_api.json
# -----------------------------------------------------------------------------
api_file = File.join(__DIR__, "..", "extension_api.json")
unless File.exists?(api_file)
  abort "Failed: extension_api.json not found at #{api_file}. Run godot.exe --headless --dump-extension-api first."
end

api_data = JSON.parse(File.read(api_file))

# Exclusions list: Any class from extension_api.json that is intentionally omitted
# MUST have a documented, architectural justification here.
# Currently, 100% of the 1,050 classes are expected to be generated with 0 exclusions.
EXCLUSIONS = Hash(String, String).new

# -----------------------------------------------------------------------------
# 2. Verify 100% Class Coverage from extension_api.json
# -----------------------------------------------------------------------------
puts "[Spec 1] Godot Engine ClassDB Coverage (extension_api.json -> Crystal)..."

api_classes = api_data["classes"].as_a
puts "  Found #{api_classes.size} classes defined in extension_api.json"

# Collect all classes defined in src/libgodot/generated/classes/classes_part*.cr
generated_classes = Hash(String, String).new # name => parent
glob_pattern = File.join(__DIR__, "..", "src", "libgodot", "generated", "classes", "classes_part*.cr").gsub('\\', '/')
generated_files = Dir.glob(glob_pattern)

abort "Failed: No generated class files found in src/libgodot/generated/classes!" if generated_files.empty?

generated_files.each do |file_path|
  File.each_line(file_path) do |line|
    # Matches: class ClassName < ParentName
    if line =~ /^\s*class\s+([A-Za-z0-9_]+)(?:\s*<\s*([A-Za-z0-9_:]+))?/
      class_name = $1
      parent_name = $2? ? $2.split("::").last : "Object"
      generated_classes[class_name] = parent_name
    end
  end
end

puts "  Found #{generated_classes.size} generated classes across #{generated_files.size} part files"

missing_classes = [] of String
unjustified_exclusions = [] of String
hierarchy_mismatches = [] of String

api_classes.each do |c|
  name = c["name"].as_s
  expected_parent = c["inherits"]?.try(&.as_s) || "Object"

  if EXCLUSIONS.has_key?(name)
    reason = EXCLUSIONS[name]
    if reason.strip.empty?
      unjustified_exclusions << "#{name}: missing justification"
    end
    next
  end

  unless generated_classes.has_key?(name)
    missing_classes << name
    next
  end

  actual_parent = generated_classes[name]
  # In Godot, Object is root. In Crystal, generated classes inherit Godot::Object or their parent
  if expected_parent != actual_parent && name != "Object"
    # Allow canonical Godot parent variations
    hierarchy_mismatches << "#{name}: expected inherits #{expected_parent}, got #{actual_parent}"
  end
end

unless unjustified_exclusions.empty?
  abort "Failed: The following classes were excluded without justification:\n  #{unjustified_exclusions.join("\n  ")}"
end

if missing_classes.size > 0
  puts "\n::error::Missing #{missing_classes.size} classes from extension_api.json:"
  missing_classes.each { |c| puts "  - #{c}" }
  abort "Failed: #{missing_classes.size} Godot classes from extension_api.json are missing from Crystal bindings!"
end

unless hierarchy_mismatches.empty?
  puts "\n::error::Found #{hierarchy_mismatches.size} class hierarchy mismatches:"
  hierarchy_mismatches.first(10).each { |m| puts "  - #{m}" }
  abort "Failed: #{hierarchy_mismatches.size} class inheritance hierarchies do not match extension_api.json!"
end

puts "  ✓ 100% Class Coverage: All #{api_classes.size} classes from extension_api.json are generated with correct hierarchies!"

# -----------------------------------------------------------------------------
# 3. Verify Singletons Coverage
# -----------------------------------------------------------------------------
puts "[Spec 2] Godot Engine Singleton Coverage..."

if singletons = api_data["singletons"]?.try(&.as_a)
  singletons_file = File.join(__DIR__, "..", "src", "libgodot", "generated", "singletons.cr")
  abort "Failed: singletons.cr not found" unless File.exists?(singletons_file)

  singletons_content = File.read(singletons_file)
  missing_singletons = [] of String

  singletons.each do |s|
    s_name = s["name"].as_s
    unless singletons_content.includes?("class #{s_name} <") || singletons_content.includes?("godot_singleton(#{s_name},")
      missing_singletons << s_name
    end
  end

  if missing_singletons.size > 0
    abort "Failed: Missing singletons in singletons.cr: #{missing_singletons.join(", ")}"
  end

  puts "  ✓ All #{singletons.size} singletons defined in extension_api.json are present in singletons.cr!"
end

# -----------------------------------------------------------------------------
# 4. Verify Global Enums Coverage
# -----------------------------------------------------------------------------
puts "[Spec 3] Godot Engine Global Enums Coverage..."

if global_enums = api_data["global_enums"]?.try(&.as_a)
  enums_file = File.join(__DIR__, "..", "src", "libgodot", "generated", "global_enums.cr")
  abort "Failed: global_enums.cr not found" unless File.exists?(enums_file)

  enums_content = File.read(enums_file)
  missing_enums = [] of String

  global_enums.each do |e|
    raw_name = e["name"].as_s
    clean_name = raw_name.starts_with?("Variant.") ? raw_name.gsub("Variant.", "") : raw_name
    next if clean_name.empty?

    unless enums_content.includes?("enum #{clean_name} :")
      missing_enums << clean_name
    end
  end

  if missing_enums.size > 0
    abort "Failed: Missing global enums in global_enums.cr: #{missing_enums.join(", ")}"
  end

  puts "  ✓ All #{global_enums.size} global enums defined in extension_api.json are present in global_enums.cr!"
end

# -----------------------------------------------------------------------------
# 5. Runtime Instantiation & Class Resolution Smoke Verification
# -----------------------------------------------------------------------------
puts "[Spec 4] Runtime Class Resolution across Alphabetical Spectrum..."

# Verify classes spanning A through Z can be instantiated / referenced
test_node2d = Godot::Node2D.new
abort "Failed: Godot::Node2D instantiation" if test_node2d.nil?

test_node3d = Godot::Node3D.new
abort "Failed: Godot::Node3D instantiation" if test_node3d.nil?

test_character = Godot::CharacterBody3D.new
abort "Failed: Godot::CharacterBody3D instantiation" if test_character.nil?

test_openxr = Godot::OpenXRInterface.new
abort "Failed: Godot::OpenXRInterface instantiation" if test_openxr.nil?

test_path = Godot::Path2D.new
abort "Failed: Godot::Path2D instantiation" if test_path.nil?

test_rb = Godot::RigidBody3D.new
abort "Failed: Godot::RigidBody3D instantiation" if test_rb.nil?

test_zip = Godot::ZIPReader.new
abort "Failed: Godot::ZIPReader instantiation" if test_zip.nil?

puts "  ✓ Full spectrum from Node2D to OpenXRInterface to ZIPReader instantiated successfully!"
puts "=== All API Definition Coverage Specifications Passed! ==="
