-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
 local R={};local F;local UE,valid=ctx.UE,ctx.valid;local poseK=dofile(ctx.base..'/poseK.lua');UE.poseK=UE.poseK or{calls=0}
 local look=dofile(ctx.base..'/lookT.lua')
 local xyz={'X','Y','Z'};local angles={'Pitch','Yaw','Roll'}
 local function adapter()
  if not F then
   local at=os.clock();_G.MC_FIDELITY_J=_G.MC_FIDELITY_J or dofile(ctx.base..'/costume_fidelity_x4.lua');F=_G.MC_FIDELITY_J
   ctx.log(string.format('MCJ_POSE_LAZY_LOAD ms=%.3f',(os.clock()-at)*1000))
  end
  return F
 end
 local function changed(a,b,keys,epsilon)
  if _G.MC_J_UNCACHED or not a then return true end
  for _,k in ipairs(keys)do if math.abs(a[k]-b[k])>epsilon then return true end end
  return false
 end
 function R:bind(s)
  local f=adapter();s.x4=f.new(s.kind);s.x4.parts=s.parts;s.x4.materials={};s.x4.cache={};s.x4.materialCache={};s.x4.lastTick=nil
  for i,m in ipairs(s.models)do if m.x4 and m.mesh then
   local c=s.parts[i];s.x4.materials[i]=c:CreateDynamicMaterialInstance(0,c.StaticMesh:GetMaterial(0),UE.FindOrAddFName('None'))
  end end
  self:animate(s,os.clock(),0)
 end
 function R:input(s,now,dt)
  local x=s.x4;local ticks=math.max(0,(now-(s.bornAt or now))*20)
  local f=adapter().source.f32
  local target=f(math.min(1,math.max(0,(s.speed or 0)/100/20*4)))
  x.accumulator=(x.accumulator or 0)+math.max(0,math.min(.2,dt));local n=math.floor((x.accumulator+1e-9)*20);x.accumulator=x.accumulator-n*.05
  x.speed=x.speed or 0;x.walk=x.walk or 0
  for _=1,n do x.previousSpeed=x.speed;x.speed=f(x.speed+f(f(target-x.speed)*f(.4)));x.walk=f(x.walk+x.speed)end
  local partial=math.max(0,math.min(1,x.accumulator*20))
  local weight=f((x.previousSpeed or x.speed)+f(f(x.speed-(x.previousSpeed or x.speed))*partial))
  local position=f(x.walk-f(x.speed*f(1-partial)))
  
  if s.render then position=s.render.walk;weight=s.render.walkWeight end
  local elapsed=s.attackStart and now-s.attackStart or 99
  local input=x.input or{};x.input=input;input.ageInTicks=ticks;input.walkAnimationPos=position;input.walkAnimationSpeed=weight
  if s.render then
   input.headYaw=s.modelHeadYaw or 0;input.headPitch=s.modelHeadPitch or 0
  else

   x.lookYaw=s.lookBodyT and look.wrap(s.lookHeadT-s.lookBodyT)or look.approach(x.lookYaw or 0,math.max(-75,math.min(75,s.headYaw or 0)),200,dt)
   x.lookPitch=look.approach(x.lookPitch or 0,s.headPitch or 0,200,dt)
   input.headYaw=x.lookYaw;input.headPitch=x.lookPitch
  end
  input.attackProgress=elapsed<.5 and elapsed/.5 or 0;input.aggressive=s.aggressive or false;input.bowAiming=s.usingBow or false
  if s.kind=='irongolem'then input.attackTicksRemaining=math.max(0,10-elapsed*20)end
  if s.kind=='chicken'then input.flap=ticks;input.flapSpeed=(s.speed or 0)>0 and .3 or 0 end
  if s.kind=='creeper'then input.swell=s.fuseStart and math.min(1,(now-s.fuseStart)/1.5)or(s.fuse and math.min(1,(now-(s.fuse-1.5))/1.5)or 0)end
  if s.kind=='warden'then
   local pose=s.wardenPoseC;input.clips=input.clips or{};for k in pairs(input.clips)do input.clips[k]=false end;input.clips.attack=false;input.clips.sonicBoom=false;input.clips.roar=false;input.clips.sniff=false;input.clips.emerge=false;input.clips.dig=false
   if pose then input.clips[pose.kind=='SONIC'and'sonicBoom'or'attack']=(pose.at-(s.bornAt or now))*20 end
   x.heart=math.max(0,(x.heart or 0)-n);x.heartDelay=(x.heartDelay or 0)-n
   if x.heartDelay<=0 then x.heart=10;x.heartDelay=s.aggressive and 10 or 40 end
   input.heartAnimation=x.heart/10;input.tendrilAnimation=math.max(0,1-elapsed*2)
  elseif s.kind=='wither'then input.sideHeadYaw={input.headYaw,input.headYaw};input.sideHeadPitch={input.headPitch,input.headPitch};input.bodyYaw=0
  elseif s.kind=='enderdragon'then
   local p=s.lastMotionPosition or s.p or{Z=0};local yaw=s.yaw or 0
   if valid(s.host)then yaw=s.host:K2_GetActorRotation().Yaw end
   x.history=x.history or{};while #x.history<64 do x.history[#x.history+1]={heightBlocks=p.Z/100,yawDegrees=yaw}end
   for _=1,n do local row=table.remove(x.history,1);row.heightBlocks=p.Z/100;row.yawDegrees=yaw;x.history[#x.history+1]=row end
   input.flightHistory=x.history;input.flapTime=ticks*.05;input.partialTick=ticks%1
  end
  if s.fixtureInputJ then for k,v in pairs(s.fixtureInputJ)do input[k]=v end end
  return input
 end
 function R:animate(s,now,dt)
  local x=s.x4;if not x then return end
  local frames,material=adapter().frame(x,self:input(s,now,dt))
  if s.kind=='enderdragon'and valid(s.host)then
   local velocity=s.host:GetVelocity();local horizontal=math.sqrt(velocity.X^2+velocity.Y^2)
   local target=math.max(-30,math.min(30,math.deg(math.atan(velocity.Z,math.max(300,horizontal)))))
   x.flightPitchT=look.approach(x.flightPitchT or 0,target,45,dt)
   for i,m in ipairs(s.models)do
    local pose=frames[i]
    if m.name=='__model_root'then
     pose.rotation.Pitch=x.flightPitchT;pose.rotation.Yaw=0;pose.rotation.Roll=0
     
     local pitch=math.rad(x.flightPitchT);local dx,dz=130-pose.location.X,485-pose.location.Z
     pose.location.X=130-(dx*math.cos(pitch)-dz*math.sin(pitch))
     pose.location.Z=485-(dx*math.sin(pitch)+dz*math.cos(pitch))
    elseif m.name=='body'then pose.rotation.Pitch=0;pose.rotation.Yaw=0;pose.rotation.Roll=0
    elseif m.name=='head'or m.name:find('neck',1,true)then
     pose.rotation.Pitch=math.max(-30,math.min(30,look.wrap(pose.rotation.Pitch)));pose.rotation.Roll=0
     local targetYaw=math.max(-75,math.min(75,look.wrap(pose.rotation.Yaw)))
     local previous=x.cache[i]
     pose.rotation.Yaw=look.approach(previous and previous.rotation.Yaw or 0,targetYaw,200,dt)
    end
   end
  end
  material.Hurt=(now<(s.hitUntil or s.flashUntil or 0))and 1 or 0
  local writes=0
  for i,p in ipairs(frames)do
   local c=s.parts[i];local old=x.cache[i]
   if changed(old and old.location,p.location,xyz,.001)or changed(old and old.rotation,p.rotation,angles,.01)or changed(old and old.scale,p.scale,xyz,.0001)then
    poseK(c,p);UE.poseK.calls=UE.poseK.calls+1;writes=writes+1;x.poseCallsK=(x.poseCallsK or 0)+1
   end
   if not old or old.visible~=p.visible then c:SetVisibility(p.visible,false);writes=writes+1 end
   x.cache[i]=p
   local mid=x.materials[i];if mid then for k,value in pairs(material)do
    local cache=x.materialCache[i]or{};x.materialCache[i]=cache
    if _G.MC_J_UNCACHED or cache[k]~=value then mid:SetScalarParameterValue(UE.FindOrAddFName(k),value);cache[k]=value;writes=writes+1 end
   end end
  end
  x.lastInput=self:inputReceipt(s,now);x.writes=(x.writes or 0)+writes;x.frames=(x.frames or 0)+1
 end
 function R:inputReceipt(s,now)local q=s.x4.lastInput or{};q.at=now;q.speed=s.speed;q.walk=s.x4.walk;q.weight=s.x4.speed;q.kind=s.kind;return q end
 return R
end
