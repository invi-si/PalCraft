-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local base=debug.getinfo(1,'S').source:sub(2):match('^(.*)[/\\]');local K=assert(loadfile(base..'/variantsK.lua'))(base)
local V={setsK=K}
V.sheep={
 {name='white',rgb={.90,.90,.90}},{name='orange',rgb={.85,.50,.20}},
 {name='magenta',rgb={.70,.30,.85}},{name='light_blue',rgb={.40,.60,.85}},
 {name='yellow',rgb={.90,.90,.20}},{name='lime',rgb={.50,.80,.10}},
 {name='pink',rgb={.95,.50,.65}},{name='gray',rgb={.30,.30,.30}},
 {name='light_gray',rgb={.60,.60,.60}},{name='cyan',rgb={.30,.50,.60}},
 {name='purple',rgb={.50,.25,.70}},{name='blue',rgb={.20,.30,.70}},
 {name='brown',rgb={.40,.30,.20}},{name='green',rgb={.40,.50,.20}},
 {name='red',rgb={.60,.20,.20}},{name='black',rgb={.10,.10,.10}}
}
V.horse={'Horse','HorseWhite','HorseBlack','HorseChestnut','HorseCreamy'}
function V.seed(g,n)return((g.A%n)+(g.B%n)+(g.C%n)+(g.D%n))%n end
function V.naturalSheep(g)
 local n=V.seed(g,1000)
 return n<50 and 16 or n<100 and 8 or n<150 and 9 or n<180 and 13 or n==180 and 7 or 1
end
function V.apply(s,index,UE,asset)
 index=math.floor(index or 1)
 if s.kind=='sheep'then
  local row=assert(V.sheep[index]);local rgb=row.rgb
  
  for i,m in ipairs(s.models)do if m.layer=='fur'then s.x4.materials[i]:SetVectorParameterValue(UE.FindOrAddFName('Tint'),{R=rgb[1],G=rgb[2],B=rgb[3],A=1})end end
  s.variantJ=row.name
 elseif K[s.kind]then
  local row=assert(K[s.kind][index]);local t=assert(asset(row.texture))
  for i,m in ipairs(s.models)do if m.mesh and m.x4 then s.x4.materials[i]:SetTextureParameterValue(UE.FindOrAddFName('Tex'),t)end end
  s.variantJ=row.name
 else error('No staged variant set for '..s.kind)end
 return s.variantJ
end
return V
