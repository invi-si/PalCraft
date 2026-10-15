-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
local ignoredHitBufferJ={}
local function ignoredHitJ()
 
 for k in pairs(ignoredHitBufferJ)do ignoredHitBufferJ[k]=nil end
 return ignoredHitBufferJ
end

return function(ctx,M,asset)
 local D=dofile(ctx.base..'/item_display66.lua');local H=dofile(ctx.base..'/hand_motion66.lua')
 local worldPose=dofile(ctx.base..'/world_poseL.lua')(ctx)
 local V={};local function vec(x,y,z)return{X=x,Y=y,Z=z}end
 function V:supports(id)return id==nil or id==''or D[id]~=nil end
 local function cameraBasis(q)return{X=q.X,Y=q.Z,Z=-q.Y,W=q.W}end
 local function inCamera(v)return vec(-v.X*100,-v.Z*100,v.Y*100)end
 function V:update(S,env,held,hand,rigid,rotation,eye)
  local empty=not ctx.valid(held);local id=empty and''or hand.id
  local display=D[id];S.itemOnly66=false;if not display and not(empty and S.firstPerson)then self.token=nil;return false end
  local fp=S.firstPerson;S.itemOnly66=fp and not empty;local armScale=fp and .45 or 1;local itemScale=fp and .8 or 1
  local token=tostring(empty and 0 or held:GetAddress())..':'..id..':'..tostring(fp)..':'..tostring(hand.revision)
  local now=os.clock();local pose=rigid.snapshot or{};local dt=math.min(.1,math.max(0,now-(self.at or now)));self.at=now
  self.view=self.view or{};H.step(self.view,id,now,rotation.Pitch,rotation.Yaw,pose.speed or 0,dt)
  
  local ready=not fp or not self.token or self.perspective~=fp or self.view.visible==id
  if token~=self.token and ready then
   S:clearViewWeapons(env,true);self.token=token
   self.perspective=fp
   if not empty then
   if not ctx.valid(S.mcViewStatic)then
    S.mcViewStatic=env.player:AddComponentByClass(ctx.UE.Object('/Script/Engine.StaticMeshComponent'),true,{Rotation={X=0,Y=0,Z=0,W=1},Translation=vec(0,0,0),Scale3D=vec(1,1,1)},false)
   end
   local c=S.mcViewStatic;S.mcViewAddress66=c:GetAddress();c:SetStaticMesh(held.StaticMesh)
   for i=0,held:GetNumMaterials()-1 do c:SetMaterial(i,held:GetMaterial(i))end
   c:SetCollisionEnabled(0);c:SetCastShadow(not fp);c:SetOnlyOwnerSee(fp);c:SetOwnerNoSee(false)
   assert(c:K2_AttachToComponent(S.mesh,ctx.UE.FindOrAddFName('hand_r'),2,2,2,false))
   
   local r=rigid.rest.hand_r.Rotation
   local q=fp and M.mul(M.euler(-math.pi/2,0,0),rigid.armDown.r)or rigid.armDown.r
   local inverse=M.inv(M.mul(q,r));local d=display[fp and'first_right'or'third_right']
   local k=itemScale/armScale

   local slimOffset=S.choice and S.choice.format=='slim'and 2.8125 or 0
   local transform={Rotation=M.mul(inverse,d.Rotation),Translation=M.rotate(inverse,vec(d.Translation.X*k+slimOffset,d.Translation.Y*k,d.Translation.Z*k)),Scale3D=vec(d.Scale3D.X*k,d.Scale3D.Y*k,d.Scale3D.Z*k)}

   if display.kind=='food'then transform.Scale3D.X=.000001*k end
   _G.MC_OUT_K('K2_SetRelativeTransform',c,transform,false,ignoredHitJ(),true);c:SetVisibility(true,false)
   S.viewWeapons={{source=held,component=c,ownerNoSee=held.bOwnerNoSee,visible=held:IsVisible(),attached66=true}}
   held:SetOwnerNoSee(true);held:SetVisibility(false,false)
   ctx.log('MC66_HAND_ATTACHED id='..hand.id..' first_person='..tostring(fp)..' socket=hand_r display=jar')
   end
  end
  if fp then
   local v=self.view
   local use=pose.use=='bow'and'bow'or pose.use=='eat'and'eat'or nil
   if use~=v.use then v.use=use;v.useAt=now end
   local p,q=H.view(M,v,{pitch=rotation.Pitch,yaw=rotation.Yaw,swing=pose.swing or 0,use=use,useAge=now-(v.useAt or now)})

   p.X=p.X-.11;p.Y=p.Y+.20;p.Z=p.Z-.18

   local orient=M.mul(M.axis(0,0,1,math.rad(rotation.Yaw-90)),M.axis(1,0,0,math.rad(rotation.Pitch)))
   orient=M.mul(orient,cameraBasis(q))
   local grip=M.add(eye,M.rotate(M.mul(M.axis(0,0,1,math.rad(rotation.Yaw-90)),M.axis(1,0,0,math.rad(rotation.Pitch))),inCamera(p)))
   local handPos=rigid.previous.hand_r
   local h=handPos.Translation
   local location=M.sub(grip,M.rotate(orient,vec(h.X*armScale,h.Y*armScale,h.Z*armScale)))
   worldPose(S.mesh,{Rotation=orient,Translation=location,Scale3D=vec(armScale,armScale,armScale)})
   S.viewGrip=grip;S.viewSwing=pose.swing or 0
  end
  return true
 end
 return V
end
