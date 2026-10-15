-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U,meta)
 local valid,UE=ctx.valid,ctx.UE
 local accents={'AAAAAA','FF5555','5555FF','55FF55','FFFF55','55FFFF','FFAA00','AA00AA','FF55FF'}
 local function clamp(v)return math.max(0,math.min(1,v or 0))end
 local function stringValue(v)return type(v)=='string'and v or v:ToString()end
 local function short(s,n)local out={};for _,cp in utf8.codes(s)do if #out>=n then break end;out[#out+1]=utf8.char(cp)end;return table.concat(out)end
 function U:applyProductionOp(ns,spec)
  if spec.op=='pool_image'then
   local n=ns['Ui20Image'..spec.index];local o=spec.options;local t=spec.texture

   n.Slot:SetOffsets({Left=spec.x*spec.unit,Top=spec.y*spec.unit,Right=spec.w*spec.unit,Bottom=spec.h*spec.unit});n.Slot:SetZOrder(o.z or 30)
   if o.fill then self:fill(n,o.fill,o.alpha)
   elseif type(t)=='table'and t.item then local tex=self.items:icon(t.item);if not valid(tex)then self:visible(n,1);return end;self:icon(n,tex,o.cells or 16,o.outline or 0)
   elseif type(t)=='string'then self:poolBrush(n,t,o.tile,spec.unit)
   elseif valid(t)then self:icon(n,t,o.cells or 16,o.outline or 0)
   else self:visible(n,1);return end
   self:visible(n,3)
  elseif spec.op=='pool_text'then
   local n=ns['Ui20Text'..spec.index];self:setMeta(n,{dark=spec.dark,count=spec.count})
    n.Slot:SetOffsets({Left=spec.x*spec.unit,Top=spec.y*spec.unit,Right=spec.w*spec.unit,Bottom=spec.h*spec.unit});n.Slot:SetZOrder(40)
    local key=spec.unit..':'..tostring(spec.dark)..':'..(spec.color and table.concat({spec.color.R,spec.color.G,spec.color.B,spec.color.A or 1},':')or'')
    local styles=self.productionTextStyles;local font=styles and styles[key]
    if font then
     n:SetFont(font);local c=spec.color or(spec.dark and{R=.251,G=.251,B=.251,A=1}or{R=1,G=1,B=1,A=1})
     local function linear(x)return x<=.04045 and x/12.92 or((x+.055)/1.055)^2.4 end
     n:SetColorAndOpacity({SpecifiedColor={R=linear(c.R),G=linear(c.G),B=linear(c.B),A=c.A},ColorUseRule=0})
     n:SetShadowOffset(spec.dark and{X=0,Y=0}or{X=spec.unit,Y=spec.unit});n:SetShadowColorAndOpacity({R=linear(c.R*.25),G=linear(c.G*.25),B=linear(c.B*.25),A=spec.dark and 0 or 1})
    else self:textStyle(n,spec.unit,spec.dark,spec.color);if styles then styles[key]=n.Font end end
   self:putText(n,spec.value);n:SetClipping(1);self:visible(n,3)
   n:SetJustification(0)
  elseif spec.op=='pool_hide'then self:visible(ns[spec.name],1)
  end
 end
 function U:view(ns,env,w,h)
  local _,unit=self:metrics(env);local v={ns=ns,unit=unit,w=w,h=h,images=0,texts=0}
  self.poolState=self.poolState or{};local previous=self.poolState[ns];self.poolState[ns]=v

  function v:finish()
   if previous then
    for i=self.images+1,previous.images do if U.productionOps then U.productionOps[#U.productionOps+1]={op='pool_hide',name='Ui20Image'..i}else U:visible(ns['Ui20Image'..i],1)end end
    for i=self.texts+1,previous.texts do if U.productionOps then U.productionOps[#U.productionOps+1]={op='pool_hide',name='Ui20Text'..i}else U:visible(ns['Ui20Text'..i],1)end end
   end
  end
  function v:image(x,y,w,h,texture,options)
   self.images=self.images+1;local n=self.ns['Ui20Image'..self.images];assert(valid(n),'UI image pool exhausted')
   local spec={op='pool_image',index=self.images,x=x-self.w/2,y=y-self.h/2,w=w,h=h,unit=self.unit,texture=texture,options=options or{}}
   if U.productionOps then U.productionOps[#U.productionOps+1]=spec else U:applyProductionOp(self.ns,spec)end
   return n
  end
  function v:text(s,x,y,w,h,color,dark,count)
   self.texts=self.texts+1;local n=self.ns['Ui20Text'..self.texts];assert(valid(n),'UI text pool exhausted')
   local spec={op='pool_text',index=self.texts,value=tostring(s or''),x=x-self.w/2,y=y-self.h/2,w=w,h=h or 10,unit=self.unit,color=color,dark=dark~=false,count=count}
   if U.productionOps then U.productionOps[#U.productionOps+1]=spec else U:applyProductionOp(self.ns,spec)end
   return n
  end
  function v:bar(x,y,w,h,ratio,color)
   self:image(x,y,w,h,nil,{fill='000000'});self:image(x+1,y+1,w-2,h-2,nil,{fill='555555'})
   self:image(x+1,y+1,math.max(0,math.floor((w-2)*clamp(ratio))),h-2,nil,{fill=color or(ratio>.5 and'55FF55'or ratio>.2 and'FFFF55'or'FF5555')})
  end
  function v:pips(x,y,n,filled,color)
   for i=1,n do self:image(x+(i-1)*5,y,4,4,nil,{fill=i<=filled and(color or'55FF55')or'555555'})end
  end
  function v:pill(s,element,x,y,w)
   local c=accents[element]or'AAAAAA';local width=w or 34;self:image(x,y,width,14,nil,{fill='000000'});self:image(x+1,y+1,width-2,12,nil,{fill=c});local n=self:text(U:trimLabel(s,width-6),x+3,y+1,width-6,12,nil,false);n:SetJustification(1);n:SetClipping(1)
  end
  return v
 end
 function U:palDetails(ns,env,d,name,tab,skills,works,passives,types)
  local v=self:view(ns,env,248,180);for _,k in ipairs({'Stats','Condition','Passive','Skills','Work','Elements'})do ns[k]:SetVisibility(1)end
  local slots={};_G.MC_OUT_K('GetSlots',env.controller.BP_OtomoPalHolderComponent,slots)
  for i=1,5 do local slot=slots[i];pcall(function()slot=slot:get()end);local p=valid(slot)and slot.ReplicateIndividualParameter;ns['PalHP'..i]:SetVisibility(1)
   if valid(p)then local y=17+(i-1)*28;v:text('Lv'..p:GetLevel(),34,y+12,42,9,nil,false,true);U:position(ns['PalName'..i],34-124,y+3-90,42,10,v.unit);v:bar(34,y+21,44,3,p:GetHP().Value/(1000*math.max(1,p:GetMaxHP())))end
  end
  local gender=d:GetGenderType();v:text(gender==1 and'♂'or gender==2 and'♀'or'',212,19,10,9,gender==1 and{R=.333,G=.333,B=1,A=1}or{R=1,G=.333,B=1,A=1},false)
  v:text('Lv '..d:GetLevel(),222,19,20,9,nil,false,true):SetJustification(2)
  for i,t in ipairs(types)do v:pill(t.label,t.element,154+(i-1)*40,33,38)end
  local stats={{'T_MCHUD_HeartFull',math.floor(d:GetHP().Value/1000)..'/'..d:GetMaxHP()},{U.items:icon('MC_IronSword'),d:GetShotAttack()},{'T_MCHUD_ArmorFull',d:GetDefense()},{U.items:icon('MC_IronPickaxe'),d:GetCraftSpeed()}}
  for i,s in ipairs(stats)do local y=47+(i-1)*10;v:image(154,y,8,8,s[1]);v:text(s[2],166,y,76,10)end
  for i=1,3 do U:brush(ns['GuiDetailTab'..i],i==tab and'T_MC_UI_widget_button_disabled'or'T_MC_UI_widget_button')end
  if tab==1 then
   local halves=math.ceil(clamp(d:GetFullStomachRate())*20)
   for i=1,10 do local n=halves-(i-1)*2;v:image(88+(i-1)*8,130,8,8,n>=2 and'T_MCHUD_FoodFull'or n==1 and'T_MCHUD_FoodHalf'or'T_MCHUD_FoodEmpty')end
   v:text('Sanity',88,142,40,10);v:pips(129,145,10,math.ceil(clamp(d:GetSanityRate())*10),'FF55FF')
   local health=d:GetPhysicalHealth();if health~=0 then v:text(({'Minor injury','Severe injury','Dying','Dead','Cloud cemetery'})[health]or'Injured',88,157,78,10,{R=1,G=.333,B=.333,A=1})end
  elseif tab==2 then
   for i,s in ipairs(skills)do if i>3 then break end;local y=128+(i-1)*10;v:pill(s.elementLabel,s.element,88,y,24);v:text(s.name,114,y,104,10);v:text(s.power,218,y,24,10):SetJustification(2)end
   local p={};for _,s in ipairs(passives)do p[#p+1]=s end;v:text(table.concat(p,', '),88,160,76,12,{R=1,G=.667,B=0,A=1})
  else
   for i,w in ipairs(works)do if i>3 then break end;local y=125+(i-1)*10;v:image(88,y,8,8,U.items:icon('MC_IronPickaxe'));v:text(w.name,99,y,105,9);v:pips(211,y+1,5,math.min(5,w.rank))end
  end
  v:finish();return v
 end
 function U:production(ns,env,F,materials)
  local v=self:view(ns,env,319,166);F.inventorySlots={};F.materialSlots={};local B=U.items;self.inventory,self.env=B,env
  for _,k in ipairs({'Materials','Selected','Quantity','Queue','ProgressText','Filter'})do ns[k]:SetVisibility(1)end
  U:brush(ns.GuiList,'T_MC_UI20_recipe_book');ns.GuiList:SetColorAndOpacity({R=1,G=1,B=1,A=1});ns.GuiList.Slot:SetZOrder(2)
  U:brush(ns.GuiBackground,'T_MC_UI_panel',{4/176,4/166});ns.GuiBackground.Slot:SetZOrder(1)
  local title=F.stationName or'Workbench';ns.Title:SetText(UE.GetKismetTextLibrary():Conv_StringToText(title));U:position(ns.Title,151-159.5,6-83,160,10,v.unit)
  local search=v:image(25,14,80,12,'T_MC_UI_widget_text_field');F.searchRect={25,14,80,12}
  local field=ns.Ui20Search;U:position(field,27-159.5,16-83,76,10,v.unit);field.Slot:SetZOrder(40);local font=field.WidgetStyle.Font;font.Size=U:fontSize(6,v.unit);if valid(U.font)then font.FontObject=U.font;font.TypefaceFontName=UE.FindOrAddFName(U.nativeTypeface or'Regular')end;field.WidgetStyle.ColorAndOpacity={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0};field:SetFont(font);field:SetClipping(1);field:SetHintText(UE.GetKismetTextLibrary():Conv_StringToText('Search...'));field:SetVisibility(0)
  v:image(110,12,26,16,'T_MC_UI_widget_button');v:text(F.craftable and'✓'or'×',117,15,16,10,nil,false);F.filterRect={110,12,26,16}
  for i=1,20 do local r=F.filtered[F.page*20+i];local x=11+(i-1)%5*25;local y=31+math.floor((i-1)/5)*25
   ns['RecipeFrame'..i]:SetVisibility(1);if r then v:image(x,y,25,25,'T_MC_UI_slot');ns['RecipeIcon'..i].Slot:SetZOrder(35)end
  end
  for i,m in ipairs(materials)do if i>4 then break end;local x=151+(i-1)*18;F.materialSlots[#F.materialSlots+1]={x=x,y=34,w=18,h=18,entry={id=m.id,count=m.need,have=m.have}};v:image(x,34,18,18,'T_MC_UI_slot');v:image(x+1,35,16,16,{item=m.id},{outline=1});v:text(m.need,x-1,44,20,9,m.have<m.need and{R=1,G=.333,B=.333,A=1}or nil,false,true):SetJustification(2)end
  v:image(263,31,26,26,'T_MC_UI_slot');U:position(ns.ProductIcon,265-159.5,33-83,22,22,v.unit);ns.ProductIcon.Slot:SetZOrder(35)
  local qty=v:text(F.quantity,173,68,24,10);qty:SetJustification(1)
  for _,k in ipairs({'Prev','Next'})do ns[k]:SetText(UE.GetKismetTextLibrary():Conv_StringToText(''))end
  v:image(16,145,12,17,'T_MC_UI20_backward');v:image(118,145,12,17,'T_MC_UI20_forward')
  U:setMeta(ns.Page,{dark=false});U:textStyle(ns.Page,v.unit,false)
  ns.CraftFrame.Slot:SetZOrder(30);ns.Craft.Slot:SetZOrder(40)
  
  local craft=UE.GetKismetTextLibrary():Conv_TextToString(ns.Craft:GetText());craft=type(craft)=='string'and craft or craft:ToString()
  local scale=math.min(1,44/math.max(1,U:textWidth53(craft)));local font=ns.Craft.Font;font.Size=U:fontSize(6*scale,v.unit);ns.Craft:SetFont(font)
  U:position(ns.Craft,199-159.5,68-83,50,12,v.unit);ns.Craft:SetJustification(1)

  v:image(151,84,162,54,'T_MC_UI24_inventory_slots');v:image(151,142,162,18,'T_MC_UI24_hotbar_slots')
  for i=1,36 do local spec,x,y
   if i<=27 then spec={kind='main',index=i};x=151+(i-1)%9*18;y=84+math.floor((i-1)/9)*18
   else spec={kind='bar',index=i-27};x=151+(i-28)*18;y=142 end
   local entry=B:entry(env,spec);F.inventorySlots[#F.inventorySlots+1]={x=x,y=y,w=18,h=18,spec=spec,entry=entry}
   if entry.id then v:image(x+1,y+1,16,16,{item=entry.id},{outline=1});if entry.count>1 then v:text(entry.count,x-2,y+9,20,9,nil,false,true):SetJustification(2)end end
  end
  
  ns.Progress:SetRenderOpacity(0);F.arrow=v:image(230,34,24,17,'T_MC_UI_container_furnace_burn_progress',{z=35});F.arrowUnit=v.unit
  v:finish();F.view=v
 end
 function U:dexDetails(ns,env,F,r,drops,count,bonus)
  local v=self:view(ns,env,256,200);local image=v:image(128,5,120,12,'T_MC_UI_widget_text_field');image.Slot:SetZOrder(15);ns.Search.Slot:SetZOrder(40)
  U:position(ns.GuiList,6-128,20-100,112,168,v.unit);for _,k in ipairs({'Prev','Next','Page'})do local slot=ns[k].Slot;local p=slot:GetPosition();slot:SetPosition({X=p.X,Y=(189-100)*v.unit});U:setMeta(ns[k],{dark=true});U:textStyle(ns[k],v.unit,true)end
  for i=1,14 do local row=F.filtered[F.page*14+i];if row then local n=ns['DexLabel'..i];U:textStyle(n,v.unit,false,row.detail<2 and{R=.333,G=.333,B=.333,A=1}or nil);if row.detail<2 then n:SetShadowOffset({X=0,Y=0})end end end
  local f=ns.Description.Font;f.Size=U:fontSize(4,v.unit);ns.Description:SetFont(f);ns.Description:SetClipping(1)
  ns.Drops:SetText(UE.GetKismetTextLibrary():Conv_StringToText('Drops'));U:position(ns.Drops,124-128,153-100,124,10,v.unit)
  for i,id in ipairs(drops)do if i>5 then break end;v:image(124+(i-1)*18,163,18,18,'T_MC_UI_slot');v:image(125+(i-1)*18,164,16,16,U.items:icon(id),{outline=1})end
  ns.Bonus:SetText(UE.GetKismetTextLibrary():Conv_StringToText('Caught: '..(count or 0)));U:position(ns.Bonus,124-128,187-100,65,10,v.unit);v:pips(207,189,5,math.min(5,bonus or 0))
  v:finish();ns.Search.WidgetStyle.ColorAndOpacity={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0};U:inputFont53(ns.Search,v.unit)
 end
 function U:recipeBook(ns,env,B)
  local _,unit=self:metrics(env);B.bookSlots={}
  self:putText(ns.CreativeLabel,B.creative and'Inventory'or'Recipe Book')
  if B:layout().creative then self:textStyle(ns.CreativeLabel,unit,false);ns.CreativeLabel:SetVisibility(3)end
  for _,k in ipairs({'GuiList','GuiTabLabel1','GuiTabLabel2','GuiTabLabel3'})do ns[k]:SetVisibility(B.recipeBook and 3 or 1)end
  if not B.recipeBook then return end
  self:brush(ns.GuiList,'T_MC_UI20_recipe_book');self:position(ns.GuiList,-242,-83,148,166,unit);ns.GuiList.Slot:SetZOrder(20)
  self:position(ns.GuiTabLabel1,-232,-79,128,10,unit);self:textStyle(ns.GuiTabLabel1,unit,false);self:putText(ns.GuiTabLabel1,'Recipe Book')
  self:position(ns.CreativeSearch,-236,-69,126,12,unit);ns.CreativeSearch:SetVisibility(0);ns.CreativeSearch.Slot:SetZOrder(40)
  local rows=B:bookRows();B.bookPage=math.min(B.bookPage or 0,math.max(0,math.ceil(#rows/10)-1))
  for i=1,10 do local r=rows[B.bookPage*10+i];local frame,icon=ns['GuiTab'..i],ns['GuiTabIcon'..i]
   if not valid(frame)or not valid(icon)then
    if not valid(StaticFindObject('/Script/Engine.GameplayStatics:SpawnObject'))then ctx.log('MC21_BOOK_UNAVAILABLE native_image_factory');return end
    local parent=ns.GuiList:GetParent();local factory=UE.Object('/Script/Engine.Default__GameplayStatics');local class=UE.Object('/Script/UMG.Image')
    if not valid(frame)then frame=factory:SpawnObject(class,ns.GuiList:GetOuter());parent:AddChildToCanvas(frame);ns['GuiTab'..i]=frame end
    if not valid(icon)then icon=factory:SpawnObject(class,ns.GuiList:GetOuter());parent:AddChildToCanvas(icon);ns['GuiTabIcon'..i]=icon end
   end
   frame:SetVisibility(r and 3 or 1);icon:SetVisibility(r and 3 or 1)
   if r then local x=-236+(i-1)%5*26;local y=-54+math.floor((i-1)/5)*24
    self:brush(frame,'T_MC_UI_slot');self:position(frame,x,y,24,24,unit);frame.Slot:SetZOrder(25)
    self:icon(icon,B:icon(r.result));self:position(icon,x+4,y+4,16,16,unit);icon.Slot:SetZOrder(30);B.bookSlots[#B.bookSlots+1]={x=x,y=y,recipe=r}
   end
  end
  self:position(ns.GuiTabLabel2,-232,68,128,10,unit);self:textStyle(ns.GuiTabLabel2,unit,false);ns.GuiTabLabel2:SetJustification(1);self:putText(ns.GuiTabLabel2,'<     '..(B.bookPage+1)..'/'..math.max(1,math.ceil(#rows/10))..'     >')
  ns.GuiTabLabel3:SetVisibility(1)
 end
 function U:pcDetails(ns,env,p)
  local v=self:view(ns,env,292,200);v:image(40,8,162,14,'T_MC_UI_widget_text_field');ns.BoxTitle.Slot:SetZOrder(40)
  if not p then v:finish();return end;v:text('Atk '..p.d:GetShotAttack()..'  Def '..p.d:GetDefense(),204,157,82,20)
  local g=p.d:GetGenderType();v:text(g==1 and'♂'or g==2 and'♀'or'',274,80,10,10,g==1 and{R=.333,G=.333,B=1,A=1}or{R=1,G=.333,B=1,A=1},false)
  v:finish()
 end
end
