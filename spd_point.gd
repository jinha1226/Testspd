extends RefCounted
## Direct method port of com.watabou.utils.Point at SPD 2bb34a4e91d2.
## Godot's Vector2i is immutable; this class retains Java's mutation rules.

var x := 0
var y := 0


func _init(px = 0, py: int = 0) -> void:
	if px is RefCounted:
		x = px.x
		y = px.y
	else:
		x = int(px)
		y = py


func set_xy(px: int, py: int):
	x = px
	y = py
	return self


func set_point(point):
	return set_xy(point.x, point.y)


func clone():
	return load("res://spd_point.gd").new(x, y)


func scale_by(factor: float):
	# Java int compound assignment truncates toward zero.
	x = int(x * factor)
	y = int(y * factor)
	return self


func offset_xy(dx: int, dy: int):
	x += dx
	y += dy
	return self


func offset_point(delta):
	return offset_xy(delta.x, delta.y)


func is_zero() -> bool:
	return x == 0 and y == 0


func length() -> float:
	return sqrt(float(x * x + y * y))


static func distance(a, b) -> float:
	var dx: float = a.x - b.x
	var dy: float = a.y - b.y
	return sqrt(dx * dx + dy * dy)


func equals(other) -> bool:
	if other == null or not other is RefCounted:
		return false
	var script = other.get_script()
	var point_script = load("res://spd_point.gd")
	while script != null:
		if script == point_script:
			return x == other.x and y == other.y
		script = script.get_base_script()
	return false


func to_vector() -> Vector2i:
	return Vector2i(x, y)
