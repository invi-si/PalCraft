-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
 local timers=dofile(ctx.base..'/timers.lua');local models=assert(loadfile(ctx.base..'/model_registryJ.lua'))(ctx.base);local motion=dofile(ctx.base..'/mob_motion.lua')
 local fidelity=dofile(ctx.base..'/costume_runtimeJ.lua')(ctx)
 local ownedPose=dofile(ctx.base..'/poseK.lua')
 local cacheL=dofile(ctx.base..'/cacheL.lua');local sightCache=cacheL.new(64,5);local floorCache=cacheL.new(64,5)
 local M={slots={},arrows={},assets={},nextSlot=0,nextType=0,spawnAt=0,swingAt=0,events={},serial=0,activation=0,maxMs=0}
 local kinds={'zombie','skeleton','spider','creeper'}
 local navigation=dofile(ctx.base..'/mob_navigation.lua')(ctx.cells,ctx.key,ctx.registry)
 local balance=dofile(ctx.base..'/gear_balance.lua')
 local display66=dofile(ctx.base..'/item_display66.lua');local H66=dofile(ctx.base..'/hand_motion66.lua')
 local function gearDamage(id,unit)
  local data=ctx.items:data(id)
  return data and math.max(1,math.floor(data.AttackValue/unit+.5))or 1
 end
 local defs={
  zombie={hp=20,attribute=.23,goalSpeed=1,height=195,radius=30,headLimit=75,damage=.06,loot={MC_RottenFlesh=1}},
  skeleton={hp=20,attribute=.25,goalSpeed=1,height=199,radius=30,headLimit=75,damage=.05,loot={MC_Bone=1,MC_Arrow=1}},
  spider={hp=16,attribute=.3,goalSpeed=1,height=90,radius=70,headLimit=75,damage=.04,loot={MC_String=1}},
  creeper={hp=20,attribute=.25,goalSpeed=1,height=170,radius=30,headLimit=75,loot={MC_Gunpowder=1}}}
 local function vec(x,y,z)return{X=x,Y=y,Z=z}end
 local function tf(p)return{Rotation={X=0,Y=0,Z=0,W=1},Translation=p,Scale3D=vec(1,1,1)}end
 local function copy(p)return vec(p.X,p.Y,p.Z)end
 local function dist(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)end
 local function typed(o,path)return ctx.valid(o)and o:IsA(ctx.UE.Object(path))end
 local function unwrap(o)if type(o)=='userdata'and o.get then return o:get()end;return o end
 function M:event(action,s,extra)
  local d={action=action,slot=s and s.index,kind=s and s.kind,time=os.clock(),serial=s and s.serial,generation=s and s.generation,position=s and s.p and copy(s.p)}
  for k,v in pairs(extra or{})do d[k]=v end;self.events[#self.events+1]=d;if #self.events>256 then table.remove(self.events,1)end
  if ctx.config.debug then ctx.log('MC41_'..action:upper()..' kind='..tostring(d.kind)..' slot='..tostring(d.slot)..' serial='..tostring(d.serial))end
 end
 function M:guard(env)return env and env.status=='alive'and env.epoch==ctx.epoch()and self.epoch==ctx.epoch()and ctx.ready()and not ctx.quiesced()end
 function M:asset(path,class)
  class=class or'/Script/Engine.StaticMesh'
  local a=self.assets[path];if typed(a,class)then return a end
  local pkg,name=path:match('^(.*)%.([^%.]+)$')
  a=ctx.UE.GetAsset109(ctx.UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=ctx.UE.FindOrAddFName(pkg),AssetName=ctx.UE.FindOrAddFName(name)})
  if not typed(a,class)then a=ctx.UE.Object(path)end
  assert(typed(a,class)and ctx.UE.AssetMatchesRA(a,path),'Mob asset missing '..path)
  ctx.retain(a);self.assets[path]=a;return a
 end
 function M:validate(s,env)
  assert(self:guard(env));if s.validatedAt and os.clock()-s.validatedAt<1 and s.validatedEpoch==self.epoch then return end
  assert(typed(s.actor,'/Script/Engine.Actor')and s.actor:GetWorld():GetAddress()==env.world:GetAddress(),'Invalid mob pool world')
  assert(s.actor:ActorHasTag(ctx.UE.FindOrAddFName(s.tag)),'Invalid mob tag')
  assert(typed(s.actor:GetOuter(),'/Script/Engine.Level'),'Mob actor not level-owned')
  for _,c in ipairs(s.parts)do assert(typed(c,'/Script/Engine.StaticMeshComponent')and c:GetOwner():GetAddress()==s.actor:GetAddress()and c:GetOuter():GetAddress()==s.actor:GetAddress(),'Invalid mob part owner')end
  s.validatedAt=os.clock();s.validatedEpoch=self.epoch
 end
 function M:create(env,index,arrow,retained)
  local tag=(arrow and'MC41Arrow:'or'MC41Mob:')..index;local a=retained;local parts={}
  if a then
   local result=a:K2_GetComponentsByClass(ctx.UE.Object('/Script/Engine.StaticMeshComponent'))
   result:ForEach(function(_,v)local comp=v:get();for i=1,arrow and 1 or 16 do if comp:ComponentHasTag(ctx.UE.FindOrAddFName('MC41Part:'..i))then assert(not parts[i],'Duplicate pooled part tag');parts[i]=comp;break end end end)
   assert(#parts==(arrow and 1 or 16),'Retained mob component count')
  else
   local g=ctx.UE.Object('/Script/Engine.Default__GameplayStatics');local transform=tf(env.player:K2_GetActorLocation())
   a=g:BeginDeferredActorSpawnFromClass(env.world,ctx.UE.Object('/Script/Engine.Actor'),transform,1,nil);assert(typed(a,'/Script/Engine.Actor'));a=g:FinishSpawningActor(a,transform)
   a.Tags={ctx.UE.FindOrAddFName(arrow and'MC41Arrow'or'MC41Mob'),ctx.UE.FindOrAddFName(tag)}
   local s={index=index,actor=a,tag=tag,parts=parts};(arrow and self.arrows or self.slots)[index]=s
   local root=a:AddComponentByClass(ctx.UE.Object('/Script/Engine.SceneComponent'),false,tf(vec(0,0,0)),false);assert(typed(root,'/Script/Engine.SceneComponent'));root:SetMobility(2)
   for i=1,arrow and 1 or 16 do local c=a:AddComponentByClass(ctx.UE.Object('/Script/Engine.StaticMeshComponent'),false,tf(vec(0,0,0)),false);assert(typed(c,'/Script/Engine.StaticMeshComponent'));c.ComponentTags={ctx.UE.FindOrAddFName('MC41Part:'..i)};c:SetMobility(2);c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false);parts[i]=c end
  end
  local s={index=index,actor=a,tag=tag,parts=parts};(arrow and self.arrows or self.slots)[index]=s
  self:validate(s,env);a:SetActorEnableCollision(false);a:SetActorHiddenInGame(true)
  self:event('pool_created',s,{arrow=arrow,retained=retained~=nil,actor=a:GetAddress()});return s
 end
 function M:paint(s,kind,env,first,last)
  self:validate(s,env)
  if kind=='arrow'and s.paintedKind61==kind then return end
  for i=first or 1,last or #s.parts do local c=s.parts[i];local d=models[kind][i]
   c:SetVisibility(d~=nil,false)
   if d then
     if d.mesh then
      local mesh=self:asset(d.mesh);c:SetStaticMesh(mesh);c:SetMaterial(0,mesh:GetMaterial(0))
     else c:SetStaticMesh(nil)end
    c:K2_AttachToComponent(s.actor.RootComponent,ctx.UE.FindOrAddFName('None'),2,2,2,false)
    ownedPose(c,{location=d.location,rotation=d.rotation,scale=vec(1,1,1)})
    if d.parent then assert(c:K2_AttachToComponent(s.parts[d.parent],ctx.UE.FindOrAddFName('None'),2,2,2,false))end
    if d.name=='bow'then
     local left;for j,p in ipairs(models[kind])do if p.name=='left_arm'then left=s.parts[j]end end
     assert(left);assert(c:K2_AttachToComponent(left,ctx.UE.FindOrAddFName('None'),2,2,2,false))
     local t=display66.skeleton_bow.left;local p=t.Translation
     _G.MC_OUT_K('K2_SetRelativeTransform',c,{Rotation=t.Rotation,Translation=vec(p.X,p.Y,p.Z-75),Scale3D=t.Scale3D},false,ignoredHitJ(),true)
    end
   end
  end;if not last or last==#s.parts then s.paintedKind61=kind;if kind~='arrow'then s.kind=kind;s.models=models[kind];s.bornAt=os.clock();s.root=s.actor.RootComponent;fidelity:bind(s);dofile(ctx.base..'/equipmentK.lua').apply(s,ctx.UE)end end
 end
 function M:flash(s,red)
  local variant=red and 'hit'or s.white and 'white'or nil
  if s.materialVariant==variant then return end;s.materialVariant=variant
   if s.x4 then for _,mid in pairs(s.x4.materials)do mid:SetScalarParameterValue(ctx.UE.FindOrAddFName('Hurt'),red and 1 or 0)end end
 end
 function M:ground(env,x,y,z)
  local hit={};local color={R=0,G=0,B=0,A=0}
  local found=_G.MC_OUT_K('LineTraceSingle',ctx.UE.GetKismetSystemLibrary(),env.player,vec(x,y,z+105),vec(x,y,z-650),0,false,{env.player},0,hit,true,color,color,0)
  if not found or hit.ImpactNormal.Z<.65 then return nil end
  local h=hit.ImpactPoint;local c=ctx.cells()[ctx.key(math.floor(x/100),math.floor(y/100),math.floor((h.Z+4)/100))]
  if c then local name=ctx.registry[c.type].name;if name=='water'or name=='lava'then return nil end end
  local comp=hit.Component:Get();if ctx.valid(comp)then local name=comp:GetFullName():lower();if name:find('water',1,true)or name:find('ocean',1,true)then return nil end end
  
  if h.Z<-2100 then return nil end
  return vec(x,y,h.Z+2)
 end

 function M:sweep(s,env,q)
  local d=defs[s.kind];local p=s.p
  local v,ground,hx,hy,hz=navigation:sweep(p,q,d.radius,d.height)
  s.climbing=s.kind=='spider'and s.climbIntent and(hx or hy)or nil
  if s.climbing and not s.climbLogged then s.climbLogged=true;self:event('climb',s,{ownedBlocksOnly=true})elseif not s.climbing then s.climbLogged=nil end
  if v.X==p.X and v.Y==p.Y and v.Z==p.Z and ground and navigation:clear(v.X,v.Y,v.Z,d.radius,d.height)then
   s.ownedTerrain=true;return v,true,hx,hy,hz
  end

  if q.X==p.X and q.Y==p.Y and q.Z<=p.Z and ground and navigation:supported(p,d.radius)then
   s.ownedTerrain=true;return v,true,hx,hy,hz
  end
  if self.test65 and self.test65.feature=='sweeps'then return v,ground,hx,hy,hz end
  local half=math.max(d.radius,d.height/2);local hit={};local color={R=0,G=0,B=0,A=0}
  local ignored=self.combat.pal and{env.player,self.combat.pal}or{env.player}
  local a=vec(p.X,p.Y,p.Z+half);local b=vec(v.X,v.Y,v.Z+half)
  
  if s.grounded and v.Z>=p.Z and not s.jump then b.Z=b.Z-3 end

  local stationary=s.grounded and not s.jump and q.X==p.X and q.Y==p.Y and q.Z<=p.Z
  local revision=tostring(self.epoch)..':'..tostring(ctx.UE.geometryRevisionL or 0)..':'..tostring(self.combat.pal and self.combat.pal:GetAddress()or 0)
  local key=cacheL.ray(a,b)..':'..s.kind;local now=os.clock();local cached,value
  if stationary then cached,value=cacheL.get(floorCache,key,now,revision)end
  local found
  if cached then found=true;hit=value else
   found=_G.MC_OUT_K('CapsuleTraceSingle',ctx.UE.GetKismetSystemLibrary(),env.player,a,b,d.radius-.5,half-.5,0,false,ignored,0,hit,true,color,color,0)
   if stationary and found and hit.ImpactNormal.Z>.65 then cacheL.put(floorCache,key,now,{ImpactNormal=copy(hit.ImpactNormal),Location=copy(hit.Location),Time=hit.Time})end
  end
  s.sweeps=(s.sweeps or 0)+1
  if found then
   local normal=hit.ImpactNormal;local t=math.max(0,(hit.Time or 0)-.001)
   if normal.Z>.65 and b.Z<=a.Z then
    v.Z=math.max(v.Z,hit.Location.Z-half+2);ground=true;hz=true;s.nativeFloor=v.Z
   else
    v.X=p.X+(v.X-p.X)*t;v.Y=p.Y+(v.Y-p.Y)*t;v.Z=p.Z+(v.Z-p.Z)*t
    hx=math.abs(normal.X)>.1 or hx;hy=math.abs(normal.Y)>.1 or hy;hz=math.abs(normal.Z)>.1 or hz
    s.routeReplan=true;s.nativeBlocked=true
   end
  end
  s.ownedTerrain=s.ownedTerrain or navigation:supported(v,d.radius)
  return v,ground,hx,hy,hz
 end
 function M:plan(s,env,target,now)
  local def=defs[s.kind]
  if self.test65 and self.test65.feature=='astar'then s.goal=copy(target);s.route=nil;return end
  if motion.holdRoute(s)then return end
  if not s.routeReplan and s.routeTarget and dist(target,s.routeTarget)<110 and now<(s.replanAt or 0)then return end
  local route,visited,complete=navigation:path(s,target,def)

  s.climbIntent=s.kind=='spider'and target.Z>s.p.Z+2
  if s.climbIntent then route={};complete=false end

  if s.nativeBlocked then
   local dx,dy=target.X-s.p.X,target.Y-s.p.Y;local n=math.max(1,math.sqrt(dx*dx+dy*dy));local side=s.detourSide or(s.index%2==0 and 1 or-1)
   local q=self:ground(env,s.p.X-dy/n*250*side,s.p.Y+dx/n*250*side,s.p.Z)
   if q and math.abs(q.Z-s.p.Z)<=102 and navigation:clear(q.X,q.Y,q.Z,def.radius,def.height)then route={{X=q.X,Y=q.Y,Z=q.Z}};s.detourUntil=now+1 else s.detourSide=-side end
   s.nativeBlocked=nil
  elseif s.detourUntil and now<s.detourUntil then return end
  s.route=#route>0 and route or nil;s.routeAt=1;s.goal=#route==0 and copy(target)or nil;s.routeTarget=copy(target);s.routeReplan=false;s.replanAt=now+.7
  s.plannedNodes=visited;s.routeComplete=complete
 end
 function M:los(env,a,b)
  local pal=self.combat and self.combat.pal
  local revision=tostring(self.epoch)..':'..tostring(ctx.UE.geometryRevisionL or 0)..':'..tostring(ctx.valid(pal)and pal:GetAddress()or 0)
  local key=cacheL.ray(a,b);local now=os.clock();local cached,result=cacheL.get(sightCache,key,now,revision)
  if cached then return result end
  local hit={};local c={R=0,G=0,B=0,A=0}
  result=not _G.MC_OUT_K('LineTraceSingle',ctx.UE.GetKismetSystemLibrary(),env.player,a,b,0,false,pal and{env.player,pal}or{env.player},0,hit,true,c,c,0)
  cacheL.put(sightCache,key,now,result);return result
 end
 function M:spawn(kind,p,env,prepared)
  assert(defs[kind]and self:guard(env));local s=prepared
  if not s then for _,q in ipairs(self.slots)do if not q.active then s=q;break end end end;if not s then return nil end
  assert(not s.active,'Spawn cannot reuse an active slot')
  if prepared then assert(s==prepared and s.paintedKind61==kind)else self:paint(s,kind,env)end
  self.serial=self.serial+1;self.activation=self.activation+1;s.generation=self.activation;s.kind=kind;s.hp=defs[kind].hp;s.p=copy(p);s.home=copy(p);s.serial=self.serial;s.active=true;s.chasing=false;s.fuse=nil;s.attackAt=os.clock()+1;s.updated=os.clock();s.poof=nil;s.hitAt=0;s.flashUntil=nil;s.retreatSince=nil;s.retreatStopped=nil
  local player=env.player:K2_GetActorLocation();local initialYaw=math.deg(math.atan(player.Y-p.Y,player.X-p.X))
  s.bornAt=os.clock();s.attackStart=nil;s.hurtStart=nil;s.jump=nil;s.climbing=nil;s.goal=nil;s.groundZ=p.Z;s.vz=0;s.yaw=initialYaw;s.targetYaw=initialYaw;s.visualAt=os.clock();s.walk=0;s.walkWeight=0;s.draw=nil;s.deathAt=nil;s.poofPainted=nil;s.materialVariant=nil;s.white=nil;s.attackPose=nil;s.poseCache={};s.scaleCache=1;s.knockUntil=nil;s.shootAt=nil;s.drawStart=nil;s.drawRelease=nil
  s.palAggro=nil;s.targetAddress=nil;s.targetKind=nil;s.dropTo=nil;s.dropFromZ=nil;s.actor:SetActorScale3D(vec(1,1,1))
  motion.reset(s,os.clock(),defs[kind]);s.moveIntent=false;s.nativeFloor=p.Z;s.sweeps=0;s.nativeBlocked=nil;s.detourUntil=nil;s.ownedTerrain=nil;s.lastRenderP=nil;s.lastRenderR=nil
  _G.MC_OUT_K('K2_SetActorLocation',s.actor,s.p,true,{},false);s.actor:K2_SetActorRotation({Pitch=0,Yaw=0,Roll=0},true);s.actor:SetActorHiddenInGame(false);self:event('spawn',s,{night=self:night(env)});return s
 end
 function M:hide(s,env,why)
  self:validate(s,env);s.actor:SetActorHiddenInGame(true);s.active=false;s.pickupZ3=nil;s.fuse=nil;s.poof=nil;s.flashUntil=nil;self:event('despawn',s,{reason=why})
 end
 function M:night(env)
  local tm=ctx.UE.Object('/Script/Pal.Default__PalUtility'):GetTimeManager(env.player);if not ctx.valid(tm)then return false end
  
  local hour=tm:GetCurrentPalWorldTime_Hour();return hour>=18 or hour<6
 end
 function M:damageTarget(target,s,env,fraction)
  if target:GetAddress()==env.player:GetAddress()then self:damage(env,fraction,s.kind)else self.combat:damage(target,s,env,fraction)end
 end
 function M:damage(env,fraction,why)
  local c=env.player.CharacterParameterComponent;local hp,max=c:GetHP().Value,c:GetMaxHP().Value
  if hp<=0 or max<=0 then return end
  if hp/max>fraction then ctx.mechanics:damage(env,fraction,why)
  else
   
   env.status='dead';if ctx.UE.noteDeath78 then ctx.UE.noteDeath78()end;local u=ctx.UE.Object('/Script/Pal.Default__PalUtility');u:SetHPByRateToCharacter(env.player,0);u:ProcessDeadAction(env.player);c:ZeroDyingHP_ToServer();ctx.log('MC41_LETHAL_NATIVE_DEATH cause='..why..' before='..hp)
  end
 end
 function M:shoot(s,env,now)
  local arrow;for _,a in ipairs(self.arrows)do if not a.active then arrow=a;break end end;if not arrow then return end
  local target,p=self.combat:target(s,env);if not target then return end
  self:paint(arrow,'arrow',env);local from=motion.origin(s);local n=dist(from,p);if n<1 then return end
  self.activation=self.activation+1;arrow.generation=self.activation;arrow.p=from;arrow.velocity=motion.ballistic(from,p,1800,600);arrow.active=true;arrow.untilAt=now+3;arrow.updated=now;arrow.kind='arrow'
  arrow.nativeProbeM=nil;arrow.nativeImpactM=nil
  ownedPose(arrow.actor.RootComponent,{location=from,rotation={Pitch=math.deg(math.atan(arrow.velocity.Z,math.sqrt(arrow.velocity.X^2+arrow.velocity.Y^2))),Yaw=math.deg(math.atan(arrow.velocity.Y,arrow.velocity.X)),Roll=0},scale=vec(1,1,1)});arrow.actor:SetActorHiddenInGame(false);self:event('shoot',s,{arrow=arrow.index,origin=copy(from),velocity=copy(arrow.velocity),ballistic=true,drawSeconds=1})
 end
 function M:projectiles(env,now)
  local p
  for _,a in ipairs(self.arrows)do if a.active then
   
   p=p or env.player:K2_GetActorLocation()
   if a.pickupZ3 then self:pickupArrowZ3(env,a,now,p)else
   self:validate(a,env);local dt=math.min(.15,now-a.updated);a.updated=now;local old=a.p;local q=vec(old.X+a.velocity.X*dt,old.Y+a.velocity.Y*dt,old.Z+a.velocity.Z*dt-300*dt*dt);a.velocity.Z=a.velocity.Z-600*dt
   local vx,vy,vz=q.X-old.X,q.Y-old.Y,q.Z-old.Z;local denom=vx*vx+vy*vy+vz*vz;local t=denom>0 and math.max(0,math.min(1,((p.X-old.X)*vx+(p.Y-old.Y)*vy+(p.Z-old.Z)*vz)/denom))or 0
   local near=dist(p,vec(old.X+t*vx,old.Y+t*vy,old.Z+t*vz))<60;local victim=near and env.player or nil
   if self.combat.pal then local pp=self.combat.position;local pt=denom>0 and math.max(0,math.min(1,((pp.X-old.X)*vx+(pp.Y-old.Y)*vy+(pp.Z-old.Z)*vz)/denom))or 0
    if dist(pp,vec(old.X+pt*vx,old.Y+pt*vy,old.Z+pt*vz))<80 and(not victim or pt<t)then victim=self.combat.pal;near=true end
   end

   if not a.nativeImpactM and(not a.nativeProbeM or now>=a.nativeProbeM)then
    local horizon=.35;local hit={};local c={R=0,G=0,B=0,A=0}
    local endp=vec(q.X+a.velocity.X*horizon,q.Y+a.velocity.Y*horizon,q.Z+a.velocity.Z*horizon-300*horizon*horizon)
    local blocked=_G.MC_OUT_K('LineTraceSingle',ctx.UE.GetKismetSystemLibrary(),env.player,q,endp,0,false,self.combat.pal and{env.player,self.combat.pal}or{env.player},0,hit,true,c,c,0)
    a.nativeProbeM=now+horizon
    if blocked then a.nativeImpactM=now+math.max(0,math.min(1,hit.Time or 0))*horizon end
   end
   if a.nativeImpactM and now>=a.nativeImpactM or not navigation:clear(q.X,q.Y,q.Z,1,1)then self:hide(a,env,'arrow_ground')
   elseif near then self:hide(a,env,'arrow_hit');if victim:GetAddress()==env.player:GetAddress()then self:damage(env,.05,'skeleton')else self.combat:damage(victim,a,env,.05)end;self:event('arrow_hit',a,{target=victim:GetAddress()==env.player:GetAddress()and'player'or'pal'});return
   elseif now>a.untilAt then self:hide(a,env,'arrow_timeout')
   else a.p=q;local root=a.actor.RootComponent;ownedPose(root,{location=q,rotation={Pitch=math.deg(math.atan(a.velocity.Z,math.sqrt(a.velocity.X^2+a.velocity.Y^2))),Yaw=math.deg(math.atan(a.velocity.Y,a.velocity.X)),Roll=0},scale=root.RelativeScale3D})end
   end
  end end
 end
 function M:visual(s,env,now)
  if timers.test54 and timers.test54.mob==false then return end
  if not self:guard(env)or not ctx.valid(s.actor)then return end
  if s.poof then
   if now>=s.poof then self:hide(s,env,'killed');return end
   if now-s.deathAt<1 then
    local roll=motion.death(now-s.deathAt)
    s.actor:K2_SetActorRotation({Pitch=0,Yaw=s.yaw or 0,Roll=roll},true)
   else
    if not s.poofPainted then
     if ctx.UE.effects66 then ctx.UE.effects66:emit(env,'death',vec(s.p.X,s.p.Y,s.p.Z+80))end
     s.actor:SetActorHiddenInGame(true);s.poofPainted=true;s.flashUntil=nil;self:event('poof',s,{deathSeconds=now-s.deathAt})
    end
   end;return
  end
  local r=s.render or motion.sample(s,1)
  local oldP=s.lastRenderP
  if not oldP or math.abs(oldP.X-r.p.X)+math.abs(oldP.Y-r.p.Y)+math.abs(oldP.Z-r.p.Z)>.001 then

   local root=s.root or s.actor.RootComponent;s.root=root;local scale=root.RelativeScale3D
   ownedPose(root,{location=r.p,rotation=root.RelativeRotation,scale=vec(scale.X,scale.Y,scale.Z)})
   s.lastRenderP=oldP or{};s.lastRenderP.X=r.p.X;s.lastRenderP.Y=r.p.Y;s.lastRenderP.Z=r.p.Z
  end
  local hurt=s.hurtStart and motion.hurt(now-s.hurtStart)or 0;local direction=math.rad((s.hurtYaw or r.yaw)-r.yaw)
  local rotation={Pitch=hurt*math.sin(direction),Yaw=r.yaw,Roll=hurt*math.cos(direction)};local oldR=s.lastRenderR
  if not oldR or math.abs(oldR.Pitch-rotation.Pitch)+math.abs(oldR.Yaw-rotation.Yaw)+math.abs(oldR.Roll-rotation.Roll)>.01 then s.actor:K2_SetActorRotation(rotation,true);s.lastRenderR=rotation end
  local p=s.lookPoint or self.combat.playerPosition;local dx,dy=p.X-r.p.X,p.Y-r.p.Y
  local headYaw=((r.headYaw or r.yaw)-r.yaw+180)%360-180
  local headPitch=math.deg(math.atan(p.Z+65-(r.p.Z+defs[s.kind].height*.85),math.sqrt(dx*dx+dy*dy)))
  if s.attackPose and now>=s.attackPose then s.attackPose=nil end
  if s.shootAt then
   s.usingBow=true;s.draw=math.max(.01,math.min(1,(now-s.drawStart)/1))
   if now>=s.shootAt then
    if self:los(env,motion.origin(s),p)then self:shoot(s,env,now)end
    s.shootAt=nil;s.drawRelease=now+.18
   end
  elseif s.drawRelease and now>=s.drawRelease then s.draw=nil;s.drawRelease=nil;s.usingBow=false end
   if self.test65 and self.test65.feature=='pose'then return end

   s.modelHeadYaw=headYaw;s.modelHeadPitch=headPitch
   local dt=math.min(.2,now-(s.x4At or now))

   local player=self.combat.playerPosition
   local far=player and(player.X-r.p.X)^2+(player.Y-r.p.Y)^2>3200^2
   if not far or not s.cosmeticAtZ3 or now-s.cosmeticAtZ3>=1/15 then
    s.cosmeticAtZ3=now;s.x4At=now;fidelity:animate(s,now,dt)
   end

 end
 function M:update(s,env,now,night)
  if not s.active then return end;self:validate(s,env)
  if s.poof then return end
  if self.test65 and self.test65.mode~='attacking'then
   s.attackAt=now+1000;s.fuse=nil;s.shootAt=nil;s.moveIntent=self.test65.mode=='moving';s.route=nil
   if s.moveIntent then local q=s.fixtureOrigin65;local direction=math.floor(now/2)%2==0 and 1 or -1;s.goal=vec(q.X+direction*350,q.Y,q.Z)else s.goal=nil end
   return
  end
  local target,p,feet,targetKind=self.combat:target(s,env);if not target then return end
  s.lookPoint=copy(p);s.lookYaw=math.deg(math.atan(p.Y-s.p.Y,p.X-s.p.X));local d=dist(s.p,feet);local playerDistance=dist(s.p,self.combat.playerPosition)
  if not night or playerDistance>8000 then self:hide(s,env,not night and'day'or'far');return end
  local def=defs[s.kind];local eye=vec(s.p.X,s.p.Y,s.p.Z+math.min(def.height*.75,140));local sight=self:los(env,eye,p)
  if not s.chasing and d<=1600 and sight then s.chasing=true;self:event('chase',s)end
  if s.chasing and(d>3200 or dist(s.p,s.home)>3200)then s.chasing=false;s.fuse=nil;self:event('lose',s)end
  s.updated=now;s.aggressive=s.chasing;s.moveIntent=s.chasing
  if not s.chasing then s.route=nil;s.goal=nil end
  if s.chasing then
   if s.kind=='creeper'then
    if (d<=300 or(s.fuse and d<=700))and sight then
     if not s.fuse then s.fuse=now+1.5;ctx.phaseC:play('entity.tnt.primed',s.p,1,env);self:event('hiss',s)end
     if now>=s.fuse then local center={x=math.floor(s.p.X/100),y=math.floor(s.p.Y/100),z=math.floor(s.p.Z/100)};self:event('explode',s);ctx.mechanics:blast(center,env,function(e,fraction)self:damage(e,fraction,'creeper')end);if self.combat.pal and dist(s.p,self.combat.feet)<=600 then self.combat:damage(self.combat.pal,s,env,.35)end;self:hide(s,env,'explode');return end
    elseif s.fuse then s.fuse=nil;self:event('fuse_cancel',s)end
   elseif s.kind=='skeleton'then
    if d<1600 and sight and now>=s.attackAt then s.attackAt=now+2;s.drawStart=now;s.shootAt=now+1;self:event('bow_draw',s)end
   elseif d<=150 and math.abs(s.p.Z-feet.Z)<100 and sight and now>=s.attackAt then
    s.attackAt=now+1;s.attackStart=now;s.attackPose=now+.3;s.moveIntent=false;self:event('attack',s,{damage=def.damage});self:damageTarget(target,s,env,def.damage);return
   end
   local direction=s.kind=='skeleton'and(d<700 and-1 or d<900 and 0 or 1)or(d<110 and 0 or 1)
   if s.fuse then direction=0 end
   local dx,dy=feet.X-s.p.X,feet.Y-s.p.Y;local n=math.sqrt(dx*dx+dy*dy)
   s.goalSpeed=def.goalSpeed;s.moveIntent=direction~=0
   if n>1 and s.moveIntent then
    local goal=copy(feet)
    if direction<0 then goal=vec(s.p.X-dx/n*350,s.p.Y-dy/n*350,s.p.Z);s.goalSpeed=.7 end
    self:plan(s,env,goal,now)
   elseif not s.moveIntent then s.route=nil;s.goal=nil end

  end
 end

 function M:captureSwing(pressedAt)
  local pose=self.inputPose;if not pose or pressedAt-pose.at>.1 or pose.epoch~=self.epoch then return nil end
  local best,distance;local fx,fy=math.cos(math.rad(pose.yaw)),math.sin(math.rad(pose.yaw))
  for _,s in ipairs(self.slots)do if s.active and not s.poof then local dx,dy=s.p.X-pose.player.X,s.p.Y-pose.player.Y;local n=math.sqrt(dx*dx+dy*dy)
   if n<=300 and(n<1 or(dx*fx+dy*fy)/n>=.5)and(not distance or n<distance)then best=s;distance=n end
  end end
  if best then return{index=best.index,serial=best.serial,generation=best.generation,epoch=pose.epoch,player=copy(pose.player),distance=distance,frameAt=pose.at}end
 end
 function M:hit(env,pressedAt,swing)
  if not self:guard(env)or not(ctx.combatInput or ctx.gameplayInput)(env)then return false end
  local weapon=env.player.ShooterComponent:GetHasWeapon()
  
  if ctx.valid(weapon)and not env.player.ShooterComponent:IsCurrentWeaponMelee()then return true end
  local now=os.clock();local latency=pressedAt and now-pressedAt or 0
  if latency>.2 then ctx.log('MC42_SWING_EXPIRED latency='..latency);return false end

  local r=env.controller.PlayerCameraManager:GetCameraRotation();local yaw=math.rad(r.Yaw);local fx,fy=math.cos(yaw),math.sin(yaw);local p=env.player:K2_GetActorLocation();local best,bestDistance
  local currentPlayer=copy(p)
  if swing and swing.epoch==self.epoch then local s=self.slots[swing.index]
   if not s or not s.active or s.poof or s.serial~=swing.serial or s.generation~=swing.generation then return false end
   best=s;bestDistance=swing.distance;p=swing.player
  end
  for _,s in ipairs(self.slots)do if not swing and s.active and not s.poof then
   local dx,dy=s.p.X-p.X,s.p.Y-p.Y;local distance=math.sqrt(dx*dx+dy*dy)
   if distance<=300 and (distance<1 or(dx*fx+dy*fy)/distance>=.5)and(not bestDistance or distance<bestDistance)then best=s;bestDistance=distance end
  end end
  if not best then
   for _,s in ipairs(self.slots)do if s.active and not s.poof and dist(p,s.p)<400 then self:event('hit_miss',s,{rotation={Pitch=r.Pitch,Yaw=r.Yaw},player=copy(p),latency=latency});break end end
   return false
  end;if now<(best.hitAt or 0)then return true end
  self:validate(best,env)
  local id=ctx.valid(weapon)and weapon:GetItemId().StaticId:ToString()or''
  if id:sub(1,3)=='MC_'then if now<(self.cooldown66 or 0)then return true end;self.cooldown66=now+H66.cooldown(id);ctx.UE.attack66={at=now,period=H66.cooldown(id)}end
  local damage=gearDamage(id,balance.meleeUnit);local sword=id:lower():find('sword',1,true)~=nil
  return self:applyHit(best,env,now,id,damage,{latency=latency,distance=bestDistance,captured=swing~=nil,captureAge=swing and pressedAt-swing.frameAt,attackPlayer=copy(p),resolvedPlayer=currentPlayer},p,sword,false)
 end
 function M:applyHit(best,env,now,id,damage,details,p,sword,ranged)
  if not best.active or best.poof or best.hp<=0 or now<(best.hitAt or 0)then return false end
  best.hitAt=now+.5
  local before=best.hp;best.hp=math.max(0,before-damage);best.flashUntil=now+.5;best.hurtStart=now;best.hurtYaw=math.deg(math.atan(p.Y-best.p.Y,p.X-best.p.X));self:flash(best,true)
  details.weapon=id;details.damage=damage;details.hp_before=before;details.hp_after=best.hp;details.hp=best.hp;details.ranged=ranged
  self:event('hit',best,details)
  ctx.log((ranged and'MC43_RANGED_HIT'or'MC41_MOB_HIT')..' id='..best.serial..' hp_before='..before..' hp_after='..best.hp..' weapon='..id..' latency='..details.latency)
  local sprint=not ranged and env.player.CharacterMovement:IsSprint()
  motion.knockback(best,sprint and .9 or .4,p.X-best.p.X,p.Y-best.p.Y,0);best.knockUntil=now+.2
  ctx.phaseC:play('entity.'..best.kind..'.hurt',best.p,.7,env)
  details.critical=not ranged and env.player.CharacterMovement:IsFalling()
  if ctx.UE.effects66 then ctx.UE.effects66:emit(env,details.critical and'crit'or'hit',vec(best.p.X,best.p.Y,best.p.Z+90))end
  if best.hp<=0 then
   ctx.phaseC:play('entity.'..best.kind..'.death',best.p,.7,env)
   self:event('kill',best,{weapon=id,sword=sword,ranged=ranged});local center={x=math.floor(best.p.X/100),y=math.floor(best.p.Y/100),z=math.floor(best.p.Z/100)}
   for id,n in pairs(defs[best.kind].loot)do local item,amount=id,n;ctx.mechanics:enqueue(function(e)ctx.mechanics:drop(e,item,amount,center)end)end
   best.deathAt=now;best.poof=now+1.3;best.goal=nil;best.shootAt=nil;best.draw=nil
  end
  return true
 end
 function M:blast66(env,p)
  local now=os.clock()
  for _,s in ipairs(self.slots)do if s.active and not s.poof and not(s.kind=='creeper'and s.fuse and now>=s.fuse)then
   local d=dist(p,s.p);if d<600 then self:applyHit(s,env,now,'Explosion',math.max(1,math.floor(20*(1-d/600))),{latency=0,explosion=true},p,false,true)end
  end end
 end
 function M:ranged(env,shot)
  if not self:guard(env)or not(ctx.combatInput or ctx.gameplayInput)(env)or shot.epoch~=self.epoch then return false end
  local now=os.clock();local latency=now-shot.at;if latency>.2 then ctx.log('MC43_RANGED_EXPIRED latency='..latency);return false end
  local best,along,offset;local p,f=shot.origin,shot.direction
  for _,s in ipairs(self.slots)do if s.active and not s.poof and s.generation<=shot.activation then
   local center=vec(s.p.X,s.p.Y,s.p.Z+defs[s.kind].height*.6);local dx,dy,dz=center.X-p.X,center.Y-p.Y,center.Z-p.Z
   local t=dx*f.X+dy*f.Y+dz*f.Z;local away=dist(center,vec(p.X+f.X*t,p.Y+f.Y*t,p.Z+f.Z*t))
   if t>=0 and t<=4000 and away<=100 and(not along or t<along)then best=s;along=t;offset=away end
  end end
  if not best then return false end
  
  if not self:los(env,p,vec(p.X+f.X*along,p.Y+f.Y*along,p.Z+f.Z*along))then return false end
  if now<(best.hitAt or 0)then return true end;self:validate(best,env)
  return self:applyHit(best,env,now,shot.weapon,gearDamage(shot.weapon,shot.bow and balance.bowUnit or balance.meleeUnit),{latency=latency,distance=along,rayOffset=offset,nativeShot=true},shot.player,false,true)
 end
 function M:consumeShot(env)
  local shot=self.pendingShot;self.pendingShot=nil
  if not self:guard(env)then self.localAmmo65=nil;return end
  local shooter=env.player.ShooterComponent
  if not ctx.valid(shooter)or shooter:IsCurrentWeaponMelee()then self.localAmmo65=nil;return end
  local weapon=shooter:GetHasWeapon();if not ctx.valid(weapon)then self.localAmmo65=nil;return end
  local id=weapon:GetItemId().StaticId:ToString();local address=weapon:GetAddress()
  local loaded=weapon:GetRemainBulletCount();local ammo=loaded+weapon:GetInventoryBulletCount();local previous=self.localAmmo65
  self.localAmmo65={id=id,address=address,ammo=ammo,loaded=loaded,epoch=self.epoch}

  if id=='MC_Bow'and previous and previous.epoch==self.epoch and previous.address==address and previous.id==id and previous.loaded==loaded+1 and loaded==0 and(ctx.combatInput or ctx.gameplayInput)(env)then
   shot={at=os.clock(),epoch=self.epoch,activation=self.activation,localBowZ3=true}
   ctx.log('MCZ3_LOCAL_BOW_RELEASE loaded_before='..previous.loaded..' loaded_after='..loaded)
  end
  if not shot or shot.epoch~=self.epoch or os.clock()-shot.at>.2 or not(ctx.combatInput or ctx.gameplayInput)(env)then return end
  
  if not previous or previous.epoch~=self.epoch or previous.address~=address or previous.id~=id or ammo>=previous.ammo then return end
  local cam=env.controller.PlayerCameraManager;local r=cam:GetCameraRotation();local pitch,yaw=math.rad(r.Pitch),math.rad(r.Yaw)
  shot.weapon=id;shot.bow=id:lower():find('bow',1,true)~=nil;shot.origin=copy(cam:GetCameraLocation());shot.player=copy(env.player:K2_GetActorLocation());shot.direction=vec(math.cos(pitch)*math.cos(yaw),math.cos(pitch)*math.sin(yaw),math.sin(pitch))
  local hitMob=self:ranged(env,shot)
  if shot.localBowZ3 and not hitMob then self:recoverArrowZ3(env,shot)end
 end
 function M:recoverArrowZ3(env,shot)
  local finish=vec(shot.origin.X+shot.direction.X*4000,shot.origin.Y+shot.direction.Y*4000,shot.origin.Z+shot.direction.Z*4000)
  local hit={};local color={R=0,G=0,B=0,A=0}
  if not _G.MC_OUT_K('LineTraceSingle',ctx.UE.GetKismetSystemLibrary(),env.player,shot.origin,finish,0,false,{env.player},0,hit,true,color,color,0)then return end
  local component=hit.Component:Get();local owner=ctx.valid(component)and component:GetOwner()
  if typed(owner,'/Script/Pal.PalCharacter')then return end
  local arrow;for _,a in ipairs(self.arrows)do if not a.active then arrow=a;break end end;if not arrow then return end
  self:paint(arrow,'arrow',env);local point=hit.ImpactPoint
  arrow.p=vec(point.X-shot.direction.X*16,point.Y-shot.direction.Y*16,point.Z-shot.direction.Z*16)
  local now=os.clock();arrow.pickupZ3={ready=now+math.max(.3,dist(shot.origin,arrow.p)/3000),shown=false};arrow.untilAt=now+60;arrow.active=true;arrow.kind='arrow'
  ownedPose(arrow.actor.RootComponent,{location=arrow.p,rotation={Pitch=math.deg(math.asin(shot.direction.Z)),Yaw=math.deg(math.atan(shot.direction.Y,shot.direction.X)),Roll=0},scale=vec(1,1,1)})
  arrow.actor:SetActorHiddenInGame(true);self:event('arrow_recoverable',arrow,{nativeAmmoSpent=true,playerBow=true,position=copy(arrow.p)});ctx.log('MCZ3_ARROW_RECOVERABLE world_impact=true')
 end
 function M:pickupArrowZ3(env,a,now,p)
  local pickup=a.pickupZ3;if now<pickup.ready then return end
  if not pickup.shown then a.actor:SetActorHiddenInGame(false);pickup.shown=true end
  if now>a.untilAt then self:hide(a,env,'player_arrow_expired');return end
  if dist(p,a.p)<180 then
   local n=ctx.items.native;local before=n:count(env,'Arrow')
   if ctx.UE.drops66 and ctx.UE.drops66:give(env,'Arrow',1,false)then
    local after=n:count(env,'Arrow');assert(after==before+1,'Arrow recovery must conserve ammo')
    self:event('arrow_pickup',a,{before=before,after=after,playerBow=true});ctx.log('MCZ3_ARROW_PICKUP before='..before..' after='..after);self:hide(a,env,'player_arrow_pickup')
   end
  end
 end
 function M:installRanged()
  if self.rangedInstalled then return end
  timers.hook('/Script/Pal.PalShooterComponent:OnShootBullet',function()
   self.pendingShot={at=os.clock(),epoch=self.epoch,activation=self.activation}
  end)
  self.rangedInstalled=true;ctx.log('MC43_RANGED_REGISTERED flag_only=true')
 end
 function M:status(env)
  local rows={};local active=0
  for _,s in ipairs(self.slots)do self:validate(s,env);if s.active then active=active+1 end;rows[#rows+1]={index=s.index,actor=s.actor:GetAddress(),active=s.active or false,kind=s.kind,hp=s.hp,position=s.p,hidden=s.actor.bHidden,parts=#s.parts,yaw=s.yaw,speed=s.speed,draw=s.draw,groundZ=s.groundZ,goal=s.goal,deathAt=s.deathAt,poof=s.poof,pose=s.poseCache,velocity={X=s.vx,Y=s.vy,Z=s.vz},grounded=s.grounded,simTicks=s.simTicks,droppedSeconds=s.droppedSeconds,sweeps=s.sweeps,route=s.route,routeAt=s.routeAt,blockedTicks=s.blockedTicks,walk=s.walk,walkWeight=s.walkWeight,headYaw=s.headYaw}end
  return{combat=self.combat:status(),enabled=ctx.config.mobs,epoch=self.epoch,pool=#self.slots,active=active,arrows=#self.arrows,rows=rows,events=self.events,max_update_ms=self.maxMs,nativeCharacters=0,timerFinished=self.handle and self.handle.finished or false,timerCancelled=self.handle and self.handle.cancelled or false}
 end
 function M:start(env)
  if ctx.config.mobs~=true and not self.fixtureEnabled then ctx.log('MC41_MOBS_DISABLED');return end
  if self.handle and not self.handle.finished and not self.handle.cancelled and self.epoch==ctx.epoch()then return end
  self:installRanged()

  self.combat:reset();self.slots={};self.arrows={};self.poolReady=nil;self.paintJobE=nil;self.epoch=ctx.epoch();assert(self:guard(env))
  
  for _,entry in ipairs({{tag='MC41Mob',dest=self.slots,arrow=false},{tag='MC41Arrow',dest=self.arrows,arrow=true}})do
   local found={};_G.MC_OUT_K('GetAllActorsWithTag',ctx.UE.Object('/Script/Engine.Default__GameplayStatics'),env.player,ctx.UE.FindOrAddFName(entry.tag),found)
   for _,v in ipairs(found)do local a=v:get();if typed(a,'/Script/Engine.Actor')and a:GetWorld():GetAddress()==env.world:GetAddress()then
    for i=1,8 do if a:ActorHasTag(ctx.UE.FindOrAddFName(entry.tag..':'..i))then assert(not entry.dest[i]);self:create(env,i,entry.arrow,a);break end end
   end end
  end
  local epoch=self.epoch;local at=0;local aiAt=0
  self.handle=timers.loop(1,function()
   if epoch~=ctx.epoch()or ctx.quiesced()then return true end;local alive=ctx.environment();if not self:guard(alive)then return false end
   local begin=os.clock();local now=begin;self.combat:refresh(alive);self:consumeShot(alive)
   if #self.slots<8 then self:create(alive,#self.slots+1,false)
   elseif #self.arrows<8 then self:create(alive,#self.arrows+1,true)
   else
    if not self.poolReady then self.poolReady=true;ctx.log('MC41_POOL_READY mobs=8 arrows=8')end

    local anyActive=false
    for _,s in ipairs(self.slots)do if s.active then anyActive=true;if s.flashUntil and now>=s.flashUntil then self:flash(s,false);s.flashUntil=nil;self:event('flash_end',s)end end end
    if anyActive then self.inputPose={player=copy(alive.player:K2_GetActorLocation()),yaw=alive.controller.PlayerCameraManager:GetCameraRotation().Yaw,at=now,epoch=self.epoch}else self.inputPose=nil end
    local night=self:night(alive);if night then self.combat:tick(alive,now)end
    
    if now>=aiAt then aiAt=now+.02;at=at%8+1;local s=self.slots[at];self:update(s,alive,now,night)end
    
    if not ctx.environment()then return false end;self:projectiles(alive,now)
    if not ctx.environment()then return false end
    local paint=self.paintJobE
    if paint then
     if paint.slot.active then self.paintJobE=nil
     else
      timers.measure('mobs:paint-part',self.paint,self,paint.slot,paint.kind,alive,paint.index,paint.index);paint.index=paint.index+1
      if paint.index>#paint.slot.parts then
       self.paintJobE=nil
       if night and not self.pauseSpawn then self:spawn(paint.kind,paint.position,alive,paint.slot)end
      end
     end
    end
    if not self.paintJobE and night and not self.pauseSpawn and now>=self.spawnAt then
     self.spawnAt=now+1;local free=false;for _,s in ipairs(self.slots)do if not s.active then free=true;break end end
     if free then local p=alive.player:K2_GetActorLocation();local angle=math.random()*math.pi*2;local radius=2400+math.random()*4000;local q=self:ground(alive,p.X+math.cos(angle)*radius,p.Y+math.sin(angle)*radius,p.Z+500)
      if q and math.abs(q.Z-p.Z)<500 then
       self.nextType=self.nextType%4+1
       for _,slot in ipairs(self.slots)do if not slot.active then self.paintJobE={slot=slot,kind=kinds[self.nextType],position=q,index=1};break end end
      end
     end
    end
   end
   self.maxMs=math.max(self.maxMs,(os.clock()-begin)*1000);return false
  end,'lua-mobs');ctx.log('MC41_MOBS_START epoch='..epoch)
 end
 timers.onEpoch('mobs-wrappers',function()M.paintJobE=nil;M.slots={};M.arrows={};M.assets={};M.handle=nil;M.epoch=nil;M.poolReady=nil;M.events={};M.pauseSpawn=nil;M.maxMs=0;M.spawnAt=0;M.swingAt=0;M.inputPose=nil;M.pendingShot=nil;M.localAmmo65=nil end)
 timers.frame('pal-readiness',function()if not ctx.quiesced()then local env=ctx.environment();if M:guard(env)then M.combat:refresh(env)end end end)
 M.sweepCallback65c=function(slot,q)return M:sweep(slot,M.sweepEnvironment65c,q)end
 timers.frame('mob-motion',function()
  if ctx.quiesced()or not M.poolReady then return end;local env=ctx.environment();if not M:guard(env)then return end
  local now=os.clock()
  for _,s in ipairs(M.slots)do if s.active then
   if not s.poof then M.sweepEnvironment65c=env;s.render=motion.advance(s,now,M.sweepCallback65c)end
   M:visual(s,env,now)
  end end
 end)
 ctx.UE.mobs66=M
 M.navigation=navigation;M.defs=defs;M.motion=motion;M.combat=dofile(ctx.base..'/pal_combat.lua')(ctx,M);return M
end
