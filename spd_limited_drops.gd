extends RefCounted
## Dungeon.posNeeded and Dungeon.souNeeded from upstream
## 2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f.
## Main-dungeon regions each schedule two strength potions and three upgrade
## scrolls over their four regular floors. Call before floor generation.


static func strength_needed(depth: int, dropped: int, rng) -> bool:
	var left := 2 - (dropped - int(depth / 5) * 2)
	if left <= 0:
		return false
	var floor_in_region := depth % 5
	var target_left := 2 - int(floor_in_region / 2)
	if floor_in_region % 2 == 1 and rng.next_int(2) == 0:
		target_left -= 1
	return target_left < left


static func upgrade_needed(depth: int, dropped: int, rng) -> bool:
	var left := 3 - (dropped - int(depth / 5) * 3)
	if left <= 0:
		return false
	return rng.next_int(5 - depth % 5) < left
