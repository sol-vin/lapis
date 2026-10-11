# tools/lapis/src/tui/new_wizard.cr
require "opal"
require "../commands/scaffold"
require "../commands/scaffold/feature_configurator"
require "../commands/editor"
require "../core/env"
require "../core/template_store"

module Lapis
  module TUI
    class NewWizard
      enum ProjectType
        Game
        Addon
        Example
      end

      enum Step
        SelectTemplate
        SelectType = 0
        EnterDetails
        ToggleFeatures
        SelectAddons
        PickDirectory
        PreviewAndCreate
      end

      property project_type : ProjectType = ProjectType::Game
      property project_name : String = "my_game"
      property author : String = "Developer"
      property description : String = "A high-performance Godot game powered by Crystal"
      property target_dir : String = "."
      property active_field : Int32 = 0
      property current_step : Step = Step::SelectTemplate
      property? running : Bool = true

      property selected_template_idx : Int32 = 0
      property selected_template_name : String? = nil
      property global_templates : Array(Core::TemplateManifest) = [] of Core::TemplateManifest

      property features : Commands::Scaffold::ProjectFeatures = Commands::Scaffold::ProjectFeatures.new
      property active_feature_idx : Int32 = 0

      property available_addons : Array(String) = [] of String
      property selected_addons : Set(String) = Set(String).new
      property active_addon_idx : Int32 = 0

      getter file_dialog : Opal::UI::FileDialog

      def initialize
        @target_dir = File.expand_path(".")
        @file_dialog = Opal::UI::FileDialog.new(initial_path: @target_dir, mode: :open_dir)
        load_templates_and_addons
      end

      def self.run : Nil
        new.run
      end

      def load_templates_and_addons : Nil
        @global_templates = Core::TemplateStore.list_templates

        # Discover available addons in workspace
        root = Core::Env::ROOT_DIR
        addons_dir = root.join("addons")
        if Dir.exists?(addons_dir)
          Dir.each_child(addons_dir) do |c|
            if Dir.exists?(addons_dir.join(c)) && !c.starts_with?(".") && c != "crystal_integration"
              @available_addons << c unless @available_addons.includes?(c)
            end
          end
        end
        # Ensure default dummy addons are listed if known
        ["dummy_inventory", "dummy_dialogue", "dummy_audio"].each do |d|
          @available_addons << d unless @available_addons.includes?(d)
        end
      end

      def run : Nil
        return unless STDOUT.tty?

        driver = Opal::Terminal.default_driver
        driver.raw_mode do
          driver.enter_alternate_screen
          driver.hide_cursor
          diff_renderer = Opal::UI::DiffRenderer.new(driver)
          begin
            while @running
              render(driver, diff_renderer)
              ev = driver.poll_event(50)
              handle_input(ev, driver, diff_renderer) if ev
            end
          ensure
            driver.show_cursor
            driver.exit_alternate_screen
          end
        end
      end

      def render_to_buffer(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        # Header
        buffer.put_string(2, 1, ":: LAPIS PROJECT SCAFFOLDING WIZARD & CONFIGURATOR ::", fg: Opal::Color.bright_cyan, bold: true)
        step_title = case @current_step
                     when Step::SelectTemplate then "Step 1 of 5: Base Template Selection"
                     when Step::EnterDetails   then "Step 2 of 5: Project Metadata & Path"
                     when Step::ToggleFeatures then "Step 3 of 5: Engine Feature Toggles"
                     when Step::SelectAddons   then "Step 4 of 5: Modular Addon Selection"
                     when Step::PickDirectory  then "Directory Picker"
                     else                           "Step 5 of 5: Preview & Scaffold Execution"
                     end
        buffer.put_string(2, 2, step_title, fg: Opal::Color.bright_yellow, bold: true)
        buffer.put_string(2, 3, "─" * (width - 4), fg: Opal::Color.bright_black)

        case @current_step
        when Step::SelectTemplate
          render_select_template(buffer, width, height)
        when Step::EnterDetails
          render_enter_details(buffer, width, height)
        when Step::ToggleFeatures
          render_toggle_features(buffer, width, height)
        when Step::SelectAddons
          render_select_addons(buffer, width, height)
        when Step::PickDirectory
          @file_dialog.render(buffer, 2, 4, width - 4, height - 7)
        when Step::PreviewAndCreate
          render_preview(buffer, width, height)
        end

        # Footer
        y = height - 2
        buffer.put_string(2, y, "─" * (width - 4), fg: Opal::Color.bright_black)
        hints = case @current_step
                when Step::PickDirectory
                  "↑/↓: Browse │ Enter: Open/Select │ Space: Confirm Selection │ Esc: Back"
                when Step::ToggleFeatures, Step::SelectAddons
                  "↑/↓: Navigate │ Space: Toggle Checkbox │ Enter: Next Step │ Esc: Back"
                when Step::PreviewAndCreate
                  "Enter: Create Project │ E: Create & Launch Editor │ Esc: Back"
                else
                  "Tab / ↑↓: Navigate │ Enter: Next │ F: Choose Folder │ Esc: Exit"
                end
        buffer.put_string(2, y + 1, hints, fg: Opal::Color.cyan)
      end

      private def render(driver : Opal::Terminal::Driver, diff_renderer : Opal::UI::DiffRenderer)
        w, h = driver.size
        width = Math.max(40, w)
        height = Math.max(16, h)
        buffer = Opal::UI::Buffer.new(width, height)
        render_to_buffer(buffer, width, height)
        diff_renderer.render(buffer)
      end

      private def all_template_options : Array(NamedTuple(id: String?, type: ProjectType, label: String, desc: String))
        opts = [] of NamedTuple(id: String?, type: ProjectType, label: String, desc: String)
        opts << {id: nil.as(String?), type: ProjectType::Game, label: "[BUILTIN] Standalone Game Starter", desc: "A clean Godot game project with Crystal main loop, scenes, and GDExtension bridge."}
        opts << {id: nil.as(String?), type: ProjectType::Addon, label: "[BUILTIN] GDExtension Addon Template", desc: "A modular, redistributable Godot addon packaged with crystal.gdextension."}
        opts << {id: nil.as(String?), type: ProjectType::Example, label: "[BUILTIN] Showcase Example Demo", desc: "A self-contained showcase demonstrating engine features."}

        @global_templates.each do |gt|
          opts << {
            id: gt.name,
            type: ProjectType::Game,
            label: "[GLOBAL]  #{gt.display_name} (#{gt.name})",
            desc: "#{gt.description} (by #{gt.author} · #{gt.file_count} files)",
          }
        end
        opts
      end

      private def render_select_template(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(4, 5, "Choose a starter template or custom global template:", fg: Opal::Color.bright_white)

        options = all_template_options
        max_show = height - 10
        start_idx = Math.max(0, @selected_template_idx - (max_show // 2))

        options[start_idx, max_show]?.try &.each_with_index do |opt, offset|
          idx = start_idx + offset
          selected = (idx == @selected_template_idx)
          bullet = selected ? " (*) " : " ( ) "
          fg = selected ? Opal::Color.bright_green : Opal::Color.white

          y = 7 + (offset * 2)
          break if y >= height - 4

          buffer.put_string(6, y, "#{bullet}#{opt[:label]}", fg: fg, bold: selected)
          buffer.put_string(11, y + 1, opt[:desc], fg: Opal::Color.bright_black, max_width: width - 15)
        end
      end

      private def render_enter_details(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(4, 5, "Specify project name and destination location:", fg: Opal::Color.bright_white)

        fields = [
          {"Project Name", @project_name, "Alphanumeric identifier (e.g. chronotrigger_remake)"},
          {"Target Directory", @target_dir, "Destination folder (Press 'F' for visual folder picker)"},
          {"Author", @author, "Package creator or studio name"},
          {"Description", @description, "Short summary of the project"},
        ]

        fields.each_with_index do |f_info, idx|
          title, value, hint = f_info
          selected = (idx == @active_field)
          cursor_char = selected ? " ► " : "   "
          fg = selected ? Opal::Color.bright_cyan : Opal::Color.white

          y = 7 + (idx * 3)
          buffer.put_string(6, y, "#{cursor_char}#{title}:", fg: fg, bold: selected)
          box_str = "[ #{value} ]"
          buffer.put_string(24, y, box_str, fg: selected ? Opal::Color.bright_white : Opal::Color.cyan)
          buffer.put_string(24, y + 1, hint, fg: Opal::Color.bright_black)
        end
      end

      private def feature_list : Array(NamedTuple(key: Symbol, label: String, enabled: Bool, desc: String))
        [
          {key: :physics_2d, label: "2D Engine & Physics Support", enabled: @features.physics_2d, desc: "CanvasItem, Sprite2D, TileMap, 2D physics, and pixel-snap rendering."},
          {key: :physics_3d, label: "3D Engine & Physics Support", enabled: @features.physics_3d, desc: "Node3D, MeshInstance3D, CharacterBody3D, and 3D Jolt/Godot physics."},
          {key: :tool_testers, label: "In-Editor Tool Testers", enabled: @features.tool_testers, desc: "Mounts live ToolTester2D and ToolTester3D in editor for instant node testing."},
          {key: :audio_singleton, label: "Audio Manager Autoload", enabled: @features.audio_singleton, desc: "Global AudioManager singleton for clean SFX/music playback and pooling."},
          {key: :debug_hud, label: "Debug HUD & Telemetry Overlay", enabled: @features.debug_hud, desc: "Lightweight on-screen overlay showing FPS, ObjectDB counts, and memory usage."},
          {key: :input_map, label: "Default Input Action Map", enabled: @features.input_map, desc: "Pre-wired movement, jump, and interact keyboard/gamepad action bindings."},
        ]
      end

      private def render_toggle_features(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(4, 5, "Toggle engine modules and gameplay systems (Space to toggle):", fg: Opal::Color.bright_white)

        items = feature_list
        items.each_with_index do |item, idx|
          is_active = (idx == @active_feature_idx)
          box = item[:enabled] ? "[x] " : "[ ] "
          fg = is_active ? Opal::Color.bright_yellow : (item[:enabled] ? Opal::Color.bright_green : Opal::Color.white)
          bg = is_active ? Opal::Color.hex("#2A2B3D") : Opal::Color.none

          y = 7 + (idx * 2)
          break if y >= height - 4

          cursor = is_active ? "► " : "  "
          buffer.put_string(6, y, "#{cursor}#{box}#{item[:label]}", fg: fg, bg: bg, bold: is_active)
          buffer.put_string(12, y + 1, item[:desc], fg: Opal::Color.bright_black, max_width: width - 16)
        end
      end

      private def render_select_addons(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(4, 5, "Select optional addons to bundle into addons/ (Space to toggle):", fg: Opal::Color.bright_white)

        if @available_addons.empty?
          buffer.put_string(6, 7, "No optional addons detected in workspace.", fg: Opal::Color.bright_black)
          buffer.put_string(6, 8, "Official crystal_integration will be bundled automatically.", fg: Opal::Color.green)
          return
        end

        @available_addons.each_with_index do |addon, idx|
          is_active = (idx == @active_addon_idx)
          is_checked = @selected_addons.includes?(addon)
          box = is_checked ? "[x] " : "[ ] "
          fg = is_active ? Opal::Color.bright_yellow : (is_checked ? Opal::Color.bright_green : Opal::Color.white)
          bg = is_active ? Opal::Color.hex("#2A2B3D") : Opal::Color.none

          y = 7 + (idx * 2)
          break if y >= height - 4

          cursor = is_active ? "► " : "  "
          buffer.put_string(6, y, "#{cursor}#{box}#{addon}", fg: fg, bg: bg, bold: is_active)
          addon_desc = case addon
                       when "dummy_inventory" then "Modular slot-based item and inventory system"
                       when "dummy_dialogue"  then "Branching dialogue and text narrative engine"
                       when "dummy_audio"     then "Advanced positional audio bus manager"
                       else                        "Godot extension addon"
                       end
          buffer.put_string(12, y + 1, addon_desc, fg: Opal::Color.bright_black)
        end
      end

      private def render_preview(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(4, 5, "Preview & Confirm Creation (Review before scaffolding):", fg: Opal::Color.bright_white)

        full_dest = File.join(@target_dir, @project_name)
        tpl_name = @selected_template_name || "Default Builtin"

        buffer.put_string(6, 7, "Project Name: #{@project_name}", fg: Opal::Color.bright_white, bold: true)
        buffer.put_string(6, 8, "Type:         #{@project_type}", fg: Opal::Color.yellow)
        buffer.put_string(6, 9, "Destination:  #{full_dest}", fg: Opal::Color.bright_white)
        buffer.put_string(6, 10, "Template:     #{tpl_name}", fg: Opal::Color.green)
        buffer.put_string(6, 11, "Author:       #{@author}", fg: Opal::Color.cyan)
        buffer.put_string(6, 12, "Description:  #{@description}", fg: Opal::Color.cyan)

        # Feature Summary
        f_active = [] of String
        f_active << "2D" if @features.physics_2d
        f_active << "3D" if @features.physics_3d
        f_active << "Audio" if @features.audio_singleton
        f_active << "HUD" if @features.debug_hud
        f_active << "Testers" if @features.tool_testers
        buffer.put_string(6, 12, "Features:    #{f_active.join(", ")}", fg: Opal::Color.bright_yellow)

        addons_str = (["crystal_integration"] + @selected_addons.to_a).join(", ")
        buffer.put_string(6, 13, "Addons:      #{addons_str}", fg: Opal::Color.magenta)

        buffer.put_string(6, 15, "Planned Directory Layout:", fg: Opal::Color.bright_black)
        files = ["project.godot", "shard.yml", "Makefile", "src/main.cr", "scenes/main.tscn", "bin/"]
        files << "src/audio_manager.cr" if @features.audio_singleton
        files << "src/debug_hud.cr" if @features.debug_hud
        @selected_addons.each do |a|
          files << "addons/#{a}/"
        end

        files.each_with_index do |f, idx|
          break if idx > 6
          buffer.put_string(8, 16 + idx, "├── #{f}", fg: Opal::Color.white)
        end
      end

      private def handle_input(ev : Opal::Terminal::KeyEvent | Opal::Terminal::MouseEvent | Opal::Terminal::ResizeEvent, driver : Opal::Terminal::Driver, diff_renderer : Opal::UI::DiffRenderer)
        if ev.is_a?(Opal::Terminal::ResizeEvent)
          diff_renderer.invalidate!
          return
        end

        return unless ev.is_a?(Opal::Terminal::KeyEvent)

        if @current_step == Step::PickDirectory
          if ev.matches?("escape")
            @current_step = Step::EnterDetails
          elsif @file_dialog.handle_key(ev)
            if @file_dialog.confirmed?
              @target_dir = @file_dialog.selected_path || @target_dir
              @current_step = Step::EnterDetails
            end
          elsif ev.matches?("space")
            @target_dir = @file_dialog.current_path
            @current_step = Step::EnterDetails
          end
          return
        end

        case ev.name
        when "escape", "esc"
          if @current_step == Step::SelectTemplate
            @running = false
          else
            prev_val = Math.max(0, @current_step.value - 1)
            @current_step = Step.new(prev_val)
          end
        when "up"
          handle_up_key
        when "down"
          handle_down_key
        when "tab"
          if @current_step == Step::EnterDetails
            @active_field = (@active_field + 1) % 4
          end
        when "enter"
          handle_enter_key(driver)
        when "space"
          handle_space_key
        when "backspace"
          if @current_step == Step::EnterDetails
            backspace_active_field
          end
        else
          if ch = ev.char
            case ch
            when 'f', 'F'
              if @current_step == Step::EnterDetails
                @file_dialog.load_entries(@target_dir)
                @current_step = Step::PickDirectory
              end
            when 'e', 'E'
              if @current_step == Step::PreviewAndCreate
                execute_scaffold(open_editor: true)
              end
            else
              if @current_step == Step::EnterDetails
                append_to_active_field(ch)
              end
            end
          end
        end
      end

      private def handle_up_key
        case @current_step
        when Step::SelectTemplate
          @selected_template_idx = Math.max(0, @selected_template_idx - 1)
        when Step::EnterDetails
          @active_field = Math.max(0, @active_field - 1)
        when Step::ToggleFeatures
          @active_feature_idx = Math.max(0, @active_feature_idx - 1)
        when Step::SelectAddons
          @active_addon_idx = Math.max(0, @active_addon_idx - 1)
        end
      end

      private def handle_down_key
        case @current_step
        when Step::SelectTemplate
          max_idx = all_template_options.size - 1
          @selected_template_idx = Math.min(max_idx, @selected_template_idx + 1)
        when Step::EnterDetails
          @active_field = Math.min(3, @active_field + 1)
        when Step::ToggleFeatures
          @active_feature_idx = Math.min(feature_list.size - 1, @active_feature_idx + 1)
        when Step::SelectAddons
          max_a = Math.max(0, @available_addons.size - 1)
          @active_addon_idx = Math.min(max_a, @active_addon_idx + 1)
        end
      end

      private def handle_space_key
        case @current_step
        when Step::ToggleFeatures
          case @active_feature_idx
          when 0 then @features.physics_2d = !@features.physics_2d
          when 1 then @features.physics_3d = !@features.physics_3d
          when 2 then @features.tool_testers = !@features.tool_testers
          when 3 then @features.audio_singleton = !@features.audio_singleton
          when 4 then @features.debug_hud = !@features.debug_hud
          when 5 then @features.input_map = !@features.input_map
          end
        when Step::SelectAddons
          if addon = @available_addons[@active_addon_idx]?
            if @selected_addons.includes?(addon)
              @selected_addons.delete(addon)
            else
              @selected_addons.add(addon)
            end
          end
        end
      end

      private def handle_enter_key(driver : Opal::Terminal::Driver)
        case @current_step
        when Step::SelectTemplate
          opt = all_template_options[@selected_template_idx]? || all_template_options.first
          @selected_template_name = opt[:id]
          @project_type = opt[:type]
          @current_step = Step::EnterDetails
        when Step::EnterDetails
          if @project_type == ProjectType::Game
            @current_step = Step::ToggleFeatures
          else
            @current_step = Step::PreviewAndCreate
          end
        when Step::ToggleFeatures
          @current_step = Step::SelectAddons
        when Step::SelectAddons
          @current_step = Step::PreviewAndCreate
        when Step::PreviewAndCreate
          execute_scaffold(open_editor: false)
        end
      end

      private def append_to_active_field(ch : Char?)
        return unless ch
        case @active_field
        when 0 then @project_name += ch
        when 1 then @target_dir += ch
        when 2 then @author += ch
        when 3 then @description += ch
        end
      end

      private def backspace_active_field
        case @active_field
        when 0 then @project_name = @project_name[0...-1] if @project_name.size > 0
        when 1 then @target_dir = @target_dir[0...-1] if @target_dir.size > 0
        when 2 then @author = @author[0...-1] if @author.size > 0
        when 3 then @description = @description[0...-1] if @description.size > 0
        end
      end

      private def execute_scaffold(open_editor : Bool) : Nil
        driver = Opal::Terminal.default_driver
        driver.exit_alternate_screen
        driver.show_cursor

        puts Opal.style.bold.fg(:green).render("\n=== Scaffolding #{@project_name} ===\n")

        case @project_type
        when ProjectType::Game
          Commands::Scaffold.scaffold_game(
            name: @project_name,
            target_dir: Path.new(@target_dir),
            force: false,
            local_dep: false,
            skip_godot: false,
            template_name: @selected_template_name,
            features: @features,
            addons: @selected_addons.to_a
          )
        when ProjectType::Addon
          Commands::Scaffold.scaffold_addon(
            name: @project_name,
            target_dir: Path.new(@target_dir),
            author: @author,
            desc: @description
          )
        when ProjectType::Example
          Commands::Scaffold.scaffold_example(@project_name, Path.new(@target_dir))
        end

        if open_editor
          dest = File.join(@target_dir, @project_name)
          puts Opal.style.bold.fg(:cyan).render("\nLaunching Godot Editor in #{dest}...\n")
          Commands::Editor.run(["-p", dest])
        else
          puts "\n\e[32m✔ Project created successfully!\e[0m Press Enter to return to Lapis CLI..."
          STDIN.gets
        end

        @running = false
      end
    end
  end
end
