-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(gc,now)
 local G={steps=0,cycles=0,totalMs=0,maxMs=0,kb=0,peakKB=0,stepKB=0,sliceMs=2,maxSteps=64}
 function G:configure()

  local ok=pcall(gc,'incremental',110,200,10)
  if not ok then gc('setpause',110);gc('setstepmul',200)end

  gc('stop');self.mode=ok and'master-incremental54'or'master-incremental53'
 end
 function G:tick()
  if self.probe then
   local p=self.probe;local elapsed=now()-p.at
   if elapsed<3 then return end
   p.seconds=elapsed;p.endKB=gc('count');p.growthKBps=(p.endKB-p.startKB)/elapsed
   local at=now();gc('collect');p.fullMs=(now()-at)*1000;p.afterKB=gc('count')
   self.probe=nil;self.result=p;self:configure();return
  end
  local at=now();local done=false;local passes=0
  repeat
   done=gc('step',0)or done;passes=passes+1
  until done or passes>=self.maxSteps or(now()-at)*1000>=self.sliceMs
  local ms=(now()-at)*1000
  self.steps=self.steps+1;self.totalMs=self.totalMs+ms;self.maxMs=math.max(self.maxMs,ms)
  if done then
   self.cycles=self.cycles+1;self.cycleKB=gc('count')
   self.minCycleKB=math.min(self.minCycleKB or self.cycleKB,self.cycleKB)
  end
  self.lastMs=ms;self.kb=gc('count');self.peakKB=math.max(self.peakKB,self.kb)
 end
 function G:beginProbe()
  assert(not self.probe,'GC probe already active');gc('collect');gc('stop')
  self.result=nil;self.probe={at=now(),startKB=gc('count'),lua=_VERSION}
 end
 function G:status()
  return{mode=self.mode,stepKB=self.stepKB,sliceMs=self.sliceMs,maxSteps=self.maxSteps,steps=self.steps,cycles=self.cycles,totalMs=self.totalMs,maxMs=self.maxMs,kb=self.kb,peakKB=self.peakKB,cycleKB=self.cycleKB,minCycleKB=self.minCycleKB,probe=self.result}
 end
 G:configure();return G
end
