module Lapis
  module Docs
    # ===========================================================================
    # Guide Q: Testing Apparatus, Frame-Stepping, Signal Timeouts & In-Editor Suites
    # ===========================================================================
    #
    # LibGodot provides a reusable, first-class **Testing Apparatus** (`Lapis::Test`, accessible via `include Lapis::Test`)
    # designed for game developers, addon authors, and engine engineers.
    # It unifies standard assertion matchers, cooperative async frame-stepping,
    # signal awaiting with configurable timeout failure guarantees, and live in-editor
    # test execution docked directly inside the Godot Editor.
    #
    # ---
    #
    # ### 1. Assertion Matchers Reference
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Assertion Method</th>
    #       <th style="padding: 10px 14px;">Signature / Parameters</th>
    #       <th style="padding: 10px 14px;">Description &amp; Behavior</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_true</code></td>
    #       <td style="padding: 10px 14px;"><code>cond : Bool, msg = ""</code></td>
    #       <td style="padding: 10px 14px;">Fails if <code>cond</code> is false.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_false</code></td>
    #       <td style="padding: 10px 14px;"><code>cond : Bool, msg = ""</code></td>
    #       <td style="padding: 10px 14px;">Fails if <code>cond</code> is true.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_eq</code></td>
    #       <td style="padding: 10px 14px;"><code>actual, expected, msg = ""</code></td>
    #       <td style="padding: 10px 14px;">Fails if <code>actual != expected</code>. Outputs formatted inspected values.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_approx_eq</code></td>
    #       <td style="padding: 10px 14px;"><code>actual, expected, epsilon = 0.001, msg = ""</code></td>
    #       <td style="padding: 10px 14px;">Fails if floating-point difference exceeds <code>epsilon</code>.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_nil</code> / <code>assert_not_nil</code></td>
    #       <td style="padding: 10px 14px;"><code>val, msg = ""</code></td>
    #       <td style="padding: 10px 14px;">Asserts nil or non-nil reference.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_raises</code></td>
    #       <td style="padding: 10px 14px;"><code>klass : T.class, msg = "", &amp;block</code></td>
    #       <td style="padding: 10px 14px;">Asserts block raises exception of type <code>T</code>. Returns the caught exception.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_includes</code></td>
    #       <td style="padding: 10px 14px;"><code>collection, item, msg = ""</code></td>
    #       <td style="padding: 10px 14px;">Fails if collection does not contain <code>item</code>.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_in_delta</code></td>
    #       <td style="padding: 10px 14px;"><code>actual, expected, delta, msg = ""</code></td>
    #       <td style="padding: 10px 14px;">Fails if difference between numbers exceeds <code>delta</code>.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_between</code></td>
    #       <td style="padding: 10px 14px;"><code>actual, min, max, msg = ""</code></td>
    #       <td style="padding: 10px 14px;">Fails if number is outside the inclusive range <code>[min, max]</code>.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # ### 2. Async Frame-Stepping & Physics Ticks
    #
    # In game testing, verifying state mutations often requires advancing simulation frames
    # without blocking the OS thread or freezing the engine:
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Async Helper</th>
    #       <th style="padding: 10px 14px;">Signature</th>
    #       <th style="padding: 10px 14px;">Mechanics &amp; Usage</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>skip_frames</code></td>
    #       <td style="padding: 10px 14px;"><code>count : Int32 = 1</code></td>
    #       <td style="padding: 10px 14px;">Cooperatively yields execution across <code>count</code> process (render/idle) frames using <code>Godot.next_frame</code>.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>skip_physics_frames</code></td>
    #       <td style="padding: 10px 14px;"><code>count : Int32 = 1</code></td>
    #       <td style="padding: 10px 14px;">Cooperatively yields execution across <code>count</code> fixed physics ticks using <code>Godot.physics_frame</code>. Ideal for testing collisions and rigid body movements.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ```
    # test_suite "Physics" do
    #   test "Player jump acceleration" do
    #     player = Godot.create(PlayerNode)
    #     root.call("add_child", player)
    #     player.velocity = Godot::Vector3.new(0.0, 10.0, 0.0)
    #
    #     # Step 5 physics ticks
    #     skip_physics_frames(5)
    #     assert_true player.position.y > 0.0_f32
    #   end
    # end
    # ```
    #
    # ---
    #
    # ### 3. Signal Awaiting with Configurable Timeouts
    #
    # Unbounded signal awaits are a common cause of stalled test suites and hanging CI jobs.
    # LibGodot solves this with guaranteed timeout watchdogs:
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Signal Testing Method</th>
    #       <th style="padding: 10px 14px;">Signature</th>
    #       <th style="padding: 10px 14px;">Timeout Failure Behavior</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>await_signal</code></td>
    #       <td style="padding: 10px 14px;"><code>emitter, signal_name, timeout_sec = 2.0</code></td>
    #       <td style="padding: 10px 14px;">Awaits signal emission. If <code>timeout_sec</code> expires, raises <code>Lapis::Test::TimeoutError</code> with full emitter and signal details.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_emits</code></td>
    #       <td style="padding: 10px 14px;"><code>emitter, signal_name, timeout_sec = 2.0, &amp;block</code></td>
    #       <td style="padding: 10px 14px;">Yields block and verifies signal is emitted within timeout window. Raises <code>Lapis::Test::AssertionError</code> on timeout.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>assert_no_emit</code></td>
    #       <td style="padding: 10px 14px;"><code>emitter, signal_name, duration_sec = 0.5, &amp;block</code></td>
    #       <td style="padding: 10px 14px;">Yields block and verifies signal is NOT emitted during the observation window.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>with_timeout</code></td>
    #       <td style="padding: 10px 14px;"><code>timeout_sec = 5.0, operation_name = "Operation", &amp;block</code></td>
    #       <td style="padding: 10px 14px;">Guarded watchdog that executes a block in a fiber and aborts with <code>TimeoutError</code> if stalled.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # ### 4. Signal Spies & History Inspection
    #
    # Use `SignalSpy` to intercept and assert on signal parameters:
    # ```
    # spy = SignalSpy.new(enemy, "health_changed")
    # enemy.take_damage(25)
    #
    # assert_true spy.emitted?
    # assert_eq spy.count, 1
    # assert_eq spy.first_args.not_nil!, ["75", "100"]
    # spy.disconnect
    # ```
    #
    # ---
    #
    # ### 5. In-Editor Test Execution & Editor Plugin Dock
    #
    # Tests registered via declarative macros (`test_suite`, `test_case`)
    # are accessible directly inside the Godot Editor:
    # 1. **Crystal Engine Hub Dock**:
    #    Open the **Crystal** main screen dock in the editor and click the **Unit Test Runner** tab.
    #    All registered suites and categories appear in the test tree with status indicators (`[⚪ Ready]`).
    # 2. **Execution Modes**:
    #    - **▶ Run All Specs**: Runs headless Crystal specs via `crystal spec`.
    #    - **▶ Run In-Editor Tests**: Executes all registered `Lapis::Test` suites directly within the live engine instance.
    #    - **Run Selected Test**: Executes only the clicked test or category.
    # 3. **Live Inspector Tool Buttons**:
    #    Adding `ToolTester2D` or `ToolTester3D` nodes to any editor scene provides clickable **▶ Run 2D Tool Tests**
    #    buttons in the Inspector for instant feedback.
    #
    module Q_TESTING_FRAMEWORK_AND_EDITOR_SUITES
      def self.features : Array(String)
        [
          "Reusable Lapis::Test framework with full assertion matchers (assert_eq, assert_raises, assert_between)",
          "Cooperative frame-stepping with skip_frames and skip_physics_frames",
          "Deterministic signal awaiting with configurable timeout failure (Lapis::Test::TimeoutError)",
          "Signal emission assertions (assert_emits, assert_no_emit, with_timeout watchdog)",
          "SignalSpy for recording emission counts, call histories, and parameter payloads",
          "Declarative DSL macros: test_suite, test_case with lifecycle hooks (before_each, after_each)",
          "Godot Editor integration via CrystalPanel dock and ToolTester2D/3D Inspector buttons",
        ]
      end
    end
  end
end

