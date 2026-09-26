extends RefCounted
## RegularLevel.createMobs placement rules, for rectangular standard rooms.
## The full Java room types and mob variants have not yet been ported.

const DISTANCE_LIMIT := 8
const MAX_ROOM_TRIES := 31
const MAX_ROOM_PASSES := 64
const DIRECTIONS := [
	Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
	Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
]


static func positions(rng, width: int, height: int, tiles: PackedInt32Array,
		rooms: Array[Rect2i], room_kinds: Array[String],
		entrance: Vector2i, exit_cell: Vector2i,
		entrance_fov: PackedByteArray, count: int, depth: int,
		wall_tiles: Array[int], closed_door: int,
		create_mob: Callable) -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	if rooms.is_empty() or room_kinds.size() != rooms.size() \
			or tiles.size() != width * height \
			or entrance_fov.size() != width * height:
		return placed
	var room_order: Array[int] = []
	for room_index in range(rooms.size()):
		if room_kinds[room_index] != "special_placeholder":
			room_order.append(room_index)
	# java.util.Collections.shuffle uses this descending Fisher-Yates order.
	for shuffle_index in range(room_order.size() - 1, 0, -1):
		var other_index: int = rng.next_int(shuffle_index + 1)
		var previous: int = room_order[shuffle_index]
		room_order[shuffle_index] = room_order[other_index]
		room_order[other_index] = previous
	var nearby := _entrance_distance_map(width, height, tiles, rooms.front(),
		entrance, wall_tiles, closed_door)
	var occupied := {}
	var cursor := 0
	var attempts := 0
	var pending_kind := ""
	while placed.size() < count and attempts < room_order.size() * MAX_ROOM_PASSES:
		# Level.createMob is called before room selection. On a failed room
		# attempt Java keeps the same mob for the next room.
		if pending_kind.is_empty():
			pending_kind = str(create_mob.call())
		var room: Rect2i = rooms[room_order[cursor]]
		cursor = (cursor + 1) % room_order.size()
		attempts += 1
		var first: Vector2i = _try_room(rng, room, width, tiles, exit_cell,
			entrance_fov, nearby, occupied, wall_tiles, closed_door)
		if first == Vector2i(-1, -1):
			continue
		placed.append({"kind": pending_kind, "pos": first})
		occupied[first] = true
		pending_kind = ""
		if depth > 1 and placed.size() < count and rng.next_int(4) == 0:
			pending_kind = str(create_mob.call())
			var second: Vector2i = _try_room(rng, room, width, tiles, exit_cell,
				entrance_fov, nearby, occupied, wall_tiles, closed_door)
			if second != Vector2i(-1, -1):
				placed.append({"kind": pending_kind, "pos": second})
				occupied[second] = true
				pending_kind = ""
	return placed


static func _try_room(rng, room: Rect2i, width: int, tiles: PackedInt32Array,
		exit_cell: Vector2i, entrance_fov: PackedByteArray,
		nearby: PackedByteArray, occupied: Dictionary, wall_tiles: Array[int],
		closed_door: int) -> Vector2i:
	if room.size.x < 3 or room.size.y < 3:
		return Vector2i(-1, -1)
	for _attempt in range(MAX_ROOM_TRIES):
		# Room.random() samples the inclusive interior, one tile off each wall.
		var cell := Vector2i(
			rng.randi_range(room.position.x + 1, room.end.x - 2),
			rng.randi_range(room.position.y + 1, room.end.y - 2))
		var index := cell.x + cell.y * width
		if not occupied.has(cell) and entrance_fov[index] == 0 \
				and nearby[index] == 0 and cell != exit_cell \
				and not wall_tiles.has(tiles[index]) and tiles[index] != closed_door:
			return cell
	return Vector2i(-1, -1)


static func _entrance_distance_map(width: int, height: int,
		tiles: PackedInt32Array, entrance_room: Rect2i, entrance: Vector2i,
		wall_tiles: Array[int], closed_door: int) -> PackedByteArray:
	var near := PackedByteArray()
	near.resize(width * height)
	var queue: Array[Vector2i] = [entrance]
	near[entrance.x + entrance.y * width] = 1
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var distance: int = near[cell.x + cell.y * width] - 1
		if distance >= DISTANCE_LIMIT:
			continue
		for direction in DIRECTIONS:
			var next: Vector2i = cell + direction
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			var index := next.x + next.y * width
			if near[index] != 0 or wall_tiles.has(tiles[index]):
				continue
			# Closed doors inside the entrance room are traversable for this
			# safety check; doors on its perimeter still block the walk.
			if tiles[index] == closed_door and not _inside_room(next, entrance_room):
				continue
			near[index] = distance + 2
			queue.append(next)
	return near


static func _inside_room(cell: Vector2i, room: Rect2i) -> bool:
	return cell.x > room.position.x and cell.y > room.position.y \
		and cell.x < room.end.x - 1 and cell.y < room.end.y - 1
