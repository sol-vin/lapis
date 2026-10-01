# tools/lapis/src/tui/views/telemetry_view.cr
require "../model"
require "../canvas"
require "opal"

module Lapis
  module TUI
    module Views
      module TelemetryView
        def self.draw(canvas : Canvas, state : TestRunState, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
          return if width < 30 || height < 6

          border_style = Style.new(fg: "38;5;48")
          title_style = Style.new(fg: "48", bold: true)
          title = " [ TEST RUN TELEMETRY & PERFORMANCE METRICS ] "
          canvas.draw_box(x, y, width, height, title: title, border_style: border_style, title_style: title_style)

          # Section 1: Summary Metrics Cards (y + 1 to y + 3)
          elapsed = state.elapsed_seconds
          avg_dur = state.completed_phases > 0 ? (elapsed / state.completed_phases) : 0.0

          card1 = "Total Time: \e[1;93m#{sprintf("%.2fs", elapsed)}\e[0m"
          card2 = "Completed: \e[1;97m#{state.completed_phases}/#{state.total_phases}\e[0m"
          card3 = "Assertions: \e[32m#{state.total_assertions_passed} Passed\e[0m · \e[31m#{state.total_assertions_failed} Failed\e[0m"
          card4 = "Avg Phase: \e[1;36m#{sprintf("%.2fs", avg_dur)}\e[0m"

          canvas.draw_text(x + 2, y + 1, "#{card1}  │  #{card2}  │  #{card3}  │  #{card4}", max_w: width - 4)

          # Divider
          canvas.set_cell(x, y + 2, '├', border_style)
          canvas.set_cell(x + width - 1, y + 2, '┤', border_style)
          ((x + 1)...(x + width - 1)).each { |c| canvas.set_cell(c, y + 2, '─', border_style) }

          # Section 2: Phase Latency Sparkline
          durations = state.phases.select { |p| p.status == PhaseStatus::Passed || p.status == PhaseStatus::Failed }.map(&.duration)
          if durations.size >= 2
            spark = Opal::UI::Sparkline.render_to_string(durations)
            canvas.draw_text(x + 2, y + 3, "\e[1;96mPhase Duration Trend:\e[0m \e[1;36m#{spark}\e[0m  (min: #{sprintf("%.2fs", durations.min)}, max: #{sprintf("%.2fs", durations.max)})", max_w: width - 4)
          else
            canvas.draw_text(x + 2, y + 3, "\e[38;5;244m(Waiting for more phases to record latency trends...)\e[0m", max_w: width - 4)
          end

          # Section 3: Slowest Phases Bar Chart
          canvas.draw_text(x + 2, y + 5, "\e[1;97mTop Slowest Executed Phases:\e[0m", max_w: width - 4)

          sorted_phases = state.phases
            .select { |p| p.duration > 0.0 }
            .sort_by { |p| -p.duration }
            .first(Math.max(1, height - 8))

          if sorted_phases.empty?
            canvas.draw_text(x + 4, y + 6, "\e[38;5;244mNo phase duration timings recorded yet.\e[0m", max_w: width - 8)
            return
          end

          max_dur = Math.max(0.1, sorted_phases.first.duration)
          bar_max_w = Math.min(40, Math.max(10, width - 45))

          sorted_phases.each_with_index do |p, idx|
            row_y = y + 6 + idx
            break if row_y >= y + height - 1

            ratio = (p.duration / max_dur).clamp(0.0, 1.0)
            bar_len = (ratio * bar_max_w).round.to_i

            name_fmt = sprintf("%-24s", p.name[0...24])
            dur_fmt = sprintf("%5.2fs", p.duration)

            bar_chars = "█" * bar_len
            canvas.draw_text(x + 2, row_y, "\e[1m#{name_fmt}\e[0m \e[38;5;141m#{bar_chars}\e[0m \e[1;93m#{dur_fmt}\e[0m", max_w: width - 4)
          end
        end
      end
    end
  end
end
