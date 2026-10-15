-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,costume)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local C={events={}};local function vec(v)return{X=v.X,Y=v.Y,Z=v.Z}end
 function C:event(kind,s,extra)
  local row=extra or{};row.event=kind;row.at=os.clock();row.host=s.address
  self.events[#self.events+1]=row;if #self.events>80 then table.remove(self.events,1)end
  ctx.log('MC103_CREEPER_'..kind..' host='..s.address..' at='..row.at)
 end
 function C:begin(s,e,now,action)
  if s.fuseStart then return end
  local target=action:GetActionTarget();if not valid(target)then return end
  local cp=target.CharacterParameterComponent
  if not valid(cp)or cp:IsDead()then return end

  action:EndAction();action.bIsEndAction=true
  local controller=s.host:GetController();if valid(controller)then controller:WaitForSeconds(2)end
  s.fuseStart=now;s.fuse103={start=now,epoch=T.epoch,target=target}
  self:event('FUSE',s,{nativeActionEnded=true,target=target:GetAddress(),targetHP=cp:GetHP().Value})
 end
 function C:clear(s)s.fuseStart=nil;s.fuse103=nil end
 function C:tick(s,e,now)
  local f=s.fuse103;if not f or f.epoch~=T.epoch then return end
  if s.sample and(s.sample.dead or s.sample.capturing)then self:clear(s);return end
  if not s.fuseStart or now-s.fuseStart<1.5 then return end
  s.fuseStart=nil;f.burst=now
  local p=s.host:K2_GetActorLocation()
  if UE.effects66 then UE.effects66:emit(e,'explosion',p)end
  ctx.sound:play('entity.creeper.explode',p,.8,e);self:event('BURST',s,{elapsed=now-f.start})
  local target=f.target;f.target=nil
  if not valid(target)then return end
  local world=target:GetWorld();local cp=target.CharacterParameterComponent
  if not valid(world)or world:GetAddress()~=e.world:GetAddress()or not valid(cp)or cp:IsDead()or cp:GetIsCapturedProcessing()then return end
  local q=target:K2_GetActorLocation()
  if(p.X-q.X)^2+(p.Y-q.Y)^2>500^2 or math.abs(p.Z-q.Z)>250 then self:event('DODGED',s);return end
  local obstruction={};local color={R=0,G=0,B=0,A=0}
  if _G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,p,q,0,false,{s.host,target},0,obstruction,true,color,color,0)then self:event('OCCLUDED',s);return end

  local info={Attacker=s.host,Defender=target,HitComponent=target.CapsuleComponent,Power=40,Category=0,Element=1,AttackType=0,WeaponType=0,
   HitLocation=vec(q),HitInfo={bBlockingHit=true,ImpactPoint=vec(q),Location=vec(q)},IsLeanBack=false,IsBlow=false,BlowVelocity={X=0,Y=0,Z=0},
   SneakAttackRate=1,DamageRatePerCollision=2/3,PvPBuildingDamageRate=1,PvPPlayerToGuildPalDamageRate=1,CollectionObjectDamageRate=1,WeaponDamageRatePvP=1,
   AttackStaticItemID=UE.FindOrAddFName('None'),bAttackableToFriend=false,IgnoreShield=false,CameraShake=1}
  local before=cp:GetHP().Value;f.delivered=true
  UE.Object('/Script/Pal.Default__PalUtility'):ProcessDamageAndPlayEffects(s.host,target,info)
  self:event('HIT',s,{elapsed=now-f.start,before=before,after=cp:GetHP().Value,power=info.Power})
 end
 T.onEpoch('creeper103',function()C.events={}end)
 return C
end
