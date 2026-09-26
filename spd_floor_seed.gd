extends RefCounted
## Dungeon.seedForDepth from upstream 2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f.

const SpdRandom = preload("res://spd_random.gd")


static func for_depth(dungeon_seed: int, depth: int, branch: int = 0) -> int:
	var random = SpdRandom.new(0)
	random.push_generator(dungeon_seed)
	var result := 0
	for _draw in range(depth + 30 * branch + 1):
		result = random.next_long()
	return result
