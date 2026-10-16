# Authored silent SoundWave template

Copyright Invi. GPL-3.0-or-later.

`S_Template.uasset` and `S_Template.uexp` are a UE 5.1 Windows cooked
SoundWave made from an authored 0.1-second, mono 22050 Hz zero waveform.
They contain no Minecraft or Palworld audio. The package name is
`/Game/MinecraftSA/S_Template`. Import with `PLATFORM_SPECIFIC` compression,
`FORCE_INLINE` loading and quality 40. The Windows cook uses Vorbis.

From the repository root, rebuild the three blank paks with:

```
python tools/release/build_sound_paks.py --template release/audio-template/S_Template --manifest release/asset-runtime/cooked-sounds.json --output local/audio-build
```

The builder retains its intermediate files for inspection. Use the manifest's
pack field to place each resulting pak in its payload pack. It changes the
compressed-format map name to the verified Palworld 1.0.5 Windows key.
Other engine or game versions require new native verification.

The installer validates and embeds the installing user's supported Minecraft
Ogg files. Never distribute the patched output or extracted source files.
