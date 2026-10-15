-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local UE,valid=ctx.UE,ctx.valid
 local T={cache={},missing={},materials={},meshes={},reads=0,loaded=0,failed=0,workMs=0,maxMs=0,textureIds={},parents={},bound={},boundMaterials={},cacheHits=0,cacheWrites=0,componentSlots=0,brushes=0}
 T.root=ctx.base..'/assets/minecraft/'
 T.data={textures={},materials={}};T.preloadDone=true;T.installedCooked=true
 local PNG=dofile(ctx.base..'/png71.lua')
 T.expected=0;T.expectedParameters=0
 for _ in pairs(T.data.textures)do T.expected=T.expected+1 end
 for _,rows in pairs(T.data.materials)do T.expectedParameters=T.expectedParameters+#rows end
 local function canonical(path)
  if type(path)~='string'or #path>512 or path:find('[%c\\:]')or path:sub(1,1)=='/'or path:find('..',1,true)or path:find('//',1,true)or not path:lower():match('%.png$')then return nil end
  return path
 end
 T.canonical=canonical
 local function pathOf(o)return o:GetFullName():match('^%S+ (.+)$')end
 local function unwrap(v)local ok,o=pcall(function()return v:get()end);return ok and o or v end
 function T:warn(path,reason)
  self.failed=self.failed+1;self.missing[path]=true
  if not self.warned then self.warned=true;ctx.log('PALCRAFT_ASSETS_MISSING placeholder=true reason='..tostring(reason)..' path='..tostring(path)..' install Minecraft Java 1.21.x assets into PalCraft/assets/minecraft')end
 end
 function T:retainNative(o)
  if ctx.retain then return ctx.retain(o)end
  
  local gi=UE.GetGameInstance();if not valid(gi)then return false end
  local refs={};local found=false
  gi.ReferencedObjects:ForEach(function(_,v)local x=unwrap(v);if valid(x)then refs[#refs+1]=x;if x:GetAddress()==o:GetAddress()then found=true end end end)
  if not found then refs[#refs+1]=o;gi.ReferencedObjects=refs end
  return true
 end
 function T:retain(o)
  self.retained=self.retained or{};local id=o:GetAddress();if self.retained[id]then return true end

  local ok,err=pcall(function()
   local gs=UE.Object('/Script/Engine.Default__GameplayStatics');local cls=StaticFindObject('/Script/Engine.ObjectLibrary');assert(valid(cls))
   if not valid(self.referenceLibrary)then
    local root=gs:SpawnObject(cls,UE.GetGameInstance());assert(valid(root));self:retainNative(root);self.referenceLibrary=root;self.referenceBags={};self.referenceLeaf=nil;self.referenceBag=nil
   end
   if not self.referenceLeaf or #self.referenceLeaf>=64 then
    local bag=gs:SpawnObject(cls,self.referenceLibrary);assert(valid(bag));self.referenceBags[#self.referenceBags+1]=bag;self.referenceLibrary.Objects=self.referenceBags;self.referenceBag=bag;self.referenceLeaf={}
   end
   self.referenceLeaf[#self.referenceLeaf+1]=o;self.referenceBag.Objects=self.referenceLeaf
  end)
  if not ok then
   if not self.retainFallbackLogged then self.retainFallbackLogged=true;ctx.log('PALCRAFT_RETAIN_FALLBACK '..tostring(err))end
   self:retainNative(o)
  end
  self.retained[id]=true;return true
 end
 local cooked={
  ['textures/entity/player/wide/steve.png']='/Game/MinecraftRuntimeAssets/T_PC_Steve.T_PC_Steve',
  ['textures/entity/player/wide/alex.png']='/Game/MinecraftRuntimeAssets/T_PC_AlexWide.T_PC_AlexWide',
  ['textures/entity/player/slim/alex.png']='/Game/MinecraftRuntimeAssets/T_PC_AlexSlim.T_PC_AlexSlim',
  ['textures/block/dirt.png']='/Game/MinecraftRuntimeAssets/T_PC_Dirt.T_PC_Dirt',
 }
 function T:cooked(path,fallback)
  local object=StaticFindObject(path)
  if not valid(object)then
   local package,name=path:match('^(.*)%.([^%.]+)$')
   object=UE.GetAsset109(UE.Object('/Script/AssetRegistry.Default__AssetRegistryHelpers'),{PackageName=UE.FindOrAddFName(package),AssetName=UE.FindOrAddFName(name)})
  end
  return valid(object)and object or fallback
 end
 function T:load(relative,fallback,options)
  if not(options and(options.original or options.skin))then
   local path=cooked[relative];if not path then return fallback end
   return self:cooked(path,fallback)
  end
  relative=canonical(relative);if not relative then return fallback end
  local scope=options and options.original and'own:'or options and options.skin and'skin:'or''
  local root=scope=='own:'and(ctx.base..'/Assets/')or scope=='skin:'and(ctx.base..'/skins/')or self.root
  local cacheKey=scope..relative..(options and options.srgb==false and'|linear'or'')
  local cached=self.cache[cacheKey];if valid(cached)then return cached end
  if self.missing[cacheKey]then return fallback end
  local world=UE.GetGameInstance();if not valid(world)then return fallback end
  local started=os.clock();self.reads=self.reads+1
  local ok,result=pcall(function()
   local file=io.open(root..relative,'rb');if not file then error('file unavailable',0)end
   local bytes=file:read(33554433);file:close();local head=bytes:sub(1,24);local size=#bytes
   assert(head and #head==24 and head:sub(1,8)=='\137PNG\r\n\26\n'and size<=33554432,'invalid PNG header or file size')
   local w,h=string.unpack('>I4I4',head,17);assert(w>0 and h>0 and w<=8192 and h<=8192 and w*h<=16777216,'PNG dimensions exceed budget')

   local digest=string.format('%08x-%d',PNG.crc(bytes),size)
   local decoded=ctx.base..'/skins/_cache/tex-'..digest..'.tga'
   local f=io.open(decoded,'rb');local hit=false
   if f then local header=f:read(18);local length=f:seek('end');f:close();hit=header and #header==18 and header:byte(3)==2 and header:byte(17)==32 and length==18+w*h*4 and string.unpack('<I2',header,13)==w and string.unpack('<I2',header,15)==h end
   if hit then self.cacheHits=self.cacheHits+1 else
    local im=PNG.decode(bytes,true);local rows={string.pack('<BBB I2 I2 B I2 I2 I2 I2 BB',0,0,2,0,0,0,0,0,w,h,32,40)}
    for y=0,h-1 do local row={};for x=0,w-1 do local p=im.pixels[y*w+x+1];row[#row+1]=string.char(p[3],p[2],p[1],p[4])end;rows[#rows+1]=table.concat(row)end
    f=assert(io.open(decoded,'wb'),'Decoded cache directory unavailable');f:write(table.concat(rows));f:close();self.cacheWrites=self.cacheWrites+1
   end

   local defaults=StaticFindObject('/Script/Engine.Default__Texture2D');assert(valid(defaults),'Texture2D template unavailable')
   local oldFilter,oldSRGB,oldStream=defaults.Filter,defaults.SRGB,defaults.NeverStream
   local imported,texture=pcall(function()
    defaults.Filter=0;defaults.SRGB=not(options and options.srgb==false);defaults.NeverStream=true
    return UE.Object('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(world,decoded)
   end)
   defaults.Filter=oldFilter;defaults.SRGB=oldSRGB;defaults.NeverStream=oldStream
   assert(imported,texture)
   assert(valid(texture)and texture:Blueprint_GetSizeX()==w and texture:Blueprint_GetSizeY()==h,'PNG import failed')
   texture.Filter=0;texture.SRGB=not(options and options.srgb==false);texture.NeverStream=true
   self:retain(texture);return texture
  end)
  local ms=(os.clock()-started)*1000;self.workMs=self.workMs+ms;self.maxMs=math.max(self.maxMs,ms)
  if not ok then self:warn(cacheKey,result);return fallback end
  self.cache[cacheKey]=result;self.textureIds[result:GetAddress()]=cacheKey;self.loaded=self.loaded+1
  return result
 end
 function T:texture(path,fallback)return fallback end
 function T:material(parent)return parent end
 function T:mesh(mesh)return mesh end
 function T:asset(path,object)return object end
 function T:isTexture(t)return valid(t)and self.textureIds[t:GetAddress()]~=nil end
 function T:sourceMaterial(m)return m end
 function T:matches(object,path)return valid(object)and pathOf(object)==path end
 function T:font()return self:cooked('/Game/MinecraftFont/F_MC_UI53.F_MC_UI53',nil)end
 function T:component()end
 function T:widgets()end
 function T:actor(actor,done)if done then done()end end
 function T:level(level,done)if done then done()end end
 function T:queue(paths,done)if done then done()end end
 function T:preloadStep()return true end
 function T:status()
  return{mode='install-time-paks',runtimeBinding=false,cookedPatched=self.patchReceipt and self.patchReceipt.textures or 0,loaded=self.loaded,failed=self.failed,reads=self.reads,totalMs=self.workMs,maxMs=self.maxMs,root=self.root,bound=0,expected=0,parametersBound=0,parametersExpected=0,componentSlots=0,brushes=0,cacheHits=self.cacheHits,cacheWrites=self.cacheWrites}
 end
 function T:coverage(reason)
  local s=self:status();ctx.log('PALCRAFT_COOKED_COVERAGE reason='..reason..' patched='..s.cookedPatched..' runtime_binding=false skin_imports='..s.loaded);return s
 end
 function T:install()
  function UE.AssetMatchesRA(object,path)return T:matches(object,path)end
  local f=io.open(self.root..'_palcraft/cooked-patch-receipt.json','rb')
  if f then local raw=f:read(1048577);f:close();local ok,r=pcall(function()assert(#raw<=1048576);return dofile(ctx.base..'/json.lua').decode(raw)end);if ok then self.patchReceipt=r end end
  if not self.patchReceipt or not self.patchReceipt.complete then self:warn('cooked paks','installation patch incomplete or skipped; blank fallback active')end
  ctx.log('PALCRAFT_COOKED_ASSETS runtime_binding=false patched='..tostring(self.patchReceipt and self.patchReceipt.textures or 0))
 end
 return T
end
