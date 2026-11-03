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


# The legend's four sockets: red and blue bands of one size crossing exactly
# at the centre, a faint grey guide on the same centre line for each missing
# colour (no dots), chevrons of two equal joined arms centred between sockets.
func _test_legend_alignment() -> void:
	var probe := Probe.new()
	var art := Lesson.new()
	art.view = probe
	art._legend(Lesson.LEGEND_Y)
	var grooves := _shapes(probe, Lesson.GROUT)
	var reds := _shapes(probe, Lesson.RED)
	var blues := _shapes(probe, Lesson.BLUE)
	var guides := _shapes(probe, Lesson.GUIDE)
	var arms := _shapes(probe, Lesson.MIST)
	_expect(grooves.size() == 4 and reds.size() == 2 and blues.size() == 2 and guides.size() == 4 and arms.size() == 6, "the legend draws four sockets, two red, two blue, four grey guides and three chevrons")
	if grooves.size() != 4 or reds.size() != 2 or blues.size() != 2 or guides.size() != 4 or arms.size() != 6:
		return
	var centres: Array[Vector2] = []
	for groove in grooves:
		centres.append(_bounds(groove).get_center())
		_expect(is_equal_approx(centres[-1].y, (Lesson.LEGEND_Y + 0.5) * Lesson.U), "each legend socket is centred on the legend line")
	# Guides in drawing order: empty red, empty blue, blue on the red socket, red on the blue socket.
	for guide in [[guides[0], 0, reds[0], true], [guides[1], 0, blues[0], false], [guides[2], 1, blues[0], false], [guides[3], 2, reds[0], true]]:
		var points: PackedVector2Array = guide[0]
		var wire := _bounds(guide[2])
		_expect(_near(_mean(points), centres[guide[1]]), "each legend guide is centred on its socket")
		_expect(is_equal_approx(_bounds(points).position.y, wire.position.y) and is_equal_approx(_bounds(points).end.y, wire.end.y) and (points[2].x > points[0].x) == guide[3], "each legend guide runs along its colour's band, end to end")
		_expect(_bounds(points).size.x < wire.size.x, "a guide is thinner than its wire")
	# Each coloured band lies over the grey guide it crosses.
	var order := {}
	for index in probe.log.size():
		var entry: Array = probe.log[index]
		if entry[0] == "polygon" and entry[2] in [Lesson.GUIDE, Lesson.RED, Lesson.BLUE]:
			var icon := 0
			for c in 4:
				if _mean(entry[1]).distance_to(centres[c]) < _mean(entry[1]).distance_to(centres[icon]):
					icon = c
			order[icon] = order.get(icon, []) + [entry[2] == Lesson.GUIDE]
	for icon in [1, 2]:
		_expect(order.get(icon, []) == [true, false], "legend socket %d draws its guide under its coloured band" % icon)
	for band in [[reds[0], 1], [blues[0], 2], [reds[1], 3], [blues[1], 3]]:
		_expect(_near(_mean(band[0]), centres[band[1]]), "each legend wire band is centred on its socket (both cross at the centre)")
	_expect(_bounds(reds[1]).size.is_equal_approx(_bounds(blues[1]).size), "red and blue legend bands are the same size")
	for gap in 3:
		var upper: PackedVector2Array = arms[gap * 2]
		var lower: PackedVector2Array = arms[gap * 2 + 1]
		_expect(_near(upper[3], lower[0]) and _near(upper[2], lower[1]), "each chevron's arms join on one edge")
		_expect(is_equal_approx(_bounds(upper).size.y, _bounds(lower).size.y), "each chevron's arms are equally long")
		_expect(_near(_union([upper, lower]).get_center(), (centres[gap] + centres[gap + 1]) * 0.5), "each chevron is centred between its sockets")


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


func _test_inspection_presentation() -> void:
	var leak := Tutorial.new()
	leak.stage_index = 4
	leak._reset_stage()
	leak.inspect_floor()
	var routes := _routes(leak)
	_expect(routes.size() == 1 and routes[0].qubits == [1, 4, 7], "the trap's route is its red residual chain")
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
	# Once lesson 5 has shown the fault, a repeated leak keeps it visible
	# from the first frame instead of hiding it for the build-up.
	for tap in 4:
		leak.tap_node(0, 0)
	leak.inspect_floor()
	_expect(leak.leak_count == 2, "fixture: a second leak in lesson 5")
	var again := _texts(_render(leak, _anim(0.1, false, {"routes": _routes(leak), "leak_age": 0.1})))
	_expect(again.has("破線は元の故障、実線は自分の配線"), "the repair keeps the dashed fault through a repeated leak")
	# Both colours leaking show both explanations, not one colour.
	var both := Tutorial.new()
	both.stage_index = 6
	both._reset_stage()
	for node in [[0, 2], [1, 3], [7, 1]]:
		for tap in node[1]:
			both.tap_node(int(node[0] / 3.0), node[0] % 3)
	both.inspect_floor()
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
	# Before any inspection nothing is revealed.
	var hidden := Tutorial.new()
	hidden.stage_index = 4
	hidden._reset_stage()
	var unrevealed := _texts(_render(hidden, _anim()))
	_expect(not unrevealed.has("破線は元の故障、実線は自分の配線") and not unrevealed.has("2"), "no fault reveal or counts before the inspection")


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
	_expect(view._spoken(state) == "上の段と左の列を\n数えるぞ。" and view._talk_age == 0.0, "the foreman says he is counting")
	_expect(view._sound_starts == sounds and view._success_age >= View.SETTLED, "the pass is not celebrated before the count")
	var probe := _render(view.model, _anim(0.0, false, {"counting": 0.4, "state": view.model.semantic_state()}))
	var drawn := _texts(probe)
	_expect(drawn.has("数えるぞ。") and not drawn.has("漏電はないぞ。") and drawn.has("親方を呼ぶ") and not drawn.has("つづける"), "while counting only the counting line shows and Continue is not drawn")
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	_expect(view.model.stage_index == 3, "Continue cannot race the count")
	view._process(0.9)
	_expect(view.semantic_state().counting, "the blue line is still being traced")
	view._process(0.8)
	state = view.semantic_state()
	_expect(not state.counting and state.continue_enabled and view._spoken(state) == "検査合格！\n漏電はないぞ。", "after counting the verdict is spoken and Continue enabled")
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
	view._process(1.7)
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
	view.model._record("next_stage", {})
	view._publish_semantics()
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(not view.semantic_state().counting and view._leak_age == 0.0, "the trap's leak is explained at once, as before")


# Lesson 1 rings its approved bell once per real pass; other lessons keep
# the default sting; mute, leaks, redraws and resume never ring it.
func _test_lesson1_bell(view) -> void:
	view.reduced_motion = true
	view._muted = false
	var reset := func(stage: int) -> void:
		view.model.stage_index = stage
		view.model.boundary_phase = 0
		view.model._reset_stage()
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
	_test_legend_alignment()
	_test_socket_wire_crossing()
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
	view.model._record("next_stage", {})
	view._publish_semantics()
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(view._leaks.active and view._leak_age == 0.0 and view._leak_routes.size() == 1, "calling the foreman starts the leak presentation")
	view._handle_design_tap(Lesson.socket_center(1) * 2.0)
	view._publish_semantics()
	_expect(not view._leaks.active and view._leak_routes.is_empty() and view.model.inspection.is_empty(), "a tap during the presentation cancels the stale result")
	_expect(view.model.fault_revealed() and view.model.utterance().kind == "mistake", "the board stays editable with the lesson's dashed hint")
	for tap in 3:
		view._handle_design_tap(Lesson.socket_center(1) * 2.0)
	view._publish_semantics()
	_expect(view.model.can_call_foreman() and not view._leaks.active, "returning to the trap needs another call")
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(view._leaks.active and view._leak_age == 0.0 and view._leak_sound_starts <= 2, "a fresh call starts a fresh presentation")
	view._handle_design_tap(View.PRIMARY_RECT.get_center())
	view._publish_semantics()
	_expect(not view.model.passed() and view._leaks.active, "calling again on the same leaking board does nothing")
	_test_counting(view)
	_test_lesson1_bell(view)
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
