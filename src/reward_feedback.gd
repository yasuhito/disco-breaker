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
	var passed: bool = state.result_visible and not previous.result_visible and state.floor_dark and bool(state.inspection.get("safe", false))
	if passed:
		kind = "finale" if state.stage_id == "graduation_3x3" else "success"
		success_count += 1
	elif cleared:
		kind = "settled"
	elif not state.floor_dark or not state.result_visible and previous.result_visible:
		kind = ""
		return "reset"
	else:
		return ""
	event_count += 1
	return kind


static func wants_sound(event: String, muted: bool, master_muted: bool = false) -> bool:
	return event in ["success", "finale"] and not muted and not master_muted
