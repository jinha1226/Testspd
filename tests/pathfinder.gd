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
	print("SPD PathFinder passed: detours and unreachable goals")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
