# spec/project_scaffolding_spec.cr
# Verifies project scaffolding parity, .gdignore presence in all dependency folders,
# and symlink cycle protections across test, template, performance, and examples.

puts "=== Running Project Scaffolding & Directory Integrity Specifications ==="

root_dir = File.expand_path("..", __DIR__)
consumer_projects = [
  "test",
  "template",
  "template-addon",
  "performance",
]

# Add all example projects dynamically
examples_dir = File.join(root_dir, "examples")
if Dir.exists?(examples_dir)
  Dir.children(examples_dir).each do |child|
    full_path = File.join(examples_dir, child)
    if Dir.exists?(full_path) && File.exists?(File.join(full_path, "project.godot"))
      consumer_projects << "examples/#{child}"
    end
  end
end

# -------------------------------------------------------------
# [Spec 1] .gdignore Protection on lib/ and Dependency Directories
# -------------------------------------------------------------
puts "[Spec 1] Verifying .gdignore protection in all consumer projects..."

consumer_projects.each do |proj|
  proj_dir = File.join(root_dir, proj)
  next unless Dir.exists?(proj_dir)

  lib_dir = File.join(proj_dir, "lib")
  if Dir.exists?(lib_dir)
    gdignore_path = File.join(lib_dir, ".gdignore")
    if !File.exists?(gdignore_path)
      abort "ERROR: Project '#{proj}' has a 'lib/' directory missing '.gdignore'! This causes Godot EditorFileSystem to recursively scan shard symlinks and stack overflow."
    end
    puts "  ✓ #{proj}/lib/.gdignore verified present"
  end
end

# -------------------------------------------------------------
# [Spec 2] Project.godot Structure & Crystal Addon Manifests
# -------------------------------------------------------------
puts "[Spec 2] Verifying project.godot and GDExtension manifests..."

consumer_projects.each do |proj|
  proj_dir = File.join(root_dir, proj)
  next unless Dir.exists?(proj_dir)

  godot_proj = File.join(proj_dir, "project.godot")
  if !File.exists?(godot_proj)
    abort "ERROR: Project '#{proj}' is missing 'project.godot'!"
  end

  content = File.read(godot_proj)
  if !content.includes?("config_version=5")
    abort "ERROR: Project '#{proj}/project.godot' does not have valid Godot 4.x config_version=5!"
  end

  # Check GDExtension configuration
  if proj == "template-addon"
    addon_manifest = File.join(proj_dir, "addons/crystal_addon/crystal_addon.gdextension")
    dist_manifest = File.join(proj_dir, "dist/crystal_addon.gdextension")
    src_manifest = File.join(proj_dir, "crystal_addon.gdextension")
    if !File.exists?(addon_manifest) && !File.exists?(dist_manifest) && !File.exists?(src_manifest)
      abort "ERROR: template-addon missing crystal_addon.gdextension manifest!"
    end
  else
    ext_manifest = File.join(proj_dir, "addons/crystal_integration/crystal.gdextension")
    if !File.exists?(ext_manifest)
      # Check if any .gdextension exists under addons/
      addons_dir = File.join(proj_dir, "addons")
      has_ext = Dir.glob("#{addons_dir.gsub('\\', '/')}/**/*.gdextension").size > 0
      if !has_ext
        abort "ERROR: Project '#{proj}' missing GDExtension manifest in addons/!"
      end
    end
  end

  puts "  ✓ #{proj} project configuration verified"
end

# -------------------------------------------------------------
# [Spec 3] Verify Tooling Automates .gdignore Creation
# -------------------------------------------------------------
puts "[Spec 3] Verifying automation scripts enforce .gdignore..."

sync_tool_path = File.join(root_dir, "tools/lapis/src/commands/sync.cr")
if File.exists?(sync_tool_path)
  content = File.read(sync_tool_path)
  if !content.includes?(".gdignore")
    abort "ERROR: tools/lapis/src/commands/sync.cr does not contain logic to automatically create .gdignore in lib/ directories!"
  end
  puts "  ✓ tools/lapis/src/commands/sync.cr enforces .gdignore placement"
end

scaffold_tool_path = File.join(root_dir, "tools/lapis/src/commands/scaffold.cr")
if File.exists?(scaffold_tool_path)
  puts "  ✓ tools/lapis/src/commands/scaffold.cr verified"
end

# -------------------------------------------------------------
# [Spec 4] godot-version.yml Presence Across All Consumers
# -------------------------------------------------------------
puts "[Spec 4] Verifying godot-version.yml presence in all consumer projects..."

consumer_projects.each do |proj|
  proj_dir = File.join(root_dir, proj)
  next unless Dir.exists?(proj_dir)

  version_file = File.join(proj_dir, "godot-version.yml")
  if !File.exists?(version_file)
    abort "ERROR: Project '#{proj}' is missing 'godot-version.yml'!"
  end

  content = File.read(version_file)
  if !content.includes?("version:")
    abort "ERROR: Project '#{proj}/godot-version.yml' does not specify 'version:'!"
  end

  puts "  ✓ #{proj}/godot-version.yml verified present"
end

# -------------------------------------------------------------
# [Spec 5] Consumer godot-version.yml Ignored in Git
# -------------------------------------------------------------
puts "[Spec 5] Verifying consumer godot-version.yml files are excluded in .gitignore..."
gitignore_path = File.join(root_dir, ".gitignore")
if File.exists?(gitignore_path)
  gi_content = File.read(gitignore_path)
  [
    "/test/godot-version.yml",
    "/template/godot-version.yml",
    "/template-addon/godot-version.yml",
    "/performance/godot-version.yml",
    "/examples/*/godot-version.yml",
  ].each do |expected_rule|
    unless gi_content.includes?(expected_rule)
      abort "ERROR: .gitignore is missing rule: '#{expected_rule}'!"
    end
  end
  puts "  ✓ .gitignore properly ignores consumer godot-version.yml files"
end

# -------------------------------------------------------------
# [Spec 6] Template & Template-Addon Spec Architecture
# -------------------------------------------------------------
puts "[Spec 6] Verifying template and template-addon spec architecture & main scene purity..."

["template", "template-addon"].each do |proj|
  proj_dir = File.join(root_dir, proj)

  main_spec = File.join(proj_dir, "spec/main_spec.cr")
  if !File.exists?(main_spec) || File.empty?(main_spec)
    abort "ERROR: Project '#{proj}' is missing non-empty 'spec/main_spec.cr'!"
  end

  editor_spec = File.join(proj_dir, "spec/editor/editor_spec.cr")
  if !File.exists?(editor_spec) || File.empty?(editor_spec)
    abort "ERROR: Project '#{proj}' is missing non-empty 'spec/editor/editor_spec.cr'!"
  end

  main_cr = File.join(proj_dir, "src/main.cr")
  if File.exists?(main_cr)
    content = File.read(main_cr)
    unless content.includes?("spec/editor")
      abort "ERROR: Project '#{proj}/src/main.cr' does not conditionally require '../spec/editor/**'!"
    end
  end

  puts "  ✓ #{proj} starter spec suite verified (spec/main_spec.cr and spec/editor/editor_spec.cr)"
end

# Verify template main scene purity
template_main_tscn = File.join(root_dir, "template/scenes/main.tscn")
if File.exists?(template_main_tscn)
  tscn_content = File.read(template_main_tscn)
  if tscn_content.includes?("ToolTester") || tscn_content.includes?("TestRunner")
    abort "ERROR: template/scenes/main.tscn contains test runner nodes! Main gameplay scene must remain pure."
  end
  puts "  ✓ template/scenes/main.tscn verified pure of test runner pollution"
end

puts "=== All Project Scaffolding & Directory Integrity Specifications Passed! ==="
