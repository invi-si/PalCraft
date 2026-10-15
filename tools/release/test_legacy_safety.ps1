# SPDX-License-Identifier: GPL-3.0-or-later
param([Parameter(Mandatory=$true)][string]$OutputRoot)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out=Join-Path ([IO.Path]::GetFullPath($OutputRoot)) ('cutover-safety-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
[void][IO.Directory]::CreateDirectory($out)
$installer=Join-Path $project 'release/installer'
. (Join-Path $installer 'PalCraft-Installer.ps1') -LibraryOnly -LogPath (Join-Path $out 'installer.log')
function Fixture([string]$name) {
  $game=Join-Path $out $name;$mods=Join-Path $game 'Mods/NativeMods/UE4SS/Mods'
  $old=Join-Path $mods 'MinecraftBlocks';[void][IO.Directory]::CreateDirectory($old)
  [IO.File]::WriteAllText((Join-Path $old 'enabled.txt'),'')
  [IO.File]::WriteAllText((Join-Path $mods 'mods.txt'),"MinecraftBlocks : 1`r`nPalCraft : 1`r`nOther : 1`r`n")
  [IO.File]::WriteAllText((Join-Path $mods 'mods.json'),'[{"mod_name":"MinecraftBlocks","mod_enabled":true},{"mod_name":"PalCraft","mod_enabled":true}]')
  $schema=Join-Path $mods 'PalSchema/mods/MinecraftBlocks/items';[void][IO.Directory]::CreateDirectory($schema)
  [IO.File]::WriteAllText((Join-Path $schema 'own.json'),'{}')
  $paks=Join-Path $game 'Pal/Content/Paks/~mods';[void][IO.Directory]::CreateDirectory($paks)
  $set=Get-Content -LiteralPath (Join-Path $installer 'legacy_inventory.json') -Raw | ConvertFrom-Json
  [IO.File]::WriteAllText((Join-Path $paks $set.paks[0]),'legacy')
  return [pscustomobject]@{Game=$game;Mods=$mods;Schema=$schema;Dep=[pscustomobject]@{ModsDir=$mods;ModsPrefix='Mods/NativeMods/UE4SS/Mods'}}
}
$f=Fixture 'registration'
$r=@(Invoke-Migration $f.Game $f.Dep)
if ((Get-Content -LiteralPath (Join-Path $f.Mods 'mods.txt') -Raw) -notmatch 'MinecraftBlocks : 0') { throw 'Legacy mods.txt not disabled' }
$backup=@(Get-ChildItem -LiteralPath (Join-Path $f.Game 'PalCraft-legacy-backup') -Directory)[0].FullName
& (Join-Path $backup 'Restore-Legacy.ps1') | Out-Null
$raw=Get-Content -LiteralPath (Join-Path $f.Mods 'mods.txt') -Raw
if ($raw -notmatch 'MinecraftBlocks : 1' -or $raw -notmatch 'PalCraft : 1' -or $raw -notmatch 'Other : 1') { throw 'Restore registrations differ' }
$j=Get-Content -LiteralPath (Join-Path $f.Mods 'mods.json') -Raw | ConvertFrom-Json
if (-not $j[0].mod_enabled -or -not $j[1].mod_enabled) { throw 'JSON registration restore failed' }
$f=Fixture 'link-guard'
$outside=Join-Path $out 'outside';[void][IO.Directory]::CreateDirectory($outside)
[IO.File]::WriteAllText((Join-Path $outside 'leave.txt'),'preserve')
$link=Join-Path $f.Schema 'junction'
New-Item -ItemType Junction -Path $link -Value $outside | Out-Null
$rejected=$false
try { & (Join-Path $installer 'Cutover-Legacy.ps1') -GameRoot $f.Game -ModsDir $f.Mods | Out-Null }catch { $rejected=$_.Exception.Message -like '*link*' }
if (-not $rejected -or (Test-Path -LiteralPath (Join-Path $f.Game 'PalCraft-legacy-backup'))) { throw 'Junction guard failed' }
if ([IO.File]::ReadAllText((Join-Path $outside 'leave.txt')) -ne 'preserve') { throw 'Junction target changed' }
$f=Fixture 'no-lua-folder'
Move-Item -LiteralPath (Join-Path $f.Mods 'MinecraftBlocks') -Destination (Join-Path $out 'retained-old-lua')
$old=Join-Path $f.Mods 'MinecraftBlocks';$new=Join-Path $f.Mods 'PalCraft'
$res=@(& (Join-Path $installer 'migrate-legacy.ps1') -LegacyDir $old -TargetDir $new -GameRoot $f.Game)
if (@($res | Where-Object Status -eq 'quarantined').Count -ne 2) { throw 'Standalone schema/pak cutover failed' }
$report=[ordered]@{status='PASS';installer_registration_disable_restore=$true;unrelated_registration_preserved=$true;junction_rejected_before_moves=$true;standalone_paks_schema_without_lua=$true;game_launched=$false}
[IO.File]::WriteAllText((Join-Path $out 'report.json'),($report | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
Write-Output "RS PASS legacy safety: $out"
