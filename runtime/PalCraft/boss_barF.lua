-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(valid)
 local M={}
 function M.rows(engaged)
  local rows={}
  for address,s in pairs(engaged)do
   if not s.bossD or not valid(s.bossD.target)or not valid(s.parameter)or s.parameter:IsDead()or s.parameter:GetIsCapturedProcessing()or s.recall108 then
    engaged[address]=nil
   elseif not s.owned108 then rows[#rows+1]=s end
  end
  table.sort(rows,function(a,b)return a.kind==b.kind and a.address<b.address or a.kind~=b.kind and a.kind=='wither'end)
  return rows
 end
 function M.render(engaged,e,ns,U,unit,enabled)
  local rows=M.rows(engaged)
  for i=1,2 do
   local s=rows[i];local suffix=i==1 and'D'or'F2'
   local back,fill,name='BossBack'..suffix,'BossFill'..suffix,'BossName'..suffix
   local show=s~=nil and enabled==true
   if s or ns[name]then
    if ns['bossShow'..suffix]~=show then
     ns['bossShow'..suffix]=show
     for _,key in ipairs({back,fill,name})do local n=U:makeNode(ns,key,key==name and'TextBlock'or'Image');n:SetRenderOpacity(show and 1 or 0);n.Slot:SetZOrder(93)end
    end
    if show then
     local hp=s.parameter:GetHP().Value;local max=s.parameter:GetMaxHP().Value;local ratio=math.max(0,math.min(1,hp/math.max(1,max)))
     local _,_,dpi,size=U:metrics(e);local y=20+(i-1)*24-size.Y/(unit*dpi)*.5
     local key=s.address..':'..hp..':'..max..':'..unit..':'..dpi..':'..size.X..':'..size.Y..':'..tostring(U.language57 and U.language57.lang)
     if ns['bossKey'..suffix]~=key then
      ns['bossKey'..suffix]=key
      U:brush(ns[back],'T_MC_UI20_boss_background');U:position(ns[back],-91,y,182,5,unit)
      U:brush(ns[fill],'T_MC_UI20_boss_progress');U:position(ns[fill],-91,y,182*ratio,5,unit)
      ns[fill]:SetColorAndOpacity(s.kind=='wither'and{R=.64,G=.25,B=1,A=1}or{R=1,G=.4,B=.8,A=1})
      U:position(ns[name],-140,y-12,280,11,unit);U:textStyle(ns[name],unit,false);ns[name]:SetJustification(1)
      local ko=U.language57 and U.language57.lang=='ko'
      local title=s.kind=='wither'and(ko and'위더'or'Wither')or(ko and'엔더 드래곤'or'Ender Dragon')
      U:putText(ns[name],title..'  '..math.ceil(hp/1000)..' / '..math.ceil(max/1000))
     end
    end
   end
  end
 end
 return M
end
