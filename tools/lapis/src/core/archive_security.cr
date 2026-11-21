require "path"

module Lapis
  module Core
    # Defense-in-depth archive extraction and path-containment security utilities (CWE-22 / Zip-Slip).
    module ArchiveSecurity
      # Windows reserved DOS device names (case-insensitive, with or without extension)
      WINDOWS_RESERVED_DEVICES = /\A(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..+)?\z/i

      # Illegal characters in cross-platform / Win32 archive path segments
      ILLEGAL_SEGMENT_CHARS = {'<', '>', ':', '"', '|', '?', '*'}

      struct EntryValidation
        getter? valid : Bool
        getter clean_path : String
        getter? is_dir : Bool
        getter? skip : Bool
        getter reason : String?

        def initialize(
          @valid : Bool,
          @clean_path : String = "",
          @is_dir : Bool = false,
          @skip : Bool = false,
          @reason : String? = nil,
        )
        end

        def self.ok(clean_path : String, is_dir : Bool = false, skip : Bool = false) : self
          new(valid: true, clean_path: clean_path, is_dir: is_dir, skip: skip)
        end

        def self.invalid(reason : String) : self
          new(valid: false, reason: reason)
        end
      end

      # Returns a human-readable rejection reason if a single path segment is unsafe, or `nil` if safe.
      def self.invalid_segment_reason(seg : String) : String?
        return "segment is not valid UTF-8" unless seg.valid_encoding?
        return "segment is empty" if seg.empty?
        return "segment is '.' or '..'" if seg == "." || seg == ".."

        if seg.ends_with?(' ') || seg.ends_with?('.')
          return "segment '#{seg}' has trailing space or dot"
        end

        seg.each_byte do |b|
          if b < 0x20_u8 || b == 0x7F_u8
            return "segment contains NUL or control byte (0x#{b.to_s(16).rjust(2, '0')})"
          end
        end

        seg.each_char do |ch|
          if ILLEGAL_SEGMENT_CHARS.includes?(ch) || ch == '/' || ch == '\\'
            return "segment '#{seg}' contains illegal path character '#{ch}'"
          end
        end

        if seg.matches?(WINDOWS_RESERVED_DEVICES)
          return "segment '#{seg}' is a reserved Windows device name"
        end

        nil
      end

      # Validates that `name` is a safe single directory/identifier component (no slashes, '..', ':', control chars, etc.).
      def self.valid_single_name?(name : String) : Bool
        return false unless name.valid_encoding?
        return false if name.empty?
        invalid_segment_reason(name).nil?
      end

      # Lexically validates and normalizes an archive entry path.
      # Rejects invalid UTF-8, empty filenames, NUL/control bytes, rooted/UNC paths, drive letters,
      # NTFS alternate data streams (':'), '..' traversal segments, Win32 trailing spaces/dots, and DOS devices.
      def self.validate_entry_path(raw_name : String, is_dir_flag : Bool = false) : EntryValidation
        unless raw_name.valid_encoding?
          return EntryValidation.invalid("entry filename is not valid UTF-8")
        end

        if raw_name.empty?
          return EntryValidation.invalid("entry filename is empty")
        end

        raw_name.each_byte do |b|
          if b < 0x20_u8 || b == 0x7F_u8
            return EntryValidation.invalid("entry filename contains NUL or control byte (0x#{b.to_s(16).rjust(2, '0')})")
          end
        end

        norm = raw_name.gsub('\\', '/')
        is_dir = is_dir_flag || norm.ends_with?('/')

        if norm.starts_with?('/')
          return EntryValidation.invalid("rooted or UNC archive entry path is forbidden")
        end

        if norm.includes?(':')
          return EntryValidation.invalid("drive-qualified or colon-containing entry path is forbidden")
        end

        clean_segments = [] of String
        norm.split('/').each do |seg|
          next if seg.empty?
          if seg == ".."
            return EntryValidation.invalid("parent directory traversal ('..') is forbidden")
          end
          next if seg == "."
          if reason = invalid_segment_reason(seg)
            return EntryValidation.invalid(reason)
          end
          clean_segments << seg
        end

        if clean_segments.empty?
          # Bare "." or "./" archive root directory entry
          return EntryValidation.ok("", is_dir: true, skip: true)
        end

        EntryValidation.ok(clean_segments.join("/"), is_dir: is_dir, skip: false)
      end

      # Returns `true` if `path` exists on disk as a symlink, NTFS reparse point/junction, pipe, socket, or device.
      def self.unsafe_existing_node?(path : Path) : Bool
        if info = File.info?(path, follow_symlinks: false)
          return true if info.symlink?
          return true if !info.directory? && !info.file?
        end
        false
      rescue
        true
      end

      # Resolves `clean_rel_path` strictly within `allowed_root`, enforcing both canonical lexical
      # containment and filesystem symlink/junction verification along all existing path components.
      # Returns `nil` if the resolved destination escapes `allowed_root` or traverses a symlink/reparse point.
      def self.resolve_safe_destination(
        allowed_root : Path,
        clean_rel_path : String,
        allow_root_dir : Bool = false,
      ) : Path?
        return nil unless clean_rel_path.valid_encoding?

        root_abs = allowed_root.expand(home: false).normalize

        if clean_rel_path.empty? || clean_rel_path == "."
          return nil unless allow_root_dir
          return nil if unsafe_existing_node?(root_abs)
          return root_abs
        end

        val = validate_entry_path(clean_rel_path, allow_root_dir)
        return nil unless val.valid?
        if val.skip?
          return allow_root_dir && !unsafe_existing_node?(root_abs) ? root_abs : nil
        end

        segments = val.clean_path.split('/')
        dest_abs = segments.reduce(root_abs) { |acc, seg| acc.join(seg) }.expand(home: false).normalize

        rel = dest_abs.relative_to?(root_abs)
        return nil unless rel

        if rel.to_s == "."
          return allow_root_dir && !unsafe_existing_node?(root_abs) ? root_abs : nil
        end

        return nil if rel.anchor
        rel.each_part do |part|
          return nil if part.empty? || part == "." || part == ".."
        end

        # Verify neither `root_abs` nor any existing descendant along `rel` is a symlink or NTFS junction
        return nil if unsafe_existing_node?(root_abs)
        cur = root_abs
        rel.each_part do |part|
          cur = cur.join(part)
          return nil if unsafe_existing_node?(cur)
        end

        dest_abs
      rescue
        nil
      end
    end
  end
end
