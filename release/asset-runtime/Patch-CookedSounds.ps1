# SPDX-License-Identifier: GPL-3.0-or-later
param([Parameter(Mandatory=$true)][string]$PaksRoot,[Parameter(Mandatory=$true)][string]$AssetsRoot,[string]$Manifest,[string]$Receipt)
$ErrorActionPreference='Stop'
if (-not $Manifest) { $Manifest=Join-Path $PSScriptRoot 'cooked-sounds.json' }
if (-not $Receipt) { $Receipt=Join-Path $AssetsRoot '_palcraft/cooked-sound-receipt.json' }
Add-Type -AssemblyName System.Web.Extensions
if (-not ('PalCraftCookedSoundPatch' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'CookedSoundPatch.cs') -ReferencedAssemblies System.Web.Extensions,System.Core }
$report=[PalCraftCookedSoundPatch]::Apply([IO.Path]::GetFullPath($PaksRoot),[IO.Path]::GetFullPath($AssetsRoot),[IO.Path]::GetFullPath($Manifest))
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $Receipt))
[IO.File]::WriteAllText($Receipt,$report,(New-Object Text.UTF8Encoding($false)))
$r=$report | ConvertFrom-Json
Write-Output ("PalCraft cooked audio: {0} Vorbis sounds, {1} silent fallbacks" -f $r.patched,$r.silentFallback)
