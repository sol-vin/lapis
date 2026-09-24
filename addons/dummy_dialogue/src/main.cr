require "lapis"

# Interactive dialogue box UI control rendering narrator and character dialogue
@[Tool]
node DialogueBox < Control do
  # Name of the active speaker currently delivering dialogue
  @[Export]
  property speaker_name : String = "Narrator"

  # Current dialogue text content displayed in the dialogue panel
  @[Export]
  property dialogue_text : String = "Welcome to LibGodot multi-addon test!"

  # Emitted when the current dialogue line finishes rendering
  signal line_finished(speaker : String)

  # Advances the dialogue box to display the specified line of text
  def advance_line(new_text : String) : Void
    @dialogue_text = new_text
    emit_line_finished(@speaker_name)
  end
end

# Editor plugin providing narrative dialogue graph inspection and validation tools
@[Tool]
node DummyDialoguePlugin < EditorPlugin do
  # Tracks whether the narrative dialogue editor dock is currently open
  @[Export]
  property editor_panel_open : Bool = false

  # Emitted when dialogue script validation completes
  signal dialogue_validated(file_path : String, is_valid : Bool)

  # Opens the dialogue authoring dock inside the Godot editor workspace
  def open_dialogue_editor : Void
    @editor_panel_open = true
    Godot.print("[DummyDialoguePlugin] Dialogue authoring workspace opened.")
  end

  # Validates syntax and narrative branching for a dialogue script file
  def validate_dialogue_file(file_path : String) : Bool
    is_valid = !file_path.empty?
    emit_dialogue_validated(file_path, is_valid)
    Godot.print("[DummyDialoguePlugin] Validated dialogue file '#{file_path}': #{is_valid}")
    is_valid
  end

  def _enter_tree : Void
    Godot.print("[DummyDialoguePlugin] Initialized successfully in editor!")
  end

  def _exit_tree : Void
    Godot.print("[DummyDialoguePlugin] Deinitialized.")
  end
end
