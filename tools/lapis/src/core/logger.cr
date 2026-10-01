module Lapis
  module Core
    module Logger
      class_property? quiet : Bool = false
      @@verbose : Bool = (ENV["LIBGODOT_VERBOSE"]? == "1" || ENV["GODOT_VERBOSE"]? == "1")

      def self.verbose? : Bool
        @@verbose
      end

      def self.verbose=(v : Bool)
        @@verbose = v
        if v
          ENV["LIBGODOT_VERBOSE"] = "1"
          ENV["GODOT_VERBOSE"] = "1"
        end
      end

      def self.info(msg : String)
        return if @@quiet
        puts "\e[34m[Lapis]\e[0m #{msg}"
      end

      def self.success(msg : String)
        return if @@quiet
        puts "\e[32m[Lapis]\e[0m #{msg}"
      end

      def self.warn(msg : String)
        puts "\e[33m[Lapis:WARN]\e[0m #{msg}"
      end

      def self.error(msg : String)
        STDERR.puts "\e[31m[Lapis:ERROR]\e[0m #{msg}"
      end

      def self.step(tag : String, msg : String)
        return if @@quiet
        puts "\e[36m[#{tag}]\e[0m #{msg}"
      end

      def self.debug(msg : String)
        return unless @@verbose
        puts "\e[90m[debug]\e[0m #{msg}"
      end

      def self.trace(tag : String, msg : String)
        return unless @@verbose
        puts "\e[90m[#{tag}:trace]\e[0m #{msg}"
      end
    end
  end
end
