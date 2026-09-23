# spec/tool_verification_spec.cr
# Verifies ToolChecker functionality, semver parsing & comparison,
# shard.yml crystal version embedding, and tool discovery (crystal, make).

require "../tools/lapis/src/core/tool_checker"
require "../tools/lapis/src/core/env"

puts "=== Running Tool Verification Specifications ==="

# -------------------------------------------------------------
# [Spec 1] Embedded Compile-Time Crystal Versions Macro
# -------------------------------------------------------------
puts "[Spec 1] Verifying compile-time crystal version macros..."
target_ver = Lapis::Core::ToolChecker::TARGET_CRYSTAL_VERSION
min_ver = Lapis::Core::ToolChecker::MIN_CRYSTAL_VERSION

if target_ver.empty?
  abort "ERROR: TARGET_CRYSTAL_VERSION is empty!"
end
if min_ver.empty?
  abort "ERROR: MIN_CRYSTAL_VERSION is empty!"
end

puts "  ✓ TARGET_CRYSTAL_VERSION: '#{target_ver}'"
puts "  ✓ MIN_CRYSTAL_VERSION: '#{min_ver}'"

# -------------------------------------------------------------
# [Spec 2] SemVer Parsing Logic
# -------------------------------------------------------------
puts "[Spec 2] Verifying parse_semver..."
test_cases = [
  {"1.21.0", {1, 21, 0}},
  {"1.20.1", {1, 20, 1}},
  {"Crystal 1.20.0 [57cf7da] (2026-03-01)", {1, 20, 0}},
  {"2.0", {2, 0, 0}},
  {"invalid", {0, 0, 0}},
]

test_cases.each do |input, expected|
  parsed = Lapis::Core::ToolChecker.parse_semver(input)
  if parsed != expected
    abort "ERROR: parse_semver('#{input}') expected #{expected}, got #{parsed}"
  end
end
puts "  ✓ parse_semver parsed all test cases correctly"

# -------------------------------------------------------------
# [Spec 3] SemVer Comparison Logic
# -------------------------------------------------------------
puts "[Spec 3] Verifying compare_semver..."
if Lapis::Core::ToolChecker.compare_semver("1.21.0", "1.20.0") <= 0
  abort "ERROR: Expected 1.21.0 > 1.20.0"
end
if Lapis::Core::ToolChecker.compare_semver("1.20.0", "1.20.0") != 0
  abort "ERROR: Expected 1.20.0 == 1.20.0"
end
if Lapis::Core::ToolChecker.compare_semver("1.19.0", "1.20.0") >= 0
  abort "ERROR: Expected 1.19.0 < 1.20.0"
end
if Lapis::Core::ToolChecker.compare_semver("2.0.0", "1.99.99") <= 0
  abort "ERROR: Expected 2.0.0 > 1.99.99"
end
puts "  ✓ compare_semver correctly orders versions"

# -------------------------------------------------------------
# [Spec 4] Crystal Version Support Checking
# -------------------------------------------------------------
puts "[Spec 4] Verifying crystal_version_supported?..."
unless Lapis::Core::ToolChecker.crystal_version_supported?("1.20.0", "1.20.0")
  abort "ERROR: Expected 1.20.0 to be supported against min 1.20.0"
end
unless Lapis::Core::ToolChecker.crystal_version_supported?("1.21.0", "1.20.0")
  abort "ERROR: Expected 1.21.0 to be supported against min 1.20.0"
end
if Lapis::Core::ToolChecker.crystal_version_supported?("1.19.5", "1.20.0")
  abort "ERROR: Expected 1.19.5 NOT to be supported against min 1.20.0"
end
puts "  ✓ crystal_version_supported? enforces minimum thresholds"

# -------------------------------------------------------------
# [Spec 5] Crystal Compiler Discovery on Current System
# -------------------------------------------------------------
puts "[Spec 5] Verifying check_crystal on host..."
crystal_status = Lapis::Core::ToolChecker.check_crystal
puts "  - Found Crystal: #{crystal_status.installed} (path: #{crystal_status.path}, ver: #{crystal_status.version})"
unless crystal_status.installed
  abort "ERROR: Crystal is not installed or found on host!"
end
unless crystal_status.supported
  abort "ERROR: Host crystal #{crystal_status.version} is not supported!"
end
puts "  ✓ check_crystal passed"

# -------------------------------------------------------------
# [Spec 6] Make Discovery on Current System
# -------------------------------------------------------------
puts "[Spec 6] Verifying check_make on host..."
make_status = Lapis::Core::ToolChecker.check_make
puts "  - Found Make: #{make_status.installed} (path: #{make_status.path}, ver: #{make_status.version})"
unless make_status.installed
  abort "ERROR: Make was not found on host!"
end
puts "  ✓ check_make passed"

# -------------------------------------------------------------
# [Spec 7] Crystalline LSP Discovery
# -------------------------------------------------------------
puts "[Spec 7] Verifying check_crystalline..."
c_status = Lapis::Core::ToolChecker.check_crystalline
puts "  - Found Crystalline: #{c_status.installed} (path: #{c_status.path}, ver: #{c_status.version})"
if c_status.installed && c_status.version.nil?
  abort "ERROR: Crystalline is installed but version was not parsed!"
end
puts "  ✓ check_crystalline passed"

# -------------------------------------------------------------
# [Spec 8] LLDB Debugger Discovery
# -------------------------------------------------------------
puts "[Spec 8] Verifying check_lldb..."
lldb_status = Lapis::Core::ToolChecker.check_lldb
puts "  - Found LLDB: #{lldb_status.installed} (path: #{lldb_status.path}, ver: #{lldb_status.version})"
if lldb_status.installed && lldb_status.path.nil?
  abort "ERROR: LLDB is installed but path was nil!"
end
puts "  ✓ check_lldb passed"

# -------------------------------------------------------------
# [Spec 9] Git Version Control Discovery
# -------------------------------------------------------------
puts "[Spec 9] Verifying check_git..."
git_status = Lapis::Core::ToolChecker.check_git
puts "  - Found Git: #{git_status.installed} (path: #{git_status.path}, ver: #{git_status.version})"
unless git_status.installed
  abort "ERROR: Git is not installed or found on host!"
end
puts "  ✓ check_git passed"

# -------------------------------------------------------------
# [Spec 10] verify_all Overall Runner
# -------------------------------------------------------------
puts "[Spec 10] Verifying verify_all..."
all_ok = Lapis::Core::ToolChecker.verify_all(strict: false)
unless all_ok
  abort "ERROR: verify_all returned false on host environment!"
end
puts "  ✓ verify_all successfully verified all required tools"

puts "\n>>> All Tool Verification Specifications Passed! <<<"

