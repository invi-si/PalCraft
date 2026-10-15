-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local H={active=false,events={},rows={},owner='outside-master'}
function H:call(kind,detail,fn,...)
 if not self.active then return fn(...)end
 local at=os.clock();local result=table.pack(fn(...));local elapsed=(os.clock()-at)*1000
 self.events[#self.events+1]={kind=kind,detail=detail,owner=self.owner,master=self.master,at=at,ms=elapsed}
 return table.unpack(result,1,result.n)
end
function H:install(UE,T)
 self.timers=T
 for _,name in ipairs({'LoadAsset','StaticLoadObject','StaticFindObject','FindObject','FindFirstOf','FindAllOf'})do
  local fn=_G[name]
  if type(fn)=='function'then _G[name]=function(...)local detail=self.active and tostring(select(1,...))or'';return self:call(name,detail,fn,...)end end
 end
 function UE.Native109(object,method,...)
  if not H.active then return object[method](object,...)end
  return H:call(method,method,object[method],object,...)
 end
 function UE.GetAsset109(object,data)
  if not H.active then return object:GetAsset(data)end
  local detail=data.PackageName:ToString()..'.'..data.AssetName:ToString()
  return H:call('GetAsset',detail,object.GetAsset,object,data)
 end
end
function H:start(sample)
 assert(not self.active);self.rows={};self.events={};self.sample=sample;self.startAt=os.clock();self.active=true
 self.timers.beginBudgetProfile()
 self.timers.budgetProfile.onRecord=function(owner,ms,frame)
  local row=self.current;if row then row.owners[#row.owners+1]={owner,ms}end
 end
end
function H:beginFrame(master)
 if not self.active then return end
 self.master=master;self.owner='master-start'
 local at=os.clock();local frame,delta,p,streaming=self.sample()
 self.current={master=master,frame=frame,deltaMs=delta,at=at,position=p,streaming=streaming,heapStartKB=collectgarbage('count'),owners={},firstEvent=#self.events+1,sampleMs=(os.clock()-at)*1000}
end
function H:endFrame()
 local row=self.current;if not self.active or not row then return end
 row.luaMs=(os.clock()-row.at)*1000;row.heapEndKB=collectgarbage('count');row.lastEvent=#self.events
 local gc=self.timers.gcBudget;row.gcMs=gc and gc.lastMs or 0;row.gcCycles=gc and gc.cycles or 0
 self.rows[#self.rows+1]=row;self.current=nil;self.owner='outside-master'
 if #self.rows>=3600 then self.active=false end
end
function H:finish()
 self.active=false;self.current=nil
 return{rows=self.rows,events=self.events,seconds=os.clock()-self.startAt,budget=self.timers.endBudgetProfile(),gc=self.timers.gcBudget:status(),alignment='calibrate reflected world delta pipeline delay against master start intervals; native CPU/GPU/streaming not individually timed'}
end
return H
