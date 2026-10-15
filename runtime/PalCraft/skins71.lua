-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local K={directory=ctx.base..'/skins/',rows={}};local P=dofile(ctx.base..'/png71.lua');local J=dofile(ctx.base..'/json.lua');local R=dofile(ctx.base..'/skin_preview71.lua')
 local function read(path,limit)local f=assert(io.open(path,'rb'),'Skin file unavailable');local s=f:read(limit+1);f:close();assert(#s<=limit,'Skin file too large');return s end
 local function write(path,s)local f=assert(io.open(path,'wb'),'Cannot write skin cache');f:write(s);f:close()end
 local function basename(s)return type(s)=='string'and #s<=120 and s:lower():match('%.png$')and not s:find('[%c/\\:*?"<>|]')and not s:find('..',1,true)end
 K.basename=basename
 function K:decode(file)
  assert(basename(file),'Invalid skin filename');local bytes=read(self.directory..file,262144);local im=P.normalize(P.decode(bytes));im.file=file;im.hash=string.format('%08x',P.crc(bytes));return im
 end
 function K:scan()
  
  local path=self.directory:gsub('/','\\');assert(not path:find('[%%!&|<>"\r\n]'),'Unsafe skin directory')
  local pipe=assert(io.popen('chcp 65001 >nul & dir /b /a-d "'..path..'" 2>nul','r'));local names={}
  for name in pipe:lines()do if basename(name)then names[#names+1]=name;if #names>=128 then break end end end;pipe:close();table.sort(names,function(a,b)return a:lower()<b:lower()end)
  self.rows={};for _,file in ipairs(names)do self.rows[#self.rows+1]={file=file}end;return self.rows
 end
 function K:openFolder()
  local path=self.directory:gsub('/','\\');assert(not path:find('[%%!&|<>"\r\n]'),'Unsafe skin directory')
  
  return os.execute('start "" explorer.exe "'..path..'"')
 end
 function K:prepare(image,model)
  model=model or image.model;assert(model=='wide'or model=='slim');local stem=self.directory..'_cache/'..image.hash..'-'..model
  local mask={};for i,p in ipairs(image.pixels)do local a=p[4]>=128 and 255 or 0;mask[i]={a,a,a,255}end
  write(stem..'.png',P.encode(64,64,image.pixels));write(stem..'-mask.png',P.encode(64,64,mask))
  return {file=image.file,format=model,auto=image.model,legacy=image.legacy,path=stem..'.png',maskPath=stem..'-mask.png',hash=image.hash,custom71=true}
 end
 function K:choice(model,file)return self:prepare(self:decode(file),model)end
 function K:remember(choice)
  local path=ctx.base..'/skin-selection.json';local temp=path..'.tmp';write(temp,J.encode({file=choice.custom71 and choice.file or false,model=choice.format or'wide'}))
  local old=io.open(path,'rb');if old then old:close();os.remove(path)end;assert(os.rename(temp,path),'Cannot persist skin selection')
 end
 function K:saved()
  local f=io.open(ctx.base..'/skin-selection.json','rb');if not f then return end;local raw=f:read(4097);f:close()
  local ok,data=pcall(function()assert(#raw<=4096);return J.decode(raw)end)
  if not ok or type(data)~='table'then return false,'Invalid saved skin selection'end
  if data.file==false then return false end
  local success,choice=pcall(self.choice,self,data.model,data.file);if success then return choice end;return false,tostring(choice)
 end
 function K:import(env,path,w,h)
  assert(path:sub(1,#self.directory)==self.directory,'Skin cache escaped its directory')
  local t=ctx.UE.texRuntime:load(path:sub(#self.directory+1),nil,{skin=true});assert(ctx.valid(t)and t:Blueprint_GetSizeX()==w and t:Blueprint_GetSizeY()==h,'Skin decoder failed')
  t.Filter=0;t.SRGB=true;t.NeverStream=true;return t
 end
 function K:load(env,choice)
  local texture=self:import(env,choice.path,64,64);local mask=self:import(env,choice.maskPath,64,64);return texture,mask
 end
 function K:previewBegin(image,model)
  self.previewJob={image=image,model=model,at=0,pixels={},path=self.directory..'_cache/'..image.hash..'-'..model..'-preview.png'}
 end
 function K:previewStep()
  local j=self.previewJob;if not j then return end
  R.frame(j.image,j.model,j.at,j.pixels);j.at=j.at+1
  if j.at==R.frames then write(j.path,P.encode(R.width*R.frames,R.height,j.pixels));self.previewJob=nil;return j.path end
 end
 function K:thumbnail(image)
  local px={};for y=0,7 do for x=0,7 do local a=image.pixels[(y+8)*64+x+8+1];local b=image.pixels[(y+8)*64+x+40+1];px[y*8+x+1]=b[4]>=128 and b or a end end
  local path=self.directory..'_cache/'..image.hash..'-head.png';write(path,P.encode(8,8,px));return path
 end
 function K:portrait(env,choice)
  local model=choice.format or'wide';local image
  if choice.custom71 then image=self:decode(choice.file)
  else
   local path=ctx.base..'/assets/minecraft/textures/entity/player/'..(model=='slim'and'slim/alex.png'or'wide/steve.png')
   local f=io.open(path,'rb');if not f then if ctx.UE.texRuntime then ctx.UE.texRuntime:warn(path,'default skin unavailable')end;return nil end;f:close()
   local bytes=read(path,262144);image=P.normalize(P.decode(bytes));image.hash=string.format('%08x',P.crc(bytes))
  end
  local renderer=dofile(ctx.base..'/skin_portraitZ1.lua')
  local path=self.directory..'_cache/'..image.hash..'-'..model..'-frontZ1.png'
  write(path,P.encode(renderer.width,renderer.height,renderer.render(image,model)))
  return self:import(env,path,renderer.width,renderer.height),path,image.hash
 end
 return K
end
