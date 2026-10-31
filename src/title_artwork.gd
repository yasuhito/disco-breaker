class_name TitleArtwork
extends RefCounted

# Original title art in the flat 45-degree vector grammar: every non-text edge
# is horizontal, vertical or diagonal. Static surfaces become one mesh with a
# one-device-pixel antialiasing fringe. Mirror beams are single textured quads
# whose filtered cross-section keeps 45-degree edges smooth at any scale.
const Flicker := preload("res://src/fault_flicker.gd")

const INK := Color("#0d0a17")
const NIGHT0 := Color("#130e22")
const NIGHT1 := Color("#1b1430")
const NIGHT2 := Color("#251c3d")
const NIGHT3 := Color("#33284f")
const NIGHT4 := Color("#4b3d70")
const NIGHT5 := Color("#6c5c96")
const MIST := Color("#a89cc8")
const PAPER := Color("#f4ead8")
const RED := Color("#ef4760")
const RED_HI := Color("#ff9aa0")
const RED_LO := Color("#97213d")
const RED_DARK := Color("#4a1a2c")
const BLUE := Color("#3f9cff")
const BLUE_HI := Color("#a8dcff")
const BLUE_LO := Color("#1d4f9e")
const BLUE_DARK := Color("#1a2c52")
const GOLD_HI := Color("#ffe7a3")
const GOLD := Color("#f4b942")
const GOLD_LO := Color("#a5651f")
const PINK_HI := Color("#ffd0e4")
const PINK := Color("#f08fbd")
const PINK_LO := Color("#a9487a")

const TUTORIAL_RECT := Rect2(24, 744, 342, 62)
const REPAIR_RECT := Rect2(24, 648, 342, 66)
const MUTE_RECT := Rect2(290, 14, 76, 44)

const FASCIA_BOTTOM := 224.0
const BALL_CENTER := Vector2(195, 292)
const BALL_HALF := 54.0
const BALL_CHAMFER := 26.0
const BALL_RIM := 2.5
const BALL_ROWS := 9
const FACET_GAP := 0.6
const EMITTERS := 18
const PERIOD := 22.0
# Reduced motion holds a phase where every visible beam is at full strength.
const STILL_TIME := PERIOD / 36.0
const BEAM_HALF := 3.25
const BEAM_FADE := 5.0
const FLOOR_ROW0 := 394.0
const FLOOR_PITCH := Vector2(44, 22)
const FLOOR_FRONT := 632.0
const SPOT_HALF := Vector2(9, 4.5)
const VERTICAL_LANDINGS := [440.0, 500.0, 560.0, 470.0, 530.0]
const DIAGONAL_DROPS := [80.0, 104.0, 128.0, 152.0, 92.0]
const LIT_TILES := [[1, 3, "blue"], [6, 2, "red"], [3, 5, "red"], [7, 6, "blue"], [1, 8, "red"], [5, 9, "blue"]]

# 5 x 7 letter cells: F full, a/b/c/d the four 45-degree half cells.
const GLYPH := {
	"D": ["FFFFb", "F...F", "F...F", "F...F", "F...F", "F...F", "FFFFd"],
	"I": ["FFFFF", "..F..", "..F..", "..F..", "..F..", "..F..", "FFFFF"],
	"S": ["aFFFF", "F....", "F....", "cFFFb", "....F", "....F", "FFFFd"],
	"C": ["aFFFF", "F....", "F....", "F....", "F....", "F....", "cFFFF"],
	"O": ["aFFFb", "F...F", "F...F", "F...F", "F...F", "F...F", "cFFFd"],
	"B": ["FFFFb", "F...F", "F...d", "FFFF.", "F...b", "F...F", "FFFFd"],
	"R": ["FFFFb", "F...F", "F...d", "FFFF.", "F.Fb.", "F.cFb", "F..cF"],
	"E": ["FFFFF", "F....", "F....", "FFFF.", "F....", "F....", "FFFFF"],
	"A": ["aFFFb", "F...F", "F...F", "FFFFF", "F...F", "F...F", "F...F"],
	"K": ["F..aF", "F.aFd", "FaFd.", "FFd..", "FFb..", "FcFb.", "F.cFb"],
}
const CELL := 8.0

var _scale := 0.0
var _static_mesh: ArrayMesh
var _beam_texture: GradientTexture1D
var _spot_texture: ImageTexture
var _line_width := 0.5


# Device pixels per design pixel, including the browser's devicePixelRatio.
static func device_scale(view) -> float:
	return view.get_viewport().get_screen_transform().get_scale().x * view.get_global_transform_with_canvas().get_scale().x * view._scale


static func octagon(rect: Rect2, chamfer: float) -> PackedVector2Array:
	var k := minf(chamfer, minf(rect.size.x, rect.size.y) * 0.5)
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([Vector2(p.x + k, p.y), Vector2(e.x - k, p.y), Vector2(e.x, p.y + k), Vector2(e.x, e.y - k), Vector2(e.x - k, e.y), Vector2(p.x + k, e.y), Vector2(p.x, e.y - k), Vector2(p.x, p.y + k)])


static func diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])


static func rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


static func ball_outline() -> PackedVector2Array:
	return octagon(Rect2(BALL_CENTER - Vector2.ONE * BALL_HALF, Vector2.ONE * BALL_HALF * 2.0), BALL_CHAMFER)


static func ball_face() -> PackedVector2Array:
	# A uniform rim: the 45-degree chamfer shrinks by rim * (2 - sqrt 2).
	var half := BALL_HALF - BALL_RIM
	return octagon(Rect2(BALL_CENTER - Vector2.ONE * half, Vector2.ONE * half * 2.0), BALL_CHAMFER - BALL_RIM * (2.0 - sqrt(2.0)))


static func flat_bottom_half() -> float:
	return BALL_HALF - BALL_RIM - (BALL_CHAMFER - BALL_RIM * (2.0 - sqrt(2.0)))


static func row_span(row: int) -> Vector2:
	var top := BALL_CENTER.y - BALL_HALF + BALL_RIM
	var height := (BALL_HALF - BALL_RIM) * 2.0 / BALL_ROWS
	return Vector2(top + row * height, top + (row + 1) * height)


static func _row_radius(row: int) -> float:
	var span := row_span(row)
	var offset := absf((span.x + span.y) * 0.5 - BALL_CENTER.y)
	var flat := BALL_HALF - BALL_RIM - flat_bottom_half()
	return BALL_HALF - BALL_RIM - maxf(0.0, offset - (BALL_HALF - BALL_RIM - flat))


static func _row_count(row: int) -> int:
	if row == BALL_ROWS - 1:
		return EMITTERS
	return maxi(6, roundi(TAU * _row_radius(row) / 11.0))


static func _wrap(angle: float) -> float:
	return fposmod(angle + PI, TAU) - PI


static func _rotation(time: float) -> float:
	return time * TAU / PERIOD


# Every visible mirror facet for one moment: fixed material tiles on rotating
# latitude rows. Facets compress toward the silhouette and clip to the face.
static func facets(time: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var face := ball_face()
	var turn := _rotation(time)
	for row in BALL_ROWS:
		var count := _row_count(row)
		var radius := _row_radius(row)
		var step := TAU / count
		var span := row_span(row)
		for index in count:
			var stagger := 0.5 * (row % 2) if row != BALL_ROWS - 1 else 0.0
			var start := _wrap((index + stagger) * step + turn - step * 0.5)
			var finish := start + step
			var low := maxf(start, -PI * 0.5)
			var high := minf(finish, PI * 0.5)
			if high <= low:
				continue
			var left := BALL_CENTER.x + radius * sin(low) + FACET_GAP
			var right := BALL_CENTER.x + radius * sin(high) - FACET_GAP
			if right - left < 0.25:
				continue
			var rect := Rect2(left, span.x + FACET_GAP, right - left, span.y - span.x - FACET_GAP * 2.0)
			var clipped := Geometry2D.intersect_polygons(rect_points(rect), face)
			if clipped.is_empty():
				continue
			result.append({"row": row, "index": index, "rect": rect, "polygon": clipped[0], "shade": cos((low + high) * 0.5)})
	return result


# Beams belong to the bottom ring, whose facets slide along the octagon's flat
# underside. Each one leaves its facet's lower edge at a fixed 90 or 45 degree
# heading and lands on the floor; the pair translates rigidly with the facet.
static func beams(time: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var radius := _row_radius(BALL_ROWS - 1)
	var limit := flat_bottom_half() - BEAM_HALF - 2.0
	var origin_y := row_span(BALL_ROWS - 1).y - FACET_GAP
	for index in EMITTERS:
		var angle := _wrap(index * TAU / EMITTERS + _rotation(time))
		var x := BALL_CENTER.x + radius * sin(angle)
		var offset := absf(x - BALL_CENTER.x)
		if cos(angle) <= 0.0 or offset > limit:
			continue
		var heading := [0, -1, 1][index % 3] as int
		var group := int(index / 3.0) % 5
		var origin := Vector2(x, origin_y)
		var landing := Vector2(x, VERTICAL_LANDINGS[group])
		if heading != 0:
			var drop: float = DIAGONAL_DROPS[group]
			landing = origin + Vector2(heading * drop, drop)
		result.append({
			"facet": index, "heading": heading, "origin": origin, "landing": landing,
			"tint": [PINK_HI, BLUE_HI, GOLD_HI][(index * 2 + group) % 3],
			"strength": 1.0 - smoothstep(limit - BEAM_FADE, limit, offset),
		})
	return result


static func beam_polygon(beam: Dictionary) -> PackedVector2Array:
	var origin: Vector2 = beam.origin
	var landing: Vector2 = beam.landing
	var half := Vector2(BEAM_HALF, 0)
	return PackedVector2Array([origin - half, origin + half, landing + half, landing - half])


static func spot_polygon(center: Vector2) -> PackedVector2Array:
	var h := SPOT_HALF
	return PackedVector2Array([center + Vector2(-h.x, 0), center + Vector2(-h.y, -h.y), center + Vector2(h.y, -h.y), center + Vector2(h.x, 0), center + Vector2(h.y, h.y), center + Vector2(-h.y, h.y)])


static func tile_center(column: int, row: int) -> Vector2:
	return Vector2(8 + column * FLOOR_PITCH.x + (FLOOR_PITCH.y if row % 2 else 0.0), FLOOR_ROW0 + row * FLOOR_PITCH.y)


func draw(view, elapsed: float, reduced: bool, _started: bool, _finished: bool) -> void:
	var time := STILL_TIME if reduced else elapsed
	_ensure_resources(view)
	view.draw_mesh(_static_mesh, null)
	_draw_lit_tiles(view, time, reduced)
	var active := beams(time)
	for beam in active:
		view.draw_texture_rect(_spot_texture, Rect2(beam.landing - SPOT_HALF, SPOT_HALF * 2.0), false, Color(beam.tint, beam.strength * 0.9))
	_draw_ball(view, time, active)
	for beam in active:
		view.draw_polygon(beam_polygon(beam), PackedColorArray([Color(beam.tint, beam.strength * 0.88)]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), _beam_texture)
	_draw_labels(view)
	_draw_mute(view, view._muted)


func _ensure_resources(view) -> void:
	var scale := device_scale(view)
	if absf(scale - _scale) < 0.01 and _static_mesh != null:
		return
	_scale = scale
	_line_width = 0.5 / scale
	_static_mesh = _build_static_mesh(1.0 / scale)
	_beam_texture = _build_beam_texture(scale)
	_spot_texture = _build_spot_texture(scale)


func _fill(view, points: PackedVector2Array, color: Color) -> void:
	view.draw_colored_polygon(points, color)
	var loop := points.duplicate()
	loop.append(points[0])
	view.draw_polyline(loop, color, _line_width, true)


func _draw_lit_tiles(view, time: float, reduced: bool) -> void:
	for tile in LIT_TILES:
		var center := tile_center(tile[0], tile[1])
		var red: bool = tile[2] == "red"
		var level := Flicker.brightness(8000 + tile[1] * 11 + tile[0] * 71, time, reduced)
		if level >= 0.6:
			_fill(view, diamond(center, 20.5), RED if red else BLUE)
		elif level >= 0.2:
			_fill(view, diamond(center, 20.5), RED_LO if red else BLUE_LO)
		else:
			# A dropped lamp keeps a coloured perimeter, as in the lessons.
			_fill(view, diamond(center, 20.5), RED_DARK if red else BLUE_DARK)
			_fill(view, diamond(center, 18.0), Color("#221a38"))


func _draw_ball(view, time: float, active: Array[Dictionary]) -> void:
	_fill(view, ball_outline(), INK)
	view.draw_colored_polygon(ball_face(), Color("#211938"))
	var emitting := {}
	for beam in active:
		emitting[beam.facet] = beam
	var light := BALL_CENTER + Vector2(-18, -27)
	for facet in facets(time):
		var row: int = facet.row
		var shade := clampf(facet.shade, 0.0, 1.0)
		var color := NIGHT4.lerp(Color("#b9b4dc"), pow(shade, 0.8))
		if row < 2:
			color = NIGHT5.lerp(Color("#d7d3f0"), pow(shade, 0.8))
		elif row > 6:
			color = NIGHT3.lerp(NIGHT5, pow(shade, 0.8))
		var facet_hash := posmod(int(facet.index) * 7 + row * 13, 11)
		if row > 1 and row < 7 and (facet_hash == 4 or facet_hash == 7):
			color = color.lerp(BLUE_HI if facet_hash == 4 else PINK_HI, 0.65 * shade)
		# A fixed key light: facets brighten smoothly as they turn through it.
		var rect: Rect2 = facet.rect
		var glint := clampf(1.0 - rect.get_center().distance_to(light) / 17.0, 0.0, 1.0)
		color = color.lerp(Color("#fffaf0"), glint * 0.9)
		if row == BALL_ROWS - 1 and emitting.has(facet.index):
			var beam: Dictionary = emitting[facet.index]
			color = color.lerp(Color(beam.tint).lerp(Color.WHITE, 0.45), beam.strength)
		_fill(view, facet.polygon, color)


func _draw_labels(view) -> void:
	var label := "スタート"
	var sub := "準備中"
	view._draw_text(label, Vector2(195 - view._text_width(label, 30, true) * 0.5, 682), 30, MIST, true)
	view._draw_text(sub, Vector2(195 - view._text_width(sub, 17) * 0.5, 704), 17, GOLD)
	label = "チュートリアル"
	# Japanese glyphs centre roughly 0.38 em above the baseline.
	var face_center := TUTORIAL_RECT.position.y + 2 + (TUTORIAL_RECT.size.y - 10) * 0.5
	view._draw_text(label, Vector2(195 - view._text_width(label, 30, true) * 0.5, roundf(face_center + 30 * 0.38)), 30, INK, true)


func _draw_mute(view, muted: bool) -> void:
	var text := "OFF" if muted else "ON"
	var text_color := RED_HI if muted else PAPER
	# Horizontal extent of each icon relative to the speaker's left edge.
	var icon := Vector2(-4.0, 15.0) if muted else Vector2(0.0, 26.0)
	var text_width: float = view._text_width(text, 13, true)
	var gap := 6.0
	var face := Rect2(MUTE_RECT.position + Vector2(2, 2), Vector2(MUTE_RECT.size.x - 4, MUTE_RECT.size.y - 8))
	# The icon and measured label are centred together inside the cap.
	var group := icon.y - icon.x + gap + text_width
	var sx := roundf(face.get_center().x - group * 0.5 - icon.x)
	var cy := face.get_center().y
	# Speaker: a body and a 45-degree cone.
	_fill(view, rect_points(Rect2(sx, cy - 5, 5, 10)), PAPER)
	_fill(view, PackedVector2Array([Vector2(sx + 5, cy - 5), Vector2(sx + 11, cy - 11), Vector2(sx + 11, cy + 11), Vector2(sx + 5, cy + 5)]), PAPER)
	if muted:
		# A single 45-degree slash through the speaker, with an ink keyline.
		var from := Vector2(sx - 3.5, cy - 9)
		var to := Vector2(sx + 14.5, cy + 9)
		view.draw_line(from, to, INK, 4.5, true)
		view.draw_line(from, to, RED_HI, 2.2, true)
	else:
		# Three angular waves: 45-degree, vertical, 45-degree brackets.
		for wave in 3:
			var radius := 3.0 + wave * 3.0
			var vertical := sx + 16.0 + wave * 4.5
			var start := vertical - radius * 0.5
			view.draw_polyline(PackedVector2Array([Vector2(start, cy - radius), Vector2(vertical, cy - radius * 0.5), Vector2(vertical, cy + radius * 0.5), Vector2(start, cy + radius)]), PAPER, 1.8, true)
	view._draw_text(text, Vector2(sx + icon.y + gap, roundf(cy + 13 * 0.37)), 13, text_color, true)


# --- static mesh -----------------------------------------------------------

class MeshBuilder:
	extends RefCounted
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var fringe := 1.0

	func triangle(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
		vertices.append_array(PackedVector2Array([a, b, c]))
		colors.append_array(PackedColorArray([ca, cb, cc]))

	# A convex polygon plus an outward alpha fringe on every edge and corner.
	func convex(points: PackedVector2Array, color: Color) -> void:
		if points.size() < 3:
			return
		for i in range(1, points.size() - 1):
			triangle(points[0], points[i], points[i + 1], color, color, color)
		var clear := Color(color, 0.0)
		var count := points.size()
		var normals: Array[Vector2] = []
		for i in count:
			var edge := (points[(i + 1) % count] - points[i]).normalized()
			var normal := Vector2(edge.y, -edge.x)
			var middle := (points[i] + points[(i + 1) % count]) * 0.5
			if Geometry2D.is_point_in_polygon(middle + normal * 0.01, points):
				normal = -normal
			normals.append(normal)
		for i in count:
			var a := points[i]
			var b := points[(i + 1) % count]
			var n: Vector2 = normals[i] * fringe
			triangle(a, b, b + n, color, color, clear)
			triangle(a, b + n, a + n, color, clear, clear)
			var previous: Vector2 = normals[(i - 1 + count) % count] * fringe
			triangle(a, a + previous, a + n, color, clear, clear)

	func build() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


func _build_static_mesh(fringe: float) -> ArrayMesh:
	var mesh := MeshBuilder.new()
	mesh.fringe = fringe
	_static_shapes(mesh)
	return mesh.build()


# Records every static shape. Tests replay this into a probe to audit angles.
func _static_shapes(mesh) -> void:
	# Ceiling fascia carrying the sign, its rail, the back wall and the floor.
	mesh.convex(rect_points(Rect2(0, 0, 390, FASCIA_BOTTOM)), NIGHT0)
	mesh.convex(rect_points(Rect2(0, FASCIA_BOTTOM, 390, 2)), INK)
	mesh.convex(rect_points(Rect2(0, FASCIA_BOTTOM + 2, 390, 4)), NIGHT3)
	mesh.convex(rect_points(Rect2(0, FASCIA_BOTTOM + 6, 390, 2)), INK)
	mesh.convex(rect_points(Rect2(0, FASCIA_BOTTOM + 8, 390, FLOOR_FRONT - FASCIA_BOTTOM - 8)), NIGHT1)
	var depth_colors := [NIGHT2, Color("#2a2145"), NIGHT3, Color("#3a2e5a")]
	for row in 12:
		for column in range(-1, 10):
			mesh.convex(diamond(tile_center(column, row), FLOOR_PITCH.y), INK)
	for row in 12:
		var depth := mini(3, int(row / 3.0))
		for column in range(-1, 10):
			var center := tile_center(column, row)
			# Plain flat glass; only colour separates lit from unlit tiles.
			mesh.convex(diamond(center, 20.5), depth_colors[depth])
	mesh.convex(rect_points(Rect2(0, FLOOR_FRONT, 390, 844 - FLOOR_FRONT)), NIGHT0)
	mesh.convex(rect_points(Rect2(0, FLOOR_FRONT, 390, 3)), INK)
	mesh.convex(rect_points(Rect2(0, FLOOR_FRONT + 3, 390, 2)), NIGHT2)
	# Cord and cap from the rail to the ball.
	mesh.convex(rect_points(Rect2(194, FASCIA_BOTTOM + 8, 2, BALL_CENTER.y - BALL_HALF - FASCIA_BOTTOM - 8)), NIGHT4)
	mesh.convex(octagon(Rect2(189, BALL_CENTER.y - BALL_HALF - 5, 12, 6), 2), NIGHT5)
	_wordmark(mesh, "DISCO", 70.0, [Color("#eef6ff"), Color("#a9c6e6"), Color("#6b86b0")])
	_wordmark(mesh, "BREAKER", 140.0, [GOLD_HI, GOLD, GOLD_LO])
	# Disabled campaign: a flat plate without a raised lip.
	mesh.convex(octagon(REPAIR_RECT, 6), INK)
	mesh.convex(octagon(REPAIR_RECT.grow(-2), 6 - 2 * (2 - sqrt(2.0))), NIGHT2)
	mesh.convex(rect_points(Rect2(REPAIR_RECT.position.x + 8, REPAIR_RECT.position.y + 2, REPAIR_RECT.size.x - 16, 2)), NIGHT3)
	# Tutorial: pink cap over a darker lip, with a flat top highlight.
	mesh.convex(octagon(TUTORIAL_RECT, 6), INK)
	var inner := TUTORIAL_RECT.grow(-2)
	mesh.convex(octagon(inner, 6 - 2 * (2 - sqrt(2.0))), PINK_LO)
	mesh.convex(octagon(Rect2(inner.position, inner.size - Vector2(0, 6)), 6 - 2 * (2 - sqrt(2.0))), PINK)
	mesh.convex(rect_points(Rect2(inner.position.x + 6, inner.position.y, inner.size.x - 12, 2)), PINK_HI)
	# Audio control plate; its icon and label are drawn per state.
	mesh.convex(octagon(MUTE_RECT, 6), INK)
	mesh.convex(octagon(Rect2(MUTE_RECT.position + Vector2(2, 2), MUTE_RECT.size - Vector2(4, 8)), 6 - 2 * (2 - sqrt(2.0))), NIGHT3)
	mesh.convex(rect_points(Rect2(MUTE_RECT.position.x + 7, MUTE_RECT.position.y + 2, MUTE_RECT.size.x - 14, 2)), NIGHT4)


static func _cells(word: String, top: float) -> Array[PackedVector2Array]:
	var cells: Array[PackedVector2Array] = []
	var x := 195.0 - (word.length() * 6 - 1) * CELL * 0.5
	for letter in word:
		var rows: Array = GLYPH[letter]
		for row in rows.size():
			var line: String = rows[row]
			for column in line.length():
				var p := Vector2(x + column * CELL, top + row * CELL)
				var c := CELL
				match line[column]:
					"F":
						cells.append(PackedVector2Array([p, p + Vector2(c, 0), p + Vector2(c, c), p + Vector2(0, c)]))
					"a":
						cells.append(PackedVector2Array([p + Vector2(c, 0), p + Vector2(c, c), p + Vector2(0, c)]))
					"b":
						cells.append(PackedVector2Array([p, p + Vector2(c, c), p + Vector2(0, c)]))
					"c":
						cells.append(PackedVector2Array([p, p + Vector2(c, 0), p + Vector2(c, c)]))
					"d":
						cells.append(PackedVector2Array([p, p + Vector2(c, 0), p + Vector2(0, c)]))
		x += 6 * CELL
	return cells


# Minkowski sum with a regular octagon keeps grown edges at 0/45/90/135 and
# gives the outline one thickness on straight and diagonal sides.
static func _grow(cell: PackedVector2Array, radius: float, offset: Vector2) -> PackedVector2Array:
	var t := radius * tan(PI / 8.0)
	var points := PackedVector2Array()
	for p in cell:
		for o in [Vector2(radius, t), Vector2(t, radius), Vector2(-t, radius), Vector2(-radius, t), Vector2(-radius, -t), Vector2(-t, -radius), Vector2(t, -radius), Vector2(radius, -t)]:
			points.append(p + o + offset)
	var hull := Geometry2D.convex_hull(points)
	hull.remove_at(hull.size() - 1)
	return _simplify(hull)


static func _simplify(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count := points.size()
	for i in count:
		var a := points[(i - 1 + count) % count]
		var b := points[i]
		var c := points[(i + 1) % count]
		if absf((b - a).cross(c - b)) > 0.0001:
			result.append(b)
	return result


func _wordmark(mesh, word: String, top: float, bands: Array) -> void:
	var cells := _cells(word, top)
	for cell in cells:
		mesh.convex(_grow(cell, 4, Vector2(4, 4)), Color("#06040c"))
	for cell in cells:
		mesh.convex(_grow(cell, 4, Vector2.ZERO), INK)
	# Three flat bands, split on horizontal lines across the 2 px dilation.
	var span := 7 * CELL + 4
	var limits := [top - 2, top - 2 + span * 0.36, top - 2 + span * 0.7, top + 7 * CELL + 2]
	for cell in cells:
		var grown := _grow(cell, 2, Vector2.ZERO)
		for band in 3:
			var strip := rect_points(Rect2(0, limits[band], 390, limits[band + 1] - limits[band]))
			for part in Geometry2D.intersect_polygons(grown, strip):
				mesh.convex(_simplify(part), bands[band])


func _build_beam_texture(scale: float) -> GradientTexture1D:
	# Flat feather and core plateaus with one-device-pixel ramps; filtering
	# turns the quad's diagonal sides into smooth, continuous straight edges.
	var device_width := BEAM_HALF * 2.0 * scale
	var ramp := 1.0 / device_width
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, ramp, 0.33 - ramp * 0.5, 0.33 + ramp * 0.5, 0.67 - ramp * 0.5, 0.67 + ramp * 0.5, 1.0 - ramp, 1.0])
	var feather := Color(1, 1, 1, 0.3)
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), feather, feather, Color.WHITE, Color.WHITE, feather, feather, Color(1, 1, 1, 0)])
	var texture := GradientTexture1D.new()
	texture.width = clampi(ceili(device_width * 4.0), 32, 512)
	texture.gradient = gradient
	return texture


func _build_spot_texture(scale: float) -> ImageTexture:
	# A flattened landing patch with 45-degree sides, rasterised once per
	# device scale with 4 x 4 supersampling.
	var size := Vector2i(ceili(SPOT_HALF.x * 2.0 * scale), ceili(SPOT_HALF.y * 2.0 * scale))
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var alpha := 0.0
			for sy in 4:
				for sx in 4:
					var u := ((x + (sx + 0.5) / 4.0) / size.x * 2.0 - 1.0) * SPOT_HALF.x
					var v := ((y + (sy + 0.5) / 4.0) / size.y * 2.0 - 1.0) * SPOT_HALF.y
					if absf(u) + absf(v) <= SPOT_HALF.y and absf(v) <= SPOT_HALF.y * 0.5:
						alpha += 1.0
					elif absf(u) + absf(v) <= SPOT_HALF.x and absf(v) <= SPOT_HALF.y:
						alpha += 0.5
			image.set_pixel(x, y, Color(1, 1, 1, alpha / 16.0))
	return ImageTexture.create_from_image(image)
