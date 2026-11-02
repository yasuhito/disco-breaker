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
	# Stopped playback leaves the audio server on its own mixing thread; give
	# it real time so no stream is still referenced at exit.
	view._audio.stop()
	view._lamp_audio.stop()
	view.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	if failures.is_empty():
		print("PASS: title launch, disabled campaign, rapid input, pause/resume and replay")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
