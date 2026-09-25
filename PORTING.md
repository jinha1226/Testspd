# SPD Java → Godot 이식 대응표

원본 기준: [`00-Evan/shattered-pixel-dungeon` `2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f`](https://github.com/00-Evan/shattered-pixel-dungeon/tree/2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f). 이 문서는 실제로 대응시킨 코드와 아직 다른 동작을 구분합니다. 전체 게임의 완성 여부를 뜻하지 않습니다.

| 원본 Java | Godot | 현재 대응 범위 |
| --- | --- | --- |
| `mechanics/ShadowCaster.java` | `spd_shadowcaster.gd` | 8방향 재귀 섀도캐스팅, 원형 시야 보정, 거리 2 코너 처리. 배열 경계 검사를 추가했습니다. |
| `watabou/utils/Random.NormalIntRange`, `actors/Char.hit`·`attack` | `spd_combat.gd` | 삼각 분포 피해·방어 굴림, 명중 대 회피 굴림, `max(피해-방어, 0)`. 상태 효과·장비 강화·특성은 미포함. |
| `actors/hero/Hero.java`, `items/weapon/melee/WornShortsword.java`, `items/armor/ClothArmor.java` | `spd_combat.gd` | 시작 전사의 HP 20, 명중 10, 회피 5, 낡은 소검 피해 1–10, 천 갑옷 방어 0–2. |
| `actors/mobs/Rat.java`, `actors/mobs/Snake.java` | `spd_combat.gd`, `run.gd` | 쥐 HP 8/명중 8/회피 2/피해 1–4/방어 0–1, 뱀 HP 4/명중 10/회피 25/피해 1–4. 미인지 적에 대한 기습 명중 처리. |
| `actors/mobs/MobSpawner.java`, `levels/RegularLevel.createMobs` | `run.gd` | 1층 시작 적 8마리와 기본 비율 쥐 3:뱀 1. 희귀 변종, 방 가중치, 정확한 배치 조건은 미포함. |
| `actors/mobs/Mob.Sleeping` | `run.gd` | 적 시야와 거리별 감지 확률 `1 / distance`를 적용. 수면 이후 배회·추적·시간 스케줄링은 임시 구현. |
| `items/potions/PotionOfHealing`, `actors/buffs/Healing` | `run.gd` | 최대 HP의 80% + 14만큼을 저장하고 남은 회복량의 25%씩 턴마다 회복. 해로운 상태 해제는 미포함. |

`run.gd`의 방·복도 생성, 물약 배치, 적의 추적 경로와 전체 턴 순서는 아직 원본 `RegularLevel`·방 빌더·페인터·`Actor` 스케줄러 이식이 아닙니다. 2층 이후 적 종류도 아직 원본 로테이션을 따르지 않습니다. 이후에는 층 생성 구조와 스케줄러를 옮긴 뒤, 아이템·직업·UI를 각각 원본 코드 및 실제 동작과 대조해야 합니다.

Godot `RandomNumberGenerator`와 원본 Java RNG는 서로 다르므로 같은 숫자 시드가 같은 지도를 뜻하지 않습니다. 현재 테스트는 원본 공식·구성·시야 차폐의 동작을 확인합니다.
