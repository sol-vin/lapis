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

    # Fast-path updates the image pixel buffer directly from a raw slice of bytes without intermediate object allocations.
    # Ideal for video decoders (LibVLC), procedural textures, webcam feeds, and dynamic blitting.
    def update_buffer(width : Int, height : Int, format : Format | Int, pixels : Slice(UInt8), use_mipmaps : Bool = false) : Void
      check_alive!
      Bridge.image_update_buffer(
        @pointer,
        width.to_i32,
        height.to_i32,
        use_mipmaps,
        format.is_a?(Int) ? format.to_i32 : format.value.to_i32,
        pixels.to_unsafe,
        pixels.size.to_i64
      )
    end

    # Creates a new Godot Image directly from a raw slice of pixel bytes.
    def self.create_from_buffer(width : Int, height : Int, format : Format | Int, pixels : Slice(UInt8), use_mipmaps : Bool = false) : Image
      img = create_empty(width.to_i64, height.to_i64, use_mipmaps, format.is_a?(Int) ? format.to_i64 : format.value.to_i64)
      img.reference
      img.update_buffer(width, height, format, pixels, use_mipmaps)
      img
    end

    # Reads back the image's raw pixel buffer directly into a destination slice at native memory bandwidth.
    def read_buffer(destination : Slice(UInt8)) : Int64
      check_alive!
      Bridge.image_copy_to_buffer(@pointer, destination.to_unsafe, destination.size.to_i64)
    end

    # Returns a fresh copy of the image pixel buffer as a Crystal Bytes slice.
    def to_slice : Bytes
      check_alive!
      sz = get_data_size.to_i32
      return Bytes.empty if sz <= 0
      buf = Bytes.new(sz)
      read_buffer(buf)
      buf
    end
  end
end
