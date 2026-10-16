-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(options)
 local base,flags=options.base,options.flags
 assert(flags:has('islands_animals')and not flags:has('hud_skins'))
 local UE={packFlags=flags};local retained={};local current;local epoch=0
 local restart=false;local candidateController,gameInstance;local scanAt=0
 local function valid(o)
  if type(o)~='userdata'then return false end
  local ok,live=pcall(function()return o:IsValid()end);return ok and live==true
 end
 local function admitted()return not restart and current~=nil and current.epoch==epoch end
 local function log(s)print('[PalCraft] '..tostring(s)..'\n')end
 local function load(name)return dofile(base..'/'..name..'.lua')end
 local T=load('timers');local readyPawn=load('pawn_readiness')
 UE.worldScope65=load('world_scope')(base)
 UE.worldIdentityQ3=load('world_identityQ3')({UE=UE,valid=valid,log=log,validId=function(id)return UE.worldScope65:valid(id)end})
 UE.restorePlanner109=load('restore109')
 _G.MC_OUT_K,UE.outparmK=load('outparmK')()
 function UE.Object(path)return StaticFindObject(path)end
 function UE.FindOrAddFName(name)
  local n=FName(name,EFindName.FNAME_Find)
  return n==NAME_None and FName(name,EFindName.FNAME_Add)or n
 end
 function UE.Native109(o,method,...)return o[method](o,...)end
 function UE.GetAsset109(o,data)return o:GetAsset(data)end
 function UE.GetKismetSystemLibrary()return UE.Object('/Script/Engine.Default__KismetSystemLibrary')end
 function UE.GetKismetTextLibrary()return UE.Object('/Script/Engine.Default__KismetTextLibrary')end
 function UE.GetPlayerController()return admitted()and current.controller or candidateController end
 function UE.GetGameInstance()
  if not valid(gameInstance)then gameInstance=FindFirstOf('GameInstance')end
  return gameInstance
 end
 local config=flags:apply(load('config'))
 config.debug=false;config.test_mode=false
 UE.language57=load('language')({base=base,UE=UE,valid=valid})
 local ctx={base=base,flags=flags,UE=UE,config=config,valid=valid,log=log,
  epoch=function()return epoch end,environment=function()return admitted()and current or nil end,
  active=function()assert(admitted(),'No admitted living player');return current end,
  quiesced=function()return not admitted()end,ready=admitted,
  retain=function(o)
   if not valid(o)then return end
   local id=o:GetAddress();if retained[id]then return end
   local gi=UE.GetGameInstance();if not valid(gi)then return end
   local refs={};local present=false
   gi.ReferencedObjects:ForEach(function(_,v)local ref=v:get();if valid(ref)then refs[#refs+1]=ref;if ref:GetAddress()==id then present=true end end end)
   if not present then refs[#refs+1]=o;gi.ReferencedObjects=refs end
   retained[id]=true
  end,
  streamReady=function(e)
   local lib=UE.Object('/Script/Engine.Default__SubsystemBlueprintLibrary')
   local partition=lib:GetWorldSubsystem(e.world,UE.Object('/Script/Engine.WorldPartitionSubsystem'))
   return not valid(partition)or partition:IsAllStreamingCompleted()
  end,
  gameplayInput=function(e)return e and not e.controller.bShowMouseCursor and not e.controller:IsMoveInputIgnored()end}

 UE.texRuntime=load('tex_runtime')({base=base,UE=UE,valid=valid,log=log,timers=T})
 UE.texRuntime:install()
 ctx.registry=load('registry');ctx.types={}
 for i,row in ipairs(ctx.registry)do ctx.types[row.name]=i end
 ctx.key=function(x,y,z)return string.format('%d,%d,%d',x,y,z)end
 ctx.cells=function()return{}end
 ctx.items=load('native_items')(ctx)
 
 ctx.sound=load('phase_c')(ctx)
 local function factory(name)return load(name)(ctx)end
 ctx.island=factory('islands88');UE.island=ctx.island
 UE.zombie77=factory('zombie77')
 UE.nativeArrowsVD=factory('native_arrowsVD')
 UE.customPalsA=factory('custom_palsA')
 UE.alexTrade=factory('native_trade');ctx.trade=UE.alexTrade
 ctx.ui={notify=function(_,title,text)UE.alexTrade:notice(title..': '..text)end}
 UE.alex=factory('alex');UE.sliceX8=factory('slice_npcs_x8')
 UE.map111=load('map111')({base=base,enabled=true,UE=UE,valid=valid,log=log,
  island=ctx.island,world=function()return UE.worldScope65.id end,
  environment=ctx.environment,epoch=ctx.epoch,ready=ctx.ready})
 local worldAddress,levelAddress,playerAddress;local stableAt;local started=false;local deadSeen=false
 T.admission=function(owner)return owner=='startup-probe'or admitted()end
 T.onEpoch('palcraft-native',function()
  retained={};current=nil;candidateController=nil;gameInstance=nil;scanAt=0;started=false
  stableAt=nil;playerAddress=nil
 end)
 local function leaveWorld(reason)
  current=nil;candidateController=nil;stableAt=nil;playerAddress=nil
  if worldAddress then
   worldAddress=nil;levelAddress=nil;deadSeen=false
   epoch=epoch+1;T.advanceEpoch(epoch,reason)
  end
 end
 T.hook('/Script/Engine.PlayerController:ClientRestart',function()end,function()restart=true end)

 T.frame('startup-probe',function()
  if restart then current=nil;candidateController=nil;scanAt=0;stableAt=nil;restart=false end
  local controller=candidateController
  if not valid(controller)then
   controller=nil;candidateController=nil
   if os.clock()<scanAt then leaveWorld('native-controller-lost');return end
   scanAt=os.clock()+.25
   local cls=StaticFindObject('/Script/Pal.PalPlayerController')
   if valid(cls)then for _,c in ipairs(FindAllOf('PlayerController')or{})do
    if valid(c)and c:IsA(cls)and c:IsLocalPlayerController()then controller=c;break end
   end end
  end
  local world=valid(controller)and controller:GetWorld()
  local level=valid(world)and world.PersistentLevel

  if not valid(world)or not valid(level)or not world:GetFullName():find('/Game/Pal/Maps/MainWorld_5/',1,true)then
   leaveWorld('native-world-left');return
  end
  local instance=UE.GetGameInstance()
  if not valid(instance)then leaveWorld('native-instance-lost');return end
  local address=world:GetAddress();local lid=level:GetAddress()
  if worldAddress and(address~=worldAddress or lid~=levelAddress)then
   epoch=epoch+1;T.advanceEpoch(epoch,'native-world-change');stableAt=nil
  end
  worldAddress=address;levelAddress=lid;candidateController=controller
  local raw=instance:GetSelectedWorldSaveDirectoryName()
  if type(raw)~='string'then
   local ok,value=pcall(function()return raw and raw:ToString()end)
   raw=ok and type(value)=='string'and value or''
  end
  local id=raw:upper();if id==''then id=UE.worldIdentityQ3:resolve(instance,epoch)end
  if not UE.worldScope65:valid(id)then current=nil;stableAt=nil;return end
  local status,player,state=readyPawn(controller,valid)
  if status~='alive'or not valid(player)then
   if started then deadSeen=true end
   current=nil;stableAt=nil;return false
  end
  if deadSeen then epoch=epoch+1;T.advanceEpoch(epoch,'native-alive-resume');deadSeen=false;stableAt=nil end
  if UE.worldScope65.id~=id then
   if UE.worldScope65.id then epoch=epoch+1;T.advanceEpoch(epoch,'native-save-change')end
   UE.worldScope65:select(id,true,function()end);started=false
  end
  local pid=player:GetAddress()
  if pid~=playerAddress then playerAddress=pid;stableAt=os.clock()end
  stableAt=stableAt or os.clock();if os.clock()-stableAt<.75 then current=nil;return false end
  current={world=world,controller=controller,player=player,state=state,status='alive',epoch=epoch}
  if not started then ctx.island:start(current);UE.alex:start(current);started=true;UE.texRuntime:coverage('world-ready');log('NATIVE_PACK_READY native_hud=true native_controls=true')end
  return false
 end)

 T.key(Key.F,function()T.deferInput(function()if current and ctx.gameplayInput(current)then UE.sliceX8.input=true end end)end)
 return UE
end
