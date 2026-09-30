class_name LampSoundGate
extends RefCounted

const Flicker := preload("res://src/fault_flicker.gd")
const MIN_GAP := 0.32
const PER_LAMP_GAP := 1.0
var _levels: Dictionary = {}
var _last_by_lamp: Dictionary = {}
var _last_play := -100.0


func reset() -> void:
	# Forget phase edges, but keep the rate limit across rapid input/mute changes.
	_levels.clear()


# Observe the same brightness sample that is drawn this frame. Only a real
# bright-to-dropout edge can sound; first samples, steady light and silence cannot.
func poll(keys: PackedInt32Array, time: float, enabled: bool) -> int:
	if not enabled:
		reset()
		return -1
	var candidate := -1
	for key in keys:
		var level := Flicker.brightness(key, time)
		var previous: float = _levels.get(key, level)
		_levels[key] = level
		if previous >= 0.6 and level < 0.15 and time - _last_play >= MIN_GAP and time - float(_last_by_lamp.get(key, -100.0)) >= PER_LAMP_GAP:
			if candidate < 0:
				candidate = key
	if candidate >= 0:
		_last_play = time
		_last_by_lamp[candidate] = time
	return candidate
