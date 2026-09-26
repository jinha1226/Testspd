extends SceneTree

const Run = preload("res://run.gd")
const SpdCampaign = preload("res://spd_campaign.gd")
const SpdCombat = preload("res://spd_combat.gd")


func _initialize() -> void:
	var run = Run.new()
	for seed_value in [2, 31, 419]:
		run.start(seed_value)
		for floor_number in range(1, 27):
			run.depth = floor_number
			run._build_floor()
			if not _reachable(run):
				_fail("unreachable exit on depth %d seed %d" % [floor_number, seed_value])
				return
			if floor_number == 26:
				if not run.mobs.is_empty() or run.items.size() != 1 \
						or run.items[0]["kind"] != "amulet":
					_fail("last level should hold the amulet without normal mobs")
					return
			elif SpdCampaign.boss(floor_number) != "":
				if run.mobs.size() != 1 or run.mobs[0]["kind"] != SpdCampaign.boss(floor_number):
					_fail("wrong boss on depth %d" % floor_number)
					return
				if not _boss_gate(run):
					_fail("boss exit was not gated on depth %d" % floor_number)
					return
			else:
				if run.mobs.is_empty() or run.potions.is_empty() or run.items.is_empty():
					_fail("regular floor lacks enemies or supplies on depth %d" % floor_number)
					return
				var rotation := SpdCampaign.rotation(floor_number)
				for mob in run.mobs:
					if not rotation.has(mob["kind"]) or int(mob["hp"]) != SpdCombat.mob_hp(mob["kind"]):
						_fail("wrong mob rotation or HP on depth %d" % floor_number)
						return
	run.start(8472)
	for floor_number in range(1, 26):
		if run.depth != floor_number or not _force_descend(run):
			_fail("stairs did not transition from depth %d" % floor_number)
			return
	if run.depth != 26:
		_fail("the campaign did not reach the last level")
		return
	run.start(981)
	run.mobs.clear()
	run._gain_experience("rat")
	run.experience = 9
	run._gain_experience("rat")
	if run.level != 2 or run.max_hp != 25 or run.hp != 25 or run.experience != 0:
		_fail("hero XP and max HP progression diverged")
		return
	run.food_count = 1
	run.hunger = 400
	run.eat_food()
	if run.food_count != 0 or run.hunger != 103 or run.turns != 3:
		_fail("food did not consume three turns and reduce hunger")
		return
	run.ooze_left = 5
	run.tiles[run.hero.y * Run.WIDTH + run.hero.x] = Run.WATER
	run.wait_turn()
	if run.ooze_left != 0:
		_fail("water did not wash off Goo's ooze")
		return
	run.upgrade_count = 1
	run.upgrade_weapon()
	if run.weapon_level != 1 or run.upgrade_count != 0:
		_fail("weapon upgrade did not consume a scroll")
		return
	var combat_rng := RandomNumberGenerator.new()
	combat_rng.seed = 120
	for trial in range(20):
		var goo_hit := SpdCombat.goo_attacks_hero(combat_rng, 40, 0, 0, 0, true)
		if not goo_hit["hit"] or goo_hit["damage"] < 3 or goo_hit["damage"] > 36:
			_fail("Goo's pumped half-health damage range is wrong")
			return
	var saved: Dictionary = run.snapshot()
	var restored = Run.new()
	if not restored.restore_snapshot(saved) or restored.snapshot() != saved:
		_fail("campaign progression did not survive a snapshot round trip")
		return
	run.depth = 26
	run._build_floor()
	run.hero = run.stairs
	run._pickup_items()
	if not run.won or not run.items.is_empty() or run.step(Vector2i.RIGHT):
		_fail("amulet victory did not end the run")
		return
	print("SPD campaign passed: 3 seeds x 26 depths, bosses, region mobs, progression, save, amulet")
	quit()


func _boss_gate(run) -> bool:
	for direction in Run.DIRS8:
		var neighbor: Vector2i = run.stairs + direction
		if Run.is_wall_tile(run.tile_at(neighbor)) or run.tile_at(neighbor) == Run.CLOSED_DOOR:
			continue
		run.hero = neighbor
		return not run.step(-direction) and run.depth % 5 == 0
	return false


func _force_descend(run) -> bool:
	run.mobs.clear()
	for direction in Run.DIRS8:
		var neighbor: Vector2i = run.stairs + direction
		if Run.is_wall_tile(run.tile_at(neighbor)) or run.tile_at(neighbor) == Run.CLOSED_DOOR:
			continue
		run.hero = neighbor
		return run.step(-direction)
	return false


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
			if seen.has(next) or Run.is_wall_tile(run.tile_at(next)):
				continue
			seen[next] = true
			queue.append(next)
	return false


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
