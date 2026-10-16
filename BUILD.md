> **v1.1 accepted:** current release is PalCraft-v1.1.zip. The VF payload is
> preserved exactly during RV promotion. Historical candidate instructions below
> describe earlier build stages; they do not revoke the recorded v1.1 acceptance.
> Five source texture exclusions and deleted historical cook inputs still prevent
> a complete clean rebuild. Recover/repack only from a hash-verified baseline.

# Building PalCraft

PalCraft code is licensed GPL-3.0-or-later. Original art is CC BY 4.0; see LICENSE-ART.md.

Use Windows, Python 3.12+, Lua 5.4 through `lupa.lua54`, Unreal Engine 5.1 and a compatible PalworldModdingKit. Install these tools separately. UE4SS and PalSchema are external runtime dependencies.

1. Set `PALCRAFT_KIT_ROOT` to your modding-kit project, `PALCRAFT_UE_ROOT` to your UE 5.1 directory, and `MC_LUA54_DIR` to the directory containing `lupa`. `PALCRAFT_CONTENT_ROOT` may point at an audited source Content tree.
2. Keep package paths under `Content/Minecraft*` and `Content/CustomPals*` stable. These are Unreal asset identities used by saves and schema references; the installed mod and schema folders use PalCraft names.
3. Open the supplied `project/Pal.uproject` in the modding kit. Cook the original geometry, materials, widget shells and custom Pals for Windows. Texture/sound placeholders must contain no Minecraft or Palworld payloads. Import metadata must use relative paths and no personal identifiers. Custom Pal models are included under the art license.
4. Use UnrealPak from UE 5.1 to create separate Core, HUD & Skins and Islands & Animals archives. Read dependencies before assigning packages: NPCs share the player rig, and native drops/trades share item assets. Put a shared package in Core once. Keep load-order patch names where overrides are intentional. Never use a game installation as an output directory.
5. Write `local/release/paks.json`: `{"complete": true, "pack_split_validated": true, "native_compatibility_ready": true, "paks": [{"source": "local/build/PalCraft-Core.pak", "pack": "core", "sha256": "<SHA256>", "clean": true}]}`. Set each readiness flag only after its check passes. Each receipt must match the exact bytes. Add a provenance audit at `local/release/audit.json`; excluded categories are `mojang`, `palworld`, `owner-personal` and `test`.
6. Run `python tools/release/classify_modules.py`, `python tools/release/test_module_graph.py`, `python tools/release/test_migration.py`, then `python tools/release/build_release.py`. The release is `release/dist/PalCraft-v1.0.1.zip`. `--candidate` produces a clearly marked review archive while assets or audit are incomplete.

The release builder applies the strip list, sanitizes private marker history, checks pack paths, computes SHA256 for every payload file, and validates ZIP CRCs. It refuses an ordinary release while clean assets or audit are pending. Extracted Minecraft textures/sounds and player skins are never part of the release. Installers obtain the required files from the user's own Java Edition 1.21.11 install.

The installer calls `release/asset-runtime/Build-TextureCache.ps1` after local extraction. It generates texture transforms and a font cache from the user's files; asset-index font providers replace empty jar stubs. `Initialize-LocalData.ps1` indexes unchanged extracted language, recipe, tag, sound and font-metric JSON locally. On first use `jar_data.lua` converts the original integration bindings in `data_bindings.lua` into all 27 runtime data tables, including furnace recipes. The data-only Lua cache is keyed by Minecraft version, full jar/index hashes and converter/binding hashes. No extracted or preconverted vanilla data belongs in the release or source export. The validated version is Minecraft Java 1.21.11.

Install-time cooked patching uses `CookedFontCache.cs`, `CookedPakPatch.cs`, `Patch-CookedPaks.ps1`, and `cooked-patches.json`. The manifest records package identity, source resources, recipe output, pixel format, mip dimensions, payload ranges, and pak hash locations. The six original font faces are reconstructed byte-for-byte. BGRA8 texture payloads are copied directly from reconstructed pixels. Most original DXT1/DXT5/BC5 payloads are converted to BGRA8 because the old Oodle encoder is not distributable. In v1.0.1, seven large atlas instances instead use the included deterministic BC3 encoder (`DeterministicBc.cs`), with at most four workers and SHA256-verified content/codec/dimension/format caching. Small pixel-art textures remain BGRA8. Original dimensions, material references and sampler properties are retained; mip levels use deterministic linear-light box filtering. This format change must be reported separately from byte-identical asset checks.

Maintainer migration tools are `tools/release/build_cooked_patch.py` and `cooked_payload.py`. They consume the private provenance audit, release-v1 scratch extractions and existing recipe evidence, emit blank templates under `local/taskRE/blank-paks/`, and write the public patch manifest. They never target a game directory. The owned pak writer uses deterministic uncompressed v3 entries; the .NET installer updates both copies of each entry SHA-1 and the index SHA-1. Verify with UnrealPak and an independent readback. No Unreal/Oodle executable or DLL is bundled. See `THIRD_PARTY.md`.

DXT1 conversions preserve opaque alpha; BC5 conversions preserve the original R,G,0,1 channel convention. The independent comparison separates the 63 added shared-dependency texture instances from release-v1 assets. The font payloads match exactly, while their cooked source-filename metadata is scrubbed. Whole-pak identity is not expected after these format, dependency, metadata and index changes.

Readiness requires complete asset coverage, explained format/metadata differences, all three native pack choices, and valid native cold-entry and lifecycle measurements. The owner accepts BGRA8 reconstruction in place of the older lossy BC encoding. The 16 legacy rendered icon instances are replaced by 15 original flat polygon designs from `tools/release/original_icons.py`; `build_cooked_patch.py` embeds these directly after zeroing the old payloads. They are excluded from installer patch ranges. Run `python tools/release/original_icons.py release/art/icons` to regenerate their PNG source art. No jar image is read by this generator. Native acceptance is recorded separately in the release manifest; private reference fonts, generated Minecraft pixels, patched paks and test receipts must never enter the public tree.

For offline equivalence use `tools/release/test_jar_data.py` with your own extracted assets, jar, index and private reference tables. `tools/release/test_legacy_cutover.py --game <installation>` copies the legacy layout to local evidence before testing; it never writes to the supplied installation. `test_legacy_safety.ps1` checks registrations, junction rejection and installations with only loose paks/schema. Generator readiness is recorded in a hash-bound private build receipt at `local/release/data-generator.json`; do not mark it complete without these checks. Private reference tables and generated caches must never enter an archive or export.

For a clean source snapshot run `python tools/release/export_public_repo.py --content-root <audited Content directory>`. It emits a fresh tree without Git history. Binary source packages require explicit provenance and clean-source receipts; exclusions and outstanding source packages are reported. A READY binary release may accompany a cleared source snapshot with intentional provenance exclusions. Check `source_rebuild_complete` and `source_exclusions` in PUBLIC_EXPORT.json; this snapshot excludes five source texture packages and is not a complete rebuild kit.

PalCraft v1.0 promotion accepts the 15.702672-second second cold load under Opus decision SEQ268; the original 14.5-second target remains recorded as failed. All runtime, installer and cooked-asset bytes are bound to the RF native-tested archive. Only documentation and readiness manifests change during promotion.

The v1.0.1 RH promotion uses the exact native-tested OC runtime, installer, assets and schemas; only documentation and metadata change after acceptance. Opus accepts measured 15.928516/15.656792-second cold loads, with the original 14.5-second target still failed. Use the v1.0.1 source and patch manifest together; its five modified blank template paks can be reproduced deterministically from the cleared v1.0 templates with the authored tools. The original v1.0 acceptance above is historical.

## v1.1 candidate recovery and Creative UI (Task VB)

The old RA/RB–RH/OA–OC cook evidence and clean-pak staging directories were
deleted. The historical editor cook cannot currently be reproduced from those
inputs. Do not run the old `build_cooked_patch.py` migration as a current rebuild
recipe: it requires that deleted private evidence. Keep its implementation for
historical migration only.

Recover the cooked build baseline from a surviving hash-verified candidate:

```powershell
python tools/release/recover_candidate_inputs.py --candidate release/dist/PalCraft-v1.1-CANDIDATE.zip --output local/taskVB/rebuild
```

The recovery checks every ZIP member against the candidate manifest, restores
all clean placeholder paks and the exact cooked texture/font/sound manifests and
recipes, and independently parses/authenticates/re-emits every pak through the
owned deterministic v3 writer. `rebuild-proof.json` lists exact differences;
`paks.json` is a usable replacement for lost staging paths. The CW input with
SHA256 `460042fc75801140d603e9c31fa77381e8e7ceb647e2dde4fac51d6783ff6c5b`
recovered 546 files and reproduced all 63 paks byte-for-byte (zero differences).
This proves recovery and deterministic repacking of candidate cooked inputs;
it does not recreate deleted editor source/cook history. Retain the baseline
and proof together. Do not replace an active task's shared candidate ZIP.

For the Creative redesign run:

```powershell
python tools/release/build_creative_ui_assets.py --baseline local/taskVB/rebuild/baseline --output local/taskVB/creative-assets
python tools/taskVB_offline.py
powershell -NoProfile -ExecutionPolicy Bypass -File tools/taskVB_extract.ps1
python tools/taskVB_preview.py
python tools/release/stage_creative_ui_candidate.py
```

`build_creative_ui_assets.py` clones five owned blank Texture2D identities into
one small HUD-only pak. Jar recipes supply `creative_inventory/tab_items.png`,
`tab_item_search.png`, the trash slot from `tab_inventory.png`, and compass/iron
ingot icons. Existing 63 paks stay byte-identical. No extracted pixels or fonts
are bundled. The installer already extracts the complete textures prefix, so
its existing extraction/cache/patch pipeline handles the new resources without
installer code changes. The asset builder is deterministic and can be rerun
against the immutable recovered baseline.

The source checker uses the existing Lua 5.4 `lupa` checker dependency under
`MC_LUA54_DIR`; VB restored that deleted tool into its own evidence tools folder
(`lupa` 2.6, project-local, no global installation). Preview scripts use Pillow.
Preview PNGs at 2560×1440 show 4× and 6× GUI texels (100% and 150%), Korean and
English, using production Lua paint/layout operations and the actual installer
texture/font cache. Native inventory contents are illustrative fixtures.
`preview-manifest.json` binds source sprites/fonts and all final preview files.
These previews require Opus's visual approval; Astra must still verify native
keyboard/search, wheel/drag scrolling, carry/delete and mode controls. Keep
`CANDIDATE` and `live_verified=false` until those gates pass.

The sparse VB candidate stager overlays only VB-owned source, its new blank
pak, manifests and docs on the selected candidate. It preserves all other
payload hashes, creates a separate `PalCraft-v1.1-VB-CANDIDATE.zip`, and refuses
an incompatible/concurrently changed cooked-manifest baseline. For integration,
overlay these same listed files onto the game worker's latest candidate; do not
replace its combat, input, UI-entry or lifecycle edits with the older CW files.
