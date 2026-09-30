extends Control

const Tutorial := preload("res://src/tutorial_state.gd")
const Rewards := preload("res://src/reward_feedback.gd")
const Sounds := preload("res://src/reward_sound.gd")
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
var _glass_light: GradientTexture2D
var _style_cache: Dictionary = {}
var _tap_node_index := -1
var _tap_age := 1.0
var _button_age := 1.0
var _rewards := Rewards.new()
var _reward_age := 2.0
var _audio := AudioStreamPlayer.new()
var _sting: AudioStreamWAV
var _final_sting: AudioStreamWAV
var _muted := false
var _sound_starts := 0
var _mute_rect := Rect2(290, 14, 76, 44)


func _ready() -> void:
	# Shared, quiet diagonal reflection across the entire glass floor.
	_glass_reflection = GradientTexture2D.new()
	_glass_reflection.width = 256
	_glass_reflection.height = 256
	_glass_reflection.fill_from = Vector2.ZERO
	_glass_reflection.fill_to = Vector2.ONE
	_glass_reflection.gradient = Gradient.new()
	_glass_reflection.gradient.offsets = PackedFloat32Array([0.0, 0.23, 0.27, 0.38, 0.42, 0.70, 1.0])
	_glass_reflection.gradient.colors = PackedColorArray([
		Color(0.86, 0.93, 1, 0.02), Color(0.86, 0.93, 1, 0.02),
		Color(0.86, 0.93, 1, 0.15), Color(0.86, 0.93, 1, 0.06),
		Color(0.86, 0.93, 1, 0.01), Color(0.86, 0.93, 1, 0.01),
		Color(0.86, 0.93, 1, 0.05)])
	_glass_light = GradientTexture2D.new()
	_glass_light.width = 64
	_glass_light.height = 64
	_glass_light.fill = GradientTexture2D.FILL_RADIAL
	_glass_light.fill_from = Vector2(0.5, 0.5)
	_glass_light.fill_to = Vector2(1.15, 0.5)
	_glass_light.gradient = Gradient.new()
	_glass_light.gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	_glass_light.gradient.colors = PackedColorArray([Color(1, 1, 1, 0.50), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0)])
	_sting = Sounds.make_sting()
	_final_sting = Sounds.make_sting(true)
	_audio.volume_db = -8.0
	add_child(_audio)
	var preferences := ConfigFile.new()
	if preferences.load("user://audio.cfg") == OK:
		_muted = bool(preferences.get_value("audio", "muted", false))
	if OS.has_feature("web"):
		_muted = bool(JavaScriptBridge.eval("(() => { try { return localStorage.getItem('disco-breaker-muted') === '1'; } catch (_) { return false; } })()"))
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
		_reward_age += delta
		queue_redraw()


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
	if _mute_rect.has_point(point):
		_toggle_mute()
		return
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
	_draw_mute_toggle()
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
	var red_checks := model.lit_red_checks()
	var blue_checks := model.lit_blue_checks()
	# Draw leaked light below all panels, so it cannot relight a dark neighbor.
	for layer in 2:
		for component in [Tutorial.RED, Tutorial.BLUE]:
			var faces: Array = d.red_faces if component == Tutorial.RED else d.blue_faces
			var lit_checks := red_checks if component == Tutorial.RED else blue_checks
			var color := RED if component == Tutorial.RED else BLUE
			for check in faces.size():
				var face: Dictionary = faces[check]
				var center: Vector2 = _board_rect.position + face.center * spacing
				var extent: Vector2 = face.extent * spacing
				var lit := lit_checks.has(check)
				var lamp_key: int = model.stage_index * 1000 + grid_size * 100 + component * 40 + check
				var intensity := Flicker.brightness(lamp_key, _elapsed, reduced_motion) if lit else 0.0
				var panel := Rect2(center - extent * 0.5, extent)
				if layer == 0:
					if lit:
						_draw_glass_glow(panel, color, intensity)
				else:
					_draw_panel(panel, color, intensity, lit)
	_draw_reward_wave()
	_draw_nodes(grid_size, spacing)
	if not model.inspection.is_empty() and not bool(model.inspection.safe):
		_draw_witness(grid_size, spacing)


func _draw_glass_glow(rect: Rect2, color: Color, intensity: float) -> void:
	# Thin nested contours soften all four edges without fullscreen bloom.
	# This is the fault lamp's envelope, separate from the success sweep.
	for spread in range(8, 0, -1):
		var alpha := intensity * 0.42 * pow(1.0 - float(spread) / 10.0, 2.0)
		draw_rect(rect.grow(float(spread) - 1.0), Color(color, alpha), false, 1)


func _draw_panel(rect: Rect2, color: Color, intensity: float, lit: bool) -> void:
	var glass := rect.grow(-2)
	draw_rect(rect, Color("#090c14"))
	# Light lives below a flush glass sheet, never on a raised lamp at its center.
	# A faint colored edge persists through a dropout, but disappears on repair.
	var base := Color("#192431")
	if lit:
		base = base.lerp(color.darkened(0.52), 0.24 + intensity * 0.54)
	draw_rect(glass, base)
	if lit:
		draw_texture_rect(_glass_light, glass.grow(-2), false, Color(color, 0.14 + intensity * 0.84))
		for inset in range(1, 5):
			draw_rect(glass.grow(-float(inset)), Color(color, intensity * 0.16 * (1.0 - float(inset) / 5.0)), false, 1)
	var reflection_region := Rect2((glass.position - _board_rect.position) / _board_rect.size * 256.0, glass.size / _board_rect.size * 256.0)
	draw_texture_rect_region(_glass_reflection, glass, reflection_region)
	var rim := Color(color, 0.38 + intensity * 0.25) if lit else Color(0.42, 0.58, 0.70, 0.24)
	draw_rect(glass.grow(-2), rim, false, 1)
	# The same top-left highlight and bottom-right refraction on every panel.
	var top_left := glass.position + Vector2(0.5, 0.5)
	var top_right := Vector2(glass.end.x - 0.5, glass.position.y + 0.5)
	var bottom_left := Vector2(glass.position.x + 0.5, glass.end.y - 0.5)
	var bottom_right := glass.end - Vector2(0.5, 0.5)
	draw_line(top_left, top_right, Color(0.78, 0.9, 1, 0.29), 1)
	draw_line(top_left, bottom_left, Color(0.67, 0.84, 0.96, 0.19), 1)
	draw_line(bottom_left, bottom_right, Color(0.03, 0.07, 0.12, 0.9), 2)
	draw_line(top_right, bottom_right, Color(0.03, 0.07, 0.12, 0.8), 2)


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
		if model.stage_index != 4 and not _result_safe():
			label = "TRY AGAIN"
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
	return not model.inspection.is_empty() and bool(model.inspection.get("safe", false))


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
	var state := model.semantic_state()
	var event := _rewards.observe(state)
	if event == "reset":
		_reward_age = 2.0
		_audio.stop()
	elif not event.is_empty():
		_reward_age = 0.0
		if Rewards.wants_sound(event, _muted, AudioServer.is_bus_mute(0)):
			_audio.stream = _final_sting if event == "finale" else _sting
			_audio.play()
			_sound_starts += 1
	_publish_feedback()
	var state_json := JSON.stringify(state)
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
	var celebrating := _rewards.kind in ["success", "finale"] and model.result_visible and _result_safe()
	if celebrating and not reduced_motion and _reward_age < 0.45:
		center.y -= sin(PI * _reward_age / 0.45) * 7.0
	_circle(center + Vector2(0, 3), 41, Color(0.12, 0.07, 0.18, 0.2))
	_circle(center, 41, Color("#c0a47c") if light else Color("#63516a"))
	_circle(center, 38, Color("#fff2d5") if light else Color("#e5be88"))
	draw_texture_rect(FOREMAN, Rect2(center - Vector2(35, 35), Vector2(70, 70)), false)
	if celebrating:
		var badge := center + Vector2(29, 23)
		_circle(badge, 12, Color("#97dbbb"))
		draw_polyline(PackedVector2Array([badge + Vector2(-5, 0), badge + Vector2(-1, 4), badge + Vector2(6, -5)]), INK, 2.5, true)


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


func _draw_reward_wave() -> void:
	if reduced_motion or _rewards.kind.is_empty():
		return
	var finale := _rewards.kind == "finale"
	var success := _rewards.kind in ["success", "finale"]
	var duration := 0.85 if finale else 0.45
	if _reward_age >= duration:
		return
	var progress := clampf(_reward_age / duration, 0.0, 1.0)
	var strength := sin(PI * progress)
	var tint := Color("#f4ca82") if success else Color("#bed2e5")
	var y := _board_rect.position.y + 10 + progress * (_board_rect.size.y - 20)
	# A narrow sweep over the glass, below the sockets; it never relights a syndrome.
	draw_line(Vector2(_board_rect.position.x + 5, y), Vector2(_board_rect.end.x - 5, y), Color(tint, strength * 0.13), 8, true)
	draw_line(Vector2(_board_rect.position.x + 5, y), Vector2(_board_rect.end.x - 5, y), Color(tint, strength * 0.45), 1.5, true)
	if not success:
		return
	_outline(_board_rect.grow(17 + progress * 4), Color(tint, (1.0 - progress) * 0.55), 23)
	var count := 12 if finale else 6
	for index in count:
		var angle := TAU * float(index) / count + 0.15
		var origin := _board_rect.get_center() + Vector2(cos(angle), sin(angle)) * 158
		var drift := Vector2(cos(angle), sin(angle)) * progress * (15 if finale else 8)
		var center := origin + drift
		var radius := (2.8 if finale else 1.8) * (1.0 - progress)
		_circle(center, maxf(radius, 0.3), Color(tint, strength * 0.7))


func _draw_mute_toggle() -> void:
	_surface(_mute_rect, Color("#302939"), Color("#5e506b"), 12, 2)
	var center := _mute_rect.position + Vector2(18, 22)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-7, -3), center + Vector2(-3, -3), center + Vector2(2, -7), center + Vector2(2, 7), center + Vector2(-3, 3), center + Vector2(-7, 3)]), Color("#cfc0d8"))
	if _muted:
		draw_line(center + Vector2(-8, -8), center + Vector2(8, 8), Color("#f1b4c3"), 2, true)
	else:
		draw_arc(center + Vector2(1, 0), 8, -0.8, 0.8, 10, Color("#cfc0d8"), 1.5, true)
	_draw_text("OFF" if _muted else "ON", _mute_rect.position + Vector2(39, 27), 11, PAPER, true)


func _toggle_mute() -> void:
	_muted = not _muted
	if _muted:
		_audio.stop()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.setItem('disco-breaker-muted', '%s'); } catch (_) {}" % ("1" if _muted else "0"))
	else:
		var preferences := ConfigFile.new()
		preferences.set_value("audio", "muted", _muted)
		preferences.save("user://audio.cfg")
	queue_redraw()


func _publish_feedback() -> void:
	if OS.has_feature("web"):
		var feedback := {"kind": _rewards.kind, "event_count": _rewards.event_count,
			"success_count": _rewards.success_count, "sound_starts": _sound_starts,
			"muted": _muted, "reduced_motion": reduced_motion}
		JavaScriptBridge.eval("window.discoBreakerFeedback = %s;" % JSON.stringify(feedback))
