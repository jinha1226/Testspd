extends SceneTree

const Run = preload("res://run.gd")
const Spawner = preload("res://spd_regular_spawner.gd")


func _initialize() -> void:
	for seed_value in range(1, 65):
		var run = Run.new()
		run.start(seed_value)
		if run.mobs.size() != 8:
			_fail("floor 1 failed to place eight initial mobs on seed %d" % seed_value)
			return
		var near: PackedByteArray = Spawner._entrance_distance_map(
			Run.WIDTH, Run.HEIGHT, run.tiles, run.rooms.front(),
			run.hero, [Run.WALL, Run.WALL_DECO], Run.CLOSED_DOOR)
		var occupied := {}
		for mob in run.mobs:
			var cell: Vector2i = mob["pos"]
			var index: int = cell.x + cell.y * Run.WIDTH
			var in_interior := false
			for room in run.rooms:
				if Spawner._inside_room(cell, room):
					in_interior = true
					break
			if not in_interior or run.visible[index] != 0 or near[index] != 0 \
					or occupied.has(cell) or cell == run.stairs \
					or Run.is_wall_tile(run.tile_at(cell)) \
					or run.tile_at(cell) == Run.CLOSED_DOOR:
				_fail("invalid regular mob position at seed %d: %s" % [seed_value, cell])
				return
			occupied[cell] = true
	# The FOV check alone misses an open corridor that bends around a wall.
	var tiles := PackedInt32Array()
	tiles.resize(20 * 20)
	tiles.fill(Run.WALL)
	for x in range(2, 17):
		tiles[3 * 20 + x] = Run.FLOOR
	var near: PackedByteArray = Spawner._entrance_distance_map(
		20, 20, tiles, Rect2i(1, 1, 6, 6), Vector2i(3, 3),
		[Run.WALL], Run.CLOSED_DOOR)
	if near[12 + 3 * 20] != 0 or near[11 + 3 * 20] == 0:
		_fail("eight-step entrance exclusion used an incorrect walk distance")
		return
	print("SPD regular spawn placement passed: 64 floor seeds and entrance distance")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
