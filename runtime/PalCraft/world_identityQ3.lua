-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local Q={}
 local function text(v)if type(v)=='string'then return v end;return v and v:ToString()or''end
 function Q:resolve(instance,epoch)
  local pc=ctx.UE.GetPlayerController();if not ctx.valid(pc)then return ''end
  local world=pc:GetWorld();if not ctx.valid(world)or not world:GetFullName():find('/Game/Pal/Maps/MainWorld_5/',1,true)then return ''end
  local address=world:GetAddress()
  if self.epoch==epoch and self.address==address and self.id then return self.id end
  if self.epoch==epoch and self.address==address and os.clock()<(self.next or 0)then return ''end
  self.epoch,self.address,self.id,self.next=epoch,address,nil,os.clock()+.25
  local ok,id,detail=pcall(function()
   local state=world.GameState
   local current=text(instance:GetSelectedWorldName())
   if ctx.valid(state)then
    local stateId=text(state:GetWorldSaveDirectoryName()):upper()
    local stateName=text(state:GetWorldName())
    if ctx.validId(stateId)and stateName~=''and stateName==current and state:GetWorld():GetAddress()==address then
     return stateId,'source=live_GameState current='..string.format('%q',current)..' state_name='..string.format('%q',stateName)..' state_id='..stateId
    end
    local diagnostic='state_id='..string.format('%q',stateId)..' state_name='..string.format('%q',stateName)..' current='..string.format('%q',current)
    if self.stateDetail~=diagnostic then ctx.log('MCQ3_GAMESTATE '..diagnostic);self.stateDetail=diagnostic end
   end
   return '', 'live_GameState_identity_not_ready'
  end)
  if not ok then detail=tostring(id);id=''end
  if detail~=self.detail then ctx.log('MCQ3_WORLD_IDENTITY '..tostring(detail));self.detail=detail end
  if ctx.validId(id)then self.id=id;ctx.log('MCQ3_WORLD_VERIFIED id='..id..' epoch='..epoch..' source=verified_native_current_world');return id end
  return ''
 end
 return Q
end
