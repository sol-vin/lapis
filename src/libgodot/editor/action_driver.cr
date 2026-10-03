# =============================================================================
# LibGodot - In-Editor Action Driver ("Selenium for Godot Editor")
# =============================================================================
# Programmatic DOM-style UI traversal, synthesized input events, high-level
# editor workflows, and condition waiting for both headless and visual modes.
# =============================================================================

require "../editor"
require "../extensions/node"
require "../types"
require "../testing"

module Lapis
  module Editor
    class ActionDriver
      getter base_control : Godot::Control?
      getter action_log : Array(String) = Array(String).new

      def initialize(base : Godot::Control? = nil)
        @base_control = base || resolve_editor_base_control
      end

      # Resolves the root Control of the Godot Editor
      def resolve_editor_base_control : Godot::Control?
        return nil if Godot::EditorInterface.singleton_ptr.null?
        ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        ctrl = ed_iface.get_base_control rescue nil
        ctrl && !ctrl.pointer.null? ? ctrl : nil
      end

      def log_action(msg : String) : Void
        timestamp = ::Time.local.to_s("%H:%M:%S")
        entry = "[#{timestamp}] #{msg}"
        @action_log << entry
        Godot.print("[ActionDriver] #{msg}")
      end

      # =======================================================================
      # 1. UI Locators
      # =======================================================================

      # Finds any Control matching predicate recursively
      def find_control_where(root : Godot::Node? = nil, max_depth : Int32 = 12, &predicate : Godot::Control -> Bool) : Godot::Control?
        start_node = root || @base_control
        return nil unless start_node && start_node.active?
        traverse_control(start_node, 0, max_depth, predicate)
      end

      private def traverse_control(node : Godot::Node, current_depth : Int32, max_depth : Int32, predicate : Godot::Control -> Bool) : Godot::Control?
        return nil if current_depth > max_depth || !node.active?

        if node.is_a?(Godot::Control)
          return node if predicate.call(node)
        elsif !node.pointer.null? && Godot::Bridge.object_is_class(node.pointer, "Control")
          ctrl = Godot::Control.new(node.pointer)
          return ctrl if predicate.call(ctrl)
        end

        node.get_children.each do |child|
          if match = traverse_control(child, current_depth + 1, max_depth, predicate)
            return match
          end
        end
        nil
      end

      # Finds a Button by text, tooltip, or node name
      def find_button(text_or_name : String, root : Godot::Node? = nil) : Godot::Button?
        ctrl = find_control_where(root) do |c|
          if c.get_class == "Button" || c.is_a?(Godot::Button)
            btn = c.as?(Godot::Button) || Godot::Button.new(c.pointer)
            btn_text = (btn.get_text rescue "") || (btn.call_str("get_text") rescue "")
            btn_text = btn.name if btn_text.empty?
            btn_name = btn.name
            btn_tip = (btn.tooltip_text rescue "") || (btn.call_str("get_tooltip_text") rescue "")
            btn_text == text_or_name || btn_name == text_or_name || (!btn_tip.empty? && btn_tip.includes?(text_or_name))
          else
            false
          end
        end
        ctrl ? (ctrl.as?(Godot::Button) || Godot::Button.new(ctrl.pointer)) : nil
      end

      # Finds a LineEdit by placeholder text or node name
      def find_line_edit(name_or_placeholder : String, root : Godot::Node? = nil) : Godot::LineEdit?
        ctrl = find_control_where(root) do |c|
          if c.get_class == "LineEdit" || c.is_a?(Godot::LineEdit)
            le = c.as?(Godot::LineEdit) || Godot::LineEdit.new(c.pointer)
            ph = le.call_str("get_placeholder") rescue ""
            c.name == name_or_placeholder || ph.includes?(name_or_placeholder)
          else
            false
          end
        end
        ctrl ? (ctrl.as?(Godot::LineEdit) || Godot::LineEdit.new(ctrl.pointer)) : nil
      end

      # Finds an Editor Dock by title/name (e.g. "Scene", "FileSystem", "Inspector", "CrystalPanel")
      def find_dock(dock_name : String) : Godot::Control?
        find_control_where do |c|
          c.name == dock_name || c.name.includes?(dock_name) || (c.get_class.includes?(dock_name) rescue false)
        end
      end

      # Finds an Inspector EditorProperty control for property name
      def find_inspector_property(prop_name : String) : Godot::Control?
        find_control_where do |c|
          cls = c.get_class rescue ""
          if cls.includes?("EditorProperty")
            p_label = c.call_str("get_edited_property") rescue ""
            p_label == prop_name || c.name.includes?(prop_name)
          else
            false
          end
        end
      end

      # Finds a Tree control by name or class
      def find_tree(name_or_class : String = "Tree", root : Godot::Node? = nil) : Godot::Tree?
        ctrl = find_control_where(root) do |c|
          (c.get_class == "Tree" || c.is_a?(Godot::Tree)) && (c.name.includes?(name_or_class) || name_or_class == "Tree")
        end
        ctrl ? (ctrl.as?(Godot::Tree) || Godot::Tree.new(ctrl.pointer)) : nil
      end

      # Finds a generic Control by CSS/XPath-like selector (e.g. "Button[text='Build']", "LineEdit#Filter", "CrystalPanel")
      def find_control(selector : String, root : Godot::Node? = nil) : Godot::Control?
        if selector.includes?("[text=")
          parts = selector.split("[text=")
          cls = parts[0].strip
          txt = parts[1].rstrip("]").strip('\'').strip('"')
          return find_control_where(root) do |c|
            match_cls = cls.empty? || c.get_class == cls || c.class.name.ends_with?("::#{cls}") || c.class.name == cls
            c_text = (c.call_str("get_text") rescue "")
            c_text = c.name if c_text.empty?
            match_cls && (c_text == txt || c.name == txt)
          end
        elsif selector.starts_with?("#")
          id = selector.lchop("#")
          return find_control_where(root) { |c| c.name == id }
        elsif selector.includes?("#")
          cls, id = selector.split("#", 2)
          return find_control_where(root) do |c|
            match_cls = cls.empty? || c.get_class == cls || c.class.name.ends_with?("::#{cls}") || c.class.name == cls
            match_cls && c.name == id
          end
        else
          # Match by name or class
          find_control_where(root) do |c|
            c.name == selector || c.get_class == selector || c.class.name.ends_with?("::#{selector}") || c.class.name == selector
          end
        end
      end

      # =======================================================================
      # 2. Input Synthesizers
      # =======================================================================

      # Simulates a mouse click (mouse button down + mouse button up) at center of target control
      def click(control : Godot::Control) : Void
        control.check_alive!
        global_pos = control.global_position rescue Godot::Vector2.new(0.0_f32, 0.0_f32)
        size = control.size rescue Godot::Vector2.new(0.0_f32, 0.0_f32)
        cx = global_pos.x.to_f64
        cy = global_pos.y.to_f64
        w = size.x.to_f64
        h = size.y.to_f64

        click_pos = Godot::Vector2.new((cx + w / 2.0).to_f32, (cy + h / 2.0).to_f32)
        log_action("Click on #{control.get_class} '#{control.name}' at #{click_pos}")

        # Dispatch via Button#emit_signal("pressed") if Button, plus gui_input
        if control.has_signal?("pressed")
          control.emit_signal("pressed")
        end

        ev_down = Lapis::Test::InputFactory.mouse_button_down(Godot::MouseButton::Left, click_pos)
        ev_up = Lapis::Test::InputFactory.mouse_button_up(Godot::MouseButton::Left, click_pos)

        if vp = (control.get_viewport rescue nil)
          vp.push_input(ev_down) rescue nil
          vp.push_input(ev_up) rescue nil
        end
      end

      # Simulates a double-click
      def double_click(control : Godot::Control) : Void
        control.check_alive!
        log_action("Double-click on #{control.get_class} '#{control.name}'")
        click(control)
        Fiber.yield
        click(control)
      end

      # Simulates a right-click (secondary mouse button for context menus)
      def right_click(control : Godot::Control) : Void
        control.check_alive!
        global_pos = control.global_position rescue Godot::Vector2.new(0.0_f32, 0.0_f32)
        cx = global_pos.x.to_f64
        cy = global_pos.y.to_f64
        pos = Godot::Vector2.new(cx.to_f32, cy.to_f32)
        log_action("Right-click on #{control.get_class} '#{control.name}'")

        ev_down = Lapis::Test::InputFactory.mouse_button_down(Godot::MouseButton::Right, pos)
        ev_up = Lapis::Test::InputFactory.mouse_button_up(Godot::MouseButton::Right, pos)
        if vp = (control.get_viewport rescue nil)
          vp.push_input(ev_down) rescue nil
          vp.push_input(ev_up) rescue nil
        end
      end

      # Simulates entering text into a LineEdit / TextEdit
      def type_text(control : Godot::Control, text : String) : Void
        control.check_alive!
        log_action("Type text '#{text}' into #{control.get_class} '#{control.name}'")
        control.call("grab_focus") rescue nil
        control.call("set_text", text) rescue nil
        if control.has_signal?("text_changed")
          control.emit_signal("text_changed", text) rescue nil
        end
        if control.has_signal?("text_submitted")
          control.emit_signal("text_submitted", text) rescue nil
        end
      end

      # Switches an Editor TabBar or TabContainer to the named tab or index
      def select_tab(container_or_bar : Godot::Control, tab_name_or_index : String | Int32) : Void
        container_or_bar.check_alive!
        log_action("Select tab '#{tab_name_or_index}' on #{container_or_bar.name}")
        idx = if tab_name_or_index.is_a?(Int32)
                tab_name_or_index
              else
                # Search tab title
                count = (container_or_bar.call_i64("get_tab_count") rescue 0_i64).to_i32
                found_idx = -1
                0.upto(count - 1) do |i|
                  title = container_or_bar.call_str("get_tab_title", i.to_i64) rescue ""
                  if title == tab_name_or_index || title.includes?(tab_name_or_index)
                    found_idx = i
                    break
                  end
                end
                found_idx >= 0 ? found_idx : 0
              end
        container_or_bar.call("set_current_tab", idx.to_i64) rescue nil
        container_or_bar.call("emit_signal", "tab_changed", idx.to_i64) rescue nil
      end

      # =======================================================================
      # 3. High-Level Editor Workflows
      # =======================================================================

      # Switches the Godot Editor Main Screen tab (e.g. "2D", "3D", "Script", "Crystal")
      def switch_to_main_screen(screen_name : String) : Void
        return if Godot::EditorInterface.singleton_ptr.null?
        ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        log_action("Switch to main screen '#{screen_name}'")
        ed_iface.call("set_main_screen_editor", screen_name) rescue nil
      end

      # Opens a scene in the editor from path
      def open_scene(res_path : String) : Void
        return if Godot::EditorInterface.singleton_ptr.null?
        ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        log_action("Open scene '#{res_path}'")
        ed_iface.call("open_scene_from_path", res_path) rescue nil
      end

      # Triggers Save Scene (Ctrl+S equivalent)
      def save_scene : Void
        return if Godot::EditorInterface.singleton_ptr.null?
        ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        log_action("Save current scene")
        ed_iface.call("save_scene") rescue nil
      end

      # Selects an edited scene node by name or path
      def select_node_in_scene(node_name_or_path : String) : Void
        return if Godot::EditorInterface.singleton_ptr.null?
        ed_iface = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        root = ed_iface.get_edited_scene_root rescue nil
        return unless root && !root.pointer.null?

        target = if node_name_or_path.starts_with?("%")
                   root.get_unique_node_as(node_name_or_path, Godot::Node)
                 elsif node_name_or_path.includes?("/")
                   root.get_node?(node_name_or_path)
                 else
                   root.find_child?(node_name_or_path)
                 end

        if target && !target.pointer.null?
          log_action("Select node in scene '#{target.name}'")
          ed_iface.edit_node(target) rescue nil
        end
      end

      # Triggers the "Build Crystal" compile button
      def trigger_crystal_build : Void
        btn = find_button("Build") || find_button("Build Crystal")
        if btn
          log_action("Triggering Crystal build button")
          click(btn)
        else
          log_action("Notice: Build button not found")
        end
      end

      # =======================================================================
      # 4. Waiters & Assertions
      # =======================================================================

      # Waits until the condition evaluates to true within timeout_sec
      def wait_until(timeout_sec : Float64 = 5.0, msg : String = "", &condition : -> Bool) : Bool
        start_time = ::Time.instant
        while !condition.call
          if (::Time.instant - start_time).total_seconds >= timeout_sec
            fail_msg = msg.empty? ? "Condition not met after #{timeout_sec}s" : "#{msg} (timed out after #{timeout_sec}s)"
            log_action("WAIT TIMEOUT: #{fail_msg}")
            raise Lapis::Test::TimeoutError.new(fail_msg)
          end
          Fiber.yield
        end
        true
      end

      # Waits until control is visible
      def wait_for_visible(control : Godot::Control, timeout_sec : Float64 = 3.0) : Void
        wait_until(timeout_sec, "Waiting for #{control.name} to become visible") do
          control.alive? && (control.call_bool("is_visible_in_tree") rescue false)
        end
      end

      # =======================================================================
      # 5. DOM Tree Hierarchy & Screenshot Capture
      # =======================================================================

      # Dumps the editor UI hierarchy as an indented text tree
      def dump_dom(root : Godot::Node? = nil, max_depth : Int32 = 6) : String
        start = root || @base_control
        return "Empty or null root" unless start && start.active?
        io = IO::Memory.new
        dump_node_recursive(start, 0, max_depth, io)
        io.to_s
      end

      private def dump_node_recursive(node : Godot::Node, depth : Int32, max_depth : Int32, io : IO) : Void
        return if depth > max_depth || !node.active?
        indent = "  " * depth
        cls = node.get_class rescue "Unknown"
        name = node.name rescue "Unnamed"
        extra = ""
        if node.is_a?(Godot::Control) || (Godot::Bridge.object_is_class(node.pointer, "Control") rescue false)
          ctrl = node.is_a?(Godot::Control) ? node.as(Godot::Control) : Godot::Control.new(node.pointer)
          size = ctrl.size rescue Godot::Vector2.new(0.0_f32, 0.0_f32)
          w = size.x.to_i32
          h = size.y.to_i32
          vis = ctrl.is_visible rescue true
          extra = " [#{w}x#{h}]" + (vis ? "" : " (hidden)")
        end
        io << indent << "• " << cls << " (" << name << ")" << extra << "\n"
        node.get_children.each do |c|
          dump_node_recursive(c, depth + 1, max_depth, io)
        end
      end

      # Captures full editor viewport screenshot and saves to file
      def take_screenshot(output_path : String = "reports/screenshots/editor.png") : String?
        ctrl = @base_control
        return nil unless ctrl && ctrl.alive?
        vp = ctrl.get_viewport rescue nil
        return nil unless vp && !vp.pointer.null?
        tex = vp.get_texture rescue nil
        return nil unless tex && !tex.pointer.null?
        img = tex.get_image rescue nil
        return nil unless img && !img.pointer.null?

        FileUtils.mkdir_p(File.dirname(output_path))
        err = img.save_png(output_path) rescue Godot::Error::Failed
        if err == Godot::Error::Ok || err.value == 0
          log_action("Screenshot saved to #{output_path}")
          output_path
        else
          log_action("Failed to save screenshot to #{output_path}")
          nil
        end
      end
    end
  end
end
