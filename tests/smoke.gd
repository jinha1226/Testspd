extends SceneTree

const Run = preload("res://run.gd")
const ShadowCaster = preload("res://spd_shadowcaster.gd")
const SpdCombat = preload("res://spd_combat.gd")


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
		if run.mobs.size() != 8:
			push_error("expected eight preset mobs on floor 1 for seed %d; got %d" % [seed_value, run.mobs.size()])
			quit(1)
			return
		var rats := 0
		var snakes := 0
		for mob in run.mobs:
			if mob["kind"] == "rat":
				rats += 1
			elif mob["kind"] == "snake":
				snakes += 1
			if mob["hp"] != SpdCombat.mob_hp(mob["kind"]) or run.is_visible(mob["pos"]):
				push_error("invalid initial mob for seed %d" % seed_value)
				quit(1)
				return
		if rats != 6 or snakes != 2:
			push_error("wrong depth-1 mob rotation for seed %d" % seed_value)
			quit(1)
			return

	var blocking := PackedByteArray()
	blocking.resize(11 * 11)
	blocking[5 * 11 + 6] = 1
	var fov: PackedByteArray = ShadowCaster.cast_shadow(Vector2i(5, 5), 11, 11, blocking, 8)
	if fov[5 * 11 + 6] != 1 or fov[5 * 11 + 7] != 0 or fov[5 * 11 + 4] != 1:
		push_error("shadowcasting failed to show a wall and hide cells behind it")
		quit(1)
		return
	var combat_rng := RandomNumberGenerator.new()
	combat_rng.seed = 123
	var rat_hits := 0
	var snake_hits := 0
	for trial in range(500):
		if SpdCombat.warrior_attacks_mob(combat_rng, "rat", false)["hit"]:
			rat_hits += 1
		if SpdCombat.warrior_attacks_mob(combat_rng, "snake", false)["hit"]:
			snake_hits += 1
		if not SpdCombat.warrior_attacks_mob(combat_rng, "snake", true)["hit"]:
			push_error("surprise attack against a snake missed")
			quit(1)
			return
	if rat_hits <= snake_hits:
		push_error("snake's original evasion is not reflected in combat")
		quit(1)
		return

	run.start(42)
	run.mobs.clear()
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
	run.mobs.append({"kind": "rat", "pos": neighbor, "hp": SpdCombat.RAT_HP,
		"state": "sleeping", "enemy_seen": false, "target": neighbor})
	var attack_turn: int = run.turns
	var dealt_damage := false
	for attempt in range(12):
		run.step(adjacent)
		if run.mobs.is_empty() or run.mobs[0]["hp"] < SpdCombat.RAT_HP:
			dealt_damage = true
			break
	if run.turns <= attack_turn or run.hero != hero_before or not dealt_damage:
		push_error("attacking an adjacent rat failed")
		quit(1)
		return
	run.mobs.clear()
	var first_turn: int = run.turns
	run.wait_turn()
	if run.turns != first_turn + 1:
		push_error("waiting did not advance the turn")
		quit(1)
		return
	run.hp = 10
	run.potion_count = 1
	if not run.drink_potion() or run.hp != 18 or run.potion_count != 0 or run.healing_left != 22:
		push_error("potion use failed")
		quit(1)
		return
	run.wait_turn()
	if run.hp != run.max_hp or run.healing_left >= 22:
		push_error("potion did not continue healing on the next turn")
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
	print("SPD port smoke passed: 50 connected seeds, FOV, floor-1 mobs, combat, healing, descent")
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
