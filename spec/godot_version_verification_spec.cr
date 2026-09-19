# spec/godot_version_verification_spec.cr
# Verifies Godot version extraction, embedding macros, C++ header generation,
# and version matching logic across Lapis and LibGodot.

require "../tools/lapis/src/core/godot_finder"
require "../tools/lapis/src/core/env"

puts "=== Running Godot Engine Version Verification Specifications ==="

# -------------------------------------------------------------
# [Spec 1] Embedded Compile-Time Godot Version Macro
# -------------------------------------------------------------
puts "[Spec 1] Verifying compile-time EMBEDDED_GODOT_VERSION macro..."
embedded = Lapis::Core::GodotFinder::EMBEDDED_GODOT_VERSION
if embedded.empty?
  abort "ERROR: EMBEDDED_GODOT_VERSION is empty!"
end
if embedded != "4.8-dev6"
  abort "ERROR: EMBEDDED_GODOT_VERSION expected '4.8-dev6', got '#{embedded}'"
end
puts "  ✓ EMBEDDED_GODOT_VERSION is '#{embedded}'"

# -------------------------------------------------------------
# [Spec 2] Expected Version Resolution
# -------------------------------------------------------------
puts "[Spec 2] Verifying GodotFinder.expected_version resolution..."
root_expected = Lapis::Core::GodotFinder.expected_version
if root_expected != "4.8-dev6"
  abort "ERROR: Expected root version '4.8-dev6', got '#{root_expected}'"
end

test_expected = Lapis::Core::GodotFinder.expected_version(File.expand_path("../test", __DIR__))
if test_expected != "4.8-dev6"
  abort "ERROR: Expected test project version '4.8-dev6', got '#{test_expected}'"
end
puts "  ✓ expected_version correctly resolves '4.8-dev6'"

# -------------------------------------------------------------
# [Spec 3] Version Matching Logic (version_matches?)
# -------------------------------------------------------------
puts "[Spec 3] Verifying version_matches? token matching..."

# Matching cases
matches = [
  {"4.8-dev6", "4.8-dev6"},
  {"4.8.dev6", "4.8-dev6"},
  {"4.8.dev6.official.8898c2b3d", "4.8-dev6"},
  {"4.8.dev6.custom_build", "4.8-dev6"},
  {"4.8.dev6.official.8898c2b3d", "4.8.dev6"},
  {"4.3.stable.official", "4.3-stable"},
]

matches.each do |detected, expected|
  unless Lapis::Core::GodotFinder.version_matches?(detected, expected)
    abort "ERROR: Expected '#{detected}' to match '#{expected}', but version_matches? returned false!"
  end
end
puts "  ✓ Valid version combinations successfully match"

# Non-matching cases
mismatches = [
  {"4.8.dev5.official.8898c2b3d", "4.8-dev6"},
  {"4.4.stable.official", "4.8-dev6"},
  {"4.8.beta1.official", "4.8-dev6"},
  {"3.5.3.stable", "4.8-dev6"},
  {"4.8.rc1.official", "4.8-dev6"},
]

mismatches.each do |detected, expected|
  if Lapis::Core::GodotFinder.version_matches?(detected, expected)
    abort "ERROR: Expected '#{detected}' to NOT match '#{expected}', but version_matches? returned true!"
  end
end
puts "  ✓ Incompatible version combinations successfully rejected"

# -------------------------------------------------------------
# [Spec 4] C++ Bridge Header Generation (src/bridge/godot_version.h)
# -------------------------------------------------------------
puts "[Spec 4] Verifying src/bridge/godot_version.h..."
header_path = File.expand_path("../src/bridge/godot_version.h", __DIR__)
if !File.exists?(header_path)
  abort "ERROR: Header #{header_path} does not exist!"
end

header_content = File.read(header_path)
unless header_content.includes?("#define LIBGODOT_TARGET_VERSION \"4.8-dev6\"")
  abort "ERROR: Header does not contain correct LIBGODOT_TARGET_VERSION definition!\n#{header_content}"
end
puts "  ✓ src/bridge/godot_version.h contains target definition: '4.8-dev6'"

# -------------------------------------------------------------
# [Spec 5] Real Engine Binary Verification (if present)
# -------------------------------------------------------------
puts "[Spec 5] Verifying workspace Godot binary..."
godot_bin = Lapis::Core::GodotFinder.resolve
if godot_bin && File.exists?(godot_bin)
  detected_ver = Lapis::Core::GodotFinder.get_version(godot_bin)
  if detected_ver
    puts "  ✓ Detected active Godot engine: #{godot_bin} (version: #{detected_ver})"
    unless Lapis::Core::GodotFinder.version_matches?(detected_ver, "4.8-dev6")
      abort "ERROR: Local Godot binary #{godot_bin} (#{detected_ver}) does not match target '4.8-dev6'!"
    end
    puts "  ✓ Local Godot binary matches target version"
  else
    puts "  - Active Godot binary version query skipped"
  end
else
  puts "  - No local Godot binary found to query directly"
end

puts "=== All Godot Engine Version Verification Specifications Passed! ==="
