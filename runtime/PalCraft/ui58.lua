-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U)
 local UE,valid=ctx.UE,ctx.valid
 local design=dofile(ctx.base..'/ui_design.lua')
 function U:panel58(ns,w,h,unit)
  local x,y=-w/2,-90
  for key,p in pairs({Outline={x,y,w,h,'000000'},Face={x+1,y+1,w-2,h-2,'C6C6C6'},Top={x+2,y+1,w-4,2,'FFFFFF'},Left={x+1,y+2,2,h-4,'FFFFFF'},Bottom={x+2,y+h-3,w-4,2,'555555'},Right={x+w-3,y+2,2,h-4,'555555'}})do
   local n=ns['Panel57'..key];self:fill(n,p[5]);self:position(n,p[1],p[2],p[3],p[4],unit)
  end
 end
 local apply=U.apply
 function U:apply(w,name,env)
  local factor,unit=apply(self,w,name,env);local ns=ctx.widgets(w)
  for key,p in pairs(design.layouts[name]or{})do if p.sprite=='T_MC_UI_slot'and not p.hidden and valid(ns[key])then
   if name=='WBP_MCPC'then self:fill(ns[key],'8B8B8B')else self:brush(ns[key],'T_MC_UI_slot')end
   for _,side in ipairs({'Top','Left','Bottom','Right'})do local n=ns['Slot57'..side..key];if valid(n)then n.Slot:SetZOrder(41)end end
  end end
  return factor,unit
 end
 function U:repairNav58(ns)
  if ns.navRepaired61 then return end;ns.navRepaired61=true
  if valid(ns.Nav46Icon_5)then local tex=self:asset('T_MC_Bookshelf');self:retainTexture(tex);ns.Nav46Icon_5:SetBrushFromTexture(tex,false);ns.Nav46Icon_5:SetColorAndOpacity({R=1,G=1,B=1,A=1})end
 end
 local nav=U.navTabs
 function U:navTabs(ns,env,kind)nav(self,ns,env,kind);self:repairNav58(ns)end
 local work=U.dexWork46
 function U:dexWork46(ns,env,F,r,works)
  work(self,ns,env,F,r,works);self:dexRows58(ns,env,F)
 end
 function U:dexRows58(ns,env,F)
  local _,unit=self:metrics(env)
  for i=1,14 do
   local row=F.filtered[F.page*14+i];local n=ns['DexLabel'..i];local text=self:makeNode(ns,'Dex58Name'..i,'TextBlock')
   text:SetVisibility(row and 3 or 1)
   if row then
    local prefix='#'..row.number..' ';local width=self:textWidth53(prefix);self:putText(n,prefix)
    local label=row.detail>=2 and row.label or'???';local hangul=false;for _,cp in utf8.codes(label)do if cp>=0xac00 and cp<=0xd7a3 then hangul=true;break end end
    local ratio=hangul and 1.2 or 1;self:putText(text,self:trimLabel(label,(98-width)/ratio));self:textStyle(text,unit,false)
    local font=text.Font;font.Size=math.floor(6*unit*ratio+.5);text:SetFont(font)
    local y=-78+(i-1)*12;self:position(text,-120+width,y-(hangul and 1 or 0),98-width,12,unit);text:SetClipping(1);text.Slot:SetZOrder(42)
   end
  end
 end
 function U:muteNativeText58(controller)
  self:restoreNativeText58();self.nativeText58={}
  for _,w in ipairs(FindAllOf('PalActivatableWidget')or{})do if valid(w)and w:IsActivated()and w:GetOwningPlayer():GetAddress()==controller:GetAddress()then
   self.nativeText58[#self.nativeText58+1]={widget=w,enabled=w:GetIsEnabled()};w:SetIsEnabled(false)
  end end
  ctx.log('MC58_TEXT_NATIVE_INPUT_MUTED count='..#self.nativeText58)
 end
 function U:restoreNativeText58()
  for _,r in ipairs(self.nativeText58 or{})do if valid(r.widget)then r.widget:SetIsEnabled(r.enabled)end end;self.nativeText58=nil
 end
 local focus,clear,release=U.focusField,U.clearField,U.releaseInput
 function U:focusField(env,n)self:muteNativeText58(env.controller);focus(self,env,n)end
 function U:clearField()self:restoreNativeText58();clear(self)end
 function U:releaseInput(w)self:restoreNativeText58();release(self,w)end
 dofile(ctx.base..'/timers.lua').onEpoch('text-native-fence',function()U.nativeText58=nil end)
end
