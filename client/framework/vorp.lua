-- Obtener el objeto VORP Core correctamente
local VORPcore = nil
local utils = require 'client.modules.utils'
local groups = { 'job', 'posse' } -- En VORP, 'job' es el trabajo y 'posse' podría ser equivalente a 'job2'
local playerGroups = {}
local playerItems = utils.getItems()
local usingVORPInventory = GetResourceState('vorp_inventory'):find('start')

-- Inicializar VORP Core correctamente
Citizen.CreateThread(function()
    TriggerEvent("getCore", function(core)
        VORPcore = core
        print("VORP Core cargado correctamente")
    end)
    
    while VORPcore == nil do
        Citizen.Wait(100)
    end
end)

local function setPlayerData(playerData)
    table.wipe(playerGroups)
    table.wipe(playerItems)

    for i = 1, #groups do
        local group = groups[i]
        local data = playerData[group]

        if data then
            playerGroups[group] = data
        end
    end

    if usingVORPInventory or not playerData.inventory then return end

    -- VORP maneja el inventario de manera diferente
    for _, v in pairs(playerData.inventory) do
        if v.count > 0 then
            playerItems[v.name] = v.count
        end
    end
end

-- Comprobar si el jugador ya está cargado
Citizen.CreateThread(function()
    Wait(1000) -- Esperar un poco más para asegurar que VORPcore esté disponible
    if VORPcore then
        -- Obtener los datos del personaje actual (cliente)
        local charJob, charGrade, charGroup
        
        -- En VORP Client, usamos eventos para obtener datos
        TriggerEvent("vorp:getCharacter", function(character)
            if character then
                charJob = character.job
                charGrade = character.jobGrade or 0
                charGroup = character.group
                
                setPlayerData({
                    job = {name = charJob, grade = charGrade},
                    posse = charGroup,
                    inventory = {}
                })
            end
        end)
    end
end)

-- Eventos para actualizar los datos del jugador
RegisterNetEvent('vorp:SelectedCharacter', function(charid)
    if source == '' then return end
    
    -- Esperar a que VORPcore esté disponible
    Citizen.CreateThread(function()
        while VORPcore == nil do
            Citizen.Wait(100)
        end
        
        -- Obtener los datos del personaje seleccionado
        TriggerEvent("vorp:getCharacter", function(character)
            if character then
                setPlayerData({
                    job = {name = character.job, grade = character.jobGrade or 0},
                    posse = character.group,
                    inventory = {}
                })
            end
        end)
    end)
end)

RegisterNetEvent('vorp:setJob', function(job, grade)
    if source == '' then return end
    playerGroups.job = {name = job, grade = grade or 0}
end)

-- Si VORP tiene un sistema para manejar 'posse' o algo similar a job2
RegisterNetEvent('vorp:setGroup', function(group)
    if source == '' then return end
    playerGroups.posse = group
end)

-- Eventos para el inventario
RegisterNetEvent('vorp:addItem', function(name, count)
    playerItems[name] = (playerItems[name] or 0) + count
end)

RegisterNetEvent('vorp:removeItem', function(name, count)
    if playerItems[name] then
        playerItems[name] = math.max(0, playerItems[name] - count)
    end
end)

function utils.hasPlayerGotGroup(filter)
    local _type = type(filter)
    for i = 1, #groups do
        local group = groups[i]

        if _type == 'string' then
            local data = playerGroups[group]

            if data and data.name and filter == data.name then
                return true
            end
        elseif _type == 'table' then
            local tabletype = table.type(filter)

            if tabletype == 'hash' then
                for name, grade in pairs(filter) do
                    local data = playerGroups[group]

                    if data and data.name and data.name == name and grade <= (data.grade or 0) then
                        return true
                    end
                end
            elseif tabletype == 'array' then
                for j = 1, #filter do
                    local name = filter[j]
                    local data = playerGroups[group]

                    if data and data.name and data.name == name then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Función para comprobar si el jugador tiene un item específico
function utils.hasPlayerGotItem(itemName, count)
    count = count or 1
    if usingVORPInventory then
        -- Usar la API de VORP Inventory para verificar items
        local itemCount = exports.vorp_inventory:getItemCount(itemName)
        return itemCount >= count
    else
        -- Usar nuestra propia caché de items
        return (playerItems[itemName] or 0) >= count
    end
end