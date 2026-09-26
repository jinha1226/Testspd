extends SceneTree

const SpdPathFinder = preload("res://spd_pathfinder.gd")


func _initialize() -> void:
	var grid := PackedByteArray()
	grid.resize(7 * 7)
	grid.fill(1)
	for y in range(1, 6):
		grid[3 + y * 7] = 0
	var path: Array[Vector2i] = SpdPathFinder.find_path(7, 7,
		Vector2i(2, 3), Vector2i(4, 3), grid)
	if path.is_empty() or path.back() != Vector2i(4, 3) \
			or path.front() == Vector2i(2, 3):
		_fail("PathFinder did not route around the barrier")
		return
	for cell in path:
		if grid[cell.x + cell.y * 7] == 0:
			_fail("PathFinder crossed an impassable cell")
			return
	grid[3] = 0
	grid[3 + 6 * 7] = 0
	if not SpdPathFinder.find_path(7, 7, Vector2i(2, 3), Vector2i(4, 3), grid).is_empty():
		_fail("PathFinder crossed a sealed barrier")
		return
	var open := PackedByteArray()
	open.resize(9 * 9)
	for y in range(1, 8):
		for x in range(1, 8):
			open[x + y * 9] = 1
	var away := SpdPathFinder.distance_map(9, 9, Vector2i(4, 4), open, 3)
	if away[4 + 4 * 9] != 0 or away[4 + 6 * 9] != 2 \
			or away[1 + 1 * 9] != 3 or away[0] != 2147483647:
		_fail("PathFinder.buildDistanceMap limit or neighbor order differs")
		return
	var retreat := SpdPathFinder.get_step_back(9, 9, Vector2i(4, 5),
		Vector2i(4, 4), 3, open, true)
	if retreat.x < 1 or retreat.y < 1 or away[retreat.x + retreat.y * 9] != 2:
		_fail("PathFinder.getStepBack failed to increase distance from a threat")
		return
	var sealed := open.duplicate()
	retreat = SpdPathFinder.get_step_back(9, 9, Vector2i(4, 5),
		Vector2i(4, 4), 3, sealed, false)
	if retreat.x < 1 or retreat.y < 1 or away[retreat.x + retreat.y * 9] != 2 \
			or sealed[4 + 4 * 9] != 0:
		_fail("PathFinder.getStepBack allowed a retreat toward the threat")
		return
	print("SPD PathFinder passed: detours, distance maps, and retreat")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
