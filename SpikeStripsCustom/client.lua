--***************************************************************
--*                                                           *--
--*                SpikeStripsCustom by MajorFivePD          *--
--*                                                           *--
--***************************************************************


local SpikeStrips = {}
local PlayerPed = nil
local nearbyVehicleThreshold = 2.0


local function CreateSpikeStrip(position, heading)
    local obj = CreateObject(GetHashKey("p_ld_stinger_s"), position.x, position.y, position.z, true, true, true)
    SetEntityHeading(obj, heading)
    return obj
end


local function DeleteSpikeStrip(obj)
    if DoesEntityExist(obj) then
        DeleteEntity(obj)
    end
end


local function PlayKneelAnim(duration)
    local playerPed = PlayerPedId()
    if DoesEntityExist(playerPed) then
        if IsPedArmed(playerPed, 7) then
            SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true)
        end
        RequestAnimDict("amb@medic@standing@kneel@idle_a")
        while not HasAnimDictLoaded("amb@medic@standing@kneel@idle_a") do
            Citizen.Wait(100)
        end
        TaskPlayAnim(playerPed, "amb@medic@standing@kneel@idle_a", "idle_a", 1.0, 1.0, duration, 0, 0, false, false, false)
    end
end

local function PlayDeploySound()
    PlaySoundFrontend(-1, "Collect_Pickup", "DLC_IE_PL_Player_Sounds", .0)
end


local function DeploySpikeStrips(spikesToSpawn)
    local playerPed = PlayerPedId() 

    if not playerPed then
        return
    end

    local playerPos = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)

    PlayKneelAnim(spikesToSpawn * 2000)

    for i = 1, spikesToSpawn do
        local forwardVector = GetEntityForwardVector(playerPed)
        local spawnOffset = forwardVector * (i * 3.7) + vector3(0.0, 0.0, -1.0)
        local spikeStrip = CreateSpikeStrip(playerPos + spawnOffset, playerHeading)
        table.insert(SpikeStrips, spikeStrip)
    end

    PlayDeploySound()

    Citizen.Wait(500)

    local function ShowNotification(text)
        SetNotificationTextEntry("STRING")
        AddTextComponentString(text)
        DrawNotification(false, false)
    end

    ShowNotification("~g~Deployed " .. spikesToSpawn .. " spike strip!")
end


local function RemoveSpikeStrips()
    for _, spikeStrip in ipairs(SpikeStrips) do
        DeleteSpikeStrip(spikeStrip)
    end
    SpikeStrips = {}

   
    local function ShowNotification(text)
        SetNotificationTextEntry("STRING")
        AddTextComponentString(text)
        DrawNotification(false, false)
    end

    ShowNotification("~r~Removed all spike strips!")
end


local function CanDeploySpikeStrips()
  
    return true
end


local function CanRemoveSpikeStrips()
  
    return true
end

local function BurstNearbyVehicleTires(spikeStrip)
    if not spikeStrip or not DoesEntityExist(spikeStrip) then
        return
    end

    local spikePos = GetEntityCoords(spikeStrip)
    local vehicles = GetGamePool("CVehicle")

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if IsEntityAVehicle(vehicle) then
            local driver = GetPedInVehicleSeat(vehicle, -1)
            if driver and not NetworkGetPlayerIndexFromPed(driver) then
                if IsVehicleWheelTouchingSpikeStrip(vehicle, spikeStrip) then
                    BurstAllTires(vehicle)
                end
            end
        end
    end
end


local function IsVehicleWheelTouchingSpikeStrip(vehicle, spikeStrip)
    if not DoesEntityExist(vehicle) or not DoesEntityExist(spikeStrip) then
        return false
    end

    local spikePos = GetEntityCoords(spikeStrip)
    local vehiclePos = GetEntityCoords(vehicle)
    local distance = Vdist2(vehiclePos.x, vehiclePos.y, vehiclePos.z, spikePos.x, spikePos.y, spikePos.z)

   
    local distanceThreshold = 3.0

    return distance < distanceThreshold * distanceThreshold
end


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        for i = #SpikeStrips, 1, -1 do
            local spikeStrip = SpikeStrips[i]
            if DoesEntityExist(spikeStrip) then
                BurstNearbyVehicleTires(spikeStrip)
            else
                table.remove(SpikeStrips, i)
            end
        end
    end
end)

local function BurstAllTires(vehicle)
    if not DoesEntityExist(vehicle) then
        return
    end

    local tires = {
        {bone = "wheel_lf", index = 0},
        {bone = "wheel_rf", index = 1},
        {bone = "wheel_lm", index = 2},
        {bone = "wheel_rm", index = 3},
        {bone = "wheel_lr", index = 4},
        {bone = "wheel_rr", index = 5},
    }

    for _, tire in ipairs(tires) do
        local boneIndex = GetEntityBoneIndexByName(vehicle, tire.bone)
        if boneIndex and DoesEntityExist(vehicle) and not IsEntityDead(vehicle) then
            BurstTyre(vehicle, boneIndex)
        end
    end
end


local function BurstTyre(vehicle, wheelIndex)
    SetVehicleTyreBurst(vehicle, wheelIndex, false, 940.0)
end


local function GetClosestVehicleToPos(position, radius)
    local vehicles = GetGamePool("CVehicle")
    local closestDistance = -1
    local closestVehicle = nil

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local distance = #(position - GetEntityCoords(vehicle))
        if closestDistance == -1 or distance < closestDistance then
            closestDistance = distance
            closestVehicle = vehicle
        end
    end

    if closestDistance <= radius then
        return closestVehicle
    end

    return nil
end


local function IsVehicleWheelTouchingSpikeStrip(vehicle, spikeStrip)
    local spikePos = GetEntityCoords(spikeStrip)
    local spikeForward = GetEntityForwardVector(spikeStrip)
    local vehiclePos = GetEntityCoords(vehicle)

    local rayHandle = StartShapeTestRay(vehiclePos.x, vehiclePos.y, vehiclePos.z, spikePos.x, spikePos.y, spikePos.z, 10, vehicle, 7)
    local _, hit, endCoords, _, _ = GetShapeTestResult(rayHandle)

    if hit then
        local distance = #(vehiclePos - endCoords)
        
        local threshold = 1.0
        return distance <= threshold
    end

    return false
end


local function BurstAllTires(vehicle)
    if not DoesEntityExist(vehicle) then
        return
    end

    local tires = {
        {bone = "wheel_lf", index = 0},
        {bone = "wheel_rf", index = 1},
        {bone = "wheel_lm", index = 2},
        {bone = "wheel_rm", index = 3},
        {bone = "wheel_lr", index = 4},
        {bone = "wheel_rr", index = 5},
    }

    for _, tire in ipairs(tires) do
        local boneIndex = GetEntityBoneIndexByName(vehicle, tire.bone)
        if boneIndex and DoesEntityExist(vehicle) and not IsEntityDead(vehicle) then
            SetVehicleTyreBurst(vehicle, tire.index, true, 1000.0)
        end
    end
end


local function BurstNearbyVehicleTires(spikeStrip)
    if not spikeStrip or not DoesEntityExist(spikeStrip) then
        return
    end

    local spikePos = GetEntityCoords(spikeStrip)
    local vehicles = GetGamePool("CVehicle")

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if #(spikePos - GetEntityCoords(vehicle)) < 2.0 then 
            BurstAllTires(vehicle)
        end
    end
end


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        for i = #SpikeStrips, 1, -1 do
            local spikeStrip = SpikeStrips[i]
            if DoesEntityExist(spikeStrip) then
                BurstNearbyVehicleTires(spikeStrip)
            else
                table.remove(SpikeStrips, i)
            end
        end
    end
end)


AddEventHandler("playerSpawned", function()
    RequestModel("p_ld_stinger_s")
    while not HasModelLoaded("p_ld_stinger_s") do
        Citizen.Wait(0)
    end

    PlayerPed = PlayerPedId()
end)



Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
       
        if IsControlPressed(0, 51) then
            if IsControlJustPressed(0, 158) and CanDeploySpikeStrips() then
                DeploySpikeStrips(2)
            elseif IsControlJustPressed(0, 157) and CanDeploySpikeStrips() then
                DeploySpikeStrips(1)
            elseif IsControlJustPressed(0, 160) and CanRemoveSpikeStrips() then
                RemoveSpikeStrips()
            end
        end

       
    end
end)


local SpikeStrip = {}
SpikeStrip.__index = SpikeStrip


function SpikeStrip.Create(position, heading)
    local self = setmetatable({}, SpikeStrip)
    self.Prop = CreateSpikeStrip(position, heading)
    return self
end


function SpikeStrip:Delete()
    DeleteSpikeStrip(self.Prop)
end
