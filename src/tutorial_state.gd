class_name TutorialState
extends RefCounted

const Inspection := preload("res://src/inspection_semantics.gd")

const EMPTY := 0
const RED := 1
const BLUE := 2
const BOTH := 3

# The foreman's lines for a dark floor the inspection reported as leaking,
# chosen by the colour(s) the inspection found.
const LEAK_COLOR := {"red": "赤い線が上から下へ。", "blue": "青い線が左から右へ。", "both": "赤も青も抜けている。"}
const LEAK_AUTO := "暗いけど漏電！\n"
const LEAK_CALL := "漏電あり！\n"
const LEAK_AGAIN := "まだ漏電。\n"
# Lessons 5-7: the colour(s) the inspection found leaving the board.
const LEAVING := {"red": "あっ、まだ赤い電気が\n外へ抜けているよ！", "blue": "あっ、まだ青い電気が\n外へ抜けているよ！", "both": "あっ、まだ赤と青の電気が\n外へ抜けているよ！"}
# The optional detailed check: leftovers on the inspection lines, in pairs.
const CHECK_DETAIL := "2こで消える。\n1こ残ったら、まだ直そう！"
# Said when the detailed check's windows show their result.
const DETAIL_ALL_GONE := "全部、組で消えたね！"
const DETAIL_LEFT := {"red": "赤が1こ残ったよ。", "blue": "青が1こ残ったよ。", "both": "赤と青が1こずつ残ったよ。"}
# Hints for a lit floor, used only while they describe the actual board.
const LIT_HINTS := {
	"red_one_tap": "光る床が残っている。\n中央を押してみよう。",
	"blue_two_taps": "赤い配線になったね。\nもう1回タップして、\n青い配線に変えよう！",
	"combined_three_taps": "まだ片方だけ。\n中央をもう1回。",
}
const LIT_GENERIC := "光る床が残っている。"
const DONE_TEXT := "全7レッスン修了！\nこれで踊る準備は万全だ。"
const SKIPPED_TEXT := "チュートリアル終了。\n自由練習はまた今度。"

var stage_index := 0
var boundary_phase := 0
var finished := false
var skipped := false
var corrections: PackedInt32Array = PackedInt32Array()
# The inspection of the current board. Any wiring change clears it, so a
# verdict never outlives the board it was computed for.
var inspection: Dictionary = {}
# The player has changed this floor since it was set up.
var touched := false
# Inspections on this floor that reported a leak (lesson 5 keeps the
# original-fault reveal for the repair once one has).
var leak_count := 0
# The lesson's demonstration: how many of its steps have been shown (its
# placements, then its closing line), and whether the player has taken over.
var demo_step := 0
var demo_over := false
var leak_seen: bool:
	get:
		return leak_count > 0
var trace: Array[Dictionary] = []
var _sequence := 0
var _stage_cache: Dictionary = {}


func _init() -> void:
	_reset_stage()
	_record("launch", {})


# The seven fixed lessons. "inspect" is "auto" when a dark floor is inspected
# immediately, "call" when the player must call the foreman. Definitions
# depend only on the boundary phase and are built once per phase.
func stages() -> Array[Dictionary]:
	if not _stage_cache.has(boundary_phase):
		_stage_cache[boundary_phase] = _build_stages()
	return _stage_cache[boundary_phase]


func _build_stages() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = [
		{
			"id": "red_one_tap", "title": "赤いちらつきを直そう", "size": 3, "inspect": "auto",
			"hidden": {4: RED}, "preset": {}, "target": 4,
			"lines": {"open": "赤い床がちらついてるね。\n真ん中を1回タップして、\n赤い配線でちらつきを消そう！", "ok": "いいぞ！\n赤い床のちらつきが\n直ったね！"},
		},
		{
			"id": "blue_two_taps", "title": "青いちらつきを直そう", "size": 3, "inspect": "auto",
			"hidden": {4: BLUE}, "preset": {}, "target": 4,
			"lines": {"open": "青い床がちらついてるね。\n真ん中を2回タップして、\n青い配線でちらつきを消そう！", "ok": "いいぞ！\n青い床のちらつきが\n直ったね！"},
		},
		{
			"id": "combined_three_taps", "title": "両方のちらつきを直そう", "size": 3, "inspect": "auto",
			"hidden": {4: BOTH}, "preset": {}, "target": 4,
			"lines": {"open": "赤も青もちらついてるね。\n真ん中を3回タップして、\n両方の配線で直そう！", "ok": "いいぞ！\n赤と青のちらつきが\nどちらも直ったね！"},
		},
		{
			"id": "foreman_inspection", "title": "でも、安全かな？", "size": 3, "inspect": "call",
			"hidden": {4: BOTH}, "preset": {4: BOTH}, "target": -1,
			# This lesson's own label for the call button (others say 「親方を呼ぶ」).
			"call_label": "チェックして！",
			# It does not teach counting yet: no inspection lines or count marks.
			"teaches_counting": false,
			"lines": {"open": "ちらつきは全部消えたね。\nでも、電気がもれてるかも。\n安全かどうかチェックしよう！", "lit": "光る床がある。\n暗くしてから呼んでね。",
				"dark": "暗くなった。\n親方を呼ぼう。", "ok": "よし、電気はもれてないね。\nこれで安心！",
				# Spoken while the foreman checks after being called (the view's presentation).
				"call": "電気がもれていないか、\nチェックするよ！"},
		},
		# Lessons 5-7 show the check visually ("counts_pairs"): on a leak the
		# leaving colour's remaining sockets light up and its light runs along
		# the real leak route to a warning lamp outside the board; a bubble tap
		# shows the optional detail, the leftovers on each colour's inspection
		# line (red: top row, blue: left column) vanishing two by two ("focus"
		# colours first, the other colour too whenever it has leftovers).
		{
			"id": "crossing_trap", "title": "暗いのに安全じゃない？", "size": 3, "inspect": "call",
			"hidden": {4: RED}, "preset": {}, "target": -1,
			"call_label": "チェックして！", "counts_pairs": true, "focus": [RED],
			# An experiment, not a repair: from the fault alone the bottom button
			# places red on the top socket, then the bottom one (the foreman's
			# hand, the same corrections a tap makes), then checks the dark but
			# unsafe floor. Any tap on the board or a check ends it and keeps the
			# actual board.
			"demo": [{"node": 1, "label": "上に赤を置く", "line": "上に赤を置いたよ。\n赤い配線は、となりの\n赤い床につながるよ。"},
				{"node": 7, "label": "下に赤を置く", "line": "ちらつきは消えたね。\nでも、安全かな？"}],
			# The leak of this lesson says why a dark floor is not yet fixed.
			"leak": "暗いのに、%s電気が\n外へ抜けているよ！\n暗いだけでは足りないね。",
			"lines": {"open": "上と下に赤を置くと、\nどうなるかな？",
				"lit": "光る床がある。\nまず全部暗くしよう。",
				"dark": "暗くなったね。\nチェックしよう！", "dark_seen": "暗くなったね。\nもう一度チェックしよう！",
				# Spoken while the foreman checks after being called (the view's presentation).
				"call": "電気がもれていないか、\nチェックするよ！",
				"ok": "よし、もう外へ抜けないね。\nこれで安心！"},
		},
		{
			"id": "boundary_single", "title": "はしっこの床", "size": 3, "inspect": "auto",
			"hidden": {0: RED} if boundary_phase == 0 else {2: BLUE},
			"preset": {}, "target": 0 if boundary_phase == 0 else 2,
			"counts_pairs": true, "focus": [RED] if boundary_phase == 0 else [BLUE],
			"lines": {"open": "はしっこの床は\n1つだけ光ることがあるよ。\n左上を1回タップしよう！", "ok": "いいぞ！\nもう外へ抜けないね。"}
				if boundary_phase == 0 else
				{"open": "次は青。\n右上を2回タップしよう！", "ok": "いいぞ！\nもう外へ抜けないね。"},
		},
		{
			"id": "graduation_3x3", "title": "自分でやってみよう", "size": 3, "inspect": "call",
			"hidden": {4: RED, 2: BLUE}, "preset": {}, "target": -1,
			"call_label": "チェックして！", "counts_pairs": true, "focus": [RED, BLUE],
			"lines": {"open": "赤と青がちらついてるね。\n全部暗くして、\nチェックしよう！", "lit": "光る床がある。\nまず全部暗くしよう。",
				"dark": "暗くなったね。\nチェックしよう！", "ok": "よし、もう外へ抜けないね。\n全部できた！"},
		},
	]

	for d in definitions:
		_with_geometry(d)
	return definitions


func _with_geometry(d: Dictionary) -> Dictionary:
	d.red_faces = _faces(int(d.size), RED)
	d.blue_faces = _faces(int(d.size), BLUE)
	d.red_checks = []
	d.blue_checks = []
	for face in d.red_faces:
		d.red_checks.append(face.nodes)
	for face in d.blue_faces:
		d.blue_checks.append(face.nodes)
	d.red_cut = []
	d.blue_cut = []
	for i in int(d.size):
		d.red_cut.append(i)
		d.blue_cut.append(i * int(d.size))
	d.witness_red = [1, 4, 7] if int(d.size) == 3 else [2, 7, 12, 17, 22]
	d.witness_blue = []
	return d

# Independently constructed rotated surface-code checks. RED is X correction,
# detected by Z checks; BLUE is Z correction, detected by X checks.
func _faces(size: int, component: int) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	for row in size - 1:
		for column in size - 1:
			if ((row + column) % 2 == 0) == (component == RED):
				var q := row * size + column
				faces.append({"nodes": [q, q + 1, q + size, q + size + 1],
					"center": Vector2(column + 1, row + 1), "extent": Vector2(0.96, 0.96)})
	for i in size - 1:
		if component == RED:
			var column := 0 if i % 2 == 1 else size - 1
			faces.append({"nodes": [i * size + column, (i + 1) * size + column],
				"center": Vector2(0.25 if column == 0 else size - 0.25, i + 1),
				"extent": Vector2(0.44, 0.96)})
		else:
			var row := 0 if i % 2 == 0 else size - 1
			faces.append({"nodes": [row * size + i, row * size + i + 1],
				"center": Vector2(i + 1, 0.25 if row == 0 else size - 0.25),
				"extent": Vector2(0.96, 0.44)})
	return faces


func definition() -> Dictionary:
	return stages()[stage_index]


# The diagonal a colour's wire takes on a socket (1 is "＼", -1 is "／"), so
# that its ends point at the floors of that colour it changes. Around a
# socket the floors alternate, so one colour's floors lie on one diagonal and
# the other colour's on the other; on the centre red is "＼". A socket without
# a floor of a colour takes the diagonal the other colour leaves.
func wire_slant(node: int, component: int) -> int:
	var own := _slant_toward(node, component)
	if own != 0:
		return own
	var other := _slant_toward(node, BLUE if component == RED else RED)
	if other != 0:
		return -other
	return 1 if component == RED else -1


func _slant_toward(node: int, component: int) -> int:
	var d := definition()
	var size := int(d.size)
	var at := Vector2(node % size + 0.5, node / size + 0.5)
	var slant := 0
	for face in (d.red_faces if component == RED else d.blue_faces):
		if node in face.nodes:
			var to: Vector2 = face.center - at
			var toward := int(signf(to.x) * signf(to.y))
			assert(slant == 0 or slant == toward, "a colour's floors around a socket lie on one diagonal")
			slant = toward
	return slant


# The bottom button's label while it calls the foreman, or names the
# demonstration's next placement.
func call_label() -> String:
	if demo_next():
		return String(demo_steps()[demo_step].label)
	return String(definition().get("call_label", "親方を呼ぶ"))


func auto_inspects() -> bool:
	return String(definition().inspect) == "auto"


# The board is editable at once and stays editable after any verdict.
func tap_node(row: int, column: int) -> bool:
	if finished:
		return false
	var size: int = definition().size
	if row < 0 or row >= size or column < 0 or column >= size:
		return false
	var node := row * size + column
	corrections[node] = (corrections[node] + 1) % 4
	touched = true
	# The player takes over from the demonstration, from the actual board.
	demo_over = true
	inspection = {}
	_record("tap_node", {"row": row, "column": column, "state": corrections[node]})
	if auto_inspects() and is_dark():
		_inspect(true)
	return true


func can_call_foreman() -> bool:
	return not finished and not auto_inspects() and is_dark() and inspection.is_empty()


func inspect_floor() -> Dictionary:
	if not can_call_foreman():
		return {}
	return _inspect(false)


func _inspect(automatic: bool) -> Dictionary:
	demo_over = true
	inspection = _inspect_residual()
	if not bool(inspection.safe):
		leak_count += 1
	var payload := inspection.duplicate(true)
	payload["auto"] = automatic
	_record("inspect", payload)
	return inspection


func _inspect_residual() -> Dictionary:
	var red := _residual_support(RED)
	var blue := _residual_support(BLUE)
	var d := definition()
	return Inspection.inspect(
		red, blue,
		PackedInt32Array(d.red_cut), PackedInt32Array(d.blue_cut),
		PackedInt32Array(d.witness_red), PackedInt32Array(d.witness_blue))


# Passing needs a dark floor AND an explicitly safe inspection of this board.
func passed() -> bool:
	return not finished and not inspection.is_empty() and bool(inspection.safe) and is_dark()


func can_continue() -> bool:
	return passed()


func next_stage() -> bool:
	if not can_continue():
		return false
	if definition().id == "boundary_single" and boundary_phase == 0:
		boundary_phase = 1
		_reset_stage()
		_record("boundary_blue", {})
		return true
	if stage_index == stages().size() - 1:
		finished = true
		inspection = {}
		_record("tutorial_complete", {})
		return true
	stage_index += 1
	_reset_stage()
	_record("next_stage", {"stage": definition().id})
	return true


# Skipping the optional practice ends the tutorial without a pass.
func skip_graduation() -> bool:
	if definition().id != "graduation_3x3" or finished:
		return false
	finished = true
	skipped = true
	inspection = {}
	_record("skip_graduation", {})
	return true


func restart() -> void:
	stage_index = 0
	boundary_phase = 0
	finished = false
	skipped = false
	_reset_stage()
	_record("restart", {})


func is_dark() -> bool:
	return lit_red_checks().is_empty() and lit_blue_checks().is_empty()


func lit_red_checks() -> Array[int]:
	return _lit_checks(RED)


func lit_blue_checks() -> Array[int]:
	return _lit_checks(BLUE)


# The original fault is shown only after an inspection found a leak: on the
# leaking board itself, and in lesson 5 for the rest of the repair.
func fault_revealed() -> bool:
	# Lessons 5-7 show where the electricity leaves, not the original fault.
	if finished or counts_pairs():
		return false
	if not inspection.is_empty() and not bool(inspection.safe):
		return true
	return leak_seen and definition().id == "crossing_trap"


func progress() -> float:
	if finished:
		return 1.0
	return (stage_index + 0.5 * boundary_phase) / float(stages().size())


# The foreman's single latest utterance, derived from the current board.
func utterance() -> Dictionary:
	if finished:
		return {"kind": "done", "text": SKIPPED_TEXT if skipped else DONE_TEXT}
	var lines: Dictionary = definition().lines
	if passed():
		return {"kind": "safe", "text": lines.ok}
	if not inspection.is_empty():
		return {"kind": "unsafe", "text": _leak_line()}
	if demo_active() and demo_step > 0:
		return {"kind": "demo", "text": String(demo_steps()[demo_step - 1].line)}
	if not touched:
		return {"kind": "start", "text": lines.open}
	if not is_dark():
		return {"kind": "mistake", "text": _lit_line()}
	var dark := String(lines.get("dark_seen" if leak_seen and lines.has("dark_seen") else "dark", lines.open))
	return {"kind": "ready", "text": dark}


func _leak_line() -> String:
	var d := definition()
	if counts_pairs():
		var red_leaves := bool(inspection.get("red_crossing", false))
		var blue_leaves := bool(inspection.get("blue_crossing", false))
		var family := "both" if red_leaves and blue_leaves else ("red" if red_leaves else "blue")
		if d.has("leak"):
			return String(d.leak) % {"red": "赤い", "blue": "青い", "both": "赤と青の"}[family]
		return String(LEAVING[family])
	var red := bool(inspection.get("red_crossing", false))
	var blue := bool(inspection.get("blue_crossing", false))
	var color: String = LEAK_COLOR["both" if red and blue else ("red" if red else "blue")]
	if auto_inspects():
		return LEAK_AUTO + color
	if d.id == "crossing_trap":
		# The full explanation describes exactly the untouched trap.
		if leak_count == 1 and _matches(d.preset):
			return String(d.lines.explain)
		if leak_count > 1:
			return LEAK_AGAIN + color
	return LEAK_CALL + color


# A specific hint only while it describes the actual board.
func _lit_line() -> String:
	var d := definition()
	var lines: Dictionary = d.lines
	if lines.has("lit"):
		return String(lines.lit)
	var target: int = d.target
	var others_clean := true
	for node in corrections.size():
		if node != target and corrections[node] != int(d.hidden.get(node, EMPTY)):
			others_clean = false
	var at_target := corrections[target] if target >= 0 else EMPTY
	match String(d.id):
		"red_one_tap":
			if others_clean:
				return LIT_HINTS.red_one_tap
		"blue_two_taps":
			if others_clean and at_target == RED:
				return LIT_HINTS.blue_two_taps
		"combined_three_taps":
			if others_clean and at_target in [RED, BLUE]:
				return LIT_HINTS.combined_three_taps
	return LIT_GENERIC


# The detailed check's result, from the real counts on the reported lines.
func detail_result() -> String:
	var left: Array[int] = []
	for component in counted_components():
		if cut_marks(component).size() % 2 == 1:
			left.append(component)
	if left.is_empty():
		return DETAIL_ALL_GONE
	return String(DETAIL_LEFT["both" if left.size() == 2 else ("red" if left[0] == RED else "blue")])


func demo_steps() -> Array:
	return definition().get("demo", [])


# The demonstration (its last line included) is shown until the player taps
# the board or checks.
func demo_active() -> bool:
	return not finished and not demo_steps().is_empty() and not demo_over


# A placement of the demonstration is next (the bottom button makes it).
func demo_next() -> bool:
	return demo_active() and demo_step < demo_steps().size()


# The demonstration's next placement: a real correction of the board,
# recorded as the foreman's. False when nothing is left to place.
func advance_demo() -> bool:
	if not demo_next():
		return false
	var node := int(demo_steps()[demo_step].node)
	corrections[node] = RED
	demo_step += 1
	_record("demo_place", {"node": node, "state": corrections[node]})
	return true


# The socket the demonstration placed last, or -1.
func demo_node() -> int:
	if not demo_active() or demo_step == 0:
		return -1
	return int(demo_steps()[demo_step - 1].node)


# Runs the whole demonstration (tests and headless runs).
func play_demo() -> void:
	while advance_demo():
		pass


func counts_pairs() -> bool:
	return bool(definition().get("counts_pairs", false))


# A colour's leftovers (fault XOR wiring) on its inspection line, in line order.
func cut_marks(component: int) -> Array[int]:
	var d := definition()
	var residual := _residual_support(component)
	var marks: Array[int] = []
	for node in (d.red_cut if component == RED else d.blue_cut):
		if residual.has(int(node)):
			marks.append(int(node))
	return marks


# The colours a check reports: the lesson's focus colours, then the other
# colour whenever it has leftovers anywhere (it may be what fails).
func counted_components() -> Array[int]:
	var result: Array[int] = []
	for component in definition().get("focus", [RED, BLUE]):
		result.append(int(component))
	for component in [RED, BLUE]:
		if not result.has(component) and not _residual_support(component).is_empty():
			result.append(component)
	return result


func _matches(wiring: Dictionary) -> bool:
	for node in corrections.size():
		if corrections[node] != int(wiring.get(node, EMPTY)):
			return false
	return true


func semantic_state() -> Dictionary:
	var d := definition()
	var correction_values: Array[int] = []
	for value in corrections:
		correction_values.append(value)
	var last_action: Dictionary = trace[-1].duplicate(true) if not trace.is_empty() else {}
	return {
		"schema": "disco-breaker-tutorial-state.v2",
		"stage": stage_index + 1,
		"stage_id": d.id,
		"stage_count": stages().size(),
		"boundary_phase": boundary_phase,
		"title": d.title,
		"grid_size": d.size,
		"inspection_mode": d.inspect,
		"target": d.target,
		"finished": finished,
		"skipped": skipped,
		"corrections": correction_values,
		"lit_red": lit_red_checks(),
		"lit_blue": lit_blue_checks(),
		"floor_dark": is_dark(),
		"inspected": not inspection.is_empty(),
		"inspection": inspection.duplicate(true),
		"passed": passed(),
		"can_call_foreman": can_call_foreman(),
		"can_continue": can_continue(),
		"fault_revealed": fault_revealed(),
		"leak_seen": leak_seen,
		"demo_active": demo_active(),
		"demo_next": demo_next(),
		"demo_step": demo_step,
		"utterance": utterance(),
		"progress": progress(),
		"action_count": trace.size(),
		"last_action": last_action,
	}


func trace_json_lines() -> String:
	var lines: PackedStringArray = []
	for entry in trace:
		lines.append(JSON.stringify(entry))
	return "\n".join(lines) + "\n"


func _reset_stage() -> void:
	var d := definition()
	corrections = PackedInt32Array()
	corrections.resize(d.size * d.size)
	for key in d.preset:
		corrections[int(key)] = int(d.preset[key])
	inspection = {}
	touched = false
	leak_count = 0
	demo_step = 0
	demo_over = false


func _lit_checks(component: int) -> Array[int]:
	var d := definition()
	var checks: Array = d.red_checks if component == RED else d.blue_checks
	var hidden: Dictionary = d.hidden
	var result: Array[int] = []
	for check_index in checks.size():
		var parity := 0
		for node in checks[check_index]:
			parity ^= 1 if (int(hidden.get(node, EMPTY)) & component) != 0 else 0
			parity ^= 1 if (corrections[node] & component) != 0 else 0
		if parity == 1:
			result.append(check_index)
	return result


func _residual_support(component: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var hidden: Dictionary = definition().hidden
	for node in corrections.size():
		var hidden_component := (int(hidden.get(node, EMPTY)) & component) != 0
		var correction_component := (corrections[node] & component) != 0
		if hidden_component != correction_component:
			result.append(node)
	return result


func _record(action: String, payload: Dictionary) -> void:
	_sequence += 1
	trace.append({
		"sequence": _sequence,
		"action": action,
		"payload": payload.duplicate(true),
		"stage_id": definition().id,
		"floor_dark": is_dark(),
	})
