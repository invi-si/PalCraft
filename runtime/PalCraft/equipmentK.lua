-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local base=debug.getinfo(1,'S').source:sub(2):match('^(.*)[/\\]')
if _G.MC_EQUIPMENT_K then return _G.MC_EQUIPMENT_K end
local E={};_G.MC_EQUIPMENT_K=E
function E.apply(s,UE)
 for i,d in ipairs(s.models)do if d.heldK then
  local c=s.parts[i];local tf
  if d.heldK=='potion'then
   tf={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=25,Y=0,Z=-43},Scale3D={X=1,Y=1,Z=1}}
  else
   E.display=E.display or dofile(base..'/item_display66.lua')
   local h=assert(E.display[d.heldK]).third_right;local p=h.Translation
   tf={Rotation=h.Rotation,Translation={X=p.X,Y=p.Y,Z=p.Z-75},Scale3D=h.Scale3D}
  end
  _G.MC_OUT_K('K2_SetRelativeTransform',c,tf,false,{},true);s.heldItemK=d.heldK
 end end
end
return E
