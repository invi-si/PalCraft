-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local base=debug.getinfo(1,'S').source:sub(2):match('^(.*)[/\\]')
if _G.MC_EQUIPMENT_K then return _G.MC_EQUIPMENT_K end
local E={};_G.MC_EQUIPMENT_K=E
E.potionVA={Rotation={X=-0.0,Y=0.36627252908604746,Z=-0.0,W=0.9305076219123143},Translation={X=10.466912137689777,Y=0.0,Z=-47.04137848069912},Scale3D={X=1.5285714285714287,Y=1.5285714285714287,Z=1.5285714285714287}}
function E.apply(s,UE)
 for i,d in ipairs(s.models)do if d.heldK then
  local c=s.parts[i];local tf
  if d.heldK=='potion'then

   tf=assert(E.potionVA)
  else
   E.display=E.display or dofile(base..'/item_display66.lua')
   local h=assert(E.display[d.heldK]).third_right;local p=h.Translation

   local q=h.Rotation;local k=math.sqrt(.5)
   tf={Rotation={X=k*(q.X+q.Y),Y=k*(q.Y-q.X),Z=k*(q.Z-q.W),W=k*(q.W+q.Z)},Translation={X=p.Y,Y=-p.X,Z=p.Z-75},Scale3D=h.Scale3D}
  end
  _G.MC_OUT_K('K2_SetRelativeTransform',c,tf,false,{},true);s.heldItemK=d.heldK
 end end
end
return E
