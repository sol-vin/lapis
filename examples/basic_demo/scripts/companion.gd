extends Node
class_name CompanionBot

var companion_name: String = "Crystal Bot"
var bonus_multiplier: float = 1.5
var interaction_count: int = 0

func calculate_bonus(score: int) -> int:
	return int(score * bonus_multiplier)

static func get_system_status() -> String:
	return "Companion online and ready"

func cheer(current_score: int) -> String:
	interaction_count += 1
	if current_score > 300:
		return "Incredible score! You're a master Crystal Hunter!"
	elif current_score > 0:
		return "Great job! Keep collecting those shining crystals!"
	else:
		return "Let's explore together! Collect the floating crystals nearby!"

func praise_player(player_name: String) -> String:
	return "Hero " + player_name + ", Crystal power is with you!"
