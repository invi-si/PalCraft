-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local J={}
function J.encode(v)
    local t=type(v)
    if t=='nil'then return'null'end
    if t=='boolean'or t=='number'then assert(t~='number'or(v==v and math.abs(v)<math.huge));return tostring(v)end
    if t=='string'then return'"'..v:gsub('[%z\1-\31\\"]',function(c)return({['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'})[c]or string.format('\\u%04x',c:byte())end)..'"'end
    assert(t=='table','JSON value must be plain data')
    local keys={};local array=true;local n=0
    for k in pairs(v)do keys[#keys+1]=k;n=n+1;if type(k)~='number'or k%1~=0 or k<1 then array=false end end
    if array and #v==n then local out={};for i=1,n do out[i]=J.encode(v[i])end;return'['..table.concat(out,',')..']'end
    table.sort(keys);local out={};for _,k in ipairs(keys)do out[#out+1]=J.encode(tostring(k))..':'..J.encode(v[k])end
    return'{'..table.concat(out,',')..'}'
end
function J.decode(s)
    assert(type(s)=='string'and #s<6000000,'Invalid JSON input');local p=1;local value
    local function space()local _,e=s:find('^%s*',p);p=(e or p-1)+1 end
    local function stringValue()
        p=p+1;local out={}
        while p<=#s do
            
            local at=s:find('["\\%z\1-\31]',p);assert(at,'Unterminated JSON string')
            if at>p then out[#out+1]=s:sub(p,at-1)end
            local c=s:sub(at,at);p=at+1
            if c=='"'then return table.concat(out)end
            if c=='\\'then local e=s:sub(p,p);p=p+1
                if e=='u'then local h=s:sub(p,p+3);assert(h:match('^%x%x%x%x$'));local cp=tonumber(h,16);p=p+4
                    if cp>=0xd800 and cp<=0xdbff then assert(s:sub(p,p+1)=='\\u','Missing JSON low surrogate');local low=tonumber(s:sub(p+2,p+5),16);assert(low and low>=0xdc00 and low<=0xdfff,'Invalid JSON low surrogate');cp=0x10000+(cp-0xd800)*1024+low-0xdc00;p=p+6
                    else assert(cp<0xdc00 or cp>0xdfff,'Unpaired JSON low surrogate')end
                    out[#out+1]=utf8.char(cp)
                else out[#out+1]=assert(({['"']='"',['\\']='\\',['/']='/',n='\n',r='\r',t='\t',b='\b',f='\f'})[e],'Bad JSON escape')end
            else assert(c:byte()>=32,'Bad JSON string');out[#out+1]=c end
        end
        error('Unterminated JSON string')
    end
    value=function(depth)
        assert(depth<16,'JSON depth limit');space();local c=s:sub(p,p)
        if c=='"'then return stringValue()end
        if c=='{'or c=='['then
            local object=c=='{';local close=object and'}'or']';p=p+1;space();local result={}
            if s:sub(p,p)==close then p=p+1;return result end
            while true do
                local k;if object then assert(s:sub(p,p)=='"');k=stringValue();space();assert(s:sub(p,p)==':');p=p+1 else k=#result+1 end
                assert(result[k]==nil,'Duplicate JSON key');result[k]=value(depth+1);space();c=s:sub(p,p);p=p+1
                if c==close then return result end;assert(c==',','Missing JSON comma');space()
            end
        end
        for token,v in pairs({['true']=true,['false']=false})do if s:sub(p,p+#token-1)==token then p=p+#token;return v end end
        if s:sub(p,p+3)=='null'then p=p+4;return nil end
        local token=s:match('^-?%d+%.?%d*[eE]?[+-]?%d*',p);assert(token,'Bad JSON token');p=p+#token;return assert(tonumber(token))
    end
    local result=value(0);space();assert(p>#s,'Trailing JSON');return result
end
return J
