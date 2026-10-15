# SPDX-License-Identifier: GPL-3.0-or-later
param([Parameter(Mandatory=$true)][string]$AssetsRoot,[string]$Recipes)
$ErrorActionPreference='Stop'
if (-not $Recipes) { $Recipes=Join-Path $PSScriptRoot 'texture-recipes.json' }
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web.Extensions
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'TextureCache.cs'))) -ReferencedAssemblies System.Drawing,System.Web.Extensions
[PalCraftTextureCache]::Build([IO.Path]::GetFullPath($AssetsRoot),[IO.Path]::GetFullPath($Recipes))
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'CookedFontCache.cs'))) -ReferencedAssemblies System.Drawing,System.Web.Extensions,System.Core,System.IO.Compression,System.IO.Compression.FileSystem
[PalCraftCookedFontCache]::Build([IO.Path]::GetFullPath($AssetsRoot))
