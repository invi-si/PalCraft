-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local E={roots={},remnants={},events=0,dirty=true};local T=dofile(ctx.base..'/timers.lua')
 local valid,UE=ctx.valid,ctx.UE
 local capture82=dofile(ctx.base..'/capture82.lua')(ctx)
 local rootClass='/Game/Pal/Blueprint/UI/WBP_PlayerUI.WBP_PlayerUI_C'
 local gauge='/Game/Pal/Blueprint/UI/UserInterface/InGame/PlayerGauge/WBP_Ingame_PlayerGauge_Separated.WBP_Ingame_PlayerGauge_Separated_C'
 local task49Rows={
  {path='/Game/Pal/Blueprint/UI/WBP_PalInteractiveObjectIndicatorCanvas.WBP_PalInteractiveObjectIndicatorCanvas_C'},
  {path='/Game/Pal/Blueprint/UI/WBP_PalInteractiveObjectIndicatorUI.WBP_PalInteractiveObjectIndicatorUI_C'},
  {path='/Game/Pal/Blueprint/UI/DebugInfo/WBP_PalDebugInfo.WBP_PalDebugInfo_C'},
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/PalGet/WBP_PalGet_s.WBP_PalGet_s_C'},
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/Interact/WBP_Ingame_InteractDurability.WBP_Ingame_InteractDurability_C'},
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/Interact/WBP_Ingame_InteractMultiplayModifier.WBP_Ingame_InteractMultiplayModifier_C'},
  {path='/Game/Pal/Blueprint/UI/DamageText/WBP_PalDamageText.WBP_PalDamageText_C'},
  {path='/Game/Pal/Blueprint/UI/DamageText/WBP_PalDamageCanvas_OneShotText.WBP_PalDamageCanvas_OneShotText_C'}}
 local indicatorRows={
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/AutoSave/WBP_AutoSave.WBP_AutoSave_C'},
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/Quest/WBP_InGame_Quest_StartClearSet.WBP_InGame_Quest_StartClearSet_C'},
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/Quest/WBP_InGame_Quest_StartClear_Main.WBP_InGame_Quest_StartClear_Main_C'},
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/Quest/WBP_InGame_Quest_StartClear_Sub.WBP_InGame_Quest_StartClear_Sub_C'},
  {path='/Game/Pal/Blueprint/UI/Log/WBP_BlinkedLog.WBP_BlinkedLog_C'},
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/Notice/WBP_PalInfo.WBP_PalInfo_C'},
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/Notice/WBP_Warning.WBP_Warning_C'},
  {path='/Game/Pal/Blueprint/UI/Log/WBP_PalLogWidget.WBP_PalLogWidget_C'},
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/GameOver/WBP_GameOver_Defeat.WBP_GameOver_Defeat_C',death=true},
  {path='/Game/Pal/Blueprint/UI/WBP_GameOver_ForDIsplay.WBP_GameOver_ForDIsplay_C',death=true},
  {path='/Game/Pal/Blueprint/UI/UserInterface/InGame/Notice/WBP_Notice_DeathAnnounce.WBP_Notice_DeathAnnounce_C',death=true},
  {path='/Game/Pal/Blueprint/UI/CommonWidget/PalSaveParameterDisplayWidget/WBP_DroppedTimer.WBP_DroppedTimer_C',drop=true}}
 local function widget(o)return valid(o)and o:IsA(UE.Object('/Script/UMG.Widget'))end
 local function record(o)
  return {node=o,class=o:GetClass():GetAddress(),name=o:GetFName():ToString(),opacity=o:GetRenderOpacity()}
 end
 local function current(r)
  if r and r.checkedFrame==T.frameCounter then return r.checkedValid end
  local good=r and widget(r.node)and r.node:GetClass():GetAddress()==r.class and r.node:GetFName():ToString()==r.name
  if r then r.checkedFrame=T.frameCounter;r.checkedValid=good end
  return good
 end
 local function transient(o,path)
  return widget(o)and o:GetClass():GetFullName()=='WidgetBlueprintGeneratedClass '..path
   and o:GetFullName():find('/Engine/Transient',1,true)~=nil
 end
 local function canvas(w)
  if not widget(w)or not w:IsA(UE.Object('/Script/UMG.UserWidget'))then return end
  local tree=w.WidgetTree
  if not valid(tree)or not tree:IsA(UE.Object('/Script/UMG.WidgetTree'))then return end
  local n=tree.RootWidget;if widget(n)then return n end
 end
 local function mask(r,hide)
  if not current(r)then return false end
  local opacity=hide and 0 or r.opacity;if r.node:GetRenderOpacity()~=opacity then r.node:SetRenderOpacity(opacity)end
  local n=canvas(r.node)
  if n then
   if not current(r.canvas)or r.canvas.node:GetAddress()~=n:GetAddress()then r.canvas=record(n)end
   local alpha=hide and 0 or r.canvas.opacity;if r.canvas.node:GetRenderOpacity()~=alpha then r.canvas.node:SetRenderOpacity(alpha)end
  end
  return true
 end
 local function unwrap(x)local ok,v=pcall(function()return x:get()end);return ok and v or x end
 function E:task49Flags()
  local utility=StaticFindObject('/Script/Pal.Default__PalUtility');assert(valid(utility),'PalUtility absent for HUD flags')
  local settings=utility:GetPalDebugSetting()
  if not valid(settings)then
   self.flagsUnavailable=true;ctx.log('MC49_NATIVE_FLAGS_UNAVAILABLE admitted_controller=true getter_invalid=true cached_mask_fallback=true');return false
  end
  local id=settings:GetAddress()
  self.flagOriginals=self.flagOriginals or{}
  if not self.flagOriginals[id]then
   self.flagOriginals[id]={name=settings:GetFullName(),bIsHideAllHUD=settings.bIsHideAllHUD,bIsNowHUDHide=settings.bIsNowHUDHide,bForceDisableDamagePopup=settings.bForceDisableDamagePopup}
  end
  settings.bIsHideAllHUD=true
  settings.bForceDisableDamagePopup=true
  assert(settings.bIsHideAllHUD and settings.bForceDisableDamagePopup,'Native HUD flags rejected')
  ctx.log('MC49_NATIVE_FLAGS hideAllHUD=true disableDamagePopup=true nowHUDHide='..tostring(settings.bIsNowHUDHide)..' master_tick=true object='..settings:GetFullName())
 end
 function E:task49Status()
  local utility=StaticFindObject('/Script/Pal.Default__PalUtility');local settings=utility:GetPalDebugSetting()
  local d={originals=self.flagOriginals,flagsUnavailable=not valid(settings),specificTemplates=self.specificTemplates,specificMasks={}}
  if valid(settings)then d.bIsHideAllHUD=settings.bIsHideAllHUD;d.bIsNowHUDHide=settings.bIsNowHUDHide;d.bForceDisableDamagePopup=settings.bForceDisableDamagePopup end
  for _,row in ipairs(task49Rows)do
   local r={path=row.path,instances={}}
   for _,o in ipairs(FindAllOf(row.path:match('%.([^%.]+)$'))or{})do if widget(o)then
    local root=canvas(o);r.instances[#r.instances+1]={name=o:GetFullName(),opacity=o:GetRenderOpacity(),root=root and root:GetRenderOpacity()or false,admitted=self.remnants[o:GetAddress()]~=nil}
   end end
   d.specificMasks[#d.specificMasks+1]=r
  end
  return d
 end
 function E:retain(o)
  assert(valid(o),'UI preload reference invalid')
  if not valid(self.referenceOwner)then self.referenceOwner=UE.GetGameInstance();self.referenceIndex65=nil end
  assert(valid(self.referenceOwner),'UI reference GameInstance absent')
  if not self.referenceIndex65 then
   self.referenceIndex65={};self.referenceList65={}
   self.referenceOwner.ReferencedObjects:ForEach(function(_,v)local x=unwrap(v);if valid(x)then self.referenceIndex65[x:GetAddress()]=true;self.referenceList65[#self.referenceList65+1]=x end end)
  end
  local id=o:GetAddress()
  if not self.referenceIndex65[id]then
   
   local refs={};self.referenceOwner.ReferencedObjects:ForEach(function(_,v)local x=unwrap(v);if valid(x)then refs[#refs+1]=x;self.referenceIndex65[x:GetAddress()]=true end end)
   if not self.referenceIndex65[id]then refs[#refs+1]=o;self.referenceOwner.ReferencedObjects=refs;self.referenceIndex65[id]=true end
   self.referenceList65=refs
  end
 end
 function E:scoped()return ctx.ready()end
 function E:allowed()return ctx.ready()or(self.ready and ctx.earlyReady and ctx.earlyReady())end
 function E:hide(w,reason)
  if not self:allowed()or not transient(w,rootClass)then return end
  local id=w:GetAddress();local r=self.roots[id]
  if not current(r)then
   r=record(w);self.roots[id]=r;self.events=self.events+1
   ctx.log('MC36_HUD_ROOT_ADMITTED event='..self.events..' reason='..reason..' master_tick=true')
  end
  mask(r,true)
 end
 function E:toggle(showNative)
  if not self:allowed()then return end
  for _,rows in ipairs({self.roots,self.remnants})do for id,r in pairs(rows)do if not mask(r,not showNative)then rows[id]=nil end end end
 end
 function E:maskIndicator(w,path)
  if not self:allowed()or not transient(w,path)then return end
  local id=w:GetAddress();local r=self.remnants[id]
  if not current(r)then r=record(w);self.remnants[id]=r;ctx.log('MC36_NATIVE_INDICATOR_ADMITTED '..path..' master_tick=true')end
  mask(r,true)
 end
 function E:bindCurrent()self.dirty=true end
 function E:install()
  
  local function dirty()self.dirty=true;ctx.uiKit.nativeNoticeDirty=true end
  local function hooks(path,names,required)
   for _,name in ipairs(names)do local fn=path..':'..name
    if valid(StaticFindObject(fn))then T.hook(fn,dirty,dirty)
    elseif required then error('Concrete HUD function missing '..fn)end
   end
  end
  hooks(gauge,{'OnInitialized','Construct','SetVisibilityRightInfo','SetVisibilityShield','SetVisibleCommonKeyGuide'},true)
  hooks(rootClass,{'Setup After CreatePlayerIndividualParameter','OnChangedUISettings','SetIsHideWeaponInfo'})
  for _,row in ipairs(indicatorRows)do hooks(row.path,row.names or(row.death and{'Construct','OnInitialized','OnActivated'}or{'Construct','OnInitialized'}))end
  ctx.items:installInputHooks()
  ctx.log('MC39_HIDE_HOOKS_READY flag_only=true')
  ctx.log('MC36_UI_EVENTS_READY concrete=true pawn_reads=0')
 end
 function E:tick()
  
  if not self:allowed()then return false end
  local env=ctx.earlyEnvironment and ctx.earlyEnvironment()or ctx.environment();if not env or not valid(env.controller)then return false end
  ctx.phaseA:setLife(env.status,env)
  local controller=env.controller:GetAddress()
  if self:scoped()and env.status=='alive'then capture82:tick(env)end
  if self.input and env.status=='alive'and self.input.controller~=controller then self.input:start(env)end
  if self.controller~=controller then self:task49Flags();self.roots={};self.remnants={};self.controller=controller;self.dirty=true end

  if ctx.phaseA.profileBaseline and(not self.rootAt or os.clock()>=self.rootAt)then self.dirty=true;self.rootAt=os.clock()+1 end

  local rootDirty=self.dirty or(next(self.roots)==nil and not self.rootAttempted54)
  if rootDirty then self.dirty=false;if self.scan==nil then self.scan=0 end end
  
  if rootDirty or self.scan==0 then
   self.rootAttempted54=true
   for _,w in ipairs(FindAllOf('WBP_PlayerUI_C')or{})do if transient(w,rootClass)then
    local p=w:GetOwningPlayer();if valid(p)and p:GetAddress()==controller then self:hide(w,'dirty-tick')end
   end end
   if env.status=='alive'and next(self.roots)~=nil then ctx.phaseA:earlyHUD(env.controller);ctx.phaseA:setLife(env.status,env)end
  end
  if self.scan~=nil then
   self.scan=self.scan+1;local row=indicatorRows[self.scan]
   if row then
    for _,w in ipairs(FindAllOf(row.path:match('%.([^%.]+)$'))or{})do
     self:maskIndicator(w,row.path)
     if row.drop and transient(w,row.path)then
      local tree=w:GetOuter();local p=valid(tree)and tree:IsA(UE.Object('/Script/UMG.WidgetTree'))and tree:GetOuter()
      if widget(p)and p:GetClass():GetFullName():find('WBP_DeathChestInfoWidget',1,true)then
       local id=p:GetAddress();if not current(self.remnants[id])then self.remnants[id]=record(p)end
      end
     end
    end
   else self.scan=nil end
  end

  if self.specificScan or not self.specificAt or os.clock()>=self.specificAt then
   self.specificScan=(self.specificScan or 0)+1;local row=task49Rows[self.specificScan]
   if row then
    for _,w in ipairs(FindAllOf(row.path:match('%.([^%.]+)$'))or{})do self:maskIndicator(w,row.path)end
   else self.specificScan=nil;self.specificAt=math.huge end
  end

  if self.dirty then for _,rows in ipairs({self.roots,self.remnants})do for id,r in pairs(rows)do if not mask(r,true)then rows[id]=nil end end end
  else
   self.maskQueue61=self.maskQueue61 or{};self.maskIndex61=self.maskIndex61 or 1
   if self.maskIndex61>#self.maskQueue61 then
    local n=0
    for _,rows in ipairs({self.roots,self.remnants})do for id,r in pairs(rows)do
     n=n+1;local q=self.maskQueue61[n]or{};self.maskQueue61[n]=q;q.rows=rows;q.id=id;q.record=r
    end end
    for i=#self.maskQueue61,n+1,-1 do self.maskQueue61[i]=nil end
    self.maskIndex61=1
   end
   for _=1,4 do local q=self.maskQueue61[self.maskIndex61];if not q then break end;self.maskIndex61=self.maskIndex61+1;if not mask(q.record,true)then q.rows[q.id]=nil end end
  end
  return false
 end
 function E:start()

   local kit=ctx.uiKit
   if not kit.tabAliasesVA then
    kit.tabAliasesVA=true;local asset=kit.asset
    function kit:asset(name)
     if name:match('^T_MC_UI_creative_tab_%a+_%a+_[127]$')then name=name..'_VA'end
     return asset(self,name)
    end
   end
  local index=0;local jobs={};local begun,workMs= nil,0
  
  if ctx.config.ui_preload~=false then
   jobs[#jobs+1]=function()self:retain(ctx.uiKit:pixelFont53())end
   if ctx.preloadSteve then jobs[#jobs+1]=function()ctx.preloadSteve(function(o)self:retain(o)end)end end
   if ctx.preloadIslands then ctx.preloadIslands(function(job)jobs[#jobs+1]=job end,function(o)self:retain(o)end)end
   if ctx.preloadAlex then jobs[#jobs+1]=function()ctx.preloadAlex(function(o)self:retain(o)end)end end
   for _,name in ipairs({'WBP_MCInventory2','WBP_MCInventory3','WBP_MCGameMenu','WBP_MCDeath'})do jobs[#jobs+1]=function()self:retain(ctx.loadWidgetClass(name))end end
   
   jobs[#jobs+1]=function()self:retain(ctx.loadWidgetClass('WBP_MCHUD'))end

   for _,name in ipairs(dofile(ctx.base..'/ui_preload.lua'))do

    if not name:match('_%d+$')then jobs[#jobs+1]=function()
     local texture=ctx.uiKit:asset(name);self:retain(texture)
     ctx.uiKit.titleRetainedOC=ctx.uiKit.titleRetainedOC or{};ctx.uiKit.titleRetainedOC[texture:GetAddress()]=texture
    end end
   end
  end
  if ctx.config.ui_default_mask then
   jobs[#jobs+1]=function()
    local fn='/Script/Pal.PalPlayerState:RegisterForPalDex_ToClient'
    assert(valid(StaticFindObject(fn)),'Capture registration function absent')
    T.hook(fn,function()capture82:signal();self.specificAt=nil end)
    ctx.log('MC82_CAPTURE_EVENT_READY flag_only=true')
   end
   local paths={rootClass,gauge}
   for _,row in ipairs(indicatorRows)do paths[#paths+1]=row.path end
   for _,path in ipairs(paths)do jobs[#jobs+1]=function()
    local cls=ctx.loadNativeClass(path);self:retain(cls)
    local utility=StaticFindObject('/Script/Pal.Default__PalUtility');assert(valid(utility),'Loaded PalUtility absent at schema-admitted title')
    local cdo=utility:GetDefaultObject(cls)
    assert(widget(cdo),'Native HUD CDO is not Widget '..path)

    cdo.RenderOpacity=0
    assert(cdo:GetRenderOpacity()==0,'HUD CDO opacity rejected '..path)
    ctx.log('MC44_HUD_DEFAULT_MASK '..path..' hooks=false')
   end end
   for _,row in ipairs(task49Rows)do jobs[#jobs+1]=function()
    local cls=ctx.loadNativeClass(row.path);self:retain(cls)
    local utility=StaticFindObject('/Script/Pal.Default__PalUtility');local cdo=utility:GetDefaultObject(cls)
    assert(widget(cdo),'Specific HUD CDO invalid '..row.path);cdo.RenderOpacity=0

    local tree=cls.WidgetTree;local root=valid(tree)and tree.RootWidget;local count=0
    local function visit(n,depth)
     if not widget(n)then return end;assert(depth<=20,'Specific HUD template depth');n.RenderOpacity=0;count=count+1
     if n:IsA(UE.Object('/Script/UMG.PanelWidget'))then local children=n:GetChildrenCount();assert(children<=256,'Specific HUD template count');for i=0,children-1 do visit(n:GetChildAt(i),depth+1)end end
    end
    visit(root,0);self.specificTemplates=self.specificTemplates or{};self.specificTemplates[row.path]=count
    ctx.log('MC49_HUD_TEMPLATE_MASK path='..row.path..' nodes='..count..' hooks=false master_tick=true')
   end end
   jobs[#jobs+1]=function()

    local path='/Game/Pal/Blueprint/UI/UserInterface/MainMenu/WBP_MainMenu_bg.WBP_MainMenu_bg_C'
    local cls=ctx.loadNativeClass(path);self:retain(cls)
    local cdo=StaticFindObject('/Script/Pal.Default__PalUtility'):GetDefaultObject(cls)
    cdo.bIsDisplayFooter=false
    local function visit(n,inside,depth)
     if not widget(n)then return end;assert(depth<=20)
     inside=inside or n:GetFName():ToString()=='IngameMenu_Foot'
     if inside then n:SetRenderOpacity(0)end
     if n:IsA(UE.Object('/Script/UMG.PanelWidget'))then for i=0,n:GetChildrenCount()-1 do visit(n:GetChildAt(i),inside,depth+1)end end
    end
    visit(cls.WidgetTree.RootWidget,false,0)
    ctx.log('MC108_FOOTER_TEMPLATE_MASK subtree=IngameMenu_Foot ticking=true')
   end
   jobs[#jobs+1]=function()T.loop(1,function()return self:tick()end,'hud-opacity-mask')end
  end
  if ctx.config.ui_hide_hooks~=false then
   local paths={rootClass,gauge,'/Game/Pal/Blueprint/UI/WBP_PalHUD_InGame_InputListener.WBP_PalHUD_InGame_InputListener_C'}
   for _,row in ipairs(indicatorRows)do paths[#paths+1]=row.path end
   for _,path in ipairs(paths)do jobs[#jobs+1]=function()self:retain(ctx.loadNativeClass(path))end end
   jobs[#jobs+1]=function()self:install();T.loop(1,function()return self:tick()end,'hud-dirty-mask')end
  end
  ctx.log('MC38_UI_FLAGS preload='..tostring(ctx.config.ui_preload~=false)..' hide_hooks='..tostring(ctx.config.ui_hide_hooks~=false)..' notice_reads='..tostring(ctx.config.ui_notice_reads~=false))
  if #jobs==0 then self.ready=true;return end
  T.loop(1,function()
   if not ctx.startup.uiOpen then
    if not ctx.startup.open and not ctx.startup:bootstrapAllowed()then return false end
    ctx.startup.uiOpen=true;ctx.log('MC36_UI_SCHEMA_ADMITTED pawn_reads=0 title_preload_M=true')
   end
   begun=begun or os.clock();local tick=os.clock();local n=0
   repeat
    index=index+1;local job=jobs[index];if not job then break end
    local at=os.clock();ctx.startup.uiPreloadM=true;job();ctx.startup.uiPreloadM=nil;workMs=workMs+(os.clock()-at)*1000;n=n+1
   until n>=16 or(os.clock()-tick)*1000>=12
   if index<#jobs then return false end
   self.ready=true;ctx.log(string.format('MC36_UI_PRELOAD_READY jobs=%d retained=true pawn_reads=0 elapsed_ms=%.3f work_ms=%.3f lazy_menus=true',#jobs,(os.clock()-begun)*1000,workMs));return true
  end,'ui-preload')
 end
 T.onEpoch('ui-entry',function()E.referenceOwner=nil;E.referenceIndex65=nil;E.referenceList65=nil;E.roots={};E.remnants={};E.maskQueue61=nil;E.maskIndex61=nil;E.controller=nil;E.scan=nil;E.dirty=true;E.rootAt=nil;E.rootAttempted54=nil;E.specificScan=nil;E.specificAt=nil end)
 T.onEpoch('capture82',function()capture82:reset()end)
 return E
end
