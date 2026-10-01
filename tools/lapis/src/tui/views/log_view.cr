# tools/lapis/src/tui/views/log_view.cr
require "../model"
require "../canvas"

module Lapis
  module TUI
    module Views
      module LogView
        def self.colorize_log_line(line : String) : String
          cleaned = line.gsub('\r', "")
          if cleaned.includes?("✔") || cleaned.includes?("[PASS]") || cleaned.includes?("passed cleanly") || cleaned.includes?("passed successfully")
            "\e[32m#{cleaned}\e[0m"
          elsif cleaned.includes?("✘") || cleaned.includes?("[FAIL]") || cleaned.includes?("Error:") || cleaned.includes?("FAILED") || cleaned.includes?("Failures:")
            "\e[1;31m#{cleaned}\e[0m"
          elsif cleaned.includes?("WARNING:") || cleaned.includes?("warn")
            "\e[33m#{cleaned}\e[0m"
          elsif cleaned.starts_with?("[Test:") || cleaned.starts_with?("[Lapis]") || cleaned.starts_with?("[Spec")
            "\e[1;36m#{cleaned}\e[0m"
          elsif cleaned.starts_with?("===") || cleaned.starts_with?("---")
            "\e[38;5;141m#{cleaned}\e[0m"
          else
            "\e[38;5;250m#{cleaned}\e[0m"
          end
        end

        def self.highlight_search(text : String, query : String?) : String
          return text unless query && !query.empty?
          return text unless text.downcase.includes?(query.downcase)
          text.gsub(Regex.new(Regex.escape(query), Regex::Options::IGNORE_CASE)) do |match|
            "\e[1;97;48;5;166m#{match}\e[0m"
          end
        end

        def self.draw(canvas : Canvas, state : TestRunState, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
          return if width < 20 || height < 4

          border_style = Style.new(fg: "38;5;244")
          title_style = Style.new(fg: "96", bold: true)
          title = state.follow_mode ? " LIVE EXECUTION LOGS [AUTO-SCROLL] " : " LIVE EXECUTION LOGS [PAUSED - SCROLLING] "
          canvas.draw_box(x, y, width, height, title: title, border_style: border_style, title_style: title_style)

          # Active test indicator row (y + 1)
          active_phase = state.active_phase
          curr_test = active_phase ? active_phase.current_test : nil
          test_desc = curr_test ? "► #{curr_test}" : (state.overall_status == OverallStatus::Running ? "► Executing test suite..." : "Ready")
          canvas.draw_text(x + 2, y + 1, test_desc, max_w: width - 4, default_style: Style.new(fg: "93", bold: true))

          # Horizontal divider (y + 2)
          canvas.set_cell(x, y + 2, '├', border_style)
          canvas.set_cell(x + width - 1, y + 2, '┤', border_style)
          ((x + 1)...(x + width - 1)).each do |c|
            canvas.set_cell(c, y + 2, '─', border_style)
          end

          # Log lines area: (y + 3) to (y + height - 2)
          log_rows = height - 4
          return if log_rows <= 0

          # Filter logs if search query active
          q = state.search_query
          all_logs = if q && !q.empty?
                       state.global_logs.select { |l| l.downcase.includes?(q.downcase) }
                     else
                       state.global_logs
                     end
          total_logs = all_logs.size

          if total_logs == 0
            empty_msg = q ? "(No logs matching '#{q}')" : "(Waiting for test output...)"
            canvas.draw_text(x + 2, y + 3, empty_msg, max_w: width - 4, default_style: Style.new(fg: "38;5;242"))
            return
          end

          scroll = state.follow_mode ? 0 : Math.max(0, state.log_scroll_offset)
          start_idx = Math.max(0, total_logs - log_rows - scroll)
          end_idx = Math.min(start_idx + log_rows - 1, total_logs - 1)

          content_w = total_logs > log_rows ? width - 4 : width - 3

          row_offset = 0
          (start_idx..end_idx).each do |idx|
            line_y = y + 3 + row_offset
            break if line_y >= y + height - 1

            raw_line = all_logs[idx]
            colored = colorize_log_line(raw_line)
            highlighted = highlight_search(colored, q)
            canvas.draw_text(x + 2, line_y, highlighted, max_w: content_w)

            row_offset += 1
          end

          # Draw scrollbar if content exceeds viewport
          if total_logs > log_rows
            track_x = x + width - 2
            max_scroll = Math.max(1, total_logs - log_rows)
            scroll_pos = (total_logs - log_rows - scroll).clamp(0, max_scroll)
            thumb_y = y + 3 + ((scroll_pos.to_f / max_scroll) * (log_rows - 1)).round.to_i

            (0...log_rows).each do |r_idx|
              cur_y = y + 3 + r_idx
              is_thumb = (cur_y == thumb_y)
              char = is_thumb ? '█' : '│'
              style = is_thumb ? Style.new(fg: "38;5;141") : Style.new(fg: "38;5;238")
              canvas.set_cell(track_x, cur_y, char, style)
            end
          end
        end
      end
    end
  end
end
