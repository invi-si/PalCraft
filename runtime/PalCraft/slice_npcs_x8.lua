-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local UE,valid=ctx.UE,ctx.valid
 local T=dofile(ctx.base..'/timers.lua');local D=dofile(ctx.base..'/slice_x8_data.lua')
 local S={npcs={},input=false};local support=dofile(ctx.base..'/placement109.lua')(UE,ctx.log)
 local function tf(p)return{Rotation={X=0,Y=0,Z=0,W=1},Translation=p or{X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}end
 local function asset(path)
  local a=UE.Object(path);if not valid(a)then local package,name=path:match('^(.*)%.([^%.]+)$');a=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(package),AssetName=UE.FindOrAddFName(name)})end
  assert(valid(a),'X8 asset missing '..path);ctx.retain(a);return a
 end
 local function distance(e,p)local a=e.player:K2_GetActorLocation();return math.sqrt((a.X-p.X)^2+(a.Y-p.Y)^2+(a.Z-p.Z-90)^2)end
 local function ownedActor(e,key,p)
  local tag=UE.FindOrAddFName('MCX8_'..key);local found={};local g=UE.Object('/Script/Engine.Default__GameplayStatics')
  _G.MC_OUT_K('GetAllActorsWithTag',g,e.player,tag,found)
  local result
  for _,v in ipairs(found)do local a=v:get();if valid(a)then local w=a:GetWorld();if valid(w)and w:GetAddress()==e.world:GetAddress()then assert(not result,'Duplicate X8 actor '..key);result=a end end end
  if result then return result,false end
  local transform=tf(p);local a=g:BeginDeferredActorSpawnFromClass(e.world,UE.Object('/Script/Engine.Actor'),transform,1,nil)
  assert(valid(a));a=g:FinishSpawningActor(a,transform);assert(valid(a));a.Tags={tag};a:SetActorHiddenInGame(true);a:SetActorEnableCollision(false)
  local root=a:AddComponentByClass(UE.Object('/Script/Engine.SceneComponent'),false,tf(),false);assert(valid(root));root:SetMobility(2)
  assert(_G.MC_OUT_K('K2_SetActorLocation',a,p,false,{},true));return a,true
 end
 local function floor(e,key,p)
  return support:ready(key,p,200,function()
   local hit={};local color={R=0,G=0,B=0,A=0}
   local ok=_G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,{X=p.X,Y=p.Y,Z=p.Z+40},{X=p.X,Y=p.Y,Z=p.Z-40},0,false,{e.player},0,hit,true,color,color,0)
   local c=ok and hit.Component:Get()or nil
   if valid(c)and ctx.island:owned(c:GetOwner())and hit.ImpactNormal.Z>.65 and math.abs(hit.ImpactPoint.Z-p.Z)<8 then return hit.ImpactPoint.Z end
  end)
 end
 function S:start(e,spec)
  local n=self.npcs[spec.id];if n and n.epoch==ctx.epoch()and valid(n.actor)then return n end
  local z=floor(e,spec.id,spec.position);if not z then return end
  local p={X=spec.position.X,Y=spec.position.Y,Z=z+2};local a,fresh=ownedActor(e,spec.id,p)
  local mesh
  if fresh then
   mesh=a:AddComponentByClass(UE.Object('/Script/Engine.PoseableMeshComponent'),false,tf(),false);assert(valid(mesh));mesh:SetCollisionEnabled(0);mesh:SetGenerateOverlapEvents(false)
   mesh:SetSkinnedAssetAndUpdate(asset('/Game/MinecraftSteve/Task27/SK_MC27WideBody.SK_MC27WideBody'),true)
   _G.MC_OUT_K('K2_SetRelativeRotation',mesh,{Pitch=0,Yaw=-90,Roll=0},false,{},true)
   local tex=UE.texRuntime:load(spec.skin,nil,{original=true})
   assert(valid(tex)and tex:Blueprint_GetSizeX()==64 and tex:Blueprint_GetSizeY()==64);tex.Filter=0;ctx.retain(tex)
   dofile(ctx.base..'/steve_skin.lua')(ctx).apply(mesh,tex,asset)
  else mesh=a:GetComponentByClass(UE.Object('/Script/Engine.PoseableMeshComponent'))end
  assert(valid(mesh));local pose=dofile(ctx.base..'/alex_pose.lua')(ctx);pose:bind(mesh);pose:tick(0,0)
  a:K2_SetActorRotation({Pitch=0,Yaw=spec.yaw,Roll=0},true);a:SetActorHiddenInGame(false)
  n={actor=a,mesh=mesh,pose=pose,p=p,facing=spec.yaw,epoch=ctx.epoch()};self.npcs[spec.id]=n
  ctx.log('MCX8_NPC_READY id='..spec.id..' classic_arms=true');return n
 end
 function S:inRange(e)
  local id=UE.alexTrade.vendorX8 or'Alex'
  if id=='Alex'then return UE.alex and UE.alex.p and UE.alex.epoch==ctx.epoch()and UE.alex:distance(e)<=300 end
  local n=self.npcs[id];return n and n.epoch==ctx.epoch()and valid(n.actor)and distance(e,n.p)<=300
 end
 function S:tick()
  if not UE.worldScope65:valid(UE.worldScope65.id)or not ctx.ready()then return end
  local e=ctx.environment();local island=ctx.island.all.plains
  if not e or not island.admitted or not island.footingReady then return end
  for _,spec in ipairs(D.npcs)do if distance(e,spec.position)<15000 then local n=self:start(e,spec)
   if n then local p=e.player:K2_GetActorLocation();local dx,dy,dz=p.X-n.p.X,p.Y-n.p.Y,p.Z+60-n.p.Z-168
    local yaw,pitch=0,0;if distance(e,n.p)<=800 then yaw=math.max(-75,math.min(75,(math.deg(math.atan(dy,dx))-n.facing+180)%360-180));pitch=-math.max(-40,math.min(40,math.deg(math.atan(dz,math.sqrt(dx*dx+dy*dy)))))end
    n.pose:tick(yaw,pitch)
   end
  end end
  local near,best
  for id,n in pairs(self.npcs)do if valid(n.actor)then local dist=distance(e,n.p);if dist<=300 and(not best or dist<best)then near=id;best=dist end end end
  if near~=self.prompt then self.prompt=near;if near and ctx.gameplayInput(e)then ctx.ui:notify(near,'[F] Trade - '..D.roles[near])end end
  if not self.chest and distance(e,D.reward.position)<10000 then
   local p=D.reward.position;local z=floor(e,'reward',p)
   if z then local a,fresh=ownedActor(e,'reward',p)
    if fresh then local c=a:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,tf(),false);assert(valid(c));c:SetMobility(2);c:SetCollisionEnabled(0)
     local m=asset(ctx.registry[ctx.types.chest].mesh);assert(c:SetStaticMesh(m));c:SetMaterial(0,m:GetMaterial(0))
     
     _G.MC_OUT_K('K2_SetRelativeLocation',c,{X=0,Y=0,Z=50},false,{},true)
    end
    a:SetActorHiddenInGame(false);self.chest=a;ctx.log('MCX8_CHEST_READY id='..D.reward.id)
   end
  end
 end
 T.frame('slice-x8-input',function()
  if not S.input then return end;S.input=false
  if not UE.worldScope65:valid(UE.worldScope65.id)or not ctx.ready()then return end
  local e=ctx.environment();if not e or not ctx.gameplayInput(e)then return end
  local chosen,best
  if UE.alex and UE.alex.p and UE.alex.epoch==ctx.epoch()then local d=UE.alex:distance(e);if d<=300 then chosen='Alex';best=d end end
  for id,n in pairs(S.npcs)do if n.epoch==ctx.epoch()and valid(n.actor)then local d=distance(e,n.p);if d<=300 and(not best or d<best)then chosen=id;best=d end end end
  if chosen then UE.alexTrade:showVendorX8(e,chosen)end
 end)
 T.loop(100,function()S:tick();return false end,'slice-x8-npcs')
 T.onEpoch('slice-x8',function()S.npcs={};S.chest=nil;S.input=false;S.prompt=nil;support:reset()end)
 return S
end
