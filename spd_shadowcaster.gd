extends RefCounted
## Port of SPD mechanics/ShadowCaster.java (upstream commit 2bb34a4).
## The octant slopes and circular rounding match the Java implementation.
## Explicit bounds checks keep Godot's array accesses safe near map edges.

const MAX_DISTANCE := 20
const OCTANTS := [
	[1, -1, false], [-1, 1, true], [1, 1, true], [1, 1, false],
	[-1, 1, false], [1, -1, true], [-1, -1, true], [-1, -1, false]
]


static func cast_shadow(origin: Vector2i, width: int, height: int, blocking: PackedByteArray, distance: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(width * height)
	result.fill(0)
	if width <= 0 or height <= 0 or blocking.size() != width * height:
		return result
	if origin.x < 0 or origin.y < 0 or origin.x >= width or origin.y >= height:
		return result

	var fov: Array[bool] = []
	fov.resize(width * height)
	fov.fill(false)
	fov[origin.y * width + origin.x] = true
	var radius := clampi(distance, 0, MAX_DISTANCE)
	if radius > 0:
		var rounding: Array[int] = []
		rounding.resize(radius + 1)
		for offset in range(1, radius + 1):
			# Java tests the cell center, so the radius denominator is i + 0.5.
			rounding[offset] = mini(offset, roundi(radius * cos(asin(float(offset) / (radius + 0.5)))))
		if radius == 2:
			rounding[2] = 2
		for octant in OCTANTS:
			_scan_octant(radius, fov, blocking, rounding, 1, origin, width, height,
				0.0, 1.0, octant[0], octant[1], octant[2])
	for index in range(fov.size()):
		if fov[index]:
			result[index] = 1
	return result


static func _scan_octant(distance: int, fov: Array[bool], blocking: PackedByteArray,
		rounding: Array[int], first_row: int, origin: Vector2i, width: int, height: int,
		left_slope: float, right_slope: float, mirror_x: int, mirror_y: int, swap_xy: bool) -> void:
	var in_blocking := false
	for row in range(first_row, distance + 1):
		if right_slope < left_slope:
			return
		var start := 0 if left_slope == 0.0 else floori((row - 0.5) * left_slope + 0.499)
		var finish := rounding[row] if right_slope == 1.0 else mini(
			rounding[row], ceili((row + 0.5) * right_slope - 0.499))
		for col in range(start, finish + 1):
			if col == finish and in_blocking and ceili((row - 0.5) * right_slope - 0.499) != finish:
				break
			var cell_x := origin.x + (mirror_y * row if swap_xy else mirror_x * col)
			var cell_y := origin.y + (mirror_x * col if swap_xy else mirror_y * row)
			var inside := cell_x >= 0 and cell_y >= 0 and cell_x < width and cell_y < height
			var is_blocking := true
			if inside:
				var index := cell_y * width + cell_x
				fov[index] = true
				is_blocking = blocking[index] != 0
			if is_blocking:
				if not in_blocking:
					in_blocking = true
					if col != start:
						_scan_octant(distance, fov, blocking, rounding, row + 1, origin,
							width, height, left_slope, (col - 0.5) / (row + 0.5),
							mirror_x, mirror_y, swap_xy)
			elif in_blocking:
				in_blocking = false
				left_slope = (col - 0.5) / (row - 0.5)
		if in_blocking:
			return
