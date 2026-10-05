# tools/update_skill_tocs.cr
# Automated Table of Contents generator and line-number synchronizer for all Antigravity skills.

require "option_parser"

class SectionInfo
  property title : String
  property slug : String
  property description : String
  property original_line : Int32
  property final_start_line : Int32 = 0
  property final_end_line : Int32 = 0

  def initialize(@title : String, @slug : String, @description : String, @original_line : Int32)
  end
end

class SkillTocManager
  SKILLS_DIR = File.expand_path("../../.agents/skills", __FILE__)

  def initialize(@check_only : Bool = false)
    @stale_files = [] of String
  end

  def run : Int32
    normalized_dir = SKILLS_DIR.gsub('\\', '/')
    skill_files = Dir.glob("#{normalized_dir}/*/SKILL.md").sort
    puts "Found #{skill_files.size} skills in #{SKILLS_DIR}"

    skill_files.each do |file_path|
      process_skill(file_path)
    end

    if @check_only
      if @stale_files.empty?
        puts "All #{skill_files.size} skill Table of Contents are up-to-date with exact line numbers!"
        return 0
      else
        puts "ERROR: The following #{@stale_files.size} skills have out-of-date Table of Contents:"
        @stale_files.each { |f| puts "  - #{f}" }
        puts "Run 'crystal run tools/update_skill_tocs.cr' to synchronize line numbers."
        return 1
      end
    end

    puts "Successfully updated Table of Contents across all #{skill_files.size} skills."
    0
  end

  private def process_skill(file_path : String) : Void
    raw_content = File.read(file_path)
    lines = raw_content.split('\n')

    # Step 1: Strip existing ## Table of Contents block if present
    stripped_lines, insert_idx = strip_existing_toc(lines)

    # Step 2: Extract sections and their original line numbers in stripped content
    sections = extract_sections(stripped_lines, insert_idx)
    return if sections.empty?

    # Step 3: Compute exact ToC line size and offset
    # We do a two-pass calculation so the line numbers rendered in the table
    # match the exact line numbers in the final generated file.
    final_lines = assemble_with_exact_toc(stripped_lines, insert_idx, sections)
    new_content = final_lines.join('\n')

    if new_content.strip == raw_content.strip
      # Already matches
      return
    end

    if @check_only
      @stale_files << file_path
    else
      File.write(file_path, new_content)
      puts "✓ Updated ToC: #{File.basename(File.dirname(file_path))}/SKILL.md (#{sections.size} sections)"
    end
  end

  private def strip_existing_toc(lines : Array(String)) : Tuple(Array(String), Int32)
    stripped = [] of String
    in_toc = false
    insert_idx = -1
    found_h1 = false

    lines.each_with_index do |line, idx|
      trimmed = line.strip
      if trimmed.starts_with?("# ") && !found_h1
        found_h1 = true
      end

      if trimmed.starts_with?("## Table of Contents") || (trimmed.starts_with?("## ") && trimmed.includes?("Table of Contents"))
        in_toc = true
        insert_idx = stripped.size if insert_idx == -1
        next
      end

      if in_toc
        # The ToC ends when we hit the next heading (starting with ## but not Table of Contents)
        if trimmed.starts_with?("## ")
          in_toc = false
          stripped << line
        end
        next
      end

      # Determine insertion point after H1 title and introduction paragraphs if not found yet
      if insert_idx == -1 && found_h1 && trimmed.starts_with?("## ")
        insert_idx = stripped.size
      end

      stripped << line
    end

    insert_idx = stripped.size if insert_idx == -1
    {stripped, insert_idx}
  end

  private def extract_sections(lines : Array(String), insert_idx : Int32) : Array(SectionInfo)
    sections = [] of SectionInfo

    lines.each_with_index do |line, idx|
      # Only process sections after the insertion index
      next if idx < insert_idx
      trimmed = line.strip

      if trimmed.starts_with?("## ")
        title = trimmed[3..].strip
        slug = generate_slug(title)

        # Extract first non-empty paragraph after heading
        desc = ""
        ((idx + 1)...lines.size).each do |next_idx|
          next_line = lines[next_idx].strip
          break if next_line.starts_with?("## ")
          if !next_line.empty? && !next_line.starts_with?("```") && !next_line.starts_with?(">") && !next_line.starts_with?("---")
            # Clean markdown formatting from description
            desc = clean_description(next_line)
            break
          end
        end

        desc = "Overview and core guidelines for #{title}." if desc.empty?
        sections << SectionInfo.new(title, slug, desc, idx + 1)
      end
    end

    sections
  end

  private def generate_slug(title : String) : String
    title.downcase
      .gsub(/[^a-z0-9\s-]/, "")
      .gsub(/\s+/, "-")
      .strip('-')
  end

  private def clean_description(text : String) : String
    # Remove markdown links [text](url) -> text
    cleaned = text.gsub(/\[([^\]]+)\]\([^\)]+\)/, "\\1")
    # Remove backticks and bolding
    cleaned = cleaned.gsub(/[`*]/, "")
    # Truncate to first sentence or max 110 characters
    if dot_idx = cleaned.index(". ")
      cleaned = cleaned[0..dot_idx].strip
    elsif cleaned.size > 110
      cleaned = cleaned[0...107].strip + "..."
    end
    cleaned
  end

  private def assemble_with_exact_toc(stripped : Array(String), insert_idx : Int32, sections : Array(SectionInfo)) : Array(String)
    # Estimate ToC lines: 11 header/footer lines + (sections.size * 6) table row lines + blank lines
    # To be mathematically exact, we synthesize the table with placeholder lines, measure exact size,
    # then compute real line offsets and re-render.
    
    dummy_table = render_toc_table(sections)
    toc_lines_count = dummy_table.size

    # Calculate actual final line numbers for each section
    sections.each_with_index do |sec, idx|
      # In the final file, the section starts at original stripped index + toc_lines_count + 1 (1-indexed)
      final_start = sec.original_line + toc_lines_count
      sec.final_start_line = final_start

      # End line is the line before the next section, or EOF
      if idx + 1 < sections.size
        next_sec_start = sections[idx + 1].original_line + toc_lines_count
        sec.final_end_line = next_sec_start - 1
      else
        sec.final_end_line = stripped.size + toc_lines_count
      end
    end

    # Render real ToC table with calculated line numbers
    real_toc = render_toc_table(sections)

    # Re-verify line count equality (should be identical since formatting is fixed)
    if real_toc.size != toc_lines_count
      # Adjust if line count varied
      toc_lines_count = real_toc.size
      sections.each_with_index do |sec, idx|
        sec.final_start_line = sec.original_line + toc_lines_count
        if idx + 1 < sections.size
          sec.final_end_line = sections[idx + 1].original_line + toc_lines_count - 1
        else
          sec.final_end_line = stripped.size + toc_lines_count
        end
      end
      real_toc = render_toc_table(sections)
    end

    # Assemble final document
    final = [] of String
    final.concat(stripped[0...insert_idx])
    final.concat(real_toc)
    final.concat(stripped[insert_idx..])
    final
  end

  private def render_toc_table(sections : Array(SectionInfo)) : Array(String)
    toc = [] of String
    toc << "## Table of Contents"
    toc << "<table>"
    toc << "  <thead>"
    toc << "    <tr>"
    toc << "      <th align=\"left\">Section</th>"
    toc << "      <th align=\"left\">Description</th>"
    toc << "      <th align=\"center\">Lines</th>"
    toc << "    </tr>"
    toc << "  </thead>"
    toc << "  <tbody>"

    sections.each do |sec|
      lines_display = sec.final_start_line > 0 ? "<code>L#{sec.final_start_line}–L#{sec.final_end_line}</code>" : "<code>L0-L0</code>"
      toc << "    <tr>"
      toc << "      <td><a href=\"##{sec.slug}\"><strong>#{sec.title}</strong></a></td>"
      toc << "      <td>#{sec.description}</td>"
      toc << "      <td align=\"center\">#{lines_display}</td>"
      toc << "    </tr>"
    end

    toc << "  </tbody>"
    toc << "</table>"
    toc << ""
    toc << "---"
    toc << ""
    toc
  end
end

check_mode = false
OptionParser.parse do |parser|
  parser.banner = "Usage: crystal run tools/update_skill_tocs.cr [options]"
  parser.on("--check", "Verify skills ToC line numbers without writing files") { check_mode = true }
  parser.on("-h", "--help", "Show help") do
    puts parser
    exit 0
  end
end

manager = SkillTocManager.new(check_only: check_mode)
exit manager.run
