-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local A={open=false,tab='Buy',selected=1,serial=0,receipts={}}
 local UE,valid,U,N=ctx.UE,ctx.valid,ctx.uiKit,ctx.items.native
 local T=dofile(ctx.base..'/timers.lua');local prices=assert(loadfile(ctx.base..'/alex_prices.lua'))(ctx.base).items
 for id in pairs(dofile(ctx.base..'/items70.lua'))do prices[id]=prices[id]or{buyPrice=16,sellPrice=4,stock=100}end
 for id in pairs(dofile(ctx.base..'/items88.lua'))do prices[id]={buyPrice=8,sellPrice=2,stock=100}end
 for id in pairs(dofile(ctx.base..'/items89.lua'))do prices[id]={buyPrice=8,sellPrice=2,stock=100}end
 prices.MC_Elytra={buyPrice=50000,sellPrice=5000,stock=10};prices.MC_FireworkRocket={buyPrice=100,sellPrice=10,stock=100};prices.MC_Paper={buyPrice=12,sellPrice=1,stock=100}
 prices.MC_Saddle={buyPrice=500,sellPrice=50,stock=1}
 local J=dofile(ctx.base..'/json.lua')
 local ko={['Alex - Trade']='알렉스 - 거래',['Shift-click: stack   Esc: close']='Shift 클릭: 묶음   Esc: 닫기',['Trade in progress']='거래 진행 중',['Trade complete']='거래 완료',['Trade failed; restored']='거래 실패; 복구 완료',['Trade recovery required']='거래 복구 필요'}
 local function wallet(env)local inv=N:inventory(env);assert(valid(inv));local m=inv.MyMoneyData;assert(valid(m));return m:GetNowMoney()end
 local function snapshot(env)
  local d={gold=wallet(env),counts={},slots={}}
  for kind=0,5 do local c=N:container(env,kind);assert(valid(c));for i=0,c:Num()-1 do local s=c:Get(i);local id=N:id(s);if id then d.counts[id]=(d.counts[id]or 0)+s:GetStackCount();d.slots[#d.slots+1]={kind=kind,index=i,id=id,count=s:GetStackCount()}end end end
  return d
 end
 local function remove(env,id,num)
  local left=num
  for kind=0,5 do local c=N:container(env,kind);for i=0,c:Num()-1 do local s=c:Get(i);if N:id(s)==id and left>0 then local n=math.min(left,s:GetStackCount());N:network(env):RequestDispose_ToServer(N:guid(),{SlotId=N:slotId(s),Num=n});left=left-n end end end
  return left==0
 end
 local function add(env,id,num)return N:inventory(env):AddItem_ServerInternal(UE.FindOrAddFName(id),num,false,0,true)end
 local function capacity(env,id)
  local d=ctx.items:data(id);if not valid(d)then return 0 end
  local stack=d.MaxStackCount;local amount=0;local c=N:container(env,id=='MC_Saddle'and 2 or 0)
  if id=='MC_Saddle'and N:count(env,id)>0 then return 0 end
  for i=0,c:Num()-1 do local s=c:Get(i);local existing=N:id(s);if not existing then amount=amount+stack elseif existing==id then amount=amount+math.max(0,stack-s:GetStackCount())end end
  return amount
 end
 function A:message(s)self.messageText=s;self.dirty=true;ctx.log('MC62_TRADE_MESSAGE '..s)end
 function A:transact(stack)
  if self.inFlight then self:message('Trade in progress');return false end
  local env=ctx.environment();if not env or not self.open or self.epoch~=ctx.epoch()or not ctx.inRange(env)then return false end
  self:offers(env);local offer=self.list[self.selected];if not offer then return false end
  local id=offer.id;local data=ctx.items:data(id);if not valid(data)then return false end
  local equipment=ctx.items.registry.items[id];equipment=equipment and equipment.category=='equipment'or data.MaxStackCount==1
  local num=stack and math.min(64,data.MaxStackCount)or math.max(1,math.min(self.quantity or 1,data.MaxStackCount));if equipment then num=1 end
  local before=snapshot(env);if self.tab=='Sell'then num=math.min(num,before.counts[id]or 0)end
  if num<1 then self:message('No items');return false end
  local value=offer.price*num;local buy=self.tab=='Buy'
  if buy and(before.gold<value or(before.counts.Money or 0)<value)then self:message('Not enough gold');return false end
  if buy and capacity(env,id)<num then self:message('Inventory full');return false end

  if not buy and capacity(env,'Money')<value then
   local frees=false;for _,s in ipairs(before.slots)do if s.kind==0 and s.id==id and s.count<=num then frees=true;break end end
   if not frees then self:message('Inventory full');return false end
  end
  self.inFlight=true;self.serial=self.serial+1
  local tx={serial=self.serial,epoch=ctx.epoch(),id=id,num=num,value=value,buy=buy,before=before,at=os.clock(),state='remove'};self.tx=tx
  ctx.log('MC62_TRADE_BEGIN serial='..tx.serial..' mode='..self.tab..' id='..id..' num='..num)
  return true
 end
 local function delta(d,id)return d.counts[id]or 0 end
 function A:finish(tx,after,ok,reason)
  tx.after=after;tx.pass=ok;tx.reason=reason;tx.seconds=os.clock()-tx.at;tx.state='finished'
  self.receipts[#self.receipts+1]=tx;if #self.receipts>128 then table.remove(self.receipts,1)end
  local f=assert(io.open(ctx.base..'/task62-trades.json','wb'));f:write(J.encode(self.receipts));f:close()
  self.inFlight=false;self.tx=nil;self.dirty=true;ctx.items.dirty=true;ctx.phaseA.inventoryDirty=true
  self:message(ok and'Trade complete'or'Trade failed; restored');ctx.log('MC62_TRADE_DONE serial='..tx.serial..' pass='..tostring(ok)..' reason='..reason)
 end
 function A:step(env)
  local tx=self.tx;if not tx then return end
  if tx.epoch~=ctx.epoch()then self.tx=nil;self.inFlight=false;return end
  local source=tx.buy and'Money'or tx.id;local output=tx.buy and tx.id or'Money';local taken=tx.buy and tx.value or tx.num;local given=tx.buy and tx.num or tx.value
  if tx.state=='remove'then
   remove(env,source,taken);local d=snapshot(env)
   if delta(d,source)==delta(tx.before,source)-taken then add(env,output,given);d=snapshot(env)end

   if delta(d,source)==delta(tx.before,source)-taken and delta(d,output)==delta(tx.before,output)+given then tx.state='verify'
   else
    for _,id in ipairs({tx.id,'Money'})do local difference=delta(d,id)-delta(tx.before,id);if difference>0 then remove(env,id,difference)elseif difference<0 then add(env,id,-difference)end end
    tx.state='rollback-verify'
   end
   tx.deadline=os.clock()+1
  elseif tx.state=='verify'then
   local d=snapshot(env);local gold=tx.before.gold+(tx.buy and-tx.value or tx.value)
   if delta(d,source)==delta(tx.before,source)-taken and delta(d,output)==delta(tx.before,output)+given and d.gold==gold then self:finish(tx,d,true,'verified')
   elseif os.clock()>=tx.deadline then tx.state='rollback'end
  elseif tx.state=='rollback'then
   local d=snapshot(env)
   for _,id in ipairs({tx.id,'Money'})do local difference=delta(d,id)-delta(tx.before,id);if difference>0 then remove(env,id,difference)elseif difference<0 then add(env,id,-difference)end end
   tx.state='rollback-verify';tx.deadline=os.clock()+1
  elseif tx.state=='rollback-verify'then
   local d=snapshot(env);local restored=delta(d,tx.id)==delta(tx.before,tx.id)and delta(d,'Money')==delta(tx.before,'Money')and d.gold==tx.before.gold
   if restored then self:finish(tx,d,false,'rolled-back')elseif os.clock()>=tx.deadline then self:message('Trade recovery required');ctx.log('MC62_TRADE_RECOVERY_REQUIRED serial='..tx.serial);tx.state='locked'end
  end
 end
 function A:offers(env)
  local d=snapshot(env);local list={}
  for id in pairs(dofile(ctx.base..'/catalog70.lua'))do prices[id]=nil end
  for id,p in pairs(prices)do local count=d.counts[id]or 0;if(self.tab=='Buy'and p.buyPrice)or(self.tab=='Sell'and count>0)then list[#list+1]={id=id,price=self.tab=='Buy'and p.buyPrice or p.sellPrice,count=count}end end
  table.sort(list,function(a,b)return a.id<b.id end);self.list=list;self.selected=math.max(1,math.min(self.selected,#list));return d
 end
 local function node(parent,kind,key,x,y,w,h,z,unit)
  local ns={CanvasPanel_0=parent};local n=U:makeNode(ns,key,kind);n.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=0,Y=0}});n.Slot:SetPosition({X=x*unit,Y=y*unit});n.Slot:SetSize({X=w*unit,Y=h*unit});n.Slot:SetZOrder(z or 20);return n
 end
 local function text(ns,key,x,y,w,h,s,unit)
  local n=U:makeNode(ns,key,'TextBlock');U:position(n,x,y,w,h,unit);U:textStyle(n,unit,true);U:putText(n,UE.language57 and UE.language57.lang=='ko'and(ko[s]or s)or s);n.Slot:SetZOrder(30);n:SetVisibility(3);return n
 end
 local function unit(env)local s,_,dpi,size=U:metrics(env);return math.max(1,math.min(s,math.floor(size.Y/280),math.floor(size.X/350)))/dpi end
 function A:create(env)

  local r=ctx.create(env,'WBP_MCOptions','inventory',true);self.widget=r.widget;self.ns=ctx.widgets(self.widget);local root=self.ns.CanvasPanel_0;assert(valid(root));root:ClearChildren();self.ns={CanvasPanel_0=root}
  local u=unit(env);self.unit=u
  local dim=U:makeNode(self.ns,'Dim','Image');U:brush(dim,'T_MC_UI_dim');dim.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}});dim.Slot:SetPosition({X=0,Y=0});dim.Slot:SetSize({X=0,Y=0});dim.Slot:SetZOrder(0)
  U:panel57(self.ns,336,224,u)
  local scroll=U:makeNode(self.ns,'Offers','ScrollBox');scroll:SetVisibility(0);scroll:SetClipping(1);U:position(scroll,-158,-80,139,165,u);scroll.Slot:SetZOrder(20);self.scroll=scroll
  local size=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.SizeBox'),root:GetOuter());assert(valid(size));scroll:AddChild(size);size:SetWidthOverride(132*u)
  local canvas=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.CanvasPanel'),root:GetOuter());assert(valid(canvas));size:AddChild(canvas);canvas:SetVisibility(4);self.canvas=canvas;self.size=size;self.rows={}
 end
 function A:paint(env)
  local ns,u=self.ns,self.unit;local d=self:offers(env)
  text(ns,'Title',-157,-102,110,12,'Alex - Trade',u);text(ns,'Gold',72,-102,83,12,tostring(d.gold),u)
  local coin=U:makeNode(ns,'GoldIcon','Image');U:icon(coin,ctx.items:icon('Money'),16,1);U:position(coin,54,-104,16,16,u);coin.Slot:SetZOrder(30)
  for i,tab in ipairs({'Buy','Sell'})do local x=-157+(i-1)*69;local b=U:makeNode(ns,'Tab'..i,'Image');U:brush(b,self.tab==tab and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button');U:position(b,x,-131,66,20,u);b.Slot:SetZOrder(30);text(ns,'TabLabel'..i,x+4,-126,58,12,tab,u)end
  self.size:SetHeightOverride(math.max(165,#self.list*22)*u)
  for i=1,math.max(#self.list,#self.rows)do local offer=self.list[i];local row=self.rows[i]
   if offer and not row then
    row={frame=node(self.canvas,'Image','OfferFrame'..i,0,(i-1)*22,127,21,20,u),icon=node(self.canvas,'Image','OfferIcon'..i,3,(i-1)*22+3,16,16,23,u),coin=node(self.canvas,'Image','OfferCoin'..i,76,(i-1)*22+3,14,14,23,u),price=node(self.canvas,'TextBlock','OfferPrice'..i,91,(i-1)*22+6,34,12,24,u),name=node(self.canvas,'TextBlock','OfferName'..i,22,(i-1)*22+6,53,12,24,u)};self.rows[i]=row;U:textStyle(row.name,u,true);U:textStyle(row.price,u,true);row.name:SetClipping(1)
   end
   if row then for _,n in pairs(row)do n:SetVisibility(offer and 3 or 1)end;if offer then U:brush(row.frame,i==self.selected and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button');U:icon(row.icon,ctx.items:icon(offer.id),16,1);U:icon(row.coin,ctx.items:icon('Money'),16,1);U:putText(row.name,ctx.items:label(offer.id));U:putText(row.price,tostring(offer.price))end end
  end
  local offer=self.list[self.selected];text(ns,'SelectedTitle',-8,-77,162,22,offer and ctx.items:label(offer.id)or'No items',u)
  local icon=U:makeNode(ns,'SelectedIcon','Image');U:position(icon,58,-50,24,24,u);icon.Slot:SetZOrder(25);icon:SetVisibility(offer and 3 or 1);if offer then U:icon(icon,ctx.items:icon(offer.id),16,1)end
  text(ns,'SelectedPrice',-8,-20,162,12,offer and(tostring(offer.price)..' Gold')or'',u)
  local b=U:makeNode(ns,'TradeButton','Image');U:brush(b,self.inFlight and'T_MC_UI_widget_button_disabled'or'T_MC_UI_widget_button');U:position(b,24,-1,100,20,u);b.Slot:SetZOrder(25);text(ns,'TradeButtonLabel',28,4,92,12,self.tab,u)
  text(ns,'Inventory',-8,24,162,12,'Inventory',u)
  local c=N:container(env,0)
  for i=1,27 do local x,y=-8+((i-1)%9)*18,38+math.floor((i-1)/9)*18;local frame=U:makeNode(ns,'InvFrame'..i,'Image');U:brush(frame,'T_MC_UI_slot');U:position(frame,x,y,18,18,u);frame.Slot:SetZOrder(22)
   local s=i<=c:Num()and c:Get(i-1);local id=s and N:id(s);local n=U:makeNode(ns,'InvIcon'..i,'Image');U:position(n,x+1,y+1,16,16,u);n.Slot:SetZOrder(23);n:SetVisibility(id and 3 or 1);if id then U:icon(n,ctx.items:icon(id),16,1)end
   local count=text(ns,'InvCount'..i,x+1,y+8,16,10,id and s:GetStackCount()>1 and tostring(s:GetStackCount())or'',u);count:SetJustification(2)
  end
  text(ns,'Message',-157,95,314,12,self.messageText or'Shift-click: stack   Esc: close',u);self.dirty=false;self.nextRefresh=os.clock()+.5
 end
 function A:show(env)
  if self.open then return end
  if valid(self.widget)and self.unit~=unit(env)then self.widget:SetRenderOpacity(0);self.widget:RemoveFromParent();self.widget=nil end
  if not valid(self.widget)or self.epoch~=ctx.epoch()then self:create(env)end
  self.epoch=ctx.epoch();self.tab='Buy';self.selected=1;self.messageText=nil;self.scroll:SetScrollOffset(0);self.open=true;self:paint(env);self.widget:SetVisibility(0);self.widget:SetRenderOpacity(1);U:ownInput(env,self.widget,{});ctx.log('MC62_TRADE_OPEN mode=Buy')
 end
 function A:close(env)
  if not self.open then return end;if self.inFlight then self:message('Trade in progress');return end
  self.open=false;U:releaseInput(self.widget);if valid(self.widget)then self.widget:SetRenderOpacity(0);self.widget:SetVisibility(3)end
  local c=env.controller;c:ResetIgnoreMoveInput();c:ResetIgnoreLookInput();c.bShowMouseCursor=false;UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(c,true);ctx.items.escapeUntil=os.clock()+.5;ctx.menu.escapeDirty=nil;ctx.log('MC62_TRADE_CLOSED')
  local expected=ctx.epoch()
  T.after(350,function()
   if expected~=ctx.epoch()or A.open or ctx.items.open or ctx.menu.open then return end
   local current=ctx.environment();if not current then return end
   if ctx.menu.nativeBypass or(UE.nativeInputG4 and UE.nativeInputG4:blocksMenu())then return end
   if UE.nativeInputG4 then UE.nativeInputG4:releaseMain(current)end
   local pc=current.controller;pc:ResetIgnoreMoveInput();pc:ResetIgnoreLookInput();pc.bShowMouseCursor=false;UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(pc,true);ctx.log('MC62_TRADE_INPUT_READY')
  end,'alex-close-input')
 end
 function A:mouse(env)
  local l=UE.Object('/Script/UMG.Default__WidgetLayoutLibrary');local p=l:GetMousePositionOnViewport(env.player);local size=l:GetViewportSize(env.player);local dpi=l:GetViewportScale(env.player);return(p.X-size.X/(2*dpi))/self.unit,(p.Y-size.Y/(2*dpi))/self.unit
 end
 function A:click(stack)
  if not self.open then return false end;local env=ctx.environment();if not env then return true end;local x,y=self:mouse(env)
  if y>=-131 and y<-111 and x>=-157 and x<-19 then if self.inFlight then return true end;self.tab=x<-88 and'Buy'or'Sell';self.selected=1;self.scroll:SetScrollOffset(0);self.messageText=nil;self.dirty=true
  elseif x>=-158 and x<-19 and y>=-80 and y<85 then self.selected=math.floor((y+80+self.scroll:GetScrollOffset()/self.unit)/22)+1;self.dirty=true;if stack then self:transact(true)end
  elseif x>=24 and x<124 and y>=-1 and y<19 then self:transact(stack)end;return true
 end
 T.loop(34,function()
  if not A.open and not A.tx then return false end;local env=ctx.environment();if not env then return false end

  if A.open and(ctx.items.open or ctx.menu.open)then
   if ctx.items.open then ctx.items:close()end;if ctx.menu.open then ctx.menu:close()end
   if valid(A.widget)then A.widget:SetRenderOpacity(1);U:ownInput(env,A.widget,{})end
  end
  A:step(env);if A.open and(A.dirty or os.clock()>=(A.nextRefresh or 0))then A:paint(env)end
  if A.open and not A.inFlight and not ctx.inRange(env)then A:close(env)end;return false
 end,'alex-trade')
 T.onEpoch('alex-trade',function()A.open=false;A.widget=nil;A.ns=nil;A.scroll=nil;A.rows=nil;A.epoch=nil;A.tx=nil;A.inFlight=false end)
 A.snapshot=snapshot;A.wallet=wallet;A.prices=prices;A.capacity=capacity
 dofile(ctx.base..'/alex67.lua')(ctx,A)
 dofile(ctx.base..'/slice_trade_x8.lua')(ctx,A)
 return A
end
