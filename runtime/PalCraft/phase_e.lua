-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,h)
    local E={page=0,band=1,techPage=0};local UE,valid,log=ctx.UE,ctx.valid,ctx.log;local Timers=dofile(ctx.base..'/timers.lua')
    local nodes,kind,rows,party,box,storage;local lower={}
    for n,p in pairs(dofile(ctx.base..'/native_icons.lua'))do lower[n:lower()]=p end
    local function unwrap(v)local ok,o=pcall(function()return v:get()end);return ok and o or v end
    local function arr(v)local a={};if type(v)=='table'then for _,o in ipairs(v)do a[#a+1]=unwrap(o)end else v:ForEach(function(_,o)a[#a+1]=o:get()end)end;return a end
    local function fname(v)return type(v)=='string'and v or v:ToString()end
    local function guid(g)return{A=g.A,B=g.B,C=g.C,D=g.D}end
    local function cid(v)return{ID=guid(v.ID)}end
    local function sid(slot)local s=slot:GetSlotId();return{ContainerId=cid(s.ContainerId),SlotIndex=s.SlotIndex}end
    local function idkey(slot)local s=sid(slot);return table.concat({s.ContainerId.ID.A,s.ContainerId.ID.B,s.ContainerId.ID.C,s.ContainerId.ID.D,s.SlotIndex},':')end
    local function resolved(value,env)
        return value:gsub('<itemName id=|([^|]+)|/>',function(id)return ctx.items:label(id)end):gsub('<mapObjectName id=|([^|]+)|/>',function(id)return h.nativeText(env,'GetMapObjectName',UE.FindOrAddFName(id))end)
    end
    local function parameter(slot)return valid(slot)and not slot:IsEmpty()and slot.ReplicateIndividualParameter or nil end
    function E:containers(env)
        local state=env.controller:GetPalPlayerState();storage=state:GetPalStorage();box=storage.TargetContainer
        local manager=UE.Object('/Script/Pal.Default__PalUtility'):GetCharacterContainerManager(env.player)
        party=manager:GetContainer(cid(state:GetPalPlayerOtomoData().OtomoCharacterContainerId));assert(valid(party),'Own party container unavailable')
        assert(valid(box),'Own box container unavailable');return party,box
    end
    function E:total()
        local n=0;for _,c in ipairs({party,box})do for i=0,c:Num()-1 do if not c:Get(i):IsEmpty()then n=n+1 end end end;return n
    end
    function E:pal(slot)
        local d=parameter(slot);if not valid(d)then return nil end
        local id=fname(d:GetCharacterID());local out={};_G.MC_OUT_K('GetDisplayNickName',UE.Object('/Script/Pal.Default__PalUIUtility'),ctx.active().player,UE.FindOrAddFName(id),UE.FindOrAddFName('None'),out)
        local name=fname(d.SaveParameter.NickName);if name==''then name=out.OutNickName and fname(out.OutNickName)or id end
        return{d=d,id=id,name=name,icon=lower[('T_'..id..'_icon_normal'):lower()]}
    end
    function E:summary(slot,env)
        local p=self:pal(slot);self.selected=slot
        if not p then h.text(nodes.Name,slot and not slot:IsEmpty()and'Loading Pal…'or'Empty slot');h.icon(nodes.Portrait,nil);h.text(nodes.Level,'');h.text(nodes.Types,'');h.text(nodes.HPText,'');nodes.HP:SetPercent(0);if ctx.config.task20_ui then ctx.uiKit:pcDetails(nodes,env,nil)end;return end
        h.icon(nodes.Portrait,p.icon);h.text(nodes.Name,p.name);h.text(nodes.Level,'Lv '..p.d:GetLevel());h.text(nodes.HPText,string.format('HP %.0f / %d',p.d:GetHP().Value/1000,p.d:GetMaxHP()));nodes.HP:SetPercent(p.d:GetHP().Value/math.max(1000,p.d:GetMaxHP()*1000))
        local a,b={},{};UE.Object('/Script/Pal.Default__PalUtility'):GetDatabaseCharacterParameter(env.player):GetElementType(UE.FindOrAddFName(p.id),a,b)
        local names={};for _,e in ipairs({a.Element1 or 0,b.Element2 or 0})do if e>0 then names[#names+1]=h.nativeText(env,'GetPalElementTypeName',e)end end;h.text(nodes.Types,table.concat(names,' / '))
        p.elements={};for _,e in ipairs({a.Element1 or 0,b.Element2 or 0})do if e>0 then p.elements[#p.elements+1]={id=e,label=h.nativeText(env,'GetPalElementTypeName',e)}end end
        if ctx.config.task20_ui then ctx.uiKit:pcDetails(nodes,env,p)end
    end
    function E:refreshPC(env)
        if nodes and nodes.ui67 then return end
        self.pcPages54=storage:GetPageNum()
        for i=1,5 do local s=party:Get(i-1);local p=self:pal(s);local carried=self.carry and idkey(self.carry)==idkey(s)
            h.icon(nodes['PartyIcon'..i],not carried and(p and p.icon or s:IsEmpty()and'/Game/MinecraftBlocks/T_MC_ESlot.T_MC_ESlot'));h.text(nodes['PartyName'..i],carried and''or p and(ctx.config.task20_ui and''or p.name) or s:IsEmpty()and'Empty'or'Loading…');h.text(nodes['PartyLevel'..i],ctx.config.task20_ui and''or p and'Lv '..p.d:GetLevel()or'')end
        for i=1,30 do local s=box:Get(self.page*30+i-1);local p=self:pal(s);h.icon(nodes['BoxIcon'..i],not(self.carry and idkey(self.carry)==idkey(s))and p and p.icon)end
        h.text(nodes.BoxTitle,'Box '..(self.page+1)..' / '..storage:GetPageNum());h.text(nodes.Totals,'Pals: '..(self.lastTotal or self:total()))
        h.icon(nodes.CarryIcon,self.carry and(self:pal(self.carry)or{}).icon);if self.selected then self:summary(self.selected,env)end
        if ctx.config.task20_ui then local s=self.selectedGrid54;if s and not s.party and math.floor(s.index/30)~=self.page then s=nil end;ctx.uiKit:pcSelection54(nodes,env,s)end
    end
    function E:move(env,source,target)
        if self.pending or self.stopped then return end
        if idkey(source)==idkey(target)or source:IsEmpty()or source:IsLocked()or target:IsLocked()then log('MC_E_PC_MOVE_REJECT same_empty_or_locked');return end
        local before=self:total();local a,b=source:GetHandle(),target:GetHandle();local from,to=idkey(source),idkey(target)
        local net=UE.Object('/Script/Pal.Default__PalUtility'):GetNetworkTransmitterByPlayerCharacter(env.player):GetCharacterContainer()
        assert(valid(net));self.pending={source=source,target=target,before=before,a=valid(a)and a:GetAddress()or 0,b=valid(b)and b:GetAddress()or 0,ticks=0,from=from,to=to}
        net:RequestSwap_ToServer_Rep(sid(source),sid(target));self.carry=nil;self:checkMove(env)
    end
    function E:checkMove(env)
        local p=self.pending;if not p then return end;local total=self:total()
        if total~=p.before then self.stopped=true;self.pending=nil;self.carry=nil;log('MC_E_PC_COUNT_FAIL before='..p.before..' after='..total..' moves_disabled=true');return end
        local a,b=p.source:GetHandle(),p.target:GetHandle();local aa,bb=valid(a)and a:GetAddress()or 0,valid(b)and b:GetAddress()or 0
        if aa==p.b and bb==p.a then self.pending=nil;self.lastTotal=total;log('MC_E_PC_MOVE_PASS total='..total..' swap='..tostring(p.b~=0)..' from='..p.from..' to='..p.to);self:refreshPC(env)
        else p.ticks=p.ticks+1;if p.ticks>=20 then self.pending=nil;log('MC_E_PC_MOVE_REJECT native_request_not_settled total='..total)end end
    end
    function E:quick(env,source,inParty)
        local target=inParty and box or party
        for i=0,target:Num()-1 do local s=target:Get(i);if s:IsEmpty()and not s:IsLocked()then self:move(env,source,s);return end end;log('MC_E_PC_QUICK_REJECT no_free_slot')
    end
    function E:techRows(env)
        local data=env.controller:GetPalPlayerState():GetTechnologyData();self.tech=data;local result={};local max=1
        for _,name in ipairs(arr(data:GetRecipeTechnologyRowNameArray(false)))do local row=data:GetTechlonogyBaseData(name)
            local lv=math.max(1,row.LevelCap);result[#result+1]={name=name,id=fname(name),row=row,band=row.IsBossTechnology and 10 or math.min(9,math.floor((lv-1)/10)+1)};max=math.max(max,lv)
        end
        table.sort(result,function(a,b)return a.row.LevelCap==b.row.LevelCap and a.id<b.id or a.row.LevelCap<b.row.LevelCap end);rows=result;self.rows67=result
        log('MC_E_TECH_DATA rows='..#rows..' max_level='..max..' points='..data:GetTechnologyPoints()..' ancient='..data:GetBossTechnologyPoints())
    end
    function E:techIcon(env,e)
        local name=fname(e.row.IconName);local exact=lower[name:lower()];if exact then return h.asset(exact)end
        
        if not self.iconSignature then self.iconSignature=true;local fn=StaticFindObject('/Game/Pal/Blueprint/UI/System/BP_PalUIFunctionLibrary.BP_PalUIFunctionLibrary_C:GetTechnologyIcon')
            if valid(fn)then fn:ForEachProperty(function(p)log('MC_E_ICON_PARAM '..p:GetFullName())end)end end
        local library=StaticFindObject('/Game/Pal/Blueprint/UI/System/BP_PalUIFunctionLibrary.Default__BP_PalUIFunctionLibrary_C')
        if valid(library)then
            for _,id in ipairs({e.row.IconName,e.name})do local out={};local ok=pcall(function()_G.MC_OUT_K('GetTechnologyIcon',library,id,env.player,out)end)
                if ok and out.SoftIconTexture then local path=fname(UE.GetKismetSystemLibrary():Conv_SoftObjectReferenceToString(out.SoftIconTexture));if path~=''then return h.asset(path)end end end
        end
        return nil
    end
    function E:refreshTech(env)
        if nodes and nodes.ui67 then return end
        self.panX,self.panY=0,0;self.drag,self.press,self.hover=nil,nil,nil
        h.text(nodes.Points,'Points '..self.tech:GetTechnologyPoints()..'     Ancient '..self.tech:GetBossTechnologyPoints())
        for i=1,10 do h.text(nodes['TabLabel'..i],i==10 and'Ancient'or((i-1)*10+1)..'–'..(i==9 and'90+'or i*10));h.icon(nodes['TabFrame'..i],'/Game/MinecraftBlocks/T_MC_'..(i==self.band and'ETab'or'GTab')..'.T_MC_'..(i==self.band and'ETab'or'GTab'));nodes['TabFrame'..i]:SetColorAndOpacity({R=1,G=1,B=1,A=1})end
        self.filtered={};for _,e in ipairs(rows)do if e.band==self.band then self.filtered[#self.filtered+1]=e end end
        if ctx.config.task20_ui then
            local v=ctx.uiKit:view(nodes,env,252,140)
            for i=1,10 do local first;for _,e in ipairs(rows)do if e.band==i then first=e;break end end
                ctx.uiKit:brush(nodes['TabFrame'..i],'T_MC_UI20_tab_above');h.text(nodes['TabLabel'..i],'')
                local t=first and self:techIcon(env,first);if valid(t)then v:image((i-1)*25+4,-21,16,16,t,{outline=1})end
            end
        end
        h.text(nodes.Band,(self.band==10 and'Ancient technology'or'Level band '..self.band)..'    Page '..(self.techPage+1)..'/'..math.max(1,math.ceil(#self.filtered/(ctx.config.task20_ui and 32 or 36))))
        local iconCount=0;for i=1,36 do local e=i<=(ctx.config.task20_ui and 32 or 36)and self.filtered[self.techPage*(ctx.config.task20_ui and 32 or 36)+i];nodes['TechFrame'..i]:SetVisibility(e and 3 or 1)
            if e then local unlocked=self.tech:IsUnlockRecipeTechnology(e.name);local available=self.tech:IsUnlockableRecipeTechnology(e.name)
                if ctx.config.task20_ui then ctx.uiKit:brush(nodes['TechFrame'..i],unlocked and'T_MC_UI20_tech_obtained'or'T_MC_UI20_tech_unobtained')else h.icon(nodes['TechFrame'..i],'/Game/MinecraftBlocks/T_MC_'..(unlocked and'EUnlocked'or'EAvailable')..'.T_MC_'..(unlocked and'EUnlocked'or'EAvailable'))end
                nodes['TechFrame'..i]:SetColorAndOpacity((unlocked or available)and{R=1,G=1,B=1,A=1}or{R=.4,G=.4,B=.4,A=1})
                local texture=self:techIcon(env,e);nodes['TechIcon'..i]:SetVisibility(valid(texture)and 3 or 1);if valid(texture)then if ctx.config.task20_ui then ctx.uiKit:icon(nodes['TechIcon'..i],texture);nodes['TechIcon'..i]:SetColorAndOpacity((unlocked or available)and{R=1,G=1,B=1,A=1}or{R=.4,G=.4,B=.4,A=1})else nodes['TechIcon'..i]:SetBrushFromTexture(texture,false)end;iconCount=iconCount+1 end;h.text(nodes['TechCost'..i],e.row.Cost)
            else nodes['TechIcon'..i]:SetVisibility(1);h.text(nodes['TechCost'..i],'')end end
        if ctx.config.task20_ui then ctx.uiKit:techTree(nodes,env,self)end
        if self.scroll then self.scroll:SetScrollOffset(0)end
        local perPage=ctx.config.task20_ui and 32 or 36
        log('MC_E_TECH_VIEW entries='..math.min(perPage,#self.filtered-self.techPage*perPage)..' native_icons='..iconCount)
    end
    local function inViewport(x,y)return x>=-117 and x<117 and y>=-52 and y<61 end
    function E:beginPress(env,x,y,shift)
        self:click(env,x,y,shift)
        if kind=='PC'and self.carry and not shift then self.drag46={x=x,y=y,moved=false}end
    end
    function E:unlock(env,e)
        if not self.tech:IsUnlockableRecipeTechnology(e.name)or self.tech:IsUnlockRecipeTechnology(e.name)then log('MC_E_TECH_UNLOCK_REJECT '..e.id);return end
        local boss=e.row.IsBossTechnology;local before=boss and self.tech:GetBossTechnologyPoints()or self.tech:GetTechnologyPoints()
        ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);self.tech:RequestUnlockRecipeTechnology(e.name);ctx.uiKit:notify('Technology unlocked',fname(UE.GetKismetTextLibrary():Conv_TextToString(self.tech:GetTechnologyName(e.name))));local after=boss and self.tech:GetBossTechnologyPoints()or self.tech:GetTechnologyPoints()
        local ok=self.tech:IsUnlockRecipeTechnology(e.name)and before-after==e.row.Cost;log('MC_E_TECH_UNLOCK_'..(ok and'PASS'or'PENDING')..' id='..e.id..' before='..before..' after='..after..' cost='..e.row.Cost);self:refreshTech(env)
    end
    function E:prepare67(env,view,mode)

        nodes,kind=view,mode or'PC';self.carry=nil;self.lastTotal=nil
    end
    function E:show(env,mode,view)
        nodes,kind=view,mode;self.carry,self.pending,self.selected=nil,nil,nil
        if mode=='PC'then self:containers(env);self.page=0;env.controller:GetPalPlayerState():RequestPalBoxSyncPage_ToServer(0);self.lastTotal=self:total();local initial=party:Get(0);local initialIndex=0;for i=0,party:Num()-1 do if not party:Get(i):IsEmpty()then initial=party:Get(i);initialIndex=i;break end end;self.selectedGrid54={party=true,index=initialIndex};self:summary(initial,env);self:refreshPC(env);log('MC_E_PC_OPEN party='..party:Num()..' box='..box:Num()..' total='..self.lastTotal)
        else self.band,self.techPage=1,0;self:techRows(env)
            if ctx.config.task20_ui then self.scroll,self.scrollUnit=ctx.uiKit:technologyScroll(nodes,env,ctx.menu.uiFactor*3)end
            self:refreshTech(env)
        end
    end
    function E:tick(env,tick)
        if kind=='PC'then self:checkMove(env);if tick%10==0 then self:refreshPC(env)end
            local x,y=ctx.items:mouse(env);local f=ctx.menu and ctx.menu.uiFactor or 1;nodes.CarryIcon.Slot:SetPosition({X=(x-24)*f,Y=(y-24)*f});nodes.CarryIcon.Slot:SetZOrder(90);nodes.CarryIcon:SetRenderOpacity(.8)
            if self.drag46 then local d=self.drag46;if math.abs(x-d.x)+math.abs(y-d.y)>9 then d.moved=true end
                if not env.controller:IsInputKeyDown({KeyName=UE.FindOrAddFName('LeftMouseButton')})then self.drag46=nil;if d.moved and self.carry then self:click(env,x,y,false)end end
            end
            if ctx.config.task20_ui then
                local xx,yy=x/3,y/3;local index,inParty
                if xx>=7-146 and xx<33-146 and yy>=26-100 and yy<26-100+5*28 then index=math.floor((yy+74)/28);inParty=true
                elseif xx>=40-146 and xx<196-146 and yy>=26-100 and yy<156-100 then index=math.floor((yy+74)/26)*6+math.floor((xx+106)/26)end
                local slot=index and(inParty and party:Get(index)or box:Get(self.page*30+index));local p=valid(slot)and self:pal(slot)
                local _,unit=ctx.uiKit:metrics(env);local tip=p and{title=p.name,source='Palworld',lines={'Lv '..p.d:GetLevel(),string.format('HP %.0f / %d',p.d:GetHP().Value/1000,p.d:GetMaxHP()),'Attack '..p.d:GetShotAttack()..'  Defense '..p.d:GetDefense()}}
                ctx.uiKit:richTooltip(nodes,tip,xx,yy,unit)
                local hover=ctx.uiKit:makeNode(nodes,'PC46Hover','Image');hover:SetVisibility(index and 3 or 1)
                if index then local hx=inParty and(7-146)or(40-146+index%6*26);local hy=26-100+(inParty and index*28 or math.floor(index/6)*26);ctx.uiKit:fill(hover,'FFFFFF',.15);ctx.uiKit:position(hover,hx,hy,26,26,unit);hover.Slot:SetZOrder(44);if tip then tip.exclude={x=hx,y=hy,w=26,h=26};ctx.uiKit:richTooltip(nodes,tip,xx,yy,unit)end end
            end
        elseif kind=='Technology'then
            if valid(self.scroll)then local offset=self.scroll:GetScrollOffset();self.panY=-offset/self.scrollUnit
                if math.abs(offset-(self.lastScroll or 0))>1 then log('MC22_TECH_SCROLL offset='..offset..' gui_offset='..(-self.panY)..' native_scrollbox=true');self.lastScroll=offset;self.hover=nil end
            end
            local x,y=ctx.items:mouse(env);local e;local cursorX,cursorY=x/3,y/3;if ctx.config.task20_ui then
            if inViewport(cursorX,cursorY)and not(self.drag and self.drag.moved)then x,y=ctx.uiKit:mapInput('WBP_MCTechnology',x-(self.panX or 0)*3,y-(self.panY or 0)*3)else x,y=-99999,-99999 end
        end
            for i=1,36 do local xx=-530+(i-1)%9*118;local yy=-150+math.floor((i-1)/9)*88;if x>=xx and x<xx+100 and y>=yy and y<yy+70 then e=self.filtered[self.techPage*(ctx.config.task20_ui and 32 or 36)+i];break end end
            if e and self.hover~=e.id then self.hover=e.id;local name=fname(UE.GetKismetTextLibrary():Conv_TextToString(self.tech:GetTechnologyName(e.name)));local desc=fname(UE.GetKismetTextLibrary():Conv_TextToString(self.tech:GetTechnologyDesc(e.name)))
                local content=resolved(name,env)..'\n'..resolved(desc,env)..'\nCost: '..e.row.Cost..' points / Requires Lv '..e.row.LevelCap;if ctx.config.task20_ui then content=ctx.uiKit:wrap(content,162,7)end;h.text(nodes.Tooltip,content)end
            if ctx.config.task20_ui then
                local _,unit=ctx.uiKit:metrics(env);local tip
                if e then local label=fname(UE.GetKismetTextLibrary():Conv_TextToString(self.tech:GetTechnologyName(e.name)));local desc=fname(UE.GetKismetTextLibrary():Conv_TextToString(self.tech:GetTechnologyDesc(e.name)))
                    local unlocked=self.tech:IsUnlockRecipeTechnology(e.name);local allowed=self.tech:IsUnlockableRecipeTechnology(e.name)
                    tip={title=resolved(label,env),color=unlocked and'blue'or'white',source='Palworld',lines={{text=resolved(desc,env)},{text=unlocked and'Unlocked'or('Cost: '..e.row.Cost..' points'),color=unlocked and'blue'or'yellow'},{text='Requires Lv '..e.row.LevelCap,color=allowed and'gray'or'red'}}}
                    for _,r in pairs(self.treeRects or{})do if r.e==e then tip.exclude={x=r.x,y=r.y+(self.panY or 0),w=r.w,h=r.h};break end end
                end
                ctx.uiKit:richTooltip(nodes,tip,cursorX,cursorY,unit)
                local glow=ctx.uiKit:makeNode(nodes,'Tech46Hover','Image');glow:SetVisibility(e and 3 or 1);if e and tip.exclude then local r=tip.exclude;ctx.uiKit:fill(glow,'FFFFFF',.15);ctx.uiKit:position(glow,r.x,r.y,r.w,r.h,unit);glow.Slot:SetZOrder(44)end
            end
        end
    end
    function E:click(env,x,y,shift)
        if ctx.config.task20_ui and kind=='Technology'then local xx,yy=x/3,y/3
            if yy>=-70 and yy<-52 and xx>=-117 and xx<113 then self.band=math.floor((xx+117)/23)+1;self.techPage=0;ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);self:refreshTech(env);return end
            if yy>=70 and yy<80 and xx>=99 and xx<121 then self.techPage=math.max(0,math.min(math.ceil(#self.filtered/32)-1,self.techPage+(xx<110 and-1 or 1)));self:refreshTech(env);return end
        end
        if ctx.config.task20_ui and kind=='PC'and y/3>=-93 and y/3<-76 and((x/3>=-103 and x/3<-91)or(x/3>=58 and x/3<70))then
            self.page=math.max(0,math.min(storage:GetPageNum()-1,self.page+(x/3<0 and-1 or 1)));ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);env.controller:GetPalPlayerState():RequestPalBoxSyncPage_ToServer(self.page);self:refreshPC(env);return
        end
        if ctx.config.task20_ui then
            if kind=='Technology'and inViewport(x/3,y/3)then x,y=x-(self.panX or 0)*3,y-(self.panY or 0)*3 end
            x,y=ctx.uiKit:mapInput(kind=='PC'and'WBP_MCPC'or'WBP_MCTechnology',x,y)
        end
        if kind=='PC'then
            if y>=-277 and y<-235 then if x>=230 and x<272 then self.page=math.max(0,self.page-1)elseif x>=286 and x<328 then self.page=math.min(storage:GetPageNum()-1,self.page+1)else return end
                ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);env.controller:GetPalPlayerState():RequestPalBoxSyncPage_ToServer(self.page);self:refreshPC(env);return end
            local s,inParty
            if x>=-540 and x<-280 and y>=-230 and y<230 then local i=math.floor((y+230)/92);s=party:Get(i);inParty=true
            elseif x>=-245 and x<271 and y>=-222 and y<228 then local col,row=math.floor((x+245)/86),math.floor((y+222)/90);s=box:Get(self.page*30+row*6+col)end
            if not valid(s)then return end;self.selectedGrid54={party=inParty==true,index=s:GetSlotId().SlotIndex};self:summary(s,env)
            if shift and not s:IsEmpty()then self:quick(env,s,inParty)elseif self.carry then self:move(env,self.carry,s)elseif not s:IsEmpty()and not s:IsLocked()then self.carry=s;log('MC_E_PC_CARRY source_native_retained=true')end;self:refreshPC(env)
        else
            if y>=-268 and y<-226 and x>=-535 and x<525 then self.band=math.floor((x+535)/106)+1;ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);self.techPage=0;self:refreshTech(env);return end
            if y>=-208 and y<-173 then if x>=400 and x<440 then self.techPage=math.max(0,self.techPage-1)elseif x>=470 and x<510 then self.techPage=math.min(math.max(0,math.ceil(#self.filtered/(ctx.config.task20_ui and 32 or 36))-1),self.techPage+1)else return end;self:refreshTech(env);return end
            for i=1,36 do local xx=-530+(i-1)%9*118;local yy=-150+math.floor((i-1)/9)*88;if x>=xx and x<xx+100 and y>=yy and y<yy+70 then local e=i<=(ctx.config.task20_ui and 32 or 36)and self.filtered[self.techPage*(ctx.config.task20_ui and 32 or 36)+i];if e then self:unlock(env,e)end;return end end
        end
    end
    function E:cancel()Timers.cancel(self.inputToken);self.inputToken=nil;nodes,kind,rows,party,box,storage=nil,nil,nil,nil,nil,nil;self.drag46=nil;self.carry,self.pending,self.selected,self.tech,self.filtered,self.hover,self.drag,self.press,self.scroll,self.scrollUnit,self.lastScroll=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil end
    function E:debugUnlock(env)
        assert(ctx.config.debug and kind=='Technology');for _,e in ipairs(rows)do if e.row.Cost>0 and not e.row.IsBossTechnology and self.tech:IsUnlockableRecipeTechnology(e.name)and not self.tech:IsUnlockRecipeTechnology(e.name)then self:unlock(env,e);return end end
        log('MC_E_TECH_DEBUG_UNLOCK_NO_AVAILABLE')
    end
    function E:nativeWallUnlock(env)
        assert(ctx.config.debug);env.controller:Debug_AddPlayerExp_ToServer(1000);self:techRows(env)
        for _,e in ipairs(rows)do local builds=arr(self.tech:GetRecipeTechlonogy(e.name).UnlockBuildObjects)
            for _,n in ipairs(builds)do local id=fname(n):lower();if id:find('wood',1,true)and id:find('wall',1,true)then
                if not self.tech:IsUnlockRecipeTechnology(e.name)then self.tech:RequestUnlockRecipeTechnology(e.name)end
                log('MC_E_NATIVE_WALL_TECH id='..e.id..' build='..fname(n)..' unlocked='..tostring(self.tech:IsUnlockRecipeTechnology(e.name))..' points='..self.tech:GetTechnologyPoints());return end end end
        log('MC_E_NATIVE_WALL_TECH_PARKED no_matching_native_row')
    end
    dofile(ctx.base..'/timers.lua').onEpoch('phase-e',function()E:cancel()end)
    return E
end
