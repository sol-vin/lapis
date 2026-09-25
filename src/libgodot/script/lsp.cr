require "json"

module Lapis
  # Forward declaration for completion items
  struct CompletionItem
    property kind : String
    property display_text : String
    property insert_text : String
    property default_value : String
    property kind_id : Int64
    property location : Int64

    def initialize(
      @kind : String,
      @display_text : String,
      @insert_text : String = @display_text,
      @default_value : String = "",
      @kind_id : Int64 = 9_i64, # Default: PlainText
      @location : Int64 = 0_i64
    )
    end
  end

{% if flag?(:windows) %}
  lib LibKernel32
    fun PeekNamedPipe(
      hNamedPipe : Void*,
      lpBuffer : Void*,
      nBufferSize : UInt32,
      lpBytesRead : UInt32*,
      lpTotalBytesAvail : UInt32*,
      lpBytesLeftThisMessage : UInt32*
    ) : LibC::Int
  end
{% else %}
  lib LibPosixPoll
    struct PollFD
      fd : LibC::Int
      events : LibC::Short
      revents : LibC::Short
    end

    fun poll(fds : PollFD*, nfds : LibC::SizeT, timeout : LibC::Int) : LibC::Int
  end
{% end %}

  # Guarded, fail-safe LSP worker for Crystalline.
  # Strictly sandboxed: failures, crashes, or unresponsiveness in Crystalline
  # will NEVER freeze Godot or degrade the in-editor editing experience.
  class CrystalLSP
    @@instance : CrystalLSP? = nil
    getter? enabled : Bool = false
    getter server_path : String = "crystalline"
    @process : Process? = nil
    @is_running : Bool = false
    @starting : Bool = false
    @next_id : Int32 = 1
    @mutex : ::Thread::Mutex = ::Thread::Mutex.new
    @open_docs : Hash(String, Int32) = Hash(String, Int32).new
    @workspace_root : String = ""

    def self.instance : CrystalLSP
      @@instance ||= new
    end

    def initialize
      exe_name = {% if flag?(:windows) %} "crystalline.exe" {% else %} "crystalline" {% end %}
      local_app = ENV["LOCALAPPDATA"]?
      installed_path = local_app ? File.join(local_app, "Programs", "Lapis", "bin", exe_name) : nil

      if found = Process.find_executable("crystalline")
        @server_path = File.expand_path(found)
        @enabled = true
      elsif File.exists?(File.join(Dir.current, "bin", exe_name))
        @server_path = File.expand_path(File.join(Dir.current, "bin", exe_name))
        @enabled = true
      elsif installed_path && File.exists?(installed_path)
        @server_path = File.expand_path(installed_path)
        @enabled = true
      else
        @server_path = ""
        @enabled = false
      end
    end

    def available? : Bool
      @enabled && !@server_path.empty?
    end

    def running? : Bool
      if proc = @process
        @is_running && !proc.terminated?
      else
        false
      end
    end

    # Non-blocking background startup so editor never stalls on main thread
    def ensure_started_async(workspace_root : String? = nil) : Void
      return unless available?
      return if running? || @starting
      @starting = true
      ::Thread.new do
        begin
          start(workspace_root)
        ensure
          @starting = false
        end
      end
    end

    # Safely starts the Crystalline LSP server in background with stdio
    def start(workspace_root : String? = nil) : Bool
      return false unless available?
      return true if running?

      @mutex.synchronize do
        return true if running?

        begin
          @workspace_root = workspace_root || Dir.current
          # Launch crystalline with LSP stdio mode
          proc = Process.new(
            @server_path,
            args: ["--stdio"],
            input: Process::Redirect::Pipe,
            output: Process::Redirect::Pipe,
            error: Process::Redirect::Pipe
          )
          @process = proc

          # Format workspace root URI for LSP
          root_norm = @workspace_root.gsub('\\', '/')
          root_norm = "/#{root_norm}" unless root_norm.starts_with?('/')
          root_uri = "file://#{root_norm}"

          init_params = {
            processId:    Process.pid,
            rootUri:      root_uri,
            capabilities: {
              textDocument: {
                completion: {
                  completionItem: {
                    snippetSupport: true,
                  },
                },
                definition: {
                  dynamicRegistration: true,
                },
              },
            },
          }
          init_req = {
            jsonrpc: "2.0",
            id:      1,
            method:  "initialize",
            params:  init_params,
          }.to_json

          write_message(init_req)
          # Await initialize response (timeout 2000ms for reliable spawn)
          res = read_message(2000)
          if res
            # Send initialized notification
            initialized_ntf = {
              jsonrpc: "2.0",
              method:  "initialized",
              params:  {} of String => String,
            }.to_json
            write_message(initialized_ntf)
            @is_running = true
            @next_id = 2
            Godot.print("[CrystalLSP] Crystalline background language server started successfully.")
            return true
          else
            stop_internal
            return false
          end
        rescue ex
          stop_internal
          # Fail silently and safely without crashing Godot
          Godot.print("[CrystalLSP] Notice: Crystalline not started (#{ex.message}). Continuing with built-in editor intelligence.")
          return false
        end
      end
    end

    # Synchronize open document state to LSP
    def sync_document(path : String, code : String) : Void
      return unless running?
      norm_path = normalize_path(path)
      uri = to_uri(norm_path)

      if ver = @open_docs[norm_path]?
        new_ver = ver + 1
        @open_docs[norm_path] = new_ver
        msg = {
          jsonrpc: "2.0",
          method:  "textDocument/didChange",
          params:  {
            textDocument: {
              uri:     uri,
              version: new_ver,
            },
            contentChanges: [
              {
                text: code,
              },
            ],
          },
        }.to_json
        write_message(msg)
      else
        @open_docs[norm_path] = 1
        msg = {
          jsonrpc: "2.0",
          method:  "textDocument/didOpen",
          params:  {
            textDocument: {
              uri:        uri,
              languageId: "crystal",
              version:    1,
              text:       code,
            },
          },
        }.to_json
        write_message(msg)
      end
    end

    # Requests code completion from Crystalline LSP with timeout
    def request_completion(code : String, path : String, line : Int32, column : Int32, timeout_ms : Int32 = 60) : Array(CompletionItem)?
      unless running?
        ensure_started_async
        return nil
      end

      @mutex.synchronize do
        return nil unless running?
        begin
          sync_document(path, code)
          req_id = @next_id
          @next_id += 1

          req = {
            jsonrpc: "2.0",
            id:      req_id,
            method:  "textDocument/completion",
            params:  {
              textDocument: {
                uri: to_uri(normalize_path(path)),
              },
              position: {
                line:      Math.max(0, line - 1),
                character: Math.max(0, column),
              },
            },
          }.to_json

          write_message(req)
          raw_res = read_message_for_id(req_id, timeout_ms)
          return nil unless raw_res

          parsed = ::JSON.parse(raw_res)
          result = parsed["result"]?
          return nil unless result

          items_arr = if result.as_a?
                        result.as_a
                      elsif items = result["items"]?
                        items.as_a
                      else
                        nil
                      end

          return nil unless items_arr

          items = [] of CompletionItem
          items_arr.each do |item|
            label = item["label"]?.try(&.as_s) || ""
            next if label.empty?

            insert_text = item["insertText"]?.try(&.as_s) || label
            lsp_kind = item["kind"]?.try(&.as_i64) || 1_i64
            kind_str, kind_id = map_lsp_kind(lsp_kind)
            detail = item["detail"]?.try(&.as_s) || ""

            items << CompletionItem.new(
              kind: kind_str,
              display_text: label,
              insert_text: insert_text,
              default_value: detail,
              kind_id: kind_id,
              location: 0_i64
            )
          end

          items.empty? ? nil : items
        rescue
          nil
        end
      end
    end

    # Requests definition jump target from Crystalline LSP with timeout
    def request_definition(code : String, path : String, line : Int32, column : Int32, timeout_ms : Int32 = 100) : Tuple(String, Int32)?
      unless running?
        ensure_started_async
        return nil
      end

      @mutex.synchronize do
        return nil unless running?
        begin
          sync_document(path, code)
          req_id = @next_id
          @next_id += 1

          req = {
            jsonrpc: "2.0",
            id:      req_id,
            method:  "textDocument/definition",
            params:  {
              textDocument: {
                uri: to_uri(normalize_path(path)),
              },
              position: {
                line:      Math.max(0, line - 1),
                character: Math.max(0, column),
              },
            },
          }.to_json

          write_message(req)
          raw_res = read_message_for_id(req_id, timeout_ms)
          return nil unless raw_res

          parsed = ::JSON.parse(raw_res)
          result = parsed["result"]?
          return nil unless result

          target = if result.as_a?
                     result.as_a.first?
                   else
                     result
                   end
          return nil unless target

          uri = target["uri"]?.try(&.as_s) || target["targetUri"]?.try(&.as_s) || ""
          range = target["range"]? || target["targetRange"]?
          target_line = range.try(&.["start"]?.try(&.["line"]?.try(&.as_i))) || 0

          file_path = uri_to_path(uri)
          {file_path, target_line + 1}
        rescue
          nil
        end
      end
    end

    # Gracefully stops the Crystalline process
    def stop : Void
      @mutex.synchronize do
        stop_internal
      end
    end

    private def stop_internal : Void
      return unless @process

      begin
        proc = @process.not_nil!
        unless proc.terminated?
          proc.terminate rescue nil
          proc.wait rescue nil
        end
      rescue
      ensure
        @process = nil
        @is_running = false
        @open_docs.clear
      end
    end

    private def write_message(json : String) : Void
      proc = @process
      return unless proc && !proc.terminated?
      payload = "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
      proc.input.write(payload.to_slice)
      proc.input.flush
    rescue
      stop_internal
    end

    # Reads next JSON message with strict timeout guard
    private def read_message(timeout_ms : Int32 = 150) : String?
      proc = @process
      return nil unless proc && !proc.terminated?

      # Wait for data using platform-specific non-blocking check
      unless wait_for_data(timeout_ms)
        return nil
      end

      out_io = proc.output
      header = out_io.gets
      return nil unless header

      # Consume empty delimiter line
      out_io.gets

      if header =~ /Content-Length:\s*(\d+)/
        len = $1.to_i
        buf = Bytes.new(len)
        out_io.read_fully(buf)
        String.new(buf)
      else
        nil
      end
    rescue
      stop_internal
      nil
    end

    private def read_message_for_id(target_id : Int32, timeout_ms : Int32 = 150) : String?
      start_instant = ::Time.instant
      while (::Time.instant - start_instant).total_milliseconds < timeout_ms
        rem_ms = (timeout_ms - (::Time.instant - start_instant).total_milliseconds).to_i
        break if rem_ms <= 0
        msg = read_message(rem_ms)
        if msg
          begin
            parsed = ::JSON.parse(msg)
            if parsed["id"]? && parsed["id"].as_i? == target_id
              return msg
            end
          rescue
          end
        else
          break
        end
      end
      nil
    end

    # Non-blocking check for available bytes on stdout pipe
    private def wait_for_data(timeout_ms : Int32) : Bool
      proc = @process
      return false unless proc && !proc.terminated?

      {% if flag?(:windows) %}
        raw_fd = proc.output.as(IO::FileDescriptor).fd
        os_handle = LibC._get_osfhandle(raw_fd)
        return false if os_handle == -1 || os_handle == 0
        handle = Pointer(Void).new(os_handle.to_u64)
        bytes_avail = 0_u32
        start_instant = ::Time.instant
        loop do
          ret = LibKernel32.PeekNamedPipe(handle, nil, 0_u32, nil, pointerof(bytes_avail), nil)
          return false if ret == 0 # Pipe broken or closed
          return true if bytes_avail > 0

          elapsed = (::Time.instant - start_instant).total_milliseconds
          return false if elapsed >= timeout_ms
          Crystal::System::Thread.sleep(2.milliseconds)
        end
      {% else %}
        fd = proc.output.as(IO::FileDescriptor).fd
        pfd = LibPosixPoll::PollFD.new
        pfd.fd = fd.to_i32
        pfd.events = 1_i16 # POLLIN
        pfd.revents = 0_i16
        ret = LibPosixPoll.poll(pointerof(pfd), 1_u64, timeout_ms.to_i32)
        ret > 0 && (pfd.revents & 1_i16) != 0
      {% end %}
    end

    private def normalize_path(path : String) : String
      if path.starts_with?("res://")
        rel = path.sub("res://", "")
        File.expand_path(File.join(@workspace_root, rel))
      else
        File.expand_path(path)
      end
    end

    private def to_uri(abs_path : String) : String
      norm = abs_path.gsub('\\', '/')
      norm = "/#{norm}" unless norm.starts_with?('/')
      "file://#{norm}"
    end

    private def uri_to_path(uri : String) : String
      return uri unless uri.starts_with?("file://")
      p = uri.sub("file://", "")
      p = p.lstrip('/') if p =~ %r{^/[A-Za-z]:}
      p.gsub('/', File::SEPARATOR)
    end

    # Maps LSP CompletionItemKind to Godot CodeCompletionKind enum values
    private def map_lsp_kind(kind : Int64) : Tuple(String, Int64)
      case kind
      when 7, 8, 9 # Class, Interface, Module
        {"class", 0_i64}
      when 2, 3, 4 # Method, Function, Constructor
        {"method", 1_i64}
      when 23 # Event
        {"signal", 2_i64}
      when 6 # Variable
        {"variable", 3_i64}
      when 5, 10 # Field, Property
        {"property", 4_i64}
      when 13 # Enum
        {"enum", 5_i64}
      when 11, 12, 21 # Unit, Value, Constant
        {"constant", 6_i64}
      when 14 # Keyword
        {"keyword", 10_i64}
      when 15 # Snippet
        {"snippet", 9_i64}
      else # Text / PlainText
        {"text", 9_i64}
      end
    end
  end
end

alias CompletionItem = Lapis::CompletionItem
alias CrystalLSP = Lapis::CrystalLSP

module Godot
  alias CompletionItem = ::Lapis::CompletionItem
  alias CrystalLSP = ::Lapis::CrystalLSP
end
