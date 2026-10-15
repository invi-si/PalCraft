-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local T=dofile(ctx.base..'/timers.lua');local D=dofile(ctx.base..'/slice_x8_data.lua')
 local J=dofile(ctx.base..'/json.lua');local Core=dofile(ctx.base..'/slice_trade_core_x8.lua')
 local Journal=dofile(ctx.base..'/slice_journal_x8.lua');local Native=dofile(ctx.base..'/slice_native_x8.lua')
 local A={open=false,selected=1,nonce=0};local N=ctx.items.native
 function A:notice(text)
  local e=ctx.environment();if not e then return end
  if ctx.UE.language57 then ctx.UE.language57:refresh();text=ctx.UE.language57:t(text)end
  local ok=pcall(function()e.controller:ClientMessage(text,ctx.UE.FindOrAddFName('None'),8)end)
  ctx.log('NATIVE_NOTICE '..text..' delivered='..tostring(ok))
 end
 function A.snapshot(e)
  local inv=N:inventory(e);local d={gold=inv.MyMoneyData:GetNowMoney(),counts={},slots={}}
  for kind=0,5 do local c=N:container(e,kind)
   for i=0,c:Num()-1 do local slot=c:Get(i);local id=N:id(slot)
    if id then d.counts[id]=(d.counts[id]or 0)+slot:GetStackCount();d.slots[#d.slots+1]={kind=kind,index=i,id=id,count=slot:GetStackCount()}end
   end
  end
  return d
 end
 local function nearby(e)
  if not e then return false end
  if ctx.UE.sliceX8 and ctx.UE.sliceX8:inRange(e)then return true end
  return ctx.UE.alex and ctx.UE.alex.p and ctx.UE.alex:distance(e)<=300
 end
 function A:paint()
  local row=self.offers[self.selected];local cost,give={},{}
  for id,n in pairs(row.cost)do cost[#cost+1]=n..' '..ctx.items:label(id)end
  for id,n in pairs(row.give)do give[#give+1]=n..' '..ctx.items:label(id)end
  table.sort(cost);table.sort(give)
  self:notice(self.vendor..' '..self.selected..'/'..#self.offers..': '..table.concat(cost,' + ')..' -> '..table.concat(give,' + ')..' | Up/Down offer, Enter confirm, Esc close')
 end
 function A:showVendorX8(e,vendor)
  if self.open then return end
  local path=ctx.UE.worldScope65:path('plains-trades-x8');self.journal=Journal(J,path)
  local ok,state=pcall(self.journal.load);local made,engine=pcall(Core.new,ok and state or nil)
  self.engine=made and engine or Core.new();if not ok or not made then self.engine.locked=true end
  self.vendor=vendor;self.offers=assert(D.trades[vendor]);self.selected=1;self.open=true;self.epoch=ctx.epoch();self:paint()
  self.vendorX8=vendor
 end
 function A:close()self.open=false end
 local function key(code,action)
  T.key(code,function()T.deferInput(function()
   if not A.open then return end
   local e=ctx.environment();if not nearby(e)or A.epoch~=ctx.epoch()then A:close();return end
   action(e)
  end)end)
 end
 key(Key.UP_ARROW,function()A.selected=(A.selected-2)%#A.offers+1;A:paint()end)
 key(Key.DOWN_ARROW,function()A.selected=A.selected%#A.offers+1;A:paint()end)
 key(Key.ESCAPE,function()A:close()end)
 key(Key.RETURN,function(e)
  if os.clock()<(A.due or 0)then return end;A.due=os.clock()+.5;A.nonce=A.nonce+1
  local ok,why=A.engine:transact(A.offers[A.selected],1,Native(ctx,A,e,A.journal.save),A.nonce,os.time())
  A:notice(ok and'Trade complete'or tostring(why))
 end)
 T.onEpoch('native-trade',function()A.open=false;A.engine=nil;A.journal=nil;N.containers={}end)
 return A
end
