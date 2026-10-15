-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,A)
 local UE,U,valid=ctx.UE,ctx.uiKit,ctx.valid
 local D=dofile(ctx.base..'/slice_x8_data.lua')
 local Core=dofile(ctx.base..'/slice_trade_core_x8.lua')
 local Native=dofile(ctx.base..'/slice_native_x8.lua')
 local J=dofile(ctx.base..'/json.lua')
 local Journal=dofile(ctx.base..'/slice_journal_x8.lua')
 local View=dofile(ctx.base..'/ui67_view.lua');local R=dofile(ctx.base..'/ui67_rules.lua')
 A.vendorX8='Alex';A.quantity=1;A.query='';A.category='All'
 local function engine()
  local path=UE.worldScope65:path('plains-trades-x8')
  if A.pathX8~=path then
   A.pathX8=path;A.journalX8=Journal(J,path)
   local ok,state=pcall(A.journalX8.load)
   local made,core=pcall(Core.new,ok and state or nil)
   A.coreX8=made and core or Core.new();if not ok or not made then A.coreX8.locked=true end
  end
  return A.coreX8
 end
 local function words(values,mult)
  local out={};for id,n in pairs(values)do out[#out+1]=tostring(n*(mult or 1))..' '..(id=='Money'and'Gold'or ctx.items:label(id))end
  table.sort(out);return table.concat(out,' + ')
 end
 function A:offers(env)
  local d=self.snapshot(env);local list={}
  for _,r in ipairs(assert(D.trades[self.vendorX8]))do
   local category=r.tier=='gear'and'Equipment'or'Items'
   if self.tab==r.tab and(self.category=='All'or category==self.category)and(R.contains(ctx.items:label(r.id),self.query)or R.contains(r.key,self.query))then list[#list+1]=r end
  end
  self.list=list;self.selected=math.max(1,math.min(self.selected,#list))
  return d
 end
 function A:showVendorX8(env,vendor)
  if self.open or self.inFlight then return end
  assert(D.trades[vendor]);self.vendorX8=vendor;self.tab='Buy';self.query='';self.category='All';self.selected=1;self.quantity=1;self.pages67={Buy=0,Sell=0};self.messageText=nil;self.signature67=nil
  if valid(self.ns and self.ns.field67)then U:putText(self.ns.field67,'')end
  self:show(env)
 end
 function A:transact(stack)
  if self.inFlight or os.clock()<(self.clickUntilX8 or 0)then return false end
  local e=ctx.environment();if not e or not self.open or self.epoch~=ctx.epoch()or not ctx.inRange(e)then return false end
  self:offers(e);local offer=self.list[self.selected];if not offer then return false end
  local n=math.min(offer.maxBatches or 64,stack and 64 or self.quantity or 1)
  self.clickUntilX8=os.clock()+.4;self.inFlight=true
  local core=engine();self.nonceX8=(self.nonceX8 or 0)+1
  local called,ok,reason=pcall(core.transact,core,offer,n,Native(ctx,self,e,self.journalX8.save),self.nonceX8,os.time())
  self.inFlight=false
  if not called then ctx.log('MCX8_TRADE_ERROR '..tostring(ok));core.locked=true;reason='Trade recovery required';ok=false end
  ctx.items.dirty=true;ctx.phaseA.inventoryDirty=true;self:message(reason)
  ctx.log('MCX8_TRADE vendor='..self.vendorX8..' offer='..offer.key..' pass='..tostring(ok)..' reason='..tostring(reason))
  return ok
 end
 
 function A:step(env)end
 function A:paint(env)
  local ns=self.ns;local field=ns.field67
  if valid(field)then local t=UE.GetKismetTextLibrary():Conv_TextToString(field:GetText());local query=type(t)=='string'and t or t:ToString();if query~=self.query then self.query=query;self.pages67[self.tab]=0 end end
  local d=self:offers(env);local offer=self.list[self.selected]
  self.quantity=math.max(1,math.min(self.quantity or 1,offer and(offer.maxBatches or 64)or 1))
  local core=engine();local q,reason
  if offer then q,reason=core:quote(offer,self.quantity,d,os.time());if q and not Native(ctx,self,env,self.journalX8.save).fits(q,d)then reason='Inventory full'end else reason='No offers'end
  if reason and reason:match('^Not enough ')then local id=reason:sub(12);if id~='gold'then reason='Not enough '..ctx.items:label(id)end end
  self.reason67=reason
  local V=View(ctx,U,ns,self.unit)
  V:sprite('Panel',-300,-137,600,274,'T_MC_UI_panel')
  V:text('Title',-290,-129,255,self.vendorX8..' - '..D.roles[self.vendorX8])
  V:text('Balance',-30,-129,320,(d.counts.Eemerald or 0)..' Emeralds / '..d.gold..' Gold',true,nil,1,2)
  V:button('Buy',-290,-111,83,'Buy','Buy',false,self.tab=='Buy');V:button('Sell',-201,-111,83,'Sell','Sell',false,self.tab=='Sell')
  V:field('Search',-111,-111,228,self.query,'Search offers...');V:button('Category',123,-111,167,self.category,'category')
  V:well('OfferList',-290,-85,250,194);local page=R.page(self.pages67[self.tab],#self.list,7);self.pages67[self.tab]=page
  for i=1,7 do local r=self.list[page*7+i];if r then local y=-81+(i-1)*27
   V:button('Offer'..i,-286,y,242,'','offer:'..(page*7+i),false,page*7+i==self.selected,26)
   V:icon('OfferIcon'..i,-282,y+4,18,ctx.items:icon(r.id));V:text('OfferName'..i,-258,y+3,210,ctx.items:label(r.id))
   V:text('OfferPrice'..i,-258,y+15,210,self.tab=='Sell'and('Receive '..words(r.give))or words(r.cost),false,{R=.2,G=.5,B=.15,A=1})
  end end
  V:button('Prev',-289,115,25,'<','prev');V:button('Next',-259,115,25,'>','next');V:text('Page',-228,120,155,(page+1)..' / '..math.max(1,math.ceil(#self.list/7)))
  V:text('Name',-26,-80,310,offer and ctx.items:label(offer.id)or'No offers',true,nil,2)
  V:text('Cost',-26,-48,310,offer and('Give: '..words(offer.cost,self.quantity))or'',true,nil,2)
  V:text('Receive',-26,-18,310,offer and('Receive: '..words(offer.give,self.quantity))or'',true,nil,2)
  V:text('Limit',-26,10,310,offer and(offer.limit and('Limit: '..offer.limit.max..' exchanges / 24h')or'Stock: unlimited')or'')
  V:text('Quantity',-26,32,90,'Batches');V:button('Minus',65,27,22,'-','minus');V:text('QuantityValue',94,32,38,self.quantity);V:button('Plus',132,27,22,'+','plus');V:button('Max',163,27,44,'Max','max')
  V:well('Reason',-26,53,310,35);V:text('Reason',-21,59,300,reason or self.messageText or'',false,nil,2)
  V:button('Trade',-26,93,210,self.tab=='Sell'and'Sell for Emeralds'or'Confirm trade','trade',reason~=nil)
  V:button('Back',244,116,46,'Back','back');V:finish();self.dirty=false;self.nextRefresh=os.clock()+.35
 end
 function A:click(stack)
  if not self.open then return false end;local e=ctx.environment();if not e then return true end
  local x,y=self:mouse(e);local hit
  for _,r in ipairs(self.ns.buttons67 or{})do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then hit=r;break end end
  if hit and hit.field then U:focusField(e,hit.field);return true end;if U:editing()then U:clearField()end
  if not hit or hit.disabled or not hit.action or self.inFlight then return true end
  local a=hit.action;self.messageText=nil
  if a=='Buy'or a=='Sell'then self.tab=a;self.selected=1;self.quantity=1
  elseif a=='category'then self.category=({All='Equipment',Equipment='Items',Items='All'})[self.category];self.selected=1
  elseif a=='prev'or a=='next'then self.pages67[self.tab]=R.page(self.pages67[self.tab]+(a=='prev'and-1 or 1),#self.list,7)
  elseif a:match('^offer:')then self.selected=tonumber(a:match('%d+'));self.quantity=1
  elseif a=='minus'then self.quantity=math.max(1,self.quantity-1)
  elseif a=='plus'then self.quantity=self.quantity+1
  elseif a=='max'then
   local r=self.list[self.selected];if r then local d=self.snapshot(e);local adapter=Native(ctx,self,e,self.journalX8.save);self.quantity=1
    for n=r.maxBatches or 64,1,-1 do local q=engine():quote(r,n,d,os.time());if q and adapter.fits(q,d)then self.quantity=n;break end end
   end
  elseif a=='trade'then self:transact(stack)
  elseif a=='back'then self:close(e);return true end
  self.dirty=true;self:paint(e);return true
 end
end
