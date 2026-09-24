# =============================================================================
# LibGodot - Crystal Script Creation Dialog & Menu Integration
# =============================================================================
# Pure-Crystal editor integration for Godot 4.8.
# Provides a dedicated, native dialog for creating new Crystal scripts (.cr)
# and seamlessly hooks into:
# - Top toolbar "+ Script" button next to "Build"
# - FileSystem dock context menu ("Crystal Script...")
# - FileSystem dock "Create New" actions
# - SceneTree dock node context menu ("Attach/New Crystal Script...")
# =============================================================================

module Lapis
  include Godot

  module EditorScriptCreation
    ID_CRYSTAL_SCRIPT = 889901_i64
    ID_SCENE_ATTACH   = 889902_i64

    COMMON_BASE_TYPES = [
      "Node",
      "Node2D",
      "Node3D",
      "CharacterBody3D",
      "CharacterBody2D",
      "Control",
      "Camera3D",
      "Area3D",
      "Area2D",
      "RigidBody3D",
      "RigidBody2D",
      "Resource",
      "RefCounted",
    ]

    TEMPLATES = [
      "Standard Node (_ready & _process)",
      "Physics Movement (CharacterBody)",
      "Tool Script (@[Tool] In-Editor Execution)",
      "Empty Class",
    ]

    @@dialog : ConfirmationDialog? = nil
    @@class_edit : LineEdit? = nil
    @@base_opt : OptionButton? = nil
    @@tmpl_opt : OptionButton? = nil
    @@path_edit : LineEdit? = nil
    @@file_dialog : EditorFileDialog? = nil
    @@toolbar_button : Button? = nil
    @@hooked_popups : Set(UInt64) = Set(UInt64).new
    @@hooked_script_dialogs : Set(UInt64) = Set(UInt64).new
    @@hooked_create_dialogs : Set(UInt64) = Set(UInt64).new
    @@intercept_crystal_resource : Bool = false

    # Recursively discovers all child nodes matching the specified Godot class name
    def self.find_all_children(parent : Node, type_name : String) : Array(Node)
      results = [] of Node
      begin
        return results if parent.pointer.null?
        count = parent.call_i64("get_child_count") rescue 0_i64
        count.times do |i|
          if child = parent.call_obj("get_child", i)
            if !child.pointer.null?
              cls = child.call_str("get_class") rescue ""
              if cls == type_name || cls.includes?(type_name)
                results << child
              end
              results.concat(find_all_children(child, type_name))
            end
          end
        end
      rescue
      end
      results
    end

    # Converts CamelCase to snake_case for clean Crystal file naming
    def self.to_snake_case(str : String) : String
      res = String.build do |sb|
        str.each_char_with_index do |c, i|
          if c.ascii_uppercase?
            sb << '_' if i > 0 && str[i - 1]?.try(&.ascii_lowercase?)
            sb << c.downcase
          elsif c == ' ' || c == '-'
            sb << '_'
          else
            sb << c
          end
        end
      end
      res.empty? ? "new_node" : res
    end

    # Sets up all editor integration entry points: toolbar button, FileSystem dock menus, SceneTree menus, and ScriptCreateDialog interception
    def self.setup(ed_iface : EditorInterface, base_ctrl : Control) : Void
      return if CrystalIntegrationPlugin.headless?
      if !Godot::DisplayServer.singleton_ptr.null?
        ds = Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr)
        return if ds.call_str("get_name") == "headless"
      end

      setup_toolbar_button(ed_iface, base_ctrl)
      setup_filesystem_dock_menus(ed_iface)
      setup_scene_tree_dock_menus(ed_iface, base_ctrl)
      setup_script_create_dialog_interception(ed_iface, base_ctrl)
    end

    # 1. Top Toolbar "+ Script" Button
    def self.setup_toolbar_button(ed_iface : EditorInterface, base_ctrl : Control) : Void
      return if CrystalIntegrationPlugin.headless?
      if btn = @@toolbar_button
        return if !btn.pointer.null?
      end

      # Check for duplicate button
      if existing = base_ctrl.call_obj("find_child", "NewCrystalScriptToolbarButton", true, false)
        if !existing.pointer.null?
          btn = Godot::Button.new(existing.pointer)
          @@toolbar_button = btn
          Godot.clear_signal_subscriptions(btn.signal_target_id)
          btn.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) do |_args|
            show_dialog
          end
          return
        end
      end

      btn = Godot.create(Godot::Button)
      return unless btn
      btn.call("set_name", "NewCrystalScriptToolbarButton")
      btn.call("set_flat", true)
      btn.call("set_theme_type_variation", "RunBarButton")
      btn.call("set_text", "+ Script")
      btn.call("set_tooltip_text", "Create New Crystal Script (.cr)")
      btn.call("set_focus_mode", 0)

      btn.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) do |_args|
        show_dialog
      end

      if title_bar = base_ctrl.call_obj("find_child", "EditorTitleBar", true, false)
        title_bar.call_deferred("add_child", btn) rescue nil
        if compile_btn = base_ctrl.call_obj("find_child", "BuildCrystalToolbarButton", true, false)
          c_idx = compile_btn.call_i64("get_index") rescue -1_i64
          if c_idx >= 0
            title_bar.call_deferred("move_child", btn, c_idx + 1) rescue nil
          end
        end
      end

      @@toolbar_button = btn
    rescue ex
      Godot.print("[EditorScriptCreation] Notice toolbar button setup: #{ex.message}")
    end

    # 2. FileSystem Dock Context Menu & Create New Menu
    def self.setup_filesystem_dock_menus(ed_iface : EditorInterface) : Void
      fs_dock = ed_iface.get_file_system_dock
      return if fs_dock.pointer.null?

      popups = find_all_children(fs_dock, "PopupMenu")
      popups.each do |popup_node|
        popup = Godot::PopupMenu.new(popup_node.pointer)
        next if @@hooked_popups.includes?(popup.signal_target_id)
        @@hooked_popups << popup.signal_target_id

        popup.connect("about_to_popup") do |_args|
          item_count = popup.call_i64("get_item_count") rescue 0_i64
          has_item = false
          item_count.times do |i|
            if (popup.call_i64("get_item_id", i) rescue -1_i64) == ID_CRYSTAL_SCRIPT
              has_item = true
              break
            end
          end

          unless has_item
            popup.call("add_separator") rescue nil if item_count > 0
            tex = CrystalIntegrationPlugin.get_crystal_icon_texture
            if tex && !tex.pointer.null?
              popup.call("add_icon_item", tex, "Crystal Script...", ID_CRYSTAL_SCRIPT) rescue nil
            else
              popup.call("add_item", "Crystal Script...", ID_CRYSTAL_SCRIPT) rescue nil
            end
          end

          # Dynamically inspect and hook any child submenus (such as "Create New")
          child_popups = find_all_children(popup, "PopupMenu")
          child_popups.each do |sub_node|
            hook_create_new_submenu(fs_dock, sub_node)
          end

          # Re-check dialog interception in case dock dialogs were instantiated
          if base = ed_iface.get_base_control
            setup_script_create_dialog_interception(ed_iface, base)
          end
        end

        popup.connect("id_pressed") do |args|
          if args && args.size > 0 && (args[0].as_i64 rescue -1_i64) == ID_CRYSTAL_SCRIPT
            current_path = fs_dock.call_str("get_current_path") rescue ""
            current_dir = if current_path.empty? || current_path == "res://"
                            "res://src"
                          elsif Dir.exists?(current_path.sub("res://", ""))
                            current_path
                          else
                            File.dirname(current_path)
                          end
            show_dialog(initial_path: current_dir)
          end
        end
      end
    rescue ex
      Godot.print("[EditorScriptCreation] Notice filesystem dock menus setup: #{ex.message}")
    end

    # Hooks dynamically created "Create New" submenus in FileSystemDock
    def self.hook_create_new_submenu(fs_dock : Node, sub_node : Node) : Void
      return if sub_node.pointer.null?
      sub_popup = Godot::PopupMenu.new(sub_node.pointer)
      item_count = sub_popup.call_i64("get_item_count") rescue 0_i64
      has_crystal = false
      has_script_or_folder = false

      item_count.times do |i|
        id = sub_popup.call_i64("get_item_id", i) rescue -1_i64
        txt = sub_popup.call_str("get_item_text", i) rescue ""
        if id == ID_CRYSTAL_SCRIPT || txt.includes?("Crystal Script")
          has_crystal = true
          break
        end
        if txt.includes?("Script") || txt.includes?("Folder") || txt.includes?("Resource")
          has_script_or_folder = true
        end
      end

      if has_script_or_folder && !has_crystal
        tex = CrystalIntegrationPlugin.get_crystal_icon_texture
        if tex && !tex.pointer.null?
          sub_popup.call("add_icon_item", tex, "Crystal Script...", ID_CRYSTAL_SCRIPT) rescue nil
        else
          sub_popup.call("add_item", "Crystal Script...", ID_CRYSTAL_SCRIPT) rescue nil
        end
      end

      unless @@hooked_popups.includes?(sub_popup.signal_target_id)
        @@hooked_popups << sub_popup.signal_target_id
        sub_popup.connect("id_pressed") do |args|
          if args && args.size > 0 && (args[0].as_i64 rescue -1_i64) == ID_CRYSTAL_SCRIPT
            current_path = fs_dock.call_str("get_current_path") rescue ""
            current_dir = if current_path.empty? || current_path == "res://"
                            "res://src"
                          elsif Dir.exists?(current_path.sub("res://", ""))
                            current_path
                          else
                            File.dirname(current_path)
                          end
            show_dialog(initial_path: current_dir)
          end
        end
      end
    end

    # Retrieves the selected type from a Godot CreateDialog by inspecting its Tree control
    def self.get_create_dialog_selected_type(cd : Node) : String
      trees = find_all_children(cd, "Tree")
      trees.each do |tree_node|
        tree = Godot::Tree.new(tree_node.pointer)
        if sel_item = tree.call_obj("get_selected")
          if !sel_item.pointer.null?
            txt = sel_item.call_str("get_text", 0) rescue ""
            return txt unless txt.empty?
          end
        end
      end
      cd.call_str("get_selected_type") rescue ""
    end

    # Normalizes a path to end with exactly one .cr extension, stripping duplicate dots or other extensions
    def self.ensure_cr_extension(path : String) : String
      return path if path.ends_with?(".cr") && !path.ends_with?("..cr")
      if path.includes?('.')
        path.sub(/\.+[^.\/]*$/, ".cr")
      else
        "#{path}.cr"
      end
    end

    # Adapts the file path inside a native ScriptCreateDialog to ensure a clean .cr extension when Crystal is selected
    def self.adapt_script_create_dialog_path(scd : Node) : Void
      line_edits = find_all_children(scd, "LineEdit")
      line_edits.each do |le_node|
        le = Godot::LineEdit.new(le_node.pointer)
        txt = le.call_str("get_text") rescue ""
        if txt.starts_with?("res://") || txt.includes?("/")
          new_txt = ensure_cr_extension(txt)
          if new_txt != txt
            le.call("set_text", new_txt)
          end
          # Always emit text_changed so ScriptCreateDialog runs _path_changed and validates the .cr extension
          le.emit_signal("text_changed", new_txt) rescue nil
        end
      end
    rescue ex
      Godot.print("[EditorScriptCreation] Notice adapt_script_create_dialog_path: #{ex.message}")
    end

    # Intercepts Godot's built-in ScriptCreateDialog whenever CrystalScript is selected
    # in "Create New Resource" (FileSystem Dock -> Create New -> Resource -> CrystalScript)
    # and repairs native ScriptCreateDialog instances so they never show broken red icons.
    def self.setup_script_create_dialog_interception(ed_iface : EditorInterface, base_ctrl : Control) : Void
      # 1. Hook CreateDialog instances to track when CrystalScript is confirmed
      create_dlgs = find_all_children(base_ctrl, "CreateDialog")
      create_dlgs.each do |cd_node|
        cd = Godot::ConfirmationDialog.new(cd_node.pointer)
        next if @@hooked_create_dialogs.includes?(cd.signal_target_id)
        @@hooked_create_dialogs << cd.signal_target_id

        cd.connect("confirmed") do |_args|
          sel = get_create_dialog_selected_type(cd)
          if sel == "CrystalScript"
            @@intercept_crystal_resource = true
          end
        end

        cd.connect("create") do |_args|
          sel = get_create_dialog_selected_type(cd)
          if sel == "CrystalScript"
            @@intercept_crystal_resource = true
          end
        end
      end

      # 2. Hook ScriptCreateDialog instances to redirect to CrystalScriptCreateDialog or fix options
      script_dlgs = find_all_children(base_ctrl, "ScriptCreateDialog")
      script_dlgs.each do |scd_node|
        scd = Godot::ConfirmationDialog.new(scd_node.pointer)
        next if @@hooked_script_dialogs.includes?(scd.signal_target_id)
        @@hooked_script_dialogs << scd.signal_target_id

        scd.connect("about_to_popup") do |_args|
          triggered_by_crystal = @@intercept_crystal_resource
          unless triggered_by_crystal
            # Check if any CreateDialog has CrystalScript selected
            cd_list = find_all_children(base_ctrl, "CreateDialog")
            cd_list.each do |cd|
              if get_create_dialog_selected_type(cd) == "CrystalScript"
                triggered_by_crystal = true
                break
              end
            end
          end

          if triggered_by_crystal
            @@intercept_crystal_resource = false
            # Move Godot's native dialog far offscreen and hide it so it never flashes or renders
            scd.call("set_position", Godot::Vector2i.new(-10000, -10000)) rescue nil
            scd.call("set_visible", false) rescue nil
            scd.call_deferred("hide") rescue nil

            fs_dock = ed_iface.get_file_system_dock
            current_path = fs_dock.call_str("get_current_path") rescue ""
            current_dir = if current_path.empty? || current_path == "res://"
                            "res://src"
                          elsif Dir.exists?(current_path.sub("res://", ""))
                            current_path
                          else
                            File.dirname(current_path)
                          end

            # Present our dedicated, native CrystalScriptCreateDialog
            show_dialog(initial_path: current_dir)
          else
            # Repair the ScriptCreateDialog so Crystal is properly registered in its language menu
            fix_script_create_dialog(scd)
          end
        end
      end
    rescue ex
      Godot.print("[EditorScriptCreation] Notice script dialog interception setup: #{ex.message}")
    end

    # Repairs a Godot native ScriptCreateDialog's language menu:
    # - Updates index 1 (CrystalLanguage) text to "Crystal" and sets official Crystal icon
    # - Prunes any out-of-bounds surplus items (count must never exceed ScriptServer language count)
    # - Ensures valid selection index so it never shows broken red icon or empty fields
    # - Sets up live path adaptation when language is switched
    def self.fix_script_create_dialog(scd : Node) : Void
      return if scd.pointer.null?
      CrystalIntegrationPlugin.ensure_theme_icons
      opt_buttons = find_all_children(scd, "OptionButton")
      opt_buttons.each do |opt_node|
        opt = Godot::OptionButton.new(opt_node.pointer)
        item_count = opt.call_i64("get_item_count") rescue 0_i64
        has_gdscript = false
        item_count.times do |i|
          txt = opt.call_str("get_item_text", i) rescue ""
          has_gdscript = true if txt == "GDScript"
        end

        if has_gdscript
          # In Godot's ScriptCreateDialog, the language OptionButton items map 1-to-1 to
          # ScriptServer::get_language(p_idx). Index 0 is GDScript, index 1 is CrystalLanguage.
          # We must NEVER add extra items here, because any index >= ScriptServer::get_language_count()
          # causes an immediate Access Violation crash in ScriptCreateDialog::_lang_changed.
          tex = CrystalIntegrationPlugin.get_crystal_icon_texture

          # Remove any invalid surplus items (e.g. if previously duplicated by add_item)
          # Prune any out-of-bounds surplus items beyond actual registered script languages
          engine_ptr = Bridge.get_singleton("Engine")
          max_lang_count = if !engine_ptr.null?
                             Godot::Engine.new(engine_ptr).get_script_language_count rescue 2_i64
                           else
                             2_i64
                           end
          max_lang_count = 2_i64 if max_lang_count < 2_i64

          cur_count = opt.call_i64("get_item_count") rescue 0_i64
          while cur_count > max_lang_count
            opt.call("remove_item", cur_count - 1_i64) rescue nil
            cur_count = opt.call_i64("get_item_count") rescue 0_i64
          end

          # If index 1 exists in the underlying popup, ensure its label is "Crystal" and its icon is our Crystal logo
          popup_obj = opt.call_obj("get_popup") rescue nil
          pop_count = if popup_obj && !popup_obj.pointer.null?
                        popup_obj.call_i64("get_item_count") rescue 0_i64
                      else
                        0_i64
                      end

          if cur_count >= 2_i64
            opt.call("set_item_text", 1_i64, "Crystal") rescue nil
            if tex && !tex.pointer.null? && pop_count >= 2_i64
              opt.call("set_item_icon", 1_i64, tex) rescue nil
            end
          end

          # Avoid negative/unselected index which leads to broken red icon in Godot
          sel = opt.call_i64("get_selected") rescue -1_i64
          if sel < 0
            opt.call("select", 0) rescue nil
            sel = 0_i64
          end

          # If Crystal is currently selected, adapt path to end with .cr
          sel_txt = opt.call_str("get_item_text", sel) rescue ""
          if sel == 1_i64 || sel_txt == "Crystal"
            adapt_script_create_dialog_path(scd)
          end

          # Hook item_selected to auto-adapt path when language switches
          unless @@hooked_popups.includes?(opt.signal_target_id)
            @@hooked_popups << opt.signal_target_id
            opt.connect("item_selected") do |args|
              c_idx = (args && args.size > 0 ? args[0].as_i64 : opt.call_i64("get_selected")) rescue -1_i64
              if c_idx == 1_i64 || (opt.call_str("get_item_text", c_idx) rescue "") == "Crystal"
                adapt_script_create_dialog_path(scd)
              end
            end
          end
        end
      end
    rescue ex
      Godot.print("[EditorScriptCreation] Notice fix_script_create_dialog: #{ex.message}")
    end

    # 3. SceneTree Dock Node Context Menu ("Attach/New Crystal Script...")
    def self.setup_scene_tree_dock_menus(ed_iface : EditorInterface, base_ctrl : Control) : Void
      if scene_dock = base_ctrl.call_obj("find_child", "SceneTreeDock", true, false)
        popups = find_all_children(scene_dock, "PopupMenu")
        popups.each do |popup_node|
          popup = Godot::PopupMenu.new(popup_node.pointer)
          next if @@hooked_popups.includes?(popup.signal_target_id)
          @@hooked_popups << popup.signal_target_id

          popup.connect("about_to_popup") do |_args|
            item_count = popup.call_i64("get_item_count") rescue 0_i64
            has_item = false
            item_count.times do |i|
              if (popup.call_i64("get_item_id", i) rescue -1_i64) == ID_SCENE_ATTACH
                has_item = true
                break
              end
            end

            unless has_item
              tex = CrystalIntegrationPlugin.get_crystal_icon_texture
              if tex && !tex.pointer.null?
                popup.call("add_icon_item", tex, "Attach/New Crystal Script...", ID_SCENE_ATTACH) rescue nil
              else
                popup.call("add_item", "Attach/New Crystal Script...", ID_SCENE_ATTACH) rescue nil
              end
            end
          end

          popup.connect("id_pressed") do |args|
            if args && args.size > 0 && (args[0].as_i64 rescue -1_i64) == ID_SCENE_ATTACH
              sel_name = ""
              sel_type = ""
              if sel = ed_iface.call_obj("get_selection")
                if nodes = sel.call_obj("get_selected_nodes")
                  if !nodes.pointer.null?
                    sel_name = nodes.call_str("get_name") rescue ""
                    sel_type = nodes.call_str("get_class") rescue ""
                  end
                end
              end
              show_dialog(default_name: sel_name, default_base: sel_type)
            end
          end
        end
      end
    rescue ex
      Godot.print("[EditorScriptCreation] Notice scene tree dock menus setup: #{ex.message}")
    end

    # 4. Interactive Dialog Presentation
    def self.show_dialog(initial_path : String = "", default_name : String = "", default_base : String = "") : Void
      return unless CrystalIntegrationPlugin.has_editor_interface?
      return if Godot::EditorInterface.singleton_ptr.null?
      ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
      base_ctrl = ed_iface.get_base_control
      return if base_ctrl.pointer.null?

      # Resolve selected node if not provided
      final_name = default_name.strip
      final_base = default_base.strip
      if final_name.empty?
        if sel = ed_iface.call_obj("get_selection")
          if nodes = sel.call_obj("get_selected_nodes")
            if !nodes.pointer.null?
              final_name = nodes.call_str("get_name") rescue ""
              final_base = nodes.call_str("get_class") rescue ""
            end
          end
        end
      end

      final_name = "NewNode" if final_name.empty?
      final_base = "Node" if final_base.empty?
      final_dir = if initial_path.strip.empty? || initial_path.strip == "." || initial_path.strip == "./" || initial_path.strip == "res://" || initial_path.strip == "res://."
                    "res://src"
                  else
                    p = initial_path.strip.rstrip('/')
                    p.starts_with?("res://") ? p : "res://#{p.sub(/^\.\//, "")}"
                  end
      final_file = "#{final_dir}/#{to_snake_case(final_name)}.cr"

      if dlg = @@dialog
        if !dlg.pointer.null?
          @@class_edit.try(&.call("set_text", final_name))
          @@base_opt.try do |bo|
            b_idx = COMMON_BASE_TYPES.index(final_base) || 0
            bo.call("select", b_idx)
          end
          @@tmpl_opt.try do |to|
            to.call("select", final_base.includes?("CharacterBody") ? 1 : 0)
          end
          @@path_edit.try(&.call("set_text", final_file))
          dlg.call("popup_centered", Godot::Vector2i.new(540, 380))
          return
        end
      end

      dlg = Godot.create(Godot::ConfirmationDialog)
      return unless dlg
      dlg.call("set_name", "CrystalScriptCreateDialog")
      dlg.call("set_title", "Create New Crystal Script")
      dlg.call("set_ok_button_text", "Create")
      dlg.call("set_cancel_button_text", "Cancel")

      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_name", "DialogVBox")
      dlg.call("add_child", vbox)

      # Class Name Row
      lbl_class = Godot.create(Godot::Label)
      lbl_class.call("set_text", "Class Name:") if lbl_class
      vbox.call("add_child", lbl_class) if lbl_class

      class_edit = Godot.create(Godot::LineEdit)
      return unless class_edit
      class_edit.call("set_placeholder", "e.g. Player, GameController, LevelManager")
      class_edit.call("set_text", final_name)
      vbox.call("add_child", class_edit)
      @@class_edit = class_edit

      # Base Type Row
      lbl_base = Godot.create(Godot::Label)
      lbl_base.call("set_text", "Inherits:") if lbl_base
      vbox.call("add_child", lbl_base) if lbl_base

      base_opt = Godot.create(Godot::OptionButton)
      return unless base_opt
      COMMON_BASE_TYPES.each_with_index do |node_name, idx|
        base_opt.call("add_item", node_name, idx)
      end
      b_idx = COMMON_BASE_TYPES.index(final_base) || 0
      base_opt.call("select", b_idx)
      vbox.call("add_child", base_opt)
      @@base_opt = base_opt

      # Template Row
      lbl_tmpl = Godot.create(Godot::Label)
      lbl_tmpl.call("set_text", "Template:") if lbl_tmpl
      vbox.call("add_child", lbl_tmpl) if lbl_tmpl

      tmpl_opt = Godot.create(Godot::OptionButton)
      return unless tmpl_opt
      TEMPLATES.each_with_index do |tmpl_name, idx|
        tmpl_opt.call("add_item", tmpl_name, idx)
      end
      tmpl_opt.call("select", final_base.includes?("CharacterBody") ? 1 : 0)
      vbox.call("add_child", tmpl_opt)
      @@tmpl_opt = tmpl_opt

      # Path Row
      lbl_path = Godot.create(Godot::Label)
      lbl_path.call("set_text", "Path:") if lbl_path
      vbox.call("add_child", lbl_path) if lbl_path

      path_edit = Godot.create(Godot::LineEdit)
      return unless path_edit
      path_edit.call("set_text", final_file)
      vbox.call("add_child", path_edit)
      @@path_edit = path_edit

      # Auto-update path when class name changes
      class_edit.connect("text_changed") do |args|
        if args && args.size > 0
          raw_name = args[0].to_s.strip
          if !raw_name.empty?
            cur_p = path_edit.call_str("get_text")
            cur_d = cur_p.empty? ? "res://src" : File.dirname(cur_p)
            cur_d = "res://src" if cur_d.empty? || cur_d == "."
            path_edit.call("set_text", "#{cur_d}/#{to_snake_case(raw_name)}.cr")
          end
        end
      end

      # Auto-select movement template if CharacterBody is chosen
      base_opt.connect("item_selected") do |args|
        if args && args.size > 0
          idx = args[0].as_i64 rescue 0_i64
          selected_base = COMMON_BASE_TYPES[idx]? || "Node"
          if selected_base.includes?("CharacterBody")
            tmpl_opt.call("select", 1)
          end
        end
      end

      # On Confirm: hide dialog, write file, scan filesystem, open in script editor
      dlg.connect("confirmed") do |_args|
        dlg.call("hide") rescue nil

        raw_class = class_edit.call_str("get_text").strip
        raw_class = "NewNode" if raw_class.empty?
        b_idx = base_opt.call_i64("get_selected") rescue 0_i64
        b_type = COMMON_BASE_TYPES[b_idx]? || "Node"
        t_idx = tmpl_opt.call_i64("get_selected") rescue 0_i64
        target_path = path_edit.call_str("get_text").strip
        if target_path.empty? || target_path == "." || target_path == "./"
          target_path = "res://src/#{to_snake_case(raw_class)}.cr"
        end
        target_path = target_path.sub(/^\.\//, "")
        target_path = "res://#{target_path}" unless target_path.starts_with?("res://")
        target_path = "#{target_path}.cr" unless target_path.ends_with?(".cr")

        code = generate_template_code(raw_class, b_type, t_idx)

        disk_path = target_path.sub(/^res:\/\//, "")

        dir_name = File.dirname(disk_path)
        Dir.mkdir_p(dir_name) unless dir_name.empty? || dir_name == "."
        File.write(disk_path, code)
        Godot.print("[CrystalIntegration] Created new Crystal script: #{target_path}")

        # Ensure project entry point includes newly created scripts
        main_cr_path = "src/main.cr"
        if File.exists?(main_cr_path)
          main_content = File.read(main_cr_path)
          unless main_content.includes?(%(require "./**"))
            updated_content = if main_content.includes?(%(require "lapis"))
                                main_content.sub(%(require "lapis"), %(require "lapis"\nrequire "./**"))
                              else
                                %(require "./**"\n) + main_content
                              end
            File.write(main_cr_path, updated_content)
            Godot.print("[CrystalIntegration] Updated src/main.cr to automatically include all project scripts via require \"./**\"")
          end
        end

        if !Godot::EditorInterface.singleton_ptr.null?
          ei = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
          r_fs = ei.get_resource_filesystem
          if !r_fs.pointer.null?
            r_fs.scan rescue nil
          end
          ei.call("select_file", target_path) rescue nil
          r_loader = Godot::ResourceLoader.instance rescue nil
          if r_loader && !r_loader.pointer.null?
            scr_obj = r_loader.load(target_path, "Script", 2_i64) rescue nil
            if scr_obj && !scr_obj.pointer.null?
              ei.call("edit_script", scr_obj) rescue nil
            end
          end
        end
      end

      base_ctrl.call("add_child", dlg)
      @@dialog = dlg
      dlg.call("popup_centered", Godot::Vector2i.new(540, 380))
    rescue ex
      Godot.printerr("[EditorScriptCreation] Error displaying dialog: #{ex.message}")
    end

    def self.generate_template_code(class_name : String, base_type : String, tmpl_idx : Int64) : String
      case tmpl_idx
      when 1 # Physics Movement
        <<-CRYSTAL
        require "lapis"

        # #{class_name} character with physics movement
        node #{class_name} < #{base_type} do
          @[Export(range: 1.0_f32..20.0_f32, step: 0.5_f32)]
          property speed : Float32 = 5.0_f32

          def _ready : Void
            Godot.print("#{class_name} initialized")
          end

          def _physics_process(delta : Float64) : Void
            # Physics movement logic
          end
        end
        CRYSTAL
      when 2 # Tool Script
        <<-CRYSTAL
        require "lapis"

        # In-editor tool script #{class_name}
        @[Tool]
        node #{class_name} < #{base_type} do
          def _ready : Void
            Godot.print("#{class_name} running in editor")
          end

          def _process(delta : Float64) : Void
            # In-editor process step
          end
        end
        CRYSTAL
      when 3 # Empty Class
        <<-CRYSTAL
        require "lapis"

        node #{class_name} < #{base_type} do
        end
        CRYSTAL
      else # Standard Node
        <<-CRYSTAL
        require "lapis"

        # #{class_name} node
        node #{class_name} < #{base_type} do
          def _ready : Void
            Godot.print("#{class_name} initialized")
          end

          def _process(delta : Float64) : Void
          end
        end
        CRYSTAL
      end
    end

    def self.cleanup : Void
      if btn = @@toolbar_button
        if !btn.pointer.null? && btn.alive?
          if parent = btn.call_obj("get_parent")
            parent.call("remove_child", btn) rescue nil
          end
          btn.queue_free rescue nil
        end
        @@toolbar_button = nil
      end
      if dlg = @@dialog
        if !dlg.pointer.null? && dlg.alive?
          if parent = dlg.call_obj("get_parent")
            parent.call("remove_child", dlg) rescue nil
          end
          dlg.queue_free rescue nil
        end
        @@dialog = nil
      end
      @@class_edit = nil
      @@base_opt = nil
      @@tmpl_opt = nil
      @@path_edit = nil
      @@file_dialog = nil
      @@hooked_popups.each do |target_id|
        Godot.clear_signal_subscriptions(target_id) rescue nil
      end
      @@hooked_popups.clear
      @@hooked_script_dialogs.each do |target_id|
        Godot.clear_signal_subscriptions(target_id) rescue nil
      end
      @@hooked_script_dialogs.clear
      @@hooked_create_dialogs.each do |target_id|
        Godot.clear_signal_subscriptions(target_id) rescue nil
      end
      @@hooked_create_dialogs.clear
      @@intercept_crystal_resource = false
    end

    def self.cleanup_on_shutdown : Void
      cleanup
    end
  end
end

alias EditorScriptCreation = Lapis::EditorScriptCreation

module Godot
  alias EditorScriptCreation = ::Lapis::EditorScriptCreation
end
