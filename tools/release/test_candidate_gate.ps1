# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
# Exercise only the candidate guard, using a fake game path in project evidence.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outRoot=if($env:PALCRAFT_TEST_OUTPUT){$env:PALCRAFT_TEST_OUTPUT}else{Join-Path $root 'local/release/rs'}
$fixture=Join-Path $outRoot ('candidate-gate-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path (Join-Path $fixture 'payload') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $fixture 'manifest.json'),' { "status": "CANDIDATE" } ')
. (Join-Path $root 'release/installer/PalCraft-Installer.ps1') -LibraryOnly -LogPath (Join-Path $fixture 'installer.log') -Language en
$fakeGame=Join-Path $fixture 'FakeGame'
$rejected=$false
try {
  $mc=[pscustomobject]@{Version='1.21.test'}
  $dep=[pscustomobject]@{ModsPrefix='Mods/NativeMods/UE4SS/Mods';ModsDir=(Join-Path $fakeGame 'Mods/NativeMods/UE4SS/Mods')}
  Invoke-Install $fakeGame 'all' $false $mc $dep (Join-Path $fixture 'payload') '' | Out-Null
} catch {
  if($_.Exception.Message -notmatch 'incomplete review candidate'){throw}
  $rejected=$true
}
if(-not $rejected -or (Test-Path -LiteralPath $fakeGame)){throw 'Candidate guard did not stop before target writes'}
[IO.File]::WriteAllText((Join-Path $fixture 'report.json'),'{"status":"PASS","candidate_rejected_before_game_path_writes":true}')
Write-Output 'PASS candidate installer refusal before target writes'
