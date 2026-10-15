# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright Invi
<# Import/UV-pack original generated face artwork into exact 64x64 wide skins.
   This is deterministic atlas conversion: no new painting or AI inference.
   Source images are retained as original-art evidence; all base faces are opaque.
#>
param(
  [Parameter(Mandatory=$true)][string]$BramSource,
  [Parameter(Mandatory=$true)][string]$RinaSource,
  [Parameter(Mandatory=$true)][string]$OutputDir
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

function Build-Skin {
  param([string]$Source,[string]$Name,[hashtable]$Parts)
  $src=[Drawing.Bitmap]::FromFile([IO.Path]::GetFullPath($Source))
  $out=New-Object Drawing.Bitmap 64,64,([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  # Pixel rectangles are measured in the 1280x1280 generation canvas.
  function Face {
    param([string]$Part,[int]$X,[int]$Y,[int]$W,[int]$H)
    $r=$Parts[$Part]
    for ($v=0;$v -lt $H;$v++) { for ($u=0;$u -lt $W;$u++) {
      $sx=[Math]::Min($src.Width-1,[Math]::Max(0,[int](($r[0]+($u+0.5)*$r[2]/$W)*$src.Width/1280)))
      $sy=[Math]::Min($src.Height-1,[Math]::Max(0,[int](($r[1]+($v+0.5)*$r[3]/$H)*$src.Height/1280)))
      $c=$src.GetPixel($sx,$sy)
      if ($c.A -lt 128) {
        $cx=[int](($r[0]+$r[2]/2)*$src.Width/1280);$cy=[int](($r[1]+$r[3]/2)*$src.Height/1280)
        $c=$src.GetPixel([Math]::Min($src.Width-1,$cx),[Math]::Min($src.Height-1,$cy))
      }
      $out.SetPixel($X+$u,$Y+$v,[Drawing.Color]::FromArgb(255,$c.R,$c.G,$c.B))
    }}
  }
  try {
    Face head_top 8 0 8 8; Face head_bottom 16 0 8 8
    Face head_right 0 8 8 8; Face head_front 8 8 8 8; Face head_left 16 8 8 8; Face head_back 24 8 8 8
    Face body_top 20 16 8 4; Face body_bottom 28 16 8 4
    Face body_right 16 20 4 12; Face body_front 20 20 8 12; Face body_left 28 20 4 12; Face body_back 32 20 8 12
    foreach ($p in @(@(0,16),@(16,48))) {
      $x=$p[0];$y=$p[1]
      Face leg_top ($x+4) $y 4 4; Face leg_bottom ($x+8) $y 4 4
      Face leg_right $x ($y+4) 4 12; Face leg_front ($x+4) ($y+4) 4 12
      Face leg_left ($x+8) ($y+4) 4 12; Face leg_back ($x+12) ($y+4) 4 12
    }
    foreach ($p in @(@(40,16),@(32,48))) {
      $x=$p[0];$y=$p[1]
      Face arm_top ($x+4) $y 4 4; Face arm_bottom ($x+8) $y 4 4
      Face arm_right $x ($y+4) 4 12; Face arm_front ($x+4) ($y+4) 4 12
      Face arm_left ($x+8) ($y+4) 4 12; Face arm_back ($x+12) ($y+4) 4 12
    }
    $path=Join-Path $OutputDir ($Name+'.png')
    $out.Save([IO.Path]::GetFullPath($path),[Drawing.Imaging.ImageFormat]::Png)
    # Nearest-neighbor QA enlargement; the game uses only the 64x64 texture.
    $preview=New-Object Drawing.Bitmap 512,512
    $g=[Drawing.Graphics]::FromImage($preview)
    try {
      $g.Clear([Drawing.Color]::FromArgb(48,48,48))
      $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
      $g.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::Half
      $g.DrawImage($out,[Drawing.Rectangle]::new(0,0,512,512),[Drawing.Rectangle]::new(0,0,64,64),[Drawing.GraphicsUnit]::Pixel)
      $preview.Save([IO.Path]::GetFullPath((Join-Path $OutputDir ($Name+'-atlas-preview.png'))),[Drawing.Imaging.ImageFormat]::Png)
    } finally { $g.Dispose();$preview.Dispose() }
    [pscustomobject]@{Name=$Name;Width=$out.Width;Height=$out.Height;SHA256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
  } finally { $src.Dispose();$out.Dispose() }
}

$bram=@{
 head_top=@(226,40,126,140);head_bottom=@(375,40,97,140)
 head_right=@(50,184,154,171);head_front=@(209,184,156,171);head_left=@(370,184,153,171);head_back=@(530,184,183,171)
 body_top=@(473,415,153,76);body_bottom=@(473,746,153,23)
 body_right=@(396,498,70,270);body_front=@(473,498,153,270);body_left=@(634,498,94,270);body_back=@(736,498,133,270)
 arm_top=@(961,415,90,76);arm_bottom=@(1060,415,82,76)
 arm_right=@(909,498,46,270);arm_front=@(961,498,90,270);arm_left=@(1060,498,82,270);arm_back=@(1150,498,60,270)
 leg_top=@(470,892,112,28);leg_bottom=@(470,1167,112,24)
 leg_right=@(398,892,64,298);leg_front=@(470,892,112,298);leg_left=@(591,892,94,298);leg_back=@(693,892,63,298)
}
$rina=@{
 head_top=@(238,17,160,158);head_bottom=@(575,180,160,170)
 head_right=@(73,180,158,170);head_front=@(238,180,160,170);head_left=@(406,180,159,170);head_back=@(747,180,193,170)
 body_top=@(401,436,89,46);body_bottom=@(325,740,268,27)
 body_right=@(239,488,71,279);body_front=@(325,488,268,279);body_left=@(608,488,70,279);body_back=@(694,488,239,279)
 arm_top=@(30,435,74,46);arm_bottom=@(126,735,86,31)
 arm_right=@(126,488,86,279);arm_front=@(30,488,74,279);arm_left=@(1049,488,84,279);arm_back=@(1154,488,75,279)
 leg_top=@(87,887,91,24);leg_bottom=@(87,1164,91,24)
 leg_right=@(205,887,97,301);leg_front=@(87,887,91,301);leg_left=@(950,887,92,301);leg_back=@(1076,887,97,301)
}
Build-Skin $BramSource bram $bram
Build-Skin $RinaSource rina $rina
