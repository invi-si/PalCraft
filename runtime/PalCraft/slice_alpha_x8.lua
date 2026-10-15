-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local D=dofile(ctx.base..'/slice_x8_data.lua').alpha
 local M={seen={},events={}};local valid=ctx.valid
 M.ownsFloor=function(a)return ctx.island:owned(a)end
 local function v(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 local function event(kind,a,target,extra)
  local row=extra or{};row.kind=kind;row.at=os.clock();row.actor=a:GetAddress();row.target=valid(target)and target:GetAddress()or false
  M.events[#M.events+1]=row;if #M.events>80 then table.remove(M.events,1)end
  ctx.log('MCFC_ALPHA_'..kind)
 end
 function M:forget()self.actor=nil;self.actorName=nil;self.target=nil;self.nextAttack=nil;self.steerAt=nil end
 function M:reset()self.seen={};self.events={};self:forget()end
 local function nearby(e)
  local p=e.player:K2_GetActorLocation();local q=D.ground
  return(p.X-q.X)^2+(p.Y-q.Y)^2<5000^2 and math.abs(p.Z-q.Z)<1800
 end
 local function alive(a,e)

  if not valid(a)or not a:IsA(ctx.UE.Object('/Script/Pal.PalCharacter'))then return false end
  if not a:GetActiveActorFlag()or a.bHidden or not valid(a.CharacterParameterComponent)then return false end
  local w=a:GetWorld();local cp=a.CharacterParameterComponent
  return valid(w)and w:GetAddress()==e.world:GetAddress()and not cp:IsDead()and not cp:GetIsCapturedProcessing()
 end
 local function clearLine(a,target,e)
  local hit={};local c={R=0,G=0,B=0,A=0}
  return not _G.MC_OUT_K('LineTraceSingle',ctx.UE.GetKismetSystemLibrary(),e.player,a:K2_GetActorLocation(),target:K2_GetActorLocation(),0,false,{a,target,e.player},0,hit,true,c,c,0)
 end

 function M:tick(e,now)

  if not nearby(e)then self:forget();return end
  local a=self.actor
  if not alive(a,e)or a:GetFullName()~=self.actorName then self:forget();return end
  local cp=a.CharacterParameterComponent;local ip=cp:GetIndividualParameter()
  if not valid(ip)or ip:GetCharacterID():ToString()~=D.id then self:forget();return end
  local owner=ip.SaveParameter.OwnerPlayerUId
  if owner.A~=0 or owner.B~=0 or owner.C~=0 or owner.D~=0 then self.target=nil;return end
  local p=a:K2_GetActorLocation();local candidates={e.player}
  local holder=e.controller.BP_OtomoPalHolderComponent
  local pal=valid(holder)and holder:TryGetSpawnedOtomo()or nil
  if alive(pal,e)then candidates[#candidates+1]=pal end
  local target,best
  for _,candidate in ipairs(candidates)do if alive(candidate,e)then
   local q=candidate:K2_GetActorLocation();local distance=(p.X-q.X)^2+(p.Y-q.Y)^2
   if distance<1600^2 and math.abs(p.Z-q.Z)<350 and(not best or distance<best)and clearLine(a,candidate,e)then target=candidate;best=distance end
  end end
  if not target then self.target=nil;return end
  if not valid(self.target)or self.target:GetAddress()~=target:GetAddress()then
   self.target=target;event('AGGRO',a,target)
   local ai=a:GetController();if valid(ai)then ai:AddTargetNPC(target);local hate=ai:GetHateSystem();if valid(hate)then hate:ChangeHate(target,1000)end end
  end
  local action=a:GetActionComponent();if not valid(action)then return end
  local kind=action:GetCurrentActionType(false)
  if kind==3 or kind==7 or kind==8 or kind==9 or kind==79 then return end
  local q=target:K2_GetActorLocation();local distance=math.sqrt(best);local yaw=math.deg(math.atan(q.Y-p.Y,q.X-p.X))
  if now>=(self.steerAt or 0)then
   self.steerAt=now+.5;local ai=a:GetController()
   if valid(ai)then
    ai:WaitForSeconds(2);ai:SetControlRotation({Pitch=0,Yaw=yaw,Roll=0});a:K2_SetActorRotation({Pitch=0,Yaw=yaw,Roll=0},true)
    if distance>220 then
     local ac=ai:GetAIActionComponent();if valid(ac)then ac:SetWalkSpeed_ForAIAction(2)end
     ai:PalMoveToLocation(v(q),180,false,false,false,false,nil,false)
    else ai:StopMovement()end
   end
  end
  local class=ctx.UE.customPalsA and ctx.UE.customPalsA.classes[D.id]
  if distance<=300 and now>=(self.nextAttack or 0)and valid(class)and kind~=11 and kind~=12 then
   self.nextAttack=now+2.4
   local result=action:PlayAction(target,class)
   event('ATTACK',a,target,{distance=distance,action=valid(result)and result:GetFullName()or false})
  end
 end
 function M:check(a,e,id)
  if id~=D.id or not nearby(e)then return end
  if not valid(a)or not a:IsA(ctx.UE.Object('/Script/Pal.PalCharacter'))then return end
  local island=ctx.island.all.plains
  if not island or not island.admitted or not island.footingReady then return end
  if not a:GetActiveActorFlag()or a.bHidden then return end
  local w=a:GetWorld();if not valid(w)or w:GetAddress()~=e.world:GetAddress()then return end
  local cp=a.CharacterParameterComponent;if not valid(cp)or cp:IsDead()or cp:GetIsCapturedProcessing()then return end
  local ip=cp:GetIndividualParameter();if not valid(ip)or ip:GetCharacterID():ToString()~=D.id then return end
  local owner=ip.SaveParameter.OwnerPlayerUId
  if owner.A~=0 or owner.B~=0 or owner.C~=0 or owner.D~=0 then return end
  local p=a:K2_GetActorLocation();local q=D.ground
  if(p.X-q.X)^2+(p.Y-q.Y)^2>2500^2 then return end
  local key=a:GetAddress();local half=a.CapsuleComponent:GetScaledCapsuleHalfHeight()
  self.actor=a;self.actorName=a:GetFullName()
  local first=not self.seen[key];local fallen=p.Z-half<q.Z-180
  if not first and not fallen then return end
  local hit={};local color={R=0,G=0,B=0,A=0}
  local ok=_G.MC_OUT_K('LineTraceSingle',ctx.UE.GetKismetSystemLibrary(),e.player,{X=q.X,Y=q.Y,Z=q.Z+40},{X=q.X,Y=q.Y,Z=q.Z-40},0,false,{e.player,a},0,hit,true,color,color,0)
  local c=ok and hit.Component:Get()or nil
  if not valid(c)or not ctx.island:owned(c:GetOwner())or hit.ImpactNormal.Z<.65 or math.abs(hit.ImpactPoint.Z-q.Z)>8 then return end
  if first and not fallen and math.abs(p.Z-half-q.Z)<15 then self.seen[key]=true;return end
  a.CharacterMovement:StopMovementImmediately()
  assert(_G.MC_OUT_K('K2_SetActorLocation',a,{X=q.X,Y=q.Y,Z=q.Z+half+3},false,{},true))
  a.CharacterMovement:SetMovementMode(1,0);self.seen[key]=true
  ctx.log('MCX8_ALPHA_GROUND '..(first and'spawn'or'fall')..' floor='..q.Z)
 end
 return M
end
