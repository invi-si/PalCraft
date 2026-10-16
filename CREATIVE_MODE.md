# Creative mode — PalCraft v1.1

## Creative mode and controls

Creative requires **All** or **HUD & Skins**. Open **Esc → Game Mode** or the
inventory **Mode** button and confirm the change. New and existing worlds without
a saved preference start in Survival; each world saves its own mode. **Cancel**,
Esc and Tab close the confirmation without switching.

| Control | Creative action |
| --- | --- |
| Tab, then Catalog | Open the vanilla-style Creative inventory |
| Item-icon tabs / compass tab | Choose a category / type a search |
| Mouse wheel over panel / drag scrollbar | Scroll rows |
| Click / Shift-click an item | Carry an item / obtain a stack |
| Click hotbar while carrying | Assign the carried item |
| Trash slot | Delete the carried amount |
| Chest tab / Inventory | Return to the ordinary inventory |
| Middle mouse | Pick a mod block within normal reach |
| RMB / hold LMB | Place without consumption / instantly break mod blocks without drops |
| Double-tap Space within 0.3 s | Toggle flight |
| Space / Shift while flying | Rise / descend; landing ends flight |

Keep at least one selected block item; the catalog supplies it. Breaking a
container destroys its contents. Player damage, hunger and stamina drain are
guarded while Creative is active. Flight cannot start while mounted, swimming,
climbing, gliding or using menus. Returning to Survival ends flight and restores
normal damage, drops and consumption; switching in midair can cause fall damage.
Items already obtained remain. Pals, capture, quests and technology use native
rules. Islands & Animals only has no Creative mode.

## 크리에이티브 모드와 조작

**All** 또는 **HUD & Skins**가 필요합니다. **Esc → 게임 모드** 또는 인벤토리의
**모드(Mode)** 버튼을 누르고 확인하세요. 저장된 설정이 없는 월드는 서바이벌로
시작하며, 모드는 월드마다 따로 저장됩니다. **취소**, Esc, Tab은 모드를 바꾸지
않고 확인 창을 닫습니다.

| 조작 | 크리에이티브 기능 |
| --- | --- |
| Tab → 아이템 목록(Catalog) | 바닐라 스타일 크리에이티브 인벤토리 열기 |
| 아이콘 탭 / 나침반 탭 | 분류 선택 / 검색어 입력 |
| 패널 위 마우스 휠 / 스크롤 막대 드래그 | 목록 스크롤 |
| 아이템 클릭 / Shift 클릭 | 아이템 들기 / 한 묶음 받기 |
| 아이템을 든 상태로 단축바 클릭 | 단축바에 지정 |
| 휴지통 칸 | 들고 있는 수량 삭제 |
| 상자 탭 / 인벤토리(Inventory) | 일반 인벤토리로 돌아가기 |
| 마우스 가운데 버튼 | 일반 상호작용 거리 안의 모드 블록 선택 |
| 마우스 오른쪽 / 왼쪽 누르기 | 소모 없이 설치 / 모드 블록 즉시 파괴, 드롭 없음 |
| 0.3초 안에 Space 두 번 | 비행 켜기 또는 끄기 |
| 비행 중 Space / Shift | 상승 / 하강, 착지하면 비행 종료 |

선택한 블록 아이템을 하나 이상 보유하세요. 목록에서 받을 수 있습니다.
보관함을 파괴하면 내용물도 사라집니다. 크리에이티브에서는 플레이어 피해,
허기와 스태미나 소모를 막습니다. 탑승, 수영, 등반, 활공 또는 메뉴 사용 중에는
비행을 시작할 수 없습니다. 서바이벌로 돌아가면 비행이 끝나고 일반 피해,
드롭과 아이템 소모가 복원됩니다. 공중에서 전환하면 낙하 피해를 받을 수 있습니다.
이미 받은 아이템은 유지됩니다. 팰, 포획, 퀘스트와 기술은 기본 규칙을 따릅니다.
Islands & Animals만 설치한 경우 크리에이티브를 사용할 수 없습니다.

## Configuration and validation scope

`creative_mode = 1` in config.ini enables the feature; `0` blocks effects and
new activation while allowing return to Survival. Saved mode preferences remain.
Old sidecars without `game_mode` load as Survival. Flight/protection flags are not
saved. Default flight speed is 900 cm/s; the double-tap interval is 0.3 seconds.

CM/CV/CW/VB/VC offline checks and VA/VD/VE/VF native evidence cover different
stages. VD exercised English 100% and Korean 150% catalog/search/caret/tooltips,
counts, pause and confirmations. VF repeated real Creative/catalog and Survival
confirmation and saved Survival. This does not establish every input rate,
combat situation or first-use menu performance. See RELEASE_v1.1.md for limits.
