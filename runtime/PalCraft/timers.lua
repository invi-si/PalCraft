-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local existing=package.loaded['PalCraft.timers']
if existing then return existing end
local function new(native)
    local T={pending={},running={},hooks={},keys={},frames={},frameOrder={},frameCounter=0,serial=0,epoch=0,epochHandlers={},nativeRefCount=0}
    
    T.crumbs={};T.crumbSeq=0;T.crumbAt=0;T.pendingCountZ3=0;T.runningCountZ3=0
    T.due={};T.frameLabels={}
    function T.breadcrumb(owner,op)
        T.crumbSeq=T.crumbSeq+1
        local pending,running=T.pendingCountZ3,T.runningCountZ3
        local i=(T.crumbSeq-1)%96+1;local r=T.crumbs[i]or{};T.crumbs[i]=r
        r.seq=T.crumbSeq;r.epoch=T.epoch;r.frame=T.frameCounter;r.owner=owner;r.op=op;r.pending=pending;r.running=running;r.at=native.now()
    end
    function T.flushBreadcrumbs()
        if not T.breadcrumbPath or native.now()<T.crumbAt then return end
        T.crumbAt=native.now()+1000
        local f=io.open(T.breadcrumbPath,'wb');if not f then return end
        f:write('seq\tepoch\tframe\tsubsystem\top\tpending\trunning\tms\n')
        for seq=math.max(1,T.crumbSeq-95),T.crumbSeq do local r=T.crumbs[(seq-1)%96+1]
            if r then f:write(string.format('%d\t%d\t%d\t%s\t%s\t%d\t%d\t%.3f\n',r.seq,r.epoch,r.frame,tostring(r.owner),tostring(r.op),r.pending,r.running,r.at))end
        end
        f:flush();f:close()
    end
    local function registered(kind)
        T.nativeRefCount=T.nativeRefCount+1
        if not native.quiet then print('[PalCraft] MC_NATIVE_REF_REGISTER count='..T.nativeRefCount..' kind='..kind..'\n')end
    end

    function T.onEpoch(name,callback) T.epochHandlers[name]=callback end
    function T.advanceEpoch(value,reason)
        T.paused=T.faulted or false
        T.epoch=value
        T.breadcrumb('lifecycle',reason)
        local errors={}
        for name,callback in pairs(T.epochHandlers)do
            local ok,err=xpcall(callback,debug.traceback,value,reason)
            if not ok then errors[#errors+1]={owner=name,message=err}end
        end
        
        for _,failure in ipairs(errors)do T.reportError(failure.owner,failure.message)end
        if #errors>0 then error(errors[1].message)end
    end
    function T.reportError(owner,message)
        local s=tostring(message);local lower=s:lower()
        if lower:find('no overload',1,true)or lower:find('uobject',1,true)or lower:find('nullptr',1,true)or lower:find('lua_state',1,true)then
            print('[PalCraft] MC_LUA_CPP_ERROR owner='..tostring(owner)..' '..s..'\n');io.flush()
            if not T.faulted then
                T.faulted=true;T.paused=true;T.breadcrumb(owner,'native-fault')
                T.pending={};T.running={};T.pendingCountZ3=0;T.runningCountZ3=0
                for i=#T.due,1,-1 do T.due[i]=nil end

                if T.onNativeFault then
                    local ok,err=xpcall(T.onNativeFault,debug.traceback,owner,s)
                    if not ok then print('[PalCraft] MC_FAULT_FORGET_ERROR '..tostring(err)..'\n');io.flush()end
                end
                T.pending={};T.running={};T.pendingCountZ3=0;T.runningCountZ3=0;T.paused=true
                for i=#T.due,1,-1 do T.due[i]=nil end
            end
            return true
        end
        return false
    end
    local function trace(event,token,detail)
        if T.trace then T.trace('MC_TIMER '..event..' id='..token.id..' owner='..token.owner..' generation='..(token.generation or 0)..' '..(detail or ''))end
    end
    local function tokenFor(callback,owner)
        T.serial=T.serial+1;local info=debug.getinfo(callback,'S')
        return {id=T.serial,owner=owner or(info.short_src..':'..info.linedefined),fn=callback}
    end
    local function enqueue(token,delay)
        token.epoch=T.epoch
        token.generation=(token.generation or 0)+1
        token.due=native.now()+math.max(0,delay);if not T.pending[token]then T.pendingCountZ3=T.pendingCountZ3+1 end;T.pending[token]=true
        if T.trace then trace('SCHEDULE',token,'delay='..delay..' native=false')end
    end
    function T.after(delay,callback,owner)
        local token=tokenFor(callback,owner);enqueue(token,delay);return token
    end
    function T.defer(callback)return T.after(0,callback,'lua-defer')end
    function T.deferInput(callback)return T.after(0,callback,'menu-input')end
    function T.frame(owner,callback)
        assert(not T.frames[owner],'Duplicate frame owner');T.frames[owner]=callback;T.frameOrder[#T.frameOrder+1]=owner
        T.frameLabels[owner]='frame:'..owner
        local priorities={['startup-probe']=-1000,['task60-observer']=-100,['task61-engine']=-100,['pal-readiness']=-80,['menu-input']=-60,['ui-input-owner']=-50,['task61-observer']=100}
        table.sort(T.frameOrder,function(a,b)local ap,bp=priorities[a]or 0,priorities[b]or 0;return ap==bp and a<b or ap<bp end)
    end
    function T.loop(delay,callback,owner)
        local token=tokenFor(callback,owner);token.interval=math.max(1,delay);enqueue(token,delay);return token
    end
    function T.cancel(token)
        if not token then return false end
        trace('CANCEL_ENTER',token)
        if token.cancelled or token.finished then trace('CANCEL_EXIT',token,'inactive=true');return false end
        if not T.running[token]and not T.pending[token]then trace('CANCEL_EXIT',token,'pending=false');return false end
        token.cancelled=true;if T.pending[token]then T.pendingCountZ3=T.pendingCountZ3-1 end;T.pending[token]=nil
        trace('CANCEL_EXIT',token,'lua_only=true');return true
    end
    function T.beginProfile()T.profile={} end
    function T.beginAllocationProfile()
        T.allocations={};T.allocationStarted=os.clock()
    end
    function T.allocationRecord(owner,before)
        local growth=collectgarbage('count')-before
        local r=T.allocations[owner]
        if not r then r={calls=0,kb=0,maxKB=0};T.allocations[owner]=r end
        r.calls=r.calls+1;r.kb=r.kb+growth;r.maxKB=math.max(r.maxKB,growth)
    end
    function T.endAllocationProfile()
        local r={seconds=os.clock()-T.allocationStarted,owners=T.allocations}
        T.allocations=nil;T.allocationStarted=nil;return r
    end
    local profiler=dofile(debug.getinfo(1,'S').source:sub(2):gsub('timers.lua$','frame_budget.lua'))
    function T.beginBudgetProfile()T.budgetProfile=profiler.new(os.clock)end
    function T.endBudgetProfile()local p=T.budgetProfile;T.budgetProfile=nil;return p and p:report()or{}end
    function T.measure(owner,callback,...)
        if not T.budgetProfile then return callback(...)end
        local at=os.clock();local result=table.pack(callback(...))
        if T.budgetProfile then T.budgetProfile:record(owner,(os.clock()-at)*1000,T.frameCounter)end
        return table.unpack(result,1,result.n)
    end
    function T.endProfile()
        local report={}
        for owner,values in pairs(T.profile or{})do
            table.sort(values);local n=#values
            report[owner]={count=n,median_ms=n>0 and values[math.ceil(n/2)]or 0,max_ms=values[n]or 0}
        end
        T.profile=nil;return report
    end
    local function priority(owner)return owner=='alive-service-start'and 3 or owner=='perf-sampler'and 2 or((owner=='hotbar-input'or owner=='menu-input'or owner=='alive-service-start')and 1 or 0)end
    local function dueBefore(a,b)
        local ap,bp=priority(a.owner),priority(b.owner)
        if ap~=bp then return ap>bp end
        return a.due==b.due and a.id<b.id or a.due<b.due
    end
    local function tick()
        if T.hitch then T.hitch:beginFrame(T.frameCounter+1)end
        local crumbStart=T.hitch and T.hitch.active and os.clock()
        T.flushBreadcrumbs()
        if crumbStart and T.budgetProfile then T.budgetProfile:record("breadcrumbs",(os.clock()-crumbStart)*1000,T.frameCounter+1)end
        if T.faulted then return end
        local tickStarted=T.budgetProfile and os.clock()
        T.frameCounter=T.frameCounter+1
        local frameStart=native.now()
        if not T.paused then for _,owner in ipairs(T.frameOrder)do local callback=T.frames[owner];if callback and(not T.admission or T.admission(owner))then
            if T.hitch then T.hitch.owner=T.frameLabels[owner]end
            T.breadcrumb(owner,'frame')
            local started=(T.profile or T.budgetProfile)and os.clock()
            local allocated=T.allocations and collectgarbage('count')
            local ok,err=xpcall(callback,debug.traceback,value,reason)
            if allocated and T.allocations then T.allocationRecord(T.frameLabels[owner],allocated)end
            if started and T.profile then local values=T.profile['frame:'..owner]or{};T.profile['frame:'..owner]=values;values[#values+1]=(os.clock()-started)*1000 end
            if started and T.budgetProfile then T.budgetProfile:record(T.frameLabels[owner],(os.clock()-started)*1000,T.frameCounter)end
            if not ok then T.frames[owner]=nil;T.reportError(owner,err);print('[PalCraft] MC_TIMER_ERROR owner='..owner..' '..tostring(err)..'\n');io.flush()end
            if T.faulted then return end
        end end end
        local due,now=T.due,native.now();for i=#due,1,-1 do due[i]=nil end
        for token in pairs(T.pending)do if token.due<=now then due[#due+1]=token end end
        table.sort(due,dueBefore)
        local backgroundRan=false
        for _,token in ipairs(due)do
            if token.owner~='perf-sampler'then
                if T.budgetMs and native.now()-frameStart>=T.budgetMs and backgroundRan then break end
            end
            if not token.interval and token.epoch~=T.epoch then if T.pending[token]then T.pendingCountZ3=T.pendingCountZ3-1 end;T.pending[token]=nil;token.cancelled=true end
            if T.pending[token]and not token.cancelled and(not T.paused or token.owner=='perf-sampler')and(not T.admission or T.admission(token.owner))then
                if token.owner~='perf-sampler'and token.owner~='hotbar-input'then backgroundRan=true end
                T.pending[token]=nil;T.pendingCountZ3=T.pendingCountZ3-1;T.running[token]=true;T.runningCountZ3=T.runningCountZ3+1
                if T.hitch then T.hitch.owner=token.owner end
                T.breadcrumb(token.owner,'timer')
                if T.ownerTrace then print('[PalCraft] MC37_OWNER_BEGIN '..token.owner..'\n');io.flush()end
                trace('FIRE_ENTER',token)
                local started=(T.profile or T.budgetProfile)and os.clock()
                local allocated=T.allocations and collectgarbage('count')
                local ok,result=xpcall(token.fn,debug.traceback)
                if allocated and T.allocations then T.allocationRecord(token.owner,allocated)end
                if started and T.profile then local values=T.profile[token.owner]or{};T.profile[token.owner]=values;values[#values+1]=(os.clock()-started)*1000 end
                if started and T.budgetProfile then T.budgetProfile:record(token.owner,(os.clock()-started)*1000,T.frameCounter)end
                T.running[token]=nil;T.runningCountZ3=T.runningCountZ3-1
                if T.ownerTrace then print('[PalCraft] MC37_OWNER_END '..token.owner..' ok='..tostring(ok)..'\n');io.flush()end
                if T.trace then trace('FIRE_EXIT',token,'ok='..tostring(ok)..' stop='..tostring(result==true))end
                if not ok then
                    token.cancelled=true
                    T.reportError(token.owner,result)
                    if T.onError then T.onError(token.owner,result)
                    else print('[PalCraft] MC_TIMER_ERROR owner='..token.owner..' '..tostring(result)..'\n');io.flush()end
                elseif token.interval and result~=true and not token.cancelled then enqueue(token,token.interval)
                else token.finished=true end
                if T.faulted then return end
            end
        end
        for i=#due,1,-1 do due[i]=nil end
        if T.hitch then T.hitch.owner="lua-gc"end
        if T.gcBudget and not T.paused then T.gcBudget:tick()end
        if T.hitch then T.hitch:endFrame()end
        if tickStarted and T.budgetProfile then T.budgetProfile:frame((os.clock()-tickStarted)*1000)end
    end
    
    T.master=native.loop(1,function()
        local ok,err=xpcall(tick,debug.traceback)
        if not ok then T.reportError('master',err);print('[PalCraft] MC_TIMER_ERROR master '..tostring(err)..'\n');io.flush()end
        return false
    end)
    registered('master')
    function T.hook(path,pre,post)
        if not native.quiet then assert(path=='/Script/Engine.PlayerController:ClientRestart'or path:match('^/Game/Pal/')or path:match('^/Script/Pal%.')or path=='/Game/CustomPalsA1/BP_Action_Ac_Golem.BP_Action_Ac_Golem_C:OnBeginAction','Forbidden engine base hook: '..path)end
        local ids=T.hooks[path]
        if not ids then
            local function contained(callback,phase)
                if not callback then return nil end
                return function(...)
                    if T.faulted then return end
                    if path~='/Script/Engine.PlayerController:ClientRestart'and path~='/Game/Pal/Blueprint/UI/Title/WBP_TitleLocalWorldSelect.WBP_TitleLocalWorldSelect_C:OnClickedStartWorldButtonEventInternal'and T.admission and not T.admission('native-hook')then return end
                    local result=table.pack(xpcall(callback,debug.traceback,...))
                    if not result[1]then
                        local owner=path..':'..phase;local message=tostring(result[2])
                        pcall(T.reportError,owner,message)
                        pcall(print,'[PalCraft] MC_HOOK_ERROR owner='..owner..' '..message..'\n')
                        pcall(io.flush)
                        return
                    end
                    return table.unpack(result,2,result.n)
                end
            end
            ids=table.pack(native.hook(path,contained(pre,'pre'),contained(post,'post')))
            T.hooks[path]=ids;registered('hook '..path)
        end
        return table.unpack(ids,1,ids.n)
    end
    function T.key(key,modifiers,callback)
        if type(modifiers)=='function'then callback,modifiers=modifiers,{}end
        local names={};for _,m in ipairs(modifiers or{})do names[#names+1]=tostring(m)end;table.sort(names)
        local id=tostring(key)..':'..table.concat(names,',')
        if T.keys[id]then return end
        native.key(key,modifiers,callback);T.keys[id]=true;registered('key '..id)
    end
    return T
end
local T=new({loop=LoopInGameThreadWithDelay,now=function()return os.clock()*1000 end,hook=RegisterHook,key=RegisterKeyBindAsync})
T.budgetMs=4
T.gcBudget=dofile(debug.getinfo(1,'S').source:sub(2):gsub('timers.lua$','gc_budget.lua'))(collectgarbage,os.clock)
T.new=new
package.loaded['PalCraft.timers']=T
return T
