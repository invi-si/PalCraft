-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local P={candidates={{X=-473200,Y=384600,Z=-400},{X=-473000,Y=384700,Z=-400}},offsets={{0,0},{200,0},{-200,0},{0,200},{0,-200}}}
function P.destination(g,p)
 local q=g.perch
 if not q then return {X=p.X,Y=p.Y,Z=g.home.Z+1000} end
 if not g.perchStage then g.perchStage='ASCEND';g.perchAbove=math.max(p.Z,q.Z)+900 end
 if g.perchStage=='ASCEND'and p.Z>=g.perchAbove-90 then g.perchStage='TRAVEL' end
 if g.perchStage=='TRAVEL'and (p.X-q.X)^2+(p.Y-q.Y)^2<90^2 then g.perchStage='DESCEND' end
 if g.perchStage=='ASCEND'then return {X=p.X,Y=p.Y,Z=g.perchAbove} end
 if g.perchStage=='TRAVEL'then return {X=q.X,Y=q.Y,Z=g.perchAbove} end
 return q
end

function P.descentImpulse(heightError)
 if heightError<=65 then return 0 end
 return -math.min(140,heightError)
end
return P
