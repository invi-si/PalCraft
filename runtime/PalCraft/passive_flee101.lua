-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
 local F={};local valid,UE=ctx.valid,ctx.UE
 local passive={MC_Horse=true,MC_Camel=true,MC_Fox=true,MC_Rabbit=true,MC_Cat=true,MC_Cow=true,MC_Pig=true,MC_Sheep=true,MC_Mooshroom=true,MC_Chicken=true}
 local function copy(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 function F:release(s)
  local old=s.fleeRotation101
  if old and valid(s.host)then
   s.host.bUseControllerRotationYaw=old.controllerYaw
   local movement=s.host.CharacterMovement
   movement.bOrientRotationToMovement=old.orient
   movement.bUseControllerDesiredRotation=old.desired
  end
  if old and valid(s.root)then
   s.root:SetAbsolute(false,s.lookAbsoluteT or false,false)
   _G.MC_OUT_K('K2_SetRelativeRotation',s.root,{Pitch=0,Yaw=0,Roll=0},false,ignoredHitJ(),true)
  end
  if s.passive101 and valid(s.host)then
   local controller=s.host:GetController()
   if valid(controller)then controller:WaitForSeconds(0)end
  end
  s.passive101=nil;s.fleeRotation101=nil;s.flee101=nil
 end
 function F:suppress(s,controller,now,force)

  local hold=s.passive101
  if force or not hold or(now>=hold.refreshAt and not s.flee101 and not(s.wanderB and now<s.wanderB.untilAt))then
   controller:WaitForSeconds(6)
   s.passive101={mode='timed-native-wait',refreshAt=now+1,untilAt=now+6}
   if not hold then ctx.log('MC101B_PASSIVE id='..s.species..' mode=timed-native-wait')end
  end
 end
 function F:sample(s,e,now,hp,dead,capturing,p)
  if not passive[s.species]then return end
  local controller=s.host:GetController()
  local owner=s.parameter:GetIndividualParameter().SaveParameter.OwnerPlayerUId
  local owned=owner.A~=0 or owner.B~=0 or owner.C~=0 or owner.D~=0
  if dead or capturing or owned then self:release(s);return end
  if not valid(controller)then self:release(s);return end
  self:suppress(s,controller,now)
  if s.lastHP and hp<s.lastHP then
   local utility=UE.Object('/Script/Pal.Default__PalUtility')
   local attackerParameter=utility:GetIndividualCharacterParameterByIstanceID(e.player,s.host.DamageReactionComponent:GetLastAttackerInstanceID())
   local attacker=valid(attackerParameter)and attackerParameter:GetIndividualActor()or nil
   if not valid(attacker)then return end 
   local q=attacker:K2_GetActorLocation();local dx,dy=p.X-q.X,p.Y-q.Y;local length=math.sqrt(dx*dx+dy*dy)
   if length<1 then return end
   local goal={X=p.X+dx/length*1000,Y=p.Y+dy/length*1000,Z=p.Z}

   self:suppress(s,controller,now,true)
   controller:GetAIActionComponent():SetWalkSpeed_ForAIAction(2)
   local result=controller:PalMoveToLocation(goal,30,false,false,false,false,nil,false)
   local movement=s.host.CharacterMovement
   s.fleeRotation101=s.fleeRotation101 or{controllerYaw=s.host.bUseControllerRotationYaw,orient=movement.bOrientRotationToMovement,desired=movement.bUseControllerDesiredRotation}
   s.host.bUseControllerRotationYaw=false;movement.bOrientRotationToMovement=true;movement.bUseControllerDesiredRotation=false
   s.root:SetAbsolute(false,true,false)
   s.flee101={started=now,untilAt=now+5,origin=copy(p),attacker=copy(q),goal=goal,result=result,yaw=math.deg(math.atan(dy,dx))}
   s.lastFlee101=s.flee101
   ctx.log('MC101_FLEE_START id='..s.species..' hp='..hp..' request='..tostring(result))
  end
  local flee=s.flee101
  if flee then
   flee.position=copy(p);flee.distance=math.sqrt((p.X-flee.origin.X)^2+(p.Y-flee.origin.Y)^2)
   local v=s.host:GetVelocity()
   if v.X*v.X+v.Y*v.Y>100 then flee.yaw=math.deg(math.atan(v.Y,v.X))end
   local rotation={Pitch=0,Yaw=flee.yaw,Roll=0}
   controller:K2_ClearFocus();controller:SetControlRotation(rotation)
   s.host:K2_SetActorRotation(rotation,true)
   _G.MC_OUT_K('K2_SetWorldRotation',s.root,rotation,false,ignoredHitJ(),true)
   if now>=flee.untilAt then
    controller:StopMovement()
    flee.finished=now;self:release(s);self:suppress(s,controller,now,true)
    ctx.log('MC101_FLEE_END id='..s.species..' distance='..flee.distance)
   end
  end
 end
 return F
end
