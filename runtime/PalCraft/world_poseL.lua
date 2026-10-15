-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(ctx)
 local pose=dofile(ctx.base..'/poseK.lua');local mathlib
 return function(c,desired)
  mathlib=ctx.valid(mathlib)and mathlib or ctx.UE.Object('/Script/Engine.Default__KismetMathLibrary')
  local parent=c:GetAttachParent();local relative=desired
  if ctx.valid(parent)then relative=mathlib:MakeRelativeTransform(desired,parent:GetSocketTransform(c:GetAttachSocketName(),0))end
  pose(c,{location=relative.Translation,rotation=mathlib:Quat_Rotator(relative.Rotation),scale=relative.Scale3D})
  if ctx.UE.testModeL then
   local actual=c:K2_GetComponentToWorld();local err=0
   for _,field in ipairs({'Translation','Scale3D'})do for _,axis in ipairs({'X','Y','Z'})do err=math.max(err,math.abs(actual[field][axis]-desired[field][axis]))end end
   local dot=0;for _,axis in ipairs({'X','Y','Z','W'})do dot=dot+actual.Rotation[axis]*desired.Rotation[axis]end
   ctx.UE.heldPoseL={errorCm=err,quaternionError=math.abs(1-math.abs(dot)),samples=(ctx.UE.heldPoseL and ctx.UE.heldPoseL.samples or 0)+1}
  end
 end
end
