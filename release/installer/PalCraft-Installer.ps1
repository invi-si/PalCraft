<#
  PalCraft installer - Windows PowerShell 5.1 + WinForms, no extra runtimes.
  Launch through Install-PalCraft.bat (or: powershell -ExecutionPolicy Bypass -File PalCraft-Installer.ps1).
  See README.md in this folder for the developer documentation.

  This file is intentionally pure ASCII; all UI text lives in strings.json (UTF-8).
#>
param(
  [switch]$WhatIf,          # dry run: log what would happen, change nothing
  [switch]$Silent,          # no GUI: use the other switches/parameters
  [switch]$CandidateTest,   # explicit local acceptance only; does not mark a candidate READY
  [switch]$SkipCookedPatch, # diagnostic blank-assets fallback; never enables runtime binding
  [switch]$Uninstall,       # (with -Silent semantics) remove an existing install
  [switch]$RemoveSaves,     # with -Uninstall: also remove PalCraft\saves
  [switch]$Migrate,         # run legacy MinecraftBlocks migration only
  [string]$GameDir,         # Palworld folder (auto-detected when omitted)
  [string]$MinecraftDir,    # .minecraft style folder (auto-detected when omitted)
  [ValidateSet('all', 'hud_skins', 'islands_animals')][string]$PackChoice = 'all',
  [switch]$MapArt,          # include Palworld map artwork (islands pack only)
  [string]$PayloadDir,      # default: <script dir>\payload
  [string]$RequiredList,    # default: <script dir>\required_assets.json
  [ValidateSet('', 'en', 'ko')][string]$Language = '',
  [string]$LogPath,         # default: %TEMP%\PalCraft-install.log
  [switch]$LibraryOnly      # dot-source: define functions only (used by tests)
)

$script:InstallerVersion = '1.0.1'
$script:SteamAppId = '1623730'
$script:Dry = [bool]$WhatIf
$script:UiLog = $null
$script:UiProgress = $null
$script:ScriptDir = $PSScriptRoot
if (-not $PayloadDir) {
  $adjacentPayload = Join-Path (Split-Path -Parent $script:ScriptDir) 'payload'
  $PayloadDir = if (Test-Path -LiteralPath $adjacentPayload -PathType Container) { $adjacentPayload } else { Join-Path $script:ScriptDir 'payload' }
}
if (-not $RequiredList) { $RequiredList = Join-Path $script:ScriptDir 'required_assets.json' }
$script:LogFile = if ($LogPath) { $LogPath } else { Join-Path $env:TEMP 'PalCraft-install.log' }
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ----------------------------------------------------------------- logging / i18n
function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
  try { [IO.File]::AppendAllText($script:LogFile, $line + "`r`n", $script:Utf8NoBom) } catch { }
  if ($script:UiLog) { & $script:UiLog $line }
  elseif (-not $script:Quiet) { Write-Host $line }
}

if ($Language) { $script:Lang = $Language }
else { $script:Lang = if ((Get-UICulture).TwoLetterISOLanguageName -eq 'ko') { 'ko' } else { 'en' } }
$script:Strings = $null
try {
  $script:Strings = [IO.File]::ReadAllText((Join-Path $script:ScriptDir 'strings.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
} catch { }

function T {
  param([string]$Key, [object[]]$FormatArgs)
  $v = $null
  if ($script:Strings) {
    $p = $script:Strings.($script:Lang).PSObject.Properties[$Key]
    if ($p) { $v = [string]$p.Value }
    if (-not $v) { $p = $script:Strings.en.PSObject.Properties[$Key]; if ($p) { $v = [string]$p.Value } }
  }
  if (-not $v) { $v = $Key }
  if ($FormatArgs -and $FormatArgs.Count -gt 0) { return ($v -f $FormatArgs) }
  return $v
}

function Set-Progress { param([int]$Pct, [string]$Text) if ($script:UiProgress) { & $script:UiProgress $Pct $Text } }

# ----------------------------------------------------------------- path / file helpers
function Get-FullPath { param([string]$P) [IO.Path]::GetFullPath($P).TrimEnd('\') }

function Get-RelPath {
  param([string]$Root, [string]$Full)
  $r = (Get-FullPath $Root) + '\'
  $f = Get-FullPath $Full
  if (-not $f.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes root: $Full" }
  return ($f.Substring($r.Length) -replace '\\', '/')
}

function Resolve-UnderRoot {
  # Join a manifest-style relative path to root and refuse anything that escapes root.
  param([string]$Root, [string]$Rel)
  $full = Get-FullPath (Join-Path $Root ($Rel -replace '/', '\'))
  $r = (Get-FullPath $Root) + '\'
  if (-not $full.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing path outside root: $Rel" }
  return $full
}

function Get-Sha256 {
  param([string]$Path)
  $sha = [Security.Cryptography.SHA256]::Create()
  $fs = [IO.File]::OpenRead($Path)
  try { return ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '') } finally { $fs.Dispose(); $sha.Dispose() }
}

function New-State {
  $script:St = @{ Game = $null; Files = [ordered]@{}; Dirs = (New-Object System.Collections.ArrayList) }
}
New-State

function Add-Record {
  param([string]$Full, [string]$Kind, [string]$Sha)
  if (-not $script:St.Game) { return }
  $rel = Get-RelPath $script:St.Game $Full
  $size = 0
  if (-not $script:Dry -and (Test-Path -LiteralPath $Full)) { $size = (Get-Item -LiteralPath $Full).Length }
  $script:St.Files[$rel.ToLowerInvariant()] = [ordered]@{ path = $rel; sha256 = $Sha; size = $size; kind = $Kind }
}

function Ensure-Dir {
  param([string]$Dir)
  if (Test-Path -LiteralPath $Dir -PathType Container) { return }
  $parent = Split-Path -Parent $Dir
  if ($parent -and $parent -ne $Dir) { Ensure-Dir $parent }
  if ($script:Dry) { return }
  New-Item -ItemType Directory -Path $Dir -Force | Out-Null
  if ($script:St.Game) { [void]$script:St.Dirs.Add((Get-RelPath $script:St.Game $Dir)) }
}

function Copy-Tracked {
  param([string]$Src, [string]$Dst, [string]$Kind)
  if ($script:Dry) { Write-Log "[dry-run] copy $Src -> $Dst"; Add-Record $Dst $Kind '(dry-run)'; return }
  Ensure-Dir (Split-Path -Parent $Dst)
  Copy-Item -LiteralPath $Src -Destination $Dst -Force
  Add-Record $Dst $Kind (Get-Sha256 $Dst)
}

function Write-TextTracked {
  param([string]$Path, [string]$Text, [string]$Kind)
  if ($script:Dry) { Write-Log "[dry-run] write $Path ($($Text.Length) chars)"; Add-Record $Path $Kind '(dry-run)'; return }
  Ensure-Dir (Split-Path -Parent $Path)
  [IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
  Add-Record $Path $Kind (Get-Sha256 $Path)
}

function Remove-EmptyDirChain {
  param([string]$Dir, [string]$StopAt)
  while ($Dir -and (Get-FullPath $Dir).Length -gt (Get-FullPath $StopAt).Length) {
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { $Dir = Split-Path -Parent $Dir; continue }
    if (@(Get-ChildItem -LiteralPath $Dir -Force).Count -gt 0) { break }
    if ($script:Dry) { Write-Log "[dry-run] remove empty dir $Dir"; break }
    Remove-Item -LiteralPath $Dir -Force
    $Dir = Split-Path -Parent $Dir
  }
}

# ----------------------------------------------------------------- Palworld / Steam
function Get-SteamRoots {
  $r = @()
  foreach ($k in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
    try {
      $p = Get-ItemProperty -Path $k -ErrorAction Stop
      foreach ($n in 'SteamPath', 'InstallPath') { if ($p.$n) { $r += ([string]$p.$n -replace '/', '\') } }
    } catch { }
  }
  foreach ($p in "${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam") { if ($p) { $r += $p } }
  @($r | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
}

function Read-LibraryFolders {
  # Parses Steam libraryfolders.vdf (new and old format). Returns @{Path; HasApp} objects.
  param([string]$Vdf)
  $libs = @(); $cur = $null
  foreach ($line in [IO.File]::ReadAllLines($Vdf)) {
    if ($line -match '^\s*"path"\s+"(.+)"\s*$') {
      $cur = [pscustomobject]@{ Path = ($Matches[1] -replace '\\\\', '\'); HasApp = $false }; $libs += $cur
    } elseif ($line -match '^\s*"\d+"\s+"([A-Za-z]:\\\\.+)"\s*$') {   # old format: "1" "D:\\Games\\Steam"
      $cur = [pscustomobject]@{ Path = ($Matches[1] -replace '\\\\', '\'); HasApp = $false }; $libs += $cur
    } elseif ($cur -and $line -match ('^\s*"' + $script:SteamAppId + '"\s+"')) {
      $cur.HasApp = $true
    }
  }
  return ,$libs
}

function Test-PalworldDir {
  param([string]$Dir)
  if (-not $Dir -or -not (Test-Path -LiteralPath (Join-Path $Dir 'Pal') -PathType Container)) { return $false }
  return ((Test-Path -LiteralPath (Join-Path $Dir 'Palworld.exe')) -or
    (Test-Path -LiteralPath (Join-Path $Dir 'Pal\Binaries\Win64\Palworld-Win64-Shipping.exe')))
}

function Find-Palworld {
  # Returns valid Palworld folders; libraries that list app 1623730 come first.
  $pref = @(); $other = @()
  foreach ($root in (Get-SteamRoots)) {
    $libs = @([pscustomobject]@{ Path = $root; HasApp = $false })
    $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) { try { $libs += (Read-LibraryFolders $vdf) } catch { Write-Log "vdf parse failed: $($_.Exception.Message)" 'WARN' } }
    foreach ($l in $libs) {
      $sa = Join-Path $l.Path 'steamapps'
      $dir = $null
      $acf = Join-Path $sa "appmanifest_$($script:SteamAppId).acf"
      if (Test-Path -LiteralPath $acf) {
        $m = [regex]::Match([IO.File]::ReadAllText($acf), '"installdir"\s+"([^"]+)"')
        if ($m.Success) { $dir = Join-Path $sa ('common\' + $m.Groups[1].Value) }
      }
      if (-not $dir) { $dir = Join-Path $sa 'common\Palworld' }
      if (Test-PalworldDir $dir) { if ($l.HasApp) { $pref += $dir } else { $other += $dir } }
    }
  }
  @(($pref + $other) | Select-Object -Unique)
}

# ----------------------------------------------------------------- dependencies
function Get-DependencyInfo {
  # UE4SS layouts: <game>\Mods\NativeMods\UE4SS (Palworld mod-loader layout) or <game>\Pal\Binaries\Win64 (dwmapi proxy).
  param([string]$Game)
  $info = [ordered]@{ Ue4ssOk = $false; PalSchemaOk = $false; Ue4ssDir = $null; ModsDir = $null; ModsPrefix = $null }
  $win64 = Join-Path $Game 'Pal\Binaries\Win64'
  $cands = @(
    @{ Dir = (Join-Path $Game 'Mods\NativeMods\UE4SS'); Mods = 'Mods'; Prefix = 'Mods/NativeMods/UE4SS/Mods' },
    @{ Dir = (Join-Path $win64 'ue4ss'); Mods = 'Mods'; Prefix = 'Pal/Binaries/Win64/ue4ss/Mods' },
    @{ Dir = $win64; Mods = 'Mods'; Prefix = 'Pal/Binaries/Win64/Mods' }
  )
  foreach ($c in $cands) {
    $dll = Test-Path -LiteralPath (Join-Path $c.Dir 'UE4SS.dll')
    $proxy = (Test-Path -LiteralPath (Join-Path $c.Dir 'dwmapi.dll')) -or (Test-Path -LiteralPath (Join-Path $win64 'dwmapi.dll'))
    $modsDir = Join-Path $c.Dir $c.Mods
    if ($dll -or ($proxy -and (Test-Path -LiteralPath $modsDir -PathType Container))) {
      $info.Ue4ssOk = $true; $info.Ue4ssDir = $c.Dir; $info.ModsDir = $modsDir; $info.ModsPrefix = $c.Prefix
      break
    }
  }
  if ($info.Ue4ssOk) { $info.PalSchemaOk = Test-Path -LiteralPath (Join-Path $info.ModsDir 'PalSchema') -PathType Container }
  [pscustomobject]$info
}

# ----------------------------------------------------------------- Minecraft discovery
function Get-McRoots {
  param([string[]]$Extra)
  $r = @()
  if ($Extra) { $r += $Extra }
  if ($env:APPDATA) { $r += (Join-Path $env:APPDATA '.minecraft') }
  if ($env:USERPROFILE) { $r += (Join-Path $env:USERPROFILE 'curseforge\minecraft\Install') }
  @($r | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'versions') -PathType Container) } | Select-Object -Unique)
}

function Find-MinecraftInstall {
  # Only the vanilla version whose data bindings have passed equivalence.
  param([string[]]$ExtraRoots)
  $cands = @()
  $roots = @(Get-McRoots $ExtraRoots)
  foreach ($root in $roots) {
    foreach ($d in (Get-ChildItem -LiteralPath (Join-Path $root 'versions') -Directory -ErrorAction SilentlyContinue)) {
      if ($d.Name -ne '1.21.11') { continue }
      $jar = Join-Path $d.FullName ($d.Name + '.jar'); $json = Join-Path $d.FullName ($d.Name + '.json')
      if (-not ((Test-Path -LiteralPath $jar) -and (Test-Path -LiteralPath $json))) { continue }
      $idx = $null
      try {
        $j = [IO.File]::ReadAllText($json, [Text.Encoding]::UTF8) | ConvertFrom-Json
        if ($j.assetIndex -and $j.assetIndex.id) { $idx = [string]$j.assetIndex.id } elseif ($j.assets) { $idx = [string]$j.assets }
      } catch { Write-Log "bad version json $json : $($_.Exception.Message)" 'WARN'; continue }
      $assets = Join-Path $root 'assets'
      $indexPath = if ($idx) { Join-Path $assets "indexes\$idx.json" } else { $null }
      if ($indexPath -and -not (Test-Path -LiteralPath $indexPath)) {   # fall back to other roots' asset stores
        foreach ($o in $roots) {
          $alt = Join-Path $o "assets\indexes\$idx.json"
          if (Test-Path -LiteralPath $alt) { $assets = Join-Path $o 'assets'; $indexPath = $alt; break }
        }
      }
      $cands += [pscustomobject]@{
        Root = $root; Version = $d.Name; VersionObj = [version]$d.Name; JarPath = $jar
        AssetIndexId = $idx; IndexPath = $indexPath; IndexOk = [bool]($indexPath -and (Test-Path -LiteralPath $indexPath))
        ObjectsDir = (Join-Path $assets 'objects')
      }
    }
  }
  if (-not $cands) { return $null }
  # prefer versions whose index is present, then newest
  $best = $cands | Sort-Object @{ Expression = { $_.IndexOk }; Descending = $true }, @{ Expression = { $_.VersionObj }; Descending = $true } | Select-Object -First 1
  return $best
}

# ----------------------------------------------------------------- required assets + extraction
function Get-RequiredAssets {
  param([string]$ListPath, [string[]]$Packs)
  if (-not (Test-Path -LiteralPath $ListPath)) { throw "required_assets.json not found: $ListPath" }
  $ListPath = (Resolve-Path -LiteralPath $ListPath).ProviderPath
  $doc = [IO.File]::ReadAllText($ListPath,[Text.Encoding]::UTF8) | ConvertFrom-Json
  if ($doc.schema_version -ne 1) { throw "Unsupported required_assets schema_version $($doc.schema_version)" }
  $want = @('core') + $Packs
  $out = @()
  foreach ($e in $doc.entries) {
    $hit = $false
    foreach ($p in $e.packs) { if ($want -contains $p) { $hit = $true } }
    if ($hit) { $out += $e }
  }
  return ,$out
}

function Export-McAssets {
  # Extracts required textures (from the jar) and sounds (via the asset index) under $AssetsRoot.
  param($Mc, [string[]]$Packs, [string]$AssetsRoot, [string]$ListPath)
  $entries = Get-RequiredAssets $ListPath $Packs
  $missing = New-Object System.Collections.ArrayList
  $written = 0; $seen = @{}

  function Out-Rel([string]$p) { if ($p.StartsWith('assets/')) { $p.Substring(7) } else { $p } }
  function Save-Stream([string]$rel, [scriptblock]$Open, [string]$origin) {
    if ($rel -match '(^|/)\.\.(/|$)' -or $rel.StartsWith('/')) { throw "unsafe asset path $rel" }
    $dst = Join-Path $AssetsRoot ($rel -replace '/', '\')
    if ($seen.ContainsKey($rel.ToLowerInvariant())) { return }
    $seen[$rel.ToLowerInvariant()] = 1
    if ($script:Dry) { Write-Log "[dry-run] extract $origin -> $dst"; $script:AssetsCounter++; Add-Record $dst 'asset' '(dry-run)'; return }
    Ensure-Dir (Split-Path -Parent $dst)
    $in = & $Open
    try { $out = [IO.File]::Create($dst); try { $in.CopyTo($out) } finally { $out.Dispose() } } finally { $in.Dispose() }
    Add-Record $dst 'asset' (Get-Sha256 $dst)
    $script:AssetsCounter++
  }

  $script:AssetsCounter = 0
  $zip = $null; $jarMap = $null; $idxMap = $null
  try {
    if (@($entries | Where-Object { $_.kind -like 'jar*' }).Count) {
      $zip = [IO.Compression.ZipFile]::OpenRead($Mc.JarPath)
      $jarMap = @{}
      foreach ($z in $zip.Entries) { if ($z.Name) { $jarMap[$z.FullName] = $z } }
    }
    if (@($entries | Where-Object { $_.kind -like 'sound*' }).Count) {
      if ($Mc.IndexOk) {
        $idx = [IO.File]::ReadAllText($Mc.IndexPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
        $idxMap = @{}
        foreach ($p in $idx.objects.PSObject.Properties) { $idxMap[$p.Name] = [string]$p.Value.hash }
      } else { Write-Log "asset index missing for $($Mc.Version); sounds skipped" 'WARN' }
    }
    $n = 0
    foreach ($e in $entries) {
      $n++
      if (($n % 10) -eq 0) { Set-Progress (40 + [int](40 * $n / [Math]::Max(1, $entries.Count))) 'assets' }
      $note = if ($e.PSObject.Properties['optional'] -and $e.optional) { 'optional' } else { 'required' }
      switch ($e.kind) {
        'jar' {
          $z = if ($jarMap) { $jarMap[$e.path] } else { $null }
          if (-not $z) { [void]$missing.Add("jar:$($e.path) ($note)"); continue }
          Save-Stream (Out-Rel $e.path) ([scriptblock]::Create('$z.Open()').GetNewClosure()) $e.path
        }
        'jar_prefix' {
          $hits = @($jarMap.Keys | Where-Object { $_.StartsWith($e.path) })
          if (-not $hits) { [void]$missing.Add("jar_prefix:$($e.path) ($note)"); continue }
          foreach ($k in $hits) { $zz = $jarMap[$k]; Save-Stream (Out-Rel $k) ([scriptblock]::Create('$zz.Open()').GetNewClosure()) $k }
        }
        'sound' {
          if (-not $idxMap) { [void]$missing.Add("sound:$($e.path) (no asset index)"); continue }
          $h = $idxMap[$e.path]
          if (-not $h) { [void]$missing.Add("sound:$($e.path) ($note)"); continue }
          $obj = Join-Path $Mc.ObjectsDir ($h.Substring(0, 2) + '\' + $h)
          if (-not (Test-Path -LiteralPath $obj)) { [void]$missing.Add("sound-object:$($e.path) hash $h not in assets/objects"); continue }
          Save-Stream $e.path ([scriptblock]::Create('[IO.File]::OpenRead($obj)').GetNewClosure()) $e.path
        }
        'sound_prefix' {
          if (-not $idxMap) { [void]$missing.Add("sound_prefix:$($e.path) (no asset index)"); continue }
          $hits = @($idxMap.Keys | Where-Object { $_.StartsWith($e.path) })
          if (-not $hits) { [void]$missing.Add("sound_prefix:$($e.path) ($note)"); continue }
          foreach ($k in $hits) {
            $h = $idxMap[$k]; $obj = Join-Path $Mc.ObjectsDir ($h.Substring(0, 2) + '\' + $h)
            if (-not (Test-Path -LiteralPath $obj)) { [void]$missing.Add("sound-object:$k"); continue }
            # Asset-index font providers replace empty jar stubs.
            if ($k.StartsWith('minecraft/font/')) { [void]$seen.Remove($k.ToLowerInvariant()) }
            Save-Stream $k ([scriptblock]::Create('[IO.File]::OpenRead($obj)').GetNewClosure()) $k
          }
        }
        default { [void]$missing.Add("unknown-kind:$($e.kind) $($e.path)") }
      }
    }
  } finally { if ($zip) { $zip.Dispose() } }
  return [pscustomobject]@{ Written = $script:AssetsCounter; Missing = @($missing); Requested = $entries.Count }
}

# ----------------------------------------------------------------- UE4SS enable files
function Edit-ModsTxt {
  # Add/enable/disable/remove "<name> : 1|0". Inserts before the "Built-in keybinds" block so Keybinds stays last.
  param([string]$Path, [string]$Name, [ValidateSet('enable', 'disable', 'remove')][string]$Mode)
  if (-not (Test-Path -LiteralPath $Path)) { Write-Log "mods.txt not found: $Path" 'WARN'; return $false }
  $bytes = [IO.File]::ReadAllBytes($Path)
  $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  $raw = [Text.Encoding]::UTF8.GetString($bytes); if ($bom) { $raw = $raw.TrimStart([char]0xFEFF) }
  $nl = if ($raw -match "`r`n") { "`r`n" } else { "`n" }
  $lines = New-Object System.Collections.ArrayList
  $lines.AddRange(@($raw -split "\r?\n"))
  $pat = '^\s*' + [regex]::Escape($Name) + '\s*:'
  $idx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $pat) { $idx = $i; break } }
  $new = "$Name : " + $(if ($Mode -eq 'enable') { '1' } else { '0' })
  if ($Mode -eq 'remove') { if ($idx -ge 0) { $lines.RemoveAt($idx) } else { return $false } }
  elseif ($idx -ge 0) { if ($lines[$idx] -eq $new) { return $false }; $lines[$idx] = $new }
  elseif ($Mode -eq 'disable') { return $false }
  else {
    $c = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*;\s*Built-in keybinds') { $c = $i; break } }
    if ($c -ge 0) { $j = $c - 1; while ($j -ge 0 -and $lines[$j].Trim() -eq '') { $j-- }; $lines.Insert($j + 1, $new) }
    else { $at = $lines.Count; if ($at -gt 0 -and $lines[$at - 1] -eq '') { $at-- }; $lines.Insert($at, $new) }
  }
  if ($script:Dry) { Write-Log "[dry-run] mods.txt $Mode $Name"; return $true }
  [IO.File]::WriteAllText($Path, ($lines -join $nl), (New-Object Text.UTF8Encoding($bom)))
  Write-Log "mods.txt: $Mode $Name"
  return $true
}

function Edit-ModsJson {
  param([string]$Path, [string]$Name, [ValidateSet('enable', 'disable', 'remove')][string]$Mode)
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $arr = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8))
  $list = New-Object System.Collections.ArrayList
  $found = $false; $changed = $false
  foreach ($o in $arr) {
    if ($o.mod_name -eq $Name) {
      $found = $true
      if ($Mode -eq 'remove') { $changed = $true; continue }
      $want = ($Mode -eq 'enable')
      if ($o.mod_enabled -ne $want) { $o.mod_enabled = $want; $changed = $true }
    }
    [void]$list.Add($o)
  }
  if (-not $found -and $Mode -eq 'enable') { [void]$list.Add([pscustomobject]@{ mod_name = $Name; mod_enabled = $true }); $changed = $true }
  if (-not $changed) { return $false }
  if ($script:Dry) { Write-Log "[dry-run] mods.json $Mode $Name"; return $true }
  [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject @($list) -Depth 5), $script:Utf8NoBom)
  Write-Log "mods.json: $Mode $Name"
  return $true
}

function Set-ModEnabled {
  param([string]$ModsDir, [string]$Name, [ValidateSet('enable', 'disable', 'remove')][string]$Mode)
  [void](Edit-ModsTxt (Join-Path $ModsDir 'mods.txt') $Name $Mode)
  [void](Edit-ModsJson (Join-Path $ModsDir 'mods.json') $Name $Mode)
}

# ----------------------------------------------------------------- manifest
function Find-Manifest {
  param([string]$Game)
  $dep = Get-DependencyInfo $Game
  $cands = @()
  if ($dep.ModsDir) { $cands += (Join-Path $dep.ModsDir 'PalCraft\install-manifest.json') }
  $cands += (Join-Path $Game 'Mods\NativeMods\UE4SS\Mods\PalCraft\install-manifest.json')
  $cands += (Join-Path $Game 'Pal\Binaries\Win64\ue4ss\Mods\PalCraft\install-manifest.json')
  $cands += (Join-Path $Game 'Pal\Binaries\Win64\Mods\PalCraft\install-manifest.json')
  foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { return $c } }
  return $null
}

function Read-Manifest { param([string]$Path) [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json }

function Test-DirWritable {
  param([string]$Dir)
  $d = $Dir
  while ($d -and -not (Test-Path -LiteralPath $d -PathType Container)) { $d = Split-Path -Parent $d }
  if (-not $d) { return $false }
  $t = Join-Path $d ('.palcraft_write_test_' + [guid]::NewGuid().ToString('N'))
  try { [IO.File]::WriteAllText($t, 'x'); Remove-Item -LiteralPath $t -Force; return $true } catch { return $false }
}

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ----------------------------------------------------------------- install
function Resolve-PackList {
  param([string]$Choice)
  switch ($Choice) { 'hud_skins' { @('hud_skins') } 'islands_animals' { @('islands_animals') } default { @('hud_skins', 'islands_animals') } }
}

function Convert-PayloadRel {
  # Payload mirrors the default layout Mods/NativeMods/UE4SS/Mods/...; relocate when UE4SS lives elsewhere.
  param([string]$Rel, $Dep)
  $def = 'Mods/NativeMods/UE4SS/Mods'
  if ($Dep.ModsPrefix -and $Dep.ModsPrefix -ne $def -and $Rel.StartsWith($def + '/', [StringComparison]::OrdinalIgnoreCase)) {
    return $Dep.ModsPrefix + $Rel.Substring($def.Length)
  }
  return $Rel
}

function Copy-PayloadPack {
  param([string]$Game, $Dep, [string]$PayloadDir, [string]$Pack, [bool]$Required)
  $root = Join-Path $PayloadDir $Pack
  if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    if ($Required) { throw "Payload folder missing: $root" }
    Write-Log "payload pack '$Pack' not present at $root (skipped)" 'WARN'; return 0
  }
  $n = 0
  foreach ($f in (Get-ChildItem -LiteralPath $root -Recurse -File)) {
    $rel = Convert-PayloadRel (Get-RelPath $root $f.FullName) $Dep
    # Enable only after extraction and checked legacy migration have succeeded.
    if ($rel -match '(^|/)PalCraft/enabled\.txt$') { continue }
    $dst = Resolve-UnderRoot $Game $rel
    Copy-Tracked $f.FullName $dst "pack:$Pack"
    $n++
  }
  Write-Log "payload '$Pack': $n files"
  return $n
}

function Remove-ManifestFiles {
  # Inventory and quarantine explicit owned files; never recursively delete a tree.
  param([string]$Game, $Manifest, [bool]$RemoveSaves)
  $pc = Resolve-UnderRoot $Game $Manifest.palcraft_dir
  if ((Split-Path -Leaf $pc) -ne 'PalCraft') { throw 'Invalid PalCraft manifest root' }
  $pcRel = (Get-RelPath $Game $pc).TrimEnd('/')
  $modsRel = $pcRel.Substring(0, $pcRel.LastIndexOf('/'))
  $paths = @{}
  $checkedPaths = @{}
  function Add-RemovalPath([string]$Full) {
    $rel = Get-RelPath $Game $Full
    if ($paths.ContainsKey($rel.ToLowerInvariant())) { return }
    $owned = $rel.StartsWith($pcRel + '/', [StringComparison]::OrdinalIgnoreCase) -or
      $rel.StartsWith('Pal/Content/Paks/~mods/PalCraft/', [StringComparison]::OrdinalIgnoreCase) -or
      ($rel -match ('^' + [regex]::Escape($modsRel) + '/PalSchema/mods/PalCraft_[^/]+/'))
    if (-not $owned) { throw "Refusing uninstall outside PalCraft-owned paths: $rel" }
    $walk = $Full
    while ((Get-FullPath $walk).Length -gt (Get-FullPath $Game).Length) {
      if ($checkedPaths.ContainsKey($walk)) { break }
      if ((Test-Path -LiteralPath $walk) -and ((Get-Item -LiteralPath $walk -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Refusing uninstall reparse point: $walk"
      }
      $checkedPaths[$walk] = $true
      $walk = Split-Path -Parent $walk
    }
    if (Test-Path -LiteralPath $Full -PathType Leaf) { $paths[$rel.ToLowerInvariant()] = $Full }
  }
  foreach ($f in @($Manifest.files)) {
    Add-RemovalPath (Resolve-UnderRoot $Game $f.path)
  }
  # The texture/font builder and runtime data cache also create untracked files.
  $generated = @('assets', 'cache')
  if ($RemoveSaves) { $generated += 'saves' }
  foreach ($name in $generated) {
    $dir = Join-Path $pc $name
    Add-RemovalPath $dir # validate ancestors before enumeration
    if (Test-Path -LiteralPath $dir -PathType Container) {
      foreach ($entry in @(Get-ChildItem -LiteralPath $dir -Recurse -Force)) {
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing uninstall reparse point: $($entry.FullName)" }
        if (-not $entry.PSIsContainer) { Add-RemovalPath $entry.FullName }
      }
    }
  }
  Add-RemovalPath (Join-Path $pc 'install-manifest.json')
  Add-RemovalPath (Join-Path $pc 'lifecycle-breadcrumbs.txt')
  $rows = @($paths.Values | Sort-Object | ForEach-Object {
    [ordered]@{ path = (Get-RelPath $Game $_); sha256 = (Get-Sha256 $_); bytes = (Get-Item -LiteralPath $_).Length }
  })
  $archive = Join-Path $Game ('PalCraft-uninstall-backup/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fffffff'))
  if ($script:Dry) { foreach ($row in $rows) { Write-Log "[dry-run] quarantine $($row.path)" } }
  elseif ($rows.Count) {
    New-Item -ItemType Directory -Path $archive -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $archive 'inventory.json'), (ConvertTo-Json -InputObject $rows -Depth 5), $script:Utf8NoBom)
    Write-Log "Uninstall inventory: $(Join-Path $archive 'inventory.json') ($($rows.Count) files)"
    foreach ($row in $rows) {
      $src = Resolve-UnderRoot $Game $row.path
      $dst = Resolve-UnderRoot $archive ('files/' + $row.path)
      if ((Get-Sha256 $src) -ne $row.sha256) { throw "Uninstall source changed: $src" }
      New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
      Move-Item -LiteralPath $src -Destination $dst
    }
  }
  # Only empty directories are removed; user skins and sidecars remain.
  $emptyDirs = @()
  foreach ($name in $generated) {
    $dir = Join-Path $pc $name
    if (Test-Path -LiteralPath $dir -PathType Container) {
      $emptyDirs += @(Get-ChildItem -LiteralPath $dir -Directory -Recurse -Force | ForEach-Object { $_.FullName })
      $emptyDirs += $dir
    }
  }
  foreach ($d in @($Manifest.dirs_created | Sort-Object { $_.Length } -Descending)) {
    $full = Resolve-UnderRoot $Game $d
    $rel = Get-RelPath $Game $full
    if ($rel -eq $pcRel -or $rel.StartsWith($pcRel + '/', [StringComparison]::OrdinalIgnoreCase) -or
        $rel -eq 'Pal/Content/Paks/~mods/PalCraft' -or $rel.StartsWith('Pal/Content/Paks/~mods/PalCraft/', [StringComparison]::OrdinalIgnoreCase) -or
        $rel -match ('^' + [regex]::Escape($modsRel) + '/PalSchema/mods/PalCraft_[^/]+(/|$)')) {
      $emptyDirs += $full
    }
  }
  foreach ($full in @($emptyDirs | Sort-Object Length -Descending -Unique)) {
    if ((Test-Path -LiteralPath $full -PathType Container) -and @(Get-ChildItem -LiteralPath $full -Force).Count -eq 0) {
      if ($script:Dry) { Write-Log "[dry-run] remove empty dir $full" } else { Remove-Item -LiteralPath $full -Force }
    }
  }
  return $rows.Count
}

function Invoke-Uninstall {
  param([string]$Game, [bool]$RemoveSaves)
  $mp = Find-Manifest $Game
  if (-not $mp) { throw (T 'no_manifest') }
  Write-Log "UNINSTALL game=$Game manifest=$mp removeSaves=$RemoveSaves dry=$($script:Dry)"
  $m = Read-Manifest $mp
  $modsDir = Split-Path -Parent (Split-Path -Parent $mp)
  $removed = Remove-ManifestFiles $Game $m $RemoveSaves
  if (-not $script:Dry -and (Test-Path -LiteralPath $mp)) { Remove-Item -LiteralPath $mp -Force }
  Set-ModEnabled $modsDir 'PalCraft' 'remove'
  # PalCraft folder itself: only if now empty (saves / user files keep it alive)
  $pc = Resolve-UnderRoot $Game $m.palcraft_dir
  if ((Test-Path -LiteralPath $pc -PathType Container) -and @(Get-ChildItem -LiteralPath $pc -Force).Count -eq 0 -and -not $script:Dry) { Remove-Item -LiteralPath $pc -Force }
  Write-Log "UNINSTALL done: $removed files removed; legacy mod (if migrated) stays disabled"
  return $removed
}

function Invoke-Install {
  param(
    [string]$Game, [string]$Choice, [bool]$WithMapArt, $Mc, $Dep,
    [string]$PayloadDir, [string]$ListPath
  )
  $buildManifest = Join-Path (Split-Path -Parent $PayloadDir) 'manifest.json'
  if (Test-Path -LiteralPath $buildManifest -PathType Leaf) {
    $buildInfo = [IO.File]::ReadAllText($buildManifest, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($buildInfo.status -ne 'READY') {
      if (-not ($CandidateTest -and $Silent -and $buildInfo.status -eq 'CANDIDATE')) { throw 'This is an incomplete review candidate. Build a READY release before installation.' }
      Write-Log 'CANDIDATE TEST ONLY: native release gates remain unverified; this does not authorize distribution.' 'WARN'
    }
  }
  Write-Log "INSTALL v$($script:InstallerVersion) game=$Game packs=$Choice mapArt=$WithMapArt mc=$($Mc.Version) dry=$($script:Dry)"
  $pcRel = $Dep.ModsPrefix + '/PalCraft'
  $pc = Resolve-UnderRoot $Game $pcRel
  if (-not (Test-DirWritable $pc)) { throw 'NOT_WRITABLE' }
  $packs = Resolve-PackList $Choice
  $mapOn = ($WithMapArt -and ($packs -contains 'islands_animals'))

  # replace an earlier install cleanly (also handles switching packs); saves are never touched here
  $old = Find-Manifest $Game
  if ($old) {
    Write-Log "previous install found; removing its files first"
    $om = Read-Manifest $old
    [void](Remove-ManifestFiles $Game $om $false)
  }

  New-State
  $script:St.Game = (Get-FullPath $Game)
  $assetResult = $null
  $ok = $false
  try {
    Set-Progress 5 'core'
    [void](Copy-PayloadPack $Game $Dep $PayloadDir 'core' $true)
    $i = 0
    foreach ($p in $packs) { $i++; Set-Progress (10 + 10 * $i) $p; [void](Copy-PayloadPack $Game $Dep $PayloadDir $p $false) }
    if ($mapOn) { Set-Progress 30 'map_art'; [void](Copy-PayloadPack $Game $Dep $PayloadDir 'map_art' $false) }

    Set-Progress 40 'assets'
    $assetsRoot = Join-Path $pc 'assets'
    $assetResult = Export-McAssets $Mc $packs $assetsRoot $ListPath
    Write-Log "assets: $($assetResult.Written) written, $($assetResult.Missing.Count) missing of $($assetResult.Requested) entries"
    foreach ($m in $assetResult.Missing) { Write-Log "missing asset: $m" 'WARN' }
    if ($assetResult.Missing.Count -gt 0) {
      Write-TextTracked (Join-Path $pc 'missing-assets.txt') ("These Minecraft files were not found in your install (" + $Mc.Version + "):`r`n" + ($assetResult.Missing -join "`r`n") + "`r`n") 'report'
    }

    Set-Progress 82 'assets'
    $cacheBuilder=Join-Path (Split-Path -Parent $script:ScriptDir) 'asset-runtime/Build-TextureCache.ps1'
    if (-not (Test-Path -LiteralPath $cacheBuilder -PathType Leaf)) { throw 'Minecraft texture/font cache builder missing from release' }
    if ($script:Dry) { Write-Log '[dry-run] generate local Minecraft texture/font cache' }
    else { & $cacheBuilder -AssetsRoot (Join-Path $assetsRoot 'minecraft') | ForEach-Object { Write-Log ([string]$_) } }

    $patcher=Join-Path (Split-Path -Parent $script:ScriptDir) 'asset-runtime/Patch-CookedPaks.ps1'
    if (-not (Test-Path -LiteralPath $patcher -PathType Leaf)) { throw 'Cooked texture/font patcher missing from release' }
    $ownedPaks=Resolve-UnderRoot $Game 'Pal/Content/Paks/~mods/PalCraft'
    if ($script:Dry) { Write-Log '[dry-run] patch cooked texture/font payloads and recompute pak entry/index hashes' }
    elseif ($SkipCookedPatch) { Write-Log 'Cooked patch skipped: diagnostic blank-assets fallback active' 'WARN' }
    else {
      try {
        & $patcher -PaksRoot $ownedPaks -AssetsRoot (Join-Path $assetsRoot 'minecraft') | ForEach-Object { Write-Log ([string]$_) }
      } finally {
        # Track committed pak hashes even if a later pak fails validation.
        foreach ($f in @(Get-ChildItem -LiteralPath $ownedPaks -Filter '*.pak' -File)) {
          Add-Record $f.FullName 'cooked-pak' (Get-Sha256 $f.FullName)
        }
      }
      $patchReceipt=Join-Path $assetsRoot 'minecraft/_palcraft/cooked-patch-receipt.json'
      Add-Record $patchReceipt 'asset' (Get-Sha256 $patchReceipt)
      $patched=[IO.File]::ReadAllText($patchReceipt,[Text.Encoding]::UTF8) | ConvertFrom-Json
      if (-not $patched.complete) { Write-Log 'Some cooked assets remain blank; see the cooked patch receipt.' 'WARN' }
    }

    $dataInitializer=Join-Path $script:ScriptDir 'Initialize-LocalData.ps1'
    if ($script:Dry) { Write-Log '[dry-run] initialize version/hash-bound local data cache' }
    else {
      $dataSource=& $dataInitializer -ModRoot $pc -JarPath $Mc.JarPath -MinecraftVersion $Mc.Version -IndexPath $Mc.IndexPath
      Add-Record (Join-Path $assetsRoot 'minecraft/_palcraft/source.json') 'asset' (Get-Sha256 (Join-Path $assetsRoot 'minecraft/_palcraft/source.json'))
      Add-Record (Join-Path $assetsRoot 'minecraft/_palcraft/source-data.json') 'asset' (Get-Sha256 (Join-Path $assetsRoot 'minecraft/_palcraft/source-data.json'))
    }

    Set-Progress 85 'config'
    $cfg = @(
      ('; written by PalCraft-Installer ' + $script:InstallerVersion),
      ('packs = ' + ($packs -join ',')),
      ('map_art = ' + $(if ($mapOn) { '1' } else { '0' })),
      ('mc_version = ' + $Mc.Version),
      ('mc_jar_sha256 = ' + $(if ($dataSource) { $dataSource.jar_sha256 } else { 'dry-run' })),
      ('installed_at = ' + (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz'))
    ) -join "`r`n"
    Write-TextTracked (Join-Path $pc 'config.ini') ($cfg + "`r`n") 'config'
    [void](Invoke-Migration $Game $Dep)
    Write-TextTracked (Join-Path $pc 'enabled.txt') '' 'config'
    Set-ModEnabled $Dep.ModsDir 'PalCraft' 'enable'
    $ok = $true
  } finally {
    # always write the manifest (even after a failure) so a partial install can be uninstalled
    $manifest = [ordered]@{
      schema = 1; installer_version = $script:InstallerVersion
      installed_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
      game_dir = $script:St.Game; palcraft_dir = $pcRel
      mc_version = $Mc.Version; packs = $packs; map_art = $mapOn; complete = $ok
      missing_assets = @($(if ($assetResult) { $assetResult.Missing } else { @() }))
      dirs_created = @($script:St.Dirs)
      files = @($script:St.Files.Values)
    }
    $mpath = Join-Path $pc 'install-manifest.json'
    if ($script:Dry) { Write-Log "[dry-run] manifest would list $($script:St.Files.Count) files" }
    else {
      Ensure-Dir $pc
      [IO.File]::WriteAllText($mpath, (ConvertTo-Json -InputObject $manifest -Depth 6), $script:Utf8NoBom)
      Write-Log "manifest written: $mpath ($($script:St.Files.Count) files)"
    }
  }
  Set-Progress 100 'done'
  return [pscustomobject]@{ Files = $script:St.Files.Count; AssetsWritten = $assetResult.Written; Missing = $assetResult.Missing; ManifestPath = $mpath; Packs = $packs; MapArt = $mapOn }
}

# ----------------------------------------------------------------- legacy migration
function Get-LegacyDir {
  param($Dep)
  if (-not $Dep.ModsDir) { return $null }
  $d = Join-Path $Dep.ModsDir 'MinecraftBlocks'
  if (Test-Path -LiteralPath $d -PathType Container) { return $d }
  return $null
}

function Invoke-Migration {
  # Sidecars live directly under the mod root. Preserve legacy data and stop on conflicts.
  # Sidecars remain copied; approved legacy loaders/paks/schema are quarantined.
  param([string]$Game, $Dep)
  $legacy = Get-LegacyDir $Dep
  if (-not $legacy) { $legacy=Join-Path $Dep.ModsDir 'MinecraftBlocks' }
  $pc = Join-Path $Dep.ModsDir 'PalCraft'
  $target = $pc
  Write-Log "MIGRATE legacy=$legacy -> $target dry=$($script:Dry)"
  $script_ = Join-Path $script:ScriptDir 'migrate-legacy.ps1'
  $res = @(& $script_ -LegacyDir $legacy -TargetDir $target -GameRoot $Game -WhatIf:$script:Dry)
  foreach ($r in $res) { Write-Log "  save $($r.Name): $($r.Status) $($r.Error)" }
  $bad = @($res | Where-Object { $_.Status -in @('failed', 'conflict') })
  if ($bad.Count -gt 0) { throw "Migration failed for $($bad.Count) file(s); legacy mod left enabled and untouched." }

  # success: disable legacy mod (original folder and files stay)
  Set-ModEnabled $Dep.ModsDir 'MinecraftBlocks' 'disable'
  $renamed = @($res | Where-Object { $_.Status -eq 'quarantined' -and $_.Name -like '*MinecraftBlocks*enabled.txt' }).Count -gt 0
  $mp = Find-Manifest $Game
  if ($mp -and -not $script:Dry) {
    $m = Read-Manifest $mp
    $leg = [ordered]@{ migrated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz'); legacy_dir = $legacy; saves_copied = @($res | ForEach-Object { $_.Name }); enabled_txt_renamed = $renamed }
    $m | Add-Member -NotePropertyName legacy -NotePropertyValue $leg -Force
    [IO.File]::WriteAllText($mp, (ConvertTo-Json -InputObject $m -Depth 6), $script:Utf8NoBom)
  }
  Write-Log "MIGRATE done: $($res.Count) save files"
  return $res
}

# ----------------------------------------------------------------- GUI helpers (script-level so event handlers can reach them)
function Sync-MapArt { $u = $script:Ui; $u.CMap.Enabled = ($u.RAll.Checked -or $u.RIsl.Checked) }

function Select-GuiFolder {
  param($TextBox)
  $d = New-Object Windows.Forms.FolderBrowserDialog
  if ($d.ShowDialog() -eq 'OK') { $TextBox.Text = $d.SelectedPath; Update-GuiState }
}

function Update-GuiState {
  $u = $script:Ui
  $g = $u.Game.Text.Trim(); $u.LinkUe.Visible = $false; $u.LinkPs.Visible = $false
  $u.G = $null; $u.Dep = $null; $u.Mc_ = $null
  $ready = $true
  if (-not $g) { $u.GameStatus.Text = T 'game_notfound'; $ready = $false }
  elseif (-not (Test-PalworldDir $g)) { $u.GameStatus.Text = T 'game_invalid'; $ready = $false }
  else {
    $u.G = $g; $u.GameStatus.Text = T 'game_found'
    $dep = Get-DependencyInfo $g; $u.Dep = $dep
    if ($dep.Ue4ssOk -and $dep.PalSchemaOk) { $u.DepStatus.Text = T 'deps_ok' }
    else {
      $t = @()
      if (-not $dep.Ue4ssOk) { $t += (T 'deps_missing_ue4ss'); $u.LinkUe.Visible = $true }
      if (-not $dep.PalSchemaOk) { $t += (T 'deps_missing_palschema'); $u.LinkPs.Visible = $true }
      $u.DepStatus.Text = ($t -join ' ') + "`r`n" + (T 'deps_stop')
      $ready = $false
    }
  }
  $mcDir = $u.Mc.Text.Trim()
  $mc = if ($mcDir) { Find-MinecraftInstall @($mcDir) } else { Find-MinecraftInstall }
  if ($mc) {
    $u.Mc_ = $mc; $u.McStatus.Text = T 'mc_found' @($mc.Version, $mc.Root)
    if (-not $mc.IndexOk) { $u.McStatus.Text += "`r`n" + (T 'mc_noindex' @($mc.Version)) }
  } else { $u.McStatus.Text = T 'mc_notfound'; $ready = $false }
  $u.BtnInstall.Enabled = $ready
  $hasInst = [bool]($u.G -and (Find-Manifest $u.G))
  $u.BtnUninstall.Enabled = $hasInst
  $leg = [bool]($u.Dep -and $u.Dep.ModsDir -and (Get-LegacyDir $u.Dep))
  $u.BtnMigrate.Visible = $leg
  $u.BtnMigrate.Enabled = $leg -and $hasInst
  Sync-MapArt
}

function Invoke-GuiWork {
  param([scriptblock]$Work)
  $u = $script:Ui
  $script:Dry = [bool]$u.Dry.Checked
  foreach ($c in $u.BtnInstall, $u.BtnUninstall, $u.BtnMigrate) { $c.Enabled = $false }
  $u.Progress.Value = 0
  try { & $Work }
  catch {
    Write-Log "ERROR: $($_.Exception.Message)" 'ERROR'
    if ($_.Exception.Message -eq 'NOT_WRITABLE') {
      if (Test-IsAdmin) { [void][Windows.Forms.MessageBox]::Show((T 'need_admin_stop'), (T 'title')) }
      elseif ([Windows.Forms.MessageBox]::Show((T 'need_admin'), (T 'title'), 'YesNo') -eq 'Yes') {
        $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'), '-GameDir', ('"' + $u.G + '"'))
        Start-Process powershell.exe -ArgumentList $a -Verb RunAs; $u.Form.Close()
      }
    } else { [void][Windows.Forms.MessageBox]::Show((T 'error' @($_.Exception.Message, $script:LogFile)), (T 'title'), 'OK', 'Error') }
  }
  Update-GuiState
}

function Start-GuiInstall {
  Invoke-GuiWork {
    $u = $script:Ui
    $choice = if ($u.RHud.Checked) { 'hud_skins' } elseif ($u.RIsl.Checked) { 'islands_animals' } else { 'all' }
    $r = Invoke-Install $u.G $choice ([bool]$u.CMap.Checked) $u.Mc_ $u.Dep $PayloadDir $RequiredList
    if ($script:Dry) { [void][Windows.Forms.MessageBox]::Show((T 'done_preview' @($script:LogFile)), (T 'title')) }
    else {
      [void][Windows.Forms.MessageBox]::Show((T 'done_install' @($r.Missing.Count, $script:LogFile)), (T 'title'))
      if (Get-LegacyDir $u.Dep) {
        if ([Windows.Forms.MessageBox]::Show((T 'ask_migrate'), (T 'title'), 'YesNo') -eq 'Yes') {
          [void](Invoke-Migration $u.G $u.Dep); [void][Windows.Forms.MessageBox]::Show((T 'done_migrate'), (T 'title'))
        }
      }
    }
  }
}

function Start-GuiUninstall {
  if ([Windows.Forms.MessageBox]::Show((T 'confirm_uninstall'), (T 'title'), 'YesNo') -ne 'Yes') { return }
  Invoke-GuiWork {
    $u = $script:Ui
    $rs = [bool]$u.Saves.Checked
    [void](Invoke-Uninstall $u.G $rs)
    $sv = if ($rs) { T 'saves_removed' } else { T 'saves_kept' }
    [void][Windows.Forms.MessageBox]::Show((T 'done_uninstall' @($sv)), (T 'title'))
  }
}

function Start-GuiMigrate {
  Invoke-GuiWork {
    $u = $script:Ui
    [void](Invoke-Migration $u.G $u.Dep); [void][Windows.Forms.MessageBox]::Show((T 'done_migrate'), (T 'title'))
  }
}

# ----------------------------------------------------------------- GUI
function New-MainForm {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  try { [Windows.Forms.Application]::EnableVisualStyles() } catch { }
  $fontName = if ($script:Lang -eq 'ko') { 'Malgun Gothic' } else { 'Segoe UI' }
  $font = New-Object Drawing.Font($fontName, 9)
  $f = New-Object Windows.Forms.Form
  $f.Text = T 'title'; $f.Font = $font; $f.StartPosition = 'CenterScreen'
  $f.ClientSize = New-Object Drawing.Size(740, 700); $f.MinimumSize = New-Object Drawing.Size(640, 620)
  $u = @{}; $script:Ui = $u; $u.Form = $f
  $script:GuiGame = $null; $script:GuiDep = $null; $script:GuiMc = $null

  function Add-Ctl($c, $x, $y, $w, $h, $anchor) {
    $c.Location = New-Object Drawing.Point($x, $y); $c.Size = New-Object Drawing.Size($w, $h)
    if ($anchor) { $c.Anchor = $anchor }
    $f.Controls.Add($c); return $c
  }
  $AW = [Windows.Forms.AnchorStyles]
  $topLR = $AW::Top -bor $AW::Left -bor $AW::Right

  $l = New-Object Windows.Forms.Label; $l.Text = T 'intro'
  [void](Add-Ctl $l 12 10 716 52 $topLR)

  $l = New-Object Windows.Forms.Label; $l.Text = T 'game_path'
  [void](Add-Ctl $l 12 70 300 20 $null)
  $u.Game = New-Object Windows.Forms.TextBox; [void](Add-Ctl $u.Game 12 92 610 24 $topLR)
  $u.GameBrowse = New-Object Windows.Forms.Button; $u.GameBrowse.Text = T 'browse'
  [void](Add-Ctl $u.GameBrowse 630 90 98 27 ($AW::Top -bor $AW::Right))
  $u.GameStatus = New-Object Windows.Forms.Label; [void](Add-Ctl $u.GameStatus 12 120 716 20 $topLR)

  $u.DepStatus = New-Object Windows.Forms.Label; [void](Add-Ctl $u.DepStatus 12 144 716 36 $topLR)
  $u.LinkUe = New-Object Windows.Forms.LinkLabel; $u.LinkUe.Text = T 'link_ue4ss'; $u.LinkUe.Visible = $false
  [void](Add-Ctl $u.LinkUe 12 180 200 20 $null)
  $u.LinkPs = New-Object Windows.Forms.LinkLabel; $u.LinkPs.Text = T 'link_palschema'; $u.LinkPs.Visible = $false
  [void](Add-Ctl $u.LinkPs 220 180 200 20 $null)

  $l = New-Object Windows.Forms.Label; $l.Text = T 'mc_path'
  [void](Add-Ctl $l 12 208 300 20 $null)
  $u.Mc = New-Object Windows.Forms.TextBox; [void](Add-Ctl $u.Mc 12 230 610 24 $topLR)
  $u.McBrowse = New-Object Windows.Forms.Button; $u.McBrowse.Text = T 'browse'
  [void](Add-Ctl $u.McBrowse 630 228 98 27 ($AW::Top -bor $AW::Right))
  $u.McStatus = New-Object Windows.Forms.Label; [void](Add-Ctl $u.McStatus 12 258 716 50 $topLR)

  $g = New-Object Windows.Forms.GroupBox; $g.Text = T 'packs_title'
  [void](Add-Ctl $g 12 312 716 128 $topLR)
  $u.RAll = New-Object Windows.Forms.RadioButton; $u.RAll.Text = T 'pack_all'; $u.RAll.Checked = $true
  $u.RHud = New-Object Windows.Forms.RadioButton; $u.RHud.Text = T 'pack_hud'
  $u.RIsl = New-Object Windows.Forms.RadioButton; $u.RIsl.Text = T 'pack_islands'
  $u.CMap = New-Object Windows.Forms.CheckBox; $u.CMap.Text = T 'map_art'; $u.CMap.Checked = $true
  $y = 22
  foreach ($c in $u.RAll, $u.RHud, $u.RIsl) { $c.Location = New-Object Drawing.Point(14, $y); $c.Size = New-Object Drawing.Size(680, 22); $g.Controls.Add($c); $y += 24 }
  $u.CMap.Location = New-Object Drawing.Point(34, $y); $u.CMap.Size = New-Object Drawing.Size(660, 22); $g.Controls.Add($u.CMap)
  $u.RAll.add_CheckedChanged({ Sync-MapArt }); $u.RHud.add_CheckedChanged({ Sync-MapArt }); $u.RIsl.add_CheckedChanged({ Sync-MapArt })

  $u.Dry = New-Object Windows.Forms.CheckBox; $u.Dry.Text = T 'dry_run'; $u.Dry.Checked = $script:Dry
  [void](Add-Ctl $u.Dry 14 448 700 22 $topLR)
  $u.Saves = New-Object Windows.Forms.CheckBox; $u.Saves.Text = T 'remove_saves'
  [void](Add-Ctl $u.Saves 14 472 700 22 $topLR)

  $u.BtnInstall = New-Object Windows.Forms.Button; $u.BtnInstall.Text = T 'install'
  [void](Add-Ctl $u.BtnInstall 12 502 130 32 $null)
  $u.BtnUninstall = New-Object Windows.Forms.Button; $u.BtnUninstall.Text = T 'uninstall'
  [void](Add-Ctl $u.BtnUninstall 150 502 130 32 $null)
  $u.BtnMigrate = New-Object Windows.Forms.Button; $u.BtnMigrate.Text = T 'migrate'; $u.BtnMigrate.Visible = $false
  [void](Add-Ctl $u.BtnMigrate 288 502 210 32 $null)
  $u.BtnClose = New-Object Windows.Forms.Button; $u.BtnClose.Text = T 'close'
  [void](Add-Ctl $u.BtnClose 598 502 130 32 ($AW::Top -bor $AW::Right))
  $u.BtnClose.add_Click({ $script:Ui.Form.Close() })

  $u.Progress = New-Object Windows.Forms.ProgressBar; [void](Add-Ctl $u.Progress 12 542 716 14 $topLR)
  $u.Log = New-Object Windows.Forms.TextBox; $u.Log.Multiline = $true; $u.Log.ReadOnly = $true; $u.Log.ScrollBars = 'Vertical'
  $u.Log.Font = New-Object Drawing.Font('Consolas', 8.5)
  [void](Add-Ctl $u.Log 12 562 716 128 ($AW::Top -bor $AW::Left -bor $AW::Right -bor $AW::Bottom))

  $script:UiLog = { param($line) $script:Ui.Log.AppendText($line + "`r`n"); [Windows.Forms.Application]::DoEvents() }
  $script:UiProgress = { param($pct, $text) $script:Ui.Progress.Value = [Math]::Max(0, [Math]::Min(100, $pct)); [Windows.Forms.Application]::DoEvents() }

  $u.LinkUe.add_LinkClicked({ Start-Process 'https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest' })
  $u.LinkPs.add_LinkClicked({ Start-Process 'https://github.com/Okaetsu/PalSchema/releases' })
  $u.GameBrowse.add_Click({ Select-GuiFolder $script:Ui.Game })
  $u.McBrowse.add_Click({ Select-GuiFolder $script:Ui.Mc })
  $u.Game.add_Leave({ Update-GuiState }); $u.Mc.add_Leave({ Update-GuiState })
  $u.BtnInstall.add_Click({ Start-GuiInstall })
  $u.BtnUninstall.add_Click({ Start-GuiUninstall })
  $u.BtnMigrate.add_Click({ Start-GuiMigrate })

  # initial detection
  if ($GameDir) { $u.Game.Text = $GameDir }
  else { $found = @(Find-Palworld); if ($found.Count -gt 0) { $u.Game.Text = $found[0] } }
  if ($MinecraftDir) { $u.Mc.Text = $MinecraftDir }
  Update-GuiState
  Write-Log (T 'ready')
  return $f
}

# ----------------------------------------------------------------- main
if ($LibraryOnly) { return }

Write-Log "---- PalCraft installer v$($script:InstallerVersion) started (lang=$($script:Lang), dry=$($script:Dry), silent=$([bool]$Silent)) ----"

function Exit-WithError { param([string]$Msg, [int]$Code) Write-Log $Msg 'ERROR'; [Console]::Error.WriteLine($Msg); exit $Code }

if ($Silent -or $Uninstall -or $Migrate) {
  $game = $GameDir
  if (-not $game) { $f = @(Find-Palworld); if ($f.Count) { $game = $f[0] } }
  if (-not (Test-PalworldDir $game)) { Exit-WithError 'Palworld folder not found (use -GameDir).' 1 }
  try {
    if ($Uninstall) { [void](Invoke-Uninstall $game ([bool]$RemoveSaves)); exit 0 }
    $dep = Get-DependencyInfo $game
    if ($Migrate) { [void](Invoke-Migration $game $dep); exit 0 }
    if (-not ($dep.Ue4ssOk -and $dep.PalSchemaOk)) { Exit-WithError "Missing dependency: UE4SS ok=$($dep.Ue4ssOk), PalSchema ok=$($dep.PalSchemaOk). Install them first." 2 }
    $mc = if ($MinecraftDir) { Find-MinecraftInstall @($MinecraftDir) } else { Find-MinecraftInstall }
    if (-not $mc) { Exit-WithError 'No installed Minecraft Java 1.21.11 found (own it and launch 1.21.11 once).' 3 }
    $r = Invoke-Install $game $PackChoice ([bool]$MapArt) $mc $dep $PayloadDir $RequiredList
    Write-Log "Done: $($r.Files) files, $($r.Missing.Count) missing Minecraft files."
    exit 0
  } catch {
    if ($_.Exception.Message -eq 'NOT_WRITABLE') { Exit-WithError 'Game folder is not writable; run as administrator.' 4 }
    Exit-WithError $_.Exception.Message 1
  }
}

# GUI
try {
  Add-Type -Namespace PalCraft -Name Win -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
  [void][PalCraft.Win]::ShowWindow([PalCraft.Win]::GetConsoleWindow(), 0)   # hide the console behind the GUI
} catch { }
$script:Quiet = $true
$form = New-MainForm
[void]$form.ShowDialog()
