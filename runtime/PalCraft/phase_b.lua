-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
    local Timers=dofile(ctx.base..'/timers.lua')
    local UE,valid,log=ctx.UE,ctx.valid,ctx.log
    local nativeG=dofile(ctx.base..'/native_widgetG.lua')(UE,valid)
    local R=dofile(ctx.base..'/item_registry.lua')
    local layouts=dofile(ctx.base..'/inventory_layout.lua')
    for k,v in pairs(dofile(ctx.base..'/native_chest_layout.lua'))do layouts[k]=v end
    local recipes=dofile(ctx.base..'/recipes.lua')
    local bookRecipes,bookHidden=dofile(ctx.base..'/recipe_book.lua')(recipes)
    for _,r in ipairs(bookHidden)do log('MC24_BOOK_HIDE_LEGACY id='..r.id..' result='..r.result)end
    local match=dofile(ctx.base..'/crafting.lua')(recipes)
    local N=dofile(ctx.base..'/native_inventory.lua')(ctx)
    local B={open=false,page=0,size=2,dirty=true,bindings={'native_1','native_2','native_3','native_4','MC_Dirt','MC_GrassBlock','MC_Stone','MC_Cobblestone','MC_OakLog'},hooks={}}
    local widget,nodes,model,nativeRoot,handle,stamp;local uiSerial=0
    local function C()return ctx.phaseC()end
    local uiLayouts=ctx.uiKit and dofile(ctx.base..'/container_layouts.lua')
    if uiLayouts then uiLayouts.Creative=dofile(ctx.base..'/creative_layout.lua').container end
    function B:creativeAllowed()return ctx.config.creative~=false and UE.creativeMode and UE.creativeMode:enabled()or false end
    function B:toggleCatalog(env)
        if not self.open or self.mode or not self:creativeAllowed()then return false end
        self.creative=not self.creative;self.recipeBook=false;self.page=0;self.catalogRow=0;self.catalogWheel=0;self.catalogDrag=nil;self.search='';self.category='search';self.filtered=self:catalog('')
        if self.carry and self.carry.kind=='creative'then self.carry=nil end
        nodes.CreativeSearch:SetText(UE.GetKismetTextLibrary():Conv_StringToText(''))
        self.dirty=true;self:refresh(env);log('MCCM_CATALOG enabled='..tostring(self.creative));return true
    end
    function B:pickBlock(env)
        if not self:creativeAllowed()or self.open or not ctx.gameplayInput(env)then return false end
        local hit=ctx.trace(env,true);local chunk=hit and ctx.hitChunk(hit);local c=chunk and ctx.cells()[chunk.keys[hit.Item]]
        if not c then return false end
        local p=env.player:K2_GetActorLocation();local h=hit.ImpactPoint
        if(p.X-h.X)^2+(p.Y-h.Y)^2+(p.Z-h.Z)^2>600^2 then return false end
        local id=ctx.registry[c.type].item
        if N:count(env,id)<1 and not C():grantInto(env,id,1)then return false end
        self:assign(ctx.phaseA.selected,id);ctx.phaseA:select(ctx.phaseA.selected)
        log('MCCM_PICK_BLOCK id='..id);return true
    end
    function B:catalogChrome()
        if not self.creative then return end

        nodes.navRects={};nodes.buttons67={};nodes.field67=nil
        for name,n in pairs(nodes)do
            if type(name)=='string'and(name:match('^Nav46_')or name:match('^Nav46Icon_')or name:match('^Nav67Label')or name:match('^S67_'))and valid(n)then n:SetRenderOpacity(0)end
        end
        if valid(nodes.CreativeSearch)then nodes.CreativeSearch:SetVisibility((self.category or'search')=='search'and 0 or 1)end
    end
    function B:layout()return uiLayouts and uiLayouts[self.creative and'Creative'or self.mode or tostring(self.size)]or layouts[self.mode or tostring(self.size)]end
    function B:pageSize()return uiLayouts and self.creative and 45 or 27 end
    function B:catalog(query)
        local list=C():catalog(query);if not self.category or self.category=='search'then return list end
        local filtered={};for _,e in ipairs(list)do if e.group==self.category then filtered[#filtered+1]=e end end;return filtered
    end
    local assets,dataCache,iconCache={},{},{}
    local nativeNames={}
    local texts,images={},{}
    N.changed=function()B.dirty=true;B.visualDirty=true;ctx.phaseA.inventoryDirty=true end
    function B:installStartupHooks()
        if self.startupHooks then return end;self.startupHooks=true

    if valid(StaticFindObject('/Script/Pal.PalItemContainer:OnUpdateSlotContent'))then
        Timers.hook('/Script/Pal.PalItemContainer:OnUpdateSlotContent',function()end,function()
            B.dirty=true;B.visualDirty=true;ctx.phaseA.inventoryDirty=true
        end)
    end
    end
    local equipmentViewQ3=dofile(ctx.base..'/equipment_viewQ3.lua')
    local indexed=false
    local bindingFile
    function B:setWorld(world)
        ctx.world=world;bindingFile=ctx.base..'/hotbar-'..world..'.txt'
        self:cancel();self.page=0;self.size=2;self.output=nil;self.query=nil;self.category=nil
        self.bindings={'native_1','native_2','native_3','native_4','MC_Dirt','MC_GrassBlock','MC_Stone','MC_Cobblestone','MC_OakLog'}
        local f=io.open(bindingFile,'rb')
        if f then local saved={};for id in f:lines()do if id:match('^[%w_]+$')then saved[#saved+1]=id end end;f:close()
            local offset=#saved<=5 and 4 or 0;for i,id in ipairs(saved)do if i+offset<=9 then self.bindings[i+offset]=id end end
        end
    end
    local function text(node,value)
        if not valid(node)then return end
        local key=node:GetAddress();value=tostring(value)
        if texts[key]~=value then node:SetText(UE.GetKismetTextLibrary():Conv_StringToText(value));texts[key]=value end
    end
    local function asset(path)
        if valid(assets[path])and assets[path]:IsA(UE.Object('/Script/Engine.Texture'))and UE.AssetMatchesRA(assets[path],path) then return assets[path]end
        if valid(assets[path])then log('MC_STALE_CACHE phase-b MC_20_ITEM_ASSET_CACHE_REPAIRED '..path..' previous='..assets[path]:GetFullName())end
        local o=StaticFindObject(path)
        if not valid(o)then local package,name=path:match('^(.*)%.([^%.]+)$')
            o=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(package),AssetName=UE.FindOrAddFName(name)})
        end
        assert(valid(o)and o:IsA(UE.Object('/Script/Engine.Texture'))and UE.AssetMatchesRA(o,path),'Inventory texture missing '..path);assets[path]=o;return o
    end
    function B:data(id)
        if not id then return nil end
        if valid(dataCache[id])then
            if dataCache[id]:IsA(UE.Object('/Script/Pal.PalStaticItemDataBase'))and dataCache[id].ID:ToString()==id then return dataCache[id]end
            log('MC_STALE_CACHE item-data '..id);dataCache[id]=nil;indexed=false
        end
        if not indexed then
            for _,d in ipairs(FindAllOf('PalStaticItemDataBase')or{})do
                if valid(d)then dataCache[d.ID:ToString()]=d end
            end
            indexed=true
        end
        return dataCache[id]
    end
    function B:icon(id)
        if not id then return nil end
        local def=R.items[id]
        if def then return asset(def.icon)end
        for _,block in ipairs(ctx.registry)do if block.item==id then return asset('/Game/MinecraftBlocks/T_MC_'..id:sub(4)..'.T_MC_'..id:sub(4))end end
        if iconCache[id]~=nil then return iconCache[id]and asset(iconCache[id])or nil end
        local d=self:data(id)
        if valid(d)then
            local path=UE.GetKismetSystemLibrary():Conv_SoftObjectReferenceToString(d.IconTexture)
            path=type(path)=='string'and path or path:ToString()
            if path and path~=''and path~='None'then iconCache[id]=path;return asset(path)end
        end
        iconCache[id]=false
    end
    local function image(node,id)
        local key=node:GetAddress();local token=id or false
        if images[key]==token then return end
        local t=B:icon(id)
        node:SetVisibility(valid(t)and 3 or 1)
        if valid(t)then if ctx.config.task20_ui then ctx.uiKit:icon(node,t)else node:SetBrushFromTexture(t,false)end end
        images[key]=token
    end
    function B:label(id)
        if not id then return ''end
        if UE.language57 then local localized=UE.language57:item(id);if localized then return localized end;if self.nameLanguage57~=UE.language57.generation then nativeNames={};self.nameLanguage57=UE.language57.generation end end
        if R.items[id]then return R.items[id].label end
        for _,block in ipairs(ctx.registry)do if block.item==id then return block.label end end
        if nativeNames[id]then return nativeNames[id]end
        local name=id;local out={}
        _G.MC_OUT_K('GetItemName',UE.Object('/Script/Pal.Default__PalUIUtility'),(self.prebuildEnv or ctx.active()).player,UE.FindOrAddFName(id),out)
        local value=out.outName and UE.GetKismetTextLibrary():Conv_TextToString(out.outName)
        if type(value)~='string'then local ok,s=pcall(function()return value:ToString()end);value=ok and s or nil end
        if type(value)=='string'and value~=''then name=value end
        nativeNames[id]=name;log('MC_NATIVE_ITEM_NAME id='..id..' label='..name);return name
    end
    function B:prepareView(env)
        if not self.dirty and self.view then return self.view end
        local view={slots={},totals={},first={},sizes={}}
        for _,kind in ipairs({0,3,4,5})do
            local container=N:container(env,kind);view.slots[kind]={};view.sizes[kind]=container:Num()
            for i=0,view.sizes[kind]-1 do
                local slot=container:Get(i);local id=N:id(slot);local count=id and slot:GetStackCount()or 0
                local e={id=id,count=count,slot=slot,kind=kind,index=i};view.slots[kind][i]=e
                if id then view.totals[id]=(view.totals[id]or 0)+count;view.first[id]=view.first[id]or e end
            end
        end
        if valid(N.containers.external)then local c=N.containers.external;view.slots.external={};view.sizes.external=c:Num()
            for i=0,c:Num()-1 do local s=c:Get(i);local id=N:id(s);view.slots.external[i]={id=id,count=id and s:GetStackCount()or 0,slot=s,kind='external',index=i}end
        end
        equipmentViewQ3(view,self.bindings)
        self.view=view;self.dirty=false;return view
    end
    function B:hotbar(env,i)
        local view=self:prepareView(env);return view.barQ3[i]or{count=0}
    end
    function B:saveBindings()
        local file=assert(io.open(bindingFile,'wb'));for _,id in ipairs(self.bindings)do file:write(id,'\n')end;file:close()
    end
    function B:assign(i,id)
        assert(i>=1 and i<=9 and id,'Hotbar assignment invalid')
        self.bindings[i]=id;self.dirty=true;self:saveBindings();ctx.phaseA:updateHotbar(ctx.active())
        log('MC_ANY_HOTBAR_ASSIGN slot='..i..' id='..id)
    end
    function B:select(env,i)
        local entry=self:hotbar(env,i);local d=entry.id and self:data(entry.id)
        if valid(d)and d.TypeA==1 and valid(entry.slot)then
            local weapons=N:container(env,3)
            
            for j=0,weapons:Num()-1 do local s=weapons:Get(j);if N:id(s)==entry.id then entry.slot,entry.kind,entry.index=s,3,j;break end end
            if entry.kind~=3 then
                
                local weapons=N:container(env,3);local dest=weapons:Get(3)
                if not dest:IsEmpty()then
                    local common=N:container(env,0);local empty
                    for j=0,common:Num()-1 do local s=common:Get(j);if s:IsEmpty()then empty=s;break end end
                    if not empty then log('MC_WEAPON_SELECT_REJECT inventory_full id='..entry.id);return false,nil end
                    N:move(env,dest,empty,1)
                end
                assert(N:move(env,entry.slot,dest,1),'Native weapon move rejected')
                entry.slot,entry.kind,entry.index=dest,3,3
                assert(N:id(dest)==entry.id,'Native weapon equip rejected')
            end
            env.player.LoadoutSelectorComponent:SetWeaponLoadoutIndex(entry.index)
            env.player.LoadoutSelectorComponent:TryEquipNowSelectedWeapon()
            log('MC_ANY_WEAPON_EQUIPPED slot='..i..' id='..entry.id..' native_index='..entry.index)
            return false,nil
        end
        env.player.LoadoutSelectorComponent:SetWeaponLoadoutIndex(4)
        env.player.LoadoutSelectorComponent:TryEquipNowSelectedWeapon()
        for i,block in ipairs(ctx.registry)do if block.item==entry.id then return true,i end end
        return false,nil
    end
    function B:keepAlias(id)
        local selected=ctx.phaseA.selected
        local env=ctx.environment();return env and self:hotbar(env,selected).id==id
    end
    function B:cycle(env,slot)
        local id=self.bindings[slot]
        for i,d in ipairs(ctx.registry)do if d.item==id then self:assign(slot,ctx.registry[i%#ctx.registry+1].item);ctx.phaseA:select(slot);return end end
    end
    function B:rightClick(env)
        if self.open then self:click(true);return true end
        if UE.elytra104 and ctx.gameplayInput(env)and UE.elytra104:rocket(env)then ctx.phaseA:updateHotbar(env);return true end
        if self.beds and ctx.gameplayInput(env)then local hit=ctx.trace(env,true);local ch=hit and ctx.hitChunk(hit);if ch and self.beds:interact(env,ch.keys[hit.Item])then return true end end
        if self.mechanics and ctx.gameplayInput(env)then
            local entry=self:hotbar(env,ctx.phaseA.selected)
            if self.mechanics:interact(env,entry,ctx.trace(env,true))then ctx.phaseA:updateHotbar(env);return true end
        end
        if ctx.gameplayInput(env)then local hit=ctx.trace(env,true);local ch=hit and ctx.hitChunk(hit)
            if ch and C().connected:interact(env,ch.keys[hit.Item])then return true end end
        local entry=self:hotbar(env,ctx.phaseA.selected)
        if entry and valid(entry.slot)then
            local d=self:data(entry.id)
            if valid(d)and(d.TypeA==8 or d.TypeA==6)then N:use(env,entry.slot);ctx.phaseA:updateHotbar(env);return true end
        end
        if not valid(env.player.ShooterComponent:GetHasWeapon())then
            local hit=ctx.trace(env,true);local chunk=hit and ctx.hitChunk(hit)
            local cell=chunk and ctx.cells()[chunk.keys[hit.Item]]
            if cell and(ctx.registry[cell.type].name=='crafting_table'or ctx.registry[cell.type].kind=='chest'or ctx.registry[cell.type].kind=='furnace')then
                local p=env.player:K2_GetActorLocation();local h=hit.ImpactPoint
                if(p.X-h.X)^2+(p.Y-h.Y)^2+(p.Z-h.Z)^2<=600^2 then
                    local kind=ctx.registry[cell.type].kind
                    if kind=='chest'or kind=='furnace'then self.entityKey=chunk.keys[hit.Item];C():entity(self.entityKey);C():advance(self.entityKey,C():now(env));self:requestOpen(kind=='chest'and'Chest'or'Furnace');C():play('block.chest.open',env.player:K2_GetActorLocation(),.5)
                    else self:requestOpen(3)end
                    return true end
            end
        end
        return false
    end
    local function sameSlot(a,b)
        return a.SlotIndex==b.SlotIndex and a.ContainerId.ID.A==b.ContainerId.ID.A and a.ContainerId.ID.B==b.ContainerId.ID.B
            and a.ContainerId.ID.C==b.ContainerId.ID.C and a.ContainerId.ID.D==b.ContainerId.ID.D
    end
    function B:entry(env,spec)
        if spec.kind=='external'then local v=self:prepareView(env);local e=v.slots.external[self.storagePage*self.storageSize+spec.index-1];if not e then return{}end
            local n=e.count;if self.carry and self.carry.kind=='external'and self.carry.index==e.index then n=math.max(0,n-self.carry.count)end
            return{id=n>0 and e.id or nil,count=n,slot=e.slot,kind=e.kind,index=e.index}
        end
        if spec.kind=='entity'then return C():entityEntry(self.entityKey,spec.index,self.carry)end
        if spec.kind=='main'and self.creative then local e=self.filtered[(self.catalogRow or 0)*9+spec.index];return e and{id=e.id,count=C():stack(e.id),kind='catalog',index=spec.index}or{}end
        if spec.kind=='result'then return self.output and{id=self.output.result,count=self.output.count}or{}end
        if spec.kind=='bar'then return self:hotbar(env,spec.index)end
        local view=self:prepareView(env);local kind,index
        if spec.kind=='main'then local e=view.mainQ3[self.page*27+spec.index];if not e then return{}end;kind,index=e.kind,e.index
        elseif spec.kind=='bar'then kind=3;index=spec.index-1
        elseif spec.kind=='craft'then kind=0;index=view.sizes[0]-9+spec.index-1
        elseif spec.kind=='armor'then kind=4;index=({0,1,1,2})[spec.index]
        end
        local raw=view.slots[kind][index];local slot,id,count=raw.slot,raw.id,raw.count
        if spec.kind=='armor'and(spec.index==2 or spec.index==3)and id then
            local def=R.items[id];local leg=def and def.armor_part=='leggings'
            if(spec.index==2 and leg)or(spec.index==3 and not leg)then id=nil;count=0 end
        end
        local hand=self.carry
        if hand and hand.kind==kind and hand.index==index then count=math.max(0,count-hand.count)end
        return {id=count>0 and id or nil,count=count,slot=slot,kind=kind,index=index}
    end
    function B:grid(env)
        local result={};for i=1,self.size*self.size do result[i]=self:entry(env,{kind='craft',index=i})end;return result
    end
    function B:auditInventory(stage)
        local env=ctx.active();local counts,grid={},{};local common=N:container(env,0)
        for _,kind in ipairs({0,3,4,5})do local c=N:container(env,kind);for i=0,c:Num()-1 do local slot=c:Get(i);local id=N:id(slot);if id then counts[id]=(counts[id]or 0)+slot:GetStackCount()end end end
        for i=common:Num()-9,common:Num()-1 do local slot=common:Get(i);grid[#grid+1]={index=i,id=N:id(slot)or false,count=slot:GetStackCount()}end
        self.audits=self.audits or{};self.audits[#self.audits+1]={stage=stage,counts=counts,grid=grid};local f=assert(io.open(ctx.base..'/task21-conservation.json','wb'));f:write(dofile(ctx.base..'/json.lua').encode(self.audits));f:close()
        log('MC21_INVENTORY_AUDIT stage='..stage..' grid_is_real_native_slots=true');return counts
    end
    function B:returnGrid(env)
        local common=N:container(env,0)
        for i=common:Num()-9,common:Num()-1 do local source=common:Get(i);local id=N:id(source)
            if id then local data=self:data(id);local maximum=valid(data)and data.MaxStackCount or 64
                for j=0,common:Num()-10 do local target=common:Get(j);if N:id(target)==id then local amount=math.min(source:GetStackCount(),math.max(0,maximum-target:GetStackCount()));if amount>0 and not N:move(env,source,target,amount)then break end;if source:IsEmpty()then break end end end
                if not source:IsEmpty()then for j=0,common:Num()-10 do local target=common:Get(j);if target:IsEmpty()then N:move(env,source,target,source:GetStackCount());break end end end
                if not source:IsEmpty()then log('MC21_GRID_RETURN_SKIPPED inventory_full id='..id..' count='..source:GetStackCount()..' native_stack_retained=true')end
            end
        end
    end
    function B:bookRows()
        local list={};local q=(self.bookSearch or''):lower()
        for _,r in ipairs(bookRecipes)do
            local fits=r.kind=='crafting_shaped'and r.width<=self.size and r.height<=self.size
                or r.kind=='crafting_shapeless'and #r.ingredients<=self.size*self.size
            if fits and r.result:sub(1,3)=='MC_'and(q==''or self:label(r.result):lower():find(q,1,true)or r.result:lower():find(q,1,true))then list[#list+1]=r end
        end
        table.sort(list,function(a,b)return a.result==b.result and a.id<b.id or a.result<b.result end)
        return list
    end
    function B:fillRecipe(env,recipe)
        if self.carry then log('MC21_BOOK_FILL_SKIPPED carried_stack');return end
        local grid=self:grid(env);for _,e in ipairs(grid)do if e.id then log('MC21_BOOK_FILL_SKIPPED occupied_grid');return end end
        local common=N:container(env,0);local requirements={}
        if recipe.kind=='crafting_shaped'then
            for y=0,recipe.height-1 do for x=0,recipe.width-1 do local options=recipe.cells[y*recipe.width+x+1];if options then requirements[#requirements+1]={index=y*self.size+x+1,options=options}end end end
        else for i,options in ipairs(recipe.ingredients)do requirements[#requirements+1]={index=i,options=options}end end
        local used,plan={},{}
        for _,r in ipairs(requirements)do local source
            for _,id in ipairs(r.options)do for i=0,common:Num()-10 do local s=common:Get(i)
                if N:id(s)==id and s:GetStackCount()>(used[i]or 0)then source={slot=s,index=i};break end
            end;if source then break end end
            if not source then log('MC21_BOOK_FILL_SKIPPED missing_ingredient recipe='..recipe.id);return end
            used[source.index]=(used[source.index]or 0)+1;plan[#plan+1]={from=source.slot,to=common:Get(common:Num()-9+r.index-1)}
        end
        local before=self:auditInventory('before_autofill');self.bookSelection=recipe
        for _,p in ipairs(plan)do if not N:move(env,p.from,p.to,1)then self.dirty=true;self:refresh(env);log('MC21_BOOK_FILL_SKIPPED native_move_rejected');return end end
        local after=self:auditInventory('after_autofill');for id,count in pairs(before)do assert(after[id]==count,'Autofill lost '..id)end
        self.dirty=true;self:refresh(env);log('MC21_BOOK_FILLED recipe='..recipe.id..' result='..recipe.result)
    end
    function B:refresh(env)
        if not self.open then return end
        if self.creative and not self:creativeAllowed()then self.creative=false;if self.carry and self.carry.kind=='creative'then self.carry=nil end end
        local guiScale,_,dpi,viewport=ctx.uiKit:metrics(env)
        local layoutSignature=tostring(self.mode)..':'..self.size..':'..tostring(self.creative)..':'..tostring(self.storageSize)..':'..tostring(ctx.config.gui_scale)..':'..viewport.X..':'..viewport.Y..':'..dpi
        if ctx.uiKit and nodes.layoutSignature61~=layoutSignature then ctx.uiKit:container(nodes,self,env);nodes.layoutSignature61=layoutSignature end
        
        self.uiUnit=nodes.containerUnit61 or self.uiUnit
        self.layoutSignature=layoutSignature
        self.drawerShift67=0
        if not self.mode and self.size==2 and not self.creative then local fitted;fitted,self.drawerShift67=ctx.uiKit.inventoryFit67(viewport.X,viewport.Y,guiScale,ctx.UE.drawer67Open);nodes.inventoryUnit67=self.uiUnit end
        ctx.UE.drawer67Shift=self.drawerShift67
        widget:SetRenderTranslation({X=((self.recipeBook and 74 or 0)+self.drawerShift67)*(self.uiUnit or 1),Y=0})
        local dim=nodes.Dim or nodes.Background
        if valid(dim)then dim:SetRenderTranslation({X=-((self.recipeBook and 74 or 0)+self.drawerShift67)*(self.uiUnit or 1),Y=0})end
        local started=os.clock();self:prepareView(env)
        local grid=self.mode and{}or self:grid(env);local signature={tostring(self.size),self.bookSelection and self.bookSelection.id or''}
        for _,e in ipairs(grid)do signature[#signature+1]=(e.id or '')..':'..(e.count or 0)end
        signature=table.concat(signature,'|')
        if signature~=self.gridSignature then
            if self.mode then self.output,self.used,self.maximum=nil,nil,0 else self.output,self.used,self.maximum=match(grid,self.size,self.bookSelection)end
            self.gridSignature=signature end
        for _,spec in ipairs(self:layout().slots)do
            local entry=self:entry(env,spec);image(nodes[spec.name..'Icon'],entry.id)
            text(nodes[spec.name..'Count'],entry.count and entry.count>1 and entry.count or'')
            if ctx.uiKit then ctx.uiKit:durability(nodes,spec,entry,self)end
        end
        text(nodes.Page,(self.page+1)..'/'..math.max(1,math.ceil((self.creative and #self.filtered or #self:prepareView(env).mainQ3)/self:pageSize())))
        if valid(nodes.StoragePage)then text(nodes.StoragePage,'Storage '..(self.storagePage+1)..'/'..math.max(1,math.ceil(N.containers.external:Num()/self.storageSize)))end
        if valid(nodes.Defense)then text(nodes.Defense,'Defense '..env.player.CharacterParameterComponent:GetDefense())end
        if valid(nodes.CreativeLabel)then text(nodes.CreativeLabel,self.creative and'Inventory'or'Creative');nodes.CreativeSearch:SetVisibility(self.creative and 0 or 1)end
        if valid(nodes.Title)and not self.mode then nodes.Title:SetVisibility(self.creative and 1 or 3)end
        if self.mode=='Furnace'then local e=C():entity(self.entityKey)
            nodes.BurnStatus:SetVisibility(1)
            local flame=math.max(.001,math.min(1,e.burn/math.max(1,e.fuelTime)));local arrow=math.max(.001,math.min(1,e.cook/10))
            local u=self.uiUnit or 3;nodes.FlameClip.Slot:SetSize({X=14*u,Y=14*u*flame});if self.uiUnit then nodes.FlameClip.Slot:SetPosition({X=(56-88)*u,Y=(50-83-14*flame)*u})end;nodes.FlameFill:SetRenderTransformPivot({X=0,Y=1});nodes.FlameFill:SetRenderScale({X=1,Y=1/flame})
            nodes.CookArrowClip.Slot:SetSize({X=24*u*arrow,Y=16*u});nodes.CookArrowFill:SetRenderTransformPivot({X=0,Y=0});nodes.CookArrowFill:SetRenderScale({X=1/arrow,Y=1})end
        local hand=self.carry;image(nodes.LiftIcon,hand and hand.id);text(nodes.LiftCount,hand and hand.count or'')
        if valid(nativeRoot)and nativeRoot:IsActivated()and nativeRoot:GetRenderOpacity()~=0 then nativeRoot:SetRenderOpacity(0)end
        if ctx.uiKit and ctx.uiKit.recipeBook and not self.mode and not self.creative then ctx.uiKit:recipeBook(nodes,env,self)end
        self:catalogChrome()
        if ctx.uiKit.catalogPaint then ctx.uiKit:catalogPaint(nodes,self,env)end
        if UE.creativeUI then if not self.mode then UE.creativeUI:paint(nodes,env,'inventory',self.uiUnit,self:layout(),self)else UE.creativeUI:hide(nodes)end end
        log(string.format('MC_INV_REFRESH_MS %.3f',(os.clock()-started)*1000))
    end
    function B:mouse(env)
        local library=UE.Object('/Script/UMG.Default__WidgetLayoutLibrary')
        env=env or ctx.active();local point=library:GetMousePositionOnViewport(env.player)
        local size=library:GetViewportSize(env.player);local scale=library:GetViewportScale(env.player)
        
        local x,y=point.X-size.X/(2*scale),point.Y-size.Y/(2*scale)
        local factor=self.open and self.uiUnit or(ctx.phaseD().open and ctx.phaseD().uiFactor)or 1;return x/factor-(self.open and self.recipeBook and 74 or 0)-(self.open and(self.drawerShift67 or 0)or 0),y/factor-(not self.open and(ctx.phaseD().uiOffset46 or 0)*3 or 0)
    end
    function B:hover(env,force)
        local x,y=self:mouse(env)
        if UE.creativeUI then
            UE.creativeUI:hover(nodes,x,y)
            if UE.creativeUI.pending then ctx.uiKit:hideTooltip(nodes);self.hovered=nil;return end
        end
        if not force and self.mouseX==x and self.mouseY==y then return end
        self.mouseX,self.mouseY=x,y;self.hovered=nil
        for _,spec in ipairs(self:layout().slots)do
            local size=self.uiUnit and 16 or 48;if x>=spec.x and x<spec.x+size and y>=spec.y and y<spec.y+size then self.hovered=spec;break end
        end
        if ctx.uiKit.catalogHover and ctx.uiKit:catalogHover(nodes,self,x,y)then self.hovered=nil;return end
        local entry=self.hovered and self:entry(env,self.hovered)
        if entry and self.hovered then entry.exclude={x=self.hovered.x,y=self.hovered.y,w=16,h=16}end
        if self.recipeBook then for _,p in ipairs(self.bookSlots or{})do if x>=p.x and x<p.x+24 and y>=p.y and y<p.y+24 then entry={id=p.recipe.result,count=p.recipe.count};break end end end
        if ctx.uiKit then ctx.uiKit:tooltip(nodes,entry,entry and entry.id and self:label(entry.id)or'',x,y,self.uiUnit)end
        nodes.TooltipBox:SetVisibility(1)
        if ctx.uiKit and ctx.uiKit.navHover then ctx.uiKit:navHover(nodes,env,x,y)end
        local u=self.uiUnit or 1
        if not ctx.uiKit and entry and entry.id then text(nodes.Tooltip,self:label(entry.id));nodes.TooltipBox.Slot:SetPosition({X=(x+14)*u,Y=(y-48)*u})end
        nodes.LiftIcon.Slot:SetPosition({X=(x-(self.uiUnit and 8 or 24))*u,Y=(y-(self.uiUnit and 8 or 24))*u});nodes.LiftCount.Slot:SetPosition({X=(x-(self.uiUnit and 8 or 24))*u,Y=(y+2)*u})
        if ctx.uiKit and valid(nodes.GuiHover)then nodes.GuiHover:SetVisibility(self.hovered and 3 or 1);if self.hovered then ctx.uiKit:position(nodes.GuiHover,self.hovered.x,self.hovered.y,16,16,u);nodes.GuiHover:SetColorAndOpacity({R=1,G=1,B=1,A=.5})end end
    end
    function B:quickMove(env,spec,entry)
        if valid(N.containers.external)then
            local target=entry.kind=='external'and N:container(env,0)or N.containers.external
            local remaining=entry.count;local data=self:data(entry.id);local limit=valid(data)and data.MaxStackCount or 64
            for pass=1,2 do for i=0,target:Num()-1 do local s=target:Get(i);local id=N:id(s)
                if not sameSlot(N:slotId(entry.slot),N:slotId(s))and((pass==1 and id==entry.id)or(pass==2 and not id))then
                    local n=math.min(remaining,math.max(0,limit-(id and s:GetStackCount()or 0)))
                    if n>0 and N:move(env,entry.slot,s,n)then remaining=remaining-n;if remaining==0 then return end end
                end
            end end;log('MC_G_CHEST_QUICK_REMAIN count='..remaining);return
        end
        if entry.kind=='catalog'then if self:creativeAllowed()then C():grantInto(env,entry.id,C():stack(entry.id));self.dirty=true end;return end
        if entry.kind=='entity'then
            if C():grantInto(env,entry.id,entry.count)then local e=C():entity(entry.key);e.slots[entry.index]=false;C():persist();self.dirty=true end;return end
        if spec.kind=='main'and entry.id then
            for i=1,9 do if self:hotbar(env,i).id==entry.id then return end end
            self:assign(ctx.phaseA.selected,entry.id);return
        end
        local common=N:container(env,0)
        local first,last=0,common:Num()-10
        for i=first,last do local target=common:Get(i)
            if target:IsEmpty()and not sameSlot(N:slotId(entry.slot),N:slotId(target))then
                N:move(env,entry.slot,target,entry.slot:GetStackCount())
                return
            end
        end
        log('MC_QUICK_MOVE_REJECT no_empty_target')
    end
    function B:validateCarry(env)
        local hand=self.carry;if not hand then return end
        if hand.kind=='creative'then if not self:creativeAllowed()then self.carry=nil end;return end
        if hand.kind=='entity'then local e=C():entity(hand.key);local slot=e and e.slots[hand.index]
            if not slot or slot.id~=hand.id then self.carry=nil else hand.count=math.min(hand.count,slot.count)end;return end
        local c=N:container(env,hand.kind);local s=c:Get(hand.index)
        if N:id(s)~=hand.id then self.carry=nil;return end
        hand.count=math.min(hand.count,s:GetStackCount());hand.slot=s
        if hand.count<=0 then self.carry=nil end
    end
    function B:placeCarry(env,entry,right)
        self:validateCarry(env);local hand=self.carry;if not hand then return end
        if hand.kind=='creative'or hand.kind=='entity'or entry.kind=='entity'then
            local result=C():transfer(env,hand,entry,right);if result=='cancel'then self.carry=nil end;self.dirty=true;return end
        if hand.kind==entry.kind and hand.index==entry.index then self.carry=nil;return end
        local targetId=N:id(entry.slot);local targetCount=targetId and entry.slot:GetStackCount()or 0
        local function accepts(kind,index,id)
            if kind==4 then return N:inventory(env):CanEquip(index,UE.FindOrAddFName(id))end
            local data=self:data(id)
            if kind==3 then return valid(data)and data.TypeA==1 and index<N:inventory(env):GetUnlockedWeaponSlotNum()end
            if kind==5 then return valid(data)and(data.TypeA==8 or data.TypeA==6)end
            return kind==0 or kind=='external'
        end
        if not accepts(entry.kind,entry.index,hand.id)then log('MC_CARRY_REJECT incompatible_destination');return end
        if targetId and targetId~=hand.id then
            if right or hand.count~=hand.slot:GetStackCount()then log('MC_CARRY_REJECT partial_stack_swap');return end
            if not accepts(hand.kind,hand.index,targetId)then log('MC_CARRY_REJECT incompatible_reverse_slot');return end
            local common=N:container(env,0);local temp
            for i=0,common:Num()-10 do local s=common:Get(i)
                if s:IsEmpty()and not sameSlot(N:slotId(s),N:slotId(entry.slot))then temp=s;break end
            end
            if not temp then log('MC_CARRY_REJECT swap_needs_empty_slot');return end
            if not N:move(env,entry.slot,temp,targetCount)then return end
            if not N:move(env,hand.slot,entry.slot,hand.count)then N:move(env,temp,entry.slot,targetCount);return end
            if not N:move(env,temp,hand.slot,targetCount)then
                self.carry=nil;log('MC_NATIVE_SWAP_REJECT reverse_item_preserved_in_main');return
            end
            self.carry={id=targetId,count=targetCount,slot=hand.slot,kind=hand.kind,index=hand.index}
            log('MC_NATIVE_SWAP via_empty_temp=true');return
        end
        local d=self:data(hand.id);local limit=valid(d)and d.MaxStackCount or 64
        local num=math.min(right and 1 or hand.count,math.max(0,limit-targetCount))
        if num>0 and N:move(env,hand.slot,entry.slot,num)then hand.count=hand.count-num;if hand.count==0 then self.carry=nil end end
    end
    function B:click(right,shiftOverride)
        if self.admitting58 then return end
        if not self.open then return end
        local shift=shiftOverride==true
        local env=ctx.active();local x,y=self:mouse(env)
        if UE.creativeUI and UE.creativeUI:click(nodes,env,'inventory',x,y,right,self)then self:refresh(env);return end
        self:validateCarry(env);self:hover(env,true)
        if ctx.config.task20_ui then ctx.uiKit:hideTooltip(nodes)end
        if ctx.uiKit and not self.mode and self.size==2 then local nav=ctx.uiKit:navAt(nodes,x,y);if nav then if nav.kind~='Inventory'then local at=os.clock();self:close();ctx.phaseD():navigate46(nav.kind);log(string.format('MC51_TAB_VISIBLE kind=%s latency_ms=%.3f frame=%d',nav.kind,(os.clock()-at)*1000,Timers.frameCounter))end;return end end
        if ctx.uiKit and not self.mode and not self.creative and self.size==2 and ctx.uiKit.character67 and ctx.uiKit.character67:click(env,x,y,self)then return end
        if not ctx.config.task20_ui or not self.hovered then C():play('ui.button.click',env.player:K2_GetActorLocation(),.2)end
        local layout=self:layout()
        if self.recipeBook and not self.mode then
            if x>=-236 and x<-110 and y>=-69 and y<-57 then ctx.uiKit:focusField(env,nodes.CreativeSearch);return end
            if y>=66 and y<80 and x>=-236 and x<-110 then self.bookPage=math.max(0,math.min(math.ceil(#self:bookRows()/10)-1,(self.bookPage or 0)+(x<-170 and-1 or 1)));self:refresh(env);return end
            for _,p in ipairs(self.bookSlots or{})do if x>=p.x and x<p.x+24 and y>=p.y and y<p.y+24 then self:fillRecipe(env,p.recipe);return end end
        end
        if self.creative and ctx.uiKit.catalogClick and ctx.uiKit:catalogClick(nodes,self,env,x,y,right,shift)then return end
        if self.creative and ctx.uiKit and(self.category or'search')=='search'and x>=82-layout.width/2 and x<162-layout.width/2 and y>=6-layout.height/2 and y<18-layout.height/2 then ctx.uiKit:focusField(env,nodes.CreativeSearch);return end
        if ctx.uiKit:editing()then ctx.uiKit:clearField()end
        if self.creative and self.tabBoxes then for _,b in ipairs(self.tabBoxes)do if x>=b[1]and x<b[1]+b[3]and y>=b[2]and y<b[2]+b[4]then
            if b[5]=='inventory'then self.creative=false else self.category=b[5];self.page=0;self.filtered=self:catalog(self.search)end;self:refresh(env);log('MC_J_CREATIVE_TAB '..b[5]);return end end end
        for key,delta in pairs({storagePrev=-1,storageNext=1})do local box=layout[key];if box and x>=box[1]and x<box[1]+box[3]and y>=box[2]and y<box[2]+box[4]then self.storagePage=math.max(0,math.min(math.ceil(N.containers.external:Num()/self.storageSize)-1,self.storagePage+delta));self:refresh(env);return end end
        local cb=layout.creative
        if cb and not self.mode and x>=cb[1]and x<cb[1]+cb[3]and y>=cb[2]and y<cb[2]+cb[4]then
            if not self.mode and not shift then self.creative=false;self.recipeBook=not self.recipeBook;self.bookSearch='';self.bookPage=0;nodes.CreativeSearch:SetText(UE.GetKismetTextLibrary():Conv_StringToText(''));self:refresh(env);log('MC21_RECIPE_BOOK size='..self.size..' recipes='..#self:bookRows());return end
            self:toggleCatalog(env);return end
        for key,delta in pairs({prev=-1,next=1})do local box=layout[key]
            if x>=box[1]and x<box[1]+box[3]and y>=box[2]and y<box[2]+box[4]then
                self.page=math.max(0,math.min(math.ceil((self.creative and #self.filtered or #self:prepareView(env).mainQ3)/self:pageSize())-1,self.page+delta));self:refresh(env);return
            end
        end
        local spec=self.hovered;if not spec then return end
        self:interactEntry(env,spec,self:entry(env,spec),right,shift)
    end
    
    function B:deleteCatalogCarry(env)
        if not self.creative or not self:creativeAllowed()then return false end
        self:validateCarry(env);local hand=self.carry;if not hand then return false end
        if hand.kind~='creative'then
            if type(hand.kind)~='number'or not valid(hand.slot)then return false end
            N:dispose(env,hand.slot,hand.count)
        end
        log('MCVB_CREATIVE_DELETE id='..hand.id..' count='..hand.count..' source='..tostring(hand.kind))
        self.carry=nil;self.dirty=true;ctx.phaseA.inventoryDirty=true;return true
    end
    
    function B:interactEntry(env,spec,entry,right,shift)
        if(entry.kind=='catalog'or(self.carry and self.carry.kind=='creative'))and not self:creativeAllowed()then self.carry=nil;log('MCCM_CATALOG_REJECT survival');return end
        if spec.kind=='result'then self:craft(shift);return end
        local hand=self.carry
        if spec.kind=='bar'and hand then
            if hand.kind=='external'then self:quickMove(env,{kind='external'},hand);self.dirty=true;self:validateCarry(env);if N:count(env,hand.id)==0 then return end end
            if hand.kind=='creative'then if not C():grantInto(env,hand.id,hand.count)then return end
            elseif hand.kind=='entity'then if not C():grantInto(env,hand.id,hand.count)then return end;local e=C():entity(hand.key);e.slots[hand.index].count=e.slots[hand.index].count-hand.count;if e.slots[hand.index].count==0 then e.slots[hand.index]=false end;C():persist()end
            self:assign(spec.index,hand.id);self.carry=nil;if self.open then self:refresh(env)end;return end
        if entry.kind=='catalog'then
            if shift then C():grantInto(env,entry.id,entry.count)
            else self.carry={id=entry.id,count=entry.count,kind='creative'}end
            log('MC_CATALOG_CARRY id='..entry.id..' count='..entry.count);if self.open then self:refresh(env)end;return end
        if not valid(entry.slot)and entry.kind~='entity'then return end
        if shift and entry.id and not hand then self:quickMove(env,spec,entry)
        elseif hand then self:placeCarry(env,entry,right)
        elseif entry.id then self.carry={id=entry.id,count=right and math.ceil(entry.count/2)or entry.count,slot=entry.slot,kind=entry.kind,index=entry.index,key=entry.key}
        else
            return
        end
        log('MC_INVENTORY_CLICK '..spec.kind..' index='..spec.index..' right='..tostring(right)..' shift='..tostring(shift))
        if self.open then self:refresh(env)end;ctx.phaseA:updateHotbar(env)
    end
    function B:craft(maximum)
        local env=ctx.active();self:refresh(env)
        if not self.output then log('MC_CRAFT_REJECT no_matching_recipe');return end
        if self.output.result:sub(1,3)~='MC_'then log('MC21_MC_CRAFT_REJECT Pal_output='..self.output.result);return end
        self:validateCarry(env)
        if self.carry and self.carry.kind==0 and self.carry.index>=self.view.sizes[0]-9 then log('MC_CRAFT_REJECT carried_crafting_input');return end
        local recipe,used=self.output,self.used
        local copies=maximum and self.maximum or 1;local definition=self:data(recipe.result)
        local stack=valid(definition)and definition.MaxStackCount or 64
        copies=math.min(copies,math.max(1,math.floor(stack/recipe.count)))
        if recipe.result=='MC_Saddle'and N:count(env,recipe.result)>0 then log('MC_CRAFT_REJECT saddle_already_owned');return end
        local essential=recipe.result=='MC_Saddle'
        local common=N:container(env,essential and 2 or 0);local capacity=0
        for i=0,common:Num()-(essential and 1 or 10) do local slot=common:Get(i);local id=N:id(slot)
            if not id then capacity=capacity+stack elseif id==recipe.result then capacity=capacity+math.max(0,stack-slot:GetStackCount())end
        end
        if capacity<copies*recipe.count then log('MC_CRAFT_REJECT native_inventory_full');return end
        local grid=self:grid(env)

        for _,index in ipairs(used)do N:dispose(env,grid[index].slot,copies)end
        N:add(env,recipe.result,recipe.count*copies)
        log('MC_CRAFT_PASS recipe='..recipe.id..' copies='..copies..' result='..recipe.result..' count='..recipe.count*copies)
        self:refresh(env);ctx.phaseA:updateHotbar(env)
    end
    function B:attach(root)
        if self.open then return end
        local env=ctx.environment();if not env or not self.intent then return end
        if root then assert(valid(root)and root:GetOwningPlayer():GetAddress()==env.controller:GetAddress(),'Foreign native menu')end
        model=nil;self.carry=nil;self.dirty=true;self.view=nil;self.gridSignature=nil
        self.mode=type(self.intent)=='string'and self.intent or nil;self.size=self.mode and 2 or self.intent;self.intent=nil;self.page=self.page or 0;nativeRoot=root
        self.creative=false;self.recipeBook=false;self.bookSelection=nil;self.bookSearch='';self.bookPage=0;self.search='';self.category='search';self.filtered=C():catalog('');self.uiTicks=0;self.footerAt=nil
        local result=ctx.createUI(env,self.mode and('WBP_MC'..self.mode)or('WBP_MCInventory'..self.size),'inventory');assert(result)
        widget=result.widget;nodes=result.nodes or ctx.uiWidgets(widget);self.nodes46=nodes;stamp=ctx.epoch();self.open=true;self.openedAt=os.clock()
        ctx.phaseA:setLife('alive')
        if not result.reused then texts,images={},{};self.layoutSignature=nil end
        self.nativeOpacity=valid(root)and root:GetRenderOpacity()or 1;if valid(root)then root:SetRenderOpacity(0)end
        if ctx.phaseA.visible then ctx.phaseA:hideNative(env)end
        if valid(nodes.Defense)then nodes.Defense:SetVisibility((self.size==3 or(ctx.uiKit.character67 and not self.mode and self.size==2))and 1 or 3)end
        env.controller.bShowMouseCursor=true
        env.controller:SetIgnoreMoveInput(true);env.controller:SetIgnoreLookInput(true)
        ctx.uiKit:ownInput(env,widget,{nodes.CreativeSearch})
        if result.reused then
            self.admitting58=true;local openEpoch=stamp
            Timers.after(34,function()if self.open and stamp==openEpoch and ctx.epoch()==openEpoch then self:refresh(env);self.admitting58=nil end end,'station-first-data')
        else self:refresh(env)end
        ctx.phaseD():hideFooter(env,true)
        if self.size==2 and not self.mode then ctx.phaseD():previewStart(env,nodes.PlayerPreview)end
        uiSerial=uiSerial+1;local ownedSerial,ownedStamp=uiSerial,stamp;local loopHandle
        local function stopLoop()
            if handle==loopHandle then handle=nil end
        end
        loopHandle=Timers.loop(100,function()
            if ctx.config.task20b_disable_b_pollers or ownedSerial~=uiSerial or ownedStamp~=ctx.epoch()or ctx.quiesced()then stopLoop();return true end
            if ctx.busy()then return false end
            local current=ctx.environment();if not current or not self.open then stopLoop();return true end
            local ok,err=xpcall(function()

                if self.mode=='NativeChest'and(not valid(nativeRoot)or not nativeRoot:IsActivated())then self:close();return end
                self.uiTicks=self.uiTicks+1
                if valid(N.containers.external)and self.uiTicks%5==0 then self.dirty=true end
                if self.creative then
                    local raw=UE.GetKismetTextLibrary():Conv_TextToString(nodes.CreativeSearch:GetText());local query=type(raw)=='string'and raw or raw:ToString()
                    if query~=self.search then self.search=query;self.filtered=self:catalog(query);self.page=0;self.catalogRow=0;self.dirty=true;log('MC_CATALOG_SEARCH query='..query..' count='..#self.filtered)end
                end
                if self.recipeBook then
                    local raw=UE.GetKismetTextLibrary():Conv_TextToString(nodes.CreativeSearch:GetText());local query=type(raw)=='string'and raw or raw:ToString()
                    if query~=self.bookSearch then self.bookSearch=query;self.bookPage=0;self:refresh(current);log('MC21_BOOK_SEARCH size='..self.size..' query='..query..' rows='..#self:bookRows())end
                end
                if self.mode=='Furnace'and self.uiTicks%10==0 then C():advance(self.entityKey,C():now(current));C():persist();self.dirty=true end
                if self.dirty or self.visualDirty then self:validateCarry(current);self:refresh(current);self.visualDirty=false;self.mouseX=nil end
                self:hover(current)
                if self.profileBaseline or not self.footerAt or os.clock()>=self.footerAt then ctx.phaseD():hideFooter(current,true);self.footerAt=os.clock()+.5 end
                ctx.phaseD():previewTick(current)
            end,debug.traceback)
            if not ok then
                log('MC_ITEMS_ERROR '..err);stopLoop()
                local expected=stamp
                Timers.after(100,function()
                    if ownedSerial~=uiSerial or expected~=ctx.epoch()or ctx.quiesced()or not self.open then return end
                    local closed,reason=pcall(self.close,self)
                    if not closed then log('MC_ITEMS_ERROR close-recovery '..tostring(reason))end
                end)
                return true
            end
            return not self.open
        end)
        handle=loopHandle
        log('MC_INVENTORY_OPEN size='..self.size..' mode='..(self.mode or'Inventory')..' native_hidden='..tostring(valid(root)and root:GetVisibility()or'owned')..' carry_native_source_retained=true')
    end
    function B:prebuild(env,result,name)
        if self.open then return end
        self.prebuildEnv=env;widget=result.widget;nodes=result.nodes;self.size=name=='WBP_MCInventory3'and 3 or 2;self.mode=name=='WBP_MCChest'and'Chest'or name=='WBP_MCFurnace'and'Furnace'or nil;self.creative=false;self.recipeBook=false;self.storagePage=0;self.storageSize=27;self.filtered=C():catalog('');self.open=true
        if self.mode then ctx.uiKit:container(nodes,self,env);nodes.layoutSignature61=tostring(self.mode)..':'..self.size..':'..tostring(self.creative)..':'..tostring(self.storageSize)..':'..tostring(ctx.config.gui_scale)else self:refresh(env);if self.size==2 then ctx.phaseD():previewStart(env,nodes.PlayerPreview);ctx.phaseD():previewStop(true)end end;self.layoutSignature=nil;self.mode=nil;result.used=true;self.open=false;widget,nodes=nil,nil;self.prebuildEnv=nil
        log('MC51_INVENTORY_PRIMED diff_open=true')
    end
    function B:requestOpen(size)
        if self.open then self:close();return end
        self.intent=size or 2
        local env=ctx.active()
        if type(self.intent)=='number'or self.intent=='Chest'or self.intent=='Furnace'then self:attach(nil);return end
        for _,listener in ipairs(FindAllOf('WBP_PalHUD_InGame_InputListener_C')or{})do
            if valid(listener)and listener:GetOwningPlayer():GetAddress()==env.controller:GetAddress()then
                listener['On Trigger Open Inventory Menu'](listener);return
            end
        end
        error('Native inventory input listener unavailable')
    end
    function B:close()
        if not self.open then return end
        if UE.creativeUI then UE.creativeUI:cancel('inventory')end
        self.escapeUntil=os.clock()+.5
        local env=ctx.active();if self.mode=='Chest'or self.mode=='Furnace'then C():advance(self.entityKey,C():now(env));C():persist();C():play('block.chest.close',env.player:K2_GetActorLocation(),.5)end
        if not self.mode then local before=self:auditInventory('before_close');self:returnGrid(env);local after=self:auditInventory('after_close');for id,count in pairs(before)do assert(after[id]==count,'Close lost '..id)end end
        self.open=false;self.admitting58=nil;self.intent=nil;self.mode=nil;self.entityKey=nil;self.creative=false
        uiSerial=uiSerial+1;handle=nil 
        self.carry=nil
        ctx.phaseD():previewStop(true);ctx.phaseD():hideFooter(env,ctx.phaseA.visible)
        
        ctx.uiKit:releaseInput(widget)
        if valid(widget)then ctx.hideUI(widget)end
        self.closingUntil=os.clock()+.35
        if nativeG:activatable(nativeRoot)then nativeRoot:SetRenderOpacity(0);nativeG:closeOwned(nativeRoot,env.controller)end
        env.controller:ResetIgnoreMoveInput();env.controller:ResetIgnoreLookInput()
        env.controller.bShowMouseCursor=false

        local closedSerial,closedEpoch=uiSerial,ctx.epoch()
        Timers.after(350,function()
            if closedSerial~=uiSerial or closedEpoch~=ctx.epoch()or ctx.quiesced()or self.open or ctx.phaseD().open or ctx.uiKit.input57.owner then return end
            local current=ctx.environment();if not current then return end
            if ctx.phaseD().nativeBypass or(UE.nativeInputG4 and UE.nativeInputG4:blocksMenu())then return end
            nativeG:releaseMain(current.controller)
            current.controller:ResetIgnoreMoveInput();current.controller:ResetIgnoreLookInput();current.controller.bShowMouseCursor=false
            UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(current.controller,true)
            ctx.phaseD():hideFooter(current,ctx.phaseA.visible)
            log('MC36_INVENTORY_GAME_INPUT_READY')
        end,'inventory-close-input')
        widget,nodes,model,nativeRoot=nil,nil,nil,nil
        N.containers.external=nil;self.view=nil;self.dirty=true;self.storagePage=nil;self.storageSize=nil
        log('MC_INVENTORY_CLOSED native_items_retained=true')
    end
    function B:teardown(env)
        ctx.uiKit:releaseInput(widget)
        self.open=false;self.carry=nil
        uiSerial=uiSerial+1;handle=nil
        if valid(widget)then widget:RemoveFromParent()end
        if valid(nativeRoot)then nativeRoot:SetRenderOpacity(self.nativeOpacity)end
        self:cancel()
    end
    function B:attachStorage(root,container)
        assert(valid(container)and container:Num()>0,'Native storage is unavailable')
        N.containers.external=container;self.storagePage=0;self.storageSize=container:Num()>27 and 54 or 27
        self.intent='NativeChest'..self.storageSize;self:attach(root)
        log('MC_G_CHEST_OPEN slots='..container:Num()..' page_size='..self.storageSize..' id='..container:GetFullName())
    end
    function B:cancel()
        uiSerial=uiSerial+1;handle=nil
        self.openRequest=nil;self.nativeInventoryDirty=nil
        self.open=false;self.admitting58=nil;self.intent=nil;self.mode=nil;self.entityKey=nil;self.creative=false;widget,nodes,model,nativeRoot=nil,nil,nil,nil;self.nativeMenu61=nil
        assets,dataCache,iconCache={},{},{};indexed=false
        self.carry=nil;self.view=nil;self.dirty=true;N.containers={};texts,images={},{}
    end
    function B:retireViewport()if valid(widget)then widget:RemoveFromParent()end end
    function B:installInputHooks()
        if self.inputHook then return end
        local input='/Game/Pal/Blueprint/UI/WBP_PalHUD_InGame_InputListener.WBP_PalHUD_InGame_InputListener_C:On Trigger Open Inventory Menu'
        local function inventoryEvent()
            if ctx.quiesced()then return end
            if ctx.phaseD().open or(self.escapeUntil and os.clock()<self.escapeUntil)then return end
            self.nativeInputAt=os.clock()
            for _,r in ipairs(FindAllOf('WBP_InGameMainMenu_C')or{})do if valid(r)and r:IsActivated()then r:SetRenderOpacity(0)end end
            if self.closingUntil and os.clock()<self.closingUntil then return end
            if self.open or self.openRequest then return end 
            local expected=ctx.epoch();local request={};self.openRequest=request
            local tries=0
            Timers.loop(33,function()
                local function done()if self.openRequest==request then self.openRequest=nil end;return true end
                if expected~=ctx.epoch()or ctx.quiesced()or self.openRequest~=request or self.open then return done()end
                tries=tries+1;if tries>60 then log('MC36_INVENTORY_OPEN_EXPIRED');return done()end
                local env=ctx.environment();if not env then return false end
                self.intent=self.intent or 2
                for _,r in ipairs(FindAllOf('WBP_InGameMainMenu_C')or{})do
                    if valid(r)and r:GetOwningPlayer():GetAddress()==env.controller:GetAddress()then

                        if r:IsActivated()or(tries>=6 and type(self.intent)=='number')then self:attach(r);return done()end
                    end
                end
                if tries>=6 and(type(self.intent)=='number'or self.intent=='Chest'or self.intent=='Furnace')then self:attach(nil);return done()end
                return false
            end,'inventory-open-request')
        end
        assert(valid(StaticFindObject(input)),'Inventory concrete input event missing')
        self.nativeInventoryWork=inventoryEvent
        Timers.hook(input,function()if self.inputAlive then self.nativeInventoryDirty=true end end);self.inputHook=true
        local cls='/Game/Pal/Blueprint/UI/InGameMainMenu/WBP_InGameMainMenu.WBP_InGameMainMenu_C'
        local lib=UE.GetKismetSystemLibrary();UE.Native109(lib,'LoadClassAsset_Blocking',lib:Conv_SoftClassPathToSoftClassRef(lib:MakeSoftClassPath(cls)))
        local construct=cls..':Construct';if valid(StaticFindObject(construct))then Timers.hook(construct,function()self.nativeConstructDirty65=true end)end
        log('MC36_INVENTORY_INPUT_READY explicit_tab_esc=true')
    end
    function B:pollNativeInventory()
        if self.nativeConstructDirty65 then
            self.nativeConstructDirty65=nil
            for _,r in ipairs(FindAllOf('WBP_InGameMainMenu_C')or{})do if valid(r)then r:SetRenderOpacity(0);self.nativeMenu61=r end end
        end
        if self.nativeInventoryDirty then self.nativeInventoryDirty=nil;if self.nativeInventoryWork then self.nativeInventoryWork()end end
    end
    function B:start(env)
        self:installStartupHooks()
        self:cancel()
        self:installInputHooks()
        log('MC_ITEMS_READY definitions='..#R.order..' native_inventory_only=true')
    end
    function B:assignHovered(i)
        if not self.open or i<1 or i>9 then return end
        if UE.creativeUI and UE.creativeUI.pending then return end
        local env=ctx.active();self:hover(env,true);local hand=self.carry;local entry=self.hovered and self:entry(env,self.hovered)
        local id=hand and hand.id or entry and entry.id
        if id then
            if hand and hand.kind=='creative'or not hand and entry and entry.kind=='catalog'then if not C():grantInto(env,id,hand and hand.count or entry.count)then return end end
            self:assign(i,id);self.carry=nil;self:refresh(env)end
    end
    function B:drop()
        if UE.creativeUI and UE.creativeUI.pending then return end
        if self.open and self.carry then local env=ctx.active();self:validateCarry(env)
            local hand=self.carry;if hand and(type(hand.kind)~='number')then self.carry=nil;self:refresh(env);return end
            if hand and N:drop(env,hand.slot,hand.count)then self.carry=nil end
            self:refresh(env)
        end
    end
    function B:selfTest()
        local env=ctx.active();local checked=0
        if not self.matcherChecked then
            local test=dofile(ctx.base..'/crafting.lua')({
                {id='shape',kind='crafting_shaped',width=2,height=1,cells={{'A'},{'B'}},result='MC_C',count=1},
                {id='mix',kind='crafting_shapeless',ingredients={{'A','B'},{'A'}},result='MC_D',count=1}})
            local r,u,m=test({{},{},{},{},{id='B',count=2},{id='A',count=3},{},{},{}},3)
            assert(r and r.id=='shape'and m==2 and #u==2,'Craft mirror/offset failed')
            assert(not test({{id='A',count=1},{id='B',count=1},{id='X',count=1},{}},2),'Craft extras accepted')
            r,u,m=test({{id='A',count=4},{},{},{id='B',count=2}},2)
            assert(r and r.id=='mix'and m==2,'Shapeless tag matching failed')
            self.matcherChecked=true;log('SELF_TEST PASS CRAFT_MATCHER mirror_offset_extra_shapeless')
        end
        for _,id in ipairs(R.order)do assert(valid(self:data(id)),'Missing generated native item '..id);checked=checked+1 end
        if self.open then
            assert(valid(widget));if nativeRoot then assert(valid(nativeRoot)and nativeRoot:GetRenderOpacity()==0,'Native menu visible')end
            self:refresh(env)
            for _,spec in ipairs(self:layout().slots)do
                local value=self:entry(env,spec)
                local shown=UE.GetKismetTextLibrary():Conv_TextToString(nodes[spec.name..'Count']:GetText())
                shown=type(shown)=='string'and shown or shown:ToString()
                assert(shown==tostring(value.count and value.count>1 and value.count or''),'Inventory count mismatch '..spec.name)
            end
        end
        log('SELF_TEST PASS PHASE_B definitions='..checked..' inventory_open='..tostring(self.open))
    end
    function B:grantTest()
        assert(ctx.config.debug,'Debug grant disabled');local env=ctx.active()
        for _,entry in ipairs({{'MC_Bread',8},{'MC_IronChestplate',1},{'MC_IronBoots',1},{'MC_Bow',1},{'MC_Arrow',4},{'MC_IronSword',1},{'MC_IronPickaxe',1},{'MC_WoodenShovel',1},{'IronIngot',12},{'Wood',30}})do
            if N:count(env,entry[1])<entry[2]then N:add(env,entry[1],entry[2]-N:count(env,entry[1]))end
        end
        log('MC_ITEMS_TEST_GRANT_DONE')
    end
    function B:snapshot()
        assert(ctx.config.debug,'Snapshot disabled');local env=ctx.active()
        for _,kind in ipairs({0,3,4})do local c=N:container(env,kind)
            for i=0,c:Num()-1 do local s=c:Get(i);local id=N:id(s)
                if id then log('MC_SLOT kind='..kind..' index='..i..' id='..id..' count='..s:GetStackCount())end
            end
        end
        local hand=self.carry
        if self.open then local x,y=self:mouse();log('MC_MOUSE local='..x..','..y..' hovered='..(self.hovered and self.hovered.name or 'none'))end
        log('MC_ITEMS_SNAPSHOT defense='..env.player.CharacterParameterComponent:GetDefense()..' food='..env.player.CharacterParameterComponent:GetFullStomach()
            ..' open='..tostring(self.open)..' lifted='..(hand and hand.id..':'..hand.count or 'none')..' output='..(self.output and self.output.id or 'none'))
    end
    Timers.onEpoch('phase-b',function()B:cancel()end)
    B.registry=R;B.native=N
    return B
end
