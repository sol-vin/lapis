# tools/lapis/src/tui/template_manager.cr
require "opal"
require "../core/env"
require "../core/logger"
require "../core/template_store"

module Lapis
  module TUI
    class TemplateManager
      getter? running : Bool = true
      property selected_idx : Int32 = 0
      property search_query : String = ""
      property? searching : Bool = false
      property status_msg : String = ""

      getter templates : Array(Core::TemplateManifest) = [] of Core::TemplateManifest

      def initialize
        refresh_templates
      end

      def self.run : Nil
        new.run
      end

      def refresh_templates : Nil
        @templates = Core::TemplateStore.list_templates
        @selected_idx = @selected_idx.clamp(0, Math.max(0, @templates.size - 1))
      end

      def filtered_templates : Array(Core::TemplateManifest)
        return @templates if @search_query.empty?
        @templates.select do |t|
          t.name.includes?(@search_query.downcase) ||
            t.display_name.downcase.includes?(@search_query.downcase) ||
            t.description.downcase.includes?(@search_query.downcase) ||
            t.tags.any?(&.downcase.includes?(@search_query.downcase))
        end
      end

      def run : Nil
        return unless STDOUT.tty?

        driver = Opal::Terminal.default_driver
        driver.raw_mode do
          driver.enter_alternate_screen
          driver.hide_cursor
          begin
            while @running
              render(driver)
              handle_input(driver)
            end
          ensure
            driver.show_cursor
            driver.exit_alternate_screen
          end
        end
      end

      private def render(driver : Opal::Terminal::Driver)
        w, h = driver.size
        width = Math.max(80, w)
        height = Math.max(24, h)
        buffer = Opal::UI::Buffer.new(width, height)
        render_to_buffer(buffer, width, height)

        driver.write(Opal::Terminal::Screen.move_to(1, 1))
        driver.write(buffer.render_to_string(with_ansi: true))
        driver.flush
      end

      def render_to_buffer(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        # Header
        store_path = Core::TemplateStore.store_dir.to_s
        buffer.put_string(2, 1, ":: LAPIS MODULAR TEMPLATE MANAGER ::", fg: Opal::Color.bright_cyan, bold: true)
        buffer.put_string(42, 1, "│ Store: #{store_path}", fg: Opal::Color.bright_black)

        search_str = @searching ? "Search: [#{@search_query}_]" : "Search: [#{@search_query}] (Press '/' to search)"
        buffer.put_string(2, 2, search_str, fg: @searching ? Opal::Color.bright_yellow : Opal::Color.cyan)
        if !@status_msg.empty?
          buffer.put_string(45, 2, @status_msg, fg: Opal::Color.bright_green)
        end
        buffer.put_string(2, 3, "─" * (width - 4), fg: Opal::Color.bright_black)

        # Split: Left (Templates List - 35 cols), Right (Preview Pane)
        left_w = Math.min(38, (width * 0.4).to_i)
        right_x = left_w + 3
        right_w = width - right_x - 2

        # Vertical Divider
        (4...(height - 3)).each do |y|
          buffer.put_string(left_w + 1, y, "│", fg: Opal::Color.bright_black)
        end

        # Left: Templates List
        items = filtered_templates
        buffer.put_string(2, 4, "INSTALLED TEMPLATES (#{items.size})", fg: Opal::Color.bright_white, bold: true)

        if items.empty?
          buffer.put_string(2, 6, "No templates stored.", fg: Opal::Color.bright_black)
          buffer.put_string(2, 7, "Run 'lapis new template' to save one.", fg: Opal::Color.yellow)
        else
          max_list_items = height - 8
          start_idx = Math.max(0, @selected_idx - (max_list_items // 2))

          items[start_idx, max_list_items]?.try &.each_with_index do |tpl, offset|
            idx = start_idx + offset
            y = 6 + offset
            is_sel = (idx == @selected_idx)

            cursor = is_sel ? "► " : "  "
            fg = is_sel ? Opal::Color.bright_white : Opal::Color.white
            bg = is_sel ? Opal::Color.hex("#2A2B3D") : Opal::Color.none

            label = sprintf("%s%-18s", cursor, tpl.name[0...18])
            buffer.put_string(2, y, label, fg: fg, bg: bg, bold: is_sel)
            buffer.put_string(24, y, "#{tpl.file_count}f", fg: Opal::Color.bright_black, bg: bg)
          end
        end

        # Right: Template Details Preview
        selected_tpl = items[@selected_idx]? || items.first?
        if selected_tpl
          render_details(buffer, selected_tpl, right_x, right_w, height)
        end

        # Footer
        footer_y = height - 2
        buffer.put_string(2, footer_y - 1, "─" * (width - 4), fg: Opal::Color.bright_black)
        controls = "↑/↓: Select │ Enter: Scaffold Project │ /: Search │ D: Delete │ E: Export │ Esc/Q: Exit"
        buffer.put_string(2, footer_y, controls, fg: Opal::Color.bright_white)
      end

      private def render_details(buffer : Opal::UI::Buffer, tpl : Core::TemplateManifest, x : Int32, w : Int32, h : Int32)
        buffer.put_string(x, 4, "TEMPLATE DETAILS", fg: Opal::Color.bright_white, bold: true)

        buffer.put_string(x, 6, "Name:        ", fg: Opal::Color.bright_black)
        buffer.put_string(x + 13, 6, "#{tpl.display_name} (#{tpl.name})", fg: Opal::Color.bright_cyan, bold: true)

        buffer.put_string(x, 7, "Version:     ", fg: Opal::Color.bright_black)
        buffer.put_string(x + 13, 7, "#{tpl.version} (Godot #{tpl.godot_version})", fg: Opal::Color.bright_white)

        buffer.put_string(x, 8, "Author:      ", fg: Opal::Color.bright_black)
        buffer.put_string(x + 13, 8, tpl.author, fg: Opal::Color.cyan)

        buffer.put_string(x, 9, "Description: ", fg: Opal::Color.bright_black)
        buffer.put_string(x + 13, 9, tpl.description, fg: Opal::Color.white, max_width: w - 15)

        buffer.put_string(x, 10, "Tags:        ", fg: Opal::Color.bright_black)
        tag_str = tpl.tags.map { |tag| "[#{tag}]" }.join(" ")
        buffer.put_string(x + 13, 10, tag_str, fg: Opal::Color.bright_yellow)

        buffer.put_string(x, 11, "Files:       ", fg: Opal::Color.bright_black)
        size_mb = sprintf("%.2f MB", tpl.uncompressed_bytes.to_f / (1024.0 * 1024.0))
        buffer.put_string(x + 13, 11, "#{tpl.file_count} files (#{size_mb} uncompressed)", fg: Opal::Color.green)

        buffer.put_string(x, 13, "BUNDLED FILE TREE", fg: Opal::Color.bright_white, bold: true)
        files = Core::TemplateStore.template_files(tpl.name)
        file_y = 15
        max_files = h - 18

        files.first(max_files).each do |f|
          buffer.put_string(x, file_y, "├── #{f}", fg: Opal::Color.bright_black, max_width: w - 4)
          file_y += 1
        end

        if files.size > max_files
          buffer.put_string(x, file_y, "└── ... (#{files.size - max_files} more files)", fg: Opal::Color.bright_black)
        end
      end

      private def handle_input(driver : Opal::Terminal::Driver)
        ev = driver.read_event
        return unless ev.is_a?(Opal::Terminal::KeyEvent)

        if @searching
          if ev.matches?("escape") || ev.matches?("enter")
            @searching = false
          elsif ev.matches?("backspace")
            @search_query = @search_query[0...-1] if @search_query.size > 0
          elsif ch = ev.char
            @search_query += ch
          end
          return
        end

        case ev.name
        when "escape", "esc", "q"
          @running = false
        when "up", "k"
          @selected_idx = Math.max(0, @selected_idx - 1)
        when "down", "j"
          items = filtered_templates
          @selected_idx = Math.min(Math.max(0, items.size - 1), @selected_idx + 1)
        when "enter"
          items = filtered_templates
          if tpl = items[@selected_idx]?
            scaffold_from_template(tpl, driver)
          end
        when "d", "D"
          items = filtered_templates
          if tpl = items[@selected_idx]?
            delete_current_template(tpl)
          end
        when "e", "E"
          items = filtered_templates
          if tpl = items[@selected_idx]?
            export_current_template(tpl)
          end
        when "/"
          @searching = true
        end
      end

      private def scaffold_from_template(tpl : Core::TemplateManifest, driver : Opal::Terminal::Driver)
        driver.exit_alternate_screen
        driver.show_cursor

        print "\nEnter new project name to scaffold from '#{tpl.name}': "
        proj_name = STDIN.gets.try(&.strip) || ""

        if !proj_name.empty?
          Commands::Scaffold.run(["game", proj_name, "--template", tpl.name])
          puts "\nPress Enter to return to Template Manager..."
          STDIN.gets
        end

        driver.enter_alternate_screen
        driver.hide_cursor
        refresh_templates
      end

      private def delete_current_template(tpl : Core::TemplateManifest)
        Core::TemplateStore.delete_template(tpl.name)
        @status_msg = "Deleted template '#{tpl.name}'"
        refresh_templates
      end

      private def export_current_template(tpl : Core::TemplateManifest)
        out_name = "#{tpl.name}.zip"
        if Core::TemplateStore.export_template(tpl.name, Path.new(out_name))
          @status_msg = "Exported to #{out_name}"
        else
          @status_msg = "Export failed"
        end
      end
    end
  end
end
