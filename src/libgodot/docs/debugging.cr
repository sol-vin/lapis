module Lapis
  module Docs
    # # M. Native LLDB In-Editor Debugging, Tool Scripts & Multiplayer Sessions
    #
    # LibGodot integrates **LLDB** directly into the Godot Editor's native Debugger dock,
    # enabling in-editor gutter breakpoints, interactive command consoles, stack traces,
    # multiplayer multi-session coordination, and guidance for debugging live tool scripts.
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
    #       <td>Core capabilities of the in-editor LLDB debugger plugin.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Tooling Prerequisites</strong></td>
    #       <td><code>.topic_01_tooling_prerequisites</code></td>
    #       <td>Installing LLDB on Windows (Scoop/WinGet), Ubuntu, Arch, and macOS.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Symbols & PDB Files</strong></td>
    #       <td><code>.topic_02_debug_symbols_and_pdb</code></td>
    #       <td>Emitting full debug symbols (game.pdb / DWARF) during development builds.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>In-Editor Breakpoints</strong></td>
    #       <td><code>.topic_03_in_editor_breakpoints</code></td>
    #       <td>Setting gutter breakpoints in Godot Script Editor and automatic line sync.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>LLDB Console Commands</strong></td>
    #       <td><code>.topic_04_lldb_console_commands</code></td>
    #       <td>Interactive LLDB command console docked inside Godot for bt, frame, and watchpoints.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Tool Script Debugging</strong></td>
    #       <td><code>.topic_05_tool_script_debugging</code></td>
    #       <td>Attaching LLDB to the Godot Editor host process to debug @tool classes.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Multiplayer Sessions</strong></td>
    #       <td><code>.topic_06_multiplayer_lockstep_sessions</code></td>
    #       <td>Coordinating multi-instance debugging across host and client processes.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/debugger/lldb_driver.cr`, `addons/crystal_integration/lldb_dock.gd`
    # - **Live Specifications**: `spec/suites/test_debugger_isolation.cr`
    # - **Related Guides**: `Docs::S_IDE_INTEGRATION_AND_DEVELOPER_EXPERIENCE`, `Docs::H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY`
    module M_LLDB_NATIVE_DEBUGGING_GUIDE
      # **Key Features**: Returns core capabilities of the in-editor LLDB debugger plugin.
      def self.topic_00_key_features : Array(String)
        [
          "Native LLDB debugger integration docked directly in the Godot Editor",
          "Seamless breakpoint synchronization between Godot Script Editor and LLDB engine",
          "Interactive LLDB CLI console inside Godot for live variable and stack inspection",
          "Hardware watchpoint diagnostics for memory corruption and dead-pointer tracking",
        ]
      end

      # **Tooling Prerequisites**: Installing LLDB across Windows, Ubuntu, and macOS.
      #
      # Because Crystal's compiler is built directly on **LLVM**, LLDB natively parses
      # Microsoft `.pdb` files on Windows and DWARF debug info on Linux/macOS:
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Platform</th>
      #       <th>Package Manager</th>
      #       <th>Installation Command</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>Windows</strong></td>
      #       <td>Scoop / WinGet</td>
      #       <td><code>scoop install llvm</code> or <code>winget install LLVM.LLVM</code></td>
      #     </tr>
      #     <tr>
      #       <td><strong>Ubuntu / Debian</strong></td>
      #       <td>APT</td>
      #       <td><code>sudo apt install lldb</code></td>
      #     </tr>
      #     <tr>
      #       <td><strong>macOS</strong></td>
      #       <td>Homebrew / Xcode</td>
      #       <td><code>brew install llvm</code></td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # Verify installation:
      # ```bash
      # lldb --version
      # ```
      def self.topic_01_tooling_prerequisites : Nil
      end

      # **Debug Symbols & PDB Files**: Emitting full debug symbols during development builds.
      #
      # In development mode (`make all` or F5 in editor), Crystal emits full debug symbols (`--debug`):
      # - **Windows**: Produces `bin/game.pdb`. LLDB maps machine instructions directly to Crystal files.
      # - **Linux / macOS**: Produces standard DWARF debug info embedded within `game.so` or `game.dylib`.
      def self.topic_02_debug_symbols_and_pdb : Nil
      end

      # **In-Editor Breakpoints**: Setting gutter breakpoints in Godot Script Editor and automatic line synchronization.
      #
      # 1. Open any Crystal source file (`src/player.cr`) in Godot's Script Editor.
      # 2. Click the gutter next to any line number to set a red breakpoint marker.
      # 3. Godot's editor debugger plugin intercepts the event, maps `res://` to filesystem paths,
      #    and executes `breakpoint set --file <file> --line <line>` in LLDB.
      # 4. When execution hits the breakpoint, Godot highlights the frame in the Script Editor.
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Control</th>
      #       <th>Shortcut</th>
      #       <th>Action</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>Continue</strong></td>
      #       <td><code>F5</code></td>
      #       <td>Resumes execution until next breakpoint or exception.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Step Over</strong></td>
      #       <td><code>F10</code></td>
      #       <td>Executes current line without entering function calls.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Step Into</strong></td>
      #       <td><code>F11</code></td>
      #       <td>Steps into function call on current line.</td>
      #     </tr>
      #   </tbody>
      # </table>
      def self.topic_03_in_editor_breakpoints : Nil
      end

      # **LLDB Console Commands**: Interactive LLDB command console docked inside Godot for backtraces and watchpoints.
      #
      # The LLDB console docked inside Godot accepts standard LLDB commands:
      # - `bt`: Prints full backtrace across all threads.
      # - `frame variable`: Prints local variables in the current execution frame.
      # - `watchpoint set expression -s 8 -- (void**)&var`: Breaks immediately when a memory address changes.
      #
      # ```text
      # (lldb) bt
      # * thread #1, stop reason = breakpoint 1.1
      #   * frame #0: game.dll!Player#_process(delta=0.0166) at src/player.cr:42
      #     frame #1: crystal_bridge.dll!generic_dispatch_virtual(...) at extension_instance.hpp:85
      # ```
      def self.topic_04_lldb_console_commands : Nil
      end

      # **Tool Script Debugging**: Attaching LLDB to the Godot Editor host process to debug live tool classes.
      #
      # To debug scripts running live inside the Godot Editor, attach LLDB to the parent editor process:
      # ```bash
      # make debug-editor
      # ```
      # Or via Lapis CLI:
      # ```bash
      # lapis editor --lldb
      # ```
      def self.topic_05_tool_script_debugging : Nil
      end

      # **Multiplayer Sessions**: Coordinating multi-instance debugging across host and client processes.
      #
      # When testing multiplayer networking across multiple game windows:
      # 1. Launch instance 1 (Server): `lapis run -p . -- --server`
      # 2. Launch instance 2 (Client): `lapis run -p . -- --client`
      # 3. Attach independent LLDB sessions to each process ID to inspect packet round-trips.
      def self.topic_06_multiplayer_lockstep_sessions : Nil
      end
    end
  end
end
