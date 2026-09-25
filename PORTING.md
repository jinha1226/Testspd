# SPD Java → Godot 이식 대응표

원본 기준: [`00-Evan/shattered-pixel-dungeon` `2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f`](https://github.com/00-Evan/shattered-pixel-dungeon/tree/2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f). 이 문서는 실제로 대응시킨 코드와 아직 다른 동작을 구분합니다. 전체 게임의 완성 여부를 뜻하지 않습니다.

| 원본 Java | Godot | 현재 대응 범위 |
| --- | --- | --- |
| `watabou/utils/Random.java`, `java.util.Random` | `spd_random.gd` | Java 48비트 생성기, MX3 시드 섞기, 중첩 생성기, 유계 정수·실수. 고정 시드 출력으로 검증. 층 생성 호출 순서는 아직 원본과 달라 전체 지도 동일성은 미보장. |
| `actors/Actor.java` | `spd_actor_clock.gd`, `run.gd` | 시간·우선순위에 따라 영웅과 몹 행동을 선택하며 게의 2배 속도를 소수 시간으로 처리. 버프·블롭·애니메이션의 전체 스케줄링은 미이식. |
| `watabou/utils/PathFinder.java` | `spd_pathfinder.gd`, `run.gd` | 목표에서 역방향으로 거리 지도를 만들고 원본 이웃 순서로 영웅·몹 경로를 선택. 도주용 거리 지도는 미이식. |
| `mechanics/ShadowCaster.java` | `spd_shadowcaster.gd` | 8방향 재귀 섀도캐스팅, 원형 시야 보정, 거리 2 코너 처리. 배열 경계 검사를 추가했습니다. |
| `watabou/utils/Random.NormalIntRange`, `actors/Char.hit`·`attack` | `spd_combat.gd` | 삼각 분포 피해·방어 굴림, 명중 대 회피 굴림, `max(피해-방어, 0)`. 상태 효과·장비 강화·특성은 미포함. |
| `actors/hero/Hero.java`, `items/weapon/melee/WornShortsword.java`, `items/armor/ClothArmor.java` | `spd_combat.gd` | 시작 전사의 HP 20, 명중 10, 회피 5, 낡은 소검 피해 1–10, 천 갑옷 방어 0–2. |
| `actors/mobs/Rat.java`, `Snake.java`, `Gnoll.java`, `Swarm.java`, `Crab.java`, `Slime.java` | `spd_combat.gd`, `run.gd` | 하수도 여섯 적의 HP·명중·회피·기본 피해·방어값, 슬라임 피해 경감, 파리떼 분열, 게의 2배 속도. 파리떼 상태 효과·전리품·EXP는 미포함. |
| `actors/mobs/MobSpawner.java`, `levels/RegularLevel.createMobs` | `run.gd` | 1~4층 하수도 적 로테이션과 1층 시작 적 8마리. 희귀 변종, 방 가중치, 정확한 배치 조건은 미포함. |
| `actors/mobs/Mob.Sleeping` | `run.gd` | 적 시야와 거리별 감지 확률 `1 / distance`를 적용. 수면 이후 배회·추적·시간 스케줄링은 임시 구현. |
| `items/potions/PotionOfHealing`, `actors/buffs/Healing` | `run.gd` | 최대 HP의 80% + 14만큼을 저장하고 남은 회복량의 25%씩 턴마다 회복. 해로운 상태 해제는 미포함. |
| `levels/Patch.java`, `levels/painters/RegularPainter.java`, `levels/painters/SewerPainter.java` | `spd_patch.gd`, `run.gd` | 강제 점유율과 3×3 군집화, 하수도 물 30%·풀 20%, 키 큰 풀과 벽 주변 장식. 원본 방별 배치 가능 셀은 미이식. |
| `tiles/DungeonTileSheet.java` | `main.gd` | 평면 타일 인덱스와 물 가장자리 4방향 비트를 적용. 원본의 높은 벽·애니메이션 물 레이어는 미이식. |
| `Dungeon.saveGame`·`loadGame`, `GamesInProgress` | `spd_save.gd`, `run.gd`, `main.gd` | 지도·적·난수·행동 시간의 Godot 형식 저장/재개, 6개 슬롯 API, 현재 화면의 1번 슬롯 자동 저장·재개. 원본 Java Bundle 세이브 가져오기와 슬롯 선택 UI는 미이식. |

`run.gd`의 방·복도 생성, 물약 배치, 적 상태 전이와 버프를 포함한 전체 턴 순서는 아직 원본 `RegularLevel`·방 빌더·`Actor` 전체 이식이 아닙니다. 5층 보스 Goo와 6층 이후 지역도 미이식이며, 현재는 하수도 적 구성으로 계속 진행됩니다. 이후에는 층 생성 구조와 나머지 스케줄러를 옮긴 뒤, 아이템·직업·UI를 각각 원본 코드 및 실제 동작과 대조해야 합니다.

난수 생성기 자체는 Java의 고정 시드 출력과 일치합니다. 지도는 아직 원본 방 생성기와 난수 호출 순서를 사용하지 않으므로 같은 숫자 시드로 같은 지도가 나오지는 않습니다. 현재 테스트는 난수 시퀀스·행동 순서·경로 탐색·저장 재개와 일부 원본 공식·시야 차폐를 확인합니다.
