# tools/lapis/src/tui/views/theme_modal.cr
require "../model"
require "../canvas"
require "opal"

module Lapis
  module TUI
    module Views
      module ThemeModal
        def self.draw(canvas : Canvas, state : TestRunState, width : Int32, height : Int32) : {Int32, Int32, Int32, Int32}
          modal_w = Math.min(width - 4, 76)
          modal_h = Math.min(height - 4, 22)
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
          mode_tag = state.use_3d_color_picker ? "3D SPATIAL [#{state.color_picker_3d.shape.display_name.upcase}]" : "2D TRUECOLOR STUDIO"
          title = " [ THEME & COLOR STUDIO [#{mode_tag}] ] "
          canvas.draw_box(modal_x, modal_y, modal_w, modal_h, title: title, double_border: true, border_style: border_style, title_style: title_style)

          # 3. Top Mode Switcher Bar (modal_y + 1)
          tab2d = state.use_3d_color_picker ? "\e[38;5;244m [1] 2D RGB Sliders \e[0m" : "\e[1;97;48;2;#{r};#{g};#{b} [1] 2D RGB Sliders \e[0m"
          tab3d = state.use_3d_color_picker ? "\e[1;97;48;2;#{r};#{g};#{b} [2] 3D Spatial Picker \e[0m" : "\e[38;5;244m [2] 3D Spatial Picker \e[0m"
          hex_str = "Hex: \e[1;97m#{state.accent_color.to_hex}\e[0m (RGB: #{r}, #{g}, #{b})"

          canvas.draw_text(modal_x + 2, modal_y + 1, "#{tab2d} #{tab3d}  │  #{hex_str}", max_w: modal_w - 4)

          # Divider (modal_y + 2)
          canvas.set_cell(modal_x, modal_y + 2, '╠', border_style)
          canvas.set_cell(modal_x + modal_w - 1, modal_y + 2, '╣', border_style)
          ((modal_x + 1)...(modal_x + modal_w - 1)).each { |c| canvas.set_cell(c, modal_y + 2, '═', border_style) }

          # 4. Legend footer (modal_y + modal_h - 1)
          hint = if state.use_3d_color_picker
                   "\e[38;5;244m[Tab] 2D/3D  \e[1;97mWASD\e[38;5;244m Rotate  \e[1;97m↑↓←→\e[38;5;244m Raycast  \e[1;97mm\e[38;5;244m Shape  \e[1;97mSpace\e[38;5;244m Spin  \e[1;97mEnter\e[38;5;244m Apply\e[0m"
                 else
                   "\e[38;5;244m[Tab] 2D/3D  \e[1;97m↑↓\e[38;5;244m Channel  \e[1;97m←→\e[38;5;244m Slider  \e[1;97m0-9\e[38;5;244m Preset  \e[1;97mEnter\e[38;5;244m Apply\e[0m"
                 end
          canvas.draw_text(modal_x + 2, modal_y + modal_h - 1, hint, max_w: modal_w - 4)

          # Return content inner rectangle for Opal component blitting
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
