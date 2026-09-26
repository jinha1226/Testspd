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
	"rat": {"hp": 8, "attack": 8, "defense": 2, "damage_min": 1, "damage_max": 4, "dr_max": 1, "exp": 1, "max_lvl": 5},
	"snake": {"hp": 4, "attack": 10, "defense": 25, "damage_min": 1, "damage_max": 4, "dr_max": 0, "exp": 2, "max_lvl": 7},
	"gnoll": {"hp": 12, "attack": 10, "defense": 4, "damage_min": 1, "damage_max": 6, "dr_max": 2, "exp": 2, "max_lvl": 8},
	"swarm": {"hp": 50, "attack": 10, "defense": 5, "damage_min": 1, "damage_max": 4, "dr_max": 0, "exp": 3, "max_lvl": 9},
	"crab": {"hp": 15, "attack": 12, "defense": 5, "damage_min": 1, "damage_max": 7, "dr_max": 4, "exp": 4, "max_lvl": 9},
	"slime": {"hp": 20, "attack": 12, "defense": 5, "damage_min": 2, "damage_max": 5, "dr_max": 0, "exp": 4, "max_lvl": 9},
	"goo": {"hp": 100, "attack": 10, "defense": 8, "damage_min": 1, "damage_max": 8, "dr_max": 2, "exp": 10},
	"skeleton": {"hp": 25, "attack": 10, "defense": 9, "damage_min": 2, "damage_max": 10, "dr_max": 5, "exp": 5},
	"thief": {"hp": 20, "attack": 12, "defense": 12, "damage_min": 1, "damage_max": 10, "dr_max": 3, "exp": 5},
	"dm100": {"hp": 20, "attack": 11, "defense": 8, "damage_min": 2, "damage_max": 8, "dr_max": 4, "exp": 6},
	"guard": {"hp": 40, "attack": 14, "defense": 10, "damage_min": 4, "damage_max": 12, "dr_max": 7, "exp": 7},
	"necromancer": {"hp": 40, "attack": 12, "defense": 14, "damage_min": 4, "damage_max": 8, "dr_max": 5, "exp": 7},
	"tengu": {"hp": 200, "attack": 10, "defense": 15, "damage_min": 6, "damage_max": 12, "dr_max": 5, "exp": 20},
	"bat": {"hp": 30, "attack": 16, "defense": 15, "damage_min": 5, "damage_max": 18, "dr_max": 4, "exp": 7},
	"brute": {"hp": 40, "attack": 20, "defense": 15, "damage_min": 5, "damage_max": 25, "dr_max": 8, "exp": 8},
	"shaman": {"hp": 35, "attack": 18, "defense": 15, "damage_min": 5, "damage_max": 10, "dr_max": 6, "exp": 8},
	"spinner": {"hp": 50, "attack": 22, "defense": 17, "damage_min": 10, "damage_max": 20, "dr_max": 6, "exp": 9},
	"dm200": {"hp": 80, "attack": 20, "defense": 12, "damage_min": 10, "damage_max": 25, "dr_max": 8, "exp": 9},
	"dm300": {"hp": 300, "attack": 20, "defense": 15, "damage_min": 15, "damage_max": 25, "dr_max": 10, "exp": 30},
	"ghoul": {"hp": 45, "attack": 24, "defense": 20, "damage_min": 16, "damage_max": 22, "dr_max": 4, "exp": 5},
	"elemental": {"hp": 60, "attack": 25, "defense": 20, "damage_min": 20, "damage_max": 25, "dr_max": 5, "exp": 10},
	"warlock": {"hp": 70, "attack": 25, "defense": 18, "damage_min": 12, "damage_max": 18, "dr_max": 8, "exp": 11},
	"monk": {"hp": 70, "attack": 30, "defense": 30, "damage_min": 12, "damage_max": 25, "dr_max": 2, "exp": 11},
	"golem": {"hp": 120, "attack": 28, "defense": 15, "damage_min": 25, "damage_max": 30, "dr_max": 12, "exp": 12},
	"king": {"hp": 300, "attack": 26, "defense": 22, "damage_min": 15, "damage_max": 25, "dr_max": 10, "exp": 40},
	"succubus": {"hp": 80, "attack": 28, "defense": 25, "damage_min": 25, "damage_max": 30, "dr_max": 10, "exp": 12},
	"eye": {"hp": 100, "attack": 30, "defense": 20, "damage_min": 20, "damage_max": 30, "dr_max": 10, "exp": 13},
	"scorpio": {"hp": 110, "attack": 36, "defense": 24, "damage_min": 30, "damage_max": 40, "dr_max": 16, "exp": 14},
	"yog": {"hp": 1000, "attack": 30, "defense": 20, "damage_min": 20, "damage_max": 35, "dr_max": 12, "exp": 50},
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


static func hero_attacks_mob(rng, kind: String, surprised: bool, level: int,
		weapon_min: int, weapon_max: int, strength: int = 10,
		weapon_requirement: int = 10) -> Dictionary:
	var stats: Dictionary = MOB_STATS.get(kind, MOB_STATS["rat"])
	var defense := 0 if surprised and strength >= weapon_requirement else int(stats["defense"])
	var encumbrance := maxi(0, weapon_requirement - strength)
	var accuracy := maxi(1, roundi((HERO_ATTACK_SKILL + level - 1) / pow(1.5, encumbrance)))
	if not hit(rng, accuracy, defense):
		return {"hit": false, "damage": 0}
	var damage := normal_int_range(rng, weapon_min, weapon_max)
	if strength > weapon_requirement:
		damage += normal_int_range(rng, 0, strength - weapon_requirement)
	var strike := {"hit": true, "damage": maxi(0,
		damage - normal_int_range(rng, 0, int(stats["dr_max"])))}
	if kind == "slime" and int(strike["damage"]) >= 5:
		var slime_damage := int(strike["damage"])
		strike["damage"] = int(4.0 + (sqrt(8.0 * (slime_damage - 4) + 1.0) - 1.0) / 2.0)
	return strike


static func mob_attacks_hero(rng, kind: String, level: int, armor_max: int,
		bonus_attack: int = 0, damage_factor: int = 1,
		armor_min: int = 0, defense_skill: int = -1) -> Dictionary:
	var stats: Dictionary = MOB_STATS.get(kind, MOB_STATS["rat"])
	return attack(rng, int(stats["attack"]) + bonus_attack,
		defense_skill if defense_skill >= 0 else HERO_DEFENSE_SKILL + level - 1,
		int(stats["damage_min"]) * damage_factor,
		int(stats["damage_max"]) * damage_factor, armor_min, armor_max)


static func goo_attacks_hero(rng, goo_hp: int, hero_defense: int,
		armor_min: int, armor_max: int, pumped: bool) -> Dictionary:
	# Goo.damageRoll and attackSkill: doubled accuracy while pumped, triple
	# damage range after two warnings, and a stronger range below half HP.
	var wounded := goo_hp * 2 <= 100
	var attack_skill := (15 if wounded else 10) * (2 if pumped else 1)
	var damage_max := (12 if wounded else 8) * (3 if pumped else 1)
	return attack(rng, attack_skill, hero_defense,
		3 if pumped else 1, damage_max, armor_min, armor_max)


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
