-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local P={}
function P.legacy(base)
 local path,n=base:gsub('[/\\]PalCraft$','/MinecraftBlocks')
 return n>0 and path or nil
end
function P.readPath(path,opener)
 opener=opener or io.open
 local legacy,n=path:gsub('([/\\])PalCraft([/\\])','%1MinecraftBlocks%2',1)
 if n==0 then return path end

 local family=path:gsub('%.bak$',''):gsub('%.tmp$',''):gsub('%.previous$','')
 for _,suffix in ipairs({'','.tmp','.bak','.previous'})do
  local f=opener(family..suffix,'rb')
  if f then local size=f:seek('end');f:close();if size and size>0 then return path end end
 end
 local f=opener(legacy,'rb')
 if f then local size=f:seek('end');f:close();if size and size>0 then return legacy end end
 return path
end
function P.install(base)
 if not P.legacy(base)or package.loaded['PalCraft.legacy_paths']then return end

 local original=io.open
 function io.open(path,mode)
  local rootFile=type(path)=='string'and path:match('[/\\]PalCraft[/\\]([^/\\]+)$')
  if type(path)=='string'and(mode==nil or mode=='r'or mode=='rb')and
    rootFile and(rootFile:match('%.json$')or rootFile:match('%.json%.bak$')or rootFile:match('%.json%.tmp$')or rootFile:match('%.json%.previous$')or rootFile:match('^hotbar%-.+%.txt$'))then
   return original(P.readPath(path,original),mode)
  end
  return original(path,mode)
 end
 package.loaded['PalCraft.legacy_paths']=P
end
return P
