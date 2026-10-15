-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U)
 local UE,valid=ctx.UE,ctx.valid
 local function str(v)return type(v)=='string'and v or v:ToString()end
 local function label(ns,n,s,x,y,w,h,unit,dark)
  U:putText(ns[n],s);U:position(ns[n],x,y,w,h,unit);U:setMeta(ns[n],{dark=dark~=false});U:textStyle(ns[n],unit,dark~=false);ns[n]:SetClipping(1)
 end
 function U:palDetails(ns,env,d,name,tab,skills,works,passives,types)
  local v=self:view(ns,env,248,180);local unit=v.unit;ns.pal54Rects={}
  for _,k in ipairs({'Stats','Condition','Passive','Skills','Work','Elements','Exp'})do ns[k]:SetVisibility(1)end
  label(ns,'Name',self:trimLabel(name,110),-36,-73,110,13,unit,false)
  label(ns,'Level','Lv '..d:GetLevel(),78,-73,40,13,unit,false)
  ns.Level:SetJustification(2)
  self:fill(ns.GuiHeader,'333333');self:position(ns.Portrait,-34,-58,60,60,unit);ns.Portrait.Slot:SetZOrder(35)
  v:image(87,31,62,64,'T_MC_UI_slot');v:image(88,32,60,62,nil,{fill='000000'})
  for i,e in ipairs(types)do v:pill(e.label,e.element,154+(i-1)*44,32,#types>1 and 42 or 86)end
  local hp,max=d:GetHP().Value/1000,math.max(1,d:GetMaxHP())
  local sy=50
  v:text('HP '..math.floor(hp)..' / '..max,154,sy,86,9);v:bar(154,sy+11,86,4,hp/max)
  v:text('Attack '..d:GetShotAttack(),154,sy+20,86,9);v:text('Defense '..d:GetDefense(),154,sy+31,86,9)
  local db=UE.Object('/Script/Pal.Default__PalUtility'):GetExpDatabase(env.player);local lv=d:GetLevel();local low,high=db:GetTotalExp(lv,false),db:GetTotalExp(lv+1,false)
  v:bar(88,106,152,3,(d:GetExp()-low)/math.max(1,high-low),'55FF55')
  v:text('EXP '..(d:GetExp()-low)..' / '..math.max(1,high-low),88,97,152,8)
  self:position(ns.Button1,-118,66,44,20,unit);label(ns,'Label1','Summon',-116,72,40,10,unit,false);ns.Label1:SetJustification(1)
  self:position(ns.Button4,-72,66,28,20,unit);label(ns,'Label4','Done',-70,72,24,10,unit,false);ns.Label4:SetJustification(1)
  for i,s in ipairs({'Info','Moves','Stats'})do label(ns,'GuiTabLabel'..i,s,-36+(i-1)*52,23,50,10,unit,false)end
  if tab==1 then
   v:text('Hunger',88,127,45,10);v:bar(133,129,107,5,d:GetFullStomachRate(),'AA5500')
   v:text('Sanity',88,139,45,10);v:bar(133,141,107,5,d:GetSanityRate(),'AA00AA')
   local health=d:GetPhysicalHealth();if health~=0 then v:text(({'Minor injury','Severe injury','Dying','Dead','Cloud cemetery'})[health]or'Healthy',88,150,152,10)end
  elseif tab==2 then
   for i,s in ipairs(skills)do if i>3 then break end;local y=127+(i-1)*14;v:image(88,y,152,13,nil,{fill='555555'});v:text(self:trimLabel(s.name,111),91,y+1,111,12,nil,false);v:text(s.power,204,y+1,32,12,{R=1,G=1,B=.333,A=1},false):SetJustification(2);ns.pal54Rects[#ns.pal54Rects+1]={x=-36,y=y-90,w=152,h=13,title=s.name,lines={s.elementLabel,'Power '..s.power}}end
  else
   v:text('Work speed '..d:GetCraftSpeed(),88,127,152,12)
  end
  
  if tab~=2 then for i,s in ipairs(passives)do if i>4 then break end;local x,y=88+(i-1)%2*77,156+math.floor((i-1)/2)*15;v:image(x,y,75,14,nil,{fill='555555'});v:text(self:trimLabel(s,69),x+3,y+1,69,12,{R=1,G=.667,B=0,A=1},false);ns.pal54Rects[#ns.pal54Rects+1]={x=x-124,y=y-90,w=75,h=14,title=s,lines={'Passive skill'}}end end
  for i,w in ipairs(works)do if i>8 then break end;local x,y=88+(i-1)%8*19,190;v:image(x,y,12,12,self.items:icon(self:workIcon46(w.id)));v:text(w.rank,x+10,y+3,8,12,nil,false);ns.pal54Rects[#ns.pal54Rects+1]={x=x-124,y=y-90,w=18,h=16,title=w.name,lines={'Suitability Lv '..w.rank}}end
  local slots={};_G.MC_OUT_K('GetSlots',env.controller.BP_OtomoPalHolderComponent,slots)
  for i=1,5 do local s=slots[i];pcall(function()s=s:get()end);local p=valid(s)and s.ReplicateIndividualParameter;ns['PalHP'..i]:SetVisibility(1)
   if valid(p)then local y=17+(i-1)*28;local raw=UE.GetKismetTextLibrary():Conv_TextToString(ns['PalName'..i]:GetText());raw=type(raw)=='string'and raw or raw:ToString();label(ns,'PalName'..i,self:trimLabel(raw,43),-90,y-88,43,10,unit,false);v:text('Lv '..p:GetLevel(),34,y+12,42,9,nil,false);v:bar(34,y+22,44,3,p:GetHP().Value/(1000*math.max(1,p:GetMaxHP())))end
  end
  self:panel58(ns,248,208,unit);v:finish();return v
 end
 local oldMap=U.mapInput
 function U:mapInput(name,x,y)
  if name=='WBP_MCPals'then local xx,yy=x/3+124,y/3+90
   if yy>=156 and yy<176 then if xx>=6 and xx<50 then return -450,300,'Button1'elseif xx>=52 and xx<80 then return 440,375,'Button4'elseif xx>=168 and xx<242 then return -99999,-99999 end end
  end
  return oldMap(self,name,x,y)
 end
 local oldPC=U.pcDetails
 function U:controls54(ns,env,mode,x,y,D)
  local _,unit=self:metrics(env);local down=env.controller:IsInputKeyDown({KeyName=UE.FindOrAddFName('LeftMouseButton')});local tip
  local function button(key,rect,title,selected,enabled,existing)
   local inside=x>=rect[1]and x<rect[1]+rect[3]and y>=rect[2]and y<rect[2]+rect[4]
   local n=existing or self:makeNode(ns,key,'Image');self:brush(n,(enabled==false or selected or(inside and down))and'T_MC_UI_widget_button_disabled'or inside and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button')
   if not existing then self:position(n,rect[1],rect[2],rect[3],rect[4],unit);n.Slot:SetZOrder(38)end
   if inside then tip={title=title,source='Palworld',lines=enabled==false and{'Unavailable'}or{},exclude={x=rect[1],y=rect[2],w=rect[3],h=rect[4]}}end
  end
  if mode=='Pals'then
   button('Pal54Summon',{-118,66,44,20},'Summon selected Pal',false,true,ns.Button1);button('Pal54Done',{-72,66,28,20},'Close summary',false,true,ns.Button4)
  elseif mode=='PC'then
   local E=D.extra;button('PC54Prev',{-120,-93,12,17},'Previous box',false,E.page>0);button('PC54Next',{58,-93,12,17},'Next box',false,E.page<(E.pcPages54 or 32)-1)
   for _,k in ipairs({'Prev','Next'})do ns[k].Slot:SetZOrder(43);self:textStyle(ns[k],unit,false)end
  elseif mode=='Technology'then
   local E=D.extra
   for i=1,10 do button('Tech54Tab'..i,{-117+(i-1)*23,-70,22,18},i==10 and'Ancient technology'or('Levels '..((i-1)*10+1)..' - '..i*10),i==E.band,true,ns['TabFrame'..i])end
   button('Tech54Prev',{99,70,10,10},'Previous page',false,E.techPage>0);button('Tech54Next',{111,70,10,10},'Next page',false,E.techPage<math.ceil(#E.filtered/32)-1)
   for _,k in ipairs({'Prev','Next'})do ns[k].Slot:SetZOrder(43)end
  elseif mode=='Palpedia'then
   local F=D.features;button('Dex54Prev',{-122,89,12,10},'Previous page',false,F.page>0);button('Dex54Next',{-23,89,12,10},'Next page',false,F.page<math.ceil(#F.filtered/14)-1)
   for _,k in ipairs({'Prev','Next'})do ns[k].Slot:SetZOrder(43);self:textStyle(ns[k],unit,false)end
  end
  return tip
 end
 function U:pcDetails(ns,env,p)
  oldPC(self,ns,env,p);local _,unit=self:metrics(env)
  label(ns,'PartyTitle','Pal',-138,-85,18,10,unit,true)
  self:putText(ns.BoxTitle,self:trimLabel(str(UE.GetKismetTextLibrary():Conv_TextToString(ns.BoxTitle:GetText())),144));self:position(ns.BoxTitle,-102,-90,154,10,unit);ns.BoxTitle:SetJustification(1)
  self:fill(ns.GuiHeader,'333333');self:position(ns.Portrait,72,-74,48,48,unit);self:position(ns.Name,58,-20,76,10,unit)
  self:fill(ns.GuiWell,'777777');self:position(ns.GuiWell,72,-74,48,48,unit)
  for _,key in ipairs({'Prev','Next'})do local n=ns[key];self:textStyle(n,unit,true);n:SetClipping(1)end
 end
 local oldTree=U.techTree
 function U:pcSelection54(ns,env,s)
  local _,unit=self:metrics(env);local x,y
  if s then x=s.party and-139 or(-106+s.index%6*26);y=-74+(s.party and s.index*28 or math.floor(s.index%30/6)*26)end
  for i,p in ipairs({{0,0,26,1},{0,25,26,1},{0,0,1,26},{25,0,1,26}})do local n=self:makeNode(ns,'PC54Selected'..i,'Image');n:SetVisibility(s and 3 or 1);if s then self:fill(n,'FFFFFF');self:position(n,x+p[1],y+p[2],p[3],p[4],unit);n.Slot:SetZOrder(43)end end
 end
 function U:techTree(ns,env,E)
  oldTree(self,ns,env,E);local _,unit=self:metrics(env)
  for i=1,10 do
   local n=ns['TabLabel'..i];local selected=i==E.band;self:putText(n,i==10 and'Anc.'or((i-1)*10+1)..'+');self:position(n,-116+(i-1)*23,-66,20,10,unit);self:textStyle(n,unit,not selected);n.Slot:SetZOrder(45);n:SetVisibility(3);n:SetJustification(1)
   self:brush(ns['TabFrame'..i],selected and'T_MC_UI_widget_button_disabled'or'T_MC_UI_widget_button')
   self:position(ns['TabFrame'..i],-117+(i-1)*23,-70,22,18,unit)
  end
  for i=1,32 do if valid(ns['Ui20Image'..i])then ns['Ui20Image'..i]:SetVisibility(1)end end
  local row,col,last=-1,0,nil;local endY=113
  local colors={'AAAAAA','55FF55','55FFFF','5555FF','FF55FF','FFFF55','FFAA00','FF5555','FFFFFF','AA00AA'}
  local function owned(key,kind)
   local n=self:makeNode(ns,key,kind)
   if n:GetParent():GetAddress()~=U.techCanvas:GetAddress()then n:RemoveFromParent();U.techCanvas:AddChildToCanvas(n);n.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=0,Y=0}})end
   return n
  end
  for i,r in ipairs(E.treeRects or{})do
   local heading=last~=r.e.row.LevelCap or col>=7
   if heading then row=row+1;col=0;last=r.e.row.LevelCap end
   local x,y=12+col*30,16+row*42;col=col+1;r.x,r.y=x-117,y-52;endY=y+32
   for prefix,p in pairs({TechFrame={0,0,26,26},TechIcon={5,5,16,16},TechCost={18,17,9,9}})do local n=ns[prefix..i];n.Slot:SetPosition({X=(x+p[1])*unit,Y=(y+p[2])*unit});n.Slot:SetSize({X=p[3]*unit,Y=p[4]*unit})end
   ns['TechCost'..i]:SetJustification(2)
   local title=owned('Tech54Tier'..i,'TextBlock');self:putText(title,'Level '..r.e.row.LevelCap);self:textStyle(title,unit,false);title.Slot:SetPosition({X=5*unit,Y=(y-12)*unit});title.Slot:SetSize({X=118*unit,Y=10*unit});title.Slot:SetZOrder(4);title:SetVisibility(heading and 3 or 1)
   local tier=owned('Tech54Color'..i,'Image');self:fill(tier,colors[r.e.band]or'AAAAAA');tier.Slot:SetPosition({X=x*unit,Y=y*unit});tier.Slot:SetSize({X=26*unit,Y=unit});tier.Slot:SetZOrder(4);tier:SetVisibility(3)
   local line=ns['Tech46Line'..i];line.Slot:SetPosition({X=5*unit,Y=(y+12)*unit});line.Slot:SetSize({X=(x-5)*unit,Y=unit})
  end
  for i=#(E.treeRects or{})+1,32 do for _,prefix in ipairs({'Tech54Tier','Tech54Color'})do if valid(ns[prefix..i])then ns[prefix..i]:SetVisibility(1)end end end
  ns.Tech46Trunk.Slot:SetPosition({X=5*unit,Y=28*unit});ns.Tech46Trunk.Slot:SetSize({X=unit,Y=math.max(1,endY-48)*unit})
  U.techSize:SetHeightOverride(math.max(113,endY)*unit);U.techRects46=E.treeRects
 end
 function U:dex54Filter(ns,env,F)
  local _,unit=self:metrics(env);local n=self:makeNode(ns,'Dex54Filter','Image');local t=self:makeNode(ns,'Dex54FilterText','TextBlock')
  self:brush(n,'T_MC_UI_widget_button');self:position(n,-48,-95,44,12,unit);n.Slot:SetZOrder(42)
  self:putText(t,F.dexFilter54 or'All');self:position(t,-46,-93,40,9,unit);self:textStyle(t,unit,false);t:SetJustification(1);t.Slot:SetZOrder(43);self:position(ns.Title,-122,-94,72,10,unit)
 end
 local oldDex=U.dexWork46
 function U:dexWork46(ns,env,F,r,works)
  oldDex(self,ns,env,F,r,works);local _,unit=self:metrics(env);self:dex54Filter(ns,env,F)
  ns.Description:SetVisibility(1);ns.Work:SetVisibility(1)
  self:fill(ns.GuiWell,'777777')
  label(ns,'Selected',self:trimLabel('#'..r.number..' '..(r.detail>=2 and r.label or'???'),120),-4,-12,124,10,unit,false)
  ns.Search:SetHintText(UE.GetKismetTextLibrary():Conv_StringToText(''))
  ns.Search:SetVisibility(0)
  local hint=self:makeNode(ns,'Dex54Hint','TextBlock');self:putText(hint,'Name / number');self:position(hint,3,-93,112,10,unit);self:textStyle(hint,unit,false,{R=.667,G=.667,B=.667,A=1});hint.Slot:SetZOrder(43)
  if not valid(ns.Dex54Scroll)then
   local root=ns.CanvasPanel_0;local function make(k)return UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.'..k),root:GetOuter())end
   local scroll=make('ScrollBox');root:AddChildToCanvas(scroll);scroll:SetClipping(1);scroll.bAllowRightClickDragScrolling=true;scroll.Slot:SetZOrder(42)
   local size=make('SizeBox');scroll:AddChild(size);local text=make('TextBlock');size:AddChild(text);text:SetVisibility(3)
   ns.Dex54Scroll,ns.Dex54Size,ns.Dex54Text=scroll,size,text
  end
  self:position(ns.Dex54Scroll,-4,1,124,50,unit);ns.Dex54Scroll:SetVisibility(0);ns.Dex54Size:SetWidthOverride(120*unit)
  local description=F.description54 or(r.detail<2 and'Not encountered'or'');local lines=self:wrap46(description,118,100);self:putText(ns.Dex54Text,table.concat(lines,'\n'));self:textStyle(ns.Dex54Text,unit,true);ns.Dex54Size:SetHeightOverride(math.max(50,#lines*10)*unit);ns.Dex54Scroll:SetScrollOffset(0)
 end
end
