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


static func normal_int_range(rng: RandomNumberGenerator, minimum: int, maximum: int) -> int:
	# watabou.utils.Random.NormalIntRange: sum of two uniform rolls.
	return mini(maximum, minimum + int((rng.randf() + rng.randf()) * (maximum - minimum + 1) / 2.0))


static func hit(rng: RandomNumberGenerator, attack_skill: int, defense_skill: int) -> bool:
	# Char.hit: independent uniform rolls; attacker wins ties.
	return rng.randf() * attack_skill >= rng.randf() * defense_skill


static func attack(rng: RandomNumberGenerator, attack_skill: int, defense_skill: int,
		damage_min: int, damage_max: int, dr_min: int, dr_max: int) -> Dictionary:
	if not hit(rng, attack_skill, defense_skill):
		return {"hit": false, "damage": 0}
	var rolled_damage := normal_int_range(rng, damage_min, damage_max)
	var armor := normal_int_range(rng, dr_min, dr_max)
	return {"hit": true, "damage": maxi(0, rolled_damage - armor)}


static func mob_hp(kind: String) -> int:
	return SNAKE_HP if kind == "snake" else RAT_HP


static func warrior_attacks_mob(rng: RandomNumberGenerator, kind: String, surprised: bool) -> Dictionary:
	# Mob.defenseSkill returns zero when surprised by the hero.
	var defense := 0 if surprised else (SNAKE_DEFENSE_SKILL if kind == "snake" else RAT_DEFENSE_SKILL)
	var dr_max := 0 if kind == "snake" else RAT_DR_MAX
	return attack(rng, HERO_ATTACK_SKILL, defense,
		WORN_SHORTSWORD_MIN, WORN_SHORTSWORD_MAX, RAT_DR_MIN, dr_max)


static func mob_attacks_warrior(rng: RandomNumberGenerator, kind: String) -> Dictionary:
	var attack_skill := SNAKE_ATTACK_SKILL if kind == "snake" else RAT_ATTACK_SKILL
	return attack(rng, attack_skill, HERO_DEFENSE_SKILL,
		RAT_DAMAGE_MIN, RAT_DAMAGE_MAX, CLOTH_ARMOR_DR_MIN, CLOTH_ARMOR_DR_MAX)
