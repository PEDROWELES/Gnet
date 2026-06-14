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
    ---@param pitch number? Playback pitch, default 1
    function astrosounds.play(name, offset, parent, plys, pitch)
        net.start("playSound")
        net.writeString(name)
        net.writeVector(offset or Vector())
        net.writeBool(parent ~= nil)
        if parent then
            net.writeEntity(parent)
        end
        net.writeFloat(pitch or 1)
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

    ---Set sound pitch
    ---@param name string Identifier of sound
    ---@param pitch number Pitch multiplier
    ---@param plys table | Player | nil Players to update
    function astrosounds.setPitch(name, pitch, plys)
        net.start("pitchSound")
        net.writeString(name)
        net.writeFloat(pitch)
        net.send(plys)
    end

else
    local SOUNDS = {}
    local DEFINITIONS = {}
    local PARENTS = {}
    local ERRORS = {}
    local LOADING = {}
    local PENDING_PLAYS = {}
    local PENDING_PITCH = {}
    local DEFAULT_FADE_MIN = 50
    local DEFAULT_FADE_MAX = 300

    local function message(...)
        printConsole(Color(255, 0, 0), "[AstroSound] ", Color(255, 255, 255), ...)
    end

    local function playLoadedSound(name, offset, parent, pitch)
        offset = offset or Vector()

        local sound = SOUNDS[name]
        if not sound then return end

        sound:setPitch(pitch or 1)
        if !sound:isLooping() then
            sound:setTime(0)
        end

        local parentPos = (parent and parent:getPos() or Vector())
        sound:setPos(parentPos + offset)
        sound:play()
        PARENTS[name] = {parent, offset}
    end

    local function flushPendingPlays(name)
        local queued = PENDING_PLAYS[name]
        if not queued then return end

        PENDING_PLAYS[name] = nil
        for _, data in ipairs(queued) do
            playLoadedSound(name, data.offset, data.parent, data.pitch)
        end
    end

    ---Preload sound
    ---@param name string Name to identify this sound
    ---@param volume number Volume of this sound
    ---@param loop boolean Loop this sound
    ---@param play boolean Play this sound after preload
    ---@param url string URL to download sound
    function astrosounds.preload(name, volume, loop, play, url)
        DEFINITIONS[name] = {
            volume = volume,
            loop = loop,
            play = play,
            url = url
        }
        if LOADING[name] then return end

        local noplay = (!play and " noplay" or "")
        LOADING[name] = true
        bass.loadURL(url, "3d noblock" .. noplay, function(snd, _, errname)
            if !snd then
                LOADING[name] = nil
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

            LOADING[name] = nil
            SOUNDS[name] = snd
            message(string.format("Sound \"%s\" loaded!", name))
            snd:setVolume(volume)
            snd:setLooping(loop)
            snd:setPitch(PENDING_PITCH[name] or 1)
            snd:setFade(DEFAULT_FADE_MIN, DEFAULT_FADE_MAX, true)

            if play then
                playLoadedSound(name, Vector(), nil, PENDING_PITCH[name] or 1)
            end
            flushPendingPlays(name)
        end)
    end

    astrosounds.preload("dingusPickup", 1, false, false, "http://144.31.143.58/meowrgh.mp3")
    astrosounds.preload("dingusShoot", 1, false, false, "http://144.31.143.58/meow-1.mp3")
    astrosounds.preload("dingusImpact", 1, false, false, "http://144.31.143.58/meowrgh.mp3")
    astrosounds.preload("dingusPurr", 1, false, false, "http://144.31.143.58/purring-cat.mp3")
    astrosounds.preload("maxwellTheme", 0.8, true, false, "http://144.31.143.58/maxwell-the-cat-theme.mp3")
    astrosounds.preload("maxwellThemePickup", 0.22, true, false, "http://144.31.143.58/maxwell-the-cat-theme.mp3")
    astrosounds.preload("maxwellThemeHead", 0.35, true, false, "http://144.31.143.58/maxwell-the-cat-theme.mp3")
    astrosounds.preload("maxwellBoom", 1, false, false, "http://144.31.143.58/minecraft-explosion-meme-sound-effect.mp3")


    ---Play sound
    ---@param name string Identifier of sound
    ---@param offset Vector? Position or offset of this sound
    ---@param parent Entity? Entity, parent this sound to
    ---@param pitch number? Playback pitch, default 1
    function astrosounds.play(name, offset, parent, pitch)
        local sound = SOUNDS[name]
        if sound then
            playLoadedSound(name, offset, parent, pitch)
            return
        end

        PENDING_PLAYS[name] = PENDING_PLAYS[name] or {}
        table.insert(PENDING_PLAYS[name], {
            offset = offset or Vector(),
            parent = parent,
            pitch = pitch or 1
        })

        local def = DEFINITIONS[name]
        if def and !LOADING[name] then
            astrosounds.preload(name, def.volume, def.loop, false, def.url)
        end
    end


    ---Set pitch for already loaded or loading sound
    ---@param name string Identifier of sound
    ---@param pitch number Pitch multiplier
    function astrosounds.setPitch(name, pitch)
        PENDING_PITCH[name] = pitch

        local sound = SOUNDS[name]
        if sound then
            sound:setPitch(pitch)
            return
        end

        local def = DEFINITIONS[name]
        if def and !LOADING[name] then
            astrosounds.preload(name, def.volume, def.loop, false, def.url)
        end
    end


    ---Stop sound
    ---@param name string Identifier of sound
    function astrosounds.stop(name)
        PENDING_PLAYS[name] = nil
        PENDING_PITCH[name] = 1
        PARENTS[name] = nil

        local sound = SOUNDS[name]
        if sound then
            sound:pause()
            sound:setTime(0)
            sound:setPitch(1)
        end
    end

    net.receive("playSound", function()
        local name = net.readString()
        local pos = net.readVector()
        local is_parent = net.readBool()
        if is_parent then
            net.readEntity(function(ent)
                local pitch = net.readFloat()
                astrosounds.play(name, pos, ent, pitch)
            end)
        else
            local pitch = net.readFloat()
            astrosounds.play(name, pos, nil, pitch)
        end
    end)

    net.receive("stopSound", function()
        local name = net.readString()
        astrosounds.stop(name)
    end)

    net.receive("pitchSound", function()
        local name = net.readString()
        local pitch = net.readFloat()
        astrosounds.setPitch(name, pitch)
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
