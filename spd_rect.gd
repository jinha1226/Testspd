extends RefCounted
## Direct method port of com.watabou.utils.Rect at SPD 2bb34a4e91d2.
## Edges use Java's coordinates, including getPoints' inclusive end loop.

const SpdPoint = preload("res://spd_point.gd")

var left := 0
var top := 0
var right := 0
var bottom := 0


func _init(l = 0, t: int = 0, r: int = 0, b: int = 0) -> void:
	if l is RefCounted:
		set_rect(l)
	else:
		set_edges(int(l), t, r, b)


func width() -> int:
	return right - left


func height() -> int:
	return bottom - top


func square() -> int:
	return width() * height()


func set_edges(l: int, t: int, r: int, b: int):
	left = l
	top = t
	right = r
	bottom = b
	return self


func set_rect(rect):
	return set_edges(rect.left, rect.top, rect.right, rect.bottom)


func set_pos(x: int, y: int):
	return set_edges(x, y, x + (right - left), y + (bottom - top))


func shift(x: int, y: int):
	return set_edges(left + x, top + y, right + x, bottom + y)


func resize(w: int, h: int):
	return set_edges(left, top, left + w, top + h)


func is_empty() -> bool:
	return right <= left or bottom <= top


func set_empty():
	return set_edges(0, 0, 0, 0)


func intersect(other):
	return load("res://spd_rect.gd").new(maxi(left, other.left), maxi(top, other.top),
		mini(right, other.right), mini(bottom, other.bottom))


func union_rect(other):
	return load("res://spd_rect.gd").new(mini(left, other.left), mini(top, other.top),
		maxi(right, other.right), maxi(bottom, other.bottom))


func union_xy(x: int, y: int):
	if is_empty():
		return set_edges(x, y, x + 1, y + 1)
	if x < left:
		left = x
	elif x >= right:
		right = x + 1
	if y < top:
		top = y
	elif y >= bottom:
		bottom = y + 1
	return self


func union_point(point):
	return union_xy(point.x, point.y)


func inside(point) -> bool:
	return point.x >= left and point.x < right \
		and point.y >= top and point.y < bottom


func center(rng):
	return SpdPoint.new(int((left + right) / 2)
		+ (rng.next_int(2) if width() % 2 == 0 else 0),
		int((top + bottom) / 2)
		+ (rng.next_int(2) if height() % 2 == 0 else 0))


func shrink(distance: int = 1):
	return load("res://spd_rect.gd").new(left + distance, top + distance,
		right - distance, bottom - distance)


func scale_by(factor: int):
	return load("res://spd_rect.gd").new(left * factor, top * factor,
		right * factor, bottom * factor)


func get_points() -> Array:
	var points: Array = []
	for x in range(left, right + 1):
		for y in range(top, bottom + 1):
			points.append(SpdPoint.new(x, y))
	return points
