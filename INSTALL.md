# Install PalCraft

**PalCraft v1.0.1: READY for offline delivery.** Opus accepts the two OC cold loads of 15.928516 and 15.656792 seconds; the original 14.5-second target remains failed. See RELEASE_NOTES.md for OA/OB/OC changes and measured limitations.

Use a release whose manifest status is `READY`. Close Palworld before changing installed mod files. Install the compatible [UE4SS Palworld build](https://github.com/Okaetsu/RE-UE4SS/releases/tag/experimental-palworld) and [PalSchema](https://github.com/Okaetsu/PalSchema/releases) first; these dependencies are not included.

1. Own and launch Minecraft Java Edition 1.21.11 at least once so the jar and required asset objects are present locally.
2. Extract the PalCraft release. Run `installer/Install-PalCraft.bat` and select the game folder, Minecraft install and pack choice. The official launcher and CurseForge install locations are searched automatically; a browse fallback is available.
3. Choose All, HUD & Skins only, or Islands & Animals only. Core is always installed. Optional mounted pak/schema choices are applied by the installer; restart after changing them. The modified Palworld map artwork is excluded from the distributable payload.
4. The installer extracts your assets, reconstructs texture pixels and font faces, patches the blank cooked paks, verifies template hashes, recomputes pak entry/index hashes, and prepares the local JSON index before enabling the mod. No internet access, Unreal installation, or external packer is needed for this step. Patched paks contain your local Minecraft assets and must not be redistributed.
5. It copies MinecraftBlocks sidecars into the PalCraft mod root, preserving originals and recovery files. A different populated destination stops cutover. After a successful copy it moves listed legacy loose paks, Minecraft/CustomPalsA1 schema folders and the old enabled marker into `PalCraft-legacy-backup/<timestamp>/`, with a hash manifest and `Restore-Legacy.ps1`. No legacy content is deleted.
6. Start the game normally. User skins belong in `PalCraft/skins/`. Alex's NPC skin comes from your own jar; Bram and Rina use the included original skins.

The default installed paths are `Mods/NativeMods/UE4SS/Mods/PalCraft/`, `Mods/NativeMods/UE4SS/Mods/PalSchema/mods/PalCraft_*/`, and `Pal/Content/Paks/~mods/PalCraft/`. Lua sidecars stay directly in the PalCraft mod folder. Keep PalSchema installed for worlds that use its registered content.

If generated data is missing, rerun the installer for the same local Minecraft install. Do not obtain extracted Minecraft/Palworld assets from another person's release archive. A review candidate deliberately refuses installation while data generation or clean paks are incomplete.

The cooked patch receipt is `PalCraft/assets/minecraft/_palcraft/cooked-patch-receipt.json`. `complete: false` means some assets remain blank; it does not enable the previous runtime binding path. The command-line `-SkipCookedPatch` option is for diagnosing the blank-assets fallback. Normal installation patches automatically. The diagnostic blank fallback can load, but blank font faces also make menu text unreadable; rerun normal patching before playing. Reinstall from the original release templates when changing Minecraft inputs; the patcher refuses to treat modified paks as pristine templates.

The first launch after install does a one-time setup (several minutes); later loads take approximately 15-16 seconds on the acceptance machine. Also allow several minutes for initial local texture/font reconstruction during installation. The installer requires a supported local Minecraft install and refuses normal installation without it. Original silhouette icons are included and need no Minecraft pixels. In Islands & Animals only, Alex is near the Plains arrival area.

The first mod startup converts your local JSON into a versioned table cache under `PalCraft/cache/`; later startups read that cache. Changing the jar or converter invalidates it automatically. Minecraft sounds are unavailable in this version: native sounds or silence provide the fallback.

To reverse legacy cutover, close the game, disable/uninstall PalCraft's new payload, then run the backup's `Restore-Legacy.ps1 -WhatIf` to review it and run it again without `-WhatIf` to restore. It verifies backup hashes and refuses to overwrite existing legacy destinations. It restores the prior legacy Lua enablement while preserving unrelated mod registrations; copied PalCraft save sidecars remain available.

For v1.0.1, seven large atlas instances use deterministic install-time BC3 (75% less payload); small textures remain BGRA8. Minor enlarged palette quantization is accepted. No reconstructed Minecraft pixels are distributed. The final ten-minute eight-zombie soak had zero registry growth and +0.025326 MiB/min completed-cycle heap trend; this does not establish unlimited stability. Only All was live-tested in OC.
