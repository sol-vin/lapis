module Lapis
  module Docs
    # # Q. Testing Apparatus, Frame-Stepping, Signal Timeouts & In-Editor Suites
    #
    # LibGodot provides a reusable, first-class **Testing Apparatus** (`Lapis::Test`, accessible via
    # `include Lapis::Test`) designed for game developers, addon authors, and engine engineers.
    # It unifies standard assertion matchers, cooperative async frame-stepping, signal awaiting with
    # timeout guarantees, and live in-editor test execution docked directly inside the Godot Editor.
    #
    # ### Executive Summary & Key Topics
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Topic</th>
    #       <th>Method / Anchor</th>
    #       <th>Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><strong>Key Features</strong></td>
    #       <td><code>.topic_00_key_features</code></td>
    #       <td>Key features of Lapis::Test.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Apparatus Overview</strong></td>
    #       <td><code>.topic_01_testing_apparatus_overview</code></td>
    #       <td>Architecture of test_suite, test, before_each/after_each fixtures, and registry.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Assertion Matchers</strong></td>
    #       <td><code>.topic_02_assertion_matchers</code></td>
    #       <td>assert_true, assert_eq, assert_approx_eq, assert_raises, and domain matchers.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Async Frame-Stepping</strong></td>
    #       <td><code>.topic_03_async_frame_stepping</code></td>
    #       <td>Cooperative skip_frames and skip_physics_frames without freezing engine loops.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Signal Await Timeouts</strong></td>
    #       <td><code>.topic_04_signal_await_timeouts</code></td>
    #       <td>Awaiting signals with failure timeouts and dead-pointer protection.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>EditorDriver & TUI</strong></td>
    #       <td><code>.topic_05_editor_driver_and_tui</code></td>
    #       <td>Headless in-editor test execution via EditorDriver and ANSI interactive TUI.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Zero Leak Verification</strong></td>
    #       <td><code>.topic_06_zero_leak_verification</code></td>
    #       <td>Quantitative memory and node leak verification using assert_no_leak.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/testing.cr`, `spec/spec_helper.cr`
    # - **Live Specifications**: `spec/editor_driver_spec.cr`, `spec/suites/`
    # - **Showcase Examples**: `src/main.cr` (`ToolTester2D`, `ToolTester3D`)
    # - **Related Guides**: `Docs::H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY`, `Docs::M_LLDB_NATIVE_DEBUGGING_GUIDE`
    module Q_TESTING_FRAMEWORK_AND_EDITOR_SUITES
      # **Key Features**: Returns key features of Lapis::Test.
      def self.topic_00_key_features : Array(String)
        [
          "First-class test_suite and test DSL with before_each / after_each fixtures",
          "Rich assertion library with domain matchers (assert_approx_eq, assert_raises)",
          "Cooperative async frame stepping: skip_frames and skip_physics_frames",
          "Bounded signal awaiting preventing indefinite hangs in automated CI",
          "Quantitative memory leak verification via assert_no_leak",
          "Interactive ANSI Terminal UI (TUI) dashboard for live test runs",
        ]
      end

      # **Testing Apparatus Overview**: Architecture of test_suite, test, and lifecycle fixtures.
      #
      # Suites are authored using `test_suite` and `test` blocks:
      #
      # ```crystal
      # require "libgodot"
      # include Lapis::Test
      #
      # test_suite "Player Movement System" do
      #   player = Player.new
      #
      #   before_each do
      #     player.reset_position
      #   end
      #
      #   after_each do
      #     player.clear_inventory
      #   end
      #
      #   test "applies gravity when airborne" do
      #     player.velocity = Vector3.new(0, 0, 0)
      #     skip_physics_frames(5)
      #     assert_true(player.velocity.y < 0.0, "Velocity should drop under gravity")
      #   end
      # end
      # ```
      #
      # See also: `spec/suites/test_macros_dsl.cr`
      def self.topic_01_testing_apparatus_overview : Nil
      end

      # **Assertion Matchers Reference**: Rich assertion library with domain matchers.
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Assertion</th>
      #       <th>Signature</th>
      #       <th>Description</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><code>assert_true</code> / <code>assert_false</code></td>
      #       <td><code>cond : Bool, msg = ""</code></td>
      #       <td>Asserts boolean truth or falsehood.</td>
      #     </tr>
      #     <tr>
      #       <td><code>assert_eq</code></td>
      #       <td><code>actual, expected, msg = ""</code></td>
      #       <td>Asserts equality; displays inspected diff on failure.</td>
      #     </tr>
      #     <tr>
      #       <td><code>assert_approx_eq</code></td>
      #       <td><code>actual, expected, epsilon = 0.001</code></td>
      #       <td>Asserts floating-point difference is within epsilon tolerance.</td>
      #     </tr>
      #     <tr>
      #       <td><code>assert_nil</code> / <code>assert_not_nil</code></td>
      #       <td><code>val, msg = ""</code></td>
      #       <td>Asserts nil or non-nil reference.</td>
      #     </tr>
      #     <tr>
      #       <td><code>assert_raises</code></td>
      #       <td><code>klass : T.class, &amp;block</code></td>
      #       <td>Asserts block raises exception of type T; returns exception.</td>
      #     </tr>
      #     <tr>
      #       <td><code>assert_includes</code></td>
      #       <td><code>collection, item, msg = ""</code></td>
      #       <td>Asserts item is present within collection.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # See also: `src/libgodot/testing.cr`
      def self.topic_02_assertion_matchers : Nil
      end

      # **Async Frame-Stepping**: Cooperative skip_frames and skip_physics_frames without freezing engine loops.
      #
      # In game testing, verifying state mutations often requires advancing simulation frames
      # without blocking the OS thread or freezing the engine:
      #
      # ```crystal
      # test "advances animation state" do
      #   anim_player.play("walk")
      #   # Cooperatively advance 10 visual frames:
      #   skip_frames(10)
      #   assert_true(anim_player.is_playing)
      #
      #   # Cooperatively advance 60 fixed physics ticks:
      #   skip_physics_frames(60)
      # end
      # ```
      def self.topic_03_async_frame_stepping : Nil
      end

      # **Signal Awaiting with Timeouts**: Awaiting signals with strict timeout failure bounds.
      #
      # Tests can asynchronously await signals with strict timeout failure bounds:
      #
      # ```crystal
      # test "emits level_cleared upon reaching goal" do
      #   goal_node.trigger_contact(player)
      #   # Automatically fails test if signal is not emitted within 2.0 seconds:
      #   await(goal_node.level_cleared, timeout_sec: 2.0)
      # end
      # ```
      #
      # Awaiting fibers validate target `#alive?` on every frame slice, preventing CI hangs.
      def self.topic_04_signal_await_timeouts : Nil
      end

      # **EditorDriver & Interactive TUI**: Headless in-editor test execution and ANSI dashboard.
      #
      # - **EditorDriver** (`Lapis::Test::EditorDriver`): Launches Godot headlessly in editor mode
      #   (`godot.exe --headless --editor --path .`), verifying `@tool` scripts, gizmos, and inspector updates.
      # - **Interactive TUI Dashboard**: `lapis test --tui` opens an ANSI split-pane dashboard with
      #   real-time progress, rolling logs, and phase navigation (`↑`/`↓`/`j`/`k`).
      #
      # See also: `spec/editor_driver_spec.cr`
      def self.topic_05_editor_driver_and_tui : Nil
      end

      # **Quantitative Zero Leak Verification**: Mathematically verifying zero object or node leaks.
      #
      # Standardized assertion monitors Godot's `Performance` singleton monitors (`OBJECT_COUNT`,
      # `OBJECT_NODE_COUNT`, `MEMORY_STATIC`) and Crystal's `GC.collect`:
      #
      # ```crystal
      # test "creates and destroys nodes cleanly without leaking" do
      #   Lapis::Test.assert_no_leak do
      #     node = Godot.create(Godot::Node2D)
      #     node.destroy
      #   end
      # end
      # ```
      #
      # See also: `spec/suites/test_lifecycle_destruction.cr`
      def self.topic_06_zero_leak_verification : Nil
      end
    end
  end
end
