extends SceneTree

const BArray = preload("res://spd_barray.gd")


func _initialize() -> void:
	var a := PackedByteArray([1, 0, 1, 0])
	var b := PackedByteArray([1, 1, 0, 0])
	if BArray.and_arrays(a, b) != PackedByteArray([1, 0, 0, 0]) \
			or BArray.or_arrays(a, b) != PackedByteArray([1, 1, 1, 0]) \
			or BArray.not_array(a) != PackedByteArray([0, 1, 0, 1]):
		_fail("BArray boolean operations differ")
		return
	var source := PackedInt32Array([2, 3, 4, 2])
	if BArray.is_value(source, 2) != PackedByteArray([1, 0, 0, 1]) \
			or BArray.is_one_of(source, [2, 4]) != PackedByteArray([1, 0, 1, 1]) \
			or BArray.is_not(source, 2) != PackedByteArray([0, 1, 1, 0]) \
			or BArray.is_not_one_of(source, [2, 4]) != PackedByteArray([0, 1, 0, 0]):
		_fail("BArray integer predicates differ")
		return
	BArray.set_false(a)
	if a != PackedByteArray([0, 0, 0, 0]):
		_fail("BArray.setFalse did not mutate its input")
		return
	var result := PackedByteArray([9, 9, 9, 9])
	BArray.or_range(a, b, 1, 2, result)
	if result != PackedByteArray([9, 1, 0, 9]):
		_fail("BArray.or(offset,length) modified outside its slice")
		return
	print("SPD Java BArray methods passed")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
