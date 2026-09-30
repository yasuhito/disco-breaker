class_name LeakFeedback
extends RefCounted

var active := false
var event_count := 0
var _previous: Dictionary = {}


func observe(state: Dictionary) -> String:
	if not _previous.is_empty() and state.action_count == _previous.action_count:
		return ""
	var previous := _previous
	_previous = state.duplicate(true)
	var failed: bool = state.result_visible and state.floor_dark and not state.inspection.is_empty() and not bool(state.inspection.get("safe", true))
	var changed_floor: bool = not previous.is_empty() and (state.stage_id != previous.stage_id or state.boundary_phase != previous.boundary_phase or state.finished != previous.finished or state.last_action.action == "restart")
	if changed_floor or not failed:
		var was_active := active
		active = false
		return "reset" if was_active else ""
	if not active and not previous.is_empty():
		active = true
		event_count += 1
		return "leak"
	return ""


# Presentation only: find a connected residual chain on the check graph.
# Called AFTER logical inspection; this never decides the verdict.
static func route(faces: Array, support: PackedInt32Array, size: int, vertical: bool) -> Dictionary:
	var start := faces.size()
	var finish := start + 1
	var graph: Array = []
	for i in faces.size() + 2:
		graph.append([])
	for qubit in support:
		var incident: Array[int] = []
		for check in faces.size():
			if faces[check].nodes.has(qubit):
				incident.append(check)
		if incident.size() == 1:
			var coordinate := int(qubit / size) if vertical else qubit % size
			if coordinate != 0 and coordinate != size - 1:
				continue
			incident.append(start if coordinate == 0 else finish)
		if incident.size() != 2:
			continue
		graph[incident[0]].append({"to": incident[1], "qubit": qubit})
		graph[incident[1]].append({"to": incident[0], "qubit": qubit})
	var parents := {start: {"from": -1, "qubit": -1}}
	var queue: Array[int] = [start]
	var cursor := 0
	while cursor < queue.size() and not parents.has(finish):
		var vertex := queue[cursor]
		cursor += 1
		for edge in graph[vertex]:
			if not parents.has(edge.to):
				parents[edge.to] = {"from": vertex, "qubit": edge.qubit}
				queue.append(edge.to)
	if not parents.has(finish):
		return {}
	var qubits: Array[int] = []
	var checks: Array[int] = []
	var current := finish
	while current != start:
		qubits.push_front(parents[current].qubit)
		current = parents[current].from
		if current != start:
			checks.push_front(current)
	var points := PackedVector2Array()
	var first := Vector2(qubits[0] % size + 0.5, int(qubits[0] / size) + 0.5)
	points.append(Vector2(first.x, 0.04) if vertical else Vector2(0.04, first.y))
	for index in qubits.size():
		points.append(Vector2(qubits[index] % size + 0.5, int(qubits[index] / size) + 0.5))
		if index < checks.size():
			points.append(faces[checks[index]].center)
	var last := points[-1]
	points.append(Vector2(last.x, size - 0.04) if vertical else Vector2(size - 0.04, last.y))
	return {"qubits": qubits, "checks": checks, "points": points}


# Center the original-fault ghost on the same qubit and axis as its correction.
static func ghost_segment(center: Vector2, radius: float, component: int, even: bool) -> PackedVector2Array:
	var direction := Vector2(radius * 0.58, radius * 0.58 * (1 if even else -1))
	if component == 2:
		direction.y *= -1.0
	return PackedVector2Array([center - direction, center + direction])
