# RH offline v1.0.1 promotion - 16 October 2026

**Current delivery status: READY for v1.0.1 under the Opus RH acceptance.** This supersedes the historical candidate/publication holds in OA, OB and OC. The original 14.5-second cold target remains failed: OC measured 15.928516 and 15.656792 seconds from actual world-start mouse release to cover end in fresh processes, without flushing the OS cache. Opus explicitly accepts those times for this release.

v1.0.1 includes native Wither arrow immunity below half health, Dragon perch/breath behavior, menu bow click-through protection, retained Wither materials, and a respawn-safe boss bar. Covered preloading and selective deterministic install-time BC3 for seven large atlas instances reduce visible post-cover spikes from the earlier 329-351 ms to two final 60-second maxima of 88.620901 and 85.328996 ms. Both intervals have two frames above 60 ms and zero above 100 ms. Plains/Jungle/Mushroom/Desert admission measured 2/4/3/4 ms.

The final 600.021-second soak after 30 seconds warmup maintained exactly eight living zombies, 17,988 frames and zero missed frames. Maximum simulation delta was 50.203800 ms, with zero above 60 ms. Registry length stayed 115 to 115; completed-cycle heap trend was +0.025326 MiB/min (acceptance limit 0.1), with heap 36.696-38.579 MiB. These are bounded native simulation measurements, not GPU/present latency or proof of unlimited stability. OC supersedes the earlier OA/OB memory failures.

OC's final real-input regression covered inventory, four Technology cycles, Bram/Rina trades with counts, native map travel, unmounted bow release consuming one arrow, actual Wither-skull death, respawn, and save/title/reload. Bow hit damage is not claimed. Final gameplay and cold logs report zero Lua errors and zero new crashes. Only All was live-tested in OC; earlier RF acceptance covers the other pack choices on the v1.0 base.

RH preserves every tested runtime, installer, asset and schema byte. Only documentation and readiness metadata change. The final archive is `dist/PalCraft-v1.0.1.zip`; the OC candidate/native-tested ZIPs and released v1.0 remain retained. The external release notes and final RH receipts add hashes after sealing to avoid circular self-hashes. Public source retains 13,136 cleared source packages and the five explicit exclusions; it is not a complete rebuild kit.

Known limitations remain several-minute first setup and local texture/font reconstruction; 15.7-15.9-second measured later cold loads; minor BC3 palette quantization on large atlases; Minecraft sounds unavailable; unreadable blank-font diagnostic fallback; finite motion/performance coverage; and Islands-only Alex trade not demonstrated. Original dimensions, linear-light mip generation and material references are preserved. Seven large atlas instances use 2,009,824 bytes versus 8,039,080 bytes (75% reduction), with small textures still BGRA8. Title preload moves work before the world-start click; indivisible native UI calls may still reach 464 ms under cover.

RH is offline: no game launch, game-install write, remote addition or push, no owner Git identity, and no write to CODEX_RESULT.txt or OPUS_INTERRUPT.txt. Historical sections below describe prior snapshots; current claims are limited to the acceptance above.

---

# RG offline v1.0 promotion - 16 October 2026

**Current delivery status: READY, accepted under Opus decision SEQ268.** This supersedes the historical NOT READY/CANDIDATE release status below. RF's measured second All cold entry remains 15.702672 seconds against the original 14.5-second target; it is an accepted v1.0 exception, not a passing measurement. First entry was 16.002473 seconds. The acceptance is hash-bound to `local/taskRF/REPORT.json` in `local/taskRG/acceptance.json`.

All 523 files that RF reported byte-identical to its native-tested archive remain byte-identical. This includes every runtime, installer, asset and schema file. Only documentation and manifests change. The original conditional START-HERE.txt is preserved; its requirement for a READY manifest is now satisfied. The final archive is `dist/PalCraft-v1.0.zip`; the previous candidate and native-tested ZIP remain retained as evidence.

The installer candidate-refusal test and negative privacy/provenance policy tests PASS in project evidence. No game launch, game-install write, remote, push or owner Git identity is part of RG. Full final delivery scans, hashes and public-repository verification are recorded in the final receipt and the external `RELEASE_v1.0.md` after sealing the archive; this in-archive report records the acceptance basis without a circular archive self-hash.

Requirements remain Windows, an existing compatible Palworld installation, separately installed UE4SS (baseline commit 2281fa31) and PalSchema 0.6.71, and the user's own Minecraft Java 1.21.11 resources. The installer is offline and bundles no external runtime dependencies or extracted Minecraft assets. Source includes 13,136 cleared packages; five source texture packages remain intentionally excluded and the snapshot is not a complete rebuild kit.

Known limitations: the first launch after install does a one-time setup (several minutes); later loads are approximately 15-16 seconds on the acceptance machine. Initial texture/font reconstruction also takes several minutes. BGRA8 reconstruction differs from the old lossy BC rendering and has an accepted loading cost. Minecraft sounds are unavailable; native sounds or silence are used. The blank-font diagnostic fallback is unreadable and is not normal play. Motion evidence is brief walking/head tracking; the five-minute soak measures native world delta, not GPU presentation, and does not prove long-duration registry stability. Islands-only Alex appearance is accepted; trade interaction was not demonstrated.

The following sections retain historical evidence and describe earlier candidates. Their blockers are superseded only to the extent stated in the current RF evidence and SEQ268 acceptance above.

---

# RS offline release report - 15 October 2026

**RS3 repairs islands-only title admission offline. All six packaged module graphs and 46 title/readiness simulations PASS. Distribution remains BLOCKED by the outstanding asset/native gates; both delivery outputs remain CANDIDATE. RS3 never launched the game, wrote inside its installation, or wrote CODEX_RESULT.txt / OPUS_INTERRUPT.txt. RS2 release gates 1 and 4 remain PASS.**

RS2 archived snapshot (superseded by RB installer fixes below): `dist/PalCraft-v1.0-CANDIDATE.zip`, **522 files / 60 cleared paks**, SHA256 `cdb0286d5283479b9b15bbd3e6419f2b8c4f78b222491b9c81241f074725e23b`. Payload leak scans and ZIP CRC validation PASS. Public source: **13,136 cleared source packages / 13,631 recorded files**, leak scan PASS; manifest SHA256 `07a998a0acdebd1901f7ae99c4038eedb8eb85e5d0560dffccb14dfb4e837ff8`.

## Gate 1 - local vanilla data generation: PASS

`installer/required_assets.json` extracts English language from the user's jar, Korean language and sound metadata from the asset index, and the jar's `data/minecraft/` tree (recipes, tags, loot and other data). RA's texture/font builder supplies local font metrics. `Initialize-LocalData.ps1` validates the inputs and creates a local index of unchanged extracted JSON. `jar_data.lua` reads those documents using the existing JSON codec and original `data_bindings.lua` integration rules, then generates all **27** runtime tables on first use. The furnace table `smelting.lua` was added after finding an audit omission.

The only distributed binding data is original mesh/save/item-ID mapping, authored tuning, resource identifiers, conversion operations and our native conversion recipes. No extracted language, recipe, sound or glyph payload is distributed. Private converted tables and generated caches stay in local evidence.

The combined cache lives under `PalCraft/cache/`; its embedded identity includes the full Minecraft version, jar/index hashes, converter/binding hashes and indexed-resource hash. Short filenames keep Win32 paths bounded. A changed identity regenerates the tables. Corrupt caches are retained as invalid evidence and regenerated. Minecraft Java **1.21.11** is the verified and installer-selected version.

Exact semantic diff: **27/27 modules equal**, including numeric keys, booleans, array order and saved block slots. First conversion **0.533 s**; fresh-process disk cache **0.046 s**. Jar/converter invalidation, corrupt-cache repair and JSON UTF-8/escape/surrogate checks PASS. The codec now copies ordinary UTF-8 spans in bulk to keep resource parsing fast.

Evidence: `../local/release/rs/jar-data-20261015-173550/report.json`; actual extracted JSON receipt `../local/release/rs/jar-data-20261015-172340/extraction.log` (**7,559 resources, zero missing**). The shipped, stripped converter was also checked directly: **27/27 exact**, first conversion **0.643 s**, disk cache **0.052 s**, in `../local/release/rs/jar-data-20261015-174712/report.json`. Hash-bound readiness is `../local/release/data-generator.json`. The packaged graph uses snapshots of actual jar-generated cache values, not substituted reference fixtures.

## Gate 4 - legacy cutover and restore: PASS

Save migration still copies direct-root sidecars, settings, user skins and `.tmp/.bak/.previous` recovery generations without deleting originals. A conflicting populated target blocks the entire quarantine. Once copies succeed, `migrate-legacy.ps1` invokes `Cutover-Legacy.ps1` to move only the exact legacy inventory: **63 old paks, 30 schema folders and the old enabled marker**. The backup is `PalCraft-legacy-backup/<timestamp>/`, containing the full hash inventory and `Restore-Legacy.ps1`. The installer then disables the old UE4SS registration.

The real owner layout was copied read-only into scratch. **94 moves / 279 files** passed quarantine and byte/hash-exact restore. Dry-run zero writes, populated-sidecar conflicts, restore conflicts, repeated migration/restore and protection of unrelated/current PalCraft paks PASS. Three absent loose archives were supplied from the original local archive evidence to cover the complete legacy inventory. Additional tests passed for legacy registration disable/restore, unrelated registration retention, junction rejection before any move, and old paks/schema without an old Lua folder.

Evidence: `../local/release/rs/cutover-20261015-173039/report.json`, `../local/release/rs/cutover-safety-20261015-174018/report.json`, and hash-bound `../local/release/legacy-cutover.json`. No cutover was applied to the real installation.

## Packaging and prior offline work

The current manifest inventories **319 Lua files, 30 schema packs and 63 legacy archives**. **241 production Lua modules** compiled; all six isolated pack/map choices PASS on the actual packaged entry and constructors. Native callbacks are recorded, not executed; service starts use stubs. Evidence: `../local/release/rs/packaged-module-graph-20261015-174524.json`. The existing sidecar fallback/NPC journal migration tests, negative release-policy tests, installer syntax checks and candidate refusal before target writes also PASS.

The public export is a fresh tree with no Git history, owner identifiers, local paths, private skins, extracted vanilla data or copied native rig/map payloads. It consumes RA's final **13,141-package** source handoff, including the native-reference meshes and production material changes. Five required source packages remain excluded by provenance/metadata review; the export explicitly remains CANDIDATE and cannot claim a complete rebuild kit.

Bram and Rina retain the original renamed skins/UI/trade identities and legacy journal aliases. Alex uses the user's jar skin. GPL-3.0-or-later code and CC BY 4.0 original art remain in place. Custom Pal models by Invi (created with Meshy). Internal `/Game/Minecraft*` paths and saved content IDs remain stable.

## Remaining release gates and limitation

1. RA reports an offline cooked dependency audit with zero missing mod imports for all three choices. Native pack-choice acceptance remains outstanding; the published asset receipt has not set its release readiness flags. Archive grouping and the offline Lua graph do not prove native behavior.
2. RA reports an offline native-skeleton reference repair for 15 cosmetic meshes. Native player/NPC animation acceptance remains outstanding; no copied skeleton/IK is authorized in the release.
3. The public source candidate needs clearance of its five excluded packages before claiming a complete rebuild kit.

**Known v1 limitation:** Minecraft sounds are unavailable at runtime; native fallback audio or silence is used. This is documented in README, INSTALL and release notes.

The installer continues to reject this candidate before target writes. Final machine-readable receipts are in `../local/release/rs/final-summary.json`; progress is appended with the RS prefix in `../coordination/CODEX_PROGRESS.txt`.

## RB acceptance follow-up - 15 October 2026

Current candidate ZIP SHA256 `a19e6d46f5e06da28f74aa0abecb3a45ccda4175943ad0a66717466b81a65f28`;522 files/60 paks. Gameplay payload matches the clean native install test. Installer now supports explicit Silent CandidateTest, quarantines exact owned files, uses current1.21.11 asset paths, and emits a valid multiline INI. The public source retains the RS13136-package CANDIDATE snapshot with3 installer-file updates and a passing delta leak scan.

All and corrected HUD-only reach title with0 detected Lua errors. Islands-only fails in native admission (`native_pack.lua:80` / `pawn_readiness.lua:5`, `GetPalPlayerState` on a TrivialObject). Input87 persisted for30min; no world entered. Rig/motion/visual/performance/fallback gates remain unaccepted. No release-readiness flags were promoted.

Actual clean install and uninstall completed;13949 files quarantined and hash-verified. Owner installation matches all1278 release-v1 hashes; settings/registrations restored exactly. Full evidence: `../local/taskRB/REPORT.json` and `../coordination/TASKRB_HANDOFF.txt`.

## RS3 - islands-only title admission repair - 15 October 2026

**Offline repair PASS. A native title retry and world acceptance remain outstanding.** The RB islands-only failure above describes the previous candidate; RS3 did not launch the game or promote any native release gate.

`native_pack.lua` now proves the local controller is a `PalPlayerController`, its world is the live `MainWorld_5` world with a valid persistent level, and its save identity is valid **before** calling `pawn_readiness`. Nil/invalid wrappers and absent save strings are handled safely. The new-world identity resolver can use the verified candidate controller before final pawn admission. The living pawn must remain ready for 0.75 seconds before services start.

The shared timer's priority `startup-probe` frame checks readiness before every service frame. ClientRestart immediately closes admission through a Lua flag; world/level departure advances the epoch and forgets retained service state. Environment, ready, quiesced and timer admission all use the same current-epoch fence. The reduced NPC context also now supplies its existing native trade service to Alex.

The service-start audit covers islands/streaming, Alex, creature/boss services, custom Pals, village NPCs, native trade/items, map pins, runtime textures, audio, hooks, notifications and key callbacks. Real reduced-pack constructors and master callbacks were exercised against userdata tripwires, including all registered title callbacks. Title worlds made zero player-state or GameInstance queries. Invalid player states, restart, death/resume, return to title and new-world identity controls passed. Positive controls replace only the island/Alex native spawn methods; these are offline simulations, not native behavior acceptance.

- **241 production modules compile; all six packaged pack/map choices PASS.** The strict title/readiness suite passes **46 cases**, covering both islands-only map flags. The same suite rejects the original RB candidate's forbidden title-time `GetPalPlayerState` call.
- **Candidate ZIP:** `dist/PalCraft-v1.0-CANDIDATE.zip`, **522 files / 60 paks**, SHA256 `ee22b8ab10a38d66b945eb442d130bf08fd45ff39ef68e9f9e85b319e8105e02`. Its only changed gameplay file is `native_pack.lua`; the manifest is refreshed. Every installer and asset byte matches RB's candidate. CRC and ZIP-to-tested-payload binding PASS.
- **Public source:** `public_repo/`, **13,136 cleared source packages / 13,633 recorded files**, CANDIDATE. Full export and final text-delta leak scans PASS. All cleared source assets, installer bytes and existing public documents are preserved. The previously unrecorded Korean README is now included in the manifest. The public exporter received a minimal import-order repair so its `__future__` import is legal; all **24 public Python tools compile**. Manifest SHA256 `ad9392916bca3561b53f84ac0496bb3c8d64988304d065c2727b0bc6244cbf35`.

Evidence: `../local/release/rs/rs3-20261015-185347/`, strict packaged title receipt `../local/release/rs/native-pack-title-20261015-185837.json`, and packaged graph `../local/release/rs/packaged-module-graph-20261015-185612.json`. The public source is also checked with its own exported graph and title-test tooling; final results and artifact hashes are bound in the RS3 evidence report. The five public-source exclusions and all previously outstanding visual, rig, gameplay, performance and native pack-choice gates remain outstanding.


## RE install-time cooked patching acceptance - 16 October 2026

**NOT READY.** The installer now reconstructs local Minecraft pixels/font faces and patches 60 blank cooked paks using included PowerShell/C# source. No internet, external packer or Unreal/Oodle binary is needed at install time. Pak payload/header/index hashes, deterministic repeat output, modified-template rejection, partial-failure hash tracking and uninstall preservation passed. General runtime material/texture binding is disabled; local jar DATA adapters and personal/original skin selection remain.

All 3,699 texture instances and six font faces have cooked layout records. 3,683 textures reconstruct; 16 instances across 15 unique packages remain blank because exact rendered-icon recipes are missing. 1,023 complete texture packages and all six font payloads match release-v1 exactly. Original material files and samplers are preserved. 2,671 compressed texture instances migrate to BGRA8; whole-pak identity is not claimed. The comparison excluding newly added shared dependencies gives a base-mip mean absolute channel difference of 2.760/255; 1,479 lower-mip comparisons average 2.474/255. Actual texel crops show visible differences, including bamboo and blackstone. The replacement textures are already uncompressed; this removes the codec dependency but does not reproduce the original lossy encoder output or mip filter.

Four native launches used the actual installer: All, HUD-only, Islands-only, and All with patching skipped. All three patched choices entered the disposable world and returned to title. The initial All run exposed a title-cover AssetRegistryHelpers admission error; one narrowly scoped whitelist fix passed seven admission checks and subsequent HUD/Islands/blank launches had zero Lua errors. No new crash occurred in any of the four runs. The final patched All configuration was not relaunched after this code fix; the final All blank-fallback configuration was.

Cold entry did not pass universally. Initial All measured 16.563 s and HUD 15.629 s from helper start, which includes input setup; HUD's later cover-begin log marker to cover-end interval was still 14.684 s. Islands measured 12.491 s from actual mouse release to native readiness, with visible world by the approximately 13.75 s sample. Final All blank fallback measured 16.598 s from actual mouse release. These are single observations with different starting positions; they are not repeated performance estimates.

Native Warden/Wither icons now render in Islands-only; Ender Dragon remains blank. Steve, Alex, Bram and Rina have distinct textures in All, with short clips and consecutive-frame strips. Full rig acceptance is not claimed. Islands-only Bram/Rina are instantiated with their correct original skins, but Alex still fails support placement. Native Islands death, real-input respawn, inventory and save/title were exercised. The patched All death/respawn test also ran; its early burst and later still do not prove every intervening reveal frame.

The skipped-patch fallback loads, emits one missing-assets warning, and responds to Tab/Esc with zero Lua errors/crashes. Blank fonts make the pause menu unreadable; usable-menu/save-title acceptance is not claimed for this configuration. It was closed through the owned window with Alt-F4. The single combined startup stress run lasted 283.506 s (268.506 sampled after warmup), with eight zombies, 7,985 frames, 12 over 60 ms and a 400 ms maximum during the mixed travel workload. Its requested 300 s completion flag is false, and registry growth remains an unresolved observation.

The owner installation was restored: all 1,278 release-v1 hashes, exact INIs and registrations, original enabled/candidate disabled, and no remaining game process. Steam was never stopped. Evidence and the exact final archive hash are in the private Task RE report and handoff. The clean public tree retains 13,136 cleared original source packages and its earlier source exclusions; it remains a candidate.


## Task RF acceptance (supersedes historical RE blockers above)

Status: NOT READY / CANDIDATE. The only failed RF release gate is the second All cold-entry time: 15.702672 seconds against a maximum of 14.5. The first All entry was 16.002473 seconds. Both start at actual mouse-button release, after cursor/focus preparation, and end at the loading-cover release; screenshot sequences accompany the timings.

All 16 previously unresolved texture instances (15 packages) now contain original flat polygon icons. The generator takes no Minecraft, reference-image or base-game pixels. The original PNGs, coordinates and CC BY 4.0 attribution are included in public source. All installed mip hashes match the authored output; 3,683 other texture instances and six fonts are reconstructed locally. The owner accepted BGRA8 versus old BC visual differences. Diagnostic blank-font menus are unreadable; normal installation requires local Minecraft inputs.

Islands-only Alex waits for the owned Plains collision footing and uses its arrival area instead of the unavailable old-base blocks. The installed package produced a visible Alex at the dock shore with the correct local-jar skin and head tracking. All, HUD-only and Islands-only entered through the actual candidate ZIP installer, with zero Lua errors and no new crashes. All saved, returned to title and reloaded in the second process. Real Tab/Esc inputs, a real post-soak death/respawn and entry/respawn captures were inspected. Steve first/third-person motion and Alex/Bram/Rina head tracking have clips plus consecutive 10-fps strips. This is bounded idle/walking evidence, not an exhaustive combat-animation suite.

The night-eight stationary soak sampled 300.008 seconds after 15 seconds warmup: 8,999 frames, maximum 45.478601 ms, zero over 60 ms and zero missed frames. The metric is native world delta, not GPU presentation time. Heap range was 5.229 MB and registry growth was 2,736 entries; this does not establish long-duration boundedness. The prior RE 400 ms spike coincided with a private exhaustive object/material diagnostic. That diagnostic was excluded from this soak and the spike did not recur. The optional service-budget profile was empty and is not claimed as attribution proof.

Initial All reconstruction took approximately 146 seconds on the test machine; other choices also took several minutes including prior-install preservation. Minecraft sounds remain unavailable. No non-candidate archive was produced and readiness flags remain false. The public source tree passed its full privacy/provenance scan; subsequent documentation-only changes are scanned incrementally. Final payload binding verifies that documentation/manifest updates preserve all tested gameplay, installer and asset bytes.


## RG final delivery verification

Final non-candidate archive: `dist/PalCraft-v1.0.zip` (352,925,294 bytes).

| Artifact | SHA256 |
| --- | --- |
| Final ZIP | `0f93d4b04ef9bfd40fe81e8690a88ead2bdd0c2d97debf3230e0a7008517434d` |
| Packaged manifest | `4fc7ec651de2bc0491ce886d979f1d9c592bb6405185734169d6cb9a83f20931` |
| Public export manifest | `90c005a303077b0ac053ebf60e847125823fb4e367b6566ab09e2df3dfb52d2e` |

ZIP CRC, 529 inventoried file hashes, exact archive-to-disk equality and the 523-file native-tested binding PASS. The full final package leak/provenance scan covered 530 files and 62 hash-cleared binaries, including all 60 template paks. The full public scan covered 27,013 files, including 13,352 license sidecars and 13,136 source packages. Identity, email, local-path and cleared binary/provenance checks PASS. All public production Lua, installer and patch sources were also matched to their tested package bytes. Five source texture exclusions remain explicit; `source_rebuild_complete` remains false.

The installer's own candidate-refusal test PASS; the actual packaged installer's 16-case status/flag matrix PASS with zero target writes, including READY passage without CandidateTest and rejection of ordinary candidate installation. Negative policy tests reject private identifiers/paths/emails and uncleared Mojang/base-game asset fixtures. No runtime or installer code was changed, so RF's unchanged native and safety evidence is retained.

Public repository: `public_repo/`, exactly **one** commit `4f0eb87ddb59f365dcad676c3b64fd969c1aed8b`, authored and committed by **Invi <invi@users.noreply.github.com>**, with annotated tag **v1.0** (tag object `14c3bf5c76f1dc2d2f5f55ef96bbce85c2b0bd41`). All 27,013 tracked Git blobs match the fully scanned export byte-for-byte. Working tree clean; `git fsck --full` PASS; **zero remotes**; nothing pushed. The entire object database contains one commit and one tag. No private Git history, inherited Git hooks or owner identity was used.

Public Git attributes preserve the manifest's exact bytes, including existing line endings. The ignore rules admit the four cleared Bram/Rina skin/license files while keeping generated asset folders excluded. The first Git inventory preflight exposed those four ignored files; that preflight repository was moved by exact path into project release evidence, and the delivered repository was recreated fresh after the correction and another full leak scan.

Receipts: `../local/taskRG/acceptance.json`, `final-tested-payload-binding.json`, `package-full-leak-scan.json`, `public-full-leak-scan.json`, `public-git-verification.json`, candidate guard/matrix and policy receipts, and `REPORT.json`. The packaged/public reports and public release document are frozen acceptance snapshots; this external section adds final hashes after ZIP sealing and Git commit creation, avoiding circular self-hashes.

RG never launched the game, changed its installation, added a remote, pushed, or wrote CODEX_RESULT.txt / OPUS_INTERRUPT.txt. Both prohibited coordination files retain their initial RG hashes. Existing unrelated root-worktree changes were left in place. The RF candidate and native-tested archives remain retained.
