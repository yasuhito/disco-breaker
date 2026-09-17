extends SceneTree

const Tutorial := preload("res://src/tutorial_state.gd")
const Inspection := preload("res://src/inspection_semantics.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_tap_cycle()
	_test_three_guided_lessons()
	_test_independent_crossing_parity()
	_test_crossing_trap()
	_test_graduation()
	_test_semantic_contract()
	if failures.is_empty():
		print("PASS: 6 tutorial tests")
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
	model.stage_index = 5
	model._reset_stage()
	model.confirm_dialogue()
	model.tap_node(2, 2)
	model.tap_node(0, 3)
	model.tap_node(0, 3)
	model.tap_node(4, 1)
	_expect(model.is_dark(), "graduation target should clear all panels")
	_expect(model.can_call_foreman(), "foreman should enable only after clear")
	_expect(model.inspect_floor().safe, "graduation repair should be safe")
	model.next_stage()
	_expect(model.finished, "graduation should complete tutorial")


func _test_semantic_contract() -> void:
	var state := Tutorial.new().semantic_state()
	for key in ["schema", "stage", "stage_id", "corrections", "lit_red", "lit_blue", "floor_dark", "inspection"]:
		_expect(state.has(key), "semantic state missing %s" % key)
	_expect(String(state.schema) == "disco-breaker-tutorial-state.v1", "semantic schema version")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
