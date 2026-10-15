-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,capture,env,asset)
 local UE,valid=ctx.UE,ctx.valid;local S=assert(ctx.steve)
 local t={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
 local c=env.player:AddComponentByClass(UE.Object('/Script/Engine.PoseableMeshComponent'),true,t,false)
 assert(valid(c));c.ComponentTags={UE.FindOrAddFName('MCMInventorySteve')}
 c:SetCollisionEnabled(0);c:SetCastShadow(false);c:SetVisibleInSceneCaptureOnly(true)
 c:SetOwnerNoSee(false);c:SetOnlyOwnerSee(false)
 assert(c:K2_AttachToComponent(env.player.Mesh,UE.FindOrAddFName('None'),0,0,0,false))
 c:SetSkinnedAssetAndUpdate(assert(asset(S:meshPath(false))),true)
 if valid(S.mesh)then for i=0,S.mesh:GetNumMaterials()-1 do c:SetMaterial(i,S.mesh:GetMaterial(i))end end
 local mathM=dofile(ctx.base..'/steve_motion.lua')

 for _,side in ipairs({'r','l'})do
  local shoulder=c:GetBoneTransformByName(UE.FindOrAddFName('upperarm_'..side),1)
  local hand=c:GetBoneTransformByName(UE.FindOrAddFName('hand_'..side),1)
  local down=mathM.down(mathM.sub(hand.Translation,shoulder.Translation))
  for _,name in ipairs({'upperarm_','lowerarm_','hand_'})do
   local f=UE.FindOrAddFName(name..side);local b=c:GetBoneTransformByName(f,1)
   b.Rotation=mathM.mul(down,b.Rotation)
   b.Translation=mathM.add(shoulder.Translation,mathM.rotate(down,mathM.sub(b.Translation,shoulder.Translation)))
   c:SetBoneTransformByName(f,b,1)
  end
 end
 capture:ClearShowOnlyComponents();capture:ShowOnlyComponent(c)
 ctx.log('MCM_INVENTORY_STEVE capture_only=true native_mask_preserved=true')
 return c
end
