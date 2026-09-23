module Godot
  # ===========================================================================
  # Image Extensions
  # ===========================================================================
  class Image
    # Returns the format of the image
    def format : Format
      get_format
    end

    # Returns the pixel dimensions of the image as a Vector2i
    def size : Vector2i
      Vector2i.new(get_width.to_i32, get_height.to_i32)
    end

    # Returns true if the image has zero width or height
    def empty? : Bool
      is_empty
    end
  end
end
