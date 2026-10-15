-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local O={};local valid,UE,log=ctx.valid,ctx.UE,ctx.log;local U=ctx.uiKit;local nodes,mode,buttons,owner;local skins=dofile(ctx.base..'/skins_ui71.lua')(ctx);O.skins71=skins
 local function text(n,s)if valid(n)then n:SetText(UE.GetKismetTextLibrary():Conv_StringToText(tostring(s)))end end
 function O:settings()
  for _,o in ipairs(FindAllOf('GameUserSettings')or{})do if valid(o)and not o:GetFullName():find('Default__',1,true)then return o end end
 end
 function O:saveMod()
  local f=assert(io.open(ctx.base..'/ui-settings.json','wb'));f:write(dofile(ctx.base..'/json.lua').encode({gui_scale=ctx.config.gui_scale or 0,mc_sound_volume=ctx.config.mc_sound_volume or 1,hud=ctx.phaseA.visible}));f:close()
 end
 function O:native(env)
  local root=owner;if not valid(root)then root=ctx.menu:nativeRoot(env)end
  if not valid(root)then log('MC_J_NATIVE_SETTINGS_UNAVAILABLE');return end
  local m=root.WBP_MainMenu;local tab=m.WBP_Tab_06;if not valid(tab)then log('MC_J_NATIVE_SETTINGS_UNAVAILABLE tab');return end
  ctx.menu.nativeBypass=true;ctx.menu:close(false,true);root:SetRenderOpacity(1);root:ActivateWidget()
  m:SelectByMainMenuType(tab.BindMainMenuType);env.controller.bShowMouseCursor=true
  UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameAndUIEx(env.controller,root,0,false,false);log('MC_J_NATIVE_SETTINGS_OPEN')
 end
 function O:nativeChange(method,value)
  local s=assert(self:settings(),'Native GameUserSettings unavailable');s[method](s,value);s:ApplySettings(false);s:SaveSettings();log('MC_J_NATIVE_SETTING_SAVED method='..method..' value='..tostring(value))
 end
 function O:show(env,page,view,root)
  skins:hide();nodes,mode,owner=view,page,root;if page=='Skins'then skins:show(env,view,true);return end;nodes.Title:SetVisibility(3);buttons={};local _,unit=U:metrics(env);self.unit=unit;U.unit=unit;ctx.menu.uiFactor=unit/3
  for i=1,20 do nodes['Button'..i]:SetVisibility(1);nodes['Label'..i]:SetVisibility(1);nodes['Handle'..i]:SetVisibility(1)end
  local settings=self:settings();local _,_,dpi,viewport=U:metrics(env);local height=viewport.Y/(unit*dpi);local row0=height/6+18-height/2
  local function add(label,action,x,y,w,slider,value)
   if ctx.config.task20_ui and label~='Done'then y=y==-20 and row0+56 or row0+(y+76)end
   local i=#buttons+1;local b={label=label,action=action,x=x,y=y,w=w or 150,h=20,slider=slider,value=value};buttons[i]=b
   local image,caption,handle=nodes['Button'..i],nodes['Label'..i],nodes['Handle'..i]
   U:brush(image,slider and'T_MC_UI_widget_slider'or'T_MC_UI_widget_button',{.01,.1});U:position(image,x,y,b.w,20,unit);image:SetVisibility(3)
   U:position(caption,x,y+4,b.w,14,unit);U:textStyle(caption,unit);caption:SetJustification(1);text(caption,label);caption:SetVisibility(3)
   if slider then U:brush(handle,'T_MC_UI_widget_slider_handle');U:position(handle,x+(b.w-8)*value,y,8,20,unit);handle:SetVisibility(3)end
  end
  text(nodes.Title,page=='Sounds'and'Music & Sounds'or page=='Video'and'Video Settings'or page=='Controls'and'Controls'or page=='Language'and'Language'or'Options');U:position(nodes.Title,-155,-113,310,16,unit);U:textStyle(nodes.Title,unit);nodes.Title:SetJustification(1)
  if page=='Options'then
   add('FOV / World Settings...','native',-155,-76);add('Difficulty...','native',5,-76)
   add('Music & Sounds...','Sounds',-155,-52);add('Video Settings...','Video',5,-52)
   add('Controls...','Controls',-155,-28);add('Language...','Language',5,-28)
   add('Skins...','Skins',-155,-4);add('Palworld Settings...','native',5,-4)
  elseif page=='Language'then
   add('English','language_en',-155,-76);add('Korean','language_ko',5,-76)
  elseif page=='Sounds'then
   for i,label in ipairs({'Master Volume...','Music Volume...','Sound Effects...','Voice Volume...'})do add(label,'native',i%2==1 and-155 or 5,-76+math.floor((i-1)/2)*24)end
   local volume=ctx.config.mc_sound_volume or 1;add('Minecraft Sounds: '..math.floor(volume*100)..'%','mcvolume',-155,-20,310,true,volume)
   text(nodes.Help,'Native volume controls open Palworld settings.');U:position(nodes.Help,-155,15,310,25,unit);U:textStyle(nodes.Help,unit)
  elseif page=='Video'then
   local window=settings and settings:GetFullscreenMode();local resolution=settings and settings:GetScreenResolution();local quality=settings and settings:GetOverallScalabilityLevel();local fps=settings and settings:GetFrameRateLimit()
   local levels={[0]='Low','Medium','High','Epic','Cinematic'};local windows={[0]='Fullscreen','Borderless','Windowed'}
   local labels={{'Window Mode: '..(windows[window]or'Unavailable'),'window'},{resolution and('Resolution: '..resolution.X..'x'..resolution.Y)..'...'or'Resolution...','native'},{'Graphics: '..(levels[quality]or'Custom'),'quality'},{'Max Framerate: '..(fps and string.format('%g',fps)or'Unavailable'),'fps'},{'Brightness...','native'},{'Motion Blur...','native'},{'Anti-Aliasing: '..(settings and settings:GetAntiAliasingQuality()==0 and'Off'or levels[settings and settings:GetAntiAliasingQuality()]or'Custom'),'aa'},{'Upscaler...','native'},{'View Distance: '..(levels[settings and settings:GetViewDistanceQuality()]or'Custom'),'distance'},{'GUI Scale: '..((ctx.config.gui_scale or 0)==0 and'Auto'or tostring(ctx.config.gui_scale)),'gui'},{'Minecraft HUD: '..(ctx.phaseA.visible and'ON'or'OFF'),'hud'}}
   for i,b in ipairs(labels)do add(b[1],b[2],i%2==1 and-155 or 5,-76+math.floor((i-1)/2)*24)end
  elseif page=='Controls'then
   add('Mouse Sensitivity...','native',-155,-76);add('Invert Y...','native',5,-76);add('Key Binds...','native',-100,-52,200)
   text(nodes.Help,'Tab: Inventory   1-9 / Wheel: Hotbar\nLMB: Mine   RMB: Place\nE: Summon Pal   Q: Sphere\nArrows / R: Party   Y: Reload\nU: Sphere type   H: Commands\nF5: Perspective   K / T / P: Menus');U:position(nodes.Help,-155,-19,310,95,unit);U:textStyle(nodes.Help,unit)
  end
  if page~='Sounds'and page~='Controls'then nodes.Help:SetVisibility(1)else nodes.Help:SetVisibility(3)end
  if ctx.config.task20_ui then nodes.Help:SetVisibility(1);U:position(nodes.Title,-155,15-height/2,310,16,unit)
   if page~='Options'then U:brush(nodes.GuiBackground,'T_MC_UI20_menu_list_background');U:position(nodes.GuiBackground,-160,35-height/2,320,height/6+123,unit);nodes.GuiBackground.Slot:SetZOrder(1);nodes.GuiBackground:SetVisibility(3);for _,k in ipairs({'GuiOffhand','GuiHover'})do U:brush(nodes[k],k=='GuiOffhand'and'T_MC_UI20_header_separator'or'T_MC_UI20_footer_separator');U:position(nodes[k],-160,k=='GuiOffhand'and(33-height/2)or(height/6+160-height/2),320,2,unit);nodes[k].Slot:SetZOrder(2);nodes[k]:SetVisibility(3)end end
  end
  add('Done',page=='Options'and'Game'or'Options',-100,ctx.config.task20_ui and(height/6+168-height/2)or 100,200);log('MC_J_OPTIONS_OPEN page='..page..' buttons='..#buttons)
 end
 function O:click(env,x,y)
  x,y=x/3,y/3;if mode=='Skins'then skins:click(x,y);return end
  for _,b in ipairs(buttons or{})do if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+20 then
   local a=b.action;local s=self:settings()
   if a=='native'then self:native(env);return
   elseif a=='language_en'or a=='language_ko'then UE.language57:set(a=='language_en'and'en'or'ko');self:show(env,mode,nodes,owner);log('MC57_LANGUAGE_SELECTED '..UE.language57.lang);return
   elseif a=='mcvolume'then ctx.config.mc_sound_volume=math.max(0,math.min(1,(x-b.x-4)/(b.w-8)));self:saveMod()
   elseif a=='gui'then ctx.config.gui_scale=((ctx.config.gui_scale or 0)+1)%5;self:saveMod();if ctx.config.task20_ui then ctx.phaseA:applyScale(env)end
   elseif a=='hud'then ctx.phaseA:toggle();self:saveMod()
   elseif a=='fps'then local old=s:GetFrameRateLimit();self:nativeChange('SetFrameRateLimit',old<60 and 60 or old<120 and 120 or old<240 and 240 or 30)
   elseif a=='quality'then self:nativeChange('SetOverallScalabilityLevel',(s:GetOverallScalabilityLevel()+1)%4)
   elseif a=='aa'then self:nativeChange('SetAntiAliasingQuality',(s:GetAntiAliasingQuality()+1)%4)
   elseif a=='distance'then self:nativeChange('SetViewDistanceQuality',(s:GetViewDistanceQuality()+1)%4)
   elseif a=='window'then self:nativeChange('SetFullscreenMode',(s:GetFullscreenMode()+1)%3)
   else ctx.menu:show(env,a,owner);return end
   self:show(env,mode,nodes,owner);return
  end end
 end
 function O:cancel()skins:hide();nodes,buttons,owner=nil,nil,nil end
 function O:hover(x,y)
  x,y=x/3,y/3;if mode=='Skins'then skins:hover(x,y);return end
  for i,b in ipairs(buttons or{})do local hover=x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h
   local token=hover and 'highlighted' or 'normal'
   if b.hover~=token then b.hover=token;U:brush(nodes['Button'..i],b.slider and'T_MC_UI_widget_slider'or(hover and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button'))
    if b.slider then U:brush(nodes['Handle'..i],hover and'T_MC_UI_widget_slider_handle_highlighted'or'T_MC_UI_widget_slider_handle')end
   end
  end
 end
 dofile(ctx.base..'/timers.lua').onEpoch('options',function()nodes,mode,buttons,owner=nil,nil,nil,nil end)
 return O
end
