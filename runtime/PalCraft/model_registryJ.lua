-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local base=...
if _G.MC_MODEL_REGISTRY_J then return _G.MC_MODEL_REGISTRY_J end
local old=assert(loadfile(base..'/mob_models.lua'))(base)
local raw=_G.MC_X4_GEOMETRY_J or assert(loadfile(base..'/mob_models_x4.lua'))(base)
_G.MC_X4_GEOMETRY_J=raw
local models={};for kind,parts in pairs(raw)do local list={};for i,p in ipairs(parts)do list[i]=p end;models[kind]=list end
for kind,parts in pairs(models)do
 for _,p in ipairs(parts)do p.x4=true end
 
 for _,p in ipairs(old[kind]or{})do if p.name=='bow'then
  local copy={};for k,v in pairs(p)do copy[k]=v end

  copy.mesh='/Game/MinecraftBlocks/SM_MC_HeldBow.SM_MC_HeldBow';copy.heldK='MC_Bow'
  for i,arm in ipairs(parts)do if arm.name=='right_arm'then copy.parent=i end end
  assert(copy.parent);copy.equipmentJ=true;parts[#parts+1]=copy
 end end
end
local held={zombie={id='MC_IronSword',mesh='/Game/MinecraftBlocks/SM_MC_HeldIronSword.SM_MC_HeldIronSword',arm='right_arm'},husk={id='MC_IronShovel',mesh='/Game/MinecraftBlocks/SM_MC_HeldIronShovel.SM_MC_HeldIronShovel',arm='right_arm'},witch={id='potion',mesh='/Game/MinecraftHostiles107/SM_potion_body.SM_potion_body',arm='arms'}}
for kind,d in pairs(held)do
 local parts=models[kind];local parent;for i,p in ipairs(parts)do if p.name==d.arm then parent=i end end;assert(parent)
 parts[#parts+1]={name='held_'..d.id,heldK=d.id,equipmentJ=true,parent=parent,mesh=d.mesh,location={X=0,Y=0,Z=0},rotation={Pitch=0,Yaw=0,Roll=0}}
end
for k,v in pairs(old)do if not models[k]then models[k]=v end end
_G.MC_MODEL_REGISTRY_J=models
return models
