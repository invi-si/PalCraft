-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx,U)
 local widths={};do local f=io.open(ctx.base..'/assets/minecraft/_palcraft/font-metrics.json','rb');if f then local raw=f:read(2097152);f:close();local ok,data=pcall(dofile(ctx.base..'/json.lua').decode,raw);if ok and type(data)=='table'then for k,v in pairs(data)do widths[tonumber(k)]=v end end end end
 local test=io.open(ctx.base..'/task53-native-font-baseline.txt','rb');local baseline=test~=nil;if test then test:close()end
 function U:pixelFont53()
  local font=baseline and StaticFindObject('/Game/Pal/Font/Ft_PalDefaultFont.Ft_PalDefaultFont')or self:asset('F_MC_UI53');assert(ctx.valid(font)and font:GetClass():GetFullName()=='Class /Script/Engine.Font','Task53 populated UFont missing')
  ctx.UE.pixelFont53=font;ctx.config.pixel_font_verified=true
  if not self.font53Logged then self.font53Logged=true;ctx.log('MC53_FONT_READY path='..font:GetFullName()..' typeface=Regular native_slate=true baseline='..tostring(baseline)..' local_metrics='..tostring(next(widths)~=nil))end
  return font
 end
 function U:glyphAdvance53(cp)return widths[cp]or widths[63]or 6 end
 function U:textWidth53(s)
  if ctx.UE.language57 then s=ctx.UE.language57:t(s)end
  local width,line=0,0;for _,cp in utf8.codes(tostring(s or''))do if cp==10 then width=math.max(width,line);line=0 else line=line+self:glyphAdvance53(cp)end end;return math.max(width,line)
 end
 function U:inputFont53(n,unit)
  local f=n.WidgetStyle.Font;f.FontObject=self:pixelFont53();f.TypefaceFontName=ctx.UE.FindOrAddFName('Regular');f.Size=math.max(1,math.floor(6*unit+.5));n:SetFont(f)
 end
end
