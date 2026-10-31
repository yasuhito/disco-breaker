extends SceneTree

# Title art regression: the angular grammar, mirror-beam attachment, floor
# landings, continuity through a full revolution and reduced-motion stillness.
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
	var textured: Array[PackedVector2Array] = []
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
			textured.append(points)
		else:
			shapes.append(points)
		log.append(["textured", points, colors])

	func draw_polyline(points: PackedVector2Array, color: Color, width: float, _aa := false) -> void:
		shapes.append(points)
		log.append(["polyline", points, color, width])

	func draw_line(from: Vector2, to: Vector2, color: Color, width: float, _aa := false) -> void:
		shapes.append(PackedVector2Array([from, to]))
		log.append(["line", from, to, color, width])

	func draw_texture_rect(_texture, rect: Rect2, _tile: bool, modulate: Color) -> void:
		log.append(["spot", rect, modulate])

	func _draw_text(text: String, position: Vector2, size: int, color: Color, bold := false) -> void:
		texts.append({"text": text, "position": position, "size": size, "bold": bold})
		log.append(["text", text, position, color])

	func _text_width(text: String, size: int, bold := false) -> float:
		var font: Font = BOLD_FONT if bold else FONT
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


class MeshProbe:
	extends RefCounted
	var shapes: Array[PackedVector2Array] = []
	var colors: Array[Color] = []

	func convex(points: PackedVector2Array, color: Color) -> void:
		shapes.append(points)
		colors.append(color)


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


func area(polygons: Array[PackedVector2Array]) -> float:
	var total := 0.0
	for polygon in polygons:
		var sum := 0.0
		for i in polygon.size():
			sum += polygon[i].cross(polygon[(i + 1) % polygon.size()])
		total += absf(sum) * 0.5
	return total


func _initialize() -> void:
	var art := Artwork.new()
	var face := Artwork.ball_face()
	var bottom := Artwork.BALL_ROWS - 1
	var origin_y := Artwork.row_span(bottom).y - Artwork.FACET_GAP
	var radius := Artwork._row_radius(bottom)
	var max_step := radius * TAU / Artwork.PERIOD * STEP + 0.001
	var flat := Artwork.flat_bottom_half()

	# Static surfaces: background, floor, sign, buttons and audio plate.
	var mesh := MeshProbe.new()
	art._static_shapes(mesh)
	check(mesh.shapes.size() > 500, "static title surfaces are recorded")
	for shape in mesh.shapes:
		check(angular(shape, true), "static edge is horizontal, vertical or 45 degrees: %s" % [shape])

	var previous := {}
	var min_beams := 99
	var min_bright := 99
	var frames := int(Artwork.PERIOD / STEP) + 1
	for frame in frames:
		var time := frame * STEP
		var facets := Artwork.facets(time)
		var bottom_facets := {}
		for facet in facets:
			check(angular(facet.polygon, true), "mirror facet edges stay angular")
			if facet.row == bottom:
				bottom_facets[facet.index] = facet
		var beams := Artwork.beams(time)
		min_beams = mini(min_beams, beams.size())
		var bright := 0
		var current := {}
		for beam in beams:
			var origin: Vector2 = beam.origin
			var landing: Vector2 = beam.landing
			var strength: float = beam.strength
			if strength >= 0.5:
				bright += 1
			var heading: int = beam.heading
			check(heading in [-1, 0, 1], "beam heading is vertical or 45 degrees")
			check((landing - origin).normalized().is_equal_approx(Vector2(heading, 1).normalized()), "beam core keeps an exact 90 or 45 degree direction")
			var polygon := Artwork.beam_polygon(beam)
			check(angular(polygon, true), "beam boundaries are straight 0/45/90 degree edges")
			# Surfaced origin: the lower edge of a visible, front-facing facet.
			check(is_equal_approx(origin.y, origin_y), "beam leaves the bottom facet edge")
			check(bottom_facets.has(beam.facet), "emitting facet is visible at %.2f s" % time)
			if bottom_facets.has(beam.facet):
				var rect: Rect2 = bottom_facets[beam.facet].rect
				check(is_equal_approx(rect.end.y, origin.y), "origin is on its facet's lower edge")
				check(rect.position.x <= origin.x - Artwork.BEAM_HALF + 0.001 and origin.x + Artwork.BEAM_HALF <= rect.end.x + 0.001, "beam footprint stays on its own facet at %.2f s" % time)
			check(absf(origin.x - Artwork.BALL_CENTER.x) + Artwork.BEAM_HALF <= flat, "beam starts on the flat underside, never a chamfer")
			for point in polygon:
				check(point.y >= origin.y - 0.001, "beam never rises over the mirror face")
			for facet in facets:
				check(area(Geometry2D.intersect_polygons(polygon, facet.polygon)) < 0.01, "beam never crosses a mirror facet")
			# Safe endpoint: on visible floor glass, clear of sign, controls and edges.
			var spot := Artwork.spot_polygon(landing)
			check(angular(spot, true), "landing patch edges stay angular")
			for point in spot:
				check(point.y >= Artwork.FLOOR_ROW0 and point.y <= Artwork.FLOOR_FRONT - 2.0, "landing lies on the floor surface")
				check(point.x >= 4.0 and point.x <= 386.0, "landing is fully on screen")
			for point in polygon:
				check(point.y > Artwork.FASCIA_BOTTOM + 8 and point.y < Artwork.REPAIR_RECT.position.y, "beam clears sign and controls")
				check(point.y <= landing.y + 0.001, "beam ends at its floor landing")
			# Continuity: rigid translation with the facet; entry and exit fade.
			current[beam.facet] = beam
			if previous.has(beam.facet):
				var before: Dictionary = previous[beam.facet]
				var moved: Vector2 = origin - before.origin
				check(moved.length() <= max_step and absf(moved.y) < 0.0001, "origin glides smoothly with its facet")
				check((landing - before.landing).distance_to(moved) < 0.001, "landing moves rigidly with its origin")
				check(absf(strength - before.strength) <= 0.08, "beam strength changes smoothly")
			elif frame > 0:
				check(strength <= 0.03, "beam fades in rather than popping (%.3f)" % strength)
		for facet_index in previous:
			if not current.has(facet_index) and frame > 0:
				check(previous[facet_index].strength <= 0.03, "beam fades out rather than vanishing")
		previous = current
		min_bright = mini(min_bright, bright)
	check(min_beams >= 3, "at least three beams are visible throughout the revolution (min %d)" % min_beams)
	check(min_bright >= 2, "at least two bright beams at every phase (min %d)" % min_bright)

	# One continuous textured core per beam, with a single-peaked cross-section.
	var probe := Probe.new()
	art.draw(probe, 4.2, false, false, false)
	var drawn := Artwork.beams(4.2)
	check(probe.textured.size() == drawn.size(), "each beam is one uninterrupted quad")
	for i in drawn.size():
		check(probe.textured[i] == Artwork.beam_polygon(drawn[i]), "drawn beam matches its checked geometry")
	var alphas: Array[float] = []
	for color in art._beam_texture.gradient.colors:
		alphas.append(color.a)
	var peak := alphas.find(1.0)
	for i in alphas.size() - 1:
		check(alphas[i + 1] >= alphas[i] if i < peak else alphas[i + 1] <= alphas[i], "beam cross-section has one bright continuous core")
	for shape in probe.shapes:
		check(angular(shape, shape.size() > 2), "dynamic title edge is angular: %s" % [shape])

	# Audio control: measured icon and label fit with balanced padding.
	for muted in [false, true]:
		var mute := Probe.new()
		mute._muted = muted
		art._draw_mute(mute, muted)
		var label: Dictionary = mute.texts[0]
		var left := 999.0
		for shape in mute.shapes:
			for point in shape:
				left = minf(left, point.x)
		var right: float = label.position.x + mute._text_width(label.text, label.size, true)
		var inner := Rect2(Artwork.MUTE_RECT.position + Vector2(2, 2), Artwork.MUTE_RECT.size - Vector2(4, 8))
		check(left - inner.position.x >= 6.0 and inner.end.x - right >= 6.0, "%s fits comfortably inside the audio cap" % label.text)
		check(absf((left - inner.position.x) - (inner.end.x - right)) <= 2.5, "%s padding is balanced" % label.text)
		check(label.text == ("OFF" if muted else "ON"), "audio label follows state")
		check(mute.log.filter(func(entry): return entry[0] == "line").size() == (2 if muted else 0), "OFF uses one slash (ink keyline + colour), ON uses waves")

	# Reduced motion is one still frame.
	var first := Probe.new()
	var later := Probe.new()
	art.draw(first, 0.0, true, false, false)
	art.draw(later, 17.3, true, true, true)
	check(str(first.log) == str(later.log), "reduced-motion title is static")
	for beam in Artwork.beams(Artwork.STILL_TIME):
		check(beam.strength >= 0.95, "the still frame has no half-faded beams")
	if failures == 0:
		print("PASS: angular title surfaces, surfaced facet origins, floor landings and smooth beams across %d phases (at least %d beams, %d bright)" % [frames, min_beams, min_bright])
	else:
		printerr("FAIL: ", failures, " title geometry checks")
	quit(0 if failures == 0 else 1)
