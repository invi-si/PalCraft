-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,I)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua');local d=I.data
 local key=d.key or 'plains';local title=key:sub(1,1):upper()..key:sub(2)
 local asset='/Game/MinecraftIsland114_'..key..'/L_MC_'..title..'.L_MC_'..title
 local color={R=0,G=0,B=0,A=0}
 local function vec(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 function I:owns(a)
  if not valid(a)or not valid(self.level)then return false end
  local level=a:GetLevel();return valid(level)and level:GetAddress()==self.level:GetAddress()
 end
 local function ground(e,p)
  local hit={};local ok=_G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,
   {X=p.X,Y=p.Y,Z=p.Z+600},{X=p.X,Y=p.Y,Z=p.Z-700},0,false,{e.player},0,hit,true,color,color,0)
  local c=ok and hit.Component and hit.Component:Get()
  if not valid(c)or not I:owns(c:GetOwner())or hit.ImpactNormal.Z<.65 then return end
  return vec(hit.ImpactPoint),c:GetOwner()
 end
 function I:start(e)
  if ctx.config.island==false then return end
  local stamp=ctx.epoch();assert(self:guard(e,stamp),'Stream before WORLD_READY/services')
  if self.streamEpoch==stamp then return end
  self.streamEpoch=stamp;self.epoch=stamp;self.started=os.clock();self.streamState='requested';self.stableB=0
  self.handle=T.loop(100,function()
   if stamp~=ctx.epoch()or ctx.quiesced()then return true end
   local env=ctx.environment();if not self:guard(env,stamp)then return false end
   if self.streamState=='requested' then
    if ctx.streamReady and not ctx.streamReady(env)then return false end
    self.streamState='loading' 
    local lib=UE.GetKismetSystemLibrary();local ref=lib:Conv_SoftObjPathToSoftObjRef(lib:MakeSoftObjectPath(asset))
    local began=os.clock()

    local fn=UE.Object('/Script/Engine.LevelStreamingDynamic:LoadLevelInstanceBySoftObjectPtr')
    local out={};local values={WorldContextObject=env.world,Level=ref,Location=d.origin,
     Rotation={Pitch=0,Yaw=0,Roll=0},bOutSuccess=out,OptionalLevelNameOverride='MC_B_'..key,
     bLoadAsTempPackage=false}
    local known={WorldContextObject=true,Level=true,Location=true,Rotation=true,bOutSuccess=true,
     OptionalLevelNameOverride=true,OptionalLevelStreamingClass=true,bLoadAsTempPackage=true}
    local args,order={},{};local count=0
    fn:ForEachProperty(function(prop)
     local full=prop:GetFullName();local name=full:match('([^:]+)$')
     if name~='ReturnValue' then
      assert(known[name],'Unexpected streaming parameter: '..full)
      count=count+1;args[count]=values[name];order[count]=full
     end
    end)
    assert(count==8,'Expected eight reflected streaming inputs')
    ctx.log('MCB_STREAM_SIGNATURE '..table.concat(order,' | '))
    self.stream=UE.Object('/Script/Engine.Default__LevelStreamingDynamic'):LoadLevelInstanceBySoftObjectPtr(table.unpack(args,1,count))
    assert(valid(self.stream),'Owned island stream load rejected: '..key)
    self.maxMs=(os.clock()-began)*1000;self.spawned=1
    ctx.log('MCB_STREAM_REQUEST key='..key..' epoch='..stamp..' ms='..self.maxMs)
   end
   assert(os.clock()-self.started<90,'Owned island shown/collision timeout: '..key)
   if not self.stream:IsLevelLoaded()or not self.stream:IsLevelVisible()then return false end
   self.level=self.stream:GetLoadedLevel();if not valid(self.level)then return false end
   if UE.texRuntime and not self.texturesReadyRA then
    if not self.texturesStartedRA then self.texturesStartedRA=true;UE.texRuntime:level(self.level,function()self.texturesReadyRA=true end)end
    return false
   end
   local landing,owner=ground(env,d.arrival)
   if not landing then self.stableB=0;return false end
   self.stableB=self.stableB+1;if self.stableB<2 then return false end
   self.actor=owner;self.actors={island=owner};self.admitted=true;self.footingReady=true;self.prewarm=#d.chunks
   self.streamState='ready';self.handle=nil;self.collisionB=landing
   
   local p=env.player:K2_GetActorLocation();local h=self:height(p.X,p.Y)
   if h then
    local half=env.player.CapsuleComponent:GetScaledCapsuleHalfHeight()
    if p.Z-half<h-50 then
     local q=ground(env,{X=p.X,Y=p.Y,Z=h})
     if q and q.Z+half+3-p.Z>0 and q.Z+half+3-p.Z<=5000 then
      q.Z=q.Z+half+3;env.player.CharacterMovement:StopMovementImmediately()
      assert(_G.MC_OUT_K('K2_SetActorLocation',env.player,q,false,{},true));env.player.CharacterMovement:SetMovementMode(1,0)
      if ctx.entryFooting then ctx.entryFooting(env)end
     end
    end
   end
   ctx.log('MCB_STREAM_READY key='..key..' seconds='..(os.clock()-self.started)..' level='..self.level:GetFullName())
   ctx.log('MC48_ISLAND_ARRIVAL_READY epoch='..stamp..' key='..key)
   return true
  end,'island-streamB-'..key)
 end
 function I:status()
  return{architecture='cooked-streamed-level-T114',asset=asset,state=self.streamState,epoch=self.epoch,
   spawned=self.spawned,admitted=self.admitted,footingReady=self.footingReady,collision=self.collisionB,
   nativePathing=self.nativePathingB or false,max_stream_operation_ms=self.maxMs,removed=0,destroyed=0}
 end
 function I:inspect(e)
  assert(self:guard(e,ctx.epoch())and self.admitted and self.stream:IsLevelVisible())
  assert(ground(e,d.arrival),'Streamed landing collision lost');return{status=self:status(),rows={}}
 end
 T.onEpoch('island-streamB-'..key,function()
  I.texturesStartedRA=nil;I.texturesReadyRA=nil;I.stream=nil;I.level=nil;I.streamEpoch=nil;I.streamState=nil;I.stableB=nil;I.collisionB=nil;I.nativePathingB=nil
 end)
 return I
end
