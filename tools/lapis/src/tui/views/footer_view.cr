# tools/lapis/src/tui/views/footer_view.cr
require "../model"
require "../canvas"

module Lapis
  module TUI
    module Views
      module FooterView
        def self.draw(canvas : Canvas, state : TestRunState, x : Int32, y : Int32, width : Int32) : Nil
          return if y < 0 || y >= canvas.height || width < 20

          hints = if state.searching
                    " \e[1;97;48;5;236m Type to search \e[0m  \e[1;97;48;5;236m Enter \e[0m Confirm  \e[1;97;48;5;236m Esc \e[0m Clear/Close "
                  elsif state.overall_status == OverallStatus::Running
                    " \e[1;97;48;5;236m 1-5 \e[0m Tabs  \e[1;97;48;5;236m d \e[0m Duration  \e[1;97;48;5;236m c \e[0m Charts  \e[1;97;48;5;236m ↑↓ \e[0m Nav  \e[1;97;48;5;236m Enter \e[0m Inspect  \e[1;97;48;5;236m t \e[0m Theme  \e[1;97;48;5;236m o \e[0m Files  \e[1;97;48;5;236m x \e[0m FX  \e[1;97;48;5;236m f \e[0m Follow  \e[1;97;48;5;236m / \e[0m Search  \e[1;97;48;5;236m q \e[0m Abort  \e[1;97;48;5;236m ? \e[0m Help "
                  else
                    " \e[1;97;48;5;236m 1-5 \e[0m Tabs  \e[1;97;48;5;236m d \e[0m Duration  \e[1;97;48;5;236m c \e[0m Charts  \e[1;97;48;5;236m ↑↓ \e[0m Nav  \e[1;97;48;5;236m Enter \e[0m Inspect  \e[1;97;48;5;236m t \e[0m Theme  \e[1;97;48;5;236m o \e[0m Files  \e[1;97;48;5;236m x \e[0m FX  \e[1;97;48;5;236m f \e[0m Follow  \e[1;97;48;5;236m / \e[0m Search  \e[1;97;48;5;236m q \e[0m Exit  \e[1;97;48;5;236m ? \e[0m Help "
                  end

          canvas.draw_text(x, y, hints, max_w: width - 25)

          # Draw active toast notification on the right side if present
          if last_toast = state.toasts.toasts.last?
            unless last_toast.expired?
              badge_label = case last_toast.level
                            when :success then "[OK] SUCCESS"
                            when :error   then "[X] ERROR"
                            when :warning then "[!] WARNING"
                            else               "[*] INFO"
                            end
              toast_msg = " #{badge_label}: #{last_toast.title} "
              toast_x = Math.max(x + 20, x + width - toast_msg.size - 2)
              toast_style = case last_toast.level
                            when :success then "\e[1;97;48;5;28m"
                            when :error   then "\e[1;97;48;5;124m"
                            when :warning then "\e[1;97;48;5;130m"
                            else               "\e[1;97;48;5;31m"
                            end
              canvas.draw_text(toast_x, y, "#{toast_style}#{toast_msg}\e[0m", max_w: toast_msg.size + 2)
            end
          end
        end
      end
    end
  end
end
