extends SceneTree

const Tutorial := preload("res://src/tutorial_state.gd")
const Inspection := preload("res://src/inspection_semantics.gd")
const Leaks := preload("res://src/leak_feedback.gd")
const LampGate := preload("res://src/lamp_sound_gate.gd")
const Rewards := preload("res://src/reward_feedback.gd")
const Sounds := preload("res://src/reward_sound.gd")
const Flicker := preload("res://src/fault_flicker.gd")
const Lesson := preload("res://src/lesson_artwork.gd")


# Keep the earlier 5x5 adjacency regression as a test fixture, not a game mode.
class RegressionFloor:
	extends "res://src/tutorial_state.gd"

	func definition() -> Dictionary:
		return _with_geometry({"id": "regression_5x5", "size": 5, "inspect": "call",
			"hidden": {12: RED, 3: BLUE, 21: RED}, "preset": {}, "target": -1,
			"lines": {"open": "", "lit": "", "ok": ""}})

var failures: Array[String] = []


func _init() -> void:
	_test_tap_cycle()
	_test_three_guided_lessons()
	_test_allowed_actions()
	_test_edit_after_pass_invalidates()
	_test_independent_crossing_parity()
	_test_crossing_trap_observe_then_repair()
	_test_crossing_trap_alternatives()
	_test_crossing_trap_fixed_before_inspection()
	_test_graduation()
	_test_boundary_lesson()
	_test_final_skip_and_replay()
	_test_full_flow_trace()
	_test_surface_code_geometry()
	_test_screenshot_move()
	_test_logical_classes()
	_test_semantic_contract()
	_test_latest_utterance()
	_test_leak_lines_follow_inspection()
	_test_foreman_copy_fits_bubble()
	_test_reference_pairs()
	_test_exhaustive_pass_parity()
	_test_fault_flicker()
	_test_reward_events()
	_test_unsafe_rewards_and_retry()
	_test_reward_audio()
	_test_leak_events()
	_test_residual_routes()
	_test_original_fault_xor()
	_test_lamp_sound_gate()
	_test_electrical_sounds()
	_test_color_families_and_wire_directions()
	if failures.is_empty():
		print("PASS: 31 tutorial tests")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _at(stage: int, phase := 0) -> Tutorial:
	var model := Tutorial.new()
	model.stage_index = stage
	model.boundary_phase = phase
	model._reset_stage()
	return model


# Tap from the current board to the given wiring (each box at most 3 taps).
func _wire(model: Tutorial, wiring: Dictionary) -> int:
	var taps := 0
	for node in model.corrections.size():
		var goal := int(wiring.get(node, wiring.get(str(node), 0)))
		while model.corrections[node] != goal:
			model.tap_node(int(node / 3.0), node % 3)
			taps += 1
	return taps


func _test_tap_cycle() -> void:
	var model := Tutorial.new()
	for expected in [Tutorial.RED, Tutorial.BLUE, Tutorial.BOTH, Tutorial.EMPTY]:
		_expect(model.tap_node(1, 1), "the board accepts taps at once, without a dialogue gate")
		_expect(model.corrections[4] == expected, "tap cycle expected %d" % expected)


func _test_three_guided_lessons() -> void:
	var model := Tutorial.new()
	for taps in [1, 2, 3]:
		_expect(not model.can_continue() and not model.can_call_foreman(), "guided stage %d starts with Continue disabled" % taps)
		for tap in taps:
			_expect(not model.passed(), "intermediate taps never pass")
			model.tap_node(1, 1)
		_expect(model.is_dark() and model.inspection.safe and model.passed(), "guided stage %d is inspected automatically when dark" % taps)
		_expect(model.trace[-1].action == "inspect" and bool(model.trace[-1].payload.auto), "automatic inspection is recorded")
		_expect(model.next_stage(), "Continue advances a passed lesson")
	_expect(model.stage_index == 3, "three guided lessons lead to the inspection lesson")


func _test_allowed_actions() -> void:
	var auto := Tutorial.new()
	_expect(auto.inspect_floor().is_empty(), "auto lessons have no foreman call")
	_expect(not auto.next_stage() and auto.stage_index == 0, "Continue is disabled before a pass")
	_expect(not auto.skip_graduation() and not auto.finished, "skip exists only in the optional practice")
	_expect(not auto.tap_node(3, 0) and not auto.tap_node(0, -1), "taps outside the board are rejected")
	var count := auto.trace.size()
	auto.next_stage()
	auto.inspect_floor()
	_expect(auto.trace.size() == count, "rejected commands leave no trace")
	var call := _at(3)
	_expect(call.can_call_foreman(), "the inspection lesson starts dark and callable")
	call.tap_node(1, 1)
	_expect(not call.is_dark() and not call.can_call_foreman() and call.inspect_floor().is_empty(), "a lit floor cannot be inspected")
	for tap in 3:
		call.tap_node(1, 1)
	_expect(not call.inspect_floor().is_empty(), "a dark floor can be inspected")
	_expect(not call.can_call_foreman() and call.inspect_floor().is_empty(), "the same board is not inspected twice")
	var finished := _at(6)
	finished.skip_graduation()
	_expect(not finished.tap_node(1, 1) and finished.inspect_floor().is_empty() and not finished.next_stage(), "a finished tutorial accepts only replay")
	# A function value on a lit floor never enables completion.
	var lit := _at(1)
	lit.tap_node(1, 1)
	_expect(lit._inspect_residual().safe and not lit.is_dark(), "the lit intermediate board reads safe in isolation")
	_expect(not lit.passed() and not lit.can_continue() and lit.inspection.is_empty(), "a safe reading on a lit floor cannot enable completion")


func _test_edit_after_pass_invalidates() -> void:
	var guided := Tutorial.new()
	guided.tap_node(1, 1)
	_expect(guided.can_continue(), "guided lesson passes")
	guided.tap_node(0, 0)
	_expect(not guided.can_continue() and guided.inspection.is_empty(), "editing after a pass disables Continue")
	for tap in 3:
		guided.tap_node(0, 0)
	_expect(guided.can_continue(), "restoring the repair re-inspects and passes again")
	var call := _at(3)
	call.inspect_floor()
	_expect(call.can_continue(), "inspection lesson passes after calling the foreman")
	for tap in 4:
		call.tap_node(0, 0)
	_expect(call.corrections == PackedInt32Array([0, 0, 0, 0, 3, 0, 0, 0, 0]), "cycling restores the board")
	_expect(not call.can_continue() and call.can_call_foreman(), "any change after inspection needs a new inspection")


func _test_independent_crossing_parity() -> void:
	var cut := PackedInt32Array([0, 4, 8])
	var none := Inspection.inspect(PackedInt32Array([0, 4]), PackedInt32Array(), cut, cut)
	var red := Inspection.inspect(PackedInt32Array([0, 4, 8]), PackedInt32Array(), cut, cut, cut, cut)
	var blue := Inspection.inspect(PackedInt32Array(), PackedInt32Array([0]), cut, cut, cut, cut)
	var both := Inspection.inspect(PackedInt32Array([0]), PackedInt32Array([8]), cut, cut, cut, cut)
	_expect(none.safe, "even crossings must cancel mod 2")
	_expect(red.red_crossing and not red.blue_crossing, "red class must be independent")
	_expect(blue.blue_crossing and not blue.red_crossing, "blue class must be independent")
	_expect(both.red_crossing and both.blue_crossing, "both odd classes must survive")
	_expect(red.red_witness == [0, 4, 8], "witness should explain computed odd red class")


func _test_crossing_trap_observe_then_repair() -> void:
	var model := _at(4)
	_expect(model.is_dark() and model.can_call_foreman() and not model.fault_revealed(), "the trap looks cleared and hides its fault before inspection")
	_expect(model.utterance().text == "これも全部暗い。\n親方を呼ぼう。", "the trap opens by asking for the foreman")
	var verdict := model.inspect_floor()
	_expect(verdict.red_crossing and not verdict.blue_crossing and not verdict.safe, "trap keeps its odd red class only")
	_expect(not model.passed() and not model.can_continue() and not model.next_stage(), "the first inspection is a leak, not a pass")
	_expect(model.utterance().kind == "unsafe" and model.utterance().text.begins_with("漏電あり！床は2本で暗い。"), "the explanation describes the trap")
	_expect(model.fault_revealed() and not model.can_call_foreman(), "the leak reveals the fault; the call waits for a change")
	model.tap_node(0, 1)
	_expect(not model.is_dark() and model.fault_revealed(), "repairs keep the original fault visible in lesson 5")
	_expect(model.utterance().text == "光る床がある。\n破線と同じにしよう。", "lit repair hint refers to the dashed fault")
	var taps := 1 + _wire(model, {4: Tutorial.RED})
	_expect(taps == 7, "the canonical repair matches the fault in seven taps")
	_expect(model.is_dark() and model.can_call_foreman() and model.utterance().text == "暗くなった。\nもう一度親方を呼ぼう。", "a dark repair asks for another inspection")
	_expect(model.inspect_floor().safe and model.can_continue(), "a repaired, inspected trap passes")
	_expect(model.utterance().text == "検査合格！\n漏電が直った。", "the pass is announced")
	model.next_stage()
	_expect(model.definition().id == "boundary_single" and not model.fault_revealed(), "the next lesson hides the fault again")


func _test_crossing_trap_alternatives() -> void:
	var followup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/flow_followup.json"))
	var boards: Array = followup.s5_min_boards
	_expect(boards.size() == 3 and int(followup.s5_min_taps_to_dark_and_safe) == 3, "fixture: three minimal repairs")
	for board in boards:
		var model := _at(4)
		model.inspect_floor()
		var wiring := {}
		for node in 9:
			wiring[node] = int(board[node])
		var taps := _wire(model, wiring)
		_expect(taps == 3, "minimal alternative repair takes three taps")
		_expect(model.is_dark() and model.inspect_floor().safe and model.can_continue(), "a three-tap alternative passes the same inspection: %s" % [board])
	var loop := _at(4)
	loop.inspect_floor()
	_wire(loop, {1: Tutorial.RED, 2: Tutorial.RED, 5: Tutorial.RED})
	_expect(loop.inspect_floor().safe and loop.can_continue(), "the loop-shaped leftover passes")
	_expect(Array(loop._residual_support(Tutorial.RED)) == [1, 2, 4, 5], "the loop keeps its leftovers")
	var again := _at(4)
	again.inspect_floor()
	again.tap_node(0, 0)
	for tap in 3:
		again.tap_node(0, 0)
	_expect(not again.inspect_floor().safe and again.utterance().text == "まだ漏電。\n赤い線が上から下へ。", "a second leak says it is still leaking")


func _test_crossing_trap_fixed_before_inspection() -> void:
	# Repairing before ever calling the foreman is allowed: the first
	# inspection of the repaired, dark board passes. No unsafe step is forced.
	var model := _at(4)
	model.tap_node(0, 1)
	_expect(model.utterance().text == "光る床がある。\n暗くしてから呼んでね。" and not model.fault_revealed(), "no fault reveal or dashed hint before an inspection")
	_wire(model, {4: Tutorial.RED})
	_expect(model.utterance().text == "これも全部暗い。\n親方を呼ぼう。", "a dark board asks for the first inspection")
	_expect(model.inspect_floor().safe and model.can_continue() and not model.leak_seen, "a pass without a prior leak is accepted")


func _test_graduation() -> void:
	var model := _at(6)
	_expect(model.definition().size == 3 and model.corrections.size() == 9, "final practice is 3x3")
	_expect(model.definition().target == -1, "final practice has no hint ring")
	model.tap_node(1, 1)
	_expect(not model.can_call_foreman(), "foreman call is disabled while lit")
	model.tap_node(0, 2)
	model.tap_node(0, 2)
	_expect(model.is_dark() and model.can_call_foreman(), "foreman should enable only after clear")
	_expect(model.inspect_floor().safe and model.can_continue(), "graduation repair should be safe")
	model.next_stage()
	_expect(model.finished and not model.skipped and model.utterance().kind == "done", "graduation completes the tutorial")
	_expect(model.progress() == 1.0, "progress is full at the end")


func _test_final_skip_and_replay() -> void:
	var model := _at(6)
	model.skip_graduation()
	_expect(model.finished and model.skipped, "final practice can be skipped unsolved")
	_expect(not model.passed() and model.inspection.is_empty(), "skip is not a pass")
	_expect(model.utterance().text == Tutorial.SKIPPED_TEXT, "the skip is not announced as a completion of all lessons")
	model.restart()
	_expect(not model.finished and not model.skipped and model.stage_index == 0 and not model.touched, "replay starts the tutorial again")


func _test_full_flow_trace() -> void:
	var model := Tutorial.new()
	var progress: Array[float] = [model.progress()]
	model.tap_node(1, 1)
	model.next_stage()
	_wire(model, {4: Tutorial.BLUE})
	model.next_stage()
	_wire(model, {4: Tutorial.BOTH})
	model.next_stage()
	progress.append(model.progress())
	model.inspect_floor()
	model.next_stage()
	model.inspect_floor()
	_wire(model, {4: Tutorial.RED})
	model.inspect_floor()
	model.next_stage()
	model.tap_node(0, 0)
	model.next_stage()
	progress.append(model.progress())
	_wire(model, {2: Tutorial.BLUE})
	model.next_stage()
	_wire(model, {4: Tutorial.RED, 2: Tutorial.BLUE})
	model.inspect_floor()
	model.next_stage()
	progress.append(model.progress())
	_expect(model.finished, "all seven lessons complete through public commands")
	_expect(progress == [0.0, 3.0 / 7.0, 5.5 / 7.0, 1.0], "progress follows lessons and the boundary half")
	var actions := {}
	for entry in model.trace:
		actions[entry.action] = true
		_expect(entry.action != "confirm_dialogue", "the dialogue gate is gone")
	for action in ["launch", "tap_node", "inspect", "next_stage", "boundary_blue", "tutorial_complete"]:
		_expect(actions.has(action), "trace records %s" % action)


func _test_semantic_contract() -> void:
	var state := Tutorial.new().semantic_state()
	for key in ["schema", "stage", "stage_id", "stage_count", "boundary_phase", "title", "grid_size", "inspection_mode", "target",
			"finished", "skipped", "corrections", "lit_red", "lit_blue", "floor_dark", "inspected", "inspection", "passed",
			"can_call_foreman", "can_continue", "fault_revealed", "leak_seen", "utterance", "progress", "action_count", "last_action"]:
		_expect(state.has(key), "semantic state missing %s" % key)
	for removed in ["dialogue_visible", "result_visible"]:
		_expect(not state.has(removed), "semantic state no longer has %s" % removed)
	_expect(String(state.schema) == "disco-breaker-tutorial-state.v2", "semantic schema version")
	var modes: Array[String] = []
	var model := Tutorial.new()
	for stage in model.stages():
		modes.append(String(stage.inspect))
	_expect(modes == ["auto", "auto", "auto", "call", "call", "auto", "call"], "lessons 1-3 and 6 inspect automatically; 4, 5 and 7 call the foreman")
	var ids: Array[String] = []
	for stage in model.stages():
		ids.append(String(stage.id))
	_expect(ids == ["red_one_tap", "blue_two_taps", "combined_three_taps", "foreman_inspection", "crossing_trap", "boundary_single", "graduation_3x3"], "stage ids and order are unchanged")


func _test_latest_utterance() -> void:
	var model := Tutorial.new()
	_expect(model.utterance() == {"kind": "start", "text": "中央を1回タップ。\n赤い配線にしよう！"}, "lesson opens with its instruction")
	model.tap_node(0, 0)
	_expect(model.utterance() == {"kind": "mistake", "text": Tutorial.LIT_GENERIC}, "a mistake replaces the instruction (no stale hint about the centre)")
	model.tap_node(0, 0)
	model.tap_node(0, 0)
	model.tap_node(0, 0)
	_expect(model.utterance().text == Tutorial.LIT_HINTS.red_one_tap, "the centre hint returns once it describes the board")
	model.tap_node(1, 1)
	_expect(model.utterance() == {"kind": "safe", "text": "いいぞ！ 点滅が消えた。"}, "a pass replaces the hint")
	model.next_stage()
	_expect(model.utterance().kind == "start" and model.utterance().text.begins_with("中央を2回"), "the next lesson replaces the praise")
	model.tap_node(1, 1)
	_expect(model.utterance().text == Tutorial.LIT_HINTS.blue_two_taps, "the red-first hint follows the board")
	model.tap_node(0, 0)
	_expect(model.utterance().text == Tutorial.LIT_GENERIC, "the red-first hint is withdrawn when it no longer applies")
	var both := _at(2)
	both.tap_node(1, 1)
	_expect(both.utterance().text == Tutorial.LIT_HINTS.combined_three_taps, "one colour placed")
	both.tap_node(1, 1)
	_expect(both.utterance().text == Tutorial.LIT_HINTS.combined_three_taps, "still one colour placed")
	var final_lesson := _at(6)
	_wire(final_lesson, {4: Tutorial.RED, 2: Tutorial.BLUE})
	_expect(final_lesson.utterance() == {"kind": "ready", "text": "暗くなった。\n親方を呼ぼう。"}, "a dark practice floor asks for the foreman")


func _test_leak_lines_follow_inspection() -> void:
	var cases := [
		[0, {1: 1, 7: 1}, "暗いけど漏電！\n赤い線が上から下へ。"],
		[1, {3: 2, 5: 2}, "暗いけど漏電！\n青い線が左から右へ。"],
		[2, {1: 1, 3: 2, 5: 2, 7: 1}, "暗いけど漏電！\n赤も青も抜けている。"],
		[5, {3: 1, 6: 1}, "暗いけど漏電！\n赤い線が上から下へ。"],
		[6, {1: 1, 2: 2, 7: 1}, "漏電あり！\n赤い線が上から下へ。"],
		[6, {0: 2, 1: 2, 4: 1}, "漏電あり！\n青い線が左から右へ。"],
		[6, {0: 2, 1: 3, 7: 1}, "漏電あり！\n赤も青も抜けている。"],
		[3, {1: 1, 4: 2, 7: 1}, "漏電あり！\n赤い線が上から下へ。"],
	]
	for case in cases:
		var model := _at(case[0])
		_wire(model, case[1])
		if not model.auto_inspects():
			model.inspect_floor()
		_expect(model.is_dark() and not model.inspection.is_empty() and not model.inspection.safe, "fixture board leaks: %s" % [case])
		_expect(model.utterance() == {"kind": "unsafe", "text": case[2]}, "leak line names the colours the inspection found: %s" % [case])
		_expect(not model.can_continue() and model.fault_revealed(), "a leak keeps Continue disabled and shows the fault")
		model.tap_node(2, 2)
		_expect(model.inspection.is_empty() and not model.fault_revealed() and model.utterance().kind == "mistake", "a change clears the stale verdict and its explanation")


func _test_foreman_copy_fits_bubble() -> void:
	var regular := preload("res://assets/fonts/NotoSansJP-Regular.otf")
	var bold := preload("res://assets/fonts/NotoSansJP-Bold.tres")
	var copy: Array[String] = [Tutorial.DONE_TEXT, Tutorial.SKIPPED_TEXT, Tutorial.LIT_GENERIC]
	for hint in Tutorial.LIT_HINTS.values():
		copy.append(hint)
	for prefix in [Tutorial.LEAK_AUTO, Tutorial.LEAK_CALL, Tutorial.LEAK_AGAIN]:
		for color in Tutorial.LEAK_COLOR.values():
			copy.append(prefix + color)
	for phase in 2:
		var model := Tutorial.new()
		model.boundary_phase = phase
		for stage in model.stages():
			for line in stage.lines.values():
				copy.append(String(line))
	# The bubble holds three 24 px lines in its 114-unit text column, also in bold.
	for text in copy:
		var lines := text.split("\n")
		_expect(lines.size() <= 3, "utterance exceeds three lines: %s" % text)
		for line in lines:
			for font in [regular, bold]:
				_expect(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= 228.0, "utterance line is wider than the bubble: %s" % line)
		for character in text:
			if character != "\n":
				_expect(regular.has_char(character.unicode_at(0)), "bundled font lacks glyph: %s" % character)
	for path in ["res://src/tutorial_state.gd", "res://src/tutorial_view.gd", "res://src/lesson_artwork.gd", "res://src/title_artwork.gd"]:
		for character in FileAccess.get_file_as_string(path):
			if character.unicode_at(0) >= 0x3000:
				_expect(regular.has_char(character.unicode_at(0)), "bundled font lacks UI glyph: %s" % character)


# The proposal's Godot-verified boards, replayed through the real flow.
func _test_reference_pairs() -> void:
	var pairs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/flow_pairs.json"))
	var followup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/flow_followup.json"))
	var stage_of := {"red_one_tap": 0, "blue_two_taps": 1, "combined_three_taps": 2, "foreman_inspection": 3, "crossing_trap": 4, "boundary_single": 5, "graduation_3x3": 6}
	var extra := {"s3": 2, "s6": 5, "s7": 6, "s4": 3}
	var boards: Array = []
	for pair in pairs:
		boards.append([int(stage_of[pair.stage_id]), int(pair.boundary_phase), pair.wiring, pair])
	for case in followup.cases:
		boards.append([int(extra[String(case.case).substr(0, 2)]), 0, case.wiring, case])
	_expect(boards.size() == 25, "fixture boards loaded")
	for board in boards:
		var model := _at(board[0], board[1])
		_wire(model, board[2])
		var expected: Dictionary = board[3]
		var name := String(expected.case)
		_expect(model.is_dark() == bool(expected.dark), "%s: dark" % name)
		_expect(_ints(model._residual_support(Tutorial.RED)) == _ints(expected.red_residual) and _ints(model._residual_support(Tutorial.BLUE)) == _ints(expected.blue_residual), "%s: leftovers" % name)
		if expected.has("lit_red"):
			_expect(_ints(model.lit_red_checks()) == _ints(expected.lit_red) and _ints(model.lit_blue_checks()) == _ints(expected.lit_blue), "%s: lit floors" % name)
		var verdict := model._inspect_residual()
		_expect(verdict.safe == expected.safe and verdict.red_crossing == expected.red_crossing and verdict.blue_crossing == expected.blue_crossing, "%s: inspection" % name)
		if not model.auto_inspects() and model.can_call_foreman():
			model.inspect_floor()
		_expect(model.can_continue() == (bool(expected.dark) and bool(expected.safe)), "%s: Continue iff dark and safe" % name)


func _ints(values) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	return result


# Exhaustive: on every floor, for every wiring, the flow passes exactly when
# the floor is dark and both leftover families cross their inspection line an
# even number of times (computed here independently of the model).
func _test_exhaustive_pass_parity() -> void:
	var floors := [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [5, 1], [6, 0]]
	var mismatches := 0
	var counts := {}
	for floor in floors:
		var model := _at(floor[0], floor[1])
		var d := model.definition()
		var dark_safe := 0
		for code in 1 << 18:
			var red_cut := 0
			var blue_cut := 0
			for node in 9:
				var value := (code >> (2 * node)) & 3
				model.corrections[node] = value
				var hidden := int(d.hidden.get(node, 0))
				if node < 3 and ((hidden ^ value) & 1):
					red_cut ^= 1
				if node % 3 == 0 and ((hidden ^ value) & 2):
					blue_cut ^= 1
			var dark := model.is_dark()
			model.inspection = model._inspect_residual() if dark else {}
			var expected := dark and red_cut == 0 and blue_cut == 0
			if model.can_continue() != expected or (dark and bool(model.inspection.safe) != (red_cut == 0 and blue_cut == 0)):
				mismatches += 1
			dark_safe += 1 if expected else 0
		counts["%d/%d" % floor] = dark_safe
	_expect(mismatches == 0, "Continue is enabled exactly for dark and safe boards (%d mismatches)" % mismatches)
	for key in counts:
		_expect(counts[key] == 256, "each floor has 256 dark and safe wirings (%s: %d)" % [key, counts[key]])


func _test_surface_code_geometry() -> void:
	var model := RegressionFloor.new()
	for size in [3, 5]:
		var reds := model._faces(size, Tutorial.RED)
		var blues := model._faces(size, Tutorial.BLUE)
		_expect(reds.size() + blues.size() == size * size - 1, "full code includes boundary checks")
		# Every X-check and Z-check must commute, including at boundaries.
		for red in reds:
			for blue in blues:
				var overlap := 0
				for node in red.nodes:
					if blue.nodes.has(node):
						overlap += 1
				_expect(overlap % 2 == 0, "opposite checks commute at size %d" % size)
	model._reset_stage()
	# Exhaustively verify every connection point for red, blue and both.
	for node in 25:
		for value in [Tutorial.RED, Tutorial.BLUE, Tutorial.BOTH]:
			model.corrections.fill(0)
			var before_red := model.lit_red_checks()
			var before_blue := model.lit_blue_checks()
			model.corrections[node] = value
			for component in [Tutorial.RED, Tutorial.BLUE]:
				var faces: Array = model.definition().red_faces if component == Tutorial.RED else model.definition().blue_faces
				var before := before_red if component == Tutorial.RED else before_blue
				var after := model.lit_red_checks() if component == Tutorial.RED else model.lit_blue_checks()
				for index in faces.size():
					var flips: bool = (value & component) != 0 and faces[index].nodes.has(node)
					_expect((before.has(index) != after.has(index)) == flips, "only incident checks flip")


func _test_screenshot_move() -> void:
	var model := RegressionFloor.new()
	model._reset_stage()
	# Red face 1 is upper-right of node 7; face 2 is lower-left.
	var before := model.lit_red_checks()
	var blue_before := model.lit_blue_checks()
	model.tap_node(1, 2)
	var after := model.lit_red_checks()
	_expect(not before.has(1) and after.has(1), "screenshot move lights the previously dark red floor")
	_expect(before.has(2) and not after.has(2), "screenshot move clears the adjacent lit red floor")
	_expect(model.lit_blue_checks() == blue_before, "red move preserves blue syndrome")
	# When both endpoints are lit, the very same move clears both immediately.
	model.corrections.fill(0)
	model.corrections[12] = Tutorial.RED
	model.corrections[21] = Tutorial.RED
	for node in [1, 2, 6]:
		model.corrections[node] = Tutorial.RED
	_expect(model.lit_red_checks() == [1, 2], "two-red regression setup")
	model.tap_node(1, 2) # EMPTY -> RED cancels the two incident red checks.
	_expect(model.lit_red_checks().is_empty(), "both red flickers disappear without inspection")


func _test_logical_classes() -> void:
	for component in [Tutorial.RED, Tutorial.BLUE]:
		var model := RegressionFloor.new()
		model._reset_stage()
		for key in model.definition().hidden:
			model.corrections[int(key)] = int(model.definition().hidden[key])
		# Full column of X or full row of Z is an undetectable logical string.
		for i in 5:
			var node := i * 5 + 2 if component == Tutorial.RED else 10 + i
			model.corrections[node] ^= component
		_expect(model.is_dark(), "logical string has zero syndrome")
		var verdict := model.inspect_floor()
		_expect(not verdict.safe, "logical string fails despite a dark floor")
		_expect(bool(verdict.red_crossing) == (component == Tutorial.RED), "logical X family")
		_expect(bool(verdict.blue_crossing) == (component == Tutorial.BLUE), "logical Z family")
	# Multiplying by a stabilizer is a successful correction even if E != C.
	var model := RegressionFloor.new()
	model._reset_stage()
	for key in model.definition().hidden:
		model.corrections[int(key)] = int(model.definition().hidden[key])
	for node in model.definition().blue_faces[0].nodes:
		model.corrections[node] ^= Tutorial.RED
	_expect(model.is_dark() and model.inspect_floor().safe, "stabilizer-equivalent correction succeeds")


func _test_fault_flicker() -> void:
	var model := Tutorial.new()
	var state_before := JSON.stringify(model.semantic_state())
	var pairs := [[340, 341], [340, 380], [5340, 5341]]
	for keys in pairs:
		var dark_count := 0
		var bright_count := 0
		var independent_count := 0
		var transitions := 0
		var was_dark := false
		for frame in 1200:
			var time := float(frame) / 60.0
			var a := Flicker.brightness(keys[0], time)
			var b := Flicker.brightness(keys[1], time)
			_expect(a >= 0.0 and a <= 1.0, "lamp brightness is bounded")
			_expect(a == Flicker.brightness(keys[0], time), "lamp sampling is deterministic")
			_expect(Flicker.brightness(keys[0], time, true) == 1.0, "reduced motion holds the lamp steady")
			var is_dark := a < 0.15
			dark_count += 1 if is_dark else 0
			bright_count += 1 if a > 0.8 else 0
			independent_count += 1 if is_dark != (b < 0.15) else 0
			transitions += 1 if is_dark != was_dark else 0
			was_dark = is_dark
		_expect(dark_count > 0 and bright_count > 600, "short dropouts have long bright intervals")
		_expect(independent_count > 20, "adjacent and opposite-color lamps blink independently")
		_expect(transitions > 8 and transitions < 100, "local blink bursts stay bounded")
	_expect(JSON.stringify(model.semantic_state()) == state_before, "animation sampling never changes syndrome state")


func _test_boundary_lesson() -> void:
	for alternative in [false, true]:
		var model := _at(5)
		_expect(model.stages().size() == 7, "seven lesson progress")
		_expect(model.lit_red_checks().size() == 1 and model.lit_blue_checks().is_empty(), "one red edge syndrome")
		model.tap_node(0, 1 if alternative else 0)
		_expect(model.is_dark() and model.inspection.safe and model.can_continue(), "red boundary correction is safe including equivalent solution")
		_expect(model.boundary_phase == 0, "the blue half waits for a deliberate Continue")
		model.tap_node(2, 2)
		_expect(model.boundary_phase == 0 and not model.can_continue(), "a stale extra tap edits the red half, it does not start the blue one")
		for tap in 3:
			model.tap_node(2, 2)
		model.next_stage()
		_expect(model.stage_index == 5 and model.boundary_phase == 1 and not model.touched, "blue follows red within the same lesson")
		_expect(model.lit_blue_checks().size() == 1 and model.lit_red_checks().is_empty(), "one blue edge syndrome")
		model.tap_node(1 if alternative else 0, 2)
		_expect(not model.is_dark() and not model.can_continue(), "intermediate red does not solve blue")
		model.tap_node(1 if alternative else 0, 2)
		_expect(model.is_dark() and model.inspection.safe, "blue boundary correction is safe including equivalent solution")
		model.next_stage()
		_expect(model.stage_index == 6 and model.definition().id == "graduation_3x3", "boundary leads to final review")
		model.restart()
		_expect(model.boundary_phase == 0, "replay resets boundary practice")
	# A zero-syndrome logical string must not advance the boundary lesson.
	var model := _at(5)
	_wire(model, {0: Tutorial.EMPTY, 3: Tutorial.RED, 6: Tutorial.RED})
	_expect(model.is_dark() and not model.inspection.safe, "boundary still detects logical errors")
	_expect(not model.next_stage() and model.boundary_phase == 0, "unsafe boundary solution stays available to repair")


func _test_reward_events() -> void:
	var model := Tutorial.new()
	var rewards := Rewards.new()
	rewards.observe(model.semantic_state())
	for taps in [1, 2, 3]:
		for index in taps:
			model.tap_node(1, 1)
			var event := rewards.observe(model.semantic_state())
			_expect((event == "success") == (index == taps - 1), "only the solving tap celebrates")
		var count := rewards.event_count
		_expect(rewards.observe(model.semantic_state()).is_empty() and rewards.event_count == count, "repeated redraw never retriggers reward")
		model.next_stage()
		rewards.observe(model.semantic_state())
	_expect(rewards.observe(model.semantic_state()).is_empty(), "initial dark floor does not celebrate")
	model.inspect_floor()
	_expect(rewards.observe(model.semantic_state()) == "success", "explicit safe inspection celebrates")
	model.next_stage()
	rewards.observe(model.semantic_state())
	model.inspect_floor()
	_expect(rewards.observe(model.semantic_state()).is_empty() and rewards.success_count == 4, "the trap's leak never celebrates")
	model.tap_node(1, 1)
	_expect(rewards.observe(model.semantic_state()) == "reset", "editing the leak clears it")
	for node in [1, 7]:
		for tap in 3:
			model.tap_node(int(node / 3.0), node % 3)
			rewards.observe(model.semantic_state())
	_expect(rewards.kind == "settled", "darkening the repair is not yet a pass")
	model.inspect_floor()
	_expect(rewards.observe(model.semantic_state()) == "success" and rewards.success_count == 5, "the inspected repair celebrates")
	model.next_stage()
	rewards.observe(model.semantic_state())
	for phase in 2:
		for tap in phase + 1:
			model.tap_node(0, phase * 2)
			var event := rewards.observe(model.semantic_state())
			_expect((event == "success") == (tap == phase), "each boundary color has one true success")
		model.next_stage()
		rewards.observe(model.semantic_state())
	for node in [Vector2i(1, 1), Vector2i(0, 2), Vector2i(0, 2)]:
		model.tap_node(node.x, node.y)
		rewards.observe(model.semantic_state())
	_expect(rewards.kind == "settled" and rewards.success_count == 7, "final extinction is not yet a passed inspection")
	model.inspect_floor()
	_expect(rewards.observe(model.semantic_state()) == "finale", "only verified final inspection gets the larger reward")
	_expect(rewards.success_count == 8, "the full tutorial has eight verified rewards (lesson 5 after its repair)")
	model.next_stage()
	_expect(rewards.observe(model.semantic_state()) == "reset" and rewards.success_count == 8, "completion does not replay final sound")
	model.restart()
	rewards.observe(model.semantic_state())
	_expect(rewards.kind.is_empty(), "replay clears effects")
	model.stage_index = 6
	model._reset_stage()
	model._record("test_floor", {})
	rewards.observe(model.semantic_state())
	model.skip_graduation()
	rewards.observe(model.semantic_state())
	_expect(rewards.success_count == 8 and rewards.kind.is_empty(), "skip is never a successful repair reward")


func _test_unsafe_rewards_and_retry() -> void:
	for stage in [0, 6]:
		var model := _at(stage)
		var rewards := Rewards.new()
		rewards.observe(model.semantic_state())
		for node in [Vector2i(0, 1), Vector2i(2, 1)]:
			model.tap_node(node.x, node.y)
			rewards.observe(model.semantic_state())
		if stage == 6:
			for tap in 2:
				model.tap_node(0, 2)
				rewards.observe(model.semantic_state())
			model.inspect_floor()
			rewards.observe(model.semantic_state())
		_expect(model.is_dark() and not model.inspection.safe, "guided and final logical errors fail inspection")
		_expect(rewards.success_count == 0 and rewards.kind == "settled", "unsafe dark floor receives no success or success sound")
		_expect(not model.next_stage() and model.stage_index == stage and not model.finished, "unsafe result stays available to retry")
		for node in [Vector2i(0, 1), Vector2i(2, 1)]:
			for tap in 3:
				model.tap_node(node.x, node.y)
				rewards.observe(model.semantic_state())
		model.tap_node(1, 1)
		rewards.observe(model.semantic_state())
		if stage == 6:
			model.inspect_floor()
			rewards.observe(model.semantic_state())
		_expect(model.inspection.safe and rewards.success_count == 1, "correcting the retry produces exactly one success")


func _test_reward_audio() -> void:
	for finale in [false, true]:
		var sound := Sounds.make_sting(finale)
		var repeated := Sounds.make_sting(finale)
		_expect(sound.data == repeated.data, "synthesized sound is deterministic")
		_expect(sound.get_length() < 0.8 and sound.get_length() > 0.3, "reward sound stays brief")
		var peak := 0
		for frame in sound.data.size() / 2:
			peak = maxi(peak, absi(sound.data.decode_s16(frame * 2)))
		_expect(peak > 1000 and peak < 24000, "sound has audible non-clipping samples")
		_expect(sound.data.decode_s16(0) == 0 and absi(sound.data.decode_s16(sound.data.size() - 2)) < 10, "sound envelope has quiet endpoints")
	for event in ["", "settled", "reset", "success", "finale"]:
		_expect(not Rewards.wants_sound(event, true), "mute suppresses every reward sound")
		_expect(not Rewards.wants_sound(event, false, true), "master mute is respected")
		_expect(Rewards.wants_sound(event, false) == (event in ["success", "finale"]), "sound requires a verified success event")


func _test_leak_events() -> void:
	var model := Tutorial.new()
	var leaks := Leaks.new()
	leaks.observe(model.semantic_state())
	model.tap_node(1, 1)
	_expect(leaks.observe(model.semantic_state()).is_empty() and not leaks.active, "safe clear never discharges")
	model.stage_index = 4
	model._reset_stage()
	model._record("test_floor", {})
	leaks.observe(model.semantic_state())
	_expect(not leaks.active, "dark floor before inspection never reveals error")
	model.inspect_floor()
	_expect(leaks.observe(model.semantic_state()) == "leak" and leaks.event_count == 1, "failed trap inspection discharges once")
	_expect(leaks.observe(model.semantic_state()).is_empty(), "redraw cannot repeat discharge")
	model.tap_node(1, 1)
	_expect(leaks.observe(model.semantic_state()) == "reset" and not leaks.active, "the first change cancels the leak presentation")
	model.tap_node(1, 1)
	model.tap_node(1, 1)
	model.tap_node(1, 1)
	_expect(model.corrections == PackedInt32Array([0, 1, 0, 0, 0, 0, 0, 1, 0]) and leaks.observe(model.semantic_state()).is_empty(), "returning to the trap needs a new inspection")
	model.inspect_floor()
	_expect(leaks.observe(model.semantic_state()) == "leak" and leaks.event_count == 2, "a new inspection discharges again")
	model.stage_index = 0
	model._reset_stage()
	model._record("test_floor", {})
	_expect(leaks.observe(model.semantic_state()) == "reset" and not leaks.active, "another lesson clears crack and reveal state")
	model.tap_node(0, 1)
	leaks.observe(model.semantic_state())
	model.tap_node(2, 1)
	_expect(leaks.observe(model.semantic_state()) == "leak", "guided logical failure discharges")
	model.restart()
	leaks.observe(model.semantic_state())
	_expect(not leaks.active and leaks.event_count == 3, "replay neither leaks nor repeats sound")


func _test_residual_routes() -> void:
	var model := Tutorial.new()
	var d := model.definition()
	for component in [Tutorial.RED, Tutorial.BLUE]:
		var faces: Array = d.red_faces if component == Tutorial.RED else d.blue_faces
		var cut: Array = d.red_cut if component == Tutorial.RED else d.blue_cut
		for mask in 512:
			var support := PackedInt32Array()
			for node in 9:
				if mask & (1 << node):
					support.append(node)
			var dark := true
			for face in faces:
				var parity := 0
				for node in face.nodes:
					parity ^= 1 if support.has(node) else 0
				dark = dark and parity == 0
			var crossing := 0
			for node in cut:
				crossing ^= 1 if support.has(node) else 0
			if not dark or crossing == 0:
				continue
			var route := Leaks.route(faces, support, 3, component == Tutorial.RED)
			_expect(not route.is_empty(), "every zero-syndrome logical class has a drawable residual chain")
			if route.is_empty():
				continue
			for node in route.qubits:
				_expect(support.has(node), "route never invents a residual qubit")
			_expect(route.checks.size() == route.qubits.size() - 1, "chain alternates actual qubits and shared checks")
			for index in route.checks.size():
				var nodes: Array = faces[route.checks[index]].nodes
				_expect(nodes.has(route.qubits[index]) and nodes.has(route.qubits[index + 1]), "drawn segment joins qubits incident to the same check")
			var first: int = route.qubits[0]
			var last: int = route.qubits[-1]
			_expect((first < 3 and last >= 6) if component == Tutorial.RED else (first % 3 == 0 and last % 3 == 2), "chain connects the correct opposing boundaries")
			# The drawn chain uses only horizontal, vertical and 45-degree steps.
			route.component = component
			var points := Lesson.route_points(route, faces)
			for i in points.size() - 1:
				var step := points[i + 1] - points[i]
				_expect(is_zero_approx(step.x) or is_zero_approx(step.y) or is_equal_approx(absf(step.x), absf(step.y)), "route segment is 0, 45 or 90 degrees")


func _test_original_fault_xor() -> void:
	var model := _at(2)
	for column in [0, 2]:
		model.tap_node(1, column)
		model.tap_node(1, column)
	model.tap_node(1, 1)
	_expect(model.definition().hidden == {4: Tutorial.BOTH}, "answer reveal preserves the original hidden error")
	_expect(model.is_dark() and model.inspection.blue_crossing and not model.inspection.red_crossing, "red component cancels while blue logical component remains")
	_expect(model._residual_support(Tutorial.RED).is_empty(), "cancelled original and placed red never enters discharge")
	var route := Leaks.route(model.definition().blue_faces, model._residual_support(Tutorial.BLUE), 3, false)
	_expect(route.qubits == [3, 4, 5], "blue residual includes the original center component and placed end corrections")


func _test_lamp_sound_gate() -> void:
	var gate := LampGate.new()
	var keys := PackedInt32Array([6340, 6341, 6380, 6381])
	var count := 0
	var last := -100.0
	var by_lamp: Dictionary = {}
	_expect(gate.poll(keys, 0.0, true) == -1, "initial lamp sample never starts a sound")
	for frame in range(1, 4800):
		if frame % 47 == 0:
			gate.reset()
		var time := float(frame) / 120.0
		var key := gate.poll(keys, time, true)
		if key < 0:
			continue
		count += 1
		_expect(Flicker.brightness(key, time) < 0.15 and Flicker.brightness(key, time - 1.0 / 120.0) >= 0.6, "every tick matches a visible dropout edge")
		_expect(time - last >= LampGate.MIN_GAP - 0.00001, "all lamps share a frequency limit")
		_expect(time - float(by_lamp.get(key, -100.0)) >= LampGate.PER_LAMP_GAP - 0.00001, "one lamp cannot chatter every blink")
		last = time
		by_lamp[key] = time
	_expect(count > 4 and count < 125, "subtle periodic lamp sound remains bounded")
	for frame in 240:
		_expect(gate.poll(keys, 40.0 + float(frame) / 120.0, false) == -1, "mute, reduced motion and non-play states silence lamps")
	_expect(gate.poll(keys, 42.0, true) == -1, "unmute or lesson change cannot replay a missed dropout")
	_expect(gate.poll(PackedInt32Array(), 43.0, true) == -1, "cleared floor has no lamp sound")


func _test_electrical_sounds() -> void:
	var discharge := Sounds.make_discharge()
	_expect(discharge.get_length() < 0.4, "failure snap is short")
	_expect(discharge.data == Sounds.make_discharge().data, "failure sound is deterministic")
	var streams: Array[AudioStreamWAV] = [discharge]
	for variant in 3:
		var tick := Sounds.make_lamp_tick(variant)
		_expect(tick.get_length() < 0.07, "lamp sounds remain tiny ticks")
		_expect(tick.data == Sounds.make_lamp_tick(variant).data, "tick variations are deterministic")
		if variant > 0:
			_expect(tick.data != streams[-1].data, "lamp tick has small variations")
		streams.append(tick)
	for stream in streams:
		var peak := 0
		for frame in stream.data.size() / 2:
			peak = maxi(peak, absi(stream.data.decode_s16(frame * 2)))
		_expect(peak > 1000 and peak < 20000, "electrical PCM is audible and bounded")
		_expect(stream.data.decode_s16(0) == 0 and absi(stream.data.decode_s16(stream.data.size() - 2)) < 10, "electrical PCM endpoints stay quiet")


func _test_color_families_and_wire_directions() -> void:
	var red := Tutorial.new()
	red.corrections[1] = Tutorial.RED
	red.corrections[7] = Tutorial.RED
	_expect(red.is_dark() and red._inspect_residual().red_crossing, "original center X plus upper/lower X is the dark logical X example")
	var blue := _at(1)
	blue.corrections[1] = Tutorial.RED
	blue.corrections[7] = Tutorial.RED
	_expect(blue.lit_red_checks() == [0, 1] and blue.lit_blue_checks() == [0, 1], "center Z cannot complete an X chain: two red and two blue syndromes remain")
	blue.corrections = PackedInt32Array([0, 0, 0, Tutorial.BLUE, 0, Tutorial.BLUE, 0, 0, 0])
	_expect(blue.is_dark() and blue._inspect_residual().blue_crossing, "center Z plus left/right Z makes the independent logical Z chain")
	var both := _at(2)
	both.corrections[1] = Tutorial.RED
	both.corrections[7] = Tutorial.RED
	_expect(both.lit_red_checks().is_empty() and both.lit_blue_checks() == [0, 1], "center Y includes X but its uncorrected Z still lights blue checks")
	both.corrections[3] = Tutorial.BLUE
	both.corrections[5] = Tutorial.BLUE
	var result := both._inspect_residual()
	_expect(both.is_dark() and result.red_crossing and result.blue_crossing, "Y center participates in independent X and Z residual chains")
	# Red is always "\" and blue always "/", on every socket; the dashed
	# original fault uses the same band as the player's wire.
	for node in 9:
		var center := Lesson.socket_center(node)
		var r := Lesson.wire_band(center, Tutorial.RED)
		var b := Lesson.wire_band(center, Tutorial.BLUE)
		_expect(r[1].x > r[0].x and r[1].y > r[0].y and is_equal_approx(r[1].x - r[0].x, r[1].y - r[0].y), "red wire is a 45-degree backslash")
		_expect(b[1].x < b[0].x and b[1].y > b[0].y and is_equal_approx(b[0].x - b[1].x, b[1].y - b[0].y), "blue wire is a 45-degree forward slash")
		_expect(((r[0] + r[1]) * 0.5).distance_to(center) <= 1.0 and ((b[0] + b[1]) * 0.5).distance_to(center) <= 1.0, "both wires cross at their socket")
