require "./spec_helper"
require "../src/libgodot/logging"

# Test single-statement registration across files/scopes
log_filter :spec_public, tag: "{public}", name_tag: "SPEC_PUBLIC", color: "#50fa7b"
log_filter :spec_secret, tag: "{secret}", name_tag: "SPEC_SECRET", color: "#ff5555"

# Test block DSL registration
define_log_filters do
  filter :spec_spoiler, tag: "{spoiler}", name_tag: "SPEC_SPOILER", color: "#bd93f9"
  filter :spec_telemetry, tag: "{telemetry}", name_tag: "SPEC_TELEMETRY", color: "#8be9fd"
end

describe "Godot Diagnostic Logging System" do
  describe "Godot::LogLevel" do
    it "maintains correct severity hierarchy and ordering" do
      (Godot::LogLevel::Off < Godot::LogLevel::Error).should be_true
      (Godot::LogLevel::Error < Godot::LogLevel::Warn).should be_true
      (Godot::LogLevel::Warn < Godot::LogLevel::Info).should be_true
      (Godot::LogLevel::Info < Godot::LogLevel::Debug).should be_true
      (Godot::LogLevel::Debug < Godot::LogLevel::Trace).should be_true
      (Godot::LogLevel::Trace < Godot::LogLevel::Internal).should be_true
    end

    it "formats name tags correctly" do
      Godot::LogLevel::Off.name_tag.should eq("OFF")
      Godot::LogLevel::Error.name_tag.should eq("ERROR")
      Godot::LogLevel::Warn.name_tag.should eq("WARN")
      Godot::LogLevel::Info.name_tag.should eq("INFO")
      Godot::LogLevel::Debug.name_tag.should eq("DEBUG")
      Godot::LogLevel::Trace.name_tag.should eq("TRACE")
      Godot::LogLevel::Internal.name_tag.should eq("INTERNAL")
    end

    it "provides BBCode hex colors" do
      Godot::LogLevel::Error.color_bbcode.should eq("#ff5555")
      Godot::LogLevel::Warn.color_bbcode.should eq("#ffb86c")
      Godot::LogLevel::Info.color_bbcode.should eq("#8be9fd")
      Godot::LogLevel::Debug.color_bbcode.should eq("#50fa7b")
    end

    it "parses string representations case-insensitively" do
      Godot::LogLevel.parse?("error").should eq(Godot::LogLevel::Error)
      Godot::LogLevel.parse?("WARN").should eq(Godot::LogLevel::Warn)
      Godot::LogLevel.parse?("info").should eq(Godot::LogLevel::Info)
      Godot::LogLevel.parse?("DEBUG").should eq(Godot::LogLevel::Debug)
      Godot::LogLevel.parse?("trace").should eq(Godot::LogLevel::Trace)
      Godot::LogLevel.parse?("gc").should eq(Godot::LogLevel::Internal)
      Godot::LogLevel.parse?("1").should eq(Godot::LogLevel::Error)
      Godot::LogLevel.parse?("3").should eq(Godot::LogLevel::Info)
      Godot::LogLevel.parse?("spec_spoiler").should eq(Godot::LogLevel::SpecSpoiler)
      Godot::LogLevel.parse?("invalid").should be_nil
    end
  end

  describe "Godot::LogRecord" do
    it "constructs with timestamp, user-defined status, and formats with location" do
      t = Time.local(2026, 9, 28, 12, 0, 0)
      rec = Godot::LogRecord.new(
        level: Godot::LogLevel::Info,
        channel: "TestChannel",
        message: "Hello World",
        file: "test.cr",
        line: 42,
        function: "test_fn",
        tags: ["engine", "test"],
        status: "verified",
        timestamp: t
      )
      str = rec.to_formatted_string(include_location: true)
      str.should contain("[2026-09-28 12:00:00")
      str.should contain("[INFO]")
      str.should contain("[TestChannel]")
      str.should contain("{verified}")
      str.should contain("<engine,test>")
      str.should contain("Hello World (test.cr:42)")
      rec.has_status?.should be_true
      rec.status?("verified").should be_true
      rec.status?("other").should be_false
    end

    it "detects public and confidential status/tags correctly" do
      public_rec = Godot::LogRecord.new(
        level: Godot::LogLevel::Info,
        channel: "Gameplay",
        message: "Match finished",
        status: "public"
      )
      public_rec.public?.should be_true
      public_rec.confidential?.should be_false

      secret_rec = Godot::LogRecord.new(
        level: Godot::LogLevel::Info,
        channel: "Gameplay",
        message: "Boss weakness is ice",
        status: "secret"
      )
      secret_rec.public?.should be_false
      secret_rec.confidential?.should be_true

      spoiler_rec = Godot::LogRecord.new(
        level: Godot::LogLevel::Warn,
        channel: "Story",
        message: "Protagonist's real identity is revealed",
        status: "spoiler"
      )
      spoiler_rec.confidential?.should be_true
    end

    it "formats BBCode with status and colors" do
      rec = Godot::LogRecord.new(
        level: Godot::LogLevel::Error,
        channel: "Network",
        message: "Connection timeout",
        status: "failed"
      )
      bb = rec.to_bbcode
      bb.should contain("[color=#ff5555][ERROR][/color]")
      bb.should contain("[color=#8be9fd][Network][/color]")
      bb.should contain("{failed}")
      bb.should contain("Connection timeout")
    end
  end

  describe "Godot::MemoryRingBufferSink" do
    it "records up to capacity and shifts oldest entries on overflow" do
      sink = Godot::MemoryRingBufferSink.new(capacity: 3)
      (1..5).each do |i|
        sink.write(Godot::LogRecord.new(
          level: Godot::LogLevel::Info,
          channel: "Channel",
          message: "Msg #{i}"
        ))
      end

      snap = sink.snapshot
      snap.size.should eq(3)
      snap.map(&.message).should eq(["Msg 3", "Msg 4", "Msg 5"])
    end

    it "clears in-memory records cleanly" do
      sink = Godot::MemoryRingBufferSink.new(capacity: 10)
      sink.write(Godot::LogRecord.new(level: Godot::LogLevel::Info, channel: "A", message: "M"))
      sink.snapshot.size.should eq(1)
      sink.clear
      sink.snapshot.size.should eq(0)
    end
  end

  describe "User-Defined Log Channels, Status, and Custom Filters" do
    it "allows users to define a public log channel with error filter plus custom public filter preventing secret leakage" do
      logger = Godot.logger
      logger.min_level = Godot::LogLevel::Trace

      # Create user-defined "public" channel with status "public_release" and error-only level
      pub_channel = Godot.configure_channel("public_demo", status: "public_release", min_level: Godot::LogLevel::Error) do |chan|
        # Custom "public" filter to prevent leakage of secret game info
        chan.add_filter do |record|
          is_secret = record.confidential? || 
                      record.message.includes?("SECRET_QUEST") || 
                      record.message.includes?("ENDGAME_BOSS")
          !is_secret
        end
      end

      # Capture logs sent to central sinks
      test_sink = Godot::MemoryRingBufferSink.new(capacity: 100)
      logger.add_sink(test_sink)

      # 1. Info log on this channel should be rejected because min_level is Error
      pub_channel.info("Player logged in")
      test_sink.snapshot.none? { |r| r.message == "Player logged in" }.should be_true

      # 2. Warning log should also be rejected
      pub_channel.warn("Inventory near capacity")
      test_sink.snapshot.none? { |r| r.message == "Inventory near capacity" }.should be_true

      # 3. Error containing secret game info should be blocked by the custom public filter
      pub_channel.error("Failed to spawn ENDGAME_BOSS in dungeon", tags: ["secret"])
      test_sink.snapshot.none? { |r| r.message.includes?("ENDGAME_BOSS") }.should be_true

      # 4. Standard public error (no secret info) SHOULD pass through cleanly
      pub_channel.error("Failed to load texture: res://icon.svg")
      test_sink.snapshot.any? { |r| r.message == "Failed to load texture: res://icon.svg" }.should be_true

      # Verify status propagation
      err_rec = test_sink.snapshot.find { |r| r.message == "Failed to load texture: res://icon.svg" }
      err_rec.should_not be_nil
      err_rec.not_nil!.status.should eq("public_release")
      err_rec.not_nil!.channel.should eq("public_demo")

      logger.remove_sink(test_sink)
    end

    it "supports muting/unmuting channels dynamically via status" do
      logger = Godot.logger
      chan = Godot.channel("CombatTelemetry")
      chan.status = "active"

      test_sink = Godot::MemoryRingBufferSink.new(capacity: 100)
      logger.add_sink(test_sink)

      chan.info("Slash attack dealt 45 damage")
      test_sink.snapshot.any? { |r| r.message.includes?("Slash attack") }.should be_true

      # Mute the channel
      chan.mute!
      chan.status.should eq("muted")
      chan.enabled?.should be_false

      chan.info("Fireball dealt 120 damage")
      test_sink.snapshot.none? { |r| r.message.includes?("Fireball") }.should be_true

      # Unmute channel
      chan.unmute!
      chan.status.should eq("active")
      chan.enabled?.should be_true

      chan.info("Frost attack dealt 80 damage")
      test_sink.snapshot.any? { |r| r.message.includes?("Frost attack") }.should be_true

      logger.remove_sink(test_sink)
    end

    it "supports dedicated channel sinks" do
      chan = Godot.channel("Audio")
      chan_sink = Godot::MemoryRingBufferSink.new(capacity: 50)
      chan.add_sink(chan_sink)

      chan.info("BGM tracks started")
      chan_sink.snapshot.any? { |r| r.message == "BGM tracks started" }.should be_true

      chan.remove_sink(chan_sink)
    end
  end

  describe "Godot::DiagnosticLogger & Filter Registry" do
    it "dispatches to registered sinks" do
      logger = Godot.logger
      logger.min_level = Godot::LogLevel::Trace

      test_sink = Godot::MemoryRingBufferSink.new(capacity: 100)
      logger.add_sink(test_sink)

      Godot.log_info("SpecChannel", "Dispatcher Verification")

      snapshot = test_sink.snapshot
      snapshot.any? { |r| r.channel == "SpecChannel" && r.message == "Dispatcher Verification" }.should be_true
      logger.remove_sink(test_sink)
    end

    it "suppresses logs above min_level" do
      logger = Godot.logger
      logger.min_level = Godot::LogLevel::Warn

      test_sink = Godot::MemoryRingBufferSink.new(capacity: 100)
      logger.add_sink(test_sink)

      Godot.log_debug("SpecChannel", "This should be suppressed")
      test_sink.snapshot.none? { |r| r.message == "This should be suppressed" }.should be_true

      Godot.log_error("SpecChannel", "This should pass")
      test_sink.snapshot.any? { |r| r.message == "This should pass" }.should be_true

      logger.remove_sink(test_sink)
      logger.min_level = Godot::LogLevel::Trace
    end

    it "allows registering custom global named filters" do
      Godot::DiagnosticLogger.register_filter("quest_filter") do |record|
        !record.message.includes?("SECRET_QUEST_LOCATION")
      end

      quest_proc = Godot::DiagnosticLogger.named_filter("quest_filter")
      quest_proc.should_not be_nil

      sink = Godot::MemoryRingBufferSink.new(capacity: 10)
      sink.add_filter("quest_filter")

      rec_blocked = Godot::LogRecord.new(level: Godot::LogLevel::Info, channel: "Q", message: "Go to SECRET_QUEST_LOCATION")
      rec_allowed = Godot::LogRecord.new(level: Godot::LogLevel::Info, channel: "Q", message: "Go to Town Square")

      sink.passes_filters?(rec_blocked).should be_false
      sink.passes_filters?(rec_allowed).should be_true
    end
  end

  describe "Zero-Cost Compile-Time Godot.log & Shorthand Macros" do
    it "supports flexible Godot.log with automatic tagging and status" do
      # 1-argument form defaults channel to 'General' and auto-tags 'INFO'
      Godot.log(Godot::LogLevel::Info, "Single argument log test")
      # 2-argument form specifies channel explicitly
      Godot.log(Godot::LogLevel::Warn, "Inspector", "Two argument log test")
      # Custom enum level with auto-tagging
      Godot.log(Godot::LogLevel::SpecSpoiler, "Story", "Final boss identity revealed")
      # Custom symbol level with auto-tagging
      Godot.log(:spec_spoiler, "Cutscene", "Symbol custom level test")
      # Symbol level form
      Godot.log(:info, "SymbolChannel", "Symbol log test")
      # Channel helper macro
      Godot.log_channel("Dialogue", :info, "NPC dialogue triggered", status: "spoken")

      history = Godot.log_history

      # Verify 1-arg form
      entry1 = history.find { |r| r.message == "Single argument log test" }
      entry1.should_not be_nil
      entry1.not_nil!.channel.should eq("General")
      entry1.not_nil!.tags.should contain("INFO")
      entry1.not_nil!.status.should eq("info")

      # Verify 2-arg form
      entry2 = history.find { |r| r.message == "Two argument log test" }
      entry2.should_not be_nil
      entry2.not_nil!.channel.should eq("Inspector")
      entry2.not_nil!.tags.should contain("WARN")
      entry2.not_nil!.status.should eq("warn")

      # Verify custom category
      entry3 = history.find { |r| r.message == "Final boss identity revealed" }
      entry3.should_not be_nil
      entry3.not_nil!.channel.should eq("Story")
      entry3.not_nil!.tags.should contain("SPEC_SPOILER")
      entry3.not_nil!.status.should eq("spec_spoiler")

      # Verify custom category via symbol
      entry3b = history.find { |r| r.message == "Symbol custom level test" }
      entry3b.should_not be_nil
      entry3b.not_nil!.channel.should eq("Cutscene")
      entry3b.not_nil!.tags.should contain("SPEC_SPOILER")
      entry3b.not_nil!.status.should eq("spec_spoiler")

      # Verify channel helper
      entry4 = history.find { |r| r.message == "NPC dialogue triggered" }
      entry4.should_not be_nil
      entry4.not_nil!.channel.should eq("Dialogue")
      entry4.not_nil!.status.should eq("spoken")
    end

    it "supports log_public and log_secret macros" do
      Godot.log_public_info("PublicNotice", "Game servers are online")
      Godot.log_secret(:info, "Security", "Admin salt: xyz789")

      history = Godot.log_history
      pub_entry = history.find { |r| r.message == "Game servers are online" }
      pub_entry.should_not be_nil
      pub_entry.not_nil!.public?.should be_true
      pub_entry.not_nil!.status.should eq("public")

      sec_entry = history.find { |r| r.message.includes?("Admin salt") }
      sec_entry.should_not be_nil
      sec_entry.not_nil!.confidential?.should be_true
      sec_entry.not_nil!.status.should eq("secret")
    end
  end

  describe "Extensible LogFilter Registry & Delayed LogLevel Enum" do
    it "synthesizes enum values and bracketed tags dynamically" do
      Godot::LogLevel::SpecPublic.tag.should eq("{public}")
      Godot::LogLevel::SpecSecret.tag.should eq("{secret}")
      Godot::LogLevel::SpecSpoiler.tag.should eq("{spoiler}")
      Godot::LogLevel::SpecTelemetry.tag.should eq("{telemetry}")

      Godot::LogLevel::SpecPublic.name_tag.should eq("SPEC_PUBLIC")
      Godot::LogLevel::SpecSpoiler.name_tag.should eq("SPEC_SPOILER")
      Godot::LogLevel::SpecPublic.color_bbcode.should eq("#50fa7b")
    end

    it "classifies raw log lines with from_line without hardcoding" do
      line1 = "[2026-09-28] [INFO] [Quest] {spoiler} Final boss defeated"
      line2 = "[2026-09-28] [INFO] [Notice] {public} Welcome"
      line3 = "[2026-09-28] [INFO] [Raw] Untagged event"
      line4 = "Raw untagged print output"

      Godot::LogLevel.from_line(line1).should eq(Godot::LogLevel::SpecSpoiler)
      Godot::LogLevel.from_line(line2).should eq(Godot::LogLevel::SpecPublic)
      Godot::LogLevel.from_line(line3).should eq(Godot::LogLevel::Info)
      Godot::LogLevel.from_line(line4).should be_nil
      Godot::LogLevel.from_line(line4, default: Godot::LogLevel::Info).should eq(Godot::LogLevel::Info)
    end

    it "introspects all tags and name tags" do
      Godot::LogLevel.all_tags.should contain("{public}")
      Godot::LogLevel.all_tags.should contain("{secret}")
      Godot::LogLevel.all_tags.should contain("{spoiler}")
      Godot::LogLevel.all_tags.should contain("{telemetry}")
      Godot::LogLevel.all_tags.should contain("[ERROR]")
      Godot::LogLevel.all_tags.should contain("[INFO]")

      Godot::LogLevel.all_name_tags.should contain("SPEC_PUBLIC")
      Godot::LogLevel.all_name_tags.should contain("SPEC_SECRET")
      Godot::LogLevel.all_name_tags.should contain("SPEC_SPOILER")
      Godot::LogLevel.all_name_tags.should contain("SPEC_TELEMETRY")
      Godot::LogLevel.all_name_tags.should contain("ERROR")
      Godot::LogLevel.all_name_tags.should contain("INFO")
    end
  end
end
