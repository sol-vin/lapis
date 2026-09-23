# =============================================================================
# LibGodot Test Suite: First-Class Crystal Scripts (.cr)
# =============================================================================

include Lapis::Test


{% if flag?(:release) %}
  test_script_first_class "Editor script integration cleanly stripped in release mode" do
    class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)
    assert_false class_db.call_bool("class_exists", "CrystalHighlighter"), "CrystalHighlighter must not be registered in release mode"
    assert_false class_db.call_bool("class_exists", "CrystalIntegrationPlugin"), "CrystalIntegrationPlugin must not be registered in release mode"
    assert_false class_db.call_bool("class_exists", "CrystalPanel"), "CrystalPanel must not be registered in release mode"
  end
{% else %}
  test_script_first_class "CrystalHighlighter pure-Crystal lexer tokenization" do
    # Test line with keywords, types, annotations, symbols, numbers, and comments
    line = "  @[Export(range: 1.0_f32..20.0_f32)] property speed : Float32 = 7.5_f32 # player speed"
    spans = Godot::CrystalHighlighter.highlight_line(line)
    assert_true spans.size > 0, "Highlighter should generate spans for annotated property"

    # Verify comment span exists at end
    comment_span = spans.find { |s| s.r == Godot::CrystalHighlighter::COLOR_COMMENT[0] && s.g == Godot::CrystalHighlighter::COLOR_COMMENT[1] }
    assert_true !comment_span.nil?, "Highlighter should detect and color line comments"

    # Test keyword line
    kw_line = "node Player < CharacterBody3D do"
    kw_spans = Godot::CrystalHighlighter.highlight_line(kw_line)
    assert_true kw_spans.size >= 2, "Highlighter should recognize 'node' and 'do' keywords"

    # Test string interpolation line
    str_line = %(  Godot.print("Hello \#{name}!"))
    str_spans = Godot::CrystalHighlighter.highlight_line(str_line)
    assert_true str_spans.size > 0, "Highlighter should color strings and string interpolation"
  end

  test_script_first_class "CrystalLanguage metadata, templates, and completions" do
    lang = Godot::CrystalLanguage.instance

    assert_eq lang.get_name, "Crystal"
    assert_eq lang.get_type, "CrystalScript"
    assert_eq lang.get_extension, "cr"
    assert_true lang.get_recognized_extensions.includes?("cr"), "Language recognized extensions should include 'cr'"

    res_words = lang.get_reserved_words
    assert_true res_words.includes?("node"), "Reserved words should include 'node'"
    assert_true res_words.includes?("property"), "Reserved words should include 'property'"
    assert_true res_words.includes?("signal"), "Reserved words should include 'signal'"
    assert_true res_words.includes?("def"), "Reserved words should include 'def'"
    assert_true res_words.includes?("end"), "Reserved words should include 'end'"

    assert_true lang.is_control_flow_keyword("if"), "'if' should be recognized as control flow"
    assert_true lang.is_control_flow_keyword("while"), "'while' should be recognized as control flow"
    assert_false lang.is_control_flow_keyword("node"), "'node' should not be control flow"

    # Test Template generation
    tmpl = lang.make_template("default", "EnemyBoss", "CharacterBody3D")
    assert_true tmpl.includes?("node EnemyBoss < CharacterBody3D do"), "Template should generate proper class header"
    assert_true tmpl.includes?("def _ready : Void"), "Template should contain _ready method"

    tool_tmpl = lang.make_template("tool", "LevelGenerator", "Node3D")
    assert_true tool_tmpl.includes?("@[Tool]"), "Tool template should have @[Tool] annotation"

    # Test Auto-indentation
    code_to_indent = "node Test do\ndef hello\nif true\n1\nend\nend\nend"
    indented = lang.auto_indent_code(code_to_indent, 0, 6)
    assert_true indented.includes?("  def hello"), "Auto-indent should indent inside 'do' block"
    assert_true indented.includes?("    if true"), "Auto-indent should indent inside 'def' block"

    # Test Completion proposals
    completions = lang.complete_code("", "res://test.cr")
    assert_true completions.any? { |c| c.display_text.includes?("node") }, "Completions should offer 'node' macro"
    assert_true completions.any? { |c| c.display_text.includes?("_ready") }, "Completions should offer '_ready' callback"
  end

  test_script_first_class "CrystalScript AST reflection and Inspector property extraction" do
    source = <<-CRYSTAL
      require "lapis"

      # Hero player character
      node HeroPlayer < CharacterBody2D do
        # Movement speed in px/s
        @[Export(range: 50.0_f32..800.0_f32, step: 10.0_f32)]
        property speed : Float32 = 250.0_f32

        @[Export]
        property player_name : String = "Hero"

        signal leveled_up(new_level : Int32)
        signal defeated

        def _ready : Void
        end

        def attack : Void
        end
      end
      CRYSTAL

    script = Godot::CrystalScript.new("res://hero_player.cr", source)

    assert_eq script.class_name, "HeroPlayer"
    assert_eq script.base_type, "CharacterBody2D"
    assert_eq script.signals.size, 2
    assert_true script.signals.includes?("leveled_up"), "Script should detect 'leveled_up' signal"
    assert_true script.signals.includes?("defeated"), "Script should detect 'defeated' signal"
    assert_true script.methods.includes?("_ready"), "Script should detect '_ready' method"
    assert_true script.methods.includes?("attack"), "Script should detect 'attack' method"

    # Inspector properties
    props = script.properties
    assert_true props.size >= 2, "Script should have at least 2 properties"

    speed_prop = props.find { |p| p.name == "speed" }
    assert_true !speed_prop.nil?, "Script should expose 'speed' property"
    if s = speed_prop
      assert_eq s.type_name, "Float32"
      assert_eq s.variant_type, 3 # TYPE_FLOAT
      assert_eq s.hint, 1_u32     # PROPERTY_HINT_RANGE
      assert_eq s.hint_string, "50.0,800.0,10.0"
    end

    name_prop = props.find { |p| p.name == "player_name" }
    assert_true !name_prop.nil?, "Script should expose 'player_name' property"
    if np = name_prop
      assert_eq np.type_name, "String"
      assert_eq np.variant_type, 4 # TYPE_STRING
    end
    script.destroy
  end

  test_script_first_class "ResourceFormatLoader and ResourceFormatSaver for .cr files" do
    loader = Godot::ResourceFormatLoaderCrystal.instance
    saver = Godot::ResourceFormatSaverCrystal.instance

    assert_true loader.get_recognized_extensions.includes?("cr"), "Loader recognizes .cr"
    assert_true loader.handles_type("Script"), "Loader handles Script type"
    assert_true loader.handles_type("CrystalScript"), "Loader handles CrystalScript type"
    assert_eq loader.get_resource_type("res://scripts/player.cr"), "CrystalScript"

    assert_true saver.recognize("CrystalScript"), "Saver recognizes CrystalScript"
    assert_true saver.get_recognized_extensions.includes?("cr"), "Saver recognizes .cr"

    # Test dynamic script saving and loading end-to-end in sandbox
    test_path = "user://test_dynamic_script.cr"
    test_code = <<-CRYSTAL
  require "lapis"

  node DynamicPlayer < CharacterBody2D do
    @[Export]
    property speed : Float32 = 250.0_f32

    @[Export]
    property max_health : Int32 = 100

    def _ready : Void
      Godot.print("DynamicPlayer ready!")
    end
  end
  CRYSTAL

    test_script = Godot::CrystalScript.new
    test_script.set_source_code(test_code)
    test_script.set_script_path(test_path)

    # Verify saver writes file
    save_err = saver.save(test_script, test_path)
    assert_eq save_err, 0_i32

    # Verify loader loads file
    loaded_script = loader.load(test_path, test_path)
    assert_true !loaded_script.nil?, "Loader should load #{test_path} successfully"
    if sc = loaded_script
      assert_eq sc.class_name, "DynamicPlayer"
      assert_eq sc.base_type, "CharacterBody2D"
      assert_true sc.properties.any? { |p| p.name == "speed" }, "Loaded script has 'speed' property"
      assert_true sc.properties.any? { |p| p.name == "max_health" }, "Loaded script has 'max_health' property"
    end

    # Cleanup
    test_script.unreference rescue nil

    # Clean up temporary test file from disk
    fs_path = Godot::ResourceFormatSaverCrystal.resolve_save_path(test_path)
    LibSystemIO.remove(fs_path.to_unsafe) if !fs_path.empty? && Godot::SystemIO.file_exists?(fs_path)
  end

  test_script_first_class "ResourceSaver engine singleton round-trip via GDExtension boundary" do
    rs_ptr = Godot::Bridge.get_singleton("ResourceSaver")
    rl_ptr = Godot::Bridge.get_singleton("ResourceLoader")
    assert_true !rs_ptr.null?, "ResourceSaver singleton must exist"
    assert_true !rl_ptr.null?, "ResourceLoader singleton must exist"

    r_saver = Godot::ResourceSaver.new(rs_ptr)
    r_loader = Godot::ResourceLoader.new(rl_ptr)

    test_script = Godot.create(Godot::CrystalScript)
    assert_true !test_script.nil?, "CrystalScript must be created"

    if script = test_script
      test_path = "user://test_engine_saver_roundtrip.cr"
      fs_path = Godot::ResourceFormatSaverCrystal.resolve_save_path(test_path)

      sample_code = <<-CRYSTAL
    require "lapis"

    node EngineTestNode < Node do
      @[Export]
      property test_val : Int32 = 42

      def _ready : Void
        Godot.print("EngineTestNode ready")
      end
    end
    CRYSTAL

      script.source_code = sample_code
      script.script_path = test_path

      begin
        # 1. Verify ResourceSaver recognize and save via engine singleton
        save_ret = r_saver.call_i64("save", script, test_path)
        assert_eq save_ret, 0_i64, "ResourceSaver.save via engine singleton should return OK (0)"

        # 2. Verify file written to disk
        assert_true Godot::SystemIO.file_exists?(fs_path), "File should be created on disk"
        disk_content = Godot::SystemIO.read_file(fs_path)
        assert_true disk_content.includes?("EngineTestNode"), "File content should contain EngineTestNode"

        # 3. Verify ResourceLoader loads the file via engine singleton
        loaded_res = r_loader.call_obj("load", test_path)
        assert_true !loaded_res.nil? && !loaded_res.pointer.null?, "ResourceLoader.load should return non-null object"
        if loaded_obj = loaded_res
          c_name = loaded_obj.call_str("get_class") rescue ""
          assert_eq c_name, "CrystalScript", "Loaded resource class should be CrystalScript"
        end
      ensure
        # Guaranteed sandbox cleanup
        LibSystemIO.remove(fs_path.to_unsafe) if !fs_path.empty? && Godot::SystemIO.file_exists?(fs_path)
      end
    end
  end

  test_script_first_class "Editor ScriptEditor lifecycle: set_source_code, save, reload and AST round-trip" do
    rs_ptr = Godot::Bridge.get_singleton("ResourceSaver")
    rl_ptr = Godot::Bridge.get_singleton("ResourceLoader")
    assert_true !rs_ptr.null?, "ResourceSaver singleton must exist"
    assert_true !rl_ptr.null?, "ResourceLoader singleton must exist"

    r_saver = Godot::ResourceSaver.new(rs_ptr)
    r_loader = Godot::ResourceLoader.new(rl_ptr)

    test_path = "user://test_editor_save_workflow.cr"
    fs_path = Godot::ResourceFormatSaverCrystal.resolve_save_path(test_path)

    initial_code = <<-CRYSTAL
  require "lapis"

  # Initial version of player script
  @[Tool]
  node EditorPlayer < CharacterBody2D do
    @[Export]
    property speed : Float32 = 200.0_f32

    @[Export]
    property max_hp : Int32 = 50

    signal health_changed(current : Int32)

    def _ready : Void
      Godot.print("EditorPlayer initial ready")
    end
  end
  CRYSTAL

    script = Godot.create(Godot::CrystalScript)
    assert_true !script.nil?, "CrystalScript instance should be created"

    if sc = script
      begin
        # 1. Simulate ScriptEditor initial creation: set source code and save
        sc.call("set_source_code", initial_code)
        sc.call("set_path", test_path) rescue nil
        sc.script_path = test_path

        save_ret = r_saver.call_i64("save", sc, test_path)
        assert_eq save_ret, 0_i64, "Initial save via ResourceSaver should succeed with 0"
        assert_true Godot::SystemIO.file_exists?(fs_path), "File should be created on disk"

        # 2. Verify ResourceLoader loads the script back with exact content
        loaded_res = r_loader.call_obj("load", test_path)
        assert_true !loaded_res.nil? && !loaded_res.pointer.null?, "ResourceLoader should load script"
        if l_obj = loaded_res
          code_on_disk = l_obj.call_str("get_source_code")
          assert_true code_on_disk.includes?("EditorPlayer initial ready"), "Loaded source should contain initial code"
          assert_true code_on_disk.includes?("speed : Float32 = 200.0_f32"), "Loaded source should contain speed property"
        end

        # 3. Simulate Editor modification: user edits code in script editor and presses Ctrl+S
        updated_code = <<-CRYSTAL
      require "lapis"

      # Updated version of player script with new properties
      @[Tool]
      node EditorPlayer < CharacterBody2D do
        @[Export]
        property speed : Float32 = 350.0_f32

        @[Export]
        property max_hp : Int32 = 100

        @[Export]
        property player_title : String = "Legendary Hero"

        signal health_changed(current : Int32)
        signal hero_level_up(new_level : Int32)

        def _ready : Void
          Godot.print("EditorPlayer updated ready")
        end
      end
      CRYSTAL

        sc.call("set_source_code", updated_code)
        save_ret2 = r_saver.call_i64("save", sc, test_path)
        assert_eq save_ret2, 0_i64, "Saving updated script over existing file should succeed with 0"

        # Verify updated content on disk
        disk_text = Godot::SystemIO.read_file(fs_path)
        assert_true disk_text.includes?("EditorPlayer updated ready"), "Disk file should contain updated code"
        assert_true disk_text.includes?(%(player_title : String = "Legendary Hero")), "Disk file should contain new property"
        assert_true disk_text.includes?("speed : Float32 = 350.0_f32"), "Disk file should contain updated speed"

        # 4. Direct load via ResourceFormatLoaderCrystal and verify AST metadata parsing
        loader = Godot::ResourceFormatLoaderCrystal.instance
        direct_loaded = loader.load(test_path, test_path)
        assert_true !direct_loaded.nil?, "Direct ResourceFormatLoaderCrystal.load should succeed"
        if d_sc = direct_loaded
          assert_eq d_sc.class_name, "EditorPlayer"
          assert_eq d_sc.base_type, "CharacterBody2D"
          assert_true d_sc.is_tool_script, "EditorPlayer should be recognized as tool script"
          assert_true d_sc.properties.any? { |p| p.name == "player_title" }, "Parsed metadata should include player_title"
          assert_true d_sc.signals.includes?("hero_level_up"), "Parsed metadata should include hero_level_up signal"
          d_sc.unreference rescue nil
        end
      ensure
        # Cleanup
        LibSystemIO.remove(fs_path.to_unsafe) if !fs_path.empty? && Godot::SystemIO.file_exists?(fs_path)
      end
    end
  end

  test_script_first_class "ResourceFormatSaver overwrite safety guard against truncation" do
    guard_path = "user://test_truncation_guard.cr"
    fs_path = Godot::ResourceFormatSaverCrystal.resolve_save_path(guard_path)
    initial_code = "# Valuable user code\nnode ImportantNode < Node do\nend\n"

    begin
      # Write initial content
      File.write(fs_path, initial_code)
      assert_true Godot::SystemIO.file_exists?(fs_path), "Initial file must exist"
      initial_size = Godot::SystemIO.file_size(fs_path)
      assert_true initial_size > 0, "Initial file size must be > 0"

      saver = Godot::ResourceFormatSaverCrystal.instance
      empty_script = Godot.create(Godot::CrystalScript)
      if s = empty_script
        s.source_code = "" # Empty code
        # Attempt to save empty code over existing file: must be rejected!
        err = saver.save(s, guard_path)
        assert_eq err, 1_i32, "Saver must refuse to overwrite existing content with empty source (ERR_FILE_CANT_WRITE)"

        # Verify content was NOT truncated
        current_content = Godot::SystemIO.read_file(fs_path)
        assert_eq current_content, initial_code, "File content must be preserved intact"
      end
    ensure
      LibSystemIO.remove(fs_path.to_unsafe) if !fs_path.empty? && Godot::SystemIO.file_exists?(fs_path)
    end
  end

  test_script_first_class "Editor script creation path adaptation and extension validation" do
    # Test extension replacement preserving directory structures
    dummy_paths = {
      "res://src/player.gd"            => "res://src/player.cr",
      "res://scripts/combat/enemy.cs"  => "res://scripts/combat/enemy.cr",
      "res://my.custom.dir/controller" => "res://my.custom.dir/controller.cr",
      "res://src/main.cr"              => "res://src/main.cr",
    }

    dummy_paths.each do |input, expected|
      new_txt = if input.ends_with?(".cr")
                  input
                else
                  dir = File.dirname(input)
                  base = File.basename(input)
                  ext = File.extname(base)
                  if !ext.empty?
                    "#{dir}/#{base.sub(/\.[^.]+$/, ".cr")}"
                  else
                    "#{input}.cr"
                  end
                end
      assert_eq new_txt, expected, "Path #{input} should adapt to #{expected}"
    end
  end

  test_script_first_class "Editor script linking, ClassRegistry script_path, and global class inspection" do
    # Test path normalization
    res_path = Godot.to_godot_res_path("src/libgodot.cr")
    assert_true res_path.starts_with?("res://"), "Path should normalize to res://"

    # Test ClassRegistry entries have script_path
    entries = Godot::ClassRegistry.entries
    assert_true entries.size > 0, "ClassRegistry should have registered entries"

    # Find an entry registered via the node macro
    tool_tester_entry = Godot::ClassRegistry.find("ToolTester2D")
    if entry = tool_tester_entry
      assert_true entry.script_path.starts_with?("res://"), "ToolTester2D script_path should start with res://"
      assert_true entry.script_path.ends_with?(".cr"), "ToolTester2D script_path should end with .cr"
    end

    # Test link_class_script attaching script to a node
    test_node = Godot.create(Godot::Node2D)
    if test_node
      entry = Godot::ClassRegistry.find("ToolTester2D")
      if entry && !entry.script_path.empty?
        script = Godot::ClassRegistry.get_or_load_script(entry.script_path, entry.class_name, entry.parent_name, entry.is_tool)
        assert_true !script.nil?, "Script cache should load script for entry"
        if script
          test_node.call("set_script", script)
          linked = test_node.call_obj("get_script")
          assert_true !linked.nil? && !linked.pointer.null?, "Node should have linked script"
        end
      end
      test_node.destroy
    end

    # Test CrystalLanguage.inspect_file_global_class
    source_snippet = <<-CRYSTAL
  node InspectTarget < CharacterBody3D do
    def _ready; end
  end
  CRYSTAL
    temp_path = "user://test_inspect_target.cr"
    fs_temp_path = Godot::ResourceFormatSaverCrystal.resolve_save_path(temp_path)
    File.write(fs_temp_path, source_snippet) rescue nil
    c_name, b_type, _icon = Godot::CrystalLanguage.inspect_file_global_class(temp_path)
    assert_eq c_name, "InspectTarget"
    assert_eq b_type, "CharacterBody3D"
    LibSystemIO.remove(fs_temp_path.to_unsafe) if File.exists?(fs_temp_path)

    # Non-.cr files must immediately return empty tuple without inspecting/regexing
    c_non_cr, _, _ = Godot::CrystalLanguage.inspect_file_global_class("res://icon.svg")
    assert_eq c_non_cr, ""

    # Files with invalid UTF-8 bytes (e.g. 0xfe, 0xff) must not crash PCRE2 regex
    temp_invalid_path = "user://test_invalid_utf8.cr"
    fs_invalid_path = Godot::ResourceFormatSaverCrystal.resolve_save_path(temp_invalid_path)
    # Write binary invalid UTF-8 bytes
    File.open(fs_invalid_path, "wb") { |f| f.write(Bytes[0xff, 0xfe, 0x41, 0x00, 0x42, 0x00]) } rescue nil
    c_invalid, _, _ = Godot::CrystalLanguage.inspect_file_global_class(temp_invalid_path)
    assert_eq c_invalid, ""
    LibSystemIO.remove(fs_invalid_path.to_unsafe) if File.exists?(fs_invalid_path)
  end

  test_script_first_class "ScriptEditor save simulation: unsaved script without path, set_path, and save via ResourceSaver" do
    rs_ptr = Godot::Bridge.get_singleton("ResourceSaver")
    rl_ptr = Godot::Bridge.get_singleton("ResourceLoader")
    assert_true !rs_ptr.null?, "ResourceSaver singleton must exist"
    assert_true !rl_ptr.null?, "ResourceLoader singleton must exist"

    r_saver = Godot::ResourceSaver.new(rs_ptr)
    r_loader = Godot::ResourceLoader.new(rl_ptr)

    # Create a fresh script with no path set initially (mimicking File -> New Script in Editor)
    new_script = Godot.create(Godot::CrystalScript)
    assert_true !new_script.nil?, "Fresh CrystalScript instance must be created"

    if sc = new_script
      test_path = "user://test_script_editor_unsaved_flow.cr"
      fs_path = Godot::ResourceFormatSaverCrystal.resolve_save_path(test_path)

      code = <<-CRYSTAL
    require "lapis"

    node UnsavedToSavedNode < Node2D do
      @[Export]
      property greeting : String = "Hello from ScriptEditor!"

      def _ready : Void
        Godot.print(greeting)
      end
    end
    CRYSTAL

      begin
        sc.source_code = code
        # Script initially has no path
        assert_eq sc.script_path, ""

        # User chooses destination in Save Dialog: script.script_path = test_path
        sc.script_path = test_path

        # Save via ResourceSaver.save(script, path)
        save_ret = r_saver.call_i64("save", sc, test_path)
        assert_eq save_ret, 0_i64, "Saving via ResourceSaver with target path should return OK (0)"
        assert_true Godot::SystemIO.file_exists?(fs_path), "File should be created on disk"

        # Also test saving with empty path string (ResourceSaver should resolve path from script itself)
        save_ret_empty = r_saver.call_i64("save", sc, "")
        assert_eq save_ret_empty, 0_i64, "Saving via ResourceSaver with empty path should resolve resource path and return OK (0)"

        # Reload and verify
        loaded = r_loader.call_obj("load", test_path)
        assert_true !loaded.nil? && !loaded.pointer.null?, "Script should be loadable"
        if l_obj = loaded
          src = l_obj.call_str("get_source_code")
          assert_true src.includes?("UnsavedToSavedNode"), "Loaded source must contain class name"
          assert_true src.includes?("Hello from ScriptEditor!"), "Loaded source must contain greeting"
        end
      ensure
        LibSystemIO.remove(fs_path.to_unsafe) if !fs_path.empty? && Godot::SystemIO.file_exists?(fs_path)
      end
    end
  end

  test_script_first_class "CrystalLanguage LSP and virtual _complete_code / _lookup_code integration" do
    lang = Godot::CrystalLanguage.instance
    lsp = Lapis::CrystalLSP.instance

    assert_true lsp.available?, "CrystalLSP should be discovered and available in dev environment"

    # Test complete_code proposal generation with Node DSL and Godot callbacks
    source_sample = <<-CRYSTAL
    node TestWarrior < CharacterBody3D do
      property armor : Int32 = 50
      signal shield_broken

      def block_attack : Void
      end
    end
    CRYSTAL

    items = lang.complete_code(source_sample, "res://warrior.cr")
    assert_true items.any? { |c| c.display_text == "armor" && c.kind_id == 4_i64 }, "Local property 'armor' should be completed with MemberVariable kind"
    assert_true items.any? { |c| c.display_text == "shield_broken" && c.kind_id == 2_i64 }, "Local signal 'shield_broken' should be completed with Signal kind"
    assert_true items.any? { |c| c.display_text == "block_attack()" && c.kind_id == 1_i64 }, "Local method 'block_attack()' should be completed with Function kind"
    assert_true items.any? { |c| c.display_text == "CharacterBody3D" && c.kind_id == 0_i64 }, "Godot engine class CharacterBody3D should be completed with Class kind"
    assert_true items.any? { |c| c.display_text.includes?("_physics_process") && c.kind_id == 1_i64 }, "Godot lifecycle callback _physics_process should be completed"

    # Test Bridge completion option C-ABI data layout
    c_opt = Godot::Bridge::BridgeCompletionOption.new(
      1_i64,
      "test_method".to_unsafe,
      "test_method()".to_unsafe,
      "".to_unsafe,
      0_i64
    )
    assert_eq c_opt.kind, 1_i64
    assert_eq c_opt.location, 0_i64
  end
{% end %}
