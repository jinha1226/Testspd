extends RefCounted
## Main-dungeon depth table from Dungeon.newLevel and MobSpawner.standardMobRotation
## at upstream 2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f.

const REGION_NAMES := ["하수도", "감옥", "동굴", "드워프 도시", "악마의 전당"]
const BOSSES := {5: "goo", 10: "tengu", 15: "dm300", 20: "king", 25: "yog"}
const ROTATIONS := {
	1: ["rat", "rat", "rat", "snake"],
	2: ["rat", "rat", "snake", "gnoll", "gnoll"],
	3: ["rat", "snake", "gnoll", "gnoll", "gnoll", "swarm", "crab"],
	4: ["gnoll", "swarm", "crab", "crab", "slime", "slime"],
	6: ["skeleton", "skeleton", "skeleton", "thief", "swarm"],
	7: ["skeleton", "skeleton", "skeleton", "thief", "dm100", "guard"],
	8: ["skeleton", "skeleton", "thief", "dm100", "dm100", "guard", "guard", "necromancer"],
	9: ["skeleton", "thief", "dm100", "dm100", "guard", "guard", "necromancer", "necromancer"],
	11: ["bat", "bat", "bat", "brute", "shaman"],
	12: ["bat", "bat", "brute", "brute", "shaman", "spinner"],
	13: ["bat", "brute", "brute", "shaman", "shaman", "spinner", "spinner", "dm200"],
	14: ["bat", "brute", "shaman", "shaman", "spinner", "spinner", "dm200", "dm200"],
	16: ["ghoul", "ghoul", "ghoul", "elemental", "warlock"],
	17: ["ghoul", "elemental", "elemental", "warlock", "monk"],
	18: ["ghoul", "elemental", "warlock", "warlock", "monk", "monk", "golem"],
	19: ["elemental", "warlock", "warlock", "monk", "monk", "golem", "golem", "golem"],
	21: ["succubus", "succubus", "eye"],
	22: ["succubus", "eye"],
	23: ["succubus", "eye", "eye", "scorpio"],
	24: ["succubus", "eye", "eye", "scorpio", "scorpio", "scorpio"],
}


static func region(depth: int) -> int:
	return clampi(int((depth - 1) / 5), 0, 4)


static func region_name(depth: int) -> String:
	return REGION_NAMES[region(depth)]


static func boss(depth: int) -> String:
	return BOSSES.get(depth, "")


static func rotation(depth: int) -> Array[String]:
	var key := depth
	if depth == 26:
		key = 24
	elif depth % 5 == 0 and depth < 25:
		key -= 1
	var result: Array[String] = []
	for kind in ROTATIONS.get(key, ROTATIONS[24]):
		result.append(kind)
	return result
