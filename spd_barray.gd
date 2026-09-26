extends RefCounted
## com.watabou.utils.BArray at SPD 2bb34a4e91d2.
## Java boolean[] is represented by PackedByteArray of zeros and ones.


static func set_false(values: PackedByteArray) -> void:
	values.fill(0)


static func and_arrays(a: PackedByteArray, b: PackedByteArray,
		result: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	result.resize(a.size())
	for index in range(a.size()):
		result[index] = 1 if a[index] != 0 and b[index] != 0 else 0
	return result


static func or_arrays(a: PackedByteArray, b: PackedByteArray,
		result: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	return or_range(a, b, 0, a.size(), result)


static func or_range(a: PackedByteArray, b: PackedByteArray,
		offset: int, length: int,
		result: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	if result.is_empty():
		result.resize(length)
	for index in range(offset, offset + length):
		result[index] = 1 if a[index] != 0 or b[index] != 0 else 0
	return result


static func not_array(a: PackedByteArray,
		result: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	result.resize(a.size())
	for index in range(a.size()):
		result[index] = 1 if a[index] == 0 else 0
	return result


static func is_value(a: PackedInt32Array, value: int,
		result: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	result.resize(a.size())
	for index in range(a.size()):
		result[index] = 1 if a[index] == value else 0
	return result


static func is_one_of(a: PackedInt32Array, values: Array[int],
		result: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	result.resize(a.size())
	for index in range(a.size()):
		result[index] = 0
		for value in values:
			if a[index] == value:
				result[index] = 1
				break
	return result


static func is_not(a: PackedInt32Array, value: int,
		result: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	result.resize(a.size())
	for index in range(a.size()):
		result[index] = 1 if a[index] != value else 0
	return result


static func is_not_one_of(a: PackedInt32Array, values: Array[int],
		result: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	result.resize(a.size())
	for index in range(a.size()):
		result[index] = 1
		for value in values:
			if a[index] == value:
				result[index] = 0
				break
	return result
