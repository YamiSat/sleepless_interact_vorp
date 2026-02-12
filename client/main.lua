local dui = require 'client.modules.dui'
local store = require 'client.modules.store'
local config = require 'client.modules.config'
local utils = require 'client.modules.utils'

-- Sistema de gestión de botones interactivos
local keymapRegistry = {}

function CrearBotonInteractivo(nombre, tecla, onDown, onUp, puedeDesactivarse)
    if keymapRegistry[nombre] then
        print("Ya existe un botón con ese nombre:", nombre)
        return
    end

    RegisterRawKeymap(nombre, onUp, onDown, tecla, puedeDesactivarse or true)

    keymapRegistry[nombre] = {
        nombre = nombre,
        tecla = tecla,
        activo = true,
        puedeDesactivarse = puedeDesactivarse ~= false
    }

    print("Botón registrado:", nombre)
end

function ActivarBoton(nombre)
    if keymapRegistry[nombre] then
        keymapRegistry[nombre].activo = true
     --   print("Botón activado:", nombre)
    end
end

function DesactivarBoton(nombre)
    if keymapRegistry[nombre] and keymapRegistry[nombre].puedeDesactivarse then
        DisableRawKeyThisFrame(keymapRegistry[nombre].tecla)
        keymapRegistry[nombre].activo = false
      --  print("Botón desactivado:", nombre)
    end
end

---@type boolean
local drawLoopRunning = false

local GetEntityCoords = GetEntityCoords
local DrawSprite = DrawSprite
local SetDrawOrigin = SetDrawOrigin
local getNearbyObjects = lib.getNearbyObjects
local getNearbyPlayers = lib.getNearbyPlayers
local getNearbyVehicles = lib.getNearbyVehicles
local getNearbyPeds = lib.getNearbyPeds
local GetOffsetFromEntityInWorldCoords = GetOffsetFromEntityInWorldCoords
local GetEntityBoneIndexByName = GetEntityBoneIndexByName
local GetEntityBonePosition_2 = GetEntityBonePosition_2
local GetModelDimensions = GetModelDimensions
local NetworkGetEntityIsNetworked = NetworkGetEntityIsNetworked
local NetworkGetNetworkIdFromEntity = NetworkGetNetworkIdFromEntity
local GetEntityModel = GetEntityModel

local r, g, b, a = table.unpack(config.themeColor)



-- Función para ejecutar la interacción seleccionada
function ExecuteInteraction()
    local currentTime = GetGameTimer()
    if store.current.options and currentTime > (store.cooldownEndTime or 0) then
        -- Usar el índice seleccionado por el jugador
        local category = next(store.current.options)
        if category and store.current.options[category] and #store.current.options[category] > 0 then
            local idx = store.current.index or 1
            local option = store.current.options[category][idx]
            if option then
                if option.onSelect then
                    option.onSelect(option.qtarget and store.current.entity or utils.getResponse(option))
                elseif option.export then
                    exports[option.resource][option.export](nil, utils.getResponse(option))
                elseif option.event then
                    TriggerEvent(option.event, utils.getResponse(option))
                elseif option.serverEvent then
                    TriggerServerEvent(option.serverEvent, utils.getResponse(option, true))
                elseif option.command then
                    ExecuteCommand(option.command)
                end
                local cooldown = option.cooldown or 1500
                store.cooldownEndTime = currentTime + cooldown
                if cooldown > 0 then
                    dui.sendMessage('setCooldown', true)
                    Citizen.Wait(cooldown)
                    dui.sendMessage('setCooldown', false)
                end
            end
        end
    end
end

local hidePerKeybind = config.showKeyBindBehavior == "hold"

local modelCache, netIdCache = {}, {}

local function cachedEntityInfo(entity)
    if modelCache[entity] then
        return modelCache[entity], netIdCache[entity]
    end

    local model = GetEntityModel(entity)
    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or nil
    modelCache[entity] = model
    netIdCache[entity] = netId
    return model, netId
end

---@param options InteractOption[]
---@param entity number
---@param distance number
---@param coords vector3
---@return nil | table<string, InteractOption[]>, number | nil, boolean | nil
local function filterValidOptions(options, entity, distance, coords)
    if not options then return nil end
    local validOptions = {}
    local totalValid = 0
    local hasGlobal = options['global'] ~= nil
    local hasNonGlobal = false

    for category, _options in pairs(options) do
        if category ~= 'global' then
            hasNonGlobal = true
        end

        local validCategoryOptions = {}

        for i = 1, #_options do
            local option = _options[i]
            local hide = false

            if not hide and not option.allowInVehicle and cache.vehicle then
                hide = true
            end

            if not hide then hide = distance > (option.distance or 2.0) end

            if not hide and option.groups then hide = not utils.hasPlayerGotGroup(option.groups) end

            if not hide and option.items then hide = not utils.hasPlayerGotItems(option.items, option.anyItem) end

            if not hide and option.canInteract then
                local success, resp = pcall(option.canInteract, entity, distance, coords, option.name)
                hide = not success or not resp
            end

            if not hide then
                validCategoryOptions[#validCategoryOptions + 1] = option
                totalValid = totalValid + 1
            end
        end

        if #validCategoryOptions > 0 then
            validOptions[category] = validCategoryOptions
        end
    end

    local hideCompletely = hasGlobal and not hasNonGlobal and totalValid == 0

    if totalValid == 0 then
        return nil, nil, hideCompletely
    end

    return validOptions, totalValid, hideCompletely
end

---@param entity number
---@param globalType string
---@return InteractOption[] | nil
local function getOptionsForEntity(entity, globalType)
    if not entity then return nil end

    if IsPedAPlayer(entity) then
        return {
            global = store.players,
        }
    end

    local model, netId = cachedEntityInfo(entity)

    local options = {
        global = (store[globalType] ~= nil and #store[globalType] > 0 and store[globalType]) or nil,
        model = (store.models[model] ~= nil and #store.models[model] > 0 and store.models[model]) or nil,
        entity = (netId and store.entities[netId] ~= nil and #store.entities[netId] > 0 and store.entities[netId]) or nil,
        localEntity = (store.localEntities[entity] ~= nil and #store.localEntities[entity] > 0 and store.localEntities[entity]) or nil,
    }

    return next(options) and options or nil
end

---@param entity number
---@param globalType string
---@return table<string, InteractOption[]> | nil
local function getBoneOptionsForEntity(entity, globalType)
    if not entity then return nil end
    local model, netId = cachedEntityInfo(entity)
    local boneOptions = {}
    local hasOptions = false

    if store.bones[globalType] then
        for boneId, options in pairs(store.bones[globalType]) do
            if #options > 0 then
                boneOptions[boneId] = boneOptions[boneId] or {}
                boneOptions[boneId].global = options
                hasOptions = true
            end
        end
    end

    if store.bones.models and store.bones.models[model] then
        for boneId, options in pairs(store.bones.models[model]) do
            if #options > 0 then
                boneOptions[boneId] = boneOptions[boneId] or {}
                boneOptions[boneId].model = options
                hasOptions = true
            end
        end
    end

    if netId and store.bones.entities and store.bones.entities[netId] then
        for boneId, options in pairs(store.bones.entities[netId]) do
            if #options > 0 then
                boneOptions[boneId] = boneOptions[boneId] or {}
                boneOptions[boneId].entity = options
                hasOptions = true
            end
        end
    end

    if not netId and store.bones.localEntities and store.bones.localEntities[entity] then
        for boneId, options in pairs(store.bones.localEntities[entity]) do
            if #options > 0 then
                boneOptions[boneId] = boneOptions[boneId] or {}
                boneOptions[boneId].localEntity = options
                hasOptions = true
            end
        end
    end

    return hasOptions and boneOptions or nil
end

---@param entity number
---@param globalType string
---@return table<string, InteractOption[]> | nil
local function getOffsetOptionsForEntity(entity, globalType)
    if not entity then return nil end
    local model, netId = cachedEntityInfo(entity)
    local offsetOptions = {}
    local hasOptions = false

    if store.offsets[globalType] then
        for offsetStr, options in pairs(store.offsets[globalType]) do
            if #options > 0 then
                offsetOptions[offsetStr] = offsetOptions[offsetStr] or {}
                offsetOptions[offsetStr].global = options
                hasOptions = true
            end
        end
    end

    if store.offsets.models and store.offsets.models[model] then
        for offsetStr, options in pairs(store.offsets.models[model]) do
            if #options > 0 then
                offsetOptions[offsetStr] = offsetOptions[offsetStr] or {}
                offsetOptions[offsetStr].model = options
                hasOptions = true
            end
        end
    end

    if netId and store.offsets.entities and store.offsets.entities[netId] then
        for offsetStr, options in pairs(store.offsets.entities[netId]) do
            if #options > 0 then
                offsetOptions[offsetStr] = offsetOptions[offsetStr] or {}
                offsetOptions[offsetStr].entity = options
                hasOptions = true
            end
        end
    end

    if not netId and store.offsets.localEntities and store.offsets.localEntities[entity] then
        for offsetStr, options in pairs(store.offsets.localEntities[entity]) do
            if #options > 0 then
                offsetOptions[offsetStr] = offsetOptions[offsetStr] or {}
                offsetOptions[offsetStr].localEntity = options
                hasOptions = true
            end
        end
    end

    return hasOptions and offsetOptions or nil
end

---@param coords vector3
---@return NearbyItem[]
local function checkNearbyEntities(coords)
    local valid = {}
    local num = 0

    local function processEntities(entities, globalType)
        for i = 1, #entities do
            local ent = entities[i]
            local entity = ent.object or ent.vehicle or ent.ped
            local model = cachedEntityInfo(entity)
            local entCoords = GetEntityCoords(entity)
            local options = getOptionsForEntity(entity, globalType)
            local boneOptions = getBoneOptionsForEntity(entity, globalType)
            local offsetOptions = getOffsetOptionsForEntity(entity, globalType)


            if options then
                num = num + 1
                valid[num] = {
                    entity = entity,
                    coords = entCoords,
                    currentDistance = #(coords - entCoords),
                    currentScreenDistance = utils.getScreenDistanceSquared(entCoords),
                    options = options
                }
            end

            if boneOptions then
                for boneId, _options in pairs(boneOptions) do
                    local boneIndex = GetEntityBoneIndexByName(entity, boneId)
                    if boneIndex ~= -1 then
                        local boneCoords = GetEntityBonePosition_2(entity, boneIndex)
                        num = num + 1
                        valid[num] = {
                            entity = entity,
                            bone = boneId,
                            coords = boneCoords,
                            currentDistance = #(coords - boneCoords),
                            currentScreenDistance = utils.getScreenDistanceSquared(boneCoords),
                            options = _options
                        }
                    end
                end
            end

            if offsetOptions then
                for offsetStr, _options in pairs(offsetOptions) do
                    local x, y, z, offsetType = utils.getCoordsAndTypeFromOffsetId(offsetStr)
                    if x and y and z and offsetType then
                        local offset = vec3(tonumber(x), tonumber(y), tonumber(z))
                        local worldPos
                        if offsetType == "offset" then
                            local min, max = GetModelDimensions(model)
                            offset = (max - min) * offset + min
                        end
                        worldPos = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
                        num = num + 1
                        valid[num] = {
                            entity = entity,
                            offset = offsetStr,
                            coords = worldPos,
                            currentDistance = #(coords - worldPos),
                            currentScreenDistance = utils.getScreenDistanceSquared(worldPos),
                            options = _options
                        }
                    end
                end
            end
        end
    end

    processEntities(getNearbyObjects(coords, 4.0), 'objects')
    processEntities(getNearbyVehicles(coords, 4.0), 'vehicles')
    processEntities(getNearbyPlayers(coords, 4.0, false), 'players')
    processEntities(getNearbyPeds(coords, 4.0), 'peds')

    return valid
end

---@param coords vector3
---@param update NearbyItem[]
---@return NearbyItem[]
local function checkNearbyCoords(coords, update)
    for id, _coords in pairs(store.coordIds) do
        local dist = #(coords - _coords)
        if dist < config.maxInteractDistance then
            update[#update + 1] = {
                coords = _coords,
                currentDistance = dist,
                currentScreenDistance = utils.getScreenDistanceSquared(_coords),
                coordId = id,
                options = { coords = store.coords[id] }
            }
        end
    end
    return update
end


local function shouldHideInteract()
    if IsNuiFocused() or LocalPlayer.state.hideInteract or (lib and lib.progressActive()) or hidePerKeybind or LocalPlayer.state.invOpen then
        return true
    end
    return false
end

local activeOptions = {}

local aspectRatio = GetAspectRatio(true)

local function drawLoop()
    if drawLoopRunning then return end
    drawLoopRunning = true


    local lastClosestItem, lastValidCount, lastValidOptions = nil, 0, nil
    local nearbyData = {}
    local playerCoords

    local entityStartCoords = {}
    local movingEntity = {}

    CreateThread(function()
        while drawLoopRunning do
            if shouldHideInteract() then
                table.wipe(store.nearby)
                break
            end

            playerCoords = GetEntityCoords(cache.ped)
            nearbyData = {}
            for i = 1, #store.nearby do
                local item = store.nearby[i]

                local coords = utils.getDrawCoordsForInteract(item)

                if coords then
                    if item.entity then
                        if not entityStartCoords[item.entity] then
                            entityStartCoords[item.entity] = coords
                        end

                        if coords ~= entityStartCoords then
                            movingEntity[item.entity] = true
                        end
                    end

                    local distance = #(playerCoords - coords)
                    local validOpts, validCount, hideCompletely = filterValidOptions(item.options, item.entity, distance, coords)
                    local id = item.bone or item.offset or item.entity or item.coordId
                    local shouldUpdate = false

                    if id == lastClosestItem then
                        if lastValidOptions then
                            shouldUpdate = not lib.table.matches(validOpts, lastValidOptions)
                        end
                    end

                    nearbyData[i] = {
                        item = item,
                        coords = coords,
                        shouldUpdate = shouldUpdate,
                        hideCompletely = hideCompletely,
                        distance = distance,
                        validOpts = validOpts,
                        validCount = validCount
                    }
                    
                end
            end
            Wait(550)
        end
    end)

      local dict = 'menu_textures'

    -- if not HasStreamedTextureDictLoaded(dict) then
    --     RequestStreamedTextureDict(dict)

    --     local timeout = GetGameTimer() + 10000 -- 10 segundos de espera
    --     while not HasStreamedTextureDictLoaded(dict) and GetGameTimer() < timeout do
    --         Wait(0)
    --     end
    -- end  
    while #store.nearby > 0 do
        Wait(0)
        local foundValid = false

        for i = 1, #store.nearby do
            local data = nearbyData[i]

            if data and data.coords and not data.hideCompletely then
                local item = data.item
                local coords = (item.entity and not movingEntity[item.entity] and data.coords) or utils.getDrawCoordsForInteract(item)

                SetDrawOrigin(coords.x, coords.y, coords.z)

                if not foundValid and data.validOpts and data.validCount > 0 then
                    foundValid = true

                    -- Dibujar un indicador visual para mostrar que se puede interactuar
                   -- DrawSprite(dict, "cross", 0.0, 0.0, 0.05, 0.05, 0.0, r, g, b, 255)
                    
                    local newClosestId = item.bone or item.offset or item.entity or item.coordId
                    if data.shouldUpdate or lastClosestItem ~= newClosestId or lastValidCount ~= data.validCount then
                        local newOptions = {}

                        if data.validOpts then
                            for _, opts in pairs(data.validOpts) do
                                for j = 1, #opts do
                                    local opt = opts[j]
                                    newOptions[opt] = true
                                    if not activeOptions[opt] then
                                        activeOptions[opt] = true
                                        local resp = (opt.onActive or opt.whileActive) and utils.getResponse(opt)

                                        if opt.onActive then
                                            pcall(opt.onActive, resp)
                                        end

                                        if opt.whileActive then
                                            CreateThread(function()
                                                while activeOptions[opt] do
                                                    pcall(opt.whileActive, resp)
                                                    Wait(0)
                                                end
                                            end)
                                        end
                                    end
                                end
                            end
                        end

                        if lastValidOptions then
                            for _, opts in pairs(lastValidOptions) do
                                for j = 1, #opts do
                                    local opt = opts[j]

                                    if opt.onInactive and not newOptions[opt] and activeOptions[opt] then
                                        pcall(opt.onInactive, utils.getResponse(opt))
                                        activeOptions[opt] = nil
                                    end
                                end
                            end
                        end

                        local resetIndex = lastClosestItem ~= newClosestId
                        lastClosestItem = newClosestId
                        lastValidCount = data.validCount
                        lastValidOptions = data.validOpts

                        store.current = {
                            options = data.validOpts,
                            entity = item.entity,
                            distance = data.distance,
                            coords = coords,
                            index = 1,
                        }
                        dui.sendMessage('setOptions', { options = data.validOpts, resetIndex = resetIndex })
                    end
                else


                -- if not HasStreamedTextureDictLoaded(config.IndicatorSprite.dict) then
                --     RequestStreamedTextureDict(config.IndicatorSprite.dict)

                --     local timeout = GetGameTimer() + 10000 -- 10 segundos de espera
                --     while not HasStreamedTextureDictLoaded(config.IndicatorSprite.dict) and GetGameTimer() < timeout do
                --         Wait(0)
                --     end
                -- end  

                    local distance = #(playerCoords - coords)
                    if distance < config.maxInteractDistance and item.currentScreenDistance < math.huge then
                        local distanceRatio = math.min(0.5 + (0.25 * (distance / 10.0)), 1.0)
                        local scale = 0.025 * distanceRatio
                    --    DrawSprite(dict, config.IndicatorSprite.txt, 0.0, 0.0, scale, scale * aspectRatio, 0.0, r, g, b, a)
                    end
                end

                ClearDrawOrigin()
            end
        end

        if not foundValid and next(store.current) then
            for _, opts in pairs(store.current.options) do
                for j = 1, #opts do
                    local opt = opts[j]

                    if opt.onInactive and activeOptions[opt] then
                        pcall(opt.onInactive, utils.getResponse(opt))
                        activeOptions[opt] = nil
                    end
                end
            end
            store.current = {}
            lastClosestItem = nil
            dui.sendMessage('setOptions', { options = {} })
        end
    end

    drawLoopRunning = false
end

local function BuilderLoop()
    while true do
        if shouldHideInteract() then
            table.wipe(store.nearby)
        else
            local coords = GetEntityCoords(cache.ped)
            local update = checkNearbyEntities(coords)
            update = checkNearbyCoords(coords, update)

            store.nearby = update

            table.sort(store.nearby, function(a, b)
                return a.currentScreenDistance < b.currentScreenDistance
            end)

            if #store.nearby > 0 and not drawLoopRunning then
                CreateThread(drawLoop)
            end
        end
        Wait(1000)
    end
end

RegisterNUICallback('select', function(data, cb)
    local currentTime = GetGameTimer()
    if store.current.options and currentTime > (store.cooldownEndTime or 0) then
        local option = store.current.options?[data[1]]?[data[2]]
        if option then
            if option.onSelect then
                option.onSelect(option.qtarget and store.current.entity or utils.getResponse(option))
            elseif option.export then
                exports[option.resource][option.export](nil, utils.getResponse(option))
            elseif option.event then
                TriggerEvent(option.event, utils.getResponse(option))
            elseif option.serverEvent then
                TriggerServerEvent(option.serverEvent, utils.getResponse(option, true))
            elseif option.command then
                ExecuteCommand(option.command)
            end
            local cooldown = option.cooldown or 1500
            store.cooldownEndTime = currentTime + cooldown
            if cooldown > 0 then
                dui.sendMessage('setCooldown', true)
                Wait(cooldown)
                dui.sendMessage('setCooldown', false)
            end
        end
    end
    cb(1)
end)

CreateThread(BuilderLoop)

-- Ejemplo de cómo agregar un punto de interacción
-- CreateThread(function()
--     local id = exports.sleepless_interact:addCoords(vector3(-320.5790, 760.0184, 117.4863), {
--         label = "Interact Here",
--         icon = "hand",
--         distance = 2.0,
--         onSelect = function(data) 
--             print("¡Acción activada al presionar E!") 
--             -- Aquí puedes poner cualquier código que quieras ejecutar cuando se presiona E
--         end,
--         canInteract = function(entity, distance, coords, name)
--             return distance < 2.0
--         end
--     })
-- end)


-- Configuración para la tecla G
local KEY_G = 71 -- Código de tecla G para RedM
local lastKeyPressTime = 0
local KEY_COOLDOWN = 500 -- Milisegundos para evitar activaciones repetidas

-- Registrar el botón interactivo para la interacción
CrearBotonInteractivo("sleepless_interact_btn", KEY_G,
    function() -- onDown
        if next(store.current) and not shouldHideInteract() then
            local currentTime = GetGameTimer()
            
            -- Evitar activaciones repetidas con un pequeño cooldown
            if currentTime - lastKeyPressTime > KEY_COOLDOWN then
                lastKeyPressTime = currentTime
                ExecuteInteraction()
            end
        end
    end,
    function() -- onUp
        -- No necesitamos hacer nada al soltar la tecla
    end,
    false -- No puede ser desactivado por el sistema
)

RegisterNUICallback('selectedIndex', function(data, cb)
    local selected = data[1]
    print('Índice seleccionado desde frontend:', selected)
    -- Aquí puedes usar el índice como necesites
    cb(1)
end)