# tools/lapis/src/tui/views/phases_view.cr
require "../model"
require "../canvas"

module Lapis
  module TUI
    module Views
      module PhasesView
        SPINNERS = ["◐", "◓", "◑", "◒"]

        def self.draw(canvas : Canvas, state : TestRunState, x : Int32, y : Int32, width : Int32, height : Int32, frame_count : Int32 = 0) : Nil
          return if width < 15 || height < 3

          border_style = Style.new(fg: "38;5;244")
          title_style = Style.new(fg: "96", bold: true)
          canvas.draw_box(x, y, width, height, title: " TEST PHASES & CHECKLIST ", border_style: border_style, title_style: title_style)

          max_items = height - 2
          phases = state.phases
          return if phases.empty?

          selected_idx = state.selected_phase_index

          # Windowing slice when phases exceed viewport height
          start_idx = 0
          if phases.size > max_items
            if selected_idx >= max_items - 2
              start_idx = Math.min(selected_idx - max_items // 2, phases.size - max_items)
            end
          end
          end_idx = Math.min(start_idx + max_items - 1, phases.size - 1)

          spinner_char = SPINNERS[frame_count % SPINNERS.size]

          (start_idx..end_idx).each_with_index do |idx, offset|
            row_y = y + 1 + offset
            break if row_y >= y + height - 1

            phase = phases[idx]
            is_selected = (idx == selected_idx)

            # Highlight selected row
            if is_selected
              canvas.fill_rect(x + 1, row_y, width - 2, 1, char: ' ', style: Style.new(bg: "48;5;237"))
            end

            cursor = is_selected ? "\e[1;36m►\e[0m" : " "
            canvas.draw_text(x + 2, row_y, cursor)

            icon = case phase.status
                   when PhaseStatus::Running
                     "\e[1;33m#{spinner_char}\e[0m"
                   when PhaseStatus::Passed
                     "\e[1;32m✔\e[0m"
                   when PhaseStatus::Failed
                     "\e[1;31m✘\e[0m"
                   when PhaseStatus::Skipped
                     "\e[38;5;242m⊘\e[0m"
                   else
                     "\e[38;5;242m○\e[0m"
                   end
            canvas.draw_text(x + 4, row_y, icon)

            # Duration badge
            dur_str = if phase.duration > 0
                        sprintf("%4.1fs", phase.duration)
                      else
                        "     "
                      end

            dur_x = x + width - 7
            canvas.draw_text(dur_x, row_y, "\e[38;5;244m#{dur_str}\e[0m")

            # Phase name
            max_name_w = Math.max(5, width - 14)
            name_style = if is_selected
                           Style.new(bold: true)
                         elsif phase.status == PhaseStatus::Failed
                           Style.new(fg: "31")
                         elsif phase.status == PhaseStatus::Passed
                           Style.new(fg: "37")
                         else
                           Style.new(fg: "38;5;244")
                         end

            canvas.draw_text(x + 6, row_y, phase.name, max_w: max_name_w, default_style: name_style)
          end
        end
      end
    end
  end
end
