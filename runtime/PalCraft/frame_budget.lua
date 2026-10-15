-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local P={}
function P.new(now)
 local p={now=now,owners={},spikes={},frames=0,frameMs=0,maxFrameMs=0,start=now()}
 function p:record(owner,ms,frame,detail)
  if self.onRecord then self.onRecord(owner,ms,frame)end
  local r=self.owners[owner]
  if not r then r={count=0,total_ms=0,max_ms=0,over33=0,hist={}};self.owners[owner]=r end
  r.count=r.count+1;r.total_ms=r.total_ms+ms;r.max_ms=math.max(r.max_ms,ms)
  local bin=math.min(1000,math.ceil(ms*4));r.hist[bin]=(r.hist[bin]or 0)+1
  if ms>33 then
   r.over33=r.over33+1
   if #self.spikes<128 then self.spikes[#self.spikes+1]={owner=owner,ms=ms,frame=frame,detail=detail}end
  end
 end
 function p:frame(ms)self.frames=self.frames+1;self.frameMs=self.frameMs+ms;self.maxFrameMs=math.max(self.maxFrameMs,ms)end
 function p:report()
  local out={seconds=self.now()-self.start,frames=self.frames,lua_mean_ms=self.frameMs/math.max(1,self.frames),lua_max_ms=self.maxFrameMs,owners={},spikes=self.spikes,spikeLimit=128}
  for owner,r in pairs(self.owners)do
   local n,target=0,math.ceil(r.count*.99);local p99=0
   for bin=0,1000 do n=n+(r.hist[bin]or 0);if n>=target then p99=bin/4;break end end
   out.owners[owner]={count=r.count,mean_ms=r.total_ms/r.count,p99_ms=p99,max_ms=r.max_ms,over33=r.over33,total_ms=r.total_ms}
  end
  return out
 end
 return p
end
return P
