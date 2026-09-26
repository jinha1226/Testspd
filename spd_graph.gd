extends RefCounted
## Graph.java at SPD 2bb34a4e91d2; nodes implement distance, price, edges.

const MAX_DISTANCE := 2147483647


static func set_price(nodes: Array, value: int) -> void:
	for node in nodes:
		node.set_price(value)


static func build_distance_map(nodes: Array, focus) -> void:
	for node in nodes:
		node.set_distance(MAX_DISTANCE)
	var queue: Array = [focus]
	focus.set_distance(0)
	var head := 0
	while head < queue.size():
		var node = queue[head]
		head += 1
		var distance: int = node.get_distance()
		var price: int = node.get_price()
		for edge in node.edges():
			if edge.get_distance() > distance + price:
				queue.append(edge)
				edge.set_distance(distance + price)


static func build_path(_nodes: Array, from, to):
	var path: Array = []
	var room = from
	while room != to:
		var minimum: int = room.get_distance()
		var next = null
		for edge in room.edges():
			var distance: int = edge.get_distance()
			if distance < minimum:
				minimum = distance
				next = edge
		if next == null:
			return null
		path.append(next)
		room = next
	return path
