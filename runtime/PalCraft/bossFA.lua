-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,Z)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local F={events={},calibration={}};local levels={MC_Wither=35,MC_Warden=40,MC_EnderDragon=50}
 local damage={SKULL=8,BLUE_SKULL=12,DASH=8,SLAM=30,SONIC=10,CHARGE=10,BREATH=6,PERCH_BREATH=6,WING=5,WITHER_DOT=1}
 function F:event(kind,s,d)
  d=d or{};d.kind=kind;d.species=s.species;d.host=s.address;d.at=os.clock()
  self.events[#self.events+1]=d;if #self.events>160 then table.remove(self.events,1)end
  ctx.log('MCFA_BOSS_'..kind..' species='..s.species)
 end
 function F:hit(s,e,target,q,kind)
  if not valid(target)or not valid(target.CharacterParameterComponent)then return false end
  local cp=target.CharacterParameterComponent;if cp:IsDead()or cp:GetIsCapturedProcessing()then return false end
  local w=target:GetWorld();if not valid(w)or w:GetAddress()~=e.world:GetAddress()then return false end
  local level=levels[s.species]or s.parameter:GetIndividualParameter():GetLevel()

  local hpBasis=500;local mc=assert(damage[kind],kind);local desired=mc/20*hpBasis
  local before=cp:GetHP().Value;local ip=cp:GetIndividualParameter();local shieldBefore=valid(ip)and ip:GetShieldHP().Value or 0;local power
  if kind=='SONIC'or kind=='WITHER_DOT'then
   target.DamageReactionComponent:SlipDamage(math.max(1,math.floor(desired+.5)),true,1,false)
  else
   local stat=s.parameter:GetMeleeAttack();local key=s.species..':'..level..':'..stat
   local unit=self.calibration[key]
   local u=UE.Object('/Script/Pal.Default__PalUtility')
   if not unit then
    local info={Attacker=s.host,AttackerLevel=level,BasePower=100,NativeDamageValue=10000,bApplyNativeDamageValue=false,Category=0,AttackType=0,AttackElementType=1,WeaponType=0,BodyPartsType=1,
     DamageRatePerCollision=1,SneakAttackRate=1,PvPBuildingDamageRate=1,PvPPlayerToGuildPalDamageRate=1,CollectionObjectDamageRate=1,WeaponDamageRatePvP=1}
    local out={}
    local ok,result=pcall(_G.MC_OUT_K,'CalcDamageCharacter',u,info,target,{OtomoRate=1,DefenderLevel=level,DefenderDefence=100,DefenderElementType1=0,DefenderElementType2=0,ElementStatusMultiplay=1},out)
    if not ok or type(result)~='number'or result<=1 then self:event('CALIBRATION_FAILED',s,{reason=tostring(result)});return false end
    unit=result
    self.calibration[key]=unit;self:event('CALIBRATION',s,{level=level,hpBasis=hpBasis,referenceDefence=100,raw10000=unit,attack=stat})
   end
   power=math.max(1,math.floor(10000*desired/unit+.5))
   local v={X=q.X,Y=q.Y,Z=q.Z};local dx,dy=q.X-s.host:K2_GetActorLocation().X,q.Y-s.host:K2_GetActorLocation().Y
   local n=math.max(1,math.sqrt(dx*dx+dy*dy))
   local group=s.parameter:GetIndividualParameter():GetGroupId()
   local info={Attacker=s.host,AttackerGroupID={A=group.A,B=group.B,C=group.C,D=group.D},AttackerLevel=level,BasePower=100,NativeDamageValue=power,bApplyNativeDamageValue=false,Category=0,AttackElementType=1,AttackType=0,WeaponType=0,BodyPartsType=1,
    HitLocation=v,IsLeanBack=false,IsBlowAttack=kind=='WING',BlowVelocity={X=dx/n*400,Y=dy/n*400,Z=kind=='WING'and 150 or 0},
    SneakAttackRate=1,DamageRatePerCollision=1,PvPBuildingDamageRate=1,PvPPlayerToGuildPalDamageRate=1,CollectionObjectDamageRate=1,WeaponDamageRatePvP=1,
    AttackStaticItemID=UE.FindOrAddFName('None'),bAttackableToFriend=false,IgnoreShield=false,CameraShake=0,bIsExplosionDamage=kind=='SKULL'or kind=='BLUE_SKULL'}
   u:ProcessDamageAndPlayEffectsByDamageInfo(s.host,target,info,true,0)
  end
  local after=cp:GetHP().Value;local shieldAfter=valid(ip)and ip:GetShieldHP().Value or 0;local actual=(before-after+shieldBefore-shieldAfter)/1000
  self:event(kind..'_HIT',s,{before=before,after=after,shieldBefore=shieldBefore,shieldAfter=shieldAfter,actual=actual,mcDamage=mc,fraction=mc/20,hpBasis=hpBasis,nominal=desired,power=power,defence=cp:GetDefense(),ignoreDefence=kind=='SONIC'or kind=='WITHER_DOT'})
  if actual>0 and(kind=='SKULL'or kind=='BLUE_SKULL')then
   s.witherDotFA={target=target,epoch=T.epoch,next=os.clock()+2,untilAt=os.clock()+10};self:event('WITHER',s,{seconds=10,interval=2})
  end
  return actual>0
 end
 function F:dot(s,e,now)
  local d=s.witherDotFA;if not d then return end
  if d.epoch~=T.epoch or now>=d.untilAt or not valid(d.target)or not valid(s.host)or s.parameter:IsDead()then s.witherDotFA=nil;return end
  if now>=d.next then d.next=now+2;self:hit(s,e,d.target,d.target:K2_GetActorLocation(),'WITHER_DOT')end
 end
 function F:darkness(s,e,target,now)
  if now<(s.darknessAtFA or 0)or not valid(target.StatusComponent)then return end
  s.darknessAtFA=now+10;local st=target.StatusComponent
  if not valid(st:GetExecutionStatus(25))then st:AddStatus(25)end
  local status=st:GetExecutionStatus(25);if valid(status)then status.Duration=5;self:event('DARKNESS',s,{seconds=5,target=target:GetAddress()})end
 end
 function F:ride(s,e,now)
  if e.controller.bShowMouseCursor then return end
  local r=s.rideFA
  if not r or r.epoch~=T.epoch then
   r={epoch=T.epoch,next={},down={},keys={}};s.rideFA=r
   for i,default in ipairs({'LeftMouseButton','E','C'})do
    local config=e.controller.PlayerInput:GetActionConfigKeys(UE.FindOrAddFName('RidingSkill'..i),0)
    local name=config.MainKey.KeyName:ToString();if name=='None'then name=default end
    r.keys[i]={KeyName=UE.FindOrAddFName(name)}
   end
  end
  if r.sonicAt and now>=r.sonicAt then
   r.sonicAt=nil
   if valid(r.target)then local q=r.target:K2_GetActorLocation();Z.wardenC:beamFX(s,e,s.host:K2_GetActorLocation(),q,now);self:hit(s,e,r.target,q,'SONIC');self:darkness(s,e,r.target,now)end
  end
  for i,k in ipairs(r.keys)do
   local down=e.controller:IsInputKeyDown(k)
   if down and now>=(r.next[i]or 0)then
    r.next[i]=now+(i==1 and 3 or 8)
    local cam=e.controller.PlayerCameraManager;local p=cam:GetCameraLocation();local rot=cam:GetCameraRotation()
    local y,t=math.rad(rot.Yaw),math.rad(rot.Pitch);local d={X=math.cos(y)*math.cos(t),Y=math.sin(y)*math.cos(t),Z=math.sin(t)}
    local q={X=p.X+d.X*8000,Y=p.Y+d.Y*8000,Z=p.Z+d.Z*8000};local hit={};local c={R=0,G=0,B=0,A=0}
    local found=_G.MC_OUT_K('SphereTraceSingleForObjects',UE.GetKismetSystemLibrary(),s.host,p,q,100,{2},false,{s.host,e.player},0,hit,true,c,c,0)
    local comp=found and hit.Component:Get();local target=valid(comp)and comp:GetOwner()or nil
    if valid(target)and target~=s.host and target~=e.player and valid(target.CharacterParameterComponent)and not target.CharacterParameterComponent:IsDead()then q=target:K2_GetActorLocation()else target=nil end
    self:event('RIDE_ABILITY',s,{slot=i,key=k.KeyName:ToString(),target=target and target:GetAddress()or false})
    if s.kind=='warden'then
     local point=s.host:K2_GetActorLocation()
     if i==1 then
      Z:beginAttack(s,e,now,nil);s.wardenPoseC={kind='SLAM',at=now}
      if target and(point.X-q.X)^2+(point.Y-q.Y)^2<=550^2 then self:hit(s,e,target,q,'SLAM')end
     else
      r.sonicAt=now+1.1;r.target=target;s.wardenPoseC={kind='SONIC',at=now};self:event('SONIC_CHARGE',s,{ridden=true});ctx.sound:play('entity.warden.sonic_charge',point,1,e)
      if not target then Z.wardenC:beamFX(s,e,point,q,now)end
     end
    else
     local g=Z.bossD:state(s,now);g.riddenFA=true;g.target=target
     if i<3 then Z.bossD:skull(s,e,q,now,s.kind=='wither'and i==2)
     elseif s.kind=='wither'then
      local point=s.host:K2_GetActorLocation();s.host.CharacterMovement:AddImpulse({X=d.X*1000,Y=d.Y*1000,Z=d.Z*1000},true)
      self:event('DASH',s,{ridden=true});if target and(point.X-q.X)^2+(point.Y-q.Y)^2<600^2 then self:hit(s,e,target,q,'DASH')end
     else
      local point=s.host:K2_GetActorLocation();local cloud={X=point.X+d.X*500,Y=point.Y+d.Y*500,Z=point.Z-s.capsule:GetScaledCapsuleHalfHeight()+30}
      g.cloud={position=cloud,untilAt=now+5,nextHit=now,target=target};Z.bossD:fx(s,e,cloud,true,now,5);self:event('PERCH_BREATH',s,{ridden=true})
     end
    end
   end
   r.down[i]=down
  end
 end
 
 local function armor(_,attacker,defender,remote)
  if not ctx.ready()then return end
  local target=defender:get();if not valid(target)then return end
  local s=Z.hosts[target:GetAddress()]
  if not s or s.species~='MC_Wither'or not valid(s.parameter)or s.parameter:GetHP().Value>s.parameter:GetMaxHP().Value*.5 then return end
  local info=remote:get()
  if info.WeaponType==8 or info.WeaponType==9 then info.NoDamage=true;F:event('ARROW_IMMUNE',s,{weapon=info.WeaponType})end
 end
 T.hook('/Script/Pal.PalUtility:ProcessDamageAndPlayEffects',armor)
 T.hook('/Script/Pal.PalUtility:ProcessDamageAndPlayEffectsByDamageInfo',armor)
 T.onEpoch('bossFA',function()F.events={};F.calibration={}end)
 return F
end
