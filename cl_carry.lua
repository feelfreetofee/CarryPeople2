local carry = {
	allowedWeapons = {
		`WEAPON_PISTOL`,
		`WEAPON_COMBATPISTOL`,
		--etc add guns you want
	},
	InProgress = false,
	targetSrc = -1,
	type = "",
	personCarrying = {
		animDict = "missfinale_c2mcs_1",
		anim = "fin_c2_mcs_1_camman",
		flag = 49,
	},
	personCarried = {
		animDict = "nm",
		anim = "firemans_carry",
		attachX = 0.27,
		attachY = 0.15,
		attachZ = 0.63,
		flag = 33,
	},
	personPiggybacking = {
		animDict = "anim@arena@celeb@flat@paired@no_props@",
		anim = "piggyback_c_player_a",
		flag = 49,
	},
	personBeingPiggybacked = {
		animDict = "anim@arena@celeb@flat@paired@no_props@",
		anim = "piggyback_c_player_b",
		attachX = 0.0,
		attachY = -0.07,
		attachZ = 0.45,
		flag = 33,
	},
	agressor = {
		animDict = "anim@gangops@hostage@",
		anim = "perp_idle",
		flag = 49,
	},
	hostage = {
		animDict = "anim@gangops@hostage@",
		anim = "victim_idle",
		attachX = -0.24,
		attachY = 0.11,
		attachZ = 0.0,
		flag = 49,
	}
}

local function GetClosestPlayer(radius)
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _,playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(targetCoords-playerCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
	if closestDistance ~= -1 and closestDistance <= radius then
		return closestPlayer
	else
		return nil
	end
end

local function ensureAnimDict(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(0)
        end        
    end
    return animDict
end

function commander(mtype)
	if not carry.InProgress and not IsPedInAnyVehicle(PlayerPedId(), true) and not IsPedDeadOrDying(PlayerPedId()) then
		local closestPlayer = GetClosestPlayer(3)
		if closestPlayer and not IsPedInAnyVehicle(GetPlayerPed(closestPlayer), true) then
			local targetSrc = GetPlayerServerId(closestPlayer)
			if targetSrc ~= -1 then
				carry.InProgress = true
				carry.targetSrc = targetSrc
				if mtype == 'carry' then
				TriggerServerEvent("CarryPeople:sync",'carry',targetSrc)
				ensureAnimDict(carry.personCarrying.animDict)
				carry.type = "carrying"
				elseif mtype == 'piggy' and not IsPedDeadOrDying(GetPlayerPed(closestPlayer)) then
				TriggerServerEvent("CarryPeople:sync",'piggy',targetSrc)
				ensureAnimDict(carry.personPiggybacking.animDict)
				carry.type = "piggybacking"
				elseif mtype == 'hostage' and not IsPedDeadOrDying(GetPlayerPed(closestPlayer)) then
					local canTakeHostage = false
					for i=1, #carry.allowedWeapons do
						if GetCurrentPedWeapon(PlayerPedId(), carry.allowedWeapons[i], false) then
							if GetAmmoInPedWeapon(PlayerPedId(), carry.allowedWeapons[i]) > 0 then
								canTakeHostage = true 
								foundWeapon = carry.allowedWeapons[i]
								break
							end 					
						end
					end
					if canTakeHostage then
						SetCurrentPedWeapon(PlayerPedId(), foundWeapon, true)
						TriggerServerEvent("CarryPeople:sync",'hostage',targetSrc)
						ensureAnimDict(carry.agressor.animDict)
						carry.type = "agressor"					
					end
				end
			end
		end
	else
		if carry.type == "hostage" then
		
		else
			carry.InProgress = false
			carry.type = ""
			ClearPedSecondaryTask(PlayerPedId())
			DetachEntity(PlayerPedId(), true, false)
			TriggerServerEvent("CarryPeople:stop",carry.targetSrc)
			carry.targetSrc = 0
		end
	end
end

RegisterCommand("carry",function(source, args)
commander('carry')
end,false)

RegisterCommand("piggy",function(source, args)
commander('piggy')
end,false)

RegisterCommand("takehostage",function()
commander('hostage')
end)

RegisterNetEvent("CarryPeople:syncTarget")
AddEventHandler("CarryPeople:syncTarget", function(targetSrc, mtype)
	local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSrc))
	carry.InProgress = true
	if mtype == 'carry' then
	ensureAnimDict(carry.personCarried.animDict)
	AttachEntityToEntity(PlayerPedId(), targetPed, 0, carry.personCarried.attachX, carry.personCarried.attachY, carry.personCarried.attachZ, 0.5, 0.5, 180, false, false, false, false, 2, false)
	carry.type = "beingcarried"	
	elseif mtype == 'piggy' then
	ensureAnimDict(carry.personBeingPiggybacked.animDict)
	AttachEntityToEntity(PlayerPedId(), targetPed, 0, carry.personBeingPiggybacked.attachX, carry.personBeingPiggybacked.attachY, carry.personBeingPiggybacked.attachZ, 0.5, 0.5, 180, false, false, false, false, 2, false)
	carry.type = "beingPiggybacked"
	elseif mtype == 'hostage' then
	ensureAnimDict(carry.hostage.animDict)
	AttachEntityToEntity(PlayerPedId(), targetPed, 0, carry.hostage.attachX, carry.hostage.attachY, carry.hostage.attachZ, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
	carry.type = "hostage"
	end
end)

RegisterNetEvent("CarryPeople:cl_stop")
AddEventHandler("CarryPeople:cl_stop", function()
	carry.InProgress = false
	carry.type = ""
	ClearPedSecondaryTask(PlayerPedId())
	DetachEntity(PlayerPedId(), true, false)
end)

RegisterNetEvent("CarryPeople:releaseHostage")
AddEventHandler("CarryPeople:releaseHostage", function()
	carry.InProgress = false 
	carry.type = ""
	DetachEntity(PlayerPedId(), true, false)
	ensureAnimDict("reaction@shove")
	TaskPlayAnim(PlayerPedId(), "reaction@shove", "shoved_back", 8.0, -8.0, -1, 0, 0, false, false, false)
	Wait(250)
	ClearPedSecondaryTask(PlayerPedId())
end)

RegisterNetEvent("CarryPeople:killHostage")
AddEventHandler("CarryPeople:killHostage", function()
	carry.InProgress = false 
	carry.type = ""
	SetEntityHealth(PlayerPedId(),0)
	DetachEntity(PlayerPedId(), true, false)
	ensureAnimDict("anim@gangops@hostage@")
	TaskPlayAnim(PlayerPedId(), "anim@gangops@hostage@", "victim_fail", 8.0, -8.0, -1, 168, 0, false, false, false)
end)

Citizen.CreateThread(function()
	while true do
		if carry.InProgress then
			if carry.type == "beingcarried" then
				if not IsEntityPlayingAnim(PlayerPedId(), carry.personCarried.animDict, carry.personCarried.anim, 3) then
					TaskPlayAnim(PlayerPedId(), carry.personCarried.animDict, carry.personCarried.anim, 8.0, -8.0, 100000, carry.personCarried.flag, 0, false, false, false)
				end
				DisableControlAction(0,21,true) -- disable sprint
				DisableControlAction(0,24,true) -- disable attack
				DisableControlAction(0,25,true) -- disable aim
				DisableControlAction(0,47,true) -- disable weapon
				DisableControlAction(0,58,true) -- disable weapon
				DisableControlAction(0,263,true) -- disable melee
				DisableControlAction(0,264,true) -- disable melee
				DisableControlAction(0,257,true) -- disable melee
				DisableControlAction(0,140,true) -- disable melee
				DisableControlAction(0,141,true) -- disable melee
				DisableControlAction(0,142,true) -- disable melee
				DisableControlAction(0,143,true) -- disable melee
				DisableControlAction(0,23,true) -- disable enter vehicle
				DisableControlAction(0,75,true) -- disable exit vehicle
				DisableControlAction(27,75,true) -- disable exit vehicle  
				DisableControlAction(0,22,true) -- disable jump
				DisableControlAction(0,32,true) -- disable move up
				DisableControlAction(0,268,true)
				DisableControlAction(0,33,true) -- disable move down
				DisableControlAction(0,269,true)
				DisableControlAction(0,34,true) -- disable move left
				DisableControlAction(0,270,true)
				DisableControlAction(0,35,true) -- disable move right
				DisableControlAction(0,271,true)
				DisablePlayerFiring(PlayerPedId(),true)
			elseif carry.type == "carrying" then
				if not IsEntityPlayingAnim(PlayerPedId(), carry.personCarrying.animDict, carry.personCarrying.anim, 3) then
					TaskPlayAnim(PlayerPedId(), carry.personCarrying.animDict, carry.personCarrying.anim, 8.0, -8.0, 100000, carry.personCarrying.flag, 0, false, false, false)
				end
				if IsEntityDead(PlayerPedId()) then	
					carry.type = ""
					carry.InProgress = false
					ClearPedSecondaryTask(PlayerPedId())
					DetachEntity(PlayerPedId(), true, false)
					TriggerServerEvent("CarryPeople:stop",carry.targetSrc)
				end
			elseif carry.type == "beingPiggybacked" then
				if not IsEntityPlayingAnim(PlayerPedId(), carry.personBeingPiggybacked.animDict, carry.personBeingPiggybacked.anim, 3) then
					TaskPlayAnim(PlayerPedId(), carry.personBeingPiggybacked.animDict, carry.personBeingPiggybacked.anim, 8.0, -8.0, 100000, carry.personBeingPiggybacked.flag, 0, false, false, false)
				end
								DisableControlAction(0,21,true) -- disable sprint
				DisableControlAction(0,24,true) -- disable attack
				DisableControlAction(0,25,true) -- disable aim
				DisableControlAction(0,47,true) -- disable weapon
				DisableControlAction(0,58,true) -- disable weapon
				DisableControlAction(0,263,true) -- disable melee
				DisableControlAction(0,264,true) -- disable melee
				DisableControlAction(0,257,true) -- disable melee
				DisableControlAction(0,140,true) -- disable melee
				DisableControlAction(0,141,true) -- disable melee
				DisableControlAction(0,142,true) -- disable melee
				DisableControlAction(0,143,true) -- disable melee
				DisableControlAction(0,23,true) -- disable enter vehicle
				DisableControlAction(0,75,true) -- disable exit vehicle
				DisableControlAction(27,75,true) -- disable exit vehicle  
				DisableControlAction(27,75,true) -- disable exit vehicle  
				DisableControlAction(0,22,true) -- disable jump
				DisableControlAction(0,32,true) -- disable move up
				DisableControlAction(0,268,true)
				DisableControlAction(0,33,true) -- disable move down
				DisableControlAction(0,269,true)
				DisableControlAction(0,34,true) -- disable move left
				DisableControlAction(0,270,true)
				DisableControlAction(0,35,true) -- disable move right
				DisableControlAction(0,271,true)
				DisablePlayerFiring(PlayerPedId(),true)
				if IsEntityDead(PlayerPedId()) then	
					carry.type = ""
					carry.InProgress = false
					ClearPedSecondaryTask(PlayerPedId())
					DetachEntity(PlayerPedId(), true, false)
					TriggerServerEvent("CarryPeople:stop",carry.targetSrc)
				end
			elseif carry.type == "piggybacking" then
				if not IsEntityPlayingAnim(PlayerPedId(), carry.personPiggybacking.animDict, carry.personPiggybacking.anim, 3) then
					TaskPlayAnim(PlayerPedId(), carry.personPiggybacking.animDict, carry.personPiggybacking.anim, 8.0, -8.0, 100000, carry.personPiggybacking.flag, 0, false, false, false)
				end
				if IsEntityDead(PlayerPedId()) then	
					carry.type = ""
					carry.InProgress = false
					ClearPedSecondaryTask(PlayerPedId())
					DetachEntity(PlayerPedId(), true, false)
					TriggerServerEvent("CarryPeople:stop",carry.targetSrc)
				end
			elseif carry.type == "agressor" then
				if not IsEntityPlayingAnim(PlayerPedId(), carry.agressor.animDict, carry.agressor.anim, 3) then
					TaskPlayAnim(PlayerPedId(), carry.agressor.animDict, carry.agressor.anim, 8.0, -8.0, 100000, carry.agressor.flag, 0, false, false, false)
				end
				DisableControlAction(0,24,true) -- disable attack
				DisableControlAction(0,25,true) -- disable aim
				DisableControlAction(0,47,true) -- disable weapon
				DisableControlAction(0,58,true) -- disable weapon
				DisableControlAction(0,21,true) -- disable sprint
				DisableControlAction(0,263,true) -- disable meleee
				DisableControlAction(0,264,true) -- disable melee
				DisableControlAction(0,257,true) -- disable melee
				DisableControlAction(0,140,true) -- disable melee
				DisableControlAction(0,141,true) -- disable melee
				DisableControlAction(0,142,true) -- disable melee
				DisableControlAction(0,143,true) -- disable melee
				DisableControlAction(0,22,true) -- disable jump
				DisableControlAction(0,23,true) -- disable enter vehicle
				DisableControlAction(0,75,true) -- disable exit vehicle
				DisableControlAction(27,75,true) -- disable exit vehicle
				DisablePlayerFiring(PlayerPedId(),true)

				if IsEntityDead(PlayerPedId()) then	
					carry.type = ""
					carry.InProgress = false
					ensureAnimDict("reaction@shove")
					TaskPlayAnim(PlayerPedId(), "reaction@shove", "shove_var_a", 8.0, -8.0, -1, 168, 0, false, false, false)
					TriggerServerEvent("CarryPeople:releaseHostage", carry.targetSrc)
				end 

				if IsDisabledControlJustPressed(0,25) then --release	g
					carry.type = ""
					carry.InProgress = false 
					ensureAnimDict("reaction@shove")
					TaskPlayAnim(PlayerPedId(), "reaction@shove", "shove_var_a", 8.0, -8.0, -1, 168, 0, false, false, false)
					TriggerServerEvent("CarryPeople:releaseHostage", carry.targetSrc)
				elseif IsDisabledControlJustPressed(0,24) then --kill 	h		
					carry.type = ""
					carry.InProgress = false 		
					ensureAnimDict("anim@gangops@hostage@")
					TaskPlayAnim(PlayerPedId(), "anim@gangops@hostage@", "perp_fail", 8.0, -8.0, -1, 168, 0, false, false, false)
					TriggerServerEvent("CarryPeople:killHostage", carry.targetSrc)
					TriggerServerEvent("CarryPeople:stop",carry.targetSrc)
					Wait(100)
					SetPedShootsAtCoord(PlayerPedId(), 0.0, 0.0, 0.0, 0)
				end

			elseif carry.type == "hostage" then
				if not IsEntityPlayingAnim(PlayerPedId(), carry.hostage.animDict, carry.hostage.anim, 3) then
					TaskPlayAnim(PlayerPedId(), carry.hostage.animDict, carry.hostage.anim, 8.0, -8.0, 100000, carry.hostage.flag, 0, false, false, false)
				end
				DisableControlAction(0,21,true) -- disable sprint
				DisableControlAction(0,24,true) -- disable attack
				DisableControlAction(0,25,true) -- disable aim
				DisableControlAction(0,47,true) -- disable weapon
				DisableControlAction(0,58,true) -- disable weapon
				DisableControlAction(0,263,true) -- disable melee
				DisableControlAction(0,264,true) -- disable melee
				DisableControlAction(0,257,true) -- disable melee
				DisableControlAction(0,140,true) -- disable melee
				DisableControlAction(0,141,true) -- disable melee
				DisableControlAction(0,142,true) -- disable melee
				DisableControlAction(0,143,true) -- disable melee
				DisableControlAction(0,23,true) -- disable enter vehicle
				DisableControlAction(0,75,true) -- disable exit vehicle
				DisableControlAction(27,75,true) -- disable exit vehicle
				DisableControlAction(0,22,true) -- disable jump
				DisableControlAction(0,32,true) -- disable move up
				DisableControlAction(0,268,true)
				DisableControlAction(0,33,true) -- disable move down
				DisableControlAction(0,269,true)
				DisableControlAction(0,34,true) -- disable move left
				DisableControlAction(0,270,true)
				DisableControlAction(0,35,true) -- disable move right
				DisableControlAction(0,271,true)
				DisablePlayerFiring(PlayerPedId(),true)
				if IsEntityDead(PlayerPedId()) then	
					carry.type = ""
					carry.InProgress = false
					ClearPedSecondaryTask(PlayerPedId())
					DetachEntity(PlayerPedId(), true, false)
					TriggerServerEvent("CarryPeople:stop",carry.targetSrc)
				end
			end
		end
		Wait(0)
	end
end)