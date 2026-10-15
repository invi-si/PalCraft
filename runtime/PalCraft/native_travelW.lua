-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,W)
 local UE,valid=ctx.UE,ctx.valid;local T=dofile(ctx.base..'/timers.lua')
 local N={order={'plains','desert','jungle','mushroom'},rows={}}
 local function v(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 local function g(p)return{A=p.A,B=p.B,C=p.C,D=p.D}end
 local function name(p)return p:ToString()end
 local function manager(e)return UE.Native109(UE.Object('/Script/Pal.Default__PalUtility'),'GetLocationManager',e.player)end
 local ids={plains={A=1296257100,B=1347174734,C=1398166577,D=1},desert={A=1296257100,B=1145394002,C=1415009841,D=2},jungle={A=1296257100,B=1247104583,C=1279604273,D=3},mushroom={A=1296257100,B=1297437512,C=1380929329,D=4}}
 local function flags(e)
  local rows={};local array=e.controller:GetPalPlayerState():GetRecordData().FastTravelPointUnlockFlag.Items
  local count=#array;assert(count>=0 and count<=1024,'Unexpected fast-travel flag count')
  local seen=0
  if count>0 then array:ForEach(function(_,value)local row=value:get();rows[name(row.Key)]=row.Value;seen=seen+1;if seen>=count then return true end end)end
  return rows
 end
 function N:point(e,row)
  local p=manager(e):GetLocationPoint(row.guid)
  if valid(p)and p:IsA(UE.Object('/Script/Pal.PalLocationPointFastTravel'))then return p end
 end
 function N:spawn(e,key)
  local row=self.rows[key];if row and valid(row.actor)then return end
  row=row or{key=key,id='MC_Island_'..key:sub(1,1):upper()..key:sub(2)..'_V1',guid=ids[key],position=v(ctx.island.all[key].data.nativeStatuePad.center)}
  self.rows[key]=row
  local actors={};local gs=UE.Object('/Script/Engine.Default__GameplayStatics')
  _G.MC_OUT_K('GetAllActorsWithTag',gs,e.world,UE.FindOrAddFName('MCNativeTravelV:'..key),actors)
  for _,wrap in ipairs(actors)do local a=wrap:get();if valid(a)and a:GetWorld():GetAddress()==e.world:GetAddress()then row.actor=a;return end end
  if not valid(self.cls)then
   local lib=UE.GetKismetSystemLibrary();local path='/Game/Pal/Blueprint/MapObject/Object/LevelObject/BP_LevelObject_TowerFastTravelPoint.BP_LevelObject_TowerFastTravelPoint_C'
   self.cls=UE.Native109(lib,'LoadClassAsset_Blocking',lib:Conv_SoftClassPathToSoftClassRef(lib:MakeSoftClassPath(path)));assert(valid(self.cls),'Native statue class missing')
  end
  local tf={Translation=v(row.position),Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
  local a=gs:BeginDeferredActorSpawnFromClass(e.world,self.cls,tf,1,nil);assert(valid(a))
  a.FastTravelPointID=UE.FindOrAddFName(row.id);a.LevelObjectInstanceId=row.guid
  a.Tags={UE.FindOrAddFName('MCNativeTravelV'),UE.FindOrAddFName('MCNativeTravelV:'..key)}
  a=gs:FinishSpawningActor(a,tf);assert(valid(a));row.actor=a
  ctx.log('MCW_NATIVE_STATUE_READY key='..key..' id='..row.id)
 end
 function N:start(e)
  if self.failed then return end

  if UE.loadingCover51 and(UE.loadingCover51.at or UE.loadingCover51.armed)then
   if not self.deferX then self.deferX=true;ctx.log('MCX_STARTUP_DEFER native_statues=true distant_islands=true')end
   return
  end

  local key=self.order[(self.index or 0)+1]
  if key then
   local ok,err=pcall(self.spawn,self,e,key)
   if not ok then self.failed=tostring(err);ctx.log('MCW_NATIVE_FAIL '..self.failed);return end
   self.index=(self.index or 0)+1
  end
  for _,k in ipairs(self.order)do local row=self.rows[k]
   if row and valid(row.actor)then
    local unlocked=row.actor:IsUnlocked();local p=self:point(e,row)

    if valid(p)and p.bUnlockMapPoint~=unlocked then p.bUnlockMapPoint=unlocked;ctx.log('MCW_MAP_DISCOVERY key='..k..' unlocked='..tostring(unlocked))end
   end
  end
  if not self.legacyCleaned then
   self.legacyCleaned=true
   local path=ctx.base..'/nativeV-mode-'..tostring(UE.worldScope65.id)..'.json';local f=io.open(path,'rb')
   if f then local raw=f:read('*a');f:close();local d=dofile(ctx.base..'/json.lua').decode(raw)
    if d.markerGuid then manager(e):RemoveLocalCustomMarker(d.markerGuid)end
    f=assert(io.open(path,'wb'));f:write(dofile(ctx.base..'/json.lua').encode({mode='native-W',legacyRetired=true}));f:close()
   end
  end
 end
 function N:snapshot(e)
  local d={mode='native-W',normalPlay=true,error=self.failed,player=v(e.player:K2_GetActorLocation()),flags=flags(e),statues={},points={}}
  local ps=e.controller:GetPalPlayerState();d.technology=ps:GetTechnologyData():GetTechnologyPoints();d.bonusIndex=ps:GetRecordData():GetBonusExpTableIndex();d.exp=e.player.CharacterParameterComponent:GetIndividualParameter():GetExp()
  for _,key in ipairs(self.order)do local row=self.rows[key]
   if row then
    local x={id=row.id,guid=row.guid,position=row.position};d.statues[key]=x
    if valid(row.actor)then x.actor=row.actor:GetFullName();x.unlocked=row.actor:IsUnlocked();x.actual=v(row.actor:K2_GetActorLocation())end
    local p=self:point(e,row)
    if valid(p)then x.point={id=name(p.FastTravelPointID),position=v(p:GetLocation()),enabled=p:IsEnableFastTravel(),unlockedMap=p:IsUnlockMapPoint(),show=p:ShouldDisplay(),showInMap=p:IsShowInMap(),type=p:GetType(),registered=true}end
   end
  end
  local m=manager(e)
  for _,p in ipairs(FindAllOf('PalLocationPointFastTravel')or{})do
   if valid(p)and not p:GetFullName():find('Default__',1,true)and valid(m:GetLocationPoint(g(p:GetLocationId())))then
    d.points[#d.points+1]={id=name(p.FastTravelPointID),guid=g(p:GetLocationId()),position=v(p:GetLocation()),enabled=p:IsEnableFastTravel(),showInMap=p:IsShowInMap()}
   end
  end
  return d
 end
 function N:command(op,e,r)
  assert(UE.worldScope65:valid(UE.worldScope65.id)and e.status=='alive')
  local key=r.island or'plains';local island=assert(ctx.island.all[key]);local row=self.rows[key]
  if op=='site'or op=='arrival'or op=='habitat'or op=='position'then
   assert(not self.sitePending,'Prior W site still pending');self.sitePending=true
   local epoch=ctx.epoch();local begin=os.clock();local desired
   if op=='site'then desired=v(assert(row).position);desired.X=desired.X-220
   elseif op=='arrival'then desired=v(island.data.arrival)
   elseif op=='habitat'then desired=v(assert(UE.customPalsA.data[r.species]).ground);desired.X=desired.X-650
   else desired=v(assert(r.position))end
   UE.loadingCover51:show(e)
   T.loop(100,function()
    if epoch~=ctx.epoch()then self.sitePending=nil;return true end
    local env=ctx.environment();if not env or not ctx.island:request(key,env)then return false end
    local p=W.ground(env,desired,true);p.Z=p.Z+env.player.CapsuleComponent:GetScaledCapsuleHalfHeight()+3
    ctx.routes:travelTo(env,p,'taskW-'..op,function(a)
     a.controller:SetControlRotation({Pitch=r.pitch or -6,Yaw=r.yaw or 0,Roll=0});N.sitePending=nil
     W.write('W-arrival',{island=key,kind=op,seconds=os.clock()-begin,position=v(a.player:K2_GetActorLocation())});ctx.log('MCW_SITE_READY island='..key..' kind='..op)
    end);return true
   end,'taskW-site')
  elseif op=='quality'then
   
   local keys={'ViewDistance','AntiAliasing','Shadow','GlobalIllumination','Reflection','PostProcess','Texture','Effects','Foliage','Shading'}
   local accepted={};for _,k in ipairs(keys)do accepted[k..'Quality']=true end
   for k,n in pairs(assert(r.quality))do assert(accepted[k]and type(n)=='number'and n%1==0 and n>=0 and n<=4,'Invalid quality request')end
   local lib=UE.GetKismetSystemLibrary();local applied={}
   for _,k in ipairs(keys)do local name=k..'Quality';local n=r.quality[name];if n~=nil then
    lib:ExecuteConsoleCommand(e.player,'sg.'..name..' '..n,e.controller)
    applied[name]=lib:GetConsoleVariableIntValue('sg.'..name);assert(applied[name]==n,'Quality CVar did not apply: '..name)
   end end
   lib:ExecuteConsoleCommand(e.player,'t.MaxFPS 30',e.controller)
   local cap=lib:GetConsoleVariableIntValue('t.MaxFPS');assert(cap==30,'30 FPS cap did not apply')
   W.write('W-quality',{requested=r.quality,applied=applied,fpsCap=cap})
  elseif op=='inspect'then
   local d={island=key,actor=island:inspect(e),habitats={}}
   for id,spec in pairs(UE.customPalsA.data)do if spec.island==key then d.habitats[id]=spec end end
   d.customActors={};for _,a in ipairs(UE.customPalsA.actors)do if valid(a.actor)then d.customActors[#d.customActors+1]={id=a.id,position=v(a.actor:K2_GetActorLocation())}end end
   W.write('W-inspect',d)
  elseif op=='ui'then
   local G=dofile(ctx.base..'/native_widgetG.lua')(UE,valid);local d={cursor=e.controller.bShowMouseCursor,widgets={}}
   for _,w in ipairs(FindAllOf('PalActivatableWidget')or{})do
    if G:active(w,e.controller)then local x={name=w:GetFullName(),visible=G:visible(w,e.controller),opacity=w:GetRenderOpacity(),input=w.InputConfig,ancestors={}};d.widgets[#d.widgets+1]=x
     if w:GetClass():GetFullName():find('WBP_Map_Base',1,true)then
      local node=w
      for _=1,12 do if not valid(node)or not node:IsA(UE.Object('/Script/UMG.Widget'))then break end
       x.ancestors[#x.ancestors+1]={name=node:GetFullName(),opacity=node:GetRenderOpacity(),visible=node:IsVisible()}
       local parent=node:GetParent();if not valid(parent)then local outer=node:GetOuter();if valid(outer)and outer:IsA(UE.Object('/Script/UMG.WidgetTree'))then parent=outer:GetOuter()end end;node=parent
      end
     end
    end
   end
   W.write('W-ui',d)
  elseif op~='status'then error('Unknown TaskW native command '..op)end
  local d=self:snapshot(e);W.write('nativeV',d);ctx.log('MCW_RECEIPT '..op);return d
 end
 function N:reset()self.quietStartZ3=nil;self.rows={};self.index=nil;self.failed=nil;self.cls=nil;self.legacyCleaned=nil;self.sitePending=nil;self.deferX=nil end
 return N
end
