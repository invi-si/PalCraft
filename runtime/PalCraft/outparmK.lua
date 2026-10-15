-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function()
 local indices={K2_SetRelativeLocation={3},K2_SetRelativeRotation={3},K2_SetWorldLocation={3},K2_SetWorldRotation={3},K2_SetRelativeTransform={3},K2_SetWorldTransform={3},K2_SetActorLocation={3},GetActorBounds={2,3},LineTraceSingle={8},CapsuleTraceSingle={10},BoxTraceSingle={10},SphereTraceSingleForObjects={9},GetAllActorsWithTag={3},GetAllActorsOfClass={3},GetInstanceTransform={2},K2_ProjectPointToNavigation={3}}
 indices['GetSlots']={1};indices['TryGetDynamicItemData']={1};indices['IsAnyMenuOpened']={1};indices['TryGetContainerFromInventoryType']={2};indices['GetLocalizedCharacterName']={2};indices['GetDisplayNickName']={4};indices['GetItemName']={3};indices['GetItemDescription']={3};indices['FindWazaForBP']={2};indices['GetRequiredMaterialInfos']={1};indices['GetDropItemData']={3};indices['TryGetConcreteModel']={1};indices['GetTechnologyIcon']={3};
 indices['CalcDamageCharacter']={4}
 local pools={};local depth=0;local stats={calls=0,buffers=0,maxDepth=0,releasedFields=0,errors=0}
 local function clear(t)for k in pairs(t)do t[k]=nil end end
 local function call(method,object,...)
  local slots=assert(indices[method]);local args=table.pack(...);local destinations={}
  depth=depth+1;assert(depth<=32,'OutParm nesting exceeds bound');stats.maxDepth=math.max(stats.maxDepth,depth)
  local group=pools[depth];if not group then group={};pools[depth]=group end
  for n,index in ipairs(slots)do
   assert(type(args[index])=='table','OutParm destination must be table: '..method)
   destinations[n]=args[index]
   local buffer=group[n];if not buffer then buffer={};group[n]=buffer;stats.buffers=stats.buffers+1 end
   clear(buffer);args[index]=buffer
  end
  local sample=_G.MC_REGISTRY_SAMPLE_L
  if sample and os.clock()>sample.untilAt then sample=nil end
  local before=sample and rawlen(debug.getregistry())
  local result=table.pack(pcall(object[method],object,table.unpack(args,1,args.n)))
  if sample then
   local info=debug.getinfo(2,'Sl');local key=info.short_src..':'..info.currentline..':'..method
   local row=sample.sites[key]or{calls=0,registryGrowth=0,outputSlots=#slots};sample.sites[key]=row
   row.calls=row.calls+1;row.registryGrowth=row.registryGrowth+rawlen(debug.getregistry())-before
  end
  for n,index in ipairs(slots)do
   local buffer=args[index]
   if result[1]then for k,value in pairs(buffer)do destinations[n][k]=value;stats.releasedFields=stats.releasedFields+1 end end
   clear(buffer);args[index]=nil;destinations[n]=nil
  end
  depth=depth-1;stats.calls=stats.calls+1
  if not result[1]then stats.errors=stats.errors+1;error(result[2],0)end
  return table.unpack(result,2,result.n)
 end
 return call,stats
end
