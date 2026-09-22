# spec/binary_release_spec.cr
# Verifies that release binaries do NOT include editor-only classes,
# plugins, panels, or highlighters.

require "file_utils"
require "path"

puts "=== Running Release Binary Cleanliness Specifications ==="

root_dir = File.expand_path("..", __DIR__)
scratch_dir = File.join(root_dir, "scratch", "spec_binary_release")
FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
FileUtils.mkdir_p(scratch_dir)

# -------------------------------------------------------------
# [Spec 1] Verify src/libgodot.cr shim exists and points to lapis
# -------------------------------------------------------------
puts "[Spec 1] Verifying src/libgodot.cr shim integrity..."
libgodot_shim = File.join(root_dir, "src", "libgodot.cr")
unless File.exists?(libgodot_shim)
  abort "ERROR: src/libgodot.cr does not exist!"
end
shim_content = File.read(libgodot_shim)
unless shim_content.includes?("require \"./lapis\"")
  abort "ERROR: src/libgodot.cr does not require ./lapis!"
end
puts "  ✓ src/libgodot.cr exists and properly shims to ./lapis"

# -------------------------------------------------------------
# [Spec 2] Build a release test binary and verify editor symbols are stripped
# -------------------------------------------------------------
puts "[Spec 2] Compiling release test binary and auditing editor symbols..."
entry_cr = File.join(scratch_dir, "release_entry.cr")
output_bin = File.join(scratch_dir, "release_sample" + ({% if flag?(:windows) %} ".dll" {% else %} ".so" {% end %}))

File.write(entry_cr, <<-CRYSTAL)
require "../../src/libgodot"

node ReleaseGameEntity < Node2D do
  @[Export]
  property hit_points : Int32 = 100

  def _ready : Void
    Godot.print("ReleaseGameEntity ready!")
  end
end
CRYSTAL

link_flags = {% if flag?(:windows) %} "/DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init" {% else %} "-shared" {% end %}
build_args = [
  "build",
  entry_cr,
  "-o", output_bin,
  "--release",
  "--link-flags", link_flags
]

# Set CRYSTAL_PATH to include src/
src_path = File.join(root_dir, "src")
base_crystal_path = `crystal env CRYSTAL_PATH`.strip
env_path_sep = {% if flag?(:windows) %} ";" {% else %} ":" {% end %}
full_crystal_path = "#{src_path}#{env_path_sep}#{base_crystal_path}"

build_out = IO::Memory.new
status = Process.run(
  "crystal",
  build_args,
  env: {"CRYSTAL_PATH" => full_crystal_path},
  chdir: scratch_dir,
  output: build_out,
  error: build_out
)

unless status.success? && File.exists?(output_bin)
  abort "ERROR: Failed to compile release test binary at #{output_bin}:\n#{build_out}"
end

puts "  ✓ Release binary compiled successfully (#{File.size(output_bin)} bytes)"

# Read raw bytes and extract printable ASCII strings of length >= 4
bin_bytes = File.read(output_bin).to_slice
strings_found = [] of String
current_str = String::Builder.new

bin_bytes.each do |b|
  if (b >= 32 && b <= 126) # printable ASCII
    current_str << b.unsafe_chr
  else
    if current_str.bytesize >= 4
      strings_found << current_str.to_s
    end
    current_str = String::Builder.new
  end
end
if current_str.bytesize >= 4
  strings_found << current_str.to_s
end

# Check for absence of editor-only classes
editor_only_symbols = [
  "CrystalIntegrationPlugin",
  "CrystalHighlighter",
  "CrystalDebuggerPlugin",
  "CrystalPanel",
  "CrystalLldbSessionTab"
]

editor_only_symbols.each do |sym|
  found = strings_found.any? { |s| s.includes?(sym) }
  if found
    abort "ERROR: Release binary leaked editor-only symbol '#{sym}'!"
  end
end

puts "  ✓ Formally verified zero editor-only classes in release binary: #{editor_only_symbols.join(", ")}"

# Verify game class IS present
has_game_entity = strings_found.any? { |s| s.includes?("ReleaseGameEntity") }
unless has_game_entity
  abort "ERROR: Release binary did not contain the user game class 'ReleaseGameEntity'!"
end
puts "  ✓ User game class 'ReleaseGameEntity' verified present in release binary"

# Clean up scratch dir
FileUtils.rm_rf(scratch_dir)

puts ">>> All Release Binary Cleanliness Specifications Passed! <<<"
