-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,mobs)
 local UE,V=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local C={targets={},byAddress={},mobByAddress={},contacts={},skills={},nextSearch=0,searches=0}
 local function copy(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 local function dist(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)end
 local function live(e)return e and e.epoch==ctx.epoch()and mobs:guard(e)and V(e.world)end
 local function unwrap(v)if type(v)~='userdata'then return v end;local ok,r=pcall(function()return v:get()end);return ok and r or v end
 local function each(a,f)
  if type(a)=='table'then for _,v in ipairs(a)do f(unwrap(v))end else a:ForEach(function(_,v)f(v:get())end)end
 end
 function C:releaseMove()
  if self.controlled and V(self.controller)then self.controller:WaitForSeconds(0);self.controller:StopMovement()end
  self.controlled=false;self.controller=nil;self.best=nil;self.targetSerial=nil
 end
 function C:reset()
  
  self.pal=nil;self.address=nil;self.position=nil;self.feet=nil;self.speciesP=nil;self.refreshAt=nil
  self.targets={};self.byAddress={};self.mobByAddress={};self.contacts={};self.skills={};self.nextSearch=0;self.nextScan=0
  self.best=nil;self.targetSerial=nil;self.controlled=false;self.controller=nil;self.nextAttack=0;self.identity=nil
 end
 function C:admit(a,e)
  if not V(a)or not a:IsA(UE.Object('/Script/Pal.PalCharacter'))or a:GetAddress()==e.playerAddress or not a:GetActiveActorFlag()then return end
  local w=a:GetWorld();local cp=a.CharacterParameterComponent;local cap=a.CapsuleComponent
  if not V(w)or w:GetAddress()~=e.world:GetAddress()or not V(cp)or not V(cap)or cp:IsDead()or cp:GetHP().Value<=0 or cp:IsInactiveOtomo()then return end
  local p=copy(a:K2_GetActorLocation());local feet=copy(p);feet.Z=feet.Z-cap:GetScaledCapsuleHalfHeight()
  local row={actor=a,address=a:GetAddress(),position=p,feet=feet,radius=cap:GetScaledCapsuleRadius(),height=cap:GetScaledCapsuleHalfHeight()*2,parameter=cp}
  self.targets[#self.targets+1]=row;self.byAddress[row.address]=row;return row
 end
 function C:refresh(e)
  if not live(e)then self:reset();self.playerPosition=nil;return false end
  local now=os.clock();if self.refreshAt and now<self.refreshAt then return true end;self.refreshAt=now+.075;self.epoch=ctx.epoch()
  self.playerPosition=copy(e.player:K2_GetActorLocation());self.playerFeet=copy(self.playerPosition)
  self.playerFeet.Z=self.playerFeet.Z-e.player.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local holder=e.controller.BP_OtomoPalHolderComponent;local summoned=V(holder)and holder:TryGetSpawnedOtomo()or nil
  local address=V(summoned)and summoned:GetAddress()or nil
  if self.address~=address then self:releaseMove();self.skills={};self.nextAttack=0 end
  self.pal=nil;self.address=nil;self.position=nil;self.feet=nil;self.targets={};self.byAddress={}
  if ctx.config.pal_combat==false then return true end
  local row=self:admit(summoned,e)
  if row and not e.controller:IsRiding()then
   self.pal=summoned;self.address=row.address;self.position=row.position;self.feet=row.feet
   self.speciesP=row.parameter:GetIndividualParameter():GetCharacterID():ToString();self.identity=tostring(self.epoch)..':'..row.address
  end
  
  if now>=(self.nextScan or 0)then
   self.nextScan=now+.5;self.nearby={};local out={}
   _G.MC_OUT_K('SphereOverlapActors',UE.GetKismetSystemLibrary(),e.player,self.playerPosition,3200,{2},UE.Object('/Script/Pal.PalCharacter'),{e.player},out)
   local owner=e.controller:GetPalPlayerState().PlayerUId
   for _,v in ipairs(out)do local a=unwrap(v)
    if V(a)and V(a.CharacterParameterComponent)then
     local ip=a.CharacterParameterComponent:GetIndividualParameter();local g=V(ip)and ip.SaveParameter.OwnerPlayerUId
     if g and g.A==owner.A and g.B==owner.B and g.C==owner.C and g.D==owner.D and #self.nearby<8 then self.nearby[#self.nearby+1]=a end
    end
   end
  end
  for _,a in ipairs(self.nearby or{})do if V(a)and not self.byAddress[a:GetAddress()]then self:admit(a,e)end end
  return true
 end
 function C:target(s,e)
  if not self:refresh(e)then return end
  local a,p,feet,kind=e.player,self.playerPosition,self.playerFeet,'player';local nearest=dist(s.p,feet)
  for _,r in ipairs(self.targets)do local d=dist(s.p,r.feet)
   if d<nearest and d<=3200 and math.abs(s.p.Z-r.feet.Z)<400 then a,p,feet,kind,nearest=r.actor,r.position,r.feet,'pal',d end
  end
  local address=a:GetAddress()
  if s.targetAddress~=address then s.targetAddress=address;s.targetKind=kind;mobs:event('retarget',s,{target=kind,address=address,distance=nearest})end
  return a,p,feet,kind
 end
 function C:bind(s)
  local co
  each(s.actor:K2_GetComponentsByClass(UE.Object('/Script/Engine.CapsuleComponent')),function(v)
   if V(v)and v:ComponentHasTag(UE.FindOrAddFName('MCVAContact'))then co=v end
  end)
  if not V(co)then co=s.actor:AddComponentByClass(UE.Object('/Script/Engine.CapsuleComponent'),false,{Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=95},Scale3D={X=1,Y=1,Z=1}},false);co.ComponentTags={UE.FindOrAddFName('MCVAContact')}end
  co:SetMobility(2);co:K2_AttachToComponent(s.actor.RootComponent,UE.FindOrAddFName('None'),2,2,2,false)
  co:SetCollisionObjectType(2);co:SetCollisionResponseToAllChannels(1);co:SetGenerateOverlapEvents(true);co:SetCollisionEnabled(0)
  s.contactVA=co;self.mobByAddress[s.actor:GetAddress()]=s
 end
 function C:activate(s,on)
  if not V(s.contactVA)then return end
  if on then local d=mobs.defs[s.kind];local half=math.max(d.radius,d.height/2)
   s.contactVA:SetCapsuleSize(d.radius,half,false)
   _G.MC_OUT_K('K2_SetRelativeLocation',s.contactVA,{X=0,Y=0,Z=half},false,{},true)
  end
  s.contactVA:SetCollisionEnabled(on and 1 or 0);s.actor:SetActorEnableCollision(on)
 end
 function C:waza(id,e)
  if self.skills[id]then return self.skills[id]end
  local raw={};local util=UE.Object('/Script/Pal.Default__PalUtility')
  if not _G.MC_OUT_K('FindWazaForBP',util:GetWazaDatabase(e.player),id,raw)then return end
  local d={id=id,category=raw.Category,power=raw.Power or 20,min=raw.MinRange or 0,max=raw.MaxRange or 1200,cool=raw.CoolTime or 2}
  self.skills[id]=d;return d
 end
 function C:drain(e,now)
  local q=self.contacts;self.contacts={}
  for _,hit in ipairs(q)do local s=hit.slot;local r=self.byAddress[hit.attacker]
   if hit.epoch==self.epoch and s.active and not s.poof and s.generation==hit.generation and r and now-hit.at<.4 then
    local data=self:waza(hit.waza,e);local melee=data and data.category==0
    local reach=r.radius+mobs.defs[s.kind].radius+85;local distance=dist(r.feet,s.p)
    if (not melee or distance<=reach)and mobs:los(e,hit.point,{X=s.p.X,Y=s.p.Y,Z=s.p.Z+math.min(80,mobs.defs[s.kind].height/2)})then
     local stat=melee and r.parameter:GetMeleeAttack()or r.parameter:GetShotAttack()
     local damage=math.max(1,math.floor(stat/25*math.max(.25,(data and data.power or 20)/40)+.5))
     mobs:applyHit(s,e,now,'Pal:'..r.parameter:GetIndividualParameter():GetCharacterID():ToString(),damage,
      {latency=now-hit.at,palAttack=true,pal=hit.attacker,waza=hit.waza,nativeContact=true,contactComponent=hit.component,distance=distance,reach=melee and reach or nil},r.position,false,not melee)
    else mobs:event('pal_contact_rejected',s,{distance=distance,reach=reach,waza=hit.waza})end
   end
  end
 end
 function C:tick(e,now)
  if not self:refresh(e)then return end;self:drain(e,now)
  if mobs.test65 and(mobs.test65.feature=='bridge'or mobs.test65.mode~='attacking')then return end
  local a=self.pal;if not V(a)then return end
  local nativeSlot=UE.zombie77 and UE.zombie77.hosts[self.address]
  if nativeSlot and(nativeSlot.golemAc or nativeSlot.kind=='skeleton')then return end
  if now>=self.nextSearch then
   self.nextSearch=now+.25;self.searches=self.searches+1;self.best=nil;local nearest=1600
   for _,s in ipairs(mobs.slots)do if s.active and not s.poof then local d=dist(self.feet,s.p)
    if d<nearest and math.abs(self.feet.Z-s.p.Z)<300 then self.best=s;self.bestGeneration=s.generation;nearest=d end
   end end
  end
  local s=self.best
  if not s or not s.active or s.poof or s.generation~=self.bestGeneration then self:releaseMove();return end
  local ai=a:GetController();if not V(ai)then return end
  self.controller=ai;self.controlled=true;self.targetSerial=s.serial
  local near=dist(self.feet,s.p);local row=self.byAddress[self.address];local reach=row.radius+mobs.defs[s.kind].radius+40
  local skills={};each(a.CharacterParameterComponent:GetIndividualParameter():GetEquipWaza(),function(id)local d=self:waza(id,e);if d then skills[#skills+1]=d end end)
  local chosen
  for _,d in ipairs(skills)do if d.category~=2 and now>=(d.ready or 0)then
   if not chosen or(d.category==0 and near<=reach)or(chosen.category==0 and near>reach and d.category==1)then chosen=d end
  end end
  if not chosen then return end
  local max=chosen.category==0 and reach or math.min(1400,math.max(300,chosen.max))
  local point={X=s.p.X,Y=s.p.Y,Z=s.p.Z+80};local sight=mobs:los(e,self.position,point)
  if now>=(self.steerAt or 0)then
   self.steerAt=now+.4;ai:WaitForSeconds(1)
   if near>max or not sight then

    local acceptance=math.max(5,max-row.radius-60)
    local result=ai:PalMoveToLocation(copy(s.p),acceptance,false,true,true,false,nil,true)
    if result==0 and sight then result=ai:PalMoveToLocation(copy(s.p),acceptance,false,false,false,false,nil,false)end
    mobs:event('pal_approach',s,{pal=self.address,distance=near,reach=max,nativeMove=result})
   else ai:StopMovement()end
  end
  if near<=max and sight and now>=(self.nextAttack or 0)then
   local action=a:GetActionComponent();local active=V(action)and action:GetCurrentActionType(false)or 0
   if(active==0 and V(action:GetCurrentAction()))or active==3 or active==7 or active==8 or active==9 or active==10 or active==11 or active==12 then return end
   local yaw=math.deg(math.atan(s.p.Y-self.position.Y,s.p.X-self.position.X))
   ai:SetControlRotation({Pitch=0,Yaw=yaw,Roll=0});a:K2_SetActorRotation({Pitch=0,Yaw=yaw,Roll=0},true)
   local played=UE.Object('/Script/Pal.Default__PalUtility'):PlayActionByWazaID(a,s.actor,chosen.id)
   self.nextAttack=now+1;chosen.ready=now+math.max(1,chosen.cool)
   mobs:event('pal_attack',s,{pal=self.address,waza=chosen.id,category=chosen.category,distance=near,reach=max,played=played,damageOnlyOnNativeContact=true})
  end
 end
 function C:damage(a,s,e,fraction)
  if not live(e)or not V(a)then return false end
  local row=self.byAddress[a:GetAddress()];if not row then return false end
  local cp=row.parameter;local before=cp:GetHP().Value;if before<=0 then return false end
  local amount=math.max(1,math.floor(cp:GetMaxHP().Value/1000*fraction+.5));a.DamageReactionComponent:SlipDamage(amount,true,1,false)
  mobs:event('pal_damage',s,{pal=row.address,hp_before=before,hp_after=cp:GetHP().Value,damage=amount,nativePath='PalDamageReactionComponent:SlipDamage'})
  return cp:GetHP().Value<before
 end
 function C:status()return{pal=self.address or false,identity=self.identity,epoch=self.epoch,target=self.targetSerial,controlled=self.controlled,searches=self.searches,targets=#self.targets,queued=#self.contacts,skills=self.skills}end
 T.hook('/Script/Pal.PalHitFilter:OnBeginOverlap',function(context,my,other)
  local target=other:get();if not V(target)then return end;local s=C.mobByAddress[target:GetAddress()]
  if not s or not s.active or s.poof or #C.contacts>=64 then return end
  local filter=context:get();if not V(filter)or not filter:IsA(UE.Object('/Script/Pal.PalAttackFilter'))then return end
  local a=filter:GetAttacker();local component=my:get()
  if V(a)and C.byAddress[a:GetAddress()]and V(component)then

   C.contacts[#C.contacts+1]={slot=s,generation=s.generation,epoch=C.epoch,attacker=a:GetAddress(),waza=filter.Waza,point=copy(component:K2_GetComponentLocation()),component=component:GetFullName(),at=os.clock()}
  end
 end)
 T.onEpoch('pal-combat',function()C:reset();C.epoch=nil;C.nearby=nil;C.playerPosition=nil end)
 return C
end
