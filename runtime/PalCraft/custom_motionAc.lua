-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local UE,valid=ctx.UE,ctx.valid;local M={rows={},events={}}
 local function vec(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 local function xy(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)end
 local function event(kind,id,row)
  row.kind=kind;row.id=id;row.at=os.clock();M.events[#M.events+1]=row
  if #M.events>60 then table.remove(M.events,1)end
  ctx.log('MCAC_MOTION_'..kind..' id='..id)
 end
 function M:sample(a,e,id,slot)
  if not a:GetActiveActorFlag()or a.bHidden then self.rows[a:GetAddress()]=nil;return end
  if id=='MC_Warden'or id=='MC_Wither'or id=='MC_EnderDragon'then return end 
  local cp=a.CharacterParameterComponent
  if cp:IsDead()or cp:GetIsCapturedProcessing()then self.rows[a:GetAddress()]=nil;return end
  local world=a:GetWorld();if not valid(world)or world:GetAddress()~=e.world:GetAddress()then return end
  local p=a:K2_GetActorLocation();local now=os.clock();local key=a:GetAddress()
  local s=self.rows[key]
  if not s then s={p=vec(p),at=now,idle=now,wander=now+5+math.random()*4};self.rows[key]=s;return end
  local function skip(reason)s.reason=reason;return end
  if now<(s.sampleAt or 0)then return end;s.sampleAt=now+1
  local dt=now-s.at;local delta=xy(p,s.p);local measured=dt>0 and dt<2 and delta<1000 and delta/dt or 0
  s.p=vec(p);s.at=now
  local move=a.CharacterMovement;local v=move:GetVelocity();local speed=math.max(measured,math.sqrt(v.X*v.X+v.Y*v.Y))
  s.speed=speed
  if speed>8 then s.idle=now;return skip('moving')end
  local action=a:GetActionComponent();local current=valid(action)and action:GetCurrentAction()
  local kind=valid(current)and action:GetCurrentActionType(false)or 0
  s.action=kind
  if kind~=0 and not(kind>=16 and kind<=23)then s.idle=now;return skip('action:'..tostring(kind))end
  if move:IsMoveDisabled()or move:IsInputDisabled()then return skip('movement-disabled')end
  local ai=a:GetController();if not valid(ai)or not ai:IsA(UE.Object('/Script/Pal.PalAIController'))then return skip('controller')end
  local ac=ai:GetAIActionComponent();local parent=valid(ac)and ac:GetCurrentTopParentAction_BP()
  local name=valid(parent)and parent:GetClass():GetFullName()or''
  if name:find('Combat',1,true)or name:find('Work',1,true)or name:find('Escape',1,true)then return skip('ai:'..name)end
  if slot and(slot.flee101 or now<(slot.panicUntil or 0)or slot.golemAc)then return skip('combat-or-flee')end
  local owner=cp:GetIndividualParameter().SaveParameter.OwnerPlayerUId
  local owned=owner.A~=0 or owner.B~=0 or owner.C~=0 or owner.D~=0
  local q,mode
  if owned then
   local summoned=e.controller.BP_OtomoPalHolderComponent:TryGetSpawnedOtomo()
   if not valid(summoned)or summoned:GetAddress()~=key or cp:IsInactiveOtomo()then return end
   local player=e.player:K2_GetActorLocation();local distance=xy(p,player)
   if distance<600 or distance>6000 or now-s.idle<2 then return end
   q=vec(player);mode='FOLLOW'
  else
   if now<s.wander or now-s.idle<4 then return skip('wander-wait')end
   s.wander=now+5+math.random()*7;mode='WANDER'
   local island=ctx.island and ctx.island:at(p)
   if not island or not island.admitted or not island.footingReady then return skip('island-not-ready')end
   local ground=UE.zombie77.farmGround.data.islands[island.data.key or 'plains']
   if not ground then return skip('no-ground-cells')end
   local candidates={};local half=a.CapsuleComponent:GetScaledCapsuleHalfHeight()
   for _,cell in ipairs(ground.views or ground.cells)do
    local distance=xy(p,cell)
    if distance>=250 and distance<=600 and math.abs(cell.Z-(p.Z-half))<=60 then candidates[#candidates+1]=cell end
   end
   if #candidates==0 then return skip('no-local-ground-cell')end
   local cell=candidates[math.random(#candidates)];q={X=cell.X,Y=cell.Y,Z=cell.Z+half+3}
   s.nativeNav=ai:IsOnNavMesh();s.aiActive=ai:IsActiveAI()
   if not s.aiActive then ai:SetActiveAI(true);event('WAKE',id,{actor=key,nativeNav=s.nativeNav})end
  end

  local color={R=0,G=0,B=0,A=0};local half=a.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local ground={};local k=UE.GetKismetSystemLibrary()
  local ok=_G.MC_OUT_K('LineTraceSingle',k,e.player,{X=q.X,Y=q.Y,Z=q.Z+200},{X=q.X,Y=q.Y,Z=q.Z-half-300},0,false,{e.player,a},0,ground,true,color,color,0)
  if not ok or ground.ImpactNormal.Z<.65 or math.abs(ground.ImpactPoint.Z-(p.Z-half))>130 then return skip('floor')end
  if mode=='WANDER'then
   local c=ground.Component and ground.Component:Get()
   if not valid(c)or not ctx.island:owned(c:GetOwner())then return skip('unowned-floor')end
  end
  q.Z=ground.ImpactPoint.Z+half+3
  local blocked={};if _G.MC_OUT_K('LineTraceSingle',k,e.player,p,q,0,false,{e.player,a},0,blocked,true,color,color,0)then return skip('obstruction')end
  local middle={};if not _G.MC_OUT_K('LineTraceSingle',k,e.player,{X=(p.X+q.X)*.5,Y=(p.Y+q.Y)*.5,Z=p.Z+200},{X=(p.X+q.X)*.5,Y=(p.Y+q.Y)*.5,Z=p.Z-half-160},0,false,{e.player,a},0,middle,true,color,color,0)then return skip('midpoint-floor')end
  if middle.ImpactNormal.Z<.65 or math.abs(middle.ImpactPoint.Z-(p.Z-half))>100 then return skip('midpoint-step')end
  if move.MovementMode==0 then move:SetMovementMode(1,0)end
  if valid(ac)then ac:SetWalkSpeed_ForAIAction(owned and 2 or 1)end
  local result=ai:PalMoveToLocation(q,owned and 200 or 35,false,false,false,false,nil,false)
  s.last={at=now,mode=mode,result=result,goal=vec(q)};s.idle=now;s.reason='requested'
  if slot then slot.wanderB={untilAt=now+5,goal=vec(q)}end
  event(mode,id,{actor=key,result=result,origin=vec(p),goal=vec(q),priorSpeed=speed,nativeNav=ai:IsOnNavMesh()})
 end
 function M:reset()self.rows={};self.events={}end
 return M
end
