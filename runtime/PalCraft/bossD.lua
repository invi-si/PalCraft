-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx,Z)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local data=dofile(ctx.base..'/bossD_data.lua');local motion=dofile(ctx.base..'/boss_motionD.lua')
 local B={events={},engagedF={},data=data,writeStats={frames=0,total=0,max=0}};local D='/Game/MinecraftBossD/'
 local posesE=dofile(ctx.base..'/boss_poseE.lua')
 local barsF=dofile(ctx.base..'/boss_barF.lua')(valid)
 local perchE=dofile(ctx.base..'/boss_perchE.lua')
 local function vec(x,y,z)return{X=x,Y=y,Z=z}end
 local function v(p)return vec(p.X,p.Y,p.Z)end
 local function dist(p,q)return math.sqrt((p.X-q.X)^2+(p.Y-q.Y)^2+(p.Z-q.Z)^2)end
 local function angle(x)return(x+180)%360-180 end
 function B:event(kind,s,row)
  row=row or{};row.kind=kind;row.at=os.clock();row.host=s.address;row.species=s.species
  self.events[#self.events+1]=row;if #self.events>160 then table.remove(self.events,1)end
  ctx.log('MCD_'..kind..' species='..s.species)
 end
 function B:alive(a,e)
  if not valid(a)or not valid(a.CharacterParameterComponent)then return false end
  local w=a:GetWorld();local c=a.CharacterParameterComponent
  return valid(w)and w:GetAddress()==e.world:GetAddress()and not c:IsDead()and not c:GetIsCapturedProcessing()
 end
 function B:clear(s)
  local g=s.bossD;if not g then return end
  if g.epoch==T.epoch then
   if valid(g.controller)then g.controller:WaitForSeconds(0);g.controller:StopMovement()end
   if valid(s.host)and valid(s.parameter)and not s.parameter:GetIsCapturedProcessing()then s.host.CharacterMovement:SetMovementMode(g.mode or 1,0)end
   for _,p in ipairs(g.projectiles)do if valid(p.actor)then p.actor:SetActorHiddenInGame(true)end end
   if valid(g.fx)then g.fx:SetActorHiddenInGame(true)end
  end
  s.bossPoolD={epoch=g.epoch,projectiles=g.projectiles,fx=g.fx,cubes=g.cubes}
  s.bossD=nil;s.bossHistoryD=nil;s.bossDesiredE=nil
  self.engagedF[s.address]=nil
  if self.active==s then self.active=nil end
 end
 function B:state(s,now)
  if s.bossD then return s.bossD end
  local g={epoch=T.epoch,born=now,nextAttack=now+2,steerAt=0,projectiles={},mode=s.host.CharacterMovement.MovementMode,home=v(s.host:K2_GetActorLocation()),phase='CIRCLE',phaseAt=now,nextBreath=now+7}
  local pool=s.bossPoolD;if pool and pool.epoch==T.epoch then g.projectiles=pool.projectiles;g.fx=pool.fx;g.cubes=pool.cubes;for _,p in ipairs(g.projectiles)do p.active=false end end
  s.bossD=g;return g
 end
 function B:engage(s,target,now)
  if not s.definition.bossD or not valid(target)or not valid(target.CharacterParameterComponent)then return end
  local e=ctx.environment();if e and valid(e.controller.Pawn)and e.controller.Pawn:GetAddress()==s.address then return end
  local g=self:state(s,now)
  if valid(g.target)and g.target:GetAddress()==target:GetAddress()then return end
  g.target=target;self.active=s;self.engagedF[s.address]=s;g.phaseAt=now;g.nextAttack=now+1.5;g.nextBreath=now+5;self:event('ENGAGE',s,{target=target:GetAddress()})
 end
 function B:actor(e,p,mesh)
  local tf={Rotation={X=0,Y=0,Z=0,W=1},Translation=v(p),Scale3D=vec(1,1,1)};local u=UE.Object('/Script/Engine.Default__GameplayStatics')
  local a=u:BeginDeferredActorSpawnFromClass(e.world,UE.Object('/Script/Engine.Actor'),tf,1,nil);a=u:FinishSpawningActor(a,tf)
  a:AddComponentByClass(UE.Object('/Script/Engine.SceneComponent'),false,{Rotation=tf.Rotation,Translation=vec(0,0,0),Scale3D=vec(1,1,1)},false);a:SetActorEnableCollision(false)
  if mesh then
   local c=a:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,{Rotation=tf.Rotation,Translation=vec(0,0,0),Scale3D=vec(1,1,1)},false)
   c:SetMobility(2);c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false);c:SetCastShadow(false);c:SetStaticMesh(Z:asset(D..mesh..'.'..mesh))
  end
  return a
 end
 function B:fx(s,e,p,purple,now,duration)
  local g=s.bossD
  if not valid(g.fx)then
   g.fx=self:actor(e,p);g.cubes={};local tf={Rotation={X=0,Y=0,Z=0,W=1},Translation=vec(0,0,0),Scale3D=vec(1,1,1)}
   local c=g.fx:AddComponentByClass(UE.Object('/Script/Engine.InstancedStaticMeshComponent'),false,tf,false)
   c:SetMobility(2);c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false);c:SetCastShadow(false);g.cubes={c}
  end
  local path='SM_BossD'..(purple and'Purple'or'Smoke');local mesh=Z:asset(D..path..'.'..path)
  _G.MC_OUT_K('K2_SetActorLocation',g.fx,p,false,ignoredHitJ(),true);g.fx:SetActorHiddenInGame(false)
  if g.fxPurple~=purple then
   local c=g.cubes[1];c:SetStaticMesh(mesh);c:ClearInstances()
   for i=1,16 do
    local a=i*2.39996;local radius=(purple and 320 or 100)*math.sqrt(i/16)
    local size=purple and .85+.18*(i%3)or .12+.06*(i%3)
    c:AddInstance({Rotation={X=0,Y=0,Z=0,W=1},Translation=vec(math.cos(a)*radius,math.sin(a)*radius,(purple and 35 or 0)+math.sin(i*2.3)*20),Scale3D=vec(size,size,purple and .22+.08*(i%3)or size)},false)
   end
   g.fxPurple=purple
  end
  g.fxUntil=now+duration
 end
 function B:blocked(s,e,p,q,target)
  local hit={};local c={R=0,G=0,B=0,A=0}
  local function trace()return _G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),s.host,p,q,0,false,{s.host,target,e.player},0,hit,true,c,c,0)end
  local blocked=T.measure('boss:los',trace)
  if blocked and valid(target)then local comp=hit.Component and hit.Component:Get();local actor=valid(comp)and comp:GetOwner();if valid(actor)and actor:GetAddress()==target:GetAddress()then blocked=false end end
  return blocked,hit
 end
 function B:damage(s,e,target,p,q,power,kind)
  if not self:alive(target,e)or not self:alive(s.host,e)then return false end
  if self:blocked(s,e,p,q,target)then self:event('OCCLUDED',s,{attack=kind});return false end
  return Z.bossFA:hit(s,e,target,q,kind)
 end
 function B:skull(s,e,q,now,blue)
  local g=s.bossD;local p
  g.head=(g.head or 0)%3+1;local names={'center_head','right_head','left_head'}
  for i,d in ipairs(s.models)do if d.name==names[g.head]then p=v(s.parts[i]:K2_GetComponentLocation())end end
  p=p or v(s.host:K2_GetActorLocation());local n=math.max(1,dist(p,q));local dir=vec((q.X-p.X)/n,(q.Y-p.Y)/n,(q.Z-p.Z)/n)
  local shot
  for _,x in ipairs(g.projectiles)do if not x.active then shot=x;break end end
  if not shot then if #g.projectiles>=3 then return end;shot={};g.projectiles[#g.projectiles+1]=shot end
  local dragon=s.kind=='enderdragon'
  if not valid(shot.actor)then shot.actor=self:actor(e,p,dragon and'SM_BossDPurple'or'SM_WitherSkullD')end
  _G.MC_OUT_K('K2_SetActorLocation',shot.actor,p,false,ignoredHitJ(),true);shot.actor:K2_SetActorRotation({Pitch=math.deg(math.atan(dir.Z,math.sqrt(dir.X^2+dir.Y^2))),Yaw=math.deg(math.atan(dir.Y,dir.X)),Roll=0},true);shot.actor:SetActorHiddenInGame(false)
  shot.active=true;shot.p=p;shot.dir=dir;shot.at=now;shot.born=now;shot.target=g.target;shot.blueFA=blue==true;shot.dragonFA=dragon
  shot.actor:SetActorScale3D(vec(blue and 1.5 or 1,blue and 1.5 or 1,blue and 1.5 or 1))
  if not dragon then
   local part=shot.actor:GetComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'))
   if valid(part)then
    if not shot.originalFA then shot.originalFA=part:GetMaterial(0)end
    part:SetMaterial(0,blue and Z:asset('/Game/MinecraftBossE/M_WitherArmorE.M_WitherArmorE')or shot.originalFA)
   end
  end
  self:event(dragon and'FIREBALL_LAUNCH'or blue and'BLUE_SKULL_LAUNCH'or'SKULL_LAUNCH',s,{head=g.head,from=p,aim=v(q)});ctx.sound:play(dragon and'entity.enderdragon.shoot'or'entity.wither.shoot',p,1,e)
 end
 function B:projectiles(s,e,now)
  local g=s.bossD
  for _,shot in ipairs(g.projectiles)do if shot.active then
   if(shot.target and not self:alive(shot.target,e))or now-shot.born>6 then shot.active=false;shot.actor:SetActorHiddenInGame(true)
   else
    local dt=math.min(.2,math.max(0,now-shot.at));shot.at=now;local p=shot.p;local speed=shot.blueFA and 600 or shot.dragonFA and 900 or 1100;local q=vec(p.X+shot.dir.X*speed*dt,p.Y+shot.dir.Y*speed*dt,p.Z+shot.dir.Z*speed*dt)
    local blocked,hit=self:blocked(s,e,p,q,shot.target);local t=shot.target and shot.target:K2_GetActorLocation()or q;local dx,dy,dz=q.X-p.X,q.Y-p.Y,q.Z-p.Z;local n=dx*dx+dy*dy+dz*dz
    local f=math.max(0,math.min(1,((t.X-p.X)*dx+(t.Y-p.Y)*dy+(t.Z-p.Z)*dz)/math.max(1,n)));local near=vec(p.X+f*dx,p.Y+f*dy,p.Z+f*dz)
    local touch=shot.target and dist(near,t)<85
    if blocked or touch then
     local impact=blocked and v(hit.ImpactPoint)or near;shot.active=false;shot.actor:SetActorHiddenInGame(true);self:fx(s,e,impact,false,now,.5)
     if shot.dragonFA then
      local cloud=v(impact);cloud.Z=shot.target and t.Z-shot.target.CapsuleComponent:GetScaledCapsuleHalfHeight()+20 or impact.Z
      g.cloud={position=cloud,untilAt=now+10,nextHit=now+.5,target=shot.target};self:fx(s,e,cloud,true,now,10);self:event('ACID_CLOUD',s,{position=cloud,seconds=10})
     elseif shot.target and dist(impact,t)<(shot.blueFA and 300 or 180)then self:damage(s,e,shot.target,impact,t,30,shot.blueFA and'BLUE_SKULL'or'SKULL')end
     self:event('SKULL_IMPACT',s,{blocked=blocked,position=impact})
    else shot.p=q;_G.MC_OUT_K('K2_SetActorLocation',shot.actor,q,false,ignoredHitJ(),true)end
   end
  end end
 end
 function B:tick(s,e,now)
  if not s.definition.bossD then return end

  if valid(e.controller.Pawn)and e.controller.Pawn:GetAddress()==s.address then
   if s.bossD and not s.bossD.riddenFA then s.bossD.mode=s.host.CharacterMovement.MovementMode;self:clear(s)end
   Z.bossFA:ride(s,e,now)
   local g=s.bossD;if g then
    self:projectiles(s,e,now);Z.bossFA:dot(s,e,now)
    local cloud=g.cloud
    if cloud then
     if now>=cloud.untilAt then g.cloud=nil
     elseif valid(cloud.target)and now>=cloud.nextHit then
      cloud.nextHit=now+.5;local q=cloud.target:K2_GetActorLocation()
      if dist(q,cloud.position)<400 then self:damage(s,e,cloud.target,cloud.position,q,10,'BREATH')end
     end
    end
    if g.fxUntil and now>=g.fxUntil then g.fx:SetActorHiddenInGame(true);g.fxUntil=nil end
   end
   return
  end
  if not self:alive(s.host,e)or not s.host:GetActiveActorFlag()or s.host.bHidden or s.recall108 or s.fixtureD then self:clear(s);return end
  if s.bossD and s.bossD.riddenFA then self:clear(s);s.rideFA=nil end
  local g=self:state(s,now);if g.epoch~=T.epoch then self:clear(s);return end
  Z.bossFA:dot(s,e,now)
  local p=s.host:K2_GetActorLocation();local owned=s.owned108
  if valid(g.target)and(not self:alive(g.target,e)or dist(p,g.target:K2_GetActorLocation())>4800)then g.target=nil;g.cloud=nil end
  if not valid(g.target)and not owned and self:alive(e.player,e)and dist(p,e.player:K2_GetActorLocation())<3000 then self:engage(s,e.player,now)end
  if owned and not valid(g.target)then self:clear(s);return end
  self:projectiles(s,e,now)
  if g.fxUntil and now>=g.fxUntil then g.fx:SetActorHiddenInGame(true);g.fxUntil=nil end
  local target=g.target;local q=valid(target)and target:K2_GetActorLocation()or nil
  local ac=s.host:GetActionComponent();local action=valid(ac)and ac:GetCurrentActionType(false)or 0
  if action==3 or action==7 or action==8 or action==9 then return end
  local dragon=s.kind=='enderdragon';local destination
  local ratio=s.parameter:GetHP().Value/math.max(1,s.parameter:GetMaxHP().Value)
  if not dragon then
   local armored=ratio<=.5
   if s.armorE~=armored then
    if armored and not s.armorMaterialsRetainedOA then
     for _,mid in pairs(s.x4 and s.x4.materials or{})do ctx.retain(mid)end
     s.armorMaterialsRetainedOA=true
    end
    s.armorE=armored;s.normalMaterial105=armored and Z:asset('/Game/MinecraftBossE/M_WitherArmorE.M_WitherArmorE')or nil
    for i,m in ipairs(s.models)do if m.mesh then local c=s.parts[i];c:SetMaterial(0,s.normalMaterial105 or(s.x4 and s.x4.materials[i])or(s.seatPartI==i and s.seatMaterialI)or c.StaticMesh:GetMaterial(0))end end
    self:event('ARMOR',s,{enabled=armored,ratio=ratio})
   end
  end
  if dragon and not owned and ratio<=.3 then
   if g.phase~='PERCH'then
    g.phase='PERCH';g.phaseAt=now;g.cloud=nil;g.perchIndex=1;g.perchProbe=1;g.perchStage=nil;g.perchFloor=nil;g.landedFA=nil
    if valid(g.fx)then g.fx:SetActorHiddenInGame(true)end
    self:event('WEAKENED_DESCENT',s,{ratio=ratio,home=g.home})
   end
   if not g.perch and now>=(g.perchProbeAt or 0)then
    g.perchProbeAt=now+.1;local center=g.home;local offset=perchE.offsets[g.perchProbe]
    local x,y=center.X+offset[1],center.Y+offset[2]
    local hit={};local c={R=0,G=0,B=0,A=0}
    if _G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,vec(x,y,center.Z+2400),vec(x,y,center.Z-6000),0,false,{s.host,e.player},0,hit,true,c,c,0)and hit.ImpactNormal.Z>.75 then
     g.perchFloor=math.max(g.perchFloor or hit.ImpactPoint.Z,hit.ImpactPoint.Z);g.perchProbe=g.perchProbe+1
     if g.perchProbe>#perchE.offsets then
      g.perch=vec(center.X,center.Y,g.perchFloor+s.capsule:GetScaledCapsuleHalfHeight()+55)
      self:event('PERCH_READY',s,{position=g.perch,floor=vec(center.X,center.Y,g.perchFloor),footprintProbes=#perchE.offsets})
     end
    else
     g.perchIndex=g.perchIndex%#perchE.candidates+1;g.perchProbe=1;g.perchFloor=nil;g.perchProbeAt=now+1
    end
   end
   destination=perchE.destination(g,p)
   if g.perch and dist(p,g.perch)<180 and q and now>=(g.perchBreathFA or 0)then
    g.perchBreathFA=now+.5;self:fx(s,e,q,true,now,1)
    if dist(p,q)<950 then self:damage(s,e,target,p,q,10,'PERCH_BREATH')end
    self:event('PERCH_BREATH',s,{position=v(q)})
   end
  elseif dragon then
   if g.phase=='PERCH'then g.phase='CIRCLE';g.phaseAt=now;g.perch=nil;g.perchStage=nil end
   local age=now-g.phaseAt
   if q and g.phase=='CIRCLE'and age>=5 then g.phase='CHARGE';g.phaseAt=now;g.chargeAim=vec(q.X,q.Y,q.Z+70);g.chargeHit=false;self:event('CHARGE',s,{aim=g.chargeAim})
   elseif g.phase=='CHARGE'and age>=2.6 then
    g.phase='BREATH';g.phaseAt=now
    if q then
     self:skull(s,e,q,now);self:event('BREATH',s,{position=v(q)})
    end
   elseif g.phase=='BREATH'and age>=3.6 then g.phase='CIRCLE';g.phaseAt=now end
   if g.phase=='CHARGE'and g.chargeAim then destination=g.chargeAim
    if q and not g.chargeHit and dist(p,q)<650 then g.chargeHit=true;self:damage(s,e,target,p,q,35,'CHARGE')end
   elseif g.phase=='BREATH'and q then destination=vec(q.X-500,q.Y,q.Z+650)
   else local center=q or g.home;local a=(now-g.born)*.36;destination=vec(center.X+math.cos(a)*1600,center.Y+math.sin(a)*1600,center.Z+850)end
   local cloud=g.cloud
   if cloud then
    if now>=cloud.untilAt then g.cloud=nil
    elseif q and now>=cloud.nextHit then cloud.nextHit=now+.5;if dist(q,cloud.position)<380 then self:damage(s,e,target,vec(cloud.position.X,cloud.position.Y,cloud.position.Z+30),q,10,'BREATH')end end
   end
   if q and dist(p,q)<650 and now>=(g.wingAtFA or 0)then g.wingAtFA=now+2;self:damage(s,e,target,p,q,10,'WING')end
  else
   if q then
    local a=math.atan(p.Y-q.Y,p.X-q.X);destination=vec(q.X+math.cos(a)*1150,q.Y+math.sin(a)*1150,q.Z+430)
    if now>=g.nextAttack then g.nextAttack=now+2.8;self:skull(s,e,q,now,(g.head or 0)%3==2)end
    if ratio<=.5 and now>=(g.dashAtFA or 0)then g.dashAtFA=now+7;g.dashUntilFA=now+1.5;g.dashAimFA=v(q);g.dashHitFA=false;self:event('DASH',s,{aim=g.dashAimFA})end
    if g.dashUntilFA and now<g.dashUntilFA then destination=g.dashAimFA;if dist(p,q)<350 and not g.dashHitFA then g.dashHitFA=true;self:damage(s,e,target,p,q,30,'DASH')end end
   else local a=(now-g.born)*.24;destination=vec(g.home.X+math.cos(a)*350,g.home.Y+math.sin(a)*350,g.home.Z+120)end
  end
  if now>=g.steerAt then
   g.steerAt=now+.45;local ai=s.host:GetController()
   if valid(ai)then
    g.controller=ai;ai:WaitForSeconds(2)
    if dragon and g.phase=='PERCH'and g.perchStage=='DESCEND'and g.perch then
     local error=p.Z-g.perch.Z;local horizontal=(p.X-g.perch.X)^2+(p.Y-g.perch.Y)^2
     if not g.landedFA and math.abs(error)<450 and horizontal<180^2 then g.landedFA=true;self:event('PERCH_LAND',s,{position=v(p),nativeWalking=true})end
     local impulse=not g.landedFA and perchE.descentImpulse(error)or 0
     if impulse<0 then s.host.CharacterMovement:AddImpulse({X=0,Y=0,Z=impulse},true)end
    end
    s.host.CharacterMovement:SetMovementMode(dragon and g.phase=='PERCH'and g.landedFA and 1 or 5,0)
    
    s.host.CharacterMovement.MaxFlySpeed=dragon and(g.phase=='CHARGE'and 1600 or g.phase=='PERCH'and(g.perchStage=='DESCEND'and 250 or 700)or 750)or(g.dashUntilFA and now<g.dashUntilFA and 1400 or 400)
    local face=q or destination;local yaw=math.deg(math.atan(face.Y-p.Y,face.X-p.X));if dragon and g.phase~='BREATH'and g.phase~='PERCH'then yaw=math.deg(math.atan(destination.Y-p.Y,destination.X-p.X))end
    ai:SetControlRotation({Pitch=0,Yaw=yaw,Roll=0});s.host:K2_SetActorRotation({Pitch=0,Yaw=yaw,Roll=0},true)
    if g.phase=='PERCH'and dist(p,destination)<65 then s.host.CharacterMovement:StopMovementImmediately();ai:StopMovement()
    else ai:PalMoveToLocation(destination,g.phase=='PERCH'and 25 or 80,false,false,false,false,nil,false)end
   end
  end
  if now>=(g.sampleAt or 0)then
   g.sampleAt=now+.5;g.rows=g.rows or{};g.rows[#g.rows+1]={at=now,position=v(p),mode=s.host.CharacterMovement.MovementMode,phase=g.phase,target=q and v(q),hp=s.parameter:GetHP().Value}
   if #g.rows>120 then table.remove(g.rows,1)end
  end
 end
 function B:animate(s,now)
  if s.deadAt or s.capturing then return end
  local g=s.bossD;local yaw=s.host:K2_GetActorRotation().Yaw;local target=g and g.target;local ty,tp
  if valid(target)then local p,q=s.host:K2_GetActorLocation(),target:K2_GetActorLocation();ty=math.deg(math.atan(q.Y-p.Y,q.X-p.X));tp=math.deg(math.atan(q.Z-p.Z,math.sqrt((q.X-p.X)^2+(q.Y-p.Y)^2)))end
  s.bossHistoryD=s.bossHistoryD or{};local h=s.bossHistoryD;h[#h+1]=yaw;if #h>32 then table.remove(h,1)end
  local poses,bob=motion.frame(s.kind,s.models,now,s.bornAt,yaw,ty,tp,h)
  posesE.queue(s,poses,-s.capsule:GetUnscaledCapsuleHalfHeight()+bob)
 end
 function B:flush()
  local used=0;local n=#Z.slots;if n==0 then return end
  self.flushCursor=(self.flushCursor or 0)%n+1
  for j=0,n-1 do local s=Z.slots[(self.flushCursor+j-1)%n+1]
   if s.host and s.definition and s.definition.bossD and not s.deadAt and not s.capturing and not s.recall108 then
    used=used+posesE.flush(s,posesE.limit-used);if used>=posesE.limit then break end
   end
  end
  self.writeStats.frames=self.writeStats.frames+1;self.writeStats.total=self.writeStats.total+used;self.writeStats.max=math.max(self.writeStats.max,used)
 end
 function B:ui(e,ns,U,unit,enabled)
  barsF.render(self.engagedF,e,ns,U,unit,enabled)
 end
 T.onEpoch('bossD',function()B.events={};B.active=nil;B.engagedF={};B.writeStats={frames=0,total=0,max=0}end)
 return B
end
