# tools/lapis/src/tui/views/detail_modal.cr
require "../model"
require "../canvas"
require "./log_view"

module Lapis
  module TUI
    module Views
      module DetailModal
        def self.draw(canvas : Canvas, state : TestRunState, width : Int32, height : Int32) : Nil
          phase = state.selected_phase
          return unless phase

          modal_w = Math.min(width - 4, 110)
          modal_h = Math.min(height - 4, 30)
          return if modal_w < 30 || modal_h < 8

          modal_x = (width - modal_w) // 2
          modal_y = (height - modal_h) // 2

          border_style = Style.new(fg: "38;5;141")

          # 1. Clear modal backdrop with solid dark background
          canvas.fill_rect(modal_x, modal_y, modal_w, modal_h, char: ' ', style: Style.new(bg: "48;5;234"))

          # 2. Double border outer box
          title = " 📋 PHASE INSPECTION: #{phase.name.upcase} "
          title_style = Style.new(fg: "97", bg: "48;5;54", bold: true)
          canvas.draw_box(modal_x, modal_y, modal_w, modal_h, title: title, double_border: true, border_style: border_style, title_style: title_style)

          # 3. Status metadata bar (modal_y + 1)
          status_str = case phase.status
                       when PhaseStatus::Passed then "\e[1;32mPASSED ✔\e[0m"
                       when PhaseStatus::Failed then "\e[1;31mFAILED ✘\e[0m"
                       when PhaseStatus::Running then "\e[1;33mRUNNING ⏳\e[0m"
                       else "\e[38;5;244mPENDING ○\e[0m"
                       end

          meta_text = " Category: \e[1m#{phase.category}\e[0m │ Tag: \e[1;36m#{phase.tag}\e[0m │ Status: #{status_str} │ Duration: \e[1;93m#{phase.duration}s\e[0m │ Exit: #{phase.exit_code}"
          canvas.draw_text(modal_x + 2, modal_y + 1, meta_text, max_w: modal_w - 4)

          # 4. Divider (modal_y + 2)
          draw_divider(canvas, modal_x, modal_y + 2, modal_w, border_style)

          curr_row = modal_y + 3

          # 5. Error excerpt if failed
          if phase.status == PhaseStatus::Failed && phase.error_excerpt
            canvas.draw_text(modal_x + 2, curr_row, "\e[1;31m🚨 ERROR / FAILURE EXCERPT:\e[0m", max_w: modal_w - 4)
            curr_row += 1

            phase.error_excerpt.not_nil!.each_line do |err_l|
              break if curr_row >= modal_y + 8
              canvas.draw_text(modal_x + 4, curr_row, "\e[31m#{err_l}\e[0m", max_w: modal_w - 6)
              curr_row += 1
            end

            draw_divider(canvas, modal_x, curr_row, modal_w, border_style)
            curr_row += 1
          end

          # 6. Log history title
          canvas.draw_text(modal_x + 2, curr_row, "\e[1;96m📜 PHASE LOG OUTPUT (#{phase.log_lines.size} lines):\e[0m", max_w: modal_w - 4)
          curr_row += 1

          # 7. Log lines
          avail_rows = (modal_y + modal_h - 2) - curr_row
          if avail_rows > 0
            p_logs = phase.log_lines
            if p_logs.empty?
              canvas.draw_text(modal_x + 4, curr_row, "\e[38;5;242m(No log output recorded for this phase)\e[0m", max_w: modal_w - 6)
            else
              scroll = Math.max(0, state.detail_scroll_offset)
              start_l = Math.max(0, p_logs.size - avail_rows - scroll)
              end_l = Math.min(start_l + avail_rows - 1, p_logs.size - 1)

              (start_l..end_l).each do |l_idx|
                break if curr_row >= modal_y + modal_h - 2
                raw_l = p_logs[l_idx]
                colored = LogView.colorize_log_line(raw_l)
                canvas.draw_text(modal_x + 4, curr_row, colored, max_w: modal_w - 6)
                curr_row += 1
              end
            end
          end

          # 8. Modal footer hint
          hint = "\e[38;5;244mPress [Esc] or [Enter] to return\e[0m"
          canvas.draw_text(modal_x + modal_w - 36, modal_y + modal_h - 1, hint, max_w: 34)
        end

        private def self.draw_divider(canvas : Canvas, x : Int32, y : Int32, w : Int32, style : Style)
          canvas.set_cell(x, y, '╠', style)
          canvas.set_cell(x + w - 1, y, '╣', style)
          ((x + 1)...(x + w - 1)).each do |c|
            canvas.set_cell(c, y, '═', style)
          end
        end
      end
    end
  end
end
