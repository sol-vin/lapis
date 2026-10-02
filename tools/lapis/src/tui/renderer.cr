# tools/lapis/src/tui/renderer.cr
require "./terminal"
require "./model"
require "./canvas"
require "./views/header_view"
require "./views/phases_view"
require "./views/log_view"
require "./views/detail_modal"
require "./views/theme_modal"
require "./views/file_modal"
require "./views/footer_view"
require "./views/benchmarks_view"

module Lapis
  module TUI
    class Renderer
      property frame_count : Int32 = 0
      getter last_buffer : Opal::UI::Buffer? = nil
      @diff_renderer : Opal::UI::DiffRenderer = Opal::UI::DiffRenderer.new
      @last_w : Int32 = 0
      @last_h : Int32 = 0

      def render(state : TestRunState) : Nil
        size = Terminal.size
        # Reserve 1 column and 1 row margin to prevent terminal auto-wrap and scrolling on Windows Console
        w = Math.max(40, size[:cols] - 1)
        h = Math.max(12, size[:rows] - 1)

        # Handle terminal resize: invalidate diff renderer cache to prevent ghosting
        if @last_w != w || @last_h != h
          @diff_renderer.invalidate!
          @last_w = w
          @last_h = h
        end

        canvas, theme_rect, file_rect = build_canvas_with_overlays(state, w, h)

        # Double-buffered differential render to terminal driver
        opal_buffer = canvas.to_opal_buffer

        # Render Opal UI interactive elements directly onto buffer if modal active
        render_opal_modals(opal_buffer, state, theme_rect, file_rect)

        # Apply Text Shader FX post-processing if enabled
        apply_shader_fx(opal_buffer, state)

        # Feed frame into Asciicast ScreenRecorder if recording is active
        if state.recording? && (rec = state.recorder)
          rec.capture_frame(opal_buffer)
        end

        @last_buffer = opal_buffer
        @diff_renderer.render(opal_buffer)
        @frame_count += 1
      end

      def render_to_string(state : TestRunState, width : Int32, height : Int32) : String
        w = Math.max(40, width - 1)
        h = Math.max(12, height - 1)
        canvas, theme_rect, file_rect = build_canvas_with_overlays(state, w, h)
        if state.current_view == ViewMode::ColorStudio || state.current_view == ViewMode::FileExplorer
          opal_buffer = canvas.to_opal_buffer
          render_opal_modals(opal_buffer, state, theme_rect, file_rect)
          apply_shader_fx(opal_buffer, state) if state.shader_fx != ShaderFxMode::None
          return opal_buffer.render_to_string
        elsif state.shader_fx != ShaderFxMode::None
          opal_buffer = canvas.to_opal_buffer
          apply_shader_fx(opal_buffer, state)
          return opal_buffer.render_to_string
        end
        canvas.render_to_string
      end

      def render_lines(state : TestRunState, width : Int32, height : Int32) : Array(String)
        w = Math.max(40, width - 1)
        h = Math.max(12, height - 1)
        canvas, _, _ = build_canvas_with_overlays(state, w, h)
        canvas.render_lines
      end

      def build_canvas(state : TestRunState, w : Int32, h : Int32) : Canvas
        build_canvas_with_overlays(state, w, h)[0]
      end

      def build_canvas_with_overlays(state : TestRunState, w : Int32, h : Int32) : {Canvas, {Int32, Int32, Int32, Int32}, {Int32, Int32, Int32, Int32}}
        canvas = Canvas.new(w, h)

        # 1. Header (y = 0 .. header_h - 1)
        header_h = Views::HeaderView.draw(canvas, state, 0, 0, w)

        # 2. Middle area (y = header_h .. h - 2)
        middle_y = header_h
        middle_h = Math.max(4, h - middle_y - 1)

        # Render active tab view
        case state.active_tab
        when TabMode::Failures
          Views::FailuresView.draw(canvas, state, 0, middle_y, w, middle_h)
        when TabMode::Breakdown
          Views::BreakdownView.draw(canvas, state, 0, middle_y, w, middle_h)
        when TabMode::Telemetry
          Views::TelemetryView.draw(canvas, state, 0, middle_y, w, middle_h)
        when TabMode::Benchmarks
          Views::BenchmarksView.draw(canvas, state, 0, middle_y, w, middle_h)
        else
          # TabMode::Dashboard (default split view)
          left_w = Math.min(w - 24, Math.max(26, (w * 0.35).to_i))
          right_x = left_w + 1
          right_w = w - right_x

          Views::PhasesView.draw(canvas, state, 0, middle_y, left_w, middle_h, @frame_count)
          Views::LogView.draw(canvas, state, right_x, middle_y, right_w, middle_h)
        end

        # 3. Footer (bottom row: y = h - 1)
        Views::FooterView.draw(canvas, state, 0, h - 1, w)

        theme_rect = {0, 0, 0, 0}
        file_rect = {0, 0, 0, 0}

        # 4. Modals (rendered on top with backdrop if active)
        if state.current_view == ViewMode::PhaseDetail
          Views::DetailModal.draw(canvas, state, w, h)
        elsif state.current_view == ViewMode::ColorStudio
          theme_rect = Views::ThemeModal.draw(canvas, state, w, h)
        elsif state.current_view == ViewMode::FileExplorer
          file_rect = Views::FileModal.draw(canvas, state, w, h)
        elsif state.current_view == ViewMode::Help
          draw_help_modal(canvas, state, w, h)
        end

        {canvas, theme_rect, file_rect}
      end

      private def render_opal_modals(
        buffer : Opal::UI::Buffer,
        state : TestRunState,
        theme_rect : {Int32, Int32, Int32, Int32},
        file_rect : {Int32, Int32, Int32, Int32}
      ) : Nil
        if state.current_view == ViewMode::ColorStudio
          tx, ty, tw, th = theme_rect
          if tw > 0 && th > 0
            if state.use_3d_color_picker
              state.color_picker_3d.render(buffer, tx, ty, tw, th)
            else
              state.color_picker.render(buffer, tx, ty, tw, th)
            end
          end
        elsif state.current_view == ViewMode::FileExplorer
          fx, fy, fw, fh = file_rect
          if fw > 0 && fh > 0
            state.file_dialog.render(buffer, fx, fy, fw, fh)
          end
        end
      end

      private def apply_shader_fx(buffer : Opal::UI::Buffer, state : TestRunState) : Nil
        mode = state.shader_fx
        return if mode == ShaderFxMode::None

        time = state.elapsed_seconds
        frame = @frame_count.to_u64

        case mode
        when ShaderFxMode::Crt
          pass = Opal::Shader::CrtPass.new(intensity: 0.22, scanline_gap: 2, flicker: true)
          buffer.apply_shader(pass, time, frame)
        when ShaderFxMode::Matrix
          pass = Opal::Shader::MatrixPass.new(
            speed: 1.2,
            density: 0.15,
            lead_color: state.accent_color,
            trail_color: :green,
            preserve_text: true
          )
          buffer.apply_shader(pass, time, frame)
        when ShaderFxMode::Glitch
          pass = Opal::Shader::GlitchPass.new(intensity: 0.25, slice_height: 3, chromatic_shift: true)
          buffer.apply_shader(pass, time, frame)
        when ShaderFxMode::Plasma
          pass = Opal::Shader::PlasmaPass.new(scale: 0.25, speed: 1.6, shade_bg: false)
          buffer.apply_shader(pass, time, frame)
        when ShaderFxMode::Fire
          pass = Opal::Shader::FirePass.new(speed: 1.0)
          buffer.apply_shader(pass, time, frame)
        when ShaderFxMode::Vignette
          pass = Opal::Shader::VignettePass.new(radius: 0.82, falloff: 0.45)
          buffer.apply_shader(pass, time, frame)
        else
          # None
        end
      end

      private def draw_help_modal(canvas : Canvas, state : TestRunState, width : Int32, height : Int32)
        box_w = Math.min(width - 4, 82)
        box_h = Math.min(height - 4, 24)
        box_x = (width - box_w) // 2
        box_y = (height - box_h) // 2

        r, g, b = state.accent_color.to_rgb
        accent_fg = "38;2;#{r};#{g};#{b}"
        accent_bg = "48;2;#{r};#{g};#{b}"

        canvas.fill_rect(box_x, box_y, box_w, box_h, char: ' ', style: Style.new(bg: "48;5;234"))
        canvas.draw_box(
          box_x,
          box_y,
          box_w,
          box_h,
          title: " [?] KEYBOARD SHORTCUTS & OPAL STUDIO CONTROLS ",
          double_border: true,
          border_style: Style.new(fg: accent_fg),
          title_style: Style.new(fg: "97", bg: accent_bg, bold: true)
        )

        canvas.draw_text(box_x + 3, box_y + 2, "\e[1;96mTabs & Navigation:\e[0m", max_w: box_w - 6)
        canvas.draw_text(box_x + 5, box_y + 3, "\e[1;97m1, 2, 3, 4\e[0m       Directly switch to tab (Dashboard / Failures / Breakdown / Telemetry)", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 4, "\e[1;97mTab / S-Tab\e[0m      Cycle to next / previous tab view", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 5, "\e[1;97m↑ / ↓ / j / k\e[0m    Select test phase or table row", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 6, "\e[1;97mPgUp / PgDn\e[0m      Scroll logs / results viewport up or down", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 7, "\e[1;97m/\e[0m                Interactive text filter & search across logs / phases", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 8, "\e[1;97mf\e[0m                Toggle live auto-scroll follow mode (on / off)", max_w: box_w - 8)

        canvas.draw_text(box_x + 3, box_y + 10, "\e[1;96m[#] Opal Interactive Studio Additions:\e[0m", max_w: box_w - 6)
        canvas.draw_text(box_x + 5, box_y + 11, "\e[1;97mt / p\e[0m            Theme Studio (2D TrueColor RGB sliders & 3D rotatable color cubes)", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 12, "\e[1;97mo / e\e[0m            File Explorer (interactive directory browser & artifact preview)", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 13, "\e[1;97mx\e[0m                Cycle Text Shaders (CRT scanlines, Matrix rain, Glitch, Plasma, Heat)", max_w: box_w - 8)

        canvas.draw_text(box_x + 3, box_y + 15, "\e[1;96mActions & Screencasts:\e[0m", max_w: box_w - 6)
        canvas.draw_text(box_x + 5, box_y + 16, "\e[1;97mEnter / Space\e[0m    Inspect selected phase in modal dialog", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 17, "\e[1;97mCtrl+R\e[0m           Record asciicast screencast (.cast tape file)", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 18, "\e[1;97mCtrl+S\e[0m           VCR Screenshot (ANSI + HTML saved to disk & clipboard)", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 19, "\e[1;97mc\e[0m                Copy error excerpt or log to clipboard via OSC 52", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 20, "\e[1;97mq\e[0m                Abort active test run / Exit dashboard", max_w: box_w - 8)
        canvas.draw_text(box_x + 5, box_y + 21, "\e[1;97m? / Esc\e[0m          Toggle help overlay / Close active modal", max_w: box_w - 8)
      end
    end
  end
end

