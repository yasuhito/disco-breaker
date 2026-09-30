extends Control

const Tutorial := preload("res://src/tutorial_state.gd")
const Flicker := preload("res://src/fault_flicker.gd")
const CopyLayout := preload("res://src/text_layout.gd")
const FONT := preload("res://assets/fonts/Roboto-Regular.ttf")
const BOLD_FONT := preload("res://assets/fonts/Roboto-Bold.ttf")
const BACKGROUND := preload("res://assets/console-background.svg")
const HOUSING := preload("res://assets/console-housing.svg")
const SOCKET := preload("res://assets/socket.svg")
const FOREMAN := preload("res://assets/foreman.svg")

const DESIGN_SIZE := Vector2(390, 844)
const INK := Color("#100e1b")
const PANEL := Color("#262132")
const PAPER := Color("#f7f1e3")
const MUTED := Color("#a997bb")
const RED := Color("#ff6274")
const BLUE := Color("#64bcff")
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
var _definition: Dictionary = {}
var _stage_count := 0
var _glass_reflection: GradientTexture2D
var _style_cache: Dictionary = {}
var _tap_node_index := -1
var _tap_age := 1.0
var _button_age := 1.0
var _success_age := 1.0
var _was_result := false


func _ready() -> void:
	_glass_reflection = GradientTexture2D.new()
	_glass_reflection.width = 8
	_glass_reflection.height = 128
	_glass_reflection.fill_from = Vector2(0, 0)
	_glass_reflection.fill_to = Vector2(0, 1)
	_glass_reflection.gradient = Gradient.new()
	_glass_reflection.gradient.colors = PackedColorArray([Color(1, 0.94, 1, 0.1), Color(1, 0.94, 1, 0)])
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
		_tap_age += delta
		_button_age += delta
		_success_age += delta
		queue_redraw()
	if model.result_visible and not _was_result:
		_success_age = 0.0
	_was_result = model.result_visible


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
	_publish_semantics()


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
	if _primary_rect.has_point(point) or _secondary_rect.has_point(point):
		_button_age = 0.0
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
	if _definition.id == "graduation_3x3" and _secondary_rect.has_point(point):
		model.skip_graduation()
		queue_redraw()
		return
	if model.can_call_foreman() and _primary_rect.has_point(point):
		model.inspect_floor()
		queue_redraw()
		return
	var d := _definition
	var size: int = d.size
	var spacing := _board_rect.size.x / float(size)
	for row in size:
		for column in size:
			var center := _board_rect.position + Vector2(column + 0.5, row + 0.5) * spacing
			if point.distance_to(center) <= maxf(25.0, spacing * 0.3):
				if model.tap_node(row, column):
					_tap_node_index = row * size + column
					_tap_age = 0.0
				queue_redraw()
				return


func _draw() -> void:
	_scale = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_offset = (size - DESIGN_SIZE * _scale) * 0.5
	draw_set_transform(_offset, 0.0, Vector2.ONE * _scale)
	_draw_background()
	_draw_app_bar()
	_draw_progress()
	_draw_board()
	_draw_board_caption()
	_draw_footer()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_background() -> void:
	# Static surfaces are imported once and reused by the GPU.
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, DESIGN_SIZE), false)


func _draw_app_bar() -> void:
	# A tiny mirror-ball mark anchors the disco identity without consuming play space.
	draw_line(Vector2(38, 0), Vector2(38, 21), Color("#726679"), 1)
	_circle(Vector2(38, 35), 14, Color("#423a50"))
	for row in range(-2, 3):
		for column in range(-2, 3):
			if row * row + column * column <= 5:
				var tile := Rect2(36 + column * 5, 33 + row * 5, 3.5, 3.5)
				draw_rect(tile, Color("#ead9b9") if (row + column) % 3 == 0 else Color("#9383a0"))
	_draw_text("DISCO BREAKER", Vector2(63, 42), 17, PAPER, true)
	_draw_text("TUTORIAL", Vector2(293, 40), 10, Color("#bfaccb"), true)
	draw_line(Vector2(24, 67), Vector2(366, 67), Color(1, 0.87, 0.68, 0.12), 1)
	var titles := {
		"red_one_tap": "The red connection",
		"blue_two_taps": "The blue connection",
		"combined_three_taps": "Make them cross",
		"foreman_inspection": "The safety check",
		"crossing_trap": "A hidden power leak",
		"boundary_single": "One light at the edge",
		"graduation_3x3": "Your turn to shine",
	}
	var title: String = titles.get(_definition.id, _definition.title)
	_draw_text(title, Vector2(195 - _text_width(title, 25, true) * 0.5, 109), 25, PAPER, true)


func _draw_progress() -> void:
	var count := _stage_count
	for index in count:
		var center := Vector2(195 - (count - 1) * 11 + index * 22, 135)
		var active := index <= model.stage_index
		_circle(center + Vector2(0, 1), 3.5, Color("#0b0812"))
		_circle(center, 3.0, Color("#e5bc85") if active else Color("#51455e"))
		if index == model.stage_index:
			_circle(center, 6.0, Color("#ad8760"), false, 1.0, true)


func _draw_board() -> void:
	var d := _definition
	var grid_size: int = d.size
	var board_size := 286.0 if grid_size == 3 else 338.0
	var board_top := 166.0 if grid_size == 3 else 157.0
	_board_rect = Rect2((390.0 - board_size) * 0.5, board_top, board_size, board_size)
	draw_texture_rect(HOUSING, Rect2(_board_rect.position - Vector2(19, 19), _board_rect.size + Vector2(38, 52)), false)
	var spacing := board_size / float(grid_size)
	for component in [Tutorial.RED, Tutorial.BLUE]:
		var faces: Array = d.red_faces if component == Tutorial.RED else d.blue_faces
		var lit_checks := model.lit_red_checks() if component == Tutorial.RED else model.lit_blue_checks()
		var color := RED if component == Tutorial.RED else BLUE
		for check in faces.size():
			var face: Dictionary = faces[check]
			var center: Vector2 = _board_rect.position + face.center * spacing
			var extent: Vector2 = face.extent * spacing
			var lit := lit_checks.has(check)
			var lamp_key: int = model.stage_index * 1000 + grid_size * 100 + component * 40 + check
			var intensity := Flicker.brightness(lamp_key, _elapsed, reduced_motion) if lit else 0.0
			_draw_panel(Rect2(center - extent * 0.5, extent), color, intensity)
			if lit:
				_draw_fault_badge(center, color, spacing, intensity)
	_draw_nodes(grid_size, spacing)
	if not model.inspection.is_empty() and not bool(model.inspection.safe):
		_draw_witness(grid_size, spacing)


func _draw_panel(rect: Rect2, color: Color, intensity: float) -> void:
	var glass := rect.grow(-2)
	draw_style_box(_rounded_box(Color("#090b12"), 7), glass.grow(2))
	# Diffused glass, a bevel and a reflection, with the same lamp envelope as its badge.
	var base := Color("#19202b").lerp(color.darkened(0.32), 0.10 + intensity * 0.85)
	draw_rect(glass, base)
	draw_texture_rect(_glass_reflection, glass, false)
	draw_rect(glass, Color(color, 0.16 + intensity * 0.40), false, 1)
	draw_line(glass.position + Vector2(2, 2), glass.position + Vector2(glass.size.x - 2, 2), Color(1, 0.96, 1, 0.10 + intensity * 0.17), 1)
	# Etched horizontal lines distinguish the glass checks from circular tap sockets.
	for offset in [-5, 5]:
		draw_line(glass.get_center() + Vector2(-glass.size.x * 0.25, offset), glass.get_center() + Vector2(glass.size.x * 0.25, offset), Color(color, 0.10), 1)


func _draw_fault_badge(center: Vector2, color: Color, spacing: float, intensity: float) -> void:
	# This tiny persistent lamp core means a dropout cannot be mistaken for a repair.
	for ring in range(3, 0, -1):
		_circle(center, 5.0 + ring * 4, Color(color, (0.015 + intensity * 0.025) / ring))
	_circle(center + Vector2(0, 1), 5, Color("#12121c"))
	_circle(center, 3.5, Color(color, 0.52 + intensity * 0.48))
	_circle(center + Vector2(-0.6, -0.8), 1.2, Color(1, 0.98, 1, intensity * 0.9))


func _draw_nodes(grid_size: int, spacing: float) -> void:
	var definition := _definition
	var target: int = definition.target
	for row in grid_size:
		for column in grid_size:
			var index := row * grid_size + column
			var center := _board_rect.position + Vector2(column + 0.5, row + 0.5) * spacing
			var radius := minf(25.0, spacing * 0.28)
			var press := 0.0
			if not reduced_motion and index == _tap_node_index and _tap_age < 0.18:
				press = 2.5 * sin(PI * _tap_age / 0.18)
			var cap := center + Vector2(0, press)
			var texture_size := Vector2.ONE * radius * 64.0 / 25.0
			draw_texture_rect(SOCKET, Rect2(cap - texture_size * 0.5, texture_size), false)
			if target == index and not model.dialogue_visible and not model.result_visible:
				var alpha := 0.9 if reduced_motion else 0.7 + 0.2 * sin(_elapsed * 2.7)
				_circle(center, radius + 6, Color(AMBER, alpha), false, 2, true)
				var taps := int(definition.get("hint_taps", model.stage_index + 1))
				_draw_tap_badge(center + Vector2(radius * 0.85, -radius * 1.05), taps)
			_draw_wires(cap, radius, model.corrections[index], (row + column) % 2 == 0)
			if not reduced_motion and index == _tap_node_index and _tap_age < 0.35:
				_circle(center, radius + 3 + _tap_age * 23, Color(PAPER, 0.3 * (1.0 - _tap_age / 0.35)), false, 1.3, true)


func _draw_wires(center: Vector2, radius: float, state: int, even: bool) -> void:
	var diagonal := Vector2(radius * 0.44, radius * 0.44)
	if not even:
		diagonal.y *= -1.0
	for component in [Tutorial.RED, Tutorial.BLUE]:
		if state & component:
			var direction := diagonal if component == Tutorial.RED else Vector2(diagonal.x, -diagonal.y)
			var color := RED if component == Tutorial.RED else BLUE
			draw_line(center - direction + Vector2(0, 2), center + direction + Vector2(0, 2), Color("#08090e"), 8, true)
			draw_line(center - direction, center + direction, color.darkened(0.35), 7, true)
			draw_line(center - direction + Vector2(0, -1), center + direction + Vector2(0, -1), color, 4, true)
			for sign_value in [-1, 1]:
				_circle(center + direction * sign_value, 3.8, Color("#e9d9b8"))
				_circle(center + direction * sign_value, 2, color)


func _draw_tap_badge(center: Vector2, count: int) -> void:
	_circle(center + Vector2(0, 2), 12, Color("#3d251c"))
	_circle(center, 12, Color("#f4ca82"))
	var label := "×%d" % count
	_draw_text(label, center + Vector2(-_text_width(label, 12, true) * 0.5, 4), 12, INK, true)


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
		draw_polyline(points, Color("#280f1c"), 11.0, true)
		draw_polyline(points, RED.darkened(0.3), 8.0, true)
		draw_polyline(points, RED.lightened(0.15), 3.0, true)
		draw_line(points[0] - Vector2(0, spacing * 0.48), points[0], RED, 8.0, true)
		draw_line(points[-1], points[-1] + Vector2(0, spacing * 0.48), RED, 8.0, true)


func _draw_footer() -> void:
	_primary_rect = Rect2(18, 764, 354, 58)
	_secondary_rect = Rect2(18, 716, 354, 38)
	if model.dialogue_visible:
		_draw_dialogue()
		_draw_button(_primary_rect, "REPLAY" if model.finished else "OK", PINK, true)
		return
	if model.result_visible:
		_draw_result()
		var label := "TUTORIAL COMPLETE" if _definition.id == "graduation_3x3" else "NEXT"
		if _definition.id == "boundary_single":
			label = ("TRY BLUE" if model.boundary_phase == 0 else "NEXT") if _result_safe() else "TRY AGAIN"
		_draw_button(_primary_rect, label, GREEN if _result_safe() else PINK, true)
		return
	if _definition.id == "graduation_3x3":
		_draw_button(_secondary_rect, "SKIP OPTIONAL STAGE", Color("#49365e"), true)
	var enabled := model.can_call_foreman()
	if model.stage_index >= 3:
		_draw_button(_primary_rect, "CALL THE FOREMAN", AMBER if enabled else Color("#4b4156"), enabled)


func _draw_dialogue() -> void:
	var rect := Rect2(18, 610, 354, 137)
	_surface(rect, Color("#f0e5cf"), Color("#fff3db"), 20, 5)
	_draw_portrait(Vector2(70, 680), true)
	_draw_text("THE FOREMAN", Vector2(130, 638), 10, Color("#7a573e"), true)
	var text := "All seven lessons done!\nYou're ready to dance." if model.finished else String(_definition.coach)
	_draw_multiline(text, Vector2(130, 663), 18, Color("#302439"), 218)


func _draw_result() -> void:
	var safe := _result_safe()
	var rect := Rect2(18, 610, 354, 137)
	_surface(rect, Color("#292539"), Color("#5e5269"), 20, 5)
	_draw_portrait(Vector2(70, 680), false)
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
	elif _definition.id == "boundary_single":
		body = "One edge flicker cleared!"
	elif _definition.id == "graduation_3x3":
		heading = "GRADUATION: PASSED"
		body = "Practice floor is safe!"
	if not safe:
		heading = "POWER LEAK"
		color = RED
		body = "Red reaches the other side!" if model.inspection.red_crossing else "Blue reaches the other side!"
		if model.inspection.red_crossing and model.inspection.blue_crossing:
			body = "Both wires reach the other side!"
	_draw_text("FLOOR REPORT", Vector2(126, 636), 10, Color("#b6a6be"), true)
	_draw_text(heading, Vector2(126, 661), 18, color, true)
	_draw_multiline(body, Vector2(126, 689), 17, PAPER, 224)


func _result_safe() -> bool:
	return model.inspection.is_empty() or bool(model.inspection.get("safe", true))


func _draw_button(rect: Rect2, label: String, color: Color, enabled: bool) -> void:
	var secondary := rect.size.y < 45
	var base := Color("#3b3449") if not enabled else Color("#e8c38e")
	if color == GREEN:
		base = Color("#97dbbb")
	elif color == PINK:
		base = Color("#e8b4ca")
	if secondary:
		base = Color("#282333")
	var press := 0.0 if reduced_motion or _button_age >= 0.16 else 3.0 * sin(PI * _button_age / 0.16)
	var cap := Rect2(rect.position + Vector2(0, press), rect.size)
	_surface(cap, base, Color("#736080") if secondary else base.lightened(0.16), 16 if not secondary else 12, 5 - press)
	var text_color := Color("#2b2332") if enabled else Color("#a89aae")
	if secondary:
		text_color = Color("#dfd1e8")
	var font_size := 16 if not secondary else 12
	var width := _text_width(label, font_size, true)
	_draw_text(label, Vector2(cap.get_center().x - width * 0.5, cap.position.y + cap.size.y * 0.5 + 6), font_size, text_color, true)
	if enabled:
		var arrow := cap.position + Vector2(cap.size.x - 24, cap.size.y * 0.5)
		draw_polyline(PackedVector2Array([arrow + Vector2(-3, -4), arrow + Vector2(1, 0), arrow + Vector2(-3, 4)]), Color(text_color, 0.5), 2, true)


func _rounded_box(color: Color, radius: int) -> StyleBoxFlat:
	var key := color.to_html() + str(radius)
	if _style_cache.has(key):
		return _style_cache[key]
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	_style_cache[key] = box
	return box


func _draw_text(text: String, position: Vector2, font_size: int, color: Color, bold := false) -> void:
	var font: Font = BOLD_FONT if bold else FONT
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_multiline(text: String, position: Vector2, font_size: int, color: Color, width: float) -> void:
	var line_y := position.y
	for line in CopyLayout.wrap_lines(FONT, text, font_size, width):
		draw_string(FONT, Vector2(position.x, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
		line_y += font_size + 8


func _text_width(text: String, font_size: int, bold := false) -> float:
	var font: Font = BOLD_FONT if bold else FONT
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _publish_semantics() -> void:
	_definition = model.definition()
	_stage_count = model.stages().size()
	var state_json := JSON.stringify(model.semantic_state())
	if state_json == _last_state_json:
		return
	_last_state_json = state_json
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.discoBreakerState = %s; document.documentElement.dataset.tutorialStage = String(window.discoBreakerState.stage); document.title = 'DISCO BREAKER · ' + window.discoBreakerState.stage_id;" % state_json)


func _surface(rect: Rect2, base: Color, edge: Color, radius: int, depth: float) -> void:
	draw_style_box(_rounded_box(Color(0.025, 0.02, 0.045, 0.35), radius + 2), Rect2(rect.position + Vector2(0, depth + 3), rect.size).grow(2))
	draw_style_box(_rounded_box(base.darkened(0.42), radius), Rect2(rect.position + Vector2(0, depth), rect.size))
	draw_style_box(_rounded_box(edge, radius), rect)
	draw_style_box(_rounded_box(base, radius - 1), rect.grow(-1))
	draw_line(rect.position + Vector2(radius, 2), rect.position + Vector2(rect.size.x - radius, 2), Color(1, 0.96, 0.91, 0.12), 1)


func _draw_portrait(center: Vector2, light: bool) -> void:
	_circle(center + Vector2(0, 3), 41, Color(0.12, 0.07, 0.18, 0.2))
	_circle(center, 41, Color("#c0a47c") if light else Color("#63516a"))
	_circle(center, 38, Color("#fff2d5") if light else Color("#e5be88"))
	draw_texture_rect(FOREMAN, Rect2(center - Vector2(35, 35), Vector2(70, 70)), false)


func _draw_board_caption() -> void:
	var safe := model.result_visible and _result_safe()
	var caption := "TAP A SOCKET TO CHANGE THE WIRE"
	if model.dialogue_visible:
		caption = "LIGHTS OUT. MUSIC ON."
	elif model.result_visible:
		caption = "BEAUTIFULLY CONNECTED" if safe else "DARK DOESN'T ALWAYS MEAN SAFE"
	elif model.can_call_foreman():
		caption = "LIGHTS OUT. READY FOR INSPECTION."
	_draw_text(caption, Vector2(195 - _text_width(caption, 10, true) * 0.5, 506), 10, Color("#c7b5d0"), true)
	# A compact physical wire legend makes the tap cycle visible during play.
	for index in 4:
		var center := Vector2(138 + index * 38, 538)
		_circle(center + Vector2(0, 1), 10, Color("#090b12"))
		_circle(center, 9, Color("#363044"))
		if index == 0:
			_circle(center, 2, Color("#80718c"))
		else:
			_draw_wires(center, 12, index, true)
		if index < 3:
			_draw_text("›", center + Vector2(16, 4), 13, Color("#746580"))
	if safe and not reduced_motion and _success_age < 0.6:
		var alpha := (1.0 - _success_age / 0.6) * 0.6
		var rect := _board_rect.grow(18 + _success_age * 6)
		_outline(rect, Color(GREEN, alpha), 23)


func _circle(center: Vector2, radius: float, color: Color, filled := true, width := -1.0, _antialiased := true) -> void:
	draw_circle(center, radius, color, filled, width, true)


func _outline(rect: Rect2, color: Color, radius: int) -> void:
	var key := "outline" + color.to_html() + str(radius)
	if not _style_cache.has(key):
		var box := StyleBoxFlat.new()
		box.draw_center = false
		box.border_color = color
		box.set_border_width_all(1)
		box.set_corner_radius_all(radius)
		_style_cache[key] = box
	draw_style_box(_style_cache[key], rect)
