# tools/lapis/src/tui/views/failures_view.cr
require "../model"
require "../canvas"
require "opal"

module Lapis
  module TUI
    module Views
      module FailuresView
        def self.draw(canvas : Canvas, state : TestRunState, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
          return if width < 25 || height < 4

          border_style = Style.new(fg: "38;5;196")
          title_style = Style.new(fg: "196", bold: true)
          title = " [!] TEST FAILURES & ERROR TRIAGE (#{state.failed_phases} Failed Phases) "
          canvas.draw_box(x, y, width, height, title: title, border_style: border_style, title_style: title_style)

          fails = state.failed_phases_list
          if fails.empty?
            canvas.draw_text(x + 4, y + 2, "\e[1;32m[OK] No test failures detected!\e[0m All completed phases passed cleanly.", max_w: width - 8)
            canvas.draw_text(x + 4, y + 4, "\e[38;5;244mPress [1] to return to the live Dashboard or [3] for the full Suite Breakdown.\e[0m", max_w: width - 8)
            return
          end

          # Split: Left 30% list of failed phases, Right 70% failure detail
          left_w = Math.min(width - 20, Math.max(24, (width * 0.32).to_i))
          right_x = x + left_w + 1
          right_w = width - left_w - 2

          # Vertical divider
          (y + 1...y + height - 1).each do |div_y|
            canvas.set_cell(x + left_w, div_y, '│', Style.new(fg: "38;5;240"))
          end

          sel_idx = state.failure_selected_index.clamp(0, fails.size - 1)

          # Draw Left Pane: Failed Phases
          fails.each_with_index do |phase, idx|
            row_y = y + 1 + idx
            break if row_y >= y + height - 1

            is_sel = (idx == sel_idx)
            if is_sel
              canvas.fill_rect(x + 1, row_y, left_w - 1, 1, char: ' ', style: Style.new(bg: "48;5;237"))
            end

            cursor = is_sel ? "\e[1;31m►\e[0m" : " "
            canvas.draw_text(x + 2, row_y, "#{cursor} \e[1;31m[X]\e[0m #{phase.name}", max_w: left_w - 4)
          end

          # Draw Right Pane: Selected Failure Detail
          selected = fails[sel_idx]?
          return unless selected

          curr_y = y + 1
          canvas.draw_text(right_x + 2, curr_y, "\e[1;97mPhase: \e[1;31m#{selected.name}\e[0m (#{selected.category})  Exit: \e[1;33m#{selected.exit_code}\e[0m", max_w: right_w - 4)
          curr_y += 1

          if err = selected.error_excerpt
            canvas.draw_text(right_x + 2, curr_y, "\e[1;31mFailure Summary:\e[0m", max_w: right_w - 4)
            curr_y += 1
            err.each_line do |el|
              break if curr_y >= y + height - 2
              canvas.draw_text(right_x + 4, curr_y, "\e[31m#{el}\e[0m", max_w: right_w - 6)
              curr_y += 1
            end
          end

          # Recent log output from failed phase
          if curr_y < y + height - 3
            curr_y += 1
            canvas.draw_text(right_x + 2, curr_y, "\e[1;96mRecent Phase Logs:\e[0m", max_w: right_w - 4)
            curr_y += 1
            tail_lines = selected.log_lines.to_a.last(Math.max(1, y + height - 2 - curr_y))
            tail_lines.each do |line|
              break if curr_y >= y + height - 1
              canvas.draw_text(right_x + 4, curr_y, line, max_w: right_w - 6, default_style: Style.new(fg: "38;5;250"))
              curr_y += 1
            end
          end
        end
      end
    end
  end
end
