extends SceneTree

const Run = preload("res://run.gd")


func _initialize() -> void:
	var run = Run.new()
	for seed_value in range(1, 51):
		run.start(seed_value)
		if run.rooms.size() < 2 or not _reachable(run):
			push_error("unreachable exit for seed %d" % seed_value)
			quit(1)
			return
		if not run.is_visible(run.hero) or run.tile_at(run.stairs) != Run.EXIT:
			push_error("invalid initial state for seed %d" % seed_value)
			quit(1)
			return

	run.start(42)
	run.rats.clear()
	var adjacent := Vector2i.ZERO
	for direction in Run.DIRS8:
		if run.tile_at(run.hero + direction) == Run.FLOOR:
			adjacent = direction
			break
	if adjacent == Vector2i.ZERO:
		push_error("no free adjacent tile for action test")
		quit(1)
		return
	var neighbor: Vector2i = run.hero + adjacent
	run.tiles[neighbor.y * Run.WIDTH + neighbor.x] = Run.CLOSED_DOOR
	var hero_before: Vector2i = run.hero
	run.step(adjacent)
	if run.hero != hero_before or run.tile_at(neighbor) != Run.OPEN_DOOR:
		push_error("opening a door failed")
		quit(1)
		return
	run.rats.append({"pos": neighbor, "hp": 5})
	var attack_turn: int = run.turns
	run.step(adjacent)
	if run.turns != attack_turn + 1 or run.hero != hero_before or run.rats[0]["hp"] >= 5:
		push_error("attacking an adjacent rat failed")
		quit(1)
		return
	run.rats.clear()
	var first_turn: int = run.turns
	run.wait_turn()
	if run.turns != first_turn + 1:
		push_error("waiting did not advance the turn")
		quit(1)
		return
	run.hp = 10
	run.potion_count = 1
	if not run.drink_potion() or run.hp != 18 or run.potion_count != 0:
		push_error("potion use failed")
		quit(1)
		return
	var moved_down := false
	for direction in Run.DIRS8:
		var stairs_neighbor: Vector2i = run.stairs + direction
		if run.tile_at(stairs_neighbor) != Run.WALL and run.tile_at(stairs_neighbor) != Run.CLOSED_DOOR:
			run.hero = stairs_neighbor
			run.step(-direction)
			moved_down = run.depth == 2
			break
	if not moved_down:
		push_error("descending stairs failed")
		quit(1)
		return
	print("SPD port smoke passed: 50 connected seeds, sight, turns, potion, descent")
	quit()


func _reachable(run) -> bool:
	var queue: Array[Vector2i] = [run.hero]
	var seen := {run.hero: true}
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		if p == run.stairs:
			return true
		for direction in Run.DIRS8:
			var next: Vector2i = p + direction
			if seen.has(next) or run.tile_at(next) == Run.WALL:
				continue
			seen[next] = true
			queue.append(next)
	return false
