# tools/lapis/src/tui/views/header_view.cr
require "../model"
require "../canvas"
require "opal"

module Lapis
  module TUI
    module Views
      module HeaderView
        HEIGHT = 5

        def self.draw(canvas : Canvas, state : TestRunState, x : Int32, y : Int32, width : Int32) : Int32
          w = Math.max(width, 40)
          ar, ag, ab = state.accent_color.to_rgb
          border_fg = "38;2;#{ar};#{ag};#{ab}"
          title_bg = "48;2;#{ar};#{ag};#{ab}"
          border_style = Style.new(fg: border_fg)

          # 1. Double border box
          title_text = " [ #{state.title.upcase} ] "
          title_style = Style.new(fg: "97", bg: title_bg, bold: true)
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
                                            {"\e[1;97;48;5;31m RUNNING [*] \e[0m", 13}
                                          when OverallStatus::Passed
                                            {"\e[1;97;48;5;28m ALL PASSED [OK] \e[0m", 17}
                                          when OverallStatus::Failed
                                            {"\e[1;97;48;5;124m FAILURES DETECTED [X] \e[0m", 23}
                                          when OverallStatus::Aborted
                                            {"\e[1;97;48;5;130m ABORTED [!] \e[0m", 13}
                                          else
                                            {"\e[1;97;48;5;240m READY [.] \e[0m", 11}
                                          end

          chip_x = Math.max(x + 20, x + w - status_plain_len - 2)
          canvas.draw_text(chip_x, y + 1, status_chip, max_w: status_plain_len + 2)

          # Recording badge right-aligned before status chip
          if state.recording?
            rec_badge = "\e[1;97;48;5;196m ● REC #{state.recording_elapsed_str} \e[0m"
            rec_len = 8 + state.recording_elapsed_str.size
            rec_x = Math.max(x + 10, chip_x - rec_len - 2)
            canvas.draw_text(rec_x, y + 1, rec_badge, max_w: rec_len + 2)
          end

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

          durations = state.phases.select { |p| p.status == PhaseStatus::Passed || p.status == PhaseStatus::Failed }.map(&.duration)
          if durations.size >= 2
            spark = Opal::UI::Sparkline.render_to_string(durations)
            summary_text += " · \e[1;36m#{spark}\e[0m"
          end
          summary_text += ")"

          canvas.draw_text(x + 4 + bar_width, y + 2, summary_text, max_w: w - bar_width - 8)

          # 4. Multi-view Tabs row (row y + 3)
          tab_labels = [
            {"[1] Dashboard", TabMode::Dashboard},
            {"[2] Failures (#{state.failed_phases})", TabMode::Failures},
            {"[3] Breakdown", TabMode::Breakdown},
            {"[4] Telemetry", TabMode::Telemetry},
            {"[5] Benchmarks", TabMode::Benchmarks},
          ]

          tab_x = x + 2
          tab_labels.each do |label, mode|
            is_active = (state.active_tab == mode)
            has_fails = (mode == TabMode::Failures && state.failed_phases > 0)

            pill = if is_active
                     "\e[1;97;#{title_bg}m #{label} \e[0m"
                   elsif has_fails
                     "\e[1;31m #{label} \e[0m"
                   else
                     "\e[38;5;244m #{label} \e[0m"
                   end

            canvas.draw_text(tab_x, y + 3, pill)
            tab_x += label.size + 3
            break if tab_x >= x + w - 30
          end

          # Active Shader FX pill if enabled
          if state.shader_fx != ShaderFxMode::None
            fx_pill = "\e[1;97;48;5;55m [*] FX: #{state.shader_fx.display_name} \e[0m"
            canvas.draw_text(tab_x + 1, y + 3, fx_pill)
          end

          # Follow / Search status indicator on right of tab bar
          status_tag = if state.searching
                         "\e[1;33m[/] Search: #{state.search_input}█\e[0m"
                       elsif q = state.search_query
                         "\e[36m[/] Filter: \"#{q}\"\e[0m"
                       elsif state.follow_mode
                         "\e[38;5;244m[Follow: \e[32mON\e[38;5;244m]\e[0m"
                       else
                         "\e[38;5;244m[Follow: \e[33mOFF\e[38;5;244m]\e[0m"
                       end

          tag_len = state.searching ? (12 + state.search_input.size) : (state.search_query ? (12 + (state.search_query.try(&.size) || 0)) : 13)
          tag_x = Math.max(tab_x + 2, x + w - tag_len - 3)
          canvas.draw_text(tag_x, y + 3, status_tag, max_w: tag_len + 4)

          HEIGHT
        end
      end
    end
  end
end
