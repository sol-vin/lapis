module Lapis
  module Docs
    # ===========================================================================
    # Guide M: Native LLDB In-Editor Debugging, Tool Scripts & Multiplayer Sessions
    # ===========================================================================
    #
    # LibGodot integrates **LLDB** directly into the Godot Editor's native Debugger dock,
    # enabling in-editor breakpoints, interactive command consoles, stack traces,
    # multiplayer multi-session coordination, and guidance for debugging live tool scripts.
    #
    # ---
    #
    # ### 1. Prerequisite Tooling
    #
    # Because Crystal's compiler is built directly on **LLVM**, LLDB natively parses
    # both Microsoft `.pdb` (Program Database) files on Windows and DWARF debug info
    # on Linux and macOS without external symbol converters.
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Platform</th>
    #       <th style="padding: 10px 14px;">Package Manager</th>
    #       <th style="padding: 10px 14px;">Installation Command</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Windows</strong></td>
    #       <td style="padding: 10px 14px;">Scoop / WinGet</td>
    #       <td style="padding: 10px 14px;"><code>scoop install llvm</code> or <code>winget install LLVM.LLVM</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Ubuntu / Debian</strong></td>
    #       <td style="padding: 10px 14px;">APT</td>
    #       <td style="padding: 10px 14px;"><code>sudo apt install lldb</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Arch Linux</strong></td>
    #       <td style="padding: 10px 14px;">Pacman</td>
    #       <td style="padding: 10px 14px;"><code>sudo pacman -S lldb</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>macOS</strong></td>
    #       <td style="padding: 10px 14px;">Homebrew / Xcode</td>
    #       <td style="padding: 10px 14px;"><code>brew install llvm</code> or <code>xcode-select --install</code></td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # Verify installation from your terminal:
    # ```bash
    # lldb --version
    # ```
    #
    # ---
    #
    # ### 2. Native Debug Symbols & Compilation
    #
    # When compiling in development mode (`make all` or pressing **F5** in the editor),
    # Crystal emits full debug symbols (`--debug`):
    # - **Windows**: Produces `bin/game.pdb` (Microsoft Program Database). LLDB reads this
    #   directly to map machine instructions to Crystal source files and line numbers.
    # - **Linux / macOS**: Produces standard DWARF debug info embedded within `game.so` or `game.dylib`.
    #
    # ---
    #
    # ### 3. In-Editor Breakpoint Synchronization & Navigation
    #
    # 1. Open any Crystal source file (e.g. `src/player.cr`) in Godot's Script Editor.
    # 2. Click the gutter next to any line number to set a red breakpoint marker.
    # 3. Godot's <code>EditorDebuggerPlugin._breakpoint_set_in_tree</code> intercepts the event,
    #    translates <code>res://</code> paths to absolute filesystem paths, and pushes
    #    <code>breakpoint set --file &lt;file&gt; --line &lt;line&gt;</code> to all active LLDB sessions.
    # 4. When execution hits the breakpoint, the Godot Script Editor automatically navigates
    #    to the file and line, highlighting the current execution frame.
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Control</th>
    #       <th style="padding: 10px 14px;">Shortcut</th>
    #       <th style="padding: 10px 14px;">Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Continue</strong></td>
    #       <td style="padding: 10px 14px;"><code>F5</code></td>
    #       <td style="padding: 10px 14px;">Resumes process execution until the next breakpoint or signal.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Step Over</strong></td>
    #       <td style="padding: 10px 14px;"><code>F10</code></td>
    #       <td style="padding: 10px 14px;">Executes the current line without stepping inside function calls.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Step Into</strong></td>
    #       <td style="padding: 10px 14px;"><code>F11</code></td>
    #       <td style="padding: 10px 14px;">Steps into the method or function called on the current line.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Step Out</strong></td>
    #       <td style="padding: 10px 14px;"><code>Shift + F11</code></td>
    #       <td style="padding: 10px 14px;">Finishes executing the current function and returns to the caller.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Pause</strong></td>
    #       <td style="padding: 10px 14px;">—</td>
    #       <td style="padding: 10px 14px;">Interrupts execution immediately via <code>process interrupt</code>.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # ### 4. Multiplayer Multi-Session Coordination & Lockstep Break Mode
    #
    # When running multiple game instances simultaneously in the Godot Editor (via
    # <strong>Debug &gt; Run Multiple Instances</strong>):
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Feature</th>
    #       <th style="padding: 10px 14px;">Mechanic</th>
    #       <th style="padding: 10px 14px;">Multiplayer Benefit</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Per-Session Isolation</strong></td>
    #       <td style="padding: 10px 14px;">Each instance connects to its own independent LLDB controller bound to that child PID.</td>
    #       <td style="padding: 10px 14px;">Prevents breakpoints or inspect commands in Client 1 from interfering with Server or Client 2.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Role Badging</strong></td>
    #       <td style="padding: 10px 14px;">Instances report their multiplayer role (<code>Server</code>, <code>Client 1</code>, etc.) on startup.</td>
    #       <td style="padding: 10px 14px;">Developers immediately know which debugger tab corresponds to which game window.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Lockstep Break Mode</strong></td>
    #       <td style="padding: 10px 14px;">When any peer hits a breakpoint, all other peers are cooperatively interrupted via <code>process interrupt</code>.</td>
    #       <td style="padding: 10px 14px;">Eliminates network heartbeat timeout disconnections and physics state desynchronization.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # ### 5. Tool Scripts (`@[Tool]`) Debugging Architecture
    #
    # Developers frequently ask: *"If I set a breakpoint in a tool script, will it trigger?"*
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Context</th>
    #       <th style="padding: 10px 14px;">Will Breakpoint Trigger in Editor Tab?</th>
    #       <th style="padding: 10px 14px;">Reason</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Running Game Project</strong> (F5 / F6)</td>
    #       <td style="padding: 10px 14px;"><strong>YES</strong></td>
    #       <td style="padding: 10px 14px;">The tool script runs inside the spawned child game process where LLDB is actively attached.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Live In-Editor Viewport / Inspector</strong></td>
    #       <td style="padding: 10px 14px;"><strong>NO</strong></td>
    #       <td style="padding: 10px 14px;">The script executes inside the parent Godot Editor process, not a child game process.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # #### Why In-Editor Execution Does Not Trigger in the In-Editor Tab:
    #
    # 1. **Target Process Boundary**:
    #    When working inside the editor (e.g. custom docks, inspectors, editor gizmos, or `_process` running in the 2D/3D viewport),
    #    that code executes **inside the host Godot Editor process itself** (`godot.exe`), rather than in a child game process.
    #    Godot's `EditorDebuggerPlugin` only opens debug sessions when you launch game scenes.
    #
    # 2. **The Host Deadlock Paradox (Native vs Interpreted Execution)**:
    #    Unlike GDScript, which runs in an interpreted virtual machine and can pause execution within its own bytecode loop,
    #    Crystal compiles to native machine code. Native breakpoints trigger OS-level interrupts (`SIGTRAP` / `int 3`).
    #    Because the in-editor debugger tab and UI controls run on the Godot Editor's own GUI thread:
    #    - If the in-editor LLDB attached to the editor process itself, hitting a breakpoint would freeze the entire Godot Editor window.
    #    - The editor would be unable to process mouse clicks or keyboard events, making it impossible to click **Continue**, **Step**, or view the call stack in the debugger panel!
    #
    # ---
    #
    # ### 6. How to Debug Live Tool Scripts with an External Debugger
    #
    # If you need to step through a `@[Tool]` script executing inside the editor itself (such as a custom inspector plugin,
    # dock UI, or tool script logic running in the editor viewport), attach an **external debugger** to the Godot Editor process.
    #
    # #### Option A: External Terminal LLDB
    # Launch the Godot Editor directly under LLDB in an independent terminal window:
    # ```bash
    # lldb -- godot.exe --editor --path test
    # (lldb) breakpoint set -f tool_tester_2d.cr -l 42
    # (lldb) run
    # ```
    # Or attach to an already-running editor instance by its Process ID:
    # ```bash
    # lldb -p <godot_editor_pid>
    # ```
    #
    # #### Option B: VS Code with CodeLLDB Extension
    # Add a launch target to `.vscode/launch.json` in your project root:
    # ```json
    # {
    #   "version": "0.2.0",
    #   "configurations": [
    #     {
    #       "name": "Debug Live Editor Tool Scripts",
    #       "type": "lldb",
    #       "request": "launch",
    #       "program": "${workspaceFolder}/godot.exe",
    #       "args": ["--editor", "--path", "${workspaceFolder}/test"],
    #       "cwd": "${workspaceFolder}"
    #     },
    #     {
    #       "name": "Attach to Godot Editor (PID)",
    #       "type": "lldb",
    #       "request": "attach",
    #       "pid": "${command:pickProcess}"
    #     }
    #   ]
    # }
    # ```
    # In this workflow, the external VS Code or terminal window maintains control while the Godot Editor window is safely paused.
    #
    # ---
    #
    # ### 7. Interactive LLDB Console Commands Reference
    #
    # Inside the in-editor **Crystal LLDB** tab console, you can enter native LLDB commands directly:
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Command</th>
    #       <th style="padding: 10px 14px;">Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>thread backtrace</code> (or <code>bt</code>)</td>
    #       <td style="padding: 10px 14px;">Prints the entire call stack for the current thread.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>frame variable</code> (or <code>v</code>)</td>
    #       <td style="padding: 10px 14px;">Displays all local variables in the current stack frame.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>expression &lt;expr&gt;</code> (or <code>p</code>)</td>
    #       <td style="padding: 10px 14px;">Evaluates an arbitrary expression or inspects memory.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>breakpoint list</code></td>
    #       <td style="padding: 10px 14px;">Lists all active breakpoints and hit counts.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>process status</code></td>
    #       <td style="padding: 10px 14px;">Shows the current execution state, stop reason, and thread ID.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    module M_LLDB_NATIVE_DEBUGGING_GUIDE
      def self.features : Array(String)
        [
          "First-class LLDB native debugger integration via EditorDebuggerPlugin",
          "Direct PDB symbol parsing on Windows and DWARF on Linux/macOS",
          "Gutter breakpoint synchronization from Godot Script Editor",
          "Interactive LLDB command console inside Godot Debugger dock",
          "Multiplayer multi-session tabs with Server/Client role identification",
          "Multiplayer Lockstep Break mode to prevent network heartbeat timeouts",
        ]
      end
    end
  end
end

