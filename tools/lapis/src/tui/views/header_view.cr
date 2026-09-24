# tools/lapis/src/tui/views/header_view.cr
require "../model"
require "../canvas"

module Lapis
  module TUI
    module Views
      module HeaderView
        HEIGHT = 4

        def self.draw(canvas : Canvas, state : TestRunState, x : Int32, y : Int32, width : Int32) : Int32
          w = Math.max(width, 40)
          border_style = Style.new(fg: "38;5;141")

          # 1. Double border box
          title_text = " 🔮 #{state.title.upcase} "
          title_style = Style.new(fg: "97", bg: "48;5;54", bold: true)
          canvas.draw_box(x, y, w, HEIGHT, title: title_text, double_border: true, border_style: border_style, title_style: title_style)

          # 2. System stats row (row y + 1)
          elapsed = state.elapsed_seconds
          mins = (elapsed / 60).to_i
          secs = (elapsed % 60).to_i
          time_str = sprintf("%02d:%02d", mins, secs)

          stats_text = "Host: \e[1;97m#{state.platform_name}\e[0m │ Godot: \e[1;97m#{state.godot_version}\e[0m │ Crystal: \e[1;97mv#{state.crystal_version}\e[0m │ Time: \e[1;93m#{time_str}\e[0m"
          canvas.draw_text(x + 2, y + 1, stats_text, max_w: w - 24)

          # Status chip right-aligned
          status_chip, status_plain_len = case state.overall_status
                                          when OverallStatus::Running
                                            {"\e[1;97;48;5;31m RUNNING ⏳ \e[0m", 11}
                                          when OverallStatus::Passed
                                            {"\e[1;97;48;5;28m ALL PASSED ✔ \e[0m", 14}
                                          when OverallStatus::Failed
                                            {"\e[1;97;48;5;124m FAILURES DETECTED ✘ \e[0m", 21}
                                          when OverallStatus::Aborted
                                            {"\e[1;97;48;5;130m ABORTED ⚠ \e[0m", 11}
                                          else
                                            {"\e[1;97;48;5;240m READY ○ \e[0m", 9}
                                          end

          chip_x = Math.max(x + 20, x + w - status_plain_len - 2)
          canvas.draw_text(chip_x, y + 1, status_chip, max_w: status_plain_len + 2)

          # 3. Progress bar row (row y + 2)
          ratio = state.progress_ratio
          percent = (ratio * 100).to_i
          bar_width = Math.min(26, Math.max(8, (w * 0.28).to_i))

          canvas.draw_text(x + 2, y + 2, "\e[38;5;244m[\e[0m")
          canvas.draw_bar(
            x + 3,
            y + 2,
            bar_width,
            ratio,
            filled_char: '█',
            empty_char: '░',
            filled_style: Style.new(fg: "38;5;48"),
            empty_style: Style.new(fg: "38;5;238")
          )
          canvas.draw_text(x + 3 + bar_width, y + 2, "\e[38;5;244m]\e[0m")

          summary_text = " \e[1;97m#{percent}%\e[0m (#{state.completed_phases}/#{state.total_phases} Phases · \e[32m#{state.total_assertions_passed} Passed\e[0m"
          summary_text += " · \e[31m#{state.total_assertions_failed} Failed\e[0m" if state.total_assertions_failed > 0
          summary_text += ")"

          canvas.draw_text(x + 4 + bar_width, y + 2, summary_text, max_w: w - bar_width - 8)

          HEIGHT
        end
      end
    end
  end
end
