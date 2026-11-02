extends SceneTree

# Title art regression: the angular grammar, a mirror ball built only from
# mirrors, rays that leave visible facets outward in several directions and
# heights, clean ray paths and endpoints, continuity through a revolution,
# the audio control's padding, reduced-motion stillness and the tutorial
# plate's press.
const Artwork := preload("res://src/title_artwork.gd")
const FONT := preload("res://assets/fonts/NotoSansJP-Regular.otf")
const BOLD_FONT := preload("res://assets/fonts/NotoSansJP-Bold.tres")
const STEP := 1.0 / 30.0


class Probe:
	extends RefCounted
	var _scale := 1.0
	var _muted := false
	var log: Array = []
	var shapes: Array[PackedVector2Array] = []
	var beams: Array[Dictionary] = []
	var texts: Array[Dictionary] = []

	func get_viewport():
		return self

	func get_screen_transform() -> Transform2D:
		return Transform2D.IDENTITY

	func get_global_transform_with_canvas() -> Transform2D:
		return Transform2D.IDENTITY

	func draw_mesh(_mesh, _texture) -> void:
		log.append("mesh")

	func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
		shapes.append(points)
		log.append(["polygon", points, color])

	func draw_polygon(points: PackedVector2Array, colors: PackedColorArray, _uvs := PackedVector2Array(), texture: Texture2D = null) -> void:
		if texture != null:
			beams.append({"points": points, "alpha": colors[0].a})
		else:
			shapes.append(points)
		log.append(["textured", points, colors])

	func draw_polyline(points: PackedVector2Array, color: Color, width: float, _aa := false) -> void:
		shapes.append(points)
		log.append(["polyline", points, color, width])

	func draw_line(from: Vector2, to: Vector2, color: Color, width: float, _aa := false) -> void:
		shapes.append(PackedVector2Array([from, to]))
		log.append(["line", from, to, color, width])

	func draw_texture_rect(_texture, rect: Rect2, _tile: bool, modulate := Color.WHITE) -> void:
		log.append(["texture", rect, modulate])

	func _draw_text(text: String, position: Vector2, size: int, color: Color, bold := false) -> void:
		texts.append({"text": text, "position": position, "size": size, "bold": bold})
		log.append(["text", text, position, color])

	func _text_width(text: String, size: int, bold := false) -> float:
		var font: Font = BOLD_FONT if bold else FONT
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 16:
			printerr("FAIL: ", message)


func angular(shape: PackedVector2Array, closed: bool) -> bool:
	var count := shape.size() if closed else shape.size() - 1
	for i in count:
		var edge := shape[(i + 1) % shape.size()] - shape[i]
		if edge.length() < 0.05:
			continue
		var degrees := fposmod(rad_to_deg(edge.angle()), 45.0)
		if minf(degrees, 45.0 - degrees) > 0.05:
			return false
	return true


func covered(point: Vector2, pieces: Array) -> bool:
	for piece in pieces:
		if Geometry2D.is_point_in_polygon(point, piece):
			return true
	return false


func band(y: float) -> String:
	var third := Artwork.BALL_HALF * 2.0 / 3.0
	var top := Artwork.BALL_CENTER.y - Artwork.BALL_HALF
	return "upper" if y < top + third else ("middle" if y < top + third * 2.0 else "lower")


func _initialize() -> void:
	var art := Artwork.new()
	var outline := Artwork.ball_outline()
	var center := Artwork.BALL_CENTER

	# Static surfaces: background, plain floor glass, plates and sign geometry.
	var back := Artwork.ShapeLog.new()
	Artwork._background_shapes(back)
	var sign := Artwork.ShapeLog.new()
	Artwork._logo_shapes(sign)
	for shape in back.shapes + sign.shapes:
		check(angular(shape, true), "static edge is horizontal, vertical or 45 degrees: %s" % [shape])
	var tiles := 0
	for shape in back.shapes:
		# Floor-sized shapes only (the full-width front edge is not a tile).
		var inside_floor := shape[1].x - shape[3].x < 60.0
		for point in shape:
			inside_floor = inside_floor and point.y > Artwork.FLOOR_ROW0 - 22.5 and point.y < Artwork.FLOOR_ROW0 + 12 * 22.0
		if inside_floor:
			tiles += 1
	check(tiles == 12 * 11 * 2, "each floor tile is just its seam and plain glass (%d shapes)" % tiles)
	var logo := Image.new()
	check(logo.load_svg_from_string(Artwork._logo_svg(), 2.0) == OK, "sign SVG rasterises")
	check(logo.get_size() == Vector2i(Artwork.LOGO_RECT.size * 2.0), "sign raster matches the device scale")
	check(logo.get_pixel(int((Artwork.DISCO_TOP.x - Artwork.LOGO_RECT.position.x + 12) * 2), int((Artwork.DISCO_TOP.y - Artwork.LOGO_RECT.position.y + 4) * 2)).a > 0.99, "sign face is opaque")

	var previous := {}
	var classes := {}
	var min_bright := 99
	var max_gap := 0.0
	var frames := int(Artwork.PERIOD / STEP) + 1
	for frame in frames:
		var time := frame * STEP
		var facets := Artwork.facets(time)
		var by_key := {}
		var pieces: Array = []
		for facet in facets:
			check(angular(facet.polygon, true), "mirror facet edges stay angular")
			by_key[facet.key] = facet
			pieces.append(facet.polygon)
		# The silhouette is mirrors: only narrow seams interrupt its edge.
		if frame % 15 == 0:
			for i in outline.size():
				var a := outline[i]
				var b := outline[(i + 1) % outline.size()]
				var inward := (center - (a + b) * 0.5).normalized() * 0.4
				var gap := 0.0
				var length := a.distance_to(b)
				for step in int(length * 4.0):
					var point := a.lerp(b, (step + 0.5) / (length * 4.0)) + inward
					# Hairline seams under 0.3 px are invisible; real gaps are not.
					var hit := false
					for nudge in [Vector2.ZERO, Vector2(0.3, 0), Vector2(-0.3, 0), Vector2(0, 0.3), Vector2(0, -0.3)]:
						hit = hit or covered(point + nudge, pieces)
					gap = 0.0 if hit else gap + 0.25
					max_gap = maxf(max_gap, gap)
		var current := {}
		var bright := 0
		for beam in Artwork.beams(time):
			var origin: Vector2 = beam.origin
			var finish: Vector2 = beam.end
			var heading: Vector2 = beam.heading
			var strength: float = beam.strength
			var direction := heading.normalized()
			check(heading != Vector2(0, -1) and absf(heading.x) <= 1.0 and absf(heading.y) <= 1.0 and heading != Vector2.ZERO, "ray heading is one of the allowed 45-degree steps")
			check((finish - origin).normalized().is_equal_approx(direction), "ray core keeps its exact heading")
			var polygon := Artwork.beam_polygon(beam)
			check(angular(polygon, true), "ray boundaries are straight 0/45/90 degree edges")
			# Surfaced origin: inside a visible, front-facing mirror.
			check(by_key.has(beam.key), "emitting facet is visible at %.2f s" % time)
			if by_key.has(beam.key):
				check(Geometry2D.is_point_in_polygon(origin, by_key[beam.key].polygon), "ray starts on its own mirror")
				check(by_key[beam.key].shade > 0.0, "emitting mirror faces the viewer")
			var radial := origin - center
			check(direction.dot(radial) > 0.0, "ray heads outward, never across the ball")
			check(heading.x == 0.0 or signf(heading.x) == signf(radial.x), "ray leaves on its own side of the ball")
			check(Artwork._exit_length(origin, direction, outline) <= 12.0, "ray crosses at most a narrow rim of mirrors")
			if beam.behind_sign:
				# Straight down into the sign: everything past its top edge is hidden.
				for y in range(int(Artwork.OBSTACLES[0].position.y) + 1, int(finish.y)):
					for dx in [-Artwork.BEAM_HALF - 1.0, 0.0, Artwork.BEAM_HALF + 1.0]:
						check(covered(Vector2(origin.x + dx, y + 0.5), sign.shapes), "ray end is hidden by solid sign, never seen through a gap")
				check(finish.y < Artwork.OBSTACLES[1].position.y, "ray never reaches the second sign line")
			else:
				check(finish.x <= 0.01 or finish.x >= 389.99 or finish.y <= 0.01, "free ray runs to a scene edge")
				for obstacle in Artwork.OBSTACLES:
					check(Artwork._segment_rect_distance(origin, finish, obstacle) >= 2.9, "ray clears sign, audio control, cord and floor")
			if strength >= 0.5:
				bright += 1
				classes[band(origin.y)] = true
				classes["%d,%d" % [heading.x, heading.y]] = true
			# Continuity: headings never jump; entry and exit fade.
			current[beam.key] = beam
			if previous.has(beam.key):
				var before: Dictionary = previous[beam.key]
				check(before.heading == heading or before.strength + strength <= 0.06, "a mirror changes heading only while dark")
				check(origin.distance_to(before.origin) <= 1.0, "origin glides with its mirror")
				check(absf(strength - before.strength) <= 0.12, "ray strength changes smoothly (%.3f)" % absf(strength - before.strength))
			elif frame > 0:
				check(strength <= 0.06, "ray fades in rather than popping (%.3f)" % strength)
		for key in previous:
			if not current.has(key) and frame > 0:
				check(previous[key].strength <= 0.06, "ray fades out rather than vanishing")
		previous = current
		min_bright = mini(min_bright, bright)
	check(max_gap <= 2.0 * Artwork.SEAM * sqrt(2.0) + 0.5, "only seams meet the silhouette, no backing band (longest gap %.2f px)" % max_gap)
	check(min_bright >= 3, "at least three bright rays at every phase (min %d)" % min_bright)
	for name in ["upper", "middle", "lower", "-1,-1", "1,-1", "-1,0", "1,0", "0,1"]:
		check(classes.has(name), "bright rays appear from the %s class over a revolution" % name)

	# Drawn output: one textured quad per ray, visible from several heights and
	# headings; the sign is drawn after the rays so it hides their ends.
	var seen := {}
	for frame in range(0, frames, 3):
		var probe := Probe.new()
		art.draw(probe, frame * STEP, false, false, false)
		var drawn := Artwork.beams(frame * STEP)
		check(probe.beams.size() == drawn.size(), "each ray is one uninterrupted quad")
		var sign_index := probe.log.find(probe.log.filter(func(entry): return entry is Array and entry[0] == "texture")[0])
		var last_beam := -1
		for i in probe.log.size():
			if probe.log[i] is Array and probe.log[i][0] == "textured":
				last_beam = i
		check(last_beam < sign_index, "the sign is drawn in front of the rays")
		for i in drawn.size():
			check(probe.beams[i].points == Artwork.beam_polygon(drawn[i]), "drawn ray matches its checked geometry")
			if probe.beams[i].alpha >= 0.45:
				var heading: Vector2 = drawn[i].heading
				seen[band(drawn[i].origin.y)] = true
				seen["%d,%d" % [heading.x, heading.y]] = true
		for shape in probe.shapes:
			check(angular(shape, shape.size() > 2), "dynamic title edge is angular: %s" % [shape])
		for entry in probe.log:
			if entry is Array and entry[0] == "polygon":
				check(not Geometry2D.triangulate_polygon(entry[1]).is_empty(), "every drawn polygon is valid for the renderer")
		check(probe.log.filter(func(entry): return entry is Array and entry[0] == "polyline" and entry[1].size() > 4 and entry[2] == Artwork.INK).is_empty(), "no ink frame is drawn around the ball")
	for name in ["upper", "middle", "lower", "-1,-1", "1,-1", "-1,0", "1,0"]:
		check(seen.has(name), "drawn bright rays include %s" % name)
	var alphas: Array[float] = []
	for color in art._beam_texture.gradient.colors:
		alphas.append(color.a)
	var peak := alphas.find(1.0)
	for i in alphas.size() - 1:
		check(alphas[i + 1] >= alphas[i] if i < peak else alphas[i + 1] <= alphas[i], "ray cross-section has one bright continuous core")

	# Floor lamps flicker over the revolution (the floor receives no rays).
	var lamp_states := {}
	for frame in frames:
		var levels := ""
		for tile in Artwork.LIT_TILES:
			var level := Artwork.Flicker.brightness(8000 + tile[1] * 11 + tile[0] * 71, frame * STEP)
			levels += "2" if level >= 0.6 else ("1" if level >= 0.2 else "0")
		lamp_states[levels] = true
	check(lamp_states.size() >= 4, "title floor lamps flicker through several states")
	# Lit lamps are plain coloured glass.
	var lamps := Probe.new()
	art._draw_lit_tiles(lamps, 3.0, false)
	check(lamps.log.filter(func(entry): return entry is Array and entry[0] == "polygon").size() == Artwork.LIT_TILES.size(), "each lit tile is one flat colour, without inner marks")

	# Audio control: measured icon and label fit with balanced padding.
	for muted in [false, true]:
		var mute := Probe.new()
		art._draw_mute(mute, muted)
		var label: Dictionary = mute.texts[0]
		var left := 999.0
		for shape in mute.shapes:
			for point in shape:
				left = minf(left, point.x)
		var right: float = label.position.x + mute._text_width(label.text, label.size)
		var plate := Artwork.MUTE_RECT
		check(left - plate.position.x >= 6.0 and plate.end.x - right >= 6.0, "%s fits comfortably inside the audio plate" % label.text)
		check(absf((left - plate.position.x) - (plate.end.x - right)) <= 1.5, "%s padding is balanced" % label.text)
		check(label.text == ("OFF" if muted else "ON"), "audio label follows state")
		var slashes := 0
		for shape in mute.shapes:
			if shape.size() == 4 and absf((shape[2] - shape[1]).angle() - PI * 0.25) < 0.01:
				slashes += 1
		check(slashes == (2 if muted else 0), "OFF uses one 45-degree slash (ink keyline + colour), ON uses waves")

	# Reduced motion is one still frame with up, sideways and down rays.
	var first := Probe.new()
	var later := Probe.new()
	art.draw(first, 0.0, true, false, false)
	art.draw(later, 17.3, true, true, true)
	check(str(first.log) == str(later.log), "reduced-motion title is static")
	var still := {}
	for beam in Artwork.beams(Artwork.STILL_TIME):
		if beam.strength >= 0.9:
			still["up" if beam.heading.y < 0 else ("down" if beam.heading.y > 0 else "side")] = true
	check(still.size() == 3, "the still frame shows up, sideways and down rays")
	# The tutorial plate's press: at rest nothing changes; pushed in, only the
	# plate's cap, highlight and label move down (4 px) inside the drawn plate.
	var rest := Probe.new()
	var pushed := Probe.new()
	art.draw(rest, 0.0, true, false, false, 0.0)
	art.draw(pushed, 0.0, true, false, false, 1.0)
	check(str(rest.log) == str(first.log), "an unpressed tutorial plate draws exactly the title at rest")
	var label_y := []
	for probe in [rest, pushed]:
		for text in probe.texts:
			if text.text == "チュートリアル":
				label_y.append(text.position.y)
	check(label_y.size() == 2 and is_equal_approx(label_y[1] - label_y[0], 4.0), "the pushed label moves down 4 px")
	var resting := {}
	for shape in rest.shapes:
		resting[str(shape)] = true
	var added := 0
	for shape in pushed.shapes:
		if resting.has(str(shape)):
			continue
		added += 1
		for point in shape:
			check(Artwork.TUTORIAL_RECT.grow(0.001).has_point(point), "the pushed plate stays inside its drawn bounds")
	check(added == 8, "the push redraws only the plate: outline, lip, cap and highlight, each a fill and its rim")
	if failures == 0:
		print("PASS: angular title, mirror-only ball, outward rays from facets at all heights and headings, clean paths across %d phases (at least %d bright rays)" % [frames, min_bright])
	else:
		printerr("FAIL: ", failures, " title geometry checks")
	quit(0 if failures == 0 else 1)
