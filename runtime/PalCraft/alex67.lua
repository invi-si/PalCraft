-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,A)
 local U,UE,valid=ctx.uiKit,ctx.UE,ctx.valid;local View=dofile(ctx.base..'/ui67_view.lua');local R=dofile(ctx.base..'/ui67_rules.lua')
 local create,offers=A.create,A.offers;A.query='';A.category='All';A.quantity=1;A.pages67={Buy=0,Sell=0};A.tabMemory67={}
 local function text(v)local s=UE.GetKismetTextLibrary():Conv_TextToString(v);return type(s)=='string'and s or s:ToString()end
 function A:offers(env)
  local d=offers(self,env);local out={};for _,r in ipairs(self.list)do
   local item=ctx.items.registry.items[r.id];local equipment=item and item.category=='equipment'
   if (self.category=='All'or self.category=='Equipment'and equipment or self.category=='Items'and not equipment)and(R.contains(ctx.items:label(r.id),self.query)or R.contains(r.id,self.query))then out[#out+1]=r end
  end
  self.list=out;local chosen=self.selectedId67;self.selected=math.min(math.max(1,self.selected),#out)
  for i,r in ipairs(out)do if r.id==chosen then self.selected=i;break end end
  if out[self.selected]then self.selectedId67=out[self.selected].id end;return d
 end
 function A:create(env)
  create(self,env);local _,unit,dpi,size=U:metrics(env);self.unit=math.max(1,math.min(unit*dpi,math.floor(size.X/616),math.floor(size.Y/328)))/dpi
  local canvas=self.ns.CanvasPanel_0;local dim=self.ns.Dim
  for key,n in pairs(self.ns)do if valid(n)and n:GetAddress()~=canvas:GetAddress()and(not valid(dim)or n:GetAddress()~=dim:GetAddress())then n:SetRenderOpacity(0)end end
  canvas:SetRenderOpacity(1);if valid(dim)then dim:SetRenderOpacity(1)end
  self.signature67=nil
 end
 function A:paint(env)
  local ns=self.ns;local field=ns.field67;if valid(field)then local query=text(field:GetText());if query~=self.query then self.query=query;self.pages67[self.tab]=0 end end
  local d=self:offers(env);local offer=self.list[self.selected];local max=offer and ctx.items:data(offer.id).MaxStackCount or 1
  self.quantity=math.max(1,math.min(self.quantity,max));local count=offer and offer.count or 0;local total=offer and offer.price*self.quantity or 0
  local capacity=offer and self.capacity(env,offer.id)or 0
  local reason=not offer and'No items'or self.inFlight and'Trade in progress'or self.tab=='Buy'and d.gold<total and'Not enough gold'or self.tab=='Buy'and capacity<self.quantity and'Inventory full'or self.tab=='Sell'and count<self.quantity and'No items'or nil
  self.reason67=reason
  local signature=table.concat({self.tab,self.selected,self.quantity,self.query,self.category,d.gold,count,capacity,self.pages67[self.tab],self.messageText or'',tostring(self.inFlight)},':')
  if signature==self.signature67 then self.dirty=false;self.nextRefresh=os.clock()+.35;return end;self.signature67=signature
  local V=View(ctx,U,ns,self.unit);V:sprite('Panel',-300,-137,600,274,'T_MC_UI_panel');V:text('Title',-290,-129,260,'Alex - Trade');V:text('Balance',55,-129,235,'Balance: '..d.gold..' Gold',true,nil,1,2)
  V:button('Buy',-290,-111,83,'Buy','Buy',false,self.tab=='Buy');V:button('Sell',-201,-111,83,'Sell','Sell',false,self.tab=='Sell')
  V:field('Search',-111,-111,228,self.query,'Search offers...');V:button('Category',123,-111,167,'Category: '..self.category,'category')
  V:well('OfferList',-290,-85,232,194);local page=R.page(self.pages67[self.tab],#self.list,7);self.pages67[self.tab]=page
  for i=1,7 do local r=self.list[page*7+i];if r then local y=-81+(i-1)*27;V:button('Offer'..i,-286,y,224,'','offer:'..(page*7+i),false,page*7+i==self.selected,26)
   V:icon('OfferIcon'..i,-282,y+4,18,ctx.items:icon(r.id));V:text('OfferName'..i,-258,y+3,190,ctx.items:label(r.id),false);V:text('OfferPrice'..i,-258,y+15,190,r.price..' Gold',false,{R=1,G=.667,B=0,A=1})end end
  V:button('Prev',-289,115,25,'<','prev');V:button('Next',-259,115,25,'>','next');V:text('Page',-228,120,155,(page+1)..' / '..math.max(1,math.ceil(#self.list/7)))
  V:well('Alex',-47,-85,80,112)
  local portrait=U:asset67('alex');if valid(portrait)then V:icon('Alex',-32,-80,50,portrait)end;V:text('AlexName',-42,12,70,'Alex',false,nil,1,1)
  V:text('Name',45,-82,245,offer and ctx.items:label(offer.id)or'No items',true,nil,2)
  V:text('Price',45,-56,211,offer and('Price each: '..offer.price..' Gold')or'');if offer then V:icon('SelectedIcon',261,-57,26,ctx.items:icon(offer.id))end
  V:text('Stock',45,-38,244,'Stock: '..count..' / Max: '..max)
  V:text('Quantity',45,-12,78,'Quantity');V:button('Minus',128,-17,18,'-','minus');V:well('Quantity',150,-17,35,18);V:text('QuantityValue',154,-13,27,self.quantity,false,nil,1,2);V:button('Plus',189,-17,18,'+','plus');V:button('Max',213,-17,35,'Max','max')
  V:text('Total',45,7,243,'Total: '..total..' Gold');V:text('After',45,22,243,'Balance after: '..(reason and'--'or(d.gold+(self.tab=='Buy'and-total or total))))
  local rx=self.tab=='Sell'and 128 or 45;local rw=290-rx;V:well('Reason',rx,39,rw,31);V:text('Reason',rx+5,44,rw-10,reason or self.messageText or'',false,{R=1,G=.333,B=.333,A=1},2)
  V:button('Trade',130,77,160,self.tab,'trade',reason~=nil)
  
  if self.tab=='Sell'then
   V:text('InventoryLabel',-46,39,164,'Inventory');local c=ctx.items.native:container(env,0)
   for i=1,27 do local x,y=-46+(i-1)%9*18,52+math.floor((i-1)/9)*18;V:sprite('InvSlot'..i,x,y,18,18,'T_MC_UI_slot')
    local s=i<=c:Num()and c:Get(i-1);local id=s and ctx.items.native:id(s);if id then V:icon('InvIcon'..i,x+1,y+1,16,ctx.items:icon(id));local amount=s:GetStackCount();if amount>1 then V:text('InvCount'..i,x+1,y+8,16,amount,false,nil,1,2)end end
    V.buttons[#V.buttons+1]={x=x,y=y,w=18,h=18,action='inventory',item=id}
   end
  end
  V:button('Back',244,116,46,'Back','back');V:finish();self.dirty=false;self.nextRefresh=os.clock()+.35
 end
 function A:click(stack)
  if not self.open then return false end;local env=ctx.environment();if not env then return true end;local x,y=self:mouse(env);local hit
  for _,r in ipairs(self.ns.buttons67 or{})do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then hit=r;break end end
  if hit and hit.field then U:focusField(env,hit.field);return true end;if U:editing()then U:clearField()end
  if not hit or hit.disabled or not hit.action then return true end
  local a=hit.action;if self.inFlight then return true end
  if a=='Buy'or a=='Sell'then self.tabMemory67[self.tab]={id=self.selectedId67,quantity=self.quantity};self.tab=a;local keep=self.tabMemory67[a]or{};self.selectedId67=keep.id;self.selected=1;self.quantity=keep.quantity or 1
  elseif a=='category'then self.category=({All='Equipment',Equipment='Items',Items='All'})[self.category];self.pages67[self.tab]=0
  elseif a=='prev'or a=='next'then self.pages67[self.tab]=R.page(self.pages67[self.tab]+(a=='prev'and-1 or 1),#self.list,7)
  elseif a:match('^offer:')then self.selected=tonumber(a:match('%d+'));self.selectedId67=self.list[self.selected].id;self.quantity=1
  elseif a=='inventory'and hit.item then for i,r in ipairs(self.list)do if r.id==hit.item then self.selected=i;self.selectedId67=r.id;self.pages67[self.tab]=math.floor((i-1)/7);self.quantity=1;break end end
  elseif a=='minus'then self.quantity=math.max(1,self.quantity-1)
  elseif a=='plus'then self.quantity=self.quantity+1
  elseif a=='max'then local r=self.list[self.selected];if r then local max=ctx.items:data(r.id).MaxStackCount;self.quantity=self.tab=='Sell'and math.min(max,r.count)or math.min(max,math.floor(self.wallet(env)/r.price),self.capacity(env,r.id))end
  elseif a=='trade'then self:transact(stack)
  elseif a=='back'then self:close(env);return true end
  self.messageText=nil;self.dirty=true;self:paint(env);ctx.log('MC67_TRADE_ACTION '..a);return true
 end
 function A:prime67(env)
  if self.open or self.epoch==ctx.epoch()and valid(self.widget)then return end
  self:create(env);self.epoch=ctx.epoch();self:paint(env)
  self.widget:SetRenderOpacity(0);self.widget:SetVisibility(3)
  ctx.log('MC67_ALEX_PRIMED once_per_epoch=true')
 end
 function A:show(env)
  if self.open then return end
  local _,unit,dpi,size=U:metrics(env);local desired=math.max(1,math.min(unit*dpi,math.floor(size.X/616),math.floor(size.Y/328)))/dpi
  if valid(self.widget)and self.unit~=desired then self.widget:SetRenderOpacity(0);self.widget:RemoveFromParent();self.widget=nil end
  if not valid(self.widget)or self.epoch~=ctx.epoch()then self:create(env)end
  self.epoch=ctx.epoch();self.open=true;self:paint(env);self.widget:SetVisibility(0);self.widget:SetRenderOpacity(1);U:ownInput(env,self.widget,{self.ns.field67});ctx.log('MC62_TRADE_OPEN mode='..self.tab)
 end
 local tick=A.step
 function A:step(env)
  tick(self,env);if not self.open or os.clock()<(self.nextHover67 or 0)then return end;self.nextHover67=os.clock()+.1
  local x,y=self:mouse(env);local tip;for _,r in ipairs(self.ns.buttons67 or{})do if r.item and x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then tip={id=r.item,exclude=r};break end end
  U:tooltip(self.ns,tip,tip and ctx.items:label(tip.id)or'',x,y,self.unit)
 end
end
