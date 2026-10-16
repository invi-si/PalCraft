# PalCraft v1.1 — 17 October 2026

**READY for offline delivery under Opus's RV acceptance.** This release promotes
the exact VF final candidate (`7f88c0c15da1a908a3c1f22571888c973eac47c63d52a14a335ac174b3286f83`),
with `live_verified=true` under VF1/VF2. Every runtime, installer, schema and
cooked-asset byte is preserved. Promotion changes documentation and metadata.

## New since v1.0.1

- Minecraft sounds via install-time patching: 360 authored silent SoundWave
  templates in three audio-only paks accept original local Ogg bytes. Source,
  template, Ogg and pak hashes are checked; invalid/missing sounds stay silent.
  Reduced HUD/Islands choices cover 115/358 sounds. No user audio is distributed.
- Per-world Creative mode with confirmed switching, a vanilla-style catalog,
  icon tabs, keyboard search, scroll/drag, carried counts, hotbar and trash slot.
  Includes pick block, free placement, instant no-drop breaking, flight and local
  damage/hunger/stamina guards. Survival restoration keeps obtained items.
- Installer hardening preserves concurrent changes and adds robust validation,
  owned-file tracking and bilingual layout checks. SA's merged installer passed
  118 robustness checks; production installer bytes are retained exactly.
- Bow ammunition compatibility bridges legacy MC_Arrow to native Arrow with
  conservation/rollback. VA exercised 25 real releases; VF repeated 110→109.
- Skeletons use bounded shared physical arrows, with terrain/target collision
  and moving-target attachment. Captured skeleton native-enemy hits were verified
  in VE All and Islands; that bridge remains unchanged in VF. Player arrows keep
  native physics/ammunition/damage. Coverage is limited to tested routes.
- Held swords, shovel, potion and idle skeleton bow use corrected transforms.
  VD retained front/side motion/reference checks; references are independent
  vanilla-layer reconstructions, not Minecraft screenshots.
- More vanilla-like mob approach uses capsule/ground/line-of-sight checks,
  wall sliding, swept strafes and bounded recovery/give-up. Multiple nearby Pals
  can be targets. The exact farm corner remains a documented limitation.
- Pal melee damage requires actual native contact within reach/line of sight;
  ranged damage requires native projectile contact. VD verified Mossback,
  Sheepball and HawkBird cases, not every species or skill.
- New-player fixes retain use-time hotbar block selection, Pals-screen Summon,
  respawn Palbox-prompt masking and shared saved-item icon dependencies for
  HUD-only. NP acceptance remains partial; see the limits below.
- Covered per-slot hotbar warmup, in-world title-scan fencing and deferred
  noncritical sound prewarm reduce measured startup spikes without removing
  arrow, contact or AI services. First-use menu construction remains deferred.

## Performance

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

## Validation scope

VF's final All, HUD-only and Islands-only runs recorded zero production Lua
errors and zero new crash folders. Offline checks compiled 327 source and 249
packaged Lua modules, six pack/map graphs and 37 VA behavior assertions. VF real
input covered bow, Creative/catalog/Survival and Rina/Bram/Alex trade deltas.
Alex used disposable placement; VE's unchanged native-enemy arrow evidence is
retained by reference. Earlier real death/respawn evidence is not relabeled as a
fresh VF final-build respawn test. Startup screenshots sample frames and do not
prove every reveal frame. Whole-task diagnostic failures remain in private
evidence; zero production errors does not mean no failed harness experiments.

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

## Install and source

Use `dist/PalCraft-v1.1.zip` and its `.sha256`, then follow INSTALL.md. Windows,
Palworld 1.0.5.102999, separate UE4SS/PalSchema and owned Minecraft Java 1.21.11
are required. The installer works offline. Never redistribute patched local
assets. Source has the same five explicit provenance exclusions as v1.0.1;
existing cleared source content is preserved. The public repository adds a third
commit by Invi and an annotated v1.1 tag. RV performs no launch, remote addition,
push or publication. Final hashes are added to the external release notes only
after archive sealing, avoiding circular self-hashes.
