extends SceneTree

const Point = preload("res://spd_point.gd")
const Room = preload("res://spd_room.gd")
const Door = preload("res://spd_room_door.gd")
const Random = preload("res://spd_random.gd")


func _initialize() -> void:
	var rng = Random.new(31)
	var left = Room.new(rng, 0, 0, 4, 4)
	var right = Room.new(rng, 4, 1, 8, 5)
	if left.width() != 5 or left.height() != 5 \
			or not left.inside(Point.new(2, 2)) or left.inside(Point.new(0, 2)):
		_fail("Room inclusive dimensions or strict interior differ")
		return
	if left.item_placeable_points(null).size() != 9:
		_fail("Room item placement did not use the inner perimeter")
		return
	if not left.connect_room(right) or left.cur_connections(Room.RIGHT) != 1 \
			or right.cur_connections(Room.LEFT) != 1:
		_fail("Room adjacency and directional connection differ")
		return
	var door = Door.new(4, 2)
	left.connected[right] = door
	right.connected[left] = door
	if left.edges().size() != 1:
		_fail("open Room.Door did not form a traversable graph edge")
		return
	door.set_type(Door.Type.LOCKED)
	if not left.edges().is_empty():
		_fail("locked Room.Door was treated as traversable")
		return
	door.lock_type_changes(true)
	door.set_type(Door.Type.WALL)
	if door.type != Door.Type.LOCKED or door.store_in_bundle()["type"] != Door.Type.LOCKED:
		_fail("Room.Door lock or enum precedence differs")
		return
	left.clear_connections()
	if not left.connected.is_empty() or not right.connected.is_empty() \
			or right.neigbours.has(left):
		_fail("Room.clearConnections left a reverse link")
		return
	print("SPD Java Room geometry and Door graph passed")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
