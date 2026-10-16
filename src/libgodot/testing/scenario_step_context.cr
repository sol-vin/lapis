module Lapis
  module Test
    class ScenarioStepContext
      getter name : String
      getter current_step : String = ""

      def initialize(@name : String)
      end

      # Executes an individual named step within the scenario with automatic failure context
      def step(step_name : String, &block : -> Void) : Void
        @current_step = step_name
        begin
          block.call
        rescue ex : AssertionError
          raise AssertionError.new("Scenario '#{@name}' failed at step '#{step_name}': #{ex.message}", ex.file, ex.line)
        end
      end
    end
  end
end
