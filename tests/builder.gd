extends SceneTree

const Point = preload("res://spd_point.gd")
const Random = preload("res://spd_random.gd")
const Builder = preload("res://spd_builder.gd")
const FixedRoom = preload("res://tests/fixed_room.gd")


func _initialize() -> void:
	var rng = Random.new(72)
	var entrance = FixedRoom.new(rng, 0, 0, 4, 4)
	var east = FixedRoom.new(rng)
	var angle = Builder.place_room([entrance], entrance, east, 90.0, rng)
	if not is_equal_approx(angle, 90.0) or east.left != 4 or east.right != 8 \
			or east.top != 0 or east.bottom != 4 \
			or not entrance.connected.has(east):
		_fail("Builder.placeRoom did not attach the eastern room on the shared edge")
		return
	var north = FixedRoom.new(rng)
	angle = Builder.place_room([entrance, east], entrance, north, 0.0, rng)
	if angle < -0.5 or north.bottom != entrance.top or not entrance.connected.has(north):
		_fail("Builder.placeRoom did not attach a northern room")
		return
	var free = Builder.find_free_space(Point.new(4, 2), [entrance], 5, rng)
	if free.left != 4 or free.right != 9:
		_fail("Builder.findFreeSpace did not exclude the colliding room")
		return
	Builder.find_neighbours([entrance, east, north])
	if not entrance.neigbours.has(east) or not entrance.neigbours.has(north):
		_fail("Builder.findNeighbours omitted edge-adjacent rooms")
		return
	entrance.clear_connections()
	east.clear_connections()
	north.clear_connections()
	print("SPD Java Builder room placement passed")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
