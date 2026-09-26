extends RefCounted
## Direct method port of com.watabou.utils.PointF at SPD 2bb34a4e91d2.

const SpdPoint = preload("res://spd_point.gd")
const PI_FLOAT := 3.1415926
const PI2 := PI_FLOAT * 2.0
const G2R := PI_FLOAT / 180.0

var x := 0.0
var y := 0.0


func _init(px = 0.0, py: float = 0.0) -> void:
	if px is RefCounted:
		x = px.x
		y = px.y
	else:
		x = float(px)
		y = py


func clone():
	return load("res://spd_pointf.gd").new(x, y)


func scale_by(factor: float):
	x *= factor
	y *= factor
	return self


func inv_scale(factor: float):
	x /= factor
	y /= factor
	return self


func set_xy(px: float, py: float):
	x = px
	y = py
	return self


func set_point(point):
	return set_xy(point.x, point.y)


func set_value(value: float):
	return set_xy(value, value)


func polar(angle: float, length_value: float):
	x = length_value * cos(angle)
	y = length_value * sin(angle)
	return self


func offset_xy(dx: float, dy: float):
	x += dx
	y += dy
	return self


func offset_point(point):
	return offset_xy(point.x, point.y)


func negate():
	x = -x
	y = -y
	return self


func normalize():
	var magnitude := length()
	x /= magnitude
	y /= magnitude
	return self


func floor_point():
	# Java's (int) cast truncates toward zero, including negative coordinates.
	return SpdPoint.new(int(x), int(y))


func is_zero() -> bool:
	return x == 0.0 and y == 0.0


func length() -> float:
	return sqrt(x * x + y * y)


static func sum(a, b):
	return load("res://spd_pointf.gd").new(a.x + b.x, a.y + b.y)


static func diff(a, b):
	return load("res://spd_pointf.gd").new(a.x - b.x, a.y - b.y)


static func inter(a, b, fraction: float):
	return load("res://spd_pointf.gd").new(
		a.x + (b.x - a.x) * fraction, a.y + (b.y - a.y) * fraction)


static func distance(a, b) -> float:
	var dx: float = a.x - b.x
	var dy: float = a.y - b.y
	return sqrt(dx * dx + dy * dy)


static func angle_xy(px: float, py: float) -> float:
	return atan2(py, px)


static func angle_points(start, end) -> float:
	return atan2(end.y - start.y, end.x - start.x)


func equals(other) -> bool:
	return other == self or (other is RefCounted and other.get_script() == get_script()
		and x == other.x and y == other.y)
