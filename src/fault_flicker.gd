class_name FaultFlicker
extends RefCounted


# Stateless, reproducible failing-lamp envelopes. No random generator touches
# game state; each lamp has its own period, phase and per-cycle blink pattern.
static func brightness(key: int, time: float, reduced_motion: bool = false) -> float:
	if reduced_motion:
		return 1.0
	var period := 3.4 + _noise(key, 0, 0) * 2.7
	var clock := maxf(time, 0.0) + _noise(key, 0, 1) * period
	var cycle := int(floor(clock / period))
	var cursor := fposmod(clock, period)
	var steady := 0.86 + _noise(key, cycle, 2) * 0.14
	var hold := 1.2 + _noise(key, cycle, 3) * 0.8
	if cursor < hold:
		return steady
	cursor -= hold
	var count := 2 + int(_noise(key, cycle, 4) * 3.0)
	for blink in count:
		var off_time := 0.045 + _noise(key, cycle, 5 + blink * 3) * 0.07
		if cursor < off_time:
			return 0.025 + _noise(key, cycle, 6 + blink * 3) * 0.09
		cursor -= off_time
		var on_time := 0.075 + _noise(key, cycle, 7 + blink * 3) * 0.09
		if cursor < on_time:
			return 0.68 + _noise(key, cycle, 20 + blink) * 0.25
		cursor -= on_time
	# A weak, hesitant recovery after the short blink burst.
	var recovery := 0.18 + _noise(key, cycle, 30) * 0.28
	if cursor < recovery:
		return 0.26 + _noise(key, cycle, 31) * 0.18
	return steady


static func _noise(key: int, cycle: int, stream: int) -> float:
	var value := posmod(key * 7919 + cycle * 104729 + stream * 15485863, 2147483647)
	value = posmod(value * 48271 + 12345, 2147483647)
	value = posmod(value * 48271 + 12345, 2147483647)
	return float(value) / 2147483647.0
