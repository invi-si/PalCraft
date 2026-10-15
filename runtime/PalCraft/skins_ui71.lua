-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local V={page=0,selected=1,model='auto'};local U,UE,valid=ctx.uiKit,ctx.UE,ctx.valid;local K=ctx.steve.library71
 local function tr(s)return UE.language57:t(s)end
 local function name(s,n)local out={};for _,c in utf8.codes(s)do if #out>=n then out[#out+1]='...';break end;out[#out+1]=utf8.char(c)end;return table.concat(out)end
 function V:node(key,kind,x,y,w,h)
  local n=U:makeNode(self.nodes,'Skin71'..key,kind);U:position(n,x,y,w,h,self.unit);n.Slot:SetZOrder(kind=='TextBlock'and 52 or 50);n:SetVisibility(3);return n
 end
 function V:label(key,s,x,y,w,h,dark)
  local n=self:node(key,'TextBlock',x,y,w,h or 12);U:textStyle(n,self.unit,dark==true);n:SetText(UE.GetKismetTextLibrary():Conv_StringToText(s));return n
 end
 function V:button(key,s,x,y,w,action)
  local n=self:node('Button'..key,'Image',x,y,w,20);U:brush(n,'T_MC_UI_widget_button');local t=self:label('Caption'..key,tr(s),x,y+4,w,14);t:SetJustification(1)
  self.buttons[#self.buttons+1]={node=n,x=x,y=y,w=w,h=20,action=action}
 end
 function V:hide()
  if self.nodes then for key,n in pairs(self.nodes)do if type(key)=='string'and key:sub(1,6)=='Skin71'and valid(n)then n:SetVisibility(1)end end end
  K.previewJob=nil;self.open=false;self.previewImage=nil;self.env=nil
 end
 function V:show(env,nodes,refresh)
  self:hide();self.env=env;self.nodes=nodes;self.open=true;self.unit=select(2,U:metrics(env));ctx.menu.uiFactor=self.unit/3
  for _,key in ipairs({'Title','Help','GuiBackground','GuiOffhand','GuiHover'})do if valid(nodes[key])then nodes[key]:SetVisibility(1)end end
  for i=1,20 do for _,p in ipairs({'Button','Label','Handle'})do nodes[p..i]:SetVisibility(1)end end
  if refresh or not self.scanned then K:scan();self.scanned=true end
  self.page=math.max(0,math.min(self.page,math.ceil(#K.rows/6)-1));self.buttons={}
  self:label('Title',tr('Skins'),-156,-110,312,16):SetJustification(1)
  local panel=self:node('Panel','Image',-158,-88,316,174);U:brush(panel,'T_MC_UI_panel')
  local list=self:node('List','Image',-150,-80,174,142);U:fill(list,'202020')
  for i=1,6 do local ix=self.page*6+i;local row=K.rows[ix];if row then
   local y=-77+(i-1)*23;local frame=self:node('Row'..i,'Image',-147,y,168,22);U:brush(frame,ix==self.selected and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button')
   self.buttons[#self.buttons+1]={node=frame,x=-147,y=y,w=168,h=22,action=ix}
   self:label('Name'..i,name(row.file,22),-120,y+6,137,12)
   local ok,im=pcall(K.decode,K,row.file)
   if ok then
    local tex=K:import(env,K:thumbnail(im),8,8);local n=self:node('Head'..i,'Image',-143,y+3,16,16);n:SetBrushFromTexture(tex,false)
    row.auto=im.model;row.legacy=im.legacy;row.error=nil
   else row.error=tostring(im);self:label('Bad'..i,'!',-141,y+5,15,12)end
  end end
  if #K.rows==0 then self:label('Empty',tr('No skins found'),-139,-56,154,20)end
  self:button('Prev','<',-147,65,20,'prev');self:label('Page',(self.page+1)..' / '..math.max(1,math.ceil(#K.rows/6)),-122,70,90,12):SetJustification(1);self:button('Next','>',1,65,20,'next')
  self:button('Model',self.model=='auto'and'Auto'or self.model=='wide'and'Wide'or'Slim',34,63,114,'model')
  self:button('Load','Load',-156,91,58,'load');self:button('Default','Default',-94,91,58,'default');self:button('Refresh','Refresh',-32,91,58,'refresh');self:button('Folder','Open folder',30,91,64,'folder');self:button('Done','Done',98,91,58,'done')
  self:label('Folder','MinecraftBlocks/skins/',-148,-97,296,10):SetJustification(1)
  self:preview()
  ctx.log('MC71_SKINS_OPEN files='..#K.rows..' page='..self.page)
 end
 function V:message(s)
  self.message71=s;local n=self:label('Message',tr(s),30,37,122,25);n:SetJustification(1);n:SetAutoWrapText(true)
 end
 function V:preview()
  local row=K.rows[self.selected];local im
  if row then local ok,value=pcall(K.decode,K,row.file);if ok then im=value end end
  self.image=im
  local n=self:node('Preview','Image',41,-73,99,112);self.previewImage=n
  
  n:SetBrushFromTexture(U:asset('T_MC_UI_white'),false);n:SetColorAndOpacity({R=.015,G=.015,B=.015,A=1})
  if not im then self:message(row and'Invalid skin'or'Add PNG files here');return end
  local model=self.model=='auto'and im.model or self.model
  self:message(im.legacy and'Legacy skin'or(model=='slim'and'Slim'or'Wide'))
  K:previewBegin(im,model);self.previewReady=false
 end
 function V:tick()
  if not self.open or not K.previewJob then return end
  local path=K:previewStep();if not path then return end
  local tex=K:import(self.env,path,1280,112)
  local parent=UE.Object('/Game/MinecraftTask71/M_SkinPreview71.M_SkinPreview71')
  if not valid(parent)then parent=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName('/Game/MinecraftTask71/M_SkinPreview71'),AssetName=UE.FindOrAddFName('M_SkinPreview71')})end
  assert(valid(parent),'Skin preview material unavailable');self.previewImage:SetBrushFromMaterial(parent);local mid=self.previewImage:GetDynamicMaterial();mid:SetTextureParameterValue(UE.FindOrAddFName('Preview'),tex)
  self.previewImage:SetColorAndOpacity({R=1,G=1,B=1,A=1});self.previewReady=true;ctx.log('MC71_PREVIEW_READY file='..self.image.file..' model='..(self.model=='auto'and self.image.model or self.model)..' shader_frames=16')
 end
 function V:hover(x,y)
  self:tick();for _,b in ipairs(self.buttons or{})do local yes=x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h
   if b.hover~=yes then b.hover=yes;U:brush(b.node,(yes or b.action==self.selected)and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button')end
  end
 end
 function V:click(x,y)
  for _,b in ipairs(self.buttons or{})do if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then
   local a=b.action;local env,ns=self.env,self.nodes
   if type(a)=='number'then self.selected=a;self.model='auto';self:show(env,ns,false)
   elseif a=='prev'or a=='next'then self.page=self.page+(a=='prev'and-1 or 1);self:show(env,ns,false)
   elseif a=='model'then self.model=self.model=='auto'and'wide'or self.model=='wide'and'slim'or'auto';self:show(env,ns,false)
   elseif a=='refresh'then self:show(env,ns,true)
   elseif a=='folder'then K:openFolder()
   elseif a=='done'then ctx.menu:show(env,'Options',nil)
   elseif a=='load'or a=='default'then
    local row=K.rows[self.selected];if a=='load'and not row then return end
    local ok=ctx.steve:selectSkin71(env,a=='load'and row.file or nil,self.model~='auto'and self.model or nil)
    self:message(ok and(a=='default'and'Default skin loaded'or'Skin loaded')or'Invalid skin: default loaded');U:notify('Skins',self.message71)
   end;return
  end end
 end
 return V
end
