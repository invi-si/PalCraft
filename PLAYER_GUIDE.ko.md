<details>
<summary><b>🌐 English</b> (click to open)</summary>

# PalCraft player guide — v1.1

These Minecraft controls require HUD & Skins; Islands & Animals alone keeps
Palworld's native controls. See INSTALL.md before your first launch.

| Control | Action |
| --- | --- |
| Hold LMB | Mine/break mod blocks, attack, harvest native rocks/trees |
| RMB | Place/use; hold to draw bow, release to shoot |
| 1–9 / mouse wheel | Select hotbar slot |
| Tab | Inventory; Pals, Pal Box, Technology and Palpedia tabs |
| E / Q | Summon or recall partner / throw sphere |
| F | Interact, talk, unlock statue, mount/dismount |
| M | Native map and unlocked fast travel |
| Space in air with elytra | Glide |
| Esc | Game menu, including confirmed mode change |

The bow uses native Arrow ammunition. The compatibility bridge converts legacy
MC_Arrow stacks with conservation and rollback safeguards. Opening menus cancels
an unfinished charge. Mod melee and ranged contacts retain native damage rules.

Four islands offer Plains village, Desert, Jungle and Mushroom areas. Unlock
their statues with F, then use the M map. Bram sells tools, Rina sells bows,
arrows and crops, and Alex trades blocks; her legacy full-pack placement has
the footing limitation below. Capture, technology and Pal progression follow
native requirements in both game modes.

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

## Known limitations

- A mob can remain trapped in one penetrating farm-border corner. Recovery and
  bounded give-up run; no penetration teleport is used. Other tested curb and
  farm-border approaches reached contact.
- The 300-second soak includes one 92.55 ms frame above the earlier 60 ms
  reference. No owner attribution was captured for that frame.
- Palworld's native previous-session/mod warning can appear after a normal
  save/title return. Its cause is unresolved. A rare upstream UE4SS async-load
  crash remains a known limitation; the final VF pack runs recorded no new crash.
- Alex's original full-pack legacy anchor still lacks verified footing. VF
  verified her trade using a disposable placement on existing owned floor;
  production terrain and the legacy anchor were unchanged.
- Minecraft sounds are reconstructed locally for existing sound bindings. Real
  player footsteps and bow retain their native audio routes. SA's isolated
  footstep sample correlation was 0.845659, below its strict 0.85 check.
- HUD-only custom-species portraits require assets from Islands & Animals.
- New-player coverage is partial: basic crafting, harvesting, statue, two
  deaths/respawns and save/reload were exercised; a complete shelter, first
  capture, natural-night mob encounter and full village route were not completed.
  First-person aim/table selection, empty-armor display, intermittent shoulder
  artifacts and native UI remnants remain reported issues. No complete new-player
  or zero-native-HUD-frame claim is made.
- Five original source texture packages remain excluded. Deleted historical cook
  inputs have not been recovered; source is not a complete clean-rebuild kit.
  Candidate recovery and deterministic repacking preserve existing cooked bytes.
- Initial installation and first-use setup can take several minutes. The
  blank-font diagnostic fallback is unreadable and is not normal play.

</details>

# PalCraft 플레이 가이드 — v1.1

HUD & Skins의 기본 조작입니다. Islands & Animals 전용은 기본 조작을 유지합니다.

| 키 | 동작 |
| --- | --- |
| 마우스 왼쪽 누르기 | 채굴, 블록 파괴, 공격, 바위와 나무 채집 |
| 마우스 오른쪽 | 설치 또는 사용, 활은 누르고 당긴 뒤 놓아 발사 |
| 1–9 / 마우스 휠 | 단축바 선택 |
| Tab | 인벤토리 및 팰, 팰 박스, 기술, 팰 도감 |
| E / Q | 파트너 소환·회수 / 스피어 던지기 |
| F / M | 상호작용 / 지도와 고속 이동 |
| 겉날개 착용 후 공중 Space | 활공 |
| Esc | 게임 메뉴 |

활은 기본 Arrow 탄약을 사용하며 기존 MC_Arrow를 보존 검사를 거쳐 변환합니다.
메뉴를 열면 진행 중인 활 당기기가 취소됩니다. 조각상은 F로 해제하고 M 지도에서 이동하세요.

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

알려진 제한과 측정 범위는 [README](README.md)를 확인하세요.
