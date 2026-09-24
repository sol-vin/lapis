# tools/lapis/src/tui/renderer.cr
require "./terminal"
require "./model"
require "./canvas"
require "./views/header_view"
require "./views/phases_view"
require "./views/log_view"
require "./views/detail_modal"
require "./views/footer_view"

module Lapis
  module TUI
    class Renderer
      property frame_count : Int32 = 0

      def render(state : TestRunState) : Nil
        size = Terminal.size
        # Reserve 1 column and 1 row margin to prevent terminal auto-wrap and scrolling on Windows Console
        w = Math.max(40, size[:cols] - 1)
        h = Math.max(12, size[:rows] - 1)
        canvas = build_canvas(state, w, h)
        output = canvas.render_to_string
        STDOUT.print(output)
        STDOUT.flush
        @frame_count += 1
      end

      def render_to_string(state : TestRunState, width : Int32, height : Int32) : String
        w = Math.max(40, width - 1)
        h = Math.max(12, height - 1)
        canvas = build_canvas(state, w, h)
        canvas.render_to_string
      end

      def render_lines(state : TestRunState, width : Int32, height : Int32) : Array(String)
        w = Math.max(40, width - 1)
        h = Math.max(12, height - 1)
        canvas = build_canvas(state, w, h)
        canvas.render_lines
      end

      def build_canvas(state : TestRunState, w : Int32, h : Int32) : Canvas
        canvas = Canvas.new(w, h)

        # 1. Header (top 4 rows: y = 0..3)
        header_h = Views::HeaderView.draw(canvas, state, 0, 0, w)

        # 2. Middle split panes (y = header_h .. h - 2)
        middle_y = header_h
        middle_h = Math.max(4, h - middle_y - 1)

        # Left checklist pane (~35% width), 1-space separator gap, right live logs pane (remainder)
        left_w = Math.min(w - 24, Math.max(26, (w * 0.35).to_i))
        right_x = left_w + 1
        right_w = w - right_x

        Views::PhasesView.draw(canvas, state, 0, middle_y, left_w, middle_h, @frame_count)
        Views::LogView.draw(canvas, state, right_x, middle_y, right_w, middle_h)

        # 3. Footer (bottom row: y = h - 1)
        Views::FooterView.draw(canvas, state, 0, h - 1, w)

        # 4. Modals (rendered on top with backdrop if active)
        if state.current_view == ViewMode::PhaseDetail
          Views::DetailModal.draw(canvas, state, w, h)
        elsif state.current_view == ViewMode::Help
          draw_help_modal(canvas, w, h)
        end

        canvas
      end

      private def draw_help_modal(canvas : Canvas, width : Int32, height : Int32)
        box_w = Math.min(width - 4, 70)
        box_h = Math.min(height - 4, 15)
        box_x = (width - box_w) // 2
        box_y = (height - box_h) // 2

        canvas.fill_rect(box_x, box_y, box_w, box_h, char: ' ', style: Style.new(bg: "48;5;234"))
        canvas.draw_box(
          box_x,
          box_y,
          box_w,
          box_h,
          title: " 💡 KEYBOARD SHORTCUTS ",
          double_border: true,
          border_style: Style.new(fg: "38;5;141"),
          title_style: Style.new(fg: "97", bg: "48;5;54", bold: true)
        )

        canvas.draw_text(box_x + 3, box_y + 2, "\e[1;96mNavigation:\e[0m", max_w: box_w - 6)
        canvas.draw_text(box_x + 5, box_y + 3, "\e[1;97m↑ / k\e[0m        Select previous test phase", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 4, "\e[1;97m↓ / j\e[0m        Select next test phase", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 5, "\e[1;97mEnter / Space\e[0m Inspect selected phase (details modal)", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 6, "\e[1;97mEsc\e[0m          Close inspection modal / help screen", max_w: box_w - 8)

        canvas.draw_text(box_x + 3, box_y + 8, "\e[1;96mActions:\e[0m", max_w: box_w - 6)
        canvas.draw_text(box_x + 5, box_y + 9, "\e[1;97mq\e[0m            Abort active test run / Exit dashboard", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 10, "\e[1;97m?\e[0m            Toggle this help overlay", max_w: box_w - 8)

        canvas.draw_text(box_x + 3, box_y + 12, "\e[38;5;244mPress [Esc] or [Enter] to return to the test dashboard\e[0m", max_w: box_w - 6)
      end
    end
  end
end
