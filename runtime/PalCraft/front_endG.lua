-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local F={};local valid=ctx.valid
 local words={['WORLD SELECT']='월드 선택',['World Select']='월드 선택',['WORLD SETTINGS']='월드 설정',
  ['GAME SETTINGS']='게임 설정',['START GAME']='게임 시작',['START']='시작',['OPTIONS']='설정',
  ['EXIT GAME']='게임 종료',['BACK']='뒤로',['Loading terrain...']='지형 불러오는 중...',
  ['Saving world...']='월드 저장 중...'}
 function F:localize(root)
  local panel=StaticFindObject('/Script/UMG.PanelWidget');local user=StaticFindObject('/Script/UMG.UserWidget')
  local text=StaticFindObject('/Script/UMG.TextBlock');local lib=StaticFindObject('/Script/Engine.Default__KismetTextLibrary')
  local seen={};local count=0
  local function visit(w,depth)
   if not valid(w)or depth>24 or seen[w:GetAddress()]then return end;seen[w:GetAddress()]=true
   if w:IsA(text)then local old=w:GetText():ToString();local value=words[old];if value then w:SetText(lib:Conv_StringToText(value));count=count+1 end end
   if w:IsA(panel)then for i=0,w:GetChildrenCount()-1 do visit(w:GetChildAt(i),depth+1)end
   elseif w:IsA(user)then local tree=w.WidgetTree;if valid(tree)then visit(tree.RootWidget,depth+1)end end
  end
  visit(root,0);return count
 end
 function F:tick(leaving)
  local now=os.clock();if now<(self.at or 0)then return end;self.at=now+.25
  local value=StaticFindObject('/Script/Engine.Default__KismetInternationalizationLibrary'):GetCurrentLanguage();local lang=type(value)=='string'and value or value:ToString()
  local title=false
  for _,name in ipairs({'WBP_TItle_C','WBP_TitleLocalWorldSelect_C'})do
   for _,w in ipairs(FindAllOf(name)or{})do if valid(w)and w:IsA(StaticFindObject('/Script/UMG.UserWidget'))and w:IsVisible()and w:GetRenderOpacity()>0 then
    if lang:lower():match('^ko')then
     local ok,n=pcall(self.localize,self,w)
     if ok and n>0 then ctx.log('MCG_TITLE_LOCALIZED class='..name..' strings='..n)
     elseif not ok and not self.warned then self.warned=true;ctx.log('MCG_TITLE_LOCALIZE_REJECT '..tostring(n))end
    end
    if name=='WBP_TItle_C'and w:IsA(StaticFindObject('/Script/CommonUI.CommonActivatableWidget'))and w:IsActivated()then local world=w:GetWorld();title=valid(world)and not world:GetFullName():find('MainWorld',1,true)or title end
   end end
  end
  if leaving and title and ctx.cover.saveDispatchedG then
   if valid(ctx.cover.widget)then ctx.cover.widget:SetRenderOpacity(0)end
   ctx.cover:forget();ctx.log('MCG_TITLE_COVER_RELEASE native_title_ready=true');return true
  end
 end
 return F
end
