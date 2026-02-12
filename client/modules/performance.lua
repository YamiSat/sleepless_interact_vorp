-- Módulo de rendimiento y optimización
local performance = {}

-- Configuración de rendimiento
performance.settings = {
    -- Caché de entidades
    entityCacheDuration = 5000, -- 5 segundos antes de limpiar entidades no usadas
    
    -- Intervalos de actualización (ms)
    updateIntervals = {
        normal = 1000,  -- Intervalo estándar
        active = 500,   -- Cuando hay interacciones activas cerca
        idle = 2000     -- Cuando no hay nada cerca o el jugador está inactivo
    },
    
    -- Configuración de renderizado
    rendering = {
        skipFrames = 1,           -- Número de frames para saltar entre actualizaciones de UI
        maxVisibleItems = 10,     -- Máximo número de ítems a mostrar por frame
        distanceCheckInterval = 150  -- Intervalo para comprobar distancias (ms)
    },
    
    -- Distancias de detección
    detectionDistances = {
        objects = 3.5,     -- Reducido de 4.0
        vehicles = 4.0,
        players = 3.5,     -- Reducido de 4.0
        peds = 3.0         -- Reducido de 4.0
    },
    
    -- Debug y diagnóstico
    debug = false,
    logPerformanceStats = false
}

-- Estadísticas de rendimiento
performance.stats = {
    frameTime = 0,
    entitiesProcessed = 0,
    cacheHits = 0,
    cacheMisses = 0,
    lastCleanup = 0
}

-- Actualizar estadísticas
function performance.updateStats(key, value)
    if performance.settings.logPerformanceStats then
        performance.stats[key] = value
    end
end

-- Obtener todos los ajustes de rendimiento
function performance.getSettings()
    return performance.settings
end

-- Permitir sobrescribir configuraciones
function performance.configure(newSettings)
    for k, v in pairs(newSettings) do
        if type(v) == "table" and type(performance.settings[k]) == "table" then
            for subk, subv in pairs(v) do
                performance.settings[k][subk] = subv
            end
        else
            performance.settings[k] = v
        end
    end
end

return performance
