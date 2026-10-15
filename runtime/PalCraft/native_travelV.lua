-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,W)
 local UE,valid=ctx.UE,ctx.valid
 local N={id='MC_Island_Plains_V1',guid={A=1296257100,B=1347174734,C=1398166577,D=1}}
 local function v(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 local function g(p)return{A=p.A,B=p.B,C=p.C,D=p.D}end
 local function name(p)return p:ToString()end
 local function manager(e)return UE.Native109(UE.Object('/Script/Pal.Default__PalUtility'),'GetLocationManager',e.player)end
 local function modePath()return ctx.base..'/nativeV-mode-'..tostring(UE.worldScope65.id)..'.json'end
 local function saveMode(d)local f=assert(io.open(modePath(),'wb'));f:write(dofile(ctx.base..'/json.lua').encode(d));f:close()end
 function N:loadMode()
  if self.modeLoaded then return end;self.modeLoaded=true
  local f=io.open(modePath(),'rb');if not f then return end;local raw=f:read('*a');f:close()
  local d=dofile(ctx.base..'/json.lua').decode(raw);self.mode=d.mode;self.markerGuid=d.markerGuid
 end
 function N:hybrid(e)
  self.mode='hybrid';local m=manager(e)
  if self.markerGuid then m:RemoveLocalCustomMarker(self.markerGuid)end
  self.markerGuid=g(m:AddLocalCustomMarker(assert(self.position),0));self.markerReady=true
  saveMode({mode=self.mode,markerGuid=self.markerGuid});ctx.log('MCV_HYBRID_READY native_statue_unlock_custom_pin=true custom_travel=true')
 end
 local function flags(e)
  local rows={};local rec=e.controller:GetPalPlayerState():GetRecordData()

  local array=rec.FastTravelPointUnlockFlag.Items;local count=#array
  assert(count>=0 and count<=1024,'Unexpected fast-travel flag count')
  local seen=0
  array:ForEach(function(_,value)
   local row=value:get();rows[name(row.Key)]=row.Value;seen=seen+1
   if seen>=count then return true end
  end)
  return rows
 end
 function N:point(e)
  local m=manager(e)
  for _,p in ipairs(FindAllOf('PalLocationPointFastTravel')or{})do
   if valid(p)and not p:GetFullName():find('Default__',1,true)and name(p.FastTravelPointID)==self.id then
    local current=m:GetLocationPoint(g(p:GetLocationId()))
    if valid(current)and current:GetAddress()==p:GetAddress()then return p end
   end
  end
 end
 function N:spawn(e,p)
  if valid(self.actor)then return end
  local actors={};_G.MC_OUT_K('GetAllActorsWithTag',UE.Object('/Script/Engine.Default__GameplayStatics'),e.world,UE.FindOrAddFName('MCNativeTravelV:plains'),actors)
  for _,wrap in ipairs(actors)do local a=wrap:get();if valid(a)and a:GetWorld():GetAddress()==e.world:GetAddress()then self.actor=a;self.position=v(p);return end end
  local lib=UE.GetKismetSystemLibrary();local path='/Game/Pal/Blueprint/MapObject/Object/LevelObject/BP_LevelObject_TowerFastTravelPoint.BP_LevelObject_TowerFastTravelPoint_C'
  local cls=UE.Native109(lib,'LoadClassAsset_Blocking',lib:Conv_SoftClassPathToSoftClassRef(lib:MakeSoftClassPath(path)));assert(valid(cls),'Native statue class missing')
  local tf={Translation=v(p),Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
  local gs=UE.Object('/Script/Engine.Default__GameplayStatics')
  local a=gs:BeginDeferredActorSpawnFromClass(e.world,cls,tf,1,nil);assert(valid(a))
  a.FastTravelPointID=UE.FindOrAddFName(self.id);a.LevelObjectInstanceId=self.guid
  a.Tags={UE.FindOrAddFName('MCNativeTravelV'),UE.FindOrAddFName('MCNativeTravelV:plains')}
  a=gs:FinishSpawningActor(a,tf);assert(valid(a));self.actor=a;self.position=v(p)
  ctx.log('MCV_NATIVE_STATUE_READY id='..self.id)
 end
 function N:register(e)
  local m=manager(e);assert(valid(m));local p=self:point(e)
  if not valid(p)then
   p=StaticConstructObject(UE.Object('/Script/Pal.PalLocationPointFastTravel'),m,UE.FindOrAddFName('MC_PlainsLocationV'))
   assert(valid(p),'Native destination construction failed')
   p.ID=self.guid;p.LocationId=self.guid;p.FastTravelPointID=UE.FindOrAddFName(self.id)
   local q=v(assert(self.position));q.X=q.X-240;q.Z=q.Z+e.player.CapsuleComponent:GetScaledCapsuleHalfHeight()+3
   p.Location=q;p.RotationZ=0;p.bShouldDisplay=true;p.bShowInMap=true;p.bShowInCompass=true
   p.ShouldUnlockFlag=true;p.bUnlockMapPoint=true

   m.LocationMapInServer:Add(self.guid,p);m.LocationMapInLocal:Add(self.guid,p);m.LocationMapCombined:Add(self.guid,p)
   self.registration='explicit-native-map'
  else self.registration='native-actor-initialization' end
  local id=g(p:GetLocationId());assert(valid(m:GetLocationPoint(id)),'Native manager rejected destination')
  self.locationGuid=id;ctx.log('MCV_NATIVE_DESTINATION_READY registration='..self.registration)
 end
 function N:start(e)

  if not UE.worldScope65 or not UE.worldScope65:valid(UE.worldScope65.id)then return end
  if not W.points or not W.points.plains or self.failed then return end
  self:loadMode()
  if not self.spawnTried then
   self.spawnTried=true
   local ok,err=pcall(self.spawn,self,e,W.points.plains)
   if not ok then self.failed=tostring(err);ctx.log('MCV_NATIVE_PROTOTYPE_FAIL '..self.failed);return end
  end
  if valid(self.actor)and valid(W.actors.plains)and W.actors.plains:GetAddress()~=self.actor:GetAddress()then
   W.actors.plains:SetActorHiddenInGame(true);W.actors.plains:SetActorEnableCollision(false)
  end
  if valid(self.actor)and self.mode=='hybrid'and not self.markerReady then self:hybrid(e)end
  if valid(self.actor)and self.mode~='hybrid'and self.actor:IsUnlocked()and not self.registerTried then
   self.registerTried=true;local ok,err=pcall(self.register,self,e)
   if not ok then self.registrationError=tostring(err);ctx.log('MCV_NATIVE_REGISTER_FAIL '..self.registrationError)end
  end
 end
 function N:snapshot(e)
  ctx.log('MCV_SNAPSHOT flags-start')
  local d={id=self.id,guid=self.guid,mode=self.mode or'native-prototype',markerGuid=self.markerGuid,registration=self.registration,error=self.failed,registrationError=self.registrationError,player=v(e.player:K2_GetActorLocation()),flags=flags(e),points={}}
  ctx.log('MCV_SNAPSHOT flags-done')
  local ps=e.controller:GetPalPlayerState();d.technology=ps:GetTechnologyData():GetTechnologyPoints();d.bonusIndex=ps:GetRecordData():GetBonusExpTableIndex()
  d.exp=e.player.CharacterParameterComponent:GetIndividualParameter():GetExp()
  ctx.log('MCV_SNAPSHOT rewards-done')
  if valid(self.actor)then d.actor={name=self.actor:GetFullName(),position=v(self.actor:K2_GetActorLocation()),unlocked=self.actor:IsUnlocked(),id=name(self.actor.FastTravelPointID),instance=g(self.actor:GetLevelObjectInstanceId())}end
  local n=0;local m=manager(e)
  ctx.log('MCV_SNAPSHOT points-start')
  for _,p in ipairs(FindAllOf('PalLocationPointFastTravel')or{})do if valid(p)and not p:GetFullName():find('Default__',1,true)then
   local id=name(p.FastTravelPointID);local pos=v(p:GetLocation());local own=id==self.id
   if own or n<8 then
    local gid=g(p:GetLocationId());d.points[#d.points+1]={id=id,guid=gid,position=pos,enabled=p:IsEnableFastTravel(),unlocked=p:IsUnlockMapPoint(),show=p:ShouldDisplay(),showInMap=p:IsShowInMap(),type=p:GetType(),registered=valid(m:GetLocationPoint(gid)),shouldUnlock=p.ShouldUnlockFlag,locationGuid=g(p.LocationId)}
    n=n+1
   end
  end end
  ctx.log('MCV_SNAPSHOT done')
  return d
 end
 function N:command(op,e,r)
  assert(UE.worldScope65:valid(UE.worldScope65.id)and e.status=='alive')
  if op=='register'then self:register(e)
  elseif op=='hybrid'then self:hybrid(e)
  elseif op=='site'then
   local p=v(assert(self.position,'Plains native statue not admitted'));p.X=p.X-220;p.Z=p.Z+e.player.CapsuleComponent:GetScaledCapsuleHalfHeight()+3
   ctx.routes:travelTo(e,p,'taskV-statue',function(a)a.controller:SetControlRotation({Pitch=-8,Yaw=0,Roll=0})end)
  elseif op=='travel'then
   local id=r.guid or self.locationGuid;assert(id,'No registered destination GUID');e.controller:RequestFastTravel_ToServer(id)
  elseif op=='interact'then assert(valid(self.actor));self.actor:OnTriggerInteract(e.player,self.actor:IsUnlocked()and 27 or 26)
  elseif op=='sync'then assert(valid(self.actor));self.actor:OnCompleteSyncPlayer(e.controller:GetPalPlayerState())
  elseif op=='unlock'then
   local tx=UE.Object('/Script/Pal.Default__PalUtility'):GetNetworkTransmitterByPlayerCharacter(e.player)
   tx:GetPlayer():RequestUnlockFastTravelPoint_ToServer(UE.FindOrAddFName(self.id))
  elseif op~='status'then error('Unknown TaskV command '..op)end
  local d=self:snapshot(e);W.write('nativeV',d);ctx.log('MCV_RECEIPT '..op);return d
 end
 function N:reset()self.actor=nil;self.position=nil;self.failed=nil;self.spawnTried=nil;self.registration=nil;self.locationGuid=nil;self.registerTried=nil;self.registrationError=nil;self.modeLoaded=nil;self.markerReady=nil end
 return N
end
