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

$script:InstallerVersion = '1.1-CANDIDATE'
$script:SteamAppId = '1623730'
$script:SupportedMcVersions = @('1.21.11')   # versions whose data bindings passed equivalence (Initialize-LocalData enforces it)
$script:MinPalSchema = [version]'0.6.71'
$script:BaselineUe4ss = '2281fa31'
$script:Ue4ssUrl = 'https://github.com/Okaetsu/RE-UE4SS/releases/tag/experimental-palworld'
$script:PalSchemaUrl = 'https://github.com/Okaetsu/PalSchema/releases'
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
  Copy-FileAtomic $Src $Dst
  Add-Record $Dst $Kind (Get-Sha256 $Dst)
}

function Write-TextTracked {
  param([string]$Path, [string]$Text, [string]$Kind)
  if ($script:Dry) { Write-Log "[dry-run] write $Path ($($Text.Length) chars)"; Add-Record $Path $Kind '(dry-run)'; return }
  Ensure-Dir (Split-Path -Parent $Path)
  Write-TextAtomic $Path $Text
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
  if ($env:PALCRAFT_STEAM_ROOTS) {   # semicolon list; replaces registry/default detection (tests, portable Steam)
    return @($env:PALCRAFT_STEAM_ROOTS -split ';' | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
  }
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
  foreach ($line in [IO.File]::ReadAllLines($Vdf, [Text.Encoding]::UTF8)) {
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
        $m = [regex]::Match([IO.File]::ReadAllText($acf, [Text.Encoding]::UTF8), '"installdir"\s+"([^"]+)"')
        if ($m.Success) { $dir = Join-Path $sa ('common\' + $m.Groups[1].Value) }
      }
      if (-not $dir) { $dir = Join-Path $sa 'common\Palworld' }
      if (Test-PalworldDir $dir) { if ($l.HasApp) { $pref += $dir } else { $other += $dir } }
    }
  }
  @(($pref + $other) | ForEach-Object { $_.TrimEnd('\') } | Select-Object -Unique)
}

function Test-XboxPalworld {
  # Xbox / Microsoft Store (Game Pass) build: GDK layout (WinGDK binaries); UE4SS cannot be installed like on Steam.
  param([string]$Dir)
  if (-not $Dir) { return $false }
  foreach ($m in 'MicrosoftGame.config', 'gamelaunchhelper.exe', 'appxmanifest.xml', 'Pal\Binaries\WinGDK') {
    if (Test-Path -LiteralPath (Join-Path $Dir $m)) { return $true }
  }
  if ($Dir -match '\\(WindowsApps|XboxGames)\\' -and -not (Test-Path -LiteralPath (Join-Path $Dir 'Pal\Binaries\Win64\Palworld-Win64-Shipping.exe'))) { return $true }
  return $false
}

function Get-PalworldProblem {
  # '' when the folder is usable, else the strings.json key that explains why not.
  param([string]$Dir)
  if (-not $Dir) { return $(if (@(Get-SteamRoots).Count) { 'game_notfound' } else { 'game_nosteam' }) }
  if (Test-XboxPalworld $Dir) { return 'game_xbox' }
  if (-not (Test-PalworldDir $Dir)) { return 'game_invalid' }
  return ''
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
  $info.Ue4ssName = $null; $info.Ue4ssVersion = $null; $info.PalSchemaVersion = $null
  if ($info.Ue4ssOk) {
    $ij = Join-Path $info.Ue4ssDir 'Info.json'
    if (Test-Path -LiteralPath $ij -PathType Leaf) {
      try { $o = [IO.File]::ReadAllText($ij, [Text.Encoding]::UTF8) | ConvertFrom-Json; $info.Ue4ssName = [string]$o.ModName; $info.Ue4ssVersion = [string]$o.Version } catch { }
    }
  }
  if ($info.PalSchemaOk) {
    $dll = Join-Path $info.ModsDir 'PalSchema\dlls\main.dll'
    if (Test-Path -LiteralPath $dll -PathType Leaf) {
      try { $info.PalSchemaVersion = [version](Get-Item -LiteralPath $dll).VersionInfo.FileVersion } catch { }
    }
  }
  [pscustomobject]$info
}

function Get-DependencyProblems {
  # Level 'error' blocks installation; 'warn' is shown and logged only. Dep = which download link applies.
  param($Dep)
  $p = New-Object System.Collections.ArrayList
  if (-not $Dep.Ue4ssOk) { [void]$p.Add([pscustomobject]@{ Level = 'error'; Key = 'deps_missing_ue4ss'; Args = @(); Dep = 'ue4ss' }) }
  else {
    if ($Dep.Ue4ssName -and $Dep.Ue4ssName -notmatch 'Palworld') {
      [void]$p.Add([pscustomobject]@{ Level = 'warn'; Key = 'deps_ue4ss_vanilla'; Args = @($Dep.Ue4ssName); Dep = 'ue4ss' })
    } elseif ($Dep.Ue4ssVersion -and $Dep.Ue4ssVersion -ne $script:BaselineUe4ss) {
      [void]$p.Add([pscustomobject]@{ Level = 'warn'; Key = 'deps_ue4ss_version'; Args = @($Dep.Ue4ssVersion, $script:BaselineUe4ss); Dep = 'ue4ss' })
    }
    if (-not $Dep.PalSchemaOk) { [void]$p.Add([pscustomobject]@{ Level = 'error'; Key = 'deps_missing_palschema'; Args = @(); Dep = 'palschema' }) }
    elseif (-not $Dep.PalSchemaVersion) { [void]$p.Add([pscustomobject]@{ Level = 'warn'; Key = 'deps_palschema_unknown'; Args = @(); Dep = 'palschema' }) }
    else {
      $pv = $Dep.PalSchemaVersion   # file versions are 4-part (0.6.71.0); compare major.minor.build only
      $pv3 = New-Object Version($pv.Major, $pv.Minor, [Math]::Max(0, $pv.Build))
      if ($pv3 -lt $script:MinPalSchema) {
        [void]$p.Add([pscustomobject]@{ Level = 'error'; Key = 'deps_palschema_old'; Args = @($pv3.ToString(), $script:MinPalSchema.ToString()); Dep = 'palschema' })
      } elseif ($pv3 -gt $script:MinPalSchema) {
        [void]$p.Add([pscustomobject]@{ Level = 'warn'; Key = 'deps_palschema_newer'; Args = @($pv3.ToString(), $script:MinPalSchema.ToString()); Dep = 'palschema' })
      }
    }
  }
  if (-not $Dep.Ue4ssOk -and -not $Dep.PalSchemaOk) { [void]$p.Add([pscustomobject]@{ Level = 'error'; Key = 'deps_missing_palschema'; Args = @(); Dep = 'palschema' }) }
  return @($p)
}

function Format-DependencyProblem {
  param($P)
  $url = if ($P.Dep -eq 'palschema') { $script:PalSchemaUrl } else { $script:Ue4ssUrl }
  return ((T $P.Key $P.Args) + ' ' + $url)
}


# ----------------------------------------------------------------- Minecraft discovery
function Get-McRoots {
  # Launcher data folders that can hold versions\<v>\<v>.jar + assets\ (official launcher, CurseForge, Modrinth App,
  # Prism/MultiMC-style libraries\com\mojang\minecraft layout, or any folder the user browses to).
  # PALCRAFT_MC_ROOTS (semicolon list) replaces the default locations (tests / unusual setups).
  param([string[]]$Extra)
  $r = @()
  foreach ($e in @($Extra)) {
    if (-not $e) { continue }
    $r += $e
    foreach ($sub in '.minecraft', 'minecraft') { $r += (Join-Path $e $sub) }   # an instance / launcher folder was picked
  }
  if ($env:PALCRAFT_MC_ROOTS) { $r += @($env:PALCRAFT_MC_ROOTS -split ';' | Where-Object { $_ }) }
  else {
    if ($env:APPDATA) {
      $r += (Join-Path $env:APPDATA '.minecraft')
      $r += (Join-Path $env:APPDATA 'PrismLauncher')
      $r += (Join-Path $env:APPDATA 'PolyMC')
      $r += (Join-Path $env:APPDATA 'ModrinthApp\meta')
    }
    if ($env:USERPROFILE) {
      $r += (Join-Path $env:USERPROFILE 'curseforge\minecraft\Install')
      $r += (Join-Path $env:USERPROFILE 'Documents\curseforge\minecraft\Install')
    }
  }
  @($r | Where-Object {
    $_ -and ((Test-Path -LiteralPath (Join-Path $_ 'versions') -PathType Container) -or
             (Test-Path -LiteralPath (Join-Path $_ 'libraries\com\mojang\minecraft') -PathType Container))
  } | ForEach-Object { (Get-FullPath $_) } | Select-Object -Unique)
}

function Get-McVersions {
  # Every plain release (1.N[.M]) found in the roots, with jar/asset-index facts. Modded or snapshot profiles
  # (1.21.11-fabric..., OptiFine, 24w14a, anything with inheritsFrom) are never candidates.
  param([string[]]$ExtraRoots)
  $roots = @(Get-McRoots $ExtraRoots)
  $raw = @()
  foreach ($root in $roots) {
    $vdir = Join-Path $root 'versions'
    if (Test-Path -LiteralPath $vdir -PathType Container) {
      foreach ($d in (Get-ChildItem -LiteralPath $vdir -Directory -ErrorAction SilentlyContinue)) {
        if ($d.Name -notmatch '^\d+\.\d+(\.\d+)?$') { continue }
        $raw += [pscustomobject]@{ Root = $root; Version = $d.Name; Jar = (Join-Path $d.FullName ($d.Name + '.jar')); Json = (Join-Path $d.FullName ($d.Name + '.json')) }
      }
    }
    $lib = Join-Path $root 'libraries\com\mojang\minecraft'
    if (Test-Path -LiteralPath $lib -PathType Container) {
      foreach ($d in (Get-ChildItem -LiteralPath $lib -Directory -ErrorAction SilentlyContinue)) {
        if ($d.Name -notmatch '^\d+\.\d+(\.\d+)?$') { continue }
        $raw += [pscustomobject]@{ Root = $root; Version = $d.Name; Jar = (Join-Path $d.FullName ('minecraft-' + $d.Name + '-client.jar')); Json = (Join-Path $root ('meta\net.minecraft\' + $d.Name + '.json')) }
      }
    }
  }
  $out = @()
  foreach ($c in $raw) {
    $idx = $null
    if (Test-Path -LiteralPath $c.Json -PathType Leaf) {
      try {
        $j = [IO.File]::ReadAllText($c.Json, [Text.Encoding]::UTF8) | ConvertFrom-Json
        if ($j.PSObject.Properties['inheritsFrom'] -and $j.inheritsFrom) { continue }   # modded profile
        if ($j.assetIndex -and $j.assetIndex.id) { $idx = [string]$j.assetIndex.id } elseif ($j.assets) { $idx = [string]$j.assets }
      } catch { Write-Log "bad version json $($c.Json) : $($_.Exception.Message)" 'WARN'; continue }
    }
    $hasJar = Test-Path -LiteralPath $c.Jar -PathType Leaf
    if (-not $hasJar -and -not (Test-Path -LiteralPath $c.Json -PathType Leaf)) { continue }   # leftover empty folder
    $assets = Join-Path $c.Root 'assets'
    $indexPath = if ($idx) { Join-Path $assets "indexes\$idx.json" } else { $null }
    if ($indexPath -and -not (Test-Path -LiteralPath $indexPath)) {   # fall back to other roots' asset stores
      foreach ($o in $roots) {
        $alt = Join-Path $o "assets\indexes\$idx.json"
        if (Test-Path -LiteralPath $alt) { $assets = Join-Path $o 'assets'; $indexPath = $alt; break }
      }
    }
    $out += [pscustomobject]@{
      Root = $c.Root; Version = $c.Version; VersionObj = [version]$c.Version; JarPath = $c.Jar; HasJar = $hasJar
      Supported = ($script:SupportedMcVersions -contains $c.Version)
      AssetIndexId = $idx; IndexPath = $indexPath; IndexOk = [bool]($indexPath -and (Test-Path -LiteralPath $indexPath))
      ObjectsDir = (Join-Path $assets 'objects')
    }
  }
  return $out
}

function Select-McBest {
  param($All)
  $cands = @($All | Where-Object { $_.Supported -and $_.HasJar })
  if (-not $cands) { return $null }
  # prefer versions whose index is present, then newest
  return ($cands | Sort-Object @{ Expression = { $_.IndexOk }; Descending = $true }, @{ Expression = { $_.VersionObj }; Descending = $true } | Select-Object -First 1)
}

function Find-MinecraftInstall {
  # Only vanilla versions whose data bindings have passed equivalence ($script:SupportedMcVersions).
  param([string[]]$ExtraRoots)
  return (Select-McBest @(Get-McVersions $ExtraRoots))
}

function Test-McReady {
  # $null when the install can supply every user-owned file the installer needs; otherwise @{Key; Args}.
  param($Mc)
  if (-not $Mc.IndexOk) { return [pscustomobject]@{ Key = 'mc_noindex'; Args = @($Mc.Version) } }
  $ko = $null
  try {
    $m = [regex]::Match([IO.File]::ReadAllText($Mc.IndexPath, [Text.Encoding]::UTF8), '"minecraft/lang/ko_kr\.json"\s*:\s*\{[^}]*?"hash"\s*:\s*"([0-9a-fA-F]{40})"')
    if ($m.Success) { $ko = $m.Groups[1].Value }
  } catch { }
  if (-not $ko) { return [pscustomobject]@{ Key = 'mc_noindex'; Args = @($Mc.Version) } }
  if (-not (Test-Path -LiteralPath (Join-Path $Mc.ObjectsDir ($ko.Substring(0, 2) + '\' + $ko)) -PathType Leaf)) {
    return [pscustomobject]@{ Key = 'mc_noobjects'; Args = @($Mc.Version) }
  }
  return $null
}

function Get-McDiagnosis {
  # What to tell the user: Status ok|notfound|unsupported|nojar|noindex|noobjects, Message (localized), Mc (when ok).
  param([string[]]$ExtraRoots)
  $all = @(Get-McVersions $ExtraRoots)
  $sup = @($all | Where-Object { $_.Supported })
  $want = ($script:SupportedMcVersions -join ', ')
  if ($sup.Count) {
    $best = Select-McBest $all
    if (-not $best) { return [pscustomobject]@{ Status = 'nojar'; Mc = $null; Message = (T 'mc_nojar' @($sup[0].Version, $sup[0].Root)) } }
    $why = Test-McReady $best
    if ($why) { return [pscustomobject]@{ Status = ($why.Key -replace '^mc_', ''); Mc = $best; Message = (T $why.Key $why.Args) } }
    return [pscustomobject]@{ Status = 'ok'; Mc = $best; Message = (T 'mc_found' @($best.Version, $best.Root)) }
  }
  if ($all.Count) {
    $vs = (@($all | Sort-Object VersionObj -Descending | ForEach-Object { $_.Version } | Select-Object -Unique) -join ', ')
    return [pscustomobject]@{ Status = 'unsupported'; Mc = $null; Message = (T 'mc_unsupported' @($vs, $want)) }
  }
  return [pscustomobject]@{ Status = 'notfound'; Mc = $null; Message = (T 'mc_notfound') }
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
    $tmp = $dst + '.palcraft-tmp'
    try {
      try { $out = [IO.File]::Create($tmp); try { $in.CopyTo($out) } finally { $out.Dispose() } } finally { $in.Dispose() }
      Move-IntoPlace $tmp $dst
    } catch {
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
      throw (Convert-IoError $_.Exception $dst)
    }
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
  Write-UserFileText $Path ($lines -join $nl) (New-Object Text.UTF8Encoding($bom))
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
  Write-UserFileText $Path (ConvertTo-Json -InputObject @($list) -Depth 5) $script:Utf8NoBom
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

# ----------------------------------------------------------------- preflight (robustness)
function New-InstallError {
  # Exception whose Data['ExitCode'] becomes the -Silent process exit code.
  param([int]$Code, [string]$Message)
  $e = New-Object System.Exception($Message)
  $e.Data['ExitCode'] = $Code
  return $e
}

function Convert-IoError {
  # Disk-full IOExceptions become a clear message; everything else passes through unchanged.
  param([Exception]$Ex, [string]$Path)
  $x = $Ex
  while ($x) {
    if (($x -is [IO.IOException]) -and (($x.HResult -band 0xFFFF) -in 112, 39)) { return (New-InstallError 7 (T 'disk_full' @($Path))) }
    if ($x.Message -match 'not enough space on the disk') { return (New-InstallError 7 (T 'disk_full' @($Path))) }
    $x = $x.InnerException
  }
  return $Ex
}

function Copy-FilePrimitive {
  param([string]$Src, [string]$Tmp)
  if (Test-Path -LiteralPath $Tmp) { [IO.File]::SetAttributes($Tmp, [IO.FileAttributes]::Normal) }
  [IO.File]::Copy($Src, $Tmp, $true)
  [IO.File]::SetAttributes($Tmp, [IO.FileAttributes]::Normal)   # a read-only payload must not make the game copy read-only
}

function Move-IntoPlace {
  # Rename a finished temp file over $Dst (read-only or not); the target is never left half-written.
  param([string]$Tmp, [string]$Dst)
  if (Test-Path -LiteralPath $Dst -PathType Leaf) { [IO.File]::SetAttributes($Dst, [IO.FileAttributes]::Normal) }
  Move-Item -LiteralPath $Tmp -Destination $Dst -Force
}

function Copy-FileAtomic {
  param([string]$Src, [string]$Dst)
  $tmp = $Dst + '.palcraft-tmp'
  try {
    Copy-FilePrimitive $Src $tmp
    Move-IntoPlace $tmp $Dst
  } catch {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    throw (Convert-IoError $_.Exception $Dst)
  }
}

function Write-TextAtomic {
  param([string]$Path, [string]$Text)
  $tmp = $Path + '.palcraft-tmp'
  try {
    if (Test-Path -LiteralPath $tmp) { [IO.File]::SetAttributes($tmp, [IO.FileAttributes]::Normal) }
    [IO.File]::WriteAllText($tmp, $Text, $script:Utf8NoBom)
    Move-IntoPlace $tmp $Path
  } catch {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    throw (Convert-IoError $_.Exception $Path)
  }
}

function Write-UserFileText {
  # Rewrite a user-owned file (mods.txt / mods.json) in place, tolerating the read-only attribute.
  param([string]$Path, [string]$Text, $Encoding)
  $attr = [IO.File]::GetAttributes($Path)
  $ro = [bool]($attr -band [IO.FileAttributes]::ReadOnly)
  if ($ro) { [IO.File]::SetAttributes($Path, ($attr -band (-bnot [IO.FileAttributes]::ReadOnly))) }
  try { [IO.File]::WriteAllText($Path, $Text, $Encoding) }
  finally { if ($ro) { [IO.File]::SetAttributes($Path, $attr) } }
}

function Test-LongPathSupport {
  # Windows PowerShell 5.1 only handles paths over 259 characters when the OS "LongPathsEnabled" policy is on; probe it.
  $base = Join-Path ([IO.Path]::GetTempPath()) ('palcraft_lp_' + [guid]::NewGuid().ToString('N'))
  try {
    $p = $base
    while ($p.Length -lt 275) { $p = Join-Path $p ('d' * 50) }
    [void][IO.Directory]::CreateDirectory($p)
    [IO.File]::WriteAllText((Join-Path $p 'probe.txt'), 'x')
    return $true
  } catch { return $false }
  finally { try { if (Test-Path -LiteralPath $base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } } catch { } }
}

function Get-FreeBytes {
  param([string]$Path)
  try {
    $root = [IO.Path]::GetPathRoot((Get-FullPath $Path))
    if (-not $root -or $root.StartsWith('\\')) { return [long]::MaxValue }
    return [long](New-Object IO.DriveInfo($root)).AvailableFreeSpace
  } catch { return [long]::MaxValue }
}

function Assert-InstallPreflight {
  # Everything that can be known before the first byte is written. Throws a localized error (with exit code) or 'NOT_WRITABLE'.
  param([string]$Game, $Dep, $Mc, [string[]]$Packs, [bool]$MapOn, [string]$PayloadDir, [string]$ListPath)
  if (Test-XboxPalworld $Game) { throw (New-InstallError 5 (T 'game_xbox')) }
  $probs = @(Get-DependencyProblems $Dep)
  $errs = @($probs | Where-Object { $_.Level -eq 'error' })
  foreach ($w in @($probs | Where-Object { $_.Level -eq 'warn' })) { Write-Log (Format-DependencyProblem $w) 'WARN' }
  if ($errs.Count) { throw (New-InstallError 2 ((@($errs | ForEach-Object { Format-DependencyProblem $_ }) -join ' '))) }
  $bad = Test-McReady $Mc
  if ($bad) { throw (New-InstallError 3 (T $bad.Key $bad.Args)) }

  $pc = Resolve-UnderRoot $Game ($Dep.ModsPrefix + '/PalCraft')
  $paks = Resolve-UnderRoot $Game 'Pal/Content/Paks/~mods/PalCraft'
  foreach ($d in $pc, $paks) { if (-not (Test-DirWritable $d)) { throw 'NOT_WRITABLE' } }

  # payload size + longest destination path
  $bytes = [long]0; $longest = 0
  $gl = (Get-FullPath $Game).Length + 1
  $want = @('core') + $Packs; if ($MapOn) { $want += 'map_art' }
  foreach ($pk in $want) {
    $root = Join-Path $PayloadDir $pk
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
    foreach ($f in (Get-ChildItem -LiteralPath $root -Recurse -File)) {
      $bytes += $f.Length
      $rel = Convert-PayloadRel (Get-RelPath $root $f.FullName) $Dep
      $longest = [Math]::Max($longest, $gl + $rel.Length + 12)   # + ".palcraft-tmp"
    }
  }
  try {
    foreach ($e in (Get-RequiredAssets $ListPath $Packs)) {
      $extra = if ($e.kind -like '*_prefix') { 60 } else { 0 }
      $longest = [Math]::Max($longest, $pc.Length + 8 + ([string]$e.path).Length + $extra + 13)
    }
  } catch { }
  if ($longest -ge 259 -and -not (Test-LongPathSupport)) { throw (New-InstallError 6 (T 'path_too_long' @($longest))) }

  $need = $bytes + 700MB
  $free = Get-FreeBytes $Game
  if ($free -lt $need) { throw (New-InstallError 7 (T 'disk_low' @([int]($need / 1MB), [int]($free / 1MB)))) }
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
  $plan = @()
  foreach ($f in (Get-ChildItem -LiteralPath $root -Recurse -File)) {
    $rel = Convert-PayloadRel (Get-RelPath $root $f.FullName) $Dep
    # Enable only after extraction and checked legacy migration have succeeded.
    if ($rel -match '(^|/)PalCraft/enabled\.txt$') { continue }
    $plan += [pscustomobject]@{ Src = $f.FullName; Dst = (Resolve-UnderRoot $Game $rel) }
  }
  # Register every file of the pack in the manifest BEFORE copying, so even a killed process can be uninstalled.
  if (-not $script:Dry -and $script:St.Game) {
    foreach ($e in $plan) { Add-Record $e.Dst "pack:$Pack" '(pending)' }
    if ($script:ManifestSaver) { & $script:ManifestSaver }
  }
  foreach ($e in $plan) {
    Copy-Tracked $e.Src $e.Dst "pack:$Pack"
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
  foreach ($own in 'config.ini', 'enabled.txt', 'missing-assets.txt') { Add-RemovalPath (Join-Path $pc $own) }   # written after the last checkpoint
  # Leftovers of an interrupted install: temp files and anything under our own pak folder.
  $ownedPakDir = Join-Path $Game 'Pal/Content/Paks/~mods/PalCraft'
  if (Test-Path -LiteralPath $ownedPakDir -PathType Container) {
    foreach ($entry in @(Get-ChildItem -LiteralPath $ownedPakDir -Recurse -Force -File)) { Add-RemovalPath $entry.FullName }
  }
  if (Test-Path -LiteralPath $pc -PathType Container) {
    foreach ($entry in @(Get-ChildItem -LiteralPath $pc -Recurse -Force -File -Filter '*.palcraft-tmp')) { Add-RemovalPath $entry.FullName }
  }
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
  $packs = Resolve-PackList $Choice
  $mapOn = ($WithMapArt -and ($packs -contains 'islands_animals'))
  Assert-InstallPreflight $Game $Dep $Mc $packs $mapOn $PayloadDir $ListPath

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
  $script:ManifestSaver = $null
  $mpath = Join-Path $pc 'install-manifest.json'
  # Checkpointed manifest: an interrupted or failed install can always be uninstalled from the last checkpoint.
  $saveManifest = {
    $manifest = [ordered]@{
      schema = 1; installer_version = $script:InstallerVersion
      installed_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
      game_dir = $script:St.Game; palcraft_dir = $pcRel
      mc_version = $Mc.Version; packs = $packs; map_art = $mapOn; complete = $ok
      missing_assets = @($(if ($assetResult) { $assetResult.Missing } else { @() }))
      dirs_created = @($script:St.Dirs)
      files = @($script:St.Files.Values)
    }
    if ($script:Dry) { Write-Log "[dry-run] manifest would list $($script:St.Files.Count) files"; return }
    Ensure-Dir $pc
    Write-TextAtomic $mpath (ConvertTo-Json -InputObject $manifest -Depth 6)
  }
  $script:ManifestSaver = $saveManifest
  try {
    Set-Progress 5 'core'
    [void](Copy-PayloadPack $Game $Dep $PayloadDir 'core' $true)
    $i = 0
    foreach ($p in $packs) { $i++; Set-Progress (10 + 10 * $i) $p; [void](Copy-PayloadPack $Game $Dep $PayloadDir $p $false) }
    if ($mapOn) { Set-Progress 30 'map_art'; [void](Copy-PayloadPack $Game $Dep $PayloadDir 'map_art' $false) }
    & $saveManifest

    Set-Progress 40 'assets'
    $assetsRoot = Join-Path $pc 'assets'
    $assetResult = Export-McAssets $Mc $packs $assetsRoot $ListPath
    Write-Log "assets: $($assetResult.Written) written, $($assetResult.Missing.Count) missing of $($assetResult.Requested) entries"
    foreach ($m in $assetResult.Missing) { Write-Log "missing asset: $m" 'WARN' }
    if ($assetResult.Missing.Count -gt 0) {
      Write-TextTracked (Join-Path $pc 'missing-assets.txt') ("These Minecraft files were not found in your install (" + $Mc.Version + "):`r`n" + ($assetResult.Missing -join "`r`n") + "`r`n") 'report'
    }

    & $saveManifest
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
      $soundReceipt=Join-Path $assetsRoot 'minecraft/_palcraft/cooked-sound-receipt.json'
      if (Test-Path -LiteralPath $soundReceipt -PathType Leaf) {
        Add-Record $soundReceipt 'asset' (Get-Sha256 $soundReceipt)
        $soundPatched=[IO.File]::ReadAllText($soundReceipt,[Text.Encoding]::UTF8) | ConvertFrom-Json
        if (-not $soundPatched.complete) { Write-Log 'Some Minecraft sounds remain silent; see the cooked sound receipt.' 'WARN' }
      }
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
      ('creative_mode = ' + $(if ($packs -contains 'hud_skins') { '1' } else { '0' })),
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
    try { & $saveManifest; if (-not $script:Dry) { Write-Log "manifest written: $mpath ($($script:St.Files.Count) files, complete=$ok)" } }
    catch { Write-Log "manifest could not be written: $($_.Exception.Message)" 'ERROR' }
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
  $g = $u.Game.Text.Trim(); $u.LinkUe.Visible = $false; $u.LinkPs.Visible = $false; $u.WantUe = $false; $u.WantPs = $false
  $u.G = $null; $u.Dep = $null; $u.Mc_ = $null
  $ready = $true
  $gp = Get-PalworldProblem $g
  if ($gp) { $u.GameStatus.Text = T $gp; $u.DepStatus.Text = ''; $ready = $false }
  else {
    $u.G = $g; $u.GameStatus.Text = T 'game_found'
    $dep = Get-DependencyInfo $g; $u.Dep = $dep
    $probs = @(Get-DependencyProblems $dep)
    if ($probs.Count -eq 0) { $u.DepStatus.Text = T 'deps_ok' }
    else {
      $t = @($probs | ForEach-Object { T $_.Key $_.Args })
      if (@($probs | Where-Object { $_.Level -eq 'error' }).Count) { $t += (T 'deps_stop'); $ready = $false }
      $u.DepStatus.Text = $t -join "`r`n"
      if (@($probs | Where-Object { $_.Dep -eq 'ue4ss' }).Count) { $u.LinkUe.Visible = $true; $u.WantUe = $true }
      if (@($probs | Where-Object { $_.Dep -eq 'palschema' }).Count) { $u.LinkPs.Visible = $true; $u.WantPs = $true }
    }
  }
  $mcDir = $u.Mc.Text.Trim()
  $dg = if ($mcDir) { Get-McDiagnosis @($mcDir) } else { Get-McDiagnosis }
  $u.McStatus.Text = $dg.Message
  if ($dg.Status -eq 'ok') { $u.Mc_ = $dg.Mc } else { $ready = $false }
  $u.BtnInstall.Enabled = $ready
  $hasInst = [bool]($u.G -and (Find-Manifest $u.G))
  $u.BtnUninstall.Enabled = $hasInst
  $leg = [bool]($u.Dep -and $u.Dep.ModsDir -and (Get-LegacyDir $u.Dep))
  $u.BtnMigrate.Visible = $leg; $u.WantMigrate = $leg
  $u.BtnMigrate.Enabled = $leg -and $hasInst
  Sync-MapArt
  Update-GuiLayout
}

function Get-NotWritableAction {
  # 'stop' when already elevated (nothing more we can do), else 'prompt' to relaunch elevated.
  if (Test-IsAdmin) { return 'stop' } else { return 'prompt' }
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
      if ((Get-NotWritableAction) -eq 'stop') { [void][Windows.Forms.MessageBox]::Show((T 'need_admin_stop'), (T 'title')) }
      elseif ([Windows.Forms.MessageBox]::Show((T 'need_admin'), (T 'title'), 'YesNo') -eq 'Yes') {
        $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'), '-GameDir', ('"' + $u.G.TrimEnd('\') + '"'), '-Language', $script:Lang)
        if ($u.Mc.Text.Trim()) { $a += @('-MinecraftDir', ('"' + $u.Mc.Text.Trim().TrimEnd('\') + '"')) }
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
function Update-GuiLayout {
  # Flow layout computed from measured text so no localized message is ever clipped (Korean and English, any DPI scale).
  $u = $script:Ui
  if (-not $u -or $script:InGuiLayout) { return }
  $script:InGuiLayout = $true
  try {
    $f = $u.Form; $S = [double]$u.S
    $P = { param([double]$n) [int][Math]::Round($n * $S) }
    $m = & $P 12; $gap = & $P 6
    $w = $f.ClientSize.Width - 2 * $m
    $fl = [Windows.Forms.TextFormatFlags]::WordBreak -bor [Windows.Forms.TextFormatFlags]::NoPrefix
    $fit = { param($c, [int]$width, [int]$minH)
      if ([string]::IsNullOrEmpty($c.Text)) { return 0 }
      $sz = [Windows.Forms.TextRenderer]::MeasureText($c.Text, $c.Font, (New-Object Drawing.Size(($width - (& $P 8)), 0)), $fl)
      return [Math]::Max($minH, $sz.Height + (& $P 4)) }
    $y = & $P 10
    $h = & $fit $u.Intro $w (& $P 20); $u.Intro.SetBounds($m, $y, $w, $h); $y += $h + $gap
    $u.LblGame.SetBounds($m, $y, $w, (& $P 20)); $y += (& $P 22)
    $bw = [Math]::Max((& $P 98), [Windows.Forms.TextRenderer]::MeasureText($u.GameBrowse.Text, $u.GameBrowse.Font).Width + (& $P 24))
    $u.GameBrowse.SetBounds($f.ClientSize.Width - $m - $bw, $y - (& $P 2), $bw, (& $P 27))
    $u.Game.SetBounds($m, $y, $w - $bw - $gap, (& $P 24)); $y += (& $P 28)
    $h = & $fit $u.GameStatus $w (& $P 20); $u.GameStatus.SetBounds($m, $y, $w, $h); $y += $h + $gap
    $h = & $fit $u.DepStatus $w 0; $u.DepStatus.SetBounds($m, $y, $w, $h); if ($h) { $y += $h + $gap }
    # Control.Visible is false for children of a form that is not shown yet, so layout uses the Want* flags.
    if ($u.WantUe -or $u.WantPs) {
      $x = $m
      foreach ($pair in @(@($u.LinkUe, $u.WantUe), @($u.LinkPs, $u.WantPs))) {
        if ($pair[1]) { $lk = $pair[0]; $lk.AutoSize = $true; $lk.Location = New-Object Drawing.Point($x, $y); $x += $lk.PreferredWidth + (& $P 24) }
      }
      $y += (& $P 26)
    }
    $u.LblMc.SetBounds($m, $y, $w, (& $P 20)); $y += (& $P 22)
    $bw2 = [Math]::Max((& $P 98), [Windows.Forms.TextRenderer]::MeasureText($u.McBrowse.Text, $u.McBrowse.Font).Width + (& $P 24))
    $u.McBrowse.SetBounds($f.ClientSize.Width - $m - $bw2, $y - (& $P 2), $bw2, (& $P 27))
    $u.Mc.SetBounds($m, $y, $w - $bw2 - $gap, (& $P 24)); $y += (& $P 28)
    $h = & $fit $u.McStatus $w (& $P 20); $u.McStatus.SetBounds($m, $y, $w, $h); $y += $h + $gap
    # pack group (inner stack measured too)
    $gw = $w - (& $P 28); $iy = & $P 22
    foreach ($c in $u.RAll, $u.RHud, $u.RIsl) { $ch = & $fit $c ($gw - (& $P 24)) (& $P 22); $c.SetBounds((& $P 14), $iy, $gw, $ch); $iy += $ch + (& $P 2) }
    $ch = & $fit $u.CMap ($gw - (& $P 44)) (& $P 22); $u.CMap.SetBounds((& $P 34), $iy, $gw - (& $P 20), $ch); $iy += $ch + (& $P 8)
    $u.Group.SetBounds($m, $y, $w, $iy); $y += $iy + $gap
    foreach ($c in $u.Dry, $u.Saves) { $ch = & $fit $c ($w - (& $P 28)) (& $P 22); $c.SetBounds($m + (& $P 2), $y, $w - (& $P 2), $ch); $y += $ch + (& $P 2) }
    $y += $gap
    # buttons
    $bh = & $P 34; $x = $m
    foreach ($b in $u.BtnInstall, $u.BtnUninstall, $u.BtnMigrate) {
      $bwid = [Math]::Max((& $P 130), [Windows.Forms.TextRenderer]::MeasureText($b.Text, $b.Font).Width + (& $P 32))
      $b.SetBounds($x, $y, $bwid, $bh); if (($b -ne $u.BtnMigrate) -or $u.WantMigrate) { $x += $bwid + $gap }
    }
    $cw = [Math]::Max((& $P 130), [Windows.Forms.TextRenderer]::MeasureText($u.BtnClose.Text, $u.BtnClose.Font).Width + (& $P 32))
    $u.BtnClose.SetBounds($f.ClientSize.Width - $m - $cw, $y, $cw, $bh); $y += $bh + $gap
    $u.Progress.SetBounds($m, $y, $w, (& $P 14)); $y += (& $P 20)
    $minLog = & $P 70
    $need = $y + $minLog + $m
    if ($need -gt $f.ClientSize.Height) { $f.ClientSize = New-Object Drawing.Size($f.ClientSize.Width, $need) }
    $u.Log.SetBounds($m, $y, $w, ($f.ClientSize.Height - $y - $m))
  } finally { $script:InGuiLayout = $false }
}

function New-MainForm {
  param([double]$TestScale = 1.0)   # tests only: emulate a DPI-aware window at 125/150/200 percent
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  try { [Windows.Forms.Application]::EnableVisualStyles() } catch { }
  $S = $TestScale
  if ($TestScale -eq 1.0) {
    try { $g0 = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $S = [Math]::Max(1.0, $g0.DpiX / 96.0); $g0.Dispose() } catch { $S = 1.0 }
  }
  $fontName = if ($script:Lang -eq 'ko') { 'Malgun Gothic' } else { 'Segoe UI' }
  # With a DPI-aware process, a point size already renders larger at 125/150/200 percent; TestScale emulates that.
  $font = New-Object Drawing.Font($fontName, (9 * $TestScale))
  $f = New-Object Windows.Forms.Form
  $f.Text = T 'title'; $f.Font = $font; $f.StartPosition = 'CenterScreen'; $f.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
  $f.ClientSize = New-Object Drawing.Size([int](740 * $S), [int](620 * $S)); $f.MinimumSize = New-Object Drawing.Size([int](640 * $S), [int](560 * $S))
  $u = @{}; $script:Ui = $u; $u.Form = $f; $u.S = $S
  $script:GuiGame = $null; $script:GuiDep = $null; $script:GuiMc = $null; $script:InGuiLayout = $false

  function New-Lbl([string]$text) { $c = New-Object Windows.Forms.Label; $c.Text = $text; $c.UseMnemonic = $false; $f.Controls.Add($c); return $c }
  $u.Intro = New-Lbl (T 'intro')
  $u.LblGame = New-Lbl (T 'game_path')
  $u.Game = New-Object Windows.Forms.TextBox; $f.Controls.Add($u.Game)
  $u.GameBrowse = New-Object Windows.Forms.Button; $u.GameBrowse.Text = T 'browse'; $f.Controls.Add($u.GameBrowse)
  $u.GameStatus = New-Lbl ''
  $u.DepStatus = New-Lbl ''
  $u.LinkUe = New-Object Windows.Forms.LinkLabel; $u.LinkUe.Text = T 'link_ue4ss'; $u.LinkUe.Visible = $false; $u.LinkUe.UseMnemonic = $false; $f.Controls.Add($u.LinkUe)
  $u.LinkPs = New-Object Windows.Forms.LinkLabel; $u.LinkPs.Text = T 'link_palschema'; $u.LinkPs.Visible = $false; $u.LinkPs.UseMnemonic = $false; $f.Controls.Add($u.LinkPs)
  $u.LblMc = New-Lbl (T 'mc_path')
  $u.Mc = New-Object Windows.Forms.TextBox; $f.Controls.Add($u.Mc)
  $u.McBrowse = New-Object Windows.Forms.Button; $u.McBrowse.Text = T 'browse'; $f.Controls.Add($u.McBrowse)
  $u.McStatus = New-Lbl ''

  $g = New-Object Windows.Forms.GroupBox; $g.Text = T 'packs_title'; $f.Controls.Add($g); $u.Group = $g
  $u.RAll = New-Object Windows.Forms.RadioButton; $u.RAll.Text = T 'pack_all'; $u.RAll.Checked = $true
  $u.RHud = New-Object Windows.Forms.RadioButton; $u.RHud.Text = T 'pack_hud'
  $u.RIsl = New-Object Windows.Forms.RadioButton; $u.RIsl.Text = T 'pack_islands'
  $u.CMap = New-Object Windows.Forms.CheckBox; $u.CMap.Text = T 'map_art'; $u.CMap.Checked = $true
  foreach ($c in $u.RAll, $u.RHud, $u.RIsl, $u.CMap) { $c.UseMnemonic = $false; $g.Controls.Add($c) }   # "HUD & Skins": '&' is literal text
  $u.RAll.add_CheckedChanged({ Sync-MapArt }); $u.RHud.add_CheckedChanged({ Sync-MapArt }); $u.RIsl.add_CheckedChanged({ Sync-MapArt })

  $u.Dry = New-Object Windows.Forms.CheckBox; $u.Dry.Text = T 'dry_run'; $u.Dry.Checked = $script:Dry; $u.Dry.UseMnemonic = $false; $f.Controls.Add($u.Dry)
  $u.Saves = New-Object Windows.Forms.CheckBox; $u.Saves.Text = T 'remove_saves'; $u.Saves.UseMnemonic = $false; $f.Controls.Add($u.Saves)

  $u.BtnInstall = New-Object Windows.Forms.Button; $u.BtnInstall.Text = T 'install'; $f.Controls.Add($u.BtnInstall)
  $u.BtnUninstall = New-Object Windows.Forms.Button; $u.BtnUninstall.Text = T 'uninstall'; $f.Controls.Add($u.BtnUninstall)
  $u.BtnMigrate = New-Object Windows.Forms.Button; $u.BtnMigrate.Text = T 'migrate'; $u.BtnMigrate.Visible = $false; $f.Controls.Add($u.BtnMigrate)
  $u.BtnClose = New-Object Windows.Forms.Button; $u.BtnClose.Text = T 'close'; $f.Controls.Add($u.BtnClose)
  foreach ($b in $u.BtnInstall, $u.BtnUninstall, $u.BtnMigrate, $u.BtnClose, $u.GameBrowse, $u.McBrowse) { $b.UseMnemonic = $false }
  $u.BtnClose.add_Click({ $script:Ui.Form.Close() })

  $u.Progress = New-Object Windows.Forms.ProgressBar; $f.Controls.Add($u.Progress)
  $u.Log = New-Object Windows.Forms.TextBox; $u.Log.Multiline = $true; $u.Log.ReadOnly = $true; $u.Log.ScrollBars = 'Vertical'
  $u.Log.Font = New-Object Drawing.Font('Consolas', (8.5 * $TestScale)); $f.Controls.Add($u.Log)

  $script:UiLog = { param($line) $script:Ui.Log.AppendText($line + "`r`n"); [Windows.Forms.Application]::DoEvents() }
  $script:UiProgress = { param($pct, $text) $script:Ui.Progress.Value = [Math]::Max(0, [Math]::Min(100, $pct)); [Windows.Forms.Application]::DoEvents() }

  $u.LinkUe.add_LinkClicked({ Start-Process $script:Ue4ssUrl })
  $u.LinkPs.add_LinkClicked({ Start-Process $script:PalSchemaUrl })
  $u.GameBrowse.add_Click({ Select-GuiFolder $script:Ui.Game })
  $u.McBrowse.add_Click({ Select-GuiFolder $script:Ui.Mc })
  $u.Game.add_Leave({ Update-GuiState }); $u.Mc.add_Leave({ Update-GuiState })
  $u.BtnInstall.add_Click({ Start-GuiInstall })
  $u.BtnUninstall.add_Click({ Start-GuiUninstall })
  $u.BtnMigrate.add_Click({ Start-GuiMigrate })
  $f.add_Resize({ Update-GuiLayout })

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
  if ($game -and (Test-XboxPalworld $game)) { Exit-WithError (T 'game_xbox') 5 }
  if (-not (Test-PalworldDir $game)) { Exit-WithError ((T (Get-PalworldProblem $game)) + ' (-GameDir)') 1 }
  try {
    if ($Uninstall) { [void](Invoke-Uninstall $game ([bool]$RemoveSaves)); exit 0 }
    $dep = Get-DependencyInfo $game
    if ($Migrate) { [void](Invoke-Migration $game $dep); exit 0 }
    $probs = @(Get-DependencyProblems $dep)
    foreach ($w in @($probs | Where-Object { $_.Level -eq 'warn' })) { Write-Log (Format-DependencyProblem $w) 'WARN' }
    $errs = @($probs | Where-Object { $_.Level -eq 'error' })
    if ($errs.Count) { Exit-WithError ((@($errs | ForEach-Object { Format-DependencyProblem $_ }) -join ' ') + ' ' + (T 'deps_stop')) 2 }
    $mc = if ($MinecraftDir) { Find-MinecraftInstall @($MinecraftDir) } else { Find-MinecraftInstall }
    if (-not $mc) { $dg = if ($MinecraftDir) { Get-McDiagnosis @($MinecraftDir) } else { Get-McDiagnosis }; Exit-WithError $dg.Message 3 }
    $r = Invoke-Install $game $PackChoice ([bool]$MapArt) $mc $dep $PayloadDir $RequiredList
    Write-Log "Done: $($r.Files) files, $($r.Missing.Count) missing Minecraft files."
    exit 0
  } catch {
    if ($_.Exception.Message -eq 'NOT_WRITABLE') { Exit-WithError (T 'need_admin_stop') 4 }
    if ($_.Exception.Data['ExitCode']) { Exit-WithError $_.Exception.Message ([int]$_.Exception.Data['ExitCode']) }
    Exit-WithError $_.Exception.Message 1
  }
}

# GUI
try {
  Add-Type -Namespace PalCraft -Name Win -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
  [void][PalCraft.Win]::ShowWindow([PalCraft.Win]::GetConsoleWindow(), 0)   # hide the console behind the GUI
} catch { }
$script:Quiet = $true
try {
  Add-Type -Namespace PalCraft -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
  [void][PalCraft.Dpi]::SetProcessDPIAware()   # must precede the first window; avoids blurry bitmap scaling
} catch { }
$form = New-MainForm
[void]$form.ShowDialog()
