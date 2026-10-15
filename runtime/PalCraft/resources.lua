-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local Timers=dofile(ctx.base..'/timers.lua');local R={plans={},byId={},scan=1,max_ms=0};local M=ctx.mechanics
 local sites={{120,136},{110,124},{136,126},{108,144},{142,146},{124,154},{94,130},{152,120},{100,110},{142,108}}
 local ores={{126,128},{116,116},{134,138},{106,136},{146,132}}
 local function key(c)return ctx.key(c.x,c.y,c.z)end
 local function owned(c,id)return c and c.state and c.state.resource==id end
 local function clone(p,id)
  local c={x=p.x,y=p.y,z=p.z,type=p.type,variant=0,debug=false,state={resource=id}}
  if ctx.registry[p.type].name:find('leaves',1,true)then c.state.persistent=false end
  if id:match('^island_ore_')and tonumber(id:match('(%d+)$'))<41 then c.state.embed=35 end
  return c
 end
 function R:build()
  if ctx.island.data.x5Resources then
   if #self.plans>0 then return end
   for _,key in ipairs({'plains','desert','jungle','mushroom'})do
    local island=assert(ctx.island.all[key])
    for _,raw in ipairs(island.data.x5Resources or {})do
     local node={id=raw.id,kind=raw.kind,delay=raw.delay,root=raw.root,islandKey=key,cells={}}
     for _,p in ipairs(raw.cells)do node.cells[#node.cells+1]={x=p.x,y=p.y,z=p.z,type=assert(ctx.types[p.block])}end
     self.plans[#self.plans+1]=node;self.byId[node.id]=node
    end
   end
   return
  end
  if ctx.island.data.resourcesStatic then return end
  if #self.plans>0 then return end
  for i,s in ipairs(sites)do
   local p=ctx.island:position(s[1],s[2]);local root={x=math.floor(p.X/100),y=math.floor(p.Y/100),z=math.floor(p.Z/100)}
   
   for _,o in ipairs({{-49,-49},{49,-49},{-49,49},{49,49}})do root.z=math.max(root.z,math.ceil(assert(ctx.island:height(root.x*100+50+o[1],root.y*100+50+o[2]))/100))end
   local id=string.format('island_tree_%02d',i);local species=i%2==0 and'birch'or'oak';local h=4+i%2
   local node={id=id,kind='tree',delay=600,root=root,cells={},logs=h};local trunk={}
   for z=0,h-1 do local c={x=root.x,y=root.y,z=root.z+z,type=assert(ctx.types[species..'_log'])};node.cells[#node.cells+1]=c;trunk[key(c)]=true end
   for z=h-2,h do local radius=z==h and 1 or 2
    for x=-radius,radius do for y=-radius,radius do local c={x=root.x+x,y=root.y+y,z=root.z+z,type=assert(ctx.types[species..'_leaves']or ctx.types.oak_leaves)}
     if not trunk[key(c)]and not(math.abs(x)==radius and math.abs(y)==radius)then node.cells[#node.cells+1]=c end
    end end
   end
   self.plans[#self.plans+1]=node;self.byId[id]=node
  end
  for i,s in ipairs(ores)do
   local p=ctx.island:position(s[1],s[2]);local root={x=math.floor(p.X/100),y=math.floor(p.Y/100),z=math.floor(p.Z/100)}
   local id=string.format('island_ore_%02d',i);local name=i%2==0 and'iron_ore'or'coal_ore'
   local node={id=id,kind='ore',delay=900,root=root,cells={}}

   for _,o in ipairs({{0,0},{1,0},{0,1},{1,1}})do
    local x,y=root.x+o[1],root.y+o[2];local z=math.floor(assert(ctx.island:height(x*100+50,y*100+50))/100)
    node.cells[#node.cells+1]={x=x,y=y,z=z,type=assert(ctx.types[name])}
   end
   self.plans[#self.plans+1]=node;self.byId[id]=node
  end
  local seen={};for _,n in ipairs(self.plans)do for _,c in ipairs(n.cells)do assert(not seen[key(c)],'Overlapping resource plans');seen[key(c)]=n.id end end
 end
 function R:dirty()if ctx.cancelSave then ctx.cancelSave()end;M.dirty=true end
 function R:changed(old,new)
  local id=old and old.state and old.state.resource or new and new.state and new.state.resource
  if id then self:dirty()end
 end
 function R:remaining(node)
  local n=0;for _,p in ipairs(node.cells)do if owned(ctx.cells()[key(p)],node.id)then n=n+1 end end;return n
 end
 function R:near(node,env)
  local p=env.player:K2_GetActorLocation();local dx,dy=p.X-(node.root.x*100+50),p.Y-(node.root.y*100+50)
  local island=node.islandKey and ctx.island.all[node.islandKey]or ctx.island
  return dx*dx+dy*dy<18000^2 and island.admitted and island.footingReady and island.epoch==ctx.epoch()
 end
 function R:migrateX6(env,d)
  if not ctx.island.data.x6Rebuilt or self.x6Migrated then return true end
  local obsolete={["island_ore_41"]=true,["island_ore_42"]=true,["island_ore_43"]=true,["island_ore_44"]=true,["island_ore_45"]=true,["island_ore_46"]=true,["island_ore_47"]=true,["island_ore_48"]=true,["island_ore_49"]=true,["island_ore_50"]=true,["island_ore_51"]=true,["island_ore_52"]=true,["island_ore_53"]=true,["island_ore_54"]=true,["island_ore_55"]=true,["island_ore_56"]=true,["island_ore_57"]=true,["island_ore_58"]=true,["island_ore_59"]=true,["island_ore_60"]=true,["island_ore_61"]=true,["island_ore_62"]=true,["island_ore_63"]=true,["island_ore_64"]=true,["island_ore_65"]=true,["island_ore_66"]=true,["island_ore_67"]=true,["island_ore_68"]=true,["island_ore_69"]=true,["island_ore_70"]=true,["island_ore_71"]=true,["island_ore_72"]=true,["island_ore_73"]=true,["island_ore_74"]=true,["island_ore_75"]=true,["island_ore_76"]=true,["island_ore_77"]=true,["island_ore_78"]=true,["island_ore_79"]=true}
  if not self.x6Cleanup then
   self.x6Cleanup={};self.x6At=1
   for k,c in pairs(ctx.cells())do if c.state and obsolete[c.state.resource]then self.x6Cleanup[#self.x6Cleanup+1]=k end end
   table.sort(self.x6Cleanup)
  end
  local k=self.x6Cleanup[self.x6At]
  if k then
   local c=ctx.cells()[k]
   if c and c.state and obsolete[c.state.resource]then assert(ctx.mutate(k,nil,env),'X6 old ore migration failed')end
   self.x6At=self.x6At+1;return false
  end
  for id in pairs(obsolete)do d.nodes[id]=nil end
  self.x6Migrated=true;self:dirty();ctx.log('MCX6_ORE_MIGRATED cells='..#self.x6Cleanup)
  return true
 end
 function R:step(env)
  local begin=os.clock();local d=ctx.state();if not d then return end
  if not self:migrateX6(env,d)then return end
  local now=ctx.UE.Object('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(env.player)
  if self.last and now>=self.last then d.clock=d.clock+(now-self.last)*M.growth_speed end;self.last=now
  local n=self.plans[self.scan];self.scan=self.scan%#self.plans+1;local r=d.nodes[n.id]
  if not r then r={phase='new',cycle=0};d.nodes[n.id]=r;self:dirty()end
  if r.phase=='active'and self:remaining(n)==0 then r.phase='waiting';r.due=d.clock+n.delay;self:dirty();ctx.log('MC34_NODE_EXHAUSTED id='..n.id..' due='..r.due..' clock='..d.clock)end
  if not self.job and(r.phase=='new'or r.phase=='growing'or r.phase=='waiting'and d.clock>=r.due)and self:near(n,env)then
   self.job={node=n,at=1,stage='check',resume=r.phase=='growing',added=0};r.phase=r.phase=='growing'and'growing'or r.phase
  end
  local j=self.job
  if j then
   local p=j.node.cells[j.at];local c=ctx.cells()[key(p)];local rec=d.nodes[j.node.id]
   local blocked=c and not(j.resume and owned(c,j.node.id))or ctx.intersects(p,env)
   if not blocked then blocked=not ctx.emptyNative(p,env)end
   if blocked then self.job=nil;ctx.log('MC34_NODE_BLOCKED id='..j.node.id..' cell='..key(p))
   elseif j.stage=='check'then
    j.at=j.at+1;if j.at>#j.node.cells then j.stage='put';j.at=1;rec.phase='growing';self:dirty()end
   else
    if not c then assert(ctx.mutate(key(p),clone(p,j.node.id),env));j.added=j.added+1 end
    j.at=j.at+1
    if j.at>#j.node.cells then rec.phase='active';rec.due=nil;rec.cycle=rec.cycle+1;self.job=nil;self:dirty();ctx.log('MC34_NODE_GROWN id='..j.node.id..' cycle='..rec.cycle..' added='..j.added)end
   end
  end

  if now>=(self.saveAt or 0)then self.saveAt=now+5;M.dirty=true end
  self.max_ms=math.max(self.max_ms,(os.clock()-begin)*1000)
 end
 function R:start(env)
  if ctx.island.data.resourcesStatic then ctx.log('MC83_LEGACY_RESOURCES_RETIRED');return end
  self:build();if self.handle then Timers.cancel(self.handle)end;self.last=nil;self.job=nil;self.scan=1
  local epoch=ctx.epoch();self.handle=Timers.loop(ctx.island.data.x5Resources and 200 or 33,function()
   if epoch~=ctx.epoch()or ctx.quiesced()then return true end
   local alive=ctx.environment();if not alive then self.last=nil;return false end
   local ok,err=xpcall(function()self:step(alive)end,debug.traceback);if not ok then ctx.log('MC34_RESOURCE_ERROR '..tostring(err));return true end;return false
  end,'island-resources');ctx.log('MCX5_RESOURCES_READY nodes='..#self.plans..' persisted_v4=true')
 end
 function R:status()
  self:build();local out={clock=ctx.state().clock,nodes={},max_ms=self.max_ms,growth_speed=M.growth_speed}
  for _,n in ipairs(self.plans)do out.nodes[#out.nodes+1]={id=n.id,kind=n.kind,root=n.root,total=#n.cells,remaining=self:remaining(n),state=ctx.state().nodes[n.id]or false}end
  return out
 end
 Timers.onEpoch('resource-nodes',function()R.handle=nil;R.job=nil;R.last=nil;R.x6Migrated=nil;R.x6Cleanup=nil;R.x6At=nil end)
 return R
end
