# Shattered Pixel Dungeon → Godot: 하수도 이식 진행본

이 폴더는 루트의 `잿빛 원정`과 **분리된 Godot 4.6 프로젝트**입니다. 원본 전체 게임을 복제한 상태는 아닙니다. SPD의 첫 던전 루프를 옮겨, 이 기반에서 어떤 시스템을 더할지 판단할 수 있는 첫 실행 버전입니다.

## 실행

```bash
godot --path .
```

위 명령은 이 폴더를 별도 저장소로 열었을 때의 실행 방법입니다. `PROJ_S` 루트에서 실행한다면 `godot --path spd_port`를 사용합니다. Godot 실행 파일이 PATH에 없다면 `godot` 대신 해당 실행 파일 경로를 쓰면 됩니다.

터치·마우스로 인접 칸을 눌러 이동·공격·문 열기를 합니다. 발견한 먼 칸을 누르면 경로를 따라 이동하고, 적이 보이면 멈춥니다. 키보드는 방향키/WASD/HJKL 이동, 스페이스 또는 마침표 대기, P 물약입니다. 계단을 밟으면 다음 층을 생성합니다.

현재 포함: 연결된 방과 복도, 문, 시야와 발견 지형, 물·풀 군집 지형, 플레이어와 하수도 1~4층의 쥐·뱀·놀·파리떼·게·슬라임, 근접 공격, 체력과 회복 물약, 계단 하강, 원본 SPD 하수도 타일·스프라이트 시트. 한글 UI에는 Galmuri11 폰트를 포함했습니다. 5층 보스와 6층 이후 지역·아이템·직업 시스템은 아직 이식하지 않았습니다. 원본 Java 코드와 Godot 구현의 대응 관계는 [PORTING.md](PORTING.md)에 기록했습니다.

원본 Java 난수 시퀀스와 시간·우선순위 기반 턴 순서, 장애물을 돌아가는 경로 탐색을 적용했습니다. 게임은 1번 슬롯에 매 행동 자동 저장되며 다음 실행 때 이어집니다. 저장 상태가 손상되면 자동 덮어쓰기를 멈추고 새 게임을 눌러 새로 저장할 수 있습니다. 저장 형식은 Godot판 전용이며, 나머지 슬롯의 선택 화면과 세이브 내보내기·가져오기 UI는 아직 없습니다.

아직 없는 것: 원본 SPD의 방 배치·특수 방·페인터·전리품을 포함한 층 생성기, 전체 직업·장비·주문·함정·굶주림·보스·저장, 애니메이션과 완성형 UI. 현재 구현은 **원본 Java 규칙 일부를 실제로 옮긴 이식 진행본**이며 전체 게임의 1:1 포트는 아닙니다.

## 검증

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/foundation.gd
godot --headless --path . --script res://tests/pathfinder.gd
godot --headless --path . --script res://tests/save_ui.gd
```

첫 테스트는 50개 시드에서 시작 지점에서 계단까지 연결되는지와 시야·하수도 적 구성·명중·턴·물약·하강을 확인합니다. 별도 폰트 테스트는 한글 글리프와 UI 폰트 적용을 확인합니다. 출처와 라이선스는 [ATTRIBUTION.md](ATTRIBUTION.md)에 정리했습니다. 이 폴더의 원본 스프라이트는 코드로 다시 그린 에셋이 아닙니다.

GitHub Actions의 [Godot tests](.github/workflows/godot-tests.yml)는 `main` 푸시와 풀 리퀘스트마다 Godot 4.6.2 임포트, 위 스모크 테스트, 메인 씬 로딩을 실행합니다. Actions 탭에서 수동 실행도 할 수 있습니다.

## 웹에서 실행

`main`에 푸시하면 [Build and deploy web](.github/workflows/deploy-pages.yml)이 웹 빌드를 만들고 GitHub Pages에 배포합니다. 배포가 성공하면 [웹 실행 페이지](https://jinha1226.github.io/Testspd/)에서 열 수 있습니다. 최초 배포 전에 저장소의 **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 선택해야 할 수 있습니다.
