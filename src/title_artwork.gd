class_name TitleArtwork
extends RefCounted

# Original, lightweight CanvasItem artwork informed by the archived HTML mock.
# It is a decorative floor, separate from the tutorial's check geometry.
const LOGO := preload("res://assets/title-wordmark.svg")
const Flicker := preload("res://src/fault_flicker.gd")
const RED := Color("#ff6274")
const BLUE := Color("#64bcff")
const GOLD := Color("#e7c792")
const LIT_TILES := [8, 17, 31, 38]
const TUTORIAL_RECT := Rect2(24, 744, 342, 62)
const REPAIR_RECT := Rect2(24, 648, 342, 66)
var _facets: Array[PackedVector3Array] = []


func _init() -> void:
	for row in 9:
		var lat := -PI * 0.5 + (float(row) + 0.5) * PI / 9.0
		for column in 18:
			var lon := float(column) * TAU / 18.0
			var corners := PackedVector3Array()
			for corner in [Vector2(-0.45, -0.44), Vector2(0.45, -0.44), Vector2(0.45, 0.44), Vector2(-0.45, 0.44)]:
				var a: float = lat + corner.y * PI / 9.0
				var b: float = lon + corner.x * TAU / 18.0
				corners.append(Vector3(cos(a) * sin(b), sin(a), cos(a) * cos(b)))
			_facets.append(corners)


func draw(view, elapsed: float, reduced: bool, started: bool, finished: bool) -> void:
	var time := 0.0 if reduced else elapsed
	_lighting(view, time)
	_ball(view, time)
	view._draw_text("LIGHT-UP FLOOR REPAIR", Vector2(114, 234), 11, Color("#adced8"), true)
	view.draw_texture_rect(LOGO, Rect2(0, 250, 390, 146), false)
	_floor(view, time, reduced)
	_floor_reflections(view, time)
	view._surface(REPAIR_RECT, Color("#282331"), Color("#544653"), 16, 4)
	view._draw_text("REPAIR THE FLOOR", Vector2(113, 675), 16, Color("#a799ac"), true)
	view._draw_text("COMING SOON", Vector2(155, 698), 10, Color("#b9a68c"), true)
	# This disabled preview cannot launch a nonexistent campaign.
	view._draw_text("For now, learn to repair in the tutorial.", Vector2(90, 734), 12, Color("#baabc6"))
	var label := "REPLAY TUTORIAL" if finished else ("CONTINUE TUTORIAL" if started else "TUTORIAL")
	view._draw_button(TUTORIAL_RECT, label, view.PINK, true)
	view._draw_text("7 SHORT LESSONS  /  NO TIMER", Vector2(116, 830), 10, Color("#a89ab7"), true)


func _lighting(view, time: float) -> void:
	var center := Vector2(195, 145)
	# Muted, slow light fans. No flashes or full-screen brightness modulation.
	for index in 5:
		var direction := 0.43 + float(index) * 0.55 + sin(time * 0.18 + index) * 0.08
		var reach := 390.0
		var left := center + Vector2(cos(direction - 0.026), sin(direction - 0.026)) * reach
		var right := center + Vector2(cos(direction + 0.026), sin(direction + 0.026)) * reach
		var tint := BLUE if index % 2 == 0 else RED
		view.draw_polygon(PackedVector2Array([center, left, right]), PackedColorArray([Color(tint, 0.12), Color(tint, 0), Color(tint, 0)]))
	for i in 18:
		var angle := time * TAU / 22.0
		var y := 195.0 + fmod(i * 37.0, 220.0) + sin(angle + i) * 5.0
		var x := 30.0 + fmod(i * 79.0 + sin(angle + i * 0.7) * 24.0 + 330.0, 330.0)
		var tint := BLUE if i % 3 == 0 else GOLD
		view._circle(Vector2(x, y), 0.8 if i % 3 else 1.2, Color(tint, 0.3))


func _ball(view, time: float) -> void:
	var center := Vector2(195, 145)
	var radius := 48.0
	view.draw_line(Vector2(195, 0), center - Vector2(0, radius), Color("#948397"), 2, true)
	view.draw_line(Vector2(180, 55), Vector2(210, 55), Color("#5e5069"), 2, true)
	for ring in range(12, 0, -1):
		view._circle(center, radius + ring * 2.0, Color(0.38, 0.62, 0.76, 0.009))
	view._circle(center + Vector2(0, 3), radius + 1, Color("#080913"))
	view._circle(center, radius, Color("#263442"))
	var angle := time * TAU / 22.0
	var rotation := Basis(Vector3.UP, angle)
	var light := Vector3(-0.45, -0.6, 0.8).normalized()
	for facet in _facets:
		var normal := rotation * ((facet[0] + facet[2]) * 0.5).normalized()
		if normal.z < 0.08:
			continue
		var points := PackedVector2Array()
		for vertex in facet:
			var p: Vector3 = rotation * vertex
			points.append(center + Vector2(p.x, p.y) * radius)
		var shine := clampf(normal.dot(light), 0, 1)
		var tint := Color("#829daf").lerp(Color("#fff3cd"), pow(shine, 3) * 0.9)
		if normal.x < -0.28:
			tint = tint.lerp(RED, 0.15)
		elif normal.x > 0.3:
			tint = tint.lerp(BLUE, 0.24)
		tint = tint.darkened((1.0 - normal.z) * 0.55 + (1.0 - shine) * 0.12)
		view.draw_colored_polygon(points, tint)
	view.draw_arc(center, radius, 3.55, 5.48, 36, Color(1, 0.94, 0.78, 0.38), 1.0, true)
	view._circle(center + Vector2(-16, -27), 2, Color("#fff7dd"))
	view.draw_line(center + Vector2(-22, -27), center + Vector2(-10, -27), Color(1, 0.97, 0.86, 0.54), 1, true)
	view.draw_line(center + Vector2(-16, -33), center + Vector2(-16, -21), Color(1, 0.97, 0.86, 0.54), 1, true)


func _project(column: float, row: float) -> Vector2:
	var depth := row / 6.0
	var half_width := lerpf(105, 268, depth)
	return Vector2(195 + (column / 7.0 * 2.0 - 1.0) * half_width, 435 + pow(depth, 1.45) * 188)


func _floor(view, time: float, reduced: bool) -> void:
	for row in 6:
		for column in 7:
			var index := row * 7 + column
			var points := PackedVector2Array([_project(column + 0.055, row + 0.055), _project(column + 0.945, row + 0.055), _project(column + 0.945, row + 0.945), _project(column + 0.055, row + 0.945)])
			var color := RED if index % 2 == 0 else BLUE
			var lit := LIT_TILES.has(index)
			var intensity := Flicker.brightness(8000 + index * 71, time, reduced) if lit else 0.0
			var base := Color("#1a2030")
			if lit:
				base = base.lerp(color.darkened(0.38), 0.24 + intensity * 0.7)
				var outline := points.duplicate()
				outline.append(points[0])
				for spread in range(7, 1, -1):
					view.draw_polyline(outline, Color(color, intensity * 0.021), float(spread) * 2.0, true)
			view.draw_colored_polygon(points, base)
			view.draw_polygon(points, PackedColorArray([Color(0.75, 0.85, 0.92, 0.15), Color(0.75, 0.85, 0.92, 0.02), Color(0.75, 0.85, 0.92, 0.01), Color(0.75, 0.85, 0.92, 0.04)]))
			view.draw_line(points[0], points[1], Color(color, 0.35 + intensity * 0.3) if lit else Color("#4a485c"), 1, true)
			view.draw_line(points[0], points[3], Color(0.67, 0.71, 0.81, 0.27), 1, true)
			view.draw_line(points[3], points[2], Color("#080b15"), 2, true)


func _floor_reflections(view, time: float) -> void:
	# Small mirror-facet reflections travel across the glass with the same
	# angular phase as the ball. Their whole path stays above the controls.
	var angle := time * TAU / 22.0
	for index in 11:
		var phase := angle + float(index) * 1.91
		var column := 3.5 + sin(phase) * 2.9
		var row := 0.7 + fmod(index * 1.17, 4.5) + cos(phase) * 0.18
		var center := _project(column, row)
		var width := lerpf(1.5, 4.0, row / 6.0)
		var tint := GOLD if index % 3 == 0 else (BLUE if index % 3 == 1 else Color("#efb7d6"))
		var patch := PackedVector2Array([center + Vector2(-width, -1), center + Vector2(width, -1), center + Vector2(width + 0.6, 1.5), center + Vector2(-width - 0.6, 1.5)])
		view._circle(center, width * 2.1, Color(tint, 0.035))
		view.draw_colored_polygon(patch, Color(tint, 0.32))
