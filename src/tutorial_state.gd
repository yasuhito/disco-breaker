class_name TutorialState
extends RefCounted

const Inspection := preload("res://src/inspection_semantics.gd")

const EMPTY := 0
const RED := 1
const BLUE := 2
const BOTH := 3

var stage_index := 0
var dialogue_visible := true
var result_visible := false
var finished := false
var corrections: PackedInt32Array = PackedInt32Array()
var inspection: Dictionary = {}
var trace: Array[Dictionary] = []
var _sequence := 0


func _init() -> void:
	_reset_stage()
	_record("launch", {})


func stages() -> Array[Dictionary]:
	return [
		{
			"id": "red_one_tap", "title": "RED: ONE TAP", "size": 3,
			"coach": "Tap the middle box once.\nMake a red wire!",
			"hidden": {4: RED}, "preset": {}, "target": 4,
			"red_checks": [[4], [4]], "blue_checks": [],
			"red_tiles": [0, 3], "blue_tiles": [],
			"red_cut": [], "blue_cut": [], "witness_red": [], "witness_blue": [],
		},
		{
			"id": "blue_two_taps", "title": "BLUE: TWO TAPS", "size": 3,
			"coach": "Tap the middle box twice.\nRed changes to blue.",
			"hidden": {4: BLUE}, "preset": {}, "target": 4,
			"red_checks": [], "blue_checks": [[4], [4]],
			"red_tiles": [], "blue_tiles": [1, 2],
			"red_cut": [], "blue_cut": [], "witness_red": [], "witness_blue": [],
		},
		{
			"id": "combined_three_taps", "title": "BOTH: THREE TAPS", "size": 3,
			"coach": "Tap the middle box 3 times.\nMake both wires cross!",
			"hidden": {4: BOTH}, "preset": {}, "target": 4,
			"red_checks": [[4], [4]], "blue_checks": [[4], [4]],
			"red_tiles": [0, 3], "blue_tiles": [1, 2],
			"red_cut": [], "blue_cut": [], "witness_red": [], "witness_blue": [],
		},
		{
			"id": "foreman_inspection", "title": "CALL FOR INSPECTION", "size": 3,
			"coach": "All dark is not always safe.\nCall me to inspect it.",
			"hidden": {4: BOTH}, "preset": {4: BOTH}, "target": -1,
			"red_checks": [[4], [4]], "blue_checks": [[4], [4]],
			"red_tiles": [0, 3], "blue_tiles": [1, 2],
			"red_cut": [0, 4, 8], "blue_cut": [2, 4, 6],
			"witness_red": [0, 4, 8], "witness_blue": [2, 4, 6],
		},
		{
			"id": "crossing_trap", "title": "THE CROSSING TRAP", "size": 3,
			"coach": "Dark floors can still leak.\nLet's inspect this one.",
			"hidden": {4: RED}, "preset": {0: RED, 8: RED}, "target": -1,
			"red_checks": [[4, 0], [4, 8]], "blue_checks": [],
			"red_tiles": [0, 3], "blue_tiles": [],
			"red_cut": [0, 4, 8], "blue_cut": [2, 4, 6],
			"witness_red": [0, 4, 8], "witness_blue": [2, 4, 6],
		},
		{
			"id": "graduation_5x5", "title": "OPTIONAL 5 × 5", "size": 5,
			"coach": "Try one full-size floor.\nStop every flicker!",
			"hidden": {12: RED, 3: BLUE, 21: RED}, "preset": {}, "target": -1,
			"red_checks": [[12], [12], [21]], "blue_checks": [[3], [3]],
			"red_tiles": [5, 10, 13], "blue_tiles": [2, 7],
			"red_cut": [0, 6, 12, 18, 24], "blue_cut": [4, 8, 12, 16, 20],
			"witness_red": [0, 6, 12, 18, 24], "witness_blue": [4, 8, 12, 16, 20],
		},
	]


func definition() -> Dictionary:
	return stages()[stage_index]


func confirm_dialogue() -> void:
	if finished:
		restart()
		return
	if not dialogue_visible:
		return
	dialogue_visible = false
	_record("confirm_dialogue", {})
	if stage_index == 4:
		inspect_floor()


func tap_node(row: int, column: int) -> bool:
	if dialogue_visible or result_visible or finished:
		return false
	var size: int = definition().size
	if row < 0 or row >= size or column < 0 or column >= size:
		return false
	var node := row * size + column
	corrections[node] = (corrections[node] + 1) % 4
	_record("tap_node", {"row": row, "column": column, "state": corrections[node]})
	if stage_index <= 2 and is_dark():
		result_visible = true
		_record("lesson_solved", {"stage": definition().id})
	return true


func can_call_foreman() -> bool:
	return not dialogue_visible and not result_visible and is_dark() and stage_index >= 3


func inspect_floor() -> Dictionary:
	if stage_index != 4 and not can_call_foreman():
		return {}
	var red := _residual_support(RED)
	var blue := _residual_support(BLUE)
	var d := definition()
	inspection = Inspection.inspect(
		red, blue,
		PackedInt32Array(d.red_cut), PackedInt32Array(d.blue_cut),
		PackedInt32Array(d.witness_red), PackedInt32Array(d.witness_blue))
	result_visible = true
	_record("inspect", inspection)
	return inspection


func next_stage() -> void:
	if not result_visible:
		return
	if stage_index == stages().size() - 1:
		finished = true
		result_visible = false
		dialogue_visible = true
		_record("tutorial_complete", {})
		return
	stage_index += 1
	_reset_stage()
	_record("next_stage", {"stage": definition().id})


func skip_graduation() -> void:
	if stage_index == 5 and not finished:
		finished = true
		result_visible = false
		dialogue_visible = true
		_record("skip_graduation", {})


func restart() -> void:
	stage_index = 0
	finished = false
	_reset_stage()
	_record("restart", {})


func is_dark() -> bool:
	return lit_red_checks().is_empty() and lit_blue_checks().is_empty()


func lit_red_checks() -> Array[int]:
	return _lit_checks(RED)


func lit_blue_checks() -> Array[int]:
	return _lit_checks(BLUE)


func semantic_state() -> Dictionary:
	var d := definition()
	var correction_values: Array[int] = []
	for value in corrections:
		correction_values.append(value)
	var last_action: Dictionary = trace[-1].duplicate(true) if not trace.is_empty() else {}
	return {
		"schema": "disco-breaker-tutorial-state.v1",
		"stage": stage_index + 1,
		"stage_id": d.id,
		"stage_count": stages().size(),
		"grid_size": d.size,
		"dialogue_visible": dialogue_visible,
		"result_visible": result_visible,
		"finished": finished,
		"corrections": correction_values,
		"lit_red": lit_red_checks(),
		"lit_blue": lit_blue_checks(),
		"floor_dark": is_dark(),
		"can_call_foreman": can_call_foreman(),
		"inspection": inspection.duplicate(true),
		"action_count": trace.size(),
		"last_action": last_action,
	}


func trace_json_lines() -> String:
	var lines: PackedStringArray = []
	for entry in trace:
		lines.append(JSON.stringify(entry))
	return "\n".join(lines) + "\n"


func _reset_stage() -> void:
	var d := definition()
	corrections = PackedInt32Array()
	corrections.resize(d.size * d.size)
	for key in d.preset:
		corrections[int(key)] = int(d.preset[key])
	dialogue_visible = true
	result_visible = false
	inspection = {}


func _lit_checks(component: int) -> Array[int]:
	var d := definition()
	var checks: Array = d.red_checks if component == RED else d.blue_checks
	var hidden: Dictionary = d.hidden
	var result: Array[int] = []
	for check_index in checks.size():
		var parity := 0
		for node in checks[check_index]:
			parity ^= 1 if (int(hidden.get(node, EMPTY)) & component) != 0 else 0
			parity ^= 1 if (corrections[node] & component) != 0 else 0
		if parity == 1:
			result.append(check_index)
	return result


func _residual_support(component: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var hidden: Dictionary = definition().hidden
	for node in corrections.size():
		var hidden_component := (int(hidden.get(node, EMPTY)) & component) != 0
		var correction_component := (corrections[node] & component) != 0
		if hidden_component != correction_component:
			result.append(node)
	return result


func _record(action: String, payload: Dictionary) -> void:
	_sequence += 1
	trace.append({
		"sequence": _sequence,
		"action": action,
		"payload": payload.duplicate(true),
		"stage_id": definition().id,
		"floor_dark": is_dark(),
	})
