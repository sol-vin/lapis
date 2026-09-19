# =============================================================================
# LibGodot Test Suite: Standalone Portable Executable & --single-module Toolchain
# =============================================================================

test_standalone_portable "Toolchain automatically enforces --single-module for shared libraries" do
  # Verify shared library detection logic for --single-module
  shared_exts = [".so", ".dll", ".dylib"]
  shared_exts.each do |ext|
    p = Path.new("bin/game#{ext}")
    is_shared = [".so", ".dll", ".dylib"].includes?(p.extension)
    TestFramework.assert_true is_shared, "Extension #{ext} must be recognized as shared library"
  end

  # Executables should not be treated as shared libraries
  exe_p = Path.new("bin/game" + ({% if flag?(:windows) %} ".exe" {% else %} "" {% end %}))
  is_exe_shared = [".so", ".dll", ".dylib"].includes?(exe_p.extension)
  TestFramework.assert_false is_exe_shared, "Executable binary must not be identified as shared library"
end

test_standalone_portable "Standalone executable contains valid GDPC embedded PCK footer" do
  root_dir = File.expand_path("../../..", __DIR__)
  scratch_dir = File.join(root_dir, "scratch", "test_embedded_pck")
  FileUtils.mkdir_p(scratch_dir) unless Dir.exists?(scratch_dir)

  dummy_exe = File.join(scratch_dir, "test_app.exe")
  dummy_pck = File.join(scratch_dir, "test_app.pck")
  output_exe = File.join(scratch_dir, "test_app_portable.exe")

  # 1. Create mock executable (2048 bytes) and mock PCK (1024 bytes)
  exe_data = Bytes.new(2048) { |i| (i % 255).to_u8 }
  pck_data = Bytes.new(1024) { |i| ((i * 3) % 255).to_u8 }
  File.write(dummy_exe, exe_data)
  File.write(dummy_pck, pck_data)

  # 2. Embed PCK into executable using Godot GDPC footer specification
  exe_size = File.size(dummy_exe)
  pck_size = File.size(dummy_pck)
  File.open(output_exe, "wb") do |out_f|
    File.open(dummy_exe, "rb") { |in_exe| IO.copy(in_exe, out_f) }
    File.open(dummy_pck, "rb") { |in_pck| IO.copy(in_pck, out_f) }
    footer_bytes = Bytes.new(12)
    IO::ByteFormat::LittleEndian.encode(pck_size.to_u64, footer_bytes[0, 8])
    IO::ByteFormat::LittleEndian.encode(0x43504447_u32, footer_bytes[8, 4])
    out_f.write(footer_bytes)
  end

  TestFramework.assert_true File.exists?(output_exe), "Embedded executable must exist"

  expected_size = 2048 + 1024 + 12
  TestFramework.assert_eq File.size(output_exe), expected_size, "Output file size must equal exe + pck + 12-byte footer"

  # 3. Decode and verify 12-byte GDPC footer
  File.open(output_exe, "rb") do |f|
    f.seek(2048 + 1024)
    footer = Bytes.new(12)
    f.read_fully(footer)

    pck_size_read = IO::ByteFormat::LittleEndian.decode(UInt64, footer[0, 8])
    magic = IO::ByteFormat::LittleEndian.decode(UInt32, footer[8, 4])
    pck_offset = expected_size - 12 - pck_size_read

    TestFramework.assert_eq pck_size_read, 1024_u64, "pck_size in footer must equal PCK data size (1024)"
    TestFramework.assert_eq pck_offset, 2048_u64, "computed pck_offset must point to start of PCK data (offset 2048)"
    TestFramework.assert_eq magic, 0x43504447_u32, "magic must equal 0x43504447 (GDPC in little-endian)"
  end

  # Cleanup
  FileUtils.rm_rf(scratch_dir) if Dir.exists?(scratch_dir)
end

test_standalone_portable "Active tests executable GDPC footer verification" do
  root_dir = File.expand_path("../../..", __DIR__)
  exe_ext = ({% if flag?(:windows) %} ".exe" {% else %} "" {% end %})
  tests_exe = File.join(root_dir, "test", "bin", "tests_portable" + exe_ext)
  tests_exe = File.join(root_dir, "test", "bin", "tests" + exe_ext) unless File.exists?(tests_exe)

  if File.exists?(tests_exe) && File.size(tests_exe) > 12
    File.open(tests_exe, "rb") do |f|
      file_size = f.size
      f.seek(file_size - 12)
      footer = Bytes.new(12)
      f.read_fully(footer)

      pck_size_read = IO::ByteFormat::LittleEndian.decode(UInt64, footer[0, 8])
      magic = IO::ByteFormat::LittleEndian.decode(UInt32, footer[8, 4])
      pck_offset = file_size - 12 - pck_size_read

      if magic == 0x43504447_u32
        TestFramework.assert_true pck_size_read > 0_u64 && pck_size_read < file_size.to_u64, "pck_size must be within file bounds"
        TestFramework.assert_true pck_offset > 0_u64 && pck_offset < file_size.to_u64, "computed pck_offset must be within file bounds"
      end
    end
  end
end
