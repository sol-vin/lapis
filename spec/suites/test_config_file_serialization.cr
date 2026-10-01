# =============================================================================
# LibGodot Test Suite: ConfigFile Parsing & Serialization
# =============================================================================

include Lapis::Test

test_suite "ConfigFile" do
  test "ConfigFile parse text, sections, and keys" do
    cf = Godot.create(Godot::ConfigFile)
    assert_not_nil cf
    assert_false cf.pointer.null?

    raw_ini = <<-INI
    [player]
    name = "Hero"
    level = 42
    speed = 12.5

    [audio]
    master_volume = 0.8
    sfx_enabled = true
    INI

    err = cf.parse(raw_ini)
    assert_eq err.value, Godot::Error::Ok.value

    assert_true cf.has_section("player")
    assert_true cf.has_section("audio")
    assert_false cf.has_section("video")

    assert_true cf.has_section_key("player", "name")
    assert_true cf.has_section_key("player", "level")
    assert_true cf.has_section_key("audio", "master_volume")
    assert_false cf.has_section_key("audio", "non_existent")

    # Erase section
    cf.erase_section("audio")
    assert_false cf.has_section("audio")
  end

  test "ConfigFile encode_to_text roundtrip" do
    cf = Godot.create(Godot::ConfigFile)
    ini_data = "[game]\ntitle = \"LapisAdventure\"\n"
    cf.parse(ini_data)
    encoded = cf.encode_to_text
    assert_true encoded.includes?("[game]")
    assert_true encoded.includes?("title")
  end
end
