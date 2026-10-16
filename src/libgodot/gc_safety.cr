# Multi-module GC & Thread/Fiber safety guard for LibGodot GDExtension shared libraries.
#
# When multiple Crystal shared libraries (game.dll, addons/*.dll) are loaded into
# the same engine process, they share a single Boehm GC (gc.dll) instance.
# During GC collection sweeps (triggered by LibGC.collect or heap exhaustion),
# Boehm GC invokes all registered `before_collect` callbacks via `LibGC.set_push_other_roots`.
#
# If a shared library's runtime is still initializing (between GC.init and Crystal.init_runtime),
# or if a module has not initialized its own fiber/thread linked lists,
# `Fiber.@@fibers` and `Thread.@@threads` remain NULL (0x0).
# Crystal stdlib's `unsafe_each` attempts to iterate `@head` at offset 8 on NULL,
# resulting in an unrecoverable `ACCESS_VIOLATION (0xC0000005)` at address `0x8`.
#
# These guards ensure `unsafe_each` safely returns if the linked list pointer is null.

class Fiber
  def self.unsafe_each(&)
    ptr = pointerof(@@fibers).as(Pointer(Void*)).value
    return if ptr.null?
    previous_def { |f| yield f }
  end
end

class Thread
  def self.unsafe_each(&)
    ptr = pointerof(@@threads).as(Pointer(Void*)).value
    return if ptr.null?
    previous_def { |t| yield t }
  end
end
