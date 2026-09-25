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
	while head < queue.size() and distance[start] == 2147483647:
		var index: int = queue[head]
		head += 1
		var origin := Vector2i(index % width, int(index / width))
		for direction in outward:
			var cell: Vector2i = origin + direction
			if not _inside(cell, width, height):
				continue
			var neighbor := cell.x + cell.y * width
			if distance[neighbor] <= distance[index] + 1:
				continue
			if neighbor == start or passable[neighbor] != 0:
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


static func _inside(cell: Vector2i, width: int, height: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height
