> Historical candidate evidence. The RH Opus acceptance promotes v1.0.1 to READY and supersedes the publication hold below. OC supersedes earlier OA/OB performance and memory results. See RELEASE_NOTES.md.

# PalCraft v1.0.1 candidate — Task OA

Owner publication remains on hold. This is a separate candidate; the released v1.0 files are unchanged.

Validated fixes: native Wither arrows do zero damage at or below half health, while above-half bow damage still works; normal Wither materials remain valid through armor swaps; custom modal menu clicks no longer fire the equipped native bow. Real trades, Tab/Technology cycles, statue/map travel, mineshaft interaction, boss summon/ride, bow use, actual death/respawn, and two title/reload cycles were exercised. Dragon perch landing and breath were observed with motion evidence; no Dragon behavior change was needed.

Startup changes retain the native identity, rendering, collision and epoch gates, shorten redundant stable sampling, retain admitted island classes, defer optional distant island loads, and batch covered reflection checks within 16 jobs/16 ms. Hot owned costume-root rotations use the existing input-only transform helper. Textures and native terrain are unchanged.

Final fresh-process cold runs: 14.498697 s and 14.303585 s; <=14.5 s gate: PASS. The first result is very close to the threshold; this is not a broad reliability claim. The original released v1.0 comparison measured 15.942028 s.

One soak: 600.007 measured seconds after 30 s warmup, 17994 native-world-delta samples, max 79.545 ms, 1 frames over60 ms, 0 missed frames. Registry growth: 29810 entries (49.683/s); completed-cycle heap trend: 0.063 MiB/min. The fixture attempted eight Lua zombies but sustained 4–6, plus a summoned native Dragon and ambient native costumes. The intended eight-mob workload was not achieved. Different historical scenes are not a controlled before/after memory comparison.

Remaining limitations: synchronous island class loads still take roughly 53–79 ms when first needed; explicit travel covers them, but proximity admission can still hitch. General <33 ms frame-time acceptance is not met. A separate optional-UI-prebuild-associated startup spike remains. Collision/ground-query registry retention remains. A custom remote-boss bar briefly showed 0/0 after respawn. One baseline native crash occurred during the debug route; a private stale-host fixture was suspected, corrected, and did not recur in subsequent candidate sessions. No claim of unlimited stability is made.

The package excludes private test companions and evidence. See the Task OA handoff and evidence directory for full measurements, clips, strips, bug receipts, source patch, and exact owner-restoration verification.
