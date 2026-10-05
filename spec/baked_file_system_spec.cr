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
  "template/.github/workflows/release.yml",
  "template-addon/.github/workflows/release.yml",
  "src/libgodot.cr",
  "src/lapis.cr",
  "src/bridge/crystal_bridge.cpp",
  "src/libgodot/binding_macros.cr",
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

# -------------------------------------------------------------
# [Spec 5] Platform-Specific Asset Isolation
# -------------------------------------------------------------
puts "[Spec 5] Verifying platform-specific asset isolation..."
{% if flag?(:windows) %}
  unless Lapis::Core::BakedFileSystem.has_file?("scripts/windows/install_deps.ps1")
    abort "ERROR: Windows platform asset 'scripts/windows/install_deps.ps1' missing on Windows!"
  end
  unless Lapis::Core::BakedFileSystem.has_file?("packaging/windows/lapis_installer.iss")
    abort "ERROR: Windows platform asset 'packaging/windows/lapis_installer.iss' missing on Windows!"
  end
  puts "  ✓ Windows-specific scripts verified present in Windows binary"
{% else %}
  if Lapis::Core::BakedFileSystem.has_file?("scripts/windows/install_deps.ps1")
    abort "ERROR: Windows asset 'scripts/windows/install_deps.ps1' leaked into non-Windows binary!"
  end
  if Lapis::Core::BakedFileSystem.has_file?("packaging/windows/lapis_installer.iss")
    abort "ERROR: Windows asset 'packaging/windows/lapis_installer.iss' leaked into non-Windows binary!"
  end
  puts "  ✓ Non-Windows binary verified clean of Windows scripts and installers"
{% end %}

# -------------------------------------------------------------
# [Spec 6] Lean Engine Library Extraction & Bloat Exclusion
# -------------------------------------------------------------
puts "[Spec 6] Verifying lean engine library extraction (extract_engine_lib)..."
temp_lib_dir = Path.new(Dir.tempdir).join("lapis_engine_lib_test_#{Time.utc.to_unix}")
begin
  success = Lapis::Core::BakedFileSystem.extract_engine_lib(temp_lib_dir)
  unless success
    abort "ERROR: extract_engine_lib returned false!"
  end

  # Required compiler files must exist
  [
    "shard.yml",
    "godot-version.yml",
    ".gdignore",
    "src/libgodot.cr",
    "src/lapis.cr",
    "src/libgodot/types.cr",
    "src/libgodot/variant.cr",
    "src/libgodot/binding_macros.cr",
    "src/libgodot/generated/classes/classes_part1.cr",
    "src/bridge/crystal_bridge.cpp",
  ].each do |required_file|
    unless File.exists?(temp_lib_dir.join(required_file))
      abort "ERROR: Required engine library file '#{required_file}' missing from extracted lib at #{temp_lib_dir.join(required_file)}!"
    end
  end

  # Non-code bloat must NEVER be extracted into lib/lapis
  if File.exists?(temp_lib_dir.join("src/main.cr"))
    abort "ERROR: Root test runner 'src/main.cr' leaked into extracted lib/lapis!"
  end

  if Dir.exists?(temp_lib_dir.join("src/libgodot/docs"))
    abort "ERROR: Jasper documentation directory 'src/libgodot/docs' leaked into extracted lib/lapis!"
  end

  puts "  ✓ Lean engine library extracted with zero non-code bloat (no src/main.cr, no docs/**)"
ensure
  FileUtils.rm_rf(temp_lib_dir) if Dir.exists?(temp_lib_dir)
end

# -------------------------------------------------------------
# [Spec 7] Bakelite Item Metadata & CRC32 Checksums
# -------------------------------------------------------------
puts "[Spec 7] Verifying Bakelite item metadata and CRC32 checksums..."
engine_file = Lapis::Core::BakedFileSystem.get("src/libgodot.cr")
if engine_file.crc32 == 0_u32
  abort "ERROR: CRC32 checksum for 'src/libgodot.cr' is zero!"
end
if engine_file.crc32_hex.size != 8
  abort "ERROR: Hex CRC32 checksum invalid format: #{engine_file.crc32_hex}!"
end
unless engine_file.mime_type.includes?("crystal") || engine_file.mime_type.includes?("text")
  abort "ERROR: Expected text MIME type, got #{engine_file.mime_type}!"
end
puts "  ✓ Item metadata verified (CRC32: 0x#{engine_file.crc32_hex}, MIME: #{engine_file.mime_type})"

# -------------------------------------------------------------
# [Spec 8] Streamed Chunk Decompression (Bakelite::FileIO)
# -------------------------------------------------------------
puts "[Spec 8] Verifying streaming IO decompression (Bakelite::FileIO)..."
Lapis::Core::BakedFileSystem.open("src/libgodot/binding_macros.cr") do |io|
  buf = Bytes.new(64)
  read_bytes = io.read(buf)
  if read_bytes <= 0
    abort "ERROR: Streaming IO read 0 bytes from 'src/libgodot/binding_macros.cr'!"
  end
  str = String.new(buf[0, read_bytes])
  unless str.includes?("macro") || str.includes?("module") || str.includes?("#")
    abort "ERROR: Streamed content does not contain expected code tokens!"
  end
end
puts "  ✓ Streaming chunk decompression verified via Bakelite::FileIO"

# -------------------------------------------------------------
# [Spec 9] Volume Routing & Isolation
# -------------------------------------------------------------
puts "[Spec 9] Verifying Bakelite volume routing and isolation..."
unless Lapis::Core::BakedFileSystem.fs.volume?(:engine)
  abort "ERROR: Volume ':engine' not found in Bakelite registry!"
end
unless Lapis::Core::BakedFileSystem.fs.volume?(:template)
  abort "ERROR: Volume ':template' not found in Bakelite registry!"
end
unless Lapis::Core::BakedFileSystem.fs.volume?(:addon)
  abort "ERROR: Volume ':addon' not found in Bakelite registry!"
end

engine_vol = Lapis::Core::BakedFileSystem.fs.volume(:engine)
if engine_vol.empty?
  abort "ERROR: Volume ':engine' is empty!"
end
puts "  ✓ Volume isolation verified: :engine (#{engine_vol.size} files), :template, :addon mounted"

puts "\n>>> All BakedFileSystem Specifications Passed! <<<"

