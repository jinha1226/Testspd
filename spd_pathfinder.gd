extends RefCounted
## Breadth-first distance map and step selection from watabou.utils.PathFinder.
## The source searches backward from the goal, then picks the first closer
## neighbor in dir order. Border guards replace its edge-offset shortcuts.


static func get_step(width: int, height: int, from: Vector2i, to: Vector2i,
		passable: PackedByteArray) -> Vector2i:
	var path: Array[Vector2i] = find_path(width, height, from, to, passable)
	return path.front() if not path.is_empty() else from


static func find_path(width: int, height: int, from: Vector2i, to: Vector2i,
		passable: PackedByteArray) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if from == to or not _inside(from, width, height) or not _inside(to, width, height) \
			or passable.size() != width * height:
		return path
	var distance := PackedInt32Array()
	distance.resize(width * height)
	distance.fill(2147483647)
	var goal := to.x + to.y * width
	var start := from.x + from.y * width
	distance[goal] = 0
	var queue: Array[int] = [goal]
	var head := 0
	# Source dirLR order, with x/y bounds checked explicitly.
	var outward := [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1),
		Vector2i(1, 0), Vector2i(1, 1)]
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		if index == start:
			break
		var origin := Vector2i(index % width, int(index / width))
		for direction in outward:
			var cell: Vector2i = origin + direction
			if not _inside(cell, width, height):
				continue
			var neighbor := cell.x + cell.y * width
			if neighbor == start or (passable[neighbor] != 0
					and distance[neighbor] > distance[index] + 1):
				distance[neighbor] = distance[index] + 1
				queue.append(neighbor)
	if distance[start] == 2147483647:
		return path
	var downhill := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	var current := from
	while current != to:
		var current_index := current.x + current.y * width
		var best := current
		var best_distance := distance[current_index]
		for direction in downhill:
			var cell: Vector2i = current + direction
			if not _inside(cell, width, height):
				continue
			var candidate := distance[cell.x + cell.y * width]
			if candidate < best_distance:
				best = cell
				best_distance = candidate
		if best == current:
			path.clear()
			return path
		path.append(best)
		current = best
	return path


static func distance_map(width: int, height: int, goal: Vector2i,
		passable: PackedByteArray, limit: int = 2147483647) -> PackedInt32Array:
	var distance := _new_distance(width * height)
	if not _inside(goal, width, height) or passable.size() != width * height:
		return distance
	var queue: Array[int] = [goal.x + goal.y * width]
	distance[queue[0]] = 0
	var head := 0
	while head < queue.size():
		var step: int = queue[head]
		head += 1
		var next_distance := distance[step] + 1
		if next_distance > limit:
			return distance
		for neighbor in _neighbors_lr(step, width, height):
			if passable[neighbor] != 0 and distance[neighbor] > next_distance:
				distance[neighbor] = next_distance
				queue.append(neighbor)
	return distance


static func get_step_back(width: int, height: int, current: Vector2i,
		from: Vector2i, lookahead: int, passable: PackedByteArray,
		can_approach_from_pos: bool) -> Vector2i:
	var failure := Vector2i(-1, -1)
	if not _inside(current, width, height) or not _inside(from, width, height) \
			or passable.size() != width * height:
		return failure
	var current_index := current.x + current.y * width
	var from_index := from.x + from.y * width
	var distance := _new_distance(width * height)
	var queue: Array[int] = [from_index]
	distance[from_index] = 0
	var head := 0
	var destination_distance := 2147483647
	var highest_distance := 0
	while head < queue.size():
		var step: int = queue[head]
		head += 1
		highest_distance = distance[step]
		if highest_distance > destination_distance:
			highest_distance = destination_distance
			break
		if step == current_index:
			destination_distance = highest_distance + lookahead
		var next_distance := highest_distance + 1
		for neighbor in _neighbors_lr(step, width, height):
			if passable[neighbor] != 0 and distance[neighbor] > next_distance:
				distance[neighbor] = next_distance
				queue.append(neighbor)
	if highest_distance == 0:
		return failure
	if not can_approach_from_pos:
		var new_distance := distance[current_index]
		var queued := PackedByteArray()
		queued.resize(width * height)
		queue = [current_index]
		queued[current_index] = 1
		head = 0
		while head < queue.size():
			var step: int = queue[head]
			head += 1
			if distance[step] > new_distance:
				new_distance = distance[step]
			for neighbor in _neighbors_lr(step, width, height):
				if passable[neighbor] == 0:
					continue
				if distance[neighbor] < distance[current_index]:
					passable[neighbor] = 0
				elif distance[neighbor] >= distance[step] and queued[neighbor] == 0:
					queue.append(neighbor)
					queued[neighbor] = 1
		highest_distance = mini(new_distance, highest_distance)
	var goals := PackedByteArray()
	goals.resize(width * height)
	for index in range(width * height):
		goals[index] = 1 if distance[index] == highest_distance else 0
	if goals[current_index] != 0:
		return failure
	distance = _new_distance(width * height)
	queue.clear()
	for index in range(width * height):
		if goals[index] != 0:
			distance[index] = 0
			queue.append(index)
	head = 0
	while head < queue.size():
		var step: int = queue[head]
		head += 1
		if step == current_index:
			break
		var next_distance := distance[step] + 1
		for neighbor in _neighbors_lr(step, width, height):
			if neighbor == current_index or (passable[neighbor] != 0
					and distance[neighbor] > next_distance):
				distance[neighbor] = next_distance
				queue.append(neighbor)
	if distance[current_index] == 2147483647:
		return failure
	var best := current_index
	var best_distance := distance[current_index]
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for direction in directions:
		var neighbor: Vector2i = current + direction
		if _inside(neighbor, width, height):
			var neighbor_index := neighbor.x + neighbor.y * width
			if distance[neighbor_index] < best_distance:
				best = neighbor_index
				best_distance = distance[neighbor_index]
	return Vector2i(best % width, int(best / width))


static func _new_distance(size: int) -> PackedInt32Array:
	var distance := PackedInt32Array()
	distance.resize(size)
	distance.fill(2147483647)
	return distance


static func _neighbors_lr(step: int, width: int, height: int) -> Array[int]:
	var result: Array[int] = []
	var cell := Vector2i(step % width, int(step / width))
	for offset in [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
			Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1),
			Vector2i(1, 0), Vector2i(1, 1)]:
		var neighbor: Vector2i = cell + offset
		if _inside(neighbor, width, height):
			result.append(neighbor.x + neighbor.y * width)
	return result


static func _inside(cell: Vector2i, width: int, height: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height
