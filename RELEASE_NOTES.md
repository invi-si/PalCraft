# PalCraft 1.0 release engineering

The installed mod name is PalCraft. Core, HUD & Skins and Islands & Animals have separate payloads; islands-only admission keeps native HUD and controls. Pack settings are read before optional service factories.

Legacy MinecraftBlocks builds and sidecars use copy-only save migration and a Lua read fallback. After successful copy, the installer quarantines the enumerated old loose paks, legacy schema folders and old enabled marker in a timestamped backup, with hashes and a conflict-safe restore script. Populated new saves win over legacy recovery generations. Renamed village NPC journal keys preserve exchange limits and pending receipts. Bram and Rina have new original skins and English/Korean names; Alex's skin is obtained locally from the user's jar.

The archive/source builders strip tests, probes, tokens, private marker history, personal skins and audited copied assets. Jar-derived Lua tables are replaced with local-data loader adapters. The public tree includes original source content with validated import metadata scrubbed, full GPL-3.0-or-later code licensing and CC BY 4.0 original-art attribution.

Minecraft Java 1.21.11 is the validated data source. All 27 language, registry, recipe, furnace, sound-metadata and font-metric tables are generated from locally extracted resources plus original integration rules, then cached by jar/version/converter identity. No converted vanilla table is distributed.

Install-time texture/font reconstruction replaces the general runtime material binder. The six font payloads match the original release; DXT/BC textures migrate to uncompressed BGRA8 with original material references and samplers. The owner accepted these visual differences from the prior compressed payloads. All 16 previously blank icon instances now use 15 original polygon designs, including the Ender Dragon. Islands-only Alex waits for the owned Plains floor and uses an anchor independent of old-base block restoration. Final native acceptance is recorded in the build manifest.

Known limitation: Minecraft sounds are unavailable at runtime in v1. Native fallback sounds or silence are used because OGG import has no supported reflected runtime path. Review candidates remain blocked for ordinary installation. Modified Palworld map art and copied native rig files are excluded.

The intentionally skipped-patch fallback entered the world with one warning and zero Lua errors/crashes. Its blank fonts make menus unreadable; this is a load-survival fallback, not normal play. The owner installation and exact settings were restored after testing.

**PalCraft v1.0: READY for offline delivery.** Opus accepted the measured cold-load exception in SEQ268. The second All cold entry was 15.703 seconds (first: 16.002 seconds); the original 14.5-second target was not met. The final release retains the native-tested gameplay, installer and asset bytes.
The final installed All, HUD-only and Islands-only choices booted without Lua errors or new crashes. Islands-only Alex now appears beside the Plains dock. A 300.008-second night-eight soak recorded 8,999 frames, maximum 45.479 ms and zero frames above 60 ms (native world delta).

SEQ268 accepts the v1.0 load-time exception without changing the measured result. The first launch after install does a one-time setup (several minutes); later loads are approximately 15-16 seconds on the acceptance machine. Uncompressed BGRA8 increases loading cost and differs from the prior lossy BC rendering. No new game launch or runtime change was made for promotion. The public source retains five provenance exclusions and is not a complete rebuild kit.
