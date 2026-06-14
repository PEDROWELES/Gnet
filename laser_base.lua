--@name Laser Eyes Base
--@author vertihluy
--@shared

--@include https://raw.githubusercontent.com/PEDROWELES/Gnet/refs/heads/main/laser_guns.lua as guns
--@include https://raw.githubusercontent.com/PEDROWELES/Gnet/refs/heads/main/laser_ftimer.lua as ftimers
--@include https://raw.githubusercontent.com/PEDROWELES/Gnet/refs/heads/main/laser_sounds.lua as sounds

local M = {}

function M.init()
    require("guns")
    local FTimer = require("ftimers")
    local astrosounds = require("sounds")

    if SERVER then
        local targetPlayer = nil
        local isFiring = false
        local eyeL, eyeR
        local laserL, laserR
        
        --  
        local LASER_DAMAGE = 1.9
        local LASER_RADIUS = 1
        local DAMAGE_RADIUS = 3
        
        -- 
        local SND_START = "eyeLaserStart"
        local SND_LOOP = "eyeLaserLoop"
        local SND_END = "eyeLaserEnd"

        --   (   50)
        local spawnPos = chip():getPos() + Vector(0, 0, 50)
        local serum = prop.create(spawnPos, Angle(0, 0, 0), "models/healthvial.mdl", true)
        local ring = nil
        
        if isValid(serum) then
            serum:setRenderMode(2) --    2  RENDERMODE.TRANSCOLOR  
            serum:setColor(Color(255, 70, 70, 200))
            serum:setMaterial("models/debug/debugwhite")
            
            --    
            local light = hologram.create(spawnPos, Angle(), "models/holograms/hq_sphere.mdl", Vector(1.5))
            light:setParent(serum)
            light:setMaterial("models/debug/debugwhite")
            light:setRenderMode(3) -- :   3 (Additive  Source Engine)
            light:setColor(Color(255, 80, 80, 12)) -- red glow
            light:suppressEngineLighting(true)
            
            --    ()    
            local floorPos = chip():getPos() + Vector(0, 0, 1)
            ring = hologram.create(floorPos, Angle(0, 0, 0), "models/holograms/hq_torus.mdl", Vector(3, 3, 0.1))
            if isValid(ring) then
                ring:setMaterial("models/debug/debugwhite")
                ring:setRenderMode(3) 
                ring:setColor(Color(255, 70, 70, 45)) 
                ring:suppressEngineLighting(true)
            end
            
            --        
            hook.add("think", "SerumAnimation", function()
                if not isValid(serum) then 
                    if isValid(ring) then ring:remove() end --     ,    
                    hook.remove("think", "SerumAnimation")
                    return 
                end
                
                local time = timer.curtime()
                
                --   
                local hoverOffset = Vector(0, 0, math.sin(time * 2) * 3)
                serum:setPos(spawnPos + hoverOffset)
                
                --    Y (Yaw)
                local currentAngle = Angle(0, time * 45, 0)
                serum:setAngles(currentAngle)

                --    ()
                if isValid(ring) then
                    ring:setAngles(Angle(0, time * -45, 0)) --    
                    
                    local wave = 3 + math.sin(time * 4) * 0.3 --  
                    ring:setScale(Vector(wave, wave, 0.05))
                end
            end)
        end

        local function setupLasers(ply)
            if not isValid(ply) then return end
            
            if isValid(eyeL) then eyeL:remove() end
            if isValid(eyeR) then eyeR:remove() end

            eyeL = hologram.create(ply:getPos(), ply:getAngles(), "models/holograms/hq_sphere.mdl", Vector(0.01))
            eyeR = hologram.create(ply:getPos(), ply:getAngles(), "models/holograms/hq_sphere.mdl", Vector(0.01))
            
            if isValid(eyeL) and isValid(eyeR) then
                eyeL:setColor(Color(0,0,0,0))
                eyeR:setColor(Color(0,0,0,0))
                
                laserL = Laser:new(eyeL, LASER_RADIUS, LASER_DAMAGE, DAMAGE_RADIUS, ply)
                laserR = Laser:new(eyeR, LASER_RADIUS, LASER_DAMAGE, DAMAGE_RADIUS, ply)
                
                laserL:addIgnore(ply)
                laserR:addIgnore(ply)
                
                net.start("serum_v_event_v22")
                net.writeInt(1, 4) -- 1: Take
                net.writeString(ply:getName())
                net.send()

                net.start("serum_v_event_v22")
                net.writeInt(3, 4) -- 3: Personal V1 instructions
                net.send(ply)
            end
        end

        --     -
        local function isPlayerInBuildMode(ply)
            if isValid(ply) and ply.isBUILD then
                local res = ply:isBUILD()
                if res == true or res == 1 then 
                    return true 
                end
            end
            return false
        end

        hook.add("playerUse", "SerumInjection", function(ply, ent)
            if ent == serum and not targetPlayer then
                if not isPlayerInBuildMode(ply) then
                    targetPlayer = ply
                    
                    if isValid(serum) then serum:remove() end
                    if isValid(ring) then ring:remove() end
                    
                    setupLasers(ply)
                else
                    net.start("serum_v_event_v22")
                    net.writeInt(0, 4) -- 0: Build Mode Error
                    net.send(ply)
                end
            end
        end)

        local function cleanUp(ply)
            if isValid(ply) then
                net.start("serum_v_event_v22")
                net.writeInt(2, 4) -- 2: Loss
                net.writeString(ply:getName())
                net.send()
            end

            targetPlayer = nil
            isFiring = false
            if isValid(eyeL) then eyeL:remove() end
            if isValid(eyeR) then eyeR:remove() end
            if isValid(ring) then ring:remove() end
            
            chip():remove()
        end

        hook.add("think", "EyeLasersThink", function()
            if not isValid(targetPlayer) or not targetPlayer:isAlive() or not isValid(eyeL) or not isValid(eyeR) then 
                if isFiring then
                    isFiring = false
                    if laserL then laserL:stop() end
                    if laserR then laserR:stop() end
                    astrosounds.stop(SND_START)
                    astrosounds.stop(SND_LOOP)
                end
                return 
            end
            
            -- :    -    
            if isPlayerInBuildMode(targetPlayer) then
                cleanUp(targetPlayer)
                return
            end
            
            local shootPos = targetPlayer:getShootPos()
            local eyeAng = targetPlayer:getEyeAngles()
            local forward = eyeAng:getForward()
            local right = eyeAng:getRight()
            local up = eyeAng:getUp()
            
            local lStart = shootPos + (right * -3.2) + (up * 2.5) + (forward * 10)
            local rStart = shootPos + (right * 3.2) + (up * 2.5) + (forward * 10)
            
            eyeL:setPos(lStart)
            eyeR:setPos(rStart)
            
            local traceRes = targetPlayer:getEyeTrace()
            local targetPos = traceRes.HitPos
            
            eyeL:setAngles((targetPos - lStart):getAngle())
            eyeR:setAngles((targetPos - rStart):getAngle())
            
            local attackKey1 = IN_KEY and IN_KEY.ATTACK or 1
            local attackKey2 = IN_KEY and IN_KEY.ATTACK2 or 2
            local active = targetPlayer:keyDown(attackKey1) and targetPlayer:keyDown(attackKey2)
            
            if active then
                if not isFiring then
                    isFiring = true
                    if laserL then laserL:start() end
                    if laserR then laserR:start() end
                    astrosounds.play(SND_START, Vector(), targetPlayer)
                    astrosounds.play(SND_LOOP, Vector(), targetPlayer)
                end
                if laserL then laserL:think(nil, targetPlayer) end
                if laserR then laserR:think(nil, targetPlayer) end
            else
                if isFiring then
                    isFiring = false
                    if laserL then laserL:stop() end
                    if laserR then laserR:stop() end
                    astrosounds.stop(SND_START)
                    astrosounds.stop(SND_LOOP)
                    astrosounds.play(SND_END, Vector(), targetPlayer)
                end
            end
        end)

        hook.add("PlayerDeath", "SerumDeath", function(ply)
            if ply == targetPlayer then cleanUp(ply) end
        end)
        
        hook.add("playerDisconnected", "SerumDisconnect", function(ply)
            if ply == targetPlayer then cleanUp(ply) end
        end)

    else
        --   
        local scout_sounds = "https://raw.githubusercontent.com/AstricUnion/AstroBots/refs/heads/main/sounds/astroscout/"
        astrosounds.preload("eyeLaserStart", 1, false, false, scout_sounds .. "LaserStart.mp3")
        astrosounds.preload("eyeLaserLoop", 0.6, true, false, scout_sounds .. "LaserLoop.mp3")
        astrosounds.preload("eyeLaserEnd", 0.8, false, false, scout_sounds .. "LaserEnd.mp3")

        net.receive("serum_v_event_v22", function()
            local type = net.readInt(4)
            local plyName = (type == 1 or type == 2) and net.readString() or ""
            
            local function showChat(col, prefix, msg)
                if chat and chat.addText then
                    chat.addText(col, prefix, Color(255, 255, 255), msg)
                else
                    print(prefix .. msg)
                end
            end

            if type == 1 then
                showChat(Color(0, 255, 0), "[Vought News] ", plyName .. " has accepted Serum V! Fear the laser eyes.")
            elseif type == 2 then
                showChat(Color(255, 50, 0), "[Vought News] ", plyName .. " has died and lost the power of Compound V.")
            elseif type == 0 then
                showChat(Color(255, 0, 0), "[Vought] ", "Error! Cannot accept serum in Build Mode.")
            elseif type == 3 then
                showChat(Color(180, 255, 0), "[Vought] ", "You injected V1. Hold LMB + RMB to fire your eye lasers.")
            end
        end)
    end
end

return M
