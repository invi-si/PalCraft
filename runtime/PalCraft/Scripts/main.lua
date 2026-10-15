-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local UE={}
UE.startupReadsJ={}
do
 local native=dofile
 function UE.dofileJ(path)
    local at=os.clock();local result=table.pack(native(path))
    local rows=UE.startupReadsJ;rows[#rows+1]={path=path,ms=(os.clock()-at)*1000}
    return table.unpack(result,1,result.n)
 end
end
local Startup,startupJobs={} , {}
local function live(o)return type(o)=='userdata'and o:IsValid()end
local cdoPaths={text='/Script/Engine.Default__KismetTextLibrary',system='/Script/Engine.Default__KismetSystemLibrary'}
local cdos={}
local function cdo(name)
    assert(Startup.open or Startup.uiOpen or Startup.coverWork,'Native CDO lookup before schema/UI admission')
    if not live(cdos[name])then cdos[name]=StaticFindObject(cdoPaths[name])end
    return cdos[name]
end
local textLibrary={}
function textLibrary:Conv_StringToText(value)
    if type(value)~='string'then value=tostring(value or'')end
    local library=cdo('text');if not live(library)then return FText(value)end
    if UE.language57 then UE.language57:refresh();value=UE.language57:t(value)end
    return library:Conv_StringToText(value)
end
function textLibrary:Conv_TextToString(value)
    
    if type(value)~='userdata'or value:type()~='FText'then value=FText('')end
    local library=cdo('text')
    if not live(library)then return {ToString=function()return value:ToString()end}end
    return library:Conv_TextToString(value)
end
function UE.GetKismetTextLibrary()return textLibrary end
function UE.GetKismetSystemLibrary()local library=cdo('system');return live(library)and library or nil end
UE.fnameCache65c={}
function UE.FindOrAddFName(name)
    if type(name)~='string'then name=tostring(name or'None')end
    local cached=UE.fnameCache65c[name];if cached then return cached end
    local found=FName(name,EFindName.FNAME_Find)
    if found==NAME_None then found=FName(name,EFindName.FNAME_Add)end
    UE.fnameCache65c[name]=found;return found
end
local gameInstance,playerController,environmentCache
local objects={}
function UE.Object(path)
    assert(Startup.open or(Startup.uiPreloadM and Startup.schemaAdmitted)or(Startup.coverWork and(path:match('^/Script/UMG%.')or path=='/Script/AssetRegistry.Default__AssetRegistryHelpers'or path=='/Script/Engine.Default__KismetMaterialLibrary'or path=='/Script/Engine.Default__KismetRenderingLibrary'or path=='/Script/Engine.Default__GameplayStatics'))or(Startup.uiOpen and(UE.earlyGameplay51 or path:match('^/Game/MinecraftSteve/')or path:match('^/Script/UMG%.')or path:match('^/Script/AssetRegistry%.')or path=='/Script/Engine.Default__KismetMaterialLibrary'or path=='/Script/Engine.Default__KismetRenderingLibrary'or path=='/Script/Engine.Texture' or path=='/Script/Engine.Default__GameplayStatics')),'Object lookup before startup admission: '..path)
    local o=objects[path];if not live(o)then o=StaticFindObject(path);objects[path]=o end;return o
end
function UE.GetGameInstance()
    if not live(gameInstance)then
        if os.clock()<(UE.instanceScanAt109e or 0)then return nil end
        UE.instanceScanAt109e=os.clock()+.5
        gameInstance=FindFirstOf('GameInstance')
    end
    return gameInstance
end
function UE.GetPlayerController()
    if live(playerController)then return playerController end

    if os.clock()<(UE.controllerScanAt109e or 0)then return nil end
    UE.controllerScanAt109e=os.clock()+.5
    for _,controller in ipairs(FindAllOf('PlayerController')or FindAllOf('Controller')or{})do
        if live(controller)and controller:IsLocalPlayerController()then playerController=controller;return controller end
    end
end
UE.testWorld65 = string.rep('0',32)
local WORLD = UE.testWorld65 
local SIZE, CHUNK = 100, 8
local base = debug.getinfo(1,'S').source:sub(2):gsub('[/\\]Scripts[/\\]main.lua$','')
UE.packFlags=dofile(base..'/feature_flags.lua').read(base)
dofile(base..'/legacy_paths.lua').install(base)
UE.packServices=dofile(base..'/pack_services.lua')
if not UE.packFlags:has('hud_skins')then
 if UE.packFlags:has('islands_animals')then return dofile(base..'/native_pack.lua')({base=base,flags=UE.packFlags})end
 print('[PalCraft] Core enabled; no optional services selected\n');return
end

_G.MC_OUT_K,UE.outparmK=dofile(base..'/outparmK.lua')()
UE.worldScope65=UE.dofileJ(base..'/world_scope.lua')(base,UE.testWorld65)
UE.language57=UE.dofileJ(base..'/language.lua')({base=base,valid=live})
local Timers=UE.dofileJ(base..'/timers.lua')
UE.hitch109=UE.dofileJ(base..'/hitch109.lua');UE.hitch109:install(UE,Timers);Timers.hitch=UE.hitch109
Timers.breadcrumbPath=base..'/lifecycle-breadcrumbs.txt'
Timers.onEpoch('native-resolvers',function()cdos={};gameInstance=nil;playerController=nil;UE.controllerScanAt109e=nil;UE.instanceScanAt109e=nil;environmentCache=nil;UE.environmentFrame=nil;UE.worldAddress61=nil;UE.worldIdentity61=nil;objects={} end)
local path = base..'/blocks-'..WORLD..'.json'
local cells, chunks, session, sequence = {}, {}, nil, 0
local entities,entityClock={},0
local J=UE.dofileJ(base..'/json.lua')
local CellState=UE.dofileJ(base..'/cell_state.lua')
local mechanics,beds,deathScreen,resources
local resourceState
local ResourceState=UE.dofileJ(base..'/resource_state.lua')
local busy, disabled = false, false
local quiesced, drainHandle, ui = false, nil, nil
local transitioning=true
local beginTransition

local uiStage, probeRemovedAt = 'passed', nil
local uiInventoryHooks={}
local uiUpdatePending=false
local epoch, diagnostic = 0, nil
local worldReady=false
local restoring=false
local verified = {}
local dirtGranted = false
local inventoryTransactionsReady = true
local nativeDirtInventory, nativeDirtRemoval, remove
local inventoryTransaction = nil
UE.placementDirty68=false
UE.placementCount68=0
local pendingPath = base..'/inventory-pending-'..WORLD..'.json'
local registry = UE.dofileJ(base..'/registry.lua')
local typeByName={}
for i,definition in ipairs(registry) do typeByName[definition.name]=i end
assert(registry[1].name=='dirt','Legacy cells require dirt as first type')
local selectedType, testGranted = 1, false
local placeCell, returnCell, selfTest, houseTest
local updateHotbar
local phaseA,phaseB,phaseC,phaseD,task12,config,blockMode
config=UE.packFlags:apply(UE.dofileJ(base..'/config.lua'))

config.test_mode=false;config.debug=false;config.legacy_debug_keys=false
Timers.trace=config.timer_trace and function(s)print('[PalCraft] '..s..'\n');io.flush()end or nil
Timers.ownerTrace=config.island_trace==true
if config.enabled==false then print('[PalCraft] CONFIG_C_MOD_DISABLED no_keys_no_hooks\n');return end
blockMode=true
local directReturns = false 
local intersectsPlayer, startLiveTimer, stopLiveTimer, targetCell
local deferred, preview, liveHandle, restoreHandle = {}, nil, nil, nil
local previewEnabled=true
local function log(s)
    s=tostring(s);print('[PalCraft] '..s..'\n');if config.debug then io.flush()end
    if s:find('_ERROR',1,true)or s:find('HOTBAR_UPDATE_FAIL',1,true)then Timers.reportError('runtime_log',s)end
end
local function phase(name, action)
    log('PHASE '..name..'_BEGIN')
    local result=action()
    log('PHASE '..name..'_END')
    return result
end
Startup=UE.dofileJ(base..'/startup_gate.lua')({timers=Timers,now=function()return os.clock()*1000 end,startDelay=function()return UE.earlyGameplay51 and 500 or 2000 end,epoch=function()return epoch end,quiesced=function()return quiesced end,log=log,logPath=base..'/../../UE4SS.log'})

Timers.admission=function(owner)return owner=='startup-probe'or owner=='startup-admission'or owner=='loading-cover-preload'or owner=='loading-cover-display'or(owner=='ui-preload'and Startup.schemaAdmitted)or(owner=='native-save-title'and UE.leaving62)or(Startup.open and not UE.restartPending65b)end
Timers.onEpoch('startup-admission',function()Startup:reset()end)
local function valid(o) return live(o) end
UE.texRuntime=dofile(base..'/tex_runtime.lua')({base=base,UE=UE,valid=live,log=log,timers=Timers});UE.texRuntime:install()
local function str(s) return type(s)=='string' and s or s:ToString() end
local function key(x,y,z) return string.format('%d,%d,%d',x,y,z) end
local function count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
local function sorted(t) local a={} for k in pairs(t) do a[#a+1]=k end table.sort(a) return a end
local function vector(x,y,z) return {X=x,Y=y,Z=z} end
local function transform(x,y,z)
    return {Rotation={X=0,Y=0,Z=0,W=1},Translation=vector(x,y,z),Scale3D=vector(1,1,1)}
end
local function signature(name, expected)
    assert(Startup.open or(Startup.coverWork and(name:match('^/Script/UMG%.')or name:match('^/Script/Engine.KismetSystemLibrary:')))or(Startup.uiOpen and(UE.earlyGameplay51 or name:match('^/Script/UMG%.')or name:match('^/Script/Engine.KismetSystemLibrary:'))),'Signature lookup before startup admission')
    if verified[name] then return end
    local fn=StaticFindObject(name)
    assert(valid(fn),'Missing function '..name)
    local names={}
    fn:ForEachProperty(function(p) names[#names+1]=p:GetFullName():match('([^:]+)$') end)
    assert(#names==#expected,'Signature size changed '..name..' '..table.concat(names,','))
    for i,n in ipairs(expected) do assert(names[i]:lower()==n:lower(),
        'Signature changed '..name..' '..table.concat(names,',')) end
    verified[name]=true
    log('SIGNATURE_OK '..name)
end
local function loadMesh(reason, blockType, variant)
    assert(Startup.open or(Startup.uiOpen and UE.earlyGameplay51),'Mesh load before startup admission')
    local definition=assert(registry[blockType or 1],'Unknown block type')
    local meshPath=definition.variants and definition.variants[(variant or 0)+1]or definition.mesh
    local package,asset=meshPath:match('^(.*)%.([^%.]+)$')
    local object=StaticFindObject(meshPath)
    local method='found'
    if not valid(object) then
        local helpers=UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers')
        assert(valid(helpers),'Asset helpers absent')
        object=UE.GetAsset109(helpers,{PackageName=UE.FindOrAddFName(package),AssetName=UE.FindOrAddFName(asset)})
        method='reloaded'
    end
    assert(valid(object),'Owned block mesh unavailable '..definition.name)
    log('MESH_LOADED reason='..reason..' method='..method..' address='..tostring(object:GetAddress())..
        ' class='..object:GetClass():GetFullName()..' name='..object:GetFullName())
    return object
end
local pawnReadiness=UE.dofileJ(base..'/pawn_readiness.lua')
UE.possession65b=UE.dofileJ(base..'/possession.lua')
UE.coverRelease78=UE.dofileJ(base..'/cover_release78.lua')
function UE.noteDeath78()
    if UE.mountCamera102 then UE.mountCamera102:release('death',false)end
    if not session or not worldReady or restoring or transitioning then return end
    if UE.lastPossession65b then UE.lastPossession65b.alive=false;UE.lastPossession65b.deathSeen=true end
    if not UE.resumePawn78 then
        UE.resumePawn78=true;UE.sceneReady52=nil
        if UE.mount76 then UE.mount76:invalidate()end
        log('MC78_DEATH_SESSION_RETAINED epoch='..epoch..' chunks='..count(chunks))
    end
end
Timers.onEpoch('possession',function()UE.lastPossession65b=nil;UE.resumePawn78=nil;UE.resumingPawn78=nil end)
local function loadEnvironment()
    if quiesced or not(Startup.open or Startup.probing)then return nil end
    local instance=UE.GetGameInstance()
    if not valid(instance) or not UE.selectWorld65(instance) then return nil end
    local controller=UE.GetPlayerController()
    if not valid(controller) then return nil end
    local status,player,state=pawnReadiness(controller,valid)
    local world=controller:GetWorld()
    if not valid(world) then return nil end
    local address=world:GetAddress()
    if address~=UE.worldAddress61 then
        UE.worldAddress61=address;UE.worldIdentity61=world:GetFullName()..'@'..tostring(address)
        local level=world.PersistentLevel;UE.worldLevel78=valid(level)and level:GetAddress()or nil
    end
    if status=='alive'and worldReady and not transitioning and not UE.restartPending65b then
        local p=UE.lastPossession65b or{};UE.lastPossession65b=p
        p.epoch=epoch;p.world=address;p.level=UE.worldLevel78;p.controller=controller:GetAddress();p.player=player:GetAddress();p.riding=controller:IsRiding();p.alive=true
    elseif status=='dead'then UE.noteDeath78()end
    return {world=world,controller=controller,player=player,state=state,status=status,
        epoch=epoch,
        playerAddress=player and player:GetAddress()or nil,
        identity=UE.worldIdentity61}
end
local function environment(bootstrap)
    if UE.resumePawn78 and not UE.resumingPawn78 and not bootstrap then return nil end
    if not bootstrap and not Startup.open then return nil end
    if (transitioning or quiesced)and not bootstrap then return nil end

    if not bootstrap and UE.environmentFrame==Timers.frameCounter then
        return environmentCache and environmentCache.status=='alive'and valid(environmentCache.player)and environmentCache or nil
    end

    local env=loadEnvironment();UE.environmentFrame=Timers.frameCounter
    if not env or env.status~='alive'then environmentCache=nil;return nil end
    environmentCache=env;return env
end
local function gameplayInput(env)
    if UE.nativeInputG4 and UE.nativeInputG4.radialOpen then return false end
    if not env or env.controller.bShowMouseCursor or env.controller:IsMoveInputIgnored()or(phaseB and phaseB.open)or(UE.alexTrade and UE.alexTrade.open)or(UE.waystones83 and(UE.waystones83.open or UE.waystones83.busy))then return false end
    local parameter=env.player.CharacterParameterComponent
    if not valid(parameter)or parameter:GetIndividualParameter():IsDead()then return false end

    local builder=env.builder;if not valid(builder)then builder=env.player:GetComponentByClass(UE.Object('/Script/Pal.PalBuilderComponent'));env.builder=builder end
    if valid(builder)and builder:IsInBuildingMode()then UE.geometryRevisionL=(UE.geometryRevisionL or 0)+1;return false end
    return not UE.Object('/Script/Pal.Default__PalUIUtility'):IsToggleBuildMode(env.player)
end
local island
local function decode(text)
    if not text then return nil end
    local ok,doc=pcall(J.decode,text)
    if not ok or type(doc)~='table'or doc.world~=WORLD or not({[1]=true,[2]=true,[3]=true,[4]=true})[doc.version]then return nil end
    if type(doc.sequence)~='number'or doc.sequence<0 or type(doc.cells)~='table'or #doc.cells>20000 then return nil end
    local result={}
    for _,r in ipairs(doc.cells)do
        if type(r)~='table'then return nil end
        local x,y,z=r[1],r[2],r[3]
        for _,v in ipairs({x,y,z})do if type(v)~='number'or v%1~=0 or math.abs(v)>100000 then return nil end end
        local t=doc.version==1 and 1 or typeByName[r[5]];local variant=doc.version>=3 and(r[6]or 0)or 0
        if not registry[t]or type(variant)~='number'or variant%1~=0 or variant<0 or variant>=#(registry[t].variants or{registry[t].mesh})then return nil end
        local k=key(x,y,z);if result[k]then return nil end
        result[k]={x=x,y=y,z=z,debug=r[4]==1,type=t,variant=variant,support=r[7]~=''and r[7]or nil,open=r[8]==1,state=doc.version==4 and CellState.load(r,registry[t].name)or nil}
    end
    local storage=doc.version>=3 and doc.entities or{}
    if type(storage)~='table'then return nil end
    for k,e in pairs(storage)do
        local c=result[k];local kind=c and registry[c.type].kind
        if not c or type(e)~='table'or e.kind~=kind or(kind~='chest'and kind~='furnace')or type(e.slots)~='table'then return nil end
        if #e.slots~=(kind=='chest'and 27 or 3)then return nil end
        for _,slot in ipairs(e.slots)do
            if slot~=false and(type(slot)~='table'or type(slot.id)~='string'or not slot.id:match('^[%w_]+$')or type(slot.count)~='number'or slot.count%1~=0 or slot.count<1 or slot.count>999)then return nil end
        end
    end
    local nodes=ResourceState.validate(doc.resources)
    if not nodes then return nil end
    return result,doc.sequence,storage,tonumber(doc.clock)or 0,nodes
end
local function read(file)
    local f=io.open(file,'rb')
    if not f then return nil end
    local text=f:read('*a');f:close()
    assert(#text<3000000,'Sidecar exceeds size limit')
    return text
end
local function restoreData()
    local best,seq,bestEntities,bestClock,bestResources=nil,-1,nil,0,nil
    local any=false
    for _,suffix in ipairs({'','.tmp','.bak'}) do
        local text=read(path..suffix)
        if text then any=true end
        local data,n,e,c,r=decode(text)
        if data and n>seq then best,seq,bestEntities,bestClock,bestResources=data,n,e,c,r end
    end
    assert(best or not any,'Sidecar invalid; preserve files and repair before changes')
    cells,sequence=best or {},math.max(seq,0);UE.placementCount68=count(cells)
    entities,entityClock=bestEntities or{},bestClock or 0
    resourceState=bestResources or ResourceState.empty()
    if island and island.data.resourcesStatic then
        local removed=0
        for k,c in pairs(cells)do local id=c.state and c.state.resource
            if type(id)=='string'and(id:match('^island_tree_%d%d$')or id:match('^island_ore_%d%d$'))then assert(not entities[k]);cells[k]=nil;removed=removed+1 end
        end
        resourceState=ResourceState.empty();UE.retiredResource83=removed;UE.placementCount68=count(cells)
        log('MC83_RESOURCE_RETIRE cells='..removed..' metadata_only_before_restore=true')
    end
    log('RESTORE sequence='..sequence..' cells='..count(cells))
end
local mechanicsWriter
local function save()
    if mechanicsWriter then mechanicsWriter:cancel()end
    local rows={}
    for _,k in ipairs(sorted(cells))do local c=cells[k]
        rows[#rows+1]=CellState.row(c,registry[c.type or 1].name)
    end
    sequence=sequence+1
    local text=J.encode({version=4,world=WORLD,sequence=sequence,cells=rows,entities=entities,clock=entityClock,resources=resourceState or ResourceState.empty()})..'\n'
    local f=assert(io.open(path..'.tmp','wb'));assert(f:write(text));assert(f:flush());assert(f:close())
    assert(decode(assert(read(path..'.tmp'))),'Temporary sidecar validation failed')
    if read(path)then assert(os.remove(path))end;assert(os.rename(path..'.tmp',path))
    UE.placementCount68=#rows
    if UE.placementDirty68 and not inventoryTransaction then if read(pendingPath)then assert(os.remove(pendingPath))end;UE.placementDirty68=false end
    log('SAVE sequence='..sequence..' cells='..#rows..' entities='..count(entities))
end
local saveCommit
mechanicsWriter=UE.dofileJ(base..'/state_writer.lua')({json=J,state=CellState,cells=function()return cells end,
    name=function(c)return registry[c.type or 1].name end,
    metadata=function()return{entities=J.encode(entities),clock=entityClock,resources=J.encode(resourceState or ResourceState.empty())}end,
    cancelCommit=function()saveCommit=nil end,
    commitStep=function(parts,meta)
        if saveCommit then
            local s=saveCommit
            if s.stage==1 then local f=assert(io.open(s.temporary,'wb'));assert(f:write(s.text));assert(f:flush());assert(f:close());s.stage=2;return false end
            if s.stage==2 then assert(read(s.temporary)==s.text,'Autosave bytes did not settle');s.stage=3;return false end
            if s.stage==3 then if read(path)then assert(os.remove(path))end;assert(os.rename(s.temporary,path));sequence=s.sequence
                UE.placementCount68=#parts
                if UE.placementDirty68 and not inventoryTransaction then if read(pendingPath)then assert(os.remove(pendingPath))end;UE.placementDirty68=false end
                log('SAVE sequence='..sequence..' cells='..#parts..' entities='..count(entities)..' incremental=true');saveCommit=nil;return true end
        end
        local nextSequence=sequence+1
        local text='{"version":4,"world":'..J.encode(WORLD)..',"sequence":'..nextSequence..
            ',"cells":['..table.concat(parts,',')..'],"entities":'..meta.entities..',"clock":'..J.encode(meta.clock)..',"resources":'..meta.resources..'}\n'
        assert(#text<3000000,'Sidecar exceeds size limit')
        saveCommit={stage=1,text=text,temporary=path..'.mechanics.tmp',sequence=nextSequence};return false
    end})
do
    local originalSave,originalStep=save,mechanicsWriter.step
    save=function(...)return Timers.measure('save:full',originalSave,...)end
    mechanicsWriter.step=function(...)return Timers.measure('save:incremental',originalStep,...)end
end
local function chunkCoords(c)
    return math.floor(c.x/CHUNK),math.floor(c.y/CHUNK),math.floor(c.z/CHUNK)
end
local readyAfterRestore,steve
UE.restorePlanner109=UE.dofileJ(base..'/restore109.lua')
function UE.restoreReady109(p,radius)
    for k,pending in pairs(deferred)do local c=cells[k]
        if (pending==UE.restorePlanner109.pending or radius and pending)and c and UE.restorePlanner109.distance(c,p)<=(radius or UE.restorePlanner109.radius)^2 then return false end
    end
    return true
end
function UE.sceneRenderedM(e)
    local p=e.player:K2_GetActorLocation()
    local i=island and island:at(p)
    if i and valid(i.actor)then return i.actor:WasRecentlyRendered(.25)end
    local nearby=false
    for _,c in pairs(chunks)do

        local span=CHUNK*SIZE
        local dx=math.max(c.x*span-p.X,0,p.X-(c.x+1)*span)
        local dy=math.max(c.y*span-p.Y,0,p.Y-(c.y+1)*span)
        local dz=math.max(c.z*span-p.Z,0,p.Z-(c.z+1)*span)
        if dx*dx+dy*dy+dz*dz<=2500^2 then
            nearby=true
            if valid(c.actor)and c.actor:WasRecentlyRendered(.25)then return true end
        end
    end

    return not nearby
end
local meshCache={}
local chunkActors={}
local chunkReused={}
UE.chunkByAddress68={}
Timers.onEpoch('chunk-native-wrappers',function()
    
    chunks={};chunkActors={};chunkReused={};UE.chunkByAddress68={};meshCache={};worldReady=false
end)
local function chunkKey(c)
    local x,y,z=chunkCoords(c)
    return key(x,y,z)..'|'..(c.type or 1)..'|'..(c.variant or 0)
end
local function getChunk(c,env)
    assert(worldReady and not transitioning and not quiesced and env.epoch==epoch,'Chunk work before world readiness/current epoch')
    assert(valid(env.world),'Chunk world unavailable')
    local level=env.world.PersistentLevel
    assert(valid(level),'Chunk level unavailable/changed')
    local k=chunkKey(c);if chunks[k]then assert(chunks[k].epoch==epoch,'Stale chunk epoch');return chunks[k]end
    local x,y,z=chunkCoords(c);local location=transform(x*CHUNK*SIZE,y*CHUNK*SIZE,z*CHUNK*SIZE)
    local gameplay=UE.Object('/Script/Engine.Default__GameplayStatics')
    local spatial=key(x,y,z);local actor=chunkActors[spatial]
    if not valid(actor)then
        actor=gameplay:BeginDeferredActorSpawnFromClass(env.player,UE.Object('/Script/Engine.Actor'),location,1,nil)
        assert(valid(actor),'Chunk spawn failed');actor=gameplay:FinishSpawningActor(actor,location)
        actor.Tags={UE.FindOrAddFName('MCBlocksChunk')};chunkActors[spatial]=actor
    end
    local chunk={actor=actor,x=x,y=y,z=z,keys={},index={},epoch=epoch};chunks[k]=chunk
    local tag='MCChunk:'..k;local component

    if chunkReused[spatial]then
        for _,candidate in ipairs(FindAllOf('InstancedStaticMeshComponent')or{})do
            if valid(candidate)and candidate:GetOwner():GetAddress()==actor:GetAddress()then
                for _,componentTag in ipairs(candidate.ComponentTags)do if str(componentTag)==tag then component=candidate;break end end
                if component then UE.Native109(component,'ClearInstances');break end
            end
        end
    end
    if not component then component=actor:AddComponentByClass(UE.Object('/Script/Engine.InstancedStaticMeshComponent'),false,location,false);assert(valid(component));component.ComponentTags={UE.FindOrAddFName(tag)}end
    assert(valid(component),'ISM creation failed');chunk.component=component;UE.chunkByAddress68[component:GetAddress()]=chunk;component:SetMobility(2)
    local mk=(c.type or 1)..'|'..(c.variant or 0);local mesh=meshCache[mk]
    if not valid(mesh)then mesh=loadMesh('batch-assignment',c.type,c.variant);meshCache[mk]=mesh end
    if not component:SetStaticMesh(mesh)then
        local assigned=component.StaticMesh
        assert(valid(assigned)and assigned:GetAddress()==mesh:GetAddress(),'Chunk mesh assignment failed')
    end
    component:SetCollisionProfileName(UE.FindOrAddFName('BlockAll'),true);component:SetCollisionEnabled(3)
    if registry[c.type or 1].collision==false then component:SetCollisionEnabled(1);component:SetCollisionResponseToAllChannels(0);component:SetCollisionResponseToChannel(3,2)end
    if c.open then component:SetCollisionResponseToAllChannels(0);component:SetCollisionResponseToChannel(3,2)end
    return chunk
end
local function addBatch(group,env)
    if #group==0 then return end
    local chunk=getChunk(group[1],env);local transforms={};local first=chunk.component:GetInstanceCount()
    for _,c in ipairs(group)do
        assert(chunkKey(c)==chunkKey(group[1]),'Mixed ISM batch')
        transforms[#transforms+1]=transform(c.x*SIZE+50,c.y*SIZE+50,c.z*SIZE+50-(c.state and c.state.embed or 0))
    end
    UE.Native109(chunk.component,'AddInstances',transforms,false,true)
    assert(chunk.component:GetInstanceCount()==first+#group,'Batch instance count failed')
    for n,c in ipairs(group)do local k=key(c.x,c.y,c.z);local index=first+n-1
        chunk.keys[index]=k;chunk.index[k]=index;c.chunk=chunkKey(c)
    end
end
local function addVisual(c,env)
    UE.geometryRevisionL=(UE.geometryRevisionL or 0)+1
    local chunk=getChunk(c,env);local k=key(c.x,c.y,c.z)
    local index=UE.Native109(chunk.component,'AddInstance',transform(c.x*SIZE+50,c.y*SIZE+50,c.z*SIZE+50-(c.state and c.state.embed or 0)),true)
    assert(type(index)=='number'and index>=0,'Single instance add failed')
    chunk.keys[index]=k;chunk.index[k]=index;c.chunk=chunkKey(c)
end
local function batchVisual(planned,env)
    local groups={};for _,c in ipairs(planned)do local k=chunkKey(c);groups[k]=groups[k]or{};groups[k][#groups[k]+1]=c end
    for _,k in ipairs(sorted(groups))do addBatch(groups[k],env)end
end
local function rebuild(chunk)
    local group={};for _,k in ipairs(sorted(chunk.index))do if cells[k]then group[#group+1]=cells[k]end end
    UE.Native109(chunk.component,'ClearInstances');chunk.keys={};chunk.index={}
    if #group>0 then addBatch(group,assert(environment()))end
    assert(chunk.component:GetInstanceCount()==count(chunk.index),'Chunk index conservation failed')
end
local function removeMany(keys)
    local affected={}
    for _,k in ipairs(keys)do local c=assert(cells[k]);assert(c.debug,'Bulk removal is debug-only')
        assert(not entities[k],'Bulk removal excludes block entities')
        if deferred[k]then deferred[k]=nil else local chunk=assert(chunks[c.chunk]);chunk.index[k]=nil;affected[c.chunk]=chunk end
        cells[k]=nil
    end
    for _,chunk in pairs(affected)do rebuild(chunk)end
end
function UE.restoreCapsule109(env)
 local p=env.player:K2_GetActorLocation();local c=env.player.CapsuleComponent
 return{position={X=p.X,Y=p.Y,Z=p.Z},radius=c:GetScaledCapsuleRadius()+2,half=c:GetScaledCapsuleHalfHeight()+2}
end
do
 local rawChunk,rawBatch,rawMesh=getChunk,addBatch,loadMesh
 getChunk=function(...)return Timers.measure('restore:chunk',rawChunk,...)end
 addBatch=function(...)return Timers.measure('restore:addBatch',rawBatch,...)end
 loadMesh=function(...)return Timers.measure('restore:loadMesh',rawMesh,...)end
end
local function init(env)
    if session==env.identity then return not restoring end
    local restoreStarted=os.clock()
    assert(not read(pendingPath),'Unresolved inventory operation; inspect pending journal before changes')
    epoch=epoch+1;Timers.advanceEpoch(epoch,'world-entry');diagnostic=nil;cells={};sequence=0;session=env.identity
    worldReady=true
    log('MC_WORLD_EPOCH '..epoch..' world-entry')
    log('WORLD_READY '..WORLD..' identity='..session..' chunks=0 restore_pending=true native_refs='..Timers.nativeRefCount)
    log('WORLD_IDENTITY_LUA_RESET')
    restoring=true
    local identity=session;env=nil 
    local function restoreEntry()
    Timers.beginBudgetProfile()
    local env=assert(environment(),'Living player changed during startup delay')
    assert(env.identity==identity,'World changed during startup delay')
    local level=env.world.PersistentLevel;assert(valid(level),'World persistent level unavailable at chunk entry')
    env.level=level;env.levelAddress=level:GetAddress()
    UE.earlyGameplay51=true
    UE.loadingCover51:show(env);UE.entryHold51:begin(env)
    
    restoreData()
    local near={};local origin=env.player:K2_GetActorLocation();local earlyCapsule109=UE.restoreCapsule109(env)
    for _,c in pairs(cells)do
        if math.abs(c.x*SIZE+50-origin.X)<=150 and math.abs(c.y*SIZE+50-origin.Y)<=150 and c.z*SIZE<=origin.Z and origin.Z-c.z*SIZE<=400 and not intersectsPlayer(c,env,earlyCapsule109)then near[#near+1]=c end
    end
    table.sort(near,function(a,b)return a.z>b.z end)
    local early={};for i=1,math.min(16,#near)do early[#early+1]=near[i]end
    local earlyGroups={};for _,c in ipairs(early)do local k=chunkKey(c);earlyGroups[k]=earlyGroups[k]or{};earlyGroups[k][#earlyGroups[k]+1]=c end
    for _,g in pairs(earlyGroups)do addBatch(g,env)end
    local earlyKeys={};for _,c in ipairs(early)do earlyKeys[key(c.x,c.y,c.z)]=true end
    log('MC51_NEAR_COLLISION_READY cells='..#early..' elapsed_ms='..((os.clock()-restoreStarted)*1000))
    if UE.entryHold51 and #early>0 then UE.entryHold51:release(env,'support-collidable')end
    if island then island:start(env)end
    signature('/Script/Engine.InstancedStaticMeshComponent:AddInstances',{'InstanceTransforms','bShouldReturnIndices','bWorldSpace','ReturnValue'})
    local gameplay=UE.Object('/Script/Engine.Default__GameplayStatics')
    for _,tag in ipairs({'MCBlocksChunk','MCBlocksPreview'})do
        local leftovers={};gameplay:GetAllActorsWithTag(env.player,UE.FindOrAddFName(tag),leftovers)
        for _,parameter in ipairs(leftovers)do local actor=parameter:get()
            if valid(actor)and actor:GetWorld():GetAddress()==env.world:GetAddress()then
                if tag=='MCBlocksPreview'then actor:K2_DestroyActor()
                else local p=actor:K2_GetActorLocation();local spatial=key(math.floor(p.X/(CHUNK*SIZE)),math.floor(p.Y/(CHUNK*SIZE)),math.floor(p.Z/(CHUNK*SIZE)));chunkActors[spatial]=actor;chunkReused[spatial]=true end
            end
        end
    end
    deferred={};preview=nil;local groups={};local initialCapsule109=UE.restoreCapsule109(env)
    for _,k in ipairs(sorted(cells))do local c=cells[k]
        if earlyKeys[k]then elseif intersectsPlayer(c,env,initialCapsule109)then deferred[k]=true else local ck=chunkKey(c);groups[ck]=groups[ck]or{};groups[ck][#groups[ck]+1]=c;deferred[k]=UE.restorePlanner109.pending end
    end
    local p=env.player:K2_GetActorLocation()
    local anchors=UE.restorePlanner109.anchors(cells,entities,registry,island and island.all,beds and beds.spawn)
    local ordered,nearGroups=UE.restorePlanner109.order(groups,p,anchors);local visualStarted=os.clock();local admitted109=false
    local prepared109=#ordered+1;local cost109=3;local backgroundMax109,backgroundOver109=0,0
    log('MC109C_PRIORITY_ANCHORS count='..#anchors..' player_x='..p.X..' player_y='..p.Y)
    log('MC109_RESTORE_BEGIN cells='..count(cells)..' groups='..#ordered..' near_groups='..nearGroups..' radius_m='..(UE.restorePlanner109.radius/100))
    restoring=true;local nextGroup,nextCell,longest=1,1,0;local stamp=epoch;local ownedRestore;local entryPosition={X=p.X,Y=p.Y,Z=p.Z};local moved=false;local deadReady=false
    local function finishTimer()if restoreHandle==ownedRestore then restoreHandle=nil end end
    ownedRestore=Timers.loop(1,function()
        if transitioning or quiesced or stamp~=epoch then finishTimer();return true end
        local current=environment()
        if not current then
            local loading=loadEnvironment()
            if loading and loading.status=='dead'and not deadReady then
                deadReady=true;log('MC28_LOAD_DEFERRED state=dead during_restore=true native_death_ui_untouched=true')
                log('WORLD_READY '..WORLD..' cells='..count(cells)..' dead=true gameplay_deferred=true native_refs='..Timers.nativeRefCount)
            end
            return false
        end
        if current.identity~=env.identity then finishTimer();return true end
        current.level=env.level;current.levelAddress=env.levelAddress
        env=current
        if admitted109 and not UE.sceneReady52 then return false end
        local tick=os.clock();local budget=admitted109 and UE.restorePlanner109.budgetMs or 40;local ok,err=xpcall(function()
            if not admitted109 and nextGroup>nearGroups and prepared109<=#ordered then

                local prepared=0
                repeat
                    local row=ordered[prepared109];getChunk(row.group[1],env);prepared109=prepared109+1;prepared=prepared+1
                until prepared109>#ordered or prepared>=16 or(os.clock()-tick)*1000>=budget
                return
            end
            local position=env.player:K2_GetActorLocation();if(position.X-entryPosition.X)^2+(position.Y-entryPosition.Y)^2+(position.Z-entryPosition.Z)^2>100^2 then moved=true end

            local groupsDone=0;local batchCapsule109=UE.restoreCapsule109(env)
            repeat
            if nextGroup<=#ordered and(admitted109 or nextGroup<=nearGroups)then
                local row=ordered[nextGroup];local batch
                local limit=admitted109 and UE.restorePlanner109.limit(cost109,(os.clock()-tick)*1000)or 64
                if limit==0 then break end
                batch,nextCell=UE.restorePlanner109.batch(row,nextCell,limit,cells,deferred,key,chunkKey,function(c)return intersectsPlayer(c,env,batchCapsule109)end)
                local at=os.clock();addBatch(batch,env)
                if admitted109 and #batch>0 then cost109=UE.restorePlanner109.cost(cost109,(os.clock()-at)*1000,#batch)end
                if nextCell>#row.group then nextGroup=nextGroup+1;nextCell=1 end
            end
            groupsDone=groupsDone+1
            until nextGroup>#ordered or groupsDone>=(admitted109 and 1 or 16)or(os.clock()-tick)*1000>=budget or(not admitted109 and nextGroup>nearGroups)
        end,debug.traceback)
        local elapsed109=(os.clock()-tick)*1000
        longest=math.max(longest,elapsed109)
        if admitted109 then
            backgroundMax109=math.max(backgroundMax109,elapsed109)
            if elapsed109>UE.restorePlanner109.budgetMs then backgroundOver109=backgroundOver109+1 end
        end
        if not ok then finishTimer();disabled=true;restoring=false;log('AUTO_RESTORE_ERROR '..tostring(err));return true end
        if not admitted109 and nextGroup>nearGroups and prepared109>#ordered then
            admitted109=true;restoring=false
            log(string.format('MC109_NEAR_RESTORE_READY elapsed_ms=%.3f visual_ms=%.3f cells=%d ism=%d background_groups=%d',(os.clock()-restoreStarted)*1000,(os.clock()-visualStarted)*1000,count(cells),count(chunks),#ordered-nextGroup+1))
            local good,reason=xpcall(function()readyAfterRestore(env)end,debug.traceback)
            if not good then finishTimer();disabled=true;log('AUTO_RESTORE_ERROR '..tostring(reason));return true end
        end
        if nextGroup>#ordered then
            finishTimer();restoring=false
            log(string.format('MC_E_RESTORE total_ms=%.3f longest_tick_ms=%.3f cells=%d ism=%d adaptive=true max_batch=16 max_batches_per_tick=8 final_budget_ms=%d moved=%s',(os.clock()-restoreStarted)*1000,longest,count(cells),count(chunks),budget,tostring(moved)))
            log(string.format('MC109_BACKGROUND_RESTORE_DONE visual_ms=%.3f background_max_ms=%.3f budget_overruns=%d',(os.clock()-visualStarted)*1000,backgroundMax109,backgroundOver109))
            log('MC29_BLOCK_RESTORE_DONE cells='..count(cells)..' chunks='..count(chunks)..' deferred='..count(deferred)..' native_refs='..Timers.nativeRefCount)
            Timers.endBudgetProfile()
            return true
        end
        return false
    end,'block-restore')
    restoreHandle=ownedRestore
    end
    Startup:world(epoch,startupJobs,function()
        local expected=epoch
        Timers.loop(33,function()
            if expected~=epoch or transitioning or quiesced then return true end
            if not phaseA.uiEntry.ready then return false end
            restoreEntry();return true
        end,'restore-after-preload')
    end)
    return false
end
local function active()
    assert(not disabled,'Mod stopped after an error; inspect log before restarting')
    local env=assert(environment(),'No admitted living local player')
    assert(not restoring,'Restore still in progress');init(env);return env
end
local function trace(env,quiet,previewOnly)
    local camera=env.controller.PlayerCameraManager
    assert(valid(camera),'Camera unavailable')
    local start=camera:GetCameraLocation()
    local rot=camera:GetCameraRotation()
    local cached=UE.previewTraceL
    if previewOnly and cached and cached.epoch==epoch and cached.revision==UE.geometryRevisionL and os.clock()<cached.untilAt
     and cached.x==start.X and cached.y==start.Y and cached.z==start.Z and cached.pitch==rot.Pitch and cached.yaw==rot.Yaw then return cached.hit end
    local pitch,yaw=math.rad(rot.Pitch),math.rad(rot.Yaw)
    local finish=vector(start.X+600*math.cos(pitch)*math.cos(yaw),
        start.Y+600*math.cos(pitch)*math.sin(yaw),start.Z+600*math.sin(pitch))
    local hit={};local color={R=0,G=0,B=0,A=0}
    local system=UE.GetKismetSystemLibrary()
    if not quiet then log('PHASE TRACE_BEGIN') end

    local ignored={env.player};local found=false
    for _=1,16 do
        hit={}
        found=_G.MC_OUT_K('LineTraceSingle',system,env.player,start,finish,0,false,ignored,0,hit,true,color,color,0)
        if not found then break end
        local actor
        local component=hit.Component:Get()
        actor=valid(component) and component:GetOwner() or nil
        if not valid(actor) or not actor:GetClass():GetFullName():find('BP_MapObject_CommonDropItem3D',1,true) then break end
        ignored[#ignored+1]=actor
        if not quiet then log('TRACE_IGNORE_NATIVE_DROP '..actor:GetFullName()) end
    end
    if not quiet then log('PHASE TRACE_END found='..tostring(found)) end
    if previewOnly then UE.previewTraceL={epoch=epoch,revision=UE.geometryRevisionL,untilAt=os.clock()+5,x=start.X,y=start.Y,z=start.Z,pitch=rot.Pitch,yaw=rot.Yaw,hit=found and hit or nil}end
    if not found then if not quiet then log('TRACE_MISS') end;return nil end
    if not quiet then log('TRACE_HIT item='..tostring(hit.Item)) end
    return hit
end
local function hitChunk(hit)
    local component=hit.Component:Get()
    if not valid(component) then return nil end
    return UE.chunkByAddress68[component:GetAddress()]
end
local function normalAxis(n)
    local a,b,c=math.abs(n.X),math.abs(n.Y),math.abs(n.Z)
    if a>=b and a>=c then return n.X>=0 and 1 or -1,0,0 end
    if b>=c then return 0,n.Y>=0 and 1 or -1,0 end
    return 0,0,n.Z>=0 and 1 or -1
end
intersectsPlayer=function(c,env,snapshot)
    local p=snapshot and snapshot.position or env.player:K2_GetActorLocation()
    local capsule=not snapshot and env.player.CapsuleComponent
    local radius=snapshot and snapshot.radius or capsule:GetScaledCapsuleRadius()+2
    local half=snapshot and snapshot.half or capsule:GetScaledCapsuleHalfHeight()+2
    
    local dx=math.max(math.abs(p.X-(c.x*SIZE+50))-50,0)
    local dy=math.max(math.abs(p.Y-(c.y*SIZE+50))-50,0)
    local dz=math.max(math.abs(p.Z-(c.z*SIZE+50))-(half-radius)-50,0)
    return dx*dx+dy*dy+dz*dz<radius*radius
end
targetCell=function(env,quiet)
    local hit=trace(env,quiet);if not hit then return nil end
    local chunk=hitChunk(hit);local c
    if chunk then
        local old=cells[chunk.keys[hit.Item]];if not old then return nil end
        local x,y,z=normalAxis(hit.ImpactNormal)
        c={x=old.x+x,y=old.y+y,z=old.z+z,debug=false}
    else
        local p,n=hit.ImpactPoint,hit.ImpactNormal
        c={x=math.floor((p.X+n.X*50)/SIZE),y=math.floor((p.Y+n.Y*50)/SIZE),
           z=math.floor((p.Z+n.Z*50)/SIZE),debug=false}
    end
    c.type=selectedType
    if phaseC then c=phaseC:placement(env,hit,c)end
    return c
end
local function makePreview(env)
    local gameplay=UE.Object('/Script/Engine.Default__GameplayStatics')
    local t=transform(0,0,0)
    local actor=gameplay:BeginDeferredActorSpawnFromClass(env.player,UE.Object('/Script/Engine.Actor'),t,1,nil)
    assert(valid(actor),'Preview actor failed');actor=gameplay:FinishSpawningActor(actor,t)
    actor.Tags={UE.FindOrAddFName('MCBlocksPreview')}
    local component=actor:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,t,false)
    assert(valid(component),'Preview component failed')
    component:SetMobility(2);component:SetCollisionEnabled(0)
    assert(component:SetStaticMesh(loadMesh('preview',1)))
    local material=StaticFindObject('/Game/MinecraftSelection68/M_Selection.M_Selection')
    if not valid(material) then
        local helpers=UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers')
        material=UE.GetAsset109(helpers,{PackageName=UE.FindOrAddFName('/Game/MinecraftSelection68/M_Selection'),AssetName=UE.FindOrAddFName('M_Selection')})
    end
    assert(valid(material),'Preview material absent');component:SetMaterial(0,material)
    actor:SetActorHiddenInGame(true)
    preview={actor=actor,component=component,last=nil}
    log('PREVIEW_READY collision=0 interval_ms=100')
end
stopLiveTimer=function(reason)
    if liveHandle then Timers.cancel(liveHandle);liveHandle=nil end
    log('LIVE_TIMER_STOP '..reason)
end
startLiveTimer=function(env)
    if quiesced or liveHandle then return end
    local stamp,identity,playerAddress=epoch,env.identity,env.player:GetAddress()
    local ticks=0
    if previewEnabled and (not preview or not valid(preview.actor)) then makePreview(env) end
    local ownedHandle
    local function stop()
        if liveHandle==ownedHandle then liveHandle=nil end
        return true
    end
    ownedHandle=Timers.loop(100,function()
        
        if quiesced or stamp~=epoch then return stop() end
        local ok,done=xpcall(function()
            assert(IsInGameThread(),'Preview outside game thread')
            if disabled then return true end
            local current=environment()
            if not current or current.identity~=identity or current.player:GetAddress()~=playerAddress then return true end
            ticks=ticks+1

            for _,k in ipairs(sorted(deferred)) do
                local c=cells[k]
                if not c then deferred[k]=nil
                elseif deferred[k]~=UE.restorePlanner109.pending and not intersectsPlayer(c,current) then
                    addVisual(c,current);deferred[k]=nil;log('RESTORE_DEFERRED_READY '..k)
                end
            end
            if preview and valid(preview.actor) then
                local hit=previewEnabled and gameplayInput(current)and trace(current,true,true);local ch=hit and hitChunk(hit);local c=ch and cells[ch.keys[hit.Item]]
                local show=type(c)=='table'
                if show then
                    
                    if not preview.meshKey then preview.component:SetRelativeScale3D(vector(1.003,1.003,1.003));preview.meshKey=true end
                    if preview.last~=key(c.x,c.y,c.z)then local hit={};_G.MC_OUT_K('K2_SetActorLocation',preview.actor,vector(c.x*SIZE+50,c.y*SIZE+50,c.z*SIZE+50),false,hit,true)end
                    preview.last=key(c.x,c.y,c.z)
                else preview.last=nil end
                preview.actor:SetActorHiddenInGame(not show)
            end
            return false 
        end,debug.traceback)
        if not ok then log('LIVE_TIMER_ERROR '..tostring(done));disabled=true;done=true end
        if done then log('LIVE_TIMER_END ticks='..ticks);return stop() end
        return false
    end)
    liveHandle=ownedHandle
end

local function beginInventoryChange(action,c,env,before,quantity)
    assert(not inventoryTransaction and(not read(pendingPath)or UE.placementDirty68),'Inventory operation already pending')
    assert(type(Timers.loop)=='function' and type(IsInGameThread)=='function'
        and IsInGameThread(),'Inventory settlement must run on the game thread')
    local w={action=action,cell=c,key=key(c.x,c.y,c.z),before=before,epoch=epoch,
        delta=action=='PLACE' and -1 or (action=='DROP' and 0 or(quantity or 1)),identity=env.identity,blockType=c.type or selectedType,
        playerAddress=env.player:GetAddress(),ticks=0}
    local f=assert(io.open(pendingPath,'wb'))
    assert(f:write(string.format('{"version":1,"world":"%s","action":"%s","cell":[%d,%d,%d],"before":%d,"sequence":%d}\n',
        WORLD,action,c.x,c.y,c.z,before,sequence)))
    assert(f:flush());assert(f:close());inventoryTransaction=w
    return w
end
local function rollbackVisual(w,env)
    if w.action=='PLACE' then remove(w.key);if w.replaced then addVisual(w.replaced,env);cells[w.key]=w.replaced end
    else addVisual(w.cell,env);cells[w.key]=w.cell end
end
local function finishInventoryChange(w,env,after)
    assert(after==w.before+w.delta,'Native inventory changed by an unexpected amount')
    if w.action=='PLACE'then UE.placementDirty68=true;inventoryTransaction=nil
    else save();assert(os.remove(pendingPath));UE.placementDirty68=false;inventoryTransaction=nil end
    log(w.action..' '..w.key..' type='..registry[w.blockType].name..' item_before='..w.before..' item_after='..after..' settlement_ticks='..w.ticks..' PASS')
    if mechanics then mechanics:changed(w.action=='PLACE'and w.replaced or w.cell,cells[w.key])end
    if phaseC then phaseC:changed(w.cell,env);if w.action~='PLACE'then phaseC:dropUnsupported(env)end end
    if w.action=='PLACE'then mechanics.dirty=true;mechanics.saveAt=os.clock()+.8 else save()end
    if updateHotbar then updateHotbar(env) end
end
local function settleInventoryChange(w,env,inventory,item)
    local after=inventory:CountItemNum(item)
    if after==w.before+w.delta then finishInventoryChange(w,env,after);return end
    if after~=w.before then
        rollbackVisual(w,env);error('Unexpected immediate native item delta; visual rolled back, journal retained')
    end

    log('INVENTORY_PENDING '..w.action..' before='..w.before)
    w.handle=Timers.loop(50,function()
        if quiesced or (w.epoch and w.epoch~=epoch) then return true end
        local ok,done=xpcall(function()
            assert(IsInGameThread(),'Inventory tick outside game thread')
            local current=environment()
            assert(current and current.identity==w.identity and current.player:GetAddress()==w.playerAddress,
                'World/player changed during inventory operation; preserve journal')
            local inv,id=nativeDirtInventory(current,w.blockType);local n=inv:CountItemNum(id)
            w.ticks=w.ticks+1
            if n==w.before+w.delta then finishInventoryChange(w,current,n);return true end
            if n~=w.before then
                rollbackVisual(w,current);error('Unexpected native item delta; visual rolled back, journal retained')
            end
            if w.ticks>=40 then
                rollbackVisual(w,current)
                error('Native operation timed out; visual rolled back, journal retained for delayed-result review')
            end
            return false
        end,debug.traceback)
        if not ok then disabled=true;log('STOP_ERROR '..tostring(done));return true end
        return done
    end)
end
local function place()
    if not inventoryTransactionsReady then active();log('PLACE_REJECT inventory_setup_pending');return end
    log('PHASE PLACE_BEGIN')
    local env=active();local inventory,item=nativeDirtInventory(env)
    local before=inventory:CountItemNum(item)
    if before<1 then log('PLACE_REJECT no_item dirt_count='..before);return end
    local c=targetCell(env,false);if not c then return end
    return placeCell(c,env)
end
placeCell=function(c,env)
    c.type=c.type or selectedType
    if beds and registry[c.type].kind=='bed'then return beds:place(c,env)end
    local inventory,item=nativeDirtInventory(env,c.type)
    local before=inventory:CountItemNum(item)
    if before<1 then log('PLACE_REJECT no_item type='..registry[c.type].name);return false end
    local k=key(c.x,c.y,c.z)
    if mechanics then if not mechanics:canPlace(c)then log('PLACE_REJECT mechanics_ground');return false end;mechanics:initialize(c)end
    if phaseC and not phaseC:canPlace(c,env)then return false end
    local replaced=cells[k]
    if replaced and not c.merge then log('PLACE_REJECT occupied '..k);return end
    if intersectsPlayer(c,env) then log('PLACE_REJECT player '..k);return end
    assert(UE.placementCount68<20000,'Prototype cell limit reached')
    
    local network,request,slotInfo=nativeDirtRemoval(env,inventory,item)
    local w=beginInventoryChange('PLACE',c,env,before);w.replaced=replaced
    if replaced then remove(k)end
    c.merge=nil;addVisual(c,env);cells[k]=c
    if not replaced then UE.placementCount68=UE.placementCount68+1 end
    if mechanicsWriter then mechanicsWriter:cancel()end
    
    w.handle=Timers.after(1,function()
        if w.epoch~=epoch or quiesced or transitioning then return end
        local current=environment();assert(current and current.identity==w.identity,'Placement owner changed')
        local inv,id=nativeDirtInventory(current,w.blockType);local net,req,slot=nativeDirtRemoval(current,inv,id)
        net:RequestDispose_ToServer(req,slot);settleInventoryChange(w,current,inv,id)
    end,'placement-inventory68')
    return cells[k]~=nil
end
remove=function(k)
    UE.geometryRevisionL=(UE.geometryRevisionL or 0)+1
    local c=assert(cells[k])
    if phaseC and not phaseC:beforeBreak(k,environment())then return false end
    if deferred[k] then deferred[k]=nil;cells[k]=nil;if phaseC then phaseC.connected:neighbors(c)end;return end
    local chunk=assert(chunks[c.chunk])
    assert(chunk.index[k]~=nil,'Removed cell not indexed')
    cells[k]=nil;chunk.index[k]=nil;rebuild(chunk);if mechanics then mechanics:changed(c,nil)end;if phaseC then phaseC.connected:neighbors(c)end;return true
end
local function smoke()
    local env=active();local p=env.player:K2_GetActorLocation()
    local yaw=math.rad(env.controller.PlayerCameraManager:GetCameraRotation().Yaw)
    local c={x=math.floor((p.X+300*math.cos(yaw))/SIZE),
        y=math.floor((p.Y+300*math.sin(yaw))/SIZE),
        z=math.ceil((p.Z-env.player.CapsuleComponent:GetScaledCapsuleHalfHeight())/SIZE),debug=true}
    local k=key(c.x,c.y,c.z)
    assert(not cells[k],'Smoke cell already occupied')
    assert(not intersectsPlayer(c,env),'Smoke overlaps player')
    addVisual(c,env);cells[k]=c;save()
    log('SMOKE_PLACED '..k..' (debug-only; no inventory refund)')
end
local function breakBlock()
    if not inventoryTransactionsReady then active();log('BREAK_REJECT inventory_setup_pending');return end
    local env=active();local hit=trace(env);if not hit then return end
    local chunk=hitChunk(hit)
    if not chunk then log('BREAK_REJECT native target');return end
    local k=assert(chunk.keys[hit.Item],'Hit instance not mapped')
    local c=assert(cells[k])
    if beds and registry[c.type].kind=='bed'then return beds:remove(k,env)end
    if c.debug then remove(k);save();log('DEBUG_BREAK '..k..' no_inventory_refund');return end
    return returnCell(k,env)
end
returnCell=function(k,env)
    if beds and cells[k]and registry[cells[k].type].kind=='bed'then return beds:remove(k,env)end
    if mechanics and not directReturns then local result=mechanics:harvest(k,env,'mine');if result~=nil then return result end end
    local c=assert(cells[k])
    if phaseC and not phaseC:beforeBreak(k,env)then return false end
    local quantity=registry[c.type].kind=='slab'and c.variant==2 and 2 or 1
    local inventory,item=nativeDirtInventory(env,c.type);local before=inventory:CountItemNum(item)
    if not phaseC:capacity(env,registry[c.type].item,quantity)then log('MC66_MINE_FULL kept='..k);return false end
    local w=beginInventoryChange('BREAK',c,env,before,quantity)
    remove(k)
    local result=inventory:AddItem_ServerInternal(item,quantity,false,0.0,true)
    local after=inventory:CountItemNum(item)
    log('DIRT_NATIVE_RETURN requested=1 result='..tostring(result)..' before='..before..' after='..after)
    if result~=0 and after==before then
        rollbackVisual(w,env);assert(os.remove(pendingPath));inventoryTransaction=nil
        log('BREAK_REJECT native_add_failed block_kept '..k..' result='..tostring(result));return
    end
    log('MC66_BLOCK_DIRECT id='..registry[c.type].item..' before='..before..' after='..after..' count='..quantity)
    settleInventoryChange(w,env,inventory,item)
    return not inventoryTransaction and cells[k]==nil
end
local function fill()
    local env=active();local p=env.player:K2_GetActorLocation()
    local x,y,z=math.floor(p.X/SIZE)+6,math.floor(p.Y/SIZE)-5,math.floor((p.Z-100)/SIZE)
    local added=0
    for i=0,9 do for j=0,9 do for h=0,9 do
        local c={x=x+i,y=y+j,z=z+h,debug=true};local k=key(c.x,c.y,c.z)
        if not cells[k] and not intersectsPlayer(c,env) then addVisual(c,env);cells[k]=c;added=added+1 end
    end end end
    save();log('DEBUG_FILL added='..added..' cells='..count(cells)..' chunks='..count(chunks))
end
local function clearDebug()
    active();local affected={};local removed=0
    for k,c in pairs(cells) do if c.debug then
        local chunk=c.chunk and chunks[c.chunk]
        if chunk then chunk.index[k]=nil;affected[c.chunk]=true end
        deferred[k]=nil;cells[k]=nil;removed=removed+1
    end end
    for k in pairs(affected) do rebuild(chunks[k]) end
    save();log('DEBUG_CLEAR removed='..removed..' cells='..count(cells))
end
local function status()
    local env=active();local p=env.player:K2_GetActorLocation()
    local camera=env.controller.PlayerCameraManager
    local rotation=camera:GetCameraRotation()
    log(string.format('STATUS cells=%d chunks=%d pos=%.1f,%.1f,%.1f yaw=%.1f pitch=%.1f',
        count(cells),count(chunks),p.X,p.Y,p.Z,rotation.Yaw,rotation.Pitch))
    for k,chunk in pairs(chunks) do
        assert(chunk.component:GetInstanceCount()==count(chunk.index),'Index count mismatch')
        for i,cell in pairs(chunk.keys) do assert(chunk.index[cell]==i and cells[cell],'Index mapping mismatch') end
    end
    log('CELL_KEYS '..table.concat(sorted(cells),'|'))
    local inventory,item=nativeDirtInventory(env);log('DIRT_NATIVE_COUNT '..inventory:CountItemNum(item))
    local hit=trace(env)
    if hit then
        local h=hit.ImpactPoint
        log(string.format('TRACE item=%s position=%.1f,%.1f,%.1f',tostring(hit.Item),h.X,h.Y,h.Z))
    end
end
local function cameraInput(pitch,yaw)
    local env=active()
    local r=env.controller:GetControlRotation()
    local signed=(r.Pitch+180)%360-180
    env.controller:SetControlRotation({Pitch=math.max(-80,math.min(80,signed+pitch)),Yaw=r.Yaw+yaw,Roll=0})
    log('DEBUG_CAMERA pitch_delta='..pitch..' yaw_delta='..yaw)
end

local function requireProperty(className,propertyName,kind)
    local class=StaticFindObject(className);assert(valid(class),'Missing class '..className)
    local found
    class:ForEachProperty(function(p)
        local name=p:GetFullName()
        if name:match('([^:]+)$')==propertyName then found=name end
    end)
    assert(found and found:match('^'..kind..' '),'Property changed '..className..':'..propertyName..' actual='..tostring(found))
    log('PROPERTY_OK '..found)
end
local function sameObject(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function diagnosticAvailable()
    if diagnostic then log('DIAGNOSTIC_REJECT already running');return false end
    return true
end
local function runDiagnostic(label,limit,env,watch,tick,finish)
    assert(type(Timers.loop)=='function' and type(Timers.cancel)=='function'
        and type(IsInGameThread)=='function' and IsInGameThread(),'Game-thread diagnostic API unavailable')
    watch.label=label;watch.epoch=epoch;watch.player=env.player
    watch.address=env.player:GetAddress();watch.ticks=0;watch.cancelled=false;watch.stopped=false
    diagnostic=watch
    local function stop(reason,touch)
        if watch.stopped then return true end
        watch.stopped=true
        if diagnostic==watch then diagnostic=nil end
        local cancelled=false 
        if touch then
            local ok,failure=xpcall(function()
                if watch.jumping then watch.player:StopJumping();watch.jumping=false end
                if finish then finish(watch,reason) end
            end,debug.traceback)
            if not ok then log('DIAGNOSTIC_FINISH_ERROR '..label..' '..failure) end
        end
        log('DIAGNOSTIC_END '..label..' ticks='..watch.ticks..' reason='..reason..' cancelled='..tostring(cancelled))
        return true
    end
    watch.handle=Timers.loop(50,function()
        
        if quiesced or watch.epoch~=epoch then return stop('MAP_CHANGED',false) end
        if watch.stopped then return true end
        local ok,result=xpcall(function()
            assert(IsInGameThread(),'Diagnostic tick outside game thread')
            if not valid(watch.player) or watch.player:GetAddress()~=watch.address then
                return stop('PLAYER_CHANGED',false)
            end
            if watch.cancelled then return stop('CANCELLED',true) end
            watch.ticks=watch.ticks+1
            local done=tick(watch)
            if done or watch.ticks>=limit then return stop('COMPLETE',true) end
            return false
        end,debug.traceback)
        if not ok then
            log('DIAGNOSTIC_ERROR '..label..' '..result)
            
            local canTouch=watch.epoch==epoch and valid(watch.player) and watch.player:GetAddress()==watch.address
            return stop('ERROR',canTouch)
        end
        return result
    end)
    log('DIAGNOSTIC_BEGIN '..label..' limit='..limit..' delay_ms=50')
end
local faces={['+X']=vector(1,0,0),['-X']=vector(-1,0,0),['+Y']=vector(0,1,0),
    ['-Y']=vector(0,-1,0),['+Z']=vector(0,0,1),['-Z']=vector(0,0,-1)}
local viewIndex,selectedView,woodGranted=0,nil,false
local function walkCheck()
    if not diagnosticAvailable() then return end
    local env=active();assert(not env.controller:IsMoveInputIgnored(),'Close native menus before walking')
    local direction
    if selectedView then direction=faces[selectedView.walk] else
        local yaw=math.rad(env.controller:GetControlRotation().Yaw)
        direction=vector(math.cos(yaw),math.sin(yaw),0)
    end
    local p=env.player:K2_GetActorLocation()
    log(string.format('FREE_WALK_DIRECTION %.0f,%.0f,%.0f',direction.X,direction.Y,direction.Z))
    runDiagnostic('FREE_WALK',60,env,{start=vector(p.X,p.Y,p.Z)},function(w)
        w.player:AddMovementInput(direction,1.0,false)
    end,function(w,reason)
        local q=w.player:K2_GetActorLocation()
        log(string.format('FREE_WALK %s moved_cm=%.3f position=%.3f,%.3f,%.3f',reason,
            math.sqrt((q.X-w.start.X)^2+(q.Y-w.start.Y)^2),q.X,q.Y,q.Z))
    end)
end

local function viewConfig()
    local f=assert(io.open(base..'/views.txt','rb'),'No view preset file')
    local text=f:read(16385);f:close();assert(#text<=16384,'View file too large')
    text=text:gsub('\r\n','\n');local header,body=text:match('^([^\n]+)\n(.*)$')
    assert(header=='views-v1|'..WORLD,'View world/header mismatch')
    local result,seen={},{}
    local function xyz(s,bound,integer)
        local x,y,z=s:match('^([+-]?%d+%.?%d*),([+-]?%d+%.?%d*),([+-]?%d+%.?%d*)$')
        x,y,z=tonumber(x),tonumber(y),tonumber(z)
        assert(x and y and z and math.max(math.abs(x),math.abs(y),math.abs(z))<=bound,'View coordinate bounds')
        if integer then assert(x%1==0 and y%1==0 and z%1==0,'View cell must be integral') end
        return vector(x,y,z)
    end
    for row in body:gmatch('[^\n]+') do
        local name,anchor,standing,face,target,walk=row:match('^([%w_-]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$')
        assert(name and #name<=48 and not seen[name],'Invalid/duplicate view name')
        assert(faces[face] or face=='terrain','Unknown view face')
        assert(walk=='+X' or walk=='-X' or walk=='+Y' or walk=='-Y','Unknown walk axis')
        result[#result+1]={name=name,anchor=xyz(anchor,100000,true),standing=xyz(standing,20,false),
            face=face,target=xyz(target,20,face~='terrain'),walk=walk}
        seen[name]=true;assert(#result<=32,'Too many views')
    end
    assert(#result>0,'Empty view file');return result
end
local function presetPosition(v,half)
    return vector((v.anchor.X+v.standing.X)*SIZE+50,(v.anchor.Y+v.standing.Y)*SIZE+50,
        (v.anchor.Z+v.standing.Z+1)*SIZE+half+5)
end
local function presetTarget(v)
    local n=faces[v.face] or vector(0,0,0)
    local p=vector((v.anchor.X+v.target.X)*SIZE+50+n.X*50,
        (v.anchor.Y+v.target.Y)*SIZE+50+n.Y*50,(v.anchor.Z+v.target.Z)*SIZE+50+n.Z*50)
    return phaseC and phaseC:viewPoint(v,p)or p
end
local function capsuleClear(p,env)
    local r=env.player.CapsuleComponent:GetScaledCapsuleRadius()+2
    local h=env.player.CapsuleComponent:GetScaledCapsuleHalfHeight()+2
    for _,c in pairs(cells) do
        local dx=math.max(math.abs(p.X-(c.x*SIZE+50))-50,0)
        local dy=math.max(math.abs(p.Y-(c.y*SIZE+50))-50,0)
        assert(dx*dx+dy*dy>=r*r or math.abs(p.Z-(c.z*SIZE+50))>=h+50,'View capsule intersects '..key(c.x,c.y,c.z))
    end
end
local function aimPreset(env,v)
    local p=env.controller.PlayerCameraManager:GetCameraLocation();local t=presetTarget(v)
    local x,y,z=t.X-p.X,t.Y-p.Y,t.Z-p.Z
    local pitch=math.deg(math.atan(z,math.sqrt(x*x+y*y)))
    assert(math.abs(pitch)<=80,'View pitch exceeds native diagnostic limit')
    env.controller:SetControlRotation({Pitch=pitch,Yaw=math.deg(math.atan(y,x)),Roll=0})
end
local function reportPreset(env,v)
    local camera=env.controller.PlayerCameraManager;local p,r=camera:GetCameraLocation(),camera:GetCameraRotation()
    local hit=trace(env);local matched=false;local info='miss'
    if hit then
        local c=hitChunk(hit);local n,h=hit.ImpactNormal,hit.ImpactPoint
        if v.face=='terrain' then
            local t=presetTarget(v)
            matched=not c and (h.X-t.X)^2+(h.Y-t.Y)^2+(h.Z-t.Z)^2<=225
        else
            local wanted=key(v.anchor.X+v.target.X,v.anchor.Y+v.target.Y,v.anchor.Z+v.target.Z)
            local axis=faces[v.face]
            matched=c and c.keys[hit.Item]==wanted and n.X*axis.X+n.Y*axis.Y+n.Z*axis.Z>=0.9 or false
        end
        local component=hit.Component:Get()
        info=string.format('component=%s item=%s cell=%s impact=%.3f,%.3f,%.3f normal=%.3f,%.3f,%.3f',
            valid(component) and component:GetFullName() or 'none',tostring(hit.Item),c and tostring(c.keys[hit.Item]) or 'native',
            h.X,h.Y,h.Z,n.X,n.Y,n.Z)
    end
    log(string.format('VIEW_READY name=%s matched=%s face=%s camera=%.3f,%.3f,%.3f yaw=%.3f pitch=%.3f %s',
        v.name,tostring(matched),v.face,p.X,p.Y,p.Z,r.Yaw,r.Pitch,info))
end
local function applyView(delta)
    if not diagnosticAvailable() then return end
    local ok,views=pcall(viewConfig)
    if not ok then log('VIEW_CONFIG_REJECT '..tostring(views));return end
    local env=active();assert(not env.controller:IsMoveInputIgnored(),'Close menus before applying a view')
    viewIndex=(viewIndex+delta-1)%#views+1;local v=views[viewIndex];selectedView=v
    local movement=env.player.CharacterMovement
    local p=presetPosition(v,env.player.CapsuleComponent:GetScaledCapsuleHalfHeight());capsuleClear(p,env)
    local watch={stage='drop',env=env,view=v,position=p,stable=0}
    if movement.MovementMode==6 or movement.MovementMode==5 then
        movement:SetMovementMode(3,0);log('VIEW_RELEASE_CUSTOM_MODE native SetMovementMode Falling')
    end
    runDiagnostic('TEST_VIEW',40,env,watch,function(w)
        local mode=w.player.CharacterMovement.MovementMode
        if w.stage=='drop' then
            if mode==6 then assert(w.ticks<10,'View could not release custom movement');return end
            local hit={};w.player:K2_SetActorLocation(w.position,false,hit,true)
            log('VIEW_SETUP_TELEPORT '..w.view.name);w.stage='settle';return
        end
        if w.stage=='settle' then
            local z=w.player:K2_GetActorLocation().Z
            w.stable=mode==1 and w.lastZ and math.abs(z-w.lastZ)<=1 and w.stable+1 or 0;w.lastZ=z
            if w.stable>=2 then aimPreset(w.env,w.view);w.stage='aim';w.at=w.ticks end
        elseif w.stage=='aim' then

            aimPreset(w.env,w.view)
            if w.ticks-w.at>=20 then w.stage='report';w.at=w.ticks end
        elseif w.stage=='report' and w.ticks-w.at>=2 then
            reportPreset(w.env,w.view);w.ready=true;return true
        end
    end,function(w,reason)
        if not w.ready then log('VIEW_NOT_READY '..w.view.name..' reason='..reason..' stage='..w.stage) end
    end)
end
local function woodFixture()
    local env=active();if woodGranted then log('NATIVE_FIXTURE_REJECT already_granted');return end
    local inventory=env.controller:GetPalPlayerState():GetInventoryData()
    assert(valid(inventory),'Native inventory absent');woodGranted=true
    for _,name in ipairs({'Wood','Stone'}) do
        local item=UE.FindOrAddFName(name);local before=inventory:CountItemNum(item)
        inventory:AddItem_ServerInternal(item,2,false,0.0,true)
        local after=inventory:CountItemNum(item)
        log('NATIVE_FIXTURE '..name..' before='..before..' after='..after..' '..(after==before+2 and 'PASS' or 'FAIL'))
    end
end
nativeDirtInventory=function(env,blockType)
    signature('/Script/Pal.PalPlayerController:GetPalPlayerState',{'ReturnValue'})
    signature('/Script/Pal.PalPlayerState:GetInventoryData',{'ReturnValue'})
    signature('/Script/Pal.PalPlayerInventoryData:AddItem_ServerInternal',{'StaticItemId','Count','IsAssignPassive','LogDelay','bNotifyLog','ReturnValue'})
    signature('/Script/Pal.PalPlayerInventoryData:CountItemNum',{'StaticItemId','ReturnValue'})
    local state=env.controller:GetPalPlayerState();assert(valid(state),'Native state absent')
    local inventory=state:GetInventoryData();assert(valid(inventory),'Native inventory absent')
    return inventory,UE.FindOrAddFName(assert(registry[blockType or selectedType]).item)
end
nativeDirtRemoval=function(env,inventory,item)
    signature('/Script/Pal.PalUtility:GetNetworkTransmitterByPlayerCharacter',{'Player','ReturnValue'})
    signature('/Script/Pal.PalNetworkTransmitter:GetItem',{'ReturnValue'})
    signature('/Script/Pal.PalNetworkItemComponent:RequestDispose_ToServer',{'RequestID','SlotInfo'})
    signature('/Script/Pal.PalPlayerInventoryData:TryGetContainerFromStaticItemID',{'StaticItemId','OutContainer','ReturnValue'})
    signature('/Script/Pal.PalItemContainer:Num',{'ReturnValue'})
    signature('/Script/Pal.PalItemContainer:Get',{'Index','ReturnValue'})
    signature('/Script/Pal.PalItemSlot:GetItemId',{'ReturnValue'})
    signature('/Script/Pal.PalItemSlot:GetSlotId',{'ReturnValue'})
    signature('/Script/Pal.PalItemSlot:GetStackCount',{'ReturnValue'})
    signature('/Script/Engine.KismetGuidLibrary:NewGuid',{'ReturnValue'})
    for _,p in ipairs({
        {'/Script/Pal.PalNetworkItemComponent:RequestDispose_ToServer','RequestID','StructProperty'},
        {'/Script/Pal.PalNetworkItemComponent:RequestDispose_ToServer','SlotInfo','StructProperty'},
        {'/Script/Pal.PalItemSlotIdAndNum','SlotId','StructProperty'},
        {'/Script/Pal.PalItemSlotIdAndNum','Num','IntProperty'},
        {'/Script/Pal.PalItemSlotId','ContainerId','StructProperty'},
        {'/Script/Pal.PalItemSlotId','SlotIndex','IntProperty'},
        {'/Script/Pal.PalContainerId','ID','StructProperty'},
        {'/Script/Pal.PalItemId','StaticId','NameProperty'}}) do requireProperty(p[1],p[2],p[3]) end
    local utility=UE.Object('/Script/Pal.Default__PalUtility');assert(valid(utility),'Native utility absent')
    local transmitter=utility:GetNetworkTransmitterByPlayerCharacter(env.player)
    assert(valid(transmitter) and transmitter:HasAuthority() and transmitter:GetWorld():GetAddress()==env.world:GetAddress(),
        'Local-authority transmitter mismatch')
    local network=transmitter:GetItem();assert(valid(network),'Native removal component absent')
    signature('/Script/Engine.ActorComponent:GetOwner',{'ReturnValue'})
    assert(sameObject(network:GetOwner(),transmitter),'Native item component owner mismatch')
    local out={}
    assert(inventory:TryGetContainerFromStaticItemID(item,out),'Native dirt container unavailable')
    local container=out.OutContainer;assert(valid(container),'Native dirt container output absent')
    local size=container:Num();assert(size>=0 and size<=1024,'Native container too large')
    local selected,sum=nil,0
    for i=0,size-1 do
        local slot=container:Get(i)
        if valid(slot) and str(slot:GetItemId().StaticId)==str(item) then
            local n=slot:GetStackCount();assert(n>=0,'Invalid dirt stack')
            sum=sum+n
            if n>=1 and not selected then
                local id=slot:GetSlotId();local g=id.ContainerId.ID
                assert(id.SlotIndex==i,'Dirt slot identity mismatch')
                selected={SlotId={ContainerId={ID={A=g.A,B=g.B,C=g.C,D=g.D}},SlotIndex=i},Num=1}
            end
        end
    end
    assert(selected and sum==inventory:CountItemNum(item),'Dirt slot/count mismatch')
    local library=UE.Object('/Script/Engine.Default__KismetGuidLibrary');assert(valid(library),'Guid library absent')
    local g=library:NewGuid();local request={A=g.A,B=g.B,C=g.C,D=g.D}
    return network,request,selected
end
local function dirtFixture()
    if not diagnosticAvailable() then return end
    local env=active()
    if testGranted then log('TEST_GRANT_REJECT once_per_process');return end
    testGranted=true
    signature('/Script/Engine.DataTableFunctionLibrary:DoesDataTableRowExist',{'Table','RowName','ReturnValue'})
    local table=StaticFindObject('/Game/Pal/DataTable/Item/DT_ItemDataTable.DT_ItemDataTable')
    local library=UE.Object('/Script/Engine.Default__DataTableFunctionLibrary')
    assert(valid(table) and valid(library),'Native item table absent')
    for i,definition in ipairs(registry)do if i>9 then break end
        local inventory,item=nativeDirtInventory(env,i);local before=inventory:CountItemNum(item)
        assert(library:DoesDataTableRowExist(table,item),'Item row absent '..definition.item)
        local result=inventory:AddItem_ServerInternal(item,64,false,0.0,true)
        local after=inventory:CountItemNum(item)
        log('TEST_GRANT '..definition.item..' before='..before..' requested=64 after='..after..' result='..tostring(result))
        assert(after==before+64,'Test grant failed '..definition.item)
    end
    log('TEST_GRANT PASS types='..math.min(9,#registry))
end
local function inventoryMetadata()
    local env=active();local inventory,item=nativeDirtInventory(env)
    log('DIRT_NATIVE_COUNT '..inventory:CountItemNum(item))
    for _,name in ipairs({'PalPlayerInventoryData','PalItemContainer','PalItemSlot','PalItemContainerMultiHelper',
        'PalNetworkItemComponent','PalNetworkPlayerComponent','PalNetworkComponentUtility','PalStaticItemDataBase',
        'PalItemSlotIdAndNum','PalItemSlotId','PalContainerId','PalItemId'}) do
        local class=StaticFindObject('/Script/Pal.'..name)
        if valid(class) then
            log('ITEM_META_CLASS '..class:GetFullName())
            if name~='PalItemSlotIdAndNum' and name~='PalItemSlotId' and name~='PalContainerId' and name~='PalItemId' then
                class:ForEachFunction(function(fn)
                    log('ITEM_META_FUNCTION '..fn:GetFullName())
                    fn:ForEachProperty(function(p) log('ITEM_META_PARAMETER '..p:GetFullName()) end)
                end)
            end
            class:ForEachProperty(function(p) log('ITEM_META_PROPERTY '..p:GetFullName()) end)
        else log('ITEM_META_CLASS_MISSING '..name) end
    end
    signature('/Script/Engine.Actor:GetComponentByClass',{'ComponentClass','ReturnValue'})
    local networkClass=UE.Object('/Script/Pal.PalNetworkItemComponent')
    local network=env.controller:GetComponentByClass(networkClass)
    log('ITEM_META_LOCAL_NETWORK '..(valid(network) and network:GetFullName() or 'absent'))
    
    for _,name in ipairs({'/Script/Pal.PalUtility:GetNetworkTransmitterByPlayerCharacter',
        '/Script/Pal.PalNetworkTransmitter:GetItem','/Script/Pal.PalPlayerInventoryData:TryGetContainerFromStaticItemID',
        '/Script/Pal.PalItemContainer:Num','/Script/Pal.PalItemContainer:Get',
        '/Script/Pal.PalItemSlot:GetItemId','/Script/Pal.PalItemSlot:GetSlotId',
        '/Script/Pal.PalItemSlot:GetStackCount','/Script/Engine.KismetGuidLibrary:NewGuid'}) do
        local fn=StaticFindObject(name);assert(valid(fn),'Native route absent '..name)
        log('DIRT_ROUTE_FUNCTION '..fn:GetFullName())
        fn:ForEachProperty(function(p) log('DIRT_ROUTE_PARAMETER '..p:GetFullName()) end)
    end
    signature('/Script/Pal.PalUtility:GetNetworkTransmitterByPlayerCharacter',{'Player','ReturnValue'})
    signature('/Script/Pal.PalNetworkTransmitter:GetItem',{'ReturnValue'})
    signature('/Script/Pal.PalPlayerInventoryData:TryGetContainerFromStaticItemID',{'StaticItemId','OutContainer','ReturnValue'})
    signature('/Script/Pal.PalItemContainer:Num',{'ReturnValue'})
    signature('/Script/Pal.PalItemContainer:Get',{'Index','ReturnValue'})
    signature('/Script/Pal.PalItemSlot:GetItemId',{'ReturnValue'})
    signature('/Script/Pal.PalItemSlot:GetSlotId',{'ReturnValue'})
    signature('/Script/Pal.PalItemSlot:GetStackCount',{'ReturnValue'})
    signature('/Script/Engine.KismetGuidLibrary:NewGuid',{'ReturnValue'})
    local utility=UE.Object('/Script/Pal.Default__PalUtility');assert(valid(utility),'PalUtility absent')
    local transmitter=utility:GetNetworkTransmitterByPlayerCharacter(env.player)
    assert(valid(transmitter) and transmitter:HasAuthority(),'Local authority transmitter absent')
    assert(transmitter:GetWorld():GetAddress()==env.world:GetAddress(),'Transmitter world mismatch')
    network=transmitter:GetItem();assert(valid(network),'Local item component absent')
    log('DIRT_ROUTE_COMPONENT '..network:GetFullName()..' transmitter='..transmitter:GetFullName())
    local out={};local found=inventory:TryGetContainerFromStaticItemID(item,out)
    local container=out.OutContainer
    log('DIRT_ROUTE_CONTAINER found='..tostring(found)..' valid='..tostring(valid(container)))
    if found then
        assert(valid(container),'Native container output absent')
        local size=container:Num();assert(size>=0 and size<=1024,'Native slot count exceeds bound')
        local sum=0
        for i=0,size-1 do
            local slot=container:Get(i)
            if valid(slot) and str(slot:GetItemId().StaticId)=='MC_Dirt' then
                local n=slot:GetStackCount();local id=slot:GetSlotId();local guid=id.ContainerId.ID
                assert(id.SlotIndex==i,'Native slot identity mismatch')
                log('DIRT_ROUTE_SLOT index='..i..' count='..n..' guid='..guid.A..','..guid.B..','..guid.C..','..guid.D)
                sum=sum+n
            end
        end
        assert(sum==inventory:CountItemNum(item),'Native slot/count mismatch')
        log('DIRT_ROUTE_SLOT_SUM '..sum)
    end
    local library=UE.Object('/Script/Engine.Default__KismetGuidLibrary');assert(valid(library),'Native Guid library absent')
    local guid=library:NewGuid()
    assert(type(guid.A)=='number' and type(guid.B)=='number' and type(guid.C)=='number' and type(guid.D)=='number',
        'Native request Guid fields unavailable')
    log('DIRT_ROUTE_GUID_READ_OK; no inventory mutation performed')
end
local function flatTestRow(env)
    local p=env.player:K2_GetActorLocation()
    local ignored={env.player}
    for _,chunk in pairs(chunks) do ignored[#ignored+1]=chunk.actor end
    local system=UE.GetKismetSystemLibrary();local colour={R=0,G=0,B=0,A=0}
    for _,offset in ipairs({{6,0},{-6,0},{0,6},{0,-6},{10,8},{-10,8},{10,-8},{-10,-8}}) do
        local x,y=math.floor(p.X/SIZE)+offset[1],math.floor(p.Y/SIZE)+offset[2]
        local row,low,high={},math.huge,-math.huge
        local all=true
        for i=0,math.min(9,#registry)-1 do
            local xx=x+i;local hit={}
            if not system:LineTraceSingle(env.player,vector(xx*SIZE+50,y*SIZE+50,p.Z+2000),
                vector(xx*SIZE+50,y*SIZE+50,p.Z-4000),0,false,ignored,0,hit,true,colour,colour,0) then all=false;break end
            low=math.min(low,hit.ImpactPoint.Z);high=math.max(high,hit.ImpactPoint.Z)
            row[#row+1]={x=xx,y=y,z=math.ceil(hit.ImpactPoint.Z/SIZE),debug=false,type=i+1}
        end
        if all and high-low<=40 then
            local z=math.ceil(high/SIZE);local clear=true
            for _,c in ipairs(row) do c.z=z;if cells[key(c.x,c.y,c.z)] or intersectsPlayer(c,env) then clear=false end end
            if clear then log('SELF_TEST_FLAT_GROUND height_range_cm='..(high-low));return row end
        end
    end
    error('Self-test needs a clear flat 9m row nearby')
end
selfTest=function()
    local env=active();local rowOK,row=pcall(flatTestRow,env)
    if not rowOK then
        local before={};for _,k in ipairs(sorted(cells))do before[#before+1]=CellState.row(cells[k],registry[cells[k].type or 1].name)end
        save();local loaded=assert(decode(read(path)),'F5 state sidecar decode failed');local after={}
        for _,k in ipairs(sorted(loaded))do after[#after+1]=CellState.row(loaded[k],registry[loaded[k].type or 1].name)end
        assert(J.encode(before)==J.encode(after),'F5 state conservation failed')
        log('SELF_TEST PASS STATE_V4_CONSERVATION cells='..#before..' flat_fixture=skipped')
        log('SELF_TEST_SKIP_BLOCK_AREA '..tostring(row));return false
    end
    local before={};local baseline=count(cells);local existing={};for k,c in pairs(cells)do existing[k]={x=c.x,y=c.y,z=c.z,type=c.type,state=J.encode(c.state or{})}end
    for i=1,math.min(9,#registry)do local inv,item=nativeDirtInventory(env,i);before[i]=inv:CountItemNum(item);assert(before[i]>=3,'Grant test kit first (F3)') end
    local previousReturns=directReturns;directReturns=true
    local owned={}
    local passed,failure=xpcall(function()
        for _,c in ipairs(row) do
            assert(not cells[key(c.x,c.y,c.z)],'Self-test target no longer empty')
            assert(placeCell(c,env),'Self-test placement did not settle')
            local k=key(c.x,c.y,c.z);owned[k]=true
            local inv,item=nativeDirtInventory(env,c.type)
            assert(cells[k].type==c.type and inv:CountItemNum(item)==before[c.type]-1,'Row type/count mismatch')
            log('SELF_TEST PASS place '..registry[c.type].name)
        end
        for _,c in ipairs(row) do
            local k=key(c.x,c.y,c.z);assert(owned[k]and not existing[k]and cells[k]and cells[k].type==c.type,'Self-test may only return its own new cell');assert(returnCell(k,env),'Self-test return did not settle');owned[k]=nil
            local inv,item=nativeDirtInventory(env,c.type)
            assert(not cells[k] and inv:CountItemNum(item)==before[c.type],'Break/count mismatch')
            log('SELF_TEST PASS return '..registry[c.type].name..' mode=direct')
        end
        local anchor=row[1]
        for i=1,3 do
            local c={x=anchor.x,y=anchor.y,z=anchor.z+i-1,debug=false,type=i}
            local k=key(c.x,c.y,c.z);assert(not cells[k],'Stack target occupied')
            assert(placeCell(c,env));owned[k]=true
            assert(cells[k].type==i,'Stack type mismatch')
        end
        log('SELF_TEST PASS mixed_stack height=3')
        for i=3,1,-1 do
            local k=key(anchor.x,anchor.y,anchor.z+i-1);assert(owned[k]and not existing[k],'Self-test stack ownership missing');assert(returnCell(k,env));owned[k]=nil
        end
        assert(count(cells)==baseline,'Cleanup cell count mismatch')
        for k,c in pairs(existing)do assert(cells[k]and cells[k].type==c.type and J.encode(cells[k].state or{})==c.state,'Pre-existing cell changed '..k)end
        for i=1,math.min(9,#registry)do local inv,item=nativeDirtInventory(env,i);assert(inv:CountItemNum(item)==before[i],'Final inventory mismatch') end
        log('SELF_TEST PASS cleanup counts_conserved types='..math.min(9,#registry)..' pre_existing_preserved='..baseline)
    end,debug.traceback)
    directReturns=previousReturns
    if not passed then
        log('SELF_TEST FAIL '..failure)
        if not inventoryTransaction then
            for _,k in ipairs(sorted(owned)) do if cells[k]and not existing[k] then pcall(returnCell,k,env) end end
        end
        error(failure)
    end
    log('SELF_TEST PASS COMPLETE')
end
houseTest=function()
    local env=active();local row=flatTestRow(env);local a=row[1];local plan={}
    for x=0,4 do for y=0,4 do
        plan[#plan+1]={x=a.x+x,y=a.y+y,z=a.z,debug=false,type=typeByName.oak_planks}
        if x==0 or x==4 or y==0 or y==4 then
            for h=1,3 do
                if not(x==2 and y==0 and h<3) then
                    local t=(x==0 or x==4) and (y==0 or y==4) and 'oak_log' or (h==2 and 'glass' or 'cobblestone')
                    plan[#plan+1]={x=a.x+x,y=a.y+y,z=a.z+h,debug=false,type=typeByName[t]}
                end
            end
        end
        plan[#plan+1]={x=a.x+x,y=a.y+y,z=a.z+4,debug=false,type=typeByName.oak_planks}
    end end
    plan[#plan+1]={x=a.x+1,y=a.y+1,z=a.z+1,debug=false,type=typeByName.crafting_table}
    local needed={}
    for _,c in ipairs(plan) do assert(not cells[key(c.x,c.y,c.z)] and not intersectsPlayer(c,env),'House footprint occupied');needed[c.type]=(needed[c.type] or 0)+1 end
    for t,n in pairs(needed) do local inv,item=nativeDirtInventory(env,t);assert(inv:CountItemNum(item)>=n,'Insufficient house materials; grant kit') end
    for _,c in ipairs(plan) do assert(placeCell(c,env),'House placement failed') end
    log('HOUSE_TEST PASS placed='..#plan..' anchor='..key(a.x,a.y,a.z))
end
local probeRegistered=false
local function houseView()
    if not diagnosticAvailable() then return end
    local env=active();local tableCell
    for _,k in ipairs(sorted(cells)) do
        if cells[k].type==typeByName.crafting_table then tableCell=cells[k];break end
    end
    assert(tableCell,'Build the F6 house before using F9')
    local target=vector((tableCell.x+1.5)*SIZE,(tableCell.y+1.5)*SIZE,(tableCell.z+1.5)*SIZE)
    local p=vector(target.X+650,target.Y-600,target.Z)
    local hit={};local color={R=0,G=0,B=0,A=0};local ignore={env.player}
    for _,chunk in pairs(chunks) do ignore[#ignore+1]=chunk.actor end
    local found=UE.GetKismetSystemLibrary():LineTraceSingle(env.player,vector(p.X,p.Y,p.Z+1000),
        vector(p.X,p.Y,p.Z-2000),0,false,ignore,0,hit,true,color,color,0)
    assert(found,'House view ground absent')
    p.Z=hit.ImpactPoint.Z+env.player.CapsuleComponent:GetScaledCapsuleHalfHeight()+5
    capsuleClear(p,env)
    local out={};env.player:K2_SetActorLocation(p,false,out,true)
    runDiagnostic('HOUSE_VIEW',20,env,{},function(w)
        local camera=env.controller.PlayerCameraManager:GetCameraLocation()
        local x,y,z=target.X-camera.X,target.Y-camera.Y,target.Z-camera.Z
        env.controller:SetControlRotation({Pitch=math.deg(math.atan(z,math.sqrt(x*x+y*y))),Yaw=math.deg(math.atan(y,x)),Roll=0})
        return w.ticks>=8
    end,function() log('HOUSE_VIEW_READY') end)
end
local function probeValue(v,depth)
    depth=depth or 0
    local ok,result=pcall(function()
        if type(v)=='string' or type(v)=='number' or type(v)=='boolean' then return tostring(v) end
        if depth>1 then return tostring(v) end
        local parts={}
        for _,field in ipairs({'X','Y','Z','Num','SlotId','StaticItemId','StaticId','Count','SlotIndex','ContainerId','ID'}) do
            local good,value=pcall(function()return v[field]end)
            if good and value~=nil then parts[#parts+1]=field..'='..probeValue(value,depth+1) end
        end
        if #parts>0 then return '{'..table.concat(parts,',')..'}' end
        if type(v)=='table' then for i,value in ipairs(v) do if i<=4 then parts[#parts+1]=probeValue(value,depth+1) end end;return '['..table.concat(parts,',')..']' end
        return tostring(v)
    end)
    return ok and result or '<unreadable>'
end
local uiKit,uiWidgets
local function safe(action,loadProbe,recoverable,onMasterTick)
    if quiesced or transitioning or(restoring and not loadProbe)or busy or disabled then return end
    if inventoryTransaction then log('INPUT_REJECT inventory_pending');return end
    local uiAction=(phaseD and phaseD.open)or(phaseB and phaseB.open)
    local uiGeneration=uiKit and uiKit.input57 and uiKit.input57.serial
    busy=true
    local function run()
        if quiesced or transitioning then busy=false;return end
        if uiAction and uiKit and uiKit.input57 and uiGeneration~=uiKit.input57.serial then busy=false;return end
        local ok,error= xpcall(action,debug.traceback)
        busy=false
        if not ok then
            if uiAction and uiKit and uiKit.recoverInputZ1 then
                log('MCZ1_UI_ACTION_ERROR '..tostring(error));uiKit.recoverInputZ1('action-error')
            elseif recoverable then log('MC36_COMMAND_REJECT '..tostring(error))
            else disabled=true;log('STOP_ERROR '..tostring(error))end
        end
    end
    if onMasterTick then run()else Timers.defer(run)end
end
local widgetClasses={}
local function loadWidgetClass(name)
    local expected='/Game/MinecraftBlocks/'..name..'.'..name..'_C'
    if valid(widgetClasses[name])and widgetClasses[name]:IsA(StaticFindObject('/Script/CoreUObject.Class'))and widgetClasses[name]:GetFullName()=='WidgetBlueprintGeneratedClass '..expected then return widgetClasses[name]end
    assert(IsInGameThread(),'Widget asset load outside game thread')
    local package='/Game/MinecraftBlocks/'..name
    local classPath=package..'.'..name..'_C'
    local class=StaticFindObject(classPath)
    if not valid(class) then

        signature('/Script/Engine.KismetSystemLibrary:MakeSoftClassPath',{'PathString','ReturnValue'})
        signature('/Script/Engine.KismetSystemLibrary:Conv_SoftClassPathToSoftClassRef',{'SoftClassPath','ReturnValue'})
        signature('/Script/Engine.KismetSystemLibrary:LoadClassAsset_Blocking',{'AssetClass','ReturnValue'})
        local library=UE.GetKismetSystemLibrary()
        local softPath=library:MakeSoftClassPath(classPath)
        class=UE.Native109(library,'LoadClassAsset_Blocking',library:Conv_SoftClassPathToSoftClassRef(softPath))
        log('UI_CLASS_LOAD '..classPath..' valid='..tostring(valid(class)))
    end
    assert(valid(class)and class:IsA(StaticFindObject('/Script/CoreUObject.Class'))and class:GetFullName()=='WidgetBlueprintGeneratedClass '..expected,'Cooked widget class unavailable/changed '..name)
    widgetClasses[name]=class;return class
end
function UE.createRawUI51(env,name,kind,hidden)
    signature('/Script/UMG.WidgetBlueprintLibrary:Create',{'WorldContextObject','WidgetType','OwningPlayer','ReturnValue'})
    signature('/Script/UMG.UserWidget:AddToViewport',{'ZOrder'})
    signature('/Script/UMG.Widget:RemoveFromParent',{})
    local class=loadWidgetClass(name)
    local library=UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary')
    assert(valid(library),'Native widget library unavailable')
    local widget=library:Create(env.player,class,env.controller)
    if not valid(widget) then log('UI_CREATE_INVALID '..name);return nil end
    local uiFactor,uiUnit;if uiKit then uiFactor,uiUnit=uiKit:apply(widget,name,env)end
    if hidden then widget:SetRenderOpacity(0);widget:SetVisibility(3)end

    local overlay=name=='WBP_MCHUD'or name=='WBP_MCCapture'
    widget:AddToViewport(overlay and 100 or 200)
    log('UI_VISIBLE '..name)
    return {widget=widget,kind=kind,epoch=epoch,identity=env.identity,uiFactor=uiFactor,uiUnit=uiUnit}
end
UE.uiCache51=UE.dofileJ(base..'/ui_cache.lua')({base=base,UE=UE,valid=valid,log=log,create=UE.createRawUI51,widgets=function(w)return uiWidgets(w)end,
    retire=function(r)UE.widgetNodes58[r.widget:GetAddress()]=nil;if uiKit then uiKit:forgetGraph(r.nodes)end;r.nodes=nil end,
    epoch=function()return epoch end,environment=environment,scale=function(env)return uiKit:metrics(env)end,locale=function()UE.language57:refresh();return UE.language57.generation end,quiesced=function()return quiesced or transitioning end})
local function createUI(env,name,kind)return UE.uiCache51:get(env,name,kind)end
function UE.hideUI51(w)return UE.uiCache51:hide(w)end
local function uiProbe()
    local env=active()
    if uiStage=='failed' then log('UI_PROBE_STOPPED');return end
    if ui and ui.kind=='probe' then
        ui.widget:RemoveFromParent()
        ui=nil;probeRemovedAt=os.time();uiStage='removed'
        log('UI_PROBE_REMOVED wait_seconds=60');return
    end
    if uiStage=='removed' then
        local seconds=os.time()-probeRemovedAt
        if seconds<60 then log('UI_PROBE_WAIT seconds='..seconds);return end
        uiStage='passed';log('UI_PROBE_PASS removed_and_game_alive_seconds='..seconds);return
    end
    if uiStage=='passed' then log('UI_PROBE_ALREADY_PASSED');return end
    local ok,result=xpcall(function() return createUI(env,'WBP_MCProbe','probe') end,debug.traceback)
    if not ok or not result then uiStage='failed';log('UI_PROBE_FAIL '..tostring(result));return end
    ui=result;uiStage='shown'
end
UE.widgetNodes58={}
Timers.onEpoch('widget-node-maps',function()UE.widgetNodes58={}end)
uiWidgets=function(widget)
    local address=widget:GetAddress();local saved=UE.widgetNodes58[address]
    if saved and saved.epoch==epoch and saved.name==widget:GetFullName()then return saved.nodes end
    local tree=widget.WidgetTree;assert(valid(tree),'Runtime WidgetTree unavailable')
    local root=tree.RootWidget;assert(valid(root),'Runtime widget root unavailable')
    local panel=UE.Object('/Script/UMG.PanelWidget')
    local result=setmetatable({},{__index=function(t,k)if type(k)=='string' then return rawget(t,k:lower())end end})
    local function visit(node,depth)
        assert(depth<=20,'Widget depth exceeds bounded tree')
        local name=node:GetFullName():match('([^.:]+)$');result[name]=node
        result[name:lower()]=node
        result[name:gsub('_%d+$','')]=node
        if node:IsA(panel) then
            local n=node:GetChildrenCount();assert(n<=1024,'Unexpected widget child count')
            for i=0,n-1 do local child=node:GetChildAt(i);if valid(child) then visit(child,depth+1) end end
        end
    end
    visit(root,0);UE.widgetNodes58[address]={epoch=epoch,name=widget:GetFullName(),nodes=result};return result
end
updateHotbar=function(env)
    if phaseA then phaseA:updateHotbar(env) end
    if quiesced or not ui or ui.kind~='hotbar' or ui.epoch~=epoch then return end
    if ui.identity~=env.identity or not valid(ui.widget) then ui=nil;return end
    local nodes=ui.nodes
    local textLibrary=UE.GetKismetTextLibrary()
    local counts={}
    for i,definition in ipairs(registry)do if i>9 then break end
        local inventory,item=nativeDirtInventory(env,i);local n=inventory:CountItemNum(item)
        counts[i]=tostring(n)
        nodes['Count'..i]:SetText(textLibrary:Conv_StringToText(tostring(n)))
        nodes['Slot'..i]:SetBrushColor(i==selectedType and {R=.9,G=.8,B=.2,A=1} or {R=.15,G=.15,B=.15,A=.9})
    end
    local values=table.concat(counts,',')
    if values~=ui.lastCounts then log('HOTBAR_COUNTS '..values);ui.lastCounts=values end
end
local function hotbarToggle()
    local env=active()
    if uiStage~='passed' then log('HOTBAR_REJECT probe_gate='..uiStage);return end
    if ui and ui.kind=='hotbar' then ui.widget:RemoveFromParent();ui=nil;log('HOTBAR_HIDDEN');return end
    local view
    local ok,result=xpcall(function()
        signature('/Script/UMG.PanelWidget:GetChildrenCount',{'ReturnValue'})
        signature('/Script/UMG.PanelWidget:GetChildAt',{'Index','ReturnValue'})
        signature('/Script/UMG.TextBlock:SetText',{'InText'})
        signature('/Script/UMG.Border:SetBrushColor',{'InBrushColor'})
        signature('/Script/Engine.KismetTextLibrary:Conv_StringToText',{'InString','ReturnValue'})
        view=assert(createUI(env,'WBP_MCHotbar','hotbar'),'Hotbar Create invalid')
        view.nodes=uiWidgets(view.widget)
        for i=1,#registry do assert(valid(view.nodes['Count'..i]) and valid(view.nodes['Slot'..i]),'Missing hotbar nodes') end
        ui=view;updateHotbar(env)
        return view
    end,debug.traceback)
    if not ok then
        if view and valid(view.widget) then pcall(function() view.widget:RemoveFromParent() end) end
        ui=nil;log('HOTBAR_FAIL '..tostring(result));return
    end
    ui=result;log('HOTBAR_READY slots=9 selection='..registry[selectedType].name)
end
local function bind(k,action,allowMenu,modifiers,loadProbe,recoverable)
    modifiers=modifiers or{}
    assert(not IsKeyBindRegistered(k,modifiers),'Key conflict '..k)
    Timers.key(k,modifiers,function()
        safe(function()
            local env=loadProbe and loadEnvironment()or environment()
            if not env then return end
            if uiKit and uiKit:editing() and #modifiers==0 then
                return 
            end
            if not allowMenu and env.controller:IsMoveInputIgnored() then return end
            action()
        end,loadProbe,recoverable)
    end)
end
local wallAnchor
local function wallFixture()
    local env=active();local row=flatTestRow(env);wallAnchor=row[1]
    for i=1,4 do row[i].type=typeByName.dirt;assert(placeCell(row[i],env),'Wall fixture placement failed')end
    local f=assert(io.open(base..'/views.txt','wb'))
    local anchor=key(wallAnchor.x,wallAnchor.y,wallAnchor.z)
    f:write('views-v1|'..WORLD..'\nwall_south|'..anchor..'|1.5,-3,0|-Y|1,0,0|+Y\nwall_north|'..anchor..'|1.5,5,0|+Y|1,0,0|-Y\n');f:close()
    viewIndex=0;applyView(1);log('PAL_WALL_BUILT width=4 height=1 anchor='..anchor)
end
local function wallFollow()
    assert(wallAnchor,'Create wall fixture first')
    local env=active();local stamp=epoch;applyView(1)
    Timers.after(2500,function()
        if stamp~=epoch or quiesced or transitioning then return end
        local current=environment();if not current or diagnostic then log('PAL_WALL_UNAVAILABLE view-not-ready');return end
        local pal=current.controller.BP_OtomoPalHolderComponent:TryGetCurrentSelectPalActor()
        if not valid(pal) then log('PAL_WALL_UNAVAILABLE no-active-pal');return end
        local start=pal:K2_GetActorLocation()
        runDiagnostic('PAL_WALL',300,current,{pal=pal,start=start,last=start,maxStep=0,crossed=false,around=false},function(w)
            if not valid(w.pal) then return true end
            local p=w.pal:K2_GetActorLocation()
            local dx,dy,dz=p.X-w.last.X,p.Y-w.last.Y,p.Z-w.last.Z
            w.maxStep=math.max(w.maxStep,math.sqrt(dx*dx+dy*dy+dz*dz));w.last=vector(p.X,p.Y,p.Z)
            local y=wallAnchor.y*SIZE
            if p.Y>=y-100 and p.Y<=y+200 then
                if p.X<wallAnchor.x*SIZE-30 or p.X>(wallAnchor.x+4)*SIZE+30 then w.around=true end
            end
            w.crossed=w.crossed or (w.start.Y<y and p.Y>y+100)
            if w.ticks%20==0 then log(string.format('PAL_WALL_POSITION t=%.1f x=%.1f y=%.1f z=%.1f',w.ticks*.05,p.X,p.Y,p.Z))end
            return w.crossed and w.around
        end,function(w)
            log('PAL_WALL_RESULT '..(w.crossed and w.around and w.maxStep<250 and 'PASS_WALK_AROUND' or 'FAIL_OR_INCONCLUSIVE')..
                ' crossed='..tostring(w.crossed)..' around='..tostring(w.around)..' max_step_cm='..string.format('%.1f',w.maxStep))
        end)
    end)
end
if config.legacy_debug_keys then
bind(Key.NUM_ONE,place);bind(Key.NUM_SEVEN,breakBlock)
bind(Key.NUM_NINE,smoke)
bind(Key.NUM_FIVE,fill);bind(Key.NUM_ZERO,clearDebug);bind(Key.MULTIPLY,status)
assert(Key.DIVIDE~=nil,'NumDivide key unavailable')
bind(Key.DIVIDE,function() active();log('MANUAL_INIT_READY') end)
bind(Key.PAGE_DOWN,function() cameraInput(-10,0) end)
bind(Key.PAGE_UP,function() cameraInput(10,0) end)
bind(Key.HOME,function() cameraInput(0,-10) end)
bind(Key.END,function() cameraInput(0,10) end)
bind(Key.NUM_EIGHT,walkCheck)
assert(Key.ADD and Key.SUBTRACT and Key.F2,'Task6A keys unavailable')
bind(Key.ADD,function() applyView(1) end);bind(Key.SUBTRACT,function() applyView(-1) end)
bind(Key.F2,function()
    local env=active();local selected
    for _,parameter in ipairs(env.player.LoadoutSelectorComponent:GetWeaponList()) do
        local good,w=pcall(function()return parameter:get()end);if not good then w=parameter end
        if valid(w) and w:GetItemId().StaticId:ToString():lower():find('pickaxe',1,true) then selected=w:GetLoadoutSelectorIndex()+1 end
    end
    assert(selected,'Smoke test needs a native pickaxe in one of the four weapon slots')
    phaseA:select(selected);log('MC_PICKAXE_READY slot='..selected)
end)
assert(Key.F3 and Key.F4,'Dirt setup keys unavailable')
bind(Key.F3,dirtFixture)
local miningFixtureIndex=0
bind(Key.F4,function()
    miningFixtureIndex=miningFixtureIndex+1
    assert(miningFixtureIndex<=4,'Four mining fixtures already created')
    local env=active();local row=flatTestRow(env);local c=row[1]
    c.type=(miningFixtureIndex%2==1) and typeByName.dirt or typeByName.stone
    assert(placeCell(c,env),'Mining fixture did not settle')
    local f=assert(io.open(base..'/views.txt','wb'))
    f:write('views-v1|'..WORLD..'\nmining_'..miningFixtureIndex..'|'..c.x..','..c.y..','..c.z..'|2,-1,0|+X|0,0,0|-X\n');f:close()
    viewIndex=0;applyView(1)
    log('MC_FIXTURE '..miningFixtureIndex..' type='..registry[c.type].name..' cell='..key(c.x,c.y,c.z))
end)
bind(Key.F6,wallFixture)
bind(Key.F7,function()
    local env=active();selectedType=selectedType%#registry+1
    log('SELECTED_BLOCK '..registry[selectedType].label);updateHotbar(env)
end)
bind(Key.F11,uiProbe)
bind(Key.F9,wallFollow)
bind(Key.F1,function()
    local env=active();previewEnabled=not previewEnabled
    if not liveHandle then startLiveTimer(env) end
    if previewEnabled and not preview then makePreview(env) end
    log('PREVIEW_ENABLED '..tostring(previewEnabled))
end)
assert(Key.DECIMAL~=nil,'NumDecimal key unavailable')
bind(Key.DECIMAL,function() if diagnostic then diagnostic.cancelled=true;log('DIAGNOSTIC_CANCEL_REQUEST') end end)
end
local function overlayCube(env)
    local gameplay=UE.Object('/Script/Engine.Default__GameplayStatics')
    local t=transform(0,0,0)
    local actor=gameplay:BeginDeferredActorSpawnFromClass(env.player,UE.Object('/Script/Engine.Actor'),t,1,nil)
    assert(valid(actor),'Crack actor failed');actor=gameplay:FinishSpawningActor(actor,t)
    actor.Tags={UE.FindOrAddFName('MCBlocksPreview')}
    local component=actor:AddComponentByClass(UE.Object('/Script/Engine.StaticMeshComponent'),false,t,false)
    component:SetMobility(2);component:SetCollisionEnabled(0)
    assert(component:SetStaticMesh(loadMesh('crack',1)))
    actor:SetActorScale3D(vector(1.005,1.005,1.005));actor:SetActorHiddenInGame(true)
    return {actor=actor,component=component}
end
if config.task19_ui then uiKit=UE.dofileJ(base..'/ui_kit.lua')({UE=UE,base=base,config=config,valid=valid,log=log,widgets=uiWidgets,
    epoch=function()return epoch end,nativeUIReady=function()return worldReady and Startup.open and not transitioning and not quiesced and not disabled end,
    nativeUIReadReady=function()return not busy and not(phaseB and phaseB.open)and not(phaseD and phaseD.open)and not(deathScreen and deathScreen.open)end})end
phaseA=UE.dofileJ(base..'/phase_a.lua')({UE=UE,base=base,registry=registry,config=config,valid=valid,log=log,
    epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end,environment=environment,active=active,
    gameplayInput=gameplayInput,trace=trace,hitChunk=hitChunk,cells=function()return cells end,inventory=nativeDirtInventory,
    setBlockMode=function(v)blockMode=v end,setType=function(t)selectedType=t end,
    place=place,returnCell=returnCell,remove=remove,save=save,pending=function()return inventoryTransaction~=nil end,
    createUI=createUI,hideUI=UE.hideUI51,uiWidgets=uiWidgets,uiKit=uiKit,overlay=overlayCube,sound=function(event,p,v)if phaseC then phaseC:play(event,p,v)end end})
if config.phase_b then
    phaseB=UE.dofileJ(base..'/phase_b.lua')({UE=UE,base=base,world=WORLD,registry=registry,config=config,valid=valid,log=log,uiKit=uiKit,
        epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end,environment=environment,active=active,
        gameplayInput=gameplayInput,trace=trace,hitChunk=hitChunk,cells=function()return cells end,phaseA=phaseA,phaseC=function()return phaseC end,phaseD=function()return phaseD end,busy=function()return busy end,createUI=createUI,hideUI=UE.hideUI51,uiWidgets=uiWidgets})
    phaseA.items=phaseB
    if uiKit then uiKit.items=phaseB end
end
phaseC=UE.dofileJ(base..'/phase_c.lua')({UE=UE,base=base,world=WORLD,config=config,registry=registry,typeByName=typeByName,valid=valid,log=log,
    epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end,active=active,environment=environment,gameplayInput=gameplayInput,phaseA=phaseA,items=phaseB,
    cells=function()return cells end,entities=function()return entities end,clock=function(v)if v then entityClock=v end;return entityClock end,save=save,key=key,
    loadMesh=loadMesh,hitChunk=hitChunk,intersectsPlayer=intersectsPlayer,placeCell=placeCell,returnCell=returnCell,addVisual=addVisual,remove=remove,chunks=function()return chunks end,transform=transform,flatRow=flatTestRow,
    setVariant=function(k,v,opened)local c=assert(cells[k]);if deferred[k]then c.variant=v;if opened~=nil then c.open=opened end;return end;local ch=assert(chunks[c.chunk]);ch.index[k]=nil;rebuild(ch);c.variant=v;if opened~=nil then c.open=opened end;addVisual(c,active())end})

local function mechanicMutation(k,new,env)
    UE.geometryRevisionL=(UE.geometryRevisionL or 0)+1
    local old=cells[k]
    if old and phaseC and not phaseC:beforeBreak(k,env)then return false end
    if old then
        if deferred[k]then deferred[k]=nil
        else
            local ch=assert(chunks[old.chunk]);local index=assert(ch.index[k]);local last=ch.component:GetInstanceCount()-1
            assert(ch.component:RemoveInstance(index),'Mechanics RemoveInstance failed')
            ch.index[k]=nil
            for j=index,last-1 do local shifted=ch.keys[j+1];ch.keys[j]=shifted;ch.index[shifted]=j end
            ch.keys[last]=nil
            assert(ch.component:GetInstanceCount()==count(ch.index),'Mechanics index conservation')
        end
        cells[k]=nil
    end
    if new then addVisual(new,env);cells[k]=new end
    if mechanics then mechanics:changed(old,new)end
    phaseC.dirty=true
    if old then phaseC.connected:neighbors(old)end
    return true
end
local function mechanicVariant(k,v,env)
    local c=assert(cells[k]);if c.variant==v then return end
    
    local q={};for name,value in pairs(c)do q[name]=value end;q.variant=v
    assert(mechanicMutation(k,q,env))
end
local function mechanicNativeEmpty(c,env)
    local ignored={env.player};for _,ch in pairs(chunks)do ignored[#ignored+1]=ch.actor end
    local p={X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+50};local system=UE.GetKismetSystemLibrary();local colour={R=0,G=0,B=0,A=0}
    
    local finish={X=p.X,Y=p.Y,Z=p.Z+.2}
    for _=1,16 do
        local hit={}
        if not _G.MC_OUT_K('BoxTraceSingle',system,env.player,p,finish,{X=49.9,Y=49.9,Z=49.9},{Pitch=0,Yaw=0,Roll=0},0,false,ignored,0,hit,true,colour,colour,0)then return true end
        local component=hit.Component:Get();local actor=valid(component)and component:GetOwner()or nil
        if not valid(actor)or not actor:GetClass():GetFullName():find('BP_MapObject_CommonDropItem3D',1,true)then return false end
        ignored[#ignored+1]=actor 
    end
    return false
end
mechanics=UE.dofileJ(base..'/mechanics.lua')({base=base,config=config,UE=UE,valid=valid,log=log,registry=registry,types=typeByName,
    key=key,cells=function()return cells end,items=phaseB,phaseA=phaseA,phaseC=phaseC,save=save,mutate=mechanicMutation,
    variant=mechanicVariant,emptyNative=mechanicNativeEmpty,intersects=intersectsPlayer,targetCell=targetCell,hitChunk=hitChunk,
    environment=environment,epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end,
    saveActive=function()return mechanicsWriter:active()end,saveSlice=function(budget)return mechanicsWriter:step(budget)end,
    cancelSave=function()mechanicsWriter:cancel()end,
    flashJobs=function(c,env)return phaseC:explosionFlashJobs(c,env)end})
phaseB.mechanics=mechanics
UE.uiCache51.prime=function(env,result,name)if phaseD then phaseD:hideFooter(env,true)end;if name=='WBP_MCInventory2'or name=='WBP_MCInventory3'or name=='WBP_MCChest'or name=='WBP_MCFurnace'then phaseB:prebuild(env,result,name)elseif phaseD then phaseD:prebuild(env,result,name)end end
UE.uiCache51.primeReady=function(env)phaseA:earlyHUD(env.controller);return valid(uiKit.iconCacheRoot)end
beds=UE.dofileJ(base..'/beds.lua')({base=base,UE=UE,world=WORLD,active=active,valid=valid,log=log,items=phaseB,uiKit=uiKit,mechanics=mechanics,
    types=typeByName,registry=registry,key=key,cells=function()return cells end,mutate=mechanicMutation,save=save,
    emptyNative=mechanicNativeEmpty,intersects=intersectsPlayer,gameplayInput=gameplayInput,environment=environment,
    ground=function(c,env)local p={X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+3};local q={X=p.X,Y=p.Y,Z=p.Z-20};return UE.GetKismetSystemLibrary():LineTraceSingle(env.player,p,q,0,false,{env.player},0,{},true,{R=0,G=0,B=0,A=0},{R=0,G=0,B=0,A=0},0)end,
    deadClear=function(c,env)
        local ignored={env.controller};for _,ch in pairs(chunks)do if valid(ch.actor)then ignored[#ignored+1]=ch.actor end end
        local p={X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+90};local color={R=0,G=0,B=0,A=0}
        return not UE.GetKismetSystemLibrary():BoxTraceSingle(env.controller,p,{X=p.X,Y=p.Y,Z=p.Z+.2},{X=34,Y=34,Z=87},{Pitch=0,Yaw=0,Roll=0},0,false,ignored,0,{},true,color,color,0)
    end,
    deadGround=function(c,env)local p={X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+3};return UE.GetKismetSystemLibrary():LineTraceSingle(env.controller,p,{X=p.X,Y=p.Y,Z=p.Z-20},0,false,{env.controller},0,{},true,{R=0,G=0,B=0,A=0},{R=0,G=0,B=0,A=0},0)end,
    epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end})
phaseB.beds=beds;mechanics.beds=beds
steve=UE.dofileJ(base..'/steve.lua')({base=base,UE=UE,config=config,valid=valid,log=log,phaseC=phaseC,items=phaseB,phaseA=phaseA,environment=environment,epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end})
UE.mount76=UE.dofileJ(base..'/mount76.lua')({base=base,UE=UE,valid=valid,log=log,epoch=function()return epoch end})
UE.controls68=UE.dofileJ(base..'/controls68.lua')({base=base,UE=UE,valid=valid,log=log,items=phaseB,phaseA=phaseA,mobs=mobs,trace=trace,gameplayInput=gameplayInput,environment=environment})
phaseA.attackSync68=function(env)UE.controls68:sync(env)end
local task26=config.test_mode and (function()return nil end)()
phaseA.onSelection=function(env)if UE.controls68 then UE.controls68:sync(env)end;if phaseC.started then phaseC:updateHand(env);steve:tick(env);return{frame=Timers.frameCounter,engineFrame=UE.GetKismetSystemLibrary():GetFrameCount(),handFrame=phaseC.handFrame,itemFrame=steve.itemFrame,id=steve.itemId}end end
local task27=config.test_mode and (function()return nil end)()
UE.task52=config.test_mode and (function()return nil end)()
UE.task56=config.test_mode and (function()return nil end)()
local task28=config.test_mode and (function()return nil end)()
local task31Stage=config.test_mode and (function()return nil end)()or{mode='S3'}
if UE.packFlags:has('islands_animals')then
island=UE.dofileJ(base..'/islands88.lua')({base=base,world=WORLD,config=config,UE=UE,valid=valid,log=log,environment=function()return environment()or(UE.earlyEnvironment51 and UE.earlyEnvironment51())end,epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end,ready=function()return worldReady end,
 entryFooting=function(env)if UE.entryHold51 then UE.entryHold51:rebaseOwnedFooting(env)end end,
 retain=function(o)assert(phaseA.uiEntry);phaseA.uiEntry:retain(o)end,
 streamReady=function(env)
  local lib=UE.Object('/Script/Engine.Default__SubsystemBlueprintLibrary')
  local subsystem=lib:GetWorldSubsystem(env.world,UE.Object('/Script/Engine.WorldPartitionSubsystem'))
  if valid(subsystem)and not subsystem:IsAllStreamingCompleted()then return false end
  local pending=false;env.world.StreamingLevels:ForEach(function(_,v)local level=v:get();if valid(level)and level:IsStreamingStatePending()then pending=true end end)
  return not pending
 end})
end
local task30=config.test_mode and (function()return nil end)()
local task31=(config.test_mode and (function()return nil end)()or UE.dofileJ(base..'/owned_travel.lua'))({base=base,world=WORLD,UE=UE,valid=valid,log=log,active=active,beds=beds,environment=environment,epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end,island=island,mode=task31Stage.mode})
local task25=config.test_mode and (function()return nil end)()
local task23=config.test_mode and (function()return nil end)()
phaseD=UE.dofileJ(base..'/phase_d.lua')({UE=UE,valid=valid,log=log,base=base,config=config,active=active,environment=environment,items=phaseB,uiKit=uiKit,phaseA=phaseA,phaseC=phaseC,beds=beds,steve=steve,
    epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end,busy=function()return busy end,gameplayInput=gameplayInput,createUI=createUI,hideUI=UE.hideUI51,uiWidgets=uiWidgets,beginTransition=function(...)return beginTransition(...)end})
phaseD.menuInput=UE.dofileJ(base..'/menu_input.lua')({base=base,UE=UE,log=log,uiKit=uiKit,environment=environment,items=phaseB,menu=phaseD,trade=function()return UE.waystones83 and UE.waystones83.open and UE.waystones83 or UE.alexTrade end,epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end})
phaseD.menuInput:install()
uiKit.recoverInputZ1=function(reason)
    if phaseD.open then phaseD:close()end
    if phaseB and phaseB.open then phaseB:close()end
    phaseD.pendingNav46=nil;phaseD.intent=nil;phaseD.escapeDirty=nil;phaseD.escapeDue=nil
    if phaseB then phaseB.openRequest=nil;phaseB.intent=nil;phaseB.nativeInventoryDirty=nil end
    local env=environment()
    if env and env.status=='alive'and not(UE.nativeInputG4 and UE.nativeInputG4:blocksMenu())then
        UE.nativeInputG4:releaseMain(env)
        env.controller:ResetIgnoreMoveInput();env.controller:ResetIgnoreLookInput();env.controller.bShowMouseCursor=false
        UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(env.controller,true)
    end
    uiKit:releaseInput();log('MCZ1_UI_WATCHDOG stack_reset=true reason='..tostring(reason))
end
phaseA.captureHUD=function(env,visible)phaseD.features:updateCapture(env,visible);phaseD.armor:tick(env)end
local task33=config.test_mode and (function()return nil end)()
deathScreen=UE.dofileJ(base..'/death_screen.lua')({base=base,UE=UE,valid=valid,log=log,beds=beds,uiKit=uiKit,cover=UE.loadingCover51,createUI=createUI,widgets=uiWidgets,loadEnvironment=loadEnvironment,closeMenus=function()if phaseD.open then phaseD:close(false,true)end;if phaseB.open then phaseB:teardown(nil)end end})
if UE.packFlags:has('islands_animals')then
resources=UE.dofileJ(base..'/resources.lua')({base=base,world=WORLD,island=island,types=typeByName,registry=registry,key=key,cells=function()return cells end,state=function()return resourceState end,mechanics=mechanics,cancelSave=function()mechanicsWriter:cancel()end,
    mutate=mechanicMutation,emptyNative=function(c,env)
        local ignored={env.player};for _,ch in pairs(chunks)do ignored[#ignored+1]=ch.actor end;for _,a in pairs(island.actors)do if valid(a)then ignored[#ignored+1]=a end end
        local p={X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+50};local color={R=0,G=0,B=0,A=0}
        for _=1,16 do
            local hit={};if not UE.GetKismetSystemLibrary():BoxTraceSingle(env.player,p,{X=p.X,Y=p.Y,Z=p.Z+.2},{X=49,Y=49,Z=49},{Pitch=0,Yaw=0,Roll=0},0,false,ignored,0,hit,true,color,color,0)then return true end
            local comp=hit.Component:Get();local actor=valid(comp)and comp:GetOwner()or nil
            if not valid(actor)or not actor:GetClass():GetFullName():find('BP_MapObject_CommonDropItem3D',1,true)then return false end
            ignored[#ignored+1]=actor
        end
        return false
    end,intersects=intersectsPlayer,log=log,UE=UE,environment=environment,epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end})
mechanics.resources=resources
else resources={start=function()end,scan=1}end
local task34=config.test_mode and (function()return nil end)()
phaseA.menuOpen=function()return phaseD.open or phaseD.nativeVisibleG or deathScreen.open or(UE.alexTrade and UE.alexTrade.open)or(UE.waystones83 and(UE.waystones83.open or UE.waystones83.busy))end
local uiEntry=UE.dofileJ(base..'/ui_entry.lua')({base=base,UE=UE,valid=valid,log=log,config=config,world=WORLD,phaseA=phaseA,items=phaseB,uiKit=uiKit,startup=Startup,loadWidgetClass=loadWidgetClass,preloadSteve=function(retain)steve:preload(retain)end,
    preloadIslands=function(add,retain)if island then island:preloadAssetsOC(add,retain)end end,
    preloadAlex=function(retain)if UE.alex then UE.alex:preloadStaticOC(retain)end end,
    ready=function()return worldReady and Startup.open and not transitioning and not quiesced and not disabled end,
    earlyReady=function()return Startup.uiOpen and not quiesced and not disabled end,
    earlyEnvironment=function()
        if not Startup.uiOpen or quiesced or disabled then return end
        local instance=UE.GetGameInstance();if not valid(instance)or not UE.selectWorld65(instance) then return end
        local controller=UE.GetPlayerController();if not valid(controller)then return end
        local state=controller:GetPalPlayerState();if not valid(state)then return end
        return{controller=controller,status=state:IsPlayerDead()and'dead'or'alive'}
    end,
    environment=loadEnvironment,
    loadNativeClass=function(path)
        local o=StaticFindObject(path);if not valid(o)then local lib=UE.GetKismetSystemLibrary();o=UE.Native109(lib,'LoadClassAsset_Blocking',lib:Conv_SoftClassPathToSoftClassRef(lib:MakeSoftClassPath(path)))end;assert(valid(o));return o
    end})
phaseA.uiEntry=uiEntry;uiEntry:start()
UE.entryHold51=UE.dofileJ(base..'/entry_hold.lua')({valid=valid,epoch=function()return epoch end,log=log,timers=Timers})
UE.loadingCover51=UE.dofileJ(base..'/loading_cover.lua')({valid=valid,UE=UE,uiKit=uiKit,create=UE.createRawUI51,loadClass=loadWidgetClass,widgets=uiWidgets,dirt=function()return UE.loadingDirt51 end,log=log,resetReady=function()UE.sceneReady52=nil;UE.coverStable52=nil end})
Timers.coveredBudget=function()return Startup.open and UE.loadingCover51.at and not UE.leaving62 and 24 or nil end
UE.prespawnQ2=UE.dofileJ(base..'/native_prespawnQ2.lua')({valid=valid,log=log})
Timers.onEpoch('native-prespawn-Q2',function()UE.prespawnQ2:reset();UE.prespawnNextQ2=nil;UE.prespawnActiveQ2=nil end)
function UE.observePrespawnQ2()
    local cover=UE.loadingCover51
    if UE.leaving62 or worldReady or quiesced or disabled or not cover.preloaded then return end
    if os.clock()<(UE.prespawnNextQ2 or 0)then return UE.prespawnActiveQ2 end
    UE.prespawnNextQ2=os.clock()+.25
    local pc=UE.GetPlayerController();if not valid(pc)then return end
    local w=pc:GetWorld();if not valid(w)or not w:GetFullName():find('MainWorld',1,true)then return end
    local status=pawnReadiness(pc,valid)
    local native=UE.prespawnQ2:inspect(pc,status)
    UE.prespawnActiveQ2=native
    if native then cover:suspendForSetupQ2(native)
    elseif status=='alive'and valid(pc.Pawn)then cover:resumeAfterSetupQ2()end
    return native
end

Timers.loop(100,function()
    if not Startup:bootstrapAllowed()then return false end
    Startup.coverWork=true
    local ok,err=xpcall(function()
        local gi=UE.GetGameInstance();assert(valid(gi),'Cover GameInstance absent')
        UE.loadingDirt51=UE.texRuntime:load('textures/block/dirt.png',nil);if valid(UE.loadingDirt51)then uiEntry:retain(UE.loadingDirt51)end
        local function loader(path)local o=StaticFindObject(path);if not valid(o)then local lib=UE.GetKismetSystemLibrary();o=UE.Native109(lib,'LoadClassAsset_Blocking',lib:Conv_SoftClassPathToSoftClassRef(lib:MakeSoftClassPath(path)))end;assert(valid(o));return o end
        UE.loadingCover51:preload(function(o)uiEntry:retain(o)end,loader,base)
        uiEntry:retain(loader('/Game/Pal/Blueprint/UI/Title/WBP_TitleLocalWorldSelect.WBP_TitleLocalWorldSelect_C'))
        Timers.hook('/Game/Pal/Blueprint/UI/Title/WBP_TitleLocalWorldSelect.WBP_TitleLocalWorldSelect_C:OnClickedStartWorldButtonEventInternal',function()UE.loadingCover51:arm()end)
        UE.frontG=UE.dofileJ(base..'/front_endG.lua')({valid=valid,cover=UE.loadingCover51,log=log})
        UE.loadingCover51.preloaded=true;log('MC63_LOADING_PRELOAD_READY cover_only=true gameplay_fence_unchanged=true')
    end,debug.traceback)
    Startup.coverWork=nil;if not ok then error(err)end;return true
end,'loading-cover-preload')
Timers.loop(1,function()
    if not UE.loadingCover51.preloaded or not Startup:bootstrapAllowed()then return false end
    if not(UE.packFlags:has('hud_skins')and UE.packFlags:has('islands_animals'))then return true end
    Startup.coverWork=true
    local ok,done=xpcall(function()return UE.texRuntime:preloadStep()end,debug.traceback)
    Startup.coverWork=nil;if not ok then error(done)end;return done
end,'loading-cover-preload')
Timers.frame('loading-cover-display',function()
    local cover=UE.loadingCover51
    if cover.preloaded and UE.frontG and(not Startup.open or UE.leaving62)then
        local ok,released=pcall(UE.frontG.tick,UE.frontG,UE.leaving62)
        if ok and released then UE.leaving62=false
        elseif not ok and not UE.frontG.warnedTick then UE.frontG.warnedTick=true;log('MCG_TITLE_TICK_REJECT '..tostring(released))end
    end
    if not cover.preloaded or not cover.armed or quiesced or disabled then return end
    UE.observePrespawnQ2()
    
    cover:display()
end)
Timers.onEpoch('loading-cover',function(_,reason)if reason=='client-restart'then UE.loadingCover51:arm()end end)
function UE.earlyEnvironment51()
    UE.earlyGameplay51=nil
    if not uiEntry.ready or quiesced or disabled or(transitioning and not UE.allowEntry51)then return end
    if Startup.open and worldReady and not transitioning then local e=environment();if e then UE.earlyGameplay51=true;return e end end
    local gi=UE.GetGameInstance();if not valid(gi)or not UE.selectWorld65(gi) then return end
    local controller=UE.GetPlayerController();if not valid(controller)then return end
    local status,player=pawnReadiness(controller,valid)
    if status~='alive'then return end
    local world=controller:GetWorld();if not valid(world)then return end
    local e={world=world,player=player,controller=controller,status=status,identity=world:GetFullName()..'@'..world:GetAddress()}
    UE.earlyGameplay51=true
    return e
end
Timers.frame('entry-loading',function()
    if not Startup.open or UE.leaving62 then return end
    if Timers.test54 and Timers.test54.entry==false then return end

    if session and worldReady and not restoring and not UE.loadingCover51.armed and not UE.loadingCover51.at and not UE.entryHold51.active and not UE.entryHold51.inputPending then return end
    if uiEntry.ready and UE.loadingCover51.armed and not quiesced and not disabled then UE.loadingCover51:show({player=UE.GetGameInstance()})end

    if uiEntry.ready and not quiesced and not disabled and(not transitioning or UE.allowEntry51)then
        local gi=UE.GetGameInstance()
        if valid(gi)and UE.selectWorld65(gi) then
            local pc=UE.GetPlayerController()
            if valid(pc)then
                local w=pc:GetWorld();local state=pc:GetPalPlayerState()
                if valid(w)and w:GetFullName():find('/Game/Pal/Maps/MainWorld_5/',1,true)and(not valid(state)or not state:IsPlayerDead())then
                    local identity=w:GetFullName()..'@'..w:GetAddress()
                    if session~=identity or restoring then UE.loadingCover51:show({player=pc,controller=pc,world=w,identity=identity,status='loading'})end
                end
            end
        end
    end
    if UE.loadingCover51.at or UE.loadingCover51.armed then
        local observed=loadEnvironment()
        if observed and observed.status=='dead'then
            UE.entryHold51:forget();phaseA:setLife('dead');deathScreen:observe(observed)
            UE.loadingCover51:releaseForDeath();return
        end
    end
    local e=UE.earlyEnvironment51();if not e then return end
    if not UE.resumePawn78 then steve:early(e)end
    if session~=e.identity then

        UE.loadingCover51:show(e);steve:early(e)
        Startup.probing=true;transitioning=false;init(e)
    elseif restoring then UE.loadingCover51:show(e);steve:early(e)
    elseif UE.loadingCover51.at and not(UE.waystones83 and UE.waystones83.busy)then
            local release,reason=UE.coverRelease78.ready({alive=e.status=='alive',controlled=valid(e.controller.Pawn),hudReady=phaseA:ready78(e),seconds=os.clock()-UE.loadingCover51.at,sceneReady=UE.sceneReady52 and UE.uiCache51.ready and(not island or island:nearbyReady(e)),held=UE.entryHold51.active})
        if release and UE.sceneReady52 and(not island or island:nearbyReady(e))and UE.restoreReady109(e.player:K2_GetActorLocation())and UE.sceneRenderedM(e)and(config.steve==false or steve.state and steve.state.epoch==epoch and steve.state.player==e.player:GetAddress()and valid(steve.mesh))then
            if reason=='alive-hud-timeout15s'and not UE.loadingCover51.safety78 then
                UE.loadingCover51.safety78=true;UE.entryHold51:release(e,reason);log('MC78_COVER_SAFETY_RELEASE alive=true controlled=true hud=true')
            end
            UE.coverStable52=UE.coverStable52 or os.clock();if os.clock()-UE.coverStable52>.10 then e.controller.PlayerCameraManager:StopCameraFade();UE.loadingCover51:hide()end
        else UE.coverStable52=nil end
    end
    UE.entryHold51:tick(e)
    if not UE.loadingCover51.at then
        UE.entryHold51:finish(e)
        if UE.hotbarPrimedM~=epoch and gameplayInput(e)then
            phaseA:select(phaseA.selected or 5);phaseA:updateHotbar(e)
            UE.hotbarPrimedM=epoch;log('MCM_HOTBAR_PRIMED epoch='..epoch..' gameplay_input=true')
        end
    end
end)
if config.test_mode then (function()return nil end)()end
local task36=config.test_mode and (function()return nil end)()
local mobs=UE.packServices.disabledMobs()
if UE.packFlags:has('islands_animals')then
mobs=UE.dofileJ(base..'/mobs.lua')({base=base,config=config,world=WORLD,UE=UE,valid=valid,log=log,environment=environment,epoch=function()return epoch end,quiesced=function()return quiesced or transitioning end,ready=function()return worldReady and not restoring end,retain=function(o)phaseA.uiEntry:retain(o)end,gameplayInput=gameplayInput,
 combatInput=function(env)
  if not env or env.controller.bShowMouseCursor or phaseB.open or phaseD.open then return false end
  if env.player.CharacterParameterComponent:GetIndividualParameter():IsDead()then return false end
  local builder=env.builder;if not valid(builder)then builder=env.player:GetComponentByClass(UE.Object('/Script/Pal.PalBuilderComponent'))end
  if valid(builder)and builder:IsInBuildingMode()then return false end
  
  return not UE.Object('/Script/Pal.Default__PalUIUtility'):IsToggleBuildMode(env.player)
 end,mechanics=mechanics,phaseC=phaseC,items=phaseB,cells=function()return cells end,key=key,registry=registry})
end
UE.effects66=UE.dofileJ(base..'/particles73.lua')({base=base,UE=UE,valid=valid,log=log,registry=registry,types=typeByName,epoch=function()return epoch end,ready=function()return worldReady and not restoring and not transitioning and not quiesced end,retain=function(o)uiEntry:retain(o)end})
UE.zombie77=UE.packFlags:has('islands_animals')and UE.dofileJ(base..'/zombie77.lua')({base=base,UE=UE,island=island,types=typeByName,valid=valid,log=log,environment=environment,sound=phaseC,retain=function(o)uiEntry:retain(o)end,ready=function()return Startup.open and worldReady and not restoring and not transitioning and not quiesced and not UE.resumePawn78 and not UE.leaving62 end})
local task41=config.test_mode and (function()return nil end)()
UE.task59=config.test_mode and (function()return nil end)()
UE.task60=config.test_mode and (function()return nil end)()
UE.task61=config.test_mode and (function()return nil end)()
UE.task64=config.test_mode and (function()return nil end)()
UE.task65=config.test_mode and (function()return nil end)()
UE.task70=config.test_mode and (function()return nil end)()
UE.task71=config.test_mode and (function()return nil end)()
UE.task72=config.test_mode and (function()return nil end)()
UE.task91=config.test_mode and (function()return nil end)()
UE.task104=config.test_mode and (function()return nil end)()
UE.customPalsA=UE.packFlags:has('islands_animals')and UE.dofileJ(base..'/custom_palsA.lua')({base=base,UE=UE,valid=valid,log=log,island=island,environment=environment,ready=function()return Startup.open and worldReady and not restoring and not transitioning and not quiesced and not UE.leaving62 end})
UE.task92=config.test_mode and (function()return nil end)()
UE.task74=config.test_mode and (function()return nil end)()
UE.task73=config.test_mode and (function()return nil end)()
UE.waystones83=UE.packFlags:has('islands_animals')and UE.dofileJ(base..'/waystones83.lua')({base=base,UE=UE,valid=valid,log=log,uiKit=uiKit,items=phaseB,menu=phaseD,beds=beds,island=island,routes=task31,environment=environment,epoch=function()return epoch end,ready=function()return worldReady and not restoring and not transitioning and island:nearbyReady(environment()) end,gameplayInput=gameplayInput,create=UE.createRawUI51,widgets=uiWidgets})
UE.follow86=UE.packFlags:has('islands_animals')and UE.dofileJ(base..'/follow86.lua')({base=base,UE=UE,valid=valid,log=log,cells=function()return cells end,key=key,island=island,combat=mobs.combat,environment=environment,epoch=function()return epoch end,ready=function()return Startup.open and worldReady and not restoring and not transitioning and not quiesced and not UE.resumePawn78 and not UE.leaving62 and island:nearbyReady(environment()) end})
UE.loot88=UE.packFlags:has('islands_animals')and UE.dofileJ(base..'/loot88.lua')({base=base,UE=UE,valid=valid,log=log,items=phaseB,ui=uiKit,island=island,environment=environment,gameplayInput=gameplayInput,ready=function()return Startup.open and worldReady and not restoring and not transitioning and not quiesced and not UE.resumePawn78 and not UE.leaving62 and island:nearbyReady(environment()) end})

UE.map111=UE.packFlags:has('islands_animals')and UE.dofileJ(base..'/map111.lua')({base=base,enabled=true,world=function()return WORLD end,UE=UE,valid=valid,log=log,beds=beds,island=island,items=phaseB,environment=environment,epoch=function()return epoch end,ready=function()return Startup.open and UE.sceneReady52 and worldReady and not restoring and not transitioning and not quiesced and not UE.restartPending65b and not UE.resumePawn78 and not UE.leaving62 end})
UE.task83=config.test_mode and (function()return nil end)()
UE.alexTrade=UE.packFlags:has('islands_animals')and UE.dofileJ(base..'/alex_trade.lua')({base=base,UE=UE,valid=valid,log=log,uiKit=uiKit,items=phaseB,phaseA=phaseA,menu=phaseD,environment=environment,epoch=function()return epoch end,create=UE.createRawUI51,widgets=uiWidgets,inRange=function(env)return UE.sliceX8 and UE.sliceX8:inRange(env)or(not UE.sliceX8 and UE.alex and UE.alex.p and UE.alex:distance(env)<=300)end})
UE.alex=UE.packFlags:has('islands_animals')and UE.dofileJ(base..'/alex.lua')({base=base,UE=UE,valid=valid,log=log,registry=registry,types=typeByName,environment=environment,epoch=function()return epoch end,ready=function()return Startup.open and worldReady and not restoring and not transitioning and not quiesced and not UE.leaving62 end,retain=function(o)uiEntry:retain(o)end,gameplayInput=gameplayInput,trade=UE.alexTrade})
UE.sliceX8=UE.packFlags:has('islands_animals')and UE.dofileJ(base..'/slice_npcs_x8.lua')({base=base,UE=UE,valid=valid,log=log,registry=registry,types=typeByName,island=island,ui=uiKit,environment=environment,epoch=function()return epoch end,ready=function()return Startup.open and worldReady and not restoring and not transitioning and not quiesced and not UE.leaving62 end,retain=function(o)uiEntry:retain(o)end,gameplayInput=gameplayInput})
UE.taskFB=config.test_mode and (function()return nil end)()
UE.task62=config.test_mode and (function()return nil end)()
local task47=config.test_mode and (function()return nil end)()
if task47 then task47.task48=config.test_mode and (function()return nil end)() end
local task44=(config.test_mode and (function()return nil end)())or{}
UE.task54=config.test_mode and (function()return nil end)()
UE.task57=config.test_mode and (function()return nil end)()
task44.input=UE.dofileJ(base..'/input_layout.lua')({base=base,UE=UE,valid=valid,log=log,active=active,environment=environment,ready=function()return uiEntry:scoped()end,phaseA=phaseA,items=phaseB,phaseD=phaseD,gameplayInput=gameplayInput})
uiEntry.input=task44.input
task44.task49=config.test_mode and (function()return nil end)()
task44.task50=config.test_mode and (function()return nil end)()
local task37=config.test_mode and (function()return nil end)()
local titleOverlay=UE.dofileJ(base..'/title_overlay.lua')({base=base,valid=valid,log=log,UE=UE,widgets=uiWidgets,uiKit=uiKit,environment=environment,world=WORLD})
startupJobs[#startupJobs+1]=function()titleOverlay:install()end
local task17=config.test_mode and (function()return nil end)()
UE.worldIdentityQ3=UE.dofileJ(base..'/world_identityQ3.lua')({UE=UE,valid=valid,log=log,validId=function(id)return UE.worldScope65:valid(id)end})

function UE.selectWorld65(instance)
    local raw=str(instance:GetSelectedWorldSaveDirectoryName());local id=raw:upper()
    if raw==''then id=session and UE.worldIdentityQ3.epoch==epoch and UE.worldIdentityQ3.id or UE.worldIdentityQ3:resolve(instance,epoch)end
    if UE.worldResolveRaw65b~=raw or UE.worldResolveEpoch65b~=epoch then
        UE.worldResolveRaw65b=raw;UE.worldResolveEpoch65b=epoch
        log('MC65B_WORLD_RESOLVE raw='..string.format('%q',raw)..' length='..#raw..' valid='..tostring(UE.worldScope65:valid(id))..' canChange='..tostring(transitioning or session==nil)..' epoch='..epoch..' instance='..instance:GetFullName())
    end
    if id==UE.worldScope65.id then return true end
    return UE.worldScope65:select(id,transitioning or session==nil,function(selected,previous)
        assert(not session,'World switch before lifecycle quiescence')
        mechanicsWriter:cancel();WORLD=selected
        path=UE.worldScope65:path('blocks');pendingPath=UE.worldScope65:path('inventory-pending')
        cells={};entities={};entityClock=0;resourceState=ResourceState.empty();sequence=0
        inventoryTransaction=nil;inventoryTransactionsReady=true;dirtGranted=false;testGranted=false;selectedType=1
        phaseB:setWorld(selected);beds:setWorld(selected)
        resources.job=nil;resources.last=nil;resources.scan=1
        phaseA.selected=5;config.debug=config.test_mode and UE.worldScope65:testsAllowed()
        Timers.breadcrumbPath=UE.worldScope65:path('lifecycle-breadcrumbs','.txt')
        log('MC65_WORLD_BOUND '..selected..' previous='..tostring(previous)..' tests='..tostring(config.debug))
    end)
end
bind(Key.K,function()phaseD:request('Pals')end,true)
bind(Key.T,function()phaseD:nativeShortcut('Technology')end)
bind(Key.P,function()phaseD:nativeShortcut('Palpedia')end)
for i=1,9 do local slot=i;bind(0x30+i,function()
    if phaseB and phaseB.open then phaseB:assignHovered(slot)end
end,true)end
bind(Key.G,function()phaseA:cycle()end)

UE.controls68.mobs=mobs
Timers.key(Key.LEFT_MOUSE_BUTTON,function()
    local pressedAt=os.clock();local swing=mobs:captureSwing(pressedAt)
    Timers.deferInput(function()
        if valid(titleOverlay.widget)then local ok,err=pcall(titleOverlay.click,titleOverlay);if not ok then titleOverlay:close();log('MC_H_TITLE_SKIP '..tostring(err))end
        elseif UE.waystones83 and UE.waystones83.open then UE.waystones83:click()
        elseif UE.alexTrade and UE.alexTrade.open then UE.alexTrade:click(false)
        elseif deathScreen and deathScreen.open then deathScreen:click()
        else safe(function()local env=environment();if not env then return end;if phaseD.open then phaseD:click()elseif phaseB and phaseB.open then phaseB:click(false)else local handled=UE.controls68:hit(env,pressedAt,swing);if handled==nil then handled=mobs:hit(env,pressedAt,swing)end;if not handled then phaseA:beginMining()end end end,nil,nil,true)end
    end)
end)
bind(Key.RIGHT_MOUSE_BUTTON,function()if phaseD.open then phaseD:click(false,true)elseif phaseB and phaseB.open then phaseB:click(true)else phaseA:place()end end,true)
bind(Key.LEFT_MOUSE_BUTTON,function()if UE.waystones83 and UE.waystones83.open then UE.waystones83:click()elseif UE.alexTrade and UE.alexTrade.open then UE.alexTrade:click(true)elseif phaseD.open then phaseD:click(true)elseif phaseB and phaseB.open then phaseB:click(false,true)else phaseA:beginMining()end end,true,{ModifierKey.SHIFT})
bind(Key.RIGHT_MOUSE_BUTTON,function()if phaseD.open then phaseD:click(true,true)elseif phaseB and phaseB.open then phaseB:click(true,true)else phaseA:place()end end,true,{ModifierKey.SHIFT})
if phaseB then

    bind(Key.Q,function()if phaseB.open then phaseB:drop()end end,true)
    if config.legacy_debug_keys then bind(Key.F18,function()phaseB:grantTest()end)end
    if config.legacy_debug_keys then bind(Key.F20,function()phaseB:snapshot()end,true)end
end
bind(Key.UP_ARROW,function()task44.input:party(1)end)
bind(Key.RIGHT_ARROW,function()task44.input:party(1)end)
bind(Key.DOWN_ARROW,function()task44.input:party(-1)end)
bind(Key.LEFT_ARROW,function()task44.input:party(-1)end)
bind(Key.R,function()task44.input:party(1)end)
bind(Key[config.steve_perspective_key or 'F5'],function()local env=active();if steve.enabled and gameplayInput(env)then steve:perspective(env,not steve.requestedFirstPerson);log('MC27_PERSPECTIVE_TOGGLE first_person='..tostring(steve.requestedFirstPerson))end end,true)

for _,name in ipairs({'OnUpdateInventoryContainer','OnUpdateEssentialContainer'}) do
    local fn='/Script/Pal.PalPlayerInventoryData:'..name
    local pre,post=Timers.hook(fn,function()end,function()
        if config.timer_trace then log('MC_INVENTORY_CHANGED_ENTER owner='..name)end
        if quiesced or transitioning then if config.timer_trace then log('MC_INVENTORY_CHANGED_EXIT owner='..name..' transition=true')end;return end
        if phaseB then phaseB.dirty=true end
        if uiUpdatePending then if config.timer_trace then log('MC_INVENTORY_CHANGED_EXIT owner='..name..' pending=true')end;return end
        uiUpdatePending=true;local stamp=epoch
        Timers.defer(function()
            if config.timer_trace then log('MC_INVENTORY_REFRESH_ENTER owner='..name)end
            uiUpdatePending=false;if quiesced or transitioning or stamp~=epoch then if config.timer_trace then log('MC_INVENTORY_REFRESH_EXIT owner='..name..' transition=true')end;return end
            local env=environment();if env then local ok,err=pcall(function()updateHotbar(env);if phaseC then phaseC:inventoryUpdated(env)end end);if not ok then log('HOTBAR_UPDATE_FAIL '..tostring(err))end end
            if config.timer_trace then log('MC_INVENTORY_REFRESH_EXIT owner='..name)end
        end)
        if config.timer_trace then log('MC_INVENTORY_CHANGED_EXIT owner='..name)end
    end)
    uiInventoryHooks[#uiInventoryHooks+1]={fn=fn,pre=pre,post=post}
end

beginTransition=function(reason,cleanup,env)

    if reason=='own-save-quit'and not transitioning and UE.map111 then UE.map111:beforeExit(env)end
    UE.leaving62=reason=='own-save-quit'
    UE.sceneReady52=nil
    UE.coverStable52=nil
    UE.allowEntry51=reason=='client-restart'
    if reason=='client-restart'or reason=='native-return-title'or reason=='native-boundary-fault'then

        if transitioning and reason~='native-boundary-fault'then return end
        transitioning=true;epoch=epoch+1;worldReady=false
        for _,h in ipairs({liveHandle or false,restoreHandle or false,diagnostic and diagnostic.handle or false,inventoryTransaction and inventoryTransaction.handle or false})do if h then Timers.cancel(h)end end

        local saved,saveError=true,nil
        if session and reason~='native-boundary-fault'then if phaseC then entityClock=phaseC.cachedClock end;saved,saveError=pcall(save)end
        liveHandle=nil;restoreHandle=nil;diagnostic=nil;preview=nil;chunks={};chunkActors={};cells={};meshCache={};deferred={};session=nil;ui=nil;uiUpdatePending=false;restoring=false;busy=false
        Timers.advanceEpoch(epoch,reason);log('MC_WORLD_EPOCH '..epoch..' '..reason..' wrappers_forget_only=true')
        if not saved then log('MC_TRANSITION_SAVE_ERROR '..tostring(saveError))end
        log('MAP_TRANSITION_TIMERS_CANCELLED epoch='..epoch);return
    end
    UE.uiCache51:retire()
    if transitioning then return end
    if reason=='own-save-quit'and beds then beds:recordEntry(env)end
    if reason=='own-save-quit'and UE.zombie77 then UE.zombie77:hideAll()end
    if UE.entryHold51 then UE.entryHold51:release(env,'transition');UE.entryHold51:finish(env)end;if UE.loadingCover51 and reason~='own-save-quit'then UE.loadingCover51:forget()end
    if steve then steve:clear(env,reason=='own-save-quit'and env~=nil)end
    transitioning=true;epoch=epoch+1
    log('MC_E_TRANSITION_BEGIN reason='..reason..' epoch='..epoch)
    for _,h in ipairs({liveHandle or false,restoreHandle or false,
        diagnostic and diagnostic.handle or false,inventoryTransaction and inventoryTransaction.handle or false})do
        if h then Timers.cancel(h)end
    end
    liveHandle=nil;restoreHandle=nil;diagnostic=nil
    if session then if phaseC then entityClock=phaseC.cachedClock end;save()end
    if cleanup then
        if phaseD then phaseD:teardown(env)end
        if phaseB then phaseB:teardown(env)end
        if phaseA then phaseA:teardown(env)end
        if phaseC then phaseC:cancel(false)end
        if preview and valid(preview.actor)then preview.actor:K2_DestroyActor()end
        if ui and valid(ui.widget)then ui.widget:RemoveFromParent()end
        log('MC_E_TRANSITION_TEARDOWN widgets=0 capture=0 held=0 armor=0 lights=0 chunks=0')
    else
        if phaseA then phaseA:retireViewport(env)end;if phaseB then phaseB:retireViewport()end;if phaseD then phaseD:retireViewport(env)end
        if phaseA then phaseA:cancel()end;if phaseB then phaseB:cancel()end
        if phaseC then phaseC:cancel(true)end;if phaseD then phaseD:cancel()end
    end
    preview=nil;chunks={};chunkActors={};cells={};meshCache={};deferred={};session=nil;ui=nil;uiUpdatePending=false;restoring=false
    Timers.advanceEpoch(epoch,reason);log('MC_WORLD_EPOCH '..epoch..' '..reason)
    if reason=='own-save-quit'then titleOverlay:schedule()end
    busy=false
    log('MAP_TRANSITION_TIMERS_CANCELLED epoch='..epoch)
end
Timers.onNativeFault=function(owner,message)
    
    quiesced=true;Timers.paused=true
    if beginTransition then beginTransition('native-boundary-fault',false)end
end

local nativeTitleHooked=false
local function hookNativeTitle()
    local fn='/Game/Pal/Blueprint/UI/UserInterface/ESCMenu/WBP_MenuESC.WBP_MenuESC_C:ConfirmReturnTitle'
    
    for _,w in ipairs(FindAllOf('WBP_MenuESC_C')or{})do if valid(w)then
        w:GetClass():ForEachFunction(function(f)if f:GetFullName():match(':ConfirmReturnTitle$')then fn=f:GetFullName():gsub('^Function ','')end end);break
    end end
    if config.bpHooks~=false and not nativeTitleHooked and valid(StaticFindObject(fn))then
        Timers.hook(fn,function(_,confirmed)
            if quiesced or transitioning then return end
            local ok,value=pcall(function()return confirmed:get()end);value=ok and value or confirmed
            if value==true then beginTransition('native-return-title',false);titleOverlay:schedule()end
        end);nativeTitleHooked=true;log('MC_E_NATIVE_TITLE_HOOK '..fn)
    end
end
readyAfterRestore=function(env)
    local expected=epoch;local started,paused=false,false;local resumedAt,resumedPawn;local queued109=os.clock();local stageZ3=0;local servicesStartedZ3
    log('MC109_SERVICES_QUEUED epoch='..expected)
    Timers.loop(1,function()
        if expected~=epoch or quiesced or transitioning then return true end
        local observed=loadEnvironment();if deathScreen then deathScreen:observe(observed)end
        if UE.resumePawn78 then paused=true end
        local current=environment(UE.resumePawn78==true)
        if not current then if started then paused=true end;resumedAt=nil;resumedPawn=nil;return false end
        if started and not paused then return false end
        if paused then
            if resumedPawn~=current.player:GetAddress()then resumedPawn=current.player:GetAddress();resumedAt=os.clock()end
            if os.clock()-resumedAt<3 then return false end
        end
        env=current
        servicesStartedZ3=servicesStartedZ3 or os.clock();local services109=servicesStartedZ3
        if stageZ3==0 then
        log(string.format('MC109_SERVICES_BEGIN wait_ms=%.3f',(services109-queued109)*1000))
        UE.resumingPawn78=true
        deathScreen:restoreAlive(env)
        if started then

            steve:clear(env,true);phaseA:retireViewport(env);phaseB:retireViewport();phaseD:retireViewport(env)
            phaseD.armor:cancel(true);phaseD:cancel();stopLiveTimer('alive-resume')
            log('MC28_ALIVE_RESUME chunks_preserved='..count(chunks))
        end
        beds:finishRespawn(env)
        if not started and beds:recoverEntry(env)and UE.entryHold51 then UE.entryHold51:rebaseOwnedFooting(env)end
        startLiveTimer(env)
                local navLibrary=UE.Object('/Script/NavigationSystem.Default__NavigationSystemV1')
                local navSystem=navLibrary:GetNavigationSystem(env.player)
                if valid(navSystem)then navSystem:RegisterNavigationInvoker(env.player,6000,8000);log('MC_PLAYER_NAV_INVOKER generation_cm=6000 removal_cm=8000')end
                signature('/Script/Pal.PalBuilderComponent:IsInBuildingMode',{'ReturnValue'})
                if config.discovery then
                    local good,err=pcall(function()(function()return nil end)()end)
                    if not good then log('NARROW_DISCOVERY_FAIL '..tostring(err))end
                end
                UE.entryPhasesK={};stageZ3=1;return false
        end
        local function startK(name,object)
         local at=os.clock();object:start(env);local ms=(os.clock()-at)*1000
         UE.entryPhasesK[#UE.entryPhasesK+1]={name=name,ms=ms};log(string.format('MCK_ENTRY_PHASE name=%s work_ms=%.3f',name,ms))
        end
        if stageZ3==1 then if phaseB then startK('inventory',phaseB)end;startK('ui-cache',UE.uiCache51)
        elseif stageZ3==2 then startK('steve',steve);startK('hud',phaseA)
        elseif stageZ3==3 then startK('stations',phaseC);startK('menus',phaseD)
        elseif stageZ3==4 then startK('mechanics',mechanics);if UE.retiredResource83 and UE.retiredResource83>0 then mechanics.dirty=true end;startK('beds',beds)
        elseif stageZ3==5 then if UE.packFlags:has('islands_animals')then startK('islands',island);startK('resources',resources);startK('mobs',mobs)end;startK('input',task44.input)
        else
                hookNativeTitle();log('AUTO_RESTORE_READY cells='..count(cells)..' deferred='..count(deferred))
                if steve.skinWarning71 then uiKit:notify('Skins','Saved skin unavailable: default loaded');steve.skinWarning71=nil end
                steve:tick(env);if UE.entryHold51 then UE.entryHold51:release(env,'world-ready')end;UE.sceneReady52=true
                UE.texRuntime:coverage('world-ready')
                if UE.resumePawn78 then
                    UE.resumePawn78=nil;if UE.lastPossession65b then UE.lastPossession65b.deathSeen=nil end
                    log('MC78_ALIVE_RESUME_READY epoch='..epoch..' chunks='..count(chunks))
                end
                log(string.format('MC109_SERVICES_READY work_ms=%.3f',(os.clock()-services109)*1000))
                UE.resumingPawn78=nil;started=true;paused=false;stageZ3=0;servicesStartedZ3=nil;return false
        end
        stageZ3=stageZ3+1;return false
    end,'alive-service-start')
end
function UE.restartWorld65b()
    if quiesced then return end
    if not transitioning then beginTransition('client-restart',false)end
    
    if restoreHandle then Timers.cancel(restoreHandle) end
    local stamp=epoch
    local attempts=0;local boot;local deadReady=false;local aliveSince,aliveAddress
    boot=function()
        restoreHandle=nil
        if quiesced or stamp~=epoch or disabled then return end
        if not Startup:bootstrapAllowed()then restoreHandle=Timers.after(500,boot,'startup-probe');return end
        Startup.probing=true
        local setupQ2=UE.observePrespawnQ2()
        local ready=loadEnvironment()
        if UE.loadingCover51.diagDisabledQ2 and(attempts==0 or attempts==19 or attempts==59 or attempts==119)then
            local pc=UE.GetPlayerController()
            local function describe(o)return valid(o)and o:GetFullName()or'nil'end
            log('MCQ2_NATIVE_STATE attempt='..attempts..' state='..tostring(ready and ready.status)..' controller='..describe(pc)..' pawn='..describe(valid(pc)and pc.Pawn)..' default='..describe(valid(pc)and pc:GetDefaultPlayerCharacter()))
            for _,w in ipairs(FindAllOf('UserWidget')or{})do if valid(w)and w:IsInViewport()then log('MCQ2_VIEWPORT class='..w:GetClass():GetFullName()..' visible='..tostring(w:IsVisible())..' opacity='..w:GetRenderOpacity()..' name='..w:GetFullName())end end
        end
        if setupQ2 or not ready or(ready.status~='alive'and ready.status~='dead')then
            aliveSince=nil;aliveAddress=nil
            attempts=attempts+1
            if attempts==1 or attempts==20 or attempts==120 then log('MC65B_ADMISSION_WAIT attempt='..attempts..' state='..tostring(ready and ready.status)..' selected='..tostring(UE.worldResolveRaw65b))end
            if attempts==121 then log('MCQ2_ADMISSION_CONTINUE waiting_for_native_setup_or_possession=true')end
            restoreHandle=Timers.after(attempts<=120 and 500 or 1000,boot,'startup-probe')
            return
        end
        if ready.status=='dead'then
            aliveSince=nil;aliveAddress=nil
            if not deadReady then

                restoreData();transitioning=false;deadReady=true;worldReady=true
                Startup:world(epoch,startupJobs,function()end)
                log('MC28_LOAD_DEFERRED state=dead native_death_ui_untouched=true')
                log('WORLD_READY '..WORLD..' cells='..count(cells)..' chunks=0 dead=true gameplay_deferred=true native_refs='..Timers.nativeRefCount)
            end
            if Startup.open then deathScreen:observe(ready)end
            restoreHandle=Timers.after(500,boot,'startup-probe');return
        end
        if Startup.open and deathScreen.open then deathScreen:close(ready)end

        if aliveAddress~=ready.playerAddress then aliveAddress=ready.playerAddress;aliveSince=os.clock();log('MCH_PAWN_READY_BEGIN address='..tostring(aliveAddress))end
        if os.clock()-aliveSince<.25 then restoreHandle=Timers.after(125,boot,'startup-probe');return end
        log(string.format('MCH_PAWN_READY_STABLE seconds=%.3f',os.clock()-aliveSince))
            local env=environment(true)
            if env then
                transitioning=false;init(env)
            else transitioning=true;log('AUTO_RESTORE_SKIP no_live_test_player') end
    end
    restoreHandle=Timers.after(250,boot,'startup-probe')
    log('AUTO_RESTORE_SCHEDULED delay_ms=250')
end

Timers.hook('/Script/Engine.PlayerController:ClientRestart',function()end,function()UE.restartPending65b=true;playerController=nil;UE.controllerScanAt109e=nil;environmentCache=nil;UE.environmentFrame=nil end)
Timers.frame('startup-probe',function()
    if not UE.restartPending65b or quiesced then return end
    if not Startup:bootstrapAllowed()then return end
    local old=UE.lastPossession65b;local same=false;local deathResume=false
    if UE.mount76 then UE.mount76:invalidate()end
    if old and Startup.open and not transitioning then
        local pc=UE.GetPlayerController()
        if valid(pc)then
            local w=pc:GetWorld()
            if valid(w)and w:GetAddress()==old.world and pc:GetAddress()==old.controller then
                local status,player=pawnReadiness(pc,valid)
                local level=w.PersistentLevel
                deathResume=worldReady and not restoring and session~=nil and valid(level)and UE.possession65b.sameLevelDeath(old,{epoch=epoch,world=w:GetAddress(),level=level:GetAddress(),controller=pc:GetAddress(),status=status})
                if deathResume then
                    same=true;UE.noteDeath78();log('MC78_POSSESSION_KEEP_LEVEL status='..tostring(status)..' epoch='..epoch..' chunks='..count(chunks))
                elseif status=='alive'and old.alive then
                    local pawn=pc.Pawn;local low=pc:GetLowBodyPawn()
                    local riding=pc:IsRiding()
                    same=UE.possession65b.sameRide(old,{epoch=epoch,world=w:GetAddress(),controller=pc:GetAddress(),player=player:GetAddress(),alive=true,riding=riding,mountPossessed=valid(pawn)and valid(low)and pawn:GetAddress()==low:GetAddress()and pawn:GetAddress()~=player:GetAddress()})
                    if same then old.riding=riding;log('MC65B_POSSESSION_KEEP epoch='..epoch..' riding='..tostring(riding)..' player='..old.player..' pawn='..tostring(valid(pawn)and pawn:GetAddress()))end
                end
            end
        end
    end
    UE.restartPending65b=nil;UE.environmentFrame=nil
    if phaseA.uiEntry then phaseA.uiEntry:bindCurrent()end
    if not same then

        UE.leaving62=false;UE.allowEntry51=true;UE.loadingCover51:arm()
        UE.restartWorld65b()
    elseif not deathResume and steve.state then

        local e=environment();if e then steve:maskNative(e)end
    end
end)
local function quiesce()
    assert(IsInGameThread(),'Quiesce must run on the game thread')
    quiesced=true;epoch=epoch+1
    phaseA:cancel()
    if phaseC then phaseC:cancel(true)end
    if phaseB then phaseB:cancel()end
    if phaseD then phaseD:cancel()end
    for _,handle in ipairs({liveHandle or false,restoreHandle or false,
        diagnostic and diagnostic.handle or false,inventoryTransaction and inventoryTransaction.handle or false}) do
        if handle then Timers.cancel(handle) end
    end
    liveHandle=nil;restoreHandle=nil;diagnostic=nil
    if ui and valid(ui.widget) then ui.widget:RemoveFromParent() end
    ui=nil
    uiInventoryHooks={}
    local ticks=0
    drainHandle=Timers.loop(50,function()
        
        ticks=ticks+1
        if ticks>=3 then
            drainHandle=nil
            log('QUIESCED ticks=3 owned_timers=0 reload_key=Ctrl+R');return true
        end
    end)
    log('QUIESCE_BEGIN')
end
if config.legacy_debug_keys then bind(Key.F10,quiesce,false,{ModifierKey.CONTROL}) end

startupJobs[#startupJobs+1]=function() signature('/Script/Engine.Actor:AddComponentByClass',{'Class','bManualAttachment','RelativeTransform','bDeferredFinish','ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.Actor:K2_GetRootComponent',{'ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.Actor:K2_GetActorLocation',{'ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.Actor:K2_DestroyActor',{}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.SceneComponent:SetMobility',{'NewMobility'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.StaticMeshComponent:SetStaticMesh',{'NewMesh','ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.PrimitiveComponent:SetMaterial',{'ElementIndex','Material'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.Actor:SetActorHiddenInGame',{'bNewHidden'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.PlayerController:ClientRestart',{'NewPawn'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.PrimitiveComponent:SetCollisionProfileName',{'InCollisionProfileName','bUpdateOverlaps'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.PrimitiveComponent:GetCollisionProfileName',{'ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.PrimitiveComponent:SetCollisionEnabled',{'NewType'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.PrimitiveComponent:GetCollisionEnabled',{'ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.Controller:SetControlRotation',{'NewRotation'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.GameplayStatics:BeginDeferredActorSpawnFromClass',{'WorldContextObject','ActorClass',
            'SpawnTransform','CollisionHandlingOverride','Owner','ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.GameplayStatics:FinishSpawningActor',{'Actor','SpawnTransform','ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.InstancedStaticMeshComponent:AddInstance',{'InstanceTransform','bWorldSpace','ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.InstancedStaticMeshComponent:GetInstanceCount',{'ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.InstancedStaticMeshComponent:ClearInstances',{}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.InstancedStaticMeshComponent:RemoveInstance',{'InstanceIndex','ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.Actor:K2_SetActorLocation',{'NewLocation','bSweep','SweepHitResult','bTeleport','ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.Controller:IsMoveInputIgnored',{'ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.CapsuleComponent:GetScaledCapsuleRadius',{'ReturnValue'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.CapsuleComponent:GetScaledCapsuleHalfHeight',{'ReturnValue'}) end
startupJobs[#startupJobs+1]=function() requireProperty('/Script/Engine.CharacterMovementComponent','MovementMode','ByteProperty') end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.CharacterMovementComponent:SetMovementMode',{'NewMovementMode','NewCustomMode'}) end
startupJobs[#startupJobs+1]=function() signature('/Script/Engine.KismetSystemLibrary:LineTraceSingle',{'WorldContextObject','Start','End','TraceChannel',
            'bTraceComplex','ActorsToIgnore','DrawDebugType','OutHit','bIgnoreSelf','TraceColor','TraceHitColor','DrawTime','ReturnValue'}) end
startupJobs[#startupJobs+1]=function()log('STARTUP_READY native Actor + ISM; after stable-pawn admission (no duplicate delay)')end
log('LOADED Phase A debug='..tostring(config.debug)..'; 1-9 items; wheel9 polling limited; arrows/R party; Q sphere; E summon; Y reload; U sphere-cycle; H commands; J extra-interact; F5 perspective; G block-cycle; reload OFF')

log('MC35_BOOTSTRAP_REGISTERED assets=0 native_lookups=0 initial_title=native')
log('MC109_ASSET_POLICY costume=first_host sound=first_play catalogs=first_open lua_LoadAssetAsync='..type(_G.LoadAssetAsync))
