-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local C={};local UE,valid=ctx.UE,ctx.valid
 function C:signal()self.pending=true;self.tries=0;self.nextAt=nil end
 function C:tick(env)
  if self.counts and not self.pending then return end
  if self.nextAt and os.clock()<self.nextAt then return end
  local state=env.controller:GetPalPlayerState();if not valid(state)then return end
  local record=state:GetRecordData();local counts={}
  record.PalCaptureCount.Items:ForEach(function(_,v)
   local row=v:get();counts[row.Key:ToString()]=row.Value
  end)
  if not self.counts then self.counts=counts;self.pending=false;return end
  local changed=false
  for id,count in pairs(counts)do
   if count>(self.counts[id]or 0)then
    local label={};UE.Object('/Script/Pal.Default__PalUtility'):GetDatabaseCharacterParameter(env.controller):GetLocalizedCharacterName(UE.FindOrAddFName(id),label)
    local name=label.OutText and UE.GetKismetTextLibrary():Conv_TextToString(label.OutText)or id
    name=type(name)=='string'and name or name:ToString()
    local ko=ctx.uiKit.language57 and ctx.uiKit.language57.lang=='ko'
    if id=='MC_Zombie'then name=ko and '좀비'or 'Zombie'end
    if id=='MC_Skeleton'then name=ko and '좀비'or 'Skeleton'end
    ctx.uiKit:notify(ko and(name..'을(를)')or('Caught '..name..'!'),ko and'포획했습니다!'or'')
    ctx.log('MC82_CAPTURE_TOAST id='..id..' before='..(self.counts[id]or 0)..' after='..count..' name='..name)
    changed=true
   end
  end
  self.counts=counts;self.tries=(self.tries or 0)+1
  if changed or self.tries>=10 then self.pending=false else self.nextAt=os.clock()+.1 end
 end
 function C:reset()self.counts=nil;self.pending=false;self.tries=0;self.nextAt=nil end
 return C
end
