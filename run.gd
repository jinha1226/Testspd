extends RefCounted
## Sewer-region Godot port in progress; see PORTING.md for exact upstream mappings.

const ShadowCaster = preload("res://spd_shadowcaster.gd")
const SpdCombat = preload("res://spd_combat.gd")
const SpdPatch = preload("res://spd_patch.gd")
const SpdRandom = preload("res://spd_random.gd")
const SpdActorClock = preload("res://spd_actor_clock.gd")
const SpdPathFinder = preload("res://spd_pathfinder.gd")

const WIDTH := 36
const HEIGHT := 36
const WALL := 0
const FLOOR := 1
const CLOSED_DOOR := 2
const OPEN_DOOR := 3
const ENTRANCE := 4
const EXIT := 5
const WATER := 6
const GRASS := 7
const HIGH_GRASS := 8
const FLOOR_DECO := 9
const WALL_DECO := 10
const SIGHT_RADIUS := 8
const DIRS8 := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0),                    Vector2i(1, 0),
	Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
]

var tiles := PackedInt32Array()
var explored := PackedByteArray()
var visible := PackedByteArray()
var rooms: Array[Rect2i] = []
var mobs: Array[Dictionary] = []
var potions: Array[Vector2i] = []
var hero := Vector2i.ZERO
var stairs := Vector2i.ZERO
var depth := 1
var hp := 20
var max_hp := 20
var potion_count := 0
var healing_left := 0
var turns := 0
var message := ""
var rng = SpdRandom.new()
var clock = SpdActorClock.new()
var next_actor_id := 1


func start(seed_value: int = 0) -> void:
	rng.reset(seed_value if seed_value != 0 else Time.get_ticks_usec())
	depth = 1
	hp = max_hp
	potion_count = 0
	healing_left = 0
	turns = 0
	_build_floor()
	message = "1층 하수도. 계단을 찾으세요."


func _build_floor() -> void:
	clock.clear()
	clock.add(0, SpdActorClock.HERO_PRIORITY)
	next_actor_id = 1
	tiles.resize(WIDTH * HEIGHT)
	tiles.fill(WALL)
	explored.resize(WIDTH * HEIGHT)
	explored.fill(0)
	visible.resize(WIDTH * HEIGHT)
	visible.fill(0)
	rooms.clear()
	mobs.clear()
	potions.clear()

	# Each room is connected to the previous one, so the exit remains reachable.
	for attempt in range(180):
		var size := Vector2i(rng.randi_range(5, 8), rng.randi_range(5, 8))
		var position := Vector2i(
			rng.randi_range(2, WIDTH - size.x - 3),
			rng.randi_range(2, HEIGHT - size.y - 3)
		)
		var room := Rect2i(position, size)
		var overlaps := false
		for existing in rooms:
			if room.grow(1).intersects(existing):
				overlaps = true
				break
		if overlaps:
			continue
		_carve_room(room)
		if not rooms.is_empty():
			_carve_corridor(_room_center(rooms.back()), _room_center(room))
		rooms.append(room)
		if rooms.size() >= 10:
			break

	# The map is large enough for many rooms; this keeps even unlucky seeds playable.
	if rooms.size() < 2:
		rooms.clear()
		tiles.fill(WALL)
		var first := Rect2i(5, 5, 8, 8)
		var last := Rect2i(23, 23, 8, 8)
		_carve_room(first)
		_carve_room(last)
		_carve_corridor(_room_center(first), _room_center(last))
		rooms.append_array([first, last])

	_mark_doors()
	_paint_terrain()
	hero = _room_center(rooms.front())
	stairs = _room_center(rooms.back())
	tiles[_index(hero)] = ENTRANCE
	tiles[_index(stairs)] = EXIT
	for room_index in range(1, rooms.size()):
		var room := rooms[room_index]
		if room_index == 2 or room_index == 5:
			var potion_pos := _room_center(room) + Vector2i(1, 0)
			if potion_pos != stairs:
				potions.append(potion_pos)
	_reveal()
	_spawn_mobs()


func _spawn_mobs() -> void:
	# RegularLevel.createMobs presets eight enemies on depth 1. MobSpawner's
	# sewer rotations are selected by depth and reshuffled when exhausted.
	# Rare alternates and exact standard-room weighting remain to be ported.
	var candidates: Array[Vector2i] = []
	for room_index in range(1, rooms.size()):
		var room := rooms[room_index]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				var cell := Vector2i(x, y)
				if not is_wall_tile(tile_at(cell)) and tile_at(cell) != CLOSED_DOOR \
						and cell != stairs and not is_visible(cell) \
						and maxi(absi(cell.x - hero.x), absi(cell.y - hero.y)) > 8:
					candidates.append(cell)
	var count := 8 if depth == 1 else 3 + depth % 5 + rng.randi_range(0, 2)
	var rotation := _mob_rotation()
	var rotation_index := 0
	while mobs.size() < count and not candidates.is_empty():
		if rotation_index == 0:
			for shuffle_index in range(rotation.size() - 1, 0, -1):
				var other_index := rng.randi_range(0, shuffle_index)
				var current: String = rotation[shuffle_index]
				rotation[shuffle_index] = rotation[other_index]
				rotation[other_index] = current
		var index := rng.randi_range(0, candidates.size() - 1)
		var cell := candidates[index]
		candidates.remove_at(index)
		if _mob_index_at(cell) < 0:
			var kind: String = rotation[rotation_index]
			var actor_id := next_actor_id
			next_actor_id += 1
			mobs.append({"id": actor_id, "kind": kind, "pos": cell, "hp": SpdCombat.mob_hp(kind),
				"state": "sleeping", "enemy_seen": false, "target": cell})
			clock.add(actor_id, SpdActorClock.MOB_PRIORITY)
			_trample(cell)
			rotation_index = (rotation_index + 1) % rotation.size()


func _mob_rotation() -> Array[String]:
	match depth:
		1:
			return ["rat", "rat", "rat", "snake"]
		2:
			return ["rat", "rat", "snake", "gnoll", "gnoll"]
		3:
			return ["rat", "snake", "gnoll", "gnoll", "gnoll", "swarm", "crab"]
		_:
			return ["gnoll", "swarm", "crab", "crab", "slime", "slime"]


func _paint_terrain() -> void:
	# SewerLevel.painter() uses 30% water with five smoothing passes and
	# 20% grass with four passes. Current rooms are still provisional.
	var water: PackedByteArray = SpdPatch.generate(rng, WIDTH, HEIGHT, 0.30, 5, true)
	var grass: PackedByteArray = SpdPatch.generate(rng, WIDTH, HEIGHT, 0.20, 4, true)
	for room in rooms:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				var index := x + y * WIDTH
				if tiles[index] == FLOOR and water[index] != 0:
					tiles[index] = WATER
	for room in rooms:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				var index := x + y * WIDTH
				if tiles[index] != FLOOR or grass[index] == 0:
					continue
				var count := 1
				for direction in DIRS8:
					var neighbor: Vector2i = Vector2i(x, y) + direction
					if _inside(neighbor) and grass[_index(neighbor)] != 0:
						count += 1
				tiles[index] = HIGH_GRASS if rng.randf() < count / 12.0 else GRASS
	# SewerPainter.decorate(): decorate walls above water and floor near walls.
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			var index := x + y * WIDTH
			if tiles[index] == WALL and tiles[index - WIDTH] == WALL \
					and tiles[index + WIDTH] == WATER and rng.randi_range(0, 1) == 0:
				tiles[index] = WALL_DECO
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			var index := x + y * WIDTH
			if tiles[index] != FLOOR:
				continue
			var count := 0
			for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				if tile_at(Vector2i(x, y) + direction) == WALL:
					count += 1
			if rng.randi_range(0, 15) < count * count:
				tiles[index] = FLOOR_DECO


func _carve_room(room: Rect2i) -> void:
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			tiles[_index(Vector2i(x, y))] = FLOOR


func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	var p := from
	if rng.randi_range(0, 1) == 0:
		while p.x != to.x:
			p.x += 1 if to.x > p.x else -1
			tiles[_index(p)] = FLOOR
		while p.y != to.y:
			p.y += 1 if to.y > p.y else -1
			tiles[_index(p)] = FLOOR
	else:
		while p.y != to.y:
			p.y += 1 if to.y > p.y else -1
			tiles[_index(p)] = FLOOR
		while p.x != to.x:
			p.x += 1 if to.x > p.x else -1
			tiles[_index(p)] = FLOOR


func _mark_doors() -> void:
	for room in rooms:
		for x in range(room.position.x, room.end.x):
			for y in [room.position.y, room.end.y - 1]:
				var inward := Vector2i(0, 1 if y == room.position.y else -1)
				_try_door(Vector2i(x, y), inward)
		for y in range(room.position.y + 1, room.end.y - 1):
			for x in [room.position.x, room.end.x - 1]:
				var inward := Vector2i(1 if x == room.position.x else -1, 0)
				_try_door(Vector2i(x, y), inward)


func _try_door(p: Vector2i, inward: Vector2i) -> void:
	var outside := p - inward
	if _inside(outside) and tiles[_index(outside)] == FLOOR \
			and tiles[_index(p)] == FLOOR and tiles[_index(p + inward)] == FLOOR:
		tiles[_index(p)] = CLOSED_DOOR


func _room_center(room: Rect2i) -> Vector2i:
	return room.position + Vector2i(int(room.size.x / 2), int(room.size.y / 2))


func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < WIDTH and p.y < HEIGHT


func _index(p: Vector2i) -> int:
	return p.y * WIDTH + p.x


func tile_at(p: Vector2i) -> int:
	return tiles[_index(p)] if _inside(p) else WALL


static func is_wall_tile(tile: int) -> bool:
	return tile == WALL or tile == WALL_DECO


func _trample(p: Vector2i) -> void:
	if tile_at(p) == HIGH_GRASS:
		tiles[_index(p)] = GRASS


func is_visible(p: Vector2i) -> bool:
	return _inside(p) and visible[_index(p)] != 0


func is_explored(p: Vector2i) -> bool:
	return _inside(p) and explored[_index(p)] != 0


func _reveal() -> void:
	visible = ShadowCaster.cast_shadow(hero, WIDTH, HEIGHT, _blocking_map(), SIGHT_RADIUS)
	for index in range(visible.size()):
		if visible[index] != 0:
			explored[index] = 1


func _blocking_map() -> PackedByteArray:
	var blocking := PackedByteArray()
	blocking.resize(WIDTH * HEIGHT)
	for index in range(tiles.size()):
		blocking[index] = 1 if is_wall_tile(tiles[index]) \
			or tiles[index] == CLOSED_DOOR or tiles[index] == HIGH_GRASS else 0
	return blocking


func _mob_index_at(p: Vector2i) -> int:
	for i in range(mobs.size()):
		if mobs[i]["pos"] == p:
			return i
	return -1


func step(direction: Vector2i) -> bool:
	if hp <= 0 or direction == Vector2i.ZERO:
		return false
	if absi(direction.x) > 1 or absi(direction.y) > 1:
		return false
	var target := hero + direction
	if not _inside(target) or is_wall_tile(tile_at(target)):
		message = "벽이 가로막고 있습니다."
		return false
	var mob_index := _mob_index_at(target)
	if mob_index >= 0:
		var mob: Dictionary = mobs[mob_index]
		var kind: String = mob["kind"]
		var name := _mob_name(kind)
		var strike: Dictionary = SpdCombat.warrior_attacks_mob(rng, kind, not mob["enemy_seen"])
		if not strike["hit"]:
			message = "공격이 빗나갔습니다."
		else:
			_split_swarm(mob_index, int(strike["damage"]))
			mob = mobs[mob_index]
			mob["hp"] = int(mob["hp"]) - int(strike["damage"])
			if int(mob["hp"]) <= 0:
				if mob.has("id"):
					clock.remove(int(mob["id"]))
				mobs.remove_at(mob_index)
				message = "%s을(를) 쓰러뜨렸습니다." % name
			else:
				mob["state"] = "hunting"
				mob["enemy_seen"] = true
				mob["target"] = hero
				mobs[mob_index] = mob
				message = "%s에게 %d 피해." % [name, strike["damage"]]
	elif tile_at(target) == CLOSED_DOOR:
		tiles[_index(target)] = OPEN_DOOR
		message = "문을 열었습니다."
	else:
		hero = target
		_trample(hero)
		message = "이동했습니다."
		if potions.has(hero):
			potions.erase(hero)
			potion_count += 1
			message = "회복 물약을 주웠습니다."
		if hero == stairs:
			depth += 1
			_build_floor()
			message = "%d층으로 내려왔습니다." % depth
			return true
	_advance_turn()
	return true


func wait_turn() -> void:
	if hp <= 0:
		return
	message = "잠시 기다립니다."
	_advance_turn()


func drink_potion() -> bool:
	if hp <= 0 or potion_count <= 0 or hp >= max_hp:
		message = "지금은 물약을 쓸 수 없습니다."
		return false
	potion_count -= 1
	# PotionOfHealing heals 0.8 * HT + 14 over time via Healing.act().
	healing_left = maxi(healing_left, int(0.8 * max_hp + 14))
	message = "회복 물약을 마셨습니다."
	_advance_turn()
	return true


func _advance_turn() -> void:
	turns += 1
	clock.spend(0, 1.0)
	_run_actors_until_hero()
	if hp > 0:
		_heal_tick()
	_reveal()
	if hp <= 0:
		message = "%d층에서 쓰러졌습니다. 새 게임을 눌러 재시작하세요." % depth


func _heal_tick() -> void:
	if healing_left <= 0:
		return
	var amount := clampi(roundi(healing_left * 0.25), 1, healing_left)
	hp = mini(max_hp, hp + amount)
	healing_left -= amount


func _run_actors_until_hero() -> void:
	# Actor.process chooses the lowest time, then the highest priority.
	# A bound prevents a broken actor from freezing the browser.
	for event in range(4096):
		var actor_id := clock.next_actor()
		if actor_id == 0 or actor_id < 0 or hp <= 0:
			return
		var index := _mob_index_by_id(actor_id)
		if index < 0:
			clock.remove(actor_id)
			continue
		_mob_act(index, _blocking_map())
		var speed := 2.0 if mobs[index]["kind"] == "crab" else 1.0
		clock.spend(actor_id, 1.0 / speed)
		if hp <= 0:
			return
	push_error("actor clock exceeded 4096 actions before the hero")


func _mob_index_by_id(actor_id: int) -> int:
	for index in range(mobs.size()):
		if int(mobs[index].get("id", -1)) == actor_id:
			return index
	return -1


func _mob_act(i: int, blocking: PackedByteArray) -> void:
	var mob: Dictionary = mobs[i]
	var pos: Vector2i = mob["pos"]
	var distance := maxi(absi(pos.x - hero.x), absi(pos.y - hero.y))
	var mob_fov: PackedByteArray = ShadowCaster.cast_shadow(pos, WIDTH, HEIGHT, blocking, SIGHT_RADIUS)
	var sees_hero := mob_fov[_index(hero)] != 0
	if mob["state"] == "sleeping":
		# Mob.Sleeping detects an unstealthed hero with chance 1 / distance.
		if sees_hero and rng.randf() < 1.0 / maxf(1.0, float(distance)):
			mob["state"] = "hunting"
			mob["enemy_seen"] = true
			mob["target"] = hero
			mobs[i] = mob
		return
	mob["enemy_seen"] = sees_hero
	if sees_hero:
		mob["state"] = "hunting"
		mob["target"] = hero
	if distance <= 1 and sees_hero:
		var strike: Dictionary = SpdCombat.mob_attacks_warrior(rng, mob["kind"])
		var name := _mob_name(mob["kind"])
		if strike["hit"]:
			hp = maxi(0, hp - int(strike["damage"]))
			message += " %s에게 %d 피해를 받았습니다." % [name, strike["damage"]]
		else:
			message += " %s의 공격이 빗나갔습니다." % name
		mobs[i] = mob
		return
	var goal: Vector2i = mob["target"]
	if pos == goal:
		mob["state"] = "wandering"
		mobs[i] = mob
		return
	var passable := _path_passability(false)
	for other in mobs:
		if other["pos"] != pos:
			passable[_index(other["pos"])] = 0
	passable[_index(hero)] = 0
	var best: Vector2i = SpdPathFinder.get_step(WIDTH, HEIGHT, pos, goal, passable)
	if best == hero or _mob_index_at(best) >= 0:
		best = pos
	mob["pos"] = best
	_trample(best)
	mobs[i] = mob


func _split_swarm(index: int, damage: int) -> void:
	var mob: Dictionary = mobs[index]
	if mob["kind"] != "swarm" or int(mob["hp"]) < damage + 2:
		return
	var candidates: Array[Vector2i] = []
	var origin: Vector2i = mob["pos"]
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var cell: Vector2i = origin + direction
		if not is_wall_tile(tile_at(cell)) and tile_at(cell) != CLOSED_DOOR \
				and cell != hero and _mob_index_at(cell) < 0:
			candidates.append(cell)
	if candidates.is_empty():
		return
	var clone_hp := int((int(mob["hp"]) - damage) / 2)
	mob["hp"] = int(mob["hp"]) - clone_hp
	mobs[index] = mob
	var cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	var actor_id := next_actor_id
	next_actor_id += 1
	mobs.append({"id": actor_id, "kind": "swarm", "pos": cell, "hp": clone_hp,
		"state": "hunting", "enemy_seen": true, "target": hero})
	clock.add(actor_id, SpdActorClock.MOB_PRIORITY, 1.0)


static func _mob_name(kind: String) -> String:
	match kind:
		"snake": return "뱀"
		"gnoll": return "놀"
		"swarm": return "파리떼"
		"crab": return "게"
		"slime": return "슬라임"
		_: return "쥐"


func has_visible_enemy() -> bool:
	for mob in mobs:
		if is_visible(mob["pos"]):
			return true
	return false


func path_to(target: Vector2i) -> Array[Vector2i]:
	if not is_explored(target) or target == hero or is_wall_tile(tile_at(target)):
		return []
	return SpdPathFinder.find_path(WIDTH, HEIGHT, hero, target, _path_passability(true))


func _path_passability(explored_only: bool) -> PackedByteArray:
	var passable := PackedByteArray()
	passable.resize(WIDTH * HEIGHT)
	for index in range(tiles.size()):
		passable[index] = 1 if not is_wall_tile(tiles[index]) \
			and (not explored_only or explored[index] != 0) \
			and (explored_only or tiles[index] != CLOSED_DOOR) else 0
	return passable


func snapshot() -> Dictionary:
	var saved_rooms: Array = []
	for room in rooms:
		saved_rooms.append([room.position.x, room.position.y, room.size.x, room.size.y])
	var saved_mobs: Array = []
	for mob in mobs:
		saved_mobs.append({"id": mob.get("id", -1), "kind": mob["kind"],
			"pos": _vector_data(mob["pos"]), "hp": mob["hp"], "state": mob["state"],
			"enemy_seen": mob["enemy_seen"], "target": _vector_data(mob["target"])})
	var saved_potions: Array = []
	for potion in potions:
		saved_potions.append(_vector_data(potion))
	var saved_tiles: Array = []
	for tile in tiles:
		saved_tiles.append(tile)
	var saved_explored: Array = []
	for bit in explored:
		saved_explored.append(bit)
	return {"map_size": [WIDTH, HEIGHT], "tiles": saved_tiles, "explored": saved_explored,
		"rooms": saved_rooms, "mobs": saved_mobs, "potions": saved_potions,
		"hero": _vector_data(hero), "stairs": _vector_data(stairs),
		"depth": depth, "hp": hp, "max_hp": max_hp,
		"potion_count": potion_count, "healing_left": healing_left,
		"turns": turns, "message": message, "rng": rng.state_snapshot(),
		"clock": clock.snapshot(), "next_actor_id": next_actor_id}


func restore_snapshot(saved: Dictionary) -> bool:
	var saved_size = saved.get("map_size")
	if typeof(saved_size) != TYPE_ARRAY or saved_size.size() != 2 \
			or not _is_saved_int(saved_size[0]) or not _is_saved_int(saved_size[1]) \
			or int(saved_size[0]) != WIDTH or int(saved_size[1]) != HEIGHT:
		return false
	var saved_tiles = saved.get("tiles")
	var saved_explored = saved.get("explored")
	var saved_rooms = saved.get("rooms")
	var saved_mobs = saved.get("mobs")
	var saved_potions = saved.get("potions")
	if typeof(saved_tiles) != TYPE_ARRAY or saved_tiles.size() != WIDTH * HEIGHT \
			or typeof(saved_explored) != TYPE_ARRAY or saved_explored.size() != WIDTH * HEIGHT \
			or typeof(saved_rooms) != TYPE_ARRAY or typeof(saved_mobs) != TYPE_ARRAY \
			or typeof(saved_potions) != TYPE_ARRAY:
		return false
	if not _valid_saved_vector(saved.get("hero")) or not _valid_saved_vector(saved.get("stairs")):
		return false
	for key in ["depth", "hp", "max_hp", "potion_count", "healing_left", "turns", "next_actor_id"]:
		if not _is_saved_int(saved.get(key)):
			return false
	if saved["depth"] < 1 or saved["max_hp"] < 1 or saved["hp"] < 0 \
			or saved["hp"] > saved["max_hp"] or saved["potion_count"] < 0 \
			or saved["healing_left"] < 0 or saved["turns"] < 0 or saved["next_actor_id"] < 1:
		return false
	if typeof(saved.get("message")) != TYPE_STRING or typeof(saved.get("rng")) != TYPE_ARRAY \
			or typeof(saved.get("clock")) != TYPE_DICTIONARY:
		return false
	var restored_tiles := PackedInt32Array()
	for value in saved_tiles:
		if not _is_saved_int(value) or value < WALL or value > WALL_DECO:
			return false
		restored_tiles.append(int(value))
	var restored_explored := PackedByteArray()
	for value in saved_explored:
		if not _is_saved_int(value) or value < 0 or value > 1:
			return false
		restored_explored.append(int(value))
	var restored_rooms: Array[Rect2i] = []
	for value in saved_rooms:
		if typeof(value) != TYPE_ARRAY or value.size() != 4:
			return false
		for component in value:
			if not _is_saved_int(component):
				return false
		if value[2] <= 0 or value[3] <= 0 or value[0] < 0 or value[1] < 0 \
				or value[0] + value[2] > WIDTH or value[1] + value[3] > HEIGHT:
			return false
		restored_rooms.append(Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3])))
	var restored_mobs: Array[Dictionary] = []
	var ids := {}
	for value in saved_mobs:
		if typeof(value) != TYPE_DICTIONARY or not SpdCombat.MOB_STATS.has(value.get("kind")) \
				or not _valid_saved_vector(value.get("pos")) or not _valid_saved_vector(value.get("target")) \
				or not _is_saved_int(value.get("id")) or not _is_saved_int(value.get("hp")) \
				or typeof(value.get("enemy_seen")) != TYPE_BOOL \
				or not ["sleeping", "hunting", "wandering"].has(value.get("state")):
			return false
		if value["id"] < 1 or ids.has(value["id"]) or value["hp"] <= 0 \
				or value["id"] >= saved["next_actor_id"]:
			return false
		ids[int(value["id"])] = true
		restored_mobs.append({"id": int(value["id"]), "kind": value["kind"],
			"pos": _data_vector(value["pos"]), "hp": int(value["hp"]), "state": value["state"],
			"enemy_seen": value["enemy_seen"], "target": _data_vector(value["target"])})
	var restored_potions: Array[Vector2i] = []
	for value in saved_potions:
		if not _valid_saved_vector(value):
			return false
		restored_potions.append(_data_vector(value))
	if not rng.restore_state(saved["rng"]) or not clock.restore(saved["clock"]) \
			or not clock.has(0):
		return false
	for mob in restored_mobs:
		if not clock.has(mob["id"]):
			return false
	tiles = restored_tiles
	explored = restored_explored
	visible.resize(WIDTH * HEIGHT)
	visible.fill(0)
	rooms = restored_rooms
	mobs = restored_mobs
	potions = restored_potions
	hero = _data_vector(saved["hero"])
	stairs = _data_vector(saved["stairs"])
	depth = int(saved["depth"])
	hp = int(saved["hp"])
	max_hp = int(saved["max_hp"])
	potion_count = int(saved["potion_count"])
	healing_left = int(saved["healing_left"])
	turns = int(saved["turns"])
	message = saved["message"]
	next_actor_id = int(saved["next_actor_id"])
	_reveal()
	return true


static func _vector_data(value: Vector2i) -> Array:
	return [value.x, value.y]


static func _valid_saved_vector(value) -> bool:
	return typeof(value) == TYPE_ARRAY and value.size() == 2 \
		and _is_saved_int(value[0]) and _is_saved_int(value[1]) \
		and value[0] >= 0 and value[0] < WIDTH and value[1] >= 0 and value[1] < HEIGHT


static func _data_vector(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


static func _is_saved_int(value) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) \
		and absf(float(value)) <= 9007199254740991.0 \
		and float(value) == floorf(float(value))
