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
	view._handle_design_tap(Vector2(195, 675))
	view._handle_design_tap(Vector2(195, 309))
	_expect(view.semantic_state() == initial, "disabled repair and decorative floor cannot change tutorial")
	_expect(not view.inject_action({"type": "confirm"}), "hidden tutorial cannot accept injected input")
	view._handle_design_tap(Vector2(195, 775))
	view._handle_design_tap(Vector2(195, 793))
	_expect(not view.at_title and view.model.dialogue_visible, "double entry cannot dismiss lesson dialogue")
	view._navigation_guard_until = 0
	await process_frame
	await process_frame
	view._handle_design_tap(Vector2(195, 793))
	view._handle_design_tap(Vector2(100, 214))
	view._publish_semantics()
	var playing: Dictionary = view.model.semantic_state()
	view._handle_design_tap(Vector2(38, 36))
	_expect(view.at_title and not view._audio.playing and not view._lamp_audio.playing, "home stops tutorial sound")
	view._navigation_guard_until = 0
	view._handle_design_tap(Vector2(195, 775))
	_expect(view.model.semantic_state() == playing, "continue preserves corrections, dialogue, inspection and trace")
	# A revealed leak can be left/resumed without replaying the discharge.
	view.model.stage_index = 4
	view.model._reset_stage()
	view.model._record("next_stage", {})
	view._publish_semantics()
	view.model.confirm_dialogue()
	view._publish_semantics()
	var leak_count: int = view._leak_sound_starts
	view._show_title()
	view._publish_semantics()
	view._open_tutorial()
	view._publish_semantics()
	_expect(view._leak_sound_starts == leak_count and view._leaks.active, "resuming leak keeps explanation without replaying sound")
	_expect(view._leak_age >= 2.0, "resumed leak is a settled static explanation")
	view.model.stage_index = 6
	view.model._reset_stage()
	view.model.skip_graduation()
	view._publish_semantics()
	view._show_title()
	view._open_tutorial()
	view._publish_semantics()
	_expect(not view.model.finished and view.model.stage_index == 0 and view.model.dialogue_visible, "completed/skip return then replay restarts with dialogue")
	_expect(view._rewards.kind.is_empty() and not view._leaks.active, "replay clears reward, leak and original error reveal")
	view.model.stage_index = 6
	view.model._reset_stage()
	view.model.skip_graduation()
	view._publish_semantics()
	view._navigation_guard_until = 0
	await process_frame
	await process_frame
	view._handle_design_tap(Vector2(195, 793))
	view._handle_design_tap(Vector2(195, 793))
	_expect(view.model.stage_index == 0 and view.model.dialogue_visible, "double Replay cannot dismiss the first lesson")
	view.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: title launch, disabled campaign, rapid input, pause/resume and replay")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
