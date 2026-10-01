# =============================================================================
# LibGodot - Crystal radare2 Session Tab UI
# =============================================================================
# Embedded directly into Godot's Debugger bottom dock for each active session
# via EditorDebuggerSession#add_session_tab.
# Provides interactive r2 console, native pdc decompiler view, assembly view,
# execution stepping controls, call stack tree with boundary badges, CPU registers,
# role identification (Server / Client), and multiplayer lockstep break coordination.

require "../../lapis"
require "../../libgodot/debugger/radare_driver"

module Godot
  @[Tool]
  node CrystalRadareSessionTab < VBoxContainer do
    property session_id : Int32 = 0
    property target_pid : Int64 = 0_i64
    property role_name : String = "Instance"
    property lockstep_enabled : Bool = true
  end

  class CrystalRadareSessionTab
    @status_label : Label? = nil
    @role_badge : Label? = nil
    @btn_attach : Button? = nil
    @btn_continue : Button? = nil
    @btn_pause : Button? = nil
    @btn_step_over : Button? = nil
    @btn_step_in : Button? = nil
    @btn_step_out : Button? = nil
    @chk_lockstep : CheckBox? = nil

    # Center Tabs & Views
    @tab_container : TabContainer? = nil
    @console_log : RichTextLabel? = nil
    @command_input : LineEdit? = nil
    @decompiler_log : RichTextLabel? = nil
    @disasm_log : RichTextLabel? = nil

    # Left & Right Panels
    @stack_tree : Tree? = nil
    @registers_tree : Tree? = nil

    @driver : Debugger::RadareDriver? = nil
    @on_command_callback : Proc(String, Nil)? = nil
    @on_frame_select_callback : Proc(Debugger::StackFrame, Nil)? = nil
    @on_lockstep_toggle_callback : Proc(Bool, Nil)? = nil
    @on_attach_request : Proc(Nil)? = nil

    def setup(session_id : Int32, role : String = "Instance", driver : Debugger::RadareDriver? = nil) : Void
      @session_id = session_id
      @role_name = role
      @driver = driver
      self.name = "Crystal radare2"

      call("set_h_size_flags", 3_i64) # SIZE_EXPAND_FILL
      call("set_v_size_flags", 3_i64) # SIZE_EXPAND_FILL

      build_ui
      update_status("Detached", false)
    end

    def set_on_command(&block : String -> Nil) : Void
      @on_command_callback = block
    end

    def set_on_frame_select(&block : Debugger::StackFrame -> Nil) : Void
      @on_frame_select_callback = block
    end

    def set_on_lockstep_toggle(&block : Bool -> Nil) : Void
      @on_lockstep_toggle_callback = block
    end

    def set_on_attach_request(&block : -> Nil) : Void
      @on_attach_request = block
    end

    # Appends text output into the interactive radare2 console
    def append_console(text : String) : Void
      @console_log.try(&.append_text(text))
    end

    # Updates status indicator and button enabled states
    def update_status(status_text : String, is_attached : Bool, is_paused : Bool = false) : Void
      if lbl = @status_label
        icon = is_attached ? (is_paused ? "⏸ " : "▶ ") : "○ "
        lbl.text = "#{icon}#{status_text}"
      end

      @btn_attach.try(&.text = is_attached ? "Detach" : "Attach")
      @btn_continue.try(&.disabled = !is_attached || !is_paused)
      @btn_pause.try(&.disabled = !is_attached || is_paused)
      @btn_step_over.try(&.disabled = !is_attached || !is_paused)
      @btn_step_in.try(&.disabled = !is_attached || !is_paused)
      @btn_step_out.try(&.disabled = !is_attached || !is_paused)
    end

    # Updates the multiplayer role badge with distinct coloring
    def update_role(role : String, pid : Int64) : Void
      @role_name = role
      @target_pid = pid
      @role_badge.try(&.text = "[#{role.upcase} - PID: #{pid}]")
    end

    # Populates call stack frames tree with module boundary badges
    def update_stack_frames(frames : Array(Debugger::StackFrame)) : Void
      tree = @stack_tree
      return unless tree

      tree.clear
      root = tree.create_item
      return unless root

      frames.each do |frame|
        item = tree.create_item(root)
        next unless item

        # Classify module boundary for badges
        badge = if frame.file.includes?("src/") || frame.function.includes?("#")
                  "[Game] "
                elsif frame.function.includes?("godot_") || frame.function.includes?("GDExtension")
                  "[Bridge] "
                elsif frame.file.empty?
                  "[Engine] "
                else
                  "[Plugin] "
                end

        text = "#{badge}##{frame.index} #{frame.function}"
        if !frame.file.empty?
          text += " at #{File.basename(frame.file)}:#{frame.line}"
        end

        item.set_text(0_i64, text)
        item.call("set_metadata", 0, "#{frame.file}::#{frame.line}::#{frame.address}")
      end
    end

    # Updates decompiled pseudo-C text in decompiler view
    def update_decompiled_code(code : String) : Void
      if log = @decompiler_log
        log.clear
        log.append_text(code)
      end
    end

    # Updates disassembly text in disassembly view
    def update_disassembly(asm_text : String) : Void
      if log = @disasm_log
        log.clear
        log.append_text(asm_text)
      end
    end

    # Updates CPU registers table
    def update_registers(regs : Hash(String, UInt64)) : Void
      tree = @registers_tree
      return unless tree

      tree.clear
      root = tree.create_item
      return unless root

      regs.each do |name, val|
        item = tree.create_item(root)
        next unless item
        item.set_text(0_i64, name.upcase)
        item.set_text(1_i64, "0x#{val.to_s(16)}")
      end
    end

    private def build_ui : Void
      # -----------------------------------------------------------------------
      # Top Toolbar
      # -----------------------------------------------------------------------
      toolbar = Godot.create(Godot::HBoxContainer)
      return unless toolbar
      toolbar.call("add_theme_constant_override", "separation", 8)
      add_child(toolbar)

      # Role Badge
      badge = Godot.create(Godot::Label)
      if badge
        badge.text = "[#{@role_name.upcase}]"
        toolbar.add_child(badge)
        @role_badge = badge
      end

      # Status Label
      status = Godot.create(Godot::Label)
      if status
        status.text = "○ Detached"
        toolbar.add_child(status)
        @status_label = status
      end

      sep1 = Godot.create(Godot::VSeparator)
      toolbar.add_child(sep1) if sep1

      # Attach / Detach Button
      btn_att = Godot.create(Godot::Button)
      if btn_att
        btn_att.text = "Attach"
        btn_att.pressed.connect do
          if cb = @on_attach_request
            cb.call
          end
        end
        toolbar.add_child(btn_att)
        @btn_attach = btn_att
      end

      # Local Execution Buttons
      btn_cont = Godot.create(Godot::Button)
      if btn_cont
        btn_cont.text = "Continue (F5)"
        btn_cont.tooltip_text = "Resume target execution (dc)"
        btn_cont.pressed.connect { @driver.try(&.continue_exec) }
        toolbar.add_child(btn_cont)
        @btn_continue = btn_cont
      end

      btn_p = Godot.create(Godot::Button)
      if btn_p
        btn_p.text = "Pause"
        btn_p.tooltip_text = "Interrupt target execution via debug break"
        btn_p.pressed.connect { @driver.try(&.interrupt_exec) }
        toolbar.add_child(btn_p)
        @btn_pause = btn_p
      end

      btn_so = Godot.create(Godot::Button)
      if btn_so
        btn_so.text = "Step Over (F10)"
        btn_so.pressed.connect { @driver.try(&.step_over) }
        toolbar.add_child(btn_so)
        @btn_step_over = btn_so
      end

      btn_si = Godot.create(Godot::Button)
      if btn_si
        btn_si.text = "Step In (F11)"
        btn_si.pressed.connect { @driver.try(&.step_into) }
        toolbar.add_child(btn_si)
        @btn_step_in = btn_si
      end

      btn_sou = Godot.create(Godot::Button)
      if btn_sou
        btn_sou.text = "Step Out"
        btn_sou.pressed.connect { @driver.try(&.step_out) }
        toolbar.add_child(btn_sou)
        @btn_step_out = btn_sou
      end

      sep2 = Godot.create(Godot::VSeparator)
      toolbar.add_child(sep2) if sep2

      # Multiplayer Lockstep Break Checkbox
      chk = Godot.create(Godot::CheckBox)
      if chk
        chk.text = "Lockstep Peers on Break"
        chk.button_pressed = true
        chk.tooltip_text = "When this instance breaks, automatically pause all other multiplayer peers to prevent network heartbeat timeouts and desync."
        chk.toggled.connect do |val|
          @lockstep_enabled = val
          if cb = @on_lockstep_toggle_callback
            cb.call(val)
          end
        end
        toolbar.add_child(chk)
        @chk_lockstep = chk
      end

      # -----------------------------------------------------------------------
      # Main Area Split (Left: Stack Tree, Center: Tabs, Right: Registers)
      # -----------------------------------------------------------------------
      main_split = Godot.create(Godot::HSplitContainer)
      return unless main_split
      main_split.call("set_h_size_flags", 3)
      main_split.call("set_v_size_flags", 3)
      add_child(main_split)

      # Left Column: Call Stack Frames
      stack_box = Godot.create(Godot::VBoxContainer)
      if stack_box
        stack_box.call("set_custom_minimum_size", Vector2.new(240.0_f32, 100.0_f32))
        stack_box.call("set_v_size_flags", 3)
        main_split.add_child(stack_box)

        lbl_stack = Godot.create(Godot::Label)
        if lbl_stack
          lbl_stack.text = "Call Stack Frames"
          stack_box.add_child(lbl_stack)
        end

        tree = Godot.create(Godot::Tree)
        if tree
          tree.call("set_h_size_flags", 3)
          tree.call("set_v_size_flags", 3)
          tree.hide_root = true
          tree.item_selected.connect { on_tree_item_selected }
          stack_box.add_child(tree)
          @stack_tree = tree
        end
      end

      # Right Split: Center Tabs & Right Inspector
      right_split = Godot.create(Godot::HSplitContainer)
      if right_split
        right_split.call("set_h_size_flags", 3)
        right_split.call("set_v_size_flags", 3)
        main_split.add_child(right_split)

        # Center Column: TabContainer (Console, Decompiler, Disassembly)
        center_box = Godot.create(Godot::VBoxContainer)
        if center_box
          center_box.call("set_h_size_flags", 3)
          center_box.call("set_v_size_flags", 3)
          right_split.add_child(center_box)

          tab_c = Godot.create(Godot::TabContainer)
          if tab_c
            tab_c.call("set_h_size_flags", 3)
            tab_c.call("set_v_size_flags", 3)
            center_box.add_child(tab_c)
            @tab_container = tab_c

            # Tab 1: Interactive radare2 Console
            c_box = Godot.create(Godot::VBoxContainer)
            if c_box
              c_box.name = "Console"
              c_box.call("set_h_size_flags", 3)
              c_box.call("set_v_size_flags", 3)
              tab_c.add_child(c_box)

              log = Godot.create(Godot::RichTextLabel)
              if log
                log.call("set_h_size_flags", 3)
                log.call("set_v_size_flags", 3)
                log.call("set_scroll_follow", true)
                log.call("set_selection_enabled", true)
                c_box.add_child(log)
                @console_log = log
              end

              input_bar = Godot.create(Godot::HBoxContainer)
              if input_bar
                input_bar.call("set_h_size_flags", 3)
                c_box.add_child(input_bar)

                cmd_line = Godot.create(Godot::LineEdit)
                if cmd_line
                  cmd_line.call("set_h_size_flags", 3)
                  cmd_line.placeholder_text = "Enter radare2 command (e.g. 'drj', 'pdc', 'pdf', 'CL.')..."
                  cmd_line.text_submitted.connect { |_| submit_current_command }
                  input_bar.add_child(cmd_line)
                  @command_input = cmd_line
                end

                btn_send = Godot.create(Godot::Button)
                if btn_send
                  btn_send.text = "Execute"
                  btn_send.pressed.connect { submit_current_command }
                  input_bar.add_child(btn_send)
                end
              end
            end

            # Tab 2: Decompiler View (pdc)
            d_box = Godot.create(Godot::VBoxContainer)
            if d_box
              d_box.name = "Decompiler (pdc)"
              d_box.call("set_h_size_flags", 3)
              d_box.call("set_v_size_flags", 3)
              tab_c.add_child(d_box)

              d_log = Godot.create(Godot::RichTextLabel)
              if d_log
                d_log.call("set_h_size_flags", 3)
                d_log.call("set_v_size_flags", 3)
                d_log.call("set_selection_enabled", true)
                d_box.add_child(d_log)
                @decompiler_log = d_log
              end
            end

            # Tab 3: Disassembly View (pdf / pd)
            a_box = Godot.create(Godot::VBoxContainer)
            if a_box
              a_box.name = "Disassembly (pdf)"
              a_box.call("set_h_size_flags", 3)
              a_box.call("set_v_size_flags", 3)
              tab_c.add_child(a_box)

              a_log = Godot.create(Godot::RichTextLabel)
              if a_log
                a_log.call("set_h_size_flags", 3)
                a_log.call("set_v_size_flags", 3)
                a_log.call("set_selection_enabled", true)
                a_box.add_child(a_log)
                @disasm_log = a_log
              end
            end
          end
        end

        # Right Column: CPU Registers & Memory Inspector
        reg_box = Godot.create(Godot::VBoxContainer)
        if reg_box
          reg_box.call("set_custom_minimum_size", Vector2.new(200.0_f32, 100.0_f32))
          reg_box.call("set_v_size_flags", 3)
          right_split.add_child(reg_box)

          lbl_regs = Godot.create(Godot::Label)
          if lbl_regs
            lbl_regs.text = "CPU Registers"
            reg_box.add_child(lbl_regs)
          end

          reg_tree = Godot.create(Godot::Tree)
          if reg_tree
            reg_tree.call("set_columns", 2_i64)
            reg_tree.call("set_column_title", 0, "Register")
            reg_tree.call("set_column_title", 1, "Value")
            reg_tree.call("set_column_titles_visible", true)
            reg_tree.call("set_h_size_flags", 3)
            reg_tree.call("set_v_size_flags", 3)
            reg_tree.hide_root = true
            reg_box.add_child(reg_tree)
            @registers_tree = reg_tree
          end
        end
      end
    end

    private def submit_current_command : Void
      line = @command_input
      return unless line

      cmd = line.text.strip
      return if cmd.empty?

      append_console("[r2] #{cmd}\n")
      line.text = ""

      if cb = @on_command_callback
        cb.call(cmd)
      elsif driver = @driver
        driver.send_command(cmd)
      end
    end

    private def on_tree_item_selected : Void
      tree = @stack_tree
      return unless tree

      selected = tree.get_selected
      return unless selected

      meta = selected.call_str("get_metadata", 0)
      if !meta.empty? && meta.includes?("::")
        parts = meta.split("::")
        file = parts[0]
        line_num = parts[1]?.try(&.to_i32?) || 0
        addr_str = parts[2]? || ""
        frame = Debugger::StackFrame.new(0, selected.get_text(0_i64), file, line_num, addr_str)
        if cb = @on_frame_select_callback
          cb.call(frame)
        end
      end
    end
  end
end
