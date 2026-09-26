extends "res://spd_rect.gd"
## Base Room.java port from SPD 2bb34a4e91d2. Source spelling "neigbours"
## and inclusive room edges are retained. Individual room subclasses/painters
## are not implemented here.

const SpdCombat = preload("res://spd_combat.gd")
const Door = preload("res://spd_room_door.gd")

const ALL := 0
const LEFT := 1
const TOP := 2
const RIGHT := 3
const BOTTOM := 4

var neigbours: Array = []
var connected: Dictionary = {}
var distance := 0
var price := 1
var rng


func _init(random = null, l: int = 0, t: int = 0, r: int = 0, b: int = 0) -> void:
	rng = random
	super(l, t, r, b)


func set_room(other):
	set_rect(other)
	for room in other.neigbours:
		neigbours.append(room)
		room.neigbours.erase(other)
		room.neigbours.append(self)
	for room in other.connected:
		var door = other.connected[room]
		room.connected.erase(other)
		room.connected[self] = door
		connected[room] = door
	return self


func min_width() -> int:
	return -1


func max_width() -> int:
	return -1


func min_height() -> int:
	return -1


func max_height() -> int:
	return -1


func set_size() -> bool:
	return _set_size_bounds(min_width(), max_width(), min_height(), max_height())


func force_size(w: int, h: int) -> bool:
	return _set_size_bounds(w, w, h, h)


func set_size_with_limit(w: int, h: int) -> bool:
	if w < min_width() or h < min_height():
		return false
	set_size()
	if width() > w or height() > h:
		resize(mini(width(), w) - 1, mini(height(), h) - 1)
	return true


func _set_size_bounds(min_w: int, max_w: int, min_h: int, max_h: int) -> bool:
	if min_w < min_width() or max_w > max_width() \
			or min_h < min_height() or max_h > max_height() \
			or min_w > max_w or min_h > max_h:
		return false
	resize(SpdCombat.normal_int_range(rng, min_w, max_w) - 1,
		SpdCombat.normal_int_range(rng, min_h, max_h) - 1)
	return true


func point_inside(from, n: int):
	var step = SpdPoint.new(from.x, from.y)
	if from.x == left:
		step.offset_xy(n, 0)
	elif from.x == right:
		step.offset_xy(-n, 0)
	elif from.y == top:
		step.offset_xy(0, n)
	elif from.y == bottom:
		step.offset_xy(0, -n)
	return step


func width() -> int:
	return super.width() + 1


func height() -> int:
	return super.height() + 1


func random_point(margin: int = 1):
	return SpdPoint.new(rng.randi_range(left + margin, right - margin),
		rng.randi_range(top + margin, bottom - margin))


func inside(point) -> bool:
	return point.x > left and point.y > top and point.x < right and point.y < bottom


func center(_unused = null):
	return SpdPoint.new(int((left + right) / 2)
		+ (rng.next_int(2) if (right - left) % 2 == 1 else 0),
		int((top + bottom) / 2)
		+ (rng.next_int(2) if (bottom - top) % 2 == 1 else 0))


func min_connections(direction: int) -> int:
	return 1 if direction == ALL else 0


func cur_connections(direction: int) -> int:
	if direction == ALL:
		return connected.size()
	var total := 0
	for room in connected:
		var intersection = intersect(room)
		if direction == LEFT and intersection.width() == 0 and intersection.left == left:
			total += 1
		elif direction == TOP and intersection.height() == 0 and intersection.top == top:
			total += 1
		elif direction == RIGHT and intersection.width() == 0 and intersection.right == right:
			total += 1
		elif direction == BOTTOM and intersection.height() == 0 and intersection.bottom == bottom:
			total += 1
	return total


func rem_connections(direction: int) -> int:
	if cur_connections(ALL) >= max_connections(ALL):
		return 0
	return max_connections(direction) - cur_connections(direction)


func max_connections(direction: int) -> int:
	return 16 if direction == ALL else 4


func can_connect_point(point) -> bool:
	return (point.x == left or point.x == right) != (point.y == top or point.y == bottom)


func can_connect_direction(direction: int) -> bool:
	return rem_connections(direction) > 0


func can_connect_room(room) -> bool:
	if (is_exit() and room.is_entrance()) or (is_entrance() and room.is_exit()):
		return false
	var intersection = intersect(room)
	var found_point := false
	for point in intersection.get_points():
		if can_connect_point(point) and room.can_connect_point(point):
			found_point = true
			break
	if not found_point:
		return false
	if intersection.width() == 0 and intersection.left == left:
		return can_connect_direction(LEFT) and room.can_connect_direction(RIGHT)
	if intersection.height() == 0 and intersection.top == top:
		return can_connect_direction(TOP) and room.can_connect_direction(BOTTOM)
	if intersection.width() == 0 and intersection.right == right:
		return can_connect_direction(RIGHT) and room.can_connect_direction(LEFT)
	if intersection.height() == 0 and intersection.bottom == bottom:
		return can_connect_direction(BOTTOM) and room.can_connect_direction(TOP)
	return false


func can_merge(_level, _other, _point, _terrain: int) -> bool:
	return false


func merge(level, _other, area, terrain: int) -> void:
	# Painter.fill(Level, Rect, terrain) is supplied by the Level port.
	level.paint_fill(area, terrain)


func add_neigbour(other) -> bool:
	if neigbours.has(other):
		return true
	var intersection = intersect(other)
	if (intersection.width() == 0 and intersection.height() >= 2) \
			or (intersection.height() == 0 and intersection.width() >= 2):
		neigbours.append(other)
		other.neigbours.append(self)
		return true
	return false


func connect_room(room) -> bool:
	if (neigbours.has(room) or add_neigbour(room)) \
			and not connected.has(room) and can_connect_room(room):
		connected[room] = null
		room.connected[self] = null
		return true
	return false


func clear_connections() -> void:
	for room in neigbours:
		room.neigbours.erase(self)
	neigbours.clear()
	for room in connected:
		room.connected.erase(self)
	connected.clear()


func is_entrance() -> bool:
	return false


func is_exit() -> bool:
	return false


func paint(_level) -> void:
	push_error("Room.paint must be implemented by a concrete room class")


func can_place_water(_point) -> bool:
	return true


func can_place_grass(_point) -> bool:
	return true


func can_place_trap(_point) -> bool:
	return true


func can_place_item(point, _level) -> bool:
	return inside(point)


func can_place_character(point, _level) -> bool:
	return inside(point)


func water_placeable_points() -> Array:
	return _placeable_points("can_place_water")


func grass_placeable_points() -> Array:
	return _placeable_points("can_place_grass")


func trap_placeable_points() -> Array:
	return _placeable_points("can_place_trap")


func item_placeable_points(level) -> Array:
	return _placeable_points("can_place_item", level, true)


func char_placeable_points(level) -> Array:
	return _placeable_points("can_place_character", level, true)


func _placeable_points(method: String, level = null, has_level: bool = false) -> Array:
	var points: Array = []
	for x in range(left, right + 1):
		for y in range(top, bottom + 1):
			var point = SpdPoint.new(x, y)
			var allowed: bool = call(method, point, level) if has_level else call(method, point)
			if allowed:
				points.append(point)
	return points


func edges() -> Array:
	var result: Array = []
	for room in connected:
		var door = connected[room]
		if door != null and [Door.Type.EMPTY, Door.Type.TUNNEL,
				Door.Type.UNLOCKED, Door.Type.REGULAR].has(door.type):
			result.append(room)
	return result


func get_distance() -> int:
	return distance


func set_distance(value: int) -> void:
	distance = value


func get_price() -> int:
	return price


func set_price(value: int) -> void:
	price = value


func store_in_bundle() -> Dictionary:
	return {"left": left, "top": top, "right": right, "bottom": bottom}


func restore_from_bundle(bundle: Dictionary) -> void:
	set_edges(int(bundle.get("left", 0)), int(bundle.get("top", 0)),
		int(bundle.get("right", 0)), int(bundle.get("bottom", 0)))


func on_level_load(_level) -> void:
	pass
