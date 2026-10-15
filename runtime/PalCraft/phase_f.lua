-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,h)
    local Timers=dofile(ctx.base..'/timers.lua')
    local UE,valid,log=ctx.UE,ctx.valid,ctx.log
    local F={page=0,quantity=1};local nodes,kind,owner,model,setting,concrete,rows
    local utility
    local function getUtility()if not valid(utility)then utility=UE.Object('/Script/Pal.Default__PalUtility')end;return utility end
    local icons={};for n,p in pairs(dofile(ctx.base..'/native_icons.lua'))do icons[n:lower()]=p end
    local function unwrap(v)local ok,o=pcall(function()return v:get()end);return ok and o or v end
    local function array(v)local out={};if type(v)=='table'then for _,o in ipairs(v)do out[#out+1]=unwrap(o)end else v:ForEach(function(_,o)out[#out+1]=unwrap(o)end)end;return out end
    local function name(v)return type(v)=='string'and v or v:ToString()end
    local function txt(v)return name(UE.GetKismetTextLibrary():Conv_TextToString(v))end
    local function texture(node,value)node:SetVisibility(valid(value)and 3 or 1);if valid(value)then if ctx.config.task20_ui then ctx.uiKit:icon(node,value)else node:SetBrushFromTexture(value,false)end end end
    local function palIcon(env,id)
        local p=icons[('T_'..id..'_icon_normal'):lower()];if p then return p end
        local ref=getUtility():GetDatabaseCharacterParameter(env.player):GetCharacterIconTexture(UE.FindOrAddFName(id));local path=name(UE.GetKismetSystemLibrary():Conv_SoftObjectReferenceToString(ref));return path~=''and path or nil
    end
    function F:recipeRows()
        rows={};local selected=setting:GetRecipeId()
        for _,id in ipairs(array(owner.CachedRecipeIds))do
            setting:SelectRecipe(id);local r=setting:GetRecipe();local product=name(r.Product_Id)
            if product~='None'and product:sub(1,3)~='MC_'then rows[#rows+1]={id=id,key=name(id),product=product,row=r,max=setting:CalcMaxProductableNum()}end
        end
        if #rows>0 then local keep=rows[1].id;for _,r in ipairs(rows)do if r.key==name(selected)then keep=r.id;break end end;setting:SelectRecipe(keep)end
        log('MC_G_PRODUCTION_DATA recipes='..#rows..' model='..model:GetClass():GetFullName())
    end
    function F:refreshProduction(env)
        self.renderSerial=(self.renderSerial or 0)+1;local serial,epoch=self.renderSerial,Timers.epoch
        if self.renderHandle then Timers.cancel(self.renderHandle)end
        self.filtered={};local query=(self.search or''):lower()
        for _,r in ipairs(rows)do if(not self.craftable or r.max>0)and(query==''or ctx.items:label(r.product):lower():find(query,1,true)or r.product:lower():find(query,1,true))then self.filtered[#self.filtered+1]=r end end
        local specs={};local perPage=ctx.config.task20_ui and 20 or 30
        for i=1,30 do local r=i<=perPage and self.filtered[self.page*perPage+i]
            specs[#specs+1]={op='recipe',index=i,product=r and r.product or false,max=r and r.max or 0}
        end
        specs[#specs+1]={op='header',page=(self.page+1)..'/'..math.max(1,math.ceil(#self.filtered/perPage)),filter=self.craftable and'Craftable only [ON]'or'Craftable only [OFF]'}
        if self.selected then specs[#specs+1]={op='selection',key=self.selected.key,product=self.selected.product,count=self.selected.row.Product_Count,quantity=self.quantity}end
        self.renderSpecs=specs;self.render=true;self.renderFrameMax=0;self.renderCpuMs=0;ctx.uiKit.productionAssets={};ctx.uiKit.productionTextStyles={}
        local index,begun=1,os.clock()
        self.renderHandle=Timers.loop(1,function()
            if serial~=self.renderSerial or epoch~=Timers.epoch or kind~='Production'then return true end
            local at=os.clock()
            repeat
                local spec=specs[index];index=index+1
                if spec.op=='recipe'then
                    local i=spec.index;texture(nodes['RecipeIcon'..i],spec.product and ctx.items:icon(spec.product))
                    if not ctx.config.task20_ui then
                    nodes['RecipeFrame'..i]:SetVisibility(spec.product and 3 or 1)
                    nodes['RecipeFrame'..i]:SetColorAndOpacity(spec.max>0 and{R=1,G=1,B=1,A=1}or{R=1,G=.2,B=.2,A=1})
                    end
                elseif spec.op=='header'then h.text(nodes.Page,spec.page);h.text(nodes.Filter,spec.filter)
                elseif spec.op=='selection'then
                    setting:SelectRecipe(UE.FindOrAddFName(spec.key));setting:SetProductNumByInput(spec.quantity);self.quantity=setting:GetProductNum()
                    h.text(nodes.Selected,ctx.items:label(spec.product)..' x'..spec.count);texture(nodes.ProductIcon,ctx.items:icon(spec.product))
                    h.text(nodes.Quantity,'Quantity '..self.quantity..'    Max '..setting:CalcMaxProductableNum())
                    local materials,materialRows,out={},{},{};_G.MC_OUT_K('GetRequiredMaterialInfos',setting,out,false)
                    local totals=ctx.items:prepareView(env).totals
                    for _,m in ipairs(array(out.RequiredMaterialInfos or out))do local id=name(m.StaticItemId);local have=totals[id]or 0;materials[#materials+1]=ctx.items:label(id)..'   '..have..' / '..m.Num;materialRows[#materialRows+1]={id=id,have=have,need=m.Num}end
                    h.text(nodes.Materials,table.concat(materials,'\n'));h.text(nodes.Craft,model:CanStartProduction()==0 and'Craft'or'Cannot craft')
                    if ctx.config.task20_ui then
                        ctx.uiKit.productionOps=specs
                        local ok,err=pcall(ctx.uiKit.production,ctx.uiKit,nodes,env,self,materialRows)
                        ctx.uiKit.productionOps=nil;if not ok then error(err)end
                    end
                else ctx.uiKit:applyProductionOp(nodes,spec)end
            until index>#specs or(os.clock()-at)*1000>=3
            local ms=(os.clock()-at)*1000;self.renderFrameMax=math.max(self.renderFrameMax,ms);self.renderCpuMs=self.renderCpuMs+ms
            if index>#specs then
                self.renderHandle=nil;self.render=nil;ctx.uiKit.productionAssets=nil;ctx.uiKit.productionTextStyles=nil;self.lastRefreshMs=self.renderCpuMs;self.renderElapsedMs=(os.clock()-begun)*1000
                self.refreshTimes=self.refreshTimes or{};self.refreshTimes[#self.refreshTimes+1]=self.renderCpuMs
                self:updateQueue(env);log('MC21_PRODUCTION_BUILD_DONE max_slice_ms='..self.renderFrameMax..' cpu_ms='..self.renderCpuMs..' elapsed_ms='..self.renderElapsedMs);return true
            end
            return false
        end,'production-build')
    end
    function F:updateQueue(env)
        if not valid(concrete)then return end
        local recipe=name(concrete.CurrentRecipeId);h.text(nodes.Queue,recipe~='None'and('Queue: '..recipe..'  '..concrete.RemainProductNum..' / '..concrete.RequestedProductNum)or'Queue: empty')
        local module=concrete:GetWorkeeModule();local work=valid(module)and module.TargetWork
        local rate=valid(work)and work:IsA(UE.Object('/Script/Pal.PalWorkProgress'))and work:GetProgressRate()or 0
        nodes.Progress:SetPercent(math.max(0,math.min(1,rate)));h.text(nodes.ProgressText,string.format('Native work %.0f%%',rate*100));if ctx.config.task20_ui then nodes.Queue:SetVisibility(1);nodes.ProgressText:SetVisibility(1);if valid(self.arrow)then self.arrow:SetColorAndOpacity(rate>0 and{R=1,G=1,B=1,A=1}or{R=.25,G=.25,B=.25,A=1})end end
    end
    function F:craft(env)
        if not self.selected then return end
        if self.selected.product:sub(1,3)=='MC_'then log('MC21_NATIVE_CRAFT_REJECT MC_output='..self.selected.product);return end
        setting:SelectRecipe(self.selected.id);setting:SetProductNumByInput(self.quantity)
        local before={};for i=1,5 do local id=name(self.selected.row['Material'..i..'_Id']);if id~='None'then before[id]=ctx.items.native:count(env,id)end end
        
        local allowed=model:CanStartProduction();if allowed~=0 then log('MC_G_PRODUCTION_REJECT native_reason='..allowed);return end
        local id=self.selected.key;model:StartProduction()
        local changes={};for item,n in pairs(before)do changes[#changes+1]=item..':'..n..'->'..ctx.items.native:count(env,item)end
        log('MC_G_PRODUCTION_REQUEST recipe='..id..' quantity='..self.quantity..' materials='..table.concat(changes,','));ctx.items.dirty=true
        for _,r in ipairs(rows)do setting:SelectRecipe(r.id);r.max=setting:CalcMaxProductableNum()end;self:refreshProduction(env)
    end
    function F:selectRecipe(id)
        assert(kind=='Production','Open the native workbench first')
        for _,r in ipairs(rows)do if r.key==id then self.selected=r;self.quantity=1;self:refreshProduction(ctx.active());log('MC_G_RECIPE_SELECTED '..id);return end end
        log('MC_G_RECIPE_UNAVAILABLE '..id)
    end
    function F:setMax(env)assert(kind=='Production');self.quantity=math.max(1,setting:CalcMaxProductableNum());self:refreshProduction(env);log('MC_H_QTY_MAX_READY quantity='..self.quantity)end
    function F:palRows(env)
        local language=UE.language57 and UE.language57.generation
        if self.catalog55 and self.catalog55.epoch==ctx.epoch()and self.catalog55.language~=language then
            local db=getUtility():GetDatabaseCharacterParameter(env.player)
            for _,r in ipairs(self.catalog55.rows)do local out={};_G.MC_OUT_K('GetLocalizedCharacterName',db,r.name,out);r.label=out.OutText and txt(out.OutText)or r.id end
            self.catalog55.language=language
        end
        if self.catalog55 and self.catalog55.epoch==ctx.epoch()then rows=self.catalog55.rows;return end
        rows={};local db=getUtility():GetDatabaseCharacterParameter(env.player)
        for _,r in ipairs(array(owner.displayInfoArray))do
            local id=name(r.baseCharacterName);local out={};_G.MC_OUT_K('GetLocalizedCharacterName',db,r.baseCharacterName,out)
            local label=out.OutText and txt(out.OutText)or id
            rows[#rows+1]={id=id,name=r.baseCharacterName,index=r.Index,suffix=name(r.IndexSuffix),number=name(r.CombinedIndexString),detail=r.detailType,label=label,icon=palIcon(env,id)}
        end
        table.sort(rows,function(a,b)return a.index==b.index and a.suffix<b.suffix or a.index<b.index end)
        self.catalog55={epoch=ctx.epoch(),language=language,owner=owner:GetAddress(),rows=rows}
        log('MC_G_PALPEDIA_DATA rows='..#rows..' unlocked='..env.controller:GetPalPlayerState():GetRecordData():GetUnlockedPaldexCount())
    end
    function F:refreshPalpedia(env)
        self.filtered={};local q=(self.search or''):lower()
        for _,r in ipairs(rows)do if (self.dexFilter54~='Seen'or r.detail>=2)and(self.dexFilter54~='Caught'or r.detail>=3)and(q==''or r.number:lower():find(q,1,true)or(r.detail>=2 and(r.label:lower():find(q,1,true)or r.id:lower():find(q,1,true))))then self.filtered[#self.filtered+1]=r end end
        self.page=math.min(self.page,math.max(0,math.ceil(#self.filtered/(ctx.config.task20_ui and(kind=='Production'and 20 or 14)or 30))-1))
        for i=1,30 do local r=i<=(ctx.config.task20_ui and(kind=='Production'and 20 or 14)or 30)and self.filtered[self.page*(ctx.config.task20_ui and(kind=='Production'and 20 or 14)or 30)+i];h.icon(nodes['DexIcon'..i],r and r.icon);h.text(nodes['DexLabel'..i],r and(r.number..' '..(r.detail>=2 and r.label or'???'))or'')
            nodes['DexIcon'..i]:SetColorAndOpacity(r and r.detail>=2 and{R=1,G=1,B=1,A=1}or{R=0,G=0,B=0,A=1});local sphere=r and r.detail==3 and ctx.items:icon('PalSphere');texture(nodes['Caught'..i],sphere)
            h.text(nodes['CaughtText'..i],r and r.detail==3 and not valid(sphere)and'O'or'')
        end
        h.text(nodes.Page,(self.page+1)..'/'..math.max(1,math.ceil(#self.filtered/(ctx.config.task20_ui and(kind=='Production'and 20 or 14)or 30))))
        if ctx.config.task20_ui then ctx.uiKit:dex54Filter(nodes,env,self);ctx.uiKit:dexRows58(nodes,env,self)end
    end
    function F:palDetail(env,r)
        self.dropIds46,self.workRows46,self.workRects46={},{},{};self.description54=nil;self.selected=r;h.text(nodes.Selected,r.number..' '..(r.detail>=2 and r.label or'???'));h.icon(nodes.Portrait,r.icon);nodes.Portrait:SetColorAndOpacity(r.detail>=2 and{R=1,G=1,B=1,A=1}or{R=0,G=0,B=0,A=1})
        for _,n in ipairs({'Types','Work','Drops','Description','Bonus'})do h.text(nodes[n],'')end
        if r.detail<2 then h.text(nodes.Description,'Not encountered');if ctx.config.task20_ui then ctx.uiKit:dexDetails(nodes,env,self,r,{},0,0);ctx.uiKit:dexWork46(nodes,env,self,r,{})end;return end
        local db=getUtility():GetDatabaseCharacterParameter(env.player);local a,b={},{};db:GetElementType(r.name,a,b);local types={}
        for _,v in ipairs({a.Element1,b.Element2})do if v and v>0 then types[#types+1]=h.nativeText(env,'GetPalElementTypeName',v)end end;h.text(nodes.Types,table.concat(types,' / '))
        local ranks={};db:GetWorkSuitabilityRank(r.name,ranks);local works={};self.workRows46={};local values=ranks.WorkSuitabilities or{}
        local function add(k,v)k,v=unwrap(k),unwrap(v);if v>0 then local label=h.nativeText(env,'GetWorkSuitabilityName',k);works[#works+1]=label..' '..v;self.workRows46[#self.workRows46+1]={id=k,rank=v,name=label}end end
        if type(values)=='table'then for k,v in pairs(values)do add(k,v)end else values:ForEach(add)end;h.text(nodes.Work,'Work: '..table.concat(works,', '))
        local description=h.nativeText(env,'GetPalLongDescription',r.name);self.description54=ctx.uiKit:cleanDescription(description,env);if ctx.config.task20_ui then description=ctx.uiKit:wrap(description,124,5)end;h.text(nodes.Description,description)
        local out={};local drops,dropIds={},{};if _G.MC_OUT_K('GetDropItemData',db,r.name,1,out)then local d=out.OutData or out;for i=1,10 do local id=name(d['ItemId'..i]);if id~='None'then drops[#drops+1]=ctx.items:label(id);dropIds[#dropIds+1]=id end end end;h.text(nodes.Drops,'Drops: '..table.concat(drops,', '))
        
        local caughtCount,bonusCount=r.capture55 or 0,r.bonus55 or 0;local native=valid(owner)and owner.WBP_Paldex or nil;if valid(native)then native:ClickByCharacterID(r.name)
            local info=native.WBP_Paldex_PalInfo_00;if valid(info)then
                local count=info.Text_CaptureNumValue;local task=info.WBP_Paldex_Task
                local bonus=valid(task)and task.Text_CaptureNumOutGame
                h.text(nodes.Bonus,(valid(count)and('Captured: '..txt(count:GetText()))or'')..(valid(bonus)and('\nCapture bonus: '..txt(bonus:GetText()))or''))
                caughtCount=valid(count)and tonumber(txt(count:GetText()):match('%d+'))or 0;bonusCount=valid(bonus)and tonumber(txt(bonus:GetText()):match('%d+'))or 0
            end
        end
        if ctx.config.task20_ui then self.dropIds46=dropIds;self.works46=works;ctx.uiKit:dexDetails(nodes,env,self,r,dropIds,caughtCount,bonusCount);ctx.uiKit:dexWork46(nodes,env,self,r,works)end
        r.capture55,r.bonus55=caughtCount,bonusCount
        log('MC_G_PALPEDIA_DETAIL id='..r.id..' state='..r.detail..' works='..#works..' drops='..#drops)
    end
    function F:prepare67(env,root)
        owner=root;self:palRows(env)
        local record=env.controller:GetPalPlayerState():GetRecordData();local counts,bonuses,flags={},{},{}
        for key,target in pairs({PalCaptureCount=counts,PalCaptureBonusCount=bonuses,PaldeckUnlockFlag=flags})do
            for _,entry in ipairs(array(record[key].Items))do target[name(entry.Key):lower()]=entry.Value end
        end
        for _,r in ipairs(rows)do local id=r.id:lower();r.capture55=counts[id]or 0;r.bonus55=bonuses[id]or 0;r.detail=math.max(r.detail,r.capture55>0 and 3 or flags[id]and 2 or 0)end
    end
    function F:show(env,mode,view,root)
        if mode=='Palpedia'and view.dex55 and view.dex55.epoch==ctx.epoch()and self.catalog55 and self.catalog55.epoch==ctx.epoch()then
            nodes,kind,owner,rows=view,mode,root,self.catalog55.rows
            local c=view.dex55;self.filtered,self.selected,self.search,self.page,self.dexFilter54=c.filtered,c.selected,c.search,c.page,c.filter
            self.description54,self.dropIds46,self.works46,self.workRows46,self.workRects46=c.description,c.drops,c.works,c.workRows,c.workRects
            self.lastMouseX,self.lastMouseY=nil,nil
            log('MC55_DEX_CACHED_VISIBLE rows='..#rows);return
        end
        nodes,kind,owner=view,mode,root;self.refreshTimes={};self.lastMouseX,self.lastMouseY,self.lastCarry=nil,nil,nil;self.page,self.quantity,self.search,self.selected,self.craftable=0,1,'',nil,false
        if mode=='Production'then model=root['Convert Item Model'];assert(valid(model));setting=model.ProductSettingModel;assert(valid(setting))
            if ctx.config.task20_ui then ctx.items.creative=false;ctx.items.page=0;ctx.items.carry=nil;self.stationName='Workbench'end
            local out={};assert(_G.MC_OUT_K('TryGetConcreteModel',model,out));concrete=out.Model;assert(valid(concrete));self:recipeRows();self.selected=rows[1];self:refreshProduction(env)
        else self:palRows(env);self:refreshPalpedia(env);if rows[1]then self:palDetail(env,rows[1])end
            self:cacheDex55()
        end
    end
    function F:cacheDex55()
        nodes.dex55={epoch=ctx.epoch(),filtered=self.filtered,selected=self.selected,search=self.search,page=self.page,filter=self.dexFilter54,description=self.description54,drops=self.dropIds46,works=self.works46,workRows=self.workRows46,workRects=self.workRects46}
    end
    function F:recordRefresh55(env)
        local record=env.controller:GetPalPlayerState():GetRecordData();local counts,bonuses,flags={},{},{}
        for key,target in pairs({PalCaptureCount=counts,PalCaptureBonusCount=bonuses,PaldeckUnlockFlag=flags})do
            for _,entry in ipairs(array(record[key].Items))do target[name(entry.Key):lower()]=entry.Value end
        end
        local changed=false
        for _,r in ipairs(rows or{})do local id=r.id:lower();local captured,bonus=counts[id]or 0,bonuses[id]or 0
            local detail=math.max(r.detail,captured>0 and 3 or flags[id]and 2 or 0)
            if r.capture55~=captured or r.bonus55~=bonus or r.detail~=detail then r.capture55,r.bonus55,r.detail=captured,bonus,detail;changed=true end
        end
        if changed then self:refreshPalpedia(env);if self.selected then self:palDetail(env,self.selected)end;self:cacheDex55();log('MC55_DEX_RECORD_REFRESH native=true')end
    end
    function F:tick(env,tick)
        if kind=='Production'then
            if ctx.items.dirty then for _,r in ipairs(rows)do setting:SelectRecipe(r.id);r.max=setting:CalcMaxProductableNum()end;self:refreshProduction(env)end
            if tick%5==0 then self:updateQueue(env)end
            if ctx.config.task20_ui then
                if not valid(nodes.Ui20Search)or not nodes.Ui20Search:IsA(UE.Object('/Script/UMG.EditableText'))then return end
                local q=txt(nodes.Ui20Search:GetText());if q~=self.search then self.search=q;self.page=0;self:refreshProduction(env);log('MC_20_PRODUCTION_SEARCH rows='..#self.filtered..' query='..q)end
            end
            if ctx.config.task20_ui then local x,y=ctx.items:mouse(env);if self.lastMouseX==x and self.lastMouseY==y and self.lastCarry==ctx.items.carry and not ctx.items.dirty then return end;self.lastMouseX,self.lastMouseY,self.lastCarry=x,y,ctx.items.carry;local xx,yy=x/3+159.5,y/3+83;local hover
                for _,p in ipairs(self.inventorySlots or{})do if xx>=p.x and xx<p.x+p.w and yy>=p.y and yy<p.y+p.h then hover=p;break end end
                if not hover then for _,p in ipairs(self.materialSlots or{})do if xx>=p.x and xx<p.x+p.w and yy>=p.y and yy<p.y+p.h then hover=p;break end end end
                local _,unit=ctx.uiKit:metrics(env);nodes.GuiHover:SetVisibility(hover and 3 or 1)
                if hover then ctx.uiKit:fill(nodes.GuiHover,'FFFFFF',.15);ctx.uiKit:position(nodes.GuiHover,hover.x-159.5,hover.y-83,18,18,unit);nodes.GuiHover.Slot:SetZOrder(45)end
                ctx.uiKit:tooltip(nodes,hover and hover.entry,hover and hover.entry.id and ctx.items:label(hover.entry.id)or'',x/3,y/3,unit)
                local hand=ctx.items.carry;nodes.GuiExtra3:SetVisibility(hand and 3 or 1);nodes.GuiTabLabel3:SetVisibility(hand and 3 or 1)
                if hand then ctx.uiKit:icon(nodes.GuiExtra3,ctx.items:icon(hand.id));ctx.uiKit:position(nodes.GuiExtra3,x/3-8,y/3-8,16,16,unit);nodes.GuiExtra3.Slot:SetZOrder(60);ctx.uiKit:position(nodes.GuiTabLabel3,x/3-8,y/3,20,10,unit);ctx.uiKit:textStyle(nodes.GuiTabLabel3,unit,false);nodes.GuiTabLabel3.Slot:SetZOrder(61);h.text(nodes.GuiTabLabel3,hand.count);nodes.GuiTabLabel3:SetJustification(2)end
            end
        elseif kind=='Palpedia'then if tick%10==0 then self:recordRefresh55(env)end;self:hoverDex46(env);local q=txt(nodes.Search:GetText());if valid(nodes.Dex54Hint)then nodes.Dex54Hint:SetVisibility(q==''and not nodes.Search:HasKeyboardFocus()and 3 or 1)end;if q~=self.search then self.search=q;self.page=0;self:refreshPalpedia(env);log('MC_G_PALPEDIA_SEARCH query='..q..' rows='..#self.filtered)end end
    end
    function F:hoverDex46(env)
        local x,y=ctx.items:mouse(env);x,y=x/3,y/3;local tip
        local xx,yy=x+128,y+100
        if xx>=6 and xx<118 and yy>=20 and yy<188 then local r=self.filtered[self.page*14+math.floor((yy-20)/12)+1]
            if r then tip={title=r.detail>=2 and r.label or'???',source='Palworld',lines={'#'..r.number,r.detail>=3 and'Caught'or r.detail>=2 and'Encountered'or'Not encountered'},exclude={x=6-128,y=20-100+math.floor((yy-20)/12)*12,w=112,h=12}}end
        end
        local _,unit=ctx.uiKit:metrics(env)
        local highlight=ctx.uiKit:makeNode(nodes,'Dex54RowHover','Image');local listHover=xx>=6 and xx<118 and yy>=20 and yy<188
        highlight:SetVisibility(listHover and 3 or 1);if listHover then ctx.uiKit:fill(highlight,'FFFFFF',.15);ctx.uiKit:position(highlight,-122,-80+math.floor((yy-20)/12)*12,112,12,unit);highlight.Slot:SetZOrder(44)end
        local active=ctx.uiKit:makeNode(nodes,'Dex54Selected','Image');local selectedIndex
        for i=1,14 do if self.selected and self.filtered[self.page*14+i]==self.selected then selectedIndex=i;break end end
        active:SetVisibility(selectedIndex and 3 or 1);if selectedIndex then ctx.uiKit:fill(active,'55FF55');ctx.uiKit:position(active,-122,-80+(selectedIndex-1)*12,1,12,unit);active.Slot:SetZOrder(45)end
        if xx>=80 and xx<124 and yy>=5 and yy<17 then tip={title='Catalog filter',source='Palworld',lines={'Show: '..(self.dexFilter54 or'All'),'Click to cycle All / Seen / Caught'},exclude={x=-48,y=-95,w=44,h=12}}end
        if valid(nodes.Dex54Filter)then ctx.uiKit:brush(nodes.Dex54Filter,xx>=80 and xx<124 and yy>=5 and yy<17 and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button')end
        for _,r in ipairs(self.workRects46 or{})do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then tip={title=r.label,source='Palworld',lines={'Suitability Lv '..r.rank},exclude=r};break end end
        if xx>=124 and xx<214 and yy>=163 and yy<181 then local id=(self.dropIds46 or{})[math.floor((xx-124)/18)+1];if id then ctx.uiKit:tooltip(nodes,{id=id,exclude={x=124-128+math.floor((xx-124)/18)*18,y=163-100,w=18,h=18}},ctx.items:label(id),x,y,unit);return end end
        ctx.uiKit:richTooltip(nodes,tip,x,y,unit)
    end
    function F:click(env,x,y,shift,right)
        if kind=='Palpedia'and ctx.config.task20_ui and x/3>=0 and x/3<120 and y/3>=-95 and y/3<-83 then
            ctx.uiKit:focusField(env,nodes.Search);self.searchUI54=true;self.searchFocused=true;log('MC54_DEX_SEARCH_FOCUS real_click=true ui_only=true');return
        end
        if kind=='Palpedia'and self.searchUI54 then
            local own=nodes.CanvasPanel_0:GetOuter():GetOuter();assert(valid(own)and own:IsA(UE.Object('/Script/UMG.UserWidget')))
            ctx.uiKit:clearField();self.searchUI54=nil;self.searchFocused=false
        end
        if kind=='Palpedia'and ctx.config.task20_ui and x/3>=-48 and x/3<-4 and y/3>=-95 and y/3<-83 then
            self.dexFilter54=({All='Seen',Seen='Caught',Caught='All'})[self.dexFilter54 or'All'];self.page=0;self:refreshPalpedia(env);ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);log('MC54_DEX_FILTER '..self.dexFilter54..' rows='..#self.filtered);return
        end
        if ctx.config.task20_ui and kind=='Production'then
            local xx,yy=x/3+159.5,y/3+83
            for _,p in ipairs(self.inventorySlots or{})do if xx>=p.x and xx<p.x+p.w and yy>=p.y and yy<p.y+p.h then ctx.items:validateCarry(env);ctx.items:interactEntry(env,p.spec,p.entry,right==true,shift==true);self:refreshProduction(env);log('MC_20_PRODUCTION_SLOT native=true');return end end
            if self.searchRect and xx>=25 and xx<105 and yy>=14 and yy<26 then self.searchFocused=true;ctx.uiKit:focusField(env,nodes.Ui20Search);return end
            self.searchFocused=false
            if right then return end
            if xx>=110 and xx<136 and yy>=12 and yy<28 then self.craftable=not self.craftable;self.page=0;self:refreshProduction(env);log('MC_20_PRODUCTION_FILTER craftable='..tostring(self.craftable));return end

            if xx>=199 and xx<249 and yy>=62 and yy<82 then self:craft(env);return end
        end
        if ctx.config.task20_ui then x,y=ctx.uiKit:mapInput(kind=='Production'and'WBP_MCProduction'or'WBP_MCPalpedia',x,y)end
        if y>=275 and y<320 then if x>=-540 and x<-480 then self.page=math.max(0,self.page-1)elseif x>=-80 and x<-20 then self.page=math.min(math.max(0,math.ceil(#self.filtered/(ctx.config.task20_ui and(kind=='Production'and 20 or 14)or 30))-1),self.page+1)else return end
            ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);if kind=='Production'then self:refreshProduction(env)else self:refreshPalpedia(env)end;return end
        for i=1,30 do local xx=-540+(i-1)%6*85;local yy=-205+math.floor((i-1)/6)*92
            if x>=xx and x<xx+78 and y>=yy and y<yy+84 then local r=self.filtered[self.page*(ctx.config.task20_ui and(kind=='Production'and 20 or 14)or 30)+i];if not r then return end;self.selected=r
                if kind=='Production'then self.quantity=1;self:refreshProduction(env)else ctx.phaseC:play('ui.button.click',env.player:K2_GetActorLocation(),.2);self:palDetail(env,r)end;return end
        end
        if kind~='Production'then return end
        if x>=-540 and x<-100 and y>=-280 and y<-240 then self.craftable=not self.craftable;self.page=0;self:refreshProduction(env);return end
        if x>=20 and x<550 and y>=210 and y<265 then self:craft(env);return end
        if y>=140 and y<185 then
            if x>=20 and x<70 then self.quantity=math.max(1,self.quantity-1)elseif x>=480 and x<535 then self.quantity=self.quantity+1
            else local i=math.floor((x-95)/92)+1;if i>=1 and i<=4 then self.quantity=({1,5,10,math.max(1,setting:CalcMaxProductableNum())})[i]end end
            self:refreshProduction(env)
        end
    end
    function F:cancel()
        if kind=='Palpedia'and nodes then self:cacheDex55()end
        self.renderSerial=(self.renderSerial or 0)+1;if self.renderHandle then Timers.cancel(self.renderHandle)end;self.renderHandle=nil;self.render=nil;ctx.uiKit.productionOps=nil;ctx.uiKit.productionAssets=nil;ctx.uiKit.productionTextStyles=nil;if kind=='Production'and ctx.config.task20_ui then ctx.items.carry=nil end;nodes,kind,owner,model,setting,concrete,rows=nil,nil,nil,nil,nil,nil,nil;self.selected=nil;self.filtered=nil;self.inventorySlots=nil;self.searchFocused=false;self.searchUI54=nil
    end
    function F:startCapture(env)
        self:captureTeardown();local ui=ctx.createUI(env,'WBP_MCCapture','capture');self.captureUI=ui.widget;self.captureNodes=ctx.uiWidgets(ui.widget);ui.widget:SetVisibility(1)
        self.captureElements={};local class=StaticFindObject('/Game/Pal/Blueprint/UI/CommonWidget/PalStatusParts/WBP_PalElementIcon.WBP_PalElementIcon_C')
        if valid(class)and not ctx.config.task20_ui then for i=1,2 do local w=UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(env.player,class,env.controller);local slot=self.captureNodes.CanvasPanel_0:AddChildToCanvas(w)
            slot:SetAnchors({Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}});slot:SetPosition({X=372+(i-1)*32,Y=-111});slot:SetSize({X=25,Y=25});self.captureElements[i]=w
        end end
    end
    function F:updateCapture(env,visible)
        if not valid(self.captureUI)then return end
        if not valid(self.nativeCapture)then for _,w in ipairs(FindAllOf('WBP_CaptureReticle_C')or{})do if valid(w)and w:GetOwningPlayer():GetAddress()==env.controller:GetAddress()then self.nativeCapture=w;break end end end
        local w=self.nativeCapture;local native=valid(w)and w.WBP_PalGetReticle;local target
        if valid(w)then local ok,t=pcall(function()return w.NowTargetMonster:Get()end);if ok and valid(t)then target=t end;if not valid(target)then local good,t=pcall(function()return UE.GetKismetSystemLibrary():Conv_SoftObjectReferenceToObject(w.NowTargetMonster)end);if good and valid(t)then target=t end end end
        if not visible or not ctx.gameplayInput(env)or not valid(native)or native:GetVisibility()==1 or native:GetVisibility()==2 or not valid(target)then self.captureUI:SetVisibility(1);self:restoreCapture();return end

        local rate=native.targetCaptureRate
        local n=type(rate)=='number'and math.max(0,math.min(100,math.floor(rate*100+.5)))or nil
        if not n then self.captureUI:SetVisibility(1);self:restoreCapture();return end
        local d=target.CharacterParameterComponent:GetIndividualParameter();local id=name(d:GetCharacterID());local node=self.captureNodes
        local label={};getUtility():GetDatabaseCharacterParameter(env.player):GetLocalizedCharacterName(UE.FindOrAddFName(id),label)
        h.text(node.Name,(label.OutText and txt(label.OutText)or id)..'   Lv '..d:GetLevel()..'   '..({[0]='?','Male','Female'})[d:GetGenderType()]);h.icon(node.Portrait,palIcon(env,id))
        local a,b={},{};getUtility():GetDatabaseCharacterParameter(env.player):GetElementType(UE.FindOrAddFName(id),a,b);local types={};for _,v in ipairs({a.Element1,b.Element2})do if v and v>0 then types[#types+1]=h.nativeText(env,'GetPalElementTypeName',v)end end;h.text(node.Types,table.concat(types,' / '))
        for i,v in ipairs({a.Element1 or 0,b.Element2 or 0})do local w=self.captureElements[i];if valid(w)then w:SetElement(v);w:SetVisibility(v>0 and 3 or 1)end end
        local hp,max=d:GetHP().Value/1000,d:GetMaxHP();node.HP:SetPercent(hp/math.max(1,max));h.text(node.HPText,string.format('HP %.0f / %d',hp,max));h.text(node.Rate,'Capture '..n..'%');self.captureUI:SetVisibility(3)
        if ctx.config.task20_ui then local _,unit,dpi,size=ctx.uiKit:metrics(env);local height=size.Y/(unit*dpi);ctx.uiKit:position(node.GuiExtra1,-91,12-height/2,182*math.max(0,math.min(1,hp/math.max(1,max))),5,unit);local colors={[1]={1,1,1},[2]={1,.333,.333},[3]={.333,.333,1},[4]={.333,1,.333},[5]={1,1,.333},[6]={1,1,1},[7]={1,1,1},[8]={.667,0,.667},[9]={1,.333,1}};local c=colors[a.Element1 or 1]or colors[1];node.GuiExtra1:SetColorAndOpacity({R=c[1],G=c[2],B=c[3],A=1});h.text(node.Rate,n..'%');for _,k in ipairs({'Portrait','Types','HP','HPText'})do node[k]:SetVisibility(1)end end
        if self.captureHidden and self.captureHidden.node:GetAddress()~=native:GetAddress()then self:restoreCapture()end
        if not self.captureHidden then self.captureHidden={node=native,opacity=native:GetRenderOpacity()}end;native:SetRenderOpacity(0)
        self.captureSamples=(self.captureSamples or 0)+1
        if self.captureSamples<=3 or self.captureLogged~=id..':'..n then self.captureLogged=id..':'..n;log('MC_G_CAPTURE_PARITY native='..n..' displayed='..n..' id='..id..' sample='..self.captureSamples..' source=native_display_rate targetRate='..native.targetCaptureRate)end
    end
    function F:restoreCapture()local v=self.captureHidden;if v and valid(v.node)then v.node:SetRenderOpacity(v.opacity)end;self.captureHidden=nil end
    function F:captureTeardown()self:restoreCapture();if valid(self.captureUI)then self.captureUI:RemoveFromParent()end;self.captureUI,self.captureNodes,self.nativeCapture,self.captureLogged,self.captureSamples=nil,nil,nil,nil,nil;self.captureElements=nil end
    dofile(ctx.base..'/timers.lua').onEpoch('phase-f',function()
        F:cancel();F.captureHidden=nil;F.captureUI=nil;F.captureNodes=nil;F.nativeCapture=nil;F.captureElements=nil
        F.catalog55=nil
        F.view=nil;F.materialSlots=nil;F.env=nil;F.inventorySlots=nil
        utility=nil
    end)
    return F
end
