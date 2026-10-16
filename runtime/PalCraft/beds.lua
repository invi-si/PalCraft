-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local Timers=dofile(ctx.base..'/timers.lua');local J=dofile(ctx.base..'/json.lua')
 local B={};local N=ctx.items.native;local dirs={{1,0},{0,1},{-1,0},{0,-1}}

 function B:isCombat(env)
  return env.player:GetBattleMode()or(self.combatUntil or 0)>os.clock()
 end

 Timers.hook('/Script/Pal.PalPlayerCharacter:OnDamagePlayer_Server',function()end,function()
  B.damagePending=true;B.damageEpoch=ctx.epoch()
 end)
 local file,entryFile
 function B:setWorld(world)
  ctx.world=world;file=ctx.base..'/bed-spawn-'..world..'.json';entryFile=ctx.base..'/bed-entry-'..world..'.json'
  self.spawn=nil;self.pendingBed=nil;self.entryRecovered=nil;self.request=nil;self.sleeping=nil;self.health=nil;self.combatUntil=nil
  local f=io.open(file,'rb');if f then local d=J.decode(f:read('*a'));f:close();assert(d.version==1 and d.world==world);self.spawn=d.spawn end
 end
 local function name(c)return c and ctx.registry[c.type].name end
 local function key(c)return ctx.key(c.x,c.y,c.z)end
 function B:write()
  local text=J.encode({version=1,world=ctx.world,spawn=self.spawn or false})
  local f=assert(io.open(file..'.tmp','wb'));assert(f:write(text));f:close()
  local old=io.open(file,'rb');if old then old:close();assert(os.remove(file))end;assert(os.rename(file..'.tmp',file))
 end
 function B:message(env,s)
  if ctx.uiKit then ctx.uiKit.nativeHud=ctx.uiKit.nativeHud or{};ctx.uiKit.nativeHud.action={text=s,time=ctx.UE.Object('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(env.player)}end
  ctx.log('MC25_ACTIONBAR '..s)
 end
 function B:pair(c)
  if name(c)~='bed'or not c.state then return nil end
  local st=c.state;local d=dirs[(st.facing or 0)+1];if not d then return nil end
  local q={x=c.x+(st.half==0 and d[1]or-d[1]),y=c.y+(st.half==0 and d[2]or-d[2]),z=c.z}
  local other=ctx.cells()[key(q)]
  if name(other)~='bed'or not other.state or other.state.facing~=st.facing or other.state.half~=1-st.half then return nil end
  return st.half==0 and c or other,st.half==0 and other or c
 end
 function B:plan(c,env)
  local facing=math.floor((env.controller.PlayerCameraManager:GetCameraRotation().Yaw+45)/90)%4
  local d=dirs[facing+1];local a={x=c.x,y=c.y,z=c.z,type=ctx.types.bed,variant=facing,debug=c.debug,state={facing=facing,half=0}}
  local b={x=c.x+d[1],y=c.y+d[2],z=c.z,type=a.type,variant=facing+4,debug=c.debug,state={facing=facing,half=1}}
  for _,q in ipairs({a,b})do
   if ctx.cells()[key(q)]or ctx.intersects(q,env)or not ctx.emptyNative(q,env)then return nil,'occupied' end
  end
  return a,b
 end
 function B:place(c,env)
  local a,b=self:plan(c,env);if not a then ctx.log('MC25_BED_PLACE_REJECT '..tostring(b));return false end
  local before=N:count(env,'MC_Bed');local slot=N:find(env,'MC_Bed');if before<1 or not slot then return false end
  local consume=not(ctx.UE.creativeMode and ctx.UE.creativeMode:enabled())
  assert(ctx.mutate(key(a),a,env));assert(ctx.mutate(key(b),b,env));if consume then N:dispose(env,slot,1)end;ctx.save()
  assert(N:count(env,'MC_Bed')==before-(consume and 1 or 0));ctx.items.dirty=true
  ctx.log('MC25_BED_PLACED foot='..key(a)..' head='..key(b)..' facing='..a.state.facing..' before='..before..' after='..N:count(env,'MC_Bed'));return true
 end
 function B:remove(k,env,drop)
  local c=ctx.cells()[k];if name(c)~='bed'then return nil end
  local a,b=self:pair(c);local origin=a or c
  assert(ctx.mutate(k,nil,env));local other=a and(key(a)==k and b or a);if other then assert(ctx.mutate(key(other),nil,env))end
  if self.spawn and self.spawn~=false and self.spawn.key==key(origin)then self.spawn=nil;self:write();ctx.log('MC25_SPAWN_INVALIDATED missing_bed')end
  if drop~=false and not c.debug then ctx.mechanics:drop(env,'MC_Bed',1,origin)end
  ctx.save();ctx.items.dirty=true;ctx.log('MC25_BED_REMOVED half='..c.state.half..' pair='..tostring(a~=nil)..' drops='..(drop~=false and not c.debug and 1 or 0));return true
 end
 function B:destination(env)
  local s=self.spawn;if not s or s==false then return nil,'unset' end
  local a,b=self:pair(ctx.cells()[s.key]);if not a then return nil,'missing' end
  local half=env.player.CapsuleComponent:GetScaledCapsuleHalfHeight()
  
  local d=dirs[a.state.facing+1];local choices={{-d[2],d[1]},{d[2],-d[1]},{-d[1],-d[2]}}
  for _,offset in ipairs(choices)do
   local q={x=a.x+offset[1],y=a.y+offset[2],z=a.z};local free=true
   for dz=0,math.ceil(half*2/100)-1 do local r={x=q.x,y=q.y,z=q.z+dz};if ctx.cells()[key(r)]or not ctx.emptyNative(r,env)then free=false;break end end
   if free and(ctx.cells()[ctx.key(q.x,q.y,q.z-1)]or ctx.ground(q,env))then return{X=q.x*100+50,Y=q.y*100+50,Z=q.z*100+half+3},{Pitch=0,Yaw=a.state.facing*90,Roll=0}end
  end
  return nil,'obstructed'
 end

 function B:deadDestination(env)
  local s=self.spawn;if not s or s==false then return nil end
  local a=self:pair(ctx.cells()[s.key]);if not a then return nil end
  local d=dirs[a.state.facing+1]
  for _,o in ipairs({{-d[2],d[1]},{d[2],-d[1]},{-d[1],-d[2]}})do
   local q={x=a.x+o[1],y=a.y+o[2],z=a.z};local free=true
   for dz=0,1 do if ctx.cells()[ctx.key(q.x,q.y,q.z+dz)]then free=false end end
   
   if free and ctx.deadClear(q,env)and(ctx.cells()[ctx.key(q.x,q.y,q.z-1)]or ctx.deadGround(q,env))then
    return{X=q.x*100+50,Y=q.y*100+50,Z=q.z*100+91}
   end
  end
 end
 function B:requestDead(env,useBed)
  assert(env.status=='dead'and ctx.valid(env.state),'Native dead player required')
  local loc=useBed~=false and self:deadDestination(env)or nil
  self.pendingBed=loc and{key=self.spawn.key,at=os.clock()}or nil
  env.state:RequestRespawn()
  ctx.log('MC34_RESPAWN_REQUESTED bed='..tostring(loc~=nil)..' native=true controller_only=true')
 end
 function B:finishRespawn(env)
  local r=self.pendingBed;if not r then return end
  self.pendingBed=nil
  if not env or env.status~='alive'or os.clock()-r.at>120 or not self.spawn or self.spawn==false or self.spawn.key~=r.key then ctx.log('MC34_RESPAWN_BED_CANCELLED stale=true');return end
  local loc,rot=self:destination(env)
  if not loc then ctx.log('MC34_RESPAWN_BED_CANCELLED obstructed=true');return end
  local p=env.player:K2_GetActorLocation()
  env.player.CharacterMovement:StopMovementImmediately()
  assert(_G.MC_OUT_K('K2_SetActorLocation',env.player,loc,false,{},true),'Bed respawn correction failed')
  env.player.CharacterMovement:SetMovementMode(1,0)
  self:register(env,loc,rot)
  local q=env.player:K2_GetActorLocation();local dist=math.sqrt((q.X-loc.X)^2+(q.Y-loc.Y)^2+(q.Z-loc.Z)^2)
  assert(dist<180,'Bed respawn correction did not settle')
  local f=assert(io.open(ctx.base..'/task34-bed-route.json','wb'));f:write(J.encode({world=ctx.world,key=r.key,before={X=p.X,Y=p.Y,Z=p.Z},destination=loc,actual={X=q.X,Y=q.Y,Z=q.Z},distance=dist}));f:close()
  ctx.log('MC34_RESPAWN_BED_ARRIVED distance='..dist..' after_alive_restore=true')
 end
 function B:recordEntry(env)

  os.remove(entryFile)
  if not env or env.status~='alive'then return end
  local loc=self:destination(env);if not loc then return end
  local p=env.player:K2_GetActorLocation()
  if(p.X-loc.X)^2+(p.Y-loc.Y)^2+(p.Z-loc.Z)^2>=180^2 then return end
  local f=assert(io.open(entryFile,'wb'));assert(f:write(J.encode({version=1,world=ctx.world,key=self.spawn.key,position={X=p.X,Y=p.Y,Z=p.Z}})));assert(f:close())
  ctx.log('MC28_BED_ENTRY_RECORDED key='..self.spawn.key)
 end
 function B:recoverEntry(env)
  local f=io.open(entryFile,'rb');if not f then

   if not env or env.status~='alive'then return end
   local loc=self:destination(env);if not loc then return end
   local floor=ctx.cells()[ctx.key(math.floor(loc.X/100),math.floor(loc.Y/100),math.floor(loc.Z/100)-1)]
   local p=env.player:K2_GetActorLocation()
   if floor and(p.X-loc.X)^2+(p.Y-loc.Y)^2<180^2 and p.Z<loc.Z-500 and loc.Z-p.Z<10000 then
    assert(_G.MC_OUT_K('K2_SetActorLocation',env.player,loc,false,{},true),'Owned bed footing correction failed')
    ctx.log('MC63_BED_FOOTING_RECOVERED native_height='..p.Z..' owned_height='..loc.Z);return true
   end
   return
  end
  local text=f:read(512);f:close();os.remove(entryFile)
  local ok,d=pcall(J.decode,text)
  if not ok or type(d)~='table'or d.version~=1 or d.world~=ctx.world or not self.spawn or self.spawn==false or d.key~=self.spawn.key or type(d.position)~='table'then return end
  for _,axis in ipairs({'X','Y','Z'})do local v=d.position[axis];if type(v)~='number'or v~=v or math.abs(v)>10000000 then return end end
  if not env or env.status~='alive'then return end
  local loc=self:destination(env);if not loc then return end
  local q=d.position
  if(q.X-loc.X)^2+(q.Y-loc.Y)^2+(q.Z-loc.Z)^2>=180^2 then return end
  local p=env.player:K2_GetActorLocation()
  if(p.X-q.X)^2+(p.Y-q.Y)^2<180^2 and p.Z<q.Z-500 then
   assert(_G.MC_OUT_K('K2_SetActorLocation',env.player,q,false,{},true),'Recorded bed entry correction failed')
   ctx.log('MC28_BED_LOAD_RECOVERED native_height='..p.Z..' saved_height='..q.Z)
   return true
  end
 end
 function B:register(env,location,rotation)
  local t=ctx.UE.Object('/Script/Pal.Default__PalUtility'):GetNetworkTransmitterByPlayerCharacter(env.player)
  local uid=env.controller:GetPlayerUId();t:GetPlayer():RegisterRespawnPoint_ToServer({A=uid.A,B=uid.B,C=uid.C,D=uid.D},location,rotation)
  ctx.log('MC25_NATIVE_POINT_REGISTERED x='..location.X..' y='..location.Y..' z='..location.Z)
 end
 function B:respawn(env,useBed)
  local loc,rotation;if useBed~=false then loc,rotation=self:destination(env)end
  if loc then self:register(env,loc,rotation)end
  self.pendingBed=loc and{key=self.spawn.key,at=os.clock()}or nil
  env.controller:GetPalPlayerState():RequestRespawn()
  self.request={bed=loc~=nil,location=loc,at=os.clock(),player=env.player:GetAddress()}
  ctx.log('MC25_RESPAWN_REQUESTED bed='..tostring(loc~=nil)..' native=true')
 end
 function B:interact(env,k)
  local c=ctx.cells()[k];if name(c)~='bed'then return false end
  if not ctx.gameplayInput(env)or self.sleeping then return true end
  local a=self:pair(c);if not a then self:message(env,'This bed is incomplete');return true end
  local p=env.player:K2_GetActorLocation();local dx,dy,dz=p.X-(a.x*100+50),p.Y-(a.y*100+50),p.Z-(a.z*100+50)
  if dx*dx+dy*dy+dz*dz>600^2 then return true end
  self.spawn={key=key(a),facing=a.state.facing};self:write();self:message(env,'Respawn point set')
  local tm=ctx.UE.Object('/Script/Pal.Default__PalUtility'):GetTimeManager(env.player);local hour=tm:GetCurrentPalWorldTime_Hour()
  if hour>=5 and hour<19 then self:message(env,'You can only sleep at night');ctx.log('MC25_SLEEP_DAY_REJECT hour='..hour);return true end
  if self:isCombat(env)then self:message(env,'You cannot sleep during combat');ctx.log('MC25_SLEEP_COMBAT_REJECT');return true end
  self.sleeping={stage=1,at=os.clock()+.6,epoch=ctx.epoch(),hour=hour,health=env.player.CharacterParameterComponent:GetHP().Value}
  env.controller.PlayerCameraManager:StartCameraFade(0,1,.6,{R=0,G=0,B=0,A=1},false,true)
  env.controller:SetIgnoreMoveInput(true);env.controller:SetIgnoreLookInput(true);ctx.log('MC25_SLEEP_FADE_OUT hour='..hour)
  return true
 end
 function B:cancel(env)
  if self.sleeping and env then env.controller.PlayerCameraManager:StopCameraFade();env.controller:SetIgnoreMoveInput(false);env.controller:SetIgnoreLookInput(false)end
  self.sleeping=nil;self.request=nil;self.health=nil
 end
 function B:tick(env)
  if self.damagePending then
   self.damagePending=nil
   if self.damageEpoch==ctx.epoch()and env.player:GetBattleMode()then self.combatUntil=os.clock()+8;ctx.log('MC26_COMBAT_DAMAGE master_tick=true')end
  end
  local hp=env.player.CharacterParameterComponent:GetHP().Value
  self.health=hp
  local s=self.sleeping
  if s then
   if s.epoch~=ctx.epoch()or self:isCombat(env)or hp<=0 or env.player.CharacterParameterComponent:GetIndividualParameter():IsDead()or env.controller.bShowMouseCursor or ctx.items.open then self:cancel(env);ctx.log('MC25_SLEEP_CANCELLED');return end
   if os.clock()>=s.at then
    if s.stage==1 then local tm=ctx.UE.Object('/Script/Pal.Default__PalUtility'):GetTimeManager(env.player);tm:SetGameTime_FixDay(5);assert(tm:GetCurrentPalWorldTime_Hour()==5);s.stage=2;s.at=os.clock()+.7
     env.controller.PlayerCameraManager:StartCameraFade(1,0,.7,{R=0,G=0,B=0,A=1},false,false);ctx.log('MC25_SLEEP_MORNING hour=5 before='..s.hour)
    else env.controller:SetIgnoreMoveInput(false);env.controller:SetIgnoreLookInput(false);self.sleeping=nil;ctx.log('MC25_SLEEP_DONE')end
   end
  end
  if self.request and hp>0 and not env.player.CharacterParameterComponent:GetIndividualParameter():IsDead()and os.clock()-self.request.at>.5 then
   local p=env.player:K2_GetActorLocation();local q=self.request.location;local dist=q and math.sqrt((p.X-q.X)^2+(p.Y-q.Y)^2+(p.Z-q.Z)^2)or 0
   if not q or dist<180 then ctx.log('MC25_RESPAWN_ARRIVED bed='..tostring(q~=nil)..' distance='..dist);self.request=nil
   elseif os.clock()-self.request.at>15 then ctx.log('MC25_RESPAWN_LOCATION_FAIL distance='..dist);self.request=nil end
  end
 end
 function B:start(env)
  self:cancel(env);self.health=env.player.CharacterParameterComponent:GetHP().Value
  if self.handle then Timers.cancel(self.handle)end
  local epoch=ctx.epoch();self.handle=Timers.loop(100,function()if ctx.quiesced()or epoch~=ctx.epoch()then return true end;local e=ctx.environment();if e then self:tick(e)end;return false end)
  ctx.log('MC25_BEDS_READY spawn='..tostring(self.spawn and self.spawn~=false and self.spawn.key or'unset'))
 end
 Timers.onEpoch('beds',function()B.sleeping=nil;B.request=nil;B.handle=nil;B.health=nil;B.combatUntil=nil;B.damagePending=nil;B.damageEpoch=nil end)
 return B
end
