-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,I)
 local valid=ctx.valid;local key=I.data.key or'plains';local prefix='StaticMesh /Game/MinecraftIslandX6/'..key..'/'
 function I:owns(a)return valid(a)and valid(self.actor)and a:GetAddress()==self.actor:GetAddress()end
 local previousStatus=I.status
 function I:status()
  local d=previousStatus(self);d.architecture='cooked-default-single-actor-X6';d.detailPackage='/Game/MinecraftIslandX6/'..key
  d.nativePathing=self.nativePathingB or false;return d
 end
 function I:inspect(e)
  assert(self:guard(e,ctx.epoch())and self.admitted,'Detailed island not ready')
  local actors=self:census(e);assert(#actors==1 and self:owns(actors[1]))
  local a=actors[1];assert(not a.bHidden and a:GetActorEnableCollision())
  local native=a:K2_GetComponentsByClass(ctx.UE.Object('/Script/Engine.StaticMeshComponent'));local rows={};local collision=0
  for _,v in ipairs(native)do
   local ok,c=pcall(function()return v:get()end);c=ok and c or v
   assert(valid(c)and c:GetOwner():GetAddress()==a:GetAddress()and c.Mobility==0)
   local mesh=c.StaticMesh;assert(valid(mesh)and mesh:GetFullName():sub(1,#prefix)==prefix)
   local enabled=c:GetCollisionEnabled()
   if enabled~=0 then assert(mesh:GetFullName():find('.SM_CollisionX6',1,true)and enabled==3);collision=collision+1 end
   rows[#rows+1]={component=c:GetAddress(),mesh=mesh:GetFullName(),collision=enabled}
  end
  assert(collision==1,'One exact authored collision component required')
  return{nativeActors=1,rows=rows,status=self:status()}
 end
 dofile(ctx.base..'/timers.lua').onEpoch('detailed-islandB-'..key,function()I.nativePathingB=nil;I.probePathingB=nil end)
 return I
end
