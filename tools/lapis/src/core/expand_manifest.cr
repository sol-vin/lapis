require "path"

# Compile-time manifest expansion helper for BakedFileSystem.
# Expands glob patterns (e.g. src/**/*.cr, template/**/*) while strictly
# enforcing zero binary bloat and deterministic sorting.

if ARGV.size < 2
  STDERR.puts "Usage: expand_manifest <manifest_path> <repo_root>"
  exit 1
end

manifest_path = ARGV[0]
repo_root = Path.new(ARGV[1]).expand.to_s.gsub('\\', '/')

unless File.exists?(manifest_path)
  STDERR.puts "Manifest file not found: #{manifest_path}"
  exit 1
end

FORBIDDEN_EXTENSIONS = Set{
  ".dll", ".so", ".dylib", ".lib", ".a", ".zip",
  ".uid", ".log", ".import", ".pdb", ".exp", ".o",
  ".obj", ".tmp", ".bak", ".exe", ".pck", ".tar.gz",
}

FORBIDDEN_PATTERNS = [
  "/.godot/", "/lib/", "/bin/", "/dist/", "/.git/",
  ".godot/", "lib/", "bin/", "dist/", ".git/",
  "shard.lock", "test_report.", "/src/generated/", "src/generated/",
  "template/addons/crystal_integration",
  "template-addon/addons/crystal_integration",
]

def self.forbidden?(rel_path : String) : Bool
  norm = rel_path.gsub('\\', '/')
  ext = Path.new(norm).extension.downcase
  return true if FORBIDDEN_EXTENSIONS.includes?(ext)

  FORBIDDEN_PATTERNS.each do |pat|
    return true if norm.starts_with?(pat) || norm.includes?("/#{pat}") || norm.includes?(pat)
  end

  false
end

files = Set(String).new

File.each_line(manifest_path) do |line|
  trimmed = line.strip
  next unless trimmed.starts_with?("- ")

  pattern = trimmed.lchop("- ").strip.gsub('\\', '/')
  next if pattern.empty?

  if pattern.includes?('*') || pattern.includes?('?')
    patterns_to_glob = [File.join(repo_root, pattern).gsub('\\', '/')]
    if pattern.ends_with?("**/*")
      patterns_to_glob << File.join(repo_root, pattern.sub(/\*\*\/\*$/, "**/.*")).gsub('\\', '/')
    end

    patterns_to_glob.each do |gpat|
      Dir.glob(gpat).each do |match|
        next unless File.file?(match)

        rel = Path.new(match).relative_to(Path.new(repo_root)).to_s.gsub('\\', '/')
        rel = rel.lchop("./")

        next if forbidden?(rel)
        files << rel
      end
    end
  else
    full_path = File.join(repo_root, pattern).gsub('\\', '/')
    if File.file?(full_path)
      clean_rel = pattern.lchop("./")
      next if forbidden?(clean_rel)
      files << clean_rel
    end
  end
end

# Output deterministic, sorted list of file entries
files.to_a.sort.each do |f|
  puts "- #{f}"
end
