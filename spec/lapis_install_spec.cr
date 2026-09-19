# spec/lapis_install_spec.cr
# Verifies Lapis CLI global installation, uninstallation, and configuration lifecycle.

require "file_utils"
require "path"
require "json"

puts "=== Running Lapis CLI Installation & Lifecycle Specifications ==="

root_dir = File.expand_path("..", __DIR__)
lapis_exe = File.join(root_dir, "bin", "lapis" + (Process.run("cmd", ["/c", "ver"], output: IO::Memory.new).success? ? ".exe" : ""))

# Ensure lapis binary exists for spec
unless File.exists?(lapis_exe)
  puts "Compiling Lapis CLI for spec..."
  compile_res = Process.run("crystal", ["build", File.join(root_dir, "tools/lapis/src/lapis.cr"), "-o", lapis_exe])
  unless compile_res.success?
    abort "ERROR: Failed to compile lapis for installation specification!"
  end
end

# -------------------------------------------------------------
# [Spec 1] Lapis install --help output
# -------------------------------------------------------------
puts "[Spec 1] Verifying 'lapis help install' and 'lapis install --help'..."
out_io = IO::Memory.new
status = Process.run(lapis_exe, ["help", "install"], output: out_io)
unless status.success? && out_io.to_s.includes?("=== Lapis: Toolchain Installation Manager ===")
  abort "ERROR: 'lapis help install' failed or produced unexpected output: #{out_io}"
end
puts "  ✓ 'lapis help install' displays valid usage and options"

# -------------------------------------------------------------
# [Spec 2] Lapis install into explicit target directory
# -------------------------------------------------------------
puts "[Spec 2] Verifying 'lapis install --dir <test_dir>' lifecycle..."
test_install_dir = File.join(root_dir, "scratch", "test_lapis_install")
FileUtils.rm_rf(test_install_dir) if Dir.exists?(test_install_dir)
FileUtils.mkdir_p(test_install_dir)

target_binary = File.join(test_install_dir, File.basename(lapis_exe))

install_io = IO::Memory.new
install_status = Process.run(lapis_exe, ["install", "--dir", test_install_dir], output: install_io)
unless install_status.success?
  abort "ERROR: 'lapis install --dir' failed with exit code #{install_status.exit_code}:\n#{install_io}"
end

unless File.exists?(target_binary)
  abort "ERROR: Target binary was not created at #{target_binary}!"
end

# Verify installed binary is executable and outputs valid version
test_io = IO::Memory.new
run_status = Process.run(target_binary, ["--version"], output: test_io)
unless run_status.success? && test_io.to_s.includes?("Lapis v")
  abort "ERROR: Installed lapis binary failed execution: #{test_io}"
end
puts "  ✓ 'lapis install' successfully installed executable and verified execution"

# -------------------------------------------------------------
# [Spec 3] Lapis uninstall from explicit target directory
# -------------------------------------------------------------
puts "[Spec 3] Verifying 'lapis install --uninstall --dir <test_dir>'..."
uninstall_io = IO::Memory.new
uninstall_status = Process.run(lapis_exe, ["install", "--uninstall", "--dir", test_install_dir], output: uninstall_io)
unless uninstall_status.success?
  abort "ERROR: 'lapis install --uninstall' failed with exit code #{uninstall_status.exit_code}:\n#{uninstall_io}"
end

if File.exists?(target_binary)
  abort "ERROR: Target binary #{target_binary} still exists after uninstallation!"
end
puts "  ✓ 'lapis uninstall' cleanly removed binary"

# Cleanup test directory
FileUtils.rm_rf(test_install_dir) if Dir.exists?(test_install_dir)

puts "✓ All Lapis installation specifications passed successfully!"
