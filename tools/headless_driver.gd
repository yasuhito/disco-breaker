extends SceneTree

const Tutorial := preload("res://src/tutorial_state.gd")


func _init() -> void:
	var model := Tutorial.new()
	_solve_all(model)
	var output_dir := "res://artifacts"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var state_file := FileAccess.open(output_dir + "/headless-state.json", FileAccess.WRITE)
	state_file.store_string(JSON.stringify(model.semantic_state(), "  ") + "\n")
	var trace_file := FileAccess.open(output_dir + "/action-trace.jsonl", FileAccess.WRITE)
	trace_file.store_string(model.trace_json_lines())
	print(JSON.stringify(model.semantic_state()))
	quit(0 if model.finished else 1)


# Every lesson through the public commands. Lesson 5 is first inspected as
# the untouched trap (a leak, not a pass), then repaired and inspected again.
func _solve_all(model: Tutorial) -> void:
	model.tap_node(1, 1)
	model.next_stage()
	model.tap_node(1, 1)
	model.tap_node(1, 1)
	model.next_stage()
	for tap in 3:
		model.tap_node(1, 1)
	model.next_stage()
	model.inspect_floor()
	model.next_stage()
	model.inspect_floor()
	for tap in 3:
		model.tap_node(0, 1)
		model.tap_node(2, 1)
	model.tap_node(1, 1)
	model.inspect_floor()
	model.next_stage()
	model.tap_node(0, 0)
	model.next_stage()
	model.tap_node(0, 2)
	model.tap_node(0, 2)
	model.next_stage()
	model.tap_node(1, 1)
	model.tap_node(0, 2)
	model.tap_node(0, 2)
	model.inspect_floor()
	model.next_stage()
