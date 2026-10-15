-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(UE,valid)
 local G={}
 function G:widget(w)
  return valid(w)and w:IsA(UE.Object('/Script/UMG.UserWidget'))
 end
 function G:activatable(w)
  return self:widget(w)and w:IsA(UE.Object('/Script/CommonUI.CommonActivatableWidget'))
 end
 function G:active(w,controller)
  if not self:activatable(w)then return false end
  if controller then local pc=w:GetOwningPlayer();if not valid(pc)or pc:GetAddress()~=controller:GetAddress()then return false end end
  return w:IsActivated()==true
 end
 function G:capture(w)
  if not self:activatable(w)then return end
  return{node=w,name=w:GetFullName(),class=w:GetClass():GetFullName()}
 end
 function G:resolve(row)
  if not row or not self:activatable(row.node)then return end
  local w=row.node
  if w:GetFullName()==row.name and w:GetClass():GetFullName()==row.class then return w end
 end
 function G:radialOpen(w)
  if not self:activatable(w)then return false end
  local name=w:GetClass():GetFullName():lower()
  if not name:find('wbp_playerradialmenu.wbp_playerradialmenu_c',1,true)then return false end
  local out={};_G.MC_OUT_K('IsAnyMenuOpened',w,out)
  return out.IsOpened==true
 end
 function G:mainRoot(w,controller)
  if not self:activatable(w)or not w:GetClass():GetFullName():find('WBP_InGameMainMenu.WBP_InGameMainMenu_C',1,true)then return false end
  local pc=w:GetOwningPlayer();return valid(pc)and pc:GetAddress()==controller:GetAddress()
 end
 function G:closeOwned(w,controller)
  if not self:active(w,controller)then return false end

  if self:mainRoot(w,controller)then w:SetRenderOpacity(0);w:Close()
  else w:DeactivateWidget()end
  return true
 end
 function G:releaseMain(controller)
  local closed={}
  for _,w in ipairs(FindAllOf('WBP_InGameMainMenu_C')or{})do
   if self:mainRoot(w,controller)and self:active(w,controller)then
    closed[#closed+1]=w:GetFullName();self:closeOwned(w,controller)
   end
  end
  return closed
 end
 function G:visible(w,controller)
  if not self:active(w,controller)or w:GetRenderOpacity()<=0 or not w:IsVisible()then return false end
  local name=w:GetClass():GetFullName():lower()
  if name:find('/minecraft',1,true)or name:find('palhud_ingame_inputlistener',1,true)then return false end

  local node=w;local seen={};local escapeMenu=false
  for _=1,32 do
   if not valid(node)or not node:IsA(UE.Object('/Script/UMG.Widget'))then break end
   local address=node:GetAddress();if seen[address]then return false end;seen[address]=true
   if not node:IsVisible()or node:GetRenderOpacity()<=0 then return false end
   if node:IsA(UE.Object('/Script/UMG.UserWidget'))then
    local class=node:GetClass():GetFullName():lower()
    if class:find('wbp_ingamemainmenu.wbp_ingamemainmenu_c',1,true)or class:find('wbp_menuesc.wbp_menuesc_c',1,true)then escapeMenu=true end
   end
   local parent=node:GetParent()
   if not valid(parent)then
    local outer=node:GetOuter()
    if valid(outer)and outer:IsA(UE.Object('/Script/UMG.WidgetTree'))then parent=outer:GetOuter()end
   end
   node=parent
  end

  local focused=controller and(w:HasUserFocus(controller)or w:HasUserFocusedDescendants(controller))
  local visible=self:radialOpen(w)or((w.InputConfig==1 or w.InputConfig==3)and focused)or name:find('worldmap',1,true)~=nil
   or name:find('map_for',1,true)~=nil or name:find('wbp_map_base.wbp_map_base_c',1,true)~=nil or name:find('dialog',1,true)~=nil
   or name:find('ingamemainmenu',1,true)~=nil

  return visible,escapeMenu and not(name:find('worldmap',1,true)or name:find('map_for',1,true) or name:find('wbp_map_base.wbp_map_base_c',1,true)or name:find('dialog',1,true))
 end
 return G
end
