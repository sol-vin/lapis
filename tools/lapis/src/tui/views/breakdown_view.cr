# tools/lapis/src/tui/views/breakdown_view.cr
require "../model"
require "../canvas"
require "opal"

module Lapis
  module TUI
    module Views
      module BreakdownView
        def self.draw(canvas : Canvas, state : TestRunState, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
          return if width < 30 || height < 4

          border_style = Style.new(fg: "38;5;141")
          title_style = Style.new(fg: "141", bold: true)
          title = if state.breakdown_sort_by_duration
                    " [ COMPLETE TEST SUITE BREAKDOWN (#{state.phases.size} Suites Registered) · DURATION PROFILE (Bar: '|' · Longest at top) ] "
                  else
                    " [ COMPLETE TEST SUITE BREAKDOWN (#{state.phases.size} Suites Registered · Press 'd' for duration profile) ] "
                  end
          canvas.draw_box(x, y, width, height, title: title, border_style: border_style, title_style: title_style)

          phases = if state.breakdown_sort_by_duration
                     state.phases.sort_by { |p| -p.duration }
                   else
                     state.phases
                   end

          if phases.empty?
            canvas.draw_text(x + 4, y + 2, "\e[38;5;244mNo test suites registered in this test run.\e[0m")
            return
          end

          max_dur = phases.map(&.duration).max? || 0.001
          max_dur = 0.001 if max_dur <= 0.0

          # Table Header Row (y + 1)
          hdr_y = y + 1
          header_text = if state.breakdown_sort_by_duration
                          "\e[1;96mRANK STATUS   TAG       TEST SUITE / PHASE                ASSERTIONS     DURATION   RUNTIME BAR PROFILE ('|')\e[0m"
                        else
                          "\e[1;96mSTATUS   TAG       TEST SUITE / PHASE                CATEGORY    ASSERTIONS     DURATION   EXIT\e[0m"
                        end
          canvas.draw_text(x + 2, hdr_y, header_text, max_w: width - 4)

          # Table Divider (y + 2)
          canvas.set_cell(x, y + 2, '├', border_style)
          canvas.set_cell(x + width - 1, y + 2, '┤', border_style)
          ((x + 1)...(x + width - 1)).each do |c|
            canvas.set_cell(c, y + 2, '─', border_style)
          end

          table_rows = height - 4
          return if table_rows <= 0

          sel_idx = state.breakdown_selected_index.clamp(0, Math.max(0, phases.size - 1))

          # Scrolling window
          start_idx = 0
          if phases.size > table_rows
            if sel_idx >= table_rows - 2
              start_idx = Math.min(sel_idx - table_rows // 2, phases.size - table_rows)
            end
          end
          end_idx = Math.min(start_idx + table_rows - 1, phases.size - 1)

          (start_idx..end_idx).each_with_index do |idx, offset|
            row_y = y + 3 + offset
            break if row_y >= y + height - 1

            phase = phases[idx]
            is_sel = (idx == sel_idx)

            if is_sel
              canvas.fill_rect(x + 1, row_y, width - 2, 1, char: ' ', style: Style.new(bg: "48;5;237"))
            end

            status_badge = case phase.status
                           when PhaseStatus::Passed
                             "\e[1;97;48;5;28m PASS \e[0m"
                           when PhaseStatus::Failed
                             "\e[1;97;48;5;124m FAIL \e[0m"
                           when PhaseStatus::Running
                             "\e[1;97;48;5;31m RUN  \e[0m"
                           when PhaseStatus::Skipped
                             "\e[38;5;244m SKIP \e[0m"
                           else
                             "\e[38;5;240m PEND \e[0m"
                           end

            dur_str = phase.duration > 0 ? sprintf("%5.2fs", phase.duration) : "   -  "
            assert_str = if phase.passed_count > 0 || phase.failed_count > 0
                           "\e[32m#{phase.passed_count}P\e[0m / \e[31m#{phase.failed_count}F\e[0m"
                         else
                           "   -   "
                         end

            cursor = is_sel ? "\e[1;36m►\e[0m" : " "
            tag_fmt = sprintf("%-9s", phase.tag)
            name_fmt = sprintf("%-30s", phase.name[0...30])

            if state.breakdown_sort_by_duration
              rank_str = sprintf("#%-2d", idx + 1)
              fixed_w = 2 + 3 + 1 + 6 + 2 + 9 + 1 + 30 + 1 + 11 + 3 + 7 + 3
              avail_bar_w = Math.max(5, width - fixed_w - 4)
              ratio = (phase.duration / max_dur).clamp(0.0, 1.0)
              bar_len = (ratio * avail_bar_w).round.to_i
              bar_color = if phase.duration >= 5.0
                            "\e[1;95m"
                          elsif phase.duration >= 2.0
                            "\e[1;91m"
                          elsif phase.duration >= 0.8
                            "\e[1;93m"
                          elsif phase.duration >= 0.2
                            "\e[1;96m"
                          else
                            "\e[1;92m"
                          end
              bar_str = bar_len > 0 ? "#{bar_color}#{("|" * bar_len)}\e[0m" : "\e[38;5;240m|\e[0m"

              row_text = "#{cursor} \e[1;33m#{rank_str}\e[0m #{status_badge}  \e[1;36m#{tag_fmt}\e[0m \e[1m#{name_fmt}\e[0m #{assert_str}   \e[1;93m#{dur_str}\e[0m   #{bar_str}"
            else
              cat_fmt = sprintf("%-11s", phase.category[0...11])
              row_text = "#{cursor} #{status_badge}  \e[1;36m#{tag_fmt}\e[0m \e[1m#{name_fmt}\e[0m #{cat_fmt} #{assert_str}   \e[1;93m#{dur_str}\e[0m   #{phase.exit_code}"
            end

            canvas.draw_text(x + 2, row_y, row_text, max_w: width - 4)
          end
        end
      end
    end
  end
end
