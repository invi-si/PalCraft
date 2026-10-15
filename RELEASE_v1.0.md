# PalCraft v1.0 - offline release, 16 October 2026

Status: **READY**, accepted by Opus under **SEQ268**. This is a local delivery; nothing has been uploaded or pushed.

## SHA256

| Artifact | SHA256 |
| --- | --- |
| `dist/PalCraft-v1.0.zip` | `0f93d4b04ef9bfd40fe81e8690a88ead2bdd0c2d97debf3230e0a7008517434d` |
| In-archive `manifest.json` | `4fc7ec651de2bc0491ce886d979f1d9c592bb6405185734169d6cb9a83f20931` |
| RF native-tested archive (private evidence) | `7f4550fd212fe1960054209a1248207dc3fbbffea6429efe52779456d26a7b45` |
| RF final candidate (retained evidence) | `a04d07da190d3f90b0f886366f4a0be86308c6993c73d190573809bdb23c9253` |

The final archive is 352,925,294 bytes. It contains one `PalCraft-v1.0/` root with 529 manifest-inventoried files plus the manifest itself: 60 cleared template paks, production Lua and schema payloads for Core / HUD & Skins / Islands & Animals, the offline PowerShell installer, the C# and PowerShell texture/font reconstruction code and recipes, documentation, licenses and original art. External dependencies and extracted Minecraft assets are not bundled. ZIP CRC, every manifest file hash, and archive-to-disk byte equality pass. All 523 files retained by RF from its native-tested archive remain byte-identical, including all 516 runtime/installer/asset/schema files; the other differences are documentation and the readiness manifest.

## Requirements and installation

Windows with PowerShell 5.1 / .NET Framework; an existing compatible Palworld installation; UE4SS for Palworld (tested baseline commit `2281fa31`) and PalSchema `0.6.71`, installed separately; and the user's own Minecraft Java Edition `1.21.11` with its jar and required asset objects present locally. These versions describe the tested baseline. See INSTALL.md for pack choices and migration/restore details.

Extract the archive and run `installer/Install-PalCraft.bat`. The READY manifest permits ordinary installation without `-CandidateTest`. Minecraft texture/font/data reconstruction is local and offline. Do not redistribute the resulting patched paks, extracted assets or caches. Existing legacy data is preserved through the enumerated backup and restore process.

## Acceptance and known limitations

- SEQ268 accepts the second All cold load of **15.702672 s**, with first load **16.002473 s**. Both start at actual mouse-button release and end at cover release. The original **14.5 s** target remains a failed measurement; this release uses an explicit accepted exception. Uncompressed BGRA8 trades roughly one second of loading for exact reconstructed pixels; the prior release-v1 timing method differed.
- The first launch after install does a one-time setup (several minutes); later loads take approximately **15-16 s** on the acceptance machine. Initial installer texture/font reconstruction also takes several minutes.
- BGRA8 reconstruction differs visibly from the former lossy BC rendering; that difference is accepted. All 16 formerly unresolved icon instances use 15 original polygon designs, with installed mip hashes verified. Minecraft sounds are unavailable: native audio or silence is used.
- Normal installation requires local Minecraft inputs. The intentionally skipped-patch diagnostic fallback has unreadable blank-font menus and is not a playable configuration.
- RF's All, HUD-only and Islands-only choices booted through the actual ZIP installer with zero Lua errors and no new crashes. Real save/title/reload and All death/respawn were exercised. Steve walking and Alex/Bram/Rina head tracking are bounded clips, not exhaustive combat/riding coverage. Islands-only Alex appearance at the Plains dock shore is accepted; trade interaction was not demonstrated.
- The night-eight soak sampled **300.008 s** after 15 s warmup: **8,999 frames**, **45.478601 ms** maximum, **zero** over 60 ms. This is native world delta, not GPU presentation timing. Registry growth of 2,736 and heap range of 5.229 MB remain disclosed; long-duration boundedness is not established. The earlier 400 ms observation coincided with a private exhaustive diagnostic, which was absent from the accepted soak; exclusive causality is not proven.
- A persistent prior-session native mod warning existed before RF; no new crash was recorded. Modified Palworld map artwork and copied native skeleton/IK bytes are excluded.

## Public source and licenses

`public_repo/` contains 13,136 cleared source packages plus code, original art and build instructions. Code is GPL-3.0-or-later and original art is CC BY 4.0. Custom Pal models by Invi (created with Meshy). Five source texture packages remain excluded by provenance review, so this is a cleared source snapshot, not a complete rebuild kit:

- `MinecraftBlocks/T_MC_UI20_death_dim.uasset`
- `MinecraftBlocks/T_MC_UI_dim.uasset`
- `MinecraftBlocks/T_MC_UI_white.uasset`
- `MinecraftMobs/T_arrow.uasset`
- `MinecraftMobs/T_poof.uasset`

The binary payload uses hash-cleared blank templates plus local reconstruction. Source clearance is distinct from complete source rebuild coverage. The public snapshot is initialized as a fresh Git repository with one Invi commit and tag v1.0; it has no remote and is not pushed. Its frozen copy of this document omits its own manifest/commit hashes to avoid circular references. Final local hashes and repository verification are recorded in the external release report and the private RG receipt.
