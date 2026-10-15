-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright Invi
return function(controller,valid)
 if not valid(controller)then return 'controller' end
 local state=controller:GetPalPlayerState()
 if not valid(state)then return 'player-state' end
 if state:IsPlayerDead()then return 'dead',nil,state end

 local player=controller:GetDefaultPlayerCharacter()
 if not valid(player)then return 'possession',nil,state end
 local owner=player:GetPalPlayerController()
 if not valid(owner)or owner:GetAddress()~=controller:GetAddress()then return 'ownership',nil,state end
 local component=player.CharacterParameterComponent
 if not valid(component)then return 'parameter',nil,state end
 local parameter=component:GetIndividualParameter()
 if not valid(parameter)then return 'parameter',nil,state end
 if parameter:IsDead()then return 'dead',nil,state end
 
 if not valid(player.CapsuleComponent)or not valid(player.Mesh)or
    not valid(player.ShooterComponent)or not valid(player.LoadoutSelectorComponent)then return 'components',nil,state end
 if not valid(player.Mesh:GetAnimInstance())then return 'animation',nil,state end
 if not player:HasAuthority()then return 'authority',nil,state end
 return 'alive',player,state
end
