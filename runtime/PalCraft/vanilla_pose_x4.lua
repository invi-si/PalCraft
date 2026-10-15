-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local base=(debug.getinfo(1,'S').source:sub(2):match('^(.*)[/\\]'))
local D=dofile(base..'/vanilla_pose_program_x4.lua')
local M={};local NULL={};local function copy(v)
 if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
local function f32(x)return(string.unpack('f',string.pack('f',x)))end
local function trunc(x)return x<0 and math.ceil(x)or math.floor(x)end
local function equal(a,b)if a==b then return true end;return type(a)=='table'and type(b)=='table'and a.enum~=nil and a.enum==b.enum and a.class==b.class end
local function comp(op,a,b)
 if op=='eq'then return equal(a,b)elseif op=='ne'then return not equal(a,b)elseif op=='lt'then return a<b elseif op=='le'then return a<=b elseif op=='gt'then return a>b elseif op=='ge'then return a>=b end;error(op)
end
local function reset(p)for k,v in pairs(p._initial)do p[k]=v end;for _,ch in pairs(p._children)do reset(ch)end end
local invoke
local compiled
local function animate(def,root,time,weight)
 if def.loop then time=f32(math.fmod(time,def.length))end
 local parts={};local function walk(p)parts[p.name]=p;for _,c in pairs(p._children)do walk(c)end end;walk(root)
 for _,ch in ipairs(def.channels)do
  local p=assert(parts[ch.part],ch.part);local keys=ch.keys;local en=#keys
  for i,k in ipairs(keys)do if k.time>=time then en=i;break end end
  local st=math.max(1,en-1);local dt=f32(keys[en].time-keys[st].time);local t=dt~=0 and math.max(0,math.min(1,f32(f32(time-keys[st].time)/dt)))or 0
  local fields=({['gfy$d.a']='bcd',['gfy$d.b']='efg',['gfy$d.c']='hij'})[ch.target]
  for j=1,3 do
   local a,b=keys[st].value[j],keys[en].value[j];local v
   if keys[en].interpolation=='gfy$b.b'then local u,w=keys[math.max(1,st-1)].value[j],keys[math.min(#keys,en+1)].value[j];v=invoke('bgj','a','(FFFFF)F',{t,u,a,b,w},NULL)
   else v=f32(a+f32(f32(b-a)*t))end
   local k=fields:sub(j,j);p[k]=f32(p[k]+f32(v*weight))
  end
 end
end
local sine={};local function trig(a,cos)
 local i=trunc(a*10430.378350470453+(cos and 16384 or 0))&65535
 if sine[i]==nil then sine[i]=f32(math.sin(i*math.pi*2/65536))end;return sine[i]
end
local mathops={min=math.min,max=math.max,abs=math.abs,sin=math.sin,cos=math.cos,sqrt=math.sqrt,floor=math.floor,ceil=math.ceil,pow=function(a,b)return a^b end,atan2=math.atan,clamp=function(a,lo,hi)return math.max(lo,math.min(hi,a))end}
local function builtin(c,n,d,a,o)
 if c=='bgj'and d=='(D)F'and(n=='a'or n=='b')then return true,trig(a[1],n=='b')end
 if c=='java/lang/Math'then return true,assert(mathops[n],n)(table.unpack(a))end
 if c=='java/lang/Object'or c=='java/lang/Record'then assert(n=='<init>');return true end
 if n=='ordinal'then return true,o.ordinal end
 if c=='gzm'then assert(n=='a'and d=='(Ljava/lang/Object;)V');reset(o._root);return true end
 if c=='hdg'then
  if n=='b'and d=='(Ljava/lang/String;)Lhdg;'then return true,assert(o._children[a[1]])end
  if n=='a'and d=='(Ljava/lang/String;)Z'then return true,o._children[a[1]]and 1 or 0 end
  if d=='(FFF)V'then local f=n=='a'and'bcd'or'efg';for j=1,3 do o[f:sub(j,j)]=a[j]end;return true end
  if n=='c'and d=='()V'then for k,v in pairs(o._initial)do o[k]=v end;return true end
  if d=='(Lhdg;)V'then for k in ('bcdefghij'):gmatch('.')do o[k]=a[1][k]end;return true end
 end
 if c=='ggb'then
  if d=='(Lcfz;F)V'then if a[1].started then animate(o.definition,o.root,f32(f32(trunc(f32(f32(a[2]-a[1].startTick)*50)))/1000),1)end;return true end
  if d=='(FFFF)V'then animate(o.definition,o.root,f32(f32(trunc(f32(f32(a[1]*50)*a[3])))/1000),math.min(f32(a[2]*a[4]),1));return true end
 end
 if c=='fzm'and d=='(FFF)V'then
  o.transforms=o.transforms or{};o.transforms[#o.transforms+1]={kind=n=='b'and'scale'or'translate',value=a};return true
 end
 if c=='dlt'and n=='a'then return true,(o~=NULL and o.kinetic_weapon)or NULL end
 if c=='doq'then local v=o[n];if d=='()Ljava/util/Optional;'then return true,{optional=v}end;return true,assert(v,'missing kinetic weapon field '..n)end
 if c=='java/util/Optional'then
  if n=='map'then return true,{optional=type(o.optional)=='table'and o.optional.durationTicks or o.optional}end
  if n=='orElse'then return true,o.optional or a[1]end
 end
 if c=='java/lang/Integer'then return true,n=='valueOf'and a[1]or o end
 return false
end
invoke=function(c,n,d,a,o,key)
 local handled,v=builtin(c,n,d,a,o);if handled then return v end
 key=key or c..'.'..n..d;local m=assert(D.methods[key],'unported method '..key);local loc={};local li=0
 if compiled and compiled[key]then return compiled[key](a,o)end
 if not m.static then loc[0]=o;li=1 end
 for j,t in ipairs(m.args)do loc[li]=a[j]or NULL;li=li+((t=='J'or t=='D')and 2 or 1)end
 local stack={};local sp=0;local function push(x)sp=sp+1;stack[sp]=x==nil and NULL or x end
 local function pop()assert(sp>0,'stack underflow '..key);local x=stack[sp];stack[sp]=nil;sp=sp-1;return x end
 local pc=m.first;local count=0
 while true do
  count=count+1;assert(count<100000,'loop '..key);local r=assert(m.code[pc],key..':'..pc);local op=r.op;local nxt=r.next
  if op=='new'then push({class=r.value})
  elseif op=='dup'then push(stack[sp])
  elseif op=='dup_x1'then local x,y=pop(),pop();push(x);push(y);push(x)
  elseif op=='dup2'then local x,y=stack[sp-1],stack[sp];push(x);push(y)
  elseif op=='pop'then pop()
  elseif op=='aconst_null'then push(NULL)
  elseif op=='ldc'or op=='ldc_w'or op=='ldc2_w'or op=='bipush'or op=='sipush'or op:match('^[ifdl]const_')then push(r.value)
  elseif op:match('^[aifdl]load')then push(loc[r.value])
  elseif op:match('^[aifdl]store')then loc[r.value]=pop()
  elseif op=='i2f'or op=='d2f'or op=='l2f'then push(f32(pop()))
  elseif op=='f2d'or op=='i2d'or op=='l2d'then
  elseif op=='f2i'or op=='d2i'or op=='l2i'or op=='i2l'then push(trunc(pop()))
  elseif op=='fneg'or op=='dneg'or op=='ineg'then push(-pop())
  elseif op:match('^[ifd]add$')or op:match('^[ifd]sub$')or op:match('^[ifd]mul$')or op:match('^[ifd]div$')or op:match('^[ifd]rem$')then
   local b,a=pop(),pop();local action=op:sub(2);local x
   if action=='add'then x=a+b elseif action=='sub'then x=a-b elseif action=='mul'then x=a*b elseif action=='div'then x=a/b else x=math.fmod(a,b)end
   push(op:sub(1,1)=='f'and f32(x)or(op:sub(1,1)=='i'and trunc(x)or x))
  elseif op=='iinc'then loc[r.index]=loc[r.index]+r.amount
  elseif op=='goto'then nxt=r.value
  elseif op:match('^if_icmp')then local b,a=pop(),pop();if comp(op:sub(8),a,b)then nxt=r.value end
  elseif op=='if_acmpeq'or op=='if_acmpne'then local b,a=pop(),pop();if comp(op:sub(8),a,b)then nxt=r.value end
  elseif op=='ifnull'or op=='ifnonnull'then local a=pop();if (a==NULL)==(op=='ifnull')then nxt=r.value end
  elseif op:match('^if')then if comp(op:sub(3),pop(),0)then nxt=r.value end
  elseif op=='fcmpl'or op=='fcmpg'or op=='dcmpl'or op=='dcmpg'then local b,a=pop(),pop();push(a>b and 1 or a<b and -1 or 0)
  elseif op=='getfield'then
   local a=pop();assert(a~=NULL,'null field '..r.field);local x=a[r.field]
   if x==nil then x=r.desc:match('^[ZBSCIJFD]$')and 0 or NULL end;push(x)
  elseif op=='putfield'then local x,a=pop(),pop();a[r.field]=x
  elseif op=='getstatic'then push(assert(D.static[r.field],'missing static '..r.field))
  elseif op=='putstatic'then error('static write in animation')
  elseif op=='invokedynamic'then push({lambda=r.value})
  elseif op:match('^invoke')then
   local aa={};for j=r.count,1,-1 do aa[j]=pop()end;local obj=r.static and NULL or pop();local x=invoke(r.owner,r.name,r.desc,aa,obj,r.key);if r.returns then push(x)end
  elseif op=='anewarray'or op=='newarray'then local len=pop();local ar={};for j=1,len do ar[j]=NULL end;push(ar)
  elseif op=='aastore'or op=='fastore'or op=='iastore'then local x,i,a=pop(),pop(),pop();a[i+1]=x
  elseif op=='aaload'or op=='faload'or op=='iaload'then local i,a=pop(),pop();push(a[i+1])
  elseif op=='arraylength'then push(#pop())
  elseif op=='tableswitch'or op=='lookupswitch'then nxt=r.jumps[tostring(math.floor(pop()))]or r.jumps.default
  elseif op=='iand'or op=='ior'or op=='ixor'then local b,a=math.floor(pop()),math.floor(pop());push(op=='iand'and(a&b)or op=='ior'and(a|b)or(a~b))
  elseif op=='checkcast'then
  elseif op=='areturn'or op=='freturn'or op=='ireturn'or op=='dreturn'then return pop()
  elseif op=='return'then return nil
  else error('unported opcode '..key..':'..pc..' '..op)end
  pc=nxt
 end
end
local function create(kind)
 local spec=assert(D.models[kind],kind);local parts={}
 local function make(row)
  local p={class='hdg',name=row.name,_children={},_initial={h=1,i=1,j=1,k=1,l=0}}
  if row.scale then p._initial.h=row.scale[1];p._initial.i=row.scale[2];p._initial.j=row.scale[3]end
  for j,k in ipairs({'b','c','d','e','f','g'})do p._initial[k]=row.pose[j]end
  for k,v in pairs(p._initial)do p[k]=v end;parts[p.name]=p
  for _,child in ipairs(row.children)do p._children[child.name]=make(child)end;return p
 end
 local root=make(spec.root)
 local function resolve(v)
  if type(v)~='table'then return v end
  if v.partRef then return assert(parts[v.partRef],v.partRef)end
  local out={};for k,x in pairs(v)do out[k]=resolve(x)end;return out
 end
 local obj=resolve(spec.object);obj._root=root
 return {kind=kind,spec=spec,object=obj,root=root,parts=parts,output={},args={}}
end
function M.new(kind)return create(kind)end
function M.frame(instance,state)
 local s=state or copy(instance.spec.state or{});local e=instance.spec.entry
 if e then local m=D.methods[e];instance.args[1]=s;invoke(m.owner,m.name,m.desc,instance.args,instance.object,e)else reset(instance.root)end
 local out=instance.output;for name,p in pairs(instance.parts)do local pose=out[name]or{};out[name]=pose;pose[1]=p.b;pose[2]=p.c;pose[3]=p.d;pose[4]=p.e;pose[5]=p.f;pose[6]=p.g;pose[7]=p.h;pose[8]=p.i;pose[9]=p.j;pose[10]=p.k end;return out
end
function M.defaultState(kind)return copy(D.models[kind].state or{})end
function M.enum(class,field)return assert(D.static[class..'.'..field])end 
function M.effect(key,state,age)
 local m=assert(D.methods[key],key);local obj={class=m.owner};local stack={class='fzm'};local a={state}
 if m.desc:find('Lfzm;',1,true)then a[2]=stack elseif #m.args==2 then a[2]=age end
 local value=invoke(m.owner,m.name,m.desc,a,obj,key);return value,stack.transforms
end
function M.entityEffect(key,object,partial)
 local m=assert(D.methods[key],key);return invoke(m.owner,m.name,m.desc,{f32(partial)},object,key)
end

function M.whiteOverlay(progress)
 local u=trunc(f32(progress*15));return 1-trunc(f32(f32(1-f32(f32(u/15)*.75))*255))/255
end
M.f32=f32;M.program=D;M.NULL=NULL
compiled=dofile(base..'/vanilla_pose_compiled_x4.lua')({call=invoke,D=D,f32=f32,NULL=NULL,trunc=trunc,comp=comp})
return M
