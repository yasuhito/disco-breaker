extends SceneTree

# Lesson screen regression: the proposal's angular geometry, plates that are
# exactly their hit areas, one tap per wire step at any viewport scale, the
# latest utterance only, the inspection presentation (both colours, reduced
# motion), and cancellation of stale results by rapid input.
const View := preload("res://src/tutorial_view.gd")
const Lesson := preload("res://src/lesson_artwork.gd")
const Tutorial := preload("res://src/tutorial_state.gd")
const FONT := preload("res://assets/fonts/NotoSansJP-Regular.otf")
const BOLD_FONT := preload("res://assets/fonts/NotoSansJP-Bold.tres")

var failures: Array[String] = []


class Probe:
	extends RefCounted
	var polygons: Array[PackedVector2Array] = []
	var strokes: Array[PackedVector2Array] = []
	var texts: Array[Dictionary] = []
	var log: Array = []

	func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
		polygons.append(points)
		log.append(["polygon", points, color])

	func draw_polyline(points: PackedVector2Array, color: Color, width: float, _aa := false) -> void:
		strokes.append(points)
		log.append(["polyline", points, color, width])

	func _draw_text(text: String, position: Vector2, size: int, color: Color, bold := false) -> void:
		texts.append({"text": text, "position": position, "size": size, "color": color})
		log.append(["text", text, position, color])

	func _text_width(text: String, size: int, bold := false) -> float:
		return (BOLD_FONT if bold else FONT).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _init() -> void:
	_run.call_deferred()


# ---- shared geometry: legend, socket wires and the foreman ----------------

func _shapes(probe: Probe, color: Color) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for entry in probe.log:
		if entry[0] == "polygon" and entry[2] == color:
			result.append(entry[1])
	return result


func _union(shapes: Array) -> Rect2:
	var box := _bounds(shapes[0])
	for shape in shapes:
		box = box.merge(_bounds(shape))
	return box


func _mean(points: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / points.size()


func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.001


# The live region names the bottom button as drawn: its label (the lesson's
# call label in call mode) and whether it can be pressed (a disabled button
# is drawn in MIST).
func _test_button_announcement(view) -> void:
	view.reduced_motion = false
	view._muted = true
	var reset := func(stage: int, phase := 0) -> void:
		view.model.stage_index = stage
		view.model.boundary_phase = phase
		view.model.finished = false
		view.model._reset_stage()
		view.model.play_demo()
		view.model._record("next_stage", {})
		view._navigation_guard_until = 0
		view._publish_semantics()
	var tap := func(node: int) -> void:
		view._handle_design_tap(Lesson.socket_center(node) * 2.0)
		view._publish_semantics()
	var call := func() -> void:
		view._handle_design_tap(View.PRIMARY_RECT.get_center())
		view._publish_semantics()
	var seen := {}
	var check := func(name: String, expected: String) -> void:
		var state: Dictionary = view.semantic_state()
		var said: String = view._button_announcement(state)
		_expect(said == expected, "%s: announces 「%s」, not 「%s」" % [name, expected, said])
		var label := said.trim_suffix(" を押せる").trim_suffix(" はまだ押せない")
		var probe := _render(view.model, _anim(view._elapsed, false, {"state": view.model.semantic_state(), "counting": view._count_age if view._counting() else -1.0}))
		var drawn: Array = probe.texts.filter(func(entry): return entry.text == label)
		_expect(drawn.size() == 1 and (drawn[0].color == Lesson.MIST) == said.ends_with(" はまだ押せない"), "%s: the drawn button is 「%s」 and %s" % [name, label, "disabled" if said.ends_with(" はまだ押せない") else "enabled"])
		seen[said] = true
	reset.call(3)
	check.call("lesson 4 start", "チェックして！ を押せる")
	tap.call(4)
	check.call("lesson 4 lit", "チェックして！ はまだ押せない")
	for step in 3:
		tap.call(4)
	check.call("lesson 4 dark", "チェックして！ を押せる")
	call.call()
	check.call("lesson 4 counting", "チェックして！ はまだ押せない")
	view._process(View.COUNT_TIME)
	view._publish_semantics()
	check.call("lesson 4 passed", "つづける を押せる")
	reset.call(4)
	check.call("lesson 5 start", "チェックして！ を押せる")
	call.call()
	check.call("lesson 5 leak", "チェックして！ はまだ押せない")
	tap.call(0)
	check.call("lesson 5 lit", "チェックして！ はまだ押せない")
	reset.call(6)
	check.call("lesson 7 start", "チェックして！ はまだ押せない")
	reset.call(0)
	check.call("lesson 1 start", "つづける はまだ押せない")
	tap.call(4)
	check.call("lesson 1 passed", "つづける を押せる")
	reset.call(5, 1)
	check.call("lesson 6 blue start", "つづける はまだ押せない")
	reset.call(6)
	view.model.skip_graduation()
	view._publish_semantics()
	check.call("finished", "もう一度 を押せる")
	_expect(seen.size() == 5, "every announcement form is covered")


# Lesson 4 does not teach counting: its leak shows the route, cracks and
# leftover rings but no inspection lines, count badges or line diamonds;
# lesson 5 keeps all of them. The verdict is the same parity inspection.
func _test_leak_without_counting() -> void:
	var lesson4 := Tutorial.new()
	lesson4.stage_index = 3
	lesson4._reset_stage()
	lesson4.tap_node(0, 1)
	for tap in 3:
		lesson4.tap_node(1, 1)
	lesson4.tap_node(2, 1)
	lesson4.inspect_floor()
	_expect(bool(lesson4.semantic_state().floor_dark) and not bool(lesson4.inspection.safe) and bool(lesson4.inspection.red_crossing), "lesson 4's red 1-4-7 board is dark and leaking")
	# Control: lesson 1's same 1-4-7 leak keeps the full original presentation.
	var lesson1 := Tutorial.new()
	lesson1.stage_index = 0
	lesson1._reset_stage()
	lesson1.tap_node(0, 1)
	lesson1.tap_node(2, 1)
	for case in [[lesson4, false], [lesson1, true]]:
		var model: Tutorial = case[0]
		var probe := _render(model, _anim(0.0, true, {"routes": _routes(model), "leak_age": 10.0}))
		var lines := _strokes(probe, Color(Lesson.RED_HI, 1.0), 1.2 * Lesson.U)
		var badges := _texts(probe).filter(func(text): return text.length() == 1 and text.is_valid_int())
		var diamonds := _shapes(probe, Lesson.GOLD).filter(func(shape): return shape.size() == 4 and _bounds(shape).size.x <= 7.01 * Lesson.U and is_equal_approx(_bounds(shape).size.x, _bounds(shape).size.y))
		var rings := _strokes(probe, Lesson.GOLD, 1.0 * Lesson.U)
		var route := _strokes(probe, Color(Lesson.RED_HI, 1.0), 2.0 * Lesson.U) + _strokes(probe, Lesson.RED_HI, 2.0 * Lesson.U)
		var name := "lesson %d" % (model.stage_index + 1)
		_expect(lines.is_empty() != case[1] and badges.is_empty() != case[1] and diamonds.is_empty() != case[1], "%s: inspection lines, count badges and line diamonds %s" % [name, "shown" if case[1] else "hidden"])
		_expect(not rings.is_empty() and not route.is_empty(), "%s: the leftover rings and the leak route stay" % name)


# A lesson's board; lesson 5 after its demonstration (the trap), then wired.
func _at_lesson(stage: int, wiring := {}, inspect := true, phase := 0) -> Tutorial:
	var model := Tutorial.new()
	model.stage_index = stage
	model.boundary_phase = phase
	model._reset_stage()
	model.play_demo()
	_wire(model, wiring)
	if inspect and model.can_call_foreman():
		model.inspect_floor()
	return model


# A lesson 5-7 board as drawn at a time into its leak presentation.
func _check_board(model: Tutorial, age := 10.0, reduced := false, extra := {}) -> Dictionary:
	var anim := {"routes": _routes(model), "leak_age": age}
	anim.merge(extra, true)
	var probe := _render(model, _anim(0.0, reduced, anim))
	var lamps := {}
	var routes := {}
	for route in _routes(model):
		var center: Vector2 = Lesson.lamp_position(route.points) * Lesson.U
		var lit := _shapes(probe, Lesson.FAMILY[int(route.component)].base).filter(func(shape): return _bounds(shape).get_center().distance_to(center) < 1.0)
		lamps[int(route.component)] = not lit.is_empty()
		routes[int(route.component)] = route
	var rings := {1: [], 2: []}
	for component in [1, 2]:
		var hi: Color = Lesson.FAMILY[component].hi
		for node in 9:
			var center := Lesson.socket_center(node) * Lesson.U
			var found := _strokes(probe, hi, 2.0 * Lesson.U).filter(func(points): return points.size() == 9 and _bounds(points).get_center().distance_to(center) < 1.0 and is_equal_approx(_bounds(points).size.x, 32.0 * Lesson.U))
			if not found.is_empty():
				rings[component].append(node)
	var trails := {}
	for component in [1, 2]:
		trails[component] = _strokes(probe, Lesson.FAMILY[component].hi, 2.0 * Lesson.U).filter(func(points): return points.size() != 9).size()
	var dimmed := _shapes(probe, Color(Lesson.INK, 0.35)).size() > 0
	return {"probe": probe, "texts": _texts(probe), "lamps": lamps, "routes": routes, "rings": rings, "trails": trails, "dimmed": dimmed,
		"check": _shapes(probe, Lesson.MINT).filter(func(shape): return is_equal_approx(_bounds(shape).size.x, 14.0 * Lesson.U)).size() > 0,
		"legend": _legend_shapes(probe).size() > 0}


# Lessons 5-7, a check's result: on a leak, the leaving colour's remaining
# sockets light up in route order and its light runs along the real
# LeakFeedback route to a lamp outside the board; a safe board shows a green
# check and no light, also when its top row holds a pair of marks; no
# original fault, counts or repair hint is shown.
func _test_visual_check() -> void:
	var start := _at_lesson(4, {}, false)
	var before := _check_board(start)
	_expect(before.routes.is_empty() and before.rings[1].is_empty() and not before.check and not before.legend, "lesson 5 before a check: nothing shown, no legend")
	var trap := _at_lesson(4)
	var route: Dictionary = _routes(trap)[0]
	_expect(Lesson.leaving_sockets(trap, route) == [1, 4, 7], "the trap's leaving sockets are its red leftovers 1, 4, 7, in route order")
	var dim := _check_board(trap, 0.1)
	_expect(dim.rings[1].is_empty() and dim.trails[1] == 0 and not dim.lamps[1], "first only the board dims")
	var first := _check_board(trap, Lesson.FLOW_MARK_AT + 0.01)
	_expect(first.rings[1] == [1] and not first.lamps[1], "then the remaining sockets light one by one")
	var all := _check_board(trap, Lesson.leaving_travel_at(3) - 0.01)
	_expect(_sorted(all.rings[1]) == [1, 4, 7] and all.trails[1] == 0, "all three before the light travels")
	var travel := _check_board(trap, Lesson.leaving_travel_at(3) + Lesson.FLOW_TRAVEL * 0.5)
	_expect(travel.trails[1] > 0 and not travel.lamps[1], "the light travels along the route")
	var lit := _check_board(trap)
	_expect(lit.lamps[1] and lit.trails[1] > 0 and not lit.legend and not lit.texts.has("破線は元の故障、実線は自分の配線"), "then the lamp outside the board lights; no original fault is shown")
	var lamp: Vector2 = Lesson.lamp_position(route.points)
	var c0 := Lesson.socket_center(0)
	var c8 := Lesson.socket_center(8)
	_expect(lamp.y > c8.y + 30 and lamp.x - 10 > 0 and lamp.x + 10 < 195, "the red lamp is outside the board, on the screen")
	# The lit lamp's full extent, rays and stroke included, as drawn.
	var lamp_px: Vector2 = lamp * Lesson.U
	var lowest := -INF
	for entry in lit.probe.log:
		if entry[0] in ["polygon", "polyline"]:
			var width: float = entry[3] * 0.5 if entry[0] == "polyline" else 0.0
			for point in entry[1]:
				if point.distance_to(lamp_px) <= 16.0 * Lesson.U:
					lowest = maxf(lowest, point.y + width)
	_expect(lowest > (lamp.y + 7.0) * Lesson.U and lowest < Lesson.CHECK_WINDOW_Y * Lesson.U, "the red lamp, rays and strokes included, stays above the detailed check's windows")
	_expect(Lesson.CHECK_WINDOW_Y + 26.0 + 1.0 <= Lesson.SECONDARY.position.y, "the windows stay clear of the skip button")
	_expect(not lit.texts.any(func(text): return text.contains("こ") or text.contains("漏電")), "no counts and no 「漏電」 on the board")
	var still := _check_board(trap, 0.0, true)
	_expect(still.lamps[1] and _sorted(still.rings[1]) == [1, 4, 7] and still.trails[1] > 0, "reduced motion draws the final frame at once")
	# Lesson 5 leaking through blue only: blue lights and leaves, red does not.
	var blue := _at_lesson(4, {1: Tutorial.EMPTY, 7: Tutorial.EMPTY, 3: Tutorial.BLUE, 4: Tutorial.BOTH, 5: Tutorial.BLUE})
	var blue_board := _check_board(blue)
	_expect(blue_board.routes.keys() == [2] and blue_board.lamps[2] and _sorted(blue_board.rings[2]) == [3, 4, 5] and blue_board.rings[1].is_empty(), "a blue leak lights blue and its lamp only")
	var blue_lamp: Vector2 = Lesson.lamp_position(blue_board.routes[2].points)
	_expect(blue_lamp.x > c8.x + 30 and blue_lamp.x + 11 <= 195, "the blue lamp is right of the board, on the screen")
	# The safe alternative with two marks on the top row: no light, a green check.
	var loop := _at_lesson(4, {1: Tutorial.RED, 2: Tutorial.RED, 5: Tutorial.RED, 7: Tutorial.EMPTY})
	var loop_board := _check_board(loop)
	_expect(loop.passed() and loop.cut_marks(1).size() == 2 and loop_board.routes.is_empty() and loop_board.trails[1] == 0 and loop_board.check, "a safe board with a pair on the top row shows the green check, no leaving light")
	_expect(not loop_board.dimmed and _check_board(trap).dimmed, "a safe board is not dimmed; a leak is")
	var canonical := _at_lesson(4, {1: Tutorial.EMPTY, 7: Tutorial.EMPTY, 4: Tutorial.RED})
	_expect(canonical.passed() and _check_board(canonical).check, "the canonical repair shows the green check")
	# Lesson 7: both colours leave, each to its lamp.
	var both := _at_lesson(6, {1: Tutorial.BOTH, 7: Tutorial.RED, 0: Tutorial.BLUE})
	var both_board := _check_board(both)
	_expect(both_board.routes.size() == 2 and both_board.lamps[1] and both_board.lamps[2], "lesson 7: red and blue both leave, both lamps light")
	# Lesson 6 (automatic): the same on its own result.
	var edge := _at_lesson(5, {3: Tutorial.RED, 6: Tutorial.RED}, false, 0)
	_expect(not bool(edge.inspection.safe) and _check_board(edge).lamps[1], "lesson 6's automatic result shows the same leaving light")
	# A lit board shows nothing.
	var lit_board := _at_lesson(6, {4: Tutorial.RED}, false)
	var nothing := _check_board(lit_board)
	_expect(not lit_board.is_dark() and nothing.routes.is_empty() and not nothing.check, "a lit board shows no result")
	# The light leaves only for a colour the inspection finds crossing, on a
	# dark board. Dark boards are built directly: a colour's leftovers are a
	# random sum of the other colour's floors (they never light its own) plus,
	# at random, its leaving string (red: column 1-4-7, blue: row 3-4-5).
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261104
	var leaking := 0
	var safe_with_leftovers := 0
	for sample in 600:
		var model := Tutorial.new()
		model.stage_index = [4, 5, 6][sample % 3]
		model.boundary_phase = (sample / 3) % 2 if model.stage_index == 5 else 0
		model._reset_stage()
		var d := model.definition()
		var leftover := {1: {}, 2: {}}
		for component in [1, 2]:
			var generators: Array = d.blue_faces if component == 1 else d.red_faces
			for face in generators:
				if rng.randi() % 2:
					for node in face.nodes:
						leftover[component][node] = not leftover[component].get(node, false)
			if rng.randi() % 2:
				for node in ([1, 4, 7] if component == 1 else [3, 4, 5]):
					leftover[component][node] = not leftover[component].get(node, false)
		for node in 9:
			var value := int(d.hidden.get(node, 0))
			for component in [1, 2]:
				if leftover[component].get(node, false):
					value ^= component
			model.corrections[node] = value
		_expect(model.is_dark(), "fixture: a built board is dark")
		model.inspection = model._inspect_residual()
		var families: Array = _routes(model).map(func(route): return int(route.component))
		var expected: Array = []
		if model.inspection.red_crossing:
			expected.append(1)
		if model.inspection.blue_crossing:
			expected.append(2)
		_expect(families == expected, "the light leaves exactly for the crossing colours")
		leaking += 1 if not expected.is_empty() else 0
		if model.inspection.safe and (not model._residual_support(1).is_empty() or not model._residual_support(2).is_empty()):
			safe_with_leftovers += 1
			model.touched = true
			_expect(String(model.utterance().text) == String(model.definition().lines.ok), "a safe board with leftovers passes with its plain words")
			_expect(_check_board(model).check and _check_board(model).routes.is_empty(), "and shows the green check without any leaving light")
	_expect(leaking > 100 and safe_with_leftovers > 100, "the sample covers leaks and safe boards with leftovers")


# The detailed check's plan, from real counts: particles fly in one after
# another, pairs vanish, one left over warns, none is green.
func _test_check_detail_plan() -> void:
	_expect(Lesson.LAMP_RAY_FROM > 5.0, "lamp rays start outside the chamfered body (its diagonal reaches 5 units)")
	for case in [[{}, "全部、組で消えたね！"], [{1: Tutorial.EMPTY, 7: Tutorial.EMPTY, 3: Tutorial.BLUE, 4: Tutorial.BOTH, 5: Tutorial.BLUE}, "青が1こ残ったよ。"], [{1: Tutorial.BOTH, 7: Tutorial.RED, 0: Tutorial.BLUE}, "赤と青が1こずつ残ったよ。"]]:
		var model := _at_lesson(6 if case[0].has(0) else 4, case[0], false)
		if case[0].is_empty():
			_wire(model, {1: Tutorial.RED, 2: Tutorial.RED, 5: Tutorial.RED, 7: Tutorial.EMPTY})
		_expect(model.detail_result() == case[1], "detail result from the real counts: %s" % case[1])
	for case in [[0, false, true], [1, true, false], [2, false, true], [3, true, false]]:
		var final := Lesson.detail_plan(case[0], Lesson.DETAIL_DONE)
		_expect(final.warning == case[1] and final.green == case[2], "%d marks: %s" % [case[0], "one left warns" if case[1] else "nothing left is green"])
		var gone: Array = final.vanish.filter(func(value): return value >= 1.0)
		_expect(gone.size() == case[0] - case[0] % 2 and final.flights.all(func(value): return value >= 1.0), "%d marks: every particle arrived, %d vanished in pairs" % [case[0], case[0] - case[0] % 2])
	var early := Lesson.detail_plan(2, Lesson.DETAIL_FLY_AT + 0.1)
	_expect(early.flights[0] > 0.0 and early.flights[1] == 0.0 and not early.green, "particles fly in one after another")
	_expect(Lesson.DETAIL_DONE <= View.DETAIL_TIME and Lesson.detail_settle(3) <= Lesson.DETAIL_DONE, "the view's detail time covers the plan, up to three marks on a line")


# Advance the view in 0.1 s frames.
func _frames(view, seconds: float) -> void:
	for frame in int(seconds / 0.1) + 1:
		view._process(0.1)


func _sorted(values: Array) -> Array:
	var copy := values.duplicate()
	copy.sort()
	return copy


# The detailed check in the view: offered by the bottom button
# (「くわしく見る」) only on a leak's result once the foreman has checked, where
# Continue cannot be pressed anyway; opened and replayed by that button, never
# by the bubble; spoken in its own words, ended by any later action, settled
# by home, final at once in reduced motion. A safe result keeps 「つづける」:
# the detail never gates progress.
func _test_check_detail(view) -> void:
	var reset := func() -> void:
		view.model.stage_index = 4
		view.model.boundary_phase = 0
		view.model.finished = false
		view.model._reset_stage()
		view.model.play_demo()
		view.model._record("next_stage", {})
		view._navigation_guard_until = 0
		view._publish_semantics()
	var press := func() -> void:
		view._handle_design_tap(View.PRIMARY_RECT.get_center())
		view._publish_semantics()
	var bubble := Lesson.px(Lesson.BUBBLE).get_center()
	var spoken := func() -> String:
		return view._spoken(view.semantic_state())
	var drawn := func() -> Array:
		var probe := _render(view.model, _anim(0.0, false, {"state": view.semantic_state(), "detail_button": view._detail_offered(), "detail": view._detail_age if view._detailing() else -1.0}))
		return probe.texts.filter(func(entry): return entry.text in ["くわしく見る", "チェックして！", "つづける", "？"]).map(func(entry): return [entry.text, entry.color != Lesson.MIST])
	view.reduced_motion = false
	view._muted = true
	reset.call()
	_expect(not view._detail_available() and not view._detail_offered(), "nothing to detail before a check")
	var untouched: int = view.model.trace.size()
	view._handle_design_tap(bubble)
	_expect(not view.semantic_state().check_detail and view.model.trace.size() == untouched, "a bubble tap before a check does nothing")
	press.call()
	_expect(view.semantic_state().counting and not view._detail_offered(), "not while the foreman checks")
	view._process(View.COUNT_TIME + 0.05)
	view._publish_semantics()
	_expect(spoken.call() == "暗いのに、赤い電気が\n外へ抜けているよ！\n暗いだけでは足りないね。" and view._detail_offered() and view.semantic_state().detail_offered, "the leak is spoken, and the bottom button offers the detail")
	_expect(drawn.call() == [["くわしく見る", true]], "the bottom button reads an enabled 「くわしく見る」; no 「？」 on the bubble")
	# The newly offered button hops once, like any newly enabled button;
	# reduced motion never hops.
	var label_y := func(reduced: bool) -> float:
		var probe := _render(view.model, _anim(0.0, reduced, {"state": view.semantic_state(), "detail_button": view._detail_offered(), "since_enable": view._enable_age}))
		var found: Array = probe.texts.filter(func(entry): return entry.text == "くわしく見る")
		return found[0].position.y if found.size() == 1 else INF
	var hopping: float = label_y.call(false)
	var still: float = label_y.call(true)
	_expect(view._enable_age < 0.1 and is_equal_approx(hopping, still - Lesson.U), "when the foreman's check ends, 「くわしく見る」 hops once (one unit up)")
	view._process(0.3)
	view._publish_semantics()
	_expect(view._enable_age >= 0.3 and is_equal_approx(label_y.call(false), still), "it hops only once; later publishes do not restart it")
	_expect(view._announcement(view.semantic_state()).ends_with("外へ抜けているよ！暗いだけでは足りないね。」。くわしく見る を押せる") and not view._announcement(view.semantic_state()).contains("吹き出し"), "the announcement names the button, not the bubble")
	_expect(view._leak_routes.size() == 1 and int(view._leak_routes[0].component) == 1 and view._leak_routes[0].qubits == [1, 4, 7], "the view's leaving route is the red chain 1-4-7")
	var trace_size: int = view.model.trace.size()
	view._handle_design_tap(bubble)
	_expect(not view.semantic_state().check_detail, "a bubble tap does not open it")
	press.call()
	_expect(view.semantic_state().check_detail and spoken.call() == Tutorial.CHECK_DETAIL and view._detail_age == 0.0, "the button opens the detailed check with its words")
	_expect(view.model.trace.size() == trace_size and view.model.utterance().kind == "unsafe" and not view.model.can_continue(), "it changes no game state")
	view._process(1.0)
	press.call()
	_expect(view._detail_age == 0.0 and drawn.call() == [["くわしく見る", true]], "another press replays it")
	# The words: the rule, then the actual result once the windows show it;
	# the announcement keeps the check's verdict first.
	_expect(view.semantic_state().check_detail_result.is_empty() and spoken.call() == Tutorial.CHECK_DETAIL, "before the windows settle only the rule")
	_expect(view._announcement(view.semantic_state()).contains("暗いのに、赤い電気が外へ抜けているよ！暗いだけでは足りないね。くわしく：2こで消える。"), "the announcement keeps the leak first")
	_frames(view, View.DETAIL_TIME)
	view._publish_semantics()
	_expect(view.semantic_state().check_detail_result == "赤が1こ残ったよ。" and spoken.call() == Tutorial.CHECK_DETAIL + "\n赤が1こ残ったよ。", "then the actual result: one red left")
	_expect(view._announcement(view.semantic_state()).contains("外へ抜けているよ！暗いだけでは足りないね。くわしく：2こで消える。1こ残ったら、まだ直そう！赤が1こ残ったよ。"), "and the announcement says it too")
	view._show_title()
	view._open_tutorial()
	view._navigation_guard_until = 0
	_expect(view.semantic_state().check_detail and view._detail_age >= View.DETAIL_TIME, "home settles it")
	view._handle_design_tap(Lesson.socket_center(0) * 2.0)
	view._publish_semantics()
	_expect(not view.semantic_state().check_detail and not view._detail_offered() and view.model.utterance().kind == "mistake", "an edit ends it and the offer")
	_expect(drawn.call() == [["チェックして！", false]], "then the button is the (disabled) check again")
	for tap in 3:
		view._handle_design_tap(Lesson.socket_center(0) * 2.0)
	view._publish_semantics()
	press.call()
	view._process(View.COUNT_TIME + 0.05)
	view._publish_semantics()
	_expect(not view.semantic_state().check_detail and view._detail_offered(), "a new check offers it again but does not open it")
	# Reduced motion: no check delay, the detail opens at its final frame.
	view.reduced_motion = true
	reset.call()
	press.call()
	press.call()
	_expect(view.semantic_state().check_detail and view._detail_age >= View.DETAIL_TIME, "reduced motion shows the detail's final frame")
	view.reduced_motion = false
	# A safe check keeps 「つづける」: the detail is not offered and never gates.
	reset.call()
	_wire(view.model, {1: Tutorial.RED, 2: Tutorial.RED, 5: Tutorial.RED, 7: Tutorial.EMPTY})
	view._publish_semantics()
	press.call()
	view._process(View.COUNT_TIME + 0.05)
	view._publish_semantics()
	_expect(view.model.passed() and spoken.call() == "よし、もう外へ抜けないね。\nこれで安心！" and not view._detail_offered() and drawn.call() == [["つづける", true]], "a safe check speaks its plain words and the button continues")
	_expect(view._announcement(view.semantic_state()).ends_with("これで安心！」。つづける を押せる"), "and says so")
	_expect(view._leak_routes.is_empty() and not view._leaks.active, "the view builds no leaving route for a safe board")
	view._handle_design_tap(bubble)
	_expect(not view.semantic_state().check_detail and view.semantic_state().continue_enabled, "a bubble tap does nothing on a pass")
	# Two red columns (0-3-6 and 1-4-7): a chain runs from edge to edge, but it
	# crosses the top row twice, so the board is safe and nothing leaves.
	reset.call()
	_wire(view.model, {0: Tutorial.RED, 3: Tutorial.RED, 6: Tutorial.RED})
	view._publish_semantics()
	press.call()
	view._process(View.COUNT_TIME + 0.05)
	view._publish_semantics()
	var chain := preload("res://src/leak_feedback.gd").route(view.model.definition().red_faces, view.model._residual_support(1), 3, true)
	_expect(not chain.is_empty() and view.model.cut_marks(1).size() == 2, "fixture: an edge-to-edge red chain, two marks on the top row")
	_expect(view.model.passed() and view._leak_routes.is_empty() and view.semantic_state().continue_enabled, "a chain that crosses the top row twice is safe: no leaving light, Continue")
	# Lesson 7: red leaves (column 1-4-7) while blue's two rows form an
	# edge-to-edge chain that crosses the left column twice: only red leaves.
	view.model.stage_index = 6
	view.model._reset_stage()
	view.model._record("next_stage", {})
	view._navigation_guard_until = 0
	view._publish_semantics()
	_wire(view.model, {0: Tutorial.BLUE, 1: Tutorial.BOTH, 3: Tutorial.BLUE, 4: Tutorial.BLUE, 5: Tutorial.BLUE, 7: Tutorial.RED})
	view._publish_semantics()
	press.call()
	view._publish_semantics()
	var blue_chain := preload("res://src/leak_feedback.gd").route(view.model.definition().blue_faces, view.model._residual_support(2), 3, false)
	_expect(view.model.is_dark() and view.model.inspection.red_crossing and not view.model.inspection.blue_crossing and not blue_chain.is_empty(), "fixture: red leaks, blue has an edge-to-edge chain but is safe")
	_expect(view._leak_routes.size() == 1 and int(view._leak_routes[0].component) == 1 and view.model.utterance().text == "あっ、まだ赤い電気が\n外へ抜けているよ！", "only red leaves and is named; blue's even chain does not")


# Lesson 5's experiment in the view: the bottom button alone moves it on,
# labelled for each placement and enabled although the floor is lit; the
# foreman's hand lands on the exact socket while the wire and the floors
# change through the model; the bubble only explains; a board tap ends it;
# home keeps it; rapid presses each place exactly one wire; the button and
# the announcements follow the actual board.
func _test_demonstration(view) -> void:
	var reset := func() -> void:
		view.model.stage_index = 4
		view.model.boundary_phase = 0
		view.model.finished = false
		view.model._reset_stage()
		view.model._record("next_stage", {})
		view._navigation_guard_until = 0
		view._publish_semantics()
	var bubble := Lesson.px(Lesson.BUBBLE).get_center()
	var button := View.PRIMARY_RECT.get_center()
	var frame := func() -> Dictionary:
		return {"state": view.model.semantic_state(), "demo_node": view.model.demo_node(), "demo_age": view._demo_age}
	var drawn_button := func() -> Array:
		var probe := _render(view.model, _anim(0.0, false, frame.call()))
		return probe.texts.filter(func(entry): return entry.text in ["上に赤を置く", "下に赤を置く", "チェックして！"])
	view.reduced_motion = false
	view._muted = true
	reset.call()
	var label: Array = drawn_button.call()
	_expect(label.size() == 1 and label[0].text == "上に赤を置く" and label[0].color != Lesson.MIST, "the start: an enabled 「上に赤を置く」 although the floor is lit")
	_expect(view._announcement(view.semantic_state()).ends_with("親方「上と下に赤を置くと、どうなるかな？」。上に赤を置く を押せる"), "the announcement names the button honestly")
	_expect(view.semantic_state().lit_red == [0, 1] and not view._detail_available(), "the board starts lit; no detail is offered")
	view._handle_design_tap(bubble)
	_expect(Array(view.model.corrections) == [0, 0, 0, 0, 0, 0, 0, 0, 0] and view.model.demo_step == 0, "a bubble tap does not move the experiment on")
	view._handle_design_tap(button)
	_expect(Array(view.model.corrections) == [0, 1, 0, 0, 0, 0, 0, 0, 0] and view._spoken(view.semantic_state()) == "上に赤を置いたよ。\n赤い配線は、となりの\n赤い床につながるよ。", "the button places the top red")
	_expect(view._showing_change() and view._darkened.size() == 1 and int(view._darkened[0].check) == 0 and view._change_node == 1, "the floor it darkens (red floor 0) is shown like a tap on socket 1")
	var placed := _render(view.model, _anim(0.0, false, frame.call()))
	var hand := _shapes(placed, Lesson.SKIN).filter(func(shape): return _bounds(shape).get_center().distance_to(Lesson.socket_center(1) * Lesson.U) < 30.0 * Lesson.U)
	_expect(not hand.is_empty() and hand.all(func(shape): return _bounds(shape).end.y <= (Lesson.socket_center(1).y + 1.0) * Lesson.U and absf(_bounds(shape).get_center().x - (Lesson.socket_center(1).x + 5.0) * Lesson.U) < 6.0 * Lesson.U), "the foreman's hand comes down onto socket 1")
	label = drawn_button.call()
	_expect(label.size() == 1 and label[0].text == "下に赤を置く" and label[0].color != Lesson.MIST, "then the button reads 「下に赤を置く」")
	view._process(Lesson.DEMO_POINT_TIME + 0.1)
	_expect(_shapes(_render(view.model, _anim(0.0, false, frame.call())), Lesson.SKIN).filter(func(shape): return _bounds(shape).get_center().distance_to(Lesson.socket_center(1) * Lesson.U) < 30.0 * Lesson.U).is_empty(), "then the hand leaves")
	# Rapid presses: one placement, then the button checks (an inspection, not a placement).
	view._handle_design_tap(button)
	_expect(view.model.demo_step == 2 and Array(view.model.corrections) == [0, 1, 0, 0, 0, 0, 0, 1, 0] and view.model.is_dark() and view._spoken(view.semantic_state()) == "ちらつきは消えたね。\nでも、安全かな？", "the second press places the bottom red: dark, and the question")
	label = drawn_button.call()
	_expect(label.size() == 1 and label[0].text == "チェックして！" and view._announcement(view.semantic_state()).ends_with("チェックして！ を押せる"), "no empty step: the button now checks")
	# Home keeps the board and the step.
	view._show_title()
	view._open_tutorial()
	view._navigation_guard_until = 0
	_expect(view.model.demo_step == 2 and Array(view.model.corrections) == [0, 1, 0, 0, 0, 0, 0, 1, 0], "home and resume keep the experiment's board")
	view._handle_design_tap(button)
	view._publish_semantics()
	view._process(View.COUNT_TIME + 0.05)
	view._publish_semantics()
	_expect(view._leak_routes.size() == 1 and view._leak_routes[0].qubits == [1, 4, 7] and not view.model.demo_active(), "the check shows the actual red leaving along 1-4-7")
	# A board tap during the experiment ends it; the button then follows the board.
	reset.call()
	view._handle_design_tap(button)
	view._handle_design_tap(Lesson.socket_center(4) * 2.0)
	view._publish_semantics()
	var after := Array(view.model.corrections)
	view._handle_design_tap(button)
	_expect(not view.model.demo_active() and Array(view.model.corrections) == after and after == [0, 1, 0, 0, 1, 0, 0, 0, 0], "a board tap ends the experiment; the (disabled) button places nothing later")
	_expect(view._spoken(view.semantic_state()) == "光る床がある。\nまず全部暗くしよう。" and view._announcement(view.semantic_state()).ends_with("チェックして！ はまだ押せない"), "the words and the button follow the actual board")
	# Reduced motion: the hand rests on the socket.
	view.reduced_motion = true
	reset.call()
	view._handle_design_tap(button)
	var still: Dictionary = frame.call()
	_expect(str(_render(view.model, _anim(0.0, true, still)).log) == str(_render(view.model, _anim(0.4, true, still)).log), "reduced motion draws the placement still")
	view.reduced_motion = false


# Every call-mode lesson's bottom button reads 「チェックして！」 (disabled on a
# lit board too); no lesson shows 「親方を呼ぶ」 any more.
func _test_call_labels() -> void:
	for case in [[3, "チェックして！"], [4, "上に赤を置く"], [6, "チェックして！"]]:
		var model := Tutorial.new()
		model.stage_index = case[0]
		model._reset_stage()
		var drawn := _texts(_render(model, _anim()))
		_expect(drawn.count(case[1]) == 1 and drawn.count("チェックして！") + drawn.count("上に赤を置く") == 1 and not drawn.has("親方を呼ぶ"), "lesson %d's call button reads %s" % [case[0] + 1, case[1]])
	var lit := Tutorial.new()
	lit.stage_index = 3
	lit._reset_stage()
	lit.tap_node(1, 1)
	_expect(not lit.can_call_foreman() and _texts(_render(lit, _anim())).has("チェックして！"), "lesson 4's disabled button keeps its label")


# The old wire legend's band below the board (units): the four mini sockets
# and their chevrons sat in it.
const LEGEND_BAND := Rect2(50, 286, 95, 20)


func _legend_shapes(probe: Probe) -> Array:
	var result := []
	for color in [Lesson.GROUT, Lesson.NIGHT4, Lesson.MIST, Lesson.GUIDE, Lesson.RED, Lesson.BLUE]:
		for shape in _shapes(probe, color):
			if Lesson.px(LEGEND_BAND).encloses(_bounds(shape)):
				result.append(shape)
	return result


# No lesson draws the four-state legend (its fixed slashes read as a rule):
# nothing in its band, before or after taps, and the announcement never
# mentions one; the bottom button's plate stays where it was.
func _test_no_legend() -> void:
	for stage in Tutorial.new().stages().size():
		var model := Tutorial.new()
		model.stage_index = stage
		model._reset_stage()
		_expect(_legend_shapes(_render(model, _anim())).is_empty(), "lesson %d starts without a legend" % (stage + 1))
		for node in [0, 4, 8]:
			model.tap_node(int(node / 3.0), node % 3)
		_expect(_legend_shapes(_render(model, _anim())).is_empty(), "lesson %d after taps: still no legend" % (stage + 1))
	_expect(Lesson.PRIMARY == Rect2(8, 364, 178, 32) and Lesson.SECONDARY == Rect2(37, 321, 120, 26), "the bottom button and the secondary plate keep their places")


# On the board, a socket's red and blue bands cross at its centre too, and
# each family it lacks is a faint grey guide on the same band (no dots), also
# under a dashed original fault and on a pressed socket.
func _test_socket_wire_crossing() -> void:
	var probe := Probe.new()
	var art := Lesson.new()
	art.view = probe
	var center := Lesson.socket_center(4)
	art._socket(center, 3, false, false, 0)
	for color in [Lesson.RED, Lesson.BLUE, Lesson.RED_HI, Lesson.BLUE_HI]:
		var bands := _shapes(probe, color).filter(func(shape): return _bounds(shape).size.y > 20.0)
		_expect(bands.size() == 1 and _near(_mean(bands[0]), center * Lesson.U), "a socket's wire bands cross at its centre")
	var lines := {}
	for color in [Lesson.RED_HI, Lesson.BLUE_HI]:
		lines[color] = _shapes(probe, color).filter(func(shape): return _bounds(shape).size.y > 20.0)[0]
	for case in [[0, 0, false], [1, 0, false], [2, 0, false], [3, 0, false], [0, 3, false], [2, 1, false], [0, 0, true]]:
		var socket := Probe.new()
		art.view = socket
		art._socket(center, case[0], case[2], false, case[1])
		var cap := (center + Vector2(0, 1.0 if case[2] else 0.0)) * Lesson.U
		var guides := _shapes(socket, Lesson.GUIDE).filter(func(shape): return shape.size() == 4 and _bounds(shape).size.y > 20.0)
		var wanted: Array = [1, 2].filter(func(component): return not case[0] & component)
		_expect(guides.size() == wanted.size(), "socket %s: one grey guide per unwired colour" % [case])
		for i in mini(guides.size(), wanted.size()):
			var line: PackedVector2Array = lines[Lesson.RED_HI if wanted[i] == 1 else Lesson.BLUE_HI]
			_expect(_near(_mean(guides[i]), cap) and _bounds(guides[i]).size.is_equal_approx(_bounds(line).size) and (guides[i][2].x > guides[i][0].x) == (wanted[i] == 1), "socket %s: each guide follows its colour's centre line, end to end" % [case])
		var first_guide := -1
		var first_wire := -1
		for index in socket.log.size():
			var entry: Array = socket.log[index]
			if entry[0] != "polygon" or entry[1].size() != 4 or _bounds(entry[1]).size.y < 20.0:
				continue
			if entry[2] == Lesson.GUIDE and first_guide < 0:
				first_guide = index
			elif entry[2] != Lesson.GUIDE and first_wire < 0:
				first_wire = index
		_expect(first_guide < 0 or first_wire < 0 or first_guide < first_wire, "socket %s: guides lie under wires and dashed faults" % [case])
		var small := _shapes(socket, Lesson.GUIDE).filter(func(shape): return _bounds(shape).size.x < 6.0 and _bounds(shape).size.y < 6.0)
		_expect(small.is_empty(), "socket %s: no dots" % [case])


# What the board actually draws: on all nine sockets the red and the blue
# wire (solid, dashed fault, change glow and removed trace) run on the
# diagonal whose ends point at the floors of their colour around that socket
# (from the floors' socket lists, not from the artwork), never at the other
# colour's floors, and an end reaches into such a floor's glass. The centre
# keeps red "＼" and blue "／".
func _test_wire_orientation() -> void:
	for stage in [0, 4, 5, 6]:
		var model := Tutorial.new()
		model.stage_index = stage
		model._reset_stage()
		var d := model.definition()
		for node in 9:
			model.corrections[node] = Tutorial.BOTH
		var probe := _render(model, _anim())
		for component in [Tutorial.RED, Tutorial.BLUE]:
			var f: Dictionary = Lesson.FAMILY[component]
			var own_faces: Array = d.red_faces if component == Tutorial.RED else d.blue_faces
			for node in 9:
				var center := Lesson.socket_center(node) * Lesson.U
				var lines := _shapes(probe, f.hi).filter(func(shape): return _mean(shape).distance_to(center) < 3.0 * Lesson.U and _bounds(shape).size.y > 20.0)
				_expect(lines.size() == 1, "lesson %d socket %d: one drawn %s wire" % [stage + 1, node, f.base.to_html(false)])
				if lines.size() != 1:
					continue
				var ends := _drawn_ends(lines[0])
				var own := _floor_directions(own_faces, node, int(d.size))
				var other := _floor_directions(d.blue_faces if component == Tutorial.RED else d.red_faces, node, int(d.size))
				_expect(not own.is_empty() and own.all(func(to): return to in ends) and other.all(func(to): return not to in ends), "lesson %d socket %d: the drawn %s wire points at its own floors only" % [stage + 1, node, "red" if component == Tutorial.RED else "blue"])
				var reaches := false
				for to in ends:
					var tip := Lesson.socket_center(node) + Vector2(to) * 14.0
					for face in own_faces:
						if node in face.nodes and Lesson.face_rect(face).has_point(tip):
							reaches = true
				_expect(reaches, "lesson %d socket %d: the %s wire's end reaches into its floor" % [stage + 1, node, "red" if component == Tutorial.RED else "blue"])
				if node == 4:
					_expect(ends.has(Vector2i(1, 1)) == (component == Tutorial.RED), "lesson %d: the centre keeps red ＼ and blue ／" % (stage + 1))
	# Dashed fault, change glow and removed trace follow the same diagonal.
	var art := Lesson.new()
	var trap := Tutorial.new()
	trap.stage_index = 4
	trap._reset_stage()
	for node in [1, 3, 4, 7]:
		var slants := {1: trap.wire_slant(node, 1), 2: trap.wire_slant(node, 2)}
		var center := Lesson.socket_center(node)
		var socket := Probe.new()
		art.view = socket
		art._socket(center, 0, false, false, Tutorial.BOTH, slants)
		art._socket(center, Tutorial.BOTH, false, false, 0, slants)
		for component in [1, 2]:
			var f: Dictionary = Lesson.FAMILY[component]
			var pieces := _shapes(socket, f.base).filter(func(shape): return _bounds(shape).size.y < 6.0 * Lesson.U)
			var solid := _shapes(socket, f.hi).filter(func(shape): return _bounds(shape).size.y > 20.0)
			_expect(pieces.size() >= 4 and solid.size() == 1 and pieces.all(func(piece): return _drawn_ends(solid[0]).has(_sign2(_mean(piece) - center * Lesson.U)) or _mean(piece).distance_to(center * Lesson.U) < 2.0 * Lesson.U), "socket %d: the dashed fault lies on the wire's diagonal" % node)
			for present in [true, false]:
				var glow := Probe.new()
				art.view = glow
				art._wire_glow(center, component, int(slants[component]), present, 1.0)
				var band: Array = glow.polygons.filter(func(shape): return _bounds(shape).size.y > 20.0)
				_expect(not band.is_empty() and band.all(func(shape): return _drawn_ends(shape) == _drawn_ends(solid[0])), "socket %d: the %s glow follows the wire" % [node, "change" if present else "removed"])


# The two end directions (signs, y down) of a drawn diagonal band.
func _drawn_ends(shape: PackedVector2Array) -> Array:
	var top := shape[0]
	var bottom := shape[0]
	for point in shape:
		if point.y < top.y:
			top = point
		if point.y > bottom.y:
			bottom = point
	var middle := (top + bottom) * 0.5
	return [_sign2(top - middle), _sign2(bottom - middle)]


static func _sign2(v: Vector2) -> Vector2i:
	return Vector2i(int(signf(v.x)), int(signf(v.y)))


# The diagonal directions (signs, y down) from a socket to the floors of one
# colour that contain it, from the floors' socket lists: a four-socket floor's
# middle, or a two-socket floor's edge middle moved half a cell off the board.
static func _floor_directions(faces: Array, node: int, size: int) -> Array:
	var at := Vector2(node % size, node / size)
	var result := []
	for face in faces:
		if not node in face.nodes:
			continue
		var middle := Vector2.ZERO
		for corner in face.nodes:
			middle += Vector2(int(corner) % size, int(corner) / size)
		middle /= face.nodes.size()
		if face.nodes.size() == 2:
			if is_equal_approx(middle.x, 0.0):
				middle.x -= 0.5
			elif is_equal_approx(middle.x, size - 1.0):
				middle.x += 0.5
			elif is_equal_approx(middle.y, 0.0):
				middle.y -= 0.5
			else:
				middle.y += 0.5
		result.append(_sign2(middle - at))
	return result


# The foreman's face and shirt are symmetric about the head's centre in every
# pose; the happy eyes are joined "^" shapes; the collar ends on the tie.
func _test_foreman_alignment() -> void:
	var axis := 24.0 * Lesson.U
	var base := {"bob": 0.0, "hop": 0.0, "blink": false, "mouth": "rest", "brows": "neutral", "thumb": false}
	var poses := {"rest": {}, "talk": {"mouth": "talk"}, "happy": {"mouth": "smile", "brows": "up", "thumb": true},
		"worry": {"mouth": "worry", "brows": "worry"}, "blink": {"blink": true}, "happy blink": {"mouth": "smile", "brows": "up", "thumb": true, "blink": true}}
	for name in poses:
		var pose := base.duplicate()
		pose.merge(poses[name], true)
		var probe := Probe.new()
		var art := Lesson.new()
		art.view = probe
		art._foreman(0.0, 0.0, pose)
		var u := Lesson.U
		var eyes := _shapes(probe, Lesson.INK).filter(func(shape): var box := _bounds(shape); return box.size.x <= 5.0 * u and box.position.y >= 20.0 * u and box.end.y <= 26.0 * u)
		var brows := _shapes(probe, Lesson.HAIR).filter(func(shape): return _bounds(shape).end.y <= 23.0 * u)
		var nose := _shapes(probe, Lesson.SKIN_LO).filter(func(shape): var box := _bounds(shape); return box.position.y == 23.0 * u and box.size.y == 4.0 * u)
		for feature in [["eyes", eyes], ["brows", brows]]:
			var left: Array = feature[1].filter(func(shape): return _bounds(shape).get_center().x < axis)
			var right: Array = feature[1].filter(func(shape): return _bounds(shape).get_center().x > axis)
			_expect(not left.is_empty() and left.size() == right.size(), "%s: both %s are drawn" % [name, feature[0]])
			if left.is_empty() or right.is_empty():
				continue
			var l := _union(left)
			var r := _union(right)
			_expect(is_equal_approx(l.position.x + r.end.x, 2.0 * axis) and is_equal_approx(l.end.x + r.position.x, 2.0 * axis) and is_equal_approx(l.position.y, r.position.y) and is_equal_approx(l.end.y, r.end.y), "%s: the %s mirror about the face's centre" % [name, feature[0]])
			if feature[0] == "eyes" and pose.mouth == "smile" and not pose.blink:
				for side in [left, right]:
					_expect(side.size() == 2 and _near(side[0][1], side[1][0]) and is_equal_approx(_bounds(side[0]).position.y, _bounds(side[1]).position.y), "%s: each happy eye is one joined ^" % name)
		_expect(nose.size() == 1 and is_equal_approx(_bounds(nose[0]).get_center().x, axis), "%s: the nose is on the face's centre" % name)
		var shirt := _shapes(probe, Lesson.SHIRT)
		_expect(shirt.size() == 3, "%s: collar arms and tie" % name)
		if shirt.size() == 3:
			var tie := _bounds(shirt[2])
			var arms := _union([shirt[0], shirt[1]])
			_expect(is_equal_approx(arms.position.x + arms.end.x, 2.0 * axis) and is_equal_approx(tie.get_center().x, axis), "%s: the collar is symmetric about the face's centre" % name)
			_expect(is_equal_approx(minf(shirt[0][3].x, shirt[1][3].x), tie.position.x) and is_equal_approx(maxf(shirt[0][2].x, shirt[1][2].x), tie.end.x) and is_equal_approx(shirt[0][2].y, tie.position.y), "%s: the collar's arms end exactly on the tie" % name)


# Weak references to the view's generated sounds, made here so that no stack
# slot of the caller keeps a sound alive.
func _weak_streams(view) -> Array:
	var streams := [weakref(view._sting), weakref(view._final_sting), weakref(view._discharge)]
	for tick in view._lamp_ticks:
		streams.append(weakref(tick))
	return streams


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)


func _anim(time := 0.0, reduced := true, extra := {}) -> Dictionary:
	var anim := {"device_scale": 2.0, "reduced": reduced, "time": time, "muted": false, "progress": 0.0,
		"since_talk": 10.0, "since_success": 10.0, "since_enable": 10.0, "since_press": 10.0,
		"pressed_node": -1, "leak_age": 10.0, "routes": []}
	anim.merge(extra, true)
	return anim


func _routes(model: Tutorial) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	var d := model.definition()
	for component in [1, 2]:
		if not bool(model.inspection.get("red_crossing" if component == 1 else "blue_crossing", false)):
			continue
		var faces: Array = d.red_faces if component == 1 else d.blue_faces
		var route := preload("res://src/leak_feedback.gd").route(faces, model._residual_support(component), 3, component == 1)
		route.component = component
		route.points = Lesson.route_points(route, faces)
		routes.append(route)
	return routes


func _render(model: Tutorial, anim: Dictionary) -> Probe:
	var probe := Probe.new()
	Lesson.new().draw(probe, model, anim)
	return probe


func _texts(probe: Probe) -> Array[String]:
	var result: Array[String] = []
	for entry in probe.texts:
		result.append(String(entry.text))
	return result


func _angular(points: PackedVector2Array, closed: bool) -> bool:
	var count := points.size() if closed else points.size() - 1
	for i in count:
		var step := points[(i + 1) % points.size()] - points[i]
		if step.length() < 0.001:
			continue
		var degrees := fposmod(rad_to_deg(step.angle()), 45.0)
		if minf(degrees, 45.0 - degrees) > 0.01:
			return false
	return true


func _boards() -> Array[Tutorial]:
	var boards: Array[Tutorial] = []
	for stage in 7:
		var model := Tutorial.new()
		model.stage_index = stage
		model._reset_stage()
		boards.append(model)
	var leak := Tutorial.new()
	leak.stage_index = 4
	leak._reset_stage()
	leak.play_demo()
	leak.inspect_floor()
	boards.append(leak)
	var both := Tutorial.new()
	both.stage_index = 6
	both._reset_stage()
	for node in [[0, 2], [1, 3], [7, 1]]:
		for tap in node[1]:
			both.tap_node(int(node[0] / 3.0), node[0] % 3)
	both.inspect_floor()
	boards.append(both)
	var passed := Tutorial.new()
	passed.tap_node(1, 1)
	boards.append(passed)
	var done := Tutorial.new()
	done.stage_index = 6
	done._reset_stage()
	done.skip_graduation()
	boards.append(done)
	return boards


func _test_angular_geometry() -> void:
	for model in _boards():
		for time in [0.0, 0.37, 1.1]:
			for reduced in [true, false]:
				var counting: float = time if model.definition().lines.has("call") and not reduced else -1.0
				var probe := _render(model, _anim(time, reduced, {"routes": _routes(model), "leak_age": time + 0.5, "since_success": time * 0.5, "since_talk": time, "counting": counting}))
				for polygon in probe.polygons:
					_expect(_angular(polygon, true), "lesson polygon edges are 0, 45 or 90 degrees (%s)" % model.definition().id)
				for stroke in probe.strokes:
					_expect(_angular(stroke, false), "lesson strokes are 0, 45 or 90 degrees (%s)" % model.definition().id)


func _bounds(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect


func _has_plate(probe: Probe, rect: Rect2) -> bool:
	for polygon in probe.polygons:
		var bounds := _bounds(polygon)
		if bounds.position.is_equal_approx(rect.position) and bounds.size.is_equal_approx(rect.size):
			return true
	return false


func _test_plates_are_hit_areas() -> void:
	_expect(View.HOME_RECT == Lesson.px(Lesson.HOME), "home hit area is its plate")
	_expect(View.LESSON_MUTE_RECT == Lesson.px(Lesson.MUTE), "audio hit area is its plate")
	_expect(View.PRIMARY_RECT == Lesson.px(Lesson.PRIMARY) and View.PRIMARY_RECT.size == Vector2(356, 64), "bottom button hit area is its 356 x 64 plate")
	_expect(View.SECONDARY_RECT == Lesson.px(Lesson.SECONDARY), "skip hit area is its plate")
	var start := _render(Tutorial.new(), _anim())
	var practice := Tutorial.new()
	practice.stage_index = 6
	practice._reset_stage()
	var final := _render(practice, _anim())
	for rect in [View.HOME_RECT, View.LESSON_MUTE_RECT, View.PRIMARY_RECT]:
		_expect(_has_plate(start, rect), "a drawn plate has exactly the hit area %s" % rect)
	_expect(_has_plate(final, View.SECONDARY_RECT), "the drawn skip plate is its hit area")
	_expect(not _has_plate(start, View.SECONDARY_RECT), "no skip plate outside the optional practice")
	for node in 9:
		var center := Lesson.socket_center(node) * 2.0
		for corner in [Vector2(-45.9, -45.9), Vector2(45.9, -45.9), Vector2(-45.9, 45.9), Vector2(45.9, 45.9), Vector2.ZERO]:
			_expect(Lesson.node_at(center + corner) == node, "the whole 92 px cell taps connection box %d" % node)
	for outside in [Vector2(55, 396), Vector2(334, 396), Vector2(194, 257), Vector2(194, 535)]:
		_expect(Lesson.node_at(outside) == -1, "taps outside the board's cells are ignored")


func _test_latest_utterance_only() -> void:
	var model := Tutorial.new()
	var bubble := Lesson.px(Lesson.BUBBLE)
	for step in 3:
		var probe := _render(model, _anim())
		var spoken: Array[String] = []
		for entry in probe.texts:
			if bubble.has_point(entry.position):
				spoken.append(String(entry.text))
		_expect(spoken == Array(String(model.utterance().text).split("\n")), "the bubble holds exactly the latest utterance (%s)" % model.utterance().kind)
		if step == 0:
			model.tap_node(0, 0)
		else:
			model.tap_node(1, 1)
	var texts := _texts(_render(Tutorial.new(), _anim()))
	_expect(not texts.has("わかった") and not texts.has("点滅を止めて、音楽を楽しもう。"), "no dialogue button or extra caption")


# Lessons 1-3 keep the original leak presentation: lesson 1's top-and-bottom
# board leaks along 1-4-7 like lesson 5's trap. (Lessons 5-7 count instead.)
func _test_inspection_presentation() -> void:
	var leak := Tutorial.new()
	leak.stage_index = 0
	leak._reset_stage()
	leak.tap_node(0, 1)
	leak.tap_node(2, 1)
	_expect(leak.is_dark() and not leak.inspection.is_empty() and not bool(leak.inspection.safe), "fixture: lesson 1 dark and leaking")
	var routes := _routes(leak)
	_expect(routes.size() == 1 and routes[0].qubits == [1, 4, 7], "the leak's route is its red residual chain")
	# Reduced motion: every label of the final explanation at once, unchanged over time.
	var still := _render(leak, _anim(0.0, true, {"routes": routes, "leak_age": 0.0}))
	var later := _render(leak, _anim(5.0, true, {"routes": routes, "leak_age": 0.0}))
	_expect(str(still.log) == str(later.log), "reduced-motion lessons are static")
	var texts := _texts(still)
	_expect(texts.count("2") == 2 and texts.count("1") == 1, "each watching floor shows 2 and the inspection line shows 1")
	_expect(texts.has("破線は元の故障、実線は自分の配線"), "the dashed original fault is explained")
	# With motion the explanation builds up within two seconds, then settles.
	var early := _texts(_render(leak, _anim(0.1, false, {"routes": routes, "leak_age": 0.1})))
	_expect(early.count("2") == 2 and not early.has("1") and not early.has("破線は元の故障、実線は自分の配線"), "leftovers and the floors' 2 come first")
	var middle := _texts(_render(leak, _anim(1.0, false, {"routes": routes, "leak_age": 1.0})))
	_expect(middle.has("1") and not middle.has("破線は元の故障、実線は自分の配線"), "then the route and the inspection line's count")
	var settled := _texts(_render(leak, _anim(2.1, false, {"routes": routes, "leak_age": 2.1})))
	_expect(settled.has("破線は元の故障、実線は自分の配線"), "finally the cracks and the original fault")
	# Both colours leaking show both explanations, not one colour.
	var both := Tutorial.new()
	both.stage_index = 2
	both._reset_stage()
	_wire(both, {1: Tutorial.RED, 3: Tutorial.BLUE, 5: Tutorial.BLUE, 7: Tutorial.RED})
	_expect(both.inspection.red_crossing and both.inspection.blue_crossing, "fixture leaks in both colours")
	var both_routes := _routes(both)
	_expect(both_routes.size() == 2, "both colours get a route")
	var probe := _render(both, _anim(0.0, true, {"routes": both_routes}))
	var counts := 0
	for entry in probe.texts:
		counts += 1 if entry.text == "1" else 0
	_expect(counts == 2, "both inspection lines show their odd count")
	var colors := {}
	for entry in probe.log:
		if entry[0] == "polyline" and entry[3] >= 3.9:
			colors[entry[2].to_html(false)] = true
	_expect(colors.has(Lesson.RED_HI.to_html(false)) and colors.has(Lesson.BLUE_HI.to_html(false)), "red and blue leak routes are both drawn")


func _wire(model: Tutorial, wiring: Dictionary) -> void:
	for node in 9:
		while model.corrections[node] != int(wiring.get(node, model.corrections[node])):
			model.tap_node(int(node / 3.0), node % 3)


func _tap(view, point: Vector2, touch := true) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.pressed = true
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
	event.position = point
	view._gui_input(event)
	var release: InputEvent = event.duplicate()
	release.pressed = false
	view._gui_input(release)


# Lesson 4: the foreman counts the red line, then the blue line, before
# his verdict; Continue is inert meanwhile; edits and home cancel it.
# A tap that turns lit floors dark marks exactly those floors (from the model's
# lit checks before and after) and the wire that changed, briefly, for that
# action only; the model, its verdict and the sounds are unchanged.
func _strokes(probe: Probe, color: Color, width: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for entry in probe.log:
		if entry[0] == "polyline" and entry[2] == color and is_equal_approx(entry[3], width):
			result.append(entry[1])
	return result


# An outline (design px, or units with scaled = false) lies inside its floor
# and clear of every socket's octagon (half size 13, |dx| + |dy| <= 18) by its
# 1.5-unit stroke's half width plus one unit, sampled along every edge.
func _outline_fits(points: PackedVector2Array, face: Dictionary, scaled := true) -> bool:
	var rect := Lesson.face_rect(face)
	for i in points.size() - 1:
		var a := points[i] / Lesson.U if scaled else points[i]
		var b := points[i + 1] / Lesson.U if scaled else points[i + 1]
		var steps := maxi(1, int(a.distance_to(b) / 0.5))
		for step in steps + 1:
			var p := a.lerp(b, float(step) / steps)
			if not rect.has_point(p):
				return false
			for node in 9:
				var d := (p - Lesson.socket_center(node)).abs()
				if d.x <= 14.75 and d.y <= 14.75 and d.x + d.y <= 18.0 + 0.75 * sqrt(2.0) + 1.0:
					return false
	return true


func _test_wiring_change(view) -> void:
	view.reduced_motion = false
	view._muted = true
	var reset := func(stage: int, phase := 0) -> void:
		view.model.stage_index = stage
		view.model.boundary_phase = phase
		view.model._reset_stage()
		view.model.play_demo()
		view.model._record("next_stage", {})
		view._navigation_guard_until = 0
		view._publish_semantics()
	var tap := func(node: int) -> void:
		view._handle_design_tap(Lesson.socket_center(node) * 2.0)
		view._publish_semantics()
	var floors := func() -> Array:
		var result := []
		for floor in view._darkened:
			result.append([int(floor.component), int(floor.check)])
		return result
	var lits := func() -> Array:
		var result := []
		for floor in view._lit:
			result.append([int(floor.component), int(floor.check)])
		return result
	var wires := func() -> Array:
		var result := []
		for wire in view._changed_wires:
			result.append([int(wire.component), bool(wire.present)])
		return result
	# Red: lesson 1's centre darkens both red floors; its red wire glows.
	reset.call(0)
	var schema: Array = view.semantic_state().keys()
	var sounds: int = view._sound_starts
	tap.call(4)
	_expect(floors.call() == [[1, 0], [1, 1]] and lits.call().is_empty() and wires.call() == [[1, true]] and view._showing_change(), "red: exactly the two red floors that went dark, and the red wire")
	_expect(view.model.passed() and view.semantic_state().keys() == schema, "the verdict is immediate and the semantic state unchanged")
	var anim := _anim(0.0, false, {"change": {"node": view._change_node, "darkened": view._darkened, "lit": view._lit, "wires": view._changed_wires, "age": 0.0}})
	var probe := _render(view.model, anim)
	var faces: Array = view.model.definition().red_faces
	var outlines := _strokes(probe, Lesson.GOLD, 1.5 * Lesson.U)
	_expect(outlines.size() == 2, "red: one gold outline per darkened floor")
	for i in mini(outlines.size(), 2):
		_expect(_outline_fits(outlines[i], faces[i]), "red: floor %d's outline lies inside it and clear of its sockets" % i)
	var cores := _shapes(probe, Lesson.WHITE).filter(func(shape): return shape.size() == 4 and _bounds(shape).size.y > 20.0)
	_expect(cores.size() == 1 and _near(_mean(cores[0]), Lesson.socket_center(4) * Lesson.U) and cores[0][2].x > cores[0][0].x, "red: the glowing core runs along the red diagonal of the tapped socket")
	for age in [[0.1, 1.0], [0.3, 0.5]]:
		var faded := _render(view.model, _anim(0.0, false, {"change": {"node": 4, "darkened": view._darkened, "lit": view._lit, "wires": view._changed_wires, "age": age[0]}}))
		_expect(_strokes(faded, Color(Lesson.GOLD, age[1]), 1.5 * Lesson.U).size() == 2, "the outline holds, then fades smoothly (age %.2f)" % age[0])
	_expect(_strokes(_render(view.model, _anim(0.0, true, {"change": {"node": 4, "darkened": view._darkened, "lit": view._lit, "wires": view._changed_wires, "age": 0.3}})), Lesson.GOLD, 1.5 * Lesson.U).size() == 2, "reduced motion holds the outline without fading")
	_expect(_strokes(_render(view.model, _anim()), Lesson.GOLD, 1.5 * Lesson.U).is_empty(), "no outline without a darkening tap")
	view._process(View.CHANGE_TIME)
	_expect(not view._showing_change(), "the presentation ends after its time")
	# Lesson 2's first tap adds red: the two red floors light up, in red.
	reset.call(1)
	tap.call(4)
	_expect(lits.call() == [[1, 0], [1, 1]] and floors.call().is_empty() and wires.call() == [[1, true]] and view._showing_change(), "lesson 2 red tap: the two red floors it lit, and the red wire")
	_expect(not view.model.passed() and view.model.utterance().kind == "mistake", "the red tap is still a mistake, not a pass")
	var lit_probe := _render(view.model, _anim(0.0, false, {"change": {"node": 4, "darkened": view._darkened, "lit": view._lit, "wires": view._changed_wires, "age": 0.0}}))
	var red_lines := _strokes(lit_probe, Lesson.RED_HI, 2.5 * Lesson.U)
	_expect(red_lines.size() == 2 and _strokes(lit_probe, Color(Lesson.INK, 0.85), 4.5 * Lesson.U).size() == 2 and _strokes(lit_probe, Color(Lesson.WHITE, 0.8), 0.75 * Lesson.U).size() == 2, "newly lit floors get their own colour's line with a white core on an ink casing")
	for i in mini(red_lines.size(), 2):
		_expect(_outline_fits(red_lines[i], view.model.definition().red_faces[i]), "lesson 2 red tap: floor %d's outline lies inside it" % i)
	_expect(_strokes(lit_probe, Lesson.GOLD, 1.5 * Lesson.U).is_empty() and _strokes(lit_probe, Lesson.BLUE_HI, 2.5 * Lesson.U).is_empty(), "newly lit floors are never gold, and the unchanged blue floors get nothing")
	var red_cores := _shapes(lit_probe, Lesson.WHITE).filter(func(shape): return shape.size() == 4 and _bounds(shape).size.y > 20.0)
	_expect(red_cores.size() == 1 and red_cores[0][2].x > red_cores[0][0].x, "lesson 2 red tap: the red diagonal glows")
	var faded_lit := _render(view.model, _anim(0.0, false, {"change": {"node": 4, "darkened": view._darkened, "lit": view._lit, "wires": view._changed_wires, "age": 0.3}}))
	_expect(_strokes(faded_lit, Color(Lesson.RED_HI, 0.5), 2.5 * Lesson.U).size() == 2, "the new light's outline fades the same way")
	# Lesson 2's second tap removes red and adds blue; all four floors go dark.
	tap.call(4)
	_expect(floors.call() == [[1, 0], [1, 1], [2, 0], [2, 1]] and lits.call().is_empty() and wires.call() == [[1, false], [2, true]], "blue: the red trace leaves and the blue wire glows, with the four floors they darkened")
	# Both: lesson 3's third tap adds red to blue; only the red floors went dark.
	reset.call(2)
	tap.call(4)
	tap.call(4)
	_expect(floors.call() == [[2, 0], [2, 1]] and lits.call() == [[1, 0], [1, 1]] and wires.call() == [[1, false], [2, true]], "red to blue: the removed red wire relights the red floors while the blue wire darkens the blue ones")
	var mixed_probe := _render(view.model, _anim(0.0, false, {"change": {"node": 4, "darkened": view._darkened, "lit": view._lit, "wires": view._changed_wires, "age": 0.0}}))
	_expect(_strokes(mixed_probe, Lesson.GOLD, 1.5 * Lesson.U).size() == 2 and _strokes(mixed_probe, Lesson.RED_HI, 2.5 * Lesson.U).size() == 2, "red to blue: gold on the two darkened floors, red on the two relit ones")
	tap.call(4)
	_expect(floors.call() == [[1, 0], [1, 1]] and lits.call().is_empty() and wires.call() == [[1, true]], "both: only the floors this tap darkened, and only the wire that changed")
	# Lesson 6's two parts: each repair darkens exactly its one floor.
	reset.call(5, 0)
	tap.call(0)
	_expect(floors.call().size() == 1 and int(view._darkened[0].component) == 1 and wires.call() == [[1, true]] and view.model.passed(), "lesson 6 red: the single floor and the red wire")
	reset.call(5, 1)
	tap.call(2)
	_expect(floors.call().is_empty() and lits.call() == [[1, 2]] and wires.call() == [[1, true]], "lesson 6 blue: the first tap (red) lights only the red edge floor")
	tap.call(2)
	_expect(floors.call() == [[1, 2], [2, 0]] and wires.call() == [[1, false], [2, true]] and view.model.passed(), "lesson 6 blue: the red edge floor the first tap lit and the blue floor go dark, with the red trace and the blue wire")
	_expect(view.model.definition().red_faces[2].nodes.size() == 2, "that red floor is a half (edge) floor")
	# A full floor's outline fits it and clears its sockets; a half (edge)
	# floor's is its glass rectangle 3 units in, corners cut by 2.
	var halves := 0
	for phase in 2:
		reset.call(5, phase)
		for family in [view.model.definition().red_faces, view.model.definition().blue_faces]:
			for face in family:
				var outline := Lesson.floor_outline(face)
				if face.nodes.size() == 4:
					_expect(_outline_fits(outline, face, false), "outline of floor %s fits and clears its sockets" % [face.nodes])
				else:
					halves += 1
					_expect(_bounds(outline).is_equal_approx(Lesson.face_rect(face).grow(-3)) and outline.size() == 9 and outline[0].distance_to(_bounds(outline).position) < 2.01, "outline of half floor %s is its inset rectangle" % [face.nodes])
	_expect(halves >= 4, "half floors are among the outlines checked")
	# Every single tap from every lesson start: marked floors are exactly the
	# lit-to-dark and dark-to-lit ones; unchanged floors are never marked.
	var mixed := false
	var light_only := false
	for stage in 7:
		for node in 9:
			reset.call(stage)
			var before := [view.model.lit_red_checks(), view.model.lit_blue_checks()]
			tap.call(node)
			var after := [view.model.lit_red_checks(), view.model.lit_blue_checks()]
			var expected := []
			var newly := []
			for component in [1, 2]:
				for check in before[component - 1]:
					if not after[component - 1].has(check):
						expected.append([component, check])
				for check in after[component - 1]:
					if not before[component - 1].has(check):
						newly.append([component, check])
			_expect(floors.call() == expected and lits.call() == newly and view._showing_change() == not (expected.is_empty() and newly.is_empty()), "stage %d node %d: only genuine lit-to-dark and dark-to-lit floors are marked" % [stage, node])
			mixed = mixed or (not newly.is_empty() and not expected.is_empty())
			light_only = light_only or (not newly.is_empty() and expected.is_empty())
	_expect(mixed and light_only, "the sweep covers taps that darken and light at once, and taps that only light")
	# A dark but unsafe board still marks its floors, and the leak is told as before.
	reset.call(0)
	tap.call(1)
	tap.call(7)
	_expect(not floors.call().is_empty() and not view.model.passed() and view._leaks.active, "dark but leaking: the darkened floors are marked and the leak still shows")
	# Lifecycle: a later action, Continue, home and replay end it.
	reset.call(0)
	tap.call(4)
	tap.call(0)
	_expect(not view._showing_change() or floors.call() != [[1, 0], [1, 1]], "the next tap replaces a stale presentation")
	reset.call(0)
	tap.call(4)
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(view.model.stage_index == 1 and not view._showing_change(), "Continue does not carry it into the next lesson")
	reset.call(0)
	tap.call(4)
	view._show_title()
	view._open_tutorial()
	_expect(not view._showing_change(), "home and resume clear it")
	# Lesson 4: calling the foreman right after a darkening tap (well within
	# its 0.45 s) ends the darkening; the count and verdict take over.
	reset.call(3)
	for step in 4:
		tap.call(4)
	_expect(view._showing_change() and view.model.can_call_foreman() and floors.call() == [[1, 0], [1, 1]], "lesson 4: the tap back to both darkens the red floors on a callable board")
	view._process(0.1)
	_expect(view._showing_change(), "lesson 4: still showing 0.1 s later")
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(not view.model.inspection.is_empty() and not view._showing_change() and view._change_age < View.CHANGE_TIME, "lesson 4: calling the foreman within 0.45 s ends the darkening")
	reset.call(0)
	tap.call(4)
	view.model.restart()
	_expect(not view._showing_change(), "replay clears it")
	# Reduced motion: still shown (static), then gone after its time.
	view.reduced_motion = true
	reset.call(0)
	tap.call(4)
	_expect(view._showing_change(), "reduced motion shows the static outline")
	view._process(View.CHANGE_TIME)
	_expect(not view._showing_change(), "reduced motion removes it after its time, without a fade")
	view.reduced_motion = false
	_expect(view._sound_starts == sounds, "muted: no sound was added by the presentation")


func _test_counting(view) -> void:
	var stage4 := func() -> void:
		view.model.stage_index = 3
		view.model._reset_stage()
		view.model._record("next_stage", {})
		view._navigation_guard_until = 0
		view._publish_semantics()
	view.reduced_motion = false
	view._muted = false
	stage4.call()
	var sounds: int = view._sound_starts
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	var state: Dictionary = view.semantic_state()
	_expect(state.passed and state.counting and not state.continue_enabled, "calling the foreman starts counting; the model verdict is already safe")
	_expect(view._spoken(state) == "電気がもれていないか、\nチェックするよ！" and view._talk_age == 0.0, "the foreman says he is checking")
	_expect(view._sound_starts == sounds and view._success_age >= View.SETTLED, "the pass is not celebrated before the count")
	var probe := _render(view.model, _anim(0.0, false, {"counting": 0.4, "state": view.model.semantic_state()}))
	var drawn := _texts(probe)
	_expect(drawn.has("チェックするよ！") and not drawn.has("これで安心！") and drawn.has("チェックして！") and not drawn.has("つづける"), "while checking only the checking line shows and Continue is not drawn")
	_expect(_strokes(probe, Color(Lesson.RED_HI, 1.0), 1.2 * Lesson.U).is_empty() and _strokes(probe, Color(Lesson.BLUE_HI, 1.0), 1.2 * Lesson.U).is_empty(), "lesson 4 traces no inspection lines while checking")
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	_expect(view.model.stage_index == 3, "Continue cannot race the count")
	view._process(View.COUNT_TIME - 0.1)
	_expect(view.semantic_state().counting, "the check is still running just before its end")
	view._process(0.2)
	state = view.semantic_state()
	_expect(not state.counting and state.continue_enabled and view._spoken(state) == "よし、電気はもれてないね。\nこれで安心！", "after the check the verdict is spoken and Continue enabled")
	var passed_probe := _render(view.model, _anim(0.0, false, {"state": view.model.semantic_state()}))
	_expect(_strokes(passed_probe, Color(Lesson.RED_HI, 1.0), 1.2 * Lesson.U).is_empty() and _strokes(passed_probe, Color(Lesson.BLUE_HI, 1.0), 1.2 * Lesson.U).is_empty() and _strokes(passed_probe, Color(Lesson.RED_HI, 0.6), 1.2 * Lesson.U).is_empty(), "lesson 4's pass shows no inspection lines")
	_expect(view._sound_starts == sounds + 1 and view._success_age < 0.1 and view._enable_age < 0.1, "the pass is celebrated once, after the count")
	view._process(2.0)
	_expect(view._sound_starts == sounds + 1, "no second celebration")
	# An edit during the count cancels it with its verdict and pending celebration.
	stage4.call()
	sounds = view._sound_starts
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	view._handle_design_tap(Lesson.socket_center(0) * 2.0)
	view._publish_semantics()
	state = view.semantic_state()
	_expect(not state.counting and not state.inspected and state.utterance.kind == "mistake" and view._spoken(state) == state.utterance.text, "an edit replaces the counting line; no stale explanation")
	view._process(2.0)
	_expect(view._sound_starts == sounds and not view.model.passed(), "a cancelled count never celebrates")
	# Home during the count settles it: the resumed lesson shows the verdict without replay.
	stage4.call()
	sounds = view._sound_starts
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	view._show_title()
	view._publish_semantics()
	view._navigation_guard_until = 0
	view._open_tutorial()
	view._publish_semantics()
	state = view.semantic_state()
	_expect(not state.counting and state.continue_enabled and view._talk_age >= View.SETTLED and view._sound_starts == sounds, "home cancels the presentation; resume is settled and silent")
	# A leak found by counting is explained only after the count.
	stage4.call()
	for tap in 3:
		view._handle_design_tap(Lesson.socket_center(4) * 2.0)
	view._handle_design_tap(Lesson.socket_center(1) * 2.0)
	view._handle_design_tap(Lesson.socket_center(7) * 2.0)
	view._publish_semantics()
	_expect(view.model.can_call_foreman() and not view.model._inspect_residual().safe, "fixture: a dark leaking inspection lesson")
	var leaks: int = view._leak_sound_starts
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(view.semantic_state().counting and view._leak_age < 0.0 and view._leak_sound_starts == leaks, "the discharge waits for the count")
	view._process(View.COUNT_TIME + 0.1)
	_expect(view._leak_sound_starts == leaks + 1 and view._leak_age >= 0.0 and view._leak_age < 0.2, "the leak presentation follows the count")
	# Reduced motion skips straight to the final verdict; lesson 5 never counts.
	view.reduced_motion = true
	stage4.call()
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(not view.semantic_state().counting and view.semantic_state().continue_enabled, "reduced motion shows the verdict at once")
	view.reduced_motion = false
	view.model.stage_index = 4
	view.model._reset_stage()
	view.model.play_demo()
	view.model._record("next_stage", {})
	view._publish_semantics()
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(view.semantic_state().counting and view._leak_age < 0.0, "lesson 5 checks for 1.0 s too, then shows the leaving light")
	view._process(View.COUNT_TIME + 0.05)
	view._publish_semantics()
	_expect(not view.semantic_state().counting and view._leak_age >= 0.0 and view._leak_age < 0.2, "the leaving light starts after the check")


# Lesson 1 rings its approved bell once per real pass; other lessons keep
# the default sting; mute, leaks, redraws and resume never ring it.
func _test_lesson1_bell(view) -> void:
	view.reduced_motion = true
	view._muted = false
	var reset := func(stage: int) -> void:
		view.model.stage_index = stage
		view.model.boundary_phase = 0
		view.model._reset_stage()
		view.model.play_demo()
		view.model._record("next_stage", {})
		view._navigation_guard_until = 0
		view._publish_semantics()
	reset.call(0)
	var starts: int = view._sound_starts
	view._handle_design_tap(Lesson.socket_center(1) * 2.0)
	view._publish_semantics()
	view._handle_design_tap(Lesson.socket_center(7) * 2.0)
	view._publish_semantics()
	_expect(view.model.utterance().kind == "unsafe" and view._sound_starts == starts, "an unsafe dark lesson 1 rings nothing")
	reset.call(0)
	view._handle_design_tap(Lesson.socket_center(4) * 2.0)
	view._publish_semantics()
	_expect(view._sound_starts == starts + 1 and view._last_reward_sound == "lesson1_bell" and view._audio.stream == View.LESSON1_BELL, "lesson 1's pass rings the bell once")
	_expect(view.model.utterance().text == "いいぞ！\n赤い床のちらつきが\n直ったね！", "with the approved praise")
	view._publish_semantics()
	view.queue_redraw()
	view._show_title()
	view._publish_semantics()
	view._navigation_guard_until = 0
	view._open_tutorial()
	view._publish_semantics()
	_expect(view._sound_starts == starts + 1, "redraws and resume never ring it again")
	view._navigation_guard_until = 0
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	view._handle_design_tap(Lesson.socket_center(4) * 2.0)
	view._handle_design_tap(Lesson.socket_center(4) * 2.0)
	view._publish_semantics()
	_expect(view.model.definition().id == "blue_two_taps" and view.model.passed(), "fixture: lesson 2 passed")
	_expect(view._sound_starts == starts + 2 and view._last_reward_sound == "sting" and view._audio.stream == view._sting, "lesson 2 keeps the default sting")
	view._muted = true
	reset.call(0)
	view._handle_design_tap(Lesson.socket_center(4) * 2.0)
	view._publish_semantics()
	_expect(view.model.passed() and view._sound_starts == starts + 2, "a muted pass rings nothing")
	view._muted = false


func _run() -> void:
	_test_angular_geometry()
	_test_plates_are_hit_areas()
	_test_latest_utterance_only()
	_test_inspection_presentation()
	_test_call_labels()
	_test_leak_without_counting()
	_test_visual_check()
	_test_check_detail_plan()
	_test_no_legend()
	_test_socket_wire_crossing()
	_test_wire_orientation()
	_test_foreman_alignment()
	var bell_references := View.LESSON1_BELL.get_reference_count()
	var view := View.new()
	root.add_child(view)
	view.size = Vector2(390, 844)
	view.reduced_motion = true
	await process_frame
	view._open_tutorial()
	view._navigation_guard_until = 0
	view._publish_semantics()
	# Native touch and mouse at several viewport scales: one tap, one step.
	for size in [Vector2(390, 844), Vector2(1170, 2532), Vector2(412, 915), Vector2(1440, 900), Vector2(844, 390), Vector2(320, 568)]:
		view.size = size
		view._update_transform()
		for touch in [true, false]:
			var before: int = view.model.corrections[0]
			_tap(view, view._offset + Lesson.socket_center(0) * 2.0 * view._scale, touch)
			_expect(view.model.corrections[0] == (before + 1) % 4, "one %s tap is one wire step at %s" % ["touch" if touch else "mouse", size])
	while view.model.corrections[0] != 0:
		view._handle_design_tap(Lesson.socket_center(0) * 2.0)
	view.size = Vector2(390, 844)
	view._update_transform()
	# A disabled Continue does nothing; the pass enables it.
	var count: int = view.model.trace.size()
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	_expect(view.model.trace.size() == count and view.model.stage_index == 0, "disabled Continue is inert")
	view._handle_design_tap(Lesson.socket_center(4) * 2.0)
	view._publish_semantics()
	_expect(view.model.can_continue() and view._success_age == 0.0, "the solving tap passes and celebrates once")
	view._handle_design_tap(View.PRIMARY_RECT.position)
	view._publish_semantics()
	_expect(view.model.stage_index == 1, "Continue's plate corner advances")
	# Mute is shared with the title and persists.
	var muted: bool = view._muted
	view._handle_design_tap(View.LESSON_MUTE_RECT.end - Vector2(0.5, 0.5))
	_expect(view._muted != muted, "the lesson audio plate toggles the shared mute")
	view._show_title()
	view._navigation_guard_until = 0
	view._handle_design_tap(View.Title.MUTE_RECT.get_center())
	_expect(view._muted == muted, "the title toggles the same setting back")
	view._open_tutorial()
	view._navigation_guard_until = 0
	# Rapid input during the inspection presentation cancels the stale result.
	view.reduced_motion = false
	view.model.stage_index = 4
	view.model._reset_stage()
	view.model.play_demo()
	view.model._record("next_stage", {})
	view._publish_semantics()
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(view._leaks.active and view.semantic_state().counting and view._leak_age < 0.0, "calling the foreman starts the check, then its leaving light")
	view._handle_design_tap(Lesson.socket_center(1) * 2.0)
	view._publish_semantics()
	_expect(not view._leaks.active and view._leak_routes.is_empty() and view.model.inspection.is_empty() and not view.semantic_state().check_detail, "a tap during the presentation cancels the stale result")
	_expect(not view.model.fault_revealed() and view.model.utterance().kind == "mistake", "the board stays editable, with no fault reveal in lesson 5")
	for tap in 3:
		view._handle_design_tap(Lesson.socket_center(1) * 2.0)
	view._publish_semantics()
	_expect(view.model.can_call_foreman() and not view._leaks.active, "returning to the trap needs another call")
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(view._leaks.active and view.semantic_state().counting and view._leak_age < 0.0 and view._leak_sound_starts <= 2, "a fresh call starts a fresh presentation")
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(not view.model.passed() and view._leaks.active, "calling again on the same leaking board does nothing")
	_test_wiring_change(view)
	_test_counting(view)
	_test_lesson1_bell(view)
	_test_button_announcement(view)
	_test_check_detail(view)
	_test_demonstration(view)
	# The audio server drops stopped playbacks (and their streams) on its own
	# mixing thread. After this long synchronous run the next frames advance
	# game time faster than real time, so a fixed timer could end first and
	# leave them alive at exit. Wait, in real time, until they are released.
	var streams := _weak_streams(view)
	view._audio.stop()
	view._lamp_audio.stop()
	view.queue_free()
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and (View.LESSON1_BELL.get_reference_count() > bell_references or streams.any(func(stream): return stream.get_ref() != null)):
		await process_frame
	_expect(View.LESSON1_BELL.get_reference_count() == bell_references and streams.all(func(stream): return stream.get_ref() == null), "every played sound is released after the view is freed")
	if failures.is_empty():
		print("PASS: lesson geometry, plates and hit areas, one-step input at any scale, latest utterance, inspection presentation and stale-result cancellation")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
