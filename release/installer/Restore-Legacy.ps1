# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
param([string]$ManifestPath=(Join-Path $PSScriptRoot 'manifest.json'),[switch]$WhatIf)
$ErrorActionPreference='Stop'
$manifest=Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$game=[IO.Path]::GetFullPath($manifest.game_root).TrimEnd('\','/')
$backup=[IO.Path]::GetFullPath((Split-Path -Parent $ManifestPath)).TrimEnd('\','/')
function Under([string]$Root,[string]$Relative) {
  if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[/\\])\.\.([/\\]|$)') { throw 'Unsafe restore path' }
  $p=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
  if (-not $p.StartsWith($Root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Restore path escaped root' }
  $check=$p
  while ($check -and $check.Length -ge $Root.Length) {
    if ((Test-Path -LiteralPath $check) -and ((Get-Item -LiteralPath $check).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Restore path must not contain a link' }
    $parent=Split-Path -Parent $check;if ($parent -eq $check) { break };$check=$parent
  }
  return $p
}
if (-not $backup.StartsWith((Join-Path $game 'PalCraft-legacy-backup')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Backup must be inside this installation legacy backup folder' }
$pending=@()
foreach ($row in $manifest.moves) {
  $src=Under $backup $row.relative;$dst=Under $game $row.relative
  if (-not (Test-Path -LiteralPath $src)) {
    # Already restored or a planned move never completed. Verify the original.
    foreach ($f in $row.files) {
      $p=Under $game $f.relative
      if (-not (Test-Path -LiteralPath $p -PathType Leaf) -or (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -ne $f.sha256) { throw "Missing backup/original: $($row.relative)" }
    };continue
  }
  if (Test-Path -LiteralPath $dst) { throw "Restore conflict; both paths preserved: $($row.relative)" }
  foreach ($f in $row.files) {
    $p=Under $backup $f.relative
    if (-not (Test-Path -LiteralPath $p -PathType Leaf) -or (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -ne $f.sha256) { throw "Backup changed: $($f.relative)" }
  }
  if ($row.kind -eq 'schema') {
    $count=0;$walk=New-Object System.Collections.Queue;$walk.Enqueue($src)
    while ($walk.Count) {
      $dir=$walk.Dequeue()
      foreach ($entry in @(Get-ChildItem -LiteralPath $dir)) {
        [void](Under $backup $entry.FullName.Substring($backup.Length+1))
        if ($entry.PSIsContainer) { $walk.Enqueue($entry.FullName) }else{ $count++ }
      }
    }
    if ($count -ne @($row.files).Count) { throw "Unrecorded backup files: $($row.relative)" }
  }
  $pending += [pscustomobject]@{Source=$src;Destination=$dst;Relative=$row.relative}
}
foreach ($row in $pending) {
  if (-not $WhatIf) { [void][IO.Directory]::CreateDirectory((Split-Path -Parent $row.Destination));Move-Item -LiteralPath $row.Source -Destination $row.Destination }
  [pscustomobject]@{Name=$row.Relative;Status=$(if ($WhatIf) {'would-restore'}else{'restored'})}
}
# Re-enable the legacy Lua mod only if it was enabled before cutover. Preserve
# the current PalCraft switch and every unrelated registration.
if ($manifest.legacy_enabled -and -not $WhatIf) {
  $mods=Under $game $manifest.mods_relative
  $txt=Under $game ($manifest.mods_relative+'/mods.txt')
  if (Test-Path -LiteralPath $txt) {
    $raw=[IO.File]::ReadAllText($txt);$raw=[regex]::Replace($raw,'(?im)^(\s*MinecraftBlocks\s*:\s*)[01](\s*)$','${1}1${2}')
    [IO.File]::WriteAllText($txt,$raw,[Text.UTF8Encoding]::new($false))
  }
  $jp=Under $game ($manifest.mods_relative+'/mods.json')
  if (Test-Path -LiteralPath $jp) {
    $doc=Get-Content -LiteralPath $jp -Raw | ConvertFrom-Json
    foreach ($mod in $doc) { if ($mod.mod_name -eq 'MinecraftBlocks') { $mod.mod_enabled=$true } }
    [IO.File]::WriteAllText($jp,(ConvertTo-Json -InputObject @($doc) -Depth 20),[Text.UTF8Encoding]::new($false))
  }
}
