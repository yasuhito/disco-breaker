class_name TextLayout
extends RefCounted


## Use Godot's Unicode line breaking for Japanese and space-separated words.
## Explicit newlines remain hard breaks; adaptive wrapping also handles a
## single word wider than the column.
static func wrap_lines(font: Font, text: String, font_size: int, width: float) -> PackedStringArray:
	var result := PackedStringArray()
	for paragraph in text.split("\n", true):
		if paragraph.is_empty():
			result.append("")
			continue
		var layout := TextParagraph.new()
		layout.width = width
		layout.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		layout.add_string(paragraph, font, font_size, "ja")
		for index in layout.get_line_count():
			var span := layout.get_line_range(index)
			result.append(paragraph.substr(span.x, span.y - span.x).strip_edges())
	return result


static func fits(font: Font, lines: PackedStringArray, font_size: int, width: float) -> bool:
	for line in lines:
		if _width(font, line, font_size) > width + 0.01:
			return false
	return true


static func _width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
