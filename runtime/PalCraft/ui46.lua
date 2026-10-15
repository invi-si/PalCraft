-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U)
 local UE,valid=ctx.UE,ctx.valid
 local tabs={{'Inventory','MC_CraftingTable'},{'Pals','PalSphere'},{'PC','MC_Chest'},{'Technology','MC_IronPickaxe'},{'Palpedia','MC_Bookshelf'}}
 local titles={Inventory='Inventory',Pals='Pals',PC='Pal Box',Technology='Technology',Palpedia='Palpedia'}
 local sizes={Pals={248,180},PC={292,200},Technology={252,180},Palpedia={256,200},Inventory={176,166}}
 local function root(ns)return ns.CanvasPanel_0 or(valid(ns.GuiBackground)and ns.GuiBackground:GetParent())or(valid(ns.GuiList)and ns.GuiList:GetParent())end
 function U:makeNode(ns,key,kind)
  if valid(ns[key])then return ns[key]end
  local r=root(ns);assert(valid(r),'UI46 canvas missing')
  local n=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.'..kind),r:GetOuter());assert(valid(n));r:AddChildToCanvas(n);n:SetVisibility(3);ns[key]=n;return n
 end
 function U:navTabs(ns,env,kind)
  local size=sizes[kind];if not size then return end
  local _,unit=self:metrics(env);ns.navKind=kind;ns.navRects={};self.env=env
  local y=-size[2]/2-28
  for i,t in ipairs(tabs)do
   local x=-size[1]/2+(i-1)*30;local n=self:makeNode(ns,'Nav46_'..i,'Image');local icon=self:makeNode(ns,'Nav46Icon_'..i,'Image')
   self:brush(n,'T_MC_UI_creative_tab_top_'..(t[1]==kind and'selected'or'unselected')..'_1');self:position(n,x,y,28,32,unit);n.Slot:SetZOrder(65)
   local tex=U.items:icon(t[2]);if not valid(tex)then tex=U.items:icon(i==3 and'MC_Chest'or'MC_Stone')end
   if valid(tex)then self:icon(icon,tex,16,1);self:position(icon,x+6,y+8,16,16,unit);icon.Slot:SetZOrder(66)end
   ns.navRects[i]={x=x,y=y,w=28,h=28,kind=t[1],label=titles[t[1]],node=n}
  end
 end
 function U:navAt(ns,x,y)
  for _,r in ipairs(ns.navRects or{})do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then return r end end
 end
 function U:navHover(ns,env,x,y)
  local r=self:navAt(ns,x,y)
  for _,p in ipairs(ns.navRects or{})do p.node:SetColorAndOpacity({R=1,G=1,B=1,A=r==p and 1 or .85})end
  if r then local _,unit=self:metrics(env);unit=ns.unit67 or ns.inventoryUnit67 or unit;local first=ns.navRects[1];self:richTooltip(ns,{title=r.label,lines={},source='Minecraft',exclude={x=first.x,y=first.y,w=150,h=32}},x,y,unit);return true end
 end
 function U:trimLabel(s,width)
  if UE.language57 then s=UE.language57:t(s)end
  s=tostring(s or'');local out,pixels={},0
  if self:textWidth53(s)<=width then return s end
  for _,cp in utf8.codes(s)do local w=self:glyphAdvance53(cp)
   if pixels+w>width-8 then return table.concat(out)..'..'end;out[#out+1]=utf8.char(cp);pixels=pixels+w
  end;return s
 end
 function U:wrap46(s,width,maxLines)
  if UE.language57 then s=UE.language57:t(s)end
  s=self:cleanDescription(tostring(s or''));local out,line,pixels={},'',0
  local function flush()out[#out+1]=line;line,pixels='',0 end
  for word,space in s:gmatch('(%S+)(%s*)')do
   local ww=0;for _,cp in utf8.codes(word)do ww=ww+self:glyphAdvance53(cp)end
   if pixels>0 and pixels+ww+4>width then flush()end
   for _,cp in utf8.codes(word)do local w=self:glyphAdvance53(cp);if pixels+w>width then flush()end;line=line..utf8.char(cp);pixels=pixels+w end
   if space:find('\n',1,true)then flush()elseif space~=''then line=line..' ';pixels=pixels+4 end
   if #out>=(maxLines or 10)then out[#out]=self:trimLabel(out[#out],width);return out end
  end
  if line~=''then flush()end;return out
 end
 local palette={white={R=1,G=1,B=1,A=1},gray={R=.667,G=.667,B=.667,A=1},darkgray={R=.333,G=.333,B=.333,A=1},blue={R=.333,G=.333,B=1,A=1},aqua={R=.333,G=1,B=1,A=1},yellow={R=1,G=1,B=.333,A=1},red={R=1,G=.333,B=.333,A=1},green={R=0,G=.667,B=0,A=1},purple={R=1,G=.333,B=1,A=1},gold={R=1,G=.667,B=0,A=1}}
 function U:richTooltip(ns,data,x,y,unit)
  local signature={tostring(x),tostring(y),tostring(unit),data and data.title or'',data and data.source or'',data and data.color or''}
  for _,r in ipairs(data and data.lines or{})do signature[#signature+1]=type(r)=='string'and r or tostring(r.text)..':'..tostring(r.color)end
  local ex=data and data.exclude;if ex then signature[#signature+1]=table.concat({ex.x,ex.y,ex.w,ex.h},':')end
  local key=table.concat(signature,'|');if ns.tip46Key==key then return end
  self:hideTooltip(ns)
  ns.tip46Key=key
  for i=1,18 do if valid(ns['Tip46Line'..i])then ns['Tip46Line'..i]:SetVisibility(1)end end
  for _,k in ipairs({'Tip46BG','Tip46Frame'})do if valid(ns[k])then ns[k]:SetVisibility(1)end end
  if not data then return end
  local lines={{text=self:trimLabel(data.title,170),color=data.color or'white',title=true}}
  for _,r in ipairs(data.lines or{})do if #lines>=16 then break end
   if type(r)=='string'then r={text=r,color='gray'}end
   if r.text==''then lines[#lines+1]={text='',color='gray'}else for _,s in ipairs(self:wrap46(r.text,170,5))do if #lines<16 then lines[#lines+1]={text=s,color=r.color or'gray'}end end end
  end
  if data.source then lines[#lines+1]={text=data.source,color='blue',italic=true}end
  local w=32;for _,r in ipairs(lines)do local n=0;for _,cp in utf8.codes(r.text)do n=n+self:glyphAdvance53(cp)end;w=math.max(w,n)end;w=math.min(178,w+8)
  local h=#lines*10+8+2;local _,_,dpi,size=self:metrics(self.env);local right,bottom=size.X/(unit*dpi)/2,size.Y/(unit*dpi)/2;local offset=not ns.ui67 and(ns.navKind=='PC'or ns.navKind=='Palpedia')and 14 or 0
  local shift=ns.navKind=='Inventory'and(ctx.UE.drawer67Shift or 0)or 0
  local ex=data.exclude;local exclusions={};if ex then exclusions[1]=ex end
  local portrait=({Pals={x=-36,y=-58,w=60,h=60},PC={x=67,y=-77,w=60,h=60},Palpedia={x=-4,y=-80,w=64,h=64}})[ns.navKind]
  if portrait then exclusions[#exclusions+1]=portrait end
  local bounds=dofile(ctx.base..'/tooltip_placement.lua')(x,y,w,h,{left=-right-shift+2,right=right-shift-2,top=-bottom-offset+2,bottom=bottom-offset-2},exclusions)
  if not bounds then return end;local xx,yy=bounds.x,bounds.y
  local bg=self:makeNode(ns,'Tip46BG','Image');local frame=self:makeNode(ns,'Tip46Frame','Image')
  self:brush(bg,'T_MC_UI_tooltip_background');self:brush(frame,'T_MC_UI_tooltip_frame');self:position(bg,xx,yy,w,h,unit);self:position(frame,xx,yy,w,h,unit);bg.Slot:SetZOrder(100);frame.Slot:SetZOrder(101);bg:SetVisibility(3);frame:SetVisibility(3);bg:SetRenderOpacity(1);frame:SetRenderOpacity(1)
  for i,r in ipairs(lines)do local n=self:makeNode(ns,'Tip46Line'..i,'TextBlock');self:setMeta(n,{dark=false});self:textStyle(n,unit,false,palette[r.color]or palette.white);self:putText(n,r.text);self:position(n,xx+4,yy+4+(i-1)*10+(i>1 and 2 or 0),w-8,10,unit);n.Slot:SetZOrder(102);n:SetRenderShear({X=r.italic and-.15 or 0,Y=0});n:SetVisibility(3);n:SetRenderOpacity(1)end
  ns.tip46Bounds={x=xx,y=yy,w=w,h=h,exclude=ex and{x=ex.x,y=ex.y,w=ex.w,h=ex.h},title=data.title}
 end
 local hide=U.hideTooltip
 function U:hideTooltip(ns)
  hide(self,ns);for _,k in ipairs({'Tip46BG','Tip46Frame'})do if valid(ns[k])then ns[k]:SetVisibility(1)end end
  for i=1,18 do if valid(ns['Tip46Line'..i])then ns['Tip46Line'..i]:SetVisibility(1)end end;ns.tip46Bounds=nil;ns.tip46Key=nil
 end
 function U:tooltip(ns,entry,label,x,y,unit)
  if not entry or not entry.id then return self:richTooltip(ns,nil,x,y,unit)end
  local B=self.inventory or self.items;local id=entry.id;local d=B:data(id);local lines={};self.descriptions=self.descriptions or{}
  if self.descriptions[id]==nil then local out={};local ok=pcall(function()_G.MC_OUT_K('GetItemDescription',UE.Object('/Script/Pal.Default__PalUIUtility'),self.env.player,UE.FindOrAddFName(id),out)end);local s=ok and out.outName and UE.GetKismetTextLibrary():Conv_TextToString(out.outName);self.descriptions[id]=s and(type(s)=='string'and s or s:ToString())or''end
  if self.descriptions[id]~=''then lines[#lines+1]={text=self.descriptions[id]}end
  pcall(function()if d.DefenseValue>0 then lines[#lines+1]='';lines[#lines+1]='When on Body:';lines[#lines+1]={text='+'..d.DefenseValue..' Defense',color='blue'}elseif d.AttackValue>0 then lines[#lines+1]='';lines[#lines+1]='When in Main Hand:';lines[#lines+1]={text=d.AttackValue..' Attack',color='green'}end end)
  pcall(function()if valid(entry.slot)and d.Durability>0 then local out={};if _G.MC_OUT_K('TryGetDynamicItemData',entry.slot,out)and valid(out.OutDynamicItemData)then local value=out.OutDynamicItemData.Durability;if value<d.Durability then lines[#lines+1]='Durability: '..math.floor(value)..' / '..math.floor(d.Durability)end end end end)
  if entry.have~=nil then lines[#lines+1]='Have: '..entry.have end
  if self.env.controller:IsInputKeyDown({KeyName=UE.FindOrAddFName('LeftShift')})or self.env.controller:IsInputKeyDown({KeyName=UE.FindOrAddFName('RightShift')})then local mc=id:sub(1,3)=='MC_';lines[#lines+1]={text=(mc and'minecraft:'or'palworld:')..(mc and id:sub(4):gsub('(%l)(%u)','%1_%2'):lower()or id),color='darkgray'}end
  local rarity=valid(d)and d.Rarity or 0
  self:richTooltip(ns,{title=label,lines=lines,color=({'white','yellow','aqua','purple','gold'})[math.max(0,math.min(4,rarity))+1],source=id:sub(1,3)=='MC_'and'Minecraft'or'Palworld',exclude=entry.exclude},x,y,unit)
 end
 
 function U:recipeBook(ns,env,B)
  B.recipeBook=false;B.bookSlots={};B:layout().creative=nil
  for _,k in ipairs({'CreativeButton','CreativeLabel','GuiList','GuiTabLabel1','GuiTabLabel2','GuiTabLabel3','CreativeSearch'})do if valid(ns[k])then ns[k]:SetVisibility(1)end end
  if B.size==2 and not B.mode then self:navTabs(ns,env,'Inventory')end
 end
 function U:techTree(ns,env,E)
  local _,unit=self:metrics(env);local last,row,col=nil,-1,0;E.treeRects={};local endY=0
  for i=1,32 do local e=E.filtered[E.techPage*32+i]
   if e then if last~=e.row.LevelCap or col>=7 then row=row+1;col=0;last=e.row.LevelCap end
    local xx,yy=12+col*30,6+row*32;col=col+1;endY=yy+28;E.treeRects[i]={x=xx-117,y=yy-52,w=26,h=26,e=e}
    for prefix,p in pairs({TechFrame={0,0,26,26},TechIcon={5,5,16,16},TechCost={12,19,13,8}})do local n=ns[prefix..i];n.Slot:SetPosition({X=(xx+p[1])*unit,Y=(yy+p[2])*unit});n.Slot:SetSize({X=p[3]*unit,Y=p[4]*unit});n.Slot:SetZOrder(prefix=='TechFrame'and 2 or 3);n:SetVisibility(prefix=='TechIcon'and not valid(n.Brush.ResourceObject)and 1 or 3)end
   end
  end
  if valid(U.techSize)then U.techSize:SetHeightOverride(math.max(113,endY+6)*unit)end
  for i=1,32 do local r=E.treeRects[i];local n=ns['Tech46Line'..i]
   if not valid(n)then n=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.Image'),U.techCanvas:GetOuter());U.techCanvas:AddChildToCanvas(n);ns['Tech46Line'..i]=n end
   if r then self:fill(n,'AAAAAA');n.Slot:SetPosition({X=5*unit,Y=(r.y+52+12)*unit});n.Slot:SetSize({X=(r.x+117-5)*unit,Y=unit});n.Slot:SetZOrder(0);n:SetVisibility(3)else n:SetVisibility(1)end
  end
  local trunk=ns.Tech46Trunk;if not valid(trunk)then trunk=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.Image'),U.techCanvas:GetOuter());U.techCanvas:AddChildToCanvas(trunk);ns.Tech46Trunk=trunk end
  self:fill(trunk,'AAAAAA');trunk.Slot:SetPosition({X=5*unit,Y=18*unit});trunk.Slot:SetSize({X=unit,Y=math.max(1,endY-32)*unit});trunk.Slot:SetZOrder(0);trunk:SetVisibility(3)
  self.techRects46=E.treeRects
 end
 function U:dexWork46(ns,env,F,r,works)
  local _,unit=self:metrics(env);F.workRects46={}
  for i=1,6 do local w=(F.workRows46 or{})[i];local image=self:makeNode(ns,'Dex46WorkIcon'..i,'Image');local text=self:makeNode(ns,'Dex46WorkText'..i,'TextBlock');image:SetVisibility(w and 3 or 1);text:SetVisibility(w and 3 or 1)
   if w then local x,y=196+(i-1)%3*16,46+math.floor((i-1)/3)*22;self:icon(image,U.items:icon(self:workIcon46(w.id)),12,1);self:position(image,x-128,y-100,12,12,unit);image.Slot:SetZOrder(42);self:textStyle(text,unit,true);self:putText(text,w.rank);self:position(text,x-128,y+12-100,12,9,unit);text.Slot:SetZOrder(42);F.workRects46[i]={x=x-128,y=y-100,w=12,h=20,label=w.name,rank=w.rank}end
  end
  local label=ns.Description;self:textStyle(label,unit,true);local font=label.Font;font.Size=self:fontSize(6,unit);label:SetFont(font);self:position(label,124-128,101-100,124,50,unit)
  for i=1,14 do local row=F.filtered[F.page*14+i];if row then self:putText(ns['DexLabel'..i],self:trimLabel('#'..row.number..' '..(row.detail>=2 and row.label or'???'),98))end end
 end
 function U:workIcon46(id)
  return ({'MC_Torch','MC_Water','MC_WheatSeeds','MC_CraftingTable','MC_Wheat','MC_IronAxe','MC_IronPickaxe','MC_Bread','MC_RedWool','MC_Ice','MC_Chest','MC_GrassBlock','MC_Stone'})[id]or'MC_IronPickaxe'
 end
 function U:pcDetails(ns,env,p)
  local v=self:view(ns,env,292,200);v:image(40,8,162,14,'T_MC_UI_widget_text_field');ns.BoxTitle.Slot:SetZOrder(40);ns.Title:SetVisibility(1);ns.HP:SetRenderOpacity(0)
  if not p then v:finish();return end
  local elements=p.elements or{};local id=elements[1]and elements[1].id or 1;local color=({'555555','AA0000','0000AA','00AA00','AAAA00','00AAAA','AA5500','550055','AA00AA'})[id]or'555555';self:fill(ns.GuiHeader,color)
  self:putText(ns.Name,self:trimLabel(p.name,68));self:position(ns.Name,204-146,80-100,68,10,v.unit);self:setMeta(ns.Name,{dark=false});self:textStyle(ns.Name,v.unit,false)
  self:position(ns.Level,204-146,100-100,82,10,v.unit);self:setMeta(ns.Level,{dark=true});self:textStyle(ns.Level,v.unit,true)
  ns.Types:SetVisibility(1);for i,e in ipairs(elements)do v:pill(e.label,e.id,204+(i-1)*40,118,38)end
  v:bar(208,148,74,5,p.d:GetHP().Value/math.max(1000,p.d:GetMaxHP()*1000));self:putText(ns.HPText,string.format('HP %.0f/%d',p.d:GetHP().Value/1000,p.d:GetMaxHP()));self:position(ns.HPText,208-146,136-100,74,10,v.unit);self:setMeta(ns.HPText,{dark=true});self:textStyle(ns.HPText,v.unit,true)
  v:text('Attack '..p.d:GetShotAttack(),204,157,82,10);v:text('Defense '..p.d:GetDefense(),204,168,82,10)
  v:text(p.d:GetGenderType()==1 and'♂'or p.d:GetGenderType()==2 and'♀'or'',274,80,10,10,p.d:GetGenderType()==1 and{R=.333,G=.333,B=1,A=1}or{R=1,G=.333,B=1,A=1},false);v:finish()
 end
 local details=U.palDetails
 function U:palDetails(ns,env,d,name,tab,skills,works,passives,types)
  local v=details(self,ns,env,d,name,tab,skills,works,passives,types)
  self:putText(ns.Name,self:trimLabel(name,122));self:position(ns.Name,86-124,19-90,122,10,v.unit)
  for i=1,5 do local n=ns['PalName'..i];local s=UE.GetKismetTextLibrary():Conv_TextToString(n:GetText());s=type(s)=='string'and s or s:ToString();self:putText(n,self:trimLabel(s,44))end
  self:position(ns.Level,88-124,92-90,150,10,v.unit)
  return v
 end
 local map=U.mapInput
 function U:mapInput(name,x,y)
  if name=='WBP_MCTechnology'then
   if y/3>=70 and y/3<80 then if x/3>=99 and x/3<109 then return 420,-190,'Prev'elseif x/3>=111 and x/3<121 then return 490,-190,'Next'end end
   if self.techRects46 then for i,r in pairs(self.techRects46)do if x/3>=r.x and x/3<r.x+r.w and y/3>=r.y and y/3<r.y+r.h then return -530+(i-1)%9*118+20,-150+math.floor((i-1)/9)*88+20,'TechFrame'..i end end end
   if x/3>=-117 and x/3<117 and y/3>=-52 and y/3<61 then return -99999,-99999 end
  end
  return map(self,name,x,y)
 end
 local clean=U.cleanDescription
 function U:cleanDescription(raw,env)return clean(self,tostring(raw or''):gsub('Native Palworld behavior%.',''):gsub('%s+$',''),env)end
 local apply=U.apply
 function U:apply(widget,name,env)
  local factor,unit=apply(self,widget,name,env);local ns=ctx.widgets(widget);self.env=env
  local kind=({WBP_MCPals='Pals',WBP_MCPC='PC',WBP_MCTechnology='Technology',WBP_MCPalpedia='Palpedia'})[name]
  
  if kind=='Technology'then self:position(ns.Points,-8,-64,124,10,unit);self:position(ns.Prev,99,70,10,10,unit);self:position(ns.Next,111,70,10,10,unit);ns.Band:SetVisibility(1);for _,k in ipairs({'Prev','Next'})do self:setMeta(ns[k],{dark=false});self:textStyle(ns[k],unit,false)end end
  if kind=='PC'then ns.Title:SetVisibility(1)end
  if name=='WBP_MCGameMenu'then self:putText(ns.Title,'Game Menu');self:textStyle(ns.Title,unit,false);for i,b in pairs(self.gameButtons)do self:putText(ns['Label'..i],({[2]='Skins...',[1]='Back to Game',[4]='Technology',[9]='Palpedia',[3]='Pals',[6]='Pal Box',[7]='Options...',[5]='Map',[8]='Save and Quit to Title'})[i]);ns['Label'..i]:SetClipping(1)end end
  return factor,unit
 end
 dofile(ctx.base..'/timers.lua').onEpoch('ui46',function()U.techCanvas,U.techSize,U.techRects46=nil,nil,nil end)
end
