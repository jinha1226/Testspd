extends RefCounted
## Port of watabou.utils.Random's java.util.Random generator and MX3 seed stack.
## Upstream snapshot: 2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f.

const MULTIPLIER := 0x5DEECE66D
const ADDEND := 0xB
const MASK := 0xFFFFFFFFFFFF
const MIX_MULTIPLIER := -4710160504952957587 # 0xbea225f9eb34556d as signed int64

var _states: Array[int] = []


func _init(seed_value: int = 0) -> void:
	reset(seed_value)


func reset(seed_value: int) -> void:
	_states = [(seed_value ^ MULTIPLIER) & MASK]


func push_generator(seed_value: int) -> void:
	_states.append((_scramble_seed(seed_value) ^ MULTIPLIER) & MASK)


func pop_generator() -> void:
	if _states.size() > 1:
		_states.pop_back()


func state_snapshot() -> Array[int]:
	return _states.duplicate()


func restore_state(saved: Array) -> bool:
	if saved.is_empty():
		return false
	for value in saved:
		if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) \
				or value != floorf(float(value)) or value < 0 or value > MASK:
			return false
	_states.clear()
	for value in saved:
		_states.append(int(value))
	return true


func _next_bits(bits: int, use_generator_stack: bool = true) -> int:
	var index := _states.size() - 1 if use_generator_stack else 0
	_states[index] = (_states[index] * MULTIPLIER + ADDEND) & MASK
	return _states[index] >> (48 - bits)


func next_int32(use_generator_stack: bool = true) -> int:
	var value := _next_bits(32, use_generator_stack)
	return value - 0x100000000 if value >= 0x80000000 else value


func next_int(bound: int, use_generator_stack: bool = true) -> int:
	# java.util.Random.nextInt(bound), including rejection of biased 31-bit draws.
	if bound <= 0:
		return 0
	if (bound & (bound - 1)) == 0:
		return (bound * _next_bits(31, use_generator_stack)) >> 31
	while true:
		var bits := _next_bits(31, use_generator_stack)
		var value := bits % bound
		if bits - value + bound - 1 <= 0x7FFFFFFF:
			return value
	return 0


func next_long(use_generator_stack: bool = true) -> int:
	var high := next_int32(use_generator_stack)
	var low := next_int32(use_generator_stack)
	return (high << 32) + low


func randf(use_generator_stack: bool = true) -> float:
	return float(_next_bits(24, use_generator_stack)) / 16777216.0


func randi_range(minimum: int, maximum: int) -> int:
	return minimum + next_int(maximum - minimum + 1)


func float_bounded(maximum: float) -> float:
	return _f32(self.randf() * _f32(maximum))


func float_between(minimum: float, maximum: float) -> float:
	return _f32(_f32(minimum) + float_bounded(_f32(maximum - minimum)))


func normal_float(minimum: float, maximum: float) -> float:
	var span := _f32(maximum - minimum)
	return _f32(_f32(minimum)
		+ _f32(_f32(float_bounded(span) + float_bounded(span)) / 2.0))


func int_between(minimum: int, maximum: int) -> int:
	return minimum + next_int(maximum - minimum)


func normal_int_range(minimum: int, maximum: int) -> int:
	return minimum + int(_f32(_f32(_f32(self.randf() + self.randf())
		* _f32(maximum - minimum + 1)) / 2.0))


func inv_normal_int_range(minimum: int, maximum: int) -> int:
	var roll1 := self.randf()
	var roll2 := self.randf()
	if absf(roll1 - 0.5) >= absf(roll2 - 0.5):
		return minimum + int(_f32(roll1 * _f32(maximum - minimum + 1)))
	return minimum + int(_f32(roll2 * _f32(maximum - minimum + 1)))


func long_bounded(maximum: int) -> int:
	var result := next_long()
	if result < 0:
		result += 9223372036854775807
	return result % maximum


func chances(weights: Array) -> int:
	var total := 0.0
	for weight in weights:
		total = _f32(total + maxf(0.0, _f32(float(weight))))
	if total <= 0.0:
		return -1
	var value := float_bounded(total)
	total = 0.0
	for index in range(weights.size()):
		total = _f32(total + maxf(0.0, _f32(float(weights[index]))))
		if value < total:
			return index
	return -1


func chances_map(weights: Dictionary):
	var keys := weights.keys()
	var probabilities: Array[float] = []
	var total := 0.0
	for key in keys:
		var weight := _f32(float(weights[key]))
		probabilities.append(weight)
		total = _f32(total + weight)
	if total <= 0.0:
		return null
	var value := float_bounded(total)
	total = 0.0
	for index in range(keys.size()):
		total = _f32(total + probabilities[index])
		if value < total:
			return keys[index]
	return null


func index(collection: Array) -> int:
	return next_int(collection.size())


func one_of(values: Array):
	return values[next_int(values.size())]


func element(values: Array, maximum: int = -1):
	if values.is_empty():
		return null
	return values[next_int(values.size() if maximum < 0 else maximum)]


func shuffle_list(values: Array) -> void:
	# java.util.Collections.shuffle uses descending Fisher-Yates.
	for index in range(values.size() - 1, 0, -1):
		var swap_index := next_int(index + 1)
		var old = values[index]
		values[index] = values[swap_index]
		values[swap_index] = old


func shuffle_array(values: Array) -> void:
	# Random.shuffle(T[]) uses ascending Fisher-Yates.
	for index in range(values.size() - 1):
		var swap_index := int_between(index, values.size())
		if swap_index != index:
			var old = values[index]
			values[index] = values[swap_index]
			values[swap_index] = old


func shuffle_pair(first: Array, second: Array) -> void:
	for index in range(first.size() - 1):
		var swap_index := int_between(index, first.size())
		if swap_index != index:
			var old_first = first[index]
			first[index] = first[swap_index]
			first[swap_index] = old_first
			var old_second = second[index]
			second[index] = second[swap_index]
			second[swap_index] = old_second


static func _f32(value: float) -> float:
	# Java float expressions round after each operation, unlike Godot float64.
	return PackedFloat32Array([value])[0]


static func _logical_shift(value: int, amount: int) -> int:
	return (value >> amount) & ((1 << (64 - amount)) - 1)


static func _scramble_seed(seed_value: int) -> int:
	var mixed := seed_value
	mixed ^= _logical_shift(mixed, 32)
	mixed *= MIX_MULTIPLIER
	mixed ^= _logical_shift(mixed, 29)
	mixed *= MIX_MULTIPLIER
	mixed ^= _logical_shift(mixed, 32)
	mixed *= MIX_MULTIPLIER
	mixed ^= _logical_shift(mixed, 29)
	return mixed
