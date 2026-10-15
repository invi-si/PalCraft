-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,M)
 local D={fires={},fireAt=0};local N=ctx.items.native
 local function key(c,dz)return ctx.key(c.x,c.y,c.z+(dz or 0))end
 local function cells()return ctx.cells()end
 local function def(c)return c and ctx.registry[c.type]end
 local function name(c)return c and def(c).name end
 local function st(c)c.state=c.state or{};return c.state end
 local function dirty()M.dirty=true;if ctx.cancelSave then ctx.cancelSave()end end
 local function above(c,dz)return cells()[key(c,dz or 1)]end
 local function water(c)
  for _,v in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do if name(cells()[ctx.key(c.x+v[1],c.y+v[2],c.z-1)])=='water'then return true end end;return false
 end
 local baseIndex=M.indexCell
 function M:indexCell(k,c)
  baseIndex(self,k,c);local d=def(c)
  if d and(d.kind=='berry'or d.kind=='cane')and not self.positions[k]then self.index[#self.index+1]=k;self.positions[k]=#self.index end
  D.fires[k]=d and d.kind=='campfire'and c or nil
 end
 local baseInit=M.initialize
 function M:initialize(c)
  baseInit(self,c);local d=def(c)
  if d.kind=='berry'or d.kind=='cane'then st(c).age=st(c).age or 0
  elseif d.kind=='tallplant'then st(c).half=st(c).half or 0
  elseif d.kind=='campfire'then st(c).lit=true end
 end
 local baseCan=M.canPlace
 function M:canPlace(c)
  local d=def(c);local ground=above(c,-1)
  if not d.decor70 then return baseCan(self,c)end
  if d.kind=='leaves'then return true end
  if d.kind=='sapling'then return baseCan(self,c)end
  if d.name=='vine'then
   for _,v in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do if cells()[ctx.key(c.x+v[1],c.y+v[2],c.z)]then return true end end;return false
  end
  if d.name=='lily_pad'then return name(ground)=='water'end
  if d.kind=='cane'then
   if name(ground)=='sugar_cane'then local n=1;local q=ground;while name(q)=='sugar_cane'and n<4 do n=n+1;q=above(q,-1)end;return n<=3 end
   return(name(ground)=='dirt'or name(ground)=='grass_block'or name(ground)=='sand')and water(c)
  end
  if not ground or def(ground).collision==false then return false end
  if d.kind=='tallplant'then return not above(c)end
  return true
 end
 local baseChanged=M.changed
 function M:changed(old,new)
  baseChanged(self,old,new)
  if new and def(new).kind=='tallplant'and(st(new).half or 0)==0 and not above(new)then
   local c=new;self:enqueue(function(e)
    if cells()[key(c)]==c and not above(c)then self:put({x=c.x,y=c.y,z=c.z+1,type=c.type,variant=1,debug=c.debug,state={half=1}},e)end
   end)
  elseif old and not new and def(old).kind=='tallplant'then
   local c=old;self:enqueue(function(e)local q=above(c,st(c).half==1 and-1 or 1);if q and q.type==c.type and st(q).half~=st(c).half then ctx.mutate(key(q),nil,e)end end)
  end
 end
 local baseLoot=M.loot
 function M:loot(c)
  local d=def(c)
  if d.kind=='leaves'and d.sapling then
   if st(c).persistent then return{[d.item]=1}end
   local out={};if math.random()<(d.name=='jungle_leaves'and .025 or .05)then out[d.sapling]=1 end;if math.random()<.02 then out.MC_Stick=math.random(1,2)end;if d.name=='dark_oak_leaves'and math.random()<.005 then out.MC_Apple=1 end;return out
  elseif d.kind=='berry'then return{MC_SweetBerries=math.max(1,(st(c).age or 0)>=2 and 2 or 1)}
  elseif d.kind=='pot'then local out={[d.item]=1};if st(c).plant then out[st(c).plant]=1 end;return out
  elseif d.kind=='campfire'then local out={MC_Charcoal=2};if st(c).cookItem then local id=st(c).cooked and st(c).cookResult or st(c).cookItem;out[id]=(out[id]or 0)+1 end;return out
  end
  return baseLoot(self,c)
 end
 local baseHarvest=M.harvest
 function M:harvest(k,e,cause)
  local c=cells()[k]
  if c and def(c).kind=='tallplant'then
   local d=def(c);if not c.debug and not ctx.phaseC:capacity(e,d.item,1)then return false end
   local q=above(c,st(c).half==1 and-1 or 1)
   if not ctx.mutate(k,nil,e)then return false end
   if q and q.type==c.type then ctx.mutate(key(q),nil,e)end
   if not c.debug then self:drop(e,d.item,1,c)end;return true
  end
  return baseHarvest(self,k,e,cause)
 end
 local meat={MC_Beef='MC_CookedBeef',MC_Porkchop='MC_CookedPorkchop',MC_Chicken='MC_CookedChicken',MC_Mutton='MC_CookedMutton',MC_Rabbit='MC_CookedRabbit'}
 
 local smelt=dofile(ctx.base..'/smelting.lua')
 for id,r in pairs(smelt)do if id:find('Beef')or id:find('Porkchop')or id:find('Chicken')or id:find('Mutton')or id:find('Rabbit')then meat[id]=r.result end end
 local baseInteract=M.interact
 function M:interact(e,entry,hit)
  local ch=hit and ctx.hitChunk(hit);local k=ch and ch.keys[hit.Item];local c=k and cells()[k];local d=def(c);local id=entry and entry.id
  if d and d.kind=='berry'and(st(c).age or 0)>=2 then
   local n=st(c).age==3 and 3 or 2;if not ctx.phaseC:capacity(e,'MC_SweetBerries',n)then return true end
   self:drop(e,'MC_SweetBerries',n,c);st(c).age=1;ctx.variant(k,1,e);dirty();ctx.log('MC70_BERRY_HARVEST count='..n);return true
  elseif d and d.kind=='pot'then
   if st(c).plant then
    if ctx.phaseC:capacity(e,st(c).plant,1)then self:drop(e,st(c).plant,1,c);st(c).plant=nil;ctx.variant(k,0,e);dirty()end
   elseif id and d.contents[id]and entry.count>0 then
    N:dispose(e,entry.slot,1);st(c).plant=id;ctx.variant(k,d.contents[id],e);dirty()
   end;return true
  elseif d and d.kind=='campfire'then
   local s=st(c)
   if s.cookItem and s.cooked then
    if ctx.phaseC:capacity(e,s.cookResult,1)then self:drop(e,s.cookResult,1,c);s.cookItem=nil;s.cookResult=nil;s.cookLeft=nil;s.cooked=nil;dirty();ctx.log('MC70_CAMPFIRE_TAKEN')end
   elseif not s.cookItem and id and meat[id]and entry.count>0 then
    N:dispose(e,entry.slot,1);s.cookItem=id;s.cookResult=meat[id];s.cookLeft=30;s.cooked=false;dirty();ctx.log('MC70_CAMPFIRE_COOK_STARTED seconds=30 item='..id)
   end;return true
  elseif id=='MC_SweetBerries'and c and(name(c)=='dirt'or name(c)=='grass_block')and not above(c)then
   local q={x=c.x,y=c.y,z=c.z+1,type=ctx.types.sweet_berry_bush,variant=0,state={age=0}}
   if self:canPlace(q)then N:dispose(e,entry.slot,1);self:put(q,e);dirty()end;return true
  end
  return baseInteract(self,e,entry,hit)
 end
 local baseRandom=M.randomTick
 function M:randomTick(c,e)
  local d=def(c);if not d then return end
  if d.kind=='berry'then
   if(st(c).age or 0)<3 and math.random(3)==1 then st(c).age=(st(c).age or 0)+1;ctx.variant(key(c),st(c).age,e);dirty()end
  elseif d.kind=='cane'and not above(c)then
   local base=c;local h=1;while name(above(base,-1))=='sugar_cane'and h<4 do base=above(base,-1);h=h+1 end
   if h<3 and water(base)then st(c).age=(st(c).age or 0)+1;if st(c).age>=7 then st(c).age=0;self:put({x=c.x,y=c.y,z=c.z+1,type=c.type,variant=0,state={age=0}},e)end;dirty()end
  else return baseRandom(self,c,e)end
 end
 local baseStep=M.step
 function M:step(e)
  local now=os.clock()
  if now>=D.fireAt then
   local elapsed=D.fireAt==0 and 0 or math.min(2,math.max(0,math.floor(now-D.fireAt+1)));D.fireAt=now+1
   for k,c in pairs(D.fires)do local cell=c;self:enqueue(function(current)
    if cells()[k]~=cell then return end;local s=st(cell)
    if s.cookItem and not s.cooked then s.cookLeft=math.max(0,(s.cookLeft or 30)-elapsed);if s.cookLeft==0 then s.cooked=true;ctx.log('MC70_CAMPFIRE_READY item='..s.cookResult)end;dirty()end
   end)end
  end
  return baseStep(self,e)
 end
 local baseStart=M.start
 function M:start(e)D.fires={};D.fireAt=0;return baseStart(self,e)end
 local baseGrow=M.grow
 function M:grow(c,e)
  local d=def(c);if not d.wood then return baseGrow(self,c,e)end
  local wood=d.wood;local heights={spruce=7,birch=6,jungle=8,acacia=5,dark_oak=5,cherry=5,mangrove=6,pale_oak=6};local h=heights[wood];local root=key(c)
  self.growing=self.growing or{};if self.growing[root]then return false end
  local plan={};local trunk={};local log=assert(ctx.types[wood..'_log']);local leaf=assert(ctx.types[wood..'_leaves'])
  for dz=0,h-1 do local kk=key(c,dz);if cells()[kk]and cells()[kk]~=c then return false end;trunk[kk]=true;plan[#plan+1]={x=c.x,y=c.y,z=c.z+dz,type=log,variant=0}end
  local start=wood=='spruce'and 2 or h-3;local top=wood=='acacia'and h-1 or h
  for dz=start,top do
   local rad=wood=='spruce'and math.max(1,math.floor((h-dz)/2))or wood=='acacia'and 3 or wood=='cherry'and 3 or wood=='dark_oak'and 3 or 2
   if dz==top then rad=math.max(1,rad-1)end
   for dx=-rad,rad do for dy=-rad,rad do local kk=ctx.key(c.x+dx,c.y+dy,c.z+dz)
    if not trunk[kk]and not cells()[kk]and(math.abs(dx)+math.abs(dy)<rad*2 or rad==1)then plan[#plan+1]={x=c.x+dx,y=c.y+dy,z=c.z+dz,type=leaf,variant=0,state={persistent=false}}end
   end end
  end
  self.growing[root]=true;local blocked=false
  for i=1,h do local q=plan[i];self:enqueue(function(current)if not ctx.emptyNative(q,current)then blocked=true end end)end
  self:enqueue(function(current)
   if blocked or cells()[root]~=c then self.growing[root]=nil;return end
   ctx.mutate(root,nil,current)
   for _,q in ipairs(plan)do local cell=q;self:enqueue(function(env)if not cells()[key(cell)]and(trunk[key(cell)]or ctx.emptyNative(cell,env))then self:put(cell,env)end end)end
   self:enqueue(function()self.growing[root]=nil;dirty();ctx.log('MC70_TREE_GROWN wood='..wood..' height='..h)end)
  end);return true
 end
 M.decor70=D;D.water=water
end
