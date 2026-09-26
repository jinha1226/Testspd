# SPD Java → Godot 이식 대응표

원본 기준: [`00-Evan/shattered-pixel-dungeon` `2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f`](https://github.com/00-Evan/shattered-pixel-dungeon/tree/2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f). 이 문서는 실제로 대응시킨 코드와 아직 다른 동작을 구분합니다. 전체 게임의 완성 여부를 뜻하지 않습니다.

| 원본 Java | Godot | 현재 대응 범위 |
| --- | --- | --- |
| `watabou/utils/Random.java`, `java.util.Random` | `spd_random.gd` | Java 48비트 생성기, MX3 시드 섞기, 중첩 생성기, 유계 정수·실수. 고정 시드 출력으로 검증. 층 생성 호출 순서는 아직 원본과 달라 전체 지도 동일성은 미보장. |
| `actors/Actor.java` | `spd_actor_clock.gd`, `run.gd` | 시간·우선순위에 따라 영웅과 몹 행동을 선택하며 게의 2배 속도를 소수 시간으로 처리. 버프·블롭·애니메이션의 전체 스케줄링은 미이식. |
| `watabou/utils/PathFinder.java` | `spd_pathfinder.gd`, `run.gd` | 목표에서 역방향으로 거리 지도를 만들고 원본 이웃 순서로 영웅·몹 경로를 선택. 도주용 거리 지도는 미이식. |
| `mechanics/ShadowCaster.java` | `spd_shadowcaster.gd` | 8방향 재귀 섀도캐스팅, 원형 시야 보정, 거리 2 코너 처리. 배열 경계 검사를 추가했습니다. |
| `watabou/utils/Random.NormalIntRange`, `actors/Char.hit`·`attack` | `spd_combat.gd` | 삼각 분포 피해·방어 굴림, 명중 대 회피 굴림, `max(피해-방어, 0)`. 상태 효과·장비 강화·특성은 미포함. |
| `actors/hero/Hero.java`, `items/weapon/melee/MeleeWeapon.java`, `items/armor/Armor.java` | `spd_combat.gd`, `run.gd` | HP 20에서 레벨당 5 증가, 경험치 요구량 `5 + 5 × 레벨`, 명중·회피 레벨 증가, 기본 무기 피해·방어 및 힘 요구치 공식. 직업·특성·개별 무기 특성은 미포함. |
| `actors/mobs`의 기본 적·보스 클래스 | `spd_combat.gd`, `run.gd` | 메인 던전 일반 적 24종과 보스 5종의 기본 HP·명중·회피·피해 범위·방어·EXP 데이터를 바탕으로 전투. 강령술사처럼 기본 근접 공격이 없는 적에는 임시 값을 사용하며, 다수의 특수 능력과 원본 공격 패턴은 아직 없음. |
| `actors/mobs/MobSpawner.java`, `levels/RegularLevel.createMobs` | `spd_campaign.gd`, `run.gd` | 1~24층의 원본 일반 적 로테이션, 1층 시작 적 8마리, 지역별 타일 선택. 희귀 변종, 정확한 방 가중치·재생성 조건은 미포함. |
| `Dungeon.newLevel`, `levels/*BossLevel`, `LastLevel` | `spd_campaign.gd`, `run.gd` | 메인 1~26층 지역 구분, 5층 간격 보스 계단 잠금, 26층 부적 승리. 전용 보스층 구조는 단순화한 전투 공간이고 분기층은 미이식. |
| `actors/mobs/Goo.java`, `actors/buffs/Ooze.java` | `spd_combat.gd`, `run.gd` | 구의 체력 100, 충전 경고 두 번 후 3배 피해, 절반 이하 HP의 명중·피해 변화, 물 위 회복, 1/3 확률 점액과 물·회복 물약 해제. 정확한 거리·투사체·행동 우선순위는 미이식. |
| `actors/mobs/Mob.Sleeping` | `run.gd` | 적 시야와 거리별 감지 확률 `1 / distance`를 적용. 수면 이후 배회·추적·시간 스케줄링은 임시 구현. |
| `items/potions/PotionOfHealing`, `actors/buffs/Healing` | `run.gd` | 최대 HP의 80% + 14만큼을 저장하고 남은 회복량의 25%씩 턴마다 회복. 점액 해제를 포함하며 나머지 해로운 상태는 미포함. |
| `actors/buffs/Hunger.java`, `items/food/Food.java` | `run.gd` | 300턴 배고픔·450턴 굶주림, 식량 300 에너지·3턴 섭취, 굶주림의 누적 피해. 강화·지팡이·힘 물약과 전리품 배치는 현재 플레이 가능성 검증용으로 단순화. |
| `levels/Patch.java`, `levels/painters/RegularPainter.java`, `levels/painters/SewerPainter.java` | `spd_patch.gd`, `run.gd` | 강제 점유율과 3×3 군집화, 하수도 물 30%·풀 20%, 키 큰 풀과 벽 주변 장식. 원본 방별 배치 가능 셀은 미이식. |
| `tiles/DungeonTileSheet.java` | `main.gd` | 5개 지역의 원본 타일 시트, 평면 타일 인덱스와 물 가장자리 4방향 비트. 높은 벽·애니메이션 물 레이어는 미이식. |
| `Dungeon.saveGame`·`loadGame`, `GamesInProgress` | `spd_save.gd`, `run.gd`, `main.gd` | 지도·적·난수·행동 시간의 Godot 형식 저장/재개와 6개 슬롯 선택·자동 저장. 원본 Java Bundle 세이브 가져오기와 브라우저 파일 내보내기·가져오기는 미이식. |

`run.gd`의 방·복도 생성은 아직 원본 `RegularLevel`·`LoopBuilder`·`FigureEightBuilder`가 아닌 임시 배치입니다. 5개 지역의 기본 편성과 보스·최종층을 방문할 수 있지만, 특수 방·상점·분기층·함정·퀘스트·원본 전리품 생성은 없습니다. 구 이외의 보스는 HP와 기본 공격 중심의 임시 전투이며, 원본의 페이즈·소환·기믹은 구현되지 않았습니다. 직업·특성·장비 개별 효과·상태 효과 대부분도 미이식입니다. 따라서 1~26층 진행 가능 여부와 전체 SPD 게임플레이 완성 여부를 동일하게 취급하면 안 됩니다.

난수 생성기 자체는 Java의 고정 시드 출력과 일치합니다. 지도는 아직 원본 방 생성기와 난수 호출 순서를 사용하지 않으므로 같은 숫자 시드로 같은 지도가 나오지는 않습니다. 현재 테스트는 난수 시퀀스·행동 순서·경로 탐색·저장 재개, 3개 시드의 26층 연결성과 지역 적·보스 배치, 기본 성장·식량·점액·승리를 확인합니다.
