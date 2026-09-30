class_name RewardSound
extends RefCounted

const RATE := 22050


# Original, deterministic synth stings; no external recordings or dependencies.
static func make_sting(finale := false) -> AudioStreamWAV:
	var duration := 0.72 if finale else 0.44
	var notes := PackedFloat64Array([523.25, 659.25, 783.99, 1046.50]) if finale else PackedFloat64Array([523.25, 659.25, 783.99])
	var data := PackedByteArray()
	var frames := int(duration * RATE)
	data.resize(frames * 2)
	for frame in frames:
		var time := float(frame) / RATE
		var value := 0.0
		for index in notes.size():
			var age := time - float(index) * 0.075
			if age >= 0.0:
				var envelope := minf(age / 0.008, 1.0) * exp(-age * 12.0)
				var phase := TAU * notes[index] * age
				value += (sin(phase) + 0.2 * sin(phase * 2.0)) * envelope * 0.15
		# A soft low pulse supplies the disco accent without a sharp click.
		value += sin(TAU * 110.0 * time) * minf(time / 0.01, 1.0) * exp(-time * 25.0) * 0.1
		value *= clampf((duration - time) / 0.03, 0.0, 1.0)
		data.encode_s16(frame * 2, int(clampf(value, -0.7, 0.7) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
