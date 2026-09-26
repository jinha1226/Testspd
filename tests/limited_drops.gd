extends SceneTree

const Run = preload("res://run.gd")
const Random = preload("res://spd_random.gd")
const LimitedDrops = preload("res://spd_limited_drops.gd")
const FloorSeed = preload("res://spd_floor_seed.gd")


func _initialize() -> void:
	# Independent java.util.Random/MX3 reference outputs for Dungeon.seedForDepth.
	var expected_seeds := {
		1: 8590248479019918844,
		2: -3699786503151282351,
		5: 2503009867187895053,
		26: 7966569020170226920,
	}
	for floor_number in expected_seeds:
		if FloorSeed.for_depth(123456789, floor_number) != expected_seeds[floor_number]:
			_fail("Dungeon.seedForDepth differs at depth %d" % floor_number)
			return
	if FloorSeed.for_depth(123456789, 1, 1) != -7871681324283915787:
		_fail("Dungeon.seedForDepth differs for a branch floor")
		return
	for seed_value in range(1, 101):
		var rng = Random.new(seed_value)
		var strength_count := 0
		var upgrade_count := 0
		for region in range(5):
			var strength_this_region := 0
			var upgrade_this_region := 0
			var first_strength := 0
			var second_strength := 0
			for offset in range(1, 5):
				var depth := region * 5 + offset
				if LimitedDrops.strength_needed(depth, strength_count, rng):
					strength_count += 1
					strength_this_region += 1
					if offset <= 2:
						first_strength += 1
					else:
						second_strength += 1
				if LimitedDrops.upgrade_needed(depth, upgrade_count, rng):
					upgrade_count += 1
					upgrade_this_region += 1
			if strength_this_region != 2 or upgrade_this_region != 3 \
					or first_strength != 1 or second_strength != 1:
				_fail("wrong mandatory drops in region %d seed %d" % [region, seed_value])
				return
	for seed_value in [2, 31, 419, 8472]:
		var run = Run.new()
		run.start(seed_value)
		var gameplay_rng: Array[int] = run.rng.state_snapshot()
		for depth in range(1, 26):
			run.depth = depth
			if depth != 1:
				run._build_floor()
			if run.rng.state_snapshot() != gameplay_rng:
				_fail("floor generation consumed the gameplay RNG")
				return
			if depth % 5 == 0:
				continue
			var food := 0
			for item in run.items:
				if item["kind"] == "food":
					food += 1
				if item["pos"] == run.hero or item["pos"] == run.stairs \
						or run._mob_index_at(item["pos"]) >= 0:
					_fail("floor item overlaps the hero, exit, or a mob")
					return
			if food != 1 or run.potions.is_empty():
				_fail("a regular floor lacks mandatory food or provisional healing")
				return
			for potion in run.potions:
				if potion == run.hero or potion == run.stairs \
						or run._mob_index_at(potion) >= 0:
					_fail("floor potion overlaps the hero, exit, or a mob")
					return
		if run.strength_drops != 10 or run.upgrade_drops != 15:
			_fail("run did not schedule ten strength potions and fifteen upgrade scrolls")
			return
	print("SPD limited drops passed: 100 schedules and 4 full campaigns")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
