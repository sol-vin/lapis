# tools/lapis/src/tui/views/file_modal.cr
require "../model"
require "../canvas"
require "opal"

module Lapis
  module TUI
    module Views
      module FileModal
        def self.draw(canvas : Canvas, state : TestRunState, width : Int32, height : Int32) : {Int32, Int32, Int32, Int32}
          modal_w = Math.min(width - 4, 88)
          modal_h = Math.min(height - 4, 24)
          return {0, 0, 0, 0} if modal_w < 30 || modal_h < 10

          modal_x = (width - modal_w) // 2
          modal_y = (height - modal_h) // 2

          r, g, b = state.accent_color.to_rgb
          border_fg = "38;2;#{r};#{g};#{b}"
          border_style = Style.new(fg: border_fg)
          title_style = Style.new(fg: "97", bg: "48;2;#{r};#{g};#{b}", bold: true)

          # 1. Dark backdrop fill
          canvas.fill_rect(modal_x, modal_y, modal_w, modal_h, char: ' ', style: Style.new(bg: "48;5;234"))

          # 2. Outer box
          title = " [ PROJECT FILE EXPLORER & ARTIFACT BROWSER ] "
          canvas.draw_box(modal_x, modal_y, modal_w, modal_h, title: title, double_border: true, border_style: border_style, title_style: title_style)

          # 3. Path Breadcrumbs bar (modal_y + 1)
          cur_path = state.file_dialog.current_path
          path_text = "Dir: \e[1;36m#{cur_path}\e[0m"
          canvas.draw_text(modal_x + 2, modal_y + 1, path_text, max_w: modal_w - 4)

          # Divider (modal_y + 2)
          canvas.set_cell(modal_x, modal_y + 2, '╠', border_style)
          canvas.set_cell(modal_x + modal_w - 1, modal_y + 2, '╣', border_style)
          ((modal_x + 1)...(modal_x + modal_w - 1)).each { |c| canvas.set_cell(c, modal_y + 2, '═', border_style) }

          # 4. Legend footer (modal_y + modal_h - 1)
          hint = "\e[38;5;244m[↑↓/jk] Nav  \e[1;97mEnter/→\e[38;5;244m Open  \e[1;97m←/Backspace\e[38;5;244m Up  \e[1;97m.\e[38;5;244m Hidden  \e[1;97m/\e[38;5;244m Filter  \e[1;97mEsc\e[38;5;244m Close\e[0m"
          canvas.draw_text(modal_x + 2, modal_y + modal_h - 1, hint, max_w: modal_w - 4)

          inner_x = modal_x + 2
          inner_y = modal_y + 3
          inner_w = modal_w - 4
          inner_h = modal_h - 4
          {inner_x, inner_y, inner_w, inner_h}
        end
      end
    end
  end
end
