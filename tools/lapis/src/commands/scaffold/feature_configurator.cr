# tools/lapis/src/commands/scaffold/feature_configurator.cr
require "file_utils"
require "../../core/env"
require "../../core/logger"

module Lapis
  module Commands
    module Scaffold
      struct ProjectFeatures
        property physics_2d : Bool = true
        property physics_3d : Bool = false
        property tool_testers : Bool = false
        property audio_singleton : Bool = false
        property debug_hud : Bool = false
        property input_map : Bool = true

        def initialize(
          @physics_2d : Bool = true,
          @physics_3d : Bool = false,
          @tool_testers : Bool = false,
          @audio_singleton : Bool = false,
          @debug_hud : Bool = false,
          @input_map : Bool = true
        )
        end
      end

      class FeatureConfigurator
        def self.apply(dest : Path, features : ProjectFeatures, addons : Array(String) = [] of String) : Void
          # 1. Customize project.godot
          godot_proj = dest.join("project.godot")
          if File.exists?(godot_proj)
            content = File.read(godot_proj)

            # Texture filtering for 2D pixel games
            if features.physics_2d && !features.physics_3d
              unless content.includes?("default_texture_filter")
                content += "\n[rendering]\ntextures/canvas_textures/default_texture_filter=0\n"
              end
            end

            # Autoload AudioManager
            if features.audio_singleton && !content.includes?("AudioManager=")
              content += "\n[autoload]\nAudioManager=\"*res://scenes/audio_manager.tscn\"\n"
            end

            # Autoload DebugHUD
            if features.debug_hud && !content.includes?("DebugHUD=")
              content += "\n[autoload]\nDebugHUD=\"*res://scenes/debug_hud.tscn\"\n"
            end

            File.write(godot_proj, content)
          end

          # 2. Generate Audio Manager if enabled
          if features.audio_singleton
            generate_audio_manager(dest)
          end

          # 3. Generate Debug HUD if enabled
          if features.debug_hud
            generate_debug_hud(dest)
          end

          # 4. Prune or customize 3D / 2D specific files
          if !features.physics_3d
            ["src/player_3d.cr", "scenes/main_3d.tscn"].each do |f|
              path = dest.join(f)
              FileUtils.rm_rf(path) if File.exists?(path)
            end
          end

          # 5. Inject selected addons into addons/
          root = Core::Env::ROOT_DIR
          addons.each do |addon_name|
            next if addon_name.empty? || addon_name == "crystal_integration"
            source_addon = root.join("addons/#{addon_name}")
            target_addon = dest.join("addons/#{addon_name}")

            if Dir.exists?(source_addon) && !Dir.exists?(target_addon)
              Core::Logger.step("Scaffold:Addon", "Injecting addon '#{addon_name}' into project...")
              FileUtils.mkdir_p(target_addon)
              FileUtils.cp_r(source_addon.to_s, target_addon.parent.to_s)
            end
          end
        end

        private def self.generate_audio_manager(dest : Path) : Void
          scenes_dir = dest.join("scenes")
          src_dir = dest.join("src")
          FileUtils.mkdir_p(scenes_dir)
          FileUtils.mkdir_p(src_dir)

          audio_cr = src_dir.join("audio_manager.cr")
          unless File.exists?(audio_cr)
            File.write(audio_cr, <<-CR)
require "libgodot"

# Global audio manager autoload singleton for sound effects and background music
node AudioManager < Node do
  def _ready : Void
    Godot.print("AudioManager initialized.")
  end

  def play_sound(stream : Godot::AudioStream, volume_db : Float32 = 0.0_f32) : Void
    player = Godot.create(Godot::AudioStreamPlayer)
    player.stream = stream
    player.volume_db = volume_db
    add_child(player)
    player.play
    # Automatically clean up player when sound playback finishes
    player.finished.connect do
      player.queue_free
    end
  end
end
CR
          end
        end

        private def self.generate_debug_hud(dest : Path) : Void
          scenes_dir = dest.join("scenes")
          src_dir = dest.join("src")
          FileUtils.mkdir_p(scenes_dir)
          FileUtils.mkdir_p(src_dir)

          hud_cr = src_dir.join("debug_hud.cr")
          unless File.exists?(hud_cr)
            File.write(hud_cr, <<-CR)
require "libgodot"

# Lightweight real-time performance and memory monitor overlay
node DebugHUD < CanvasLayer do
  @label : Godot::Label?

  def _ready : Void
    label = Godot.create(Godot::Label)
    label.position = Vector2.new(10.0_f32, 10.0_f32)
    add_child(label)
    @label = label
  end

  def _process(delta : Float64) : Void
    return unless (lbl = @label) && lbl.alive?

    fps = Godot::Engine.get_frames_per_second
    mem = Godot::OS.get_static_memory_usage.to_f / (1024.0 * 1024.0)
    obj_count = Godot::Performance.get_monitor(Godot::Performance::Monitor::TIME_FPS).to_i

    lbl.text = "FPS: \#{fps} | Static Mem: \#{mem.round(2)} MB"
  end
end
CR
          end
        end
      end
    end
  end
end
