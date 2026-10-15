-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local W={open=false,busy=false,actors={}};local UE,U,T=ctx.UE,ctx.uiKit,dofile(ctx.base..'/timers.lua')
 local support=dofile(ctx.base..'/placement109.lua')(UE,ctx.log)
 local function vec(p)return{X=p.X,Y=p.Y,Z=p.Z}end
 local function dist(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)end
 local function write(name,d)local f=assert(io.open(ctx.base..'/task83-'..name..'.json','wb'));f:write(dofile(ctx.base..'/json.lua').encode(d));f:close()end
 local function ground(e,p,owned,soft)
  local ignored={e.player};for _,a in pairs(W.actors)do ignored[#ignored+1]=a end
  local hit={};local c={R=0,G=0,B=0,A=0}
  local ok=_G.MC_OUT_K('LineTraceSingle',UE.GetKismetSystemLibrary(),e.player,{X=p.X,Y=p.Y,Z=p.Z+500},{X=p.X,Y=p.Y,Z=p.Z-600},0,false,ignored,0,hit,true,c,c,0)
  if not ok or hit.ImpactNormal.Z<.65 then if soft then return nil end;error('Waystone ground missing/slope')end
  if owned then local part=hit.Component:Get();if not(ctx.valid(part)and ctx.island:owned(part:GetOwner()))then if soft then return nil end;error('Arrival must hit owned island')end end
  return{X=p.X,Y=p.Y,Z=hit.ImpactPoint.Z}
 end

 function W:start(e)
  self.epoch=ctx.epoch();self.points={};self.order={'plains','mushroom','desert','jungle','base'}
  local b=ctx.beds:destination(e)
  if b then self.basePoint={X=b.X-700,Y=b.Y-700,Z=b.Z-90};self.points.base=self.basePoint end
  for k,i in pairs(ctx.island.all)do self.points[k]=vec(i.data.nativeStatuePad.center)end
 end
 function W:near(e)
  if not self.points then return end
  local p=e.player:K2_GetActorLocation()
  for k,q in pairs(self.points)do if dist(p,{X=q.X,Y=q.Y,Z=q.Z+90})<=360 then return k end end
 end
 function W:create(e)
  local r=ctx.create(e,'WBP_MCOptions','inventory',true);self.widget=r.widget
  local root=ctx.widgets(self.widget).CanvasPanel_0;root:ClearChildren();self.ns={CanvasPanel_0=root}
  local s,_,dpi,size=U:metrics(e);self.unit=math.max(1,math.min(s,math.floor(size.Y/290),math.floor(size.X/410)))/dpi
  local n,u=self.ns,self.unit
  local function image(key,x,y,w,h,color,z)
   local a=U:makeNode(n,key,'Image');U:position(a,x,y,w,h,u);U:fill(a,color,1);a.Slot:SetZOrder(z or 20);return a
  end
  local function text(key,x,y,w,h,value)
   local a=U:makeNode(n,key,'TextBlock');U:position(a,x,y,w,h,u);U:textStyle(a,u,true);U:putText(a,value);a.Slot:SetZOrder(30);a:SetVisibility(3);return a
  end
  local dim=U:makeNode(n,'Dim','Image');U:fill(dim,'211C19',1);dim.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}});dim.Slot:SetPosition({X=0,Y=0});dim.Slot:SetSize({X=0,Y=0});dim.Slot:SetZOrder(0)
  U:panel57(n,376,242,u);text('Title',-172,-108,344,15,UE.language57 and UE.language57.lang=='ko'and'웨이스톤 여행'or'Waystone travel')
  image('Sea',-172,-84,158,176,'244d68')
  local korean=UE.language57 and UE.language57.lang=='ko'
  self.labels={base=korean and '기지'or'Base',plains=korean and '초원 섬'or'Plains',mushroom=korean and '버섯 섬'or'Mushroom',desert=korean and '사막 섬'or'Desert'}
  self.labels.jungle=korean and '정글 섬'or'Jungle'
  local colors={plains='658d44',mushroom='976a96',desert='ceb675',base='ffe274',jungle='337744'}
  for i,k in ipairs(self.order)do
   local y=-77+(i-1)*self.rowGap
   image('Island'..k,-155,y,125,28,colors[k]);text('Label'..k,-147,y+8,109,14,self.labels[k])
   local b=U:makeNode(n,'Button'..k,'Image');U:brush(b,'T_MC_UI_widget_button');U:position(b,2,y,168,28,u);b.Slot:SetZOrder(24);text('ButtonText'..k,9,y+9,154,14,self.labels[k])
  end
  text('Hint',2,88,166,13,korean and '목적지 선택'or'Select destination');text('Footer',-171,101,344,13,'F: Travel    Esc: Close')
 end
 function W:show(e)
  
  return
 end
 function W:close(e)
  if not self.open then return end;self.open=false;U:releaseInput(self.widget)
  if ctx.valid(self.widget)then self.widget:SetRenderOpacity(0)end
  e.controller:ResetIgnoreMoveInput();e.controller:ResetIgnoreLookInput();e.controller.bShowMouseCursor=false
  UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(e.controller,true)
  ctx.items.escapeUntil=os.clock()+.5;ctx.menu.escapeDirty=nil;ctx.menu.escapeDue=nil;ctx.log('MC83_TRAVEL_MENU_CLOSED')
 end
 function W:go(target,e)
  if self.busy or target==self.current or not self:near(e)then return end
  local destination=ctx.island.all[target];local p=destination and vec(destination.data.arrival)or vec(assert(ctx.beds:destination(e)))
  if target=='base'then p.X=p.X-550;p.Y=p.Y-700 end
  self:close(e);self.busy=true;self.destination=target;self.departed=vec(e.player:K2_GetActorLocation());self.at=os.clock();UE.loadingCover51:show(e)
  e.controller:SetIgnoreMoveInput(true);e.controller:SetIgnoreLookInput(true)
  local epoch=ctx.epoch()
  T.loop(100,function()
   if epoch~=ctx.epoch()then return true end;local env=ctx.environment();if not env then return false end
   local assetsReady=not UE.zombie77 or UE.zombie77:prepareIslandG(target)
   if destination and not ctx.island:request(target,env)then return false end
   if not assetsReady then return false end
   if UE.restoreReady109 and not UE.restoreReady109(p)then return false end
   W:start(env);p=ground(env,p,target~='base');p.Z=p.Z+env.player.CapsuleComponent:GetScaledCapsuleHalfHeight()+3
   ctx.routes:travelTo(env,p,'waystone-'..target,function(alive)
    if epoch~=ctx.epoch()then return end
    local groundpoint=ground(alive,p,target~='base');local q={X=p.X,Y=p.Y,Z=groundpoint.Z+alive.player.CapsuleComponent:GetScaledCapsuleHalfHeight()+3}
    alive.player.CharacterMovement:StopMovementImmediately();assert(_G.MC_OUT_K('K2_SetActorLocation',alive.player,q,false,{},true));alive.player.CharacterMovement:SetMovementMode(1,0)
    alive.controller:ResetIgnoreMoveInput();alive.controller:ResetIgnoreLookInput();alive.controller:SetControlRotation({Pitch=-8,Yaw=target~='base'and 90 or 0,Roll=0})
    self.last={target=target,before=self.departed,after=vec(alive.player:K2_GetActorLocation()),seconds=os.clock()-self.at,ground=groundpoint,epoch=epoch};write('travel-'..target,self.last)
    local settled=os.clock()
    T.loop(100,function()
     if epoch~=ctx.epoch()then return true end
     if os.clock()-settled<2 or(UE.zombie77 and not UE.zombie77:arrivalReadyG(target))then return false end
     self.busy=false;self.last.coveredSettleSeconds=os.clock()-settled;self.last.arrivedAt=os.clock();write('travel-'..target,self.last)
     ctx.log('MC83_TRAVEL_ARRIVED target='..target..' costumes_settled=true');return true
    end,'waystone-arrivalG')
   end)
   return true
  end,'waystone-travel-start')
 end
 function W:click()
  if not self.open then return false end;local e=ctx.environment();if not e then return true end
  local lib=UE.Object('/Script/UMG.Default__WidgetLayoutLibrary');local p=lib:GetMousePositionOnViewport(e.player);local s=lib:GetViewportSize(e.player);local d=lib:GetViewportScale(e.player)
  local x,y=(p.X-s.X/(2*d))/self.unit,(p.Y-s.Y/(2*d))/self.unit
  if x>=2 and x<170 then for i,k in ipairs(self.order)do local top=-77+(i-1)*self.rowGap;if y>=top and y<top+28 then self:go(k,e);break end end end;return true
 end
 T.key(Key.F,function()
  W.interact=true
  if UE.loot88 then UE.loot88.input=true end
  if UE.sliceX8 then UE.sliceX8.input=true elseif UE.alex then UE.alex.interact=true end
 end)
 T.frame('waystone-input',function()
  if not W.interact then return end;W.interact=nil
  if not ctx.ready()then return end;local e=ctx.environment()
  if e and ctx.gameplayInput(e)then W:show(e)end
 end)
 T.loop(500,function()
  if not ctx.ready()then return false end;local e=ctx.environment();if not e then return false end
  W:start(e)
  W.nativeV:start(e)
  if W.open and(ctx.items.open or ctx.menu.open)then if ctx.items.open then ctx.items:close()end;if ctx.menu.open then ctx.menu:close()end;U:ownInput(e,W.widget,{})end
  if W.open and not W:near(e)then W:close(e)end
  return false
 end,'waystone-admission')
 T.onEpoch('waystones83',function()support:reset();W.open=false;W.busy=false;W.actors={};W.cls109=nil;W.points=nil;W.widget=nil;W.ns=nil;W.epoch=nil;W.interact=nil end)
 W.ground=ground;W.write=write
 W.nativeV=dofile(ctx.base..'/native_travelW.lua')(ctx,W)
 T.onEpoch('native-travelV',function()W.nativeV:reset()end)
 return W
end
