-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
    local Timers=dofile(ctx.base..'/timers.lua')
    local UE,valid,log=ctx.UE,ctx.valid,ctx.log
    local registry=ctx.registry
    local gearBalance=dofile(ctx.base..'/gear_balance.lua')
    local nativeIcons=dofile(ctx.base..'/native_icons.lua')
    local lowerIcons={};for name,path in pairs(nativeIcons)do lowerIcons[name:lower()]=path end
    setmetatable(nativeIcons,{__index=function(_,name)return lowerIcons[name:lower()]end})
    local P={selected=5,blocks={1,2,3,4,5},visible=true,hooks={}}
    local hud,nodes,hidden,statHandle,mining,overlay,owner={},{},{},nil,nil,nil,nil
    local selfHide;local hiddenOrder={};local hideCursor=0
    local function widget(node)return valid(node)and node:IsA(UE.Object('/Script/UMG.Widget'))end
    local function currentHidden(entry,node)
        node=node or(entry and entry.node)
        return entry and widget(node)and node:GetClass():GetAddress()==entry.class and node:GetFName():ToString()==entry.name
    end
    function P:hideNativeNode(node)
        if not widget(node)then return end;local entry=hidden[node:GetAddress()]
        if currentHidden(entry,node)then if node:GetRenderOpacity()~=0 then node:SetRenderOpacity(0)end
        elseif selfHide then selfHide(node)end
    end
    local changing=false;local weaponUpdatePending=false
    local assets,rowValues,iconPaths,assetIds={},{},{},{}
    local function text(node,s)if valid(node)then
        if ctx.uiKit and ctx.uiKit.putText then ctx.uiKit:putText(node,s)
        else node:SetText(UE.GetKismetTextLibrary():Conv_StringToText(tostring(s)))end
    end end
    local function clamp(n) return math.max(0,math.min(1,n or 0)) end
    local function asset(path)
        local id=assetIds[path];if valid(assets[path])and id and assets[path]:GetClass():GetAddress()==id.class and assets[path]:GetFName():ToString()==id.name then return assets[path]end
        if valid(assets[path])then log('MC_STALE_CACHE phase-a '..path)end
        local package,name=path:match('^(.*)%.([^%.]+)$')
        local o=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(package),AssetName=UE.FindOrAddFName(name)})
        if not valid(o)then o=StaticFindObject(path)end
        assert(valid(o)and UE.AssetMatchesRA(o,path),'Asset absent '..path);assets[path]=o;assetIds[path]={class=o:GetClass():GetAddress(),name=o:GetFName():ToString()};return o
    end
    local function now(env) return UE.Object('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(env.player) end
    local function unwrap(o)
        local ok,value=pcall(function()return o:get()end)
        return ok and value or o
    end
    local function live(stamp)
        if stamp~=ctx.epoch() or ctx.quiesced() then return nil end
        local env=ctx.environment()
        if not env or not owner or env.identity~=owner.identity or env.player:GetAddress()~=owner.player then return nil end
        return env
    end
    local function guarded(label,fn)
        local ok,err=xpcall(fn,debug.traceback)
        if not ok then log('PHASE_A_ERROR '..label..' '..err) end
        return ok
    end
    local function weaponChanged()
        if ctx.quiesced()or not owner or changing or weaponUpdatePending then return end
        weaponUpdatePending=true;local stamp=ctx.epoch()
        Timers.after(100,function()
            weaponUpdatePending=false;local env=live(stamp)
            if env then guarded('weapon-event',function()P:updateWeapons(env,true);if P.visible then P:hideNative(env)end end) end
        end)
    end
    local function nativeWidgetList(env,className)
        local result={}
        for _,w in ipairs(FindAllOf(className or 'UserWidget') or {}) do
            if valid(w) and not w:GetFullName():find('Default__',1,true) then
                local good,p=pcall(function()return w:GetOwningPlayer()end)
                if good and valid(p) and p:GetAddress()==env.controller:GetAddress() then result[#result+1]=w end
            end
        end
        return result
    end
    local function setNative(env,hide)
        if P.uiEntry then P.uiEntry:toggle(not hide)end
        if not hide then
            local n=0
            for _,entry in pairs(hidden) do
                if currentHidden(entry) then
                    entry.node:SetRenderOpacity(entry.opacity)
                    assert(entry.node:GetRenderOpacity()==entry.opacity,'Native HUD opacity restore failed')
                    n=n+1
                end
            end
            
            log('HUD_NATIVE_RESTORED PASS exact_opacity_nodes='..n);return
        end
        if P.nativeDiscovered then
            for _,entry in pairs(hidden)do if currentHidden(entry)and entry.node:GetRenderOpacity()~=0 then entry.node:SetRenderOpacity(0)end;entry.dirty=false end
            return
        end
        P.nativeDiscovered=true
        local function collapse(node)
            if not widget(node) then return end
            local class=node:GetClass():GetFullName():lower()
            if class:find('inputlistener',1,true)or class:find('menuesc',1,true)then return end
            local id=node:GetAddress()
            if not currentHidden(hidden[id],node)then hidden[id]={node=node,class=node:GetClass():GetAddress(),name=node:GetFName():ToString(),opacity=node:GetRenderOpacity()};hiddenOrder[#hiddenOrder+1]=hidden[id]end
            node:SetRenderOpacity(0)
        end
        selfHide=collapse
        for _,w in ipairs(nativeWidgetList(env)) do
            local name=w:GetClass():GetFullName()
            local className=name:lower()
            if className:find('weight',1,true)or(className:find('ingame',1,true)and(className:find('badstatus',1,true)or className:find('debuff',1,true)or className:find('abnormal',1,true)))then collapse(w);log('MC22_NATIVE_HUD_HIDE '..name)end
            if name:find('WBP_Ingame_Compass_C',1,true) or name:find('WBP_Ingame_PlayerStamina_Circle_C',1,true)
                or name:find('WBP_PLLvExp_C',1,true) or name:find('WBP_Ingame_WeaponChange_C',1,true)
                or name:find('WBP_Ingame_PalHPGauge_C',1,true)
                or name:find('WBP_Ingame_Thermometer_C',1,true)or name:find('WBP_Ingame_TimeZone_C',1,true)
                or name:find('WBP_Ingame_WeaponChangeList_C',1,true)or name:find('WBP_IngameStatusPoint_C',1,true)then collapse(w);log('MC22_NATIVE_HUD_HIDE '..name)end
            if ctx.config.task20_ui and(name:find('WBP_PalLogWidget_C',1,true)or name:find('WBP_NoticeLog_C',1,true)or name:find('WBP_QuestAndBaseCampInfoCanvas_C',1,true)or name:find('WBP_Ingame_QuestBoard_C',1,true))then collapse(w)end
            if name:find('WBP_PlayerUI_C',1,true)then collapse(ctx.uiWidgets(w).CanvasPanelConstructionMenu)end
            if name:find('WBP_Ingame_PlayerGauge_Separated_C',1,true) then
                local children=ctx.uiWidgets(w)
                for _,n in ipairs({'Canvas_HP','Canvas_Shield','Canvas_WeaponInfo','Canvas_Weapon_Disabled','WBP_IngameHungerGauge'}) do collapse(children[n]) end
                for n,node in pairs(children)do if n==n:lower()and(n:find('weight',1,true)or n:find('badstatus',1,true)or n:find('debuff',1,true))then collapse(node);log('MC22_NATIVE_HUD_NODE_HIDE '..node:GetFullName())end end
            end
            if name:find('WBP_WeightNotice_C',1,true)then P.nativeWeightText=ctx.uiWidgets(w).Text_Weight end
            if name:find('WBP_PalDamageText_C',1,true)then collapse(ctx.uiWidgets(w).Text_DamageValue);log('MC22_NATIVE_DAMAGE_VALUE_HIDE '..w:GetFullName())end
            if name:find('WBP_Ingame_PalHPGauge_C',1,true) then
                local children=ctx.uiWidgets(w)
                
                for n,node in pairs(children) do
                    if n=='Canvas_PalStatus' or n=='Canvas_HP' or n:find('WBP_PalCommonCharacterSlot',1,true) or n:find('ProgressBar',1,true)
                        or n=='Text_PalName' or n=='Text_PalLevel' or n=='Text_NowHP' or n=='Text_MaxHP' then collapse(node) end
                end
            end
        end
        local n=0;for _ in pairs(hidden) do n=n+1 end
        log('HUD_NATIVE_TRANSPARENT nodes='..n..' prompts_and_menus_preserved=true')
    end
    function P:hideNative(env) setNative(env,true) end
    function P:keepNativeHidden()
        if not self.visible then return end

        for _=1,math.min(4,#hiddenOrder)do
            hideCursor=hideCursor%#hiddenOrder+1;local entry=hiddenOrder[hideCursor]
            if currentHidden(entry)and entry.node:GetRenderOpacity()~=0 then entry.node:SetRenderOpacity(0)end;entry.dirty=false
        end
    end
    local function icon(node,path)
        local id=node:GetAddress()
        if iconPaths[id]==(path or false) then return end
        iconPaths[id]=path or false
        if not path then node:SetVisibility(1);return end
        if ctx.config.task20_ui then ctx.uiKit:icon(node,asset(path),path:find('_icon_normal',1,true)and 20 or 16,0)else node:SetBrushFromTexture(asset(path),false)end;node:SetVisibility(3)
    end
    local weaponTextures={}
    local function nativeWeaponIcon(item)
        if weaponTextures[item]~=nil then return weaponTextures[item] and asset(weaponTextures[item]) or nil end
        
        for _,data in ipairs(FindAllOf('PalStaticItemDataBase') or {}) do
            if valid(data) and data.ID:ToString()==item then
                local good,o=pcall(function()return data.IconTexture:Get()end)
                if good and valid(o) then weaponTextures[item]=o:GetFullName():match('^[^ ]+ (.*)$');return o end
            end
        end
        weaponTextures[item]=false
    end
    function P:updateHotbar(env,onlySlotVF)
        if not hud.widget or not valid(hud.widget) then return end
        if valid(nodes.Crosshair)then nodes.Crosshair:SetVisibility(((self.items and self.items.open)or(self.menuOpen and self.menuOpen()))and 1 or 3)end
        for i=1,9 do nodes['Select'..i]:SetVisibility(i==self.selected and 3 or 1) end
        local counts={}
        for i=onlySlotVF or 1,onlySlotVF or 9 do
            if self.items then
                local entry=self.items:hotbar(env,i);local present=entry.id and entry.count>0;local data=present and self.items:data(entry.id);local stack=present and entry.count>1 and not(valid(data)and data.TypeA==1);text(nodes['Count'..i],stack and entry.count or '');counts[#counts+1]=tostring(entry.count)
                local token=present and entry.id or false;self.hotbarVisual=self.hotbarVisual or{}
                if self.hotbarVisual[i]~=token then
                    local texture=present and self.items:icon(entry.id);nodes['Icon'..i]:SetVisibility(valid(texture)and 3 or 1)
                    if valid(texture)then if ctx.config.task20_ui then ctx.uiKit:icon(nodes['Icon'..i],texture)else nodes['Icon'..i]:SetBrushFromTexture(texture,false)end end
                    self.hotbarVisual[i]=token
                end
            elseif i>=5 then
            local def=registry[self.blocks[i-4]]
            local inventory,item=ctx.inventory(env,self.blocks[i-4]);local n=inventory:CountItemNum(item)
            text(nodes['Count'..i],n);counts[#counts+1]=tostring(n)
            icon(nodes['Icon'..i],'/Game/MinecraftBlocks/T_MC_'..def.item:sub(4)..'.T_MC_'..def.item:sub(4))
            end
        end
        if not onlySlotVF and self.items and ctx.uiKit then
            local current={};for i=1,9 do local e=self.items:hotbar(env,i);if e.id then current[e.id]=e.count end end
            if self.toastCounts then for id,count in pairs(current)do local previous=self.toastCounts[id];if previous and count>previous then ctx.uiKit:nativePickup(env,id,count-previous)end end end
            self.toastCounts=current
        end
        local summary=table.concat(counts,',')
        if not onlySlotVF and summary~=self.lastCounts then log('MC_HOTBAR_COUNTS '..summary);self.lastCounts=summary end
    end
    function P:updateWeapons(env,selection)
        if self.attackSync68 then self.attackSync68(env)end
        if not hud.widget or not valid(hud.widget) then return end
        if self.items and not self.profileBaseline then

            local w=env.player.ShooterComponent:GetHasWeapon();local e=self.items:hotbar(env,self.selected)
            if valid(w)and e.id==w:GetItemId().StaticId:ToString()and w:GetMagazineSize()>0 then text(nodes['Count'..self.selected],w:GetRemainBulletCount())end
            return
        end
        local weapons={}
        for _,w in ipairs(env.player.LoadoutSelectorComponent:GetWeaponList()) do
            w=unwrap(w)
            if valid(w) then local i=w:GetLoadoutSelectorIndex();if i>=0 and i<4 then weapons[i+1]=w end end
        end
        for i=1,4 do
            local w=weapons[i]
            if valid(w) then
                local id=w:GetItemId().StaticId:ToString()
                local o=nativeWeaponIcon(id)
                if not valid(o)and self.items then o=self.items:icon(id)end
                if valid(o) then if ctx.config.task20_ui then ctx.uiKit:icon(nodes['Icon'..i],o,32,0,1.2)else nodes['Icon'..i]:SetBrushFromTexture(o,false)end
                    self.weaponVisual=self.weaponVisual or{};if self.weaponVisual[i]~=id then local brush=nodes['Icon'..i].Brush;local c=brush.TintColor.SpecifiedColor;local gain=1;log('MC22_WEAPON_WHITE slot='..i..' prior_brush='..c.R..','..c.G..','..c.B..','..c.A..' native_palette_gain='..gain);brush.TintColor={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0};nodes['Icon'..i]:SetBrush(brush);nodes['Icon'..i]:SetColorAndOpacity({R=gain,G=gain,B=gain,A=1});nodes['Icon'..i]:SetRenderOpacity(1);nodes['Icon'..i]:SetIsEnabled(true);self.weaponVisual[i]=id end;nodes['Icon'..i]:SetVisibility(3)
                else icon(nodes['Icon'..i],nativeIcons['T_itemicon_Weapon_'..id]) end
                local ammo=w:GetRemainBulletCount();local reserve=w:GetInventoryBulletCount()
                text(nodes['Count'..i],w:GetMagazineSize()>0 and tostring(ammo)or '');nodes['Count'..i]:SetClipping(1)
                if self.weaponIDs==nil then self.weaponIDs={} end
                if self.weaponIDs[i]~=id then log('MC_WEAPON_SLOT '..i..' id='..id..' native_index='..(i-1));self.weaponIDs[i]=id end
            else nodes['Icon'..i]:SetVisibility(1);text(nodes['Count'..i],'') end
        end
        if selection and not changing then
            local w=env.player.ShooterComponent:GetHasWeapon()
            if valid(w) then
                local i=w:GetLoadoutSelectorIndex()
                if i>=0 and i<4 then
                    if not(self.items and self.items:keepAlias(w:GetItemId().StaticId:ToString()))then self.selected=i+1 end
                    ctx.setBlockMode(false);self:updateHotbar(env);log('MC_WEAPON_EVENT selection='..self.selected)
                end
            end
        end
    end
    function P:select(i)
        local env=ctx.active();if not ctx.gameplayInput(env)then return end;self:cancelMining('slot-change',true)
        changing=true
        if self.items then
            local mode,block=self.items:select(env,i);ctx.setBlockMode(mode);if block then ctx.setType(block)end
        elseif i<=4 then
            env.player.LoadoutSelectorComponent:SetWeaponLoadoutIndex(i-1)
            env.player.LoadoutSelectorComponent:TryEquipNowSelectedWeapon()
            ctx.setBlockMode(false)
        else
            if self.items then
                local mode,block=self.items:select(env,i);ctx.setBlockMode(mode);if block then ctx.setType(block)end
            else
            
            env.player.LoadoutSelectorComponent:SetWeaponLoadoutIndex(4)
            env.player.LoadoutSelectorComponent:TryEquipNowSelectedWeapon()
            ctx.setBlockMode(true);ctx.setType(self.blocks[i-4])
            end
        end
        self.selected=i;changing=false;self:updateWeapons(env,false);self:updateHotbar(env)
        self.selectionFrame=Timers.frameCounter
        if self.onSelection then self.selectionReceipt=self.onSelection(env)end
        if self.visible then setNative(env,true) end
        local w=env.player.ShooterComponent:GetHasWeapon()
        log('MC_SELECT slot='..i..' native_index='..env.player.LoadoutSelectorComponent.currentItemSlotIndex..' held='..(valid(w) and w:GetClass():GetFullName() or 'empty'))
    end
    function P:cycle()
        if not self.items and self.selected<5 then return end
        local env=ctx.active();if not ctx.gameplayInput(env)then return end;local s=self.selected-4
        if self.items then self.items:cycle(env,self.selected);return end
        self.blocks[s]=self.blocks[s]%#registry+1;ctx.setType(self.blocks[s]);self:updateHotbar(env)
        log('MC_BLOCK_ASSIGN slot='..self.selected..' type='..registry[self.blocks[s]].name)
    end
    local function row(prefix,ratio)
        local halves=math.ceil(clamp(ratio)*20)
        if rowValues[prefix]==halves then return end
        rowValues[prefix]=halves
        for i=1,10 do
            local n=halves-(i-1)*2;local node=nodes[prefix..i]
            if prefix=='Armor'and valid(nodes['ArmorEmpty'..i])then nodes['ArmorEmpty'..i]:SetRenderOpacity(halves>0 and 1 or 0)end
            node:SetVisibility(n>0 and 3 or 1)
            if n>0 then icon(node,'/Game/MinecraftBlocks/T_MCHUD_'..prefix..(n>=2 and 'Full' or 'Half')..'.T_MCHUD_'..prefix..(n>=2 and 'Full' or 'Half')) end
        end
    end
    function P:profileStep(name,started)
        if self.hudProfile then local rows=self.hudProfile[name]or{};self.hudProfile[name]=rows;rows[#rows+1]=(os.clock()-started)*1000 end
    end
    function P:cooldown66()
        if not valid(nodes.Crosshair)then return end
        local attack=UE.attack66;local fraction=attack and math.min(1,(os.clock()-attack.at)/attack.period)or 1
        local bucket=fraction<1 and math.floor(fraction*16)or -1
        if bucket==self.cooldownBucket66 then return end;self.cooldownBucket66=bucket
        if not self.cooldownNodes66 then
            local canvas=nodes.Crosshair:GetParent();self.cooldownNodes66={}
            for i=1,2 do local n=UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(UE.Object('/Script/UMG.Image'),canvas:GetOuter());canvas:AddChildToCanvas(n);n.Slot:SetAnchors({Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}});n.Slot:SetAlignment({X=0,Y=0});n.Slot:SetPosition({X=-8*(self.uiUnit or 3),Y=12*(self.uiUnit or 3)});n.Slot:SetSize({X=16*(self.uiUnit or 3),Y=4*(self.uiUnit or 3)});n:SetColorAndOpacity(i==1 and{R=.1,G=.1,B=.1,A=1}or{R=1,G=1,B=1,A=1});n:SetVisibility(3);self.cooldownNodes66[i]=n end
        end
        for _,n in ipairs(self.cooldownNodes66)do n:SetRenderOpacity(bucket>=0 and 1 or 0)end
        if bucket>=0 then self.cooldownNodes66[2].Slot:SetSize({X=math.max(1,bucket)*(self.uiUnit or 3),Y=4*(self.uiUnit or 3)})end
    end
    function P:updateStats(env)
        self:cooldown66()
        local stage=os.clock();self:keepNativeHidden();self:profileStep('native_hide',stage);stage=os.clock()
        if not hud.widget or not valid(hud.widget) then return end
        if self.inventoryDirty then self.defenseDirty=true;self.inventoryDirty=false;self:updateHotbar(env)end
        if not valid(self.statParameter)then self.statParameter=env.player.CharacterParameterComponent;self.statIndividual=self.statParameter:GetIndividualParameter()end
        local parameter=self.statParameter
        if ctx.config.task20_ui and ctx.uiKit then ctx.uiKit:quests(nodes,env,false);ctx.uiKit:nativeHUD(nodes,env,self.visible,ctx.gameplayInput(env),self)end
        self:profileStep('native_hud',stage);stage=os.clock()
        local individual=self.statIndividual;local measured=os.clock()
        local hp,maxhp=parameter:GetHP().Value,parameter:GetMaxHP().Value;row('Heart',hp/math.max(1,maxhp));self:profileStep('stats_hp',measured);measured=os.clock()
        if not self.foodAt or os.clock()>=self.foodAt then self.foodAt=os.clock()+1;local food,maxfood=parameter:GetFullStomach(),parameter:GetMaxFullStomach();row('Food',food/math.max(1,maxfood))end;self:profileStep('stats_food',measured);measured=os.clock()
        if not self.defenseAt or os.clock()>=self.defenseAt or self.defenseDirty then self.defense=parameter:GetDefense();self.defenseAt=os.clock()+.5;self.defenseDirty=false end

        local armor=0
        if self.items then
            local native=self.items.native;local container=native:container(env,4)
            for i=0,container:Num()-1 do
                local id=native:id(container:Get(i));local def=id and self.items.registry.items[id]
                if def and def.armor_points then armor=armor+def.armor_points
                elseif id then
                    local data=self.items:data(id)
                    if valid(data)and data:IsA(UE.Object('/Script/Pal.PalStaticArmorItemData'))then armor=armor+math.max(0,data:GetDefenseValue())/(registry.defense_per_chestplate or 1)*2 end
                end
            end
        end
        self.armorPointsCV=armor
        row('Armor',armor/20);self:profileStep('stats_armor',measured);measured=os.clock()
        local sp,maxsp=parameter:GetSP().Value,parameter:GetMaxSP().Value;local stamina=clamp(sp/math.max(1,maxsp))
        if self.shownStamina~=stamina then self.shownStamina=stamina;nodes.Stamina:SetPercent(stamina)end;self:profileStep('stats_stamina',measured);measured=os.clock()
        local lv,xp=individual:GetLevel(),individual:GetExp()
        if self.displayedLevel and lv>self.displayedLevel then ctx.uiKit:notify('Level up','Level '..lv);if self.uiEntry then self.uiEntry:bindCurrent()end end
        if not valid(self.expDatabase)then self.expDatabase=UE.Object('/Script/Pal.Default__PalUtility'):GetExpDatabase(env.player)end
        if self.expLevel~=lv then self.expLevel=lv;self.expLow=self.expDatabase:GetTotalExp(lv,true);self.expHigh=self.expDatabase:GetTotalExp(lv+1,true)end
        local low,high=self.expLow,self.expHigh;local ratio=clamp((xp-low)/math.max(1,high-low));local u=ctx.config.task20_ui and(self.uiUnit or 3)or 3
        if self.displayedXP~=xp or self.displayedLevel~=lv then log('MC22_XP_DISPLAY previous='..tostring(self.displayedXP)..' exp='..xp..' level='..lv..' ratio='..ratio);self.displayedXP=xp;self.displayedLevel=lv end
        if self.shownXPRatio~=ratio or self.shownXPUnit~=u then self.shownXPRatio=ratio;self.shownXPUnit=u;local clip=nodes.XPClip63;if valid(clip)then clip.Slot:SetSize({X=math.floor(182*ratio)*u,Y=5*u});nodes.XPProgress.Slot:SetSize({X=182*u,Y=5*u})else nodes.XPProgress.Slot:SetSize({X=182*u*ratio,Y=5*u})end end
        text(nodes.Level,lv);self:profileStep('stats_xp',measured)
        if UE.mount76 then UE.mount76:ui(env,nodes,u,ctx.uiKit)end
        if UE.zombie77 and UE.zombie77.bossD then Timers.measure('boss:bar',UE.zombie77.bossD.ui,UE.zombie77.bossD,env,nodes,ctx.uiKit,u,self.visible and ctx.gameplayInput(env))end
        if UE.zombie77 and UE.zombie77.wardenC then UE.zombie77.wardenC:ui(env,nodes,ctx.uiKit,u,self.visible and ctx.gameplayInput(env))end
        if not self.statLogged then
            log('MC_STATS hp='..parameter:GetHP().Value..'/'..parameter:GetMaxHP().Value..' hunger='..parameter:GetFullStomach()..' stamina='..parameter:GetSP().Value..' defense='..parameter:GetDefense()..' level='..lv..' exp='..xp..' range='..low..'..'..high);self.statLogged=true
        end
        self:profileStep('stats',stage);stage=os.clock()
        self:updateWeapons(env,false);self:profileStep('weapons',stage);stage=os.clock() 
        if valid(nodes.Clock)and(not self.clockAt or os.clock()>=self.clockAt)then
            self.clockAt=os.clock()+1
            if not valid(self.timeManager)then self.timeManager=UE.Object('/Script/Pal.Default__PalUtility'):GetTimeManager(env.player)end;local manager=self.timeManager
            if valid(manager)then
                local kind=manager:GetCurrentDayTimeType();local rate=manager:GetDayTimePassRate()
                local frame=math.floor(((kind==0 and 0 or .5)+clamp(rate)*.5)*64)%64
                if self.clockFrame~=frame then self.clockFrame=frame;local name=string.format('T_MC_Clock%02d',frame)
                    icon(nodes.Clock,'/Game/MinecraftBlocks/'..name..'.'..name)end
            end
        end
        if valid(nodes.Temperature)and valid(self.nativeThermometer)then
            local temperature=self.nativeThermometer.CachedDisplayTemperature
            nodes.Temperature:SetVisibility(temperature~=0 and 3 or 1)
            local statusIcon=nodes.GuiExtra1;local u=self.uiUnit or 3;if valid(statusIcon)then statusIcon:SetVisibility(temperature~=0 and 3 or 1)end
            if temperature~=0 then text(nodes.Temperature,temperature<0 and 'Cold' or 'Hot');nodes.Temperature.Slot:SetAnchors({Minimum={X=.5,Y=1},Maximum={X=.5,Y=1}});nodes.Temperature.Slot:SetPosition({X=21*u,Y=-64*u});nodes.Temperature.Slot:SetSize({X=68*u,Y=10*u});nodes.Temperature:SetJustification(0)
                if valid(statusIcon)then local name=temperature<0 and'T_MC_PackedIce'or'T_MC_Torch';icon(statusIcon,'/Game/MinecraftBlocks/'..name..'.'..name);statusIcon.Slot:SetAnchors({Minimum={X=.5,Y=1},Maximum={X=.5,Y=1}});statusIcon.Slot:SetPosition({X=10*u,Y=-64*u});statusIcon.Slot:SetSize({X=8*u,Y=8*u})end
            end
        end
        if valid(self.nativeWeightText)and(not self.weightAt or os.clock()>=self.weightAt)then
            self.weightAt=os.clock()+1;local v=UE.GetKismetTextLibrary():Conv_TextToString(self.nativeWeightText:GetText());local value=type(v)=='string'and v or v:ToString();local a,b=value:match('([%d%.]+)%s*/%s*([%d%.]+)');a,b=tonumber(a),tonumber(b);local show=a and b and a>b;local n,ic=nodes.GuiQuest6,nodes.GuiExtra2
            if valid(n)and valid(ic)then n:SetVisibility(show and 3 or 1);ic:SetVisibility(show and 3 or 1);if show then local u=self.uiUnit or 3;text(n,'Overweight '..math.floor(a+.5)..'/'..math.floor(b+.5));ctx.uiKit:textStyle(n,u,false,{R=1,G=.333,B=.333,A=1});n:SetJustification(0);n.Slot:SetAnchors({Minimum={X=.5,Y=1},Maximum={X=.5,Y=1}});n.Slot:SetPosition({X=21*u,Y=-77*u});n.Slot:SetSize({X=125*u,Y=10*u});icon(ic,'/Game/MinecraftBlocks/T_MC_Chest.T_MC_Chest');ic.Slot:SetAnchors({Minimum={X=.5,Y=1},Maximum={X=.5,Y=1}});ic.Slot:SetPosition({X=10*u,Y=-77*u});ic.Slot:SetSize({X=8*u,Y=8*u});if self.shownWeight~=value then self.shownWeight=value;log('MC22_OVERWEIGHT native='..value)end end end
        end
        self:profileStep('clock_temperature',stage);stage=os.clock()
        if self.lastPartyAt and os.clock()-self.lastPartyAt<.5 then return end;self.lastPartyAt=os.clock()
        local holder=env.controller.BP_OtomoPalHolderComponent
        local slots=self.partySlotsL
        if self.partyHolderL~=holder:GetAddress()then slots=nil end
        if slots then for _,slot in ipairs(slots)do if not valid(unwrap(slot))then slots=nil;break end end end
        if not slots then slots={};_G.MC_OUT_K('GetSlots',holder,slots);self.partySlotsL=slots;self.partyHolderL=holder:GetAddress()end
        local selected=holder:GetSelectedOtomoID();local active=holder.ActivatedOtomoSlotID
        local partyReady=self.partySeen73~=nil;self.partySeen73=self.partySeen73 or{}
        for i=1,5 do
            local slot=slots[i] and unwrap(slots[i]) or nil
            local data=valid(slot) and slot.ReplicateIndividualParameter or nil
            local present=valid(data)
            for _,prefix in ipairs({'Party','PalName','PalLevel','PalHP'}) do nodes[prefix..i]:SetVisibility(present and 3 or 1) end
            if present then
                local id=data:GetCharacterID():ToString();local nickname=data.SaveParameter.NickName

                local unavailable=UE.packFlags and not UE.packFlags:has('islands_animals')and(id:sub(1,3)=='MC_'or id:sub(1,3)=='CP_')
                nickname=type(nickname)=='string' and nickname or (nickname and nickname:ToString() or '')
                local label=nickname~='' and nickname or id
                if not unavailable and(nickname==''or nickname:find('!!!',1,true))then
                    self.palNames=self.palNames or{}
                    if not self.palNames[id]then
                        local out={};UE.Object('/Script/Pal.Default__PalUtility'):GetDatabaseCharacterParameter(env.player):GetLocalizedCharacterName(UE.FindOrAddFName(id),out)
                        local value=out.OutText and UE.GetKismetTextLibrary():Conv_TextToString(out.OutText);self.palNames[id]=type(value)=='string'and value or(value and value:ToString())or id
                    end
                    label=self.palNames[id]
                end

                if label then text(nodes['PalName'..i],label) end
                local individualId=data:GetAddress()
                if not self.partySeen73[individualId]then self.partySeen73[individualId]=true;if partyReady then ctx.uiKit:notify('Pal joined your party',label or id);if self.uiEntry then self.uiEntry:bindCurrent()end end end
                text(nodes['PalLevel'..i],(ctx.config.task20_ui and''or'Lv ')..data:GetLevel())
                if unavailable then
                    nodes['PalHP'..i]:SetPercent(0);icon(nodes['PalIcon'..i],nil)
                    if not self.partyLogged then log('PALCRAFT_PARTY_OPTIONAL_UNAVAILABLE id='..id..' pack=islands_animals saved_entry_preserved=true')end
                else
                    nodes['PalHP'..i]:SetPercent(clamp(data:GetHP().Value/(1000*math.max(1,data:GetMaxHP()))))
                    icon(nodes['PalIcon'..i],nativeIcons['T_'..id..'_icon_normal'])
                end
                nodes['Party'..i]:SetBrushColor(ctx.config.task20_ui and{R=0,G=0,B=0,A=.5}or((i-1==active or (active<0 and i-1==selected)) and {R=.3,G=.5,B=.22,A=.8} or {R=.055,G=.06,B=.07,A=.68}))
                if ctx.config.task20_ui then nodes['PalName'..i]:SetVisibility(i-1==selected and 3 or 1)end
                if not self.partyLogged then log('MC_PARTY slot='..i..' id='..id..' level='..data:GetLevel()) end
            else icon(nodes['PalIcon'..i],nil) end
        end
        self.partyLogged=true;self:profileStep('party',stage)
    end
    function P:cancelMining(reason,touch,fromCallback)
        if mining then
            if mining.handle and not fromCallback then Timers.cancel(mining.handle) end
            log('MC_MINE_CANCEL '..reason);mining=nil
        end
        if touch and overlay and valid(overlay.actor) then overlay.actor:SetActorHiddenInGame(true) end
    end
    local function target(env)
        local hit=ctx.trace(env,true);if not hit then return nil end
        local chunk=ctx.hitChunk(hit);if not chunk then return nil end
        local k=chunk.keys[hit.Item];local c=ctx.cells()[k];if not c then return nil end
        local p=env.player:K2_GetActorLocation();local h=hit.ImpactPoint
        if (p.X-h.X)^2+(p.Y-h.Y)^2+(p.Z-h.Z)^2>600^2 then return nil end
        return k,c
    end
    local function tool(env)
        local w=env.player.ShooterComponent:GetHasWeapon()
        if not valid(w) then return 'hand',1 end
        local item=w:GetItemId().StaticId:ToString()
        local definition=P.items and P.items.registry.items[item]
        if definition and definition.tool then return definition.tool,definition.speed end
        local id=item:lower()
        local matchedSpeed=gearBalance.nativeMining[item]
        if matchedSpeed then return id:find('pickaxe',1,true)and'pickaxe'or'axe',matchedSpeed end
        if id:find('pickaxe',1,true) then return 'pickaxe',id:find('00',1,true) and 2 or 4 end
        if id:find('axe',1,true) then return 'axe',id:find('00',1,true) and 2 or 4 end
        return 'hand',1
    end
    local function oreToolX8(env,def)local w=env.player.ShooterComponent:GetHasWeapon();local id=valid(w)and w:GetItemId().StaticId:ToString()or'';return dofile(ctx.base..'/slice_mining_x8.lua').allowed(def,id) end
    function P:beginMining()
        local env=ctx.active()
        if env.controller:IsRiding()then return end
        if env.controller:IsMoveInputIgnored() or ctx.pending() then return end
        if not ctx.gameplayInput(env)then return end
        self:cancelMining('new-press',true)
        local k,c=target(env);if not c then return end
        if UE.creativeMode and UE.creativeMode:enabled()then
            if ctx.returnCell(k,env)and UE.effects66 then UE.effects66:emit(env,'break',{X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+50},c.type)end
            log('MCCM_INSTANT_BREAK cell='..k..' removed='..tostring(ctx.cells()[k]==nil));return
        end
        local def=registry[c.type];if not oreToolX8(env,def)then log('MCX8_ORE_REJECT Minecraft_pickaxe_required');return end;local kind,speed=tool(env)
        local harvest=not def.requires_tool or kind==def.tool
        local correct=kind==def.tool
        local seconds=math.ceil(def.hardness*(harvest and 30 or 100)/(correct and speed or 1))/20
        if not overlay then overlay=ctx.overlay(env) end
        local hit={};_G.MC_OUT_K('K2_SetActorLocation',overlay.actor,{X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+50},false,hit,true)
        overlay.actor:SetActorHiddenInGame(false)
        mining={key=k,stamp=ctx.epoch(),start=now(env),seconds=seconds,stage=-1,tool=kind}
        local watch=mining
        log('MC_MINE_BEGIN type='..def.name..' tool='..kind..' seconds='..seconds..' harvest='..tostring(harvest))
        watch.handle=Timers.loop(ctx.config.mining_interval_ms,function()
            if watch.stamp~=ctx.epoch() or ctx.quiesced() then P:cancelMining('map-change',false,true);return true end
            local current=live(watch.stamp)
            if not current then P:cancelMining('world-change',false,true);return true end
            local ok=guarded('mining',function()
                local pressed=current.controller:IsInputKeyDown({KeyName=UE.FindOrAddFName('LeftMouseButton')})
                local hitKey=target(current)
                if not pressed or hitKey~=watch.key or not ctx.gameplayInput(current)then P:cancelMining('release-or-target',true,true);return end
                local elapsed=now(current)-watch.start
                watch.ticks=(watch.ticks or 0)+1
                if watch.ticks%4==0 and ctx.sound then ctx.sound('block.'..(def.sound or'stone')..'.hit',{X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+50},.3)end
                local stage=math.min(9,math.floor(elapsed/watch.seconds*10))
                if stage~=watch.stage then overlay.component:SetMaterial(0,asset('/Game/MinecraftBlocks/M_MC_Crack'..stage..'.M_MC_Crack'..stage));watch.stage=stage end
                if not oreToolX8(current,def)then P:cancelMining('minecraft-pickaxe-required',true,true);return end
                if elapsed>=watch.seconds then
                    P:cancelMining('complete',true,true)
                    if c.debug or not def.drops or not harvest then if ctx.remove(k)==false then log('MC_MINE_REJECT storage_return_unavailable');return end;ctx.save()
                    else ctx.returnCell(k,current) end
                    if not ctx.cells()[k]and UE.effects66 then UE.effects66:emit(current,'break',{X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+50},c.type)end
                    log('MC_MINE_PASS type='..def.name..' tool='..kind..' elapsed='..string.format('%.3f',elapsed)..' expected='..seconds..' drop='..tostring(def.drops and harvest and not c.debug))
                end
            end)
            if not ok then P:cancelMining('error',true,true);return true end
            return mining~=watch
        end)
    end
    function P:place(repeatHeld)
        local env=ctx.active();if env.controller:IsMoveInputIgnored() or ctx.pending() then return end
        if env.controller:IsRiding()then return end
        if not ctx.gameplayInput(env)then return end
        if not repeatHeld and self.items and self.items:rightClick(env)then return end
        if not self.items and self.selected<5 then return end
        if self.items then
            local item=self.items:hotbar(env,self.selected).id;local block=false

            for i,d in ipairs(registry)do if d.item==item then block=true;ctx.setType(i);break end end
            if not block then return end
        end
        ctx.place()
    end
    function P:toggle()
        local env=ctx.active();self.visible=not self.visible
        hud.widget:SetVisibility(self.visible and 3 or 1);setNative(env,self.visible)
        if self.captureHUD then self.captureHUD(env,self.visible)end
        if ctx.config.task20_ui and ctx.uiKit then ctx.uiKit:quests(nodes,env,false);ctx.uiKit:nativeHUD(nodes,env,self.visible,ctx.gameplayInput(env),self)end
        log('MC_HUD_TOGGLE minecraft='..tostring(self.visible))
    end
    function P:selfTest()
        local env=ctx.active()
        assert(valid(hud.widget),'Minecraft HUD missing')
        self:updateHotbar(env);self:updateWeapons(env,false);self:updateStats(env)
        local checked=0
        for _,prefix in ipairs({'Heart','Food','Armor'}) do
            for i=1,10 do assert(valid(nodes[prefix..i]),'Missing HUD node '..prefix..i);checked=checked+1 end
        end
        for i=1,9 do
            for _,prefix in ipairs({'Icon','Count','Select'}) do assert(valid(nodes[prefix..i]),'Missing hotbar node');checked=checked+1 end
            assert(nodes['Select'..i]:GetVisibility()==(i==self.selected and 3 or 1),'Hotbar highlight mismatch')
        end
        for _,name in ipairs({'Level','XPProgress','Stamina','PalHP1','PalName1','PalIcon1'}) do
            assert(valid(nodes[name]),'Missing HUD node '..name);checked=checked+1
        end
        for i=1,9 do
            local inventory,item
            if not self.items and i>=5 then inventory,item=ctx.inventory(env,self.blocks[i-4])end
            local shown=UE.GetKismetTextLibrary():Conv_TextToString(nodes['Count'..i]:GetText())
            shown=type(shown)=='string' and shown or shown:ToString()
            local expected=self.items and self.items:hotbar(env,i).count or (inventory and inventory:CountItemNum(item)or 0)
            local entry=self.items and self.items:hotbar(env,i);local data=entry and entry.id and self.items:data(entry.id);local stack=expected>1 and not(valid(data)and data.TypeA==1)
            if not(valid(data)and data.TypeA==1)then assert((not stack and shown=='')or(stack and tonumber(shown)==expected),'Hotbar inventory count mismatch slot='..i..' shown='..shown..' expected='..expected)end;if expected==0 then assert(nodes['Icon'..i]:GetVisibility()==1,'Empty alias has an icon')end
        end
        local n=0
        for _,entry in pairs(hidden) do
            if currentHidden(entry) then assert(entry.node:GetRenderOpacity()==0,'Native HUD node not transparent');n=n+1 end
        end
        local held=env.player.ShooterComponent:GetHasWeapon()
        if self.items then
            local id=self.items:hotbar(env,self.selected).id
            local data=id and self.items:data(id)
            if valid(data)and data.TypeA==1 then assert(valid(held)and held:GetItemId().StaticId:ToString()==id,'Any-item weapon/highlight mismatch')
            else assert(not valid(held),'Block/food slot is not empty-handed')end
        else assert(valid(held) and held:GetLoadoutSelectorIndex()==self.selected-1,'Native weapon/highlight mismatch') end
        log('SELF_TEST PASS HUD nodes='..checked..' counts=9 selection='..self.selected..' hidden='..n)
    end
    function P:teardown(env)
        if env then setNative(env,false)end
        if valid(hud.widget)then hud.widget:RemoveFromParent()end
        if overlay and valid(overlay.actor)then overlay.actor:K2_DestroyActor()end
        self:cancel()
    end
    function P:retireViewport(env)if valid(hud.widget)then hud.widget:RemoveFromParent()end end
    function P:ready78(env)
        return owner~=nil and owner.player==env.player:GetAddress()and self.statLogged==true
            and self.visible and valid(hud.widget)and hud.widget:IsInViewport()
    end
    function P:applyScale(env)if valid(hud.widget)and ctx.uiKit then local _,u=ctx.uiKit:apply(hud.widget,'WBP_MCHUD',env);self.uiUnit=u end end
    function P:cancel()
        if statHandle then Timers.cancel(statHandle);statHandle=nil end
        if mining and mining.handle then Timers.cancel(mining.handle) end
        self.cooldownNodes66=nil;self.cooldownBucket66=nil;UE.attack66=nil
        mining=nil;overlay=nil;hud={};nodes={};hidden={};hiddenOrder={};hideCursor=0;owner=nil;weaponUpdatePending=false;self.weaponDirty65=nil;self.hudAlive=nil;self.cinematicCV=nil;self.armorPointsCV=nil
        self.nativeDiscovered=false;self.hudProfile=nil;self.nativeWeightText=nil;self.weightAt=nil;self.shownWeight=nil;self.nativePalName=nil;self.nativeThermometer=nil;self.palNames=nil;weaponTextures={}
        assets={};assetIds={};rowValues={};iconPaths={};selfHide=nil;self.toastCounts=nil
        self.statLogged=false;self.partyLogged=false;self.partySeen73=nil;self.lastPartyAt=nil;self.partySlotsL=nil;self.partyHolderL=nil;self.weaponIDs=nil;self.displayedXP=nil;self.displayedLevel=nil;self.weaponVisual=nil;self.hotbarVisual=nil
        self.timeManager=nil;self.statParameter=nil;self.statIndividual=nil;self.shownStamina=nil;self.shownXPRatio=nil;self.shownXPUnit=nil;self.defenseAt=nil;self.expDatabase=nil;self.expLevel=nil;self.expLow=nil;self.expHigh=nil;self.clockFrame=nil;self.foodAt=nil;self.clockAt=nil
    end
    function P:earlyHUD(controller)
        if valid(hud.widget)and hud.widget:IsInViewport()and hud.controller==controller:GetAddress()then return end
        if valid(hud.widget)then hud.widget:RemoveFromParent()end
        local e={player=controller,controller=controller,identity='ui-entry'}
        hud=assert(ctx.createUI(e,'WBP_MCHUD','phase_a'));hud.controller=controller:GetAddress();hud.early=true;nodes=ctx.uiWidgets(hud.widget);self.uiUnit=(hud.uiFactor or 1)*3
        hud.widget:SetRenderOpacity(0);hud.widget:SetVisibility(3);if ctx.uiKit then ctx.uiKit:bindIconCacheRoot(nodes.Crosshair:GetParent())end
        for i=1,5 do for _,prefix in ipairs({'Party','PalIcon','PalLevel','PalHP','PalName'})do if valid(nodes[prefix..i])then nodes[prefix..i]:SetVisibility(1)end end end
        log('MC36_HUD_UI_PRESENT pawn_reads=0')
    end
    function P:setLife(status,env)
        local alive=status=='alive'
        local cinematic=false
        if env and valid(env.controller)then
            local cut=env.controller.CutsceneComponent
            cinematic=valid(cut)and cut:IsPlayingCutscene()or false
            if not cinematic then
                local view=env.controller:GetViewTarget()
                cinematic=valid(view)and view:IsA(UE.Object('/Script/Engine.CameraActor'))
            end
        end
        if self.cinematicCV~=cinematic then self.cinematicCV=cinematic;log('MCCV_CINEMATIC_HUD hidden='..tostring(cinematic))end
        local modal=(self.items and self.items.open)or(self.menuOpen and self.menuOpen())
        local cover=UE.loadingCover51
        local covered=cover and(cover.armed or cover.at)
        local alpha=alive and self.visible and not modal and not covered and not cinematic and 1 or 0
        if valid(hud.widget)and hud.widget:GetRenderOpacity()~=alpha then hud.widget:SetRenderOpacity(alpha)end
        if self.hudAlive~=alive then self.hudAlive=alive;log('MC44_HUD_LIFE alive='..tostring(alive)..' pawn_reads=0')end
    end
    function P:start(env)
        self:installStartupHooks()
        local early=hud;self:cancel();hud=early;owner={identity=env.identity,player=env.player:GetAddress(),shooter=env.player.ShooterComponent:GetAddress(),loadout=env.player.LoadoutSelectorComponent:GetAddress()}
        if ctx.config.bpHooks~=false and not self.weaponUIHook then

            local fn='/Game/Pal/Blueprint/UI/UserInterface/InGame/PlayerGauge/WBP_Ingame_WeaponChange.WBP_Ingame_WeaponChange_C:SelectWeapon'
            assert(valid(StaticFindObject(fn)),'Native weapon selection event missing')
            self.weaponUIHook=Timers.hook(fn,function()P.weaponDirty65=true end)
            log('MC_WEAPON_UI_HOOK SelectWeapon')
        end
        for _,gauge in ipairs(nativeWidgetList(env,'WBP_Ingame_PalHPGauge_C')) do
            self.nativePalName=ctx.uiWidgets(gauge).Text_PalName;break
        end
        for _,w in ipairs(nativeWidgetList(env,'WBP_Ingame_Thermometer_C'))do self.nativeThermometer=w;break end
        if self.uiEntry then self.uiEntry:bindCurrent(env.controller)end
        self:earlyHUD(env.controller);nodes=ctx.uiWidgets(hud.widget);self.uiUnit=(hud.uiFactor or 1)*3
        if ctx.uiKit then ctx.uiKit:bindIconCacheRoot(nodes.Crosshair:GetParent())end
        self.visible=ctx.config.hud;hud.widget:SetVisibility(self.visible and 3 or 1)
        setNative(env,self.visible);self:updateStats(env);self:select(5)
        local stamp=ctx.epoch()

        local slotVF=1;self.hotbarReadyVF=nil
        Timers.loop(1,function()
            if stamp~=ctx.epoch()or ctx.quiesced()then return true end
            local current=live(stamp);if not current then return false end
            self:updateHotbar(current,slotVF);slotVF=slotVF+1
            if slotVF>9 then self.hotbarReadyVF=stamp;return true end
            return false
        end,'hotbar-prewarm-vf')
        statHandle=Timers.loop(200,function()
            local current=live(stamp);if not current then return true end
            local ok=guarded('stats',function() P:updateStats(current);if P.captureHUD then P.captureHUD(current,P.visible)end end)
            return not ok
        end)
        dofile(ctx.base..'/dx_guard68.lua').entry(ctx,env)
        log('MC_READY hud=true slots=9 interval_ms=250')
    end
    function P:installStartupHooks()
        if self.startupHooks then return end;self.startupHooks=true
    
    for _,fn in ipairs({'/Script/Pal.PalShooterComponent:ChangeWeapon','/Script/Pal.PalLoadoutSelectorComponent:OnRep_CurrentItemSlotIndex','/Script/Pal.PalLoadoutSelectorComponent:OnUpdateWeaponLoadoutSlot'}) do
        if valid(StaticFindObject(fn)) then
            local pre,post=Timers.hook(fn,function()end,function()P.weaponDirty65=true end)
            P.hooks[#P.hooks+1]={fn=fn,pre=pre,post=post}
        end
    end
    end
    Timers.frame('weapon-events',function()if P.weaponDirty65 and not ctx.quiesced()then P.weaponDirty65=nil;weaponChanged()end end)
    Timers.onEpoch('phase-a',function()P:cancel()end)
    return P
end
