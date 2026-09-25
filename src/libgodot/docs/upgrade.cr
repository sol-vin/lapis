module Lapis
  module Docs
    # # N. Godot Engine Upgrade Guide
    #
    # LibGodot supports rapid updating to newer Godot Engine dev and stable releases.
    #
    # ---
    #
    # ### Upgrade Steps
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Step</th>
    #       <th style="padding: 10px 14px;">Command / Action</th>
    #       <th style="padding: 10px 14px;">Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>1. Execute Setup</strong></td>
    #       <td style="padding: 10px 14px;"><code>lapis setup -v &lt;ver&gt;</code></td>
    #       <td style="padding: 10px 14px;">Downloads binary, replaces <code>godot.exe</code>, dumps <code>extension_api.json</code> and <code>gdextension_interface.h</code>.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>2. Rebuild All</strong></td>
    #       <td style="padding: 10px 14px;"><code>make all</code></td>
    #       <td style="padding: 10px 14px;">Recompiles GDExtension bridge, test suite, templates, examples, and synchronizes all binaries.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>3. Verify Tests</strong></td>
    #       <td style="padding: 10px 14px;"><code>lapis test</code></td>
    #       <td style="padding: 10px 14px;">Runs headless unit specs, in-editor tool tests, and quantitative memory leak verification.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    module N_GODOT_UPGRADE_GUIDE
      def self.features : Array(String)
        [
          "Automated setup tool via lapis setup",
          "Single-source version tracking via godot-version.yml",
          "Automatic GDExtension API and interface header dumping into rsrc/",
          "Workspace-wide synchronization and verification via make all",
        ]
      end
    end
  end
end

