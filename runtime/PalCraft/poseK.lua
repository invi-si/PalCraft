-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(component,pose)
 component.RelativeLocation=pose.location
 component.RelativeRotation=pose.rotation
 component.RelativeScale3D={X=pose.scale.X+.001,Y=pose.scale.Y,Z=pose.scale.Z}
 component:SetRelativeScale3D(pose.scale)
end
