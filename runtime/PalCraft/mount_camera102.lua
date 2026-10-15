-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
 local V={};local UE,valid=ctx.UE,ctx.valid
 local lag=dofile(ctx.base..'/camera_lagT.lua')
 local orbit=dofile(ctx.base..'/orbitZ1.lua')
 local bossById={};for _,spec in pairs(dofile(ctx.base..'/boss_mountI.lua'))do bossById[spec.id]=spec end
 local function vec(v)return{X=v.X,Y=v.Y,Z=v.Z}end
 local function rot(v)return{Pitch=v.Pitch,Yaw=v.Yaw,Roll=v.Roll}end
 local flags={'TargetArmLength','bDoCollisionTest','bEnableCameraLag','bEnableCameraRotationLag','bUsePawnControlRotation','bInheritRoll'}
 function V:forget()self.lease=nil;self.footRecalibrate=nil end
 function V:release(reason,riding)
  local s=self.lease;self.lease=nil;if not s then return end
  if s.epoch~=ctx.epoch()then return end
  if valid(s.camera)and valid(s.parent)then
   s.camera:K2_AttachToComponent(s.parent,s.socket,2,2,2,false)
   _G.MC_OUT_K('K2_SetRelativeLocation',s.camera,s.location,false,ignoredHitJ(),true)
   _G.MC_OUT_K('K2_SetRelativeRotation',s.camera,s.rotation,false,ignoredHitJ(),true)
   s.camera:SetRelativeScale3D(s.scale)
   s.camera.bUsePawnControlRotation=s.control
  end
  if valid(s.boom)then
   for name,value in pairs(s.flags)do s.boom:SetPropertyValue(name,value)end
   s.boom:SetComponentTickEnabled(s.tick)
  end
  if valid(s.controller)and valid(s.player)then
   local current=s.controller.PlayerCameraManager.ViewTarget.Target
   if valid(current)and current:GetAddress()==s.player:GetAddress()then

    local target=riding and valid(s.nativeTarget)and s.nativeTarget or s.player
    s.controller:SetViewTargetWithBlend(target,0,0,0,false)
   end
  end
  self.lastRelease={reason=reason,epoch=s.epoch,restored=true,arm=valid(s.boom)and s.boom.TargetArmLength,collision=valid(s.boom)and s.boom.bDoCollisionTest}
  if reason=='dismount'then self.footRecalibrate=os.clock()+.2 end
  ctx.log('MC102_CAMERA_RESTORED reason='..reason)
 end
 function V:update(e,enabled,riding)
  local s=self.lease
  if s and(s.epoch~=ctx.epoch()or s.player:GetAddress()~=e.player:GetAddress())then self:forget();s=nil end
  local target=e.controller.Pawn
  local species=s and s.species
  if riding and not species and valid(target)then species=target:GetCharacterParameterComponent():GetIndividualParameter():GetCharacterID():ToString()end
  local customGround=species=='MC_Horse'or species=='MC_Camel'or bossById[species]~=nil
  if not riding or(not enabled and not customGround)then self:release(not riding and'dismount'or'F5-third-person',riding);return end
  if not s then
   local b,c=e.player.CameraBoom,e.player.FollowCamera
   assert(valid(b)and valid(c),'MC102 native rider camera absent')
   s={epoch=ctx.epoch(),player=e.player,controller=e.controller,boom=b,camera=c,parent=c:GetAttachParent(),socket=c:GetAttachSocketName(),location=vec(c.RelativeLocation),rotation=rot(c.RelativeRotation),scale=vec(c.RelativeScale3D),control=c.bUsePawnControlRotation,tick=b:IsComponentTickEnabled(),flags={},target=e.controller.PlayerCameraManager.ViewTarget.Target,nativeTarget=e.controller.Pawn}
   for _,name in ipairs(flags)do s.flags[name]=b:GetPropertyValue(name)end
   self.lease=s;s.customGround=customGround

   local ride=e.player:GetRideMeshTranslationOffset()
   s.eye={X=ride.X,Y=ride.Y,Z=ride.Z+e.player.BaseEyeHeight}

   if valid(s.nativeTarget)then
    s.species=s.nativeTarget:GetCharacterParameterComponent():GetIndividualParameter():GetCharacterID():ToString()
    if s.species=='HawkBird'then s.eye.Z=s.eye.Z+160 elseif s.species=='MC_Camel'or s.species=='MC_Horse'then s.eye.Z=s.eye.Z+140 end
    s.boss=bossById[s.species];if s.boss then s.eye.Z=s.eye.Z+s.boss.eye end
   end
   self.footRecalibrate=nil
   b.TargetArmLength=0;b.bDoCollisionTest=false;b.bEnableCameraLag=false;b.bEnableCameraRotationLag=false;b.bUsePawnControlRotation=true;b.bInheritRoll=false
   b:SetComponentTickEnabled(false)
   c.bUsePawnControlRotation=false
   assert(c:K2_AttachToComponent(s.boss and s.nativeTarget.RootComponent or e.player.RootComponent,UE.FindOrAddFName('None'),2,2,2,false))
   _G.MC_OUT_K('K2_SetRelativeLocation',c,s.eye,false,ignoredHitJ(),true)
   e.controller:SetViewTargetWithBlend(e.player,0,0,0,false)
   ctx.log('MC102_CAMERA_ACTIVE route=native-player-camera eyeZ='..s.eye.Z..' epoch='..s.epoch)
  end
  local r=e.controller:GetControlRotation();r={Pitch=r.Pitch,Yaw=r.Yaw,Roll=0}
  local mode=enabled and'first'or'third'
  if mode~=s.mode then s.mode=mode;s.traceAt=nil;ctx.log('MCAC_MOUNT_CAMERA mode='..mode..' species='..tostring(s.species))end
  if s.boss then

   local now=os.clock();local dt=now-(s.lagAtT or now);s.lagAtT=now;s.lagT=s.lagT or{}
   local p=s.nativeTarget:K2_GetActorLocation();local half=s.nativeTarget.CapsuleComponent:GetScaledCapsuleHalfHeight()
   local heading=s.nativeTarget:K2_GetActorRotation().Yaw;local yaw=math.rad(heading);local seat=s.boss.seat
   s.orbitZ1=s.orbitZ1 or{}
   r=orbit.step(s.orbitZ1,r,heading,now,dt,enabled,s.orbitModeZ1~=mode)
   s.orbitModeZ1=mode
   local pivot={X=p.X+math.cos(yaw)*seat.X-math.sin(yaw)*seat.Y,Y=p.Y+math.sin(yaw)*seat.X+math.cos(yaw)*seat.Y,Z=p.Z-half+seat.Z}
   pivot.Z=pivot.Z+(enabled and(e.player.BaseEyeHeight+s.boss.eye)or s.boss.pivot)

   if enabled and s.species=='MC_EnderDragon'then
    local safe={X=pivot.X,Y=pivot.Y,Z=math.max(pivot.Z,p.Z-half+1450)}
    local hit={};local color={R=0,G=0,B=0,A=0}
    local blocked=_G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),s.nativeTarget,pivot,safe,0,false,{e.player,s.nativeTarget},0,hit,true,color,color,0)
    if blocked then safe={X=hit.ImpactPoint.X,Y=hit.ImpactPoint.Y,Z=hit.ImpactPoint.Z-20}end
    pivot=safe;s.fpProbeT={blocked=blocked,height=pivot.Z-(p.Z-half),clearance=1450}
   end
   local modeChanged=s.lagModeT~=mode;s.lagModeT=mode
   local smooth,rotation=lag.step(s.lagT,pivot,r,dt,modeChanged)

   if enabled and s.species=='MC_EnderDragon'then smooth=pivot end
   local distance=enabled and 0 or s.boss.distance
   local cy,cp=math.rad(rotation.Yaw),math.rad(rotation.Pitch)
   if distance>0 then
    local q={X=smooth.X-math.cos(cy)*math.cos(cp)*distance,Y=smooth.Y-math.sin(cy)*math.cos(cp)*distance,Z=smooth.Z-math.sin(cp)*distance}
    local hit={};local color={R=0,G=0,B=0,A=0}

    local blocked=_G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),s.nativeTarget,smooth,q,0,false,{e.player,s.nativeTarget},0,hit,true,color,color,0)
    local target=blocked and math.max(45,math.sqrt((hit.ImpactPoint.X-smooth.X)^2+(hit.ImpactPoint.Y-smooth.Y)^2+(hit.ImpactPoint.Z-smooth.Z)^2)-20)or distance
    if not s.tpDistance or target<s.tpDistance then s.tpDistance=target
    else s.tpDistance=s.tpDistance+(target-s.tpDistance)*(1-math.exp(-10*dt))end
    distance=s.tpDistance
   end
   _G.MC_OUT_K('K2_SetWorldLocation',s.camera,{X=smooth.X-math.cos(cy)*math.cos(cp)*distance,Y=smooth.Y-math.sin(cy)*math.cos(cp)*distance,Z=smooth.Z-math.sin(cp)*distance},false,ignoredHitJ(),true)
   _G.MC_OUT_K('K2_SetWorldRotation',s.camera,rotation,false,ignoredHitJ(),true)
   s.stableRootT=true;return
  end
  if enabled then
   if s.wasThird then _G.MC_OUT_K('K2_SetRelativeLocation',s.camera,s.eye,false,ignoredHitJ(),true);s.wasThird=nil end
  else

   local yaw,pitch=math.rad(r.Yaw),math.rad(r.Pitch)
   local p=e.player:K2_GetActorLocation();local pivot={X=p.X,Y=p.Y,Z=p.Z+(s.boss and s.boss.pivot or 160)}
   local now=os.clock();local distance=s.boss and s.boss.distance or 560
   if not s.traceAt or now>=s.traceAt then
    s.traceAt=now+.1;local q={X=pivot.X-math.cos(yaw)*math.cos(pitch)*distance,Y=pivot.Y-math.sin(yaw)*math.cos(pitch)*distance,Z=pivot.Z-math.sin(pitch)*distance}
    local hit={};local color={R=0,G=0,B=0,A=0}
    local blocked=_G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,pivot,q,0,false,{e.player,s.nativeTarget},0,hit,true,color,color,0)
    s.tpDistance=blocked and math.max(45,math.sqrt((hit.ImpactPoint.X-pivot.X)^2+(hit.ImpactPoint.Y-pivot.Y)^2+(hit.ImpactPoint.Z-pivot.Z)^2)-20)or distance
   end
   distance=s.tpDistance or distance
   _G.MC_OUT_K('K2_SetWorldLocation',s.camera,{X=pivot.X-math.cos(yaw)*math.cos(pitch)*distance,Y=pivot.Y-math.sin(yaw)*math.cos(pitch)*distance,Z=pivot.Z-math.sin(pitch)*distance},false,ignoredHitJ(),true)
   s.wasThird=true
  end
  _G.MC_OUT_K('K2_SetWorldRotation',s.camera,r,false,ignoredHitJ(),true)
 end
 function V:status()
  local s=self.lease;local d={active=s~=nil,lastRelease=self.lastRelease}
  if s and s.stableRootT then d.stableRootT=true;d.positionLagSpeed=12;d.rotationLagSpeed=6;d.pitchLagSpeed=4;d.chaseHeading=s.orbitZ1 and s.orbitZ1.following or false;d.orbitZ1=s.orbitZ1;d.fpProbeT=s.fpProbeT;d.rotation=s.lagT.r;d.cameraParent=s.camera:GetAttachParent():GetFullName()end
  if s then d.mode=s.mode;d.tpDistance=s.tpDistance;d.epoch=s.epoch;d.eye=s.eye;d.species=s.species;d.originalTarget=valid(s.target)and s.target:GetFullName();d.restoreTarget=valid(s.nativeTarget)and s.nativeTarget:GetFullName();d.component=vec(s.camera:K2_GetComponentLocation());d.arm=s.boom.TargetArmLength;d.collision=s.boom.bDoCollisionTest;d.lag=s.boom.bEnableCameraLag;d.target=s.controller.PlayerCameraManager.ViewTarget.Target:GetFullName()end
  return d
 end
 return V
end
