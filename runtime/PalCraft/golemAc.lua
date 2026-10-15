-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,Z)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua');local G={events={}}
 local function vec(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 local hostiles={zombie=true,skeleton=true,spider=true,creeper=true,husk=true,witch=true,slime=true,enderman=true}
 function G:select(s,e,now)
  if now<(s.golemSearchP or 0)then return end;s.golemSearchP=now+.5
  if not valid(s.host)or not valid(s.parameter)or s.parameter:IsDead()or s.parameter:GetIsCapturedProcessing()or s.host.bHidden or not s.host:GetActiveActorFlag()then return end
  local p=s.host:K2_GetActorLocation();local pp=e.player:K2_GetActorLocation()
  if(p.X-pp.X)^2+(p.Y-pp.Y)^2>5000^2 then self:clear(s);return end
  local best,nearest
  for _,other in ipairs(Z.slots or{})do
   if other~=s and hostiles[other.kind]and valid(other.host)and valid(other.parameter)and not other.owned108 and not other.recall108 and not other.parameter:IsDead()and not other.parameter:GetIsCapturedProcessing()and other.host:GetActiveActorFlag()and not other.host.bHidden then
    local q=other.host:K2_GetActorLocation();local d=(p.X-q.X)^2+(p.Y-q.Y)^2
    if d<=1200^2 and math.abs(p.Z-q.Z)<300 and(not nearest or d<nearest)then
     local hit={};local c={R=0,G=0,B=0,A=0}
     if not _G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,p,q,0,false,{s.host,other.host},0,hit,true,c,c,0)then best=other.host;nearest=d end
    end
   end
  end
  if best then
   local old=s.golemAc
   if not old or not valid(old.target)or old.target:GetAddress()~=best:GetAddress()then
    local ai=s.host:GetController()
    if valid(ai)then ai:AddTargetNPC(best);local hate=ai:GetHateSystem();if valid(hate)then hate:ChangeHate(best,100)end end
    self:engage(s,best,now);self:event('AUTOTARGET',s,{target=best:GetAddress(),distance=math.sqrt(nearest),native=true})
   end
  end
 end
 function G:event(kind,s,row)
  row=row or{};row.kind=kind;row.at=os.clock();row.host=s.address;self.events[#self.events+1]=row
  if #self.events>80 then table.remove(self.events,1)end
  ctx.log('MCAC_GOLEM_'..kind..' host='..tostring(s.address))
 end
 function G:engage(s,target,now)
  if not valid(target)or not valid(target.CharacterParameterComponent)then return end
  local old=s.golemAc
  if old and old.epoch==T.epoch and valid(old.target)and old.target:GetAddress()==target:GetAddress()then old.seen=now;return end
  s.golemAc={target=target,epoch=T.epoch,next=now,seen=now};self:event('ENGAGE',s,{target=target:GetAddress()})
 end
 function G:clear(s)
  local g=s.golemAc
  if g and g.epoch==T.epoch and valid(g.controller)then
   g.controller:WaitForSeconds(0);g.controller:StopMovement()
  end
  s.golemAc=nil
 end
 function G:tick(s,e,now)
  self:select(s,e,now)
  local g=s.golemAc;if not g then return end
  if g.epoch~=T.epoch or not valid(s.host)or not valid(s.parameter)or s.parameter:IsDead()or s.parameter:GetIsCapturedProcessing()or not s.host:GetActiveActorFlag()then self:clear(s);return end
  local target=g.target;if not valid(target)then self:clear(s);return end
  local cp=target.CharacterParameterComponent;local world=target:GetWorld()
  if not valid(world)or world:GetAddress()~=e.world:GetAddress()or not valid(cp)or cp:IsDead()or cp:GetIsCapturedProcessing()then self:clear(s);return end
  local p,q=s.host:K2_GetActorLocation(),target:K2_GetActorLocation()
  local distance=math.sqrt((q.X-p.X)^2+(q.Y-p.Y)^2)
  if distance>1200 or math.abs(q.Z-p.Z)>500 then self:clear(s);return end

  local action=s.host:GetActionComponent()
  local kind=valid(action)and action:GetCurrentActionType(false)or 0
  if kind==3 or kind==7 or kind==8 or kind==9 or kind==79 then return end
  if now>=(g.steerAt or 0)then
   g.steerAt=now+.5;local ai=s.host:GetController()
   if valid(ai)then
    g.controller=ai;ai:WaitForSeconds(2)
    local yaw=math.deg(math.atan(q.Y-p.Y,q.X-p.X))
    ai:SetControlRotation({Pitch=0,Yaw=yaw,Roll=0})
    s.host:K2_SetActorRotation({Pitch=0,Yaw=yaw,Roll=0},true)
    if distance>260 then
     local hit={};local color={R=0,G=0,B=0,A=0}
     if not _G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,p,q,0,false,{s.host,target},0,hit,true,color,color,0)then
      local ac=ai:GetAIActionComponent();if valid(ac)then ac:SetWalkSpeed_ForAIAction(2)end
      g.moveResult=ai:PalMoveToLocation(vec(q),240,false,false,false,false,nil,false)
     else ai:StopMovement()end
    else ai:StopMovement();s.host.CharacterMovement:StopMovementImmediately()end
   end
  end
  if g.hitAt and now>=g.hitAt then
   g.hitAt=nil
   if distance<=320 and math.abs(q.Z-p.Z)<=220 then
    local hit={};local color={R=0,G=0,B=0,A=0}
    if not _G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,p,q,0,false,{s.host,target},0,hit,true,color,color,0)then
     local info={Attacker=s.host,Defender=target,HitComponent=target.CapsuleComponent,Power=40,Category=0,Element=1,AttackType=0,WeaponType=0,
      HitLocation=vec(q),HitInfo={bBlockingHit=true,ImpactPoint=vec(q),Location=vec(q)},IsLeanBack=false,IsBlow=false,BlowVelocity={X=0,Y=0,Z=0},
      SneakAttackRate=1,DamageRatePerCollision=1,PvPBuildingDamageRate=1,PvPPlayerToGuildPalDamageRate=1,CollectionObjectDamageRate=1,WeaponDamageRatePvP=1,
      AttackStaticItemID=UE.FindOrAddFName('None'),bAttackableToFriend=false,IgnoreShield=false,CameraShake=1}
     local before=cp:GetHP().Value
     UE.Object('/Script/Pal.Default__PalUtility'):ProcessDamageAndPlayEffects(s.host,target,info)
     self:event('HIT',s,{swing=g.swing,before=before,after=cp:GetHP().Value,distance=distance})
    else self:event('OCCLUDED',s)end
   else self:event('DODGED',s,{distance=distance})end
  end
  if now>=g.next and distance<=320 and math.abs(q.Z-p.Z)<=220 then
   local previous=g.swing;g.swing=now;g.next=now+1.75;g.hitAt=now+.25
   Z:beginAttack(s,e,now,nil);s.aggressive=true
   self:event('SWING',s,{interval=previous and now-previous,target=target:GetAddress(),distance=distance})
  end
 end
 T.onEpoch('golemAc',function()G.events={}end)
 return G
end
