-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local P={}
 local function visible(w)
  if not ctx.valid(w)or not w:IsVisible()or w:GetRenderOpacity()<=0 then return false end
  local name=w:GetFullName()
  if name:find('Default__',1,true)or not name:find('/Engine/Transient',1,true)then return false end
  local widgetClass=StaticFindObject('/Script/UMG.Widget')
  local userClass=StaticFindObject('/Script/UMG.UserWidget')
  local p=w;local seen={}
  for depth=1,48 do
   if not ctx.valid(p)or seen[p:GetAddress()]then return false end
   seen[p:GetAddress()]=true
   if p:IsA(widgetClass)then
    if not p:IsVisible()or p:GetRenderOpacity()<=0 then return false end
    if p:IsA(userClass)and p:IsInViewport()then return true end
    local parent=p:GetParent()
    p=ctx.valid(parent)and parent or p:GetOuter()
   else p=p:GetOuter()end
  end
  return false
 end
 function P:inspect(controller,status)
  local now=os.clock();if now<(self.nextAt or 0)then return self.active end
  self.nextAt=now+.25;local active
  for _,w in ipairs(FindAllOf('WBP_CharacterMake_C')or{})do
   if visible(w)then active=w:GetClass():GetFullName();break end
  end

  if not active and status~='alive'and ctx.valid(controller)and controller.bShowMouseCursor then
   for _,w in ipairs(FindAllOf('CommonActivatableWidget')or{})do
    if visible(w)and w:IsActivated()then
     local name=w:GetClass():GetFullName()
     if name:find('/Game/Pal/Blueprint/UI/',1,true)and not name:find('/System/',1,true)and not name:find('/Title/',1,true)and not name:find('/InGame/',1,true)and not name:find('Loading',1,true)then active=name;break end
    end
   end
  end
  if active~=self.active then ctx.log('MCQ2_PRESPAWN_UI active='..tostring(active)..' readiness='..tostring(status));self.active=active end
  return active
 end
 function P:reset()self.nextAt=nil;self.active=nil end
 return P
end
