class_name InspectionSemantics
extends RefCounted


## Classifies the two residual wiring families independently. A cut is a list
## of node indices. Crossing parity is mod 2; witness paths are explanatory
## output created only after the logical class has been computed.
static func inspect(
		red_residual: PackedInt32Array,
		blue_residual: PackedInt32Array,
		red_cut: PackedInt32Array,
		blue_cut: PackedInt32Array,
		red_witness_order: PackedInt32Array = PackedInt32Array(),
		blue_witness_order: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var red_crossing := _odd_intersection(red_residual, red_cut)
	var blue_crossing := _odd_intersection(blue_residual, blue_cut)
	return {
		"red_crossing": red_crossing,
		"blue_crossing": blue_crossing,
		"safe": not red_crossing and not blue_crossing,
		"red_witness": _ordered_witness(red_residual, red_witness_order) if red_crossing else [],
		"blue_witness": _ordered_witness(blue_residual, blue_witness_order) if blue_crossing else [],
	}


static func _odd_intersection(support: PackedInt32Array, cut: PackedInt32Array) -> bool:
	var parity := 0
	for node in support:
		if cut.has(node):
			parity ^= 1
	return parity == 1


static func _ordered_witness(support: PackedInt32Array, preferred: PackedInt32Array) -> Array[int]:
	var witness: Array[int] = []
	for node in preferred:
		if support.has(node):
			witness.append(node)
	if witness.is_empty():
		for node in support:
			witness.append(node)
	return witness
