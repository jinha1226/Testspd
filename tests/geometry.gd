extends SceneTree

const Point = preload("res://spd_point.gd")
const Rect = preload("res://spd_rect.gd")
const PointF = preload("res://spd_pointf.gd")
const GameMath = preload("res://spd_game_math.gd")
const Door = preload("res://spd_room_door.gd")
const Random = preload("res://spd_random.gd")


func _initialize() -> void:
	var point = Point.new(3, -5)
	var copy = point.clone()
	if not point.equals(copy) or point == copy:
		_fail("Point clone did not copy coordinates")
		return
	if not Point.new(point).equals(point) or not Rect.new(Rect.new(1, 2, 3, 4)).inside(Point.new(1, 2)):
		_fail("Point or Rect Java copy constructor differs")
		return
	point.scale_by(0.5).offset_xy(-1, 2)
	if point.x != 0 or point.y != 0 or not point.is_zero() \
			or not is_equal_approx(Point.distance(Point.new(0, 0), Point.new(3, 4)), 5.0):
		_fail("Point Java mutation or distance semantics differ")
		return
	var rect = Rect.new(2, 3, 6, 8)
	if rect.width() != 4 or rect.height() != 5 or rect.square() != 20 \
			or not rect.inside(Point.new(2, 3)) or rect.inside(Point.new(6, 8)) \
			or rect.get_points().size() != 30:
		_fail("Rect size, inside, or inclusive getPoints loop differs")
		return
	var intersection = rect.intersect(Rect.new(5, 7, 9, 10))
	if intersection.left != 5 or intersection.top != 7 \
			or intersection.right != 6 or intersection.bottom != 8:
		_fail("Rect intersection differs")
		return
	rect.union_xy(7, 9)
	if rect.right != 8 or rect.bottom != 10:
		_fail("Rect union(point) failed to expand the exclusive end")
		return
	rect.set_pos(10, 20)
	if rect.left != 10 or rect.top != 20 or rect.right != 16 or rect.bottom != 27:
		_fail("Rect setPos did not retain dimensions")
		return
	var rng = Random.new(0)
	var centered = Rect.new(0, 0, 4, 5).center(rng)
	if centered.x < 2 or centered.x > 3 or centered.y != 2:
		_fail("Rect center parity rule differs")
		return
	var door = Door.new(3, 4)
	if not Point.new(3, 4).equals(door) or not door.equals(Point.new(3, 4)) \
			or door.clone().get_script() != Point:
		_fail("Point.equals or clone differs for a Door subclass")
		return
	var vector = PointF.new(-1.5, 2.5)
	if not PointF.new(Point.new(3, 4)).equals(PointF.new(3, 4)) \
			or not PointF.new(vector).equals(vector):
		_fail("PointF Java copy constructor differs")
		return
	if vector.floor_point().x != -1 or vector.floor_point().y != 2 \
			or not is_equal_approx(PointF.distance(PointF.new(0, 0), PointF.new(3, 4)), 5.0) \
			or not PointF.inter(PointF.new(0, 0), PointF.new(4, 8), 0.5).equals(PointF.new(2, 4)):
		_fail("PointF Java cast, distance, or interpolation differs")
		return
	if GameMath.gate(1, 8, 5) != 5 or GameMath.speed(2, 3, 0.5) != 3.5:
		_fail("GameMath speed or gate differs")
		return
	print("SPD Java Point/Rect/PointF/GameMath geometry passed")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
