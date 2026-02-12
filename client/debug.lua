-- Archivo de debug para verificar el funcionamiento de la UI NUI
local dui = require 'client.modules.dui'

-- Crear un comando para verificar manualmente la UI
RegisterCommand('testui', function()
    -- Mostrar la UI
    dui.sendMessage('visible', true)
    
    -- Simular opciones de interacción
    dui.sendMessage('setOptions', {
        options = {
            global = {
                { label = "Opción de prueba 1", icon = "fa-solid fa-check", name = "test1" },
                { label = "Opción de prueba 2", icon = "fa-solid fa-times", name = "test2" }
            }
        },
        resetIndex = true
    })
    
    -- Ocultar la UI después de 5 segundos
    Citizen.SetTimeout(15000, function()
        dui.sendMessage('visible', false)
    end)
    
    print("Probando UI - debería verse durante 5 segundos")
end, false)

print("Módulo de debug cargado - Usa el comando /testui para probar la UI")
