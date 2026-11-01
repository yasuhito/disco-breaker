class_name TitleArtwork
extends RefCounted

# Original title art in the flat 45-degree vector grammar. The layout follows
# the approved title mock (390 x 844 design px = 2 x its 195 x 422 units).
# Every non-text edge is horizontal, vertical or diagonal. Static surfaces are
# meshes with a one-device-pixel antialiasing fringe; mirror rays are single
# textured quads whose filtered cross-section stays smooth at any scale.
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

# Plates where the mock puts them; each title plate is exactly its hit area.
const TUTORIAL_RECT := Rect2(28, 752, 332, 60)
const REPAIR_RECT := Rect2(28, 660, 332, 72)
const MUTE_RECT := Rect2(294, 16, 80, 44)
const CENTER_X := 194.0

const BALL_CENTER := Vector2(194, 108)
const BALL_HALF := 44.0
const BALL_CHAMFER := 26.0
const BALL_ROWS := 11
const SEAM := 2.0
const PERIOD := 22.0
const BEAM_HALF := 2.75
const STAR_POINTS := [Vector2(36, 60), Vector2(340, 104), Vector2(60, 236), Vector2(352, 280), Vector2(24, 344), Vector2(300, 44)]
const FLOOR_ROW0 := 381.0
const FLOOR_FRONT := 636.0
const LIT_TILES := [[3, 2, "red"], [6, 3, "blue"], [8, 5, "red"], [4, 6, "blue"], [1, 4, "blue"], [9, 2, "red"]]
const DISCO_TOP := Vector2(78, 188)
const BREAKER_TOP := Vector2(30, 260)
# Rays keep clear of the sign, the audio control, the cord and the floor.
const OBSTACLES := [Rect2(74, 184, 248, 68), Rect2(26, 256, 344, 72), Rect2(290, 12, 88, 52), Rect2(186, 0, 16, 60), Rect2(0, 356, 390, 488)]
const END_FADE := 0.28
const LOGO_RECT := Rect2(16, 176, 360, 156)
# Emitting rows and their headings (x is mirrored to the facet's side): the
# top mirrors throw light up, the middle and lower ones sideways, and the
# underside straight down behind the sign.
const EMIT_ROWS := {0: Vector2(1, -1), 2: Vector2(1, -1), 4: Vector2(1, 0), 6: Vector2(1, 0), 8: Vector2(1, 0), 10: Vector2(0, 1)}
const EMIT_EVERY := 4

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
# Reduced motion holds a phase showing up, sideways and down rays at full strength.
const STILL_TIME := 0.9

static var _hidden_span := Vector2(-1, -1)
var _scale := 0.0
var _back_mesh: ArrayMesh
var _logo_texture_cache: ImageTexture
var _beam_texture: GradientTexture1D
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


static func _half_width(y: float) -> float:
	return BALL_HALF - maxf(0.0, absf(y - BALL_CENTER.y) - (BALL_HALF - BALL_CHAMFER))


# Rows are flush with the silhouette: seams only separate neighbouring rows.
static func row_span(row: int) -> Vector2:
	var height := (BALL_HALF * 2.0 - SEAM * (BALL_ROWS - 1)) / BALL_ROWS
	var top := BALL_CENTER.y - BALL_HALF + row * (height + SEAM)
	return Vector2(top, top + height)


static func _row_radius(row: int) -> float:
	var span := row_span(row)
	var nearest := clampf(BALL_CENTER.y, span.x, span.y)
	return _half_width(nearest)


static func _row_count(row: int) -> int:
	return maxi(8, roundi(TAU * _row_radius(row) / 8.0))


static func _wrap(angle: float) -> float:
	return fposmod(angle + PI, TAU) - PI


static func _rotation(time: float) -> float:
	return time * TAU / PERIOD


# Mirror tiles on rotating latitude rows. Tiles and their seams compress
# toward the limb, so the silhouette is made of mirrors, not a frame.
static func facets(time: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var outline := ball_outline()
	var turn := _rotation(time)
	for row in BALL_ROWS:
		var count := _row_count(row)
		# Slightly past the silhouette, so the clipped edge is always mirror.
		var radius := _row_radius(row) + 1.0
		var step := TAU / count
		var span := row_span(row)
		for index in count:
			var start := _wrap((index + 0.5 * (row % 2)) * step + turn - step * 0.5)
			var low := maxf(start, -PI * 0.5)
			var high := minf(start + step, PI * 0.5)
			if high <= low:
				continue
			# Seams thin out faster than the mirrors, so the limb stays bright.
			var left := BALL_CENTER.x + radius * sin(low) + SEAM * 0.5 * pow(cos(low), 2)
			var right := BALL_CENTER.x + radius * sin(high) - SEAM * 0.5 * pow(cos(high), 2)
			if right - left < 0.2:
				continue
			var rect := Rect2(left, span.x, right - left, span.y - span.x)
			var clipped := Geometry2D.intersect_polygons(rect_points(rect), outline)
			if clipped.is_empty():
				continue
			var polygon: PackedVector2Array = clipped[0]
			# Area centroid: moves continuously as clipping adds corners.
			var center := Vector2.ZERO
			var area := 0.0
			for i in range(1, polygon.size() - 1):
				var part := absf((polygon[i] - polygon[0]).cross(polygon[i + 1] - polygon[0])) * 0.5
				center += (polygon[0] + polygon[i] + polygon[i + 1]) / 3.0 * part
				area += part
			# Sub-pixel crumbs at chamfer corners are invisible and degenerate.
			if area < 0.05:
				continue
			result.append({"row": row, "index": index, "key": row * 100 + index, "rect": rect, "polygon": polygon, "center": center / area, "shade": cos((low + high) * 0.5)})
	return result


static func _exit_length(origin: Vector2, direction: Vector2, polygon: PackedVector2Array) -> float:
	var best := INF
	for i in polygon.size():
		var hit = Geometry2D.segment_intersects_segment(origin, origin + direction * 400.0, polygon[i], polygon[(i + 1) % polygon.size()])
		if hit != null:
			best = minf(best, origin.distance_to(hit))
	return best


static func _segment_rect_distance(a: Vector2, b: Vector2, rect: Rect2) -> float:
	var corners := rect_points(rect)
	if rect.has_point(a) or rect.has_point(b):
		return 0.0
	var best := INF
	for i in 4:
		var c := corners[i]
		var d := corners[(i + 1) % 4]
		if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
			return 0.0
		best = minf(best, c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)))
	for p in [a, b]:
		best = minf(best, p.distance_to(Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))))
	return best


# Rays leave visible facets near the silhouette, heading outward at a fixed
# 0/45/90-degree angle chosen from the facet's position and a per-mirror tilt.
# Headings change only at zero strength. A ray either runs clear to a scene
# edge, fading with distance, or (straight down) ends behind the solid sign.
static func beams(time: float, visible: Array[Dictionary] = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var outline := ball_outline()
	var hidden := _hidden_columns()
	for facet in (visible if not visible.is_empty() else facets(time)):
		var row: int = facet.row
		var index: int = facet.index
		if not EMIT_ROWS.has(row) or posmod(index + row, EMIT_EVERY) != 0:
			continue
		var origin: Vector2 = facet.center
		var radial: Vector2 = origin - BALL_CENTER
		var side := signf(radial.x)
		var heading: Vector2 = EMIT_ROWS[row] * Vector2(side, 1)
		if EMIT_ROWS[row] == Vector2(0, 1):
			heading = Vector2(0, 1)
		var direction := heading.normalized()
		# Side-facing mirrors switch sides only at zero strength.
		var strength := 1.0 if heading.x == 0.0 else smoothstep(3.0, 9.0, absf(radial.x))
		strength *= smoothstep(0.2, 0.45, direction.dot(radial.normalized()))
		var inside := _exit_length(origin, direction, outline)
		strength *= 1.0 - smoothstep(6.0, 12.0, inside)
		var polygon: PackedVector2Array = facet.polygon
		var low := INF
		var high := -INF
		for point in polygon:
			low = minf(low, point.x)
			high = maxf(high, point.x)
		strength *= smoothstep(1.0, 3.5, high - low)
		if strength < 0.004:
			continue
		var finish := Vector2.ZERO
		var behind_sign := heading == Vector2(0, 1)
		if behind_sign:
			# Straight down into the sign's solid top bar: the sign hides the end.
			strength *= smoothstep(hidden.x, hidden.x + 4.0, origin.x) * (1.0 - smoothstep(hidden.y - 4.0, hidden.y, origin.x))
			finish = Vector2(origin.x, OBSTACLES[0].position.y + 12.0)
		else:
			var reach := INF
			for axis in 2:
				if direction[axis] > 0.0:
					reach = minf(reach, ([390.0, 844.0][axis] - origin[axis]) / direction[axis])
				elif direction[axis] < 0.0:
					reach = minf(reach, -origin[axis] / direction[axis])
			finish = origin + direction * reach
			var clearance := INF
			for obstacle in OBSTACLES:
				clearance = minf(clearance, _segment_rect_distance(origin, finish, obstacle))
			strength *= smoothstep(3.0, 10.0, clearance)
		if strength < 0.004:
			continue
		result.append({
			"key": facet.key, "row": row, "heading": heading, "origin": origin, "end": finish,
			"behind_sign": behind_sign, "strength": strength,
			"tint": [PINK_HI, BLUE_HI, GOLD_HI][posmod(index * 2 + row, 3)],
		})
	return result


# Horizontal span where a straight-down ray of full width meets at least 10 px
# of uninterrupted sign directly below the sign's top edge.
static func _hidden_columns() -> Vector2:
	if _hidden_span.x >= 0.0:
		return _hidden_span
	var pieces: Array[PackedVector2Array] = []
	var probe := ShapeLog.new()
	_logo_shapes(probe)
	pieces = probe.shapes
	var top := OBSTACLES[0].position.y
	var solid: Array[bool] = []
	for x in range(0, 390):
		var covered := true
		for y in range(int(top) + 1, int(top) + 14):
			var hit := false
			for piece in pieces:
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), piece):
					hit = true
					break
			if not hit:
				covered = false
				break
		solid.append(covered)
	# The widest solid run under the ball's underside.
	var best := Vector2(-1, -1)
	var start := -1
	for x in range(0, 391):
		var ok := x < 390 and solid[x]
		if ok and start < 0:
			start = x
		if not ok and start >= 0:
			var run := Vector2(start + BEAM_HALF + 1.0, x - BEAM_HALF - 1.0)
			if run.x <= BALL_CENTER.x and run.y >= BALL_CENTER.x and run.y - run.x > best.y - best.x:
				best = run
			start = -1
	_hidden_span = best
	return best


static func beam_polygon(beam: Dictionary) -> PackedVector2Array:
	var heading: Vector2 = beam.heading
	# Straight rays offset across their heading; diagonal rays keep a level
	# cap, widened by sqrt 2 so every ray has the same perpendicular width.
	var offset := Vector2(0, BEAM_HALF) if heading.y == 0.0 else Vector2(BEAM_HALF * (1.0 if heading.x == 0.0 else sqrt(2.0)), 0)
	var origin: Vector2 = beam.origin
	var finish: Vector2 = beam.end
	return PackedVector2Array([origin - offset, origin + offset, finish + offset, finish - offset])


static func tile_center(column: int, row: int) -> Vector2:
	return Vector2(9 + column * 44 + (22.0 if row % 2 else 0.0), FLOOR_ROW0 + row * 22)


func draw(view, elapsed: float, reduced: bool, _started: bool, _finished: bool) -> void:
	var time := STILL_TIME if reduced else elapsed
	_ensure_resources(view)
	view.draw_mesh(_back_mesh, null)
	_draw_lit_tiles(view, time, reduced)
	var mirrors := facets(time)
	var active := beams(time, mirrors)
	_draw_ball(view, mirrors, active)
	for beam in active:
		var fade := 1.0 if beam.behind_sign else END_FADE
		var near := Color(beam.tint, beam.strength * 0.9)
		var far := Color(beam.tint, beam.strength * 0.9 * fade)
		view.draw_polygon(beam_polygon(beam), PackedColorArray([near, near, far, far]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), _beam_texture)
	# The sign stands in front of the ball and its rays.
	view.draw_texture_rect(_logo_texture_cache, LOGO_RECT, false)
	_draw_labels(view)
	_draw_mute(view, view._muted)


func _ensure_resources(view) -> void:
	var scale := device_scale(view)
	if absf(scale - _scale) < 0.01 and _back_mesh != null:
		return
	_scale = scale
	_line_width = 0.5 / scale
	var back := MeshBuilder.new()
	back.fringe = 1.0 / scale
	_background_shapes(back)
	_back_mesh = back.build()
	_logo_texture_cache = _logo_texture(scale)
	_beam_texture = _build_beam_texture(scale)


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
		var color := (RED if red else BLUE) if level >= 0.6 else ((RED_LO if red else BLUE_LO) if level >= 0.2 else (RED_DARK if red else BLUE_DARK))
		_fill(view, diamond(center, 19.0), color)


func _draw_ball(view, mirrors: Array[Dictionary], active: Array[Dictionary]) -> void:
	# Seams between mirrors; inset so no backing shows past the mirrors.
	var inset := octagon(Rect2(BALL_CENTER - Vector2.ONE * (BALL_HALF - 0.6), Vector2.ONE * (BALL_HALF - 0.6) * 2.0), BALL_CHAMFER - 0.6 * (2.0 - sqrt(2.0)))
	view.draw_colored_polygon(inset, NIGHT3)
	var emitting := {}
	for beam in active:
		emitting[beam.key] = beam
	var light := BALL_CENTER + Vector2(-16, -24)
	for facet in mirrors:
		var row: int = facet.row
		var shade := clampf(facet.shade, 0.0, 1.0)
		var color := NIGHT4.lerp(Color("#b9b4dc"), pow(shade, 0.7))
		if row < 3:
			color = NIGHT5.lerp(Color("#d7d3f0"), pow(shade, 0.7))
		elif row > 8:
			color = NIGHT3.lerp(NIGHT5, pow(shade, 0.7))
		var facet_hash := posmod(int(facet.index) * 7 + row * 13, 11)
		if facet_hash == 4:
			color = color.lerp(BLUE_HI, 0.7 * shade)
		elif facet_hash == 7 and row > 3:
			color = color.lerp(PINK_HI, 0.7 * shade)
		# A fixed key light: mirrors brighten smoothly as they turn through it.
		var glint := clampf(1.0 - Vector2(facet.center).distance_to(light) / 15.0, 0.0, 1.0)
		color = color.lerp(Color("#fffaf0"), glint * 0.9)
		if emitting.has(facet.key):
			var beam: Dictionary = emitting[facet.key]
			color = color.lerp(Color(beam.tint).lerp(Color.WHITE, 0.45), beam.strength)
		_fill(view, facet.polygon, color)


func _draw_labels(view) -> void:
	var label := "スタート"
	view._draw_text(label, Vector2(CENTER_X - view._text_width(label, 30, true) * 0.5, 692.4), 30, MIST, true)
	label = "準備中"
	view._draw_text(label, Vector2(CENTER_X - view._text_width(label, 17) * 0.5, 717.0), 17, GOLD)
	label = "チュートリアル"
	view._draw_text(label, Vector2(CENTER_X - view._text_width(label, 30, true) * 0.5, 788.4), 30, INK, true)


# Speaker icon extents relative to its left edge: ON waves, OFF slash.
const SPEAKER_SPAN := {false: Vector2(0, 34.2), true: Vector2(-8.5, 22.5)}


func _draw_mute(view, muted: bool) -> void:
	var text := "OFF" if muted else "ON"
	var span: Vector2 = SPEAKER_SPAN[muted]
	var gap := 5.0
	var text_width: float = view._text_width(text, 17)
	# The icon and measured label are centred as one group on the plate.
	var sx := MUTE_RECT.position.x + (MUTE_RECT.size.x - (span.y - span.x + gap + text_width)) * 0.5 - span.x
	var top := MUTE_RECT.position.y + 6.0
	_fill(view, PackedVector2Array([Vector2(sx, top + 8), Vector2(sx + 6, top + 8), Vector2(sx + 6, top + 6), Vector2(sx + 14, top - 2), Vector2(sx + 14, top + 30), Vector2(sx + 6, top + 22), Vector2(sx + 6, top + 20), Vector2(sx, top + 20)]), PAPER)
	if muted:
		# One 45-degree slash through the speaker, over an ink keyline.
		for layer in [[sx - 8.5, 7.0, INK], [sx - 7.0, 4.0, RED_HI]]:
			var x0: float = layer[0]
			var width: float = layer[1]
			_fill(view, PackedVector2Array([Vector2(x0, top + 2), Vector2(x0 + width, top + 2), Vector2(x0 + width + 24, top + 26), Vector2(x0 + 24, top + 26)]), layer[2])
	else:
		# Three angular waves: 45-degree, vertical, 45-degree brackets.
		var cy := top + 14.0
		for wave in 3:
			var radius := 5.0 + wave * 4.0
			var start := sx + 18.0 + wave * 4.0
			view.draw_polyline(PackedVector2Array([Vector2(start, cy - radius), Vector2(start + radius * 0.5, cy - radius * 0.5), Vector2(start + radius * 0.5, cy + radius * 0.5), Vector2(start, cy + radius)]), PAPER, 2.4, true)
	view._draw_text(text, Vector2(sx + span.y + gap, top + 4.0 + 17 * 0.88), 17, RED_HI if muted else PAPER)


# --- static meshes ---------------------------------------------------------

class ShapeLog:
	extends RefCounted
	var shapes: Array[PackedVector2Array] = []
	var colors: Array[Color] = []

	func convex(points: PackedVector2Array, color: Color) -> void:
		shapes.append(points)
		colors.append(color)

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
		_fringe(points, color)

	func _fringe(points: PackedVector2Array, color: Color) -> void:
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


# Background, floor, cord and control plates, in the mock's order.
static func _background_shapes(mesh) -> void:
	mesh.convex(rect_points(Rect2(0, 0, 390, 844)), NIGHT0)
	mesh.convex(rect_points(Rect2(0, 192, 390, 652)), NIGHT1)
	mesh.convex(rect_points(Rect2(0, 300, 390, 544)), Color("#211838"))
	mesh.convex(rect_points(Rect2(0, 352, 390, 492)), NIGHT1)
	for star in STAR_POINTS:
		mesh.convex(rect_points(Rect2(star, Vector2(2, 2))), NIGHT5)
	var depth_colors := [NIGHT2, Color("#2a2145"), NIGHT3, Color("#3a2e5a")]
	for row in 12:
		for column in range(-1, 10):
			var center := tile_center(column, row)
			mesh.convex(diamond(center, 21.0), INK)
			# Plain flat glass; only colour separates lit from unlit tiles.
			mesh.convex(diamond(center, 19.0), depth_colors[mini(3, int(row / 3.0))])
	mesh.convex(rect_points(Rect2(0, FLOOR_FRONT, 390, 844 - FLOOR_FRONT)), NIGHT0)
	mesh.convex(rect_points(Rect2(0, FLOOR_FRONT, 390, 2)), INK)
	mesh.convex(rect_points(Rect2(192, 0, 4, 62)), NIGHT4)
	mesh.convex(rect_points(Rect2(188, 58, 12, 6)), NIGHT5)
	var inner := 6.0 - 2.0 * (2.0 - sqrt(2.0))
	mesh.convex(octagon(MUTE_RECT, 6), INK)
	mesh.convex(octagon(Rect2(MUTE_RECT.position + Vector2(2, 2), MUTE_RECT.size - Vector2(4, 8)), 4), NIGHT3)
	mesh.convex(rect_points(Rect2(MUTE_RECT.position + Vector2(6, 2), Vector2(MUTE_RECT.size.x - 12, 2))), NIGHT4)
	# Disabled campaign: a flat plate without a raised lip.
	mesh.convex(octagon(REPAIR_RECT, 6), INK)
	mesh.convex(octagon(REPAIR_RECT.grow(-2), inner), NIGHT2)
	mesh.convex(rect_points(Rect2(REPAIR_RECT.position + Vector2(6, 4), Vector2(REPAIR_RECT.size.x - 12, 2))), NIGHT2.lerp(NIGHT4, 0.5))
	# Tutorial: pink cap over a darker lip, with a flat top highlight.
	mesh.convex(octagon(TUTORIAL_RECT, 6), INK)
	var cap := TUTORIAL_RECT.grow(-2)
	mesh.convex(octagon(cap, 4), PINK_LO)
	mesh.convex(octagon(Rect2(cap.position, cap.size - Vector2(0, 6)), 4), PINK)
	mesh.convex(rect_points(Rect2(TUTORIAL_RECT.position + Vector2(6, 2), Vector2(TUTORIAL_RECT.size.x - 12, 2))), PINK_HI)


static func _cells(word: String, origin: Vector2) -> Array[PackedVector2Array]:
	var cells: Array[PackedVector2Array] = []
	var x := origin.x
	for letter in word:
		var rows: Array = GLYPH[letter]
		for row in rows.size():
			var line: String = rows[row]
			for column in line.length():
				var p := Vector2(x + column * CELL, origin.y + row * CELL)
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


# The sign's layers: shadow and ink are the letter cells dilated by a regular
# octagon (edges stay at 0/45/90/135), the face is dilated by 2 px and split
# into three flat bands, and thin 45-degree sheen lines run inside the cells.
static func _wordmark_layers(word: String, origin: Vector2) -> Dictionary:
	var cells := _cells(word, origin)
	var layers := {"cells": cells, "shadow": [], "ink": [], "face": [], "sheen": []}
	for cell in cells:
		layers.shadow.append(_grow(cell, 4, Vector2(4, 4)))
		layers.ink.append(_grow(cell, 4, Vector2.ZERO))
		layers.face.append(_grow(cell, 2, Vector2.ZERO))
	var top := origin.y
	var half := Vector2(0.8, 0.8) / sqrt(2.0)
	for k in range(-40, 200, 23):
		var a := Vector2(origin.x - 4 + k * 2, top + 7 * CELL)
		var b := a + Vector2(7 * CELL, -7 * CELL)
		layers.sheen.append(PackedVector2Array([a - half, b - half, b + half, a + half]))
	return layers


static func _logo_shapes(mesh) -> void:
	for word in [["DISCO", DISCO_TOP], ["BREAKER", BREAKER_TOP]]:
		var layers := _wordmark_layers(word[0], word[1])
		for layer in ["shadow", "ink", "face"]:
			for piece in layers[layer]:
				mesh.convex(piece, INK)


static func _svg_path(pieces: Array) -> String:
	var d := ""
	for piece in pieces:
		# One winding for every subpath: the nonzero rule fills their union.
		var loop: PackedVector2Array = piece
		if Geometry2D.is_polygon_clockwise(loop):
			loop.reverse()
		for i in loop.size():
			d += ("M" if i == 0 else "L") + "%.3f %.3f " % [loop[i].x - LOGO_RECT.position.x, loop[i].y - LOGO_RECT.position.y]
		d += "Z "
	return d


# The sign as one SVG, rasterised by Godot at the device scale. Overlapping
# cells become one antialiased union with holes, as in the mock's canvas fill.
static func _logo_svg() -> String:
	var body := ""
	var defs := ""
	for entry in [["DISCO", DISCO_TOP, ["#eef6ff", "#a9c6e6", "#6b86b0"]], ["BREAKER", BREAKER_TOP, ["#ffe7a3", "#f4b942", "#a5651f"]]]:
		var layers := _wordmark_layers(entry[0], entry[1])
		var name: String = entry[0]
		var top: float = entry[1].y - LOGO_RECT.position.y
		var bands: Array = entry[2]
		defs += "<linearGradient id='%s' gradientUnits='userSpaceOnUse' x1='0' y1='%.3f' x2='0' y2='%.3f'>" % [name, top - 2, top + 7 * CELL + 2]
		for stop in [[0.0, 0], [0.36, 0], [0.36, 1], [0.7, 1], [0.7, 2], [1.0, 2]]:
			defs += "<stop offset='%.2f' stop-color='%s'/>" % [stop[0], bands[stop[1]]]
		defs += "</linearGradient><clipPath id='%s-cells'><path d='%s'/></clipPath>" % [name, _svg_path(layers.cells)]
		body += "<path fill='#06040c' d='%s'/>" % _svg_path(layers.shadow)
		body += "<path fill='%s' d='%s'/>" % ["#" + INK.to_html(false), _svg_path(layers.ink)]
		body += "<path fill='url(#%s)' d='%s'/>" % [name, _svg_path(layers.face)]
		body += "<path fill='#ffffff' fill-opacity='0.9' clip-path='url(#%s-cells)' d='%s'/>" % [name, _svg_path(layers.sheen)]
	return "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d'><defs>%s</defs>%s</svg>" % [LOGO_RECT.size.x, LOGO_RECT.size.y, defs, body]


static func _logo_texture(scale: float) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string(_logo_svg(), scale)
	return ImageTexture.create_from_image(image)


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


