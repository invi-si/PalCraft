-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local F={}
function F.parse(text)
 local values={packs='hud_skins,islands_animals',map_art='1',creative_mode='1'}
 for line in (text or ''):gmatch('[^\r\n]+')do
  line=line:gsub('[;#].*$','')
  local key,value=line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
  if key and values[key]~=nil then values[key]=value end
 end
 local selected={core=true}
 for name in values.packs:gmatch('[^,%s]+')do
  assert(name=='hud_skins'or name=='islands_animals'or name=='core','Unknown PalCraft pack: '..name)
  selected[name]=true
 end
 assert(values.map_art=='0'or values.map_art=='1','PalCraft map_art must be 0 or 1')
 assert(values.creative_mode=='0'or values.creative_mode=='1','PalCraft creative_mode must be 0 or 1')
 selected.map_art=selected.islands_animals==true and values.map_art=='1'
 local flags={packs=selected,map_art=selected.map_art,creative_mode=selected.hud_skins==true and values.creative_mode=='1'}
 function flags:has(pack)return self.packs[pack]==true end
 function flags:apply(config)
  config.island=self:has('islands_animals');config.mobs=config.island
  config.hud=self:has('hud_skins');config.steve=config.hud
  config.map_art=self.map_art
  config.creative_mode=self.creative_mode and config.creative_mode~=false
  return config
 end
 return flags
end
function F.read(base)
 local file=io.open(base..'/config.ini','rb');local text=file and file:read('*a')or''
 if file then file:close()end
 return F.parse(text)
end
return F
