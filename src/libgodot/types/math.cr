module Math
  # Moves `from` toward `to` by the given `delta` amount, never exceeding `to`.
  def self.move_toward(from : Float32, to : Float32, delta : Float32) : Float32
    if (to - from).abs <= delta
      to
    else
      from + (to - from).sign * delta
    end
  end

  # Moves `from` toward `to` by the given `delta` amount with 64-bit precision, never exceeding `to`.
  def self.move_toward(from : Float64, to : Float64, delta : Float64) : Float64
    if (to - from).abs <= delta
      to
    else
      from + (to - from).sign * delta
    end
  end

  # Linearly interpolates between from and to by weight.
  def self.lerp(from : Float32, to : Float32, weight : Float32) : Float32
    from + (to - from) * weight
  end

  def self.lerp(from : Float64, to : Float64, weight : Float64) : Float64
    from + (to - from) * weight
  end

  # Clamps a value between min and max.
  def self.clamp(val : Float32, min_val : Float32, max_val : Float32) : Float32
    val.clamp(min_val, max_val)
  end

  def self.clamp(val : Float64, min_val : Float64, max_val : Float64) : Float64
    val.clamp(min_val, max_val)
  end

  # Converts degrees to radians.
  def self.deg_to_rad(deg : Number) : Float64
    deg.to_f64 * (System::Math::PI / 180.0)
  end

  # Converts radians to degrees.
  def self.rad_to_deg(rad : Number) : Float64
    rad.to_f64 * (180.0 / System::Math::PI)
  end

  # Wraps a floating point number between min and max.
  def self.wrapf(value : Float64, min_val : Float64, max_val : Float64) : Float64
    range = max_val - min_val
    return min_val if range == 0.0
    value - (range * ((value - min_val) / range).floor)
  end

  # Snaps a floating point value to the nearest multiple of step.
  def self.snapped(val : Float64, step : Float64) : Float64
    return val if step == 0.0
    (val / step + 0.5).floor * step
  end

  # Returns true if two floating point values are approximately equal within tolerance.
  def self.is_equal_approx(a : Float64, b : Float64, tolerance : Float64 = 0.00001) : Bool
    (a - b).abs <= tolerance
  end

  # Returns true if a floating point value is approximately zero within tolerance.
  def self.is_zero_approx(a : Float64, tolerance : Float64 = 0.00001) : Bool
    a.abs <= tolerance
  end
end

# Top-level math constructors
def vec2(x : Number, y : Number) : Godot::Vector2
  Godot::Vector2.new(x.to_f32, y.to_f32)
end

def vec3(x : Number, y : Number, z : Number) : Godot::Vector3
  Godot::Vector3.new(x.to_f32, y.to_f32, z.to_f32)
end

def vec4(x : Number, y : Number, z : Number, w : Number) : Godot::Vector4
  Godot::Vector4.new(x.to_f32, y.to_f32, z.to_f32, w.to_f32)
end
