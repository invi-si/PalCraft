-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local M={}
function M.wrap(a)return(a+180)%360-180 end
function M.approach(a,b,rate,dt)
 local limit=rate*math.max(0,math.min(.2,dt or 0))
 return M.wrap(a+math.max(-limit,math.min(limit,M.wrap(b-a))))
end

function M.couple(body,head,bodyTarget,headTarget,dt,limit)
 limit=math.min(75,limit or 75)
 headTarget=bodyTarget+math.max(-limit,math.min(limit,M.wrap(headTarget-bodyTarget)))
 head=M.approach(head,headTarget,200,dt)
 body=M.approach(body,bodyTarget,200,dt)
 body=M.wrap(head+math.max(-limit,math.min(limit,M.wrap(body-head))))
 return body,head
end
return M
