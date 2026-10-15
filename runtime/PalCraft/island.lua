-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local data=ctx.data or dofile(ctx.base..'/island_data.lua');local timers=dofile(ctx.base..'/timers.lua')
 data=dofile(ctx.base..'/island_x6_data.lua')(ctx,data)
 local islandKey=data.key or 'plains';local detailedName='BP_MC_Detailed_'..islandKey:sub(1,1):upper()..islandKey:sub(2)
 local classPath=data.classPath
 local I={data=data,actors={},spawned=0,removed=0,activated=0,prewarm=0,maxMs=0,operations={}}
 local function vec(x,y,z)return{X=x,Y=y,Z=z}end
 local function typed(o,p)return ctx.valid(o)and o:IsA(ctx.UE.Object(p))end
 function I:guard(env,stamp)return env and env.status=='alive'and stamp==ctx.epoch()and not ctx.quiesced()and ctx.ready()end
 timers.onEpoch('island-native-wrappers'..(data.key or 'plains'),function()
  
  I.actors={};I.actor=nil;I.cls=nil;I.handle=nil;I.epoch=nil;I.spawned=0;I.prewarm=0;I.quiet=0;I.admitted=false;I.footingReady=false;I.maxMs=0;I.operations={}
 end)
 function I:height(x,y)
  local a,b=math.floor((x-data.origin.X)/(100*(data.signX or 1)))-(data.min or 0)+1,math.floor((y-data.origin.Y)/(100*(data.signY or 1)))-(data.min or 0)+1
  if a<1 or a>data.size or b<1 or b>data.size or data.heights[a][b]==-99 then return nil end
  return data.origin.Z+data.heights[a][b]*100
 end
 function I:position(x,y)
  local p=vec(data.origin.X+((x+(data.min or 0))*100+50)*(data.signX or 1),data.origin.Y+((y+(data.min or 0))*100+50)*(data.signY or 1),0);p.Z=assert(self:height(p.X,p.Y));return p
 end
 function I:census(env)
  local native={};local found={};local g=ctx.UE.Object('/Script/Engine.Default__GameplayStatics')
  _G.MC_OUT_K('GetAllActorsWithTag',g,env.world,ctx.UE.FindOrAddFName(data.tag or 'MCIslandActor83'),native)
  for _,v in ipairs(native)do local a=v:get()
   if typed(a,'/Script/Engine.Actor')and a:GetWorld():GetAddress()==env.world:GetAddress()then
    assert(a:GetClass():GetFullName()=='BlueprintGeneratedClass '..classPath,'Unexpected island class')
    assert(a:GetOuter():GetAddress()==env.world.PersistentLevel:GetAddress(),'Island must be in persistent level')
    found[#found+1]=a
   end
  end
  assert(#found<=1,'Duplicate cooked island actors');return found
 end
 function I:recoverAdmission(env,a)

  local p=env.player:K2_GetActorLocation();local h=self:height(p.X,p.Y)
  if not h then return end
  local half=env.player.CapsuleComponent:GetScaledCapsuleHalfHeight();local foot=p.Z-half
  if foot>=h-50 then return end
  local ignored={env.player};local color={R=0,G=0,B=0,A=0};local hit,owner
  for _=1,4 do
   hit={};local found=_G.MC_OUT_K('LineTraceSingle',ctx.UE.GetKismetSystemLibrary(),env.player,vec(p.X,p.Y,h+2000),vec(p.X,p.Y,h-50),0,false,ignored,0,hit,true,color,color,0)
   if not found then break end
   local comp=hit.Component:Get();owner=typed(comp,'/Script/Engine.PrimitiveComponent')and comp:GetOwner()or nil
   if not typed(owner,'/Script/Engine.Actor')then break end
   if owner:GetAddress()==a:GetAddress()then break end
   ignored[#ignored+1]=owner;owner=nil
  end
  assert(owner and owner:GetAddress()==a:GetAddress()and hit.ImpactNormal.Z>=.65,'Island admission correction requires verified owned ground')
  local goal=vec(p.X,p.Y,hit.ImpactPoint.Z+half+3);assert(goal.Z-p.Z>0 and goal.Z-p.Z<=5000,'Island admission correction exceeds bounded50m')
  env.player.CharacterMovement:StopMovementImmediately();assert(_G.MC_OUT_K('K2_SetActorLocation',env.player,goal,false,{},true));env.player.CharacterMovement:SetMovementMode(1,0)
  if ctx.entryFooting then ctx.entryFooting(env)end
  ctx.log('MC48_ISLAND_LOAD_RECOVERED before_z='..p.Z..' after_z='..goal.Z..' owned_ground='..hit.ImpactPoint.Z..' same_xy=true')
 end
 function I:start(env)
  if ctx.config.island==false then ctx.log('MC48_ISLAND_DISABLED config=false');return end
  local stamp=ctx.epoch();assert(self:guard(env,stamp),'Island before WORLD_READY/restore completion')
  if self.epoch==stamp and(self.handle or self.admitted)then return end
  self.epoch=stamp;self.quiet=0
  self.handle=timers.loop(100,function()
   if stamp~=ctx.epoch()or ctx.quiesced()then return true end
   local alive=ctx.environment();if not self:guard(alive,stamp)then return false end
   if ctx.streamReady and not ctx.streamReady(alive)then self.quiet=0;return false end
   self.quiet=self.quiet+1;if self.quiet<5 then return false end
   local begin=os.clock();local existing=self:census(alive);local a=existing[1]
   if not a then
    ctx.log('MC48_ISLAND_CLASS_LOAD_BEGIN epoch='..stamp..' key='..(data.key or 'plains'))
    if not typed(self.cls,'/Script/CoreUObject.Class')then
     local lib=ctx.UE.GetKismetSystemLibrary()
     local cls=ctx.UE.Native109(lib,'LoadClassAsset_Blocking',lib:Conv_SoftClassPathToSoftClassRef(lib:MakeSoftClassPath(classPath)))
     assert(typed(cls,'/Script/CoreUObject.Class')and cls:GetFullName()=='BlueprintGeneratedClass '..classPath,'Cooked island class not admitted')
     self.cls=cls;self.classMsZ3=(os.clock()-begin)*1000
     ctx.log('MCZ3_ISLAND_CLASS_READY key='..islandKey..' ms='..self.classMsZ3)
     return false
    end
    local cls=self.cls
    ctx.log('MC48_ISLAND_SPAWN_BEGIN epoch='..stamp..' key='..(data.key or 'plains')..' nearby_entry=true')
    a=alive.world:SpawnActor(cls,data.origin,{Pitch=0,Yaw=0,Roll=0})
    assert(typed(a,'/Script/Engine.Actor'),'Cooked island spawn failed')
    assert(a:GetOuter():GetAddress()==alive.world.PersistentLevel:GetAddress(),'Spawned island has streaming-level outer')
    self.spawned=1

    timers.after(100,function()
     if stamp~=ctx.epoch()or ctx.quiesced()then return end
     local current=ctx.environment();if not self:guard(current,stamp)then return end
     assert(typed(a,'/Script/Engine.Actor')and a:GetWorld():GetAddress()==current.world:GetAddress())
     self:recoverAdmission(current,a);self.footingReady=true
     ctx.log('MC48_ISLAND_ARRIVAL_READY epoch='..stamp)
    end,'island-admission-footing'..(data.key or 'plains'))
   else self.footingReady=true;ctx.log('MC48_ISLAND_REACQUIRED epoch='..stamp..' respawn_no_duplicate=true')end
   self.actor=a;self.actors={island=a};self.prewarm=#data.chunks

   if ctx.UE.texRuntime then
    ctx.UE.texRuntime:actor(a,function()
     if stamp~=ctx.epoch()or not ctx.valid(a)then return end
     self.admitted=true;self.handle=nil
     ctx.log('PALCRAFT_ISLAND_BIND_READY key='..islandKey)
    end)
   else self.admitted=true;self.handle=nil end
   self.maxMs=(os.clock()-begin)*1000
   self.operations={{kind='class',ms=self.classMsZ3 or 0},{kind=self.spawned==1 and'spawn'or'reacquire',ms=self.maxMs}}
   ctx.log('MC48_ISLAND_READY actors=1 chunks='..#data.chunks..' columns=81 epoch='..stamp..' actor='..a:GetAddress()..' outer='..a:GetOuter():GetFullName()..' ms='..self.maxMs..' key='..(data.key or 'plains'))
   return true
  end,'island-cooked-once'..(data.key or 'plains'))
 end
 function I:inspect(env)
  assert(self:guard(env,ctx.epoch())and self.admitted,'Island not ready')
  local native=self:census(env);assert(#native==1);local a=native[1]
  assert(a:GetAddress()==self.actor:GetAddress()and not a.bHidden and a:GetActorEnableCollision(),'Island identity/visibility/collision changed')
  local result=a:K2_GetComponentsByClass(ctx.UE.Object('/Script/Engine.StaticMeshComponent'));local rows={};local seen={};local expected={};for _,row in ipairs(data.chunks)do expected[row.name]=row end
  for _,v in ipairs(result)do
   local ok,c=pcall(function()return v:get()end);c=ok and c or v;assert(typed(c,'/Script/Engine.StaticMeshComponent')and c:GetOwner():GetAddress()==a:GetAddress())
   local mesh=c.StaticMesh;assert(typed(mesh,'/Script/Engine.StaticMesh'));local name=mesh:GetFullName():match('%.(SM_%a+_%d+_%d+_%a+)$');assert(name and not seen[name]);seen[name]=true
   assert(expected[name]and c:GetCollisionEnabled()==expected[name].collision and c.Mobility==0 and not c.bHiddenInGame,'Authored component defaults changed')
   rows[#rows+1]={name=name,actor=a:GetAddress(),component=c:GetAddress(),mesh=mesh:GetAddress(),meshPath=mesh:GetFullName(),outer=a:GetOuter():GetAddress(),collision=c:GetCollisionEnabled(),mobility=c.Mobility}
  end
  assert(#rows==#data.chunks,'Cooked island component count mismatch');for _,c in ipairs(data.chunks)do assert(seen[c.name],'Missing chunk '..c.name)end
  return{nativeActors=#native,persistentLevel=env.world.PersistentLevel:GetAddress(),rows=rows,status=self:status()}
 end
 function I:status()
  return{architecture='cooked-default-single-actor',chunks=self.admitted and #data.chunks or 0,pool=self.admitted and 1 or 0,expected=#data.chunks,prewarm=self.prewarm,spawned=self.spawned,removed=0,activated=self.admitted and 1 or 0,max_stream_operation_ms=self.maxMs,operations=self.operations,epoch=self.epoch,destroyed=0}
 end
 return dofile(ctx.base..'/island_actorB.lua')(ctx,I)
end
