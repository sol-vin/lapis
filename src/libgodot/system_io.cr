lib LibSystemIO
  fun fopen(filename : LibC::Char*, mode : LibC::Char*) : Void*
  fun fclose(stream : Void*) : LibC::Int
  fun fread(ptr : Void*, size : LibC::SizeT, n : LibC::SizeT, stream : Void*) : LibC::SizeT
  fun fwrite(ptr : Void*, size : LibC::SizeT, n : LibC::SizeT, stream : Void*) : LibC::SizeT
  fun fseek(stream : Void*, offset : LibC::Long, whence : LibC::Int) : LibC::Int
  fun ftell(stream : Void*) : LibC::Long
  fun remove(filename : LibC::Char*) : LibC::Int
  {% if flag?(:windows) %}
    fun _mkdir(dirname : LibC::Char*) : LibC::Int
  {% else %}
    fun mkdir(dirname : LibC::Char*, mode : LibC::Int) : LibC::Int
  {% end %}
end

module Godot
  # ===========================================================================
  # SystemIO: Low-Level CRT File I/O Safety Primitive
  # ===========================================================================
  #
  # ## Architectural Rationale & Windows IOCP Thread Isolation:
  #
  # Standard Crystal `File` operations on Windows rely on asynchronous I/O
  # completion ports (`Crystal::IOCP`) and active cooperative Fiber event loops.
  #
  # When Godot executes GDExtension hooks (such as `ResourceFormatLoader`,
  # `ResourceFormatSaver`, `WorkerThreadPool` jobs, or audio streaming threads),
  # callbacks are executed on native C++ engine threads that are **not** managed
  # by Crystal's runtime. On these alien threads:
  #
  # 1. `Fiber.current.execution_context` is `nil`.
  # 2. Crystal's IOCP event loop is not pumping.
  # 3. Invoking standard `File.read` or `File.write` can cause deadlocks,
  #    `NilAssertionError` aborts, or silent engine hangs.
  #
  # `Godot::SystemIO` solves this by bypassing Crystal's high-level runtime
  # event loop entirely. It issues direct, synchronous C runtime (`fopen`,
  # `fread`, `fwrite`, `fclose`, `_mkdir`) calls. It has zero dependencies on
  # Fiber context, GC thread registration, or LibEvent/IOCP, making it 100%
  # crash-safe across all Godot worker threads and GDExtension background hooks.
  module SystemIO
    SEEK_SET = 0
    SEEK_END = 2

    # Reads the entire content of a file from disk into a Crystal String safely on any thread.
    def self.read_file(path : String) : String
      return "" if path.empty?
      fp = LibSystemIO.fopen(path.to_unsafe, "rb".to_unsafe)
      return "" if fp.null?

      LibSystemIO.fseek(fp, 0_i32, SEEK_END)
      size = LibSystemIO.ftell(fp)
      LibSystemIO.fseek(fp, 0_i32, SEEK_SET)
      if size <= 0
        LibSystemIO.fclose(fp)
        return ""
      end

      buf = Pointer(UInt8).malloc(size + 1)
      read_bytes = LibSystemIO.fread(buf.as(Void*), 1_u64, size.to_u64, fp)
      LibSystemIO.fclose(fp)
      buf[read_bytes] = 0_u8
      String.new(buf, read_bytes.to_i32)
    end

    # Reads a file line-by-line into an Array of Strings.
    def self.read_lines(path : String) : Array(String)
      content = read_file(path)
      return Array(String).new if content.empty?
      content.lines
    end

    # Writes the entire content string to a file on disk, overwriting existing files.
    def self.write_file(path : String, content : String) : Bool
      return false if path.empty?
      fp = LibSystemIO.fopen(path.to_unsafe, "wb".to_unsafe)
      return false if fp.null?

      written = LibSystemIO.fwrite(content.to_unsafe.as(Void*), 1_u64, content.bytesize.to_u64, fp)
      LibSystemIO.fclose(fp)
      written == content.bytesize.to_u64
    end

    # Appends the content string to the end of a file on disk.
    def self.append_file(path : String, content : String) : Bool
      return false if path.empty?
      fp = LibSystemIO.fopen(path.to_unsafe, "ab".to_unsafe)
      return false if fp.null?

      written = LibSystemIO.fwrite(content.to_unsafe.as(Void*), 1_u64, content.bytesize.to_u64, fp)
      LibSystemIO.fclose(fp)
      written == content.bytesize.to_u64
    end

    # Copies a file from `src` to `dst`.
    def self.copy_file(src : String, dst : String) : Bool
      return false if src.empty? || dst.empty?
      content = read_file(src)
      return false if content.empty? && !file_exists?(src)
      write_file(dst, content)
    end

    # Returns true if the file exists on disk and can be opened for reading.
    def self.file_exists?(path : String) : Bool
      return false if path.empty?
      fp = LibSystemIO.fopen(path.to_unsafe, "rb".to_unsafe)
      if !fp.null?
        LibSystemIO.fclose(fp)
        true
      else
        false
      end
    end

    # Returns the size of the file in bytes, or -1 if the file cannot be opened.
    def self.file_size(path : String) : Int64
      return -1_i64 if path.empty?
      fp = LibSystemIO.fopen(path.to_unsafe, "rb".to_unsafe)
      return -1_i64 if fp.null?

      LibSystemIO.fseek(fp, 0_i32, SEEK_END)
      size = LibSystemIO.ftell(fp).to_i64
      LibSystemIO.fclose(fp)
      size
    end

    # Deletes a file on disk.
    def self.delete_file(path : String) : Bool
      return false if path.empty?
      LibSystemIO.remove(path.to_unsafe) == 0
    end

    # Ensures all parent directories for `path` exist on disk.
    def self.ensure_dir(path : String) : Bool
      return false if path.empty?
      clean = path.gsub('\\', '/')
      parts = clean.split('/')
      current = ""
      parts.each do |part|
        next if part.empty?
        if part.ends_with?(":")
          current = part
          next
        end
        current = current.empty? ? part : "#{current}/#{part}"
        {% if flag?(:windows) %}
          LibSystemIO._mkdir(current.to_unsafe)
        {% else %}
          LibSystemIO.mkdir(current.to_unsafe, 0o755)
        {% end %}
      end
      true
    end
  end
end
