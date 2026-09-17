class_name TextLayout
extends RefCounted


## Greedy word wrapping for canvas-drawn copy. Explicit newlines remain hard
## breaks; every returned line is guaranteed to fit unless one word alone is
## wider than the requested column.
static func wrap_lines(font: Font, text: String, font_size: int, width: float) -> PackedStringArray:
	var result := PackedStringArray()
	for paragraph in text.split("\n", true):
		var words := paragraph.split(" ", false)
		if words.is_empty():
			result.append("")
			continue
		var line := ""
		for word in words:
			var candidate := String(word) if line.is_empty() else line + " " + String(word)
			if line.is_empty() or _width(font, candidate, font_size) <= width:
				line = candidate
			else:
				result.append(line)
				line = String(word)
		result.append(line)
	return result


static func fits(font: Font, lines: PackedStringArray, font_size: int, width: float) -> bool:
	for line in lines:
		if _width(font, line, font_size) > width + 0.01:
			return false
	return true


static func _width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
