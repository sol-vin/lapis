# ConfigFile Benchmark in Crystal
# Parsing, querying and encoding 1,000 section INI config

require "../../src/lapis"

sections = (ARGV[0]? || "1000").to_i

ini_io = String::Builder.new
sections.times do |s|
  ini_io << "[entity_section_" << s << "]\n"
  ini_io << "name = \"Entity_" << s << "\"\n"
  ini_io << "health = " << (100 + s % 500) << "\n"
  ini_io << "speed = " << (5.5_f32 + (s % 10).to_f32 * 0.5_f32) << "\n"
  ini_io << "active = true\n\n"
end
raw_ini = ini_io.to_s

start_time = Time.instant

cf = Godot::ConfigFile.new
err = cf.parse(raw_ini)

hits = 0_i64
sections.times do |s|
  if cf.has_section_key?("entity_section_#{s}", "health")
    hits += 1_i64
  end
end

encoded = cf.encode_to_text

elapsed = (Time.instant - start_time).total_milliseconds
puts "ConfigFileOps #{sections} sections: #{elapsed.round(2)} ms (hits=#{hits}, len=#{encoded.size})"
puts "ELAPSED_MS: #{elapsed.round(2)}"
