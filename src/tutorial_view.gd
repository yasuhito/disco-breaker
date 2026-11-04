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
# Original synthesized bell chosen for lesson 1 (provenance: assets/sounds/README.md).
const LESSON1_BELL := preload("res://assets/sounds/lesson1_success_bell.wav")
# Original synthesized press chosen for the title's tutorial plate (same README).
const TITLE_PRESS := preload("res://assets/sounds/title_tutorial_press.wav")

const DESIGN_SIZE := Vector2(390, 844)
# Hit areas are the lesson's drawn plates (design px).
const HOME_RECT := Rect2(12, 12, 44, 44)
const LESSON_MUTE_RECT := Rect2(300, 12, 80, 44)
const PRIMARY_RECT := Rect2(16, 728, 356, 64)
const SECONDARY_RECT := Rect2(74, 642, 240, 52)
# Animations that have finished; resuming never replays them.
const SETTLED := 10.0
# Lesson 4's called inspection: the foreman says he is checking (seconds)
# before his verdict is shown and Continue enabled.
const COUNT_TIME := 1.0
# An accepted title tutorial press: the plate goes down and back up over this
# time (seconds), then the lesson opens. Reduced motion opens it at once.
const PRESS_TIME := 0.15
# A tap that changes which floors are lit shows why: the socket's changed
# wire glows, floors it turned dark get a gold outline and floors it newly lit
# an outline in their own colour, all fading out (seconds).
const CHANGE_TIME := 0.45
# Lesson 5's first leak is explained step by step; input stays available,
# any later action ends it, a bubble tap moves on or replays. Each step stays
# long enough to read: 0.2 s per character (about 5 a second, a slow young
# reader's pace), at least 2.5 s.
const EXPLAIN_STEP := 2.5
const EXPLAIN_PER_CHARACTER := 0.2

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
var _count_age := SETTLED
var _count_sequence := -1
var _pending_reward := ""
var _pending_leak_sound := false
var _rewards := Rewards.new()
var _audio := AudioStreamPlayer.new()
var _sting: AudioStreamWAV
var _final_sting: AudioStreamWAV
var _last_reward_sound := ""
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
# The last tap's lit-to-dark and dark-to-lit floors ({component, check}) and
# the wires whose change caused them ({component, present}); valid only for
# that action.
var _darkened: Array[Dictionary] = []
var _lit: Array[Dictionary] = []
var _changed_wires: Array[Dictionary] = []
var _change_node := -1
var _change_age := SETTLED
var _change_sequence := -1
var _explain_sequence := -1
var _explain_age := 0.0
var _explain_steps: PackedStringArray = []
# The current full explanation has been shown up to its count; recorded in
# the model once a later action in the same lesson ends it.
var _explain_reached := false
var _explain_stage_id := ""
# The title press has its own player, so nothing that stops lesson audio on
# entry can cut it; only mute does.
var _press_audio := AudioStreamPlayer.new()
var _press_age := -1.0
var _title_presses := 0
var _press_sound_starts := 0


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
	# 4 dB above the other sounds: the short press was too quiet at -8 dB.
	_press_audio.volume_db = -4.0
	_press_audio.stream = TITLE_PRESS
	add_child(_press_audio)
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
	var counting := _counting()
	if not reduced_motion:
		_count_age += delta
		_elapsed += delta
		_tap_age += delta
		_talk_age += delta
		_success_age += delta
		_enable_age += delta
		_progress_age += delta
		_leak_age += delta
		queue_redraw()
	if counting and not _counting():
		_finish_counting()
	# Runs in reduced motion too: only the words change.
	if _explaining() and _explain_age < _explain_start(_explain_steps.size()):
		var step := _explain_step()
		_explain_age += delta
		if _explain_step() != step:
			_note_explain_progress()
			_publish_semantics()
	# Runs in reduced motion too, where the outline is static and then gone.
	if _change_age < CHANGE_TIME:
		_change_age += delta
		queue_redraw()
		if _change_age >= CHANGE_TIME:
			_publish_feedback()
	if _press_age >= 0.0:
		_press_age += delta
		queue_redraw()
		if _press_age >= PRESS_TIME:
			_press_age = -1.0
			_open_tutorial()
			_publish_semantics()
	_tick_lamp_audio()


# The counting presentation belongs to one inspected board; any later action,
# home or reduced motion ends it (reduced motion never starts it).
func _counting() -> bool:
	return not reduced_motion and not at_title and _count_age < COUNT_TIME and model.trace.size() == _count_sequence


# The verdict is spoken (and celebrated) after the foreman has counted.
func _finish_counting() -> void:
	_count_age = SETTLED
	if model.trace.size() == _count_sequence:
		if not _pending_reward.is_empty():
			_success_age = 0.0
			_play_reward(_pending_reward)
		if _pending_leak_sound:
			_play_discharge()
	_pending_reward = ""
	_pending_leak_sound = false
	_publish_semantics()


func _play_reward(event: String) -> void:
	if Rewards.wants_sound(event, _muted, AudioServer.is_bus_mute(0)):
		_last_reward_sound = Rewards.sound_for(event, String(_definition.id))
		_audio.stream = {"finale": _final_sting, "lesson1_bell": LESSON1_BELL}.get(_last_reward_sound, _sting)
		_audio.play()
		_sound_starts += 1


func _play_discharge() -> void:
	if not _muted and not AudioServer.is_bus_mute(0):
		_audio.stream = _discharge
		_audio.play()
		_leak_sound_starts += 1


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
			accepted = _tap(int(action.get("row", -1)), int(action.get("column", -1)))
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
	# The view's presentation of the verdict: while the foreman counts,
	# Continue is shown disabled and ignores taps.
	state["counting"] = _counting()
	state["continue_enabled"] = model.can_continue() and not state.counting
	state["explain_step"] = _explain_step()
	state["explain_steps"] = _explain_steps.size() if _explaining() else 0
	return state


# A full explanation counts as shown once its count step is on screen.
func _note_explain_progress() -> void:
	if _explain_steps.size() > 2 and _explain_step() >= _explain_steps.size() - 2:
		_explain_reached = true


# The explanation belongs to one inspected board; any later action ends it.
func _explaining() -> bool:
	return not at_title and not _explain_steps.is_empty() and model.trace.size() == _explain_sequence


# The step being shown, or -1 (none, or the foreman is still checking).
func _explain_step() -> int:
	if not _explaining() or _explain_age < 0.0:
		return -1
	var step := 0
	while step < _explain_steps.size() - 1 and _explain_age >= _explain_start(step + 1):
		step += 1
	return step


# When a step of the current explanation starts (seconds after the check).
func _explain_start(step: int) -> float:
	var start := 0.0
	for i in mini(step, _explain_steps.size()):
		start += step_seconds(_explain_steps[i])
	return start


static func step_seconds(text: String) -> float:
	return maxf(EXPLAIN_STEP, text.replace("\n", "").length() * EXPLAIN_PER_CHARACTER)


# How much of the counting lesson's teaching the board shows for this check:
# 0 the original fault, 1 cancelled sockets, 2 leftover marks, 3 the counts.
func _teach_level() -> int:
	if _counting():
		return -1
	if _explaining():
		var step := _explain_step()
		if step < 0:
			return -1
		return step if _explain_steps.size() > 2 else 3
	return 3


func _handle_design_tap(point: Vector2) -> void:
	# The title's audio plate is drawn slightly larger than the lesson's.
	if (Title.MUTE_RECT if at_title else LESSON_MUTE_RECT).has_point(point):
		_toggle_mute()
		return
	if Time.get_ticks_msec() < _navigation_guard_until:
		return
	if at_title:
		# One press per accepted tap: further taps wait for the lesson to open.
		if Title.TUTORIAL_RECT.has_point(point) and _press_age < 0.0:
			_press_tutorial()
		return
	if HOME_RECT.has_point(point):
		_show_title()
		return
	# The explanation's bubble: a tap shows the next step, or replays it.
	if _explaining() and _explain_step() >= 0 and Lesson.px(Lesson.BUBBLE).has_point(point):
		var step := _explain_step()
		_explain_age = _explain_start(step + 1) if step < _explain_steps.size() - 1 else 0.0
		_note_explain_progress()
		_publish_semantics()
		queue_redraw()
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
			if not _counting():
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
	if node >= 0 and _tap(int(node / 3.0), node % 3):
		_tap_node_index = node
		_tap_age = 0.0
		queue_redraw()


# A wiring tap, remembering which floors it turned dark or lit (from the
# model's lit checks just before and after) and which of the socket's wires
# changed for a family whose floors changed.
func _tap(row: int, column: int) -> bool:
	var size := int(model.definition().size)
	var node := row * size + column
	var before := {Tutorial.RED: model.lit_red_checks(), Tutorial.BLUE: model.lit_blue_checks()}
	var code := int(model.corrections[node]) if row >= 0 and row < size and column >= 0 and column < size else 0
	if not model.tap_node(row, column):
		return false
	var changed := code ^ int(model.corrections[node])
	_darkened.clear()
	_lit.clear()
	_changed_wires.clear()
	for component in [Tutorial.RED, Tutorial.BLUE]:
		var after := model.lit_red_checks() if component == Tutorial.RED else model.lit_blue_checks()
		var count := _darkened.size() + _lit.size()
		for check in before[component]:
			if not after.has(check):
				_darkened.append({"component": component, "check": check})
		for check in after:
			if not before[component].has(check):
				_lit.append({"component": component, "check": check})
		if _darkened.size() + _lit.size() > count and changed & component:
			_changed_wires.append({"component": component, "present": bool(model.corrections[node] & component)})
	_change_node = node
	_change_sequence = model.trace.size()
	_change_age = 0.0 if not (_darkened.is_empty() and _lit.is_empty()) else SETTLED
	return true


# The presentation belongs to the action that caused it.
func _showing_change() -> bool:
	return not at_title and _change_age < CHANGE_TIME and model.trace.size() == _change_sequence


func _replay() -> void:
	model.restart()
	_navigation_guard_until = Time.get_ticks_msec() + 280
	queue_redraw()


func _press_tutorial() -> void:
	_title_presses += 1
	if not _muted and not AudioServer.is_bus_mute(0):
		_press_audio.play()
		_press_sound_starts += 1
	if reduced_motion:
		_open_tutorial()
	else:
		_press_age = 0.0
		queue_redraw()


# How far the title's tutorial plate is pushed in (0 at rest).
func _title_press() -> float:
	return sin(PI * _press_age / PRESS_TIME) if _press_age > 0.0 else 0.0


func _open_tutorial() -> void:
	# A new or restarted lesson is spoken; a resumed one keeps its settled line.
	if model.finished or not _tutorial_started:
		_talk_age = 0.0
	if model.finished:
		model.restart()
	at_title = false
	_tutorial_started = true
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
	# The current line counts as spoken: resuming does not animate it again.
	_last_utterance = String(model.utterance().text)
	queue_redraw()


func _settle_animations() -> void:
	_tap_age = SETTLED
	_talk_age = SETTLED
	_success_age = SETTLED
	_enable_age = SETTLED
	_progress_age = SETTLED
	_leak_age = SETTLED
	_count_age = SETTLED
	_change_age = SETTLED
	# A resumed explanation shows its last word, already settled.
	_explain_age = _explain_start(_explain_steps.size())
	_pending_reward = ""
	_pending_leak_sound = false


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
		_title_art.draw(self, _elapsed, reduced_motion, _tutorial_started, model.finished, _title_press())
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
		"counting": _count_age if _counting() else -1.0,
		"teach_level": _teach_level(), "spoken": _spoken(semantic_state()),
		"change": {"node": _change_node, "darkened": _darkened, "lit": _lit, "wires": _changed_wires, "age": _change_age} if _showing_change() else {},
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
	var last: Dictionary = _state.last_action
	if not reduced_motion and not at_title and last.get("action", "") == "inspect" and not bool(last.payload.get("auto", true)) \
			and _definition.lines.has("call") and int(_state.action_count) != _count_sequence:
		_count_sequence = int(_state.action_count)
		_count_age = 0.0
	# An explanation that reached its count and was then ended by an action in
	# the same lesson counts as shown: a later leak repeats only the count.
	if _explain_reached and model.trace.size() != _explain_sequence:
		_explain_reached = false
		var after: Dictionary = model.trace[-1]
		if String(after.stage_id) == _explain_stage_id and String(after.action) in ["tap_node", "inspect"]:
			model.mark_leak_explained()
	# Lesson 5 explains a leak step by step once the foreman has checked.
	if not at_title and last.get("action", "") == "inspect" and int(_state.action_count) != _explain_sequence \
			and model.counts_pairs() and _definition.lines.has("steps") and not bool(model.inspection.get("safe", true)):
		_explain_sequence = int(_state.action_count)
		_explain_stage_id = String(_definition.id)
		_explain_reached = false
		_explain_steps = PackedStringArray()
		if not model.leak_explained:
			for line in _definition.lines.steps:
				_explain_steps.append(String(line))
			# Say honestly when this board has nothing that cancels yet.
			if model.cancelled_sockets().is_empty():
				_explain_steps[1] = String(_definition.lines.steps_no_cancel)
		_explain_steps.append(model.count_summary())
		_explain_steps.append(String(model.utterance().text))
		_explain_age = -COUNT_TIME if _counting() else 0.0
	if not _counting():
		_pending_reward = ""
		_pending_leak_sound = false
	var state := semantic_state()
	var event := _rewards.observe(state)
	if event == "reset":
		_success_age = SETTLED
		_audio.stop()
	elif event in ["success", "finale"] and _counting():
		_pending_reward = event
	elif not event.is_empty():
		if event in ["success", "finale"]:
			_success_age = 0.0
		_play_reward(event)
	var leak_event := _leaks.observe(state)
	if leak_event == "reset":
		_leak_routes.clear()
		_leak_age = SETTLED
		_audio.stop()
	elif leak_event == "leak":
		_build_leak_routes()
		# After counting, the leak presentation starts with its discharge.
		_leak_age = -COUNT_TIME if _counting() else 0.0
		if _counting():
			_pending_leak_sound = true
		else:
			_play_discharge()
	if _leaks.active and _leak_routes.is_empty():
		_build_leak_routes()
	# A new utterance is spoken; a newly available button hops once.
	var utterance := _spoken(state)
	if utterance != _last_utterance:
		_last_utterance = utterance
		_talk_age = 0.0
	var ready := bool(state.continue_enabled) or bool(state.can_call_foreman)
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


# The line in the bubble: the foreman counts first in lesson 4.
func _spoken(state: Dictionary) -> String:
	if state.get("counting", false):
		return String(_definition.lines.call)
	if int(state.get("explain_step", -1)) >= 0:
		return _explain_steps[int(state.explain_step)]
	return String(state.utterance.text)


# Screen readers hear the foreman's latest line and the button state, once
# per change, through a visually hidden live region.
func _announce(state: Dictionary) -> void:
	var text := "タイトル画面" if at_title else "レッスン %d / %d。親方「%s」。%s" % [
		state.stage, state.stage_count, _readable(_spoken(state)), _button_announcement(state)]
	JavaScriptBridge.eval("(() => { let live = document.getElementById('disco-breaker-live'); if (!live) { live = document.createElement('div'); live.id = 'disco-breaker-live'; live.setAttribute('aria-live', 'polite'); live.setAttribute('role', 'status'); live.style.cssText = 'position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap'; document.body.appendChild(live); } const text = %s; if (live.textContent !== text) live.textContent = text; })()" % JSON.stringify(text))


# A bubble's lines as one announcement: prose lines run on, and a count line
# without closing punctuation (「赤：上の段 1こ→あまり1こ」) is closed with 「。」
# so two colours stay apart.
static func _readable(text: String) -> String:
	var result := ""
	for line in text.split("\n"):
		result += line
		if line.contains("→") and not line[-1] in ["。", "！", "？", "、"]:
			result += "。"
	return result


# The bottom button as drawn (lesson_artwork.gd draw()): its label and
# whether it can be pressed. A call-mode lesson's disabled button is its call
# button, not Continue.
func _button_announcement(state: Dictionary) -> String:
	if state.finished:
		return "もう一度 を押せる"
	if state.continue_enabled:
		return "つづける を押せる"
	if state.inspection_mode == "call":
		return model.call_label() + (" を押せる" if state.can_call_foreman else " はまだ押せない")
	return "つづける はまだ押せない"


func _toggle_mute() -> void:
	_muted = not _muted
	if _muted:
		_audio.stop()
		_press_audio.stop()
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
			"success_count": _rewards.success_count, "sound_starts": _sound_starts, "last_reward_sound": _last_reward_sound,
			"title_presses": _title_presses, "title_press_sound_starts": _press_sound_starts, "title_pressing": _press_age >= 0.0,
			"wiring": {"active": _showing_change(), "node": _change_node, "darkened": _darkened, "lit": _lit, "wires": _changed_wires, "sequence": _change_sequence},
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
