-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local U,G=ctx.uiKit,ctx.mode;local valid=ctx.valid
 local V={}
 local function inside(x,y,b)return b and x>=b[1]and x<b[1]+b[3]and y>=b[2]and y<b[2]+b[4]end
 local function node(ns,key,kind,x,y,w,h,unit,z)
  local n=U:makeNode(ns,key,kind)
  n.Slot:SetAnchors({Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}})
  U:position(n,x,y,w,h,unit);n.Slot:SetZOrder(z);n:SetVisibility(3)
  ns.cmKeys=ns.cmKeys or{};ns.cmKeys[key]=true;return n
 end
 local function text(ns,key,s,x,y,w,h,unit,z,center,dark)
  local n=node(ns,key,'TextBlock',x,y,w,h,unit,z)
  U:textStyle(n,unit,dark==true);U:putText(n,s);n:SetJustification(center and 1 or 0);n:SetClipping(1);return n
 end
 local function button(ns,key,s,b,unit,z)
  local n=node(ns,key,'Image',b[1],b[2],b[3],b[4],unit,z)
  U:brush(n,'T_MC_UI_widget_button')
  text(ns,key..'Text',s,b[1]+2,b[2]+4,b[3]-4,12,unit,z+1,true)
 end
 function V:hide(ns)
  for key in pairs(ns.cmKeys or{})do if valid(ns[key])then ns[key]:SetVisibility(1)end end
  ns.cmModeBox=nil;ns.cmCatalogBox=nil
 end
 function V:cancel(host)
  if self.pending and(not host or self.pending.host==host)then self.pending=nil;ctx.log('MCCM_CONFIRM_CANCEL');return true end
  return false
 end
 function V:request(host)
  if not G:available()and G:mode()~='creative'then return false end
  self.pending={host=host,epoch=ctx.epoch(),world=ctx.world(),target=G:mode()=='creative'and'survival'or'creative'}
  ctx.log('MCCM_CONFIRM_OPEN host='..host..' target='..self.pending.target);return true
 end
 function V:paint(ns,env,host,unit,layout,B)
  self:hide(ns)
  if not G:available()and G:mode()~='creative'then return end
  if host=='game'then
   local last=U.gameButtons[2];ns.cmModeBox={-102,last[2]+24,204,20}
  else
   
   local y=B and B.creative and-114 or layout.height/2+6
   ns.cmModeBox={-layout.width/2,y,106,18}
   if G:enabled()then ns.cmCatalogBox={-layout.width/2+110,y,66,18}end
  end
  button(ns,'CMMode',(host=='game'and'Game Mode: 'or'Mode: ')..(G:mode()=='creative'and'Creative'or'Survival'),ns.cmModeBox,unit,180)
  if ns.cmCatalogBox then button(ns,'CMCatalog',B and B.creative and'Inventory'or'Catalog',ns.cmCatalogBox,unit,180)end
  local p=self.pending
  if not p or p.host~=host then return end
  if p.epoch~=ctx.epoch()or p.world~=ctx.world()then self.pending=nil;return end
  local offset=host=='inventory'and-((B and B.recipeBook and 74 or 0)+(B and B.drawerShift67 or 0))or 0
  local messages=p.target=='creative'and{
   'Creative catalog and unlimited block placement.',
   'Instant block break, no drops. Containers lose contents.',
   'Double-tap Space to fly. Space / Shift: up / down.',
   'Damage, hunger and stamina drain are disabled.',
   'Pals, capture and progression stay unchanged.',
   'You can return to Survival at any time.',
  }or{
   'Flight and Creative protection will turn off.',
   'Blocks consume items and drop normally.',
   'Native hunger, stamina and damage resume.',
   'Items obtained in Creative are kept.',
   'Switching in midair can cause fall damage.',
   'Pals, capture and progression stay unchanged.',
  }
  messages[#messages+1]='This setting is saved for this world.'
  if p.error then messages[#messages+1]=p.error end
  local lines={}
  for _,s in ipairs(messages)do for _,line in ipairs(U:wrap46(s,280,4))do lines[#lines+1]=line end end
  local height=32+#lines*10+8+20+12;local top=-height/2;local body=top+32
  local panel=node(ns,'CMConfirmPanel','Image',offset-156,top,312,height,unit,300)
  U:brush(panel,'T_MC_UI_panel',{4/176,4/166})
  text(ns,'CMConfirmTitle',p.target=='creative'and'Switch to Creative?'or'Switch to Survival?',offset-144,top+12,288,14,unit,302,true,true)
  for i,line in ipairs(lines)do text(ns,'CMConfirmLine'..i,line,offset-140,body+(i-1)*10,280,10,unit,302,false,true)end
  local buttons=body+#lines*10+8
  self.yes={offset-140,buttons,136,20};self.no={offset+4,buttons,136,20}
  button(ns,'CMConfirmYes','Confirm',self.yes,unit,302);button(ns,'CMConfirmNo','Cancel',self.no,unit,302)
 end
 function V:click(ns,env,host,x,y,right,B)
  local p=self.pending
  if p then
   if p.host~=host or p.epoch~=ctx.epoch()or p.world~=ctx.world()then self.pending=nil;return true end
   if not right then
    if inside(x,y,self.no)then self.pending=nil
    elseif inside(x,y,self.yes)then
     local ok,err=G:switch(p.target,env)
     if ok then self.pending=nil else p.error=err end
    end
   end
   return true
  end
  if right then return false end
  if inside(x,y,ns.cmModeBox)then self:request(host);return true end
  if G:enabled()and B and inside(x,y,ns.cmCatalogBox)then B:toggleCatalog(env);return true end
  return false
 end
 function V:hover(ns,x,y)
  for _,row in ipairs({{'CMMode',ns.cmModeBox},{'CMCatalog',ns.cmCatalogBox},{'CMConfirmYes',self.pending and self.yes},{'CMConfirmNo',self.pending and self.no}})do
   if row[2]and valid(ns[row[1]])then U:brush(ns[row[1]],inside(x,y,row[2])and'T_MC_UI_widget_button_highlighted'or'T_MC_UI_widget_button')end
  end
 end
 ctx.timers.onEpoch('creative-confirmation',function()V.pending=nil end)
 return V
end
