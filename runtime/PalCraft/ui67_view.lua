-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U,ns,unit)
 local V={ns=ns,unit=unit,used={},buttons={}};local valid=ctx.valid
 function V:node(key,kind,x,y,w,h)
  key='S67_'..key;local n=U:makeNode(ns,key,kind);self.used[key]=true
  U:position(n,x,y,w,h,unit);U:visible(n,kind=='EditableText'and 0 or 3);n:SetRenderOpacity(1);n.Slot:SetZOrder(kind=='Image'and 72 or 74);return n
 end
 function V:fill(key,x,y,w,h,color)local n=self:node(key,'Image',x,y,w,h);U:fill(n,color);return n end
 function V:sprite(key,x,y,w,h,sprite)local n=self:node(key,'Image',x,y,w,h);U:brush(n,sprite);return n end
 function V:icon(key,x,y,size,texture)
  local n=self:node(key,'Image',x,y,size,size);U:visible(n,valid(texture)and 3 or 1);if valid(texture)then U:icon(n,texture,size>32 and 64 or 32,0)end;return n
 end
 function V:text(key,x,y,w,s,dark,color,lines,align)
  local n=self:node(key,'TextBlock',x,y,w,(lines or 1)*11+2);local value=lines and table.concat(U:wrap46(s,w,lines),'\n')or U:trimLabel(s,w)
  U:putText(n,value);U:textStyle(n,unit,dark~=false,color);n:SetJustification(align or 0);n:SetClipping(1);return n
 end
 function V:button(key,x,y,w,label,action,disabled,selected,h)
  h=h or 18;self:sprite(key,x,y,w,h,(disabled or selected)and'T_MC_UI_widget_button_disabled'or'T_MC_UI_widget_button')
  self:text(key..'Text',x+3,y+(h-10)/2,w-6,label,false,nil,1,1)
  local r={x=x,y=y,w=w,h=h,action=action,disabled=disabled==true,label=label,key=key};self.buttons[#self.buttons+1]=r;return r
 end
 function V:field(key,x,y,w,value,hint)
  self:sprite(key..'Frame',x,y,w,18,'T_MC_UI_widget_text_field')
  local n=self:node(key,'EditableText',x+4,y+3,w-8,14)
  if not ns[key..'Init67']then n:SetText(ctx.UE.GetKismetTextLibrary():Conv_StringToText(value or''));ns[key..'Init67']=true end
  local f=n.WidgetStyle.Font;f.Size=math.floor(6*unit+.5);f.FontObject=U:pixelFont53();f.TypefaceFontName=ctx.UE.FindOrAddFName('Regular');n:SetFont(f)
  n.WidgetStyle.ColorAndOpacity={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0};n:SetHintText(ctx.UE.GetKismetTextLibrary():Conv_StringToText(U.language57:t(hint)))
  self.buttons[#self.buttons+1]={x=x,y=y,w=w,h=18,action='search',field=n};self.field=n;return n
 end
 function V:bar(key,x,y,w,rate,color)
  self:fill(key..'Edge',x,y,w,5,'373737');self:fill(key..'Back',x+1,y+1,w-2,3,'191919');self:fill(key..'Fill',x+1,y+1,math.max(.1,(w-2)*math.max(0,math.min(1,rate))),3,color or'55FF55')
 end
 function V:well(key,x,y,w,h)
  self:fill(key..'Border',x,y,w,h,'373737');self:fill(key..'Light',x+1,y+1,w-1,h-1,'FFFFFF');self:fill(key..'Face',x+1,y+1,w-2,h-2,'191919')
 end
 function V:finish()
  for key,n in pairs(ns)do if key:sub(1,4)=='S67_'and not self.used[key]and valid(n)then U:visible(n,1)end end
  ns.buttons67=self.buttons;ns.field67=self.field
 end
 return V
end
