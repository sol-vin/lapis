# tools/lapis/spec/docs_indexer_spec.cr
require "./spec_helper"
require "../src/docs/model"
require "../src/docs/indexer"

describe Lapis::Docs do
  it "parses context strings correctly" do
    Lapis::Docs::Context.parse?("gd").should eq(Lapis::Docs::Context::Godot)
    Lapis::Docs::Context.parse?("godot").should eq(Lapis::Docs::Context::Godot)
    Lapis::Docs::Context.parse?("crystal").should eq(Lapis::Docs::Context::Crystal)
    Lapis::Docs::Context.parse?("cr").should eq(Lapis::Docs::Context::Crystal)
    Lapis::Docs::Context.parse?("stdlib").should eq(Lapis::Docs::Context::Stdlib)
    Lapis::Docs::Context.parse?("std").should eq(Lapis::Docs::Context::Stdlib)
    Lapis::Docs::Context.parse?("guide").should eq(Lapis::Docs::Context::Guide)
    Lapis::Docs::Context.parse?("docs").should eq(Lapis::Docs::Context::Guide)
    Lapis::Docs::Context.parse?("unknown_context").should be_nil
  end

  it "indexes symbols and performs context-aware lookup" do
    indexer = Lapis::Docs::Indexer.new

    # Add mock symbols across different contexts
    indexer.add_symbol(Lapis::Docs::DocSymbol.new(
      context: Lapis::Docs::Context::Godot,
      kind: Lapis::Docs::SymbolKind::Method,
      name: "move_and_slide",
      full_query: "CharacterBody3D.move_and_slide",
      signature: "func move_and_slide() -> bool",
      summary: "Moves the body based on velocity.",
      description: "Moves the body based on velocity in Godot.",
      parent_name: "CharacterBody3D",
      return_type: "bool"
    ))

    indexer.add_symbol(Lapis::Docs::DocSymbol.new(
      context: Lapis::Docs::Context::Crystal,
      kind: Lapis::Docs::SymbolKind::Method,
      name: "move_and_slide",
      full_query: "CharacterBody3D#move_and_slide",
      signature: "def move_and_slide : Bool",
      summary: "Crystal typed wrapper for Godot CharacterBody3D#move_and_slide.",
      description: "Crystal typed wrapper description.",
      parent_name: "CharacterBody3D",
      return_type: "Bool"
    ))

    indexer.add_symbol(Lapis::Docs::DocSymbol.new(
      context: Lapis::Docs::Context::Stdlib,
      kind: Lapis::Docs::SymbolKind::Class,
      name: "Channel",
      full_query: "Channel",
      signature: "class Channel(T)",
      summary: "A Channel enables concurrent communication between fibers.",
      description: "Standard library Channel."
    ))

    indexer.add_symbol(Lapis::Docs::DocSymbol.new(
      context: Lapis::Docs::Context::Guide,
      kind: Lapis::Docs::SymbolKind::Guide,
      name: "Concurrency Safety & Fibers",
      full_query: "concurrency",
      signature: "guide:concurrency",
      summary: "Guide covering thread safety, fibers, channels, and dead-pointer prevention.",
      description: "Full guide content on concurrency."
    ))

    # Exact lookup with Godot context
    gd_hit = indexer.find_exact("CharacterBody3D.move_and_slide", context: Lapis::Docs::Context::Godot)
    gd_hit.should_not be_nil
    if gd_hit
      gd_hit.context.should eq(Lapis::Docs::Context::Godot)
      gd_hit.signature.should eq("func move_and_slide() -> bool")
    end

    # Exact lookup with Crystal context
    cr_hit = indexer.find_exact("CharacterBody3D#move_and_slide", context: Lapis::Docs::Context::Crystal)
    cr_hit.should_not be_nil
    if cr_hit
      cr_hit.context.should eq(Lapis::Docs::Context::Crystal)
      cr_hit.signature.should eq("def move_and_slide : Bool")
    end

    # Stdlib lookup
    std_hit = indexer.find_exact("Channel", context: Lapis::Docs::Context::Stdlib)
    std_hit.should_not be_nil
    if std_hit
      std_hit.context.should eq(Lapis::Docs::Context::Stdlib)
      std_hit.signature.should eq("class Channel(T)")
    end

    # Guide lookup
    guide_hit = indexer.find_exact("concurrency", context: Lapis::Docs::Context::Guide)
    guide_hit.should_not be_nil
    if guide_hit
      guide_hit.context.should eq(Lapis::Docs::Context::Guide)
      guide_hit.name.should eq("Concurrency Safety & Fibers")
    end

    # Search with fuzzy filtering
    results = indexer.search("move", context: Lapis::Docs::Context::Godot)
    results.size.should be >= 1
    results.all? { |r| r.context == Lapis::Docs::Context::Godot }.should be_true
  end
end
