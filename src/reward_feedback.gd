class_name RewardFeedback
extends RefCounted

# Edge-triggered presentation events. No timer or random value decides success.
var event_count := 0
var success_count := 0
var kind := ""
var _previous: Dictionary = {}


func observe(state: Dictionary) -> String:
	if not _previous.is_empty() and int(state.action_count) == int(_previous.action_count):
		return ""
	var previous := _previous
	_previous = state.duplicate(true)
	if previous.is_empty():
		return ""
	if state.stage_id != previous.stage_id or state.boundary_phase != previous.boundary_phase or state.finished != previous.finished or state.last_action.action == "restart":
		kind = ""
		return "reset"
	var cleared: bool = not previous.floor_dark and state.floor_dark
	var passed: bool = state.passed and not previous.passed
	if passed:
		kind = "finale" if state.stage_id == "graduation_3x3" else "success"
		success_count += 1
	elif cleared:
		kind = "settled"
	elif not state.floor_dark or not state.passed and previous.passed:
		kind = ""
		return "reset"
	else:
		return ""
	event_count += 1
	return kind


# Which sting a verified success plays: lesson 1 has its own approved bell
# (assets/sounds/lesson1_success_bell.wav); the final practice keeps the
# longer finale and every other lesson the default sting.
static func sound_for(event: String, stage_id: String) -> String:
	if event == "finale":
		return "finale"
	if event == "success":
		return "lesson1_bell" if stage_id == "red_one_tap" else "sting"
	return ""


static func wants_sound(event: String, muted: bool, master_muted: bool = false) -> bool:
	return event in ["success", "finale"] and not muted and not master_muted
