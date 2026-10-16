-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local K={};local directory=ctx.base:gsub('\\','/'):gsub('/MinecraftBlocks$','/MinecraftSteve')..'/Skins/'
 local function read(path,limit)
  local f=assert(io.open(path,'rb'),'Skin file unavailable '..path);local bytes=f:read(limit+1);f:close();assert(bytes and #bytes<=limit,'Skin file too large');return bytes
 end
 local function crc(bytes)
  local n=0xffffffff;for i=1,#bytes do n=n~bytes:byte(i);for _=1,8 do n=(n>>1)~((n&1)==1 and 0xedb88320 or 0)end end;return(~n)&0xffffffff
 end
 function K.validate(bytes)
  assert(bytes:sub(1,8)=='\137PNG\r\n\26\n','Skin must be PNG');local pos,count,idat,ended=9,0,false,false
  while pos<=#bytes do
   count=count+1;assert(count<=128 and pos+11<=#bytes,'Truncated/excessive PNG chunks');local len=string.unpack('>I4',bytes,pos);local kind=bytes:sub(pos+4,pos+7);local last=pos+11+len;assert(last<=#bytes,'Truncated PNG')
   local payload=bytes:sub(pos+8,pos+7+len);assert(crc(kind..payload)==string.unpack('>I4',bytes,pos+8+len),'PNG CRC mismatch')
   if count==1 then
    assert(kind=='IHDR'and len==13);local w,h=string.unpack('>I4I4',payload);assert(w==64 and h==64,'Skin must be 64x64')
    local depth,colour,compression,filter,interlace=payload:byte(9,13);assert(depth==8 and(colour==2 or colour==6)and compression==0 and filter==0 and interlace==0,'Skin must be noninterlaced 8-bit RGB/RGBA')
   else assert(kind~='IHDR','Duplicate PNG header')end
   assert(kind~='acTL'and kind~='fcTL'and kind~='fdAT','Animated PNG unsupported');if kind=='IDAT'then idat=true end
   if kind=='IEND'then assert(len==0 and idat and last==#bytes);ended=true;break end;pos=last+1
  end
  assert(ended,'Missing PNG end');return true
 end
 function K.choice(format,file)
  if file=='skin.ini'then
   local values={};for line in(read(directory..file,1024)..'\n'):gmatch('([^\r\n]*)[\r\n]')do local clean=line:match('^%s*(.-)%s*$')
    if clean~=''and clean:sub(1,1)~='#'then local k,v=clean:match('^([a-z_]+)%s*=%s*(.-)%s*$');assert((k=='arm_format'or k=='file')and not values[k],'Invalid skin setting');values[k]=v end
   end;format,file=values.arm_format,values.file
  end
  assert(format=='wide'or format=='slim','Steve arm format must be wide/slim');assert(type(file)=='string'and file:match('^[A-Za-z0-9_-]+%.png$'),'Skin must be a PNG basename')
  K.validate(read(directory..file,262144));return{format=format,file=file,path=directory..file}
 end
 function K.load(env,choice)
  local texture=ctx.UE.Object('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(env.player,choice.path)
  assert(ctx.valid(texture)and texture:Blueprint_GetSizeX()==64 and texture:Blueprint_GetSizeY()==64,'Skin decoder failed')
  texture.Filter=0 
  assert(texture.Filter==0);return texture
 end
 function K.apply(component,texture,asset,mask)

  for i,name in ipairs({'M_MC27SkinBase','M_MC27SkinOverlay'})do
   local path=mask and i==2 and'/Game/MinecraftTask71/M_SkinOverlay71.M_SkinOverlay71'or('/Game/MinecraftSteve/Task27/'..name..'.'..name)
   local parent=asset(path)

   if ctx.UE.texRuntime then parent=ctx.UE.texRuntime:sourceMaterial(parent)end
   local mid=ctx.UE.Object('/Script/Engine.Default__KismetMaterialLibrary'):CreateDynamicMaterialInstance(component,parent,ctx.UE.FindOrAddFName('None'),0);assert(ctx.valid(mid))
   if ctx.valid(texture)then mid:SetTextureParameterValue(ctx.UE.FindOrAddFName('SkinTexture'),texture)end
   if mask and i==2 then mid:SetTextureParameterValue(ctx.UE.FindOrAddFName('SkinMask'),mask)end
   component:SetMaterial(i-1,mid)
  end
 end
 return K
end
