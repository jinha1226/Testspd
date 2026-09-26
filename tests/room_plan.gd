extends SceneTree

const Run = preload("res://run.gd")

const STANDARD_MIN := [4, 5, 6, 6, 8]
const STANDARD_MAX := [6, 6, 7, 8, 9]
const SPECIAL_MIN := [1, 1, 2, 2, 2]
const SPECIAL_MAX := [2, 3, 3, 3, 3]


func _initialize() -> void:
	for seed_value in range(1, 21):
		var run = Run.new()
		run.start(seed_value)
		for depth in range(1, 25):
			if depth % 5 == 0:
				continue
			run.depth = depth
			if depth != 1:
				run._build_floor()
			var region: int = int((depth - 1) / 5)
			var standards: int = run.room_kinds.count("standard")
			var specials: int = run.room_kinds.count("special_placeholder")
			if standards < STANDARD_MIN[region] or standards > STANDARD_MAX[region] \
					or specials < SPECIAL_MIN[region] or specials > SPECIAL_MAX[region]:
				_fail("wrong room quota on depth %d seed %d" % [depth, seed_value])
				return
			if run.room_kinds.front() != "entrance" or run.room_kinds.back() != "exit" \
					or run.rooms.size() != run.room_kinds.size():
				_fail("missing entrance/exit room metadata")
				return
			for a in range(run.rooms.size()):
				var room: Rect2i = run.rooms[a]
				if room.position.x < 1 or room.position.y < 1 \
						or room.end.x >= Run.WIDTH or room.end.y >= Run.HEIGHT:
					_fail("room lies outside safe map border")
					return
				for b in range(a + 1, run.rooms.size()):
					if room.grow(1).intersects(run.rooms[b]):
						_fail("rooms overlap on depth %d seed %d" % [depth, seed_value])
						return
			if not _all_rooms_reachable(run):
				_fail("room graph is disconnected on depth %d seed %d" % [depth, seed_value])
				return
			for mob in run.mobs:
				for index in range(run.rooms.size()):
					if run.room_kinds[index] == "special_placeholder" \
							and run.rooms[index].has_point(mob["pos"]):
						_fail("regular enemy spawned in an unported special room")
						return
	print("SPD room quotas passed: 20 seeds x 20 regular depths, connected rooms")
	quit()


func _all_rooms_reachable(run) -> bool:
	var seen := {run.hero: true}
	var queue: Array[Vector2i] = [run.hero]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for direction in Run.DIRS8:
			var next: Vector2i = cell + direction
			if seen.has(next) or Run.is_wall_tile(run.tile_at(next)):
				continue
			seen[next] = true
			queue.append(next)
	for room in run.rooms:
		if not seen.has(run._room_center(room)):
			return false
	return true


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
