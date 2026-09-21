module Lapis
  VERSION = {{
    read_file("#{__DIR__}/../../../shard.yml")
      .split("\n")
      .find(&.strip.starts_with?("version:"))
      .split(":")[1]
      .gsub(/["'\r\n]/, "")
      .strip
  }}
end
