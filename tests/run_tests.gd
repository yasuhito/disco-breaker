extends SceneTree

const Tutorial := preload("res://src/tutorial_state.gd")
const Inspection := preload("res://src/inspection_semantics.gd")
const Leaks := preload("res://src/leak_feedback.gd")
const LampGate := preload("res://src/lamp_sound_gate.gd")
const Rewards := preload("res://src/reward_feedback.gd")
const Sounds := preload("res://src/reward_sound.gd")
const Flicker := preload("res://src/fault_flicker.gd")
const CopyLayout := preload("res://src/text_layout.gd")


# Keep the earlier 5x5 adjacency regression as a test fixture, not a game mode.
class RegressionFloor:
	extends "res://src/tutorial_state.gd"

	func definition() -> Dictionary:
		return _with_geometry({"id": "regression_5x5", "size": 5,
			"hidden": {12: RED, 3: BLUE, 21: RED}, "preset": {}, "target": -1})

var failures: Array[String] = []


func _init() -> void:
	_test_tap_cycle()
	_test_three_guided_lessons()
	_test_independent_crossing_parity()
	_test_crossing_trap()
	_test_graduation()
	_test_boundary_lesson()
	_test_final_skip_and_replay()
	_test_surface_code_geometry()
	_test_screenshot_move()
	_test_logical_classes()
	_test_semantic_contract()
	_test_foreman_copy_wraps()
	_test_fault_flicker()
	_test_reward_events()
	_test_unsafe_rewards_and_retry()
	_test_reward_audio()
	_test_leak_events()
	_test_residual_routes()
	_test_original_fault_xor()
	_test_lamp_sound_gate()
	_test_electrical_sounds()
	_test_color_families_and_ghost_alignment()
	if failures.is_empty():
		print("PASS: 22 tutorial tests")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_tap_cycle() -> void:
	var model := Tutorial.new()
	model.confirm_dialogue()
	for expected in [Tutorial.RED, Tutorial.BLUE, Tutorial.BOTH, Tutorial.EMPTY]:
		model.tap_node(1, 1)
		_expect(model.corrections[4] == expected, "tap cycle expected %d" % expected)
		if model.result_visible:
			model.result_visible = false


func _test_three_guided_lessons() -> void:
	var model := Tutorial.new()
	for taps in [1, 2, 3]:
		model.confirm_dialogue()
		for ignored in taps:
			model.tap_node(1, 1)
		_expect(model.is_dark(), "guided stage %d should clear" % (model.stage_index + 1))
		_expect(model.result_visible, "guided stage should show result")
		model.next_stage()


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


func _test_crossing_trap() -> void:
	var model := Tutorial.new()
	model.stage_index = 4
	model._reset_stage()
	_expect(model.is_dark(), "crossing trap must look cleared")
	model.confirm_dialogue()
	_expect(model.result_visible, "trap confirmation should inspect")
	_expect(model.inspection.red_crossing, "trap must retain odd red logical class")
	_expect(not model.inspection.blue_crossing, "trap must not invent blue class")
	_expect(not model.inspection.safe, "trap must fail inspection")


func _test_graduation() -> void:
	var model := Tutorial.new()
	model.stage_index = 6
	model._reset_stage()
	model.confirm_dialogue()
	_expect(model.definition().size == 3 and model.corrections.size() == 9, "final practice is 3x3")
	model.tap_node(1, 1)
	model.tap_node(0, 2)
	model.tap_node(0, 2)
	_expect(model.is_dark(), "graduation target should clear all panels")
	_expect(model.can_call_foreman(), "foreman should enable only after clear")
	_expect(model.inspect_floor().safe, "graduation repair should be safe")
	model.next_stage()
	_expect(model.finished, "graduation should complete tutorial")


func _test_semantic_contract() -> void:
	var state := Tutorial.new().semantic_state()
	for key in ["schema", "stage", "stage_id", "corrections", "lit_red", "lit_blue", "floor_dark", "inspection", "action_count", "last_action"]:
		_expect(state.has(key), "semantic state missing %s" % key)
	_expect(String(state.schema) == "disco-breaker-tutorial-state.v1", "semantic schema version")


func _test_foreman_copy_wraps() -> void:
	var font := preload("res://assets/fonts/Roboto-Regular.ttf")
	var model := Tutorial.new()
	var copy: Array[String] = []
	var coach_copy: Array[String] = []
	for stage in model.stages():
		var coach := String(stage.coach)
		copy.append(coach)
		coach_copy.append(coach)
	model.boundary_phase = 1
	coach_copy.append(String(model.stages()[5].coach))
	copy.append(String(model.stages()[5].coach))
	copy.append("One edge flicker cleared!")
	coach_copy.append("All seven lessons done!\nYou're ready to dance.")
	copy.append_array([
		"All seven lessons done!\nYou're ready to dance.",
		"The flicker is gone. Nice work!",
		"The crossed wires stay inside. Safe!",
		"Red reaches the other side!",
		"Practice floor is safe!",
	])
	for text in copy:
		var font_size := 18 if text in coach_copy else 17
		var width := 218.0 if font_size == 18 else 224.0
		var lines := CopyLayout.wrap_lines(font, text, font_size, width)
		_expect(CopyLayout.fits(font, lines, font_size, width), "foreman copy exceeds its text column: %s" % text)
		_expect(lines.size() <= 3, "foreman copy exceeds three visible lines: %s" % text)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


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
	model.stage_index = 6
	model._reset_stage()
	model.confirm_dialogue()
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
	model.stage_index = 6
	model._reset_stage()
	model.confirm_dialogue()
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
		model.stage_index = 6
		model._reset_stage()
		model.confirm_dialogue()
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
	model.stage_index = 6
	model._reset_stage()
	model.confirm_dialogue()
	for key in model.definition().hidden:
		model.corrections[int(key)] = int(model.definition().hidden[key])
	for node in model.definition().blue_faces[0].nodes:
		model.corrections[node] ^= Tutorial.RED
	_expect(model.is_dark() and model.inspect_floor().safe, "stabilizer-equivalent correction succeeds")

func _test_final_skip_and_replay() -> void:
	var model := Tutorial.new()
	model.stage_index = 6
	model._reset_stage()
	model.confirm_dialogue()
	model.skip_graduation()
	_expect(model.finished, "final practice can be skipped unsolved")
	model.confirm_dialogue()
	_expect(not model.finished and model.stage_index == 0 and model.dialogue_visible, "replay starts the tutorial again")


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
		var model := Tutorial.new()
		model.stage_index = 5
		model._reset_stage()
		_expect(model.stages().size() == 7, "seven lesson progress")
		_expect(model.lit_red_checks().size() == 1 and model.lit_blue_checks().is_empty(), "one red edge syndrome")
		model.confirm_dialogue()
		model.tap_node(0, 1 if alternative else 0)
		_expect(model.is_dark() and model.inspection.safe and model.result_visible, "red boundary correction is safe including equivalent solution")
		model.next_stage()
		_expect(model.stage_index == 5 and model.boundary_phase == 1 and model.dialogue_visible, "blue follows red within the same lesson")
		_expect(model.lit_blue_checks().size() == 1 and model.lit_red_checks().is_empty(), "one blue edge syndrome")
		model.confirm_dialogue()
		model.tap_node(1 if alternative else 0, 2)
		_expect(not model.is_dark() and not model.result_visible, "intermediate red does not solve blue")
		model.tap_node(1 if alternative else 0, 2)
		_expect(model.is_dark() and model.inspection.safe, "blue boundary correction is safe including equivalent solution")
		model.next_stage()
		_expect(model.stage_index == 6 and model.definition().id == "graduation_3x3", "boundary leads to final review")
		model.restart()
		_expect(model.boundary_phase == 0, "replay resets boundary practice")
	# A zero-syndrome logical string must not advance the boundary lesson.
	var model := Tutorial.new()
	model.stage_index = 5
	model._reset_stage()
	model.confirm_dialogue()
	model.corrections[0] = Tutorial.RED
	for node in [2, 5, 8]:
		model.corrections[node] ^= Tutorial.RED
	_expect(model.is_dark() and not model.inspect_floor().safe, "boundary still detects logical errors")
	model.next_stage()
	_expect(model.stage_index == 5 and model.boundary_phase == 0 and not model.result_visible, "unsafe boundary solution stays available to repair")


func _test_reward_events() -> void:
	var model := Tutorial.new()
	var rewards := Rewards.new()
	rewards.observe(model.semantic_state())
	for taps in [1, 2, 3]:
		model.confirm_dialogue()
		rewards.observe(model.semantic_state())
		for index in taps:
			model.tap_node(1, 1)
			var event := rewards.observe(model.semantic_state())
			_expect((event == "success") == (index == taps - 1), "only the solving tap celebrates")
		var count := rewards.event_count
		_expect(rewards.observe(model.semantic_state()).is_empty() and rewards.event_count == count, "repeated redraw never retriggers reward")
		model.tap_node(1, 1)
		_expect(rewards.observe(model.semantic_state()).is_empty(), "extra taps on the result never retrigger reward")
		model.next_stage()
		rewards.observe(model.semantic_state())
	model.confirm_dialogue()
	_expect(rewards.observe(model.semantic_state()).is_empty(), "initial dark floor does not celebrate")
	model.inspect_floor()
	_expect(rewards.observe(model.semantic_state()) == "success", "explicit safe inspection celebrates")
	model.next_stage()
	rewards.observe(model.semantic_state())
	model.confirm_dialogue()
	_expect(rewards.observe(model.semantic_state()).is_empty() and rewards.success_count == 4, "intentional logical trap never celebrates")
	model.next_stage()
	rewards.observe(model.semantic_state())
	for phase in 2:
		model.confirm_dialogue()
		rewards.observe(model.semantic_state())
		for tap in phase + 1:
			model.tap_node(0, phase * 2)
			var event := rewards.observe(model.semantic_state())
			_expect((event == "success") == (tap == phase), "each boundary color has one true success")
		model.next_stage()
		rewards.observe(model.semantic_state())
	model.confirm_dialogue()
	rewards.observe(model.semantic_state())
	for node in [Vector2i(1, 1), Vector2i(0, 2), Vector2i(0, 2)]:
		model.tap_node(node.x, node.y)
		rewards.observe(model.semantic_state())
	_expect(rewards.kind == "settled" and rewards.success_count == 6, "final extinction is not yet a passed inspection")
	model.inspect_floor()
	_expect(rewards.observe(model.semantic_state()) == "finale", "only verified final inspection gets the larger reward")
	_expect(rewards.success_count == 7 and rewards.event_count == 8, "full tutorial has seven verified rewards and one neutral extinction")
	model.next_stage()
	_expect(rewards.observe(model.semantic_state()) == "reset" and rewards.success_count == 7, "completion does not replay final sound")
	model.confirm_dialogue()
	rewards.observe(model.semantic_state())
	_expect(rewards.kind.is_empty(), "replay clears effects")
	model.stage_index = 6
	model._reset_stage()
	model.confirm_dialogue()
	rewards.observe(model.semantic_state())
	model.skip_graduation()
	rewards.observe(model.semantic_state())
	_expect(rewards.success_count == 7 and rewards.kind.is_empty(), "skip is never a successful repair reward")


func _test_unsafe_rewards_and_retry() -> void:
	for stage in [0, 6]:
		var model := Tutorial.new()
		model.stage_index = stage
		model._reset_stage()
		model.confirm_dialogue()
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
		model.next_stage()
		rewards.observe(model.semantic_state())
		_expect(model.stage_index == stage and not model.result_visible and not model.finished, "unsafe result stays available to retry")
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
	model.confirm_dialogue()
	leaks.observe(model.semantic_state())
	model.tap_node(1, 1)
	_expect(leaks.observe(model.semantic_state()).is_empty() and not leaks.active, "safe clear never discharges")
	model.stage_index = 4
	model._reset_stage()
	model._record("test_floor", {})
	leaks.observe(model.semantic_state())
	_expect(not leaks.active, "dark floor before inspection never reveals error")
	model.confirm_dialogue()
	_expect(leaks.observe(model.semantic_state()) == "leak" and leaks.event_count == 1, "failed trap inspection discharges once")
	_expect(leaks.observe(model.semantic_state()).is_empty(), "redraw cannot repeat discharge")
	model.tap_node(1, 1)
	_expect(leaks.observe(model.semantic_state()).is_empty(), "ignored result tap cannot repeat discharge")
	model.next_stage()
	_expect(leaks.observe(model.semantic_state()) == "reset" and not leaks.active, "next lesson clears crack and reveal state")
	model.stage_index = 0
	model._reset_stage()
	model._record("test_floor", {})
	leaks.observe(model.semantic_state())
	model.confirm_dialogue()
	leaks.observe(model.semantic_state())
	model.tap_node(0, 1)
	leaks.observe(model.semantic_state())
	model.tap_node(2, 1)
	_expect(leaks.observe(model.semantic_state()) == "leak", "guided logical failure discharges")
	model.next_stage()
	_expect(leaks.observe(model.semantic_state()) == "reset" and not leaks.active, "retry removes all failure presentation")
	model.restart()
	leaks.observe(model.semantic_state())
	_expect(not leaks.active and leaks.event_count == 2, "replay neither leaks nor repeats sound")


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


func _test_original_fault_xor() -> void:
	var model := Tutorial.new()
	model.stage_index = 2
	model._reset_stage()
	model.confirm_dialogue()
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


func _test_color_families_and_ghost_alignment() -> void:
	var red := Tutorial.new()
	red.corrections[1] = Tutorial.RED
	red.corrections[7] = Tutorial.RED
	_expect(red.is_dark() and red._inspect_residual().red_crossing, "original center X plus upper/lower X is the dark logical X example")
	var blue := Tutorial.new()
	blue.stage_index = 1
	blue._reset_stage()
	blue.corrections[1] = Tutorial.RED
	blue.corrections[7] = Tutorial.RED
	_expect(blue.lit_red_checks() == [0, 1] and blue.lit_blue_checks() == [0, 1], "center Z cannot complete an X chain: two red and two blue syndromes remain")
	blue.corrections = PackedInt32Array([0, 0, 0, Tutorial.BLUE, 0, Tutorial.BLUE, 0, 0, 0])
	_expect(blue.is_dark() and blue._inspect_residual().blue_crossing, "center Z plus left/right Z makes the independent logical Z chain")
	var both := Tutorial.new()
	both.stage_index = 2
	both._reset_stage()
	both.corrections[1] = Tutorial.RED
	both.corrections[7] = Tutorial.RED
	_expect(both.lit_red_checks().is_empty() and both.lit_blue_checks() == [0, 1], "center Y includes X but its uncorrected Z still lights blue checks")
	both.corrections[3] = Tutorial.BLUE
	both.corrections[5] = Tutorial.BLUE
	var result := both._inspect_residual()
	_expect(both.is_dark() and result.red_crossing and result.blue_crossing, "Y center participates in independent X and Z residual chains")
	for even in [false, true]:
		var center := Vector2(195, 309)
		var x := Leaks.ghost_segment(center, 25, Tutorial.RED, even)
		var z := Leaks.ghost_segment(center, 25, Tutorial.BLUE, even)
		_expect(((x[0] + x[1]) * 0.5).is_equal_approx(center) and ((z[0] + z[1]) * 0.5).is_equal_approx(center), "both ghost components are centered on their data qubit")
		_expect(is_zero_approx((x[1] - x[0]).dot(z[1] - z[0])), "X and Z ghost axes stay distinct")
		var correction_axis := Vector2(11, 11 if even else -11)
		_expect(is_zero_approx((x[1] - x[0]).cross(correction_axis)), "red ghost aligns with the physical correction wire")
