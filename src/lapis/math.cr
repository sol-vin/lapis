# =============================================================================
# Lapis - Optional Gameplay Math Helpers (require "lapis/math")
# =============================================================================

require "../libgodot"

struct Number
  # Smoothly approaches `target` by `step` without overshooting.
  #
  # ```
  # current = 5.0
  # current = current.approach(10.0, 2.0) # => 7.0
  # current = current.approach(10.0, 5.0) # => 10.0 (does not overshoot)
  # ```
  def approach(target : Number, step : Number) : Float64
    diff = target.to_f64 - self.to_f64
    if diff.abs <= step.to_f64.abs
      target.to_f64
    else
      self.to_f64 + diff.sign * step.to_f64.abs
    end
  end

  # Converts this number (interpreted as degrees) into radians.
  #
  # ```
  # rotation = 90.degrees # => ~1.5707963
  # ```
  def degrees : Float64
    self.to_f64 * (Math::PI / 180.0)
  end

  # Converts this number (interpreted as radians) into degrees.
  #
  # ```
  # deg = 1.5707963.to_degrees # => ~90.0
  # ```
  def to_degrees : Float64
    self.to_f64 * (180.0 / Math::PI)
  end

  # Converts this number (interpreted as degrees) into radians. Alias to `degrees`.
  def radians : Float64
    degrees
  end
end

struct Godot::Vector2
  # Generates a unit Vector2 pointing in a uniformly random direction (360 degrees).
  def self.random_dir : Vector2
    angle = Random.rand * 2.0 * Math::PI
    Vector2.new(Math.cos(angle).to_f32, Math.sin(angle).to_f32)
  end

  # Generates a random point inside a circle of the given radius with uniform areal distribution.
  def self.random_in_circle(radius : Number = 1.0) : Vector2
    r = Math.sqrt(Random.rand) * radius.to_f32
    angle = Random.rand * 2.0 * Math::PI
    Vector2.new((r * Math.cos(angle)).to_f32, (r * Math.sin(angle)).to_f32)
  end
end

struct Godot::Vector3
  # Generates a unit Vector3 pointing in a uniformly random direction on a sphere surface.
  def self.random_dir : Vector3
    u = Random.rand * 2.0 - 1.0
    theta = Random.rand * 2.0 * Math::PI
    f = Math.sqrt(Math.max(0.0, 1.0 - u * u))
    Vector3.new((f * Math.cos(theta)).to_f32, (f * Math.sin(theta)).to_f32, u.to_f32)
  end

  # Generates a random point inside a sphere of the given radius with uniform volumetric distribution.
  def self.random_in_sphere(radius : Number = 1.0) : Vector3
    r = (Random.rand ** (1.0 / 3.0)) * radius.to_f32
    dir = random_dir
    Vector3.new(dir.x * r, dir.y * r, dir.z * r)
  end
end
