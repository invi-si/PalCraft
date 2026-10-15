-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local L={};local T=dofile(ctx.base..'/timers.lua');local J=dofile(ctx.base..'/json.lua');local N=ctx.items.native
 local bundles={{{'MC_Bone',6},{'MC_RottenFlesh',4},{'MC_IronIngot',3}},{{'MC_Bone',4},{'MC_GoldIngot',2}},{{'MC_RottenFlesh',7},{'MC_IronIngot',4}},{{'MC_Bone',5},{'MC_GoldIngot',3},{'MC_IronIngot',2}}}
 local function count(e,id)
  local n=0;for kind=0,5 do local c=N:container(e,kind);for i=0,c:Num()-1 do local s=c:Get(i);if N:id(s)==id then n=n+s:GetStackCount()end end end;return n
 end
 function L:load()
  local path=ctx.UE.worldScope65:path('island-loot88');if path==self.path then return end
  self.path=path;self.state={version=1,chests={}};local f=io.open(path,'rb');if f then self.state=J.decode(f:read('*a'));f:close()end
 end
 function L:save()
  local f=assert(io.open(self.path..'.tmp','wb'));f:write(J.encode(self.state));f:close()

  local old=io.open(self.path,'rb');if old then local text=old:read('*a');old:close();local b=assert(io.open(self.path..'.previous','wb'));b:write(text);b:close()end
  local out=assert(io.open(self.path,'wb'));out:write(J.encode(self.state));out:close()
 end
 function L:near(e)
  local p=e.player:K2_GetActorLocation();local island=ctx.island:at(p);if not island or not island.admitted or not island.data.chests then return end
  local best,range
  for n,c in ipairs(island.data.chests)do local q=c.position;local d=(p.X-q.X)^2+(p.Y-q.Y)^2+(p.Z-q.Z-90)^2
   if d<250^2 and(not range or d<range)then best=c.id or(island.data.key=='desert'and n or(island.data.key..':'..n));range=d end
  end
  return best
 end
 function L:collect(e,n)
  local key=tostring(n);if self.state.chests[key]then self:notice('Empty');return end
  local before={};local index=tonumber(tostring(n):match('(%d+)$'));local bundle=key=='x8_mineshaft'and dofile(ctx.base..'/slice_x8_data.lua').reward.loot or bundles[index];assert(bundle,'Unknown static chest');local free=0;local c=N:container(e,0)
  for i=0,c:Num()-1 do if not N:id(c:Get(i))then free=free+1 end end
  if free<#bundle then self:notice('Make room in inventory');return end
  for _,v in ipairs(bundle)do assert(ctx.valid(ctx.items:data(v[1])));before[v[1]]=count(e,v[1])end
  local receipt={state='pending',before=before,loot=bundle};self.state.chests[key]=receipt;self:save()
  local after={};local ok=true
  for _,v in ipairs(bundle)do N:inventory(e):AddItem_ServerInternal(ctx.UE.FindOrAddFName(v[1]),v[2],false,0,true);after[v[1]]=count(e,v[1]);ok=ok and after[v[1]]==before[v[1]]+v[2]end
  receipt.after=after;receipt.state=ok and'claimed'or'recovery-required';self:save();ctx.items.dirty=true
  for _,v in ipairs(bundle)do if after[v[1]]>before[v[1]]then ctx.ui:nativePickup(e,v[1],after[v[1]]-before[v[1]])end end
  ctx.log('MC88_CHEST_LOOT chest='..n..' pass='..tostring(ok)..' counts='..J.encode(receipt));self.last=receipt
 end
 function L:notice(text)
  local ko=ctx.UE.language57 and ctx.UE.language57.lang=='ko'
  local labels={['Empty']='비어 있음',['Make room in inventory']='인벤토리 공간이 필요합니다',['[F] Collect treasure']='[F] 보물 획득',['[F] Enter treasure chamber']='[F] 보물방으로 내려가기',['[F] Return to pyramid']='[F] 피라미드로 올라가기'}
  ctx.ui:notify(ko and '유적 보물'or'Temple treasure',ko and(labels[text]or text)or text)
 end

 function L:hatch(e)
  if ctx.island.all.desert.data.x6Rebuilt then return end 
  local d=ctx.island.all.desert.data;local p=e.player:K2_GetActorLocation()
  local x=(p.X-d.origin.X)/100;local z=(d.origin.Y-p.Y)/100;local foot=(p.Z-e.player.CapsuleComponent:GetScaledCapsuleHalfHeight()-d.origin.Z)/100
  if math.abs(x+21.5)>1.1 or math.abs(z+37.5)>1.1 then return end
  if math.abs(foot-25)<.5 then return 13 elseif math.abs(foot-13)<.8 then return 25 end
 end
 function L:moveHatch(e,height)
  local d=ctx.island.all.desert.data;local x,y=d.origin.X-2150,d.origin.Y+3750;local f=ctx.UE.follow86
  local q=f:ground(e,x,y,d.origin.Z+height*100+40,d.origin.Z+height*100-40,{e.player});if not q then return end
  local cap=e.player.CapsuleComponent;q.Z=q.Z+cap:GetScaledCapsuleHalfHeight()+5
  if not f:clear(e,q,cap:GetScaledCapsuleRadius(),cap:GetScaledCapsuleHalfHeight(),{e.player})then return end
  e.player.CharacterMovement:StopMovementImmediately();assert(_G.MC_OUT_K('K2_SetActorLocation',e.player,q,false,{},true));e.player.CharacterMovement:SetMovementMode(1,0)
  ctx.log('MC88_TREASURE_HATCH floor='..height)
 end
 local function schedule()
  
  if L.handle then T.cancel(L.handle)end
  L.handle=T.loop(250,function()
   local input=L.input;L.input=nil;if not ctx.ready()then return false end
   local e=ctx.environment();if not e or not ctx.gameplayInput(e)then return false end
   L:load();local hatch=L:hatch(e);local n=not hatch and L:near(e);local prompt=hatch and('hatch'..hatch)or n
   if prompt~=L.prompt then L.prompt=prompt;if hatch then L:notice(hatch==13 and'[F] Enter treasure chamber'or'[F] Return to pyramid')elseif n then L:notice(L.state.chests[tostring(n)]and'Empty'or'[F] Collect treasure')end end
   if input then if hatch then L:moveHatch(e,hatch)elseif n then L:collect(e,n)end end
   return false
  end,'loot88')
 end
 T.onEpoch('loot88',function()L.path=nil;L.state=nil;L.prompt=nil;L.input=nil;schedule()end);schedule()
 return L
end
