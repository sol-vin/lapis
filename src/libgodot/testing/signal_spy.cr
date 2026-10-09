module Lapis
  module Test
    class SignalSpy
      getter emissions = Array(Array(String)).new
      getter emitter : Godot::Object
      getter signal_name : String
      @subscription : Godot::SignalSubscription? = nil

      def initialize(@emitter : Godot::Object, @signal_name : String)
        @subscription = @emitter.connect(@signal_name) do |args|
          record(args)
        end
      end

      def record(args : Enumerable)
        @emissions << args.map(&.to_s).to_a
      end

      def record(*args)
        @emissions << args.map(&.to_s).to_a
      end

      def count : Int32
        @emissions.size
      end

      def emitted? : Bool
        !@emissions.empty?
      end

      def first_args : Array(String)?
        @emissions.first?
      end

      def last_args : Array(String)?
        @emissions.last?
      end

      def clear : Void
        @emissions.clear
      end

      def disconnect : Void
        if sub = @subscription
          sub.unsubscribe
          @subscription = nil
        end
      end
    end
  end
end
