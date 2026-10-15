# PalCraft

**PalCraft v1.0.1: READY for offline delivery.** Opus accepts the two OC cold loads of 15.928516 and 15.656792 seconds; the original 14.5-second target remains failed. See RELEASE_NOTES.md for OA/OB/OC changes and measured limitations.

Play Palworld the Minecraft way. Requires your own Minecraft Java Edition 1.21.11 install; no Mojang assets are distributed.

Choose **All**, **HUD & Skins only**, or **Islands & Animals only**. Core is installed with every choice. HUD & Skins includes the HUD/screens, player skins, Minecraft controls, building and equipment. Islands & Animals includes the islands, creatures/custom Pals, bosses and village, with native Palworld HUD and controls when used alone. Bram is the windmill toolsmith; Rina is the farm fletcher and farmer. Their skins are original art.

Install [UE4SS for Palworld](https://github.com/Okaetsu/RE-UE4SS/releases/tag/experimental-palworld) and [PalSchema](https://github.com/Okaetsu/PalSchema/releases) separately. The compatibility baseline for this source tree is UE4SS commit `2281fa31` and PalSchema `0.6.71`. Neither dependency is bundled. See [INSTALL.md](INSTALL.md).

The installer extracts textures, font providers and vanilla JSON from your local Java Edition install. It reconstructs pixels and font faces, writes them into the shipped blank cooked paks, and updates each changed pak entry and index hash. These installed textures use the original cooked material references and sampling settings. There is no general runtime texture import or material rebinding. Native class and texture dependencies are retained at title for covered startup. Personal skins and the original Bram/Rina skins retain their small runtime skin-selection path.

On first use Lua generates all 27 language, recipe, furnace, registry, sound-metadata and font-metric tables into `PalCraft/cache/`. Cache identity includes your Minecraft version and jar/index/converter hashes. Generated Minecraft files and patched paks remain local. Original box geometry and original custom Pal art are included; modified Palworld map art and copied native rig files are excluded. Minecraft sounds are unavailable at runtime in v1; native audio or silence provides the fallback.

The release uses 15 original flat silhouette icons in place of legacy rendered icons, including the Ender Dragon. These icons contain no Minecraft image data. Alex uses the owned Plains arrival area in Islands & Animals only; the full pack retains her old-base stall. Native acceptance for the final package is recorded in its manifest.

The first launch after install does a one-time setup (several minutes); later loads take approximately 15-16 seconds on the acceptance machine. Initial installation also rebuilds textures and fonts locally. Allow setup to finish before judging normal loading times. Missing Minecraft input prevents normal installation. The diagnostic blank-assets fallback has unreadable blank font faces and is not a playable installation.

Review archives marked **CANDIDATE** cannot be installed. A distributable archive must have a `READY` build manifest, a complete local-data generator and cleared paks. In-game visual/native acceptance is recorded separately by the game worker.

Existing MinecraftBlocks sidecars are copied into PalCraft without deleting legacy data. Migration preserves recovery generations, reports conflicting populated saves and carries renamed NPC trade limits forward. After a successful copy the installer moves the listed old loose paks, schema packs and enabled marker into `PalCraft-legacy-backup/<timestamp>/`, with hashes and a restore script.

Source is supplied as a clean tree with fresh history. Five source texture packages remain deliberately excluded by provenance review; the 13,136-package source snapshot is not a complete rebuild kit. The tested binary release uses cleared blank templates and local reconstruction. See [BUILD.md](BUILD.md), [CONTRIBUTING.md](CONTRIBUTING.md) and [ARCHITECTURE.md](ARCHITECTURE.md). Code is GPL-3.0-or-later; original art is CC BY 4.0. Custom Pal models by Invi (created with Meshy). See [LICENSE](LICENSE) and [LICENSE-ART.md](LICENSE-ART.md).

For v1.0.1, seven large atlas instances use deterministic install-time BC3 (75% less payload); small textures remain BGRA8. Minor enlarged palette quantization is accepted. No reconstructed Minecraft pixels are distributed. The final ten-minute eight-zombie soak had zero registry growth and +0.025326 MiB/min completed-cycle heap trend; this does not establish unlimited stability. Only All was live-tested in OC.
