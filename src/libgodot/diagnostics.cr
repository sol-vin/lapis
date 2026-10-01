require "./diagnostics/leak_tracker"
require "./diagnostics/dispatch_profiler"
require "./diagnostics/tombstone_tracker"
require "./diagnostics/signal_spy"

module Godot
  # Master diagnostics helpers for Lapis
  def self.signal_spy
    ::Godot::SignalSpy
  end
  def self.leak_tracker
    ::Godot::LeakTracker
  end

  def self.dispatch_profiler
    ::Godot::DispatchProfiler
  end

  def self.tombstone_tracker
    ::Godot::TombstoneTracker
  end

  def self.dump_leaks(io : IO = STDERR) : Int32
    ::Godot::LeakTracker.dump_leaks(io)
  end

  def self.dump_dispatch_profile(io : IO = STDOUT, top_n : Int32 = 20) : Void
    ::Godot::DispatchProfiler.dump_profile(io, top_n)
  end
end
