> Historical candidate evidence. The RH Opus acceptance promotes v1.0.1 to READY and supersedes the publication hold below. OC supersedes earlier OA/OB performance and memory results. See RELEASE_NOTES.md.

# PalCraft v1.0.1 candidate - Task OB

This candidate supersedes Task OA's performance and respawn limitations below. OA_NOTES.md is retained as historical provenance. Released v1.0 artifacts are unchanged; owner publication remains on hold.

First-use menu graphs, Alex's assets/trade graph, and his hidden non-colliding actor are now prepared behind the loading cover. His visible placement still waits for the existing support check. Final 60-second entry observation: 1785 native world-delta frames, maximum 78.781 ms, zero above100 ms. Progressive dependency admission keeps each measured island operation below33 ms: Plains19, Jungle24, Mushroom20, Desert21 ms. The callback profile identified UI prebuild and then Alex construction as stall owners; no texture, atlas, mip or pak asset changed.

Cold load was 15.888280 s from real LMB release to cover end, slower than OA14.30-14.50 s. This is the measured cost of covering first-use work. The old <=14.5 s cold target is not retained by this candidate.

The old UE4SS bridge retained one registry reference per output table. The compatibility shim releases only matching private output buffers in the newly appended contiguous registry tail after a successful synchronous call. Foreign/preexisting refs, free-list slots and exceptional calls are untouched; already-fixed UE4SS is a no-op. Collision query cadence is unchanged. A20s warmup sample released590/590 references with zero net growth.

One ten-minute soak: 600.018 measured seconds after30s warmup; 17998 frames; mobs8-8, underfilled frames0; max46.566 ms; 0 frames above60 ms; registry growth1982 (3.303234/s); completed-cycle heap trend+0.604681 MiB/min. Combined OB2 gates: PARTIAL/FAIL - see evidence. Native simulation deltas are not GPU/present timings.

The heap flatness gate remains failed: the cycle slope exceeds the predeclared absolute0.1MiB/min limit. The residual registry and heap growth is unattributed; the output-buffer fix does not establish global memory stability. See heap-limitations.md in the task evidence.

Zero/invalid/dead boss health no longer paints a0/0 bar. Actual Wither death and real UI respawn were verified with transition captures. The quick gameplay route exercised real menus, trades, mineshaft/chest, native-map Jungle travel, summon/ride, bow use, and two title/reload cycles. Later changes only affect Alex/covered UI warmup; source bindings retain unchanged route evidence and final Alex F interaction, cold, soak and lifecycle checks.

OA's baseline AV is classified as probable stale-object dispatch in the private fixture, with moderate confidence. Its UE4SS lookup frame supports that mechanism, but the exact Lua caller is unproven; it is not established as an upstream-only or product-only defect. No new OB native crash occurred. One initial island dependency path assertion was fixed using verified R2 package paths; final production logs are clean.

Private probes are excluded. Source patch, measurements, clips/16-frame strips, failure receipts and exact owner restoration are under local/taskOB and coordination/TASKOB_HANDOFF.txt.
