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


func _next_bits(bits: int) -> int:
	var index := _states.size() - 1
	_states[index] = (_states[index] * MULTIPLIER + ADDEND) & MASK
	return _states[index] >> (48 - bits)


func next_int32() -> int:
	var value := _next_bits(32)
	return value - 0x100000000 if value >= 0x80000000 else value


func next_int(bound: int) -> int:
	# java.util.Random.nextInt(bound), including rejection of biased 31-bit draws.
	if bound <= 0:
		return 0
	if (bound & (bound - 1)) == 0:
		return (bound * _next_bits(31)) >> 31
	while true:
		var bits := _next_bits(31)
		var value := bits % bound
		if bits - value + bound - 1 <= 0x7FFFFFFF:
			return value
	return 0


func next_long() -> int:
	var high := next_int32()
	var low := next_int32()
	return (high << 32) + low


func randf() -> float:
	return float(_next_bits(24)) / 16777216.0


func randi_range(minimum: int, maximum: int) -> int:
	return minimum + next_int(maximum - minimum + 1)


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
