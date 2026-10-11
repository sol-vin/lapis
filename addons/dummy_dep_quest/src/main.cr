require "../../dummy_base_dep/src/dummy_base_dep"
ensure_lapis

# =============================================================================
# Dummy Dep Quest: Quest & Objective Subsystem Plugin depending on dummy_base_dep
# =============================================================================

# Quest entity mixing in DummyBaseMixin and utilizing DummyBaseUtils
@[Tool]
node DummyQuestEntity < Node2D do
  include DummyBaseMixin

  # Name of active quest
  @[Export]
  property current_quest : String = "IntroQuest"

  # Fractional completion percentage from 0.0 to 1.0
  @[Export]
  property quest_progress : Float64 = 0.0

  # Emitted when progress is made towards quest completion
  signal quest_advanced(quest_name : String, progress : Float64)

  # Emitted when a quest is fully finished
  signal quest_completed(quest_name : String)

  def advance_quest(delta_progress : Float64) : Float64
    @quest_progress = Math.min(1.0, @quest_progress + delta_progress)
    quest_advanced.emit(@current_quest, @quest_progress)

    if @quest_progress >= 1.0
      quest_completed.emit(@current_quest)
    end

    @quest_progress
  end

  def format_quest_log(action : String) : String
    DummyBaseUtils.format_action("Quest", action)
  end

  def quest_status : String
    "QuestEntity[quest=#{@current_quest},progress=#{@quest_progress},tag=#{@shared_tag}]"
  end
end

# Editor plugin for quest system
@[Tool]
node DummyQuestPlugin < EditorPlugin do
  signal quest_system_ready

  def _enter_tree : Void
    quest_system_ready.emit
    Godot.print("[DummyQuestPlugin] Initialized successfully in editor!")
  end

  def _exit_tree : Void
    Godot.print("[DummyQuestPlugin] Deinitialized.")
  end
end
