extends Control

const Tutorial := preload("res://src/tutorial_state.gd")
const FOREMAN := preload("res://assets/foreman.svg")

const DESIGN_SIZE := Vector2(390, 844)
const INK := Color("#120a24")
const PANEL := Color("#21143a")
const PAPER := Color("#f7f1e3")
const MUTED := Color("#a997bb")
const RED := Color("#ff4d5e")
const BLUE := Color("#4da6ff")
const PINK := Color("#ff3fa4")
const CYAN := Color("#3ee6ff")
const AMBER := Color("#ffb62b")
const GREEN := Color("#2bd889")

var model := Tutorial.new()
var reduced_motion := false
var _elapsed := 0.0
var _scale := 1.0
var _offset := Vector2.ZERO
var _board_rect := Rect2()
var _primary_rect := Rect2()
var _secondary_rect := Rect2()
var _last_state_json := ""


func _ready() -> void:
	set_process(true)
	set_process_input(true)
	resized.connect(queue_redraw)
	reduced_motion = OS.has_feature("reduced_motion") or OS.get_environment("DISCO_BREAKER_REDUCED_MOTION") == "1"
	if OS.has_feature("web"):
		reduced_motion = reduced_motion or bool(JavaScriptBridge.eval("matchMedia('(prefers-reduced-motion: reduce)').matches"))
	_publish_semantics()
	queue_redraw()


func _process(delta: float) -> void:
	if not reduced_motion:
		_elapsed += delta
		queue_redraw()
	_publish_semantics()


func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton:
		point = event.position
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		point = event.position
		pressed = event.pressed
	if not pressed:
		return
	accept_event()
	_handle_design_tap((point - _offset) / _scale)


func inject_action(action: Dictionary) -> bool:
	match String(action.get("type", "")):
		"confirm":
			model.confirm_dialogue()
		"tap":
			if not model.tap_node(int(action.get("row", -1)), int(action.get("column", -1))):
				return false
		"inspect":
			if model.inspect_floor().is_empty():
				return false
		"next":
			model.next_stage()
		"skip":
			model.skip_graduation()
		_:
			return false
	queue_redraw()
	_publish_semantics()
	return true


func semantic_state() -> Dictionary:
	return model.semantic_state()


func _handle_design_tap(point: Vector2) -> void:
	if model.dialogue_visible or model.finished:
		if _primary_rect.has_point(point):
			model.confirm_dialogue()
			queue_redraw()
		return
	if model.result_visible:
		if _primary_rect.has_point(point):
			model.next_stage()
			queue_redraw()
		return
	if model.stage_index == 5 and _secondary_rect.has_point(point):
		model.skip_graduation()
		queue_redraw()
		return
	if model.can_call_foreman() and _primary_rect.has_point(point):
		model.inspect_floor()
		queue_redraw()
		return
	var d := model.definition()
	var size: int = d.size
	var spacing := _board_rect.size.x / float(size)
	for row in size:
		for column in size:
			var center := _board_rect.position + Vector2(column + 0.5, row + 0.5) * spacing
			if point.distance_to(center) <= maxf(25.0, spacing * 0.3):
				model.tap_node(row, column)
				queue_redraw()
				return


func _draw() -> void:
	_scale = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_offset = (size - DESIGN_SIZE * _scale) * 0.5
	draw_set_transform(_offset, 0.0, Vector2.ONE * _scale)
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), INK)
	_draw_background()
	_draw_app_bar()
	_draw_progress()
	_draw_board()
	_draw_footer()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_background() -> void:
	for index in 9:
		var x := 20.0 + index * 47.0
		var alpha := 0.04 + (0.02 if index % 2 == 0 else 0.0)
		draw_line(Vector2(195, 86), Vector2(x, 700), Color(1, 0.25, 0.7, alpha), 2.0)
	for y in range(120, 720, 44):
		draw_line(Vector2(0, y), Vector2(390, y), Color(0.24, 0.9, 1, 0.035), 1.0)


func _draw_app_bar() -> void:
	draw_rect(Rect2(0, 0, 390, 78), Color("#0b0716"))
	_draw_text("‹", Vector2(22, 53), 34, PAPER)
	_draw_text("TUTORIAL", Vector2(58, 48), 20, PAPER)
	var step := "STEP %d / 6" % (model.stage_index + 1)
	_draw_text(step, Vector2(286, 47), 13, CYAN)
	_draw_text(model.definition().title, Vector2(28, 112), 24, PAPER)


func _draw_progress() -> void:
	for index in 6:
		var color := PINK if index <= model.stage_index else Color("#4b3a60")
		draw_circle(Vector2(145 + index * 20, 135), 4.0, color)


func _draw_board() -> void:
	var d := model.definition()
	var grid_size: int = d.size
	var board_size := 286.0 if grid_size == 3 else 338.0
	var board_top := 166.0 if grid_size == 3 else 157.0
	_board_rect = Rect2((390.0 - board_size) * 0.5, board_top, board_size, board_size)
	draw_rect(_board_rect.grow(8), Color("#090611"), true)
	draw_rect(_board_rect.grow(8), Color(0.24, 0.9, 1, 0.2), false, 2.0)
	var spacing := board_size / float(grid_size)
	var lit_red := model.lit_red_checks()
	var lit_blue := model.lit_blue_checks()
	var red_tiles: Array = d.red_tiles
	var blue_tiles: Array = d.blue_tiles
	var red_seen := 0
	var blue_seen := 0
	for row in grid_size - 1:
		for column in grid_size - 1:
			var tile_index := row * (grid_size - 1) + column
			var is_red := (row + column) % 2 == 0
			var local_check := red_seen if is_red else blue_seen
			var lit := lit_red.has(local_check) if is_red else lit_blue.has(local_check)
			if is_red:
				red_seen += 1
			else:
				blue_seen += 1
			var base := RED if is_red else BLUE
			var rect := Rect2(
				_board_rect.position + Vector2(column + 0.52, row + 0.52) * spacing,
				Vector2.ONE * spacing * 0.96)
			_draw_panel(rect, base, lit)
	# Explicit stage fault positions keep the approved examples stable even when
	# a compact checkerboard has fewer visible internal panels.
	for check in lit_red:
		if check < red_tiles.size():
			_draw_fault_badge(int(red_tiles[check]), RED, grid_size, spacing)
	for check in lit_blue:
		if check < blue_tiles.size():
			_draw_fault_badge(int(blue_tiles[check]), BLUE, grid_size, spacing)
	_draw_nodes(grid_size, spacing)
	if not model.inspection.is_empty() and not bool(model.inspection.safe):
		_draw_witness(grid_size, spacing)


func _draw_panel(rect: Rect2, color: Color, lit: bool) -> void:
	var fill := Color(color, 0.88 if lit else 0.09)
	if lit and not reduced_motion:
		fill.a = 0.72 + 0.16 * sin(_elapsed * 8.0)
	draw_rect(rect, fill, true)
	draw_rect(rect, Color(color, 0.7), false, 2.0)


func _draw_fault_badge(index: int, color: Color, grid_size: int, spacing: float) -> void:
	var cells := grid_size - 1
	var row := (index / cells) % cells
	var column := index % cells
	var center := _board_rect.position + Vector2(column + 1.0, row + 1.0) * spacing
	draw_circle(center, spacing * 0.18, Color(color, 0.28))
	draw_circle(center, spacing * 0.1, color)


func _draw_nodes(grid_size: int, spacing: float) -> void:
	var target: int = model.definition().target
	for row in grid_size:
		for column in grid_size:
			var index := row * grid_size + column
			var center := _board_rect.position + Vector2(column + 0.5, row + 0.5) * spacing
			var radius := minf(25.0, spacing * 0.28)
			draw_circle(center, radius, Color("#34254a"))
			draw_circle(center, radius, Color("#c8b8d8"), false, 2.0)
			if target == index and not model.dialogue_visible and not model.result_visible:
				var pulse := 4.0 if reduced_motion else 4.0 + 3.0 * (sin(_elapsed * 5.0) + 1.0)
				draw_circle(center, radius + pulse, AMBER, false, 3.0)
				if model.stage_index in [1, 2]:
					_draw_tap_badge(center + Vector2(radius * 0.8, -radius * 1.15), model.stage_index + 1)
			_draw_wires(center, radius, model.corrections[index], (row + column) % 2 == 0)


func _draw_wires(center: Vector2, radius: float, state: int, even: bool) -> void:
	var diagonal := Vector2(radius * 0.56, radius * 0.56)
	if not even:
		diagonal.y *= -1.0
	if state & Tutorial.RED:
		draw_line(center - diagonal, center + diagonal, RED, 6.0, true)
	if state & Tutorial.BLUE:
		var other := Vector2(diagonal.x, -diagonal.y)
		draw_line(center - other, center + other, BLUE, 6.0, true)


func _draw_tap_badge(center: Vector2, count: int) -> void:
	draw_circle(center, 17, AMBER)
	_draw_text("×%d" % count, center + Vector2(-11, 6), 15, INK)


func _draw_witness(grid_size: int, spacing: float) -> void:
	var witness: Array = model.inspection.get("red_witness", [])
	if witness.is_empty():
		return
	var points := PackedVector2Array()
	for index in witness:
		var row: int = int(index) / grid_size
		var column: int = int(index) % grid_size
		points.append(_board_rect.position + Vector2(column + 0.5, row + 0.5) * spacing)
	if points.size() >= 2:
		draw_polyline(points, RED, 8.0, true)
		draw_line(points[0] - Vector2(0, spacing * 0.48), points[0], RED, 8.0, true)
		draw_line(points[-1], points[-1] + Vector2(0, spacing * 0.48), RED, 8.0, true)


func _draw_footer() -> void:
	_primary_rect = Rect2(18, 764, 354, 58)
	_secondary_rect = Rect2(18, 716, 354, 38)
	if model.dialogue_visible:
		_draw_dialogue()
		_draw_button(_primary_rect, "もう一度" if model.finished else "OK", PINK, true)
		return
	if model.result_visible:
		_draw_result()
		var label := "TUTORIAL COMPLETE" if model.stage_index == 5 else "NEXT"
		_draw_button(_primary_rect, label, GREEN if _result_safe() else PINK, true)
		return
	if model.stage_index == 5:
		_draw_button(_secondary_rect, "SKIP OPTIONAL STAGE", Color("#49365e"), false)
	var enabled := model.can_call_foreman()
	if model.stage_index >= 3:
		_draw_button(_primary_rect, "CALL THE FOREMAN", AMBER if enabled else Color("#4b4156"), enabled)


func _draw_dialogue() -> void:
	var rect := Rect2(18, 615, 354, 132)
	draw_style_box(_rounded_box(PAPER, 18), rect)
	var portrait := Rect2(30, 636, 88, 88)
	draw_texture_rect(FOREMAN, portrait, false)
	if not reduced_motion and not model.finished:
		var mouth_open := fmod(_elapsed, 0.55) < 0.25
		if mouth_open:
			draw_circle(Vector2(74, 703), Vector2(7, 4).x, Color("#321d23"))
	var text := "All six lessons complete!\nThe dance floor is in good hands." if model.finished else String(model.definition().coach)
	_draw_multiline(text, Vector2(130, 657), 18, INK, 218)


func _draw_result() -> void:
	var safe := _result_safe()
	var rect := Rect2(18, 615, 354, 132)
	draw_style_box(_rounded_box(Color("#171027"), 18), rect)
	draw_texture_rect(FOREMAN, Rect2(30, 636, 82, 82), false)
	var heading := "GOOD!"
	var body := "The flicker is gone. Nice work!"
	var color := GREEN
	if model.stage_index == 3:
		heading = "INSPECTION: OK"
		body = "The crossed wires stay inside. Safe!"
	elif model.stage_index == 4:
		heading = "POWER LEAK"
		body = "Red reaches the other side!"
		color = RED
	elif model.stage_index == 5:
		heading = "GRADUATION: PASSED"
		body = "Full-size floor is safe!"
	_draw_text(heading, Vector2(126, 658), 19, color)
	_draw_multiline(body, Vector2(126, 686), 17, PAPER, 224)


func _result_safe() -> bool:
	return model.inspection.is_empty() or bool(model.inspection.get("safe", true))


func _draw_button(rect: Rect2, label: String, color: Color, enabled: bool) -> void:
	draw_style_box(_rounded_box(color, 15), rect)
	var text_color := INK if enabled and color != Color("#49365e") else Color("#d5c8dc")
	var width := _text_width(label, 18)
	_draw_text(label, Vector2(rect.get_center().x - width * 0.5, rect.position.y + rect.size.y * 0.5 + 7), 18, text_color)


func _rounded_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box


func _draw_text(text: String, position: Vector2, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_multiline(text: String, position: Vector2, font_size: int, color: Color, width: float) -> void:
	var line_y := position.y
	for paragraph in text.split("\n"):
		draw_string(ThemeDB.fallback_font, Vector2(position.x, line_y), paragraph, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
		line_y += font_size + 8


func _text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _publish_semantics() -> void:
	var state_json := JSON.stringify(model.semantic_state())
	if state_json == _last_state_json:
		return
	_last_state_json = state_json
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.discoBreakerState = %s; document.documentElement.dataset.tutorialStage = String(window.discoBreakerState.stage); document.title = 'DISCO BREAKER · ' + window.discoBreakerState.stage_id;" % state_json)
