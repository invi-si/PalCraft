-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local C={};local timer=dofile(ctx.base..'/timers.lua');local J=dofile(ctx.base..'/json.lua')
 local function vec(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 local function write(d)local f=assert(io.open(ctx.base..'/task108c-walk.json','wb'));f:write(J.encode(d));f:close()end
 function C:start(e,target,options)
  local a=target or e.controller.BP_OtomoPalHolderComponent:TryGetSpawnedOtomo();assert(ctx.valid(a),'Summon costume before camera fixture')
  options=options or{}
  self.run={host=a,epoch=timer.epoch,start=os.clock(),rows={},next=0,custom=target~=nil,follow=options.follow,duration=options.duration or 12,distance=options.distance,heading=options.heading,fixedHeading=options.fixedHeading,actor=a:GetFullName(),id=a.CharacterParameterComponent:GetIndividualParameter():GetCharacterID():ToString(),playerStart=vec(e.player:K2_GetActorLocation())};ctx.log('MC108C_CAMERA_STARTED')
 end
 function C:stop(e)
  if self.run then self.run.host=nil;write(self.run);self.run=nil end
  e.controller:SetViewTargetWithBlend(e.player,0,0,0,false);ctx.log('MC108C_CAMERA_DONE')
 end
 timer.frame('task108c-costume-camera',function(_,now)
  local s=C.run;if not s then return end
  if s.epoch~=timer.epoch then C.run=nil;return end
  local e=ctx.environment();if not e or not ctx.valid(s.host)then return end
  now=os.clock();local elapsed=now-s.start
  if elapsed>s.duration then C:stop(e);return end
  local p=s.host:K2_GetActorLocation();local yaw=s.host:K2_GetActorRotation().Yaw
  local slot=ctx.UE.zombie77.hosts[s.host:GetAddress()]
  local half=slot and(slot.definition.half or 97.5)or(s.custom and s.host.CapsuleComponent:GetScaledCapsuleHalfHeight()or 97.5)
  p.Z=p.Z-s.host.CapsuleComponent:GetScaledCapsuleHalfHeight()+half
  local angle=math.rad(s.fixedHeading or(s.follow and((s.heading or yaw)+100)or(yaw+(elapsed<5 and 90 or 155))));local distance=s.distance or math.max(440,half*3.4)
  local q={X=p.X+math.cos(angle)*distance,Y=p.Y+math.sin(angle)*distance,Z=p.Z+45}
  local dx,dy,dz=p.X-q.X,p.Y-q.Y,p.Z-q.Z
  ctx.UE.task65:setCamera(e,q,math.deg(math.atan(dy,dx)),math.deg(math.atan(dz,distance)))
  if now>=s.next then
   s.next=now+.2
   local move=s.host.CharacterMovement;local player=e.player:K2_GetActorLocation();local action=s.host:GetActionComponent():GetCurrentAction()
   local ai=s.host:GetController();local row={at=elapsed,position=vec(p),yaw=yaw,velocity=vec(s.host:GetVelocity()),componentVelocity=vec(move:GetVelocity()),rawVelocity=vec(move.Velocity),movement=move.MovementMode,maxSpeed=move.MaxWalkSpeed,moveDisabled=move:IsMoveDisabled(),inputDisabled=move:IsInputDisabled(),player=vec(player),playerVelocity=vec(e.player.CharacterMovement:GetVelocity()),camera=vec(q),view=s.follow and'side-follow'or(elapsed<5 and'side'or'rear-quarter'),costumeFrame=slot and slot.visualAt,action=ctx.valid(action)and action:GetClass():GetFullName()or'',active=s.host:GetActiveActorFlag(),capturing=s.host.CharacterParameterComponent:GetIsCapturedProcessing(),controller=ctx.valid(ai)and ai:GetFullName()}
   if ctx.valid(ai)and ai:IsA(ctx.UE.Object('/Script/Pal.PalAIController'))then
    row.aiActive=ai:IsActiveAI();row.onNavMesh=ai:IsOnNavMesh();local component=ai:GetAIActionComponent();local a=ctx.valid(component)and component:GetCurrentAction_BP();row.aiAction=ctx.valid(a)and a:GetClass():GetFullName()
   end
   if s.id=='CP_Mossback'then row.visualState=s.host.A1State end
   s.rows[#s.rows+1]=row
  end
 end)
 return C
end
