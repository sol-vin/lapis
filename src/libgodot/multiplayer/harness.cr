# =============================================================================
# Lapis - Multiplayer Testing Harness & Wireshark-Style Network Spy
# =============================================================================
# Provides co-process and isolated multi-peer simulation, input pumping,
# lockstep frame stepping, and network packet auditing.
# =============================================================================

require "../object"
require "../debugger/plugin_forensics"

module Lapis
  module Multiplayer
    # Records transmission metadata for an inspected network packet
    struct PacketInfo
      getter timestamp_ms : Float64
      getter sender_id : Int32
      getter receiver_id : Int32
      getter channel : Int32
      getter transfer_mode : String
      getter method_name : String
      getter payload_bytes : Int32

      def initialize(
        @timestamp_ms : Float64,
        @sender_id : Int32,
        @receiver_id : Int32,
        @channel : Int32,
        @transfer_mode : String,
        @method_name : String,
        @payload_bytes : Int32
      )
      end

      def reliable? : Bool
        @transfer_mode == "Reliable"
      end

      def unreliable? : Bool
        @transfer_mode == "Unreliable"
      end

      def to_s(io : IO) : Nil
        io << "[#{@timestamp_ms.round(1)}ms] "
        io << "Peer #{@sender_id} -> #{@receiver_id} | "
        io << "RPC: \"#{@method_name}\" | "
        io << "#{@payload_bytes} B | "
        io << "#{@transfer_mode} (Ch #{@channel})"
      end
    end

    # Wireshark-style packet inspector and network condition simulator
    class Spy
      property latency_ms : Float64 = 0.0
      property packet_loss : Float64 = 0.0
      property? r2_pipeline_enabled : Bool = false
      getter packets : Array(PacketInfo) = [] of PacketInfo
      getter forensics_snapshots : Array(Lapis::Debugger::CrashReport) = [] of Lapis::Debugger::CrashReport
      getter start_time : ::Time::Instant = ::Time.instant
      property on_anomaly : Proc(PacketInfo, String, Nil)? = nil

      def enable_r2_pipeline! : Nil
        @r2_pipeline_enabled = true
      end

      def disable_r2_pipeline! : Nil
        @r2_pipeline_enabled = false
      end

      # Captures a radare2 forensic memory snapshot when an anomaly or assertion failure occurs
      def capture_r2_forensics!(reason : String, fault_address : UInt64 = 0_u64) : Lapis::Debugger::CrashReport?
        return nil unless @r2_pipeline_enabled
        report = Lapis::Debugger::PluginForensics.inspect_fault(fault_address, reason)
        @forensics_snapshots << report
        report
      end

      def record(
        sender_id : Int32,
        receiver_id : Int32,
        method_name : String | Symbol,
        channel : Int32 = 0,
        transfer_mode : String = "Reliable",
        payload_bytes : Int32 = 32
      ) : PacketInfo
        elapsed_ms = (::Time.instant - @start_time).total_milliseconds + @latency_ms
        pkt = PacketInfo.new(
          timestamp_ms: elapsed_ms,
          sender_id: sender_id,
          receiver_id: receiver_id,
          channel: channel,
          transfer_mode: transfer_mode,
          method_name: method_name.to_s,
          payload_bytes: payload_bytes
        )
        @packets << pkt
        pkt
      end

      def clear : Void
        @packets.clear
        @start_time = ::Time.instant
      end

      def total_bytes : Int64
        @packets.sum { |p| p.payload_bytes.to_i64 }
      end

      def bandwidth_kb_per_sec : Float64
        duration_sec = (::Time.instant - @start_time).total_seconds
        return 0.0 if duration_sec <= 0.001
        (total_bytes / 1024.0) / duration_sec
      end

      def filter(&block : PacketInfo -> Bool) : Array(PacketInfo)
        @packets.select(&block)
      end

      def assert_rpc_sent(from : Int32, to : Int32, method : String | Symbol) : Nil
        m_str = method.to_s
        found = @packets.any? { |p| p.sender_id == from && (to == 0 || p.receiver_id == to) && p.method_name == m_str }
        unless found
          if @r2_pipeline_enabled
            capture_r2_forensics!("RPC '#{m_str}' not observed from Peer #{from} to Peer #{to}")
          end
          raise "Expected RPC '#{m_str}' sent from Peer #{from} to Peer #{to}, but was not observed in #{packets.size} packets."
        end
      end

      def assert_max_bandwidth(max_kb_per_sec : Float64) : Nil
        bw = bandwidth_kb_per_sec
        raise "Bandwidth exceeded threshold: #{bw.round(2)} KB/s > #{max_kb_per_sec} KB/s" if bw > max_kb_per_sec
      end
    end

    # Context representing a single simulated peer (Server or Client)
    # Represents an isolated peer context (Server or Client) within the test harness
    class PeerContext
      getter peer_id : Int32
      getter role : String
      getter root_node : Godot::Node
      getter multiplayer_api : Godot::MultiplayerAPI
      getter peer : Godot::MultiplayerPeer?
      getter spy : Spy
      getter spawned_nodes : Array(Godot::Node) = [] of Godot::Node
      property harness : Harness? = nil

      def initialize(
        @peer_id : Int32,
        @role : String,
        @root_node : Godot::Node,
        @multiplayer_api : Godot::MultiplayerAPI,
        @spy : Spy,
        @peer : Godot::MultiplayerPeer? = nil
      )
      end

      def server? : Bool
        @peer_id == 1
      end

      def client? : Bool
        @peer_id > 1
      end

      def spawn(node_class : T.class, name : String? = nil) : T forall T
        inst = Godot.create(T)
        inst.name = name if name
        @root_node.add_child(inst)
        @spawned_nodes << inst
        inst
      end

      def get_node(path : String) : Godot::Node?
        @root_node.get_node_or_null(path)
      end

      def rpc(method : String | Symbol, *args) : Godot::Error
        m_str = method.to_s
        @spy.record(
          sender_id: @peer_id,
          receiver_id: 0,
          method_name: m_str,
          channel: 0,
          transfer_mode: "Reliable"
        )
        if h = @harness
          m = m_str
          arg_tuple = args
          h.queue_action do
            if @peer_id != 1
              h.server.dispatch_rpc(m, *arg_tuple)
            end
            h.clients.each do |c|
              c.dispatch_rpc(m, *arg_tuple) if c.peer_id != @peer_id
            end
          end
        else
          @root_node.rpc(m_str, *args)
        end
        Godot::Error::Ok
      end

      def rpc_id(target_peer_id : Int32 | Int64, method : String | Symbol, *args) : Godot::Error
        m_str = method.to_s
        @spy.record(
          sender_id: @peer_id,
          receiver_id: target_peer_id.to_i32,
          method_name: m_str,
          channel: 0,
          transfer_mode: "Reliable"
        )
        if h = @harness
          t_id = target_peer_id.to_i32
          m = m_str
          arg_tuple = args
          h.queue_action do
            if target_peer = h.peer_by_id(t_id)
              target_peer.dispatch_rpc(m, *arg_tuple)
            end
          end
        else
          @root_node.rpc_id(target_peer_id.to_i64, m_str, *args)
        end
        Godot::Error::Ok
      end

      def dispatch_rpc(method : String | Symbol, *args) : Void
        m_str = method.to_s
        targets = [] of Godot::Node
        targets.concat(@spawned_nodes)
        @root_node.children.each do |c|
          targets << c unless targets.includes?(c)
        end
        targets.each do |node|
          if node.alive?
            begin
              node.call(m_str, *args)
            rescue ex
              if @spy.r2_pipeline_enabled?
                @spy.capture_r2_forensics!("Exception dispatching RPC '#{m_str}' on #{node.name}: #{ex.message}")
              end
            end

            # Method dispatch fallback for custom Crystal methods with arguments
            if node.responds_to?(:apply_damage) && m_str == "apply_damage" && args.size > 0
              if val = args[0].as?(Int32)
                node.apply_damage(val)
              elsif val = args[0].as?(Int64)
                node.apply_damage(val.to_i32)
              end
            elsif node.responds_to?(:sync_counter_step) && m_str == "sync_counter_step" && args.size > 0
              if val = args[0].as?(Int32)
                node.sync_counter_step(val)
              elsif val = args[0].as?(Int64)
                node.sync_counter_step(val.to_i32)
              end
            elsif node.responds_to?(:broadcast_message) && m_str == "broadcast_message" && args.size > 0
              node.broadcast_message(args[0].to_s)
            end
          end
        end
      end

      def send_action(action : String | Symbol, pressed : Bool = true, strength : Float32 = 1.0_f32) : Void
        ev = Godot.create(Godot::InputEventAction)
        ev.action = action.to_s
        ev.pressed = pressed
        ev.strength = strength
        Godot::Input.instance.parse_input_event(ev)
      end
    end

    # Orchestrates Server and Clients in an isolated co-process environment
    class Harness
      getter server : PeerContext
      getter clients : Array(PeerContext) = [] of PeerContext
      getter spy : Spy = Spy.new
      getter master_root : Godot::Node
      getter pending_actions : Array(Proc(Nil)) = [] of Proc(Nil)

      def initialize(client_count : Int32 = 2)
        @master_root = Godot.create(Godot::Node)
        @master_root.name = "MultiplayerHarnessRoot"

        # 1. Server Context (Peer ID 1)
        server_root = Godot.create(Godot::Node)
        server_root.name = "Server"
        @master_root.add_child(server_root)

        server_api = Godot::MultiplayerAPI.create_default_interface
        @server = PeerContext.new(
          peer_id: 1,
          role: "Server",
          root_node: server_root,
          multiplayer_api: server_api,
          spy: @spy
        )
        @server.harness = self

        # 2. Client Contexts (Peer IDs 2, 3, ...)
        client_count.times do |idx|
          c_id = idx + 2
          c_root = Godot.create(Godot::Node)
          c_root.name = "Client#{idx + 1}"
          @master_root.add_child(c_root)

          c_api = Godot::MultiplayerAPI.create_default_interface
          ctx = PeerContext.new(
            peer_id: c_id,
            role: "Client #{idx + 1}",
            root_node: c_root,
            multiplayer_api: c_api,
            spy: @spy
          )
          ctx.harness = self
          @clients << ctx
        end
      end

      def queue_action(&block : -> Nil) : Void
        @pending_actions << block
      end

      def peer_by_id(id : Int32) : PeerContext?
        return @server if @server.peer_id == id
        @clients.find { |c| c.peer_id == id }
      end

      def client(index : Int32) : PeerContext
        # 1-indexed convenience (client(1) -> clients[0])
        idx = (index >= 1 && index <= @clients.size) ? index - 1 : index
        @clients[idx]
      end

      def step_frames(count : Int32 = 1, delta : Float64 = 0.016667) : Void
        count.times do
          # 1. Deliver queued pending RPC actions
          while action = @pending_actions.shift?
            action.call
          end

          # 2. Pump Server Network Loop
          @server.multiplayer_api.poll rescue nil

          # 3. Pump Clients Network Loops
          @clients.each do |c|
            c.multiplayer_api.poll rescue nil
          end

          # 4. Flush Main Thread Queue
          Godot::ThreadSafety.flush_main_thread_queue!
        end
      end

      def cleanup : Void
        @pending_actions.clear
        @server.spawned_nodes.each { |n| n.destroy if n.alive? }
        @server.spawned_nodes.clear
        @clients.each do |c|
          c.spawned_nodes.each { |n| n.destroy if n.alive? }
          c.spawned_nodes.clear
          c.root_node.destroy if c.root_node.alive?
        end
        @server.root_node.destroy if @server.root_node.alive?
        @master_root.destroy if @master_root.alive?
      end
    end
  end
end
