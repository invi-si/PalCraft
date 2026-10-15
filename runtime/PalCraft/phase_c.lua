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
    local C={dirty=true,lights={},soundCount={},cachedClock=0}
    local runtimeSound=dofile(ctx.base..'/snd_runtime.lua')(ctx)
    local R,N=ctx.items.registry,ctx.items.native
    local smelting=dofile(ctx.base..'/smelting.lua');local sounds=dofile(ctx.base..'/sounds.lua')
    local assets,lightHandle,handHandle,held,socket={},nil,nil,nil,nil
    local heldItems=dofile(ctx.base..'/held_items.lua');local hiddenWeapon={}
    function C:handVisual()return held and held.type and held.component end
    function C:handStatus()return {id=held and held.type and held.id or false,block=held and held.type and held.block or false,category=held and held.type and held.category or false,frame=self.handFrame,revision=self.handRevision66}end
    function C:hideUnusedHand()if held and not held.type and valid(held.component)then held.component:SetVisibility(false,false)end end
    local selectLights=dofile(ctx.base..'/block_lights.lua')
    local function restoreWeapon()
        for _,e in ipairs(hiddenWeapon)do if valid(e.component)then e.component:SetVisibility(e.visible,false)end end
        hiddenWeapon={}
    end
    local function point(c)return{X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+50}end
    local function time(env)return UE.GetKismetSystemLibrary():GetGameTimeInSeconds(env.player)end
    local function getAsset(path)
        if valid(assets[path])and UE.AssetMatchesRA(assets[path],path) then return assets[path]end
        local begun=os.clock()
        if valid(assets[path])then log('MC_STALE_CACHE phase-c '..path)end
        local a=StaticFindObject(path)
        if not valid(a)then local p,n=path:match('^(.*)%.([^%.]+)$');a=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(p),AssetName=UE.FindOrAddFName(n)})end
        assert(valid(a),'Phase C asset absent '..path);assets[path]=a
        log(string.format('MC109_SOUND_ASSET ms=%.3f path=%s',(os.clock()-begun)*1000,path));return a
    end
    local wardenSoundZ4=dofile(ctx.base..'/optional_soundZ4.lua')(getAsset,valid,log)
    function C:preloadSoundG(path)
        if not runtimeSound:available()then return runtimeSound:preload(path)end
        if path:find('/S_mob_warden_',1,true)then return wardenSoundZ4:asset(path)end
        return getAsset(path)
    end
    function C:soundPathsG(kind)
        if not runtimeSound:available()then return {}end
        local paths={}
        for event,list in pairs(sounds)do if event:sub(1,#kind+8)=='entity.'..kind..'.'then for _,v in ipairs(list)do paths[#paths+1]=v.asset end end end
        return paths
    end
    function C:now(env)
        self.cachedClock=self.clockBase+math.max(0,time(env)-self.clockStart);ctx.clock(self.cachedClock);return self.cachedClock
    end
    function C:persist()ctx.clock(self.cachedClock);ctx.save();ctx.items.dirty=true end
    function C:entityData()return ctx.entities()end
    function C:viewPoint(v,p)
        if v.target.X%1~=0 or v.target.Y%1~=0 or v.target.Z%1~=0 then return p end
        local k=ctx.key(v.anchor.X+v.target.X,v.anchor.Y+v.target.Y,v.anchor.Z+v.target.Z);local c=ctx.cells()[k]
        if not c then return p end;local d=ctx.registry[c.type]
        if d.kind=='slab'then p.Z=c.z*100+(v.face=='+Z'and(c.variant==0 and 50 or 100)or(c.variant==0 and 25 or c.variant==1 and 75 or 50))
        elseif d.kind=='stairs'then p.Z=c.z*100+((c.variant or 0)>=4 and 75 or 25)
        elseif d.kind=='bed'then p.Z=c.z*100+(v.face=='+Z'and 56.25 or 40)end
        return p
    end
    function C:inventoryUpdated(env)
        if not self.started then return end
        local totals=ctx.items:prepareView(env).totals;local added=false
        for id,num in pairs(totals)do if id:sub(1,3)=='MC_'and self.lastTotals and num>(self.lastTotals[id]or 0)then added=true end end
        self.lastTotals={};for id,num in pairs(totals)do self.lastTotals[id]=num end
        if added then self:play('entity.item.pickup',env.player:K2_GetActorLocation(),.3)end
    end
    function C:play(event,p,volume,env)
        if not runtimeSound:available()then return runtimeSound:play(event,p,volume,env)end
        local list=sounds[event];if not list or #list==0 then return end
        local e=list[math.random(#list)]
        env=env or ctx.active()
        local function play(a)UE.Object('/Script/Engine.Default__GameplayStatics'):PlaySoundAtLocation(env.player,a,p or env.player:K2_GetActorLocation(),{Pitch=0,Yaw=0,Roll=0},(volume or 1)*e.volume*(ctx.config.mc_sound_volume or 1),e.pitch,0,nil,nil,nil,nil)end
        if event:sub(1,14)=='entity.warden.'then
            if not wardenSoundZ4:play(e.asset,play)then return false end
        else play(getAsset(e.asset))end
        self.soundCount[event]=(self.soundCount[event]or 0)+1
        log('MC_SOUND_PLAY event='..event..' count='..self.soundCount[event])
    end
    local connected=dofile(ctx.base..'/connected_blocks.lua')(ctx,C);C.connected=connected
    function C:canPlace(c,env)return connected:canPlace(c,env)end
    function C:placement(env,hit,c)
        local d=ctx.registry[c.type]
        if d.states then return connected:placement(env,hit,c)end
        local chunk=ctx.hitChunk(hit)
        local support=chunk and chunk.keys[hit.Item];local old=support and ctx.cells()[support]
        local yaw=env.controller.PlayerCameraManager:GetCameraRotation().Yaw
        local facing=math.floor((yaw+45)/90)%4
        local upper=(hit.ImpactPoint.Z/100)%1>.5
        if d.kind=='slab'then
            if old and old.type==c.type and old.variant~=2 then
                c={x=old.x,y=old.y,z=old.z,type=old.type,variant=2,debug=false,merge=true}
            else c.variant=(hit.ImpactNormal.Z<-.5 or(math.abs(hit.ImpactNormal.Z)<.5 and upper))and 1 or 0 end
        elseif d.kind=='stairs'then c.variant=facing+((hit.ImpactNormal.Z<-.5 or(math.abs(hit.ImpactNormal.Z)<.5 and upper))and 4 or 0)
        elseif d.kind=='torch'then
            if hit.ImpactNormal.Z<-.5 then return nil end
            if math.abs(hit.ImpactNormal.Z)<.5 then
                local n=hit.ImpactNormal;c.variant=math.abs(n.X)>math.abs(n.Y)and(n.X>0 and 1 or 3)or(n.Y>0 and 2 or 4)
            else c.variant=0 end
            c.support=support
        elseif d.kind=='lantern'then c.variant=hit.ImpactNormal.Z<-.5 and 1 or 0;c.support=support
        elseif d.kind=='furnace'or d.orient=='yaw'then c.variant=(facing+1)%4
        elseif d.orient=='axis'then
            local n=hit.ImpactNormal;c.variant=math.abs(n.Z)>.5 and 0 or math.abs(n.X)>.5 and 1 or 2
        else c.variant=0 end
        return c
    end
    function C:entity(k)
        local c=ctx.cells()[k];if not c then return nil end
        local kind=ctx.registry[c.type].kind;if kind~='chest'and kind~='furnace'then return nil end
        local entities=ctx.entities()
        if not entities[k]then
            local slots={};for i=1,kind=='chest'and 27 or 3 do slots[i]=false end
            entities[k]={kind=kind,slots=slots,burn=0,cook=0,fuelTime=0,last=self.cachedClock}
        end
        return entities[k]
    end
    function C:capacity(env,id,num,target)
        local d=ctx.items:data(id);if not valid(d)then return false end
        local limit=d.MaxStackCount;local capacity=0;local common=N:container(env,0)
        if target then
            local old=N:id(target);return(not old or old==id)and limit-(old and target:GetStackCount()or 0)>=num
        end
        for i=0,common:Num()-10 do local s=common:Get(i);local old=N:id(s)
            if not old then capacity=capacity+limit elseif old==id then capacity=capacity+math.max(0,limit-s:GetStackCount())end
        end
        return capacity>=num
    end
    function C:grantInto(env,id,num,entry)
        if entry and entry.kind~=0 then log('MC_VIRTUAL_CARRY_REJECT common_slot_required');return false end
        if not self:capacity(env,id,num,entry and entry.slot)or not self:capacity(env,id,num)then log('MC_VIRTUAL_CARRY_REJECT native_inventory_full');return false end
        N:add(env,id,num)
        if entry and N:id(entry.slot)~=id then
            local source=N:find(env,id);assert(valid(source)and N:move(env,source,entry.slot,num),'Virtual grant move rejected')
        elseif entry then
            
            local wanted=entry.beforeCount or 0
            if entry.slot:GetStackCount()<wanted+num then
                local common=N:container(env,0)
                for i=0,common:Num()-1 do local s=common:Get(i)
                    if s:GetAddress()~=entry.slot:GetAddress()and N:id(s)==id then
                        local move=math.min(wanted+num-entry.slot:GetStackCount(),s:GetStackCount())
                        if move>0 then assert(N:move(env,s,entry.slot,move))end
                        if entry.slot:GetStackCount()>=wanted+num then break end
                    end
                end
            end
        end
        return true
    end
    local drops66=dofile(ctx.base..'/drop_fallback66.lua')({base=ctx.base,UE=UE,native=N,log=log,capacity=function(e,id,n)return C:capacity(e,id,n)end})
    function C:catalog(query)
        if not self.catalogList then
            local groups={building=1,coloured=2,natural=3,functional=4,tools=5,combat=6,food=7,materials=8};local list={}
            for _,d in ipairs(ctx.registry)do list[#list+1]={id=d.item,label=d.label,group=d.group,order=#list+1}end
            for _,id in ipairs(R.order)do local d=R.items[id];list[#list+1]={id=id,label=d.label,
                group=d.category=='consumable'and'food'or d.armor_part and'combat'or d.tool and d.tool~='sword'and'tools'or d.category=='weapon'and'combat'or'materials',order=#list+1}end
            table.sort(list,function(a,b)local x,y=groups[a.group],groups[b.group];return x==y and a.order<b.order or x<y end);self.catalogList=list
            log('MC_CATALOG_READY blocks='..#ctx.registry..' items='..#R.order..' total='..#list)
        end
        query=(query or''):lower();local filtered={};local hidden=dofile(ctx.base..'/catalog70.lua');local seen={} 
          for _,e in ipairs(self.catalogList)do local label=UE.language57 and UE.language57:item(e.id)or e.label;if query==''or label:lower():find(query,1,true)or e.label:lower():find(query,1,true)or e.id:lower():find(query,1,true)then if not hidden[e.id]and not seen[e.id]then filtered[#filtered+1]=e;seen[e.id]=true end end end
        return filtered
    end
    function C:stack(id)return math.min(64,ctx.items:data(id).MaxStackCount)end
    function C:canStore(id)
        local d=ctx.items:data(id)
        
        return valid(d)and(d.TypeA==5 or d.TypeA==6 or d.TypeA==8)
    end
    function C:fuel(id)
        if id=='MC_Coal'or id=='MC_Charcoal'then return 80 end
        if id=='MC_Stick'then return 5 end
        local d=R.items[id];if d and d.name=='coal'then return 80 end
        for _,b in ipairs(ctx.registry)do if b.item==id and(b.name:find('planks',1,true)or b.name:find('log',1,true)or b.name:find('wood',1,true))then return 15 end end
        return 0
    end
    function C:advance(k,now)
        local e=self:entity(k);if not e or e.kind~='furnace'then return end
        local dt=math.max(0,now-(e.last or now));e.last=now;local remaining=dt;local changed=false
        for iteration=1,2000 do
            if remaining<=.0001 then break end
            local input,fuel,output=e.slots[1],e.slots[2],e.slots[3]
            local r=input and smelting[input.id];local can=r and(not output or(output.id==r.result and output.count+r.count<=64))
            if e.burn<=.0001 then
                if not can or not fuel or self:fuel(fuel.id)<=0 then break end
                e.fuelTime=self:fuel(fuel.id);e.burn=e.fuelTime;fuel.count=fuel.count-1;if fuel.count==0 then e.slots[2]=false end;changed=true
            end
            local step=math.min(remaining,e.burn,can and(10-e.cook)or remaining)
            remaining=remaining-step;e.burn=math.max(0,e.burn-step)
            if can then
                e.cook=e.cook+step
                if e.cook>=9.9999 then
                    e.cook=0;input.count=input.count-1;if input.count==0 then e.slots[1]=false end
                    e.slots[3]={id=r.result,count=(output and output.count or 0)+r.count};changed=true
                    log('MC_SMELT_PASS cell='..k..' result='..r.result..' count='..e.slots[3].count)
                end
            else e.cook=0 end
        end
        local c=ctx.cells()[k];local wanted=(c.variant or 0)%4+(e.burn>.0001 and 4 or 0)
        if c.variant~=wanted then ctx.setVariant(k,wanted);self.dirty=true;changed=true end
        return changed or(dt>0 and e.burn>0)
    end
    function C:beforeBreak(k,env)
        if not connected:beforeBreak(k,env)then return false end
        local e=ctx.entities()[k];if not e then return true end
        self:advance(k,self.cachedClock)
        if env then
            local totals={};for _,slot in ipairs(e.slots)do if slot then totals[slot.id]=(totals[slot.id]or 0)+slot.count end end
            local common=N:container(env,0);local free,spaces=0,{}
            for i=0,common:Num()-10 do local slot=common:Get(i);local id=N:id(slot)
                if not id then free=free+1 else local d=ctx.items:data(id);spaces[id]=(spaces[id]or 0)+math.max(0,d.MaxStackCount-slot:GetStackCount())end end
            local needed=0;for id,num in pairs(totals)do local d=ctx.items:data(id);needed=needed+math.ceil(math.max(0,num-(spaces[id]or 0))/d.MaxStackCount)end
            if needed>free then log('MC_ENTITY_BREAK_REJECT native_inventory_full');return false end
            for id,num in pairs(totals)do N:add(env,id,num);log('MC_ENTITY_RETURN id='..id..' count='..num)end
        end
        ctx.entities()[k]=nil;self.dirty=true;return true
    end
    function C:changed(c,env)
        connected:changed(c,env)
        local k=ctx.key(c.x,c.y,c.z);if ctx.cells()[k]then self:entity(k)end
        self.dirty=true
        self:play('block.'..(ctx.registry[c.type].sound or'stone')..(ctx.cells()[k]and'.place'or'.break'),point(c),.6)
    end
    function C:dropUnsupported(env)
        if self.dropping then return end;self.dropping=true
        local list={};for k,c in pairs(ctx.cells())do if c.support and not ctx.cells()[c.support]then list[#list+1]=k end end
        for _,k in ipairs(list)do if ctx.cells()[k]then ctx.returnCell(k,env);log('MC_SUPPORT_DROP '..k)end end
        self.dropping=false
    end
    function C:entityEntry(k,index,hand)
        local e=assert(self:entity(k));local slot=e.slots[index]
        local count=slot and slot.count or 0
        if hand and hand.kind=='entity'and hand.key==k and hand.index==index then count=math.max(0,count-hand.count)end
        return{id=count>0 and slot.id or nil,count=count,kind='entity',index=index,key=k}
    end
    function C:transfer(env,hand,entry,right)
        local num=right and 1 or hand.count;local from=hand.kind=='entity'and self:entity(hand.key)or nil
        if entry.kind=='entity'then
            local e=self:entity(entry.key);local target=e.slots[entry.index]
            if e.kind=='furnace'and(entry.index==3 or(entry.index==2 and self:fuel(hand.id)<=0))then log('MC_ENTITY_MOVE_REJECT invalid_furnace_slot');return false end
            if not self:canStore(hand.id)or(target and target.id~=hand.id)then log('MC_ENTITY_MOVE_REJECT incompatible_or_dynamic_item');return false end
            if from and hand.key==entry.key and hand.index==entry.index then return'cancel'end
            num=math.min(num,64-(target and target.count or 0));if num<=0 then return false end
            if from then local source=assert(from.slots[hand.index]);source.count=source.count-num;if source.count==0 then from.slots[hand.index]=false end
            elseif hand.kind~='creative'then N:dispose(env,hand.slot,num)end
            e.slots[entry.index]={id=hand.id,count=(target and target.count or 0)+num};e.last=self:now(env)
        else
            entry.beforeCount=entry.id and entry.slot:GetStackCount()or 0
            if not self:grantInto(env,hand.id,num,entry)then return false end
            if from then local source=assert(from.slots[hand.index]);source.count=source.count-num;if source.count==0 then from.slots[hand.index]=false end end
        end
        hand.count=hand.count-num;ctx.save();self.dirty=true
        log('MC_ENTITY_MOVE_PASS id='..hand.id..' count='..num..' from='..hand.kind..' to='..entry.kind)
        return hand.count==0 and'cancel'or true
    end
    local function actor(env,tag)
        local g=UE.Object('/Script/Engine.Default__GameplayStatics');local t=ctx.transform(0,0,0)
        local a=g:BeginDeferredActorSpawnFromClass(env.player,UE.Object('/Script/Engine.Actor'),t,1,nil);assert(valid(a));a=g:FinishSpawningActor(a,t);a.Tags={UE.FindOrAddFName(tag)};return a
    end
    function C:explosionFlash(c,env)
        local a=actor(env,'MCBlocksLight');local comp=a:AddComponentByClass(UE.Object('/Script/Engine.PointLightComponent'),false,ctx.transform(0,0,0),false)
        comp:SetMobility(2);comp:SetCastShadows(false);comp:SetIntensity(8000);comp:SetAttenuationRadius(600);_G.MC_OUT_K('K2_SetActorLocation',a,point(c),false,ignoredHitJ(),true)
        local stamp=ctx.epoch();Timers.after(180,function()if stamp==ctx.epoch()and not ctx.quiesced()and valid(a)then a:K2_DestroyActor()end end)
    end
    function C:explosionFlashJobs(c,env)
        local a,comp;local g=UE.Object('/Script/Engine.Default__GameplayStatics');local t=ctx.transform(0,0,0)
        return {
            function(e)a=g:BeginDeferredActorSpawnFromClass(e.player,UE.Object('/Script/Engine.Actor'),t,1,nil);assert(valid(a))end,
            function()a=g:FinishSpawningActor(a,t);a.Tags={UE.FindOrAddFName('MCBlocksLight')}end,
            function()comp=a:AddComponentByClass(UE.Object('/Script/Engine.PointLightComponent'),false,t,false);assert(valid(comp))end,
            function()comp:SetMobility(2);comp:SetCastShadows(false)end,
            function()comp:SetIntensity(8000);comp:SetAttenuationRadius(600)end,
            function()_G.MC_OUT_K('K2_SetActorLocation',a,point(c),false,ignoredHitJ(),true);local stamp=ctx.epoch();Timers.after(180,function()if stamp==ctx.epoch()and not ctx.quiesced()and valid(a)then a:K2_DestroyActor()end end)end,
        }
    end
    function C:updateLights(env)
        local list,candidates=selectLights(ctx.cells(),ctx.registry,ctx.entities(),env.player:K2_GetActorLocation());local wanted={}
        for _,e in ipairs(list)do wanted[e.key]=true end
        
        for k,e in pairs(self.lights)do if not wanted[k]or not valid(e.actor)or not valid(e.component)then if valid(e.actor)then e.actor:K2_DestroyActor()end;self.lights[k]=nil end end
        for _,e in ipairs(list)do
            local old=self.lights[e.key]
            if not old then
                local a=actor(env,'MCBlocksLight');local comp=a:AddComponentByClass(UE.Object('/Script/Engine.PointLightComponent'),false,ctx.transform(0,0,0),false)
                comp:SetMobility(2);comp:SetCastShadows(false);comp:SetUseInverseSquaredFalloff(false);comp:SetLightFalloffExponent(2);comp:SetSourceRadius(0);comp:SetSoftSourceRadius(0)
                self.lights[e.key]={actor=a,component=comp}
            end
            local light=self.lights[e.key]
            if light.level~=e.level or light.name~=e.name then
                light.component:SetIntensity(e.level/3.5);light.component:SetAttenuationRadius(e.level*100)
                light.component:SetLightColor(e.name=='lava'and{R=1,G=.43,B=.16,A=1}or{R=1,G=.77,B=.48,A=1},false)
                _G.MC_OUT_K('K2_SetActorLocation',light.actor,e.point,false,ignoredHitJ(),true);light.level=e.level;light.name=e.name
            end
        end
        self.lightSelection=list;self.lightCandidates=candidates;local n=#list
        if self.lightCount~=n then self.lightCount=n;log('MC_LIGHT_ACTIVE count='..n..' cap=24')end;self.dirty=false
    end
    function C:updateHand(env)
        local input=ctx.gameplayInput(env)
        local slot=ctx.phaseA.selected;local e=ctx.items:hotbar(env,slot);local block,tool,id
        if e and e.count>0 and input then id=e.id;tool=heldItems[id];for i,d in ipairs(ctx.registry)do if d.item==id then block=i;break end end end
        local weapon=env.player.ShooterComponent:GetHasWeapon()
        if not valid(weapon)or weapon:GetItemId().StaticId:ToString()~=id then weapon=nil end
        local token=tool and id or block
        local weaponAddress=valid(weapon)and weapon:GetAddress()or false
        self.handFrame=Timers.frameCounter
        if not token then if held then held.type=nil;held.component:SetVisibility(false,false)end;restoreWeapon();return end
        if held and held.type==token and(not tool or held.weapon==weaponAddress)then return end
        restoreWeapon()
        local mesh=env.player.Mesh
        if not socket then
            local names=mesh:GetAllSocketNames();local found={}
            local function append(name)
                local ok,label=pcall(function()return type(name)=='string'and name or name:ToString()end)
                if not ok then ok,label=pcall(function()return name:get():ToString()end)end
                if ok then found[#found+1]=label
                elseif type(name)=='table'then for _,v in pairs(name)do if type(v)=='string'then found[#found+1]=v end end end
            end
            if type(names)=='table'then for _,name in ipairs(names)do append(name)end
            else names:ForEach(function(_,v)append(v:get())end)end
            log('MC_HAND_SOCKETS '..table.concat(found,','))
            for _,candidate in ipairs({'weapon_r','hand_r','Weapon_R','socket_weapon_r'})do if mesh:DoesSocketExist(UE.FindOrAddFName(candidate))then socket=candidate;break end end
            if not socket then log('MC_HAND_SKIP no_right_hand_socket');return end
        end
        local a=held and held.actor or actor(env,'MCBlocksHeld');local comp=held and held.component or a:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,ctx.transform(0,0,0),false)
        comp:SetMobility(2);comp:SetCollisionEnabled(0);comp:SetStaticMesh(tool and getAsset(tool.mesh)or ctx.loadMesh('held',block))
        comp:SetVisibility(true,false)
        comp:K2_AttachToComponent(mesh,UE.FindOrAddFName(socket),2,2,2,false)
        comp:SetRelativeScale3D(tool and{X=1,Y=1,Z=1}or{X=.25,Y=.25,Z=.25});_G.MC_OUT_K('K2_SetRelativeLocation',comp,tool and{X=0,Y=2,Z=0}or{X=0,Y=8,Z=0},false,ignoredHitJ(),true)
        if tool then
            local rotations={sword={Pitch=0,Yaw=0,Roll=0},pickaxe={Pitch=0,Yaw=0,Roll=0},axe={Pitch=0,Yaw=0,Roll=0},shovel={Pitch=0,Yaw=0,Roll=0},bow={Pitch=0,Yaw=0,Roll=90}}
            _G.MC_OUT_K('K2_SetRelativeRotation',comp,rotations[tool.category]or{Pitch=0,Yaw=0,Roll=0},false,ignoredHitJ(),true)
            for _,v in ipairs(valid(weapon)and weapon:K2_GetComponentsByClass(UE.Object('/Script/Engine.MeshComponent'))or{})do local ok,c=pcall(function()return v:get()end);c=ok and c or v
                if valid(c)then hiddenWeapon[#hiddenWeapon+1]={component=c,visible=c.bVisible};c:SetVisibility(false,false)end
            end
        end
        self.handRevision66=(self.handRevision66 or 0)+1
        held={actor=a,component=comp,type=token,id=id,block=block,category=tool and tool.category,weapon=tool and weaponAddress};log(tool and('MC_TOOL_HAND_READY id='..id..' category='..tool.category..' native_meshes='..#hiddenWeapon..' socket='..socket)or('MC_BLOCK_HAND_READY type='..ctx.registry[block].name..' socket='..socket))
    end
    function C:start(env)
        self:cancel(false);self.clockStart=time(env);self.clockBase=ctx.clock();self.cachedClock=self.clockBase;self.lights={};self.started=true
        
        local stamp=ctx.epoch()
        lightHandle=Timers.loop(2000,function()
            if stamp~=ctx.epoch()or ctx.quiesced()then return true end
            local current=ctx.environment();if not current then return true end
            local ok,err=pcall(function()
                drops66:tick(current)
                local now=self:now(current);local changed=false
                for k,e in pairs(ctx.entities())do if e.kind=='furnace'then changed=self:advance(k,now)or changed end end
                if changed then ctx.save();ctx.items.dirty=true end
                self:updateLights(current)
            end)
            if not ok then log('MC_PHASE_C_ERROR lights '..tostring(err));return true end;return false
        end)
        handHandle=Timers.loop(150,function()
            if stamp~=ctx.epoch()or ctx.quiesced()then return true end
            local current=ctx.environment();if not current then return true end
            local ok,err=pcall(self.updateHand,self,current)
            if not ok then log('MC_PHASE_C_ERROR hand '..tostring(err));return true end;return false
        end)
        log('MC_PHASE_C_READY smelting='..(function()local n=0;for _ in pairs(smelting)do n=n+1 end;return n end)())
    end
    function C:cancel(persist)
        if not persist then
            restoreWeapon();if held and valid(held.actor)then held.actor:K2_DestroyActor()end
            for _,e in pairs(self.lights)do if valid(e.actor)then e.actor:K2_DestroyActor()end end
        else hiddenWeapon={}end
        if persist and self.started and not ctx.quiesced()then ctx.clock(self.cachedClock);ctx.save()end
        for _,h in ipairs({lightHandle or false,handHandle or false})do if h then Timers.cancel(h)end end
        lightHandle,handHandle,held=nil,nil,nil;self.lights={};socket=nil;assets={};self.started=false
    end
    function C:selfTest()
        local all=self:catalog('');assert(#all==#ctx.registry+#R.order,'Creative catalog count mismatch')
        for _,query in ipairs({'oak','stone','wool'})do assert(#self:catalog(query)>0,'Catalog search empty '..query)end
        assert(self.lightCount==nil or self.lightCount<=24,'Light cap exceeded')
        log('SELF_TEST PASS PHASE_C catalog='..#all..' lights='..(self.lightCount or 0))
    end
    Timers.onEpoch('phase-c',function()
        for _,h in ipairs({lightHandle or false,handHandle or false})do if h then Timers.cancel(h)end end
        assets={};lightHandle,handHandle,held,socket=nil,nil,nil,nil;hiddenWeapon={};C.lights={};C.started=false
    end)
    C.native=N
    return C
end
