-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx)
    local Timers=dofile(ctx.base..'/timers.lua')
    local UE,valid,log=ctx.UE,ctx.valid,ctx.log
    local nativeG=dofile(ctx.base..'/native_widgetG.lua')(UE,valid)
    local nativeInputG4=dofile(ctx.base..'/native_inputG4.lua')(ctx,nativeG);UE.nativeInputG4=nativeInputG4
    local D={open=false,selected=1,footers={}};local widget,nodes,root,mode,handle,stamp;local uiSerial=0
    local cursorG=dofile(ctx.base..'/cursorG.lua')(ctx,D,nativeG)
    local assets,names={},{ };local icons=dofile(ctx.base..'/native_icons.lua');local lower={};for n,p in pairs(icons)do lower[n:lower()]=p end
    local function str(v)return type(v)=='string'and v or v:ToString()end
    local function text(n,s)if valid(n)then if ctx.uiKit and ctx.uiKit.putText then ctx.uiKit:putText(n,s)else n:SetText(UE.GetKismetTextLibrary():Conv_StringToText(tostring(s)))end end end
    local function asset(p)
        if type(p)~='string'or p==''then return end
        if valid(assets[p])and UE.AssetMatchesRA(assets[p],p) then return assets[p]end
        local begun=os.clock()
        if valid(assets[p])then log('MC_STALE_CACHE phase-d MC_20_SCREEN_ASSET_CACHE_REPAIRED '..p..' previous='..assets[p]:GetFullName())end
        local o=StaticFindObject(p)
        if not valid(o)then local package,name=p:match('^(.*)%.([^%.]+)$');o=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(package),AssetName=UE.FindOrAddFName(name)})end
        if valid(o)and UE.AssetMatchesRA(o,p) then assets[p]=o;log(string.format('MC109_MENU_ASSET ms=%.3f path=%s',(os.clock()-begun)*1000,p));return o end
    end
    local function icon(node,path)if valid(node)then local a=path and asset(path);node:SetVisibility(valid(a)and 3 or 1);if valid(a)then if ctx.uiKit and path:match('/T_MC_E[%w]+%.')then ctx.uiKit:brush(node,'T_MC_UI_slot',{1/18,1/18})elseif ctx.config.task20_ui then ctx.uiKit:icon(node,a)else node:SetBrushFromTexture(a,false)end end end end
    local function unpackObject(v)local ok,o=pcall(function()return v:get()end);return ok and o or v end
    local function array(v)local t={};if type(v)=='table'then for _,x in ipairs(v)do t[#t+1]=unpackObject(x)end else v:ForEach(function(_,x)t[#t+1]=x:get()end)end;return t end
    local function nativeText(env,method,id)
        local key=method..':'..tostring(id);if names[key]then return names[key]end
        local out={};local u=UE.Object('/Script/Pal.Default__PalUIUtility');u[method](u,env.player,id,out)
        local s=out.outName and str(UE.GetKismetTextLibrary():Conv_TextToString(out.outName))or tostring(id);names[key]=s;return s
    end
    local E=dofile(ctx.base..'/phase_e.lua')(ctx,{text=text,icon=icon,asset=asset,nativeText=nativeText});D.extra=E
    local F=dofile(ctx.base..'/phase_f.lua')(ctx,{text=text,icon=icon,asset=asset,nativeText=nativeText});D.features=F
    local S67=dofile(ctx.base..'/screens67.lua')(ctx,D,E,F,{asset=asset});D.screens67=S67
    ctx.uiKit.character67=dofile(ctx.base..'/character67.lua')(ctx)
    UE.ui67={screens=S67,character=ctx.uiKit.character67,kit=ctx.uiKit}
    local A=dofile(ctx.base..'/armor_visuals.lua')(ctx,{asset=asset});D.armor=A
    ctx.nativeBase=function()local env=ctx.active();local native=root;D.nativeBypass=true;D:close(false);env.controller.bShowMouseCursor=true;UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameAndUIEx(env.controller,native,0,false,false)end
    local H=dofile(ctx.base..'/base_overview.lua')(ctx,{text=text,icon=icon,asset=asset,nativeText=nativeText});D.baseScreen=H
    ctx.menu=D;local O=ctx.uiKit and dofile(ctx.base..'/options.lua')(ctx);D.options=O
    function D:createElementIcons(env)
        self.elementWidgets={};local class=StaticFindObject('/Game/Pal/Blueprint/UI/CommonWidget/PalStatusParts/WBP_PalElementIcon.WBP_PalElementIcon_C')
        assert(valid(class),'Native type-icon class unavailable')
        for i=1,2 do
            local w=UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(env.player,class,env.controller)
            assert(valid(w));local slot=nodes.CanvasPanel_0:AddChildToCanvas(w)
            local f=self.uiFactor or 1;slot:SetAnchors({Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}});slot:SetPosition({X=(380+(i-1)*45)*f,Y=-155*f});slot:SetSize({X=35*f,Y=35*f})
            self.elementWidgets[i]=w
        end
    end
    function D:hideFooter(env,hide)
        local function isWidget(node)
            if not valid(node)then return false end
            local ok,yes=pcall(function()return node:IsA(UE.Object('/Script/UMG.Widget'))end)
            return ok and yes
        end
        if self.footerApplied==hide then return end;self.footerApplied=hide
        if hide then
            if not self.footerScanned then
                self.footerScanned=true
                for _,w in ipairs(FindAllOf('UserWidget')or{})do if valid(w)and w:GetFullName():find('/Engine/Transient',1,true)then
                    local name=w:GetClass():GetFullName():lower()

                    local sharedInputIcon=name:find('wbp_palkeyguideicon.',1,true)or name:find('wbp_playerinputkeyguideicon.',1,true)
                    if not sharedInputIcon and(name:find('keyguide',1,true)or name:find('key_guide',1,true)or name:find('inputguide',1,true)or name:find('palactionbar',1,true)or(ctx.config.task20_ui and(name:find('quest',1,true)or name:find('notification',1,true)or name:find('pickup',1,true)or name:find('itemget',1,true))))then self.footers[#self.footers+1]={node=w,opacity=w:GetRenderOpacity()}end
                    if name:find('overalluilayout',1,true)or name:find('mainmenu_bg',1,true)then
                    for name,node in pairs(ctx.uiWidgets(w))do
                        local n=name:lower();if name==n and isWidget(node)and(n:find('keyguide',1,true)or n:find('key_guide',1,true)or n:find('footer',1,true)or n:find('keyguides',1,true)or n=='ingamemenu_foot')then self.footers[#self.footers+1]={node=node,opacity=node:GetRenderOpacity()}end
                    end
                    end
                end end
                log('MC_D_FOOTERS count='..#self.footers)
            end
            for _,e in ipairs(self.footers)do if isWidget(e.node)then e.node:SetRenderOpacity(0)end end
        else for _,e in ipairs(self.footers)do if isWidget(e.node)then e.node:SetRenderOpacity(e.opacity)end end;self.footers={};self.footerScanned=false;self.footerApplied=nil end
    end
    function D:previewStart(env,image)
        if not valid(image)then return end
        self.previewImage=image;self.previewPaused=nil;self:previewTick(env)
    end
    function D:previewTick(env)
        if self.previewPaused or not valid(self.previewImage)then return end
        local choice=ctx.steve.choice
        if self.previewChoiceZ1~=choice or self.previewEpoch~=ctx.epoch()or not valid(self.portraitZ1)then
            local ok,texture,path,hash=pcall(ctx.steve.library71.portrait,ctx.steve.library71,env,choice)
            if not ok then log('MCZ1_PORTRAIT_ERROR '..tostring(texture));return end
            self.portraitZ1=texture;self.previewChoiceZ1=choice;self.previewEpoch=ctx.epoch()
            self.portraitPathZ1=path;self.portraitHashZ1=hash
            ctx.uiKit:retainTexture(texture)
            log('MCZ1_STATIC_PORTRAIT file='..choice.file..' hash='..tostring(hash or 'placeholder')..' capture=false overlay=true')
        end
        if self.previewAppliedZ1~=self.previewImage or self.previewAppliedTextureZ1~=self.portraitZ1 then
            self.previewImage:SetBrushFromTexture(self.portraitZ1,false)
            self.previewAppliedZ1=self.previewImage;self.previewAppliedTextureZ1=self.portraitZ1
        end
    end
    function D:previewStop(park)
        self.previewPaused=true;self.previewImage=nil;self.previewAppliedZ1=nil
        if not park then self.portraitZ1=nil;self.previewChoiceZ1=nil;self.previewEpoch=nil;self.previewAppliedTextureZ1=nil end
    end
    function D:party(env)
        local holder=env.controller.BP_OtomoPalHolderComponent;local slots={};_G.MC_OUT_K('GetSlots',holder,slots);local selected
        if ctx.config.task20_ui then
            local signature={tostring(nodes.Name:GetAddress()),tostring(self.selected),tostring(self.detailTab or 1)}
            for i=1,5 do local slot=slots[i]and unpackObject(slots[i]);local d=valid(slot)and slot.ReplicateIndividualParameter
                if valid(d)then
                    signature[#signature+1]=table.concat({d:GetCharacterID():ToString(),str(d.SaveParameter.NickName),d:GetLevel(),d:GetExp(),d:GetHP().Value,d:GetShotAttack(),d:GetDefense(),d:GetCraftSpeed(),d:GetGenderType(),math.floor(d:GetFullStomachRate()*100),math.floor(d:GetSanityRate()*100),d:GetPhysicalHealth()},':')
                else signature[#signature+1]='empty'end
            end
            local key=table.concat(signature,'|');if self.partyPaintSignature==key then return end;self.partyPaintSignature=key
        end
        for i=1,5 do local slot=slots[i]and unpackObject(slots[i]);local d=valid(slot)and slot.ReplicateIndividualParameter
            nodes['Party'..i]:SetBrushColor(ctx.config.task20_ui and(i==self.selected and{R=1,G=1,B=1,A=1}or{R=.7,G=.7,B=.7,A=1})or(i==self.selected and{R=.25,G=.45,B=.2,A=.9}or{R=.1,G=.1,B=.1,A=.9}))
            if valid(d)then
                local id=d:GetCharacterID():ToString();local out={};_G.MC_OUT_K('GetDisplayNickName',UE.Object('/Script/Pal.Default__PalUIUtility'),env.player,UE.FindOrAddFName(id),UE.FindOrAddFName('None'),out)
                local name=str(d.SaveParameter.NickName);if name==''then name=out.OutNickName and str(out.OutNickName)or id end
                text(nodes['PalName'..i],ctx.config.task20_ui and name or name..'   Lv '..d:GetLevel());nodes['PalHP'..i]:SetPercent(d:GetHP().Value/(1000*math.max(1,d:GetMaxHP())));icon(nodes['PalIcon'..i],lower[('T_'..id..'_icon_normal'):lower()])
                if i==self.selected then selected={d=d,id=id,name=name}end
            else text(nodes['PalName'..i],ctx.config.task20_ui and'-'or'Empty');nodes['PalHP'..i]:SetPercent(0);icon(nodes['PalIcon'..i],nil)end
        end
        self.partySelected=selected;if ctx.config.task20_ui then text(nodes.Label4,'Done')end
        if not selected then
            if ctx.config.task20_ui then ctx.uiKit:view(nodes,env,248,180)end
            text(nodes.Name,'Empty party slot');icon(nodes.Portrait,nil);nodes.Exp:SetPercent(0)
            for _,n in ipairs({'Level','Stats','Condition','Passive','Skills','Work','Elements'})do text(nodes[n],'')end
            for _,w in ipairs(self.elementWidgets or{})do w:SetVisibility(1)end;if ctx.config.task20_ui then for _,n in ipairs({'Condition','Passive','Skills','Work'})do nodes[n]:SetVisibility(1)end end;return
        end
        local d,id=selected.d,selected.id;local lv,xp=d:GetLevel(),d:GetExp();local db=UE.Object('/Script/Pal.Default__PalUtility'):GetExpDatabase(env.player);local low,high=db:GetTotalExp(lv,false),db:GetTotalExp(lv+1,false)
        text(nodes.Name,selected.name..' ('..id..')');icon(nodes.Portrait,lower[('T_'..id..'_icon_normal'):lower()]);text(nodes.Level,'Lv '..lv..'   EXP '..xp..'/'..high..'   '..({[0]='Unknown gender','Male','Female'})[d:GetGenderType()]);nodes.Exp:SetPercent(math.max(0,math.min(1,(xp-low)/math.max(1,high-low))))
        text(nodes.Stats,string.format('HP %.0f / %d   Attack %d   Defense %d\nWork speed %d',d:GetHP().Value/1000,d:GetMaxHP(),d:GetShotAttack(),d:GetDefense(),d:GetCraftSpeed()))
        text(nodes.Condition,string.format('Hunger %.0f%%   Sanity %.0f%%   %s',d:GetFullStomachRate()*100,d:GetSanityRate()*100,({[0]='Healthy','Minor injury','Severe injury','Dying','Dead','Cloud cemetery'})[d:GetPhysicalHealth()]or'Unknown condition'))
        local passive={};for _,name in ipairs(array(d.SaveParameter.PassiveSkillList))do passive[#passive+1]=nativeText(env,'GetPassiveSkillName',name)end;text(nodes.Passive,'Passive skills: '..(#passive>0 and table.concat(passive,', ')or'None'))
        local wdb=UE.Object('/Script/Pal.Default__PalUtility'):GetWazaDatabase(env.player)
        local skills,skillRows={},{};for _,skill in ipairs(array(d:GetEquipWaza()))do
            local out={};assert(_G.MC_OUT_K('FindWazaForBP',wdb,skill,out),'Native skill unavailable');local row=out.OutData or out
            skills[#skills+1]=nativeText(env,'GetWazaName',skill)..'  '..nativeText(env,'GetPalElementTypeName',row.Element)..'  Power '..row.Power
            skillRows[#skillRows+1]={name=nativeText(env,'GetWazaName',skill),element=row.Element,elementLabel=nativeText(env,'GetPalElementTypeName',row.Element),power=row.Power}
        end;text(nodes.Skills,'Active skills: '..table.concat(skills,'\n'))
        local works,workRows={},{}
        for i=1,13 do local rank=d:GetWorkSuitabilityRank(i);if rank>0 then works[#works+1]=nativeText(env,'GetWorkSuitabilityName',i)..' '..rank;workRows[#workRows+1]={id=i,name=nativeText(env,'GetWorkSuitabilityName',i),rank=rank}end end;text(nodes.Work,'Work: '..table.concat(works,', '))
        local e1,e2={},{};UE.Object('/Script/Pal.Default__PalUtility'):GetDatabaseCharacterParameter(env.player):GetElementType(UE.FindOrAddFName(id),e1,e2)
        local elements,typeRows={},{};for i,e in ipairs({e1.Element1 or 0,e2.Element2 or 0})do
            if valid(self.elementWidgets[i])then self.elementWidgets[i]:SetElement(e);self.elementWidgets[i]:SetVisibility(e>0 and 3 or 1)end
            if e>0 and e<10 then elements[#elements+1]=nativeText(env,'GetPalElementTypeName',e);typeRows[#typeRows+1]={label=nativeText(env,'GetPalElementTypeName',e),element=e}end
        end
        text(nodes.Elements,'Types: '..table.concat(elements,' / '))
        if ctx.config.task20_ui then text(nodes.Name,selected.name);text(nodes.Level,tostring(xp)..' / '..high);text(nodes.Stats,string.format('HP %.0f/%d\nAttack %d\nDefense %d\nWork %d',d:GetHP().Value/1000,d:GetMaxHP(),d:GetShotAttack(),d:GetDefense(),d:GetCraftSpeed()));text(nodes.Label4,'Done');for _,w in ipairs(self.elementWidgets or{})do w:SetVisibility(1)end
            local tab=self.detailTab or 1;nodes.Condition:SetVisibility(tab==1 and 3 or 1);nodes.Passive:SetVisibility(1);nodes.Skills:SetVisibility(tab==2 and 3 or 1);nodes.Work:SetVisibility(tab==3 and 3 or 1);text(nodes.Skills,table.concat(skills,'\n')..(#passive>0 and('\n'..table.concat(passive,', '))or''));local header=nodes.GuiHeader;local hex=({[1]='555555',[2]='AA0000',[3]='0000AA',[4]='00AA00',[5]='AAAA00',[6]='00AAAA',[7]='AA5500',[8]='550055',[9]='AA00AA'})[e1.Element1 or 1]or'555555';ctx.uiKit:fill(header,hex)
            ctx.uiKit:palDetails(nodes,env,d,selected.name,tab,skillRows,workRows,passive,typeRows)
        end
        log('MC_D_PAL_SNAPSHOT id='..id..' hp='..d:GetHP().Value..' active='..#skills..' passive='..#passive..' work='..#works)
    end
    function D:restoreDeath()
        for _,e in ipairs(self.deathHidden or{})do if valid(e.node)then e.node:SetRenderOpacity(e.opacity)end end
        self.deathHidden={};self.deathScanAt=nil
    end
    function D:respawnList(env)
        self:show(env,'Respawn',nil)
        local _,unit=ctx.uiKit:metrics(env);ctx.uiKit:position(nodes.Title,-110,-105,220,15,unit);text(nodes.Title,'Choose Respawn Point')
        self.respawnRows={};local loc=ctx.beds:destination(env)
        if loc then self.respawnRows[#self.respawnRows+1]={label='Red Bed',bed=true}end
        self.respawnRows[#self.respawnRows+1]={label='Native respawn',bed=false}
        self.respawnRows[#self.respawnRows+1]={label='Back',back=true}
        for i=1,9 do local row=self.respawnRows[i];nodes['Button'..i]:SetVisibility(row and 3 or 1);nodes['Label'..i]:SetVisibility(row and 3 or 1)
            if row then local y=-54+(i-1)*24;ctx.uiKit:position(nodes['Button'..i],-100,y,200,20,unit);ctx.uiKit:position(nodes['Label'..i],-100,y+4,200,14,unit);nodes['Label'..i]:SetJustification(1);text(nodes['Label'..i],row.label)end
        end
        log('MC25_RESPAWN_LIST_OPEN rows='..#self.respawnRows..' bed='..tostring(loc~=nil))
    end
    function D:hideDeath(current)
        self.deathHidden=self.deathHidden or{};local seen={}
        for _,e in ipairs(self.deathHidden)do if valid(e.node)then seen[e.node:GetAddress()]=true;e.node:SetRenderOpacity(0)end end
        if self.deathScanAt and os.clock()<self.deathScanAt then return end;self.deathScanAt=os.clock()+1
        for _,w in ipairs(FindAllOf('UserWidget')or{})do if valid(w)and w:GetFullName():find('/Engine/Transient',1,true)then
            local s=w:GetClass():GetFullName():lower()
            if not s:find('/minecraftblocks/',1,true)and(s:find('gameover',1,true)or s:find('playerdead',1,true)or s:find('deathscreen',1,true)or s:find('deathannounce',1,true)or s:find('dying',1,true)or s:find('defeat',1,true)or s:find('revive',1,true)or s:find('respawn',1,true))then
                if not seen[w:GetAddress()]then self.deathHidden[#self.deathHidden+1]={node=w,opacity=w:GetRenderOpacity()};w:SetRenderOpacity(0);log('MC24_DEATH_HIDE '..w:GetClass():GetFullName())end
            end
        end end
    end
    function D:close(deactivate,keepParent)
        if not self.open then return end;local env=ctx.environment();self.open=false
        ctx.items.escapeUntil=os.clock()+.5
        if mode=='Death'or mode=='Respawn'then self:restoreDeath()end
        ctx.uiKit:releaseInput(widget)
        uiSerial=uiSerial+1;Timers.cancel(handle);handle=nil;self.escapeDue=nil;self.escapeDirty=nil;self.pendingNav46=nil;if valid(widget)then ctx.hideUI(widget)end
        if env then self:hideFooter(env,ctx.phaseA.visible);if valid(root)then root:SetRenderOpacity(self.rootOpacity);if self.backHandler58~=nil then root.bIsBackHandler=self.backHandler58;self.backHandler58=nil end;if self.nativeEnabled61~=nil then root:SetIsEnabled(self.nativeEnabled61);self.nativeEnabled61=nil end;if deactivate~=false then nativeG:closeOwned(root,env.controller)end end
            if not keepParent then env.controller:ResetIgnoreMoveInput();env.controller:ResetIgnoreLookInput();if mode~='Death'then env.controller.bShowMouseCursor=false;UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(env.controller,false)end end
        end
        if self.parentHidden and valid(self.parentHidden.node)then local parent=self.parentHidden.node;parent:SetRenderOpacity(self.parentHidden.opacity);if not keepParent and env then nativeG:closeOwned(parent,env.controller)end end;self.parentHidden=nil
        S67:close();E:cancel();F:cancel();H:cancel();if O then O:cancel()end;widget,nodes,root,mode=nil,nil,nil,nil;self.nodes46=nil;self.uiOffset46=0;self.uiFactor=nil;log('MC_D_MENU_CLOSED')
        local serial,epoch=uiSerial,ctx.epoch()
        Timers.after(350,function()
            if serial~=uiSerial or epoch~=ctx.epoch()or ctx.quiesced()or self.open or ctx.items.open or self.nativeBypass then return end
            local current=ctx.environment();if not current or current.controller:GetPalPlayerState():IsPlayerDead()then return end

            if nativeInputG4:blocksMenu()or(self.nativeVisibleG and not self.nativeEscapeG)then return end
            local closed=nativeG:releaseMain(current.controller)
            log('MCG4_NATIVE_STACK_RELEASE closed='..#closed)
            self:hideFooter(current,ctx.phaseA.visible)
            current.controller:ResetIgnoreMoveInput();current.controller:ResetIgnoreLookInput();current.controller.bShowMouseCursor=false
            UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(current.controller,true);log('MC46_MENU_GAME_INPUT_READY')
        end,'menu-close-input')
    end
    function D:show(env,kind,owner)
        if self.open then self:close(false,true)end;if ctx.items.open then ctx.items:close()end
        self.partyPaintSignature=nil;self.editRecovery61=nil
        if kind=='Pals'then local slots={};_G.MC_OUT_K('GetSlots',env.controller.BP_OtomoPalHolderComponent,slots);local selected=slots[self.selected]and unpackObject(slots[self.selected]);if not valid(selected)or not valid(selected.ReplicateIndividualParameter)then for i=1,5 do local s=slots[i]and unpackObject(slots[i]);if valid(s)and valid(s.ReplicateIndividualParameter)then self.selected=i;break end end end end
        local option=kind=='Options'or kind=='Video'or kind=='Sounds'or kind=='Controls'or kind=='Language'or kind=='Skins'
        local result=ctx.createUI(env,option and'WBP_MCOptions'or(kind=='Game'or kind=='Respawn')and'WBP_MCGameMenu'or kind=='Pals'and'WBP_MCPals'or kind=='PC'and'WBP_MCPC'or kind=='Base'and'WBP_MCBase'or kind=='Technology'and'WBP_MCTechnology'or kind=='Production'and'WBP_MCProduction'or kind=='Palpedia'and'WBP_MCPalpedia'or'WBP_MCDeath','inventory');assert(result)
        self.uiFactor=result.uiFactor
        widget,nodes,root,mode=result.widget,result.nodes or ctx.uiWidgets(result.widget),owner,kind;self.mode=kind;self.open=true;stamp=ctx.epoch()
        ctx.phaseA:setLife('alive')
        local cachedDex=kind=='Palpedia'and result.reused and nodes.dex55 and nodes.dex55.epoch==ctx.epoch()
        self.nodes46=nodes;self.uiOffset46=(kind=='PC'or kind=='Palpedia')and 14 or 0
        if not cachedDex then widget:SetRenderTranslation({X=0,Y=self.uiOffset46*(self.uiFactor or 1)*3});if valid(nodes.Dim)then nodes.Dim:SetRenderTranslation({X=0,Y=-self.uiOffset46*(self.uiFactor or 1)*3})end;if ctx.uiKit and not S67:supports(kind)then ctx.uiKit:navTabs(nodes,env,kind)end end
        if not S67:supports(kind)then ctx.uiKit:repairNav58(nodes)end
        if valid(root)then self.rootOpacity=root:GetRenderOpacity();root:SetRenderOpacity(0);if kind=='Production'then self.backHandler58=root.bIsBackHandler;root.bIsBackHandler=false;self.nativeEnabled61=root:GetIsEnabled();root:SetIsEnabled(false);log('MC61_NATIVE_PRODUCTION_INPUT_PARKED ticking=true')end end
        if kind=='Technology'or(kind=='Palpedia'and not cachedDex)then local parent=self:nativeRoot(env);if valid(parent)and (not valid(root)or parent:GetAddress()~=root:GetAddress())then self.parentHidden={node=parent,opacity=parent:GetRenderOpacity()};parent:SetRenderOpacity(0)end end
        env.controller.bShowMouseCursor=true;env.controller:SetIgnoreMoveInput(true);env.controller:SetIgnoreLookInput(true)
        ctx.uiKit:ownInput(env,widget,{nodes.Search,nodes.Ui20Search});self:hideFooter(env,true)
        if S67:supports(kind)then widget:SetRenderTranslation({X=0,Y=0});if valid(nodes.Dim)then nodes.Dim:SetRenderTranslation({X=0,Y=0})end;S67:show(env,kind,nodes,root)
        elseif option then O:show(env,kind,nodes,root)elseif kind=='Base'then H:show(env,nodes,root)elseif kind=='Production'then F:show(env,kind,nodes,root)elseif kind=='Death'then text(nodes.Level,'Level: '..env.player.CharacterParameterComponent:GetIndividualParameter():GetLevel())end
        uiSerial=uiSerial+1;local ownedSerial,ownedStamp=uiSerial,stamp
        local tick=0;handle=Timers.loop(100,function()
            if ctx.config.task20b_disable_d_pollers or ownedSerial~=uiSerial or ownedStamp~=ctx.epoch()or ctx.quiesced()then return true end;if ctx.busy()then return false end
            local current=ctx.environment();if not current or not self.open then return true end
            tick=tick+1;local ok,err=pcall(function()

                local anchorActive=valid(root)and nativeG:active(root)
                if anchorActive then self.editRecovery61=nil end
                if valid(root)and mode~='Palpedia'and root~=self.paldex51 and not anchorActive then

                    if mode=='Production'and ctx.uiKit:editing()and not self.editRecovery61 then
                        self.editRecovery61=true;root:ActivateWidget();root:SetRenderOpacity(0);root:SetIsEnabled(false);root.bIsBackHandler=false
                        log('MC61_PRODUCTION_EDIT_ANCHOR_REACTIVATED once_per_deactivation=true')
                    else self:close(false);return end
                end
                self.uiTicks=tick
                if S67:supports(mode)then S67:tick(current);self:hideFooter(current,true);return end
                if mode=='PC'or mode=='Technology'then E:tick(current,tick)end
                if mode=='Base'then H:tick(current,tick)end
                if mode=='Production'or mode=='Palpedia'then F:tick(current,tick)end
                if mode=='Pals'and tick%10==0 then self:party(current)end
                if ctx.uiKit then local x,y=ctx.items:mouse(current);if option then O:hover(x,y)else ctx.uiKit:hoverButtons(nodes,kind=='Game'and'WBP_MCGameMenu'or kind=='Death'and'WBP_MCDeath'or kind=='Pals'and'WBP_MCPals'or'',x,y);self:hover46(current,x,y);ctx.uiKit:navHover(nodes,current,x/3,y/3)end end
                self:hideFooter(current,true)
            end);if not ok then log('MC_D_ERROR poll '..tostring(err));self:close();return true end;return not self.open
        end);log('MC_D_MENU_OPEN mode='..kind)
    end
    function D:prebuild(env,result,name)
        if self.open or ctx.items.open then return end
        local kinds={WBP_MCGameMenu='Game',WBP_MCPals='Pals',WBP_MCPC='PC',WBP_MCTechnology='Technology',WBP_MCPalpedia='Palpedia'}
        local kind=kinds[name];if not kind then return end
        nodes=result.nodes;widget=result.widget;mode=kind;self.uiFactor=result.uiFactor;self.nodes46=nodes
        self.uiOffset46=(kind=='PC'or kind=='Palpedia')and 14 or 0
        widget:SetRenderTranslation({X=0,Y=self.uiOffset46*(self.uiFactor or 1)*3})
        if valid(nodes.Dim)then nodes.Dim:SetRenderTranslation({X=0,Y=-self.uiOffset46*(self.uiFactor or 1)*3})end
        if ctx.uiKit then ctx.uiKit:navTabs(nodes,env,kind)end
        if S67:supports(kind)and(kind~='Palpedia'or valid(self.paldex51))then widget:SetRenderTranslation({X=0,Y=0});S67:show(env,kind,nodes,self.paldex51);S67:close()
        elseif kind=='Pals'then self:createElementIcons(env);self:party(env)
        elseif kind=='PC'or kind=='Technology'then E:show(env,kind,nodes)
        elseif kind=='Palpedia'and valid(self.paldex51)then F:show(env,kind,nodes,self.paldex51)end
        E:cancel();F:cancel();widget,nodes,root,mode=nil,nil,nil,nil;self.nodes46=nil
        ctx.hideUI(result.widget);result.used=true;log('MC51_SCREEN_PRIMED kind='..kind)
    end
    function D:nativeRoot(env)
        for _,w in ipairs(FindAllOf('WBP_InGameMainMenu_C')or{})do if nativeG:mainRoot(w,env.controller)and nativeG:active(w,env.controller)then ctx.items.nativeMenu61=w;return w end end
        local cached=ctx.items.nativeMenu61
        if nativeG:activatable(cached)and cached:GetClass():GetFullName():find('WBP_InGameMainMenu_C',1,true)then local pc=cached:GetOwningPlayer();if valid(pc)and pc:GetAddress()==env.controller:GetAddress()then return cached end end
        for _,w in ipairs(FindAllOf('WBP_InGameMainMenu_C')or{})do if valid(w)and nativeG:active(w)and w:GetOwningPlayer():GetAddress()==env.controller:GetAddress()then return w end end
    end
    function D:navigate46(kind)
        local env=ctx.environment();if not env then return end
        ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2)
        if kind=='Inventory'then self:close(false,true);ctx.items:requestOpen(2);return end
        if kind~='Palpedia'then self:show(env,kind,root);return end
        
        if F.catalog55 and F.catalog55.epoch==ctx.epoch()then self:show(env,'Palpedia',nil);return end

        if self.pendingNav46 then return end;self.pendingNav46=true
        local r=self:nativeRoot(env)
        if not valid(r)or not nativeG:active(r)then
            for _,listener in ipairs(FindAllOf('WBP_PalHUD_InGame_InputListener_C')or{})do
                if valid(listener)and listener:GetOwningPlayer():GetAddress()==env.controller:GetAddress()then listener:OnTriggerEscape();break end
            end
        end
        r=self:nativeRoot(env);if valid(r)then r:SetRenderOpacity(0)end
        self.footerScanned=false;self.footerApplied=nil;self:hideFooter(env,true)
        local expected=ctx.epoch();local tries,selected=0,false
        Timers.loop(33,function()
            if expected~=ctx.epoch()or ctx.quiesced()or not self.pendingNav46 then self.pendingNav46=nil;return true end;tries=tries+1
            local current=ctx.environment();if not current then return false end
            local parent=self:nativeRoot(current)
            if valid(parent)then parent:SetRenderOpacity(0)
                if nativeG:active(parent)and not selected then parent:SelectPaldexTab();selected=true end
            end
            if tries<=6 then self.footerScanned=false;self.footerApplied=nil;self:hideFooter(current,true)end
            for _,w in ipairs(FindAllOf('WBP_Paldex_ForDisplay_C')or{})do
                if valid(w)and nativeG:active(w)and w:GetOwningPlayer():GetAddress()==current.controller:GetAddress()then
                    w:SetRenderOpacity(0);self.paldex51=w;self.pendingNav46=nil;self:show(current,'Palpedia',w);return true
                end
            end
            if tries>=90 then self.pendingNav46=nil;log('MC46_PALPEDIA_ROUTE_EXPIRED');return true end;return false
        end,'nav-palpedia')
    end
    function D:request(kind)
        if self.open then self:close();return end;local env=ctx.active();if not ctx.gameplayInput(env)then return end
        self.intent=kind;for _,w in ipairs(FindAllOf('WBP_PalHUD_InGame_InputListener_C')or{})do if valid(w)and w:GetOwningPlayer():GetAddress()==env.controller:GetAddress()then w:OnTriggerEscape();return end end
    end
    function D:hover46(env,x,y)
        local tip;local xx,yy=x/3,y/3;local _,unit=ctx.uiKit:metrics(env)
        local control=ctx.uiKit:controls54(nodes,env,mode,xx,yy,self)
        if mode=='Pals'then
            if xx>=6-124 and xx<80-124 and yy>=17-90 and yy<155-90 then
                local i=math.floor((yy+73)/28)+1;local slots={};_G.MC_OUT_K('GetSlots',env.controller.BP_OtomoPalHolderComponent,slots);local slot=slots[i]and unpackObject(slots[i]);local d=valid(slot)and slot.ReplicateIndividualParameter
                if valid(d)then local id=d:GetCharacterID():ToString();local out={};_G.MC_OUT_K('GetDisplayNickName',UE.Object('/Script/Pal.Default__PalUIUtility'),env.player,UE.FindOrAddFName(id),UE.FindOrAddFName('None'),out);tip={title=out.OutNickName and str(out.OutNickName)or id,source='Palworld',lines={'Lv '..d:GetLevel(),string.format('HP %.0f / %d',d:GetHP().Value/1000,d:GetMaxHP()),'Attack '..d:GetShotAttack()..'  Defense '..d:GetDefense()},exclude={x=6-124,y=17-90+(i-1)*28,w=74,h=26}}end
            end
            for i=1,3 do local hover=xx>=88-124+(i-1)*52 and xx<138-124+(i-1)*52 and yy>=110-90 and yy<124-90;ctx.uiKit:brush(nodes['GuiDetailTab'..i],i==(self.detailTab or 1)and'T_MC_UI_widget_button_disabled'or hover and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button')end
            for _,r in ipairs(nodes.pal54Rects or{})do if xx>=r.x and xx<r.x+r.w and yy>=r.y and yy<r.y+r.h then tip={title=r.title,source='Palworld',lines=r.lines,exclude=r};break end end
            ctx.uiKit:richTooltip(nodes,control or tip,xx,yy,unit)
        end
        if mode~='Pals'and control then ctx.uiKit:richTooltip(nodes,control,xx,yy,unit)end
    end
    function D:nativeShortcut(kind)
        local env=ctx.active();if self.open or ctx.items.open or not ctx.gameplayInput(env)then return end
        if kind=='Technology'then
            for _,w in ipairs(FindAllOf('WBP_PalHUD_InGame_InputListener_C')or{})do if valid(w)and w:GetOwningPlayer():GetAddress()==env.controller:GetAddress()then w:OnTriggerOpenTechnologyMenu();log('MC_G_NATIVE_SHORTCUT Technology');return end end
        else
            self:request('Game');local expected=ctx.epoch();Timers.after(400,function()
                if expected~=ctx.epoch()or ctx.quiesced()then return end;local current=ctx.environment();if not current then return end
                local r=self:nativeRoot(current);if valid(r)then if self.open then self:close(false)end;r:SelectPaldexTab();log('MC_G_NATIVE_SHORTCUT Palpedia')end
            end)
        end
    end
    function D:click(shift,right)
        if not self.open then return end;local env=ctx.active();local x,y=ctx.items:mouse(env);local chosen
        if ctx.config.task20_ui then ctx.uiKit:hideTooltip(nodes)end
        if ctx.uiKit then local nav=ctx.uiKit:navAt(nodes,x/3,y/3);if nav then if nav.kind~=mode then self:navigate46(nav.kind)end;return end end
        if S67:supports(mode)then S67:click(env,x/3,y/3,shift,right);return end
        if right and mode~='Production'and mode~='PC'then return end
        if mode=='Respawn'then
            for i,row in ipairs(self.respawnRows or{})do local y1=-54+(i-1)*24;if x/3>=-100 and x/3<100 and y/3>=y1 and y/3<y1+20 then
                if row.back then self:show(env,'Death',nil)else self:close(false);ctx.beds:respawn(env,row.bed)end;return end end;return
        end
        if O and(mode=='Options'or mode=='Video'or mode=='Sounds'or mode=='Controls'or mode=='Language'or mode=='Skins')then O:click(env,x,y);return end
        if mode=='Pals'and ctx.config.task20_ui then local xx,yy=x/3+124,y/3+90;if yy>=110 and yy<124 and xx>=88 and xx<242 then self.detailTab=math.floor((xx-88)/52)+1;ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);self:party(env);return end;x,y=ctx.uiKit:mapInput('WBP_MCPals',x,y)end
        if mode=='Death'and ctx.config.task20_ui then local _,unit,dpi,size=ctx.uiKit:metrics(env);local yy=y/3+size.Y/(unit*dpi)/2;chosen=(yy>=size.Y/(unit*dpi)/4+72 and yy<size.Y/(unit*dpi)/4+92)and 1 or(yy>=size.Y/(unit*dpi)/4+96 and yy<size.Y/(unit*dpi)/4+116)and 2 or nil end
        if mode=='PC'or mode=='Technology'then E:beginPress(env,x,y,shift);return end
        if mode=='Base'then H:click(env,x,y);return end
        if mode=='Production'or mode=='Palpedia'then F:click(env,x,y,shift,right);return end
        if mode=='Game'and ctx.uiKit then for i,b in pairs(ctx.uiKit.gameButtons)do if x/3>=b[1]and x/3<b[1]+b[3]and y/3>=b[2]and y/3<b[2]+20 then chosen=i;break end end
        elseif mode=='Game'and x>=-300 and x<=300 then for i=1,9 do local yy=-285+(i-1)*78;if y>=yy and y<yy+60 then chosen=i end end
        elseif mode=='Death'and not ctx.config.task20_ui and x>=-300 and x<=300 then if y>=5 and y<65 then chosen=1 elseif y>=85 and y<145 then chosen=2 end
        elseif mode=='Pals'then
            if x>=-570 and x<-250 and y>=-260 and y<240 then self.selected=math.max(1,math.min(5,1+math.floor((y+260)/100)));self:party(env);return end
            if y>=275 and y<335 and x>=-570 and x<-330 then chosen=1
            elseif y>=345 and y<405 then if x>=-570 and x<-420 then chosen=2 elseif x>=-410 and x<-260 then chosen=3 elseif x>=320 and x<=560 then chosen=4 end end
        end
        if not chosen then return end;ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);log('MC_D_MENU_BUTTON mode='..mode..' index='..chosen)
        if mode=='Game'then
            local r=root
            if chosen==1 then self:close()elseif chosen==2 and O then self:show(env,'Skins',r)
            elseif chosen==3 then self:show(env,'Pals',r)
            elseif chosen==4 then self:show(env,'Technology',r)
            elseif chosen==6 then self:show(env,'PC',r)
            elseif chosen==7 and O then self:show(env,'Options',r)
            elseif chosen==5 then self:close();for _,w in ipairs(FindAllOf('WBP_PalHUD_InGame_InputListener_C')or{})do if valid(w)and w:GetOwningPlayer():GetAddress()==env.controller:GetAddress()then w:OnTriggerWorldMap();break end end
            elseif chosen==8 then
                self:quit(env)
            elseif chosen==9 then self:navigate46('Palpedia')
            else self:close(false);if valid(r)then
                local menu=r.WBP_MainMenu;local tab=menu[chosen==4 and'WBP_Tab_02'or chosen==6 and'WBP_Tab_04'or'WBP_Tab_06']
                assert(valid(tab),'Native tab unavailable');menu:SelectByMainMenuType(tab.BindMainMenuType)
                log('MC_D_NATIVE_TAB_REQUESTED button='..chosen..' type='..tab.BindMainMenuType)
            end end
        elseif mode=='Pals'then
            if chosen==1 then if not self.partySelected then log('MC_D_SUMMON_REJECT empty_slot');return end
                local holder=env.controller.BP_OtomoPalHolderComponent;local wanted=self.selected-1
                for _=1,5 do if holder:GetSelectedOtomoID()==wanted then break end;env.controller:OnOtomoChangeIncrement()end
                self:close();env.controller:OnOtomo_Pressed();env.controller:OnOtomo_ShortReleased();log('MC_D_SUMMON_REQUEST selected='..wanted)
            elseif chosen==2 or chosen==3 then self.selected=(self.selected+(chosen==2 and-2 or 0))%5+1;self:party(env)else self:show(env,'Game',root)end
        elseif mode=='Death'then
            self:restoreDeath()
            self:close(false)
            if chosen==1 then ctx.beds:respawn(env,true);log('MC_D_NATIVE_RESPAWN_REQUESTED ui_only=true')
            else self:respawnList(env)end
        end
    end
    function D:quit(env)
        local menu;for _,w in ipairs(FindAllOf('WBP_MenuESC_C')or{})do if valid(w)then local pc=w:GetOwningPlayer();if valid(pc)and pc:GetAddress()==env.controller:GetAddress()then menu=w;break end end end
        if not valid(menu)then

            if self.quitPrepare65b==ctx.epoch()then self.quitPrepare65b=nil;log('MC_D_SAVE_TITLE_REJECT native_menu_not_open');return false end
            self.quitPrepare65b=ctx.epoch();local expected=ctx.epoch()
            local parent=self:nativeRoot(env)
            if valid(parent)then parent:SetRenderOpacity(0);parent['Select Option Tab'](parent)
            else
                for _,w in ipairs(FindAllOf('WBP_PalHUD_InGame_InputListener_C')or{})do if valid(w)then local pc=w:GetOwningPlayer();if valid(pc)and pc:GetAddress()==env.controller:GetAddress()then w:OnTriggerEscape();break end end end
            end
            Timers.after(100,function()
                if expected~=ctx.epoch()or ctx.quiesced()then return end
                local current=ctx.environment();if not current then return end
                local root=self:nativeRoot(current);if valid(root)then root:SetRenderOpacity(0);root['Select Option Tab'](root)end
                self:quit(current)
            end,'native-quit-prepare')
            log('MC65B_NATIVE_QUIT_PREPARE');return true
        end
        self.quitPrepare65b=nil
        UE.loadingCover51:arm(true);UE.loadingCover51:setMessage('Saving world...');UE.loadingCover51:show(env)
        ctx.beginTransition('own-save-quit',false,env)
        local quitEpoch=Timers.epoch
        Timers.after(250,function()
            if Timers.epoch~=quitEpoch or not valid(env.controller)then return end
            for _,w in ipairs(FindAllOf('WBP_MenuESC_C')or{})do if valid(w)then local pc=w:GetOwningPlayer();if valid(pc)and pc:GetAddress()==env.controller:GetAddress()then UE.loadingCover51.saveDispatchedG=true;w:SetVisibility(0);w:ConfirmReturnTitle(true);log('MC_D_NATIVE_SAVE_TITLE_REQUESTED deferred=250 lua_only=true');return end end end
            log('MC_D_SAVE_TITLE_REJECT deferred_native_menu_unavailable')
        end,'native-save-title')
    end
    function D:pollEscape(env)
        local now=os.clock()
        if self.escapeDirty then
            self.escapeDirty=nil
            log('MC_H_NATIVE_ESC open='..tostring(self.open)..' inventory='..tostring(ctx.items.open)..' master_tick=true')
            if not self.escapeDue and not self.open and not ctx.items.open and not self.nativeBypass and not(ctx.items.escapeUntil and now<ctx.items.escapeUntil)then
                self.escapeDue=now;self.escapeSerial=uiSerial;self.escapeEpoch=ctx.epoch()
            end
        end
        if not self.escapeDue or now<self.escapeDue or ctx.busy()then return end
        self.escapeDue=nil
        if self.escapeSerial~=uiSerial or self.escapeEpoch~=ctx.epoch()or ctx.quiesced()or self.open or ctx.items.open or self.nativeBypass or(ctx.items.escapeUntil and now<ctx.items.escapeUntil)then return end
        local r=self:nativeRoot(env)
        local kind=self.intent or'Game';self.intent=nil
        local ok,err=pcall(self.show,self,env,kind,r);if not ok then log('MC_D_ERROR open '..tostring(err))end
    end
    function D:pollNativeRoute58(current)
            if not current.controller.bShowMouseCursor then self.nativeRouteChecked=false;self.nativeRouteAttempts61=0 end
            if not self.open and not ctx.items.open and not self.nativeBypass and current.controller.bShowMouseCursor and not self.nativeRouteChecked then
                local now=os.clock();if now<(self.nativeRouteAt61 or 0)then return end;self.nativeRouteAt61=now+.1
                self.nativeRouteChecked=false
                local routed,reason=pcall(function()
                local function showCandidate(w)
                    if nativeG:active(w,current.controller)and w:GetRenderOpacity()>0 then
                        local n=w:GetClass():GetFullName():lower()
                        if UE.waystones83 and UE.waystones83.open then
                            w:SetRenderOpacity(0);w:DeactivateWidget()
                            ctx.uiKit:ownInput(current,UE.waystones83.widget,{})
                            log('MCE_WAYSTONE_NATIVE_SUPPRESSED '..n);return true
                        end
                        if n:find('palstorage',1,true)or n:find('palbox',1,true)then self:show(current,valid(H:findModel(current))and'Base'or'PC',w);return true
                        elseif n:find('wbp_itemchest.',1,true)then local child=w.WBP_IngameMenu_Chest;if valid(child)and valid(child.TargetContainer)then ctx.items:attachStorage(w,child.TargetContainer);return true end
                        elseif n:find('wbp_ingamemenu_workspace.',1,true)and valid(w['Convert Item Model'])then self:show(current,'Production',w);return true
                        elseif n:find('wbp_paldex_fordisplay.',1,true)then self:show(current,'Palpedia',w);return true
                        elseif n:find('wbp_technologyui.',1,true)then self:show(current,'Technology',w);return true end
                    end
                end
                for _,row in ipairs(self.nativeCandidates61 or{})do if showCandidate(nativeG:resolve(row))then self.nativeRouteChecked=true;return end end

                if (self.nativeRouteAttempts61 or 0)>=2 then self.nativeRouteChecked=true;return end
                self.nativeRouteAttempts61=(self.nativeRouteAttempts61 or 0)+1;self.nativeRouteAt61=now+.25
                self.nativeCandidates61={}
                for _,w in ipairs(FindAllOf('PalActivatableWidget')or{})do if valid(w)then
                    local n=w:GetClass():GetFullName():lower()
                    if n:find('palstorage',1,true)or n:find('palbox',1,true)or n:find('wbp_itemchest.',1,true)or n:find('wbp_ingamemenu_workspace.',1,true)or n:find('wbp_paldex_fordisplay.',1,true)or n:find('wbp_technologyui.',1,true)then local row=nativeG:capture(w);if row then self.nativeCandidates61[#self.nativeCandidates61+1]=row end end
                end end
                for _,row in ipairs(self.nativeCandidates61)do if showCandidate(nativeG:resolve(row))then self.nativeRouteChecked=true;return end
                end
                end);if not routed then self.nativeCandidates61={};self.nativeRouteChecked=true;log('MCG_NATIVE_ROUTE_REJECT '..tostring(reason))end
            end
    end
    function D:start(env)
        nativeInputG4:install()
        F:startCapture(env)
        if not self.routeFrame58 then self.routeFrame58=true;Timers.frame('native-screen-route',function()if ctx.quiesced()then return end;local current=ctx.environment();if current then self:pollNativeRoute58(current);cursorG:tick(current)end end)end

        self.nativeBypass=false
        log('MC109_CATALOGS_LAZY palbox=true palpedia=true')
        if not self.nativeRouteHooks then self.nativeRouteHooks={}
            for _,route in ipairs({{'OnTriggerOpenTechnologyMenu','Technology'},{'OnTriggerOpenPaldex','Palpedia'}})do
                local path='/Game/Pal/Blueprint/UI/WBP_PalHUD_InGame_InputListener.WBP_PalHUD_InGame_InputListener_C:'..route[1]
                if valid(StaticFindObject(path))then local wanted=route[2];self.nativeRouteHooks[#self.nativeRouteHooks+1]=Timers.hook(path,function()
                    if ctx.quiesced()or self.nativeBypass then return end;local expected=ctx.epoch();Timers.after(200,function()
                        if expected~=ctx.epoch()or ctx.quiesced()then return end;local current=ctx.environment();if not current then return end
                        if wanted=='Technology'then for _,w in ipairs(FindAllOf('WBP_TechnologyUI_C')or{})do if valid(w)and nativeG:active(w)and w:GetOwningPlayer():GetAddress()==current.controller:GetAddress()then local ok,err=pcall(self.show,self,current,wanted,w);if not ok then log('MC_D_ERROR native-route '..tostring(err));self:close()end;break end end end
                    end)
                end)end
            end
        end
        local fn='/Game/Pal/Blueprint/UI/WBP_PalHUD_InGame_InputListener.WBP_PalHUD_InGame_InputListener_C:OnTriggerEscape'
        if ctx.config.bpHooks~=false and not self.hooked and valid(StaticFindObject(fn))then
            Timers.hook(fn,function()if self.inputAlive then self.escapeDirty=true end end);self.hooked=true
        end
        self.deadShown=false;local expected=ctx.epoch();self.deathHandle=Timers.loop(500,function()
            if ctx.config.task20b_disable_d_pollers or expected~=ctx.epoch()or ctx.quiesced()then return true end;if ctx.busy()then return false end;local current=ctx.environment();if not current then return false end
            local dead=current.player.CharacterParameterComponent:GetIndividualParameter():IsDead()
            if dead and not self.deadShown then self.deadShown=true;local ok,err=pcall(function()
                self:restoreDeath();self:show(current,'Death',nil);self:hideDeath(current)
            end);if not ok then log('MC_D_ERROR death '..tostring(err))end
            elseif not dead then self.deadShown=false;if self.open and(mode=='Death'or mode=='Respawn')then self:close(false)else self:restoreDeath()end
            elseif self.open and(mode=='Death'or mode=='Respawn')then self:hideDeath(current)end;return false
        end);log('MC_D_READY native_screens_and_respawn')
    end
    function D:teardown(env)
        A:cancel(true)
        F:captureTeardown()
        self:previewStop()
        if valid(widget)then widget:RemoveFromParent()end
        if valid(root)then root:SetRenderOpacity(self.rootOpacity)end
        if self.parentHidden and valid(self.parentHidden.node)then self.parentHidden.node:SetRenderOpacity(self.parentHidden.opacity)end;self.parentHidden=nil
        if env then self:hideFooter(env,false);env.controller:SetIgnoreMoveInput(false);env.controller:SetIgnoreLookInput(false)end
        self:cancel()
    end
    function D:cancel()
        uiSerial=uiSerial+1;Timers.cancel(handle);handle=nil;self.escapeDue=nil;self.escapeDirty=nil;self.pendingNav46=nil;if self.deathHandle then Timers.cancel(self.deathHandle)end
        E:cancel();F:cancel();H:cancel();A:cancel(false);F:captureTeardown();handle=nil;self.deathHandle=nil;widget,nodes,root,mode=nil,nil,nil,nil;self.open=false;self.intent=nil;self.capture,self.renderTarget,self.previewImage,self.previewLight=nil,nil,nil,nil;self.elementWidgets=nil;self.deathHidden=nil;assets={};self.footers={};self.footerScanned=false;self.footerApplied=nil
    end
    function D:retireViewport(env)
        if valid(widget)then widget:RemoveFromParent()end
        if valid(root)then root:SetRenderOpacity(self.rootOpacity)end
        if self.parentHidden and valid(self.parentHidden.node)then self.parentHidden.node:SetRenderOpacity(self.parentHidden.opacity)end
        if env then self:hideFooter(env,false);env.controller:SetIgnoreMoveInput(false);env.controller:SetIgnoreLookInput(false)end
    end
    Timers.onEpoch('phase-d',function()
        uiSerial=uiSerial+1;if handle then Timers.cancel(handle)end;if D.deathHandle then Timers.cancel(D.deathHandle)end
        handle=nil;D.deathHandle=nil;widget,nodes,root,mode=nil,nil,nil,nil;assets={};D.open=false;D.intent=nil;D.uiOffset46=0;D.pendingNav46=nil;D.nodes46=nil;D.escapeDirty=nil;D.escapeDue=nil
        D.capture,D.renderTarget,D.previewImage,D.previewLight=nil,nil,nil,nil;D.elementWidgets=nil;D.deathHidden=nil;D.paldex51=nil;D.warm51=nil
        D.nativeCandidates61=nil;D.nativeRouteAt61=nil;D.nativeRouteAttempts61=nil;D.nativeRouteChecked=false;D.nativeEnabled61=nil;D.footers={};D.footerScanned=false;D.parentHidden=nil;D.partySelected=nil;D.partyPaintSignature=nil
    end)
    return D
end
