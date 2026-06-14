---@name Sounds
---@author AstricUnion
---@shared

---@class astrosounds
local astrosounds = {}

if SERVER then
    ---Play sound
    ---@param name string Identifier of sound
    ---@param offset Vector? Position or offset of this sound
    ---@param parent Entity? Entity, parent this sound to
    ---@param plys table | Player | nil Players to send the sound
    function astrosounds.play(name, offset, parent, plys)
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
    ---@param name string Identifier of sound
    ---@param plys table | Player | nil Players to stop the sound
    function astrosounds.stop(name, plys)
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
    ---@param name string Name to identify this sound
    ---@param volume number Volume of this sound
    ---@param loop boolean Loop this sound
    ---@param play boolean Play this sound after preload
    ---@param url string URL to download sound
    function astrosounds.preload(name, volume, loop, play, url)
        local noplay = (!play and " noplay" or "")
        bass.loadURL(url, "3d noblock" .. noplay, function(snd, _, errname)
            if !snd then
                local attempts = ERRORS[name] or 3
                message(string.format(
                    "Sound \"%s\" error: %s. Attempts remain: %i",
                    name, errname, attempts
                ))

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
    ---@param name string Identifier of sound
    ---@param offset Vector? Position or offset of this sound
    ---@param parent Entity? Entity, parent this sound to
    function astrosounds.play(name, offset, parent)
        offset = offset or Vector()
        local sound = SOUNDS[name]
        if sound then
            if !sound:isLooping() then
                sound:setTime(0)
            end
            local parentPos = (parent and parent:getPos() or Vector())
            sound:setPos(parentPos + offset)
            sound:play()
            PARENTS[name] = {parent, offset}
        end
    end


    ---Stop sound
    ---@param name string Identifier of sound
    function astrosounds.stop(name)
        local sound = SOUNDS[name]
        if sound then
            sound:pause()
            sound:setTime(0)
        end
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
