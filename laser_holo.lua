--@name HoloCreator
--@author AstricUnion
--@shared

local CHIPPOS = chip():getPos()

local clientHolos = {}

if SERVER then
    -- This is a bad realization, in my opinion
    -- But I can't found something better
    -- If you want, you can send PR to it

    ---@type table[thread]
    local initializeThreads = {}
    
    local function initHolosThread(ply)
        if !isValid(ply) then return end
        for id, holo in pairs(clientHolos) do
            if !isValid(holo) then continue end
            net.start("HologramInitialized")
            net.writeString(id)
            net.writeEntity(holo)
            net.send(ply)
            coroutine.wait(0.2)
            coroutine.yield()
        end
    end


    hook.add("ClientInitialized", "HologramsInitialize", function(ply)
        local th = coroutine.create(initHolosThread)
        table.insert(initializeThreads, {th, ply})
    end)

    hook.add("Think", "ResumeInitializationThreads", function()
        for _, th in ipairs(initializeThreads) do
            if coroutine.status(th[1]) == "dead" then
                table.removeByValue(initializeThreads, th)
                continue
            end
            coroutine.resume(th[1], th[2])
        end
    end)
else
    net.receive("HologramInitialized", function()
        local id = net.readString()
        net.readEntity(function(ent)
            hook.run("HoloInitialized", id, ent)
        end)
    end)
end




---Function to create SubHolo
---@param pos? Vector Position, default Vector()
---@param ang? Angle Angle, default Angle()
---@param model? string Model of holo, default "models/hunter/blocks/cube025x025x025.mdl"
---@param scale? Vector Scale of holo, default Vector(1, 1, 1)
---@param suppressLight? boolean Suppress light of the holo, default false
---@param color? Color Color of holo, default full white
---@param mat? string Material of holo, default uses model material
---@param clientId? string Send holo to clients with unique ID. Default nil. Sends to client hook HoloInitialized. Does nothing on client
---@return Hologram?
local function SubHolo(pos, ang, model, scale, suppressLight, color, mat, clientId)
    local holo = {
        pos = pos or Vector(),
        ang = ang or Angle(),
        model = model or "models/hunter/blocks/cube025x025x025.mdl",
        scale = scale or Vector(1, 1, 1),
        suppressLight = suppressLight or false,
        color = color or Color(255, 255, 255),
        mat = mat or nil
    }
    local holo_obj = hologram.create(
        CHIPPOS + holo.pos,
        holo.ang,
        holo.model,
        holo.scale
    )
    if not holo_obj then
        throw("Can't create hologram with model " .. holo.model)
        return
    end
    holo_obj:suppressEngineLighting(holo.suppressLight)
    holo_obj:setColor(holo.color)
    if holo.mat then holo_obj:setMaterial(holo.mat) end
    if SERVER and clientId then
        net.start("HologramInitialized")
        net.writeString(clientId)
        net.writeEntity(holo_obj)
        net.send()
        clientHolos[clientId] = holo_obj
    end
    return holo_obj
end


---Function Rig, to create rig holograms
---@param pos? Vector Position, default Vector()
---@param ang? Angle Angle, default Angle()
---@param visible? boolean Turn on visibility (for designing)
---@return Hologram?
local function Rig(pos, ang, visible)
    local holo = {
        pos = pos or Vector(),
        ang = ang or Angle(),
        model = "models/editor/axis_helper_thick.mdl"
    }
    local holo_obj = hologram.create(
        CHIPPOS + holo.pos,
        holo.ang,
        holo.model,
        Vector(0.2, 0.2, 0.2)
    )
    if not holo_obj then
        throw("Can't create hologram with model " .. holo.model)
        return
    end
    if SERVER then
        holo_obj:setDrawShadow(false)
    end
    holo_obj:suppressEngineLighting(true)
    holo_obj:setNoDraw(!visible)
    return holo_obj
end


---@class Trail
---@field startSize number The start size of the trail (0-128)
---@field endSize number The end size of the trail (0-128)
---@field length number The length size of the trail
---@field mat string The material of the trail
---@field color Color The color of the trail
---@field attachmentID? number Optional attachmentid the trail should attach to
---@field additive? boolean If the trail's rendering is additive
local Trail = {}
Trail.__index = Trail


---Trail structure, stores hologram trail data
---@param startSize number The start size of the trail (0-128)
---@param endSize number The end size of the trail (0-128)
---@param length number The length size of the trail
---@param mat string The material of the trail
---@param color Color The color of the trail
---@param attachmentID? number Optional attachmentid the trail should attach to
---@param additive? boolean If the trail's rendering is additive
---@return Trail object
function Trail:new(startSize, endSize, length, mat, color, attachmentID, additive)
    return setmetatable(
        {
            startSize = startSize,
            endSize = endSize,
            length = length,
            mat = mat,
            color = color,
            attachmentID = attachmentID,
            additive = additive
        },
        Trail
    )
end
setmetatable(Trail, {__call = Trail.new})


---@class Clip
---@field pos Vector
---@field normal Vector
local Clip = {}
Clip.__index = Clip

---Clip structure
---@param pos any
---@param normal Vector Angle of clip, like normal, but local
---@return table
function Clip:new(pos, normal)
    return setmetatable(
        {
            pos = pos,
            normal = normal
        },
        Clip
    )
end

setmetatable(Clip, {__call = Clip.new})


---@class Holo
---@field subholo Hologram
---@field trail Trail
---@field clips table[Clip]
local Holo = {}
Holo.__index = Holo

---Holo structure, stores hologram data
---@param subholo Hologram Hologram to spawn
---@param trail? Trail Trail structure
---@param clips? table[Clip] Table with Clip structure
function Holo:new(subholo, trail, clips)
    return setmetatable(
        {
            subholo = subholo,
            trail = trail,
            clips = clips,
        },
        Holo
    )
end
setmetatable(Holo, {__call = Holo.new})


---Creates and parents holograms to first hologram, to create one object
---@param ... ... List of Holo structures
function hologram.createPart(...)
    local main_holo
    for i, holo in ipairs({...}) do
        ---@cast holo Holo
        if holo.trail then
            holo.subholo:setTrails(
                holo.trail.startSize,
                holo.trail.endSize,
                holo.trail.length,
                holo.trail.mat,
                holo.trail.color,
                holo.trail.attachmentID,
                holo.trail.additive
            )
        end
        if holo.clips then
            for i, clip in ipairs(holo.clips) do
                ---@cast clip Clip
                holo.subholo:setClip(
                    i,
                    true,
                    clip.pos,
                    clip.normal,
                    holo.subholo
                )
            end
        end
        if i == 1 then
            main_holo = holo.subholo
            continue
        end
        holo.subholo:setParent(main_holo)
    end
    return main_holo
end

return {
    Holo = Holo,
    Rig = Rig,
    SubHolo = SubHolo,
    Trail = Trail,
    Clip = Clip
}
