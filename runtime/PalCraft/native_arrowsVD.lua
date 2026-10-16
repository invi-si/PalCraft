-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local U,V=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua');local pose=dofile(ctx.base..'/poseK.lua')
 local M={slots={},arrows={},defs={},activation=0,events={},motion=dofile(ctx.base..'/mob_motion.lua'),combat={targets={}}}
 local mesh='/Game/MinecraftMobs/Task45/SM_arrow_shaft.SM_arrow_shaft'
 local function p(v)return{X=v.X,Y=v.Y,Z=v.Z}end
 function M:guard(e)return e and ctx.ready()and e.epoch==ctx.epoch()and self.epoch==ctx.epoch()end
 function M:asset(path)return U.zombie77:asset(path)end
 function M:event(kind,s,extra)
  local r=extra or{};r.action=kind;r.slot=s and s.index;r.time=os.clock();self.events[#self.events+1]=r
  if #self.events>256 then table.remove(self.events,1)end
 end
 function M:hide(a,e,reason)a.active=false;a.stuckVA=nil;a.stuckTargetVD=nil;a.actor:SetActorHiddenInGame(true);self:event(reason,a)end
 function M:paint(a,kind,e)if not a.painted then local co=a.part;local asset=self:asset(mesh);co:SetStaticMesh(asset);co:SetMaterial(0,asset:GetMaterial(0));a.painted=true end end
 function M:los(e,a,b)
  local hit={};local c={R=0,G=0,B=0,A=0};local ignore={e.player}
  for _,s in ipairs(U.zombie77.slots)do if V(s.host)then ignore[#ignore+1]=s.host end end
  for _,s in ipairs(self.combat.targets)do ignore[#ignore+1]=s.actor end
  return not _G.MC_OUT_K('LineTraceSingle',U.GetKismetSystemLibrary(),e.player,a,b,0,false,ignore,0,hit,true,c,c,0)
 end
 function M.combat:target(s,e)
  local actor,feet=e.player,self.playerFeet;local d=(feet.X-s.p.X)^2+(feet.Y-s.p.Y)^2
  for _,r in ipairs(self.targets)do local n=(r.feet.X-s.p.X)^2+(r.feet.Y-s.p.Y)^2;if n<d then d=n;actor=r.actor;feet=r.feet end end
  return actor,feet
 end
 local function create(e,i,old)
  local tf={Rotation={X=0,Y=0,Z=0,W=1},Translation=p(e.player:K2_GetActorLocation()),Scale3D={X=1,Y=1,Z=1}}
  local a=old;local co
  if V(a)then
   local list=a:K2_GetComponentsByClass(U.Object('/Script/Engine.StaticMeshComponent'))
   for _,v in ipairs(list)do local ok,x=pcall(function()return v:get()end);co=ok and x or v;break end
  else
   local g=U.Object('/Script/Engine.Default__GameplayStatics');a=g:BeginDeferredActorSpawnFromClass(e.world,U.Object('/Script/Engine.Actor'),tf,1,nil);a=g:FinishSpawningActor(a,tf)
   a.Tags={U.FindOrAddFName('PCNativeArrowVD'),U.FindOrAddFName('PCNativeArrowVD:'..i)}
   co=a:AddComponentByClass(U.Object('/Script/Engine.StaticMeshComponent'),false,{Rotation=tf.Rotation,Translation={X=0,Y=0,Z=0},Scale3D=tf.Scale3D},false)
   co:SetMobility(2);co:SetCollisionEnabled(0);co:SetGenerateOverlapEvents(false)
  end
  assert(V(co));a:SetActorEnableCollision(false);a:SetActorHiddenInGame(true)
  local slot={index=i,actor=a,part=co};M.arrows[i]=slot;M:paint(slot,'arrow',e)
 end
 ctx.phaseC=ctx.sound;M.arrowsVA=dofile(ctx.base..'/arrowsVA.lua')(ctx,M)
 T.onEpoch('native-arrows-VD',function()M.arrows={};M.epoch=nil;M.poolReady=nil;M.events={};M.combat.targets={}end)
 T.frame('native-arrows-VD',function()
  local e=ctx.environment();if not e or not ctx.ready()then return end
  if M.epoch~=ctx.epoch()then
   M.epoch=ctx.epoch();M.arrows={};M.poolReady=nil
   local found={};_G.MC_OUT_K('GetAllActorsWithTag',U.Object('/Script/Engine.Default__GameplayStatics'),e.player,U.FindOrAddFName('PCNativeArrowVD'),found)
   for _,v in ipairs(found)do local a=v:get();if V(a)and a:GetWorld():GetAddress()==e.world:GetAddress()then
    for i=1,8 do if a:ActorHasTag(U.FindOrAddFName('PCNativeArrowVD:'..i))then create(e,i,a);break end end
   end end
  end
  for i=1,8 do if not M.arrows[i]then create(e,i);return end end
  M.poolReady=true;local at=e.player:K2_GetActorLocation();M.combat.playerPosition=p(at);M.combat.playerFeet={X=at.X,Y=at.Y,Z=at.Z-e.player.CapsuleComponent:GetScaledCapsuleHalfHeight()};M.combat.targets={}
  local pal=e.controller.BP_OtomoPalHolderComponent:TryGetSpawnedOtomo()
  if V(pal)and not pal.CharacterParameterComponent:IsDead()then local q=pal:K2_GetActorLocation();local half=pal.CapsuleComponent:GetScaledCapsuleHalfHeight()
   M.combat.targets[1]={actor=pal,feet={X=q.X,Y=q.Y,Z=q.Z-half},radius=pal.CapsuleComponent:GetScaledCapsuleRadius(),height=half*2}
  end
  M.arrowsVA:tick(e,os.clock())
 end)
 U.mobs66=M;return M
end
