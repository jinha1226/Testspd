extends RefCounted
## Direct method port of com.watabou.utils.GameMath at SPD 2bb34a4e91d2.
## Game.elapsed is supplied explicitly as elapsed to keep game state injectable.


static func speed(current_speed: float, acceleration: float, elapsed: float) -> float:
	if acceleration != 0.0:
		current_speed += acceleration * elapsed
	return current_speed


static func gate(minimum: float, value: float, maximum: float) -> float:
	if value < minimum:
		return minimum
	if value > maximum:
		return maximum
	return value
