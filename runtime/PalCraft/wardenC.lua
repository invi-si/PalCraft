-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,Z)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua');local W={events={}}
 local function v(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 local function vec(x,y,z)return{X=x,Y=y,Z=z}end
 function W:event(kind,s,row)
  row=row or{};row.kind=kind;row.at=os.clock();row.host=s.address;self.events[#self.events+1]=row
  if #self.events>80 then table.remove(self.events,1)end;ctx.log('MCC_WARDEN_'..kind..' host='..s.address)
 end
 function W:engage(s,target,now)
  if s.kind~='warden'or not valid(target)or not valid(target.CharacterParameterComponent)then return end
  local e=ctx.environment();if e and valid(e.controller.Pawn)and e.controller.Pawn:GetAddress()==s.address then return end
  if s.wardenC and s.wardenC.epoch==T.epoch and valid(s.wardenC.target)and s.wardenC.target:GetAddress()==target:GetAddress()then return end
  s.wardenC={target=target,epoch=T.epoch,nextSlam=now,nextSonic=now+2};self:event('ENGAGE',s,{target=target:GetAddress()})
  ctx.sound:play('entity.warden.roar',s.host:K2_GetActorLocation(),1,ctx.environment())
 end
 function W:clear(s)
  local state=s.wardenC
  if state and state.epoch==T.epoch and valid(state.controller)then state.controller:WaitForSeconds(0);state.controller:StopMovement()end
  s.wardenC=nil;s.wardenPoseC=nil
  if self.beamOwner==s.address then self:hideBeam()end
 end
 function W:hideBeam()
  if valid(self.beam)then self.beam:SetActorHiddenInGame(true)end;self.beamUntil=nil;self.beamOwner=nil
 end
 function W:beamFX(s,e,p,q,now)
  if not valid(self.beam)then
   local tf={Rotation={X=0,Y=0,Z=0,W=1},Translation=p,Scale3D=vec(1,1,1)};local g=UE.Object('/Script/Engine.Default__GameplayStatics')
   self.beam=g:BeginDeferredActorSpawnFromClass(e.world,UE.Object('/Script/Engine.Actor'),tf,1,nil);self.beam=g:FinishSpawningActor(self.beam,tf)
   self.beam:AddComponentByClass(UE.Object('/Script/Engine.SceneComponent'),false,{Rotation=tf.Rotation,Translation=vec(0,0,0),Scale3D=vec(1,1,1)},false)
   self.beam:SetActorEnableCollision(false);self.beamParts={}
   for i=1,12 do
    local c=self.beam:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,{Rotation=tf.Rotation,Translation=vec(0,0,0),Scale3D=vec(1,1,1)},false)
    c:SetMobility(2);c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false);c:SetCastShadow(false);c:SetStaticMesh(Z:asset('/Game/MinecraftBossC/SM_WardenSonicC.SM_WardenSonicC'));self.beamParts[i]=c
   end
  end
  _G.MC_OUT_K('K2_SetActorLocation',self.beam,p,false,{},true)
  for i,c in ipairs(self.beamParts)do
   local f=i/12;_G.MC_OUT_K('K2_SetRelativeLocation',c,vec((q.X-p.X)*f,(q.Y-p.Y)*f,(q.Z-p.Z)*f),false,{},true)
   local size=.13+.12*math.sin(i*1.7)^2;c:SetRelativeScale3D(vec(size,size,size))
  end
  self.beam:SetActorHiddenInGame(false);self.beamUntil=now+.45;self.beamOwner=s.address
 end
 function W:damage(s,e,target,p,q,power,kind)
  if kind=='SONIC'then return Z.bossFA:hit(s,e,target,q,kind)end
  local color={R=0,G=0,B=0,A=0};local hit={}
  if _G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,p,q,0,false,{s.host,target},0,hit,true,color,color,0)then self:event('OCCLUDED',s,{attack=kind});return end
  return Z.bossFA:hit(s,e,target,q,kind)
 end
 function W:tick(s,e,now)
  if self.beamUntil and now>=self.beamUntil then self:hideBeam()end
  if valid(e.controller.Pawn)and e.controller.Pawn:GetAddress()==s.address then self:clear(s);Z.bossFA:ride(s,e,now);return end
  local g=s.wardenC;if not g then return end
  if g.epoch~=T.epoch or not valid(s.host)or not valid(s.parameter)or s.parameter:IsDead()or s.parameter:GetIsCapturedProcessing()or not s.host:GetActiveActorFlag()or s.host.bHidden then self:clear(s);return end
  local target=g.target;if not valid(target)then self:clear(s);return end
  local cp=target.CharacterParameterComponent;local world=target:GetWorld()
  if not valid(world)or world:GetAddress()~=e.world:GetAddress()or not valid(cp)or cp:IsDead()or cp:GetIsCapturedProcessing()then self:clear(s);return end
  local p,q=s.host:K2_GetActorLocation(),target:K2_GetActorLocation();local distance=math.sqrt((q.X-p.X)^2+(q.Y-p.Y)^2)
  Z.bossFA:darkness(s,e,target,now)
  if distance>2300 or math.abs(q.Z-p.Z)>600 then self:clear(s);return end
  local action=s.host:GetActionComponent();local kind=valid(action)and action:GetCurrentActionType(false)or 0
  if kind==3 or kind==7 or kind==8 or kind==9 then g.hitAt=nil;return end
  if now>=(g.steerAt or 0)then
   g.steerAt=now+.5;local ai=s.host:GetController()
   if valid(ai)then
    g.controller=ai;ai:WaitForSeconds(2);local yaw=math.deg(math.atan(q.Y-p.Y,q.X-p.X));ai:SetControlRotation({Pitch=0,Yaw=yaw,Roll=0});s.host:K2_SetActorRotation({Pitch=0,Yaw=yaw,Roll=0},true)
    if distance>300 and not g.hitAt then
     local blocked={};local color={R=0,G=0,B=0,A=0}
     if not _G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,p,q,0,false,{s.host,target},0,blocked,true,color,color,0)then
      local ac=ai:GetAIActionComponent();if valid(ac)then ac:SetWalkSpeed_ForAIAction(2)end;ai:PalMoveToLocation(v(q),270,false,false,false,false,nil,false)
     else ai:StopMovement()end
    else ai:StopMovement();s.host.CharacterMovement:StopMovementImmediately()end
   end
  end
  if g.hitAt and now>=g.hitAt then
   local attack=g.attack;g.hitAt=nil
   if attack=='SLAM'and distance<=370 and math.abs(q.Z-p.Z)<240 then self:damage(s,e,target,p,q,45,'SLAM');ctx.sound:play('entity.warden.attack',p,1,e)
   elseif attack=='SONIC'and distance<=2100 then
    local from=vec(p.X,p.Y,p.Z+30);self:beamFX(s,e,from,q,now);self:damage(s,e,target,from,q,55,'SONIC');ctx.sound:play('entity.warden.sonic_boom',p,1,e)
   else self:event('DODGED',s,{attack=attack,distance=distance})end
  end
  if not g.hitAt then
   if distance>430 and distance<=2100 and now>=g.nextSonic then
    g.attack='SONIC';g.hitAt=now+1.1;g.nextSonic=now+8;s.wardenPoseC={kind='SONIC',at=now};self:event('SONIC_CHARGE',s,{distance=distance});ctx.sound:play('entity.warden.sonic_charge',p,1,e)
   elseif distance<=370 and now>=g.nextSlam then
    g.attack='SLAM';g.hitAt=now+.45;g.nextSlam=now+2.4;s.wardenPoseC={kind='SLAM',at=now};self:event('SLAM',s,{distance=distance})
   end
  end
 end
 function W:ui(e,ns,U,unit,enabled)
  local engaged
  for _,s in ipairs(Z.slots)do if s.kind=='warden'and s.wardenC and valid(s.parameter)and not s.parameter:IsDead()and not s.parameter:GetIsCapturedProcessing()then engaged=s;break end end
  if not engaged and not ns.WardenNameC then return end
  local show=engaged and enabled;local names={'WardenBackC','WardenFillC','WardenNameC'}
  for _,key in ipairs(names)do local n=U:makeNode(ns,key,key=='WardenNameC'and'TextBlock'or'Image');n:SetRenderOpacity(show and 1 or 0);n.Slot:SetZOrder(92)end
  if not show then return end
  local hp=engaged.parameter:GetHP().Value;local max=engaged.parameter:GetMaxHP().Value;local ratio=math.max(0,math.min(1,hp/math.max(1,max)))
  local _,_,dpi,size=U:metrics(e);local y=20-size.Y/(unit*dpi)*.5
  U:brush(ns.WardenBackC,'T_MC_UI20_boss_background');U:position(ns.WardenBackC,-91,y,182,5,unit)
  U:brush(ns.WardenFillC,'T_MC_UI20_boss_progress');U:position(ns.WardenFillC,-91,y,182*ratio,5,unit)
  U:position(ns.WardenNameC,-140,y-12,280,11,unit);U:textStyle(ns.WardenNameC,unit,false);ns.WardenNameC:SetJustification(1)
  U:putText(ns.WardenNameC,(U.language57 and U.language57.lang=='ko'and'워든'or'Warden')..'  '..math.ceil(hp/1000)..' / '..math.ceil(max/1000))
 end
 T.onEpoch('wardenC',function()W.events={};W.beam=nil;W.beamParts=nil;W.beamUntil=nil;W.beamOwner=nil end)
 return W
end
