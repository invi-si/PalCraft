-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U,paths)
 local valid,UE,log=ctx.valid,ctx.UE,ctx.log;local design=dofile(ctx.base..'/ui_design.lua');local meta={};local identities={};local mids={};local textureKinds={};local retainers={};local quest
 local function identity(o)return {object=o,class=o:GetClass():GetAddress(),name=o:GetFName():ToString()}end
 local function same(r,o)return r and valid(r.object)and valid(o)and o:GetClass():GetAddress()==r.class and o:GetFName():ToString()==r.name end
 function U:setMeta(n,p)local a=n:GetAddress();meta[a]=p;identities[a]=identity(n)end
 local function metadata(n)local a=n:GetAddress();if same(identities[a],n)then return meta[a]end end
 dofile(ctx.base..'/ui20_details.lua')(ctx,U,meta)
 for name,layout in pairs(design.layouts)do paths[name]=layout end
 function U:mapInput(name,x,y)
  for _,r in ipairs(design.hitMaps[name]or{})do local p=r.new
   if x>=p[1]and x<p[1]+p[3]and y>=p[2]and y<p[2]+p[4]then local old=r.old;return old[1]+old[3]/2,old[2]+old[4]/2,r.key end
  end
  return -99999,-99999
 end
 function U:panTechnology(ns,entries,page,dx,dy,unit)
  local layout=design.layouts.WBP_MCTechnology;local shown=0
  for i=1,32 do
   local p=layout['TechFrame'..i];local x,y=p.position[1]/3+dx,p.position[2]/3+dy
   local show=entries[page*32+i]and x>=-117 and x+26<=117 and y>=-52 and y+26<=61
   if show then shown=shown+1 end
   for _,prefix in ipairs({'TechFrame','TechIcon','TechCost'})do
    local n=ns[prefix..i];local geometry=layout[prefix..i]
    if valid(n)then
     self:position(n,geometry.position[1]/3+dx,geometry.position[2]/3+dy,geometry.size[1]/3,geometry.size[2]/3,unit)
     n:SetVisibility(show and(prefix~='TechIcon'or n.Brush.ResourceObject and valid(n.Brush.ResourceObject))and 3 or 1)
    end
   end
  end;return shown
 end
 function U:technologyScroll(ns,env,unit)
  if valid(ns.techScroll54)and ns.techUnit54==unit then U.techCanvas=ns.techCanvas54;U.techSize=ns.techSize54;return ns.techScroll54,unit end
  assert(type(unit)=='number'and unit>0,'Technology scroll needs menu scale');local root=ns.CanvasPanel_0
  local function create(name)return UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.'..name),root:GetOuter())end
  local scroll=create('ScrollBox');assert(valid(scroll));root:AddChildToCanvas(scroll);self:position(scroll,-117,-52,234,113,unit)
  scroll.Slot:SetZOrder(25);scroll:SetVisibility(0);scroll:SetClipping(1);scroll.bAllowRightClickDragScrolling=true
  local size=create('SizeBox');assert(valid(size));scroll:AddChild(size);size:SetWidthOverride(234*unit);size:SetHeightOverride(180*unit)
  local canvas=create('CanvasPanel');assert(valid(canvas));size:AddChild(canvas);canvas:SetVisibility(4)
  local layout=design.layouts.WBP_MCTechnology
  for i=1,32 do for _,prefix in ipairs({'TechFrame','TechIcon','TechCost'})do
   local key=prefix..i;local n=ns[key];local p=layout[key];n:RemoveFromParent();canvas:AddChildToCanvas(n)
   n.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=0,Y=0}})
   n.Slot:SetPosition({X=(p.position[1]/3+117)*unit,Y=(p.position[2]/3+52)*unit});n.Slot:SetSize({X=p.size[1]/3*unit,Y=p.size[2]/3*unit})
   n.Slot:SetZOrder(prefix=='TechFrame'and 0 or 1)
  end end
  U.techCanvas=canvas;U.techSize=size;ns.techScroll54=scroll;ns.techCanvas54=canvas;ns.techSize54=size;ns.techUnit54=unit;return scroll,unit
 end
 function U:icon(n,t,cells,outline,gain)
  if not valid(n)or not valid(t)then return end
  local a=t:GetAddress();local info=textureKinds[a];if not same(info,t)then assert(t:IsA(UE.Object('/Script/Engine.Texture')),'UI pixel input is not a texture: '..t:GetFullName());info=identity(t);info.own=(UE.texRuntime and UE.texRuntime:isTexture(t))or t:GetFullName():find('/Game/MinecraftBlocks/',1,true)~=nil or t:GetFullName():find('/Game/MinecraftRideables106/',1,true)~=nil or t:GetFullName():find('/Game/MinecraftHostiles107/',1,true)~=nil;textureKinds[a]=info end;local own=info.own
  if own then self:retainTexture(t);n:SetBrushFromTexture(t,false);n:SetColorAndOpacity({R=1,G=1,B=1,A=1});return end
  local m=metadata(n)or{};cells=cells or m.cells or 16;if outline==nil then outline=m.outline==nil and 1 or m.outline end
  gain=gain or 1;local key=t:GetAddress()..':'..info.name..':'..cells..':'..outline..':'..gain;local entry=mids[key];local mid=entry and entry.object;local reusable=same(entry,mid)
  if not reusable then
   assert(valid(self.iconCacheRoot),'Pixel cache needs persistent HUD canvas');local holder=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.Image'),self.iconCacheRoot:GetOuter());assert(valid(holder),'Pixel cache retainer missing');self.iconCacheRoot:AddChildToCanvas(holder);holder.Slot:SetSize({X=1,Y=1});holder:SetVisibility(3);holder:SetRenderOpacity(0);retainers[#retainers+1]=holder
   holder:SetBrushFromMaterial(self:asset('M_MC_UIPixel'));mid=holder:GetDynamicMaterial();assert(valid(mid),'No UI pixel material');mid:SetTextureParameterValue(UE.FindOrAddFName('Icon'),t);mid:SetScalarParameterValue(UE.FindOrAddFName('Cells'),cells);mid:SetScalarParameterValue(UE.FindOrAddFName('Outline'),outline);mid:SetScalarParameterValue(UE.FindOrAddFName('Gain'),gain);mids[key]=identity(mid);log('MC_20_PIXEL_ICON cells='..cells..' gain='..gain..' texture='..t:GetFullName())
  end
  n:SetBrushFromMaterial(mid);n:SetColorAndOpacity({R=1,G=1,B=1,A=1})
 end
 local style=U.textStyle
 function U:fontSize(points,unit)return math.max(1,math.floor(points*unit*(ctx.config.pixel_font_verified and 1 or .75)+.5))end
 function U:textStyle(n,unit,dark,color)
  if not valid(n)then return end;local p=metadata(n);if p and p.dark~=nil then dark=p.dark end
  local font=self:pixelFont53();self.font=font;self.fontChecked=true;self.nativeTypeface='Regular'
  style(self,n,unit,dark,color);local f=n.Font;f.FontObject=font;f.TypefaceFontName=UE.FindOrAddFName('Regular')
  n:SetFont(f);n:SetClipping(1)
 end
 function U:fill(n,hex,alpha)
  self:brush(n,'T_MC_UI_white');local function component(i)local c=tonumber(hex:sub(i,i+1),16)/255;return c<=.04045 and c/12.92 or((c+.055)/1.055)^2.4 end
  local c={R=component(1),G=component(3),B=component(5),A=alpha or 1};if n:IsA(UE.Object('/Script/UMG.Image'))then n:SetColorAndOpacity(c)else n:SetBrushColor(c)end
 end
 function U:quests(ns,env,show)
  if self.nativeHud then return end
  for _,k in ipairs({'GuiHeader','GuiList','GuiTooltipName','GuiTooltipDetail','GuiTooltipSource','GuiHint','GuiTabLabel1','GuiTabLabel2','GuiTabLabel3'})do ns[k]:SetVisibility(1)end
  for i=1,6 do ns['GuiQuest'..i]:SetVisibility(1)end
 end
 local sourceKinds={
  WBP_Ingame_Interact_C='action',WBP_PalInteractiveObjectIndicatorUI_C='hide',
  WBP_PalCraftInfo_C='hide',WBP_InGame_Quest_StartClear_Main_C='toast',
  WBP_InGame_Quest_StartClear_Sub_C='toast',WBP_Notice_C='toast',WBP_NoticeLog_C='toast',
  WBP_PalLogWidget_C='toast'
 }
 local sourceClasses={};for name in pairs(sourceKinds)do sourceClasses[#sourceClasses+1]=name end;table.sort(sourceClasses)
 local function nativeString(t)return type(t)=='string'and t or t:ToString()end
 local function nativeWidget(n)return valid(n)and n:IsA(UE.Object('/Script/UMG.Widget'))end
 local function nativeText(r)return r and same(r.identity,r.node)and(r.node:IsA(UE.Object('/Script/UMG.TextBlock'))or r.node:IsA(UE.Object('/Script/UMG.RichTextBlock')))end
 local function sourceParent(n)
  if not nativeWidget(n)then return end
  local p=n:GetParent();if valid(p)then return p end
  local outer=n:GetOuter();if valid(outer)and outer:IsA(UE.Object('/Script/UMG.WidgetTree'))then p=outer:GetOuter();if valid(p)and p:IsA(UE.Object('/Script/UMG.Widget'))and p:GetAddress()~=n:GetAddress()then return p end end
 end
 local function sourceActive(r)
  if not same(r.identity,r.node)or not nativeWidget(r.node)then return false end
  for _,entry in ipairs(r.parents or{})do local node=entry.object;if not same(entry,node)or not nativeWidget(node)then return false end;local v=node:GetVisibility();if v==1 or v==2 then return false end end
  return true
 end
 function U:noticeSource(w,kind,env)
  if not nativeWidget(w)or not w:IsA(UE.Object('/Script/UMG.UserWidget'))then return end
  local tree=w.WidgetTree;if not valid(tree)or not tree:IsA(UE.Object('/Script/UMG.WidgetTree'))or not nativeWidget(tree.RootWidget)then return end
  local texts,seen={},{}
  local function walk(node,key,depth)
   if depth>5 or not nativeWidget(node)or seen[node:GetAddress()]then return end;seen[node:GetAddress()]=true
   if node:IsA(UE.Object('/Script/UMG.TextBlock'))or node:IsA(UE.Object('/Script/UMG.RichTextBlock'))then texts[#texts+1]={node=node,key=key,identity=identity(node)};return end
   if node:IsA(UE.Object('/Script/UMG.UserWidget'))then
    local t=node.WidgetTree;if valid(t)and t:IsA(UE.Object('/Script/UMG.WidgetTree'))and nativeWidget(t.RootWidget)then for k,n in pairs(ctx.widgets(node))do if k==k:lower()then walk(n,k,depth+1)end end end
   elseif node:IsA(UE.Object('/Script/UMG.PanelWidget'))then for i=0,math.min(node:GetChildrenCount()-1,15)do walk(node:GetChildAt(i),key..':'..i,depth+1)end end
  end
  if kind~='hide'then walk(w,'root',0)end;table.sort(texts,function(a,b)return a.key<b.key end)
  local parent=w:GetParent();for _=1,8 do if not nativeWidget(parent)then break end;if parent:GetFullName():lower():find('important',1,true)then kind='title';break end;parent=parent:GetParent()end
  local widgets=ctx.widgets(w);local row={node=w,identity=identity(w),kind=kind,texts=texts,guide=widgets.keyguide,signature='',path=w:GetFullName(),dirty=true,parents={identity(w)}}
  if nativeWidget(row.guide)then row.guideIdentity=identity(row.guide)end
  local parent=sourceParent(w);for _=1,8 do if not nativeWidget(parent)then break end;row.parents[#row.parents+1]=identity(parent);parent=sourceParent(parent)end
  if kind=='action'then
   for _,t in ipairs(texts)do if nativeText(t)and not t.key:lower():find('keyguide',1,true)and t.node:GetVisibility()~=1 and t.node:GetVisibility()~=2 then row.prompt=t;break end end
  end
  return row
 end
 function U:nativePromptKey(r,env)
  if r.key then return r.key end;local guide=r.guide;if not same(r.guideIdentity,guide)or not nativeWidget(guide)then return ''end
   if guide:IsA(UE.Object('/Script/UMG.UserWidget'))then local tree=guide.WidgetTree;if not valid(tree)or not tree:IsA(UE.Object('/Script/UMG.WidgetTree'))or not nativeWidget(tree.RootWidget)then return ''end;local nodes=ctx.widgets(guide);guide=nodes.paluiactionwidgetbase_24 or guide end
  if valid(StaticFindObject('/Script/CommonUI.CommonActionWidget:GetIcon'))and guide:IsA(UE.Object('/Script/CommonUI.CommonActionWidget'))then
   local brush=guide:GetIcon();local texture=brush.ResourceObject
   if valid(texture)then local path=texture:GetFullName();r.key_texture=path;local key=path:match('_([A-Z0-9]+)%.');if key then r.key=key;return key end end
  end
  return ''
 end
 function U:nativePickup(env,id,count)
  local h=self.nativeHud;if not h then return end
  local out={};_G.MC_OUT_K('GetItemName',UE.Object('/Script/Pal.Default__PalUIUtility'),env.player,UE.FindOrAddFName(id),out)
  local name=out.outName and nativeString(UE.GetKismetTextLibrary():Conv_TextToString(out.outName))or id
  h.toast={title=name,subtitle='+'..count,time=UE.Object('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(env.player),item=id}
  log('MC21_HUD_TOAST_NATIVE id='..id..' count='..count..' native_inventory_delta=true')
 end
 function U:notify(title,subtitle)
  self.pendingToasts=self.pendingToasts or{}
  if UE.language57 then title=UE.language57:t(title);subtitle=UE.language57:t(subtitle)end
  log('MCAC_NOTICE_UTF8 title='..tostring(title)..' subtitle='..tostring(subtitle))
  if #self.pendingToasts<16 then self.pendingToasts[#self.pendingToasts+1]={title=title,subtitle=subtitle}end
 end
 function U:toastTexture(env)
  if valid(self.nativeToastTexture)then return self.nativeToastTexture end
  if self.nativeToastUnavailable then return nil end
  if not valid(StaticFindObject('/Script/Engine.KismetRenderingLibrary:ImportFileAsTexture2D'))then self.nativeToastUnavailable=true;log('MC21_TOAST_SPRITE_UNAVAILABLE');return nil end
  local path=ctx.base..'/task22-owned-jar-toast.png';local f=assert(io.open(path,'wb'));f:write('\137\080\078\071\013\010\026\010\000\000\000\013\073\072\068\082\000\000\000\160\000\000\000\032\002\003\000\000\000\232\017\155\102\000\000\000\012\080\076\084\069\000\000\000\000\000\000\085\085\085\033\033\033\156\243\056\147\000\000\000\001\116\082\078\083\000\064\230\216\102\000\000\000\063\073\068\065\084\120\094\099\096\013\037\010\056\048\072\173\034\010\076\096\200\034\078\225\018\134\172\255\068\129\149\012\217\196\041\124\057\100\020\142\042\028\085\056\170\144\232\002\128\216\178\103\037\003\027\177\101\015\099\040\081\032\000\000\002\167\124\078\045\044\206\020\000\000\000\000\073\069\078\068\174\066\096\130');f:close()
  local t=UE.Object('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(env.player,path)
  if valid(t)then t.Filter=0;self.nativeToastTexture=t;log('MC21_TOAST_JAR_SPRITE_READY');return t end
  self.nativeToastUnavailable=true;log('MC21_TOAST_SPRITE_UNAVAILABLE');return nil
 end
 function U:nativeHUD(ns,env,enabled,gameplay,owner)
  if not ctx.nativeUIReady()then return end
  local h=self.nativeHud
  if not h then h={sources={},seen={},bindings={},discover=true,scan=0,ticks=0,actionSignature='',audit={},epoch=ctx.epoch()};self.nativeHud=h end
  local now=UE.Object('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(env.player)
  if self.pendingToasts and #self.pendingToasts>0 and(not h.toast or now-h.toast.time>=5)then
   h.toast=table.remove(self.pendingToasts,1);h.toast.time=now;log('MC37_UNLOCK_TOAST '..h.toast.subtitle)
  end
  if ctx.config.ui_notice_reads~=false and not self.importantLogHook then
   local fn='/Game/Pal/Blueprint/UI/Log/WBP_PalLogWidget.WBP_PalLogWidget_C:OnAddedImportantLog'
   if valid(StaticFindObject(fn))then
    local timers=dofile(ctx.base..'/timers.lua');self.importantLogHook=timers.hook(fn,function()self.nativeNoticeDirty=true end);log('MC21_IMPORTANT_LOG_HOOK_READY flag_only=true')
   end
  end
  if h.pendingImportant and h.pendingImportant>0 then h.pendingImportant=h.pendingImportant-1 end
  h.ticks=h.ticks+1
  h.env=env;h.owner=owner;h.enabled=enabled;h.gameplay=gameplay
  h.controllerIdentity=identity(env.controller);h.playerIdentity=identity(env.player)
  if self.nativeNoticeDirty then self.nativeNoticeDirty=false;h.pendingImportant=30;h.discover=true;h.scan=0 end
  
  if h.ticks%15==0 and not h.discover then h.discover=true;h.scan=0 end
  local function admitted()
   return ctx.nativeUIReady()and(not ctx.nativeUIReadReady or ctx.nativeUIReadReady())and h.gameplay and self.nativeHud==h and h.epoch==ctx.epoch()and same(h.controllerIdentity,h.env.controller)and same(h.playerIdentity,h.env.player)
  end
  if ctx.config.ui_notice_reads~=false and not h.discoveryToken then
   local timers=dofile(ctx.base..'/timers.lua')
   h.discoveryToken=timers.loop(1,function()
    if self.nativeHud~=h then return true end
    if not admitted()then return false end
    if not h.discover or not h.enabled then return false end
    local began=os.clock();h.scan=h.scan+1;local class=sourceClasses[h.scan]
    if not class then h.scan=0;h.discover=false;return false end
    for _,w in ipairs(FindAllOf(class)or{})do if nativeWidget(w)and w:GetClass():GetFName():ToString()==class and w:GetFullName():find('/Engine/Transient',1,true)then
     local ok,p=pcall(w.GetOwningPlayer,w)
     if ok and valid(p)and p:GetAddress()==h.env.controller:GetAddress()then
      local row=self:noticeSource(w,sourceKinds[class],h.env)
      if row then
       local id=w:GetAddress();local at=h.seen[id];local old=at and h.sources[at]
       if old and same(old.identity,w)then row.signature=old.signature;h.sources[at]=row
       else h.sources[#h.sources+1]=row;h.seen[id]=#h.sources;h.audit[#h.audit+1]={class=class,path=row.path,text_nodes=#row.texts};log('MC22_HUD_SOURCE class='..class..' text_nodes='..#row.texts)end
       if row.kind=='action'and row.prompt then h.prompt=row end;h.owner:hideNativeNode(w)
      end
     end
    end end
    h.owner:profileStep('notice_discovery',began);return false
   end,'hud-discover')
  end
  if ctx.config.ui_notice_reads~=false and not h.noticeToken then
   local timers=dofile(ctx.base..'/timers.lua');h.noticeIndex=0
   h.noticeToken=timers.loop(1,function()
    if self.nativeHud~=h then return true end
    if not admitted()then return false end
    if not h.enabled or #h.sources==0 then return false end
    h.noticeIndex=h.noticeIndex%#h.sources+1;local r=h.sources[h.noticeIndex]
    if r.kind=='hide'or r.kind=='action'or not same(r.identity,r.node)or not nativeWidget(r.node)then return false end
    local began=os.clock();local parts={}
    if sourceActive(r)then
     for _,t in ipairs(r.texts)do
      if nativeText(t)then
       if ctx.config.hud_trace then log('MC37_NOTICE_TEXT_BEGIN source='..r.path..' key='..t.key..' object='..t.node:GetAddress())end
       local v=t.node:GetVisibility();if v~=1 and v~=2 then local value=nativeString(UE.GetKismetTextLibrary():Conv_TextToString(t.node:GetText())):gsub('<[^>]+>',''):gsub('[\r\n]+',' ');if value~=''then parts[#parts+1]=value end end
       if ctx.config.hud_trace then log('MC37_NOTICE_TEXT_END source='..r.path..' key='..t.key)end
      else h.discover=true end
     end
    end
    local signature=table.concat(parts,' ')
    if signature~=''and signature~=r.signature then
     local kind=r.kind;if kind=='toast'then h.pendingImportant=0;h.importantSignature=signature;h.importantTime=h.now end
     h[kind]={title=parts[1],subtitle=table.concat(parts,' ',2),time=h.now};log('MC21_HUD_'..kind:upper()..'_NATIVE source='..r.path..' text='..signature)
    end;r.signature=signature;r.dirty=false;h.owner:profileStep('notice_read',began);return false
   end,'hud-notice-read')
  end
  h.now=now;local readAt=os.clock();local action='';local r=h.prompt
  if ctx.config.ui_notice_reads~=false and enabled and gameplay and r and r.prompt and nativeText(r.prompt)and sourceActive(r)then
   local value=nativeString(UE.GetKismetTextLibrary():Conv_TextToString(r.prompt.node:GetText())):gsub('<[^>]+>','')
   if value~=''then local key=self:nativePromptKey(r,env);action=(key~=''and'['..key..'] 'or'')..value end
  end
  if action~=h.actionSignature then h.actionSignature=action;if action~=''then h.action={text=action,time=now};log('MC21_HUD_ACTIONBAR_NATIVE text='..action)end end
  owner:profileStep('prompt_notice_read',readAt);local renderAt=os.clock()
  if not h.metrics or h.metricScale~=ctx.config.gui_scale then local _,unit,dpi,size=self:metrics(env);h.metrics={unit=unit,width=size.X/(unit*dpi),height=size.Y/(unit*dpi)};h.metricScale=ctx.config.gui_scale end
  local unit,width,height=h.metrics.unit,h.metrics.width,h.metrics.height
  local function line(n,text,x,y,w,points,alpha)
   self:visible(n,enabled and gameplay and alpha>0 and 3 or 1);if not enabled or not gameplay or alpha<=0 then return end
   self:position(n,x,y,w,points+5,unit);self:textStyle(n,unit,false);self:putText(n,text or'');n:SetJustification(1);n.Slot:SetZOrder(90)
   local key=points..':'..unit;if n==ns.GuiQuest2 or n==ns.GuiQuest3 then if h.fonts and h.fonts[n:GetAddress()]==key then else local f=n.Font;f.Size=self:fontSize(points,unit);n:SetFont(f);h.fonts=h.fonts or{};h.fonts[n:GetAddress()]=key end end
   n:SetRenderOpacity(alpha)
  end
  local a=h.action;local age=a and now-a.time or 99;line(ns.GuiQuest1,a and a.text,-width/2+2,height/2-60,width-4,9,math.max(0,math.min(1,(2-age)/.5)))
  local title=h.title;age=title and now-title.time or 99;local alpha=age<.5 and age/.5 or age<4 and 1 or math.max(0,5-age)
  line(ns.GuiQuest2,title and title.title,-width/2+2,-28,width-4,32,alpha);line(ns.GuiQuest3,title and title.subtitle,-width/2+2,8,width-4,16,alpha)
  local toast=h.toast;age=toast and now-toast.time or 99;alpha=math.max(0,math.min(1,5-age));local visible=enabled and gameplay and alpha>0;local slide=160*(1-math.min(1,math.max(0,age)/.3,math.max(0,5-age)/.3))
  self:visible(ns.GuiList,visible and 3 or 1);self:visible(ns.GuiExtra3,visible and 3 or 1)
  line(ns.GuiQuest4,toast and toast.title,width/2-127+slide,4-height/2,122,9,visible and alpha or 0);line(ns.GuiQuest5,toast and toast.subtitle,width/2-127+slide,16-height/2,122,9,visible and alpha or 0);ns.GuiQuest4:SetJustification(0);ns.GuiQuest5:SetJustification(0)
  if visible then local texture=self:toastTexture(env);if valid(texture)then ns.GuiList:SetBrushFromTexture(texture,false)else self:fill(ns.GuiList,'333333')end;self:position(ns.GuiList,width/2-162+slide,2-height/2,160,32,unit);ns.GuiList.Slot:SetZOrder(80);ns.GuiList:SetRenderOpacity(alpha)
   local icon=toast.item and self.items:icon(toast.item);if valid(icon)then self:icon(ns.GuiExtra3,icon);self:position(ns.GuiExtra3,width/2-154+slide,10-height/2,16,16,unit);ns.GuiExtra3.Slot:SetZOrder(90);ns.GuiExtra3:SetRenderOpacity(alpha)else self:visible(ns.GuiExtra3,1)end
  end
  owner:profileStep('action_title_toast_render',renderAt)
  if h.ticks%10==0 then local f=assert(io.open(ctx.base..'/task21-hud-sources.json','wb'));f:write(dofile(ctx.base..'/json.lua').encode({sources=h.audit,active={},action=h.actionSignature,enabled=enabled,timing={action_seconds=2,title_ticks={10,70,20}}}));f:close()end
 end

 local apply=U.apply
 function U:apply(widget,name,env)
  local ns=ctx.widgets(widget);local layout=design.layouts[name]
  for k,p in pairs(layout or{})do if valid(ns[k])then self:setMeta(ns[k],p)end end
  local factor,unit=apply(self,widget,name,env)
  if layout and valid(ns.GuiPanel)then ns.GuiPanel:SetVisibility(1)end
  for k,p in pairs(layout or{})do local n=ns[k];if valid(n)then
   if p.hidden then n:SetVisibility(1)else self:position(n,p.position[1]/3,p.position[2]/3,p.size[1]/3,p.size[2]/3,unit);n.Slot:SetZOrder(p.type=='TextBlock'and 24 or p.cells and 12 or(p.fill or p.sprite)and(math.min(p.z or 0,0)+10)or 11)
    if p.sprite then self:brush(n,p.sprite,p.sprite=='T_MC_UI_panel'and{4/176,4/166}or nil)end
    if p.fill then self:fill(n,p.fill,p.alpha)end
    if p.type=='TextBlock'then self:textStyle(n,unit,p.dark);if p.value then n:SetText(UE.GetKismetTextLibrary():Conv_StringToText(p.value))end;if p.center then n:SetJustification(1)end end
    if p.clip then n:SetClipping(1)end;n:SetVisibility(3)
   end
  end end
  if name=='WBP_MCPalpedia'and valid(ns.Search)then ns.Search.WidgetStyle.ColorAndOpacity={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0};self:inputFont53(ns.Search,unit);ns.Search:SetHintText(UE.GetKismetTextLibrary():Conv_StringToText('Search...'))end
  if name=='WBP_MCPals'then ns.Level:SetJustification(1);self:textStyle(ns.Level,unit,false,{R=.333,G=1,B=.333,A=1})end
  if name=='WBP_MCTechnology'then ns.TooltipBox:SetVisibility(1);ns.Tooltip:SetVisibility(1);self:setMeta(ns.Points,{dark=false});self:textStyle(ns.Points,unit,false,{R=1,G=.667,B=0,A=1})end
  if name=='WBP_MCCapture'then for _,k in ipairs({'Panel','Portrait','Types','HP','HPText'})do ns[k]:SetVisibility(1)end;local _,_,dpi,size=self:metrics(env);local height=size.Y/(unit*dpi);self:position(ns.Name,-91,1-height/2,182,10,unit);self:textStyle(ns.Name,unit,false);ns.Name:SetJustification(1);self:brush(ns.GuiHeader,'T_MC_UI20_boss_background');self:position(ns.GuiHeader,-91,12-height/2,182,5,unit);ns.GuiHeader:SetVisibility(3);self:brush(ns.GuiExtra1,'T_MC_UI20_boss_progress');self:position(ns.GuiExtra1,-91,12-height/2,182,5,unit);ns.GuiExtra1:SetVisibility(3);self:position(ns.Rate,-40,10,80,10,unit);self:textStyle(ns.Rate,unit,false,{R=1,G=1,B=.333,A=1});ns.Rate:SetJustification(1)end
  if name=='WBP_MCDeath'then self:brush(ns.Dim,'T_MC_UI20_death_dim');local _,_,_,size=self:metrics(env);local h=size.Y/(unit*UE.Object('/Script/UMG.Default__WidgetLayoutLibrary'):GetViewportScale(env.player));self:position(ns.Title,-100,60-h/2,200,20,unit);self:position(ns.Level,-100,85-h/2,200,10,unit)
   for i=1,2 do local y=h/4+72+(i-1)*24-h/2;self:position(ns['Button'..i],-100,y,200,20,unit);self:position(ns['Label'..i],-100,y+6,200,10,unit)end
  end
  if name=='WBP_MCHUD'then
   
   local clip=self:makeNode(ns,'XPClip63','CanvasPanel');clip:SetClipping(1)
   clip.Slot:SetAnchors({Minimum={X=.5,Y=1},Maximum={X=.5,Y=1}});clip.Slot:SetZOrder(12)
   self:position(ns.XPBackground,-91,-32,182,5,unit);self:position(clip,-91,-32,182,5,unit)
   if ns.XPProgress:GetParent():GetAddress()~=clip:GetAddress()then ns.XPProgress:RemoveFromParent();clip:AddChildToCanvas(ns.XPProgress)end
   ns.XPProgress.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=0,Y=0}});self:position(ns.XPProgress,0,0,182,5,unit)
   self:position(ns.Level,-20,-42,40,10,unit);ns.Level:SetJustification(1);self:textStyle(ns.Level,unit,false,{R=.502,G=1,B=.125,A=1})

   for i=1,9 do if valid(ns['Number'..i])then ns['Number'..i]:SetRenderOpacity(0)end;self:position(ns['Count'..i],-88+(i-1)*20,-12,15,8,unit);ns['Count'..i]:SetJustification(2)end

   for _,n in ipairs({ns.XPBackground,clip,ns.Level})do n.Slot:SetAnchors({Minimum={X=.5,Y=1},Maximum={X=.5,Y=1}})end
   ns.XPProgress.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=0,Y=0}})
   for i=1,9 do ns['Count'..i].Slot:SetAnchors({Minimum={X=.5,Y=1},Maximum={X=.5,Y=1}})end
   for i=1,5 do local y=-59+(i-1)*24;for k,r in pairs({['Party'..i]={2,y,22,22},['PalIcon'..i]={3,y+1,20,20},['PalLevel'..i]={12,y+1,11,9},['PalHP'..i]={3,y+20,20,1},['PalName'..i]={26,y+6,96,10}})do local n=ns[k];self:position(n,r[1],r[2],r[3],r[4],unit);n.Slot:SetAnchors({Minimum={X=0,Y=.5},Maximum={X=0,Y=.5}});if k:find('PalLevel',1,true)then n:SetJustification(2)end;if k:find('PalIcon',1,true)then self:setMeta(n,{cells=20,outline=0})end end end
   for i=1,9 do local n=ns['Count'..i];self:setMeta(n,{count=true,dark=false});self:textStyle(n,unit,false);local font=n.Font;font.Size=math.max(1,math.floor(4.5*unit+.5));n:SetFont(font)end
  end
  if name=='WBP_MCGameMenu'then local _,_,dpi,size=self:metrics(env);local buttons,title=dofile(ctx.base..'/creative_layout.lua').pause(size.Y/(unit*dpi));self.gameButtons=buttons;self:position(ns.Title,title[1],title[2],title[3],title[4],unit);for i,b in pairs(buttons)do self:position(ns['Button'..i],b[1],b[2],b[3],20,unit);self:position(ns['Label'..i],b[1],b[2]+4,b[3],14,unit)end end
  if name=='WBP_MCTitle'and valid(ns.GuiHint)then if valid(ns.Footer)then ns.Footer:SetVisibility(1)end;self:position(ns.GuiHint,65,-72,150,18,unit);self:textStyle(ns.GuiHint,unit,false,{R=1,G=1,B=.333,A=1});ns.GuiHint:SetText(UE.GetKismetTextLibrary():Conv_StringToText('Now with Pals!'));ns.GuiHint:SetRenderTransformAngle(-20);ns.GuiHint:SetVisibility(3)end
  log('MC_20_DESIGN_APPLIED '..name);return factor,unit
 end
 local container=U.container
 function U:container(ns,B,env)
  local layout=B:layout();layout.creative=not B.mode and{-88,-109,60,20}or nil;self.inventory=B;self.env=env
  if not B.creative then layout.prev={178-layout.width/2,90-layout.height/2,12,17};layout.next={178-layout.width/2,110-layout.height/2,12,17}end
  local unit=container(self,ns,B,env)
  if valid(ns.CreativeButton)then ns.CreativeButton:SetVisibility(not B.mode and 3 or 1)end
  if valid(ns.Help)then ns.Help:SetVisibility(1)end
  if valid(ns.CreativeSearch)then ns.CreativeSearch:SetForegroundColor({R=1,G=1,B=1,A=1});ns.CreativeSearch:SetHintText(UE.GetKismetTextLibrary():Conv_StringToText('Search...'))end
  if not B.creative then
   for _,key in ipairs({'Prev','Next'})do local n=ns[key];local p=layout[key:lower()];self:position(n,p[1],p[2],12,17,unit);n:SetText(UE.GetKismetTextLibrary():Conv_StringToText(''));local image=ns[key=='Prev'and'GuiExtra1'or'GuiExtra2'];self:brush(image,key=='Prev'and'T_MC_UI20_backward'or'T_MC_UI20_forward');self:position(image,p[1],p[2],12,17,unit);image.Slot:SetZOrder(10);image:SetVisibility(3)end
   self:position(ns.Page,179-layout.width/2,130-layout.height/2,25,10,unit);self:textStyle(ns.Page,unit,false)
  else for _,k in ipairs({'GuiExtra1','GuiExtra2'})do if valid(ns[k])then ns[k]:SetVisibility(1)end end end
  for _,s in ipairs(layout.slots)do local n=ns[s.name..'Count'];if valid(n)then self:setMeta(n,{count=true,dark=false});self:position(n,s.x-3,s.y+8,20,9,unit);n:SetJustification(2);self:textStyle(n,unit,false)end end
  return unit
 end
 local tooltip=U.tooltip
 function U:wrap(s,width,maxLines)
  local lines,line,pixels={},'',0;s=s:gsub('<[^>]+>',''):gsub('\r','')
  for _,cp in utf8.codes(s)do local c=utf8.char(cp);local w=cp>127 and 8 or 4
   if cp==10 or pixels+w>width then lines[#lines+1]=line;line,pixels='',0;if #lines>=(maxLines or 12)then lines[#lines]=lines[#lines]..'...';return table.concat(lines,'\n'),#lines end end
   if cp~=10 then line=line..c;pixels=pixels+w end
  end
  if line~=''then lines[#lines+1]=line end;return table.concat(lines,'\n'),#lines
 end
 function U:hideTooltip(ns)
  
  for _,k in ipairs({'TooltipBox','Tooltip','GuiTooltipFrame','GuiTooltipName','GuiTooltipDetail','GuiTooltipSource','GuiHint'})do
   if valid(ns[k])then ns[k]:SetVisibility(1)end
  end
 end
 function U:cleanDescription(raw,env)
  env=env or self.env;self.descriptionNames=self.descriptionNames or{}
  if env then for tag,method in pairs({itemName='GetItemName',mapObjectName='GetMapObjectName'})do
   raw=raw:gsub('<'..tag..' id=|([^|]+)|/>',function(id)
    local key=method..':'..id;if self.descriptionNames[key]==nil then
     local out={};local utility=UE.Object('/Script/Pal.Default__PalUIUtility');local ok=pcall(utility[method],utility,env.player,UE.FindOrAddFName(id),out)
     local text=ok and out.outName and UE.GetKismetTextLibrary():Conv_TextToString(out.outName);self.descriptionNames[key]=text and(type(text)=='string'and text or text:ToString())or false
    end;return self.descriptionNames[key]or('<'..tag..' id=|'..id..'|/>')
   end)
  end end
  local kept={};for line in (raw..'\n'):gmatch('(.-)\n')do
   local plain=line:gsub('<[^>]+>',''):gsub('\r','')
   local broken=line:find('<itemName',1,true)or line:find('<mapObjectName',1,true)or line:find('||',1,true)or line:find('{[^}]+}')or plain:find('을(를)',1,true)or plain:find('(으)로',1,true)or plain:match('^%s*을%s')or plain:match('^%s*를%s')
   if not broken and plain:match('%S')then kept[#kept+1]=plain:gsub('|','')end
  end;return table.concat(kept,'\n')
 end
 function U:tooltip(ns,entry,label,x,y,unit)
  if not valid(ns.TooltipBox)and valid(ns.GuiFrame)then ns.TooltipBox=ns.GuiFrame;self:brush(ns.TooltipBox,'T_MC_UI_tooltip_background')end
  if not valid(ns.Tooltip)and valid(ns.GuiHint)then ns.Tooltip=ns.GuiHint end
  if not valid(ns.GuiTooltipName)then return tooltip(self,ns,entry,label,x,y,unit)end
  local show=entry and entry.id;for _,k in ipairs({'GuiTooltipName','GuiTooltipDetail','GuiTooltipSource'})do ns[k]:SetVisibility(show and 3 or 1)end;ns.Tooltip:SetVisibility(1)
  if not show then ns.TooltipBox:SetVisibility(1);ns.GuiTooltipFrame:SetVisibility(1);if valid(ns.GuiHint)then ns.GuiHint:SetVisibility(1)end;return end
  local id=entry.id;local source=id:sub(1,3)=='MC_'and'Minecraft'or'Palworld';local lines={};local data=self.inventory and self.inventory:data(id);local rarity=valid(data)and data.Rarity or 0;self.descriptions=self.descriptions or{}
  if self.descriptions[id]==nil then self.descriptions[id]='';pcall(function()local out={};_G.MC_OUT_K('GetItemDescription',UE.Object('/Script/Pal.Default__PalUIUtility'),self.env.player,UE.FindOrAddFName(id),out);if out.outName then local v=UE.GetKismetTextLibrary():Conv_TextToString(out.outName);self.descriptions[id]=type(v)=='string'and v or v:ToString()end end)end
  local desc=self:cleanDescription(self.descriptions[id]);if desc~=''then lines[#lines+1]=self:wrap(desc,170,5)end
  if entry.have~=nil then lines[#lines+1]='Have: '..tostring(entry.have)end
  if valid(data)and data.TypeA==1 then for _,value in ipairs(self.env.player.LoadoutSelectorComponent:GetWeaponList())do local w=value;pcall(function()w=value:get()end);if valid(w)and w:GetItemId().StaticId:ToString()==id and w:GetMagazineSize()>0 then lines[#lines+1]='Reserve ammo: '..w:GetInventoryBulletCount();break end end end
  local equipment;pcall(function()if data.DefenseValue>0 then lines[#lines+1]='';lines[#lines+1]='When on Body:';equipment='+'..data.DefenseValue..' Defense'elseif data.AttackValue>0 then lines[#lines+1]='';lines[#lines+1]='When in Main Hand:';equipment=data.AttackValue..' Attack'end end)
  pcall(function()if valid(entry.slot)and data.Durability>0 then local out={};if _G.MC_OUT_K('TryGetDynamicItemData',entry.slot,out)and valid(out.OutDynamicItemData)then local value=out.OutDynamicItemData.Durability;if value<data.Durability then lines[#lines+1]='Durability: '..math.floor(value)..' / '..math.floor(data.Durability)end end end end)
  local detail=table.concat(lines,'\n');local count=detail==''and 0 or select(2,detail:gsub('\n',''))+1;local w=math.max(100,math.min(178,(utf8.len(label)or #label)*6+8));if count>0 then w=178 end;local height=26+count*10+(equipment and 10 or 0);local _,_,dpi,size=self:metrics(self.env);local right=size.X/(unit*dpi)/2;local bottom=size.Y/(unit*dpi)/2;local cursorX=x;x=x+12;if x+w>right-2 then x=cursorX-w-12 end;x=math.max(-right+2,math.min(right-w-2,x));y=math.max(-bottom+2,math.min(bottom-height-2,y-12))
  self:position(ns.TooltipBox,x,y,w,height,unit);self:position(ns.GuiTooltipFrame,x,y,w,height,unit);self:brush(ns.GuiTooltipFrame,'T_MC_UI_tooltip_frame');ns.TooltipBox:SetVisibility(3);ns.GuiTooltipFrame:SetVisibility(3);ns.TooltipBox.Slot:SetZOrder(49);ns.GuiTooltipFrame.Slot:SetZOrder(50)
  local colors={[0]={R=1,G=1,B=1,A=1},{R=1,G=1,B=.333,A=1},{R=.333,G=1,B=1,A=1},{R=1,G=.333,B=1,A=1},{R=1,G=.667,B=0,A=1}}
  for i,k in ipairs({'GuiTooltipName','GuiTooltipDetail','GuiTooltipSource'})do local n=ns[k];local yy=i==1 and 4 or i==2 and 16 or height-12;self:position(n,x+4,y+yy,w-8,i==2 and count*10 or 10,unit);n.Slot:SetZOrder(51);n:SetClipping(1);n:SetText(UE.GetKismetTextLibrary():Conv_StringToText(i==1 and label or i==2 and detail or source));self:textStyle(n,unit,false,i==1 and(colors[math.max(0,math.min(4,rarity))]or colors[0])or i==2 and{R=.667,G=.667,B=.667,A=1}or{R=.333,G=.333,B=1,A=1});if i==3 then n:SetRenderShear({X=-.2,Y=0})end end
  if valid(ns.GuiHint)then ns.GuiHint:SetVisibility(equipment and 3 or 1);if equipment then self:position(ns.GuiHint,x+4,y+height-22,w-8,10,unit);ns.GuiHint.Slot:SetZOrder(51);self:textStyle(ns.GuiHint,unit,false,{R=.333,G=.333,B=1,A=1});ns.GuiHint:SetText(UE.GetKismetTextLibrary():Conv_StringToText(equipment))end end
 end
 dofile(ctx.base..'/timers.lua').onEpoch('ui20',function()
  meta={};identities={};mids={};textureKinds={};retainers={};U.iconCacheRoot=nil;quest=nil;U.questNodes=nil;U.questTitle=nil;U.questOpacity=nil
  U.questSearchTick=nil;U.questRenderSignature=nil;U.questErrorLogged=nil;U.env=nil;U.inventory=nil
 end)
end
