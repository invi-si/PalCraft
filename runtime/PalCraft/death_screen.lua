-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local D={open=false};local Timers=dofile(ctx.base..'/timers.lua');local widget,nodes
 local function view(env)return{player=env.controller,controller=env.controller,world=env.world,identity=env.identity}end
 local function text(n,s)n:SetText(ctx.UE.GetKismetTextLibrary():Conv_StringToText(s))end
 function D:close(env)
  ctx.uiKit:releaseInput(widget)
  if ctx.valid(widget)then widget:RemoveFromParent()end
  widget,nodes=nil,nil;self.open=false
  if env then env.controller:ResetIgnoreMoveInput();env.controller:ResetIgnoreLookInput();env.controller.bShowMouseCursor=false;ctx.UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(env.controller,false)end
 end
 function D:show(env,list)
  assert(env.status=='dead');self:close(env)
  local cover=ctx.UE.loadingCover51 or ctx.cover;if cover then cover:releaseForDeath()end
  if ctx.closeMenus then ctx.closeMenus()end
  for _,class in ipairs({'WBP_GameOver_Defeat_C','WBP_GameOver_ForDIsplay_C','WBP_Notice_DeathAnnounce_C'})do
   for _,w in ipairs(FindAllOf(class)or{})do if ctx.valid(w)and w:GetFullName():find('/Engine/Transient',1,true)then w:SetRenderOpacity(0)end end
  end
  local e=view(env);local result=assert(ctx.createUI(e,list and'WBP_MCGameMenu'or'WBP_MCDeath','death'))
  widget=result.widget;nodes=ctx.widgets(widget);self.open=true;self.list=list or false;self.factor=result.uiFactor
  self.resumeNeeded=true
  local _,unit,dpi,size=ctx.uiKit:metrics(e);self.scale=unit*dpi
  if list then
   local bed=ctx.beds:deadDestination(env);self.rows={}
   if bed then self.rows[#self.rows+1]={label='Red Bed',bed=true}end
   self.rows[#self.rows+1]={label='Native respawn',bed=false};self.rows[#self.rows+1]={label='Back',back=true}
   text(nodes.Title,'Choose Respawn Point')
   for i=1,9 do local row=self.rows[i];nodes['Button'..i]:SetVisibility(row and 3 or 1);nodes['Label'..i]:SetVisibility(row and 3 or 1)
    if row then local y=-54+(i-1)*24;ctx.uiKit:position(nodes['Button'..i],-100,y,200,20,unit);ctx.uiKit:position(nodes['Label'..i],-100,y+4,200,14,unit);nodes['Label'..i]:SetJustification(1);text(nodes['Label'..i],row.label)end
   end
   ctx.log('MC34_RESPAWN_LIST_OPEN bed='..tostring(bed~=nil)..' rows='..#self.rows)
  else
   
   nodes.Title:SetJustification(1);text(nodes.Title,'You Died!');text(nodes.Level,'');text(nodes.Label1,'Respawn');text(nodes.Label2,'Choose Respawn Point')
   self.deathY=size.Y/self.scale/4+72-size.Y/self.scale/2
   ctx.log('MC34_DEATH_SCREEN_OPEN controller_only=true')
  end
  
  if ctx.valid(nodes.Dim)then ctx.uiKit:fill(nodes.Dim,'550000',1)end
  widget:SetVisibility(0);env.controller.bShowMouseCursor=true
  ctx.UE.Object('/Script/Engine.Default__GameplayStatics'):SetGamePaused(env.controller,false)
  env.controller:SetIgnoreMoveInput(true);env.controller:SetIgnoreLookInput(true)
  ctx.uiKit:ownInput(env,widget)
 end
 function D:observe(env)
  if not env then return end
  if env.status=='dead'then
   if not self.open and not ctx.beds.pendingBed then self:show(env,false)end
  elseif env.status=='alive'and self.open then self:close(env)end
 end
 function D:restoreAlive(env)
  if not self.resumeNeeded then return end;assert(env.status=='alive')
  self:close(env);self.resumeNeeded=false
  if env.player.Mesh:IsSimulatingPhysics(ctx.UE.FindOrAddFName('pelvis'))then
   local cleared=env.player:CancelDeathActionOnRevive();ctx.log('MC36_ALIVE_RAGDOLL_CANCEL native='..tostring(cleared))
  end
  ctx.UE.Object('/Script/Engine.Default__GameplayStatics'):SetGamePaused(env.controller,false)
  local target=env.controller:GetViewTarget();if not ctx.valid(target)or target:GetAddress()~=env.player:GetAddress()then env.controller:SetViewTargetWithBlend(env.player,0,0,0,false)end
  ctx.log('MC36_ALIVE_INPUT_RESTORED')
 end
 function D:click()
  if not self.open then return end
  local env=ctx.loadEnvironment();if not env or env.status~='dead'then return end
  local lib=ctx.UE.Object('/Script/UMG.Default__WidgetLayoutLibrary');local p=lib:GetMousePositionOnViewport(env.controller);local size=lib:GetViewportSize(env.controller);local dpi=lib:GetViewportScale(env.controller)
  local x,y=(p.X*dpi-size.X/2)/self.scale,(p.Y*dpi-size.Y/2)/self.scale
  if x<-100 or x>=100 then return end
  if self.list then
   for i,row in ipairs(self.rows)do local yy=-54+(i-1)*24
    if y>=yy and y<yy+20 then if row.back then self:show(env,false)else self:close(env);local cover=ctx.UE.loadingCover51 or ctx.cover;if cover then cover:arm();cover:display()end;ctx.beds:requestDead(env,row.bed)end;return end
   end
  elseif y>=self.deathY and y<self.deathY+20 then self:close(env);local cover=ctx.UE.loadingCover51 or ctx.cover;if cover then cover:arm();cover:display()end;ctx.beds:requestDead(env,true)
  elseif y>=self.deathY+24 and y<self.deathY+44 then self:show(env,true)end
 end
 Timers.onEpoch('death-screen',function()widget,nodes=nil,nil;D.open=false;D.rows=nil end)
 return D
end
