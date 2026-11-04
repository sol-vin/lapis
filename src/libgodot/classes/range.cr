module Godot
  class Range < Control
    @min_value : Float64 = 0.0
    @max_value : Float64 = 100.0
    @step : Float64 = 1.0
    @page : Float64 = 0.0
    @value : Float64 = 0.0

    def initialize(min : Number = 0.0, max : Number = 100.0, @step : Float64 = 1.0)
      super()
      @min_value = min.to_f64
      @max_value = max.to_f64
    end

    def min_value : Float64
      @pointer.null? ? @min_value : get_min
    end

    def min_value=(val : Number)
      @min_value = val.to_f64
      set_min(@min_value) unless @pointer.null?
    end

    def max_value : Float64
      @pointer.null? ? @max_value : get_max
    end

    def max_value=(val : Number)
      @max_value = val.to_f64
      set_max(@max_value) unless @pointer.null?
    end

    def step : Float64
      @pointer.null? ? @step : get_step
    end

    def step=(val : Number)
      @step = val.to_f64
      set_step(@step) unless @pointer.null?
    end

    def page : Float64
      @pointer.null? ? @page : get_page
    end

    def page=(val : Number)
      @page = val.to_f64
      set_page(@page) unless @pointer.null?
    end

    def value : Float64
      @pointer.null? ? @value : get_value
    end

    def value=(val : Number)
      @value = val.to_f64
      if !@pointer.null?
        set_value(@value)
      end
    end

    def set_value(val : Number) : Void
      self.value = val
    end

    # Type cohesion: Initialize from a Crystal Range
    def self.new(crystal_range : ::Range(Number, Number), step : Number = 1.0)
      new(crystal_range.begin, crystal_range.end, step.to_f64)
    end

    # Type cohesion: Set bounds using a Crystal Range (e.g. control.range = 0..100)
    def range=(crystal_range : ::Range(Number, Number))
      self.min_value = crystal_range.begin.to_f64
      self.max_value = crystal_range.end.to_f64
    end

    # Type cohesion: Read bounds as a Crystal Range
    def to_range : ::Range(Float64, Float64)
      min_value..max_value
    end

    # Type cohesion: Check if a value falls within the Range bounds
    def includes?(val : Number) : Bool
      to_range.includes?(val.to_f64)
    end

    def in_range?(val : Number) : Bool
      includes?(val)
    end

    def ratio : Float64
      return get_as_ratio unless @pointer.null?
      span = @max_value - @min_value
      span > 0 ? (@value - @min_value) / span : 0.0
    end
  end

  # Visual progress bar control displaying completion ratio.
end

# Crystal Standard Library Extension: Type cohesion for Crystal Range <-> Godot
struct Range(B, E)
  # Converts Crystal range into a Godot::Range control node
  def to_godot_range(step : Number = 1.0) : Godot::Range
    Godot::Range.new(self, step)
  end

  # Converts Crystal range to a Godot PROPERTY_HINT_RANGE hint string (e.g. "0,100" or "0,100,0.5")
  def to_godot_hint_string(step : Number? = nil) : String
    if s = step
      "#{self.begin},#{self.end},#{s}"
    else
      "#{self.begin},#{self.end}"
    end
  end

  # Converts to float tuple for engine interop
  def to_godot_bounds : Tuple(Float64, Float64)
    {self.begin.to_f64, self.end.to_f64}
  end
end
