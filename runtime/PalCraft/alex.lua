-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local A={};local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local support=dofile(ctx.base..'/placement109.lua')(UE,ctx.log)
 local pose=dofile(ctx.base..'/alex_pose.lua')(ctx)
 local function tf(p)return{Rotation={X=0,Y=0,Z=0,W=1},Translation=p or{X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}end
 local function asset(path)
  local a=UE.Object(path);if not valid(a)then local package,name=path:match('^(.*)%.([^%.]+)$');a=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(package),AssetName=UE.FindOrAddFName(name)})end
  assert(valid(a),'Alex asset unavailable '..path);ctx.retain(a);return a
 end
 function A:start(env)
  if not UE.worldScope65:valid(UE.worldScope65.id)then return end
  if self.epoch==ctx.epoch()and valid(self.actor)then return end
  if support.failed.alex then return end
  local nativeOnly=UE.packFlags and not UE.packFlags:has('hud_skins')
  local anchor=UE.restorePlanner109.alex
  if nativeOnly then
   local island=ctx.island.all.plains

   if not island.admitted or not island.footingReady or island.epoch~=ctx.epoch()then return end
   local p=island.data.arrival;anchor={X=p.X+300,Y=p.Y+300,Z=p.Z}
  end
  local floor=support:ready('alex',anchor,500,function()
   local p=anchor;local color={R=0,G=0,B=0,A=0};local hit={}
   local top=nativeOnly and p.Z+400 or 6400;local bottom=nativeOnly and p.Z-1200 or 3500
   if _G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),env.player,{X=p.X,Y=p.Y,Z=top},{X=p.X,Y=p.Y,Z=bottom},0,false,{env.player},0,hit,true,color,color,0)and hit.ImpactNormal.Z>.65 then
    if nativeOnly then local component=hit.Component:Get();if not valid(component)or not ctx.island:owned(component:GetOwner())then return end end
    return hit.ImpactPoint.Z
   end
  end)
  if not floor then return end
  self.epoch=ctx.epoch();local tag=UE.FindOrAddFName('MC62Alex');local found={}
  local g=UE.Object('/Script/Engine.Default__GameplayStatics');_G.MC_OUT_K('GetAllActorsWithTag',g,env.player,tag,found)
  for _,v in ipairs(found)do local a=v:get();if valid(a)then local w=a:GetWorld();if valid(w)and w:GetAddress()==env.world:GetAddress()then assert(not self.actor,'Duplicate Alex');self.actor=a end end end
  if not valid(self.actor)then
   local p={X=anchor.X,Y=anchor.Y,Z=floor+2};local transform=tf(p)
   local a=g:BeginDeferredActorSpawnFromClass(env.world,UE.Object('/Script/Engine.Actor'),transform,1,nil);assert(valid(a));a=g:FinishSpawningActor(a,transform);assert(valid(a));self.actor=a;a.Tags={tag};a:SetActorHiddenInGame(true);a:SetActorEnableCollision(false)
   local root=a:AddComponentByClass(UE.Object('/Script/Engine.SceneComponent'),false,tf(),false);assert(valid(root));root:SetMobility(2)
   self.mesh=a:AddComponentByClass(UE.Object('/Script/Engine.PoseableMeshComponent'),false,tf(),false);assert(valid(self.mesh));self.mesh:SetCollisionEnabled(0);self.mesh:SetGenerateOverlapEvents(false)
   self.mesh:SetSkinnedAssetAndUpdate(asset('/Game/MinecraftTask70/SK_MC70AlexBody.SK_MC70AlexBody'),true)
   _G.MC_OUT_K('K2_SetRelativeRotation',self.mesh,{Pitch=0,Yaw=-90,Roll=0},false,{},true)
   local tex=UE.texRuntime:load('textures/entity/player/wide/alex.png',nil);if valid(tex)then ctx.retain(tex)end
   dofile(ctx.base..'/steve_skin.lua')(ctx).apply(self.mesh,tex,asset)
   local definitions={{x=-70,y=120,z=48,sx=2.8,sy=.65,sz=.95,item='oak_planks'},{x=-135,y=120,z=170,sx=.16,sy=.16,sz=2.45,item='oak_log'},{x=135,y=120,z=170,sx=.16,sy=.16,sz=2.45,item='oak_log'},{x=0,y=120,z=292,sx=3.4,sy=1.8,sz=.15,item='red_wool'}}
   for _,d in ipairs(definitions)do local c=a:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,tf({X=d.x,Y=d.y,Z=d.z}),false);assert(valid(c));c:SetMobility(2);c:SetCollisionEnabled(0);local mesh=asset(ctx.registry[ctx.types[d.item]].mesh);assert(c:SetStaticMesh(mesh));c:SetMaterial(0,mesh:GetMaterial(0));c:SetRelativeScale3D({X=d.sx,Y=d.sy,Z=d.sz})end

   assert(_G.MC_OUT_K('K2_SetActorLocation',a,p,false,{},true),'Alex root placement failed')
  else
   self.mesh=self.actor:GetComponentByClass(UE.Object('/Script/Engine.PoseableMeshComponent'))
  end
  assert(valid(self.mesh));pose:bind(self.mesh);pose:tick(0,0);self.look=pose.snapshot;self.actor:SetActorHiddenInGame(false);local p=self.actor:K2_GetActorLocation();self.p={X=p.X,Y=p.Y,Z=p.Z};self.facing=90
  self.actor:K2_SetActorRotation({Pitch=0,Yaw=self.facing,Roll=0},true)
  ctx.log('MC62_ALEX_READY pooled=true slim=true native_npc=false epoch='..self.epoch)
  if ctx.trade.prime67 then ctx.trade:prime67(env)end
 end
 function A:distance(env)local p=env.player:K2_GetActorLocation();return math.sqrt((p.X-self.p.X)^2+(p.Y-self.p.Y)^2+(p.Z-self.p.Z-90)^2)end
 function A:tick()
  if not UE.worldScope65:valid(UE.worldScope65.id)then return false end
  local env=ctx.environment();if not env or not ctx.ready()then return false end
  self:start(env);if self.epoch~=ctx.epoch()or not valid(self.actor)or not valid(self.mesh)then return false end
  local w=self.actor:GetWorld();if not valid(w)or w:GetAddress()~=env.world:GetAddress()then return false end
  local p=env.player:K2_GetActorLocation();local dx,dy,dz=p.X-self.p.X,p.Y-self.p.Y,p.Z+60-self.p.Z-168;local distance=self:distance(env)
  local yaw,pitch=0,0;if distance<=800 then yaw=math.max(-75,math.min(75,(math.deg(math.atan(dy,dx))-self.facing+180)%360-180));pitch=-math.max(-40,math.min(40,math.deg(math.atan(dz,math.sqrt(dx*dx+dy*dy)))))end
  pose:tick(yaw,pitch);self.look=pose.snapshot
  return false
 end

 T.frame('alex-input',function()
  if not A.interact then return end;A.interact=nil
  if not UE.worldScope65:valid(UE.worldScope65.id)or not ctx.ready()then ctx.log('MCG_ALEX_INPUT_REJECT not_ready');return end
  local env=ctx.environment()
  if not env or A.epoch~=ctx.epoch()or not valid(A.actor)or not A.p then ctx.log('MCG_ALEX_INPUT_REJECT no_actor');return end
  local distance=A:distance(env)
  if distance<=300 and ctx.gameplayInput(env)then ctx.log('MCG_ALEX_INPUT_ACCEPT distance='..distance);ctx.trade:show(env)
  elseif distance<=800 then ctx.log('MCG_ALEX_INPUT_REJECT distance='..distance..' cursor='..tostring(env.controller.bShowMouseCursor)..' ignored='..tostring(env.controller:IsMoveInputIgnored()))end
 end)

 T.loop(100,function()return A:tick()end,'alex-owned-actor')
 T.onEpoch('alex',function()support:reset();A.actor=nil;A.mesh=nil;A.p=nil;A.epoch=nil;A.interact=nil;A.look=nil end)
 return A
end
