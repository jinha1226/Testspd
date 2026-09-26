extends RefCounted
## Region room quotas from Sewer/Prison/Caves/City/HallsLevel.initRooms.
## Geometry is an interim connected-room planner. Java Room, LoopBuilder,
## FigureEightBuilder, and individual special-room painters remain unported.

const STANDARD_WEIGHTS := [[1, 3, 1], [1, 1], [2, 1], [1, 3, 1], [2, 1]]
const STANDARD_BASE := [4, 5, 6, 6, 8]
const SPECIAL_WEIGHTS := [[1, 4], [1, 3, 1], [4, 1], [2, 1], [1, 1]]
const SPECIAL_BASE := [1, 1, 2, 2, 2]


static func room_quotas(depth: int, rng) -> Vector2i:
	var region: int = clampi(int((depth - 1) / 5), 0, 4)
	return Vector2i(
		STANDARD_BASE[region] + _weighted_index(STANDARD_WEIGHTS[region], rng),
		SPECIAL_BASE[region] + _weighted_index(SPECIAL_WEIGHTS[region], rng))


static func create(width: int, height: int, depth: int, rng) -> Dictionary:
	var quotas := room_quotas(depth, rng)
	var kinds: Array[String] = ["entrance"]
	for _i in range(quotas.x):
		kinds.append("standard")
	for _i in range(quotas.y):
		kinds.append("special_placeholder")
	kinds.append("exit")
	var rooms: Array[Rect2i] = []
	for _retry in range(20):
		rooms.clear()
		for kind in kinds:
			var placed := false
			for _attempt in range(700):
				var maximum := 6 if kind == "special_placeholder" else 7
				var size := Vector2i(rng.randi_range(5, maximum),
					rng.randi_range(5, maximum))
				var position := Vector2i(
					rng.randi_range(2, width - size.x - 3),
					rng.randi_range(2, height - size.y - 3))
				var candidate := Rect2i(position, size)
				if _fits(candidate, rooms):
					rooms.append(candidate)
					placed = true
					break
			if not placed:
				break
		if rooms.size() == kinds.size():
			break
	if rooms.size() != kinds.size():
		rooms = _grid_fallback(width, height, kinds.size(), rng)
	# The exit is placed far from the entrance, as the source main path does.
	var farthest := 1
	var longest := -1
	for index in range(1, rooms.size()):
		var delta := _center(rooms[index]) - _center(rooms[0])
		var distance := delta.length_squared()
		if distance > longest:
			longest = distance
			farthest = index
	var last := rooms.size() - 1
	var previous: Rect2i = rooms[last]
	rooms[last] = rooms[farthest]
	rooms[farthest] = previous
	var edges: Array[Vector2i] = []
	var linked := {0: true}
	while linked.size() < rooms.size():
		var best_from := -1
		var best_to := -1
		var best_score := INF
		for from in linked:
			for to in range(rooms.size()):
				if linked.has(to):
					continue
				var delta := _center(rooms[from]) - _center(rooms[to])
				var score := float(delta.length_squared())
				if score < best_score:
					best_score = score
					best_from = from
					best_to = to
		edges.append(Vector2i(best_from, best_to))
		linked[best_to] = true
	# Keep at least one circuit instead of a corridor-only tree.
	var extra := maxi(1, int(rooms.size() / 5))
	for _i in range(extra):
		var best_edge := Vector2i(-1, -1)
		var best_score := INF
		for a in range(rooms.size()):
			for b in range(a + 1, rooms.size()):
				if _has_edge(edges, a, b):
					continue
				var delta := _center(rooms[a]) - _center(rooms[b])
				var score: float = float(delta.length_squared()) + rng.randf() * 20.0
				if score < best_score:
					best_score = score
					best_edge = Vector2i(a, b)
		if best_edge.x >= 0:
			edges.append(best_edge)
	return {"rooms": rooms, "kinds": kinds, "edges": edges,
		"standards": quotas.x, "specials": quotas.y}


static func _weighted_index(weights: Array, rng) -> int:
	var total := 0
	for weight in weights:
		total += int(weight)
	var roll: int = rng.next_int(total)
	for index in range(weights.size()):
		roll -= int(weights[index])
		if roll < 0:
			return index
	return weights.size() - 1


static func _fits(candidate: Rect2i, existing: Array[Rect2i]) -> bool:
	for room in existing:
		if candidate.grow(1).intersects(room):
			return false
	return true


static func _grid_fallback(width: int, height: int, count: int, rng) -> Array[Rect2i]:
	var slots: Array[Vector2i] = []
	for y in range(4):
		for x in range(4):
			slots.append(Vector2i(x, y))
	for index in range(slots.size() - 1, 0, -1):
		var swap_index: int = rng.next_int(index + 1)
		var old: Vector2i = slots[index]
		slots[index] = slots[swap_index]
		slots[swap_index] = old
	var result: Array[Rect2i] = []
	for index in range(count):
		var position := Vector2i(2 + slots[index].x * 8,
			2 + slots[index].y * 8)
		var size := Vector2i(mini(6, width - position.x - 2),
			mini(6, height - position.y - 2))
		result.append(Rect2i(position, size))
	return result


static func _center(room: Rect2i) -> Vector2i:
	return room.position + Vector2i(int(room.size.x / 2), int(room.size.y / 2))


static func _has_edge(edges: Array[Vector2i], a: int, b: int) -> bool:
	for edge in edges:
		if (edge.x == a and edge.y == b) or (edge.x == b and edge.y == a):
			return true
	return false
