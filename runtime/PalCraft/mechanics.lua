-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local Timers=dofile(ctx.base..'/timers.lua')
 local M={index={},positions={},queue={},head=1,tickDebt=0,growth_speed=ctx.config.growth_speed or 1,max_cpu_ms=0,changes=0,dirty=false,fuses={},flashes={},detonating={}}
 local N=ctx.items.native
 local function cells()return ctx.cells()end
 local function name(c)return c and ctx.registry[c.type].name end
 local function key(x,y,z)return ctx.key(x,y,z)end
 local function pos(c)return{X=c.x*100+50,Y=c.y*100+50,Z=c.z*100+50}end
 local function isLeaf(c)return c and(name(c):find('leaves',1,true)~=nil)end
 local function isLog(c)return c and(name(c):find('_log',1,true)~=nil or name(c):find('_wood',1,true)~=nil)end
 local function state(c)c.state=c.state or{};return c.state end
 local function tickable(c)
  local d=c and ctx.registry[c.type];return d and(d.kind=='sapling'or(d.kind=='crop'and(c.state and c.state.age or 0)<d.stages-1)or d.kind=='farmland'or(isLeaf(c)and c.state and c.state.decay and not c.state.persistent))
 end
 function M:indexCell(k,c)
  local i=self.positions[k]
  if tickable(c)and not i then self.index[#self.index+1]=k;self.positions[k]=#self.index
  elseif not tickable(c)and i then local last=self.index[#self.index];self.index[i]=last;self.positions[last]=i;self.index[#self.index]=nil;self.positions[k]=nil end
 end
 function M:enqueue(fn)self.queue[#self.queue+1]=fn end
 function M:changed(old,new)
  if self.resources then self.resources:changed(old,new)end
  if ctx.cancelSave then ctx.cancelSave()end
  local c=new or old;local k=key(c.x,c.y,c.z);self:indexCell(k,new);self.dirty=true;self.changes=self.changes+1
  if old and not new then self.detonating[k]=nil end
  if old and isLog(old)and not isLog(new)then
   for dz=-6,6 do for dy=-6,6 do local z,y=dz,dy;self:enqueue(function()
    for dx=-6,6 do local k2=key(old.x+dx,old.y+y,old.z+z);local leaf=cells()[k2]
     if isLeaf(leaf)and not(leaf.state and leaf.state.persistent)then state(leaf).decay=true;self:indexCell(k2,leaf)end
    end
   end)end end
  end
 end
 function M:put(c,env)
  local k=key(c.x,c.y,c.z);assert(not cells()[k],'Mechanics insertion occupied '..k)
  if isLeaf(c)and not c.state then c.state={persistent=true}end
  assert(ctx.mutate(k,c,env),'Mechanics insertion rejected');return k
 end
 function M:replace(c,id,st,env)
  local k=key(c.x,c.y,c.z);local q={x=c.x,y=c.y,z=c.z,type=assert(ctx.types[id]),variant=0,debug=c.debug,state=st}
  assert(ctx.mutate(k,q,env),'Mechanics replacement rejected');return q
 end
 function M:drop(env,id,n,c)
  return ctx.UE.drops66:give(env,id,n,true)
 end
 function M:loot(c)
  local n=name(c);local d=ctx.registry[c.type]
  local drops={}
  if d.kind=='fluid'then return false
  elseif d.kind=='crop'then local age=c.state and c.state.age or 0;local mature=age>=d.stages-1
   if n=='wheat_crop'then drops.MC_WheatSeeds=mature and math.random(0,3)or 1;if mature then drops.MC_Wheat=1 end
   else drops[n=='carrot_crop'and'MC_Carrot'or'MC_Potato']=mature and math.random(1,4)or 1 end
  elseif d.kind=='farmland'then drops.MC_Dirt=1
  elseif isLeaf(c)then
   if math.random()<.05 then drops.MC_OakSapling=1 end
   if math.random()<.005 then drops.MC_Apple=1 end
   if math.random()<.02 then drops.MC_Stick=1 end
  elseif n=='grass_block'then drops[d.item]=1;if math.random()<.125 then drops.MC_WheatSeeds=1 end
  else return nil end
  return drops
 end
 function M:harvest(k,env,cause)
  local c=cells()[k];if not c then return true end;local n=name(c);local drops=self:loot(c)
  if drops==false then return false elseif not drops then return nil end
  if not c.debug then for id,n in pairs(drops)do if not ctx.phaseC:capacity(env,id,n)then ctx.log('MC66_MINE_FULL kept='..k);return false end end end
  if not ctx.mutate(k,nil,env)then return false end
  if not c.debug then for id,quantity in pairs(drops)do self:drop(env,id,quantity,c)end end
  self.dirty=true;ctx.log('MC23_HARVEST cell='..k..' name='..n..' cause='..(cause or'mine'));return true
 end
 function M:damage(env,fraction,why)
  local p=env.player.CharacterParameterComponent;local hp,max=p:GetHP().Value,p:GetMaxHP().Value
  if hp<=0 or max<=0 then return end
  
  ctx.UE.Object('/Script/Pal.Default__PalUtility'):SetHPByRateToCharacter(env.player,math.max(math.min(1000,max)/max,hp/max-fraction))
  ctx.log('MC23_DAMAGE cause='..why..' before='..hp..' after='..p:GetHP().Value..' path=verified_SetHPByRateToCharacter')
  ctx.phaseA:updateStats(env)
 end
 function M:durability(entry)
  local out={};if not ctx.valid(entry.slot)or not _G.MC_OUT_K('TryGetDynamicItemData',entry.slot,out)or not ctx.valid(out.OutDynamicItemData)then return false end
  local data=out.OutDynamicItemData;local before=data.Durability;if type(before)~='number'or before<=0 then return false end
  data.Durability=math.max(0,before-1);assert(data.Durability==math.max(0,before-1),'Durability did not settle')
  ctx.items.dirty=true;ctx.log('MC23_DURABILITY id='..entry.id..' before='..before..' after='..data.Durability);return true
 end
 function M:canPlace(c)
  local d=ctx.registry[c.type];local n=name(c);local ground=cells()[key(c.x,c.y,c.z-1)]
  if d.kind=='sapling'then return name(ground)=='dirt'or name(ground)=='grass_block'end
  if d.kind=='crop'then return name(ground)=='farmland'end
  return true
 end
 function M:initialize(c)
  local d=ctx.registry[c.type]
  if isLeaf(c)then c.state=c.state or{persistent=true}
  elseif d.kind=='crop'or d.kind=='sapling'then c.state=c.state or{age=0}
  elseif d.kind=='farmland'then c.state=c.state or{moist=0,dry=0}end
 end
 function M:interact(env,entry,hit)
  if not entry or not entry.id then return false end
  local id=entry.id;local ch=hit and ctx.hitChunk(hit);local k=ch and ch.keys[hit.Item];local c=k and cells()[k]
  local def=ctx.items.registry.items[id]
  if id=='MC_Bucket'then
   if c and(name(c)=='water'or name(c)=='lava')then
    local filled=name(c)=='water'and'MC_WaterBucket'or'MC_LavaBucket'
    N:dispose(env,entry.slot,1);assert(ctx.mutate(k,nil,env));N:add(env,filled,1);ctx.save();ctx.log('MC23_BUCKET_PICKUP '..k..' ->'..filled)
   end;return true
  elseif id=='MC_WaterBucket'or id=='MC_LavaBucket'then
   local target=ctx.targetCell(env,true);if not target or cells()[key(target.x,target.y,target.z)]then return true end
   target.type=ctx.types[id=='MC_WaterBucket'and'water'or'lava'];target.variant=0;target.state=nil
   N:dispose(env,entry.slot,1);self:put(target,env);N:add(env,'MC_Bucket',1);ctx.save();ctx.log('MC23_BUCKET_PLACE '..key(target.x,target.y,target.z)..' id='..id);return true
  elseif id=='MC_FlintAndSteel'then
   if c and name(c)=='tnt'and not self.fuses[k]and self:durability(entry)then self:ignite(k,4);ctx.save()end;return true
  elseif def and def.tool=='hoe'then
   if c and(name(c)=='dirt'or name(c)=='grass_block')and not cells()[key(c.x,c.y,c.z+1)]and self:durability(entry)then self:replace(c,'farmland',{moist=0,dry=0},env);ctx.save();ctx.log('MC23_HOE '..k)end;return true
  elseif id=='MC_WheatSeeds'or id=='MC_Carrot'or id=='MC_Potato'then
   if c and name(c)=='farmland'then
    local above=key(c.x,c.y,c.z+1);if not cells()[above]then
     local plant=id=='MC_WheatSeeds'and'wheat_crop'or id=='MC_Carrot'and'carrot_crop'or'potato_crop'
     N:dispose(env,entry.slot,1);self:put({x=c.x,y=c.y,z=c.z+1,type=ctx.types[plant],variant=0,state={age=0}},env);ctx.save();ctx.log('MC23_PLANT '..above..' name='..plant)
    end;return true
   end
  end
  return false
 end
 function M:ignite(k,seconds)
  local c=cells()[k];if not c or name(c)~='tnt'or self.fuses[k]or self.detonating[k]then return end
  self.fuses[k]={at=os.clock()+seconds,flashAt=0};state(c).lit=true;self:indexCell(k,c);self.dirty=true;ctx.log('MC23_TNT_LIT '..k..' fuse_s='..seconds)
 end
 function M:blast(center,env,damageFn)
  if ctx.UE.effects66 then ctx.UE.effects66:emit(env,'explosion',pos(center))end
  if ctx.UE.mobs66 then ctx.UE.mobs66:blast66(env,pos(center))end
  local list={};local radius=4
  for k,c in pairs(cells())do
   local dx,dy,dz=c.x-center.x,c.y-center.y,c.z-center.z;local dist=math.sqrt(dx*dx+dy*dy+dz*dz);local n=name(c)
   if dist<=radius and not(n:find('obsidian',1,true)or n:find('bedrock',1,true))then list[#list+1]={k=k,c=c,d=dist}end
  end
  table.sort(list,function(a,b)return a.d<b.d end)
  local drops,removed={},0
  for _,e in ipairs(list)do self:enqueue(function(current)
   local c=cells()[e.k];if c~=e.c then return end
   if name(c)=='tnt'and e.d>0 then self:ignite(e.k,.5+math.random());return end
   
   local steps=math.max(1,math.ceil(e.d*3));local energy=4.5;local visited={}
   for i=1,steps do
    local t=i/steps;local kk=key(math.floor(center.x+.5+(c.x-center.x)*t),math.floor(center.y+.5+(c.y-center.y)*t),math.floor(center.z+.5+(c.z-center.z)*t));local block=cells()[kk]
    if block and not visited[kk]then
     visited[kk]=true;local n=name(block)
     if n:find('obsidian',1,true)or n:find('bedrock',1,true)or n=='water'or n=='lava'then energy=0
     else energy=energy-(ctx.registry[block.type].hardness or 1)*.25-.15 end
    end
   end
   if energy<=0 and e.d>0 then return end
   local d=ctx.registry[c.type]
   if d.kind=='bed'and self.beds then self.beds:remove(e.k,current,false);removed=removed+2;if not c.debug then drops.MC_Bed=(drops.MC_Bed or 0)+1 end;return end
   if ctx.mutate(e.k,nil,current)then
    self.fuses[e.k]=nil;removed=removed+1
    if d.kind~='fluid'and not c.debug and not(name(c)=='tnt'and e.d==0)then
     local loot=self:loot(c)or{[d.item]=1};for id,n in pairs(loot)do drops[id]=(drops[id]or 0)+n end
    end
   end
  end)end
  self:enqueue(function(current)
   for id,n in pairs(drops)do local item,quantity=id,n;self:enqueue(function(e)M:drop(e,item,quantity,center)end)end
    self:enqueue(function()self.dirty=true;ctx.log('MC23_EXPLOSION_DONE center='..key(center.x,center.y,center.z)..' removed='..removed..' native_terrain=untouched drops=100_percent_recoverable_blocks')end)
  end)
  self:enqueue(function(e)ctx.phaseC:play('entity.generic.explode',pos(center),1,e)end)
  if ctx.flashJobs then for _,job in ipairs(ctx.flashJobs(center,env))do self:enqueue(job)end
  elseif ctx.flash then self:enqueue(function(e)ctx.flash(center,e)end)end
  local p=env.player:K2_GetActorLocation();local q=pos(center);local distance=math.sqrt((p.X-q.X)^2+(p.Y-q.Y)^2+(p.Z-q.Z)^2)/100
  if distance<4 then self:enqueue(function(e)
   if damageFn then damageFn(e,.3*(1-distance/4))else self:damage(e,.3*(1-distance/4),'tnt')end
  end)end
  ctx.log('MC23_EXPLOSION_START center='..key(center.x,center.y,center.z)..' candidates='..#list..' radius=4')
 end
 function M:waterNear(c)
  for dy=-4,4 do for dx=-4,4 do for dz=0,1 do if name(cells()[key(c.x+dx,c.y+dy,c.z+dz)])=='water'then return true end end end end;return false
 end
 function M:supported(leaf)
  local queue={{leaf.x,leaf.y,leaf.z,0}};local head=1;local seen={[key(leaf.x,leaf.y,leaf.z)]=true}
  while head<=#queue do local p=queue[head];head=head+1
   if p[4]<6 then for _,d in ipairs({{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}})do
    local x,y,z=p[1]+d[1],p[2]+d[2],p[3]+d[3];local k=key(x,y,z);local c=cells()[k]
    if isLog(c)then return true end
    if isLeaf(c)and not seen[k]then seen[k]=true;queue[#queue+1]={x,y,z,p[4]+1}end
   end end
  end;return false
 end
 function M:grow(c,env)
  local h=math.random(4,6);local planned={};local trunk={}
  local root=key(c.x,c.y,c.z);self.growing=self.growing or{};if self.growing[root]then return false end
  for dz=0,h-1 do local k=key(c.x,c.y,c.z+dz);local other=cells()[k]
   if other and other~=c then return false end
   local q={x=c.x,y=c.y,z=c.z+dz,type=ctx.types.oak_log,variant=0};planned[#planned+1]=q;trunk[k]=true
  end
  for dz=h-3,h do local radius=dz==h and 1 or 2
   for dy=-radius,radius do for dx=-radius,radius do
    local k=key(c.x+dx,c.y+dy,c.z+dz)
    if not trunk[k]and not cells()[k]and not(math.abs(dx)==radius and math.abs(dy)==radius and(dz==h or math.random()<.5))then
     local q={x=c.x+dx,y=c.y+dy,z=c.z+dz,type=ctx.types.oak_leaves,variant=0,state={persistent=false}}
      planned[#planned+1]=q
    end
   end end
  end
  self.growing[root]=true;local blocked=false;local added=0
  for i=1,h do local q=planned[i];self:enqueue(function(current)if not ctx.emptyNative(q,current)then blocked=true end end)end
  self:enqueue(function(current)
   if blocked or cells()[root]~=c then self.growing[root]=nil;return end
   assert(ctx.mutate(root,nil,current))
   for _,p in ipairs(planned)do local q=p;self:enqueue(function(e)
    if not cells()[key(q.x,q.y,q.z)]and(trunk[key(q.x,q.y,q.z)]or ctx.emptyNative(q,e))then self:put(q,e);added=added+1 end
   end)end
   self:enqueue(function()self.growing[root]=nil;self.dirty=true;ctx.log('MC23_TREE_GROWN root='..root..' height='..h..' added='..added)end)
  end);return true
 end
 function M:randomTick(c,env)
  if not c then return end;local d=ctx.registry[c.type];local k=key(c.x,c.y,c.z);local s=state(c)
  if d.kind=='sapling'then
   if math.random(7)==1 then if(s.age or 0)==0 then s.age=1;self.dirty=true else self:grow(c,env)end end
  elseif d.kind=='farmland'then
   local oldMoist,oldDry=s.moist,s.dry
   local water=self:waterNear(c);s.moist=water and 7 or math.max(0,(s.moist or 0)-1)
   local variant=s.moist>0 and 1 or 0;if c.variant~=variant then ctx.variant(k,variant,env)end
   local above=cells()[key(c.x,c.y,c.z+1)]
   if s.moist==0 and not above then s.dry=(s.dry or 0)+1;if s.dry>=7 then self:replace(c,'dirt',nil,env)end else s.dry=0 end
   if s.moist~=oldMoist or s.dry~=oldDry then self.dirty=true end
  elseif d.kind=='crop'then
   local ground=cells()[key(c.x,c.y,c.z-1)]
   if name(ground)~='farmland'then self:harvest(k,env,'unsupported');return end
   local moist=ground.state and(ground.state.moist or 0)>0
   if(s.age or 0)<d.stages-1 and math.random(moist and 3 or 8)==1 then s.age=(s.age or 0)+1;ctx.variant(k,s.age,env);self:indexCell(k,cells()[k]);self.dirty=true;ctx.log('MC23_CROP_STAGE '..k..' age='..s.age)end
  elseif isLeaf(c)and not s.persistent and s.decay then
   if not self:supported(c)then self:harvest(k,env,'decay')else s.decay=false;self:indexCell(k,c);self.dirty=true end
  end
 end
 function M:step(env)
  local started=os.clock();local now=started
  for k,f in pairs(self.fuses)do local c=cells()[k]
   if not c then self.fuses[k]=nil
   elseif now>=f.at then self.fuses[k]=nil;self.detonating[k]=true;self:enqueue(function(e)if cells()[k]==c then self:blast(c,e)end end)
   elseif now>=f.flashAt then f.flashAt=now+.2;local v=(c.variant or 0)==0 and 1 or 0;self:enqueue(function(e)if cells()[k]==c and self.fuses[k]and not self.detonating[k]then ctx.variant(k,v,e)end end)end
  end
  if now>=self.secondAt then
   self.secondAt=now+1;self.tickDebt=math.min(10000,self.tickDebt+math.max(1,math.ceil(3*#self.index/4096))*self.growth_speed)
   local p=env.player:K2_GetActorLocation();local x,y,z=math.floor(p.X/100),math.floor(p.Y/100),math.floor(p.Z/100)
   local touching=false;for dz=-1,0 do for dx=-1,1 do for dy=-1,1 do local c=cells()[key(x+dx,y+dy,z+dz)];if name(c)=='lava'and ctx.intersects(c,env)then touching=true end end end end
   if touching then self:damage(env,.08,'lava')end
  end
  repeat
   local job=self.queue[self.head]
   if job then self.queue[self.head]=false;self.head=self.head+1;local at=os.clock();job(env);local ms=(os.clock()-at)*1000;self.max_job_ms=math.max(self.max_job_ms or 0,ms);if ms>4 then local info=debug.getinfo(job,'Sl');ctx.log('MC24_JOB_SPIKE ms='..ms..' source='..info.short_src..':'..info.linedefined)end
   elseif self.tickDebt>0 and #self.index>0 and not(ctx.saveActive and ctx.saveActive())then self.tickDebt=self.tickDebt-1;local k=self.index[math.random(#self.index)];self:randomTick(cells()[k],env)
   else if #self.index==0 then self.tickDebt=0 end;break end
  until(os.clock()-started)*1000>=.8
  if self.head>#self.queue then self.queue={};self.head=1 end
  if self.dirty and now>=self.saveAt and self.head>#self.queue then
   local remaining=.8-(os.clock()-started)*1000
   if remaining>.05 then
    local done;if ctx.saveSlice then done=ctx.saveSlice(remaining)else ctx.save();done=true end
    if done then self.dirty=false;self.saveAt=now+2 end
   end
  end
  local cpu=(os.clock()-started)*1000;self.max_cpu_ms=math.max(self.max_cpu_ms,cpu);if cpu>4 then ctx.log('MC24_MECHANICS_SPIKE ms='..cpu..' queue='..(#self.queue-self.head+1)..' save='..tostring(ctx.saveActive and ctx.saveActive()))end
 end
 function M:start(env)
  self:cancel();self.index={};self.positions={};self.queue={};self.head=1;self.fuses={};self.detonating={};self.tickDebt=0;self.secondAt=os.clock()+1;self.saveAt=os.clock()+2
  for k,c in pairs(cells())do self:initialize(c);self:indexCell(k,c)end
  if ctx.config.debug then
   local S=dofile(ctx.base..'/cell_state.lua');local rows={};for _,c in pairs(cells())do rows[#rows+1]=S.row(c,name(c))end
   table.sort(rows,function(a,b)return key(a[1],a[2],a[3])<key(b[1],b[2],b[3])end)
   local f=assert(io.open(ctx.base..'/task23-restored-state.json','wb'));f:write(dofile(ctx.base..'/json.lua').encode(rows));f:close()
   ctx.log('MC23_RESTORED_STATE_CAPTURE cells='..#rows..' before_random_tick=true')
  end
  local stamp=ctx.epoch();self.handle=Timers.loop(33,function()
   if stamp~=ctx.epoch()or ctx.quiesced()then return true end

   local now=os.clock()
   if not self.costBaseline and now<self.secondAt and next(self.fuses)==nil and self.head>#self.queue and self.tickDebt<=0 and not(self.dirty and now>=self.saveAt)then return false end
   local current=ctx.environment();if not current then return false end
   local ok,err=xpcall(function()M:step(current)end,debug.traceback)
   if not ok then ctx.log('MC23_ERROR '..tostring(err));return true end;return false
  end,'mechanics')
  ctx.log('MC23_SERVICE_READY tickable='..#self.index..' growth_speed='..self.growth_speed..' budget_ms=1')
 end
 function M:cancel()if self.handle then Timers.cancel(self.handle);self.handle=nil end;if ctx.cancelSave then ctx.cancelSave()end;self.queue={};self.head=1;self.fuses={};self.growing={}end
 Timers.onEpoch('mechanics',function()M:cancel();M.index={};M.positions={}end)
 dofile(ctx.base..'/decor70.lua')(ctx,M)
 M.name=name;M.state=state;M.isLeaf=isLeaf;M.isLog=isLog
 return M
end
