class_name LessonArtwork
extends RefCounted

# The lesson screen of the approved 45-degree design proposal
# (docs/design/pixel-system-2026-10-31, source/art.js at 0768655): progress
# bar, speaking foreman with one bubble, board, legend and a bottom button.
# Shapes are ported from the mock's own helpers in its layout units
# (1 unit = 2 design px). Every non-text edge is horizontal, vertical or
# diagonal; flat colours, antialiased like the title's dynamic shapes.
# This draws an already-computed model and never decides a verdict.
const Flicker := preload("res://src/fault_flicker.gd")

const U := 2.0
const INSET := 2.0 - sqrt(2.0)

const INK := Color("#0d0a17")
const NIGHT1 := Color("#1b1430")
const NIGHT2 := Color("#251c3d")
const NIGHT3 := Color("#33284f")
const NIGHT4 := Color("#4b3d70")
const NIGHT5 := Color("#6c5c96")
const MIST := Color("#a89cc8")
const PAPER := Color("#f4ead8")
const BROWN := Color("#7a5638")
const MINT_INK := Color("#1e6a4a")
const GLASS := Color("#1f1934")
const GLASS_HI := Color("#2c2547")
const GROUT := Color("#0a0713")
const RED_HI := Color("#ff9aa0")
const RED := Color("#ef4760")
const RED_LO := Color("#97213d")
const RED_DARK := Color("#4a1a2c")
const BLUE_HI := Color("#a8dcff")
const BLUE := Color("#3f9cff")
const BLUE_LO := Color("#1d4f9e")
const BLUE_DARK := Color("#1a2c52")
const GOLD_HI := Color("#ffe7a3")
const GOLD := Color("#f4b942")
const GOLD_LO := Color("#a5651f")
const MINT_HI := Color("#d2fbe5")
const MINT := Color("#7fe3b0")
const MINT_LO := Color("#2f8f68")
const SKIN := Color("#c98150")
const SKIN_LO := Color("#8e5030")
const VEST := Color("#f07a2b")
const WHITE := Color("#ffffff")
const HAIR := Color("#3a2214")
const CHEEK := Color("#e0866a")
const SHIRT := Color("#2c4f8a")

# Red wiring is always "\", blue always "/", as are their lit floors' stripes.
const FAMILY := {
	1: {"hi": RED_HI, "base": RED, "lo": RED_LO, "dark": RED_DARK, "dir": 1},
	2: {"hi": BLUE_HI, "base": BLUE, "lo": BLUE_LO, "dark": BLUE_DARK, "dir": -1},
}
const BUTTON := {
	"success": {"face": MINT, "hi": MINT_HI, "lo": MINT_LO, "text": INK},
	"call": {"face": GOLD, "hi": GOLD_HI, "lo": GOLD_LO, "text": INK},
	"secondary": {"face": NIGHT3, "hi": NIGHT4, "lo": INK, "text": PAPER},
}

# The mock's lesson layout (units). Each control's hit area is its plate.
const HOME := Rect2(6, 6, 22, 22)
const BAR := Rect2(34, 12, 110, 10)
const MUTE := Rect2(150, 6, 40, 22)
const FOREMAN_AT := Vector2(6, 58)
const BUBBLE := Rect2(62, 60, 128, 46)
const ORIGIN := Vector2(51, 152)
const PITCH := 46.0
const LEGEND_Y := 296.0
const PRIMARY := Rect2(8, 364, 178, 32)
# Not in the three-lesson mock: the optional skip (and Back to title) sits
# centred between the legend and the bottom button, at the mock's secondary
# button size.
const SECONDARY := Rect2(37, 321, 120, 26)
const SPEAKER_SPAN := {false: Vector2(0, 34.2), true: Vector2(-8.5, 22.5)}

# Inspection presentation (seconds): leftovers and the floors' "2" first,
# then the leak route and the inspection line's count, then the cracks and
# the original fault. Reduced motion shows the final frame.
const LEAK_ROUTE_AT := 0.7
const LEAK_REVEAL_AT := 1.4
const LEAK_DONE_AT := 2.0
# Lesson 4's counting (the view's COUNT_TIME): red line, then blue line.
const COUNT_LINE_TIME := 0.8

var view
var _aa := 0.25
var _stripes: Dictionary = {}


static func px(rect: Rect2) -> Rect2:
	return Rect2(rect.position * U, rect.size * U)


static func socket_center(node: int) -> Vector2:
	return ORIGIN + Vector2(node % 3, int(node / 3.0)) * PITCH


# Every connection box reacts in its whole 46 x 46 unit cell (92 x 92 px).
static func node_at(point: Vector2) -> int:
	var cell := ((point / U - ORIGIN) / PITCH + Vector2(0.5, 0.5)).floor()
	if cell.x < 0 or cell.y < 0 or cell.x > 2 or cell.y > 2:
		return -1
	return int(cell.y) * 3 + int(cell.x)


# A floor's glass rectangle: the square between its four sockets, or half a
# cell outside the board for a two-socket boundary floor.
static func face_rect(face: Dictionary) -> Rect2:
	var low := Vector2(INF, INF)
	var high := -low
	for node in face.nodes:
		var center := socket_center(int(node))
		low = low.min(center)
		high = high.max(center)
	if face.nodes.size() == 2:
		var half := PITCH * 0.5 - 1.0
		if is_equal_approx(low.y, high.y):
			if int(face.nodes[0]) < 3:
				low.y -= half
			else:
				high.y += half
		elif int(face.nodes[0]) % 3 == 0:
			low.x -= half
		else:
			high.x += half
	return Rect2(low, high - low)


# The 45-degree band of a wire on a socket, as the mock draws it.
static func wire_band(center: Vector2, component: int) -> PackedVector2Array:
	var x0 := center.x - 7.0 if component == 1 else center.x + 6.0
	var dx := 1.0 if component == 1 else -1.0
	return PackedVector2Array([Vector2(x0, center.y - 7.0), Vector2(x0 + 14.0 * dx, center.y + 7.0)])


func draw(target, model, anim: Dictionary) -> void:
	view = target
	_aa = 0.5 / maxf(float(anim.get("device_scale", 1.0)), 0.01)
	var state: Dictionary = anim.get("state", {})
	if state.is_empty():
		state = model.semantic_state()
	var reduced: bool = anim.reduced
	var now: float = anim.time
	var utterance: Dictionary = state.utterance
	# While the foreman counts, his verdict waits: the bubble holds the
	# counting line and Continue stays disabled.
	var counting := float(anim.get("counting", -1.0))
	if counting >= 0.0:
		utterance = {"kind": "counting", "text": String(model.definition().lines.call)}
	var happy := (bool(state.passed) and counting < 0.0) or bool(state.finished)
	var worry: bool = utterance.kind == "unsafe"
	_rect(0, 0, 195, 422, NIGHT1)
	_home(HOME.position.x, HOME.position.y)
	var bar := float(anim.progress)
	_progress_bar(BAR.position.x, BAR.position.y, BAR.size.x, bar)
	_mute(MUTE.position.x, MUTE.position.y, anim.muted)
	_display("チュートリアル" if state.finished else String(state.title), 8, 34, PAPER)
	var talk := float(anim.since_talk)
	var win := float(anim.since_success)
	var pose := {
		"bob": 1.0 if not reduced and sin(now * 2.6) > 0.4 else 0.0,
		"hop": -float([1, 2, 2, 1][mini(3, int(win / 0.065))]) if not reduced and win < 0.26 else 0.0,
		"blink": not reduced and fposmod(now, 3.7) < 0.12,
		"mouth": (("rest" if int(talk / 0.12) % 2 else "talk") if not reduced and talk < 0.72 else ("smile" if happy else ("worry" if worry else "rest"))),
		"brows": "up" if happy else ("worry" if worry else "neutral"),
		"thumb": happy,
	}
	_foreman(FOREMAN_AT.x, FOREMAN_AT.y, pose)
	var ink := INK
	match String(utterance.kind):
		"safe", "done":
			ink = MINT_INK
		"unsafe":
			ink = RED_LO
		"mistake":
			ink = BROWN
	_bubble(BUBBLE, String(utterance.text), ink)
	_board(model, state, anim)
	if _shows_fault(model, state, anim):
		# The answer is a tutorial reveal, not information from the floors.
		_text("破線は元の故障、実線は自分の配線", 194, 578, MIST, "center")
		_text("元の故障は練習用に見せている。", 194, 602, MIST, "center")
	else:
		_legend(LEGEND_Y)
	if state.finished:
		_button(SECONDARY, "secondary", "normal", "タイトルへ", false)
	elif state.stage_id == "graduation_3x3":
		_button(SECONDARY, "secondary", "normal", "自由練習をスキップ", false, true)
	var can_continue: bool = state.can_continue and counting < 0.0
	var hop: float = -1.0 if not reduced and float(anim.since_enable) < 0.18 and (can_continue or state.can_call_foreman) else 0.0
	var primary := PRIMARY
	primary.position.y += hop
	if state.finished:
		_button(primary, "success", "normal", "もう一度", true)
	elif can_continue:
		_button(primary, "success", "normal", "つづける", true)
	elif state.inspection_mode == "call":
		_button(primary, "call", "normal" if state.can_call_foreman else "disabled", "親方を呼ぶ", true)
	else:
		_button(primary, "success", "disabled", "つづける", true)


# The dashed original fault appears with the last step of a leak's
# presentation; once lesson 5 has shown it, it stays through the repair.
func _shows_fault(model, state: Dictionary, anim: Dictionary) -> bool:
	if not state.fault_revealed:
		return false
	var leaking: bool = state.inspected and not bool(state.inspection.safe)
	if state.stage_id == "crossing_trap" and int(model.leak_count) > (1 if leaking else 0):
		return true
	return _leak_age(anim, state) >= LEAK_REVEAL_AT


func _leak_age(anim: Dictionary, state: Dictionary) -> float:
	if anim.reduced or not state.inspected:
		return INF
	return float(anim.leak_age)


# ---- board -----------------------------------------------------------------

func _board(model, state: Dictionary, anim: Dictionary) -> void:
	var d: Dictionary = model.definition()
	var reduced: bool = anim.reduced
	var now: float = anim.time
	var c0 := socket_center(0)
	_housing(c0.x - 30, c0.y - 30, 2 * PITCH + 60, 2 * PITCH + 60)
	var floors: Array = []
	for component in [1, 2]:
		var faces: Array = d.red_faces if component == 1 else d.blue_faces
		var lit: Array = state.lit_red if component == 1 else state.lit_blue
		for check in faces.size():
			floors.append({"component": component, "check": check, "face": faces[check], "lit": lit.has(check)})
	# Lit floors last, so their light spills over the neighbouring grout.
	for pass_lit in [false, true]:
		for floor in floors:
			if floor.lit != pass_lit:
				continue
			var level := "off"
			if floor.lit:
				var key: int = model.stage_index * 1000 + int(d.size) * 100 + int(floor.component) * 40 + int(floor.check)
				var brightness := Flicker.brightness(key, now, reduced)
				level = "lit" if brightness >= 0.6 else ("dim" if brightness >= 0.2 else "drop")
			_floor(face_rect(floor.face), floor.component, level)
	var inspection: Dictionary = state.inspection
	var inspected: bool = state.inspected
	var leak: bool = inspected and not bool(inspection.safe)
	var age := _leak_age(anim, state)
	var families: Array[int] = []
	if leak:
		if inspection.red_crossing:
			families.append(1)
		if inspection.blue_crossing:
			families.append(2)
	var residual := {1: Array(model._residual_support(1)), 2: Array(model._residual_support(2))}
	var routes: Array = anim.routes if leak else []
	var counting := float(anim.get("counting", -1.0))
	if counting >= 0.0:
		# The foreman traces the red line (top row), then the blue line (left column).
		for component in [1, 2]:
			_inspection_line(component, 1.0, clampf((counting - (component - 1) * COUNT_LINE_TIME) / COUNT_LINE_TIME, 0.0, 1.0))
	elif (leak and age >= 0.0) or (inspected and state.inspection_mode == "call"):
		# The foreman's inspection lines: red counts the top row, blue the left column.
		for component in ([1, 2] if not leak else families):
			_inspection_line(component, 1.0 if not residual[component].is_empty() else 0.6)
	if leak and age >= LEAK_REVEAL_AT:
		for route in routes:
			var faces: Array = d.red_faces if route.component == 1 else d.blue_faces
			for check in route.checks:
				_cracks(face_rect(faces[check]))
	var target: int = d.target
	var happy: bool = state.passed and counting < 0.0
	# The gold hint ring steps aside while a leak is being explained.
	if target >= 0 and not happy and not state.finished and not leak:
		_target_ring(socket_center(target), GOLD if reduced or int(now / 0.6) % 2 else GOLD_LO)
	if leak and age >= LEAK_ROUTE_AT:
		var grow := 1.0 if age >= LEAK_REVEAL_AT else (age - LEAK_ROUTE_AT) / (LEAK_REVEAL_AT - LEAK_ROUTE_AT)
		for route in routes:
			_route_line(route, grow)
	var reveal := _shows_fault(model, state, anim)
	for node in 9:
		var hidden := int(d.hidden.get(node, 0)) if reveal else 0
		var pressed: bool = not reduced and node == int(anim.pressed_node) and float(anim.since_press) < 0.11
		_socket(socket_center(node), int(state.corrections[node]), pressed, happy and node == target, hidden)
	if leak and age >= 0.0:
		_leftover_marks(families, residual)
		if age >= LEAK_ROUTE_AT:
			for route in routes:
				_route_dot(route, age, reduced)
		_count_badges(d, families, residual, age >= LEAK_ROUTE_AT)
	var since: float = anim.since_success
	if happy and not reduced and since < 0.7:
		_sparks(socket_center(target if target >= 0 else 4), since / 0.7)


func _housing(x: float, y: float, w: float, h: float) -> void:
	_plate(x, y, w, h, 5, NIGHT3)
	_rect(x + 3, y + 1, w - 6, 1, NIGHT5)
	_cham(x + 3, y + 3, w - 6, h - 6, 3, INK)
	_cham(x + 4, y + 4, w - 8, h - 8, 2, GROUT)


func _floor(face: Rect2, component: int, level: String) -> void:
	var f: Dictionary = FAMILY[component]
	var x := face.position.x + 1
	var y := face.position.y + 1
	var w := face.size.x - 2
	var h := face.size.y - 2
	if level == "lit" or level == "dim":
		# Light leak: one solid ring and one translucent ring on the grout.
		_rect(x - 1, y - 1, w + 2, h + 2, f.lo)
		var wash := Color(f.lo, 0.5)
		_rect(x - 2, y - 2, w + 4, 1, wash)
		_rect(x - 2, y + h + 1, w + 4, 1, wash)
		_rect(x - 2, y - 2, 1, h + 4, wash)
		_rect(x + w + 1, y - 2, 1, h + 4, wash)
	if level == "off" or level == "drop":
		_rect(x, y, w, h, GLASS)
		_rect(x + 1, y + 1, w - 2, 2, GLASS_HI)
		_rect(x + 1, y + 3, 1, minf(6, h - 4), GLASS_HI)
		# A dropout keeps a brighter coloured perimeter than a dark floor.
		var edge: Color = f.lo if level == "drop" else f.dark
		_rect(x, y, w, 1, edge)
		_rect(x, y + h - 1, w, 1, edge)
		_rect(x, y, 1, h, edge)
		_rect(x + w - 1, y, 1, h, edge)
		return
	_rect(x, y, w, h, f.base if level == "lit" else f.lo)
	var stripe: Color = f.hi if level == "lit" else f.base
	for piece in _stripe_pieces(Rect2(x, y, w, h), int(f.dir)):
		_poly(piece, stripe)
	_rect(x, y, w, 1, f.hi)
	_rect(x, y, 1, h, f.hi)
	_rect(x, y + h - 1, w, 1, f.lo)
	_rect(x + w - 1, y, 1, h, f.lo)


# Family-coded 45-degree stripes clipped to the glass (cached per floor).
func _stripe_pieces(rect: Rect2, direction: int) -> Array:
	var key := "%s/%d" % [rect, direction]
	if _stripes.has(key):
		return _stripes[key]
	var pieces: Array = []
	var w := rect.size.x
	var h := rect.size.y
	var k := -h
	while k < w + h:
		var band := _diag_points(rect.position.x + k, rect.position.y, h, direction, 2)
		for piece in Geometry2D.intersect_polygons(band, _rect_points(rect)):
			pieces.append(piece)
		k += 12
	_stripes[key] = pieces
	return pieces


func _socket(center: Vector2, code: int, pressed: bool, success: bool, hidden: int) -> void:
	var x := center.x - 13
	var y := center.y - 13
	var s := 26.0
	var k := 8.0
	if success:
		_cham(x - 3, y - 3, s + 6, s + 6, k + 2, GOLD)
		_cham(x - 2, y - 2, s + 4, s + 4, k + 1, GROUT)
	_plate(x, y, s, s, k, NIGHT5)
	_cham(x + 2, y + 2, s - 3, s - 3, k - 2, NIGHT4)
	var p := 1.0 if pressed else 0.0
	if pressed:
		_cham(x + 1, y + 1, s - 2, s - 2, k - 1, NIGHT4)
	_cham(x + 5, y + 5 + p, s - 10, s - 10, 5, GROUT)
	var cap := center + Vector2(0, p)
	if code == 0 and hidden == 0:
		_rect(center.x - 6, center.y - 1 + p, 2, 2, NIGHT5)
		_rect(center.x + 4, center.y - 1 + p, 2, 2, NIGHT5)
	for component in [1, 2]:
		if hidden & component:
			_wire(cap, component, true)
	for component in [1, 2]:
		if code & component:
			_wire(cap, component, false)
	# "0": the player's wire cancels the original fault on this socket.
	if hidden & code & 1:
		_zero_mark(center.x + 6, center.y + 4)
	if hidden & code & 2:
		_zero_mark(center.x - 10, center.y + 4)


func _wire(center: Vector2, component: int, dashed: bool) -> void:
	var f: Dictionary = FAMILY[component]
	var n := 14.0
	var band := wire_band(center, component)
	var x0: float = band[0].x
	var y0: float = band[0].y
	var dx := 1.0 if component == 1 else -1.0
	var segments := [[0, 2], [4, 6], [8, 10], [12, 14]] if dashed else [[0, 14]]
	# The bands' centre lines run through the socket's centre and the tips'
	# centres, so red and blue cross exactly at the centre.
	var bx := x0 - 0.5 * dx
	# Ink casing, colour core and a light centre line (visible to protan eyes).
	for segment in segments:
		_diag(bx + segment[0] * dx - 2, y0 + segment[0], segment[1] - segment[0], dx, INK, 5)
	for segment in segments:
		_diag(bx + segment[0] * dx - 1, y0 + segment[0], segment[1] - segment[0], dx, f.base, 3)
		_diag(bx + segment[0] * dx, y0 + segment[0], segment[1] - segment[0], dx, f.hi, 1)
	if not dashed:
		for tip in [Vector2(x0, y0), Vector2(x0 + (n - 1) * dx, y0 + n - 1)]:
			_plate(tip.x - 2, tip.y - 2, 5, 5, 1, f.hi)


func _zero_mark(x: float, y: float) -> void:
	_rect(x - 1, y - 1, 5, 7, INK)
	_rect(x, y, 3, 5, PAPER)
	_rect(x + 1, y + 1, 1, 3, INK)


func _target_ring(center: Vector2, color: Color) -> void:
	_cham(center.x - 16, center.y - 16, 32, 32, 10, color)
	_cham(center.x - 15, center.y - 15, 30, 30, 9, GROUT)


func _sparks(center: Vector2, progress: float) -> void:
	var d := roundf(14 + 12 * (1 - (1 - progress) * (1 - progress)))
	var r := 2.0 if progress < 0.7 else 1.0
	for u in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var k: float = roundf(d * 0.75) if u.x != 0 and u.y != 0 else d
		_diamond(center.x + u.x * k, center.y + u.y * k, r, GOLD_HI if (u.x + u.y) & 1 else WHITE)


# A traced line grows from its start with a white marker at its head.
func _inspection_line(component: int, alpha: float, traced := 1.0) -> void:
	var c0 := socket_center(0)
	var c8 := socket_center(8)
	var line := PackedVector2Array([Vector2(c0.x - 27, c0.y), Vector2(c8.x + 27, c0.y)]) if component == 1 else PackedVector2Array([Vector2(c0.x, c0.y - 27), Vector2(c0.x, c8.y + 27)])
	var length := _length(line)
	if traced <= 0.0:
		return
	_stroke(_slice(line, 0.0, length * traced), Color(RED_HI if component == 1 else BLUE_HI, alpha), 1.2, [3.0, 2.0])
	if traced < 1.0:
		var head := _point_at(line, length * traced).round()
		_plate(head.x - 3.5, head.y - 3.5, 7, 7, 2, WHITE)


# Radial glass cracks from the centre of a floor the leak route crosses.
func _cracks(face: Rect2) -> void:
	var center := face.get_center().floor()
	var reach := minf(1.0, minf(face.size.x, face.size.y) / PITCH)
	for ray in [[Vector3(-1, -1, 8), Vector3(0, -1, 4)], [Vector3(1, 0, 9), Vector3(1, -1, 4)], [Vector3(0, 1, 8), Vector3(1, 1, 4)], [Vector3(-1, 1, 6), Vector3(-1, 0, 5)]]:
		var point := center
		var points := PackedVector2Array([point + Vector2(0.5, 0.5)])
		for step in ray:
			point += Vector2(step.x, step.y) * roundf(step.z * reach)
			points.append(point + Vector2(0.5, 0.5))
		_stroke(points, PAPER, 0.8)
	_rect(center.x - 1, center.y - 1, 3, 3, PAPER)


# The residual chain LeakFeedback.route found after the verdict, through
# socket centres and the shared floors' centres (45 and 90 degrees only).
static func route_points(route: Dictionary, faces: Array) -> PackedVector2Array:
	var vertical: bool = route.component == 1
	var points := PackedVector2Array()
	var qubits: Array = route.qubits
	var outward := Vector2(0, 27) if vertical else Vector2(27, 0)
	points.append(socket_center(qubits[0]) - outward)
	for index in qubits.size():
		points.append(socket_center(qubits[index]))
		if index < route.checks.size():
			var middle := Vector2.ZERO
			var nodes: Array = faces[route.checks[index]].nodes
			for node in nodes:
				middle += socket_center(node)
			points.append(middle / nodes.size())
	points.append(socket_center(qubits[-1]) + outward)
	return points


func _route_line(route: Dictionary, grow: float) -> void:
	var points: PackedVector2Array = route.points
	var color: Color = RED_HI if route.component == 1 else BLUE_HI
	_stroke(_slice(points, 0.0, _length(points) * clampf(grow, 0.0, 1.0)), color, 2.0, [3.0, 1.0])


func _route_dot(route: Dictionary, age: float, reduced: bool) -> void:
	var points: PackedVector2Array = route.points
	var length := _length(points)
	var travelled := length
	if not reduced:
		var span := LEAK_REVEAL_AT - LEAK_ROUTE_AT
		travelled = length * clampf((age - LEAK_ROUTE_AT) / span, 0.0, 1.0) if age < LEAK_REVEAL_AT else fposmod((age - LEAK_REVEAL_AT) * 40.0, length)
	var head := _point_at(points, travelled).round()
	_plate(head.x - 3.5, head.y - 3.5, 7, 7, 2, WHITE)


func _leftover_marks(families: Array[int], residual: Dictionary) -> void:
	var marked := {}
	for component in families:
		for node in residual[component]:
			var center := socket_center(node)
			if not marked.has(node):
				var ring := _oct_points(center.x - 16, center.y - 16, 32, 32, 10)
				ring.append(ring[0])
				_stroke(ring, GOLD, 1.0, [2.0, 1.5])
				marked[node] = true
			# A gold diamond marks a leftover on that colour's inspection line.
			if (component == 1 and node < 3) or (component == 2 and node % 3 == 0):
				_diamond(center.x + 12, center.y - 13, 4, INK)
				_diamond(center.x + 12, center.y - 13, 3, GOLD)


# Each floor watching leftovers shows how many it sees (even, so dark); the
# inspection line shows its own count (odd: the leak).
func _count_badges(d: Dictionary, families: Array[int], residual: Dictionary, with_cut: bool) -> void:
	for component in families:
		var faces: Array = d.red_faces if component == 1 else d.blue_faces
		for face in faces:
			var count := 0
			for node in face.nodes:
				count += 1 if residual[component].has(node) else 0
			if count > 0:
				var center := face_rect(face).get_center()
				_badge(center.x, center.y, count, PAPER)
	if not with_cut:
		return
	var c0 := socket_center(0)
	for component in families:
		var count := 0
		for node in residual[component]:
			count += 1 if (node < 3 if component == 1 else node % 3 == 0) else 0
		if component == 1:
			_badge(c0.x - 22, c0.y - 9, count, GOLD)
		else:
			_badge(c0.x + 9, c0.y - 26, count, GOLD)


func _badge(x: float, y: float, count: int, face: Color) -> void:
	_plate(x - 5, y - 5, 10, 10, 2, face)
	_text(str(count), x * U, (y - 4.6) * U, INK, "center")


# Each socket's plate spans x - 7 .. x + 8, so its centre is (x + 0.5, y + 0.5):
# the two dots sit symmetrically about it, red "\" and blue "/" are equal
# bands that cross exactly there, and each chevron is two equal arms joined
# at its point, centred in the gap to the next socket.
func _legend(y: float) -> void:
	var xs := [61.0, 83.0, 105.0, 127.0]
	for i in 4:
		var x: float = xs[i]
		_plate(x - 7, y - 7, 15, 15, 4, NIGHT4)
		_cham(x - 4, y - 4, 9, 9, 2, GROUT)
		if i == 0:
			_rect(x - 3, y, 1, 1, NIGHT5)
			_rect(x + 3, y, 1, 1, NIGHT5)
		if i & 1:
			_diag(x - 3.5, y - 2.5, 6, 1, RED, 2)
		if i & 2:
			_diag(x + 2.5, y - 2.5, 6, -1, BLUE, 2)
		if i < 3:
			# The arms meet on x + 12.25 .. x + 13.25; the chevron spans x + 9.75 .. x + 13.25, centred in the 8 .. 15 gap.
			_diag(x + 9.75, y - 2, 2.5, 1, MIST)
			_diag(x + 12.25, y + 0.5, 2.5, -1, MIST)


# ---- chrome ----------------------------------------------------------------

func _home(x: float, y: float) -> void:
	_cham(x, y, 22, 22, 3, INK)
	_cham(x + 1, y + 1, 20, 18, 2, NIGHT3)
	_rect(x + 3, y + 1, 16, 1, NIGHT4)
	_poly(PackedVector2Array([Vector2(x + 10, y + 4), Vector2(x + 12, y + 4), Vector2(x + 18, y + 10), Vector2(x + 16, y + 10), Vector2(x + 16, y + 16), Vector2(x + 6, y + 16), Vector2(x + 6, y + 10), Vector2(x + 4, y + 10)]), PAPER)
	_rect(x + 10, y + 12, 2, 4, NIGHT3)


func _progress_bar(x: float, y: float, w: float, fraction: float) -> void:
	_cham(x, y, w, 10, 3, INK)
	_cham(x + 1, y + 1, w - 2, 8, 2, NIGHT3)
	var fill := roundf((w - 2) * clampf(fraction, 0.0, 1.0))
	if fill <= 0:
		return
	var clip := _rect_points(Rect2(x + 1, y + 1, fill, 8))
	for piece in Geometry2D.intersect_polygons(_oct_points(x + 1, y + 1, w - 2, 8, 2), clip):
		_poly(piece, GOLD)
	_rect(x + 3, y + 2, minf(w - 6, fill - 2), 1, GOLD_HI)
	_rect(x + 2, y + 7, minf(w - 4, fill - 1), 1, GOLD_LO)


# The shared audio toggle: the title's icon and measured label, on the
# lesson's 40 x 22 unit plate.
func _mute(x: float, y: float, muted: bool) -> void:
	_cham(x, y, 40, 22, 3, INK)
	_cham(x + 1, y + 1, 38, 18, 2, NIGHT3)
	_rect(x + 3, y + 1, 34, 1, NIGHT4)
	var rect := px(Rect2(x, y, 40, 22))
	var text := "OFF" if muted else "ON"
	var span: Vector2 = SPEAKER_SPAN[muted]
	var gap := 5.0
	var text_width: float = view._text_width(text, 17)
	var sx := rect.position.x + (rect.size.x - (span.y - span.x + gap + text_width)) * 0.5 - span.x
	var top := rect.position.y + 6.0
	_fill(PackedVector2Array([Vector2(sx, top + 8), Vector2(sx + 6, top + 8), Vector2(sx + 6, top + 6), Vector2(sx + 14, top - 2), Vector2(sx + 14, top + 30), Vector2(sx + 6, top + 22), Vector2(sx + 6, top + 20), Vector2(sx, top + 20)]), PAPER)
	if muted:
		for layer in [[sx - 8.5, 7.0, INK], [sx - 7.0, 4.0, RED_HI]]:
			var x0: float = layer[0]
			var width: float = layer[1]
			_fill(PackedVector2Array([Vector2(x0, top + 2), Vector2(x0 + width, top + 2), Vector2(x0 + width + 24, top + 26), Vector2(x0 + 24, top + 26)]), layer[2])
	else:
		var cy := top + 14.0
		for wave in 3:
			var radius := 5.0 + wave * 4.0
			var start := sx + 18.0 + wave * 4.0
			view.draw_polyline(PackedVector2Array([Vector2(start, cy - radius), Vector2(start + radius * 0.5, cy - radius * 0.5), Vector2(start + radius * 0.5, cy + radius * 0.5), Vector2(start, cy + radius)]), PAPER, 2.4, true)
	view._draw_text(text, Vector2(sx + span.y + gap, top + 4.0 + 17 * 0.88), 17, RED_HI if muted else PAPER)


func _bubble(rect: Rect2, utterance: String, color: Color) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	_cham(x, y + 2, w, h, 3, INK)
	_plate(x, y, w, h, 3, PAPER)
	_poly(PackedVector2Array([Vector2(x - 1, y + 14), Vector2(x + 1, y + 14), Vector2(x + 1, y + 23), Vector2(x - 10, y + 23)]), INK)
	_poly(PackedVector2Array([Vector2(x - 1, y + 15 + INSET), Vector2(x + 1, y + 15 + INSET), Vector2(x + 1, y + 22), Vector2(x - 8 + INSET, y + 22)]), PAPER)
	var lines := utterance.split("\n").size()
	var block := (lines - 1) * 12 + 9
	var top := y + maxf(5, floorf((h - 2 - block) / 2.0))
	_text(utterance, (x + 7) * U, top * U, color, "left", color == MINT_INK)


func _button(rect: Rect2, variant: String, state: String, label: String, big: bool, chevron := false) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	if state == "disabled":
		_plate(x, y, w, h, 3, NIGHT2)
		_rect(x + 3, y + 2, w - 6, 1, Color(NIGHT4, 0.5))
		if big:
			_display(label, x + w / 2, y + floorf((h - 16) / 2), MIST, "center")
		else:
			_text(label, (x + w / 2) * U, (y + 4) * U, MIST, "center")
		return
	var v: Dictionary = BUTTON[variant]
	var lip := 3.0
	_cham(x, y, w, h, 3, INK)
	_cham(x + 1, y + 1, w - 2, h - 2, 2, v.lo)
	_cham(x + 1, y + 1, w - 2, h - 2 - lip, 2, v.face)
	_rect(x + 3, y + 1, w - 6, 1, v.hi)
	if big:
		_display(label, x + w / 2, y + floorf((h - lip - 16) / 2), v.text, "center")
	else:
		_text(label, (x + w / 2) * U, y * U + floorf(((h - lip) * U - 16) / 2) - 1, v.text, "center")
	if chevron:
		var cx := x + w - 12
		var cy := y + floorf((h - lip) / 2) - 3
		_diag(cx, cy, 4, 1, v.text, 2)
		_diag(cx + 2, cy + 4, 3, -1, v.text, 2)


# Foreman, 48 x 56 units of chamfered plates (0, 45 and 90 degree edges).
func _foreman(fx: float, fy0: float, p: Dictionary) -> void:
	var bob: float = p.bob
	var hop: float = p.hop
	var X := fx
	var Y := fy0 + bob + hop
	_plate(X + 6, Y + 38, 36, 18 - bob - hop, 6, VEST)
	_rect(X + 9, Y + 40, 2, 14, Color("#a8471a"))
	# The face and the shirt are symmetric about X + 24 (the head's centre);
	# the collar's arms end exactly on the tie.
	_diag(X + 18, Y + 39, 6, 1, SHIRT, 2)
	_diag(X + 28, Y + 39, 6, -1, SHIRT, 2)
	_rect(X + 22, Y + 45, 4, 9, SHIRT)
	_rect(X + 14, Y + 41, 2, 14, GOLD_HI)
	_rect(X + 32, Y + 41, 2, 14, GOLD_HI)
	_plate(X + 2, Y + 46, 6, 7, 2, SKIN)
	if p.thumb:
		_plate(X + 40, Y + 30, 7, 15, 2, VEST)
		_plate(X + 39, Y + 23, 9, 8, 2, SKIN)
		_plate(X + 42, Y + 17, 4, 7, 1, SKIN)
		_rect(X + 41, Y + 26, 6, 1, SKIN_LO)
	else:
		_plate(X + 40, Y + 46, 6, 7, 2, SKIN)
	_rect(X + 20, Y + 34, 8, 5, SKIN_LO)
	_plate(X + 7, Y + 21, 5, 7, 1, SKIN)
	_plate(X + 36, Y + 21, 5, 7, 1, SKIN)
	_plate(X + 10, Y + 12, 28, 25, 6, SKIN)
	_rect(X + 34, Y + 18, 2, 14, SKIN_LO)
	_plate(X + 9, Y + 1, 30, 15, 8, GOLD)
	_rect(X + 22.5, Y + 2, 3, 12, GOLD_LO)
	_diag(X + 13, Y + 6, 4, -1, GOLD_HI, 2)
	_rect(X + 17, Y + 3, 4, 1, GOLD_HI)
	_plate(X + 5, Y + 13, 38, 4, 1, GOLD_LO)
	_rect(X + 6, Y + 14, 36, 1, GOLD)
	match String(p.brows):
		"worry":
			_diag(X + 18.5, Y + 18, 4, -1, HAIR, 2)
			_diag(X + 27.5, Y + 18, 4, 1, HAIR, 2)
		"up":
			_rect(X + 14.5, Y + 18, 5, 1, HAIR)
			_rect(X + 28.5, Y + 18, 5, 1, HAIR)
		_:
			_rect(X + 14.5, Y + 19, 5, 1, HAIR)
			_rect(X + 28.5, Y + 19, 5, 1, HAIR)
	# Eyes are centred on X + 17 and X + 31 in every pose.
	if p.mouth == "smile" and not p.blink:
		# Closed happy eyes: one "^" each, its two arms joined at the top.
		for ex in [16.0, 30.0]:
			_diag(X + ex, Y + 21, 3, -1, INK)
			_diag(X + ex + 1, Y + 21, 3, 1, INK)
	elif p.blink:
		_rect(X + 15, Y + 23, 4, 1, INK)
		_rect(X + 29, Y + 23, 4, 1, INK)
	else:
		_rect(X + 15.5, Y + 21, 3, 4, INK)
		_rect(X + 29.5, Y + 21, 3, 4, INK)
		_rect(X + 15.5, Y + 21, 1, 1, WHITE)
		_rect(X + 29.5, Y + 21, 1, 1, WHITE)
	if p.mouth == "smile":
		_rect(X + 12, Y + 26, 3, 2, CHEEK)
		_rect(X + 33, Y + 26, 3, 2, CHEEK)
	_rect(X + 22.5, Y + 23, 3, 4, SKIN_LO)
	_cham(X + 15, Y + 27, 18, 4, 2, HAIR)
	_rect(X + 14, Y + 30, 2, 2, HAIR)
	_rect(X + 32, Y + 30, 2, 2, HAIR)
	match String(p.mouth):
		"talk":
			_rect(X + 21, Y + 31, 6, 3, INK)
			_rect(X + 22, Y + 32, 4, 1, RED_LO)
		"smile":
			_rect(X + 19, Y + 31, 10, 2, INK)
			_rect(X + 20, Y + 32, 8, 1, RED_LO)
			_rect(X + 18, Y + 30, 1, 1, INK)
			_rect(X + 29, Y + 30, 1, 1, INK)
		"worry":
			_rect(X + 21, Y + 32, 6, 1, INK)
			_rect(X + 20, Y + 33, 1, 1, INK)
			_rect(X + 27, Y + 33, 1, 1, INK)
		_:
			_rect(X + 21, Y + 32, 6, 1, SKIN_LO)


# ---- primitives (units in, design px out) ----------------------------------

static func _oct_points(x: float, y: float, w: float, h: float, k: float) -> PackedVector2Array:
	k = maxf(0.0, minf(k, minf(w * 0.5, h * 0.5)))
	return PackedVector2Array([Vector2(x + k, y), Vector2(x + w - k, y), Vector2(x + w, y + k), Vector2(x + w, y + h - k), Vector2(x + w - k, y + h), Vector2(x + k, y + h), Vector2(x, y + h - k), Vector2(x, y + k)])


static func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


# A 45-degree band, t wide horizontally: "\" for dx > 0, "/" for dx < 0.
static func _diag_points(x: float, y: float, n: float, dx: int, t: float = 1.0) -> PackedVector2Array:
	if dx > 0:
		return PackedVector2Array([Vector2(x, y), Vector2(x + t, y), Vector2(x + t + n, y + n), Vector2(x + n, y + n)])
	return PackedVector2Array([Vector2(x, y), Vector2(x + t, y), Vector2(x + t - n, y + n), Vector2(x - n, y + n)])


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	if w > 0 and h > 0:
		_poly(_rect_points(Rect2(x, y, w, h)), color)


func _cham(x: float, y: float, w: float, h: float, k: float, color: Color) -> void:
	if w > 0 and h > 0:
		_poly(_oct_points(x, y, w, h, k), color)


# Outline of uniform width d: the inner chamfer shrinks by d (2 - sqrt 2).
func _plate(x: float, y: float, w: float, h: float, k: float, fill: Color, line := INK, d := 1.0) -> void:
	_cham(x, y, w, h, k, line)
	_cham(x + d, y + d, w - 2 * d, h - 2 * d, maxf(0.0, k - d * INSET), fill)


func _diamond(cx: float, cy: float, r: float, color: Color) -> void:
	var c := Vector2(cx + 0.5, cy + 0.5)
	var q := r + 0.5
	_poly(PackedVector2Array([c + Vector2(0, -q), c + Vector2(q, 0), c + Vector2(0, q), c + Vector2(-q, 0)]), color)


func _diag(x: float, y: float, n: float, dx: float, color: Color, t := 1.0) -> void:
	if n > 0:
		_poly(_diag_points(x, y, n, int(dx), t), color)


func _poly(points: PackedVector2Array, color: Color) -> void:
	var out := PackedVector2Array()
	for point in points:
		var q := point * U
		if out.is_empty() or not out[-1].is_equal_approx(q):
			out.append(q)
	if out.size() > 1 and out[0].is_equal_approx(out[-1]):
		out.remove_at(out.size() - 1)
	_fill(out, color)


# Flat fill with a sub-pixel antialiased rim, as the title's dynamic shapes.
func _fill(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var area := 0.0
	for i in points.size():
		area += points[i].cross(points[(i + 1) % points.size()])
	if absf(area) < 0.001:
		return
	view.draw_colored_polygon(points, color)
	if color.a > 0.99:
		var loop := points.duplicate()
		loop.append(points[0])
		view.draw_polyline(loop, color, _aa, true)


# Straight 0/45/90-degree strokes, optionally dashed (lengths in units).
func _stroke(points: PackedVector2Array, color: Color, width: float, dash: Array = []) -> void:
	if points.size() < 2:
		return
	if dash.is_empty():
		view.draw_polyline(Transform2D.IDENTITY.scaled(Vector2(U, U)) * points, color, width * U, true)
		return
	var length := _length(points)
	var cursor := 0.0
	while cursor < length:
		var piece := _slice(points, cursor, minf(length, cursor + float(dash[0])))
		if piece.size() >= 2:
			view.draw_polyline(Transform2D.IDENTITY.scaled(Vector2(U, U)) * piece, color, width * U, true)
		cursor += float(dash[0]) + float(dash[1])


static func _length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


static func _point_at(points: PackedVector2Array, distance: float) -> Vector2:
	var travelled := 0.0
	for i in points.size() - 1:
		var step := points[i].distance_to(points[i + 1])
		if travelled + step >= distance and step > 0:
			return points[i].lerp(points[i + 1], (distance - travelled) / step)
		travelled += step
	return points[-1]


# The part of a polyline between two distances along it, corners included.
static func _slice(points: PackedVector2Array, start: float, finish: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if finish <= start:
		return result
	result.append(_point_at(points, start))
	var travelled := 0.0
	for i in range(1, points.size()):
		travelled += points[i - 1].distance_to(points[i])
		if travelled > start and travelled < finish:
			result.append(points[i])
	result.append(_point_at(points, finish))
	return result


# Body text: Regular 17 px (24 px lines); x and top in design px.
func _text(text: String, x: float, top: float, color: Color, align := "left", bold := false) -> void:
	var lines := text.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		var left: float = x - (view._text_width(line, 17, bold) * 0.5 if align == "center" else 0.0)
		view._draw_text(line, Vector2(left, top + 17 * 0.88 + i * 24), 17, color, bold)


# Display text: Bold 30 px at a top-left (or top-centre) point in units.
func _display(text: String, x: float, y: float, color: Color, align := "left") -> void:
	var left: float = x * U - (view._text_width(text, 30, true) * 0.5 if align == "center" else 0.0)
	view._draw_text(text, Vector2(left, (y + 15 * 0.88) * U), 30, color, true)
