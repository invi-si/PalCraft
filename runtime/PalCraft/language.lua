-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local data=dofile(ctx.base..'/strings57.lua');local L={lang='en',culture='en',generation=0,unknown={}}
 for key,row in pairs(dofile(ctx.base..'/npc_text.lua'))do data.ui[key]=row;if row.ko then data.fragments[key]=row.ko end end
 for key,ko in pairs(dofile(ctx.base..'/strings67.lua'))do data.ui[key]={en=key,ko=ko};data.fragments[key]=ko end
 for key,ko in pairs({['Loading terrain...']='지형 불러오는 중...',['Saving world...']='월드 저장 중...'})do data.ui[key]={en=key,ko=ko};data.fragments[key]=ko end
 data.ui['Minecraft mod: please launch in DX11 (remove -dx12)']={en='Minecraft mod: please launch in DX11 (remove -dx12)',ko='마인크래프트 모드: DX11로 실행하세요 (-dx12 제거)'}
 for id,row in pairs(dofile(ctx.base..'/strings70.lua'))do data.items[id]=row;data.ui[row.en]=row end
 for key,ko in pairs(dofile(ctx.base..'/strings71.lua'))do data.ui[key]={en=key,ko=ko};data.fragments[key]=ko end
 for key,ko in pairs(dofile(ctx.base..'/strings76.lua'))do data.ui[key]={en=key,ko=ko};data.fragments[key]=ko end
 for key,ko in pairs(dofile(ctx.base..'/stringsCM.lua'))do data.ui[key]={en=key,ko=ko};data.fragments[key]=ko end
 for id,row in pairs(dofile(ctx.base..'/strings88.lua'))do data.items[id]=row;data.ui[row.en]=row end
 for id,row in pairs(dofile(ctx.base..'/strings104.lua'))do data.items[id]=row;data.ui[row.en]=row end
 for id,row in pairs(dofile(ctx.base..'/strings89.lua'))do data.items[id]=row;data.ui[row.en]=row end
 for id,row in pairs(dofile(ctx.base..'/strings107.lua'))do data.items[id]=row;data.ui[row.en]=row end
 for id,row in pairs(dofile(ctx.base..'/stringsA.lua'))do data.items[id]=row;data.ui[row.en]=row end
 local ordered={};for key in pairs(data.fragments)do if key:match('%a')then ordered[#ordered+1]=key end end
 table.sort(ordered,function(a,b)return #a>#b end)
 local function str(s)return type(s)=='string'and s or s:ToString()end
 function L:refresh(force)
  if not force and self.nextAt and os.clock()<self.nextAt then return end;self.nextAt=os.clock()+.5
  local lib=StaticFindObject('/Script/Engine.Default__KismetInternationalizationLibrary');assert(ctx.valid(lib),'Internationalization library absent')
  local culture=str(lib:GetCurrentLanguage());local lang=culture:lower():match('^ko')and'ko'or'en'
  if self.culture~=culture or not self.detected then self.culture=culture;self.lang=lang;self.detected=true;self.generation=self.generation+1;self.cache={};self.cacheOrder={};self.unknown={};self.unknownOrder={};print('[PalCraft] MC57_LANGUAGE culture='..culture..' mod='..lang..'\n')end
 end
 function L:set(culture)
  local lib=StaticFindObject('/Script/Engine.Default__KismetInternationalizationLibrary');assert(ctx.valid(lib))
  assert(lib:SetCurrentCulture(culture,true),'Native language change rejected');self:refresh(true);assert(self.lang==culture)
 end
 function L:item(id)
  local row=data.items[id];return row and row[self.lang]
 end
 function L:t(s)
  s=tostring(s or'');if self.lang=='en'or s==''then return s end
  if not s:match('[A-Za-z]')then return s end
  local row=data.ui[s];if row then return row.ko end
  if self.cache and self.cache[s]then return self.cache[s]end
  local result=s
  for _,key in ipairs(ordered)do local r=data.ui[key]
   if r.ko~=r.en then local pattern=key:gsub('(%W)','%%%1');result=result:gsub('%f[%a]'..pattern..'%f[%A]',function()return r.ko end)end
  end
  local function bounded(mapName,orderName,limit)
   self[mapName]=self[mapName]or{};self[orderName]=self[orderName]or{}
   if self[mapName][s]==nil then local order=self[orderName];order[#order+1]=s;if #order>limit then self[mapName][table.remove(order,1)]=nil end end
   self[mapName][s]=result
  end
  bounded('cache','cacheOrder',512)
  if result:match('[A-Za-z][A-Za-z][A-Za-z]')and not result:find('Minecraft',1,true)and not result:find('Palworld',1,true)and not result:find('minecraft:',1,true)and not result:find('palworld:',1,true)then bounded('unknown','unknownOrder',128)end
  return result
 end
 return L
end
