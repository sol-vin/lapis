# =============================================================================
# LibGodot - Action Driver AI Vision & Visual Manifest Engine
# =============================================================================
# Crops individual UI elements into discrete PNGs and generates Set-of-Marks
# (SoM) annotated screenshots and JSON manifests for multimodal AI agents.
# =============================================================================

require "./action_driver"
require "json"

module Lapis
  module Editor
    class ActionDriver
      # Crops a single Control into an isolated PNG screenshot based on its global rectangle
      def crop_element(control : Godot::Control, output_path : String = "reports/elements/element.png") : String?
        control.check_alive!
        ctrl = @base_control
        return nil unless ctrl && ctrl.alive?
        vp = ctrl.get_viewport rescue nil
        return nil unless vp && !vp.pointer.null?
        tex = vp.get_texture rescue nil
        return nil unless tex && !tex.pointer.null?
        img = tex.get_image rescue nil
        return nil unless img && !img.pointer.null?

        global_pos = control.global_position rescue Godot::Vector2.new(0.0_f32, 0.0_f32)
        size = control.size rescue Godot::Vector2.new(0.0_f32, 0.0_f32)

        x = global_pos.x.to_i32
        y = global_pos.y.to_i32
        w = size.x.to_i32
        h = size.y.to_i32

        return nil if w <= 0 || h <= 0

        rect = Godot::Rect2i.new(x, y, w, h)
        cropped = img.get_region(rect) rescue nil
        return nil unless cropped && !cropped.pointer.null?

        FileUtils.mkdir_p(File.dirname(output_path))
        err = cropped.save_png(output_path) rescue Godot::Error::Failed
        if err == Godot::Error::Ok || err.value == 0
          log_action("Cropped element '#{control.name}' (#{w}x#{h}) saved to #{output_path}")
          output_path
        else
          log_action("Failed to save cropped element to #{output_path}")
          nil
        end
      end

      # Discovers all visible interactive controls, saves crops, full screenshot, and a JSON manifest
      def capture_ai_manifest(output_dir : String = "reports/ai_vision") : NamedTuple(manifest_path: String, screenshot_path: String, count: Int32)
        FileUtils.mkdir_p(output_dir)
        elements_dir = File.join(output_dir, "elements")
        FileUtils.mkdir_p(elements_dir)

        raw_screenshot_path = File.join(output_dir, "screenshot_raw.png")
        take_screenshot(raw_screenshot_path)

        interactive_controls = Array(Godot::Control).new
        find_interactive_controls(@base_control, interactive_controls)

        manifest_elements = Array(Hash(String, ::JSON::Any)).new
        element_id = 0

        interactive_controls.each do |c|
          next unless c.alive?
          vis = c.is_visible_in_tree rescue false
          next unless vis

          size = c.size rescue Godot::Vector2.new(0.0_f32, 0.0_f32)
          w = size.x.to_i32
          h = size.y.to_i32
          next if w < 8 || h < 8 # Skip sub-pixel or tiny decorative spacers

          element_id += 1
          crop_filename = "#{element_id}_#{c.get_class.downcase}_#{c.name.downcase.gsub(/[^a-z0-9_]/, "_")}.png"
          crop_path = File.join(elements_dir, crop_filename)
          crop_element(c, crop_path)

          global_pos = c.global_position rescue Godot::Vector2.new(0.0_f32, 0.0_f32)
          gx = global_pos.x.to_i32
          gy = global_pos.y.to_i32

          text = c.call_str("get_text") rescue ""
          tooltip = c.tooltip_text rescue (c.call_str("get_tooltip_text") rescue "")

          item_data = Hash(String, ::JSON::Any).new
          item_data["id"] = ::JSON::Any.new(element_id.to_i64)
          item_data["name"] = ::JSON::Any.new(c.name)
          item_data["class"] = ::JSON::Any.new(c.get_class)
          item_data["text"] = ::JSON::Any.new(text)
          item_data["tooltip"] = ::JSON::Any.new(tooltip)
          item_data["rect"] = ::JSON::Any.new({
            "x" => ::JSON::Any.new(gx.to_i64),
            "y" => ::JSON::Any.new(gy.to_i64),
            "width" => ::JSON::Any.new(w.to_i64),
            "height" => ::JSON::Any.new(h.to_i64),
          })
          item_data["cropped_image"] = ::JSON::Any.new("elements/#{crop_filename}")

          manifest_elements << item_data
        end

        manifest = Hash(String, ::JSON::Any).new
        manifest["timestamp"] = ::JSON::Any.new(::Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ"))
        manifest["screenshot_raw"] = ::JSON::Any.new("screenshot_raw.png")
        manifest["element_count"] = ::JSON::Any.new(element_id.to_i64)
        manifest["elements"] = ::JSON::Any.new(manifest_elements.map { |m| ::JSON::Any.new(m) })

        manifest_path = File.join(output_dir, "ui_manifest.json")
        File.write(manifest_path, manifest.to_pretty_json)
        log_action("AI Vision Manifest generated: #{manifest_path} (#{element_id} elements)")

        {
          manifest_path: manifest_path,
          screenshot_path: raw_screenshot_path,
          count: element_id,
        }
      end

      private def find_interactive_controls(node : Godot::Node?, list : Array(Godot::Control)) : Void
        return unless node && node.alive?
        cls = node.get_class rescue ""

        is_interactive = case cls
                         when "Button", "CheckButton", "CheckBox", "OptionButton", "MenuButton",
                              "LineEdit", "TextEdit", "CodeEdit", "SpinBox", "HSlider", "VSlider",
                              "TabBar", "Tree", "ItemList"
                           true
                         else
                           false
                         end

        if is_interactive && node.is_a?(Godot::Control)
          list << node
        elsif is_interactive && !node.pointer.null? && (Godot::Bridge.object_is_class(node.pointer, "Control") rescue false)
          list << Godot::Control.new(node.pointer)
        end

        node.get_children.each do |c|
          find_interactive_controls(c, list)
        end
      end
    end
  end
end
