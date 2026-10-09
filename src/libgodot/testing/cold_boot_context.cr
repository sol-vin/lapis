module Lapis
  module Test
    class ColdBootContext
      getter sandbox_dir : String
      getter test_name : String
      getter godot_exe : String

      def initialize(@test_name : String)
        @godot_exe = resolve_godot || "godot.exe"
        unique_id = "#{::Time.utc.to_unix}_#{::Random.rand(1000..9999)}"
        safe_name = @test_name.downcase.gsub(/[^a-z0-9_]+/, "_")
        @sandbox_dir = File.expand_path("scratch/.cold_boot_#{safe_name}_#{unique_id}")
        FileUtils.mkdir_p(@sandbox_dir)

        # Write clean minimal project configuration
        project_file = File.join(@sandbox_dir, "project.godot")
        unless File.exists?(project_file)
          File.write(project_file, "config_version=5\n\n[application]\nconfig/name=\"ColdBoot_#{safe_name}\"\n\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
        end
      end

      # Writes an isolated test script into the ephemeral sandbox.
      # This code only exists for this test and will NEVER be replicated across the project.
      def write_script(rel_path : String, code : String) : String
        full_path = File.join(@sandbox_dir, rel_path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, code)
        full_path
      end

      # Writes an isolated scene, resource, or configuration file into the sandbox.
      def write_file(rel_path : String, content : String) : String
        write_script(rel_path, content)
      end

      private def wait_process(proc : Process, start_wait : ::Time::Instant, timeout_seconds : Float64 = 8.0) : {Process::Status, Bool}
        timed_out = false
        {% if flag?(:windows) %}
          while !proc.terminated?
            if (::Time.instant - start_wait).total_seconds > timeout_seconds
              proc.terminate rescue nil
              timed_out = true
              break
            end
            Crystal::System::Thread.sleep(20.milliseconds)
            Fiber.yield
          end
          status = proc.wait
          {status, timed_out}
        {% else %}
          raw_status = 0
          pid = proc.pid
          while true
            ret = LibC.waitpid(pid, pointerof(raw_status), LibC::WNOHANG)
            if ret == pid || ret == -1
              break
            end
            if (::Time.instant - start_wait).total_seconds > timeout_seconds
              proc.terminate rescue nil
              proc.signal(::Signal.new(9)) rescue nil
              LibC.waitpid(pid, pointerof(raw_status), 0)
              timed_out = true
              break
            end
            Crystal::System::Thread.sleep(20.milliseconds)
            Fiber.yield
          end
          status = Process::Status.[raw_status]
          {status, timed_out}
        {% end %}
      end

      # Runs an isolated script in a dedicated headless Godot process with complete environment isolation.
      def run_isolated_script(script_rel_path : String, args : Array(String) = [] of String) : TestResult
        res_script = script_rel_path.starts_with?("res://") ? script_rel_path : "res://#{script_rel_path}"
        run_args = [
          "--headless",
          "--audio-driver", "Dummy",
          "--display-driver", "headless",
          "--quit-after", "100",
          "--path", @sandbox_dir,
          "-s", res_script,
          "--"
        ] + args

        out_file = File.tempfile("stdout")
        err_file = File.tempfile("stderr")
        start = ::Time.instant
        begin
          proc = Process.new(@godot_exe, run_args, output: out_file, error: err_file)
          status, timed_out = wait_process(proc, start)
          out_file.rewind
          err_file.rewind
          duration = (::Time.instant - start).total_milliseconds
          out_str = out_file.gets_to_end + "\n" + err_file.gets_to_end
          code = status.normal_exit? ? status.exit_code : -1
          success = !timed_out && status.success?
          status_str = success ? "PASS" : "FAIL"
          msg = if timed_out
            "Process timed out after 8s: #{out_str}"
          elsif success
            out_str.strip
          else
            "Process exited with code #{code}: #{out_str}"
          end
          TestResult.new("ColdBoot", @test_name, success, msg, duration, status_str)
        rescue ex
          duration = (::Time.instant - start).total_milliseconds
          TestResult.new("ColdBoot", @test_name, false, "Failed to launch isolated engine: #{ex.message}", duration, "FAIL")
        ensure
          out_file.delete rescue nil
          err_file.delete rescue nil
        end
      end

      # Executes the isolated project in headless runtime mode
      def run_isolated_project(args : Array(String) = [] of String) : TestResult
        run_args = [
          "--headless",
          "--audio-driver", "Dummy",
          "--display-driver", "headless",
          "--quit-after", "100",
          "--path", @sandbox_dir,
        ] + args

        out_file = File.tempfile("stdout")
        err_file = File.tempfile("stderr")
        start = ::Time.instant
        begin
          proc = Process.new(@godot_exe, run_args, output: out_file, error: err_file)
          status, timed_out = wait_process(proc, start)
          out_file.rewind
          err_file.rewind
          duration = (::Time.instant - start).total_milliseconds
          out_str = out_file.gets_to_end + "\n" + err_file.gets_to_end
          code = status.normal_exit? ? status.exit_code : -1
          success = !timed_out && status.success?
          status_str = success ? "PASS" : "FAIL"
          msg = if timed_out
            "Process timed out after 8s: #{out_str}"
          elsif success
            out_str.strip
          else
            "Process exited with code #{code}: #{out_str}"
          end
          TestResult.new("ColdBoot", @test_name, success, msg, duration, status_str)
        rescue ex
          duration = (::Time.instant - start).total_milliseconds
          TestResult.new("ColdBoot", @test_name, false, "Failed to launch isolated engine project: #{ex.message}", duration, "FAIL")
        ensure
          out_file.delete rescue nil
          err_file.delete rescue nil
        end
      end

      # Guarantees that ephemeral sandbox files are completely wiped upon completion.
      def cleanup : Void
        FileUtils.rm_rf(@sandbox_dir) if Dir.exists?(@sandbox_dir)
      end

      private def resolve_godot : String?
        if env_bin = ENV["GODOT_BIN"]? || ENV["GODOT"]? || ENV["GODOT4"]? || ENV["GODOT4_BIN"]?
          return env_bin if File.exists?(env_bin)
        end
        ["./godot.exe", "../godot.exe", "godot.exe", "./godot", "../godot", "godot"].each do |c|
          return c if File.exists?(c) || Process.find_executable(c)
        end
        nil
      end
    end
  end
end
