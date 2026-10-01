# spec/lapis_cli_spec.cr
# Runner for Lapis toolchain specifications located in tools/lapis/spec

puts "=== Running Lapis Toolchain & CLI Specifications ==="

root_dir = File.expand_path("..", __DIR__)
cache_dir = File.join(root_dir, "scratch", "cache_cli_spec")
Dir.mkdir_p(cache_dir)
status = Process.run("crystal", ["spec", "tools/lapis/spec"], chdir: root_dir, output: STDOUT, error: STDERR, env: {"CRYSTAL_CACHE_DIR" => cache_dir})

if status.success?
  puts "✓ All Lapis CLI & toolchain specifications passed successfully!"
else
  abort "ERROR: Lapis CLI specifications failed with exit code #{status.exit_code}!"
end
