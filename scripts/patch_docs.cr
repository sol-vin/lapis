# Documentation Patcher: fixes sidebar tree max-height cutoff in Crystal docs
docs_dir = ARGV[0]? || "docs"
css_file = File.join(docs_dir, "css", "style.css")

if File.exists?(css_file)
  css = File.read(css_file)
  css = css.gsub("max-height: 1000em;", "max-height: 3000em;")
  css = css.gsub("max-height: none;", "max-height: 3000em;")
  File.write(css_file, css)
  puts "[Docs:Patch] Successfully patched #{css_file} with max-height: 3000em"
else
  puts "[Docs:Patch] Warning: #{css_file} not found"
end
