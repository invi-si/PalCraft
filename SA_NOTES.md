# PalCraft v1.1 audio candidate

This candidate enables all360 existing Minecraft SoundWave assets on Palworld
1.0.5 Windows, using the installing user's Minecraft Java1.21.11 asset objects.
Three paks ship with authored silence. The installer embeds unchanged Vorbis
bytes, rebuilds variable-size exports and pak indexes, and checks source/page/
template hashes. Missing or invalid sources remain silent. No Minecraft audio
is included and no extra software or decoder is required.

The hardened installer is included; its118 robustness checks passed. Actual
installation patched360/360 sounds with zero fallback. Both reduced pack choices
also passed offline. Repeated builds and conversions are byte-identical. All152
original event asset/volume/pitch bindings and the runtime gain formula are
preserved. Sounds load on demand, without adding startup preload jobs.

Native evidence includes ten sound-case WASAPI captures and real-input walking,
bow, block place/break and menu-click clips. The cow feasibility proof correlates
0.999731 with its original source. Nine of ten cases passed the chosen strict
positive-correlation threshold of0.85; the footstep sample retry reached0.845659
and remains below that threshold. Original masked captures and diagnostics are
retained. No claim is made that all strict waveform checks passed.

Creature/boss event captures use the production sound-event function through
a private test request. Footstep and bow SoundWave samples are proven separately
from real player walking/bow actions: those player actions retain the existing
native audio route. This change does not add new player-footstep or bow hooks.
Actual dirt placement/break and UI click use real inputs and production sounds;
the dirt count went16->15->16 and the bow consumed one of64 arrows.

The final cold entry took15.911653 seconds versus the comparable16.456395-second
baseline, passing the0.3-second regression limit. This is one final observation,
not a performance guarantee. Final native logs have zero Lua errors/new crashes.
Three of five authorized launches were used. Tests ran at2560x1440, lowest
graphics and30FPS in the disposable world. Private probes and captured/user
audio are excluded from this archive.

Status remains CANDIDATE/live_verified=false because the strict footstep check
and player-route limitation above are explicit acceptance limitations. Ordinary
installation remains blocked by the existing candidate gate. No publication
or upload was performed. Existing released archives are unchanged.
