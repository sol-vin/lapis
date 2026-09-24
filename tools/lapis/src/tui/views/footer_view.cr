# tools/lapis/src/tui/views/footer_view.cr
require "../model"
require "../canvas"

module Lapis
  module TUI
    module Views
      module FooterView
        def self.draw(canvas : Canvas, state : TestRunState, x : Int32, y : Int32, width : Int32) : Nil
          return if y < 0 || y >= canvas.height || width < 20

          hints = if state.overall_status == OverallStatus::Running
                    " \e[1;97;48;5;236m ↑↓/jk \e[0m Select Phase  \e[1;97;48;5;236m Enter \e[0m Inspect  \e[1;97;48;5;236m q \e[0m Abort Test  \e[1;97;48;5;236m ? \e[0m Help "
                  else
                    " \e[1;97;48;5;236m ↑↓/jk \e[0m Select Phase  \e[1;97;48;5;236m Enter \e[0m Inspect Details  \e[1;97;48;5;236m q/Esc \e[0m Exit  \e[1;97;48;5;236m ? \e[0m Help "
                  end

          canvas.draw_text(x, y, hints, max_w: width)
        end
      end
    end
  end
end
