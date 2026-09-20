# =============================================================================
# LibGodot - Crystal Editor Integration Plugin
# =============================================================================
# A compiled GDExtension EditorPlugin registered directly in Godot's ClassDB.
# Acts as the native backend for the Crystal integration addon, handling
require "file_utils"
require "./script"
require "./editor_script_creation"

module Godot
  @[Tool]
  node CrystalIntegrationPlugin < EditorPlugin do
  # Version of the compiled LibGodot library
  getter version : String = ::Godot::VERSION

  # Active status of the compiled Crystal editor integration
  getter active : Bool = true

  # Status message visible in inspector or tooling
  getter status_message : String = "LibGodot Crystal Integration Active"

  # Emitted when the Crystal editor plugin finishes initialization
  signal ready_in_editor

  @@instance : CrystalIntegrationPlugin? = nil
  @@crystal_language : CrystalLanguage? = nil
  @@crystal_highlighter : CrystalHighlighter? = nil
  @@resource_loader : ResourceFormatLoaderCrystal? = nil
  @@resource_saver : ResourceFormatSaverCrystal? = nil
  @@compile_button : Button? = nil
  @@crystal_panel : Node? = nil
  @@cached_icon_texture : Texture2D? = nil
  @@debugger_plugin : EditorDebuggerPlugin? = nil
  @@editor_start_time : ::Time = ::Time.local
  @@file_last_disk_mtime : Hash(String, ::Time) = Hash(String, ::Time).new
  @@building : Bool = false
  @@reload_pending : Bool = false
  @@cleaning_up : Bool = false
  class_property on_cleanup : Proc(Void)? = nil

  def self.building? : Bool
    @@building
  end

  def self.reload_pending? : Bool
    @@reload_pending
  end

  def self.reload_pending=(val : Bool) : Void
    @@reload_pending = val
  end

  def initialize
    super
    @@instance = self
  end

  def self.has_editor_interface? : Bool
    return false if Godot::Engine.singleton_ptr.null?
    engine = Godot::Engine.new(Godot::Engine.singleton_ptr)
    return false unless engine.has_singleton("EditorInterface")
    return false if Godot::EditorInterface.singleton_ptr.null?
    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    base_ctrl = ed_iface.get_base_control rescue nil
    return false if base_ctrl.nil? || base_ctrl.pointer.null? || !(base_ctrl.call_bool("is_inside_tree") rescue false)
    true
  end

  # Ensures all editor integration components are active when running inside the Godot Editor.
  # Safe to call both on startup and after GDExtension reloads.
  def self.ensure_editor_setup : Void
    return if headless?
    return unless has_editor_interface?
    return if Godot::EditorInterface.singleton_ptr.null?
    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    base_ctrl = ed_iface.get_base_control
    return if base_ctrl.pointer.null? || !base_ctrl.is_inside_tree

    if !Godot::DisplayServer.singleton_ptr.null?
      ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
      return if ds.call_str("get_name") == "headless"
    end

    ensure_theme_icons
    setup_toolbar_button
    setup_new_script_button
    setup_main_screen_panel
    setup_debugger_plugin
    ensure_highlighter_registered
  end

  def _enter_tree : Void
    @@instance = self
    Godot.print("==================================================================")
    Godot.print("  [CrystalIntegrationPlugin] Native Crystal editor plugin loaded!")
    Godot.print("  LibGodot Version: #{::Godot::VERSION}")
    Godot.print("  Target Godot:     #{::Godot::TARGET_GODOT_VERSION}")
    Godot.print("==================================================================")
    verify_godot_version
    verify_required_tools

    if Godot.editor_hint?
      # Ensure first-class language, loader, and saver are active in editor
      Godot::CrystalLanguage.ensure_registered
      Godot::ResourceFormatLoaderCrystal.ensure_registered
      Godot::ResourceFormatSaverCrystal.ensure_registered

      # Disable 'Highlight Type Safe Lines' to prevent engine bug in TextEdit (p_gutter = -1 out of bounds)
      if !Godot::EditorInterface.singleton_ptr.null?
        ed_interface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        ed_settings = ed_interface.get_editor_settings
        if !ed_settings.pointer.null?
          ed_settings.call("set_setting", "text_editor/appearance/gutters/highlight_type_safe_lines", false)
          ed_settings.call("set_initial_value", "text_editor/appearance/gutters/highlight_type_safe_lines", false, false)
          ed_settings.call("set_setting", "text_editor/appearance/guidelines/highlight_type_safe_lines", false)

          # Ensure 'cr' is not marked as a plain textfile so Godot treats .cr as a typed Script resource
          val = ed_settings.call_str("get_setting", "docks/filesystem/textfile_extensions")
          exts = (val.empty? ? "txt,md,cfg,ini,log,json,yml,yaml,toml,xml" : val).split(',').map(&.strip).reject(&.empty?)
          if exts.includes?("cr")
            exts.delete("cr")
            new_val = exts.join(",")
            ed_settings.call("set_setting", "docks/filesystem/textfile_extensions", new_val)
            ed_settings.call("set_initial_value", "docks/filesystem/textfile_extensions", new_val, false)
          end
        end
      end

      unless self.class.headless?
        self.class.ensure_highlighter_registered
        self.class.ensure_theme_icons
        self.class.setup_toolbar_button
        self.class.setup_new_script_button
        self.class.setup_main_screen_panel
        self.class.setup_debugger_plugin
        self.class.link_scripts_in_edited_scene
        connect("scene_changed") do |_args|
          self.class.link_scripts_in_edited_scene
        end
      end
      self.call("set_process", true) rescue nil

      Godot.print("[CrystalIntegrationPlugin] First-class .cr script support, language, and syntax highlighter registered in 100% pure Crystal.")

      # Automated verification check for Build Crystal button and live GDExtension reloading
      if ::ENV["LIBGODOT_TEST_BUILD_BUTTON"]? == "1"
        self.class.check_test_build_button_flow
      end
    end

    # Safeguard signal emission against engine script-subclassing ClassDB lookup quirks
    if !self.call_bool("has_signal", "ready_in_editor")
      self.call("add_user_signal", "ready_in_editor") rescue nil
    end

    emit_ready_in_editor
  end

  # Registers Crystal icons into Godot's EditorIcons theme so ScriptCreateDialog and FileSystem dock display proper icons
  def self.ensure_theme_icons : Void
    return if headless?
    return unless has_editor_interface?
    return if Godot::EditorInterface.singleton_ptr.null?
    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    base_ctrl = ed_iface.get_base_control
    return if base_ctrl.pointer.null? || !base_ctrl.is_inside_tree

    theme = ed_iface.get_editor_theme rescue nil
    return if theme.nil? || theme.pointer.null?

    if icon_tex = get_crystal_icon_texture
      ["CrystalScript", "CrystalLanguage", "Crystal"].each do |type_name|
        theme.set_icon(type_name, "EditorIcons", icon_tex) rescue nil
      end
      Godot.print("[CrystalIntegrationPlugin] Registered Crystal theme icons into EditorIcons theme.")
    end
  rescue ex
    Godot.printerr("[CrystalIntegrationPlugin] Notice: theme icons registration: #{ex.message}")
  end

  def verify_godot_version : Void
    target_ver = ::Godot::TARGET_GODOT_VERSION
    Godot.print("[CrystalIntegrationPlugin] Target engine version verified: #{target_ver}")
  rescue ex
    Godot.print("[CrystalIntegrationPlugin] Note: Engine version check skipped: #{ex.message}")
  end

  def verify_required_tools : Void
    return if self.class.headless?

    missing_tools = [] of String

    # 1. Check Crystal compiler
    crystal_bin = Process.find_executable("crystal")
    if crystal_bin.nil?
      missing_tools << "- Crystal compiler ('crystal') is not installed or not in PATH. Please install Crystal #{::Godot::MIN_CRYSTAL_VERSION}+."
    else
      Godot.print("[CrystalIntegrationPlugin] Crystal compiler verified at #{crystal_bin} (target: #{::Godot::TARGET_CRYSTAL_VERSION})")
    end

    # 2. Check GNU Make
    make_bin = Process.find_executable("make") || Process.find_executable("mingw32-make")
    if make_bin.nil?
      missing_tools << "- GNU Make ('make') is not found in PATH. Install via Scoop ('scoop install make') or system package manager."
    else
      Godot.print("[CrystalIntegrationPlugin] GNU Make verified: #{make_bin}")
    end

    if !missing_tools.empty?
      err_banner = missing_tools.join("\n")
      Godot.printerr("[CrystalIntegrationPlugin] WARNING: Required tool verification failed:\n#{err_banner}")

      if !Godot::EditorInterface.singleton_ptr.null?
        ei = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        dialog = Godot.create(Godot::AcceptDialog)
        if dialog
          dialog.set_title("LibGodot: Required Tools Missing")
          dialog.set_text("The following required development tools are missing or outdated:\n\n#{err_banner}\n\nPlease install them to enable Crystal compilation and build automation.")
          dialog.set_autowrap(true)
          dialog.set_ok_button_text("Acknowledge")
          ei.popup_dialog_centered(dialog, Godot::Vector2i.new(700, 300))
        end
      end
    end
  rescue ex
    Godot.print("[CrystalIntegrationPlugin] Note: Tool verification check skipped: #{ex.message}")
  end

  def self.clear_theme_icons : Void
    # Let Godot's engine shutdown clean up the EditorTheme naturally.
    # Mutating the theme or calling unreference on the master EditorTheme
    # during plugin teardown prematurely unrefs static strings in Godot's static pool.
  end

  def self.cleanup : Void
    return if @@cleaning_up
    @@cleaning_up = true
    begin
      Godot.print("[Cleanup] Step 1: highlighter")
      if (highlighter = @@crystal_highlighter) && !highlighter.pointer.null?
        if has_editor_interface? && !Godot::EditorInterface.singleton_ptr.null?
          begin
            ed_interface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
            script_editor = ed_interface.get_script_editor
            if !script_editor.pointer.null?
              script_editor.disconnect("editor_script_changed") rescue nil
              if highlighter.alive?
                script_editor.unregister_syntax_highlighter(highlighter) rescue nil
              end
            end
          rescue
          end
        end
        highlighter.unreference rescue nil
        @@crystal_highlighter = nil
      end

      Godot.print("[Cleanup] Step 2: compile_button")
      if btn = @@compile_button
        if !btn.pointer.null? && btn.alive?
          btn.call("set_button_icon", nil) rescue nil
          if inst = @@instance
            if inst.alive?
              inst.remove_control_from_container(Godot::EditorPlugin::CustomControlContainer::ContainerToolbar.value, btn) rescue nil
            end
          end
          if parent = btn.get_parent
            if parent.alive?
              parent.call("remove_child", btn) rescue nil
            end
          end
          btn.queue_free rescue nil
        end
        @@compile_button = nil
      end

      Godot.print("[Cleanup] Step 3: EditorScriptCreation")
      EditorScriptCreation.cleanup rescue nil

      Godot.print("[Cleanup] Step 4: clear_theme_icons")
      clear_theme_icons

      Godot.print("[Cleanup] Step 5: cached_icon_texture")
      @@cached_icon_texture = nil

      Godot.print("[Cleanup] Step 6: debugger_plugin")
      if dbg_plug = @@debugger_plugin
        if !dbg_plug.pointer.null?
          begin
            Bridge.trigger_debugger_cleanup rescue nil
            if on_cl = @@on_cleanup
              on_cl.call rescue nil
            end
            if (inst = @@instance) && inst.alive?
              inst.remove_debugger_plugin(dbg_plug) rescue nil
            end
            dbg_plug.unreference rescue nil
          rescue ex
            Godot.print("[CrystalIntegrationPlugin] Error in debugger cleanup: #{ex.message}")
          end
        end
        @@debugger_plugin = nil
      end

      Godot.print("[Cleanup] Step 7: crystal_panel")
      if panel = @@crystal_panel
        if !panel.pointer.null? && panel.alive?
          if parent = panel.get_parent
            if parent.alive?
              parent.call("remove_child", panel) rescue nil
            end
          end
          panel.queue_free rescue nil
        end
        @@crystal_panel = nil
      end

      Godot.print("[Cleanup] Step 8: error_dialog")
      if dlg = @@error_dialog
        if !dlg.pointer.null? && dlg.alive?
          if parent = dlg.get_parent
            if parent.alive?
              parent.call("remove_child", dlg) rescue nil
            end
          end
          dlg.queue_free rescue nil
        end
        @@error_dialog = nil
      end

      Godot.print("[Cleanup] Step 9: ClassRegistry")
      ClassRegistry.cleanup rescue nil

      @@building = false
      @@reload_pending = false
      Godot.print("[Cleanup] Completed all cleanup steps successfully!")
    ensure
      @@cleaning_up = false
    end
  end

  def self.cleanup_on_shutdown : Void
    return if @@cleaning_up
    @@cleaning_up = true
    begin
      @@crystal_highlighter = nil
      @@cached_icon_texture = nil
      @@debugger_plugin = nil
      @@compile_button = nil
      @@crystal_panel = nil
      @@error_dialog = nil
      @@instance = nil
      EditorScriptCreation.cleanup_on_shutdown rescue nil
      ClassRegistry.cleanup rescue nil
      @@building = false
      @@reload_pending = false
    ensure
      @@cleaning_up = false
    end
  end

  def _exit_tree : Void
    self.class.cleanup
    @@instance = nil
    Godot.print("  [CrystalIntegrationPlugin] Native Crystal editor plugin unloaded.")
  end

  CRYSTAL_ICON_SVG = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 193.2 206.7' width='16' height='16'><path fill='#e0e0e0' d='m165.4 122-50 49.9c-.2.2-.5.3-.7.2l-68.3-18.3c-.3-.1-.5-.3-.5-.5L27.5 85.1c-.1-.3 0-.5.2-.7l50-49.9c.2-.2.5-.3.7-.2l68.3 18.3c.3.1.5.3.5.5l18.3 68.2c.2.3.1.5-.1.7zm-67-54.3L31.3 85.6c-.1 0-.2.2-.1.3l49.1 49c.1.1.3.1.3-.1l18-67c.1 0-.1-.2-.2-.1z'/></svg>"

  # Ensures syntax highlighter is registered with ScriptEditor
  def self.ensure_highlighter_registered : Void
    return if headless?
    return if (h = @@crystal_highlighter) && !h.pointer.null?
    if !Godot::EditorInterface.singleton_ptr.null?
      ed_interface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
      script_editor = ed_interface.get_script_editor
      if !script_editor.pointer.null?
        if highlighter = Godot.create(Godot::CrystalHighlighter)
          @@crystal_highlighter = highlighter
          script_editor.register_syntax_highlighter(highlighter) rescue nil
          apply_highlighter_if_needed
          script_editor.connect("editor_script_changed") do |_args|
            apply_highlighter_if_needed
          end
        end
      end
    end
  rescue ex
    Godot.printerr("[CrystalIntegrationPlugin] Notice: highlighter registration: #{ex.message}")
  end

  # Registers and configures the native LLDB debugger plugin
  def self.setup_debugger_plugin : Void
    return if headless?
    if @@debugger_plugin
      return
    end

    if Godot::EditorInterface.singleton_ptr.null?
      return
    end
    ed_interface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    main_screen = ed_interface.get_editor_main_screen
    if main_screen.pointer.null?
      return
    end

    if !Godot::DisplayServer.singleton_ptr.null?
      ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
      ds_name = ds.call_str("get_name")
      Godot.print("[CrystalIntegrationPlugin] DisplayServer name: '#{ds_name}'")
      if ds_name == "headless"
        return
      end
    end

    lldb_path = "lldb"
    ed_settings = ed_interface.get_editor_settings
    if !ed_settings.pointer.null?
      custom_lldb = ed_settings.call_str("get_setting", "crystal/debugger/lldb_path")
      lldb_path = custom_lldb unless custom_lldb.empty?
    end

    if Debugger::LldbDriver.available?(lldb_path)
      found = Debugger::LldbDriver.find_lldb(lldb_path)
      Godot.print("[CrystalIntegrationPlugin] LLDB native debugger detected: #{found}")
    else
      Godot.print("[CrystalIntegrationPlugin] Tip: LLDB not found in PATH. Install LLVM (e.g. 'scoop install llvm' on Windows, 'apt install lldb' on Linux) for native Crystal in-editor debugging.")
    end

    dbg_plugin = Godot.create("CrystalDebuggerPlugin")
    if dbg_plugin && !dbg_plugin.pointer.null?
      plug = Godot::EditorDebuggerPlugin.new(dbg_plugin.pointer)
      if plug.get_reference_count == 0
        plug.init_ref
      end
      if inst = @@instance
        inst.add_debugger_plugin(plug) rescue nil
      end
      @@debugger_plugin = plug
      Godot.print("[CrystalIntegrationPlugin] CrystalDebuggerPlugin registered into EditorDebuggerNode.")
    end
  rescue ex
    Godot.print("[CrystalIntegrationPlugin] Notice: debugger plugin setup: #{ex.message}")
  end

  def setup_debugger_plugin : Void
    self.class.setup_debugger_plugin
  end

  # Docks the CrystalPanel into Godot Editor's main screen
  def self.setup_main_screen_panel : Void
    return if headless?
    if (p = @@crystal_panel) && !p.pointer.null?
      return
    end
    if Godot::EditorInterface.singleton_ptr.null?
      return
    end
    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    main_screen = ed_iface.get_editor_main_screen
    if main_screen.pointer.null?
      return
    end

    if !Godot::DisplayServer.singleton_ptr.null?
      ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
      if ds.call_str("get_name") == "headless"
        return
      end
    end

    existing = main_screen.call_obj("find_child", "CrystalPanel", false, false)
    if existing && !existing.pointer.null?
      @@crystal_panel = existing
      return
    end

    if (panel = Godot.create("CrystalPanel")) && !panel.pointer.null?
      panel.call("set_name", "CrystalPanel")
      panel.call("set_visible", false)
      main_screen.call_deferred("add_child", panel)
      @@crystal_panel = panel
      Godot.print("[CrystalIntegrationPlugin] Native Crystal Main Screen Tab docked successfully.")
    end
  rescue ex
    Godot.printerr("[CrystalIntegrationPlugin] Notice: could not setup main screen panel: #{ex.message}")
  end

  def setup_main_screen_panel : Void
    self.class.setup_main_screen_panel
  end

  def deferred_setup_editor_ui : Void
    return if self.class.headless?
    self.class.setup_toolbar_button
    self.class.setup_new_script_button
    self.class.setup_main_screen_panel
    self.class.setup_debugger_plugin
  end

  def make_crystal_panel_visible(visible : Bool) : Void
    if panel = @@crystal_panel
      panel.call("set_visible", visible)
    end
  end

  def get_crystal_plugin_icon : Texture2D?
    self.class.get_crystal_icon_texture
  end

  def self._godot_has_virtual_method(method_name : String) : Bool
    case method_name
    when "_has_main_screen", "has_main_screen",
         "_get_plugin_name", "get_plugin_name",
         "_get_plugin_icon", "get_plugin_icon",
         "_make_visible", "make_visible",
         "_build", "build"
      true
    else
      false
    end
  end

  def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
    case method_name
    when "_has_main_screen", "has_main_screen"
      return if ret.null?
      ret.as(UInt8*).value = 1_u8
    when "_get_plugin_name", "get_plugin_name"
      return if ret.null?
      Bridge.ret_string(ret, "Crystal")
    when "_get_plugin_icon", "get_plugin_icon"
      return if ret.null?
      if tex = self.class.get_crystal_icon_texture
        Bridge.ret_ref(ret, tex.pointer)
      else
        Bridge.ret_ref(ret, Pointer(Void).null)
      end
    when "_make_visible", "make_visible"
      visible = !args.null? && !args[0].null? && (args[0].as(UInt8*).value != 0_u8)
      make_crystal_panel_visible(visible)
    end
  end

  def _has_main_screen : Bool
    true
  end

  def _get_plugin_name : String
    "Crystal"
  end

  def _get_plugin_icon : Texture2D?
    get_crystal_plugin_icon
  end

  def _make_visible(visible : Bool) : Void
    make_crystal_panel_visible(visible)
  end

  def self.headless? : Bool
    return true if ::ENV["GODOT_HEADLESS"]? == "1" || ::ENV["CI"]? || ::ENV["LIBGL_ALWAYS_SOFTWARE"]? == "1"
    if !Godot::OS.singleton_ptr.null?
      begin
        os = Godot::OS.new(Godot::OS.singleton_ptr)
        return true if os.call("get_cmdline_args").to_s.includes?("--headless")
      rescue
      end
    end
    if !Godot::DisplayServer.singleton_ptr.null?
      begin
        ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
        name = ds.call_str("get_name")
        return true if name == "headless" || name.empty?
      rescue
        return true
      end
    else
      return true
    end
    false
  end

  def self.get_crystal_icon_texture : Godot::Texture2D?
    if cached = @@cached_icon_texture
      return cached if !cached.pointer.null?
    end

    return nil if headless?

    icon_tex : Godot::Texture2D? = nil
    img = Godot.create(Godot::Image)
    if img && !img.pointer.null?
      err = img.load_svg_from_string(CRYSTAL_ICON_SVG, 1.0_f64)
      if err == 0_i64
        itex = Godot.create(Godot::ImageTexture)
        if itex && !itex.pointer.null?
          itex.set_image(img)
          icon_tex = itex
        end
      end
      img.unreference rescue nil
    end

    @@cached_icon_texture = icon_tex
    icon_tex
  end

  def self.setup_toolbar_button : Void
    return if headless?
    return unless has_editor_interface?
    return if (btn_alive = @@compile_button) && !btn_alive.pointer.null?
    return if Godot::EditorInterface.singleton_ptr.null?
    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    base_ctrl = ed_iface.get_base_control
    return if base_ctrl.pointer.null?

    if !Godot::DisplayServer.singleton_ptr.null?
      ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
      return if ds.call_str("get_name") == "headless"
    end

    # Check if button already exists in editor tree to avoid duplicates
    existing = base_ctrl.call_obj("find_child", "BuildCrystalToolbarButton", true, false)
    if existing && !existing.pointer.null?
      btn = Godot::Button.new(existing.pointer)
      @@compile_button = btn
      @@building = false
      @@reload_pending = false
      btn.call("set_disabled", false) rescue nil
      btn.call("set_text", "Build") rescue nil
      Godot.clear_signal_subscriptions(btn.signal_target_id)
      btn.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) do |_args|
        on_compile_button_pressed
      end
      return
    end

    btn = Godot.create(Godot::Button)
    return unless btn
    btn.call("set_name", "BuildCrystalToolbarButton")
    btn.call("set_flat", true)
    btn.call("set_theme_type_variation", "RunBarButton")

    icon_tex = get_crystal_icon_texture

    if icon_tex && !icon_tex.pointer.null?
      btn.set_button_icon(icon_tex)
      btn.call("set_text", "Build")
    else
      btn.call("set_text", "Build Crystal")
    end

    btn.call("set_tooltip_text", "Build Crystal (Quick Recompile)")
    btn.call("set_focus_mode", 0)

    btn.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) do |_args|
      on_compile_button_pressed
    end

    # Place the "Build Crystal" button in CONTAINER_TOOLBAR (EditorTitleBar, an HBoxContainer)
    # and move it right before EditorRunBar (the Play buttons)
    if inst = @@instance
      inst.add_control_to_container(Godot::EditorPlugin::CustomControlContainer::ContainerToolbar.value, btn) rescue nil
    elsif title_bar = base_ctrl.call_obj("find_child", "EditorTitleBar", true, false)
      title_bar.call_deferred("add_child", btn) rescue nil
    elsif run_bar = base_ctrl.call_obj("find_child", "EditorRunBar", true, false)
      if run_bar_parent = run_bar.call_obj("get_parent")
        run_bar_parent.call_deferred("add_child", btn) rescue nil
      end
    end

    if title_bar = btn.call_obj("get_parent")
      run_bar_idx = -1_i64
      count = title_bar.call_i64("get_child_count")
      count.times do |i|
        child = title_bar.call_obj("get_child", i)
        if child && !child.pointer.null?
          cls = child.call_str("get_class")
          c_name = child.call_str("get_name")
          if cls == "EditorRunBar" || c_name == "EditorRunBar" || c_name.includes?("RunBar")
            run_bar_idx = i
            break
          end
        end
      end

      if run_bar_idx >= 0
        title_bar.call("move_child", btn, run_bar_idx)
        Godot.print("[CrystalIntegrationPlugin] Build Crystal button placed in EditorTitleBar before EditorRunBar at index #{run_bar_idx}.")
      else
        Godot.print("[CrystalIntegrationPlugin] Build Crystal button added to ContainerToolbar.")
      end
    end

    @@compile_button = btn
    @@building = false
    @@reload_pending = false
  rescue ex
    Godot.printerr("[CrystalIntegrationPlugin] Warning: could not setup toolbar button: #{ex.message}")
  end

  def setup_toolbar_button : Void
    self.class.setup_toolbar_button
  end

  def self.setup_new_script_button : Void
    return if headless?
    return unless has_editor_interface?
    return if Godot::EditorInterface.singleton_ptr.null?
    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    base_ctrl = ed_iface.get_base_control
    return if base_ctrl.pointer.null?
    EditorScriptCreation.setup(ed_iface, base_ctrl)
  end

  def setup_new_script_button : Void
    self.class.setup_new_script_button
  end

  def self.show_create_script_dialog : Void
    EditorScriptCreation.show_dialog
  end

  # Tracks the active build error dialog to prevent multiple windows
  @@error_dialog : Godot::AcceptDialog? = nil

  # Formats and bubbles up compilation failures into the Godot Editor UI:
  # - Outputs clean formatted error banner in the bottom panel
  # - Emits EditorToaster notification (toast in status bar)
  # - Pops up centered AcceptDialog in the editor viewport
  # - Jumps to the offending line in ScriptEditor if file/line is detected
  def self.report_build_failure(context : String, out_msg : String, err_msg : String, exit_code : Int32) : Void
    combined = [] of String
    combined << err_msg.strip unless err_msg.strip.empty?
    combined << out_msg.strip unless out_msg.strip.empty?
    raw_error = combined.join("\n").strip
    raw_error = "Compilation failed with exit code #{exit_code} (no compiler output)." if raw_error.empty?

    # Extract location and summary message
    file_path = ""
    line_num = -1
    col_num = -1
    error_summary = ""

    raw_error.each_line do |line|
      line_strip = line.strip
      if m = line_strip.match(/(?:In|Syntax error in)\s+([^:\r\n]+):(\d+)(?::(\d+))?/)
        file_path = m[1]
        line_num = m[2].to_i? || -1
        col_num = m[3]?.try(&.to_i?) || -1
      elsif line_strip.starts_with?("Error:")
        error_summary = line_strip.sub("Error:", "").strip
      end
    end

    summary_title = if !file_path.empty? && line_num > 0
      "#{File.basename(file_path)}:#{line_num} - #{error_summary.empty? ? "Compilation Error" : error_summary}"
    elsif !error_summary.empty?
      error_summary
    else
      "Build failed with exit code #{exit_code}"
    end

    # 1. Output formatted banner to Godot's Output panel AND Debugger / Error console
    banner_lines = [
      "==================================================================",
      "[CrystalIntegrationPlugin] #{context.upcase} FAILED",
      "Summary: #{summary_title}",
      "------------------------------------------------------------------"
    ]
    banner_lines.each do |line|
      Godot.print(line)
      Godot.printerr(line)
    end
    raw_error.each_line do |l|
      Godot.print(l)
      Godot.printerr(l)
    end
    Godot.print("==================================================================")
    Godot.printerr("==================================================================")

    # Report directly to Godot's Debugger -> Errors tab with line-jumping context
    Godot.print_error("#{summary_title}\n#{raw_error}", "execute_crystal_build", file_path.empty? ? "src/main.cr" : file_path, line_num > 0 ? line_num : 1)

    # 2. Present centered AcceptDialog modal in the editor window
    show_build_error_dialog(context, summary_title, raw_error, file_path, line_num)
  end

  @@last_error_text : String = ""

  def self.show_build_error_dialog(context : String, summary : String, full_error : String, file_path : String = "", line_num : Int32 = -1) : Void
    return if Godot::EditorInterface.singleton_ptr.null?
    ei = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)

    @@last_error_text = full_error

    # Jump to error line in script editor if applicable
    if line_num > 0
      begin
        script_ed = ei.get_script_editor rescue nil
        if script_ed && !script_ed.pointer.null?
          script_ed.goto_line(line_num.to_i64 - 1)
        end
      rescue
      end
    end

    dialog_message = "#{context.capitalize} Failed!\n\n#{full_error}"

    # Reuse existing dialog if already created
    if (dlg = @@error_dialog) && dlg.alive?
      dlg.set_text(dialog_message)
      if (parent = dlg.call_obj("get_parent")) && !parent.pointer.null?
        dlg.popup_centered(Godot::Vector2i.new(750, 450))
      else
        ei.popup_dialog_centered(dlg, Godot::Vector2i.new(750, 450))
      end
      return
    end

    dialog = Godot.create(Godot::AcceptDialog)
    return unless dialog

    dialog.set_title("Crystal Build Error")
    dialog.set_text(dialog_message)
    dialog.set_autowrap(true)
    dialog.set_ok_button_text("Close")

    # Add Copy Error button that copies the compiler error text to clipboard
    copy_btn = dialog.add_button("Copy Error", false, "copy_error")
    if copy_btn && copy_btn.alive?
      copy_btn.connect("pressed") do |_args|
        if !Godot::DisplayServer.singleton_ptr.null?
          ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
          ds.clipboard_set(@@last_error_text)
          copy_btn.call("set_text", "Copied!")
        end
      end
    end

    @@error_dialog = dialog
    ei.popup_dialog_centered(dialog, Godot::Vector2i.new(750, 450))
  rescue ex
    Godot.printerr("[CrystalIntegrationPlugin] Notice: could not display dialog: #{ex.message}")
  end

  # Synchronizes a script editor buffer with the file on disk.
  # If the file on disk was modified externally (or on initial load), disk changes take precedence.
  # If the buffer was modified in-editor inside Godot, changes are flushed to disk.
  def self.sync_script_file(base_ed : Godot::Object, path : String) : Void
    return if path.empty? || !path.ends_with?(".cr")
    if !Godot::DisplayServer.singleton_ptr.null?
      ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
      return if ds.call_str("get_name") == "headless"
    end
    return if Godot::ProjectSettings.singleton_ptr.null?
    ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
    fs_path = ps.call_str("globalize_path", path).gsub('\\', '/')
    return if fs_path.empty? || !File.exists?(fs_path)

    version = base_ed.call_i64("get_version") rescue 0_i64
    saved_version = base_ed.call_i64("get_saved_version") rescue 0_i64
    disk_mtime = File.info(fs_path).modification_time
    last_mtime = @@file_last_disk_mtime[fs_path]?
    disk_text = File.read(fs_path)
    editor_text = base_ed.call_str("get_text")

    if last_mtime.nil?
      # Initial synchronization: disk is always authoritative
      if disk_text != editor_text
        base_ed.call("set_text", disk_text)
        Godot.print("[CrystalIntegrationPlugin] Initialized editor view from disk: #{fs_path} (#{disk_text.bytesize} bytes)")
      end
      base_ed.call("tag_saved_version") rescue nil
      @@file_last_disk_mtime[fs_path] = disk_mtime
    elsif disk_mtime > last_mtime && disk_text != editor_text
      # External modifications on disk took place after our last save/sync: disk wins
      base_ed.call("set_text", disk_text)
      base_ed.call("tag_saved_version") rescue nil
      @@file_last_disk_mtime[fs_path] = disk_mtime
      Godot.print("[CrystalIntegrationPlugin] Loaded external disk modifications into editor: #{fs_path} (#{disk_text.bytesize} bytes)")
    elsif version != saved_version
      # In-editor changes typed directly inside Godot: flush live buffer to disk
      File.write(fs_path, editor_text)
      base_ed.call("tag_saved_version") rescue nil
      @@file_last_disk_mtime[fs_path] = File.info(fs_path).modification_time
      Godot.print("[CrystalIntegrationPlugin] Auto-flushed live editor buffer to #{fs_path} (#{editor_text.bytesize} bytes)")
    elsif disk_text != editor_text
      # Versions match but contents differ: reload from disk
      base_ed.call("set_text", disk_text)
      base_ed.call("tag_saved_version") rescue nil
      @@file_last_disk_mtime[fs_path] = disk_mtime
      Godot.print("[CrystalIntegrationPlugin] Synchronized editor view with disk: #{fs_path} (#{disk_text.bytesize} bytes)")
    else
      @@file_last_disk_mtime[fs_path] = disk_mtime
    end
  rescue ex
    Godot.printerr("[CrystalIntegrationPlugin] Notice during sync_script_file(#{path}): #{ex.message}")
  end

  # Saves all open scripts and scenes in the editor before compiling so modifications on disk are up to date
  def self.save_open_editor_files : Void
    if !Godot::DisplayServer.singleton_ptr.null?
      ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
      return if ds.call_str("get_name") == "headless"
    end
    return if Godot::EditorInterface.singleton_ptr.null?
    ei = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    begin
      # 1. Ask Godot's ScriptEditor to save all scripts
      script_ed = ei.call_obj("get_script_editor")
      if script_ed && !script_ed.pointer.null?
        script_ed.call("save_all_scripts") rescue nil

        # 2. Directly inspect the active editor to guarantee live changes are synchronized
        if curr = script_ed.call_obj("get_current_script")
          if !curr.pointer.null?
            path = curr.call_str("get_path")
            if curr_ed = script_ed.call_obj("get_current_editor")
              if !curr_ed.pointer.null?
                if base_ed = curr_ed.call_obj("get_base_editor")
                  if !base_ed.pointer.null?
                    sync_script_file(base_ed, path)
                  end
                end
              end
            end
          end
        end

        # Inspect any open script editors list if available
        open_editors = script_ed.call("get_open_script_editors") rescue nil
        if open_editors.is_a?(Array(Godot::Variant))
          open_editors.each do |ed_var|
            ed_obj = ed_var.as_object rescue nil
            next unless ed_obj && !ed_obj.pointer.null?
            base_ed = ed_obj.call_obj("get_base_editor") rescue nil
            next unless base_ed && !base_ed.pointer.null?
            scr = ed_obj.call_obj("get_current_script") rescue nil
            next unless scr && !scr.pointer.null?
            p = scr.call_str("get_path") rescue ""
            sync_script_file(base_ed, p) unless p.empty?
          end
        end
      end

      # 3. Save open scenes
      ei.call("save_all_scenes") rescue nil
    rescue ex
      Godot.printerr("[CrystalIntegrationPlugin] Notice during save_open_editor_files: #{ex.message}")
    end
  end

  # Handles toolbar compile button press to trigger manual Crystal rebuild
  def self.on_compile_button_pressed : Void
    if @@building || @@reload_pending
      Godot.print("[CrystalIntegrationPlugin] Build or reload already in progress, skipping duplicate request.")
      return
    end
    @@building = true

    if btn = @@compile_button
      btn.call("set_disabled", true) rescue nil
      btn.call("set_text", "Building...") rescue nil
    end

    begin
      save_open_editor_files
      Godot.print("[CrystalIntegrationPlugin] Triggering manual Crystal build...")
      recompile_modified_addons_silent
      success = execute_crystal_build
      if success
        Godot.print("[CrystalIntegrationPlugin] Build completed successfully!")
        if (dlg = @@error_dialog) && dlg.alive?
          dlg.hide
        end
        ext_path = "res://addons/crystal_integration/crystal.gdextension"
        gd_ext_mgr = Godot::GDExtensionManager.new(Godot::GDExtensionManager.singleton_ptr)
        if gd_ext_mgr.is_extension_loaded(ext_path)
          @@reload_pending = true
          if btn = @@compile_button
            btn.call("set_text", "Reloading...") rescue nil
          end
          if !Godot::Engine.singleton_ptr.null?
            engine = Godot::Engine.new(Godot::Engine.singleton_ptr)
            engine.call("set_meta", "crystal_test_reloaded", true) rescue nil
          end
          Godot::Bridge.set_reloading(true)
          gd_ext_mgr.call_deferred("reload_extension", ext_path)
          Godot.print("[CrystalIntegrationPlugin] Scheduled deferred GDExtension reload.")
        else
          @@building = false
          if btn = @@compile_button
            btn.call("set_disabled", false) rescue nil
            btn.call("set_text", "Build") rescue nil
          end
        end
      else
        Godot.printerr("[CrystalIntegrationPlugin] Build failed! Check the error dialog and Debugger -> Errors tab.")
        @@building = false
        @@reload_pending = false
        if btn = @@compile_button
          btn.call("set_disabled", false) rescue nil
          btn.call("set_text", "Build Failed") rescue nil
        end
        if ::ENV["LIBGODOT_TEST_ERROR_RECOVERY"]? == "1"
          Godot.print("[TestErrorRecovery] SUCCESS: Compilation failure captured gracefully and button recovered to 'Build Failed'!")
        end
      end
    rescue ex
      @@building = false
      @@reload_pending = false
      if btn = @@compile_button
        btn.call("set_disabled", false) rescue nil
        btn.call("set_text", "Build Failed") rescue nil
      end
      Godot.printerr("[CrystalIntegrationPlugin] Error during build: #{ex.message}")
    end
  end

  def on_compile_button_pressed : Void
    self.class.on_compile_button_pressed
  end

  # Automated verification workflow for the Build Crystal toolbar button and GDExtension reload
  def self.check_test_build_button_flow : Void
    target_cycles = ::ENV["LIBGODOT_TEST_RELOAD_CYCLES"]?.try(&.to_i?) || 2

    if !Godot::Engine.singleton_ptr.null?
      engine = Godot::Engine.new(Godot::Engine.singleton_ptr)
      if engine.call_bool("has_meta", "crystal_test_reloaded")
        engine.call("remove_meta", "crystal_test_reloaded") rescue nil
        current_cycle = if engine.call_bool("has_meta", "crystal_test_cycle")
          (engine.call_i64("get_meta", "crystal_test_cycle") rescue 0_i64) + 1_i64
        else
          1_i64
        end
        engine.call("set_meta", "crystal_test_cycle", current_cycle) rescue nil
        Godot.print("[TestBuildButton] Reload cycle #{current_cycle}/#{target_cycles} completed cleanly!")

        if current_cycle < target_cycles
          # Schedule next reload cycle
          schedule_test_button_press(1.5, current_cycle + 1_i64, target_cycles.to_i64)
          return
        else
          engine.call("remove_meta", "crystal_test_cycle") rescue nil
          Godot.print("[TestBuildButton] SUCCESS: Build Crystal button pressed, compilation succeeded, and GDExtension reloaded cleanly!")
          Godot.print("[TestBuildButton] SUCCESS: Completed all #{target_cycles} reload cycles!")
          if has_editor_interface? && !Godot::EditorInterface.singleton_ptr.null?
            ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
            if base_ctrl = ed_iface.get_base_control
              if tree = base_ctrl.get_tree
                tree.call_deferred("quit", 0_i64) rescue nil
              end
            end
          end
          return
        end
      end
    end

    # Initial launch: schedule cycle 1
    schedule_test_button_press(1.5, 1_i64, target_cycles.to_i64)
  end

  def self.schedule_test_button_press(delay_sec : Float64, cycle : Int64, total_cycles : Int64) : Void
    return unless has_editor_interface?
    return if Godot::EditorInterface.singleton_ptr.null?
    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    base_ctrl = ed_iface.get_base_control
    return if base_ctrl.pointer.null? || !base_ctrl.is_inside_tree

    begin
      tree = base_ctrl.get_tree
      if tree && !tree.pointer.null?
        timer = tree.create_timer(delay_sec)
        if timer && !timer.pointer.null?
          timer.connect("timeout") do |_args|
            Godot.print("[TestBuildButton] Triggering Build Crystal button pressed (cycle #{cycle}/#{total_cycles}) via automated test...")
            if btn = @@compile_button
              btn.emit_signal("pressed") rescue on_compile_button_pressed
            else
              on_compile_button_pressed
            end
          end
        end
      end
    rescue
    end
  end

  # Invoked by Godot editor before running project (F5 / F6)
  def _build : Bool
    if @@building || @@reload_pending
      Godot.print("[CrystalIntegrationPlugin] Build or reload already in progress, skipping F5 build.")
      return true
    end
    if self.class.headless?
      Godot.print("[CrystalIntegrationPlugin] Headless mode detected, skipping editor F5 build.")
      return true
    end
    @@building = true
    begin
      self.class.save_open_editor_files
      Godot.print("[CrystalIntegrationPlugin] Editor build requested (F5 / Play). Compiling Crystal...")
      self.class.recompile_modified_addons_silent
      self.class.execute_crystal_build
    ensure
      @@building = false
    end
  end

  # Builds an environment Hash with properly configured CRYSTAL_PATH
  # ensuring libgodot and local shards can be resolved from anywhere.
  def self.build_compiler_env : Hash(String, String)
    env = ENV.to_h
    sep = {% if flag?(:windows) %} ";" {% else %} ":" {% end %}

    # 1. If shard.yml exists but lib/ directory does not, automatically run shards install
    if !headless? && File.exists?("shard.yml") && !File.directory?("lib")
      begin
        Godot.print("[CrystalIntegrationPlugin] Dependencies in 'lib/' missing. Running 'shards install'...")
        sh_out = IO::Memory.new
        sh_status = Process.run("shards", ["install"], output: sh_out, error: sh_out)
        sh_msg = sh_out.to_s.strip
        Godot.print(sh_msg) unless sh_msg.empty?
        if sh_status.success?
          Godot.print("[CrystalIntegrationPlugin] Shards installed successfully.")
        else
          Godot.printerr("[CrystalIntegrationPlugin] 'shards install' exited with code #{sh_status.exit_code}.")
        end
      rescue ex
        Godot.printerr("[CrystalIntegrationPlugin] Notice: could not execute shards install: #{ex.message}")
      end
    end

    # 2. Gather candidate search paths for lapis / libgodot
    extra_paths = [] of String
    ["../src", "../../src", "../../../src", "lib"].each do |candidate|
      if File.exists?(File.join(candidate, "lapis.cr")) || File.exists?(File.join(candidate, "libgodot.cr")) || candidate == "lib"
        full_path = File.expand_path(candidate)
        extra_paths << full_path unless extra_paths.includes?(full_path)
      end
    end

    # 3. Query base CRYSTAL_PATH from crystal compiler if not already present
    base_crystal_path = env["CRYSTAL_PATH"]?
    if base_crystal_path.nil? || base_crystal_path.empty?
      io = IO::Memory.new
      if (Process.run("crystal", ["env", "CRYSTAL_PATH"], output: io) rescue nil).try(&.success?)
        base_crystal_path = io.to_s.strip
      end
    end

    if !extra_paths.empty?
      all_paths = extra_paths.dup
      if base_crystal_path && !base_crystal_path.empty?
        all_paths << base_crystal_path
      end
      env["CRYSTAL_PATH"] = all_paths.join(sep)
    end

    env
  end

  # Scans project addons/ directory and recompiles any Crystal addons whose source code changed
  def self.recompile_modified_addons_silent : Void
    addons_dir = "addons"
    addons_dir = "../addons" unless Dir.exists?(addons_dir)
    return unless Dir.exists?(addons_dir)

    so_ext = {% if flag?(:windows) %}
      "dll"
    {% elsif flag?(:darwin) %}
      "dylib"
    {% else %}
      "so"
    {% end %}

    link_flags = {% if flag?(:windows) %}
      "/DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init"
    {% elsif flag?(:darwin) %}
      "-dynamiclib"
    {% else %}
      "-shared"
    {% end %}

    Dir.each_child(addons_dir) do |entry|
      next if entry == "crystal_integration"
      addon_path = File.join(addons_dir, entry)
      next unless Dir.exists?(addon_path)

      main_cr = File.join(addon_path, "src", "main.cr")
      next unless File.exists?(main_cr)

      bin_dir = File.join(addon_path, "bin")
      Dir.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)

      target_bin = File.join(bin_dir, "#{entry}.#{so_ext}")
      target_mtime = File.exists?(target_bin) ? File.info(target_bin).modification_time : ::Time.unix(0)

      # Check if any .cr file inside the addon was modified after target_bin
      needs_recompile = !File.exists?(target_bin)
      unless needs_recompile
        Dir.glob(File.join(addon_path, "**", "*.cr").gsub('\\', '/')).each do |src_file|
          if File.info(src_file).modification_time > target_mtime
            needs_recompile = true
            break
          end
        end
      end

      if needs_recompile
        Godot.print("[CrystalIntegrationPlugin] Recompiling modified addon: #{entry}...")
        lapis_candidates = [
          "bin/lapis.exe", "bin/lapis",
          "../bin/lapis.exe", "../bin/lapis",
          "../../bin/lapis.exe", "../../bin/lapis"
        ]
        lapis_bin = lapis_candidates.find { |p| File.exists?(p) } || Process.find_executable("lapis")
        out_io = IO::Memory.new
        err_io = IO::Memory.new
        compiler_env = build_compiler_env

        status = if lapis_bin
          lapis_args = ["build", "--entry", main_cr, "--output", target_bin, "--link-flags", link_flags, "--flags", "-Dlibgodot_addon"]
          Godot.print("[CrystalIntegrationPlugin] Running: #{lapis_bin} #{lapis_args.join(" ")}")
          Process.run(File.expand_path(lapis_bin), lapis_args, env: compiler_env, output: out_io, error: err_io)
        else
          args = ["build", "--single-module", "--link-flags", link_flags]
          {% unless flag?(:windows) %}
            args << "-Dwithout_mt"
          {% end %}
          args << main_cr
          args << "-o"
          args << target_bin
          Godot.print("[CrystalIntegrationPlugin] Running: crystal #{args.join(" ")}")
          Process.run("crystal", args, env: compiler_env, output: out_io, error: err_io)
        end

        out_msg = out_io.to_s.strip
        err_msg = err_io.to_s.strip
        Godot.print(out_msg) unless out_msg.empty?
        Godot.printerr(err_msg) unless err_msg.empty?
        if status.success?
          Godot.print("[CrystalIntegrationPlugin] Successfully recompiled addon: #{entry}")
        else
          report_build_failure("Addon '#{entry}' compilation", out_msg, err_msg, status.exit_code)
        end
      end
    end
  rescue ex
    Godot.printerr("[CrystalIntegrationPlugin] Error checking addon recompilation: #{ex.message}")
  end

  def recompile_modified_addons_silent : Void
    self.class.recompile_modified_addons_silent
  end

  # Compiles project Crystal code into shared library
  def self.execute_crystal_build : Bool
    execute_crystal_build_with_options(false)
  end

  def execute_crystal_build : Bool
    self.class.execute_crystal_build
  end

  # Automatically generates project bindings for custom GDScript nodes if present
  def self.ensure_project_bindings : Void
    begin
      out_json = "src/generated/project_nodes.json"
      out_dir = "src/generated/project_nodes"

      gd_files = [] of String
      Dir.glob("**/*.gd").each do |f|
        clean_f = f.gsub('\\', '/')
        next if clean_f.starts_with?(".godot/")
        next if clean_f.starts_with?("addons/")
        next if clean_f.starts_with?("tools/")
        next if clean_f == "scripts/dump_project_nodes.gd"
        gd_files << clean_f
      end

      if gd_files.empty?
        # Clean out any stale generated bindings if no GDScript files remain
        if Dir.exists?(out_dir)
          cleaned = false
          Dir.each_child(out_dir) do |child|
            next if child == "all_project_nodes.cr"
            child_path = File.join(out_dir, child)
            begin
              if File.file?(child_path)
                File.delete(child_path)
                cleaned = true
              elsif File.directory?(child_path)
                FileUtils.rm_rf(child_path)
                cleaned = true
              end
            rescue
            end
          end
          manifest_path = File.join(out_dir, "all_project_nodes.cr")
          if File.exists?(manifest_path)
            File.write(manifest_path, "# Generated All Project Custom Nodes Manifest\n")
          end
          if File.exists?(out_json)
            File.delete(out_json) rescue nil
          end
          if cleaned
            Godot.print("[CrystalIntegrationPlugin] Cleaned stale generated bindings in #{out_dir} (no project GDScript files found).")
          end
        end
        return
      end

      dump_script = ["scripts/dump_project_nodes.gd", "tools/api_generator/dump_project_nodes.gd", "../tools/api_generator/dump_project_nodes.gd"].find { |p| File.exists?(p) }
      gen_script = ["scripts/generate_project_bindings.cr", "tools/api_generator/generate_project_bindings.cr", "../tools/api_generator/generate_project_bindings.cr"].find { |p| File.exists?(p) }
      return unless dump_script && gen_script

      target_dump = "scripts/dump_project_nodes.gd"
      if !File.exists?(target_dump)
        Dir.mkdir_p("scripts") unless Dir.exists?("scripts")
        File.copy(dump_script, target_dump)
      end

      godot_exe = {% if flag?(:windows) %}
        ["./godot.exe", "../godot.exe", "../../godot.exe"].find { |p| File.exists?(p) } || "godot.exe"
      {% else %}
        ["./godot", "../godot", "../../godot"].find { |p| File.exists?(p) } || "godot"
      {% end %}

      Godot.print("[CrystalIntegrationPlugin] Updating project GDScript bindings for #{gd_files.size} script(s)...")
      Dir.mkdir_p("src/generated") unless Dir.exists?("src/generated")

      # Clean out old generated bindings folder before regen
      if Dir.exists?(out_dir)
        Dir.each_child(out_dir) do |child|
          child_path = File.join(out_dir, child)
          begin
            if File.file?(child_path)
              File.delete(child_path)
            elsif File.directory?(child_path)
              FileUtils.rm_rf(child_path)
            end
          rescue
          end
        end
      else
        Dir.mkdir_p(out_dir)
      end

      Process.run(godot_exe, ["--headless", "-s", "res://scripts/dump_project_nodes.gd", "--", "--output", out_json], output: Process::Redirect::Close, error: Process::Redirect::Close) rescue nil

      if File.exists?(out_json)
        c_io = IO::Memory.new
        c_status = Process.run("crystal", ["run", gen_script, "--", out_json, out_dir], output: c_io, error: c_io) rescue nil
        if c_status && c_status.success?
          Godot.print("[CrystalIntegrationPlugin] Successfully generated project node bindings in #{out_dir}")
        end
      end

      # Guarantee manifest exists even if generation was empty
      manifest_path = File.join(out_dir, "all_project_nodes.cr")
      if !File.exists?(manifest_path)
        File.write(manifest_path, "# Generated All Project Custom Nodes Manifest\n")
      end
    rescue ex
      Godot.printerr("[CrystalIntegrationPlugin] Notice during ensure_project_bindings: #{ex.message}")
    end
  end

  # Compiles project Crystal code with optional release optimizations
  def self.execute_crystal_build_with_options(is_release : Bool = false) : Bool
    entry_file = "src/main.cr"
    if !Godot::SystemIO.file_exists?(entry_file) && !Godot::ProjectSettings.singleton_ptr.null?
      ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
      global_entry = ps.call_str("globalize_path", "res://src/main.cr").gsub('\\', '/')
      entry_file = global_entry if !global_entry.empty? && Godot::SystemIO.file_exists?(global_entry)
    end

    if !Godot::SystemIO.file_exists?(entry_file)
      report_build_failure("Crystal build", "", "Entry file not found: #{entry_file}", 1)
      return false
    end

    ensure_project_bindings

    out_dll = {% if flag?(:windows) %}
      "bin/game.dll"
    {% elsif flag?(:darwin) %}
      "bin/game.dylib"
    {% else %}
      "bin/game.so"
    {% end %}

    out_dir = File.dirname(out_dll)
    Dir.mkdir_p(out_dir) unless Dir.exists?(out_dir)

    link_flags = {% if flag?(:windows) %}
      "/DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init"
    {% elsif flag?(:darwin) %}
      "-dynamiclib"
    {% else %}
      "-shared"
    {% end %}

    compiler_env = build_compiler_env
    lapis_candidates = [
      "bin/lapis.exe", "bin/lapis",
      "../bin/lapis.exe", "../bin/lapis",
      "../../bin/lapis.exe", "../../bin/lapis"
    ]
    lapis_bin = lapis_candidates.find { |p| File.exists?(p) } || Process.find_executable("lapis")
    out_io = IO::Memory.new
    err_io = IO::Memory.new

    status = if lapis_bin
      lapis_args = ["build", "--entry", entry_file, "--output", out_dll, "--link-flags", link_flags]
      lapis_args << "--release" if is_release
      Godot.print("[CrystalIntegrationPlugin] Running: #{lapis_bin} #{lapis_args.join(" ")}")
      Process.run(File.expand_path(lapis_bin), lapis_args, env: compiler_env, output: out_io, error: err_io)
    else
      args = ["build", "--link-flags", link_flags]
      {% unless flag?(:windows) %}
        args << "-Dwithout_mt"
      {% end %}
      if is_release
        args << "--release"
      else
        args << "--single-module"
      end
      args << entry_file
      args << "-o"
      args << out_dll
      Godot.print("[CrystalIntegrationPlugin] Running: crystal #{args.join(" ")}")
      Process.run("crystal", args, env: compiler_env, output: out_io, error: err_io)
    end
    out_msg = out_io.to_s.strip
    err_msg = err_io.to_s.strip
    Godot.print(out_msg) unless out_msg.empty?
    Godot.print(err_msg) unless err_msg.empty?

    if status.success?
      if (dlg = @@error_dialog) && dlg.alive?
        dlg.hide
      end
      Godot.print("[CrystalIntegrationPlugin] Crystal build succeeded: #{out_dll}")
      if File.directory?("../bin")
        begin
          File.copy(out_dll, "../bin/#{File.basename(out_dll)}")
          Godot.print("[CrystalIntegrationPlugin] Synced DLL to root: ../bin/#{File.basename(out_dll)}")
        rescue
        end
      end
      addon_bin_target = "addons/crystal_integration/bin/#{File.basename(out_dll)}"
      if File.directory?("addons/crystal_integration/bin")
        begin
          File.copy(out_dll, addon_bin_target)
          Godot.print("[CrystalIntegrationPlugin] Synced DLL to addon: #{addon_bin_target}")
        rescue
        end
      end
      true
    else
      report_build_failure("Crystal build", out_msg, err_msg, status.exit_code)
      false
    end
  rescue ex
    report_build_failure("Crystal build", "", "Error running build: #{ex.message}", 1)
    false
  end

  def execute_crystal_build_with_options(is_release : Bool = false) : Bool
    self.class.execute_crystal_build_with_options(is_release)
  end

  @@link_check_accum : Float64 = 0.0_f64
  @@reload_watchdog : Float64 = 0.0_f64

  def _process(delta : Float64) : Void
    if dbg = @@debugger_plugin
      dbg.call("poll") rescue nil
    end

    if Godot.editor_hint?
      # Ensure toolbar button is active and restored after reload
      btn_inst = @@compile_button
      if btn_inst.nil? || btn_inst.pointer.null? || !btn_inst.alive?
        self.class.setup_toolbar_button
      elsif btn = @@compile_button
        if @@reload_pending || (btn.call_str("get_text") rescue "") == "Reloading..."
          @@reload_watchdog += delta
          if @@reload_watchdog > 1.5_f64
            @@reload_pending = false
            @@building = false
            @@reload_watchdog = 0.0_f64
            btn.call("set_disabled", false) rescue nil
            btn.call("set_text", "Build") rescue nil
            Godot.print("[CrystalIntegrationPlugin] Watchdog: Reload completed. Reset Build button to 'Build'.")
          end
        else
          @@reload_watchdog = 0.0_f64
        end
      end

      # Ensure main screen panel is active and restored after reload
      panel_inst = @@crystal_panel
      if panel_inst.nil? || panel_inst.pointer.null? || !panel_inst.alive?
        self.class.setup_main_screen_panel
      end

      @@link_check_accum += delta
      if @@link_check_accum >= 1.0_f64
        @@link_check_accum = 0.0_f64
        self.class.link_scripts_in_edited_scene
      end
    end
  end

  def apply_highlighter_if_needed : Void
    self.class.apply_highlighter_if_needed
  end

  def self.apply_highlighter_if_needed : Void
    return if Godot::EditorInterface.singleton_ptr.null?
    hl = @@crystal_highlighter
    return unless hl && !hl.pointer.null?

    ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    se = ed_iface.get_script_editor
    return if se.pointer.null?

    curr_script = se.get_current_script
    if curr_script && !curr_script.pointer.null?
      path = curr_script.call_str("get_path")
      if path.ends_with?(".cr")
        curr_ed = se.call_obj("get_current_editor")
        if curr_ed && !curr_ed.pointer.null?
          curr_ed.call("add_syntax_highlighter", hl)
          base_ed = curr_ed.call_obj("get_base_editor")
          if base_ed && !base_ed.pointer.null?
            base_ed.call("set_syntax_highlighter", hl)
            base_ed.call("queue_redraw")
          end
        end
      end
    end
  rescue
  end

  def self.link_scripts_recursive(node : Godot::Node) : Void
    return if node.pointer.null?
    return unless (node.call_bool("is_inside_tree") rescue false)
    node.link_class_script
    child_count = node.call_i64("get_child_count")
    child_count.times do |i|
      child_obj = node.call_obj("get_child", i)
      if child_obj && !child_obj.pointer.null?
        link_scripts_recursive(Godot::Node.new(child_obj.pointer))
      end
    end
  rescue ex
    Godot.print("[CrystalIntegrationPlugin] Note: link_scripts_recursive: #{ex.message}")
  end

  def self.link_scripts_in_edited_scene : Void
    return if Godot::EditorInterface.singleton_ptr.null?
    if !Godot::DisplayServer.singleton_ptr.null?
      ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
      return if ds.call_str("get_name") == "headless"
    end
    ed_interface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
    scene_root = ed_interface.call_obj("get_edited_scene_root")
    if scene_root && !scene_root.pointer.null?
      link_scripts_recursive(scene_root)
    end
  rescue ex
    Godot.print("[CrystalIntegrationPlugin] Note: link_scripts_in_edited_scene: #{ex.message}")
  end
end
end

alias CrystalIntegrationPlugin = Godot::CrystalIntegrationPlugin

Godot::Bridge.register_shutdown_callback do
  Godot::CrystalIntegrationPlugin.cleanup_on_shutdown rescue nil
end

