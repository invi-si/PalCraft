[한국어](README.md) | **English**

# PalCraft v1.1

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
