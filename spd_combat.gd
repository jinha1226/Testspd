extends RefCounted
## Unmodified, unbuffed combat subset ported from Char.java, Hero.java,
## Rat.java, MeleeWeapon.java, Armor.java, and watabou/utils/Random.java.
## Upstream commit: 2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f.

const HERO_ATTACK_SKILL := 10
const HERO_DEFENSE_SKILL := 5
const WORN_SHORTSWORD_MIN := 1
const WORN_SHORTSWORD_MAX := 10
const CLOTH_ARMOR_DR_MIN := 0
const CLOTH_ARMOR_DR_MAX := 2
const RAT_HP := 8
const RAT_ATTACK_SKILL := 8
const RAT_DEFENSE_SKILL := 2
const RAT_DAMAGE_MIN := 1
const RAT_DAMAGE_MAX := 4
const RAT_DR_MIN := 0
const RAT_DR_MAX := 1
const SNAKE_HP := 4
const SNAKE_ATTACK_SKILL := 10
const SNAKE_DEFENSE_SKILL := 25
const MOB_STATS := {
	"rat": {"hp": 8, "attack": 8, "defense": 2, "damage_min": 1, "damage_max": 4, "dr_max": 1},
	"snake": {"hp": 4, "attack": 10, "defense": 25, "damage_min": 1, "damage_max": 4, "dr_max": 0},
	"gnoll": {"hp": 12, "attack": 10, "defense": 4, "damage_min": 1, "damage_max": 6, "dr_max": 2},
	"swarm": {"hp": 50, "attack": 10, "defense": 5, "damage_min": 1, "damage_max": 4, "dr_max": 0},
	"crab": {"hp": 15, "attack": 12, "defense": 5, "damage_min": 1, "damage_max": 7, "dr_max": 4},
	"slime": {"hp": 20, "attack": 12, "defense": 5, "damage_min": 2, "damage_max": 5, "dr_max": 0},
}


static func normal_int_range(rng, minimum: int, maximum: int) -> int:
	# watabou.utils.Random.NormalIntRange: sum of two uniform rolls.
	return mini(maximum, minimum + int((rng.randf() + rng.randf()) * (maximum - minimum + 1) / 2.0))


static func hit(rng, attack_skill: int, defense_skill: int) -> bool:
	# Char.hit: independent uniform rolls; attacker wins ties.
	return rng.randf() * attack_skill >= rng.randf() * defense_skill


static func attack(rng, attack_skill: int, defense_skill: int,
		damage_min: int, damage_max: int, dr_min: int, dr_max: int) -> Dictionary:
	if not hit(rng, attack_skill, defense_skill):
		return {"hit": false, "damage": 0}
	var rolled_damage := normal_int_range(rng, damage_min, damage_max)
	var armor := normal_int_range(rng, dr_min, dr_max)
	return {"hit": true, "damage": maxi(0, rolled_damage - armor)}


static func mob_hp(kind: String) -> int:
	return int(MOB_STATS.get(kind, MOB_STATS["rat"])["hp"])


static func warrior_attacks_mob(rng, kind: String, surprised: bool) -> Dictionary:
	# Mob.defenseSkill returns zero when surprised by the hero.
	var stats: Dictionary = MOB_STATS.get(kind, MOB_STATS["rat"])
	var defense := 0 if surprised else int(stats["defense"])
	var strike := attack(rng, HERO_ATTACK_SKILL, defense,
		WORN_SHORTSWORD_MIN, WORN_SHORTSWORD_MAX, 0, int(stats["dr_max"]))
	if kind == "slime" and int(strike["damage"]) >= 5:
		# Slime.damage caps large hits on a diminishing curve.
		var damage := int(strike["damage"])
		strike["damage"] = int(4.0 + (sqrt(8.0 * (damage - 4) + 1.0) - 1.0) / 2.0)
	return strike


static func mob_attacks_warrior(rng, kind: String) -> Dictionary:
	var stats: Dictionary = MOB_STATS.get(kind, MOB_STATS["rat"])
	return attack(rng, int(stats["attack"]), HERO_DEFENSE_SKILL,
		int(stats["damage_min"]), int(stats["damage_max"]), CLOTH_ARMOR_DR_MIN, CLOTH_ARMOR_DR_MAX)
