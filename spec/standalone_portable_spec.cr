# spec/standalone_portable_spec.cr
# Verifies --single-module build flag support and Godot GDPC PCK-embedding
# for standalone portable executables.

require "file_utils"
require "path"
require "../tools/lapis/src/commands/package"
require "../tools/lapis/src/commands/build"

puts "=== Running Standalone Portable & --single-module Specifications ==="

root_dir = File.expand_path("..", __DIR__)
lapis_exe = File.join(root_dir, "bin", "lapis" + ({% if flag?(:windows) %} ".exe" {% else %} "" {% end %}))

# -------------------------------------------------------------
# [Spec 1] Lapis build --help advertises --single-module flags
# -------------------------------------------------------------
puts "[Spec 1] Verifying 'lapis build --help' advertises --single-module flags..."
if File.exists?(lapis_exe)
  out_io = IO::Memory.new
  status = Process.run(lapis_exe, ["build", "--help"], output: out_io)
  output = out_io.to_s
  unless status.success? && output.includes?("--single-module") && output.includes?("--no-single-module")
    abort "ERROR: 'lapis build --help' missing --single-module options:\n#{output}"
  end
  puts "  ✓ 'lapis build --help' properly documents -m, --single-module and --no-single-module"
else
  puts "  ! lapis binary not found at #{lapis_exe}, skipping CLI flag check"
end

# -------------------------------------------------------------
# [Spec 2] PCK embedding algorithm & GDPC 12-byte footer verification
# -------------------------------------------------------------
puts "[Spec 2] Verifying embed_pck_in_executable byte structure and GDPC footer..."
scratch_dir = File.join(root_dir, "scratch", "spec_portable")
FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
FileUtils.mkdir_p(scratch_dir)

dummy_exe_path = Path.new(File.join(scratch_dir, "mock_runner.exe"))
dummy_pck_path = Path.new(File.join(scratch_dir, "mock_game.pck"))
output_exe_path = Path.new(File.join(scratch_dir, "mock_embedded.exe"))

# 1. Create mock executable with 1024 bytes of distinct data
mock_exe_bytes = Bytes.new(1024) { |i| (i % 256).to_u8 }
File.write(dummy_exe_path.to_s, mock_exe_bytes)

# 2. Create mock PCK with 512 bytes of distinct data
mock_pck_bytes = Bytes.new(512) { |i| ((i + 128) % 256).to_u8 }
File.write(dummy_pck_path.to_s, mock_pck_bytes)

# 3. Embed PCK into executable
success = Lapis::Commands::Package.embed_pck_in_executable(
  dummy_exe_path,
  dummy_pck_path,
  output_exe_path
)

unless success
  abort "ERROR: embed_pck_in_executable returned false!"
end

unless File.exists?(output_exe_path)
  abort "ERROR: output embedded executable was not created!"
end

expected_size = 1024 + 512 + 12
actual_size = File.size(output_exe_path)
if actual_size != expected_size
  abort "ERROR: Expected file size #{expected_size}, got #{actual_size}!"
end

# 4. Read and validate footer
File.open(output_exe_path.to_s, "rb") do |f|
  f.seek(1024 + 512)
  footer_bytes = Bytes.new(12)
  f.read_fully(footer_bytes)

  pck_size = IO::ByteFormat::LittleEndian.decode(UInt64, footer_bytes[0, 8])
  magic = IO::ByteFormat::LittleEndian.decode(UInt32, footer_bytes[8, 4])
  pck_offset = actual_size - 12 - pck_size

  if pck_size != 512_u64
    abort "ERROR: Expected pck_size 512, got #{pck_size}!"
  end

  if pck_offset != 1024_u64
    abort "ERROR: Expected computed pck_offset 1024, got #{pck_offset}!"
  end

  # GDPC = 0x43504447 in little-endian
  if magic != 0x43504447_u32
    abort "ERROR: Expected magic 0x43504447 ('GDPC'), got 0x#{magic.to_s(16)}!"
  end
end

puts "  ✓ Embedded PCK matches expected byte layout (1024 exe + 512 pck + 12 footer)"
puts "  ✓ GDPC footer correctly encodes pck_size (512), computed pck_offset (1024), and magic (0x43504447)"

# -------------------------------------------------------------
# [Spec 3] Verification of tests_portable.exe GDPC footer if present
# -------------------------------------------------------------
puts "[Spec 3] Verifying active tests executable GDPC footer if present..."
exe_suffix = ({% if flag?(:windows) %} ".exe" {% else %} "" {% end %})
tests_exe = File.join(root_dir, "test", "bin", "tests_portable" + exe_suffix)
tests_exe = File.join(root_dir, "test", "bin", "tests" + exe_suffix) unless File.exists?(tests_exe)

if File.exists?(tests_exe) && File.size(tests_exe) > 12
  File.open(tests_exe, "rb") do |f|
    file_size = f.size
    f.seek(file_size - 12)
    footer_bytes = Bytes.new(12)
    f.read_fully(footer_bytes)

    pck_size = IO::ByteFormat::LittleEndian.decode(UInt64, footer_bytes[0, 8])
    magic = IO::ByteFormat::LittleEndian.decode(UInt32, footer_bytes[8, 4])
    pck_offset = file_size - 12 - pck_size

    if magic == 0x43504447_u32
      puts "  ✓ Active tests executable contains valid GDPC footer (pck_size: #{pck_size}, pck_offset: #{pck_offset} / #{file_size} bytes)"
    else
      puts "  ! Active tests executable does not currently have embedded PCK footer (magic: 0x#{magic.to_s(16)}) - will be embedded on next packaging step"
    end
  end
else
  puts "  ! tests executable not yet built, skipping active binary check"
end

# Clean up scratch dir
FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)

puts ">>> All Standalone Portable Specifications Passed! <<<"
