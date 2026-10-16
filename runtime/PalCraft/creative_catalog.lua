-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U)
 local UE,valid=ctx.UE,ctx.valid
 local L=dofile(ctx.base..'/creative_layout.lua')
 local T=dofile(ctx.base..'/timers.lua')
 local function inside(x,y,b)return x>=b[1]and x<b[1]+b[3]and y>=b[2]and y<b[2]+b[4]end
 local function image(ns,key,sprite,x,y,w,h,z,unit)
  local n=U:makeNode(ns,key,'Image');U:brush(n,sprite);U:position(n,x,y,w,h,unit)
  n.Slot:SetZOrder(z);n:SetVisibility(3);return n
 end
 local function label(ns,key,value,x,y,w,h,dark,z,unit)
  local n=U:makeNode(ns,key,'TextBlock');U:putText(n,value);U:textStyle(n,unit,dark)
  U:position(n,x,y,w,h,unit);n:SetClipping(1);n.Slot:SetZOrder(z);n:SetVisibility(3);return n
 end
 function U:stackCount(n,x,y,unit)
  if not valid(n)then return end
  if x then self:position(n,x,y,16,8,unit)else n.Slot:SetSize({X=16*unit,Y=8*unit})end;self:textStyle(n,unit,false)
  
  local raw=UE.GetKismetTextLibrary():Conv_TextToString(n:GetText());local value=type(raw)=='string'and raw or raw:ToString()
  local width=self:textWidth53(value)*.75
  local points=4.5*math.min(1,15/math.max(1,width));local f=n.Font;local size=self:fontSize(points,unit)
  if f.Size~=size then f.Size=size;n:SetFont(f)end
  n:SetJustification(2);n:SetClipping(1);n.Slot:SetZOrder(12)
 end
 function U:creativeTabs(ns,B,unit)
  B.tabBoxes={}
  for i,t in ipairs(L.tabs)do
   local selected=(B.category or'search')==t.category;local x,y=t.x-97.5,t.y-68
   image(ns,'GuiTab'..i,L.tabSprite(t,selected),x,y,26,32,selected and 7 or 0,unit)
   local icon=self:makeNode(ns,'GuiTabIcon'..i,'Image');local tex
   if t.category=='search'then tex=self:asset('T_MC_UI_creative_search_icon')
   elseif t.category=='materials'then tex=self:asset('T_MC_UI_creative_ingredients_icon')
   else tex=B:icon(t.icon)end
   if not valid(tex)then tex=B:icon(t.category=='search'and'MC_IronPickaxe'or'MC_Stone')end
   icon:SetVisibility(valid(tex)and 3 or 1)
   if valid(tex)then self:icon(icon,tex,16,0);self:position(icon,x+5,y+(t.y<0 and 9 or 6),16,16,unit);icon.Slot:SetZOrder(9)end
   B.tabBoxes[i]={x,y,26,28,t.category,t.label}
  end
 end
 function U:catalogPaint(ns,B,env)
  for _,s in ipairs(B:layout().slots)do self:stackCount(ns[s.name..'Count'],s.x,s.y+10,B.uiUnit)end
  self:stackCount(ns.LiftCount,nil,nil,B.uiUnit)
  ns.creativeCatalog=B.creative==true
  ns.creativeSearchBounds=nil
  if not B.creative then
   self.catalogOwner=nil
   for _,key in ipairs({'VBCatalogTitle','VBDelete','VBEmpty'})do if valid(ns[key])then ns[key]:SetVisibility(1)end end
   return
  end
  local unit=B.uiUnit;self.env=env;self.catalogOwner={nodes=ns,inventory=B,env=env}
  B:layout().creative=nil
  B.catalogRow=L.clampRow(B.catalogRow,#B.filtered)
  
  for _,key in ipairs({'CreativeButton','CreativeLabel','Prev','Next','Page','GuiExtra1','GuiExtra2','CatalogHeader','GuiList','GuiTabLabel1','GuiTabLabel2','GuiTabLabel3','GuiInventoryLabel','GuiOffhand'})do
   if valid(ns[key])then ns[key]:SetVisibility(1)end
  end
  for key,n in pairs(ns)do
   if type(key)=='string'and(key:match('^Slot57')or key:match('^Panel57')or key:match('^Arrow57'))and valid(n)then n:SetVisibility(1)end
  end
  local search=(B.category or'search')=='search'
  self:brush(ns.GuiBackground,search and'T_MC_UI_creative_search'or'T_MC_UI_creative_items')
  self:position(ns.GuiBackground,-97.5,-68,195,136,unit)
  self:creativeTabs(ns,B,unit)
  local title='Search Items'
  for _,t in ipairs(L.tabs)do if t.category==B.category then title=t.label end end
  local heading=label(ns,'VBCatalogTitle',title,-89.5,-62,174,10,true,12,unit);heading:SetVisibility(search and 1 or 3)
  local field=ns.CreativeSearch
  if search then
   ns.creativeSearchBounds={x=L.search[1],y=L.search[2],w=L.search[3],h=L.search[4]}
   self:position(field,L.search[1]+2,L.search[2]+1,L.search[3]-4,L.search[4]-1,unit);field.Slot:SetZOrder(20)

   local style=field.WidgetStyle;local font=style.TextStyle.Font
   font.FontObject=self:pixelFont53();font.TypefaceFontName=UE.FindOrAddFName('Regular');font.Size=self:fontSize(6,unit)
   style.TextStyle.Font=font;style.Padding={Left=0,Top=0,Right=0,Bottom=0}
   for _,key in ipairs({'BackgroundImageNormal','BackgroundImageHovered','BackgroundImageFocused','BackgroundImageReadOnly'})do style[key].DrawAs=0 end
   style.ForegroundColor={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0};style.FocusedForegroundColor=style.ForegroundColor
   field.WidgetStyle=style
   local hint=UE.language57 and UE.language57:t('Search Items')or'Search Items'
   field:SetHintText(UE.GetKismetTextLibrary():Conv_StringToText(hint))
   field:SetForegroundColor({R=1,G=1,B=1,A=1});field:SetClipping(1);field:SetVisibility(0)
  else field:SetVisibility(1)end
  local max=L.maxRow(#B.filtered)
  image(ns,'GuiScroller',max>0 and'T_MC_UI_container_creative_inventory_scroller'or'T_MC_UI_container_creative_inventory_scroller_disabled',L.track[1],L.thumbY(B.catalogRow,#B.filtered),12,15,8,unit)
  
  image(ns,'VBDelete','T_MC_UI_creative_delete',L.delete[1],L.delete[2],18,18,8,unit)
  local empty=label(ns,'VBEmpty','No results',-88.5,-16,160,10,true,12,unit);empty:SetJustification(1);empty:SetVisibility(#B.filtered==0 and 3 or 1)
  
  for i=1,45 do if valid(ns['Main'..i..'Count'])then ns['Main'..i..'Count']:SetVisibility(1)end end
  B.mouseX=nil
 end
 function U:catalogClick(ns,B,env,x,y,right,shift)
  if not B.creative then return false end
  if (B.category or'search')=='search'and inside(x,y,L.search)then if not right then self:focusField(env,ns.CreativeSearch)end;return true end
  if self:editing()then self:clearField()end
  if inside(x,y,L.track)then
   if not right then B.catalogRow=L.dragRow(y,#B.filtered);B.catalogDrag=true;B:refresh(env)end
   return true
  end
  if inside(x,y,L.delete)then
   if not right and B:creativeAllowed()then B:deleteCatalogCarry(env);B:refresh(env)end
   return true
  end
  for _,b in ipairs(B.tabBoxes or{})do if inside(x,y,b)then
   if not right then
    if self:editing()then self:clearField()end
    if b[5]=='inventory'then B:toggleCatalog(env)
    else B.category=b[5];B.catalogRow=0;B.page=0;B.search='';ns.CreativeSearch:SetText(UE.GetKismetTextLibrary():Conv_StringToText(''));B.filtered=B:catalog('');B:refresh(env)end
    ctx.log('MCVB_CREATIVE_TAB '..b[5])
   end
   return true
  end end
  return false
 end
 function U:catalogHover(ns,B,x,y)
  if not B.creative then return false end
  local title,box
  for _,b in ipairs(B.tabBoxes or{})do if inside(x,y,b)then title,box=b[6],b;break end end
  if inside(x,y,L.delete)then title,box='Destroy Item',L.delete end
  if title then
   if valid(ns.GuiHover)then ns.GuiHover:SetVisibility(1)end
   
   self:position(ns.LiftIcon,x-8,y-8,16,16,B.uiUnit);self:position(ns.LiftCount,x-8,y+2,16,8,B.uiUnit)
   self:richTooltip(ns,{title=title,lines={},source='Minecraft',exclude={x=box[1],y=box[2],w=box[3],h=box[4]}},x,y,B.uiUnit)
   return true
  end
  return false
 end
 local wheel={KeyName=UE.FindOrAddFName('MouseWheelAxis')};local left={KeyName=UE.FindOrAddFName('LeftMouseButton')}
 T.frame('creative-catalog-input',function()
  local owner=U.catalogOwner
  if not owner then return end
  local B,ns,env=owner.inventory,owner.nodes,owner.env
  if not B.open or not B.creative or not valid(env.controller)or(UE.creativeUI and UE.creativeUI.pending)then B.catalogDrag=nil;return end
  local x,y=B:mouse(env);local down=env.controller:IsInputKeyDown(left)
  local row=B.catalogRow or 0
  if B.catalogDrag and down then B.catalogRow=L.dragRow(y,#B.filtered)elseif not down then B.catalogDrag=nil end
  local delta=env.controller:GetInputAnalogKeyState(wheel)
  if delta~=0 and x>=-97.5 and x<97.5 and y>=-68 and y<68 then
   B.catalogWheel=(B.catalogWheel or 0)+delta
   local n=math.floor(math.abs(B.catalogWheel)+.00001)
   if n>0 then local direction=B.catalogWheel>0 and-1 or 1;B.catalogWheel=B.catalogWheel+direction*n;B.catalogRow=L.clampRow((B.catalogRow or 0)+direction*n,#B.filtered)end
  end
  if row~=B.catalogRow then B:refresh(env);B:hover(env,true)end
 end)
 T.onEpoch('creative-catalog-input',function()U.catalogOwner=nil end)
end
