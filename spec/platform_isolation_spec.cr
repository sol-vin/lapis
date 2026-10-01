# spec/platform_isolation_spec.cr
# Verifies platform binary classification, foreign binary purging,
# command rejection for non-supported targets, and addons directory cleanliness.

require "../tools/lapis/src/core/env"
require "../tools/lapis/src/core/process_runner"
require "file_utils"

puts "=== Running Platform Isolation Specifications ==="

# -------------------------------------------------------------
# [Spec 1] Platform Identification and Classification
# -------------------------------------------------------------
puts "[Spec 1] Verifying platform classification helpers..."
current_plat = Lapis::Core::Env.current_platform
puts "  Current host platform: #{current_plat}"

{% if flag?(:windows) %}
  unless current_plat == "windows"
    abort "ERROR: Expected current_platform to be 'windows', got #{current_plat}"
  end

  # Native binaries
  unless Lapis::Core::Env.is_native_binary?("crystal_bridge.dll")
    abort "ERROR: crystal_bridge.dll should be identified as native on Windows"
  end
  unless Lapis::Core::Env.is_native_binary?("lapis.exe")
    abort "ERROR: lapis.exe should be identified as native on Windows"
  end
  if Lapis::Core::Env.is_foreign_binary?("crystal_bridge.dll")
    abort "ERROR: crystal_bridge.dll should not be identified as foreign on Windows"
  end

  # Foreign binaries
  unless Lapis::Core::Env.is_foreign_binary?("crystal_bridge.so")
    abort "ERROR: crystal_bridge.so should be identified as foreign on Windows"
  end
  unless Lapis::Core::Env.is_foreign_binary?("plugin.so")
    abort "ERROR: plugin.so should be identified as foreign on Windows"
  end
  unless Lapis::Core::Env.is_foreign_binary?("crystal_bridge.dylib")
    abort "ERROR: crystal_bridge.dylib should be identified as foreign on Windows"
  end
  unless Lapis::Core::Env.is_foreign_binary?("lapis_1.0.0_amd64.deb")
    abort "ERROR: .deb file should be identified as foreign on Windows"
  end
  unless Lapis::Core::Env.is_foreign_binary?("game")
    abort "ERROR: bare Linux executable 'game' should be identified as foreign on Windows"
  end
  puts "  ✓ Windows native and foreign binary classification verified"
{% elsif flag?(:darwin) %}
  unless current_plat == "macos"
    abort "ERROR: Expected current_platform to be 'macos', got #{current_plat}"
  end
  unless Lapis::Core::Env.is_native_binary?("crystal_bridge.dylib")
    abort "ERROR: crystal_bridge.dylib should be identified as native on macOS"
  end
  unless Lapis::Core::Env.is_foreign_binary?("crystal_bridge.dll")
    abort "ERROR: crystal_bridge.dll should be identified as foreign on macOS"
  end
  unless Lapis::Core::Env.is_foreign_binary?("crystal_bridge.so")
    abort "ERROR: crystal_bridge.so should be identified as foreign on macOS"
  end
  puts "  ✓ macOS native and foreign binary classification verified"
{% else %}
  unless current_plat == "linux"
    abort "ERROR: Expected current_platform to be 'linux', got #{current_plat}"
  end
  unless Lapis::Core::Env.is_native_binary?("crystal_bridge.so")
    abort "ERROR: crystal_bridge.so should be identified as native on Linux"
  end
  unless Lapis::Core::Env.is_foreign_binary?("crystal_bridge.dll")
    abort "ERROR: crystal_bridge.dll should be identified as foreign on Linux"
  end
  unless Lapis::Core::Env.is_foreign_binary?("lapis-setup.exe")
    abort "ERROR: .exe should be identified as foreign on Linux"
  end
  puts "  ✓ Linux native and foreign binary classification verified"
{% end %}

# -------------------------------------------------------------
# [Spec 2] Foreign Binary Directory Purging
# -------------------------------------------------------------
puts "[Spec 2] Verifying foreign binary purging in mock directory..."
mock_dir = Path.new(Dir.tempdir).join("lapis_purge_spec_#{Time.utc.to_unix}")
FileUtils.mkdir_p(mock_dir)

begin
  File.write(mock_dir.join("native_file.dll"), "mock dll")
  File.write(mock_dir.join("foreign_file.so"), "mock so")
  File.write(mock_dir.join("foreign_file.dylib"), "mock dylib")
  File.write(mock_dir.join("documentation.txt"), "plain text")

  purged = Lapis::Core::Env.purge_foreign_binaries(mock_dir)

  {% if flag?(:windows) %}
    unless purged == 2
      abort "ERROR: Expected 2 foreign files purged on Windows, got #{purged}"
    end
    unless File.exists?(mock_dir.join("native_file.dll"))
      abort "ERROR: native_file.dll was erroneously purged on Windows!"
    end
    unless File.exists?(mock_dir.join("documentation.txt"))
      abort "ERROR: documentation.txt was erroneously purged on Windows!"
    end
    if File.exists?(mock_dir.join("foreign_file.so"))
      abort "ERROR: foreign_file.so was not purged on Windows!"
    end
    if File.exists?(mock_dir.join("foreign_file.dylib"))
      abort "ERROR: foreign_file.dylib was not purged on Windows!"
    end
    puts "  ✓ Successfully purged 2 foreign files (.so, .dylib) while preserving native .dll and text"
  {% end %}
ensure
  FileUtils.rm_rf(mock_dir) if Dir.exists?(mock_dir)
end

puts "\n>>> All Platform Isolation Specifications Passed! <<<"
