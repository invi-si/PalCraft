-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

local P={limit=12}
local function delta(a,b,keys)
 if not b then return math.huge end
 local n=0;for _,k in ipairs(keys)do n=n+math.abs(a[k]-b[k])end;return n
end
function P.queue(s,poses,bob)
 s.bossDesiredE=poses;s.bossBobE=bob;s.bossWriteCursorE=s.bossWriteCursorE or 1
 s.bossAppliedE=s.bossAppliedE or{}
end
function P.flush(s,budget)
 local rows=s.bossDesiredE;if not rows then return 0 end
 local used=0;local count=#rows*2+1
 for _=1,count do
  if used>=budget then break end
  local i=s.bossWriteCursorE;s.bossWriteCursorE=i%count+1
  if i==count then
   if not s.bossRootAppliedE or math.abs(s.bossBobE-s.bossRootAppliedE)>.5 then
    _G.MC_OUT_K('K2_SetRelativeLocation',s.root,{X=0,Y=0,Z=s.bossBobE},false,ignoredHitJ(),true)
    s.bossRootAppliedE=s.bossBobE;used=used+1
   end
  else
   local part=math.ceil(i/2);local desired=rows[part];local old=s.bossAppliedE[part]or{};s.bossAppliedE[part]=old
   if i%2==1 then
    if delta(desired.rotation,old.rotation,{'Pitch','Yaw','Roll'})>1 then
     _G.MC_OUT_K('K2_SetRelativeRotation',s.parts[part],desired.rotation,false,ignoredHitJ(),true);old.rotation=desired.rotation;used=used+1
    end
   elseif delta(desired.location,old.location,{'X','Y','Z'})>.5 then
    _G.MC_OUT_K('K2_SetRelativeLocation',s.parts[part],desired.location,false,ignoredHitJ(),true);old.location=desired.location;used=used+1
   end
  end
 end
 return used
end
return P
