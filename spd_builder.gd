extends RefCounted
## Builder.java spatial methods from SPD 2bb34a4e91d2.
## Subclass-specific LoopBuilder/FigureEightBuilder algorithms follow later.

const Point = preload("res://spd_point.gd")
const Rect = preload("res://spd_rect.gd")
const Room = preload("res://spd_room.gd")
const GameMath = preload("res://spd_game_math.gd")

const A := 180.0 / PI


static func find_neighbours(rooms: Array) -> void:
	for i in range(rooms.size() - 1):
		for j in range(i + 1, rooms.size()):
			rooms[i].add_neigbour(rooms[j])


static func find_free_space(start, collision: Array, max_size: int, rng):
	var space = Rect.new(start.x - max_size, start.y - max_size,
		start.x + max_size, start.y + max_size)
	var colliding := collision.duplicate()
	while true:
		for index in range(colliding.size() - 1, -1, -1):
			var room = colliding[index]
			if room.is_empty() \
					or maxi(space.left, room.left) >= mini(space.right, room.right) \
					or maxi(space.top, room.top) >= mini(space.bottom, room.bottom):
				colliding.remove_at(index)
		var closest_room = null
		var closest_diff := 2147483647.0
		var cur_diff = Point.new()
		for room in colliding:
			cur_diff.set_xy(0, 0)
			var inside := true
			if start.x <= room.left:
				inside = false
				cur_diff.x = room.left - start.x
			elif start.x >= room.right:
				inside = false
				cur_diff.x = start.x - room.right
			if start.y <= room.top:
				inside = false
				cur_diff.y = room.top - start.y
			elif start.y >= room.bottom:
				inside = false
				cur_diff.y = start.y - room.bottom
			if inside:
				return space.set_edges(start.x, start.y, start.x, start.y)
			if cur_diff.length() < closest_diff:
				closest_diff = cur_diff.length()
				closest_room = room
		if closest_room == null:
			return space
		var w_diff := 2147483647
		if closest_room.left >= start.x:
			w_diff = (space.right - closest_room.left) * (space.height() + 1)
		elif closest_room.right <= start.x:
			w_diff = (closest_room.right - space.left) * (space.height() + 1)
		var h_diff := 2147483647
		if closest_room.top >= start.y:
			h_diff = (space.bottom - closest_room.top) * (space.width() + 1)
		elif closest_room.bottom <= start.y:
			h_diff = (closest_room.bottom - space.top) * (space.width() + 1)
		if w_diff < h_diff or (w_diff == h_diff and rng.next_int(2) == 0):
			if closest_room.left >= start.x and closest_room.left < space.right:
				space.right = closest_room.left
			if closest_room.right <= start.x and closest_room.right > space.left:
				space.left = closest_room.right
		else:
			if closest_room.top >= start.y and closest_room.top < space.bottom:
				space.bottom = closest_room.top
			if closest_room.bottom <= start.y and closest_room.bottom > space.top:
				space.top = closest_room.bottom
		colliding.erase(closest_room)


static func angle_between_rooms(from, to) -> float:
	var from_center := Vector2((from.left + from.right) / 2.0,
		(from.top + from.bottom) / 2.0)
	var to_center := Vector2((to.left + to.right) / 2.0,
		(to.top + to.bottom) / 2.0)
	return angle_between_points(from_center, to_center)


static func angle_between_points(from: Vector2, to: Vector2) -> float:
	if to.x == from.x:
		if to.y == from.y:
			return NAN
		return 0.0 if to.y < from.y else 180.0
	var slope: float = (to.y - from.y) / (to.x - from.x)
	var angle := A * (atan(slope) + PI / 2.0)
	if from.x > to.x:
		angle -= 180.0
	return angle


static func place_room(collision: Array, prev, next, angle: float, rng) -> float:
	angle = fposmod(angle, 360.0)
	var prev_center := Vector2((prev.left + prev.right) / 2.0,
		(prev.top + prev.bottom) / 2.0)
	var slope := tan(angle / A + PI / 2.0)
	var intercept := prev_center.y - slope * prev_center.x
	var start
	var direction: int
	if absf(slope) >= 1.0:
		if angle < 90.0 or angle > 270.0:
			direction = Room.TOP
			start = Point.new(_java_round((prev.top - intercept) / slope), prev.top)
		else:
			direction = Room.BOTTOM
			start = Point.new(_java_round((prev.bottom - intercept) / slope), prev.bottom)
	else:
		if angle < 180.0:
			direction = Room.RIGHT
			start = Point.new(prev.right, _java_round(slope * prev.right + intercept))
		else:
			direction = Room.LEFT
			start = Point.new(prev.left, _java_round(slope * prev.left + intercept))
	if direction == Room.TOP or direction == Room.BOTTOM:
		start.x = int(GameMath.gate(prev.left + 1, start.x, prev.right - 1))
	else:
		start.y = int(GameMath.gate(prev.top + 1, start.y, prev.bottom - 1))
	var space = find_free_space(start, collision,
		maxi(next.max_width(), next.max_height()), rng)
	if not next.set_size_with_limit(space.width() + 1, space.height() + 1):
		return -1.0
	var target_center := Vector2.ZERO
	if direction == Room.TOP:
		target_center.y = prev.top - (next.height() - 1) / 2.0
		target_center.x = (target_center.y - intercept) / slope
		next.set_pos(_java_round(target_center.x - (next.width() - 1) / 2.0),
			prev.top - (next.height() - 1))
	elif direction == Room.BOTTOM:
		target_center.y = prev.bottom + (next.height() - 1) / 2.0
		target_center.x = (target_center.y - intercept) / slope
		next.set_pos(_java_round(target_center.x - (next.width() - 1) / 2.0),
			prev.bottom)
	elif direction == Room.RIGHT:
		target_center.x = prev.right + (next.width() - 1) / 2.0
		target_center.y = slope * target_center.x + intercept
		next.set_pos(prev.right,
			_java_round(target_center.y - (next.height() - 1) / 2.0))
	else:
		target_center.x = prev.left - (next.width() - 1) / 2.0
		target_center.y = slope * target_center.x + intercept
		next.set_pos(prev.left - (next.width() - 1),
			_java_round(target_center.y - (next.height() - 1) / 2.0))
	if direction == Room.TOP or direction == Room.BOTTOM:
		if next.right < prev.left + 2:
			next.shift(prev.left + 2 - next.right, 0)
		elif next.left > prev.right - 2:
			next.shift(prev.right - 2 - next.left, 0)
		if next.right > space.right:
			next.shift(space.right - next.right, 0)
		elif next.left < space.left:
			next.shift(space.left - next.left, 0)
	else:
		if next.bottom < prev.top + 2:
			next.shift(0, prev.top + 2 - next.bottom)
		elif next.top > prev.bottom - 2:
			next.shift(0, prev.bottom - 2 - next.top)
		if next.bottom > space.bottom:
			next.shift(0, space.bottom - next.bottom)
		elif next.top < space.top:
			next.shift(0, space.top - next.top)
	if next.connect_room(prev):
		return angle_between_rooms(prev, next)
	return -1.0


static func _java_round(value: float) -> int:
	return floori(value + 0.5)
