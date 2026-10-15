# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
param([Parameter(Mandatory=$true)][string]$ModRoot,
      [Parameter(Mandatory=$true)][string]$JarPath,
      [Parameter(Mandatory=$true)][string]$MinecraftVersion,
      [string]$IndexPath)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($ModRoot)
if ($MinecraftVersion -ne '1.21.11') { throw 'PalCraft data bindings are verified for Minecraft Java 1.21.11. Install that version once, then retry.' }
foreach ($resource in @('assets/minecraft/lang/en_us.json','assets/minecraft/lang/ko_kr.json','assets/minecraft/sounds.json','assets/minecraft/_palcraft/font-metrics.json','assets/data/minecraft/recipe/paper.json','assets/data/minecraft/tags/item/planks.json')) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $resource) -PathType Leaf)) { throw "Required user-owned data missing: $resource" }
}
$hashes=@()
foreach ($name in @('jar_data.lua','data_bindings.lua','local_data.lua','json.lua')) {
  $p=Join-Path $root $name
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "Data converter source missing: $name" }
  $hashes += (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
}
$sha=[Security.Cryptography.SHA256]::Create()
try { $converter=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($hashes -join ':'))))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
$source=[ordered]@{format=1; mc_version=$MinecraftVersion;jar_sha256=(Get-FileHash -LiteralPath $JarPath -Algorithm SHA256).Hash.ToLowerInvariant();converter_sha256=$converter;index_sha256=$null}
if ($IndexPath) { $source.index_sha256=(Get-FileHash -LiteralPath $IndexPath -Algorithm SHA256).Hash.ToLowerInvariant() }
# Pack unchanged extracted JSON documents into one local read. This is an I/O
# index only: conversion to PalCraft values remains in Lua on first use.
$assets=Join-Path $root 'assets'
$resources=@('minecraft/lang/en_us.json','minecraft/lang/ko_kr.json','minecraft/sounds.json','minecraft/_palcraft/font-metrics.json')
foreach ($folder in @('data/minecraft/recipe','data/minecraft/tags/item')) {
  $dir=Join-Path $assets $folder
  foreach ($file in @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -Recurse)) { $resources += $file.FullName.Substring($assets.Length+1).Replace('\','/') }
}
$bundle=New-Object Text.StringBuilder
[void]$bundle.Append('{');$separator=''
foreach ($relative in $resources) {
  if ($relative -match '["\\]|(^|/)\.\.(/|$)') { throw 'Unsafe local JSON resource path' }
  [void]$bundle.Append($separator+'"'+$relative+'":')
  [void]$bundle.Append([IO.File]::ReadAllText((Join-Path $assets $relative),[Text.Encoding]::UTF8));$separator=','
}
[void]$bundle.Append('}')
$bundlePath=Join-Path $assets 'minecraft/_palcraft/source-data.json'
[IO.File]::WriteAllText($bundlePath,$bundle.ToString(),[Text.UTF8Encoding]::new($false))
$source.source_data_sha256=(Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256).Hash.ToLowerInvariant()
# Directory creation is installer-owned. Runtime writes only data-only Lua caches.
$cache=Join-Path $root 'cache'
if ((Test-Path -LiteralPath $cache) -and ((Get-Item -LiteralPath $cache).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Cache folder must not be a link' }
[void][IO.Directory]::CreateDirectory($cache)
$destination=Join-Path $root 'assets/minecraft/_palcraft/source.json'
[IO.File]::WriteAllText($destination,($source | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
# Local user-derived recovery inputs; these are never part of the release ZIP.
[IO.File]::WriteAllText((Join-Path $cache 'source.json'),($source | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
[IO.File]::Copy($bundlePath,(Join-Path $cache 'source-data.json'),$true)
[pscustomobject]$source
