# tools/lapis/src/commands/template.cr
require "option_parser"
require "../core/env"
require "../core/logger"
require "../core/template_store"
require "../tui/template_manager"
require "opal"

module Lapis
  module Commands
    module Template
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Modular Template Manager ===\e[0m

Usage:
  lapis template <subcommand> [options]
  lapis new template [name] [options]

Subcommands:
  list, ls                 List all installed templates in the global store
  save, create [name]      Package current project directory into the global template store
  info <name>              Show detailed metadata, tags, and file list for a template
  remove, rm <name>        Remove a template from the global store
  clean, purge             Clean out stored templates (with interactive or forced confirmation)
  export <name> -o <zip>   Export template to a zip archive
  import <zip>             Import a template archive into the global store
  manager, tui             Launch full-screen interactive Template Manager TUI

Options:
  -d, --desc=TEXT          Description for the template (save)
  -a, --author=NAME        Author name (save)
  -t, --tags=TAGS          Comma-separated tags (save)
  -o, --output=PATH        Output file for export
  -f, --force              Force action without confirmation (clean/remove)
  --all                    Target all templates (clean)
  -h, --help               Show this help screen

Examples:
  lapis new template pixel_rpg --desc "2D top-down RPG starter"
  lapis template save 3d_fps --tags "3d,fps,retro"
  lapis template list
  lapis template info pixel_rpg
  lapis template export pixel_rpg -o my_rpg.zip
  lapis template import my_rpg.zip
  lapis template remove pixel_rpg
  lapis template clean --all --force
  lapis template manager
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        subcommand = args.first.downcase
        sub_args = args[1..-1]

        case subcommand
        when "list", "ls"
          list_templates
        when "save", "create"
          save_template(sub_args)
        when "info", "show"
          show_template_info(sub_args)
        when "remove", "rm", "delete"
          remove_template(sub_args)
        when "clean", "purge"
          clean_templates(sub_args)
        when "export"
          export_template(sub_args)
        when "import"
          import_template(sub_args)
        when "manager", "tui", "ui"
          TUI::TemplateManager.run
          0
        else
          # If first arg looks like a template name or option, treat as save
          if !subcommand.starts_with?("-")
            save_template([subcommand] + sub_args)
          else
            print_help
            1
          end
        end
      end

      private def self.format_bytes(bytes : UInt64) : String
        if bytes >= 1024_u64 * 1024_u64
          sprintf("%.2f MB", bytes.to_f / (1024.0 * 1024.0))
        elsif bytes >= 1024_u64
          sprintf("%.1f KB", bytes.to_f / 1024.0)
        else
          "#{bytes} B"
        end
      end

      def self.list_templates : Int32
        templates = Core::TemplateStore.list_templates
        store_path = Core::TemplateStore.store_dir

        puts Opal.style.bold.fg(:cyan).render("\n=== Global Template Store ===")
        puts "\e[38;5;244mStore location: #{store_path}\e[0m\n"

        if templates.empty?
          puts "  \e[33mNo custom templates stored yet.\e[0m"
          puts "  Create one from your current project by running:"
          puts "    \e[1;97mlapis new template <name> --desc \"...\"\e[0m\n"
          return 0
        end

        cols = [Opal::Terminal.default_driver.size[0] - 2, 85].max
        tbl = Opal::UI::Table.new(
          headers: ["Template Name", "Version", "Files", "Uncompressed", "Description"],
          header_fg: :cyan
        )

        templates.each do |tpl|
          size_str = format_bytes(tpl.uncompressed_bytes)
          tbl.row([
            tpl.name,
            tpl.version,
            "#{tpl.file_count} files",
            size_str,
            tpl.description
          ])
        end

        puts tbl.to_print_s(width: cols)
        puts "\nTotal: #{templates.size} template(s) available for 'lapis new game <name> --template <template_name>'\n"
        0
      end

      def self.save_template(args : Array(String)) : Int32
        name : String? = nil
        desc : String? = nil
        author : String? = nil
        tags_str : String? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis template save [name] [options]"
          opts.on("-d DESC", "--desc=DESC", "Description of template") { |d| desc = d }
          opts.on("-a AUTHOR", "--author=AUTHOR", "Template author") { |a| author = a }
          opts.on("-t TAGS", "--tags=TAGS", "Comma-separated tags") { |t| tags_str = t }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
          opts.unknown_args do |before, after|
            remaining = before + after
            name = remaining[0]?
          end
        end
        parser.parse(args)

        cwd = Path.new(Dir.current)
        tpl_name = if n = name
                     n.strip.downcase.gsub(/[^a-z0-9_-]/, "_")
                   else
                     cwd.basename.strip.downcase.gsub(/[^a-z0-9_-]/, "_")
                   end

        Core::Logger.step("Template", "Packaging '#{cwd}' as global template '#{tpl_name}'...")
        tags = tags_str ? tags_str.not_nil!.split(",").map(&.strip) : nil

        manifest = Core::TemplateStore.save_template(
          source_dir: cwd,
          name: tpl_name,
          description: desc,
          author: author,
          tags: tags
        )

        Core::Logger.success("Template '#{manifest.name}' saved to global store! (#{manifest.file_count} files, #{format_bytes(manifest.uncompressed_bytes)})")
        Core::Logger.info("You can now scaffold new projects using:")
        Core::Logger.info("  \e[1;97mlapis new game my_game --template #{manifest.name}\e[0m")
        0
      rescue ex
        Core::Logger.error("Failed to save template: #{ex.message}")
        1
      end

      def self.show_template_info(args : Array(String)) : Int32
        name = args.first?
        unless name
          Core::Logger.error("Specify template name: lapis template info <name>")
          return 1
        end

        tpl = Core::TemplateStore.get_template(name)
        unless tpl
          Core::Logger.error("Template '#{name}' not found in store.")
          return 1
        end

        puts Opal.style.bold.fg(:cyan).render("\n=== Template: #{tpl.display_name} (#{tpl.name}) ===")
        puts "  \e[1mVersion:\e[0m      #{tpl.version}"
        puts "  \e[1mAuthor:\e[0m       #{tpl.author}"
        puts "  \e[1mGodot:\e[0m        #{tpl.godot_version}"
        puts "  \e[1mCreated:\e[0m      #{tpl.created_at}"
        puts "  \e[1mDescription:\e[0m  #{tpl.description}"
        puts "  \e[1mTags:\e[0m         #{tpl.tags.join(", ")}"
        puts "  \e[1mFiles:\e[0m        #{tpl.file_count} (#{format_bytes(tpl.uncompressed_bytes)} uncompressed)"

        if !tpl.addons.empty?
          puts "  \e[1mAddons:\e[0m       #{tpl.addons.join(", ")}"
        end

        files = Core::TemplateStore.template_files(tpl.name)
        puts "\n\e[1;96mBundled File Manifest (first 25 files):\e[0m"
        files.first(25).each do |f|
          puts "  ├── #{f}"
        end
        puts "  └── ... (#{files.size - 25} more files)" if files.size > 25
        puts ""
        0
      end

      def self.remove_template(args : Array(String)) : Int32
        name = args.find { |a| !a.starts_with?("-") }
        force = args.includes?("-f") || args.includes?("--force")

        unless name
          Core::Logger.error("Specify template name to remove: lapis template remove <name>")
          return 1
        end

        tpl = Core::TemplateStore.get_template(name)
        unless tpl
          Core::Logger.error("Template '#{name}' does not exist in global store.")
          return 1
        end

        unless force
          print "Are you sure you want to delete template '#{name}'? [y/N]: "
          resp = STDIN.gets.try(&.strip.downcase) || "n"
          return 0 unless resp == "y" || resp == "yes"
        end

        if Core::TemplateStore.delete_template(name)
          Core::Logger.success("Template '#{name}' removed from store.")
          0
        else
          Core::Logger.error("Failed to remove template '#{name}'.")
          1
        end
      end

      def self.clean_templates(args : Array(String)) : Int32
        force = args.includes?("-f") || args.includes?("--force")
        all = args.includes?("--all")

        templates = Core::TemplateStore.list_templates
        if templates.empty?
          Core::Logger.info("Template store is already empty.")
          return 0
        end

        unless force
          puts "About to delete #{templates.size} template(s) from the global store."
          print "Proceed with purge? [y/N]: "
          resp = STDIN.gets.try(&.strip.downcase) || "n"
          return 0 unless resp == "y" || resp == "yes"
        end

        count = Core::TemplateStore.clean_templates
        Core::Logger.success("Cleaned #{count} template(s) from global store.")
        0
      end

      def self.export_template(args : Array(String)) : Int32
        name : String? = nil
        out_file : String? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis template export <name> -o <file.zip>"
          opts.on("-o PATH", "--output=PATH", "Output archive path") { |o| out_file = o }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
          opts.unknown_args do |before, after|
            name = (before + after).first?
          end
        end
        parser.parse(args)

        unless name
          Core::Logger.error("Specify template name to export: lapis template export <name> -o <file.zip>")
          return 1
        end

        target_name = name.not_nil!
        dest_zip = if of = out_file
                     Path.new(of)
                   else
                     Path.new("#{target_name}.zip")
                   end
        if Core::TemplateStore.export_template(target_name, dest_zip)
          Core::Logger.success("Template '#{target_name}' exported to #{dest_zip} (#{File.size(dest_zip)} bytes)")
          0
        else
          Core::Logger.error("Failed to export template '#{target_name}'.")
          1
        end
      end

      def self.import_template(args : Array(String)) : Int32
        zip_path = args.find { |a| !a.starts_with?("-") }
        unless zip_path && File.exists?(zip_path)
          Core::Logger.error("Specify valid template zip archive to import: lapis template import <file.zip>")
          return 1
        end

        Core::Logger.step("Template", "Importing template archive from #{zip_path}...")
        if manifest = Core::TemplateStore.import_template(Path.new(zip_path))
          Core::Logger.success("Imported template '#{manifest.name}' into global store! (#{manifest.file_count} files)")
          0
        else
          Core::Logger.error("Failed to import template from #{zip_path}.")
          1
        end
      end
    end
  end
end
