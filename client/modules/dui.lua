local store = require 'client.modules.store'
local config = require 'client.modules.config'

local dui = {}
dui.loaded = false
dui.visible = false
local controlsRunning = false

-- Inicializar la NUI
function dui.register()
    -- No necesitamos crear un DUI físico
    -- Simplemente mostramos la NUI cuando sea necesario
    SendNUIMessage({
        action = 'init',
        resource = GetCurrentResourceName()
    })
    
    -- Ocultar la NUI al principio
    dui.sendMessage('visible', false)
    
    -- Esperar a que la NUI esté cargada
    CreateThread(function()
        while not dui.loaded do 
            Wait(100) 
        end
        print("NUI cargada correctamente")
        dui.sendMessage('setColor', config.themeColor)
    end)
end

-- Registrar la NUI automáticamente al inicio
Citizen.CreateThread(function()
    Wait(1000) -- Aumentamos la espera para asegurar que el cliente esté listo
    dui.register()
end)

-- Enviar mensajes a la NUI
function dui.sendMessage(action, value)
    SendNUIMessage({
        action = action,
        value = value
    })

    -- Si estamos estableciendo opciones y los controles no se están ejecutando
    if action == 'setOptions' and not controlsRunning then
        controlsRunning = true
        
        -- Si estamos mostrando opciones, hacer visible la NUI
        if value and value.options and next(value.options) then
            dui.visible = true
            -- Hacer la UI visible
            dui.sendMessage('visible', true)
            -- Activar el botón de interacción
            if _G.ActivarBoton then
                _G.ActivarBoton("sleepless_interact_btn")
            end
        end

        CreateThread(function()
            while next(store.current) do
                dui.handleControls()
                Wait(0)
            end

            -- Cuando no hay opciones, ocultar la interfaz
            if dui.visible then
                dui.visible = false
                dui.sendMessage('visible', false)
                -- Desactivar el botón de interacción
                if _G.DesactivarBoton then
                    _G.DesactivarBoton("sleepless_interact_btn")
                end
            end

            controlsRunning = false
        end)
    end

    -- Si estamos cambiando la visibilidad
    if action == 'visible' then
        dui.visible = value
        
        -- Si estamos activando/desactivando la visibilidad manualmente
        if value then
            -- Activar el botón cuando la UI se hace visible
            if _G.ActivarBoton then
                _G.ActivarBoton("sleepless_interact_btn")
            end
        else
            -- Desactivar el botón cuando la UI se oculta
            if _G.DesactivarBoton then
                _G.DesactivarBoton("sleepless_interact_btn")
            end
        end
    end
end

-- Manejar los controles de navegación
dui.handleControls = function()
    local input = false

    if (IsControlJustPressed(0, 180)) then -- SCROLL DOWN
        SendNUIMessage({
            action = 'scroll',
            direction = 'down'
        })
        input = true
    end

    if (IsControlJustPressed(0, 181)) then -- SCROLL UP
        SendNUIMessage({
            action = 'scroll',
            direction = 'up'
        })
        input = true
    end

    if (IsControlJustPressed(0, 0x05CA7C52)) then -- ARROW DOWN
        SendNUIMessage({
            action = 'scroll',
            direction = 'down'
        })
        input = true
    end

    if (IsControlJustPressed(0, 0x6319DB71)) then -- ARROW UP
        SendNUIMessage({
            action = 'scroll',
            direction = 'up'
        })
        input = true
    end

    if input then
        Wait(200)
    end
end

-- Callback para cuando la NUI se ha cargado
RegisterNUICallback('load', function(_, cb)
    print("NUI cargada desde callback")
    dui.loaded = true
    Wait(500)
    cb(1)
end)

-- Callback para cuando el usuario cambia la opción actual
RegisterNUICallback('currentOption', function(data, cb)
    store.current.index = data[1]
    cb(1)
end)

return dui
