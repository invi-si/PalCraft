# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
<#
Copy-only migration contract (also the logic specification):
* LegacyDir = UE4SS/Mods/MinecraftBlocks; TargetDir = sibling PalCraft.
* Sidecars stay in the MOD ROOT, without an extra saves subdirectory.
* Copy all world-qualified JSON/text sidecars, including .tmp/.bak/.previous
  recovery generations. Lua validates world, schema and sequence on restore.
* Preserve pending inventory/trade receipts, settings and user skins.
* Identical target = no-op; missing/empty target = hash-verified atomic copy.
  Different nonempty target = conflict; preserve BOTH originals and report it.
* Never rename/delete legacy source files. Caller disables legacy loading only
  AFTER every result is copied/identical/would-copy. Conflicts require review.
* -WhatIf checks the same inventory/conflicts with zero writes.
Lua legacy_paths.lua reads old paths if new generations are missing/empty.
#>
param(
  [Parameter(Mandatory = $true)][string]$LegacyDir,
  [Parameter(Mandatory = $true)][string]$TargetDir,
  [switch]$WhatIf,
  [string]$GameRoot,
  [string]$LegacySet
)
$ErrorActionPreference = 'Stop'
if (-not $LegacySet) { $LegacySet = Join-Path $PSScriptRoot 'legacy_inventory.json' }
$sourceRoot = [IO.Path]::GetFullPath($LegacyDir).TrimEnd('\', '/')
$targetRoot = [IO.Path]::GetFullPath($TargetDir).TrimEnd('\', '/')
if ($sourceRoot -eq $targetRoot) { throw 'Legacy and new mod folders must differ' }
foreach ($candidate in @($sourceRoot, $targetRoot)) {
  if ($candidate.TrimEnd('\') -eq [IO.Path]::GetPathRoot($candidate).TrimEnd('\')) { throw 'A drive root is not a mod folder' }
}
if ((Test-Path -LiteralPath $sourceRoot) -and ((Get-Item -LiteralPath $sourceRoot).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Legacy root must not be a link' }
if ((Test-Path -LiteralPath $targetRoot) -and ((Get-Item -LiteralPath $targetRoot).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Target root must not be a link' }
$files = @(if (Test-Path -LiteralPath $sourceRoot) { Get-ChildItem -LiteralPath $sourceRoot -File | Where-Object {
  $n = $_.Name
  $n -notmatch '^(task|harness|probe|test|debug)' -and (
    $n -match '^[\w-]+-[0-9A-Fa-f]{32}\.(json|txt)(\.(tmp|bak|previous))?$' -or
    $n -match '^(skin-selection|ui-settings)\.json(\.(tmp|bak|previous))?$'
  )
} })
$skins = Join-Path $sourceRoot 'skins'
if (Test-Path -LiteralPath $skins -PathType Container) {
  if ((Get-Item -LiteralPath $skins).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Legacy skins must not be a link' }
  $files += @(Get-ChildItem -LiteralPath $skins -File -Filter '*.png')
}
# Inventory the complete explicit list before copying. No bulk move or delete.
$migrationBad=$false
foreach ($file in ($files | Sort-Object FullName)) {
  $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
  $destination = [IO.Path]::GetFullPath((Join-Path $targetRoot $relative))
  if (-not $destination.StartsWith($targetRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Destination escaped mod folder' }
  $result = [pscustomobject]@{ Name = $relative; Status = ''; Error = ''; SourceHash = ''; Destination = $destination }
  try {
    if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Source sidecar must not be a link' }
    $result.SourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    if (Test-Path -LiteralPath $destination) {
      $existing = Get-Item -LiteralPath $destination
      if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Target sidecar must not be a link' }
      if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -eq $result.SourceHash) { $result.Status = 'identical' }
      elseif ($existing.Length -gt 0) { $result.Status = 'conflict'; $result.Error = 'Different nonempty PalCraft file and legacy source both preserved' }
    }
    if (-not $result.Status) {
      if ($WhatIf) { $result.Status = 'would-copy' }
      else {
        $parent = Split-Path -Parent $destination
        if ((Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Destination sidecar parent must not be a link' }
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $temp = $destination + '.' + [Guid]::NewGuid().ToString('N') + '.migrate'
        Copy-Item -LiteralPath $file.FullName -Destination $temp
        if ((Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash -ne $result.SourceHash) { throw 'Hash mismatch; source and temporary copy retained' }
        if (Test-Path -LiteralPath $destination) {
          if ((Get-Item -LiteralPath $destination).Length -ne 0) { throw 'Target changed while migrating; source and temporary copy retained' }
          $emptyBackup = $destination + '.empty-before-migration-' + [Guid]::NewGuid().ToString('N')
          [IO.File]::Replace($temp, $destination, $emptyBackup)
        } else { [IO.File]::Move($temp, $destination) }
        $result.Status = 'copied'
      }
    }
  } catch { $result.Status = 'failed'; $result.Error = $_.Exception.Message }
  if ($result.Status -in @('failed','conflict')) { $migrationBad=$true }
  $result
}
if ($GameRoot -and -not $migrationBad) {
  & (Join-Path $PSScriptRoot 'Cutover-Legacy.ps1') -GameRoot $GameRoot -ModsDir (Split-Path -Parent $targetRoot) -LegacySet $LegacySet -WhatIf:$WhatIf
}
