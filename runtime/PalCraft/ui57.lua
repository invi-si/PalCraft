-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U)
 local UE,valid=ctx.UE,ctx.valid
 U.margins=U.margins or dofile(ctx.base..'/ui_sprites.lua')
 U.margins.T_MC_UI_panel={4/176,4/166};U.margins.T_MC_UI_slot={1/18,1/18}
 local design=dofile(ctx.base..'/ui_design.lua')
 local sizes={WBP_MCPals={248,180},WBP_MCPC={292,200},WBP_MCTechnology={252,180},WBP_MCPalpedia={256,200}}
 function U:edge57(ns,key,x,y,w,h,color,z,unit)
  local n=self:makeNode(ns,key,'Image');self:fill(n,color);self:position(n,x,y,w,h,unit);n.Slot:SetZOrder(z);n:SetVisibility(3)
 end
 function U:panel57(ns,w,h,unit)
  local x,y=-w/2,-h/2
  self:edge57(ns,'Panel57Outline',x,y,w,h,'000000',5,unit)
  self:edge57(ns,'Panel57Face',x+1,y+1,w-2,h-2,'C6C6C6',6,unit)
  self:edge57(ns,'Panel57Top',x+2,y+1,w-4,2,'FFFFFF',7,unit)
  self:edge57(ns,'Panel57Left',x+1,y+2,2,h-4,'FFFFFF',7,unit)
  self:edge57(ns,'Panel57Bottom',x+2,y+h-3,w-4,2,'555555',7,unit)
  self:edge57(ns,'Panel57Right',x+w-3,y+2,2,h-4,'555555',7,unit)
 end
 local apply=U.apply
 function U:apply(w,name,env)
  local factor,unit=apply(self,w,name,env);local ns=ctx.widgets(w)
  local size=sizes[name];if size then self:panel57(ns,size[1],size[2],unit)
   for key,p in pairs(design.layouts[name]or{})do if p.sprite=='T_MC_UI_slot'and p.position and not p.hidden then
    local x,y,sw,sh=p.position[1]/3,p.position[2]/3,p.size[1]/3,p.size[2]/3
    self:edge57(ns,'Slot57Top'..key,x,y,sw,1,'373737',18,unit);self:edge57(ns,'Slot57Left'..key,x,y,1,sh,'373737',18,unit)
    self:edge57(ns,'Slot57Bottom'..key,x,y+sh-1,sw,1,'FFFFFF',18,unit);self:edge57(ns,'Slot57Right'..key,x+sw-1,y,1,sh,'FFFFFF',18,unit)
   end end
  end
  if name=='WBP_MCTechnology'then
   self:edge57(ns,'Tech57Inset',-117,-52,234,113,'373737',24,unit)
   self:brush(ns.GuiBackground,'T_MC_UI_panel');self:position(ns.GuiBackground,-126,-90,252,180,unit)
   self:position(ns.Title,-118,-82,76,10,unit);self:position(ns.Points,-39,-82,157,10,unit);ns.Points:SetJustification(2)
   self:position(ns.Band,-118,70,208,10,unit)
   self:position(ns.Prev,99,70,10,10,unit);self:position(ns.Next,111,70,10,10,unit)
  end
  for _,key in ipairs({'GuiWell'})do if valid(ns[key])then self:brush(ns[key],'T_MC_UI_slot');local b=ns[key].Brush;b.TintColor={SpecifiedColor={R=.2,G=.2,B=.2,A=1},ColorUseRule=0};ns[key]:SetBrush(b)end end
  return factor,unit
 end
 local controls=U.controls54
 function U:controls54(ns,env,mode,x,y,D)
  local tip=controls(self,ns,env,mode,x,y,D);local _,unit=self:metrics(env)
  if mode=='PC'or mode=='Palpedia'or mode=='Technology'then
   if mode=='PC'then for _,key in ipairs({'PC54Prev','PC54Next'})do if valid(ns[key])then ns[key]:SetVisibility(1)end end end
   local rectangles=mode=='PC'and{{-103,-93,12,17},{58,-93,12,17}}or mode=='Palpedia'and{{-122,89,12,10},{-23,89,12,10}}or{{99,70,10,10},{111,70,10,10}}
   for i,key in ipairs({'Prev','Next'})do local r=rectangles[i];self:putText(ns[key],'');self:position(ns[key],r[1],r[2],r[3],r[4],unit)
    local frame=self:makeNode(ns,'Arrow57Frame_'..key,'Image');self:brush(frame,x>=r[1]and x<r[1]+r[3]and y>=r[2]and y<r[2]+r[4]and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button');self:position(frame,r[1],r[2],r[3],r[4],unit);frame.Slot:SetZOrder(44)
    for j=0,4 do local px=(i==1 and math.abs(j-2)or(2-math.abs(j-2)))+math.floor((r[3]-3)/2);local py=math.floor((r[4]-5)/2)+j
     for layer=0,1 do local n=self:makeNode(ns,'Arrow57_'..key..j..layer,'Image');self:fill(n,layer==0 and'373737'or'FFFFFF');self:position(n,r[1]+px+(layer==0 and 1 or 0),r[2]+py+(layer==0 and 1 or 0),1,1,unit);n.Slot:SetZOrder(45+layer);n:SetVisibility(3)end
    end
    if y>=r[2]and y<r[2]+r[4]and x>=r[1]and x<r[1]+r[3]then tip={title=mode=='PC'and(i==1 and'Previous box'or'Next box')or(i==1 and'Previous page'or'Next page'),lines={},source='Palworld',exclude={x=r[1],y=r[2],w=r[3],h=r[4]}}end
   end
  end
  if mode=='Palpedia'and x>=-4 and x<120 and y>=1 and y<49 then tip={title='Description',lines={D.features.description54 or''},source='Palworld',exclude={x=-4,y=1,w=124,h=48}}end
  return tip
 end
 local details=U.pcDetails
 function U:pcDetails(ns,env,p)
  details(self,ns,env,p);local _,unit=self:metrics(env)
  self:putText(ns.PartyTitle,'Party');self:position(ns.PartyTitle,-138,-87,30,10,unit)
  self:position(ns.BoxTitle,-87,-90,140,10,unit)
  self:brush(ns.GuiWell,'T_MC_UI_slot');self:position(ns.GuiWell,67,-77,60,60,unit)
  self:fill(ns.GuiWell,'000000');self:position(ns.Portrait,69,-75,56,56,unit)
  self:position(ns.GuiHeader,58,-16,82,12,unit);self:position(ns.Name,60,-14,78,10,unit)
  self:position(ns.HPText,62,36,74,10,unit)
 end
 local work=U.dexWork46
 function U:dexWork46(ns,env,F,r,works)
  work(self,ns,env,F,r,works);local _,unit=self:metrics(env)
  self:fill(ns.GuiWell,'000000')
  for i=1,14 do local n=ns['DexLabel'..i];self:textStyle(n,unit,false);n:SetClipping(1)end
  
  self:position(ns.Dex54Scroll,-4,1,124,48,unit);ns.Dex54Scroll:SetRenderOpacity(0)
  local lines=self:wrap46(F.description54 or(r.detail<2 and'Not encountered'or''),116,100)
  local shown={};for i=1,math.min(4,#lines)do shown[i]=lines[i]end;if #lines>4 then shown[4]=self:trimLabel(shown[4],104)..'...'end
  local caption=self:makeNode(ns,'Dex57Description','TextBlock');self:putText(caption,table.concat(shown,'\n'));self:position(caption,-4,1,124,42,unit);self:textStyle(caption,unit,true);caption:SetClipping(1);caption.Slot:SetZOrder(43)
 end
end
