-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U)
 U.inventoryFit67=dofile(ctx.base..'/ui67_rules.lua').inventoryFit
 function U:asset67(name)
  local p='/Game/MinecraftUI/T67/'..name;local a=ctx.UE.Object(p..'.'..name)
  if not ctx.valid(a)then a=ctx.UE.GetAsset109(ctx.UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=ctx.UE.FindOrAddFName(p),AssetName=ctx.UE.FindOrAddFName(name)})end
  if ctx.valid(a)then self:retainTexture(a);return a end
 end
 local tabs={{'Inventory','MC_CraftingTable','Inventory',96},{'Pals','PalSphere','Pals',74},{'PC','MC_Chest','Pal Box',92},{'Technology','MC_IronPickaxe','Technology',108},{'Palpedia','MC_Bookshelf','Palpedia',100}}
 function U:navTabs(ns,env,kind)
  if not({Inventory=true,Pals=true,PC=true,Technology=true,Palpedia=true})[kind]then return end
  local _,unit=self:metrics(env);unit=kind=='Inventory'and ns.inventoryUnit67 or ns.unit67 or unit;ns.navKind=kind;ns.navRects={};self.env=env
  local inventory=kind=='Inventory';local x=inventory and-196 or-294;local y=inventory and-109 or-162
  local scale=inventory and .80 or 1
  if inventory then x=x-(ctx.UE.drawer67Shift or 0)end
  for i,t in ipairs(tabs)do
   local w=t[4]*scale;local n=self:makeNode(ns,'Nav46_'..i,'Image');local icon=self:makeNode(ns,'Nav46Icon_'..i,'Image');local label=self:makeNode(ns,'Nav67Label'..i,'TextBlock')
   self:brush(n,t[1]==kind and'T_MC_UI_widget_button_disabled'or'T_MC_UI_widget_button');self:position(n,x,y,w,25,unit);n.Slot:SetZOrder(85);n:SetRenderOpacity(1)
   local tex=i==5 and self:asset('T_MC_Bookshelf')or self.items:icon(t[2]);self:icon(icon,tex,16,1);self:position(icon,x+4,y+4,16,16,unit);icon.Slot:SetZOrder(86);icon:SetRenderOpacity(1)
   self:position(label,x+23,y+8,w-25,12,unit);self:putText(label,self:trimLabel(t[3],w-25));self:textStyle(label,unit,false);label.Slot:SetZOrder(86);label:SetRenderOpacity(1)
   ns.navRects[i]={x=x,y=y,w=w,h=25,kind=t[1],label=t[3],node=n};x=x+w+2
  end
 end
 local book=U.recipeBook
 function U:recipeBook(ns,env,B)
  book(self,ns,env,B)
  if not B.mode and B.size==2 and not B.creative and self.character67 then self.character67:paint(ns,env,B)end
 end
end
