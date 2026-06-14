---@name Sounds
---@author AstricUnion
---@shared

---@class astrosounds
local astrosounds = {}

-- =========================================================================
-- НАСТРОЙКА ЗВУКОВ (Конфиг на GitHub)
-- =========================================================================
local SOUND_CONFIG = {
    ["superspeed_start"] = {
        url = "https://www.image2url.com/r2/default/audio/1781261998156-a8b851a2-c71b-4f5e-83d3-ab96c8014b15.mp3", -- Ссылка на звук СТАРТА
        volume = 1,
        loop = false
    },
    ["superspeed_start_boost"] = { -- Дополнительный слой для увеличения громкости в 1.5 раза
        url = "https://www.image2url.com/r2/default/audio/1781261998156-a8b851a2-c71b-4f5e-83d3-ab96c8014b15.mp3",
        volume = 0.5, -- Добавляем 50% громкости к основному звуку
        loop = false
    }
    -- Звук "superspeed_stop" полностью удалён из конфига, поэтому он больше не воспроизведётся
}
-- =========================================================================

if SERVER then
    ---Play sound
    function astrosounds.play(name, offset, parent, plys)
        -- Перехватываем воспроизведение старта, чтобы наложить буст громкости
        if name == "superspeed_start" then
            net.start("playSound") net.writeString("superspeed_start") net.writeVector(offset or Vector()) net.writeBool(parent ~= nil) if parent then net.writeEntity(parent) end net.send(plys)
            net.start("playSound") net.writeString("superspeed_start_boost") net.writeVector(offset or Vector()) net.writeBool(parent ~= nil) if parent then net.writeEntity(parent) end net.send(plys)
            return
        end

        if name == "superspeed_stop" then return end -- Игнорируем вызовы остановки, если они остались в чипе сыворотки

        net.start("playSound")
        net.writeString(name)
        net.writeVector(offset or Vector())
        net.writeBool(parent ~= nil)
        if parent then
            net.writeEntity(parent)
        end
        net.send(plys)
    end

    ---Stop sound
    function astrosounds.stop(name, plys)
        if name == "superspeed_stop" then return end
        net.start("stopSound")
        net.writeString(name)
        net.send(plys)
    end
else
    local SOUNDS = {}
    local PARENTS = {}
    local ERRORS = {}

    local function message(...)
        printConsole(Color(255, 0, 0), "[AstroSound] ", Color(255, 255, 255), ...)
    end

    ---Preload sound
    function astrosounds.preload(name, volume, loop, play, url)
        local noplay = (!play and " noplay" or "")
        bass.loadURL(url, "3d noblock" .. noplay, function(snd, _, errname)
            if !snd then
                local attempts = ERRORS[name] or 3
                message(string.format("Sound \"%s\" error: %s. Attempts remain: %i", name, errname, attempts))

                if attempts and attempts > 0 then
                    ERRORS[name] = attempts - 1
                    timer.simple(1, function()
                        astrosounds.preload(name, volume, loop, play, url)
                    end)
                end
                return
            end
 
            SOUNDS[name] = snd
            message(string.format("Sound \"%s\" loaded!", name))
            snd:setVolume(volume)
            snd:setLooping(loop)
        end)
    end

    ---Play sound
    function astrosounds.play(name, offset, parent)
        if name == "superspeed_stop" then return end
        
        -- Если на клиенте вызван старт, также дублируем его с бустом громкости
        if name == "superspeed_start" and SOUNDS["superspeed_start_boost"] then
            local soundBoost = SOUNDS["superspeed_start_boost"]
            soundBoost:setTime(0)
            local pPos = (parent and parent:getPos() or Vector())
            soundBoost:setPos(pPos + (offset or Vector()))
            soundBoost:play()
            PARENTS["superspeed_start_boost"] = {parent, offset or Vector()}
        end

        offset = offset or Vector()
        local sound = SOUNDS[name]
        if sound then
            sound:setTime(0) 
            local parentPos = (parent and parent:getPos() or Vector())
            sound:setPos(parentPos + offset)
            sound:play()
            PARENTS[name] = {parent, offset}
        end
    end

    ---Stop sound
    function astrosounds.stop(name)
        if name == "superspeed_stop" then return end
        if name == "superspeed_start" and SOUNDS["superspeed_start_boost"] then
            SOUNDS["superspeed_start_boost"]:pause()
            SOUNDS["superspeed_start_boost"]:setTime(0)
        end
        
        local sound = SOUNDS[name]
        if sound then
            sound:pause()
            sound:setTime(0)
        end
    end

    -- Автоматический прелоад всех звуков
    for soundName, config in pairs(SOUND_CONFIG) do
        astrosounds.preload(soundName, config.volume, config.loop, false, config.url)
    end

    net.receive("playSound", function()
        local name = net.readString()
        local pos = net.readVector()
        local is_parent = net.readBool()
        if is_parent then
            net.readEntity(function(ent)
                astrosounds.play(name, pos, ent)
            end)
        else
            astrosounds.play(name, pos)
        end
    end)

    net.receive("stopSound", function()
        local name = net.readString()
        astrosounds.stop(name)
    end)

    hook.add("Think", "soundParent", function()
        for name, parent in pairs(PARENTS) do
            local snd = SOUNDS[name]
            if snd and isValid(parent[1]) then
                snd:setPos(parent[1]:getPos() + parent[2])
            end
        end
    end)
end

return astrosounds
