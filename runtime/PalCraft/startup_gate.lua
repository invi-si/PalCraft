-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local G={open=false,probing=false,serial=0}
 function G:bootstrapAllowed()
  if self.schemaAdmitted then return true end
  local f=io.open(ctx.logPath,'rb');if not f then return false end
  local size=f:seek('end');f:seek('set',math.max(0,size-65536));local tail=f:read('*a');f:close()

  if not tail:find("[PalSchema] Added Item 'MC_Bed'",1,true)then return false end
  local last;for line in tail:gmatch('[^\r\n]+')do if line:find('[PalSchema]',1,true)then last=line end end
  if last~=self.schemaLine then self.schemaLine=last;self.schemaAt=ctx.now();return false end
  if ctx.now()-self.schemaAt>=2000 then self.schemaAdmitted=true;return true end;return false
 end
 function G:world(epoch,jobs,finish)
  self.serial=self.serial+1;local serial=self.serial;self.open=false;self.probing=false

  self.worldAt=ctx.now();local index=1;local delay=0
  ctx.log('MC35_WORLD_DELAY_BEGIN epoch='..epoch..' delay_ms='..delay..' jobs='..#jobs)
  ctx.timers.loop(1,function()
   if serial~=self.serial or epoch~=ctx.epoch()or ctx.quiesced()then return true end
   if ctx.now()-self.worldAt<delay then return false end
   self.open=true;self.admitted=true
   local slice=ctx.now();local done=0
   while index<=#jobs do
    local began=ctx.now();jobs[index]();local ms=ctx.now()-began
    ctx.log('MC35_STARTUP_SLICE index='..index..' work_ms='..ms..' elapsed_ms='..math.floor(ctx.now()-self.worldAt));index=index+1;done=done+1
    
    if done>=16 or ctx.now()-slice>=16 then return false end
   end
   if done>0 then return false end
   ctx.log('MC35_ASSET_GATE_OPEN elapsed_ms='..math.floor(ctx.now()-self.worldAt));finish();return true
  end,'startup-admission')
 end
 function G:reset()
  self.serial=self.serial+1;self.open=false;self.uiOpen=false;self.probing=false;self.worldAt=nil
 end
 return G
end
