-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local M=dofile(ctx.base..'/steve_motion.lua');local P={}
 local names={'root','pelvis','spine_01','spine_02','spine_03','neck_01','head','upperarm_r','lowerarm_r','hand_r','upperarm_l','lowerarm_l','hand_l','thigh_r','foot_r','thigh_l','foot_l'}
 function P:bind(mesh)
  local address,name=mesh:GetAddress(),mesh:GetFullName()
  if self.address==address and self.name==name and self.rest then self.mesh=mesh;return end
  self.address,self.name=address,name
  self.mesh=mesh;self.rest={};self.names={};self.down={};self.at=os.clock()
  for _,n in ipairs(names)do local f=ctx.UE.FindOrAddFName(n);self.names[n]=f;local t=mesh:GetBoneTransformByName(f,1);self.rest[n]={Rotation={X=t.Rotation.X,Y=t.Rotation.Y,Z=t.Rotation.Z,W=t.Rotation.W},Translation={X=t.Translation.X,Y=t.Translation.Y,Z=t.Translation.Z},Scale3D={X=1,Y=1,Z=1}}end
  for _,s in ipairs({'l','r'})do self.down[s]=M.down(M.sub(self.rest['hand_'..s].Translation,self.rest['upperarm_'..s].Translation))end
 end
 function P:tick(yaw,pitch)
  if not ctx.valid(self.mesh)then return end
  local pose=M.pose({age=(os.clock()-self.at)*20,amount=0,limb=0,yaw=math.rad(yaw),pitch=math.rad(pitch),swing=0})
  local function put(n,q,p)local r=self.rest[n];self.mesh:SetBoneTransformByName(self.names[n],{Rotation=M.mul(q,r.Rotation),Translation=p or r.Translation,Scale3D={X=1,Y=1,Z=1}},1)end
  put('head',M.euler(pose.head.x,pose.head.y,0))
  for _,s in ipairs({'r','l'})do local a=pose[s..'arm'];local q=M.mul(M.euler(a.x,a.y,a.z),self.down[s]);local origin=self.rest['upperarm_'..s].Translation
   for _,n in ipairs({'upperarm_'..s,'lowerarm_'..s,'hand_'..s})do put(n,q,M.add(origin,M.rotate(q,M.sub(self.rest[n].Translation,origin))))end
  end
  self.snapshot={age=(os.clock()-self.at)*20,yaw=yaw,pitch=pitch,pose=pose}
 end
 return P
end
