extends Control

const Title := preload("res://src/title_artwork.gd")
const Lesson := preload("res://src/lesson_artwork.gd")
const Tutorial := preload("res://src/tutorial_state.gd")
const Leaks := preload("res://src/leak_feedback.gd")
const LampGate := preload("res://src/lamp_sound_gate.gd")
const Rewards := preload("res://src/reward_feedback.gd")
const Sounds := preload("res://src/reward_sound.gd")
const Flicker := preload("res://src/fault_flicker.gd")
const FONT := preload("res://assets/fonts/NotoSansJP-Regular.otf")
const BOLD_FONT := preload("res://assets/fonts/NotoSansJP-Bold.tres")

const DESIGN_SIZE := Vector2(390, 844)
# Hit areas are the lesson's drawn plates (design px).
const HOME_RECT := Rect2(12, 12, 44, 44)
const LESSON_MUTE_RECT := Rect2(300, 12, 80, 44)
const PRIMARY_RECT := Rect2(16, 728, 356, 64)
const SECONDARY_RECT := Rect2(74, 642, 240, 52)
# Animations that have finished; resuming never replays them.
const SETTLED := 10.0

var model := Tutorial.new()
var at_title := true
var _tutorial_started := false
var _title_art := Title.new()
var _lesson_art := Lesson.new()
var _navigation_guard_until := 0
var reduced_motion := false
var _elapsed := 0.0
var _scale := 1.0
var _offset := Vector2.ZERO
var _last_state_json := ""
var _state: Dictionary = {}
var _definition: Dictionary = {}
var _tap_node_index := -1
var _tap_age := SETTLED
var _talk_age := SETTLED
var _success_age := SETTLED
var _enable_age := SETTLED
var _progress_age := SETTLED
var _progress_from := 0.0
var _progress_to := 0.0
var _last_utterance := ""
var _last_ready := false
var _rewards := Rewards.new()
var _audio := AudioStreamPlayer.new()
var _sting: AudioStreamWAV
var _final_sting: AudioStreamWAV
var _muted := false
var _sound_starts := 0
var _leaks := Leaks.new()
var _leak_age := SETTLED
var _leak_routes: Array[Dictionary] = []
var _discharge: AudioStreamWAV
var _leak_sound_starts := 0
var _lamp_audio := AudioStreamPlayer.new()
var _lamp_gate := LampGate.new()
var _lamp_ticks: Array[AudioStreamWAV] = []
var _lamp_keys := PackedInt32Array()
var _lamp_sound_starts := 0
var _lamp_last_key := -1
var _lamp_last_time := -1.0
var _audio_unlocked := false


func _ready() -> void:
	_sting = Sounds.make_sting()
	_final_sting = Sounds.make_sting(true)
	_discharge = Sounds.make_discharge()
	for variant in 3:
		_lamp_ticks.append(Sounds.make_lamp_tick(variant))
	_lamp_audio.volume_db = -24.0
	_lamp_audio.max_polyphony = 1
	add_child(_lamp_audio)
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
	_progress_from = model.progress()
	_progress_to = _progress_from
	_publish_semantics()
	queue_redraw()


func _process(delta: float) -> void:
	if not reduced_motion:
		_elapsed += delta
		_tap_age += delta
		_talk_age += delta
		_success_age += delta
		_enable_age += delta
		_progress_age += delta
		_leak_age += delta
		queue_redraw()
	_tick_lamp_audio()


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
	_audio_unlocked = true
	_update_transform()
	_handle_design_tap((point - _offset) / _scale)
	_publish_semantics()


# Headless/test commands: tap, inspect (call the foreman), next (Continue),
# skip (optional practice) and restart (after completion).
func inject_action(action: Dictionary) -> bool:
	if at_title:
		return false
	var accepted := false
	match String(action.get("type", "")):
		"tap":
			accepted = model.tap_node(int(action.get("row", -1)), int(action.get("column", -1)))
		"inspect":
			accepted = not model.inspect_floor().is_empty()
		"next":
			accepted = model.next_stage()
		"skip":
			accepted = model.skip_graduation()
		"restart":
			accepted = model.finished
			if accepted:
				model.restart()
	queue_redraw()
	_publish_semantics()
	return accepted


func semantic_state() -> Dictionary:
	var state := model.semantic_state()
	state["screen"] = "title" if at_title else "tutorial"
	state["tutorial_started"] = _tutorial_started
	state["campaign_available"] = false
	return state


func _handle_design_tap(point: Vector2) -> void:
	# The title's audio plate is drawn slightly larger than the lesson's.
	if (Title.MUTE_RECT if at_title else LESSON_MUTE_RECT).has_point(point):
		_toggle_mute()
		return
	if Time.get_ticks_msec() < _navigation_guard_until:
		return
	if at_title:
		if Title.TUTORIAL_RECT.has_point(point):
			_open_tutorial()
		return
	if HOME_RECT.has_point(point):
		_show_title()
		return
	if model.finished:
		if PRIMARY_RECT.has_point(point):
			_replay()
		elif SECONDARY_RECT.has_point(point):
			_show_title()
		return
	if PRIMARY_RECT.has_point(point):
		# A disabled button does nothing.
		if model.can_continue():
			model.next_stage()
		elif model.can_call_foreman():
			model.inspect_floor()
		queue_redraw()
		return
	if _definition.id == "graduation_3x3" and SECONDARY_RECT.has_point(point):
		model.skip_graduation()
		queue_redraw()
		return
	var node := Lesson.node_at(point)
	if node >= 0 and model.tap_node(int(node / 3.0), node % 3):
		_tap_node_index = node
		_tap_age = 0.0
		queue_redraw()


func _replay() -> void:
	model.restart()
	_navigation_guard_until = Time.get_ticks_msec() + 280
	queue_redraw()


func _open_tutorial() -> void:
	if model.finished:
		model.restart()
	at_title = false
	_tutorial_started = true
	_talk_age = 0.0
	# Entry and the bottom button overlap; a rapid second tap cannot act.
	_navigation_guard_until = Time.get_ticks_msec() + 280
	queue_redraw()


func _show_title() -> void:
	at_title = true
	_navigation_guard_until = Time.get_ticks_msec() + 280
	_audio.stop()
	_lamp_audio.stop()
	_lamp_gate.reset()
	# Keep the model and verdict for Continue, but never replay old effects/sounds.
	_settle_animations()
	queue_redraw()


func _settle_animations() -> void:
	_tap_age = SETTLED
	_talk_age = SETTLED
	_success_age = SETTLED
	_enable_age = SETTLED
	_progress_age = SETTLED
	_leak_age = SETTLED


# The 390 x 844 design space is scaled uniformly and centred.
func _update_transform() -> void:
	_scale = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_offset = (size - DESIGN_SIZE * _scale) * 0.5


func _draw() -> void:
	_update_transform()
	# Nothing to draw (and no device scale to rasterise at) in an empty control.
	if _scale <= 0.0:
		return
	if at_title:
		draw_set_transform(_offset, 0.0, Vector2.ONE * _scale)
		# The title paints its whole design area, including its own audio control.
		_title_art.draw(self, _elapsed, reduced_motion, _tutorial_started, model.finished)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_set_transform(_offset, 0.0, Vector2.ONE * _scale)
	var progress := _progress_to
	if not reduced_motion and _progress_age < 0.45:
		progress = lerpf(_progress_from, _progress_to, 1.0 - pow(1.0 - _progress_age / 0.45, 3.0))
	# Draw the state last published for input, not a per-frame recomputation.
	if _state.is_empty() or int(_state.action_count) != model.trace.size():
		_state = model.semantic_state()
	_lesson_art.draw(self, model, {
		"state": _state,
		"device_scale": Title.device_scale(self), "reduced": reduced_motion, "time": _elapsed,
		"muted": _muted, "progress": progress, "since_talk": _talk_age, "since_success": _success_age,
		"since_enable": _enable_age, "since_press": _tap_age, "pressed_node": _tap_node_index,
		"leak_age": _leak_age, "routes": _leak_routes,
	})
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Presentation only: the residual chains drawn after the parity verdict.
func _build_leak_routes() -> void:
	_leak_routes.clear()
	for component in [Tutorial.RED, Tutorial.BLUE]:
		var crossing := "red_crossing" if component == Tutorial.RED else "blue_crossing"
		if not bool(model.inspection.get(crossing, false)):
			continue
		var faces: Array = _definition.red_faces if component == Tutorial.RED else _definition.blue_faces
		var route := Leaks.route(faces, model._residual_support(component), int(_definition.size), component == Tutorial.RED)
		if route.is_empty():
			continue
		route.component = component
		route.points = Lesson.route_points(route, faces)
		_leak_routes.append(route)


func _draw_text(text: String, position: Vector2, font_size: int, color: Color, bold := false) -> void:
	var font: Font = BOLD_FONT if bold else FONT
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_width(text: String, font_size: int, bold := false) -> float:
	var font: Font = BOLD_FONT if bold else FONT
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _publish_semantics() -> void:
	_definition = model.definition()
	_state = model.semantic_state()
	var state := semantic_state()
	var event := _rewards.observe(state)
	if event == "reset":
		_success_age = SETTLED
		_audio.stop()
	elif not event.is_empty():
		if event in ["success", "finale"]:
			_success_age = 0.0
		if Rewards.wants_sound(event, _muted, AudioServer.is_bus_mute(0)):
			_audio.stream = _final_sting if event == "finale" else _sting
			_audio.play()
			_sound_starts += 1
	var leak_event := _leaks.observe(state)
	if leak_event == "reset":
		_leak_routes.clear()
		_leak_age = SETTLED
		_audio.stop()
	elif leak_event == "leak":
		_leak_age = 0.0
		_build_leak_routes()
		if not _muted and not AudioServer.is_bus_mute(0):
			_audio.stream = _discharge
			_audio.play()
			_leak_sound_starts += 1
	if _leaks.active and _leak_routes.is_empty():
		_build_leak_routes()
	# A new utterance is spoken; a newly available button hops once.
	var utterance := String(state.utterance.text)
	if utterance != _last_utterance:
		_last_utterance = utterance
		_talk_age = 0.0
	var ready := bool(state.can_continue) or bool(state.can_call_foreman)
	if ready and not _last_ready:
		_enable_age = 0.0
	_last_ready = ready
	if not is_equal_approx(float(state.progress), _progress_to):
		_progress_from = _progress_to
		_progress_to = float(state.progress)
		_progress_age = 0.0
	var state_json := JSON.stringify(state)
	if state_json != _last_state_json:
		_refresh_lamp_audio()
	_publish_feedback()
	if state_json == _last_state_json:
		return
	_last_state_json = state_json
	queue_redraw()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.discoBreakerState = %s; document.documentElement.dataset.tutorialStage = String(window.discoBreakerState.stage); document.documentElement.dataset.screen = window.discoBreakerState.screen; document.title = window.discoBreakerState.screen === 'title' ? 'DISCO BREAKER' : 'DISCO BREAKER · ' + %s;" % [state_json, JSON.stringify(String(_definition.title))])
		_announce(state)


# Screen readers hear the foreman's latest line and the button state, once
# per change, through a visually hidden live region.
func _announce(state: Dictionary) -> void:
	var text := "タイトル画面" if at_title else "レッスン %d / %d。親方「%s」。%s" % [
		state.stage, state.stage_count, String(state.utterance.text).replace("\n", ""),
		"もう一度 を押せる" if state.finished else ("つづける を押せる" if state.can_continue else ("親方を呼ぶ を押せる" if state.can_call_foreman else "つづける はまだ押せない"))]
	JavaScriptBridge.eval("(() => { let live = document.getElementById('disco-breaker-live'); if (!live) { live = document.createElement('div'); live.id = 'disco-breaker-live'; live.setAttribute('aria-live', 'polite'); live.setAttribute('role', 'status'); live.style.cssText = 'position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap'; document.body.appendChild(live); } const text = %s; if (live.textContent !== text) live.textContent = text; })()" % JSON.stringify(text))


func _toggle_mute() -> void:
	_muted = not _muted
	if _muted:
		_audio.stop()
		_lamp_audio.stop()
		_lamp_gate.reset()
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
			"muted": _muted, "reduced_motion": reduced_motion,
			"leak_active": _leaks.active and not at_title, "leak_events": _leaks.event_count,
			"leak_sound_starts": _leak_sound_starts, "lamp_sound_starts": _lamp_sound_starts,
			"lamp_last_key": _lamp_last_key, "lamp_last_time": _lamp_last_time,
			"lamp_last_brightness": Flicker.brightness(_lamp_last_key, _lamp_last_time) if _lamp_last_key >= 0 else 0.0,
			"revealed_hidden": _definition.hidden if model.fault_revealed() and not at_title else {}, "leak_routes": []}
		for route in ([] if at_title else _leak_routes):
			feedback.leak_routes.append({"component": route.component, "qubits": route.qubits, "checks": route.checks})
		JavaScriptBridge.eval("window.discoBreakerFeedback = %s;" % JSON.stringify(feedback))


func _refresh_lamp_audio() -> void:
	_lamp_audio.stop()
	_lamp_gate.reset()
	_lamp_keys.clear()
	for component in [Tutorial.RED, Tutorial.BLUE]:
		var checks := model.lit_red_checks() if component == Tutorial.RED else model.lit_blue_checks()
		for check in checks:
			_lamp_keys.append(model.stage_index * 1000 + int(_definition.size) * 100 + component * 40 + check)


func _tick_lamp_audio() -> void:
	var enabled := not at_title and _audio_unlocked and not _muted and not reduced_motion and not AudioServer.is_bus_mute(0) and not model.finished
	var key := _lamp_gate.poll(_lamp_keys, _elapsed, enabled)
	if not enabled:
		_lamp_audio.stop()
	if key < 0:
		return
	_lamp_audio.stream = _lamp_ticks[(key + _lamp_sound_starts) % _lamp_ticks.size()]
	_lamp_audio.play()
	_lamp_sound_starts += 1
	_lamp_last_key = key
	_lamp_last_time = _elapsed
	_publish_feedback()
