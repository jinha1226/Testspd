extends SceneTree

const Random = preload("res://spd_random.gd")


func _initialize() -> void:
	var rng = Random.new(0)
	if absf(rng.float_between(2.0, 5.0) - 4.192903280258179) > 0.000001 \
			or absf(rng.normal_float(1.0, 5.0) - 3.1439547538757324) > 0.000001 \
			or rng.normal_int_range(2, 10) != 7 \
			or rng.inv_normal_int_range(2, 10) != 4 \
			or rng.chances([1.0, 2.0, 4.0]) != 0:
		_fail("Java Random float/range/weight sequence differs")
		return
	rng.reset(0)
	if rng.chances([-2.0, 0.0, 3.0]) != 2 or rng.chances([0.0, -1.0]) != -1:
		_fail("Random.chances must ignore negative weights without drawing for zero total")
		return
	rng.reset(0)
	var list := [0, 1, 2, 3, 4]
	rng.shuffle_list(list)
	if list != [4, 2, 1, 3, 0]:
		_fail("Collections.shuffle(List) Java draw order differs")
		return
	rng.reset(0)
	var array := [0, 1, 2, 3, 4]
	rng.shuffle_array(array)
	if array != [0, 4, 3, 1, 2]:
		_fail("Random.shuffle(T[]) Java draw order differs")
		return
	rng.reset(0)
	array = [0, 1, 2, 3, 4]
	var other := [10, 11, 12, 13, 14]
	rng.shuffle_pair(array, other)
	for index in range(array.size()):
		if array[index] + 10 != other[index]:
			_fail("Random.shuffle(U[], V[]) lost paired positions")
			return
	rng.reset(0)
	rng.push_generator(42)
	var original_base = Random.new(0)
	if rng.next_int32(false) != original_base.next_int32() \
			or rng.randf(false) != original_base.randf() \
			or rng.next_long(false) != original_base.next_long():
		_fail("Random base generator access differs under a seeded stack")
		return
	rng.pop_generator()
	if rng.next_int32() != original_base.next_int32():
		_fail("Random.popGenerator did not preserve base state")
		return
	print("SPD Java Random methods passed")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
