<details>
<summary><b>🌐 English</b> (click to open)</summary>

## PalCraft v1.1 (English)

Play Palworld the Minecraft way: blocks, tools, Minecraft controls and menus,
creatures, four themed islands, village trades and bosses, with native Palworld
Pals and progression. See the [release notes](RELEASE_v1.1.md) for known limitations.

Requires Windows single-player Palworld 1.0.5.102999, separately installed UE4SS
(compatibility baseline `2281fa31`) and PalSchema `0.6.71`, and your own Minecraft
Java Edition **1.21.11** resources. No external dependencies or extracted
Minecraft/Palworld assets are bundled. See [INSTALL.md](INSTALL.md) and the [player guide](PLAYER_GUIDE.md).

Choose **All**, **HUD & Skins only**, or **Islands & Animals only**. Core is always
included. HUD & Skins provides building, equipment, skins and Minecraft menus;
Islands & Animals provides islands, mobs, custom Pals, bosses and village NPCs,
using native HUD/controls when installed alone. Bram is the windmill toolsmith;
Rina is the farm fletcher. Their skins are original art.

The offline installer reconstructs textures, fonts, data and Minecraft sound
payloads from your own install, then patches cleared blank cooked templates.
Missing/invalid sound inputs retain authored silence. Patched paks and extracted
resources stay local and must not be redistributed. Initial setup can take
several minutes. Legacy sidecars and per-world mode settings are preserved;
keep sidecars when updating. Use the original release templates for reinstall.

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

## Performance and limitations

VF measured two fresh-process All world entries at **15.152178 s** and
**15.348525 s**, from actual world-start mouse release to cover end. Their first
60-second post-cover native simulation maxima were **87.321803 ms** and
**61.863199 ms**; first-visible deltas are included. Island admission measured
3/2 ms. These are acceptance-machine observations, without OS-cache flushing,
not GPU/present latency or a promise of hitch-free menus.

The final night scene held four zombies, two skeletons and two spiders for
**300.02 s**, with exactly eight mobs, zero missed frames and zero registry
growth. Maximum native delta was **92.548802 ms**, with **one frame above 60 ms**;
the earlier 60 ms soak reference was missed. Heap range was 2.807236 MiB and
maximum GC time about 5 ms. This bounded observation does not prove unlimited
stability. First-use menus can still pause while their UI is built.

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

## Source and licensing

The public source retains 13,136 cleared source packages and five explicit
texture exclusions. It is not a complete rebuild kit; see BUILD.md. Code is
GPL-3.0-or-later and original art is CC BY 4.0. Custom Pal models by Invi (created
with Meshy). See LICENSE, LICENSE-ART.md and THIRD_PARTY.md.

</details>

# PalCraft v1.1

팰월드를 마인크래프트 방식으로 즐기는 싱글플레이 모드입니다. 블록 건축, 도구,
몹, 섬 네 곳, 마을 거래, 보스와 마인크래프트식 메뉴를 제공합니다. 팰과 진행은
팰월드 기본 규칙을 따릅니다. 알려진 제한 사항은 [릴리스 노트](RELEASE_v1.1.md)를 참고하세요.

Windows용 Palworld 1.0.5.102999, 별도 설치한 UE4SS(기준 커밋 2281fa31),
PalSchema 0.6.71 및 본인 소유 Minecraft Java Edition 1.21.11이 필요합니다.
설치 프로그램은 로컬 리소스로 텍스처, 글꼴과 소리를 재구성합니다. 추출한 리소스나
패치한 팩을 재배포하지 마세요. 첫 설치와 초기 설정에는 수 분이 걸릴 수 있습니다.

All, HUD & Skins only, Islands & Animals only 중 선택하며 Core는 항상 포함됩니다.
Islands & Animals만 사용하면 팰월드 기본 HUD와 조작을 사용합니다.
[플레이 가이드](PLAYER_GUIDE.ko.md) · [설치](INSTALL.md) · [릴리스 노트](RELEASE_v1.1.md)

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

## 성능과 알려진 제한

VF의 동일 빌드 새 프로세스 All 진입은 15.152178초와 15.348525초였습니다.
커버 종료 후 60초 최대 네이티브 시뮬레이션 간격은 87.321803ms와 61.863199ms입니다.
8마리 300.02초 관찰에서 최대 92.548802ms, 60ms 초과 1프레임, 누락 프레임과
레지스트리 증가는 0이었습니다. GPU 표시 지연이나 무제한 안정성을 뜻하지 않습니다.

- 농장 경계의 특정 모서리에 몹이 끼일 수 있습니다.
- 첫 메뉴 생성 때 지연이 남을 수 있습니다.
- 기본 이전 세션/모드 경고와 드문 상위 UE4SS 비동기 로드 충돌이 알려져 있습니다.
- Alex의 기존 전체 팩 위치는 지지 바닥이 검증되지 않았습니다. 거래 검증은 기존 바닥의 임시 배치로 수행했습니다.
- 실제 플레이어 발소리와 활 소리는 기존 기본 경로를 사용합니다. 별도 발소리 샘플 검사는 엄격한 기준에 조금 못 미쳤습니다.
- HUD 전용 팩의 커스텀 종 초상화에는 Islands 에셋이 필요합니다.
- 새 플레이어의 첫 포획, 완성된 집, 자연 야간 몹 및 마을 전체 경로는 완전히 검증되지 않았습니다. 1인칭 조준, 빈 방어구 표시, 간헐적 어깨 표시와 기본 UI 흔적 문제가 남아 있습니다.
- 소스 텍스처 5개는 출처 검토로 제외되어 완전한 재빌드 키트가 아닙니다.
