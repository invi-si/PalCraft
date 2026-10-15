-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local P={}
local crcTable={}
for i=0,255 do local c=i;for _=1,8 do c=(c>>1)~((c&1)==1 and 0xedb88320 or 0)end;crcTable[i]=c end
function P.crc(s)local c=0xffffffff;for i=1,#s do c=(c>>8)~crcTable[(c~s:byte(i))&255]end;return (~c)&0xffffffff end
local function adler(s)local a,b=1,0;for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end;return (b<<16)|a end
local function huffman(lengths)
 local counts,nextCode,codes={}, {}, {};local code=0;local max=0
 for _,n in ipairs(lengths)do assert(n<=15);if n>0 then counts[n]=(counts[n]or 0)+1;max=math.max(max,n)end end
 for n=1,15 do code=(code+(counts[n-1]or 0))<<1;nextCode[n]=code;assert(code+(counts[n]or 0)<=1<<n,'Invalid Huffman tree')end
 for symbol,n in ipairs(lengths)do if n>0 then local v=nextCode[n];nextCode[n]=v+1;local rev=0;for _=1,n do rev=(rev<<1)|(v&1);v=v>>1 end;codes[(1<<n)|rev]=symbol-1 end end
 return {codes=codes,max=max}
end
local lb={3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
local le={0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
local db={1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local de={0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}
local fixedL,fixedD={},{};for i=0,287 do fixedL[i+1]=i<144 and 8 or i<256 and 9 or i<280 and 7 or 8 end;for i=1,32 do fixedD[i]=5 end
fixedL,fixedD=huffman(fixedL),huffman(fixedD)
function P.inflate(s,limit)
 assert(#s>=6 and (s:byte(1)*256+s:byte(2))%31==0 and s:byte(1)&15==8 and s:byte(2)&32==0,'Invalid zlib header')
 local pos,buf,bits=3,0,0;local out={};local n=0
 local function read(k)while bits<k do assert(pos<=#s-4,'Truncated deflate');buf=buf|(s:byte(pos)<<bits);pos=pos+1;bits=bits+8 end;local v=buf&((1<<k)-1);buf=buf>>k;bits=bits-k;return v end
 local function decode(tree)local c=0;for i=1,tree.max do c=c|(read(1)<<(i-1));local v=tree.codes[(1<<i)|c];if v then return v end end;error('Invalid deflate code')end
 local function push(v)n=n+1;assert(n<=limit,'Inflated skin exceeds bounds');out[n]=v end
 local final=0
 repeat
  final=read(1);local kind=read(2)
  if kind==0 then
   read(bits%8);local len=read(16);assert((len~read(16))==65535,'Stored block length');for _=1,len do push(read(8))end
  else
   assert(kind<3,'Reserved deflate block');local l,d=fixedL,fixedD
   if kind==2 then
    local nl,nd,nc=read(5)+257,read(5)+1,read(4)+4;assert(nl<=286)
    local order={16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15};local cl={};for i=1,19 do cl[i]=0 end;for i=1,nc do cl[order[i]+1]=read(3)end
    local tree=huffman(cl);local lengths={}
    while #lengths<nl+nd do local v=decode(tree)
     if v<16 then lengths[#lengths+1]=v else local count,value
      if v==16 then assert(#lengths>0);count=read(2)+3;value=lengths[#lengths]elseif v==17 then count=read(3)+3;value=0 else count=read(7)+11;value=0 end
      assert(#lengths+count<=nl+nd);for _=1,count do lengths[#lengths+1]=value end
     end
    end
    local a,b={},{};for i=1,nl do a[i]=lengths[i]end;for i=1,nd do b[i]=lengths[nl+i]end;assert(a[257]>0);l,d=huffman(a),huffman(b)
   end
   while true do local v=decode(l);if v==256 then break elseif v<256 then push(v)else
    local ix=v-256;assert(lb[ix],'Invalid length');local len=lb[ix]+read(le[ix]);local di=decode(d)+1;assert(db[di],'Invalid distance');local dist=db[di]+read(de[di]);assert(dist<=n,'Deflate distance out of bounds');for _=1,len do push(out[n-dist+1])end
   end end
  end
 until final==1
 local chunks={};for i=1,n,512 do chunks[#chunks+1]=string.char(table.unpack(out,i,math.min(n,i+511)))end;local result=table.concat(chunks)
 assert(adler(result)==string.unpack('>I4',s,#s-3),'Zlib checksum');return result
end
local function paeth(a,b,c)local p=a+b-c;local x,y,z=math.abs(p-a),math.abs(p-b),math.abs(p-c);return x<=y and x<=z and a or y<=z and b or c end
function P.decode(s,texture)
 assert(#s<=(texture and 33554432 or 262144) and s:sub(1,8)=='\137PNG\r\n\26\n','Invalid/oversized PNG')
 local pos,count,idat,ihdr,ended=9,0,{},nil,false;local palette,alpha
 while pos<=#s do
  count=count+1;assert(count<=128 and pos+11<=#s,'Truncated PNG');local len=string.unpack('>I4',s,pos);local kind=s:sub(pos+4,pos+7);assert(pos+11+len<=#s,'Truncated PNG chunk');local data=s:sub(pos+8,pos+7+len)
  assert(P.crc(kind..data)==string.unpack('>I4',s,pos+8+len),'PNG CRC');if count==1 then assert(kind=='IHDR')end
  if kind=='IHDR'then assert(not ihdr and len==13);ihdr={string.unpack('>I4I4BBBBB',data)}
  elseif kind=='PLTE'then assert(len%3==0 and len<=768);palette=data
  elseif kind=='tRNS'then alpha=data
  elseif kind=='IDAT'then idat[#idat+1]=data
  elseif kind=='IEND'then assert(len==0 and pos+11==#s and #idat>0);ended=true;break
  else assert(kind~='acTL'and kind~='fcTL'and kind~='fdAT','Animated PNG unsupported');assert(kind:byte(1)&32~=0,'Unknown critical PNG chunk')end
  pos=pos+len+12
 end
 assert(ended and ihdr,'Missing PNG end');local w,h,depth,color,comp,filter,interlace=table.unpack(ihdr)
 if texture then assert(w>0 and h>0 and w<=8192 and h<=8192 and w*h<=16777216,'Texture dimensions exceed budget')
 else assert(w==64 and(h==32 or h==64),'Skin size must be 64x64 or 64x32')end
 assert(comp==0 and filter==0 and interlace==0,'Interlaced PNG unsupported')
 local channels=({[0]=1,[2]=3,[3]=1,[4]=2,[6]=4})[color];assert(channels and(depth==8 or color==3 and(depth==1 or depth==2 or depth==4)),'Unsupported PNG bit depth')
 assert(color~=3 or palette,'Indexed PNG needs a palette');local stride=math.ceil(w*channels*depth/8);local bpp=math.max(1,math.ceil(channels*depth/8));local raw=P.inflate(table.concat(idat),(stride+1)*h);assert(#raw==(stride+1)*h)
 local pixels,previous={},{};local at=1
 for y=0,h-1 do
  local ft=raw:byte(at);at=at+1;assert(ft<=4,'Invalid PNG filter');local row={}
  for x=1,stride do local a=row[x-bpp]or 0;local b=previous[x]or 0;local c=previous[x-bpp]or 0;row[x]=(raw:byte(at)+(ft==1 and a or ft==2 and b or ft==3 and math.floor((a+b)/2)or ft==4 and paeth(a,b,c)or 0))&255;at=at+1 end
  for x=0,w-1 do local i=x*channels+1;local r,g,b,a
   if color==6 then r,g,b,a=row[i],row[i+1],row[i+2],row[i+3]
   elseif color==2 then r,g,b,a=row[i],row[i+1],row[i+2],255;if alpha and #alpha==6 then local rr,gg,bb=string.unpack('>I2I2I2',alpha);if r==rr and g==gg and b==bb then a=0 end end
   elseif color==3 then local bit=x*depth;local index=(row[math.floor(bit/8)+1]>>(8-depth-bit%8))&((1<<depth)-1);r,g,b=palette:byte(index*3+1,index*3+3);assert(b,'Palette index');a=alpha and alpha:byte(index+1)or 255
   else r=row[i];g,b=r,r;a=color==4 and row[i+1]or(alpha and r==string.unpack('>I2',alpha)and 0 or 255)end
   pixels[y*w+x+1]={r,g,b,a}
  end;previous=row
 end
 return {w=w,h=h,pixels=pixels}
end
function P.normalize(image)
 local px=image.pixels;local legacy=image.h==32
 if legacy then
  for i=2049,4096 do px[i]={0,0,0,0}end
  
  local copies={{20,48,24,52,4,16,8,20},{24,48,28,52,8,16,12,20},{16,52,20,64,8,20,12,32},{20,52,24,64,4,20,8,32},{24,52,28,64,0,20,4,32},{28,52,32,64,12,20,16,32},{36,48,40,52,44,16,48,20},{40,48,44,52,48,16,52,20},{32,52,36,64,48,20,52,32},{36,52,40,64,44,20,48,32},{40,52,44,64,40,20,44,32},{44,52,48,64,52,20,56,32}}
  for _,r in ipairs(copies)do for y=0,r[4]-r[2]-1 do for x=0,r[3]-r[1]-1 do local v=px[(r[6]+y)*64+r[7]-1-x+1];px[(r[2]+y)*64+r[1]+x+1]={table.unpack(v)}end end end
  local opaque=true;for y=0,31 do for x=32,63 do if px[y*64+x+1][4]<128 then opaque=false end end end
  if opaque then for y=0,31 do for x=32,63 do px[y*64+x+1][4]=0 end end end
 end
 local slim=not legacy
 for y=20,31 do for x=54,55 do if px[y*64+x+1][4]~=0 then slim=false end end end
 
 for _,r in ipairs({{0,0,32,16},{0,16,64,32},{16,48,48,64}})do for y=r[2],r[4]-1 do for x=r[1],r[3]-1 do px[y*64+x+1][4]=255 end end end
 image.h=64;image.legacy=legacy;image.model=slim and'slim'or'wide';return image
end
function P.encode(w,h,pixels)
 local rows={};for y=0,h-1 do local bytes={};for x=0,w-1 do local p=pixels[y*w+x+1]or{0,0,0,0};bytes[#bytes+1]=string.char(p[1],p[2],p[3],p[4])end;rows[#rows+1]='\0'..table.concat(bytes)end
 local raw=table.concat(rows);local chunks={'\120\1'};for i=1,#raw,65535 do local part=raw:sub(i,i+65534);chunks[#chunks+1]=string.char(i+#part-1==#raw and 1 or 0)..string.pack('<I2I2',#part,(~#part)&65535)..part end;chunks[#chunks+1]=string.pack('>I4',adler(raw))
 local function chunk(kind,data)return string.pack('>I4',#data)..kind..data..string.pack('>I4',P.crc(kind..data))end
 return '\137PNG\r\n\26\n'..chunk('IHDR',string.pack('>I4I4BBBBB',w,h,8,6,0,0,0))..chunk('IDAT',table.concat(chunks))..chunk('IEND','')
end
return P
