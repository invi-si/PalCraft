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
