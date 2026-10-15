-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local L={}
 function L:preload(retain,loadClass,base)
  local flag=io.open(base..'/q2-cover-disabled.txt','r');if flag then flag:close();self.diagDisabledQ2=true end
  if self.diagDisabledQ2 then self:show({});retain(self.widget);self.armed=false;ctx.log('MCQ2_DIAGNOSTIC cover_disabled=true');return end

  local c=loadClass('/Game/Pal/Blueprint/UI/WBP_LoadingScreen.WBP_LoadingScreen_C');retain(c)
  local tree=c.WidgetTree
  local root=tree.RootWidget;local image
  for i=0,root:GetChildrenCount()-1 do local n=root:GetChildAt(i)
   if n:GetFName():ToString()=='Image_50'then image=n else
    local function mask(w,depth)assert(depth<=20);w:SetRenderOpacity(0);if w:IsA(ctx.UE.Object('/Script/UMG.PanelWidget'))then for j=0,w:GetChildrenCount()-1 do mask(w:GetChildAt(j),depth+1)end end end
    mask(n,0)
   end
  end
  assert(ctx.valid(image),'Native loading backdrop absent')
  local brush=ctx.UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):MakeBrushFromTexture(ctx.dirt(),32,32)
  brush.DrawAs=3;brush.Tiling=3;image:SetBrush(brush);image:SetColorAndOpacity({R=.25,G=.25,B=.25,A=1})

  local backdrop=ctx.UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(ctx.UE.Object('/Script/UMG.Image'),tree)
  assert(ctx.valid(backdrop));local slot=root:AddChildToCanvas(backdrop)
  slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
  slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0});slot:SetZOrder(999)
  backdrop:SetBrush(brush);backdrop:SetColorAndOpacity({R=.25,G=.25,B=.25,A=1});backdrop:SetVisibility(3);backdrop:SetRenderOpacity(1)
  self.nativeBackdropM=backdrop;retain(backdrop)

  local transition=loadClass('/Game/Pal/Blueprint/UI/WBP_LoadingScreen_Transition.WBP_LoadingScreen_Transition_C');retain(transition)
  local transitionTree=transition.WidgetTree;local transitionRoot=transitionTree.RootWidget
  local transitionBackdrop=ctx.UE.Object('/Script/Engine.Default__GameplayStatics'):SpawnObject(ctx.UE.Object('/Script/UMG.Image'),transitionTree)
  local transitionSlot=transitionRoot:AddChildToCanvas(transitionBackdrop)
  transitionSlot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}});transitionSlot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0});transitionSlot:SetZOrder(999)
  transitionBackdrop:SetBrush(brush);transitionBackdrop:SetColorAndOpacity({R=.25,G=.25,B=.25,A=1});transitionBackdrop:SetVisibility(3)
  retain(transitionBackdrop);self.transitionBackdropM=transitionBackdrop
  ctx.log('MCM_COMMON_LOADING_BACKDROP template=Transition independent_black_image_covered=true')
  self:show({player=ctx.UE.GetGameInstance(),controller=nil});retain(self.widget);self.widget:SetRenderOpacity(0);self.widget:SetVisibility(3);self.armed=false;self.at=nil
  ctx.log('MC52_LOADING_PREBUILT native_template_dirt=true retained_gameinstance=true')
 end

 function L:setMessage(value)self.message=value end

 function L:arm(preserveReady)self.message='Loading terrain...';self.saveDispatchedG=false;self.armed=true;self.fadeAt=nil;self.at=nil;self.safety78=nil;self.timeoutQ2=nil;if not preserveReady and ctx.resetReady then ctx.resetReady()end end
 function L:suspendForSetupQ2(reason)
  if not self.suspendedQ2 then ctx.log('MCQ2_COVER_SUSPEND native_ui='..tostring(reason))end
  self.suspendedQ2=true;self.at=nil;self.fadeAt=nil
  if ctx.valid(self.widget)then self.widget:SetRenderOpacity(0)end
 end
 function L:resumeAfterSetupQ2()
  if not self.suspendedQ2 then return end
  self.suspendedQ2=nil;self.at=nil;self.fadeAt=nil;self.armed=true
  ctx.log('MCQ2_COVER_RESUME possessed_pawn_ready=true')
 end
 function L:display()
  if self.diagDisabledQ2 then if ctx.valid(self.widget)then self.widget:SetRenderOpacity(0)end;return end
  if self.suspendedQ2 or self.timeoutQ2 then if ctx.valid(self.widget)then self.widget:SetRenderOpacity(0)end;return end
  if not ctx.valid(self.widget)then return end
  if self.at and os.clock()-self.at>=45 then
   self.widget:SetRenderOpacity(0);self.timeoutQ2=true;self.armed=false;self.at=nil;self.fadeAt=nil
   ctx.log('MCQ2_COVER_TIMEOUT seconds=45 safe_release=true');return
  end
  if not self.widget:IsInViewport()then self.widget:AddToViewport(10000)end
  if not self.at then self.at=os.clock();ctx.log('MC51_LOADING_COVER_BEGIN')end
  if self.message and self.messages and self.messages[self.message]and self.paintedMessage~=self.message then self.nodes.Title:SetText(self.messages[self.message]);self.paintedMessage=self.message end
  self.widget:SetVisibility(3);self.widget:SetRenderOpacity(1)
 end
 function L:show(env)
  if not ctx.valid(self.widget)then
   local gi=ctx.UE.GetGameInstance()
   self.widget=ctx.UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(gi,ctx.loadClass('WBP_MCDeath'),nil)
   assert(ctx.valid(self.widget),'GameInstance loading widget absent');local r={widget=self.widget,uiUnit=3};self.nodes=ctx.widgets(self.widget)
   local keep={}
   for _,leaf in ipairs({self.nodes.Dim,self.nodes.Title})do local n=leaf;local depth=0;while ctx.valid(n)do keep[n:GetAddress()]=true;n=n:GetParent();depth=depth+1;assert(depth<=20,'Loading cover ancestor depth')end end
   for _,n in pairs(self.nodes)do if ctx.valid(n)and not keep[n:GetAddress()]then n:SetRenderOpacity(0)end end
   local dirt=ctx.dirt();local brush=ctx.UE.Object('/Script/UMG.Default__WidgetBlueprintLibrary'):MakeBrushFromTexture(dirt,32,32)
   brush.DrawAs=3;brush.Tiling=3;brush.ImageSize={X=ctx.valid(dirt)and dirt:Blueprint_GetSizeX()*2 or 32,Y=ctx.valid(dirt)and dirt:Blueprint_GetSizeY()*2 or 32};self.nodes.Dim:SetBrush(brush);self.nodes.Dim:SetBrushColor({R=.25,G=.25,B=.25,A=1});self.nodes.Dim:SetRenderOpacity(1)
   self.messages={['Loading terrain...']=ctx.UE.GetKismetTextLibrary():Conv_StringToText('Loading terrain...'),['Saving world...']=ctx.UE.GetKismetTextLibrary():Conv_StringToText('Saving world...')}
   self.nodes.Title:SetText(self.messages['Loading terrain...']);self.nodes.Title:SetJustification(1);self.nodes.Title:SetRenderOpacity(1)
   local font=self.nodes.Title.Font;font.Size=math.max(8,math.floor(6*(r.uiUnit or 3)));if ctx.UE.pixelFont53 then font.FontObject=ctx.UE.pixelFont53 end;font.TypefaceFontName=ctx.UE.FindOrAddFName('Regular');self.nodes.Title:SetFont(font)
   self.nodes.Title.Slot:SetAnchors({Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}});self.nodes.Title.Slot:SetPosition({X=-300,Y=-40});self.nodes.Title.Slot:SetSize({X=600,Y=80});self.nodes.Title.Slot:SetZOrder(999)
  end
  self:display()
 end
 function L:hide()
  self.fadeAt=self.fadeAt or os.clock()
  local alpha=math.max(0,1-(os.clock()-self.fadeAt)/.15)
  if ctx.valid(self.widget)then self.widget:SetRenderOpacity(alpha)end
  if alpha>0 then return end
  if ctx.valid(self.widget)then self.widget:SetRenderOpacity(0);self.widget:SetVisibility(3)end
  ctx.log(string.format('MC51_LOADING_COVER_END seconds=%.3f',os.clock()-(self.at or os.clock())));self.at=nil;self.fadeAt=nil;self.armed=false
 end
 function L:forget()self.at=nil;self.fadeAt=nil;self.armed=false;self.suspendedQ2=nil;self.timeoutQ2=nil end
 function L:releaseForDeath()
  if ctx.valid(self.widget)then self.widget:SetRenderOpacity(0)end
  self.at=nil;self.fadeAt=nil;self.armed=false
  ctx.log('MC57_LOADING_DEATH_RELEASE controller_only=true')
 end
 return L
end
