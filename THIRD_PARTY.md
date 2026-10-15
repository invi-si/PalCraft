# Third-party components and format references

The install-time texture/font pak patcher is PalCraft GPL-3.0-or-later source.
It uses the Windows .NET Framework (`System.Drawing`, compression, JSON and
cryptography). No third-party codec, packer, Unreal binary, or Oodle DLL is bundled.

The deterministic pak layout was checked against
[repak's public format implementation](https://github.com/trumank/repak), licensed
MIT or Apache-2.0. No repak source or executable is incorporated.

The TrueType serializer implements the public sfnt/simple-glyph format. Its output
is checked against the earlier authored FontTools build. FontTools is an optional
maintainer verification dependency under MIT; it is not an installer dependency
or bundled binary. [FontTools license](https://github.com/fonttools/fonttools/blob/main/LICENSE).

Unreal Engine and the modding kit are separately installed build/verification
tools under their own licenses. Proprietary Oodle texture compression is replaced
with uncompressed BGRA8 in these templates. NVIDIA Texture Tools was evaluated
locally and is not included in this release.

UE4SS and PalSchema remain separately installed runtime dependencies. Minecraft
jar/asset-index inputs, generated font/pixel caches, and patched paks are private
outputs belonging to the user's installation and are excluded from distribution.
