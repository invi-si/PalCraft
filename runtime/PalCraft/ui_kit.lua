-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local U={gameButtons={[2]={-102,50,204},[1]={-102,-70,204},[4]={-102,-46,98},[9]={4,-46,98},[3]={-102,-22,98},[6]={4,-22,98},[7]={-102,2,98},[5]={4,2,98},[8]={-102,26,204}}};local valid,UE,log=ctx.valid,ctx.UE,ctx.log;local paths=dofile(ctx.base..'/gui_layouts.lua');local cache={}
 dofile(ctx.base..'/font53.lua')(ctx,U)
 U.language57=UE.language57
 local f=io.open(ctx.base..'/ui-settings.json','rb');if f then local ok,data=pcall(dofile(ctx.base..'/json.lua').decode,f:read(4096));f:close();if ok and type(data)=='table'then if type(data.gui_scale)=='number'and data.gui_scale>=0 and data.gui_scale<=4 then ctx.config.gui_scale=math.floor(data.gui_scale)end;if type(data.mc_sound_volume)=='number'then ctx.config.mc_sound_volume=math.max(0,math.min(1,data.mc_sound_volume))end;if type(data.hud)=='boolean'then ctx.config.hud=data.hud end end end
 local assetIds={};local textureHolders={}
 function U:retainTexture(t)
  if not valid(self.iconCacheRoot)or not valid(t)or not t:IsA(UE.Object('/Script/Engine.Texture'))then return end

  local retained=self.titleRetainedOC and self.titleRetainedOC[t:GetAddress()]
  if valid(retained)and retained:GetFullName()==t:GetFullName()then return end
  local k=t:GetAddress();if valid(textureHolders[k])then return end
  local n=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.Image'),self.iconCacheRoot:GetOuter());assert(valid(n),'Texture retainer missing');self.iconCacheRoot:AddChildToCanvas(n);n.Slot:SetSize({X=1,Y=1});n:SetVisibility(3);n:SetRenderOpacity(0);n:SetBrushFromTexture(t,false);textureHolders[k]=n
 end
 function U:bindIconCacheRoot(root)
  if valid(self.iconCacheRoot)and valid(root)and self.iconCacheRoot:GetAddress()==root:GetAddress()then return end
  self.iconCacheRoot=root;textureHolders={};for name,t in pairs(cache)do local id=assetIds[name];if valid(t)and id and t:GetClass():GetAddress()==id.class and t:GetFName():ToString()==id.name then self:retainTexture(t)end end
 end
 function U:asset(name)
  if self.productionAssets and self.productionAssets[name]then return self.productionAssets[name]end
  local package=(name=='F_MC_UI53'and'/Game/MinecraftFont/'or'/Game/MinecraftBlocks/')..name;local path=package..'.'..name
  local id=assetIds[name];if valid(cache[name])and id and cache[name]:GetClass():GetAddress()==id.class and cache[name]:GetFName():ToString()==id.name then if self.productionAssets then self.productionAssets[name]=cache[name]end;return cache[name]end
  if valid(cache[name])then log('MC_STALE_CACHE ui-kit MC_20_ASSET_CACHE_REPAIRED '..name..' previous='..cache[name]:GetFullName())end
  local o=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(package),AssetName=UE.FindOrAddFName(name)})
  if not valid(o)then o=StaticFindObject(path)end
  assert(valid(o)and UE.AssetMatchesRA(o,path),'UI asset missing '..name);cache[name]=o;assetIds[name]={class=o:GetClass():GetAddress(),name=o:GetFName():ToString()};self:retainTexture(o);if self.productionAssets then self.productionAssets[name]=o end;return o
 end
 function U:metrics(env)
  local lib=UE.Object('/Script/UMG.Default__WidgetLayoutLibrary');local size=lib:GetViewportSize(env.player);local dpi=lib:GetViewportScale(env.player)
  local s=math.max(1,math.floor(math.min(size.X/320,size.Y/240)));if(ctx.config.gui_scale or 0)>0 then s=math.min(s,ctx.config.gui_scale)end
  return s,s/dpi,dpi,size
 end
 function U:position(n,x,y,w,h,unit)
  if not valid(n)then return end;n.Slot:SetAnchors({Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}});n.Slot:SetPosition({X=x*unit,Y=y*unit});n.Slot:SetSize({X=w*unit,Y=h*unit})
 end
 function U:brush(n,name,box)
  if not valid(n)then return end;local tex=self:asset(name);local brush=UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):MakeBrushFromTexture(tex,0,0)
  self.margins=self.margins or dofile(ctx.base..'/ui_sprites.lua');box=self.margins[name]or box
  if box then brush.DrawAs=1;brush.Margin={Left=box[1],Top=box[2],Right=box[3]or box[1],Bottom=box[4]or box[2]}end
  if box then brush.ImageSize={X=brush.ImageSize.X*(self.unit or 1),Y=brush.ImageSize.Y*(self.unit or 1)}end
  if n:IsA(UE.Object('/Script/UMG.Image'))then n:SetBrush(brush);n:SetColorAndOpacity({R=1,G=1,B=1,A=1})else n:SetBrush(brush);n:SetBrushColor({R=1,G=1,B=1,A=1})end
 end
 function U:poolBrush(n,name,tile,unit)
  self.poolBrushes=self.poolBrushes or{};local key=name..':'..tostring(self.unit or 1)..':'..tostring(tile);local brush=self.poolBrushes[key]
  if not brush then
   brush=UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):MakeBrushFromTexture(self:asset(name),0,0)
   local box=(self.margins or dofile(ctx.base..'/ui_sprites.lua'))[name]
   if tile then brush.DrawAs=3;brush.Tiling=3;brush.ImageSize={X=tile*unit,Y=tile*unit}
   elseif box then brush.DrawAs=1;brush.Margin={Left=box[1],Top=box[2],Right=box[3]or box[1],Bottom=box[4]or box[2]};brush.ImageSize={X=brush.ImageSize.X*(self.unit or 1),Y=brush.ImageSize.Y*(self.unit or 1)}end
   self.poolBrushes[key]=brush
  end
  n:SetBrush(brush)
 end
 function U:textStyle(n,unit,dark,color)
  if not valid(n)then return end;local f=n.Font;f.Size=math.max(1,math.floor(6*unit+.5))
  if not self.fontChecked then self.fontChecked=true;for _,name in ipairs({'F_MC_UI53'})do local ok,a=pcall(self.asset,self,name);if ok and valid(a)then self.font=a;break end end end
  if valid(self.font)then f.FontObject=self.font;f.TypefaceFontName=UE.FindOrAddFName('Regular')end;n:SetFont(f)
  local c=color or(dark and{R=.251,G=.251,B=.251,A=1}or{R=1,G=1,B=1,A=1});local function linear(x)return x<=.04045 and x/12.92 or((x+.055)/1.055)^2.4 end
  n:SetColorAndOpacity({SpecifiedColor={R=linear(c.R),G=linear(c.G),B=linear(c.B),A=c.A},ColorUseRule=0})
  n:SetShadowOffset(dark and{X=0,Y=0}or{X=unit,Y=unit});n:SetShadowColorAndOpacity({R=linear(c.R*.25),G=linear(c.G*.25),B=linear(c.B*.25),A=dark and 0 or 1})
 end
 function U:apply(widget,name,env)
  local nodes=ctx.widgets(widget);local s,unit,dpi=self:metrics(env);local layout=paths[name];local factor=unit/3
  if UE.texRuntime then UE.texRuntime:widgets(nodes)end
  if layout and name~='WBP_MCHUD'and name~='WBP_MCTitle'and name~='WBP_MCGameMenu'and not name:find('Inventory')and not name:find('Chest')and name~='WBP_MCFurnace'then
   local maxX,maxY=0,0;for _,p in pairs(layout)do if p.position and p.type~='CanvasPanel'and p.position[1]~=0 and p.size[1]>0 then maxX=math.max(maxX,math.abs(p.position[1]),math.abs(p.position[1]+p.size[1]));maxY=math.max(maxY,math.abs(p.position[2]),math.abs(p.position[2]+p.size[2]))end end
   local _,_,_,size=self:metrics(env);if maxX>0 and maxY>0 then s=math.max(1,math.min(s,math.floor(math.min(size.X/(maxX*2/3+8),size.Y/(maxY*2/3+8)))));unit=s/dpi;factor=unit/3 end
  end
  self.unit=unit
  if layout then for key,p in pairs(layout)do local n=nodes[key]
   if valid(n)and p.position then n.Slot:SetPosition({X=p.position[1]*factor,Y=p.position[2]*factor});n.Slot:SetSize({X=p.size[1]*factor,Y=p.size[2]*factor});n.Slot:SetZOrder((p.z or 0)+10)end
   if valid(n)and p.type=='TextBlock'then self:textStyle(n,unit,key=='Title'or key:find('Title')~=nil,name=='WBP_MCHUD'and key=='Level'and{R=.502,G=1,B=.125,A=1}or nil)end
   if valid(n)and p.type=='EditableText'then local f=n.WidgetStyle.Font;f.Size=math.max(1,math.floor(6*unit+.5));f.FontObject=self:pixelFont53();f.TypefaceFontName=UE.FindOrAddFName('Regular');n:SetFont(f)end
   if valid(n)and(p.type=='Border')and key~='Dim'and key~='TooltipBox'then self:brush(n,name=='WBP_MCProduction'and key~='Panel'and'T_MC_UI_widget_button'or'T_MC_UI_panel',{4/176,4/166})end
   if valid(n)and p.type=='Image'and key:match('^Button%d+$')then self:brush(n,'T_MC_UI_widget_button',{2/200,2/20})end
   if valid(n)and p.type=='Image'and key:match('Frame%d+$')then self:brush(n,'T_MC_UI_slot',{1/18,1/18})end
  end end
  if valid(nodes.Dim)then self:brush(nodes.Dim,'T_MC_UI_dim');nodes.Dim.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}});nodes.Dim.Slot:SetPosition({X=0,Y=0});nodes.Dim.Slot:SetSize({X=0,Y=0});nodes.Dim.Slot:SetZOrder(0)end
  if valid(nodes.TooltipBox)then self:brush(nodes.TooltipBox,'T_MC_UI_tooltip_background',{.2,.2})end
  if name=='WBP_MCPalpedia'then for i=1,30 do local n=nodes['DexLabel'..i];if valid(n)then n:SetClipping(1)end end end
  if name=='WBP_MCTechnology'and valid(nodes.Tooltip)then local f=nodes.Tooltip.Font;f.Size=math.max(1,math.floor(4*unit+.5));nodes.Tooltip:SetFont(f);nodes.Tooltip:SetClipping(1)end
  if valid(nodes.GuiPanel)then self:brush(nodes.GuiPanel,'T_MC_UI_panel',{4/176,4/166});self:position(nodes.GuiPanel,-196,-122,392,264,unit);nodes.GuiPanel.Slot:SetZOrder(1);nodes.GuiPanel:SetVisibility(3)end
  if name=='WBP_MCDeath'then self:textStyle(nodes.Title,unit,false);local f=nodes.Title.Font;f.Size=f.Size*2;nodes.Title:SetFont(f)end
  if name=='WBP_MCTitle'then self:position(nodes.Logo,-400/3,-345/3,800/3,200/3,unit);for i=1,4 do local y=(-95+(i-1)*76)/3;self:position(nodes['Label'..i],-100,y+4,200,14,unit);nodes['Label'..i]:SetJustification(1)end end
  if name=='WBP_MCGameMenu'then
   if valid(nodes.Panel)then nodes.Panel:SetVisibility(1)end
   for i=1,9 do local b=self.gameButtons[i];nodes['Button'..i]:SetVisibility(b and 3 or 1);nodes['Label'..i]:SetVisibility(b and 3 or 1);if b then self:position(nodes['Button'..i],b[1],b[2],b[3],20,unit);self:position(nodes['Label'..i],b[1],b[2]+4,b[3],14,unit);nodes['Label'..i]:SetJustification(1)end end
   self:position(nodes.Title,-102,-105,204,15,unit);self:textStyle(nodes.Title,unit,false);nodes.Title:SetJustification(1)
  end
  log('MC_J_GUI_READY name='..name..' guiScale='..s..' dpi='..dpi..' unit='..unit);return factor,unit
 end
 function U:container(nodes,B,env)
  local layout=B:layout();local scale,unit,dpi,size=self:metrics(env)
  if not B.mode and B.size==2 and not B.creative and self.inventoryFit67 then scale=self.inventoryFit67(size.X,size.Y,scale,ctx.UE.drawer67Open);unit=scale/dpi end
  B.uiUnit=unit;self.unit=unit;nodes.containerUnit61=unit
  local name=B.creative and'T_MC_UI_creative_crop'or B.mode=='Furnace'and'T_MC_UI_furnace_crop'or(B.mode and B.mode:find('Chest'))and('T_MC_UI_chest'..(B.storageSize==54 and 6 or 3))or B.size==3 and'T_MC_UI_crafting_table_crop'or'T_MC_UI_inventory_crop'
  for _,key in ipairs({'Background','CatalogHeader','Panel','Title','Help','Defense','Arrow','Flame','CookArrow','PlayerPreview','ArmorBox1','ArmorBox2','ArmorBox3','ArmorBox4'})do if valid(nodes[key])then nodes[key]:SetVisibility(1)end end
  for _,key in ipairs({'StorageGrid','PlayerGrid'})do if valid(nodes[key])then nodes[key]:SetVisibility(3)end end
  local dim=nodes.Dim or nodes.Background;if valid(dim)then self:brush(dim,'T_MC_UI_dim');dim.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}});dim.Slot:SetPosition({X=0,Y=0});dim.Slot:SetSize({X=0,Y=0});dim.Slot:SetZOrder(0);dim:SetVisibility(3)end
  self:brush(nodes.GuiBackground,name);self:position(nodes.GuiBackground,-layout.width/2,-layout.height/2,layout.width,layout.height,unit);nodes.GuiBackground.Slot:SetZOrder(1);nodes.GuiBackground:SetVisibility(3)
  local used={};for _,p in ipairs(layout.slots)do used[p.name]=true end
  for key,n in pairs(nodes)do if key:match('^%a+%d+Frame$')and valid(n)then n:SetVisibility(1)end end
  for _,prefix in ipairs({'Main','Bar','Craft','Armor','Storage'})do for i=1,54 do if not used[prefix..i]then for _,suffix in ipairs({'Icon','Count','Durability','DurabilityBG'})do if valid(nodes[prefix..i..suffix])then nodes[prefix..i..suffix]:SetVisibility(1)end end end end end
  for _,p in ipairs(layout.slots)do local icon,count=nodes[p.name..'Icon'],nodes[p.name..'Count'];self:position(icon,p.x,p.y,16,16,unit);self:position(count,p.x+1,p.y+8,16,10,unit);if valid(icon)then icon.Slot:SetZOrder(10)end;if valid(count)then count.Slot:SetZOrder(12);count:SetJustification(2);self:textStyle(count,unit);count:SetVisibility(3)end end
  self:position(nodes.Prev,layout.prev[1],layout.prev[2],10,10,unit);self:position(nodes.Next,layout.next[1],layout.next[2],10,10,unit);self:position(nodes.Page,45,-layout.height/2-15,30,10,unit)
  nodes.Page:SetVisibility(B.creative and 1 or 3)
  if B.creative then self:position(nodes.Page,56,-61,20,10,unit);self:position(nodes.Prev,76,-63,8,10,unit);self:position(nodes.Next,87,-63,8,10,unit)end
  if valid(nodes.StoragePage)then local pages=math.max(1,math.ceil(B.native.containers.external:Num()/B.storageSize));local show=pages>1 and 3 or 1
   nodes.StoragePage:SetVisibility(show);nodes.StoragePrev:SetVisibility(show);nodes.StorageNext:SetVisibility(show)
   self:position(nodes.StoragePage,-50,-layout.height/2-15,60,10,unit)
   for _,key in ipairs({'StoragePrev','StorageNext'})do local p=layout[key=='StoragePrev'and'storagePrev'or'storageNext'];self:position(nodes[key],p[1],p[2],p[3],p[4],unit)end
  end
  if valid(nodes.GuiHover)then self:brush(nodes.GuiHover,'T_MC_UI_white');nodes.GuiHover:SetColorAndOpacity({R=1,G=1,B=1,A=.5});nodes.GuiHover.Slot:SetZOrder(40)end
  if valid(nodes.CreativeButton)and layout.creative then self:brush(nodes.CreativeButton,'T_MC_UI_widget_button',{.01,.1});local b=layout.creative;self:position(nodes.CreativeButton,b[1],b[2],b[3],b[4],unit)end
  if valid(nodes.CreativeLabel)then nodes.CreativeLabel:SetJustification(1)end
  if valid(nodes.CreativeSearch)then self:position(nodes.CreativeSearch,82-layout.width/2,6-layout.height/2,80,12,unit);nodes.CreativeSearch:SetVisibility(B.creative and 0 or 1);local style=nodes.CreativeSearch.WidgetStyle;local wb=UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary');style.BackgroundImageNormal=wb:MakeBrushFromTexture(self:asset('T_MC_UI_widget_text_field'),0,0);style.BackgroundImageFocused=wb:MakeBrushFromTexture(self:asset('T_MC_UI_widget_text_field_highlighted'),0,0);style.BackgroundImageHovered=style.BackgroundImageFocused;style.TextStyle.Font.Size=math.floor(6*unit+.5);style.TextStyle.Font.FontObject=self:pixelFont53();style.TextStyle.Font.TypefaceFontName=UE.FindOrAddFName('Regular');nodes.CreativeSearch.WidgetStyle=style end
  if valid(nodes.GuiScroller)then nodes.GuiScroller:SetVisibility(B.creative and 3 or 1);nodes.GuiScroller.Slot:SetZOrder(8);if B.creative then local pages=math.max(1,math.ceil(#B.filtered/45));self:brush(nodes.GuiScroller,'T_MC_UI_container_creative_inventory_scroller');self:position(nodes.GuiScroller,175-97.5,18-68+(pages>1 and 72*B.page/(pages-1)or 0),12,15,unit)end end
  if valid(nodes.PlayerPreview)and not B.creative and B.size==2 and not B.mode then self:position(nodes.PlayerPreview,26-88,8-83,49,70,unit);nodes.PlayerPreview:SetVisibility(3)end
  if not B.creative and valid(nodes.Title)then local x=(not B.mode and B.size==2)and 97 or(not B.mode and B.size==3)and 29 or 8;local y=(not B.mode and B.size==2)and 8 or 6;self:position(nodes.Title,x-88,y-layout.height/2,140-x,10,unit);self:textStyle(nodes.Title,unit,true);nodes.Title:SetText(UE.GetKismetTextLibrary():Conv_StringToText(B.mode=='Furnace'and'Furnace'or B.mode and'Chest'or'Crafting'));nodes.Title:SetVisibility(3)end
  if valid(nodes.GuiInventoryLabel)then self:position(nodes.GuiInventoryLabel,8-88,(B.mode and B.mode:find('Chest')and(91+((B.storageSize==54 and 6 or 3)-4)*18)or 72)-layout.height/2,100,10,unit);self:textStyle(nodes.GuiInventoryLabel,unit,true);nodes.GuiInventoryLabel.Slot:SetZOrder(8);nodes.GuiInventoryLabel:SetVisibility(B.creative and 1 or 3)end
  self:position(nodes.LiftIcon,0,0,16,16,unit);self:position(nodes.LiftCount,0,0,20,10,unit)
  if valid(nodes.TooltipBox)then nodes.TooltipBox.Slot:SetSize({X=160*unit,Y=14*unit})end
  if valid(nodes.GuiOffhand)then self:brush(nodes.GuiOffhand,'T_MC_UI_white');self:position(nodes.GuiOffhand,77-88,62-83,16,16,unit);nodes.GuiOffhand.Slot:SetZOrder(11);nodes.GuiOffhand:SetColorAndOpacity({R=.3,G=.3,B=.3,A=.35});nodes.GuiOffhand:SetVisibility(not B.creative and B.size==2 and not B.mode and 3 or 1)end
  if B.creative then self:creativeTabs(nodes,B,unit);nodes.CreativeButton:SetVisibility(1)elseif valid(nodes.GuiTab1)then for i=1,10 do nodes['GuiTab'..i]:SetVisibility(1);nodes['GuiTabIcon'..i]:SetVisibility(1)end;nodes.CreativeButton:SetVisibility(3)end
  if B.mode=='Furnace'then self:brush(nodes.FlameFill,'T_MC_UI_container_furnace_lit_progress');self:brush(nodes.CookArrowFill,'T_MC_UI_container_furnace_burn_progress');self:position(nodes.FlameClip,56-88,36-83,14,14,unit);self:position(nodes.CookArrowClip,79-88,34-83,24,16,unit)end
  return unit
 end
 U.categories={'building','coloured','natural','functional','tools','combat','food','materials','search','inventory'}
 U.categoryIcons={'MC_Bricks','MC_RedWool','MC_GrassBlock','MC_CraftingTable','MC_IronPickaxe','MC_IronSword','MC_Bread','IronIngot','MC_Stone','MC_Chest'}
 function U:creativeTabs(nodes,B,unit)
  B.tabBoxes={};for i=1,10 do local x=-97.5+(i<=5 and(i-1)*30 or i==10 and 165 or(i-6)*30);local y=i<=5 and-96 or 68;local category=self.categories[i];local selected=(B.category or'search')==category
   self:brush(nodes['GuiTab'..i],selected and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button');self:position(nodes['GuiTab'..i],x,y,28,32,unit);nodes['GuiTab'..i].Slot:SetZOrder(2);nodes['GuiTab'..i]:SetVisibility(3)
   local icon=B:icon(self.categoryIcons[i]);nodes['GuiTabIcon'..i]:SetVisibility(valid(icon)and 3 or 1);if valid(icon)then if ctx.config.task20_ui then self:icon(nodes['GuiTabIcon'..i],icon,16,1)else nodes['GuiTabIcon'..i]:SetBrushFromTexture(icon,false)end end;self:position(nodes['GuiTabIcon'..i],x+6,y+8,16,16,unit);nodes['GuiTabIcon'..i].Slot:SetZOrder(3);B.tabBoxes[i]={x,y,28,32,category}
  end
 end
 function U:tooltip(nodes,entry,label,x,y,unit)
  local show=entry and entry.id;nodes.TooltipBox:SetVisibility(show and 3 or 1);nodes.GuiTooltipFrame:SetVisibility(show and 3 or 1)
  if not show then return end
  local w=math.max(100,math.min(230,#label*5+12));local h=25;self:position(nodes.TooltipBox,x+4,y-26,w,h,unit);self:brush(nodes.GuiTooltipFrame,'T_MC_UI_tooltip_frame');self:position(nodes.GuiTooltipFrame,x+4,y-26,w,h,unit);nodes.GuiTooltipFrame.Slot:SetZOrder(50)
  nodes.TooltipBox.Slot:SetZOrder(49);self:textStyle(nodes.Tooltip,unit);nodes.Tooltip:SetText(UE.GetKismetTextLibrary():Conv_StringToText(label..'\nCount: '..tostring(entry.count or 0)))
 end
 function U:hoverButtons(nodes,name,x,y)
  local layout=paths[name];if not layout then return end
  for key,p in pairs(layout)do if key:match('^Button%d+$')and valid(nodes[key])and p.position then local r=self.gameButtons[tonumber(key:match('%d+'))];local xx,yy,w,h
   if name=='WBP_MCGameMenu'and r then xx,yy,w,h=r[1]*3,r[2]*3,r[3]*3,60 else xx,yy,w,h=p.position[1],p.position[2],p.size[1],p.size[2]end
   local hover=x>=xx and x<xx+w and y>=yy and y<yy+h;local token=hover and 1 or 0;self.hoverCache=self.hoverCache or{};local address=nodes[key]:GetAddress()
   if self.hoverCache[address]~=token then self.hoverCache[address]=token;self:brush(nodes[key],hover and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button')end
  end end
 end
 function U:durability(nodes,spec,entry,B)
  local bar,bg=nodes[spec.name..'Durability'],nodes[spec.name..'DurabilityBG'];if not valid(bar)then return end
  local value,max;local data=entry.id and B:data(entry.id)
  if valid(data)and valid(entry.slot)and data.Durability>0 then
   local out={};if _G.MC_OUT_K('TryGetDynamicItemData',entry.slot,out)and valid(out.OutDynamicItemData)then local d=out.OutDynamicItemData;local property
    d:GetClass():ForEachProperty(function(p)if p:GetFullName():match(':([^:]+)$')=='Durability'then property='Durability'end end)
    if property then value,max=d[property],data.Durability end
   end
  end
  local show=type(value)=='number'and type(max)=='number'and max>0 and value<max;bar:SetVisibility(show and 3 or 1);bg:SetVisibility(show and 3 or 1)
  if show then local ratio=math.max(0,math.min(1,value/max));self:brush(bg,'T_MC_UI_white');self:brush(bar,'T_MC_UI_white');self:position(bg,spec.x+2,spec.y+13,13,2,B.uiUnit);self:position(bar,spec.x+2,spec.y+13,math.max(1,math.floor(13*ratio+.5)),1,B.uiUnit);bg:SetColorAndOpacity({R=0,G=0,B=0,A=1});bar:SetColorAndOpacity({R=1-ratio,G=ratio,B=0,A=1});bg.Slot:SetZOrder(13);bar.Slot:SetZOrder(14)end
 end
 if ctx.config.task20_ui then dofile(ctx.base..'/ui20.lua')(ctx,U,paths)end

 local draws={}
 local function record(n,key,value)
  if not valid(n)then return false end
  local a=n:GetAddress();local r=draws[a];if not r then r={};draws[a]=r end
  if r[key]==value then return false end;r[key]=value;return true
 end
 function U:visible(n,value)if record(n,'visible',value)then n:SetVisibility(value)end end
 function U:putText(n,value)value=tostring(value or'');if UE.language57 then value=UE.language57:t(value)end;if record(n,'text',value)then n:SetText(UE.GetKismetTextLibrary():Conv_StringToText(value))end end
 local position,brush,style,icon,fill,apply=U.position,U.brush,U.textStyle,U.icon,U.fill,U.apply
 function U:apply(widget,name,env)
  if UE.language57 then UE.language57:refresh(true)end
  for _,n in pairs(ctx.widgets(widget))do if valid(n)then draws[n:GetAddress()]=nil end end
  local factor,unit=apply(self,widget,name,env)
  if UE.language57 then for _,n in pairs(ctx.widgets(widget))do if valid(n)and n:IsA(UE.Object('/Script/UMG.TextBlock'))then local s=UE.GetKismetTextLibrary():Conv_TextToString(n:GetText());s=type(s)=='string'and s or s:ToString();self:putText(n,s)end end end
  return factor,unit
 end
 function U:position(n,x,y,w,h,unit)
  local value=table.concat({x,y,w,h,unit},':');if record(n,'position',value)then position(self,n,x,y,w,h,unit)end
 end
 function U:brush(n,name,box)
  local value='brush:'..name..':'..(box and table.concat(box,':')or'');if record(n,'surface',value)then brush(self,n,name,box)end
 end
 function U:textStyle(n,unit,dark,color)
  local value=unit..':'..tostring(dark)..':'..(color and table.concat({color.R,color.G,color.B,color.A or 1},':')or'')
  if record(n,'style',value)then style(self,n,unit,dark,color)end
 end
 function U:icon(n,t,cells,outline,gain)
  if not valid(t)then return end
  local value='icon:'..t:GetAddress()..':'..tostring(cells)..':'..tostring(outline)..':'..tostring(gain)
  if record(n,'surface',value)then icon(self,n,t,cells,outline,gain);n:SetColorAndOpacity({R=1,G=1,B=1,A=1})end
 end
 function U:fill(n,hex,alpha)
  local changed=record(n,'fill',hex..':'..tostring(alpha));local r=draws[n:GetAddress()]
  if changed or not r or r.surface~='brush:T_MC_UI_white:'then fill(self,n,hex,alpha)end
 end
 function U:forgetGraph(nodes)for _,n in pairs(nodes or{})do if valid(n)then draws[n:GetAddress()]=nil end end end
 dofile(ctx.base..'/timers.lua').onEpoch('ui-draw-diffs',function()draws={};U.poolState=nil end)
 dofile(ctx.base..'/timers.lua').onEpoch('ui-kit',function()
  cache={};U.nativeHud=nil;U.nativeToastTexture=nil;U.font=nil;U.fontChecked=nil;U.hoverCache=nil;U.env=nil;U.inventory=nil;U.unit=nil;U.productionOps=nil;U.productionAssets=nil;U.poolBrushes=nil
 end)
 dofile(ctx.base..'/ui46.lua')(ctx,U)
 dofile(ctx.base..'/ui54.lua')(ctx,U)
 dofile(ctx.base..'/ui_input.lua')(ctx,U)
 dofile(ctx.base..'/ui57.lua')(ctx,U)
 dofile(ctx.base..'/ui58.lua')(ctx,U)
 dofile(ctx.base..'/ui67.lua')(ctx,U)
 dofile(ctx.base..'/creative_catalog.lua')(ctx,U)
 return U
end
