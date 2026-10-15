# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
param([Parameter(Mandatory=$true)][string]$GameRoot,
      [Parameter(Mandatory=$true)][string]$ModsDir,
      [string]$LegacySet=(Join-Path $PSScriptRoot 'legacy_inventory.json'),[switch]$WhatIf)
$ErrorActionPreference='Stop'
$game=[IO.Path]::GetFullPath($GameRoot).TrimEnd('\','/')
$mods=[IO.Path]::GetFullPath($ModsDir).TrimEnd('\','/')
if ($game -eq [IO.Path]::GetPathRoot($game).TrimEnd('\','/')) { throw 'Drive root is not an installation' }
function Checked([string]$p) {
  $full=[IO.Path]::GetFullPath($p)
  if (-not $full.StartsWith($game+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Legacy cutover escaped installation root' }
  $cursor=$full
  while ($cursor -and $cursor.Length -ge $game.Length) {
    if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Legacy cutover path contains link: $cursor" }
    $parent=Split-Path -Parent $cursor;if ($parent -eq $cursor) { break };$cursor=$parent
  }
  return $full
}
[void](Checked $mods)
$inventory=Get-Content -LiteralPath $LegacySet -Raw | ConvertFrom-Json
$plan=New-Object System.Collections.ArrayList
function Plan-Move([string]$path,[string]$kind) {
  $path=Checked $path
  if (-not (Test-Path -LiteralPath $path)) { return }
  $relative=$path.Substring($game.Length+1)
  $files=@()
  if ($kind -eq 'schema') {
    $walk=New-Object System.Collections.Queue;$walk.Enqueue($path)
    while ($walk.Count) {
      $dir=$walk.Dequeue();[void](Checked $dir)
      foreach ($entry in @(Get-ChildItem -LiteralPath $dir)) {
        [void](Checked $entry.FullName)
        if ($entry.PSIsContainer) { $walk.Enqueue($entry.FullName) }else{ $files += $entry }
      }
    }
  }else{ $files=@(Get-Item -LiteralPath $path) }
  $rows=@(foreach ($f in $files) { [void](Checked $f.FullName);[pscustomobject]@{relative=$f.FullName.Substring($game.Length+1);sha256=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash} })
  [void]$plan.Add([pscustomobject]@{relative=$relative;kind=$kind;files=$rows})
}
$paks=Join-Path $game 'Pal/Content/Paks'
if (Test-Path -LiteralPath $paks) {
  [void](Checked $paks)
  foreach ($file in @(Get-ChildItem -LiteralPath $paks -File)) { if ($inventory.paks -contains $file.Name) { Plan-Move $file.FullName 'pak' } }
  $loose=Join-Path $paks '~mods'
  if (Test-Path -LiteralPath $loose) {
    [void](Checked $loose)
    # Inspect directories before traversing them; never follow junctions.
    $queue=New-Object System.Collections.Queue;$queue.Enqueue($loose)
    while ($queue.Count) {
      $dir=$queue.Dequeue();[void](Checked $dir)
      foreach ($file in @(Get-ChildItem -LiteralPath $dir -File)) { if ($inventory.paks -contains $file.Name) { Plan-Move $file.FullName 'pak' } }
      foreach ($child in @(Get-ChildItem -LiteralPath $dir -Directory)) { if ($child.Name -ne 'PalCraft') { [void](Checked $child.FullName);$queue.Enqueue($child.FullName) } }
    }
  }
}
$schema=Join-Path $mods 'PalSchema/mods'
foreach ($name in $inventory.schema) {
  if ($name -notmatch '^(Minecraft[A-Za-z0-9_]*|CustomPalsA1)$') { throw 'Unexpected legacy schema identity' }
  Plan-Move (Join-Path $schema $name) 'schema'
}
$marker=Join-Path $mods 'MinecraftBlocks/enabled.txt'
$enabled=Test-Path -LiteralPath $marker
if (Test-Path -LiteralPath (Join-Path $mods 'mods.txt')) {
  if ([IO.File]::ReadAllText((Join-Path $mods 'mods.txt')) -match '(?im)^\s*MinecraftBlocks\s*:\s*1\s*$') { $enabled=$true }
}
if (Test-Path -LiteralPath (Join-Path $mods 'mods.json')) {
  $registrations=Get-Content -LiteralPath (Join-Path $mods 'mods.json') -Raw | ConvertFrom-Json
  foreach ($entry in $registrations) { if ($entry.mod_name -eq 'MinecraftBlocks' -and $entry.mod_enabled) { $enabled=$true } }
}
Plan-Move $marker 'lua-marker'
if ($plan.Count -eq 0) { return }
$stamp=(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)
$backup=Checked (Join-Path $game ('PalCraft-legacy-backup/'+$stamp))
$manifest=[ordered]@{format=1;game_root=$game;mods_relative=$mods.Substring($game.Length+1);legacy_enabled=$enabled;moves=@($plan);complete=$false}
if (-not $WhatIf) {
  [void][IO.Directory]::CreateDirectory($backup)
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Restore-Legacy.ps1') -Destination (Join-Path $backup 'Restore-Legacy.ps1')
  [IO.File]::WriteAllText((Join-Path $backup 'manifest.json'),($manifest | ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
}
# The full hash inventory is committed above before the first move. Every move
# has an explicit checked source and checked destination; nothing is deleted.
foreach ($row in $plan) {
  $src=Checked (Join-Path $game $row.relative);$dst=Checked (Join-Path $backup $row.relative)
  if (-not $WhatIf) {
    foreach ($f in $row.files) { if ((Get-FileHash -LiteralPath (Checked (Join-Path $game $f.relative)) -Algorithm SHA256).Hash -ne $f.sha256) { throw 'Legacy file changed after inventory; backup and originals preserved' } }
    if (Test-Path -LiteralPath $dst) { throw 'Legacy backup target already exists' }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $dst));Move-Item -LiteralPath $src -Destination $dst
  }
  [pscustomobject]@{Name=$row.relative;Status=$(if ($WhatIf) {'would-quarantine'}else{'quarantined'});Error='';Backup=$backup;Files=@($row.files).Count}
}
if (-not $WhatIf) { $manifest.complete=$true;[IO.File]::WriteAllText((Join-Path $backup 'manifest.json'),($manifest | ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false)) }
