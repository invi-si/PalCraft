# SPDX-License-Identifier: GPL-3.0-or-later
param(
 [Parameter(Mandatory=$true)][string]$PaksRoot,
 [Parameter(Mandatory=$true)][string]$AssetsRoot,
 [string]$Manifest,
 [string]$Receipt
)
$ErrorActionPreference='Stop'
if (-not $Manifest) { $Manifest=Join-Path $PSScriptRoot 'cooked-patches.json' }
if (-not $Receipt) { $Receipt=Join-Path $AssetsRoot '_palcraft/cooked-patch-receipt.json' }
Add-Type -AssemblyName System.Drawing,System.Web.Extensions
if (-not ('PalCraftCookedPakPatch' -as [type])) {
 Add-Type -Path @((Join-Path $PSScriptRoot 'CookedPakPatch.cs'),(Join-Path $PSScriptRoot 'DeterministicBc.cs')) -ReferencedAssemblies System.Drawing,System.Web.Extensions,System.Core
}
$report=[PalCraftCookedPakPatch]::Apply([IO.Path]::GetFullPath($PaksRoot),[IO.Path]::GetFullPath($AssetsRoot),[IO.Path]::GetFullPath($Manifest))
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $Receipt))
[IO.File]::WriteAllText($Receipt,$report,(New-Object Text.UTF8Encoding($false)))
$r=$report | ConvertFrom-Json
Write-Output ("PalCraft cooked paks: {0} textures, {1} font faces, {2} blank fallback asset sources" -f $r.textures,$r.fonts,$r.blankFallbackAssets)

# Audio has variable-sized compressed payloads, so its bounded patcher rebuilds
# only the dedicated audio paks after the fixed-range texture/font patches.
$soundManifest=Join-Path $PSScriptRoot 'cooked-sounds.json'
if (Test-Path -LiteralPath $soundManifest -PathType Leaf) {
 & (Join-Path $PSScriptRoot 'Patch-CookedSounds.ps1') -PaksRoot $PaksRoot -AssetsRoot $AssetsRoot -Manifest $soundManifest
}
