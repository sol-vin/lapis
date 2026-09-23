# =============================================================================
# LibGodot Performance Stress Benchmark - Main Application & CLI Router
# =============================================================================

require "lapis"
require "./framework/perf_metrics"
require "./framework/perf_base"
require "./framework/perf_registry"
require "./framework/perf_hud"

# Test scenarios
require "./tests/node_spawn_stress"
require "./tests/node_delete_stress"
require "./tests/node_churn_stress"
require "./tests/node_lifespan_stress"
require "./tests/hierarchy_stress"
require "./tests/alignment_stress"
require "./tests/refcounted_stress"
require "./tests/signal_stress"
require "./tests/worker_stress"
require "./tests/crystal_balloon_stress"

# Interactive Menu
require "./menu/perf_menu"

module PerfFramework
  struct CommandLineConfig
    property test_id : String? = nil
    property target_count : Int32? = nil
    property duration : Float64? = nil
    property is_infinite : Bool = false
    property cycles : Int32? = nil
    property run_all : Bool = false

    def initialize
    end
  end

  @[Tool]
  node PerfMainRunner < Godot::Node do
    @hud : PerfHUD?
    @menu : PerfMenu?
    @current_test_node : Godot::Node?
    @current_lifecycle : PerfLifecycleInterface?
    @active_queue = Array(TestDefinition).new
    @queue_running : Bool = false
    @is_cli_run : Bool = false

    def _ready : Void
      Godot.print("==================================================================")
      Godot.print("      LibGodot Performance & Stress Benchmark Initialized        ")
      Godot.print("==================================================================")

      # 1. Grab scene HUD and Menu, or instantiate dynamically if not in scene
      @hud = get_node_as?(PerfHUD, "StandardPerfHUD")
      if @hud.nil?
        hud = Godot.create(PerfHUD)
        hud.call("set_name", "StandardPerfHUD")
        add_child(hud)
        @hud = hud
      end

      @menu = get_node_as?(PerfMenu, "InteractivePerfMenu")
      if @menu.nil?
        menu = Godot.create(PerfMenu)
        menu.call("set_name", "InteractivePerfMenu")
        add_child(menu)
        @menu = menu
      end

      if hud = @hud
        hud.on_return_menu = -> { handle_escape_or_return }
      end

      if menu = @menu
        menu.on_launch_test = ->(tdef : TestDefinition, count : Int32, dur : Float64, is_inf : Bool) {
          Godot.print("[Main] Delegated launch: #{tdef.id} (count=#{count}, dur=#{dur}s, inf=#{is_inf})")
          hide_menu
          launch_test_definition(tdef, count, dur, is_inf, nil)
        }
        menu.on_launch_all = -> {
          Godot.print("[Main] Delegated launch all")
          hide_menu
          start_run_all(nil, nil)
        }
        Godot.print("[Main] Successfully wired PerfHUD and PerfMenu delegates.")
      else
        Godot.printerr("[Main ERROR] PerfMenu could not be found or created!")
      end

      # 2. Parse command line arguments
      config = parse_command_line

      if test_id = config.test_id
        # CLI direct launch mode
        @is_cli_run = true
        hide_menu
        Godot.print("[CLI] Direct launch requested for: #{test_id}")
        launch_single_by_id(test_id, config.target_count, config.duration, config.is_infinite, config.cycles)
      elsif config.run_all
        # CLI run-all mode
        @is_cli_run = true
        hide_menu
        Godot.print("[CLI] Sequential execution of all stress tests requested.")
        start_run_all(config.target_count, config.duration)
      else
        # Default: show menu
        Godot.print("[Menu] No direct test specified. Displaying interactive menu...")
        show_menu
      end
    end

    def show_menu : Void
      cleanup_active_test
      if menu = @menu
        menu.set_visible(true)
      end
    end

    def hide_menu : Void
      if menu = @menu
        menu.set_visible(false)
      end
    end

    def launch_single_by_id(
      id : String,
      count : Int32? = nil,
      duration : Float64? = nil,
      is_infinite : Bool = false,
      cycles : Int32? = nil,
    ) : Void
      tdef = TestRegistry.find?(id)
      if tdef.nil?
        Godot.printerr("[CLI ERROR] Unknown test id: '#{id}'. Available tests: #{TestRegistry.ids.join(", ")}")
        show_menu
        return
      end

      launch_test_definition(tdef, count, duration, is_infinite, cycles)
    end

    def launch_test_definition(
      tdef : TestDefinition,
      count : Int32? = nil,
      duration : Float64? = nil,
      is_infinite : Bool = false,
      cycles : Int32? = nil,
    ) : Void
      cleanup_active_test

      result = tdef.instantiate_test
      if result.nil?
        Godot.printerr("[ERROR] Failed to instantiate scene for #{tdef.id} from #{tdef.scene_path}")
        show_menu
        return
      end

      test_node, lifecycle = result
      test_node.call("set_name", "ActiveTest_#{tdef.id}")
      add_child(test_node)
      @current_test_node = test_node
      @current_lifecycle = lifecycle

      if hud = @hud
        hud.attach_test(lifecycle)
      end

      effective_count = count || tdef.default_count
      effective_duration = duration || tdef.default_duration

      lifecycle.start_test(
        target_count: effective_count,
        duration: effective_duration,
        infinite: is_infinite,
        cycles: cycles
      )
    end

    def start_run_all(count : Int32?, duration : Float64?) : Void
      @active_queue = TestRegistry.all.dup
      @queue_running = true
      run_next_in_queue(count, duration)
    end

    def run_next_in_queue(count : Int32?, duration : Float64?) : Void
      if @active_queue.empty?
        @queue_running = false
        Godot.print("==================================================================")
        Godot.print("   All LibGodot Performance Stress Tests Completed Successfully!  ")
        Godot.print("==================================================================")
        if @is_cli_run
          quit_app(0_i64)
        else
          show_menu
        end
        return
      end

      next_test = @active_queue.shift
      Godot.print("\n[Queue] Next stress test: #{next_test.title}")
      launch_test_definition(next_test, count, duration, false, nil)
    end

    def cleanup_active_test : Void
      if lifecycle = @current_lifecycle
        lifecycle.stop_and_teardown
        @current_lifecycle = nil
      end
      if test = @current_test_node
        test.queue_free
        @current_test_node = nil
      end
      if hud = @hud
        hud.detach_test
      end
      GC.collect
    end

    def handle_escape_or_return : Void
      Godot.print("[Navigation] Escape / Back requested. Halting test and returning to menu...")
      @queue_running = false
      @active_queue.clear
      cleanup_active_test
      show_menu
    end

    def _unhandled_input(event : Godot::InputEvent) : Void
      if key = event.as?(Godot::InputEventKey)
        if key.pressed? && (key.key == Godot::Key::Escape || key.key == Godot::Key::Q)
          handle_escape_or_return
        end
      end
    end

    def quit_app(exit_code : Int64 = 0_i64) : Void
      tree = get_tree
      unless tree.pointer.null?
        tree.quit(exit_code)
      end
    end

    def _process(delta : Float64) : Void
      if lifecycle = @current_lifecycle
        if lifecycle.is_running && !lifecycle.is_paused
          lifecycle.process_tick(delta)
        end
      end

      if @queue_running
        if lifecycle = @current_lifecycle
          if lifecycle.is_finished
            run_next_in_queue(nil, nil)
          end
        end
      elsif @is_cli_run
        if lifecycle = @current_lifecycle
          if lifecycle.is_finished
            quit_app(0_i64)
          end
        end
      end
    end

    # Command line argument parser supporting Godot OS cmdline args, ARGV, and ENV
    def parse_command_line : CommandLineConfig
      config = CommandLineConfig.new

      # 1. Environment variable override
      if env_test = ENV["PERF_TEST"]?
        config.test_id = env_test
      end

      # 2. Extract arguments string
      args_list = Array(String).new

      # ARGV from Crystal if running standalone executable
      ARGV.each { |a| args_list << a } rescue nil

      # User args passed after '--' (e.g. godot --path performance -- --test=node_churn)
      begin
        user_args_str = Godot.os.call_str("get_cmdline_user_args")
        user_args_str.scan(/"([^"]+)"/) do |m|
          args_list << m[1]
        end
      rescue
      end

      # All engine args
      begin
        all_args_str = Godot.os.call_str("get_cmdline_args")
        all_args_str.scan(/"([^"]+)"/) do |m|
          args_list << m[1]
        end
      rescue
      end

      args_list.each do |arg|
        clean_arg = arg.strip
        if clean_arg.starts_with?("--test=")
          config.test_id = clean_arg.sub("--test=", "").strip
        elsif clean_arg.starts_with?("-t=")
          config.test_id = clean_arg.sub("-t=", "").strip
        elsif clean_arg == "--infinite" || clean_arg == "-i" || clean_arg == "--loop"
          config.is_infinite = true
        elsif clean_arg.starts_with?("--duration=")
          val_str = clean_arg.sub("--duration=", "").strip.downcase
          if val_str == "inf" || val_str == "infinite" || val_str == "0"
            config.is_infinite = true
          else
            config.duration = val_str.to_f64 rescue nil
          end
        elsif clean_arg.starts_with?("-d=")
          config.duration = clean_arg.sub("-d=", "").to_f64 rescue nil
        elsif clean_arg.starts_with?("--count=")
          config.target_count = clean_arg.sub("--count=", "").to_i32 rescue nil
        elsif clean_arg.starts_with?("-c=")
          config.target_count = clean_arg.sub("-c=", "").to_i32 rescue nil
        elsif clean_arg.starts_with?("--cycles=")
          config.cycles = clean_arg.sub("--cycles=", "").to_i32 rescue nil
        elsif clean_arg == "--all"
          config.run_all = true
        end
      end

      config
    end
  end
end
