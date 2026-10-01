require "../src/lapis"

puts "=== Verifying LibGodot DLL Loading ==="

lib_name = {% if flag?(:windows) %}
             "bin/libgodot.dll"
           {% elsif flag?(:darwin) %}
             "bin/libgodot.dylib"
           {% else %}
             "bin/libgodot.so"
           {% end %}

if !File.exists?(lib_name)
  puts "INFO: #{lib_name} is not present (requires 'make engine' from godot-src or prebuilt binary)."
  puts "INFO: Skipping in-memory LibGodot dynamic loader verification."
  exit 0
end

loader = LibGodot::DynamicLoader.new(lib_name)
if loader.loaded?
  puts "SUCCESS: #{lib_name} loaded successfully!"
  puts "SUCCESS: Found libgodot_create_godot_instance and libgodot_destroy_godot_instance entry points!"
else
  puts "ERROR: Could not load #{lib_name} or find entry points."
  exit 1
end
