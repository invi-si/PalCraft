-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
if package.loaded['PalCraft.jar_data'] then return package.loaded['PalCraft.jar_data'] end
local G={};local sessions={}
local function safe(s)
 assert(type(s)=='string' and not s:find('..',1,true) and not s:find('\\',1,true) and not s:match('^[/]') and not s:find(':',1,true),'Unsafe Minecraft resource')
 return s
end
local function session(base)
 if sessions[base]then return sessions[base]end
 local J=dofile(base..'/json.lua');local docs={}
 local function read(path)
  if docs[path]then return docs[path]end
  local f=assert(io.open(path,'rb'),'PalCraft resource missing: '..path..'; run the installer')
  local raw=f:read(16777217);f:close();assert(raw and #raw<=16777216,'Minecraft JSON too large')
  local result=J.decode(raw);assert(type(result)=='table','Invalid Minecraft JSON: '..path);docs[path]=result;return result
 end
 local sourceRoot=base..'/assets/minecraft/_palcraft/'
 local sourceFile=io.open(sourceRoot..'source.json','rb')
 if sourceFile then sourceFile:close()else sourceRoot=base..'/cache/'end

 local source=read(sourceRoot..'source.json')
 assert(type(source.mc_version)=='string' and source.mc_version:match('^[%w_.-]+$'),'Invalid Minecraft version')
 assert(type(source.jar_sha256)=='string'and source.jar_sha256:match('^[a-f0-9]+$')and #source.jar_sha256==64,'Invalid Minecraft jar hash')
 assert(type(source.converter_sha256)=='string'and source.converter_sha256:match('^[a-f0-9]+$')and #source.converter_sha256==64,'Invalid converter hash')

 local identity=source.mc_version..':'..source.jar_sha256..':'..source.converter_sha256..':'..tostring(source.index_sha256 or '')..':'..tostring(source.source_data_sha256 or '')
 local prefix=base..'/cache/data-'..source.mc_version..'-'..source.jar_sha256:sub(1,16)..'-'..source.converter_sha256:sub(1,16)..'-'
 local bindings
 local function plan()
  if not bindings then bindings=dofile(base..'/data_bindings.lua')end
  return bindings
 end
 local bundle
 local function resource(path)
  safe(path)
  if not bundle then bundle=read(sourceRoot..'source-data.json')end
  return assert(bundle[path],'Minecraft resource missing from local JSON index: '..path)
 end
 local function ingredient(spec,mapping,seen,mode)
  if type(spec)=='table'then
   if spec.item or spec.tag then return ingredient(spec.item or ('#'..spec.tag),mapping,seen,mode)end
   if mode=='decor'then local result={};for _,v in ipairs(spec)do for _,id in ipairs(ingredient(v,mapping,seen,mode))do result[#result+1]=id end end;return result end
   local set={};for _,v in ipairs(spec)do for _,id in ipairs(ingredient(v,mapping,seen,mode))do set[id]=true end end
   local out={};for id in pairs(set)do out[#out+1]=id end;table.sort(out);return out
  end
  assert(type(spec)=='string','Invalid ingredient')
  if spec:sub(1,1)=='#'then
   local tag=spec:sub(2):gsub('^minecraft:','');safe(tag);seen=seen or {};assert(not seen[tag],'Minecraft tag cycle: '..tag)
   seen[tag]=true;local set={}
   for _,v in ipairs(resource('data/minecraft/tags/item/'..tag..'.json').values)do
    if type(v)=='table'and v.id then v=v.id end
    for _,id in ipairs(ingredient(v,mapping,seen,mode))do set[id]=true end
   end
   seen[tag]=nil
   if mode=='decor'and tag:find('logs',1,true)then
    local out={};for _,id in ipairs(plan().block_order)do if set[id]and(id:match('Log$')or id:match('Wood$'))then out[#out+1]=id end end;return out
   end
   if mode=='decor'then local out={};for _,id in ipairs(plan().item_order)do if set[id]then out[#out+1]=id;set[id]=nil end end;local rest={};for id in pairs(set)do rest[#rest+1]=id end;table.sort(rest);for _,id in ipairs(rest)do out[#out+1]=id end;return out end
   local out={};for id in pairs(set)do out[#out+1]=id end;table.sort(out);return out
  end
  local id=mapping[spec:gsub('^minecraft:','')];return id and {id}or {}
 end
 local function recipe(p)
  local raw=resource('data/minecraft/recipe/'..safe(p.source)..'.json')

  if raw.type=='minecraft:crafting_special_firework_rocket'then return {id=p.id,kind='crafting_shapeless',result='MC_FireworkRocket',count=3,ingredients={{'MC_Paper'},{'MC_Gunpowder'}}}end
  local mapping=plan().item_names[p.mode=='decor'and'modern'or p.mode];assert(mapping,'Unknown recipe binding mode')
  if p.id:match('_hoe')or p.id=='tnt23'or p.id=='bed25'then
   local copy={};for k,v in pairs(mapping)do copy[k]=v end;mapping=copy
   
   if p.id:match('^wooden_hoe')then for k in pairs(mapping)do if k:match('_planks$')and k~='oak_planks'then mapping[k]=nil end end end
   if p.id:match('^stone_hoe')then mapping.cobbled_deepslate=nil;mapping.blackstone=nil end
   if p.id=='tnt23'then mapping.gunpowder='GunPowder';mapping.red_sand=nil end
   if p.id=='bed25'then mapping.red_wool='Wool'end
  end
  local kind=raw.type:gsub('^minecraft:','');assert(kind=='crafting_shaped'or kind=='crafting_shapeless','Unsupported recipe: '..p.source)
  local result=raw.result;local id=mapping[(result.id or result.item):gsub('^minecraft:','')]
  local r={id=p.id,kind=kind,result=assert(id,'Unbound recipe result: '..p.source),count=result.count or 1}
  if kind=='crafting_shaped'then
   local pattern=raw.pattern;r.width=#pattern[1];r.height=#pattern;r.cells={}
   for _,row in ipairs(pattern)do
    for x=1,#row do
     local c=row:sub(x,x);if c==' 'then r.cells[#r.cells+1]=false else r.cells[#r.cells+1]=ingredient(raw.key[c],mapping,nil,p.mode)end
    end
   end
   if p.flip then for y=0,r.height-1 do for x=1,math.floor(r.width/2)do local a=y*r.width+x;local b=(y+1)*r.width-x+1;r.cells[a],r.cells[b]=r.cells[b],r.cells[a]end end end
  else r.ingredients={};for _,v in ipairs(raw.ingredients)do r.ingredients[#r.ingredients+1]=ingredient(v,mapping,nil,p.mode)end end
  return r
 end
 local evaluate
 evaluate=function(node)
  if type(node)~='table'then return node end
  if node.op=='language'then return assert(resource('minecraft/lang/'..(node.language=='en'and'en_us'or'ko_kr')..'.json')[node.key],'Missing language key: '..node.key)end
  if node.op=='title'then return (node.name:gsub('_',' '):gsub('(%a)([%w]*)',function(a,b)return a:upper()..b:lower()end))end
  if node.op=='recipe'then return recipe(node)end
  if node.op=='smelt'then
   local raw=resource('data/minecraft/recipe/'..safe(node.source)..'.json');assert(raw.type=='minecraft:smelting','Invalid furnace recipe')
   local mapping=plan().item_names.modern;local supported=false;for _,id in ipairs(ingredient(raw.ingredient,mapping))do if id==node.ingredient then supported=true end end;assert(supported,'Unsupported furnace ingredient')
   return {count=raw.result.count or 1,result=assert(mapping[(raw.result.id or raw.result.item):gsub('^minecraft:','')]),seconds=(raw.cookingtime or 200)/20}
  end
  if node.op=='sound'then
   local event=assert(resource('minecraft/sounds.json')[node.event],'Missing sound event')
   local sound=assert(event.sounds[node.index],'Missing sound variant');return type(sound)=='table'and(sound[node.field]or 1)or 1
  end
  if node.op=='metrics'then
   local result={};for cp,width in pairs(resource('minecraft/_palcraft/font-metrics.json'))do
    cp=tonumber(cp);if cp and(not(cp>=0x2800 and cp<=0x2bff)or node.extra[cp])then result[cp]=width end
   end;return result
  end
  local out={};for k,v in pairs(node)do out[k]=evaluate(v)end;return out
 end
 local function serialize(v)
  if type(v)=='string'then return string.format('%q',v)end
  if type(v)=='number'then assert(v==v and math.abs(v)<math.huge);return tostring(v)end
  if type(v)=='boolean'then return tostring(v)end
  assert(type(v)=='table','Non-data value in local table')
  local out={'{'};for k,x in pairs(v)do out[#out+1]='['..serialize(k)..']='..serialize(x)..','end;out[#out+1]='}';return table.concat(out)
 end
 local values;local origin
 local s={prefix=prefix}
 function s.load(name)
  if values then return assert(values[name],'Unknown generated module: '..name),origin end
  local path=prefix..'tables.lua';local cached=loadfile(path,'t',{})
  if cached then local ok,v=pcall(cached);if ok and type(v)=='table'and v.identity==identity and type(v.value)=='table'and type(v.value[name])=='table'then values=v.value;origin='disk-cache';return values[name],origin end end
  assert(plan().modules[name],'Unknown generated module: '..name)
  local v={};for module,p in pairs(plan().modules)do v[module]=evaluate(p)end
  local temp=path..'.tmp';local file=io.open(temp,'wb')
  if file then
   local ok=pcall(function()assert(file:write('return '..serialize({identity=identity,value=v})..'\n'));assert(file:flush())end);file:close()
   if ok then

    local existing=io.open(path,'rb')
    if existing then existing:close();local bad=path..'.invalid-'..tostring(os.time());local prior=io.open(bad,'rb');if prior then prior:close()else os.rename(path,bad)end end
    os.rename(temp,path)
   end
  end
  values=v;origin='generated';return values[name],origin
 end
 sessions[base]=s;return s
end
function G.load(base,name)
 assert(type(name)=='string'and name:match('^[%w_]+$'),'Invalid local table name')
 return session(base).load(name)
end
package.loaded['PalCraft.jar_data']=G
return G
