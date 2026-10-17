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
