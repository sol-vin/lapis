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

        def self.draw(canvas : Canvas, state : TestRunState, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
          return if width < 20 || height < 4

          border_style = Style.new(fg: "38;5;244")
          title_style = Style.new(fg: "96", bold: true)
          canvas.draw_box(x, y, width, height, title: " LIVE EXECUTION LOGS ", border_style: border_style, title_style: title_style)

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

          all_logs = state.global_logs
          total_logs = all_logs.size

          if total_logs == 0
            canvas.draw_text(x + 2, y + 3, "(Waiting for test output...)", max_w: width - 4, default_style: Style.new(fg: "38;5;242"))
            return
          end

          scroll = Math.max(0, state.log_scroll_offset)
          start_idx = Math.max(0, total_logs - log_rows - scroll)
          end_idx = Math.min(start_idx + log_rows - 1, total_logs - 1)

          row_offset = 0
          (start_idx..end_idx).each do |idx|
            line_y = y + 3 + row_offset
            break if line_y >= y + height - 1

            raw_line = all_logs[idx]
            colored = colorize_log_line(raw_line)
            canvas.draw_text(x + 2, line_y, colored, max_w: width - 4)

            row_offset += 1
          end
        end
      end
    end
  end
end
