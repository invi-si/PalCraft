# PalCraft v1.0.1 - 16 October 2026

Status: **READY for offline delivery**, accepted by Opus for RH. Supersedes v1.0. Nothing has been uploaded or pushed.

Archive: `dist/PalCraft-v1.0.1.zip` (352,939,982 bytes).

SHA256: `30dc070ba35fb8abf7c29798cc761cf2b581563173a05f9aa67bb70919f4cbad`

In-archive manifest SHA256: `72b043810130211c4d2f6e143192db9bd955e0c9b0b039479f22a7f528176ca3`.
Native-tested OC ZIP SHA256: `72e28d9067c0c1fff689e167570a607213d35095d60abcb6a4d0facf8668595b`.
Retained OC candidate ZIP SHA256: `a2492eff4c3766b1963265c98304b9fc4a01df750b440dfd1537421fc2f61059`.
The `.zip.sha256` file accompanies the archive.

## Changes since v1.0

- Wither is immune to native arrows below half health, with an above-half positive control. Dragon perch/breath behavior was observed. Wither material lifetime, menu bow click-through and transient respawn boss bars are fixed.
- Covered startup preloads static island/UI/Alex dependencies. Final island admissions are Plains 2, Jungle 4, Mushroom 3 and Desert 4 ms. Earlier 329-351 ms post-cover spikes fall to maxima of 88.620901 and 85.328996 ms in two 60-second intervals; each has two frames above 60 ms and none above 100 ms.
- Seven large atlas instances use authored deterministic install-time BC3: 8,039,080 to 2,009,824 bytes (75% reduction). Four unique 512px inputs are encoded locally, with bounded parallelism and hash-verified caching. Small textures remain BGRA8; linear-light mip generation and material references remain. Minor enlarged palette quantization is accepted; this is visual equivalence, not pixel identity.
- Conservative private-output cleanup fixes the waystone/bed collision callback's retained registry references. The final ten-minute eight-zombie soak has zero registry growth and +0.025326 MiB/min completed-cycle heap trend, passing the 0.1 MiB/min limit. Maximum simulation delta is 50.203800 ms, zero above 60 ms, over 17,988 frames in 600.021 seconds after 30 seconds warmup.
- Final real-input regression passes inventory, four Technology cycles, Bram stone-pickaxe and Rina 16-arrow trades, statue/map travel, unmounted bow draw/release, actual Wither-skull death, respawn and save/title/reload. Final logs have zero Lua errors and zero new crashes.

## Accepted limitations and requirements

Two final fresh-process cold entries measured **15.928516 and 15.656792 seconds**, from actual world-start LMB release to loading-cover end without OS cache flushing. The original 14.5-second target **failed**; Opus explicitly accepts these measured times. Preloading shifts work before the click. Native UI prebuild still reaches 464 ms under cover; scheduling budgets cannot cap indivisible native calls.

Native OC acceptance used **2560×1440, lowest graphics, and a 30 FPS cap**. The owner's original 60 FPS settings were restored exactly. These results apply to that test configuration.

Measurements are native simulation frame deltas, not GPU/present latency. Two 60-second observations and one ten-minute soak do not establish unlimited stability. The first 60-second interval has read-only probes at 56-58 seconds, after its hitches; the second has none. Only All was live-tested in OC. Earlier v1.0 evidence covers HUD-only and Islands-only; RH adds offline graph/guard checks, without a new native claim. Bow hit damage and exhaustive combat/riding animation are not claimed. Islands-only Alex trade remains unproven. An earlier OA crash was probably related to a private stale-object fixture, with the exact caller unresolved; no new final OC crash occurred.

Requires Windows, compatible Palworld, separately installed UE4SS (baseline commit `2281fa31`) and PalSchema `0.6.71`, and the user's own Minecraft Java `1.21.11` resources. First setup and local texture/font reconstruction may take several minutes. Minecraft sounds are unavailable; native audio or silence is used. The blank-font diagnostic fallback is unreadable and is not suitable for normal play.

The release contains cleared blank cooked templates and authored art/code; Minecraft pixels, fonts and data are reconstructed locally. No external runtime dependencies or Minecraft/base-game payloads are bundled. Code is GPL-3.0-or-later; original art is CC BY 4.0. Custom Pal models by Invi (created with Meshy).

Source retains **13,136** cleared packages and five explicit provenance exclusions recorded in `PUBLIC_EXPORT.json`; `source_rebuild_complete` remains false. It is not a complete rebuild kit. This release preserves all 517 OC-tested runtime, installer, asset and schema files byte-for-byte. Promotion changes documentation and readiness metadata only.

RH is offline: no game launch/install write, remote addition, push or upload. The public repository preserves the original v1.0 commit/tag and adds a second Invi-authored v1.0.1 commit and annotated tag. Full final package/public leak scans and exact Git blob binding are recorded in private RH receipts; historical OA/OB/OC notes are retained and superseded by this acceptance.
