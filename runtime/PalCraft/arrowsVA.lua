-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,M)
 local UE,V=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua');local pose=dofile(ctx.base..'/poseK.lua')
 local A={pending={},native={},events={}};local mesh='/Game/MinecraftMobs/Task45/SM_arrow_shaft.SM_arrow_shaft'
 local function p(v)return{X=v.X,Y=v.Y,Z=v.Z}end
 local function unwrap(v)local ok,r=pcall(function()return v:get()end);return ok and r or v end
 local function rotation(v)return{Pitch=math.deg(math.atan(v.Z,math.sqrt(v.X*v.X+v.Y*v.Y))),Yaw=math.deg(math.atan(v.Y,v.X)),Roll=0}end
 function A:free(e)
  local oldest
  for _,a in ipairs(M.arrows)do if not a.active then return a end;if a.stuckVA and(not oldest or a.updated<oldest.updated)then oldest=a end end
  if oldest then M:hide(oldest,e,'oldest_stuck_arrow');return oldest end
 end
 function A:fire(e,source,target,from)
  if not M:guard(e)or not V(target)then return false end
  local a=self:free(e);if not a then return false end
  local tp=target:K2_GetActorLocation();local aim=p(tp)
  if target:IsA(UE.Object('/Script/Pal.PalCharacter'))then aim.Z=tp.Z-target.CapsuleComponent:GetScaledCapsuleHalfHeight()/3 end
  M:paint(a,'arrow',e);M.activation=M.activation+1
  local now=os.clock();a.active=true;a.kind='arrow';a.p=p(from);a.previousVA=p(from);a.velocity=M.motion.arrowVelocity(from,aim,2)
  a.generation=M.activation;a.updated=now;a.simVA=now;a.accVA=0;a.untilAt=now+12;a.sourceVA=source;a.sourceGenerationVA=source.generation
  a.nativeShooterVA=source.host;a.playerOwnedVA=source.owned108==true;a.targetVA=target;a.stuckVA=nil;a.stuckTargetVD=nil;a.pickupZ3=nil;a.nativeProbeM=nil;a.nativeImpactM=nil
  pose(a.actor.RootComponent,{location=a.p,rotation=rotation(a.velocity),scale={X=1,Y=1,Z=1}});a.actor:SetActorHiddenInGame(false)
  M:event('shoot',source,{arrow=a.index,origin=p(from),velocity=p(a.velocity),speed=3200,inaccuracy=6,gravityPerTick=.05,drag=.99,drawSeconds=1,nativeHost=V(source.host)and source.host:GetAddress()or nil})
  ctx.phaseC:play('entity.skeleton.shoot',from,.8,e);return true
 end
 local function capsule(old,q,feet,r,h)
  local dx,dy=q.X-old.X,q.Y-old.Y;local n=dx*dx+dy*dy
  local t=n>.001 and math.max(0,math.min(1,((feet.X-old.X)*dx+(feet.Y-old.Y)*dy)/n))or 0
  local x,y,z=old.X+dx*t,old.Y+dy*t,old.Z+(q.Z-old.Z)*t
  local clamped=math.max(feet.Z+r,math.min(feet.Z+h-r,z))
  if(x-feet.X)^2+(y-feet.Y)^2+(z-clamped)^2<=(r+2)^2 then return t end
 end
 function A:impact(e,a,target,slot,point)
  if slot then
   if a.playerOwnedVA then
    local cp=V(a.nativeShooterVA)and a.nativeShooterVA.CharacterParameterComponent
    if V(cp)then M:applyHit(slot,e,os.clock(),'Pal:MC_Skeleton',math.max(1,math.floor(cp:GetShotAttack()/25+.5)),{latency=0,nativeContact=true,projectile=a.index,arrowFlight=true},a.p,false,true)end
   end
  elseif V(target)then
   local source=a.nativeShooterVA
   if V(source)and source:IsA(UE.Object('/Script/Pal.PalCharacter'))then
    local cp=target.CharacterParameterComponent;local before=cp:GetHP().Value
    local info={Attacker=source,Defender=target,HitComponent=target.CapsuleComponent,Power=40,Category=1,Element=0,AttackType=0,WeaponType=0,
     HitLocation=p(point),HitInfo={bBlockingHit=true,ImpactPoint=p(point),Location=p(point)},IsLeanBack=true,IsBlow=false,BlowVelocity={X=0,Y=0,Z=0},SneakAttackRate=1,DamageRatePerCollision=1,
     PvPBuildingDamageRate=1,PvPPlayerToGuildPalDamageRate=1,CollectionObjectDamageRate=1,WeaponDamageRatePvP=1,AttackStaticItemID=UE.FindOrAddFName('None'),bAttackableToFriend=false}
    UE.Object('/Script/Pal.Default__PalUtility'):ProcessDamageAndPlayEffects(source,target,info)
    M:event('arrow_native_hit',a,{target=target:GetAddress(),before=before,after=cp:GetHP().Value,path='ProcessDamageAndPlayEffects'})
   else M:damageTarget(target,{kind='skeleton'},e,.05);M:event('arrow_hit',a,{target=target:GetAddress(),nativeDamage=true})end
  end
  a.p=p(point);a.stuckVA=true;a.untilAt=os.clock()+20;a.updated=os.clock()
  if V(target)then
   local at=target:K2_GetActorLocation();local yaw=math.rad(target:K2_GetActorRotation().Yaw);local dx,dy=point.X-at.X,point.Y-at.Y
   a.stuckTargetVD={actor=target,identity=target:GetFullName(),generation=slot and slot.generation,slot=slot,offset={X=dx*math.cos(yaw)+dy*math.sin(yaw),Y=-dx*math.sin(yaw)+dy*math.cos(yaw),Z=point.Z-at.Z},yaw=rotation(a.velocity).Yaw-math.deg(yaw)}
  end
  pose(a.actor.RootComponent,{location=a.p,rotation=rotation(a.velocity),scale={X=1,Y=1,Z=1}})
  M:event('arrow_stick',a,{target=V(target)and target:GetAddress()or false,point=p(point)})
 end
 function A:step(e,a)
  local old=a.p;local v=a.velocity;local q={X=old.X+v.X*.05,Y=old.Y+v.Y*.05,Z=old.Z+v.Z*.05}
  local t,target,slot=2,nil,nil
  local function consider(actor,feet,r,h,s)
   local hit=capsule(old,q,feet,r,h);if hit and hit<t then t,target,slot=hit,actor,s end
  end
  if a.playerOwnedVA then
   for _,s in ipairs(M.slots)do if s.active and not s.poof then local d=M.defs[s.kind];consider(s.actor,s.p,d.radius,d.height,s)end end
   local native=a.targetVA
   if V(native)and native:IsA(UE.Object('/Script/Pal.PalCharacter'))and not native.CharacterParameterComponent:IsDead()then
    local at=native:K2_GetActorLocation();local half=native.CapsuleComponent:GetScaledCapsuleHalfHeight()
    consider(native,{X=at.X,Y=at.Y,Z=at.Z-half},native.CapsuleComponent:GetScaledCapsuleRadius(),half*2)
   end
  else
   consider(e.player,M.combat.playerFeet,e.player.CapsuleComponent:GetScaledCapsuleRadius(),e.player.CapsuleComponent:GetScaledCapsuleHalfHeight()*2)
   for _,r in ipairs(M.combat.targets)do consider(r.actor,r.feet,r.radius,r.height)end
  end
  local hit={};local c={R=0,G=0,B=0,A=0};local ignore={e.player}
  for _,r in ipairs(M.combat.targets)do ignore[#ignore+1]=r.actor end
  if V(a.nativeShooterVA)then ignore[#ignore+1]=a.nativeShooterVA end
  if a.playerOwnedVA and V(a.targetVA)and a.targetVA:IsA(UE.Object('/Script/Pal.PalCharacter'))then ignore[#ignore+1]=a.targetVA end
  local blocked=_G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,old,q,0,false,ignore,0,hit,true,c,c,0)
  if blocked and(hit.Time or 0)<t then t=hit.Time or 0;target=nil;slot=nil end
  if t<=1 then self:impact(e,a,target,slot,{X=old.X+(q.X-old.X)*t,Y=old.Y+(q.Y-old.Y)*t,Z=old.Z+(q.Z-old.Z)*t});return end
  a.previousVA=p(old);a.p=q
  
  v.X=v.X*.99;v.Y=v.Y*.99;v.Z=v.Z*.99-100
 end
 function A:tick(e,now)
  self:players(e,now)
  for _,a in ipairs(M.arrows)do if a.active then
   if a.pickupZ3 then M:pickupArrowZ3(e,a,now,M.combat.playerPosition)
   elseif now>a.untilAt then M:hide(a,e,'arrow_timeout')
   elseif a.stuckVA and a.stuckTargetVD then
    local r=a.stuckTargetVD;local actor=r.actor
    if not V(actor)or actor:GetFullName()~=r.identity or(r.slot and(not r.slot.active or r.slot.generation~=r.generation))then M:hide(a,e,'stuck_target_lost')
    else local at=actor:K2_GetActorLocation();local yaw=math.rad(actor:K2_GetActorRotation().Yaw);local o=r.offset
     a.p={X=at.X+o.X*math.cos(yaw)-o.Y*math.sin(yaw),Y=at.Y+o.X*math.sin(yaw)+o.Y*math.cos(yaw),Z=at.Z+o.Z}
     local rot=rotation(a.velocity);rot.Yaw=math.deg(yaw)+r.yaw;pose(a.actor.RootComponent,{location=a.p,rotation=rot,scale={X=1,Y=1,Z=1}})
    end
   elseif not a.stuckVA then
    a.accVA=(a.accVA or 0)+math.min(.25,now-(a.simVA or now));a.simVA=now;local n=0
    while a.accVA>=.05 and n<5 and not a.stuckVA do self:step(e,a);a.accVA=a.accVA-.05;n=n+1 end
    if not a.stuckVA then local t=math.min(1,a.accVA/.05);local prev=a.previousVA or a.p
     pose(a.actor.RootComponent,{location={X=prev.X+(a.p.X-prev.X)*t,Y=prev.Y+(a.p.Y-prev.Y)*t,Z=prev.Z+(a.p.Z-prev.Z)*t},rotation=rotation(a.velocity),scale={X=1,Y=1,Z=1}})
    end
   end
  end end
 end

 NotifyOnNewObject('/Game/Pal/Blueprint/Weapon/Bullet/BP_Arrow.BP_Arrow_C',function(a)
  if #A.pending<32 then A.pending[#A.pending+1]={actor=a,epoch=T.epoch}end
 end)
 function A:players(e,now)
  for _,r in ipairs(self.pending)do if r.epoch==T.epoch and V(r.actor)then self.native[#self.native+1]=r end end;self.pending={}
  for i=#self.native,1,-1 do local r=self.native[i];local a=r.actor
   if not V(a)or r.epoch~=T.epoch then table.remove(self.native,i)
   elseif not r.done then
    local owner=a:GetInstigator();local weapon=e.player.ShooterComponent:GetHasWeapon()
    if V(owner)and owner:GetAddress()==e.player:GetAddress()and V(weapon)and weapon:GetItemId().StaticId:ToString()=='MC_Bow'then
     local tf={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
     local list=a:K2_GetComponentsByClass(UE.Object('/Script/Engine.StaticMeshComponent'))
     for _,v in ipairs(list)do local c=unwrap(v);if V(c)then c:SetVisibility(false,false)end end
     local co=a:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,tf,false);co:SetCollisionEnabled(0);co:SetGenerateOverlapEvents(false)
     co:K2_AttachToComponent(a.RootComponent,UE.FindOrAddFName('None'),2,2,2,false);co:SetStaticMesh(M:asset(mesh));r.done=true
     M:event('player_arrow_mesh',nil,{actor=a:GetAddress(),mesh=mesh,nativePhysics=true})
    else r.tries=(r.tries or 0)+1;if r.tries>10 then table.remove(self.native,i)end end
   elseif a.bHidden then table.remove(self.native,i)end
  end
  while #self.native>32 do table.remove(self.native,1)end
 end
 T.onEpoch('arrowsVA',function()A.pending={};A.native={}end)
 return A
end
