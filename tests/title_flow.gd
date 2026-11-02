extends SceneTree

const View := preload("res://src/tutorial_view.gd")
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := View.new()
	root.add_child(view)
	view.size = Vector2(390, 844)
	view.reduced_motion = true
	await process_frame
	await process_frame
	var initial: Dictionary = view.semantic_state()
	_expect(initial.screen == "title" and not initial.campaign_available, "launch shows title, not campaign")
	# Title plates are exactly their drawn bounds.
	var was_muted: bool = view._muted
	var mute: Rect2 = View.Title.MUTE_RECT
	view._handle_design_tap(mute.end - Vector2(0.5, 0.5))
	_expect(view._muted != was_muted, "the drawn title audio plate's far corner toggles sound")
	view._handle_design_tap(mute.position)
	_expect(view._muted == was_muted, "the drawn title audio plate's near corner toggles sound")
	for outside in [mute.position - Vector2(0.5, 0), mute.position - Vector2(0, 0.5), mute.end + Vector2(0.5, -1), mute.end + Vector2(-1, 0.5)]:
		view._handle_design_tap(outside)
	_expect(view._muted == was_muted, "taps just outside the title audio plate are ignored")
	view._handle_design_tap(Vector2(195, 675))
	view._handle_design_tap(Vector2(195, 309))
	_expect(view.semantic_state() == initial, "disabled repair and decorative floor cannot change tutorial")
	_expect(not view.inject_action({"type": "tap", "row": 1, "column": 1}), "hidden tutorial cannot accept injected input")
	var plate: Rect2 = View.Title.TUTORIAL_RECT
	var start: Rect2 = View.Title.REPAIR_RECT
	view._handle_design_tap(Vector2(plate.position.x - 0.5, 780))
	view._handle_design_tap(Vector2(plate.end.x + 0.5, 780))
	view._handle_design_tap(Vector2(195, plate.position.y - 0.5))
	view._handle_design_tap(Vector2(195, plate.end.y + 0.5))
	view._handle_design_tap(Vector2(195, (start.end.y + plate.position.y) * 0.5))
	view._handle_design_tap(start.position)
	view._handle_design_tap(start.end - Vector2(0.5, 0.5))
	_expect(view.semantic_state() == initial, "taps outside the drawn tutorial plate, in the gap or on the disabled plate do nothing")
	# The plate's bottom lip is part of the button.
	view._handle_design_tap(Vector2(195, plate.end.y - 0.5))
	_expect(not view.at_title and view.model.stage_index == 0 and not view.model.touched, "the tutorial opens on an editable first lesson")
	_expect(view._talk_age == 0.0, "a new lesson is spoken")
	view._navigation_guard_until = 0
	view._handle_design_tap(Vector2(194, 396))
	view._publish_semantics()
	_expect(view.model.can_continue(), "the first lesson passes in one tap, without a dialogue")
	var playing: Dictionary = view.model.semantic_state()
	view._handle_design_tap(Vector2(34, 34))
	_expect(view.at_title and not view._audio.playing and not view._lamp_audio.playing, "home stops tutorial sound")
	# Entry and Continue overlap: a rapid second tap cannot skip a lesson.
	view._navigation_guard_until = 0
	view._handle_design_tap(Vector2(195, 780))
	view._handle_design_tap(Vector2(195, 760))
	_expect(not view.at_title and view.model.semantic_state() == playing, "continue preserves corrections, inspection and trace; a double tap cannot advance")
	_expect(view._talk_age >= View.SETTLED and view._success_age >= View.SETTLED, "resuming keeps the settled line and never replays the talk or the success")
	# A revealed leak can be left/resumed without replaying the discharge.
	view.model.stage_index = 4
	view.model._reset_stage()
	view.model._record("next_stage", {})
	view._publish_semantics()
	view._navigation_guard_until = 0
	view._handle_design_tap(Vector2(194, 760))
	view._publish_semantics()
	_expect(view._leaks.active and view._leak_age == 0.0 and not view.model.passed(), "calling the foreman on the trap reveals a leak, not a pass")
	var leak_count: int = view._leak_sound_starts
	view._show_title()
	view._publish_semantics()
	view._open_tutorial()
	view._publish_semantics()
	_expect(view._leak_sound_starts == leak_count and view._leaks.active, "resuming leak keeps explanation without replaying sound")
	_expect(view._leak_age >= View.SETTLED, "resumed leak is a settled static explanation")
	view.model.stage_index = 6
	view.model._reset_stage()
	view.model.skip_graduation()
	view._publish_semantics()
	view._show_title()
	view._open_tutorial()
	view._publish_semantics()
	_expect(not view.model.finished and view.model.stage_index == 0 and not view.model.touched, "completed/skip return then replay restarts all seven lessons")
	_expect(view._rewards.kind.is_empty() and not view._leaks.active, "replay clears reward, leak and original error reveal")
	view.model.stage_index = 6
	view.model._reset_stage()
	view.model.skip_graduation()
	view._publish_semantics()
	view._navigation_guard_until = 0
	view._handle_design_tap(Vector2(195, 760))
	view._handle_design_tap(Vector2(194, 396))
	view._handle_design_tap(Vector2(195, 760))
	_expect(view.model.stage_index == 0 and not view.model.touched and not view.model.finished, "a rapid second tap after Replay cannot act on the first lesson")
	view.model.skip_graduation()
	view._navigation_guard_until = 0
	view.model.stage_index = 6
	view.model._reset_stage()
	view.model.skip_graduation()
	view._handle_design_tap(View.SECONDARY_RECT.get_center())
	_expect(view.at_title and view.model.finished, "the completion screen returns to the title")
	_test_title_press(view)
	# Stopped playback leaves the audio server on its own mixing thread; give
	# it real time so no stream is still referenced at exit.
	view._audio.stop()
	view._lamp_audio.stop()
	view._press_audio.stop()
	view.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	if failures.is_empty():
		print("PASS: title launch, disabled campaign, rapid input, pause/resume and replay")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


# The title tutorial plate: one press sound and one short push per accepted
# tap, then the lesson. Time is driven by hand (frames would advance it).
func _test_title_press(view) -> void:
	view.set_process(false)
	view.reduced_motion = false
	view._muted = false
	view._navigation_guard_until = 0
	var plate: Rect2 = View.Title.TUTORIAL_RECT
	var presses: int = view._title_presses
	var sounds: int = view._press_sound_starts
	var rewards: int = view._sound_starts
	_expect(view.at_title and view._title_press() == 0.0, "the title plate is at rest before a press")
	# The press alone is 4 dB louder; every other player keeps its level, and
	# the sample's peak stays far from clipping at that gain.
	_expect(view._press_audio.volume_db == -4.0 and view._audio.volume_db == -8.0 and view._lamp_audio.volume_db == -24.0, "only the title press plays 4 dB louder")
	var pcm: PackedByteArray = View.TITLE_PRESS.data
	var peak := 0
	for frame in pcm.size() / 2:
		peak = maxi(peak, absi(pcm.decode_s16(frame * 2)))
	_expect(peak == 17639 and peak / 32768.0 * db_to_linear(view._press_audio.volume_db) < 0.5, "the press peaks near -9.4 dBFS after its gain, with no clipping")
	var clicked := Time.get_ticks_msec()
	view._handle_design_tap(plate.get_center())
	_expect(view.at_title and view._title_presses == presses + 1 and view._press_sound_starts == sounds + 1 and view._press_audio.playing, "an accepted press plays the chosen sound once and stays on the title while the plate moves")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = plate.get_center()
	view._gui_input(touch)
	view._handle_design_tap(plate.position)
	_expect(view.at_title and view._title_presses == presses + 1 and view._press_sound_starts == sounds + 1, "rapid mouse and touch presses during the push are ignored")
	view._process(View.PRESS_TIME * 0.5)
	_expect(view.at_title and is_equal_approx(view._title_press(), 1.0), "the plate is fully in halfway through the press")
	view.size = Vector2(1440, 900)
	# Real time passes during the push; the guard must count from the entry.
	OS.delay_msec(100)
	view._process(View.PRESS_TIME * 0.5)
	_expect(not view.at_title and view._title_press() == 0.0 and view._press_age < 0.0, "the lesson opens once the plate is back up, across a resize")
	_expect(view._navigation_guard_until >= clicked + 100 + 280, "the navigation guard starts at the actual entry, not at the click")
	var trace_size: int = view.model.trace.size()
	view._handle_design_tap(Vector2(194, 396))
	_expect(view.model.trace.size() == trace_size, "a tap right after the actual entry is still guarded")
	view.size = Vector2(390, 844)
	# Other buttons never play the press: home, lesson taps, mute, Replay.
	view._navigation_guard_until = 0
	view._handle_design_tap(Vector2(34, 34))
	view._navigation_guard_until = 0
	view._handle_design_tap(View.Title.MUTE_RECT.get_center())
	view._handle_design_tap(View.Title.MUTE_RECT.get_center())
	_expect(view._press_sound_starts == sounds + 1 and view._title_presses == presses + 1, "home and the audio plate never play the press")
	# Resume: every accepted press sounds, and entry does not cut it.
	view._handle_design_tap(plate.get_center())
	view._process(View.PRESS_TIME + 0.001)
	_expect(not view.at_title and view._press_sound_starts == sounds + 2 and view._press_audio.playing, "a resumed entry plays the press once and entering does not cut it")
	view._navigation_guard_until = 0
	view._handle_design_tap(Vector2(102, 304))
	view._handle_design_tap(Vector2(34, 34))
	_expect(view._press_sound_starts == sounds + 2, "lesson taps never play the press")
	# Muted: the press still opens the lesson, silently; muting mid-press stops it.
	view._navigation_guard_until = 0
	view._toggle_mute()
	view._handle_design_tap(plate.get_center())
	view._process(View.PRESS_TIME + 0.001)
	_expect(not view.at_title and view._title_presses == presses + 3 and view._press_sound_starts == sounds + 2, "a muted press opens the lesson without sound")
	view._toggle_mute()
	view._navigation_guard_until = 0
	view._handle_design_tap(Vector2(34, 34))
	view._navigation_guard_until = 0
	view._handle_design_tap(plate.get_center())
	_expect(view._press_audio.playing, "an unmuted press sounds")
	view._handle_design_tap(View.Title.MUTE_RECT.get_center())
	_expect(view._muted and not view._press_audio.playing and view.at_title, "muting during the push stops the press sound")
	view._process(View.PRESS_TIME + 0.001)
	view._toggle_mute()
	_expect(not view.at_title, "the muted push still opens the lesson")
	# Replay from the title after completion also presses once; the lesson's
	# own Replay button does not.
	view.model.stage_index = 6
	view.model._reset_stage()
	view.model.skip_graduation()
	view._publish_semantics()
	view._navigation_guard_until = 0
	sounds = view._press_sound_starts
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	_expect(view.model.stage_index == 0 and not view.model.finished and view._press_sound_starts == sounds, "the lesson's Replay button keeps its own behaviour, without the press")
	view.model.stage_index = 6
	view.model._reset_stage()
	view.model.skip_graduation()
	view._navigation_guard_until = 0
	view._handle_design_tap(View.SECONDARY_RECT.get_center())
	_expect(view.at_title and view.model.finished, "completion returns to the title")
	view._navigation_guard_until = 0
	view._handle_design_tap(plate.get_center())
	view._process(View.PRESS_TIME + 0.001)
	_expect(not view.at_title and view.model.stage_index == 0 and not view.model.finished and view._press_sound_starts == sounds + 1, "replay from the title presses once and restarts the lessons")
	# Reduced motion: no push, the lesson opens at once, and the press sounds.
	view._navigation_guard_until = 0
	view._handle_design_tap(Vector2(34, 34))
	view.reduced_motion = true
	view._navigation_guard_until = 0
	view._handle_design_tap(plate.get_center())
	_expect(not view.at_title and view._press_age < 0.0 and view._press_sound_starts == sounds + 2 and view._press_audio.playing, "reduced motion opens the lesson immediately and still plays the press")
	_expect(view._sound_starts == rewards, "the press is not a reward sound")


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
