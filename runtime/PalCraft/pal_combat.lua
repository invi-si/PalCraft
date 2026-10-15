-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,mobs)
 local C={montages={},nextAttack=0,nextSearch=0,searches=0};local timers=dofile(ctx.base..'/timers.lua')
 local function copy(p,old)local q=old or{};q.X=p.X;q.Y=p.Y;q.Z=p.Z;return q end
 local function distance(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)end
 local function current(env)
  
  return env and env.epoch==ctx.epoch()and mobs:guard(env)and ctx.valid(env.world)
 end
 function C:reset()
  self.pal=nil;self.address=nil;self.identity=nil;self.nativeIdentity=nil;self.speciesP=nil;self.position=nil;self.feet=nil;self.pending=nil;self.targetSerial=nil;self.nextAttack=0;self.approachSerial=nil;self.best=nil;self.nextSearch=0;self.emptySince=nil;self.controlled=false
  for _,s in ipairs(mobs.slots)do s.palAggro=nil end
 end
 function C:refresh(env)
  if not current(env)then self:reset();self.playerPosition=nil;self.playerFeet=nil;self.frame=nil;return false end
  if self.frame==timers.frameCounter and self.epoch==ctx.epoch()and self.playerAddress==env.playerAddress and self.worldIdentity==env.identity then return self.playerPosition~=nil end
  self.frame=timers.frameCounter;self.epoch=ctx.epoch()
  self.playerAddress=env.playerAddress;self.worldIdentity=env.identity
  local previous=self.nativeIdentity
  if not ctx.valid(env.player)or not ctx.valid(env.controller)then self:reset();self.playerPosition=nil;self.playerFeet=nil;return false end
  local playerCapsule=env.player.CapsuleComponent
  if not ctx.valid(playerCapsule)then self:reset();self.playerPosition=nil;self.playerFeet=nil;return false end
  self.playerPosition=copy(env.player:K2_GetActorLocation(),self.playerPointZ3);self.playerPointZ3=self.playerPosition;self.playerFeet=copy(self.playerPosition,self.playerFeetZ3);self.playerFeetZ3=self.playerFeet
  self.playerFeet.Z=self.playerFeet.Z-playerCapsule:GetScaledCapsuleHalfHeight()
  self.pal=nil;self.position=nil;self.feet=nil;self.address=nil
  if ctx.config.pal_combat==false then self:reset();return true end
  local h=env.controller.BP_OtomoPalHolderComponent;if not ctx.valid(h)then self:reset();return true end;local a=h:TryGetSpawnedOtomo()
  if not ctx.valid(a)or not a:GetActiveActorFlag()then self:reset();return true end
  local world=a:GetWorld();if not ctx.valid(world)or world:GetAddress()~=env.world:GetAddress()then self:reset();return true end
  local c=a.CharacterParameterComponent;local capsule=a.CapsuleComponent
  if not ctx.valid(capsule)or not ctx.valid(c)or c:IsDead()or c:GetHP().Value<=0 or c:IsInactiveOtomo()then self:reset();return true end
  
  if env.controller:IsRiding()then self:reset();return true end
  local address=a:GetAddress();local identity=previous
  if self.nativeAddress61~=address or not previous then identity=tostring(ctx.epoch())..':'..address end
  if previous~=identity then
   self:reset();self.nativeAddress61=address;self.generation=(self.generation or 0)+1;self.nativeIdentity=identity;self.identity=identity..'#'..self.generation;mobs:event('pal_identity',nil,{previous=previous or false,identity=self.identity})
  end
  self.pal=a;self.address=address;self.position=copy(a:K2_GetActorLocation(),self.palPointZ3);self.palPointZ3=self.position;self.feet=copy(self.position,self.palFeetZ3);self.palFeetZ3=self.feet
  if not self.speciesP then self.speciesP=c:GetIndividualParameter():GetCharacterID():ToString()end
  self.feet.Z=self.feet.Z-capsule:GetScaledCapsuleHalfHeight()
  return true
 end
 function C:target(s,env)
  if not self:refresh(env)then return end
  local a=env.player;local p=self.playerPosition;local feet=self.playerFeet;local kind='player'
  if self.pal and (s.palAggro==self.address or distance(s.p,self.feet)<distance(s.p,feet))and distance(s.p,self.feet)<=3200 then a=self.pal;p=self.position;feet=self.feet;kind='pal' end
  local address=kind=='pal'and self.address or env.playerAddress
  if s.targetAddress~=address then s.targetAddress=address;s.targetKind=kind;mobs:event('retarget',s,{target=kind,address=address})end
  return a,p,feet,kind
 end
 function C:montage(a)
  local c=a.CharacterParameterComponent;if not ctx.valid(c)then return end
  local parameter=c:GetIndividualParameter();if not ctx.valid(parameter)then return end
  local id=parameter:GetCharacterID():ToString()
  local clips={CP_IvoryRattle='Pounce',CP_RedstoneRevenant='ChargePunch',CP_FungalHost='SporePuff',CP_PatchworkBrute='GloveSlam'}
  if clips[id]then
   local m=self.montages[id];if ctx.valid(m)then return m end
   local name='AM_A2_'..id:sub(4)..'_'..clips[id]
   m=ctx.UE.zombie77:asset('/Game/CustomPalsA1/'..name..'.'..name)
   if ctx.valid(m)then ctx.retain(m);self.montages[id]=m;return m end
  end
  
  local slot=ctx.UE.zombie77 and ctx.UE.zombie77.hosts[a:GetAddress()]
  local donor=slot and slot.definition and slot.definition.host or(id:sub(1,3)=='CP_'and'PinkCat'or id)
  local m=self.montages[donor]
  if ctx.valid(m)then return m end
  local stem='/Game/Pal/Animation/Character/Monster/'..donor..'/AM_'..donor..'_FarSkill_Action'
  m=ctx.UE.Object(stem..'.AM_'..id..'_FarSkill_Action')
  if not ctx.valid(m)then
   m=ctx.UE.GetAsset109(ctx.UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=ctx.UE.FindOrAddFName(stem),AssetName=ctx.UE.FindOrAddFName('AM_'..id..'_FarSkill_Action')})
  end
  if ctx.valid(m)and m:IsA(ctx.UE.Object('/Script/Engine.AnimMontage'))then ctx.retain(m);self.montages[donor]=m;return m end
 end
 function C:tick(env,now)
  if not current(env)or self.epoch~=ctx.epoch()then self:reset();return end
  if mobs.test65 and(mobs.test65.feature=='bridge'or mobs.test65.mode~='attacking')then self.pending=nil;return end
  local a=self.pal
  if a then
   if not ctx.valid(a)or not ctx.valid(a.CharacterParameterComponent)or not ctx.valid(a.CapsuleComponent)then self:reset();return end
   local world=a:GetWorld();if not ctx.valid(world)or world:GetAddress()~=env.world:GetAddress()then self:reset();return end
  end
  if not a then self.pending=nil;self.targetSerial=nil;return end
  local golem=self.speciesP=='MC_IronGolem';local nativeSlot=golem and ctx.UE.zombie77 and ctx.UE.zombie77.hosts[self.address]
  if nativeSlot and nativeSlot.golemAc then self.pending=nil;return end
  local p=self.position;local pending=self.pending
  if pending then
   local s=pending.slot
   if pending.identity~=self.identity or pending.address~=self.address or not s.active or s.poof or s.serial~=pending.serial or s.generation~=pending.generation or pending.epoch~=ctx.epoch()then self.pending=nil
   elseif now>=pending.at then
    self.pending=nil
    if distance(p,s.p)<=(pending.golem and 360 or 1100)and mobs:los(env,p,{X=s.p.X,Y=s.p.Y,Z=s.p.Z+80})then
     s.palAggro=self.address
     mobs:applyHit(s,env,now,'Pal:'..pending.id,pending.damage,{latency=now-pending.start,palAttack=true,pal=self.address,nativeAttack=pending.stat,montage=pending.montage},p,false,true)
    end
   end
  end
  if now>=self.nextSearch then
   self.nextSearch=now+.25;self.searches=self.searches+1;self.best=nil;local near
   for _,s in ipairs(mobs.slots)do if s.active and not s.poof then local d=distance(self.feet,s.p)
    if d<=1200 and math.abs(self.feet.Z-s.p.Z)<220 and(not near or d<near)and mobs:los(env,p,{X=s.p.X,Y=s.p.Y,Z=s.p.Z+80})then self.best=s;self.bestGeneration=s.generation;near=d end
   end end
  end
  local best=self.best;local near=best and distance(self.feet,best.p)
  if not best or not best.active or best.poof or best.generation~=self.bestGeneration or near>1200 then
   self.best=nil;self.targetSerial=nil;self.pending=nil;self.emptySince=self.emptySince or now
   if self.controlled and now-self.emptySince>=2 then self.controlled=false;self.approachSerial=nil;mobs:event('pal_follow_release',nil,{pal=self.address,emptySeconds=now-self.emptySince})end
   return
  end
  self.emptySince=nil;self.controlled=true
  self.targetSerial=best.serial
  local dx,dy=best.p.X-p.X,best.p.Y-p.Y;local n=math.sqrt(dx*dx+dy*dy)
  if n<1 then return end
  local yaw=math.deg(math.atan(dy,dx));a:K2_SetActorRotation({Pitch=0,Yaw=yaw,Roll=0},true)
  if near>(golem and 280 or 850)then

   a:AddMovementInput({X=dx/n,Y=dy/n,Z=0},1,true)
   if self.approachSerial~=best.serial then self.approachSerial=best.serial;mobs:event('pal_approach',best,{pal=self.address,distance=near})end
  elseif now>=self.nextAttack and not self.pending then
   self.nextAttack=now+(golem and 1.75 or .95)
   local slot=ctx.UE.zombie77 and ctx.UE.zombie77.hosts[self.address]
   local m=not golem and self:montage(a)or nil
   if golem then
    if not nativeSlot then self.nextAttack=now+.5;return end
    ctx.UE.zombie77:beginAttack(nativeSlot,env,now,nil)
   else

   if slot then ctx.UE.zombie77:beginAttack(slot,env,now,nil)end
   if self.speciesP=='CP_Mossback'then
    local mesh=a.MossbackVisual
    if ctx.valid(mesh)then
     local name='AS_Mossback_Attack';local clip=ctx.UE.zombie77:asset('/Game/CustomPalsA1/'..name..'.'..name)
     a.A2HoldTicks=60;mesh:PlayAnimation(clip,false)
    end
   elseif m then
    local played=a:PlayAnimMontage(m,1,ctx.UE.FindOrAddFName('None'))
    if played<=0 and not slot then mobs:event('pal_animation_failed',best,{pal=self.address});self.nextAttack=now+3;return end
   elseif not slot then mobs:event('pal_animation_missing',best,{pal=self.address});self.nextAttack=now+3;return end
   if self.speciesP=='CP_FungalHost'and ctx.UE.customPalsA then ctx.UE.customPalsA.fx:queue(a,now)end
   end
   local c=a.CharacterParameterComponent;local stat=math.max(c:GetMeleeAttack(),c:GetShotAttack());local id=c:GetIndividualParameter():GetCharacterID():ToString()
   self.pending={slot=best,serial=best.serial,generation=best.generation,epoch=ctx.epoch(),address=self.address,identity=self.identity,at=now+(id=='MC_Creeper'and 1.5 or golem and .25 or .28),start=now,damage=math.max(1,math.floor(stat/25+.5)),stat=stat,id=id,montage=m and m:GetFullName()or'production costume swing',golem=golem}
   mobs:event('pal_attack',best,{pal=self.address,distance=near,montage=self.pending.montage,damage=self.pending.damage,cadence=golem and 1.75 or .95})
  end
 end
 function C:damage(a,s,env,fraction)
  if not current(env)or self.epoch~=ctx.epoch()then self:reset();return false end
  if not self.pal or not ctx.valid(a)or a:GetAddress()~=self.address then return false end
  local world=a:GetWorld();if not ctx.valid(world)or world:GetAddress()~=env.world:GetAddress()then return false end
  local c=a.CharacterParameterComponent;local damage=a.DamageReactionComponent;if not ctx.valid(c)or not ctx.valid(damage)then return false end;local before=c:GetHP().Value
  if before<=0 or c:IsDead()then return false end

  local max=c:GetMaxHP().Value;local amount=math.max(1,math.floor(max/1000*fraction+.5))
  damage:SlipDamage(amount,true,1,false)
  local after=c:GetHP().Value
  mobs:event('pal_damage',s,{pal=self.address,hp_before=before,hp_after=after,damage=amount,nativePath='PalDamageReactionComponent:SlipDamage',dead=c:IsDead()})
  if after>=before then ctx.log('MC59_NATIVE_DAMAGE_FAILED before='..before..' after='..after)end
  return after<before
 end
 function C:status()return{pal=self.address or false,identity=self.identity or false,epoch=self.epoch,frame=self.frame,target=self.targetSerial or false,pending=self.pending and self.pending.serial or false,nextAttack=self.nextAttack,controlled=self.controlled or false,emptySince=self.emptySince or false,searches=self.searches}end
 timers.onEpoch('pal-combat',function()C.playerPointZ3=nil;C.playerFeetZ3=nil;C.palPointZ3=nil;C.palFeetZ3=nil;C:reset();C.frame=nil;C.epoch=nil;C.playerPosition=nil;C.playerFeet=nil;C.playerAddress=nil;C.worldIdentity=nil;C.montages={}end)
 return C
end
