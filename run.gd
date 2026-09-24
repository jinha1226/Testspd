extends RefCounted
## Independent Godot implementation of the first SPD-style dungeon loop.
## Upstream inspiration and license are recorded in README.md and ATTRIBUTION.md.

const WIDTH := 36
const HEIGHT := 36
const WALL := 0
const FLOOR := 1
const CLOSED_DOOR := 2
const OPEN_DOOR := 3
const ENTRANCE := 4
const EXIT := 5
const SIGHT_RADIUS := 6
const DIRS8 := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0),                    Vector2i(1, 0),
	Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
]

var tiles := PackedInt32Array()
var explored := PackedByteArray()
var visible := PackedByteArray()
var rooms: Array[Rect2i] = []
var rats: Array[Dictionary] = []
var potions: Array[Vector2i] = []
var hero := Vector2i.ZERO
var stairs := Vector2i.ZERO
var depth := 1
var hp := 20
var max_hp := 20
var potion_count := 0
var turns := 0
var message := ""
var rng := RandomNumberGenerator.new()


func start(seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
	depth = 1
	hp = max_hp
	potion_count = 0
	turns = 0
	_build_floor()
	message = "1층 하수도. 계단을 찾으세요."


func _build_floor() -> void:
	tiles.resize(WIDTH * HEIGHT)
	tiles.fill(WALL)
	explored.resize(WIDTH * HEIGHT)
	explored.fill(0)
	visible.resize(WIDTH * HEIGHT)
	visible.fill(0)
	rooms.clear()
	rats.clear()
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
	hero = _room_center(rooms.front())
	stairs = _room_center(rooms.back())
	tiles[_index(hero)] = ENTRANCE
	tiles[_index(stairs)] = EXIT
	for room_index in range(1, rooms.size()):
		var room := rooms[room_index]
		if room_index < 6:
			var rat_pos := _room_center(room) + Vector2i(
				rng.randi_range(-1, 1), rng.randi_range(-1, 1)
			)
			if rat_pos != stairs and rat_pos != hero:
				rats.append({"pos": rat_pos, "hp": 5})
		if room_index == 2 or room_index == 5:
			var potion_pos := _room_center(room) + Vector2i(1, 0)
			if potion_pos != stairs:
				potions.append(potion_pos)
	_reveal()


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


func is_visible(p: Vector2i) -> bool:
	return _inside(p) and visible[_index(p)] != 0


func is_explored(p: Vector2i) -> bool:
	return _inside(p) and explored[_index(p)] != 0


func _blocks_sight(p: Vector2i) -> bool:
	var tile := tile_at(p)
	return tile == WALL or tile == CLOSED_DOOR


func _line_visible(target: Vector2i) -> bool:
	var p := hero
	var dx: int = abs(target.x - hero.x)
	var dy: int = abs(target.y - hero.y)
	var sx := 1 if hero.x < target.x else -1
	var sy := 1 if hero.y < target.y else -1
	var error := dx - dy
	while p != target:
		var twice := 2 * error
		if twice > -dy:
			error -= dy
			p.x += sx
		if twice < dx:
			error += dx
			p.y += sy
		if p != target and _blocks_sight(p):
			return false
	return true


func _reveal() -> void:
	visible.fill(0)
	for y in range(maxi(0, hero.y - SIGHT_RADIUS), mini(HEIGHT, hero.y + SIGHT_RADIUS + 1)):
		for x in range(maxi(0, hero.x - SIGHT_RADIUS), mini(WIDTH, hero.x + SIGHT_RADIUS + 1)):
			var p := Vector2i(x, y)
			if hero.distance_squared_to(p) <= SIGHT_RADIUS * SIGHT_RADIUS and _line_visible(p):
				visible[_index(p)] = 1
				explored[_index(p)] = 1


func _rat_index_at(p: Vector2i) -> int:
	for i in range(rats.size()):
		if rats[i]["pos"] == p:
			return i
	return -1


func step(direction: Vector2i) -> bool:
	if hp <= 0 or direction == Vector2i.ZERO:
		return false
	if absi(direction.x) > 1 or absi(direction.y) > 1:
		return false
	var target := hero + direction
	if not _inside(target) or tile_at(target) == WALL:
		message = "벽이 가로막고 있습니다."
		return false
	var rat_index := _rat_index_at(target)
	if rat_index >= 0:
		var rat: Dictionary = rats[rat_index]
		var damage := rng.randi_range(2, 4)
		rat["hp"] = int(rat["hp"]) - damage
		if int(rat["hp"]) <= 0:
			rats.remove_at(rat_index)
			message = "쥐를 쓰러뜨렸습니다."
		else:
			rats[rat_index] = rat
			message = "쥐에게 %d 피해." % damage
	elif tile_at(target) == CLOSED_DOOR:
		tiles[_index(target)] = OPEN_DOOR
		message = "문을 열었습니다."
	else:
		hero = target
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
	hp = mini(max_hp, hp + 8)
	message = "물약으로 체력을 회복했습니다."
	_advance_turn()
	return true


func _advance_turn() -> void:
	turns += 1
	_enemy_turn()
	_reveal()
	if hp <= 0:
		message = "%d층에서 쓰러졌습니다. 새 게임을 눌러 재시작하세요." % depth


func _enemy_turn() -> void:
	for i in range(rats.size()):
		var rat: Dictionary = rats[i]
		var pos: Vector2i = rat["pos"]
		var distance := maxi(absi(pos.x - hero.x), absi(pos.y - hero.y))
		if distance <= 1:
			hp = maxi(0, hp - rng.randi_range(1, 2))
			message += " 쥐가 공격했습니다."
			continue
		if distance > 7:
			continue
		var best := pos
		var best_distance := pos.distance_squared_to(hero)
		for direction in DIRS8:
			var next: Vector2i = pos + direction
			if tile_at(next) == WALL or tile_at(next) == CLOSED_DOOR or next == hero:
				continue
			if _rat_index_at(next) >= 0:
				continue
			var next_distance := next.distance_squared_to(hero)
			if next_distance < best_distance:
				best = next
				best_distance = next_distance
		rat["pos"] = best
		rats[i] = rat


func has_visible_enemy() -> bool:
	for rat in rats:
		if is_visible(rat["pos"]):
			return true
	return false


func path_to(target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_explored(target) or target == hero:
		return result
	var queue: Array[Vector2i] = [hero]
	var previous := {hero: hero}
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		if p == target:
			break
		for direction in DIRS8:
			var next: Vector2i = p + direction
			if previous.has(next) or not is_explored(next) or tile_at(next) == WALL:
				continue
			previous[next] = p
			queue.append(next)
	if not previous.has(target):
		return result
	var p := target
	while p != hero:
		result.push_front(p)
		p = previous[p]
	return result
