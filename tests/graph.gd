extends SceneTree

const Graph = preload("res://spd_graph.gd")
const Random = preload("res://spd_random.gd")
const FixedRoom = preload("res://tests/fixed_room.gd")
const Door = preload("res://spd_room_door.gd")


func _initialize() -> void:
	var rng = Random.new(3)
	var a = FixedRoom.new(rng, 0, 0, 4, 4)
	var b = FixedRoom.new(rng, 4, 0, 8, 4)
	var c = FixedRoom.new(rng, 8, 0, 12, 4)
	if not a.connect_room(b) or not b.connect_room(c):
		_fail("Room graph did not connect adjacent rooms")
		return
	a.connected[b] = Door.new(4, 2)
	b.connected[a] = a.connected[b]
	b.connected[c] = Door.new(8, 2)
	c.connected[b] = b.connected[c]
	Graph.set_price([a, b, c], 1)
	Graph.build_distance_map([a, b, c], c)
	if a.distance != 2 or b.distance != 1 or c.distance != 0:
		_fail("Graph.buildDistanceMap differs on a simple chain")
		return
	var path = Graph.build_path([a, b, c], a, c)
	if path != [b, c]:
		_fail("Graph.buildPath failed to follow descending distances")
		return
	b.connected[c].set_type(Door.Type.LOCKED)
	if b.edges().has(c):
		_fail("Room.edges included a locked door")
		return
	Graph.build_distance_map([a, b, c], c)
	if a.distance != Graph.MAX_DISTANCE or Graph.build_path([a, b, c], a, c) != null:
		_fail("Graph allowed a path through a locked door")
		return
	a.clear_connections()
	b.clear_connections()
	c.clear_connections()
	print("SPD Java Graph distance and path passed")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
