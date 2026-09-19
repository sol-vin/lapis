# spec/baked_file_system_spec.cr
# Verifies BakedFileSystem declarative loading from baked.yml,
# file retrieval, absence of bloat/binaries, and disk extraction.

require "../tools/lapis/src/core/baked_file_system"
require "file_utils"

puts "=== Running BakedFileSystem Specifications ==="

# -------------------------------------------------------------
# [Spec 1] Manifest Loading and Whitelist Verification
# -------------------------------------------------------------
puts "[Spec 1] Verifying BakedFileSystem loaded whitelisted assets..."
files = Lapis::Core::BakedFileSystem.files
if files.empty?
  abort "ERROR: BakedFileSystem.files is empty!"
end
puts "  ✓ Total baked files: #{files.size}"

required_assets = [
  "godot-version.yml",
  "shard.yml",
  "template/project.godot",
  "template/shard.yml",
  "template/Makefile",
  "template/export_presets.cfg",
  "template/src/main.cr",
  "template/scenes/main.tscn",
  "addons/crystal_integration/crystal.gdextension",
  "addons/crystal_integration/plugin.cfg",
  "addons/crystal_integration/plugin.gd",
  "addons/crystal_integration/crystal_icon.svg",
  "template-addon/project.godot",
  "template-addon/shard.yml",
  "template-addon/src/main.cr",
  "template-addon/addons/crystal_addon/crystal_addon.gdextension",
]

required_assets.each do |req|
  unless Lapis::Core::BakedFileSystem.has_file?(req)
    abort "ERROR: Required asset '#{req}' is missing from BakedFileSystem!"
  end
end
puts "  ✓ All core assets verified present in BakedFileSystem"

# -------------------------------------------------------------
# [Spec 2] Zero Bloat & Forbidden Patterns Verification
# -------------------------------------------------------------
puts "[Spec 2] Verifying zero bloat: absence of binaries, caches, and logs..."
forbidden_extensions = [".dll", ".so", ".dylib", ".lib", ".a", ".zip", ".uid", ".log", ".import"]
forbidden_patterns = [".godot/", "lib/", "bin/", "dist/"]

files.each do |f|
  forbidden_extensions.each do |ext|
    if f.ends_with?(ext)
      abort "ERROR: Forbidden extension '#{ext}' found in baked file '#{f}'! Binary bloat detected."
    end
  end

  forbidden_patterns.each do |pat|
    # Only check if pat appears as a directory path component, not root subpaths
    if f.includes?("/#{pat}") || f.starts_with?(pat)
      abort "ERROR: Forbidden directory pattern '#{pat}' found in baked file '#{f}'!"
    end
  end
end
puts "  ✓ Zero bloat verified: no binaries, caches, logs, or intermediate artifacts baked"

# -------------------------------------------------------------
# [Spec 3] Content Retrieval Integrity
# -------------------------------------------------------------
puts "[Spec 3] Verifying content retrieval (get and get?)..."
godot_ver_file = Lapis::Core::BakedFileSystem.get("godot-version.yml")
unless godot_ver_file.content.includes?("version:")
  abort "ERROR: godot-version.yml does not contain 'version:'!"
end
puts "  ✓ godot-version.yml content verified: #{godot_ver_file.size} bytes"

shard_file = Lapis::Core::BakedFileSystem.get("shard.yml")
unless shard_file.content.includes?("name: lapis")
  abort "ERROR: shard.yml does not contain 'name: lapis'!"
end
puts "  ✓ shard.yml content verified: #{shard_file.size} bytes"

non_existent = Lapis::Core::BakedFileSystem.get?("non_existent_file.xyz")
if non_existent
  abort "ERROR: get? on non-existent file expected nil, got object!"
end
puts "  ✓ Safe lookup on missing file returned nil"

# -------------------------------------------------------------
# [Spec 4] Prefix Filtering and Folder Extraction
# -------------------------------------------------------------
puts "[Spec 4] Verifying prefix filtering and folder extraction..."
template_files = Lapis::Core::BakedFileSystem.files_with_prefix("template")
if template_files.size < 5
  abort "ERROR: Expected at least 5 template files, got #{template_files.size}"
end
puts "  ✓ files_with_prefix('template') found #{template_files.size} assets"

temp_extract_dir = Path.new(Dir.tempdir).join("lapis_baked_test_#{Time.utc.to_unix}")
begin
  count = Lapis::Core::BakedFileSystem.extract_folder("template", temp_extract_dir)
  if count != template_files.size
    abort "ERROR: extract_folder extracted #{count} files, expected #{template_files.size}!"
  end

  [
    "project.godot",
    "shard.yml",
    "src/main.cr",
    "scenes/main.tscn",
  ].each do |subpath|
    unless File.exists?(temp_extract_dir.join(subpath))
      abort "ERROR: Extracted file '#{subpath}' not found at #{temp_extract_dir.join(subpath)}!"
    end
  end
  puts "  ✓ Successfully extracted #{count} template files to disk with full integrity"
ensure
  FileUtils.rm_rf(temp_extract_dir) if Dir.exists?(temp_extract_dir)
end

puts "\n>>> All BakedFileSystem Specifications Passed! <<<"
