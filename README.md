# Shattered Pixel Dungeon → Godot: 메인 던전 이식 진행본

이 폴더는 루트의 `잿빛 원정`과 **분리된 Godot 4.6 프로젝트**입니다. 현재 메인 던전 1~26층을 진행하고 부적을 획득할 수 있지만, 원본 SPD의 전체 규칙을 완성한 포트는 아닙니다. 원본과 구현 차이는 [PORTING.md](PORTING.md)에 기록합니다.

## 실행

```bash
godot --path .
```

위 명령은 이 폴더를 별도 저장소로 열었을 때의 실행 방법입니다. `PROJ_S` 루트에서 실행한다면 `godot --path spd_port`를 사용합니다. Godot 실행 파일이 PATH에 없다면 `godot` 대신 해당 실행 파일 경로를 쓰면 됩니다.

터치·마우스로 인접 칸을 눌러 이동·공격·문 열기를 합니다. 발견한 먼 칸을 누르면 경로를 따라 이동하고, 적이 보이면 멈춥니다. 키보드는 방향키/WASD/HJKL 이동, 스페이스 또는 마침표 대기, P 물약, F 식량, Z 지팡이 대상 선택, U 무기 강화, O 갑옷 강화입니다. 계단을 밟으면 다음 층으로 내려갑니다. 보스층은 보스를 쓰러뜨려야 계단을 이용할 수 있습니다.

현재 포함: 5개 지역의 타일과 원본 일반 적 편성, 지역별 표준 방·특수 방 개수 추첨, 층별 시드 계산, 지역마다 힘 물약 2개·강화 주문서 3개의 보장 일정, 5·10·15·20·25층 보스 배치, 26층 부적, 적의 원본 기본 능력치, 경험치·레벨·HP 성장, 무기·갑옷의 기본 피해·방어 공식, 힘·식량·회복 물약·강화 주문서·마법 지팡이의 간략한 동작입니다. 구의 2단계 충전 공격, 물 위 회복, 점액 상태 효과도 적용했습니다. 한글 UI에는 Galmuri11 폰트를 포함했습니다.

원본 Java 난수 시퀀스와 시간·우선순위 기반 턴 순서, 장애물을 돌아가는 경로 탐색을 적용했습니다. 게임은 선택한 6개 슬롯 중 하나에 매 행동 자동 저장되며 다음 실행 때 1번 슬롯에서 이어집니다. 저장 상태가 손상되면 자동 덮어쓰기를 멈추고 새 게임을 눌러 새로 저장할 수 있습니다. 저장 형식은 Godot판 전용이며, 브라우저 파일 내보내기·가져오기 UI는 아직 없습니다.

웹의 `user://` 저장은 브라우저 IndexedDB 사용 허용에 달려 있으며 시크릿 모드나 사이트 데이터 삭제 후에는 유지되지 않습니다. 자세한 조건은 [Godot 웹 내보내기 문서](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html#using-cookies-for-data-persistence)를 참고하세요.

층 생성기는 원본의 방 개수만 따르는 간소화된 연결 방·복도 배치입니다. 특수 방은 내부 기능이 없는 빈 공간입니다. 보스층은 별도 전투 공간이지만 원본의 전용 빌더와 전투 단계를 그대로 재현하지 않습니다. 적의 기본 능력치와 지역별 편성은 원본에서 옮겼지만 다수의 고유 능력은 아직 없습니다. 직업·특성, 장비 종류와 인벤토리, 던전 분기·퀘스트·상점·함정, 원본 전리품 생성·상태 효과·보스 페이즈·승천, 애니메이션·음향 등은 남아 있습니다. 현재 게임플레이는 **메인 던전 진행을 검증하는 플레이 가능 기반**입니다.

## 검증

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/foundation.gd
godot --headless --path . --script res://tests/pathfinder.gd
godot --headless --path . --script res://tests/campaign.gd
godot --headless --path . --script res://tests/room_plan.gd
godot --headless --path . --script res://tests/limited_drops.gd
godot --headless --path . --script res://tests/save_ui.gd
```

첫 테스트는 50개 시드에서 시작 지점에서 계단까지 연결되는지와 시야·하수도 적 구성·명중·턴·물약·하강을 확인합니다. 캠페인 테스트는 3개 시드의 1~26층 연결성, 지역별 적·보스, 보스 계단 잠금, 경험치·식량·저장·부적 승리를 확인합니다. 별도 폰트 테스트는 한글 글리프와 UI 폰트 적용을 확인합니다. 출처와 라이선스는 [ATTRIBUTION.md](ATTRIBUTION.md)에 정리했습니다.

GitHub Actions의 [Godot tests](.github/workflows/godot-tests.yml)는 `main` 푸시와 풀 리퀘스트마다 Godot 4.6.2 임포트, 위 스모크 테스트, 메인 씬 로딩을 실행합니다. Actions 탭에서 수동 실행도 할 수 있습니다.

## 웹에서 실행

`main`에 푸시하면 [Build and deploy web](.github/workflows/deploy-pages.yml)이 웹 빌드를 만들고 GitHub Pages에 배포합니다. 배포가 성공하면 [웹 실행 페이지](https://jinha1226.github.io/Testspd/)에서 열 수 있습니다. 최초 배포 전에 저장소의 **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 선택해야 할 수 있습니다.
