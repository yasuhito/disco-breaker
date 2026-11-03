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
	check.call("lesson 5 start", "親方を呼ぶ を押せる")
	call.call()
	check.call("lesson 5 leak", "親方を呼ぶ はまだ押せない")
	tap.call(0)
	check.call("lesson 5 lit", "親方を呼ぶ はまだ押せない")
	reset.call(6)
	check.call("lesson 7 start", "親方を呼ぶ はまだ押せない")
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
	_expect(seen.size() == 7, "every announcement form is covered")


# Lesson 4's bottom button reads 「チェックして！」 (disabled on a lit board too);
# lessons 5 and 7 keep 「親方を呼ぶ」.
func _test_call_labels() -> void:
	for case in [[3, "チェックして！"], [4, "親方を呼ぶ"], [6, "親方を呼ぶ"]]:
		var model := Tutorial.new()
		model.stage_index = case[0]
		model._reset_stage()
		var drawn := _texts(_render(model, _anim()))
		_expect(drawn.has(case[1]) and drawn.count("チェックして！") + drawn.count("親方を呼ぶ") == 1, "lesson %d's call button reads %s" % [case[0] + 1, case[1]])
	var lit := Tutorial.new()
	lit.stage_index = 3
	lit._reset_stage()
	lit.tap_node(1, 1)
	_expect(not lit.can_call_foreman() and _texts(_render(lit, _anim())).has("チェックして！"), "lesson 4's disabled button keeps its label")


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
	_expect(view._spoken(state) == "上の段と左の列を\n数えるぞ。" and view._talk_age == 0.0, "the foreman says he is counting")
	_expect(view._sound_starts == sounds and view._success_age >= View.SETTLED, "the pass is not celebrated before the count")
	var probe := _render(view.model, _anim(0.0, false, {"counting": 0.4, "state": view.model.semantic_state()}))
	var drawn := _texts(probe)
	_expect(drawn.has("数えるぞ。") and not drawn.has("漏電はないぞ。") and drawn.has("チェックして！") and not drawn.has("つづける"), "while counting only the counting line shows and Continue is not drawn")
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
	_test_call_labels()
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
	_test_wiring_change(view)
	_test_counting(view)
	_test_lesson1_bell(view)
	_test_button_announcement(view)
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
