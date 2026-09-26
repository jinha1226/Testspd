extends RefCounted
## Sewer-region Godot port in progress; see PORTING.md for exact upstream mappings.

const ShadowCaster = preload("res://spd_shadowcaster.gd")
const SpdCombat = preload("res://spd_combat.gd")
const SpdPatch = preload("res://spd_patch.gd")
const SpdRandom = preload("res://spd_random.gd")
const SpdActorClock = preload("res://spd_actor_clock.gd")
const SpdPathFinder = preload("res://spd_pathfinder.gd")
const SpdCampaign = preload("res://spd_campaign.gd")
const SpdRegularSpawner = preload("res://spd_regular_spawner.gd")
const SpdLimitedDrops = preload("res://spd_limited_drops.gd")
const SpdFloorSeed = preload("res://spd_floor_seed.gd")
const SpdRoomPlan = preload("res://spd_room_plan.gd")

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
const RESPAWNER_ID := -2
const RESPAWN_COOLDOWN := 50.0
const DIRS8 := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0),                    Vector2i(1, 0),
	Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
]

var tiles := PackedInt32Array()
var explored := PackedByteArray()
var visible := PackedByteArray()
var rooms: Array[Rect2i] = []
var room_kinds: Array[String] = []
var mobs: Array[Dictionary] = []
var potions: Array[Vector2i] = []
var items: Array[Dictionary] = []
var hero := Vector2i.ZERO
var stairs := Vector2i.ZERO
var depth := 1
var dungeon_seed := 0
var hp := 20
var max_hp := 20
var potion_count := 0
var food_count := 1
var upgrade_count := 0
var strength_drops := 0
var upgrade_drops := 0
var wand_charges := 0
var hunger := 0
var hunger_damage := 0.0
var level := 1
var experience := 0
var strength := 10
var weapon_tier := 1
var weapon_level := 0
var armor_tier := 1
var armor_level := 0
var won := false
var healing_left := 0
var ooze_left := 0
var turns := 0
var message := ""
var rng = SpdRandom.new()
var clock = SpdActorClock.new()
var next_actor_id := 1
var _mob_rotation: Array[String] = []
var _mob_rotation_index := 0


func start(seed_value: int = 0) -> void:
	dungeon_seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
	rng.reset(dungeon_seed)
	depth = 1
	hp = max_hp
	potion_count = 0
	food_count = 1
	upgrade_count = 0
	strength_drops = 0
	upgrade_drops = 0
	wand_charges = 0
	hunger = 0
	hunger_damage = 0.0
	level = 1
	experience = 0
	strength = 10
	weapon_tier = 1
	weapon_level = 0
	armor_tier = 1
	armor_level = 0
	won = false
	healing_left = 0
	ooze_left = 0
	turns = 0
	_build_floor()
	message = "1층 하수도. 계단을 찾으세요."


func _build_floor() -> void:
	# Level.create uses an isolated, deterministic generator per depth.
	rng.push_generator(SpdFloorSeed.for_depth(dungeon_seed, depth))
	var scheduled_items: Array[String] = []
	if depth < 26 and SpdCampaign.boss(depth) == "":
		# Level.create schedules mandatory consumables before rolling the map.
		scheduled_items.append("food")
		if SpdLimitedDrops.strength_needed(depth, strength_drops, rng):
			strength_drops += 1
			scheduled_items.append("strength")
		if SpdLimitedDrops.upgrade_needed(depth, upgrade_drops, rng):
			upgrade_drops += 1
			scheduled_items.append("upgrade")
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
	room_kinds.clear()
	mobs.clear()
	potions.clear()
	items.clear()
	_mob_rotation.clear()
	_mob_rotation_index = 0

	if depth == 26:
		_build_final_layout()
	elif SpdCampaign.boss(depth) != "":
		_build_boss_layout()
	else:
		_build_regular_layout()
	if room_kinds.is_empty():
		for _room in rooms:
			room_kinds.append("standard")

	_mark_doors()
	_paint_terrain()
	if SpdCampaign.boss(depth) != "":
		_decorate_boss_arena()
	hero = _room_center(rooms.front())
	stairs = _room_center(rooms.back())
	tiles[_index(hero)] = ENTRANCE
	tiles[_index(stairs)] = EXIT if depth < 26 else FLOOR
	if depth == 26:
		items.append({"kind": "amulet", "pos": stairs, "tier": 0})
	_reveal()
	_spawn_mobs()
	if SpdCampaign.boss(depth) == "" and depth < 26:
		_place_floor_items(scheduled_items)
	if depth < 26 and SpdCampaign.boss(depth) == "":
		clock.add(RESPAWNER_ID, SpdActorClock.BUFF_PRIORITY, RESPAWN_COOLDOWN)
	rng.pop_generator()


func _build_regular_layout() -> void:
	var plan: Dictionary = SpdRoomPlan.create(WIDTH, HEIGHT, depth, rng)
	rooms = plan["rooms"]
	room_kinds = plan["kinds"]
	for room in rooms:
		_carve_room(room)
	for edge in plan["edges"]:
		_carve_corridor(_room_center(rooms[edge.x]), _room_center(rooms[edge.y]))



func _build_boss_layout() -> void:
	# Compact entrance, arena, and exit keep a distinct fight space on each
	# boss depth. Their detailed source builders remain to be ported.
	rooms.append(Rect2i(2, 13, 7, 10))
	rooms.append(Rect2i(11, 7, 16, 22))
	rooms.append(Rect2i(29, 13, 5, 10))
	for room in rooms:
		_carve_room(room)
	_carve_corridor(_room_center(rooms[0]), _room_center(rooms[1]))
	_carve_corridor(_room_center(rooms[1]), _room_center(rooms[2]))


func _build_final_layout() -> void:
	rooms.append(Rect2i(5, 14, 8, 9))
	rooms.append(Rect2i(20, 10, 11, 17))
	for room in rooms:
		_carve_room(room)
	_carve_corridor(_room_center(rooms[0]), _room_center(rooms[1]))


func _decorate_boss_arena() -> void:
	var center := _room_center(rooms[1])
	match depth:
		5:
			for direction in DIRS8:
				tiles[_index(center + direction * 2)] = WATER
		10:
			for offset in [Vector2i(-4, -4), Vector2i(4, -4),
					Vector2i(-4, 4), Vector2i(4, 4)]:
				tiles[_index(center + offset)] = WALL_DECO
		15:
			for offset in [Vector2i(-5, -6), Vector2i(5, -6),
					Vector2i(-5, 6), Vector2i(5, 6)]:
				tiles[_index(center + offset)] = WALL_DECO
		20:
			for x in range(center.x - 3, center.x + 4):
				for y in range(center.y - 2, center.y + 3):
					tiles[_index(Vector2i(x, y))] = FLOOR_DECO
		25:
			for offset in [Vector2i(-4, -5), Vector2i(4, -5),
					Vector2i(-4, 5), Vector2i(4, 5)]:
				tiles[_index(center + offset)] = WALL_DECO
	tiles[_index(center)] = FLOOR


func _place_floor_items(scheduled_items: Array[String]) -> void:
	# Mandatory drops follow Level.create. The remaining three-to-five drops
	# still use a reduced item pool until Generator and the inventory are ported.
	for kind in scheduled_items:
		_drop_floor_item(kind)
	# RegularLevel.createItems rolls 3/4/5 random items with weights 6/3/1.
	var roll := rng.next_int(10)
	var random_count := 3 if roll < 6 else (4 if roll < 9 else 5)
	# Keep one healing item available while other potion types are absent.
	_drop_floor_item("potion")
	for _drop in range(random_count - 1):
		var category := rng.next_int(10)
		if category < 5:
			_drop_floor_item("potion")
		elif category < 7:
			_drop_floor_item("weapon")
		elif category < 9:
			_drop_floor_item("armor")
		else:
			_drop_floor_item("wand")


func _drop_floor_item(kind: String) -> void:
	var cell := _random_drop_cell()
	if cell == Vector2i(-1, -1):
		return
	if kind == "potion":
		potions.append(cell)
	else:
		var tier := 0
		if kind == "weapon" or kind == "armor":
			tier = mini(5, 1 + int(depth / 5))
		items.append({"kind": kind, "pos": cell, "tier": tier})
	_trample(cell)


func _random_drop_cell() -> Vector2i:
	# RegularLevel.randomDropCell samples standard rooms, excluding their
	# entrance room, exit cell, occupied heaps, and enemies.
	if rooms.size() < 2:
		return Vector2i(-1, -1)
	for _attempt in range(100):
		var room_index := rng.next_int(rooms.size())
		if room_index == 0 or room_kinds[room_index] == "special_placeholder":
			continue
		var room: Rect2i = rooms[room_index]
		var cell := Vector2i(
			rng.randi_range(room.position.x + 1, room.end.x - 2),
			rng.randi_range(room.position.y + 1, room.end.y - 2))
		if _can_drop_at(cell):
			return cell
	return Vector2i(-1, -1)


func _can_drop_at(cell: Vector2i) -> bool:
	if cell == stairs or cell == hero or is_wall_tile(tile_at(cell)) \
			or tile_at(cell) == CLOSED_DOOR or _mob_index_at(cell) >= 0 \
			or potions.has(cell):
		return false
	for item in items:
		if item["pos"] == cell:
			return false
	return true


func _spawn_mobs() -> void:
	if depth == 26:
		return
	var boss_kind := SpdCampaign.boss(depth)
	if boss_kind != "":
		var boss_cell := _room_center(rooms[int(rooms.size() / 2)])
		_spawn_mob(boss_kind, boss_cell)
		return
	# RegularLevel.createMobs: shuffled standard rooms, entrance FOV and an
	# eight-step open-space walk exclusion, with 31 random tries per room.
	var count := 8 if depth == 1 else 3 + depth % 5 + rng.randi_range(0, 2)
	_mob_rotation = SpdCampaign.rotation(depth)
	_mob_rotation_index = 0
	var placements: Array[Dictionary] = SpdRegularSpawner.positions(rng, WIDTH, HEIGHT,
		tiles, rooms, room_kinds, hero, stairs, visible, count, depth,
		[WALL, WALL_DECO], CLOSED_DOOR, _next_regular_mob_kind)
	for placement in placements:
		_spawn_mob(placement["kind"], placement["pos"])


func _next_regular_mob_kind() -> String:
	if _mob_rotation_index == 0:
		for shuffle_index in range(_mob_rotation.size() - 1, 0, -1):
			var other_index := rng.randi_range(0, shuffle_index)
			var current: String = _mob_rotation[shuffle_index]
			_mob_rotation[shuffle_index] = _mob_rotation[other_index]
			_mob_rotation[other_index] = current
	var kind: String = _mob_rotation[_mob_rotation_index]
	_mob_rotation_index = (_mob_rotation_index + 1) % _mob_rotation.size()
	return kind


func _spawn_mob(kind: String, cell: Vector2i) -> void:
	var actor_id := next_actor_id
	next_actor_id += 1
	mobs.append({"id": actor_id, "kind": kind, "pos": cell,
		"hp": SpdCombat.mob_hp(kind), "state": "sleeping",
		"enemy_seen": false, "target": cell, "charge": 0})
	clock.add(actor_id, SpdActorClock.MOB_PRIORITY)
	_trample(cell)


func _paint_terrain() -> void:
	# SewerLevel.painter() uses 30% water with five smoothing passes and
	# 20% grass with four passes. Current rooms are still provisional.
	var region := SpdCampaign.region(depth)
	var water_rates := [0.30, 0.30, 0.30, 0.30, 0.15]
	var grass_rates := [0.20, 0.20, 0.15, 0.20, 0.10]
	var water_passes := [5, 4, 6, 4, 6]
	var grass_passes := [4, 3, 3, 3, 3]
	var water: PackedByteArray = SpdPatch.generate(rng, WIDTH, HEIGHT,
		0.50 if depth == 5 else water_rates[region], water_passes[region], true)
	var grass: PackedByteArray = SpdPatch.generate(rng, WIDTH, HEIGHT,
		grass_rates[region], grass_passes[region], true)
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
	if hp <= 0 or won or direction == Vector2i.ZERO:
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
		var strike: Dictionary = SpdCombat.hero_attacks_mob(rng, kind,
			not mob["enemy_seen"], level, _weapon_min(), _weapon_max(),
			strength, _gear_requirement(weapon_tier, weapon_level))
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
				_gain_experience(kind)
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
		if target == stairs and SpdCampaign.boss(depth) != "" and not mobs.is_empty():
			message = "보스를 쓰러뜨려야 계단을 이용할 수 있습니다."
			return false
		hero = target
		_trample(hero)
		message = "이동했습니다."
		if potions.has(hero):
			potions.erase(hero)
			potion_count += 1
			message = "회복 물약을 주웠습니다."
		_pickup_items()
		if won:
			return true
		if hero == stairs:
			depth += 1
			_build_floor()
			message = "%d층 %s에 내려왔습니다." % [depth, SpdCampaign.region_name(depth)]
			return true
	_advance_turn()
	return true


func wait_turn() -> void:
	if hp <= 0 or won:
		return
	message = "잠시 기다립니다."
	_advance_turn()


func drink_potion() -> bool:
	if hp <= 0 or won or potion_count <= 0 or hp >= max_hp:
		message = "지금은 물약을 쓸 수 없습니다."
		return false
	potion_count -= 1
	# PotionOfHealing heals 0.8 * HT + 14 over time via Healing.act().
	healing_left = maxi(healing_left, int(0.8 * max_hp + 14))
	ooze_left = 0
	message = "회복 물약을 마셨습니다."
	_advance_turn()
	return true


func eat_food() -> bool:
	if hp <= 0 or won or food_count <= 0:
		message = "먹을 식량이 없습니다."
		return false
	food_count -= 1
	hunger = maxi(0, hunger - 300)
	message = "식량을 먹었습니다."
	for _turn in range(3):
		if hp > 0:
			_advance_turn()
	return true


func upgrade_weapon() -> bool:
	if hp <= 0 or won or upgrade_count <= 0:
		message = "강화 주문서가 없습니다."
		return false
	upgrade_count -= 1
	weapon_level += 1
	message = "무기를 강화했습니다 (+%d)." % weapon_level
	_advance_turn()
	return true


func upgrade_armor() -> bool:
	if hp <= 0 or won or upgrade_count <= 0:
		message = "강화 주문서가 없습니다."
		return false
	upgrade_count -= 1
	armor_level += 1
	message = "갑옷을 강화했습니다 (+%d)." % armor_level
	_advance_turn()
	return true


func zap(target: Vector2i) -> bool:
	if hp <= 0 or won or wand_charges <= 0 or not is_visible(target):
		message = "지팡이를 사용할 수 없습니다."
		return false
	if maxi(absi(target.x - hero.x), absi(target.y - hero.y)) > SIGHT_RADIUS:
		message = "사거리 밖입니다."
		return false
	var mob_index := _mob_index_at(target)
	if mob_index < 0:
		message = "적을 선택하세요."
		return false
	wand_charges -= 1
	var mob: Dictionary = mobs[mob_index]
	var damage := SpdCombat.normal_int_range(rng, 5 + level, 9 + level * 2)
	mob["hp"] = int(mob["hp"]) - damage
	if int(mob["hp"]) <= 0:
		clock.remove(int(mob["id"]))
		mobs.remove_at(mob_index)
		_gain_experience(mob["kind"])
		message = "%s을(를) 마법으로 쓰러뜨렸습니다." % _mob_name(mob["kind"])
	else:
		mob["state"] = "hunting"
		mob["enemy_seen"] = true
		mob["target"] = hero
		mobs[mob_index] = mob
		message = "%s에게 마법 피해 %d." % [_mob_name(mob["kind"]), damage]
	_advance_turn()
	return true


func _weapon_min() -> int:
	return weapon_tier + weapon_level


func _weapon_max() -> int:
	return 5 * (weapon_tier + 1) + weapon_level * (weapon_tier + 1)


func _armor_max() -> int:
	return armor_tier * (2 + armor_level)


func _armor_min() -> int:
	return armor_level - _armor_max() if armor_level >= _armor_max() else armor_level


func _gear_requirement(tier: int, item_level: int) -> int:
	return 8 + 2 * tier - int((sqrt(8.0 * maxi(0, item_level) + 1.0) - 1.0) / 2.0)


func _gain_experience(kind: String) -> void:
	var stats: Dictionary = SpdCombat.MOB_STATS.get(kind, {})
	if level > int(stats.get("max_lvl", 30)):
		return
	experience += int(stats.get("exp", 0))
	while level < 30 and experience >= 5 + level * 5:
		experience -= 5 + level * 5
		level += 1
		max_hp += 5
		hp += 5


func _pickup_items() -> void:
	for index in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[index]
		if item["pos"] != hero:
			continue
		match item["kind"]:
			"food":
				food_count += 1
				message = "식량을 주웠습니다."
			"upgrade":
				upgrade_count += 1
				message = "강화 주문서를 주웠습니다."
			"strength":
				strength += 1
				message = "힘의 물약을 마셨습니다. 힘 %d." % strength
			"weapon":
				if int(item["tier"]) > weapon_tier:
					weapon_tier = int(item["tier"])
					weapon_level = 0
				message = "새 무기를 장착했습니다."
			"armor":
				if int(item["tier"]) > armor_tier:
					armor_tier = int(item["tier"])
					armor_level = 0
				message = "새 갑옷을 장착했습니다."
			"wand":
				wand_charges += 3
				message = "마법 지팡이를 주웠습니다."
			"amulet":
				won = true
				message = "옌더의 부적을 찾았습니다! 던전을 정복했습니다."
		items.remove_at(index)


func _advance_turn() -> void:
	turns += 1
	clock.spend(0, 1.0)
	_run_actors_until_hero()
	if hp > 0:
		_heal_tick()
		_ooze_tick()
		_hunger_tick()
	_reveal()
	if hp <= 0:
		message = "%d층에서 쓰러졌습니다. 새 게임을 눌러 재시작하세요." % depth


func _hunger_tick() -> void:
	if SpdCampaign.boss(depth) != "" and not mobs.is_empty():
		return
	if hunger < 450:
		hunger += 1
		if hunger == 450:
			hp = maxi(0, hp - 1)
			message += " 굶주리기 시작합니다."
	elif hp > 0:
		hunger_damage += max_hp / 1000.0
		if hunger_damage >= 1.0:
			var damage := int(hunger_damage)
			hp = maxi(0, hp - damage)
			hunger_damage -= damage


func _ooze_tick() -> void:
	if ooze_left <= 0:
		return
	if tile_at(hero) == WATER:
		ooze_left = 0
		message += " 물이 점액을 씻어냈습니다."
		return
	hp = maxi(0, hp - (1 if depth <= 5 else 1 + int(depth / 5)))
	ooze_left -= 1


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
		if actor_id == 0 or actor_id == -1 or hp <= 0:
			return
		if actor_id == RESPAWNER_ID:
			_respawner_act()
			continue
		var index := _mob_index_by_id(actor_id)
		if index < 0:
			clock.remove(actor_id)
			continue
		_mob_act(index, _blocking_map())
		var speed := 2.0 if ["crab", "thief", "monk"].has(mobs[index]["kind"]) else 1.0
		clock.spend(actor_id, 1.0 / speed)
		if hp <= 0:
			return
	push_error("actor clock exceeded 4096 actions before the hero")


func _respawner_act() -> void:
	# MobSpawner.act: a regular floor tries again after one turn if no safe
	# cell exists, or waits Level.TIME_TO_RESPAWN (50 turns) otherwise.
	var cooldown := RESPAWN_COOLDOWN
	if depth > 1 and mobs.size() < 3 + depth % 5 + rng.next_int(3):
		var kind := _next_regular_mob_kind()
		var cell := _respawn_cell()
		if cell != Vector2i(-1, -1):
			_spawn_mob(kind, cell)
			var mob: Dictionary = mobs.back()
			mob["state"] = "wandering"
			mobs[mobs.size() - 1] = mob
		else:
			cooldown = 1.0
	clock.spend(RESPAWNER_ID, cooldown)


func _respawn_cell() -> Vector2i:
	# Level.spawnMob(12) also excludes tiles reachable within 11 steps of
	# the hero. RegularLevel.randomRespawnCell samples standard room interiors.
	var reachable := _distance_from_hero()
	for _attempt in range(30):
		for _room_try in range(30):
			var room_index := rng.next_int(rooms.size())
			if room_index == 0 or room_kinds[room_index] == "special_placeholder":
				continue
			var room: Rect2i = rooms[room_index]
			var cell := Vector2i(
				rng.randi_range(room.position.x + 1, room.end.x - 2),
				rng.randi_range(room.position.y + 1, room.end.y - 2))
			if is_visible(cell) or _mob_index_at(cell) >= 0 or cell == stairs \
					or cell == hero or is_wall_tile(tile_at(cell)) \
					or tile_at(cell) == CLOSED_DOOR:
				continue
			if reachable[_index(cell)] >= 12:
				return cell
			break
	return Vector2i(-1, -1)


func _distance_from_hero() -> PackedInt32Array:
	var distance := PackedInt32Array()
	distance.resize(WIDTH * HEIGHT)
	distance.fill(2147483647)
	var queue: Array[Vector2i] = [hero]
	distance[_index(hero)] = 0
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for direction in DIRS8:
			var next: Vector2i = cell + direction
			if not _inside(next) or is_wall_tile(tile_at(next)) \
					or tile_at(next) == CLOSED_DOOR:
				continue
			var index := _index(next)
			if distance[index] != 2147483647:
				continue
			distance[index] = distance[_index(cell)] + 1
			queue.append(next)
	return distance


func _random_wander_destination() -> Vector2i:
	for _attempt in range(30):
		var room: Rect2i = rooms[rng.next_int(rooms.size())]
		var cell := Vector2i(
			rng.randi_range(room.position.x + 1, room.end.x - 2),
			rng.randi_range(room.position.y + 1, room.end.y - 2))
		if not is_wall_tile(tile_at(cell)) and tile_at(cell) != CLOSED_DOOR:
			return cell
	return hero


func _mob_index_by_id(actor_id: int) -> int:
	for index in range(mobs.size()):
		if int(mobs[index].get("id", -1)) == actor_id:
			return index
	return -1


func _mob_act(i: int, blocking: PackedByteArray) -> void:
	var mob: Dictionary = mobs[i]
	var pos: Vector2i = mob["pos"]
	if mob["kind"] == "goo" and tile_at(pos) == WATER and int(mob["hp"]) < SpdCombat.mob_hp("goo"):
		mob["hp"] = int(mob["hp"]) + 1
		mobs[i] = mob
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
	if mob["state"] == "wandering" and sees_hero:
		# Mob.Wandering notices an unstealthed hero with 1/(distance/2).
		if rng.randf() < minf(1.0, 2.0 / maxf(1.0, float(distance))):
			mob["state"] = "hunting"
			mob["target"] = hero
	mob["enemy_seen"] = sees_hero
	if sees_hero and mob["state"] == "hunting":
		mob["state"] = "hunting"
		mob["target"] = hero
	if mob["kind"] == "goo" and int(mob.get("charge", 0)) > 0:
		var charge := int(mob["charge"])
		if distance > 2 or not sees_hero:
			mob["charge"] = 0
			mobs[i] = mob
		elif charge == 1:
			mob["charge"] = 2
			mobs[i] = mob
			message += " 구가 크게 부풀어 오릅니다!"
			return
		else:
			mob["charge"] = 0
			mobs[i] = mob
			_mob_strike(mob, true)
			return
	if distance <= 1 and sees_hero and mob["state"] == "hunting":
		if mob["kind"] == "goo" and rng.randi_range(0, 4) == 0:
			mob["charge"] = 1
			message += " 구가 부풀어 오릅니다!"
		else:
			_mob_strike(mob)
		mobs[i] = mob
		return
	if sees_hero and mob["state"] == "hunting" and distance <= 4 \
			and ["dm100", "shaman", "warlock", "eye", "scorpio", "tengu"].has(mob["kind"]):
		if mob["kind"] == "eye" and int(mob.get("charge", 0)) == 0:
			mob["charge"] = 1
			mobs[i] = mob
			message += " 사악한 눈이 광선을 충전합니다!"
			return
		mob["charge"] = 0
		mobs[i] = mob
		_mob_strike(mob)
		return
	var goal: Vector2i = mob["target"]
	if pos == goal:
		mob["state"] = "wandering"
		mob["target"] = _random_wander_destination()
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
	if best == pos and mob["state"] == "wandering":
		mob["target"] = _random_wander_destination()
	mob["pos"] = best
	_trample(best)
	mobs[i] = mob


func _mob_strike(mob: Dictionary, pumped: bool = false) -> void:
	var kind: String = mob["kind"]
	var armor_encumbrance := maxi(0, _gear_requirement(armor_tier, armor_level) - strength)
	var defense := maxi(1, roundi((SpdCombat.HERO_DEFENSE_SKILL + level - 1) \
		/ pow(1.5, armor_encumbrance)))
	var armor_min := maxi(0, _armor_min() - armor_encumbrance * 2)
	var armor_max := maxi(0, _armor_max() - armor_encumbrance * 2)
	var strike: Dictionary
	if kind == "goo":
		strike = SpdCombat.goo_attacks_hero(rng, int(mob["hp"]), defense,
			armor_min, armor_max, pumped)
	else:
		strike = SpdCombat.mob_attacks_hero(rng, kind, level,
			armor_max, 0, 1, armor_min, defense)
	var name := _mob_name(kind)
	if strike["hit"]:
		hp = maxi(0, hp - int(strike["damage"]))
		message += " %s에게 %d 피해를 받았습니다." % [name, strike["damage"]]
		if kind == "goo" and rng.randi_range(0, 2) == 0:
			ooze_left = 20
			message += " 검은 점액이 묻었습니다."
	else:
		message += " %s의 공격이 빗나갔습니다." % name


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
		"goo": return "구"
		"skeleton": return "해골"
		"thief": return "도둑"
		"dm100": return "DM-100"
		"guard": return "간수"
		"necromancer": return "강령술사"
		"tengu": return "텐구"
		"bat": return "흡혈박쥐"
		"brute": return "놀 야만인"
		"shaman": return "놀 주술사"
		"spinner": return "거미"
		"dm200": return "DM-200"
		"dm300": return "DM-300"
		"ghoul": return "구울"
		"elemental": return "정령"
		"warlock": return "흑마법사"
		"monk": return "수도승"
		"golem": return "골렘"
		"king": return "드워프 왕"
		"succubus": return "서큐버스"
		"eye": return "사악한 눈"
		"scorpio": return "전갈"
		"yog": return "요그제바"
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
			"enemy_seen": mob["enemy_seen"], "target": _vector_data(mob["target"]),
			"charge": mob.get("charge", 0)})
	var saved_potions: Array = []
	for potion in potions:
		saved_potions.append(_vector_data(potion))
	var saved_items: Array = []
	for item in items:
		saved_items.append({"kind": item["kind"], "pos": _vector_data(item["pos"]),
			"tier": item.get("tier", 0)})
	var saved_tiles: Array = []
	for tile in tiles:
		saved_tiles.append(tile)
	var saved_explored: Array = []
	for bit in explored:
		saved_explored.append(bit)
	return {"map_size": [WIDTH, HEIGHT], "tiles": saved_tiles, "explored": saved_explored,
		"rooms": saved_rooms, "room_kinds": room_kinds.duplicate(),
		"mobs": saved_mobs, "potions": saved_potions,
		"items": saved_items,
		"hero": _vector_data(hero), "stairs": _vector_data(stairs),
		"depth": depth, "dungeon_seed": dungeon_seed,
		"hp": hp, "max_hp": max_hp,
		"potion_count": potion_count, "healing_left": healing_left,
		"ooze_left": ooze_left,
		"food_count": food_count, "upgrade_count": upgrade_count,
		"strength_drops": strength_drops, "upgrade_drops": upgrade_drops,
		"wand_charges": wand_charges,
		"hunger": hunger, "hunger_damage": hunger_damage,
		"level": level, "experience": experience, "strength": strength,
		"weapon_tier": weapon_tier, "weapon_level": weapon_level,
		"armor_tier": armor_tier, "armor_level": armor_level, "won": won,
		"turns": turns, "message": message, "rng": rng.state_snapshot(),
		"clock": clock.snapshot(), "next_actor_id": next_actor_id,
		"mob_rotation": _mob_rotation.duplicate(),
		"mob_rotation_index": _mob_rotation_index}


func restore_snapshot(saved: Dictionary) -> bool:
	var saved_size = saved.get("map_size")
	if typeof(saved_size) != TYPE_ARRAY or saved_size.size() != 2 \
			or not _is_saved_int(saved_size[0]) or not _is_saved_int(saved_size[1]) \
			or int(saved_size[0]) != WIDTH or int(saved_size[1]) != HEIGHT:
		return false
	var saved_tiles = saved.get("tiles")
	var saved_explored = saved.get("explored")
	var saved_rooms = saved.get("rooms")
	var saved_room_kinds = saved.get("room_kinds", [])
	var saved_mobs = saved.get("mobs")
	var saved_potions = saved.get("potions")
	var saved_items = saved.get("items", [])
	if typeof(saved_tiles) != TYPE_ARRAY or saved_tiles.size() != WIDTH * HEIGHT \
			or typeof(saved_explored) != TYPE_ARRAY or saved_explored.size() != WIDTH * HEIGHT \
			or typeof(saved_rooms) != TYPE_ARRAY or typeof(saved_room_kinds) != TYPE_ARRAY \
			or typeof(saved_mobs) != TYPE_ARRAY \
			or typeof(saved_potions) != TYPE_ARRAY or typeof(saved_items) != TYPE_ARRAY:
		return false
	if not saved_room_kinds.is_empty() and saved_room_kinds.size() != saved_rooms.size():
		return false
	for kind in saved_room_kinds:
		if not ["entrance", "standard", "special_placeholder", "exit"].has(kind):
			return false
	if not _valid_saved_vector(saved.get("hero")) or not _valid_saved_vector(saved.get("stairs")):
		return false
	for key in ["depth", "hp", "max_hp", "potion_count", "healing_left", "turns", "next_actor_id"]:
		if not _is_saved_int(saved.get(key)):
			return false
	if saved["depth"] < 1 or saved["depth"] > 26 or saved["max_hp"] < 1 or saved["hp"] < 0 \
			or saved["hp"] > saved["max_hp"] or saved["potion_count"] < 0 \
			or saved["healing_left"] < 0 or saved["turns"] < 0 or saved["next_actor_id"] < 1:
		return false
	if typeof(saved.get("message")) != TYPE_STRING or typeof(saved.get("rng")) != TYPE_ARRAY \
			or typeof(saved.get("clock")) != TYPE_DICTIONARY:
		return false
	if saved.has("dungeon_seed") and not _is_saved_int(saved["dungeon_seed"]):
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
				or not _is_saved_int(value.get("charge", 0)) \
				or typeof(value.get("enemy_seen")) != TYPE_BOOL \
				or not ["sleeping", "hunting", "wandering"].has(value.get("state")):
			return false
		if value["id"] < 1 or ids.has(value["id"]) or value["hp"] <= 0 \
				or value["id"] >= saved["next_actor_id"]:
			return false
		ids[int(value["id"])] = true
		restored_mobs.append({"id": int(value["id"]), "kind": value["kind"],
			"pos": _data_vector(value["pos"]), "hp": int(value["hp"]), "state": value["state"],
			"enemy_seen": value["enemy_seen"], "target": _data_vector(value["target"]),
			"charge": int(value.get("charge", 0))})
	var restored_potions: Array[Vector2i] = []
	for value in saved_potions:
		if not _valid_saved_vector(value):
			return false
		restored_potions.append(_data_vector(value))
	var restored_items: Array[Dictionary] = []
	for value in saved_items:
		if typeof(value) != TYPE_DICTIONARY or not ["food", "upgrade", "strength",
				"weapon", "armor", "wand", "amulet"].has(value.get("kind")) \
				or not _valid_saved_vector(value.get("pos")) \
				or not _is_saved_int(value.get("tier")):
			return false
		if value["tier"] < 0 or value["tier"] > 5:
			return false
		restored_items.append({"kind": value["kind"], "pos": _data_vector(value["pos"]),
			"tier": int(value["tier"])})
	var progress_keys := ["food_count", "upgrade_count", "wand_charges",
		"strength_drops", "upgrade_drops",
		"ooze_left",
		"hunger", "level", "experience", "strength",
		"weapon_tier", "weapon_level", "armor_tier", "armor_level"]
	for key in progress_keys:
		if saved.has(key) and (not _is_saved_int(saved[key]) or saved[key] < 0):
			return false
	if saved.has("hunger_damage") and (typeof(saved["hunger_damage"]) != TYPE_FLOAT \
			and typeof(saved["hunger_damage"]) != TYPE_INT):
		return false
	if saved.has("won") and typeof(saved["won"]) != TYPE_BOOL:
		return false
	var saved_rotation = saved.get("mob_rotation", [])
	var saved_rotation_index = saved.get("mob_rotation_index", 0)
	if typeof(saved_rotation) != TYPE_ARRAY or not _is_saved_int(saved_rotation_index):
		return false
	for kind in saved_rotation:
		if typeof(kind) != TYPE_STRING or not SpdCombat.MOB_STATS.has(kind):
			return false
	if saved_rotation_index < 0 or (not saved_rotation.is_empty() \
			and saved_rotation_index >= saved_rotation.size()):
		return false
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
	room_kinds.clear()
	if saved_room_kinds.is_empty():
		for _room in rooms:
			room_kinds.append("standard")
	else:
		for kind in saved_room_kinds:
			room_kinds.append(kind)
	mobs = restored_mobs
	potions = restored_potions
	items = restored_items
	hero = _data_vector(saved["hero"])
	stairs = _data_vector(saved["stairs"])
	depth = int(saved["depth"])
	dungeon_seed = int(saved.get("dungeon_seed", 0))
	hp = int(saved["hp"])
	max_hp = int(saved["max_hp"])
	potion_count = int(saved["potion_count"])
	healing_left = int(saved["healing_left"])
	ooze_left = int(saved.get("ooze_left", 0))
	food_count = int(saved.get("food_count", 1))
	upgrade_count = int(saved.get("upgrade_count", 0))
	strength_drops = int(saved.get("strength_drops", 0))
	upgrade_drops = int(saved.get("upgrade_drops", 0))
	wand_charges = int(saved.get("wand_charges", 0))
	hunger = int(saved.get("hunger", 0))
	hunger_damage = float(saved.get("hunger_damage", 0.0))
	level = int(saved.get("level", 1))
	experience = int(saved.get("experience", 0))
	strength = int(saved.get("strength", 10))
	weapon_tier = int(saved.get("weapon_tier", 1))
	weapon_level = int(saved.get("weapon_level", 0))
	armor_tier = int(saved.get("armor_tier", 1))
	armor_level = int(saved.get("armor_level", 0))
	won = saved.get("won", false)
	turns = int(saved["turns"])
	message = saved["message"]
	next_actor_id = int(saved["next_actor_id"])
	_mob_rotation.clear()
	for kind in saved_rotation:
		_mob_rotation.append(kind)
	_mob_rotation_index = int(saved_rotation_index)
	if _mob_rotation.is_empty() and depth < 26 and SpdCampaign.boss(depth) == "":
		_mob_rotation = SpdCampaign.rotation(depth)
		_mob_rotation_index = 0
	if not saved.has("mob_rotation") and depth < 26 \
			and SpdCampaign.boss(depth) == "" and not clock.has(RESPAWNER_ID):
		clock.add(RESPAWNER_ID, SpdActorClock.BUFF_PRIORITY, RESPAWN_COOLDOWN)
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
