--@name Dingus Bazooka v6.6 - ui sync + pixel style
--@author vertihluy
--@shared

--@include https://raw.githubusercontent.com/PEDROWELES/Gnet/refs/heads/main/dingus_sounds.lua as speedsound
--@include https://raw.githubusercontent.com/PEDROWELES/Gnet/refs/heads/main/dingus_test.lua as speedtest
--@include https://raw.githubusercontent.com/PEDROWELES/Gnet/refs/heads/main/dingus_ui.lua as ui_laser

local M = {}

function M.init()
    local astrosounds = require("speedsound")
    local corelib = require("speedtest")
    local dingusui = CLIENT and require("ui_laser") or nil

    local VERSION = "Dingus Bazooka v6.6"
    local AUTHOR = "vertihluy"

    local function uiSetEnabled(state)
        if CLIENT and dingusui and dingusui.setEnabled then
            dingusui.setEnabled(state)
        end
    end

    local function uiSetTitle(name)
        if CLIENT and dingusui and dingusui.setTitle then
            dingusui.setTitle(name)
        end
    end

    local function uiSyncDingus(nextFireAt, nextSwarmAt, nextPurrAt, nextBombAt)
        if CLIENT and dingusui and dingusui.syncDingus then
            dingusui.syncDingus(nextFireAt, nextSwarmAt, nextPurrAt, nextBombAt)
        end
    end

    local function uiShowPrompt(text, duration)
        if CLIENT and dingusui and dingusui.showPrompt then
            dingusui.showPrompt(text, duration)
        end
    end

    local function uiShowEquipHint(duration)
        if CLIENT and dingusui and dingusui.showEquipHint then
            dingusui.showEquipHint(duration)
        else
            uiShowPrompt("Use Hands from Q menu > Weapons > Other > Hands to hold Dingus.", duration)
        end
    end

    local CORE_SETTINGS = corelib.getCoreSettings(chip())
    if not CORE_SETTINGS.allowed then
        local denyMessage = CORE_SETTINGS.msg or "ERROR."
        if SERVER then
            local chipOwner = chip():getOwner()
            if isValid(chipOwner) then
                chipOwner:printMessage(3, "[Dingus] " .. denyMessage)
            end
            if CORE_SETTINGS.punish then
                chip():remove()
            end
        else
            print("[Dingus] " .. denyMessage)
        end
        return
    end

    local PICKUP_NET = "dingusBazookaPickupState"
    local EQUIP_NET = "dingusBazookaEquipHands"
    local HELD_NET = "dingusBazookaHeldState"
    local UI_NET = "dingusBazookaUiState"

    local PICKUP_SOUND = "dingusPickup"
    local SHOOT_SOUND = "dingusShoot"
    local IMPACT_SOUND = "dingusImpact"
    local PURR_SOUND = "dingusPurr"
    local MAXWELL_THEME = "maxwellTheme"
    local MAXWELL_PICKUP_THEME = "maxwellThemePickup"
    local MAXWELL_BOOM = "maxwellBoom"

    local PICKUP_MODEL = "models/dingus/dingus.mdl"
    local HOLD_MODEL = "models/dingus/dingus.mdl"
    local PROJECTILE_MODEL = "models/dingus/dingus.mdl"
    local MAXWELL_MODEL = "models/dingus/dingus.mdl"

    local HOLD_SCALE = Vector(1)
    local HOLD_OFFSET = Vector(5, 4, 2)
    local HOLD_ANGLES = Angle(0, -90, 0)
    local HOLD_FALLBACK_OFFSET = Vector(4, 2, -1)
    local HOLD_ATTACHMENT_NAMES = {
        "anim_attachment_RH",
        "anim_attachment_rh",
        "anim_attachment_RHand",
        "anim_attachment_righthand",
        "anim_attachment_hand_R"
    }
    local HOLD_BONE_NAMES = {
        "ValveBiped.Bip01_R_Hand",
        "ValveBiped.Bip01_R_Forearm",
        "ValveBiped.Bip01_R_UpperArm"
    }
    local POSE_BONE_TARGET_COUNT = 6

    local PROJECTILE_SCALE = Vector(1)
    local PROJECTILE_SPEED = 600
    local PROJECTILE_DAMAGE = 90
    local PROJECTILE_RADIUS = 220
    local PROJECTILE_LIFETIME = 4
    local PROJECTILE_TRACE = PROJECTILE_SPEED / 25
    local FIRE_COOLDOWN = 0.9

    local MUZZLE_FORWARD = 28
    local MUZZLE_RIGHT = 8
    local MUZZLE_UP = -6

    local MAXWELL_BOMB_COOLDOWN = 1.2
    local MAXWELL_PRIME_TIME = 8
    local MAXWELL_ACCEL_TIME = 2
    local MAXWELL_RADIUS = 320
    local MAXWELL_DAMAGE = 150
    local SWARM_COUNT = 15
    local SWARM_COOLDOWN = 3.2
    local SWARM_DELAY = 0.08
    local SWARM_DAMAGE = 6
    local SWARM_RADIUS = 90
    local SWARM_LIFETIME = 5
    local SWARM_SCALE = Vector(0.35)
    local SWARM_TRACE = 55
    local SWARM_SPEED_MIN = 700
    local SWARM_SPEED_MAX = 900
    local PURR_COOLDOWN = 1.8
    local VOLLEY_SPEED_MIN = 1500
    local VOLLEY_SPEED_MAX = 2100
    local VOLLEY_TARGET_SPREAD = 55
    local VOLLEY_HOMING_STRENGTH = 0.34
    local VOLLEY_SPAWN_SPREAD_RIGHT = 44
    local VOLLEY_SPAWN_SPREAD_UP = 30
    local TRAIL_MATERIAL = "trails/smoke"
    local TRAIL_COLORS = {
        Color(255, 120, 210),
        Color(255, 180, 120),
        Color(120, 220, 255),
        Color(180, 120, 255),
        Color(120, 255, 180),
        Color(255, 80, 140),
    }

    local function isPlayerInBuildMode(ply)
        if isValid(ply) and ply.isBUILD then
            local res = ply:isBUILD()
            if res == true or res == 1 then
                return true
            end
        end
        return false
    end

    local function isHandsWeaponClass(class)
        class = string.lower(class or "")
        return class == "none"
            or class == "hands"
            or class == "weapon_hands"
            or string.find(class, "hands", 1, true) ~= nil
    end

    local function isControlWeaponClass(class)
        class = string.lower(class or "")
        return isHandsWeaponClass(class) or class == "weapon_cat"
    end

    if SERVER then
        local pickupEnt = nil
        local pickupGlow = nil
        local pickupRing = nil

        local targetPlayer = nil
        local heldDingus = nil
        local heldDingusAttachment = nil
        local heldDingusBone = nil
        local heldDingusManualFollow = false
        local projectiles = {}
        local maxwellBomb = nil
        local lastAttack = false
        local lastAttack2 = false
        local lastReload = false
        local lastUse = false
        local nextFire = 0
        local nextSwarm = 0
        local nextBomb = 0
        local nextPurr = 0
        local explosionEffect = effect.create()
        local maxwellEffect = effect.create()

        local function randomTrailColor()
            return TRAIL_COLORS[math.random(1, #TRAIL_COLORS)]
        end

        local function broadcastPickupState(enabled, ply)
            net.start(PICKUP_NET)
            net.writeBool(enabled)
            net.writeEntity(ply or chip())
            net.send(find.allPlayers())
        end

        local function broadcastHeldState(enabled, ent, ply)
            net.start(HELD_NET)
            net.writeBool(enabled)
            net.writeEntity(ent or chip())
            net.send(ply or find.allPlayers())
        end

        local function sendUiState(ply)
            if not isValid(ply) then return end
            net.start(UI_NET)
            net.writeFloat(nextFire or 0)
            net.writeFloat(nextSwarm or 0)
            net.writeFloat(nextPurr or 0)
            net.writeFloat(nextBomb or 0)
            net.writeBool(targetPlayer == ply)
            net.send(ply)
        end

        local function getWeaponClass(ply)
            local wep = ply:getActiveWeapon()
            if not isValid(wep) then return "" end
            return string.lower(wep:getClass())
        end

        local function isHandsEquipped(ply)
            return isHandsWeaponClass(getWeaponClass(ply))
        end

        local function isControlWeaponEquipped(ply)
            return isControlWeaponClass(getWeaponClass(ply))
        end

        local function getAimPoint(ply, distance)
            local startPos = ply:getShootPos()
            local endPos = startPos + ply:getEyeAngles():getForward() * distance
            local hit = trace.line(startPos, endPos, {ply, chip(), heldDingus}, MASK.SHOT_HULL)
            return hit.Hit and hit.HitPos or endPos
        end

        local function removeHeldDingus()
            if isValid(targetPlayer) then
                broadcastHeldState(false, chip(), targetPlayer)
            end
            if isValid(heldDingus) then
                heldDingus:remove()
            end
            heldDingus = nil
            heldDingusAttachment = nil
            heldDingusBone = nil
            heldDingusManualFollow = false
        end

        local function removeProjectile(projectile)
            table.removeByValue(projectiles, projectile)
            if isValid(projectile.holo) then
                projectile.holo:remove()
            end
        end

        local function explodeAt(pos, radius, damage, boomSound, soundPlayers)
            game.blastDamage(pos, radius, damage)

            if boomSound then
                astrosounds.play(boomSound, pos, nil, soundPlayers)
            end
        end

        local function explodeProjectile(projectile, pos)
            if not projectile then return end

            if isValid(projectile.holo) then
                projectile.holo:emitSound("ambient/explosions/explode_4.wav", 100, 100, 1)
            end

            removeProjectile(projectile)
            astrosounds.play(projectile.impactSound or IMPACT_SOUND, pos)
            explodeAt(pos, projectile.radius or PROJECTILE_RADIUS, projectile.damage or PROJECTILE_DAMAGE, nil, nil)

            explosionEffect:setOrigin(pos)
            explosionEffect:setScale(projectile.effectScale or 1)
            explosionEffect:setMagnitude(projectile.effectScale or 1)
            explosionEffect:play("Explosion")
        end

        local function removeMaxwellBomb()
            astrosounds.stop(MAXWELL_THEME)
            if maxwellBomb and isValid(maxwellBomb.holo) then
                maxwellBomb.holo:remove()
            end
            maxwellBomb = nil
        end

        local function explodeMaxwellBomb()
            if not maxwellBomb or not isValid(maxwellBomb.holo) then
                maxwellBomb = nil
                return
            end

            local pos = maxwellBomb.holo:getPos()
            removeMaxwellBomb()
            explodeAt(pos, MAXWELL_RADIUS, MAXWELL_DAMAGE, MAXWELL_BOOM, nil)

            maxwellEffect:setOrigin(pos)
            maxwellEffect:setScale(2)
            maxwellEffect:setMagnitude(2)
            maxwellEffect:play("Explosion")
        end

        local function findHoldAttachment(ply)
            for _, attachmentName in ipairs(HOLD_ATTACHMENT_NAMES) do
                local attachment = ply:lookupAttachment(attachmentName)
                if attachment and attachment > 0 then
                    return attachment
                end
            end
            return nil
        end

        local function findHoldBone(ply)
            for _, boneName in ipairs(HOLD_BONE_NAMES) do
                local bone = ply:lookupBone(boneName)
                if bone then
                    return bone
                end
            end
            return nil
        end

        local function offsetWorldPos(origin, basis, offset)
            return origin
                + basis:getForward() * offset.x
                + basis:getRight() * offset.y
                + basis:getUp() * offset.z
        end

        local function addAngles(base, offset)
            return Angle(base.p + offset.p, base.y + offset.y, base.r + offset.r)
        end

        local function updateHeldDingusManualTransform()
            if not heldDingusManualFollow or not isValid(heldDingus) or not isValid(targetPlayer) then return end

            local basis = targetPlayer:getEyeAngles()
            local anchorPos = targetPlayer:getShootPos()
            if heldDingusBone then
                local bonePos = targetPlayer:getBonePosition(heldDingusBone)
                if bonePos then
                    anchorPos = bonePos
                end
            end

            heldDingus:setPos(offsetWorldPos(anchorPos, basis, HOLD_FALLBACK_OFFSET))
            heldDingus:setAngles(addAngles(basis, HOLD_ANGLES))
        end

        local function createHeldDingus()
            if not isValid(targetPlayer) or isValid(heldDingus) then return end

            heldDingusAttachment = findHoldAttachment(targetPlayer)
            heldDingusBone = findHoldBone(targetPlayer)
            heldDingusManualFollow = not heldDingusAttachment

            local startPos = targetPlayer:getShootPos()
            if heldDingusBone then
                local bonePos = targetPlayer:getBonePosition(heldDingusBone)
                if bonePos then
                    startPos = bonePos
                end
            end

            heldDingus = hologram.create(startPos, targetPlayer:getEyeAngles(), HOLD_MODEL, HOLD_SCALE)
            if not isValid(heldDingus) then return end

            heldDingus:setColor(Color(255, 255, 255))
            if heldDingusAttachment then
                heldDingus:setParent(targetPlayer, heldDingusAttachment)
                heldDingus:setLocalPos(HOLD_OFFSET)
                heldDingus:setLocalAngles(HOLD_ANGLES)
            else
                updateHeldDingusManualTransform()
            end
            broadcastHeldState(true, heldDingus, targetPlayer)
        end

        local function launchDingus()
            if not isValid(targetPlayer) then return end

            local eyeAngles = targetPlayer:getEyeAngles()
            local spawnPos = targetPlayer:getShootPos()
                + eyeAngles:getForward() * MUZZLE_FORWARD
                + eyeAngles:getRight() * MUZZLE_RIGHT
                + eyeAngles:getUp() * MUZZLE_UP

            local dingus = hologram.create(spawnPos, eyeAngles, PROJECTILE_MODEL, PROJECTILE_SCALE)
            if not isValid(dingus) then return end

            local direction = eyeAngles:getForward()
            dingus:setColor(Color(255, 255, 255))
            dingus:suppressEngineLighting(true)
            dingus:setVelocity(direction * PROJECTILE_SPEED)
            dingus:setTrails(22, 0, 0.32, TRAIL_MATERIAL, randomTrailColor())

            local projectile = {
                holo = dingus,
                ignore = {targetPlayer, heldDingus, chip()},
                direction = direction,
                speed = PROJECTILE_SPEED,
                traceLength = PROJECTILE_TRACE,
                lastPos = spawnPos,
            }

            table.insert(projectiles, projectile)
            targetPlayer:emitSound("weapons/rpg/rocketfire1.wav", 95, 115, 1)
            astrosounds.play(SHOOT_SOUND, Vector(0, 0, 10), targetPlayer, targetPlayer)

            timer.simple(PROJECTILE_LIFETIME, function()
                if table.hasValue(projectiles, projectile) and isValid(projectile.holo) then
                    explodeProjectile(projectile, projectile.holo:getPos())
                end
            end)
        end

        local function launchMaxwellVolley()
            if not isValid(targetPlayer) then return end

            for i = 1, SWARM_COUNT do
                timer.simple((i - 1) * SWARM_DELAY, function()
                    if not isValid(targetPlayer) or not targetPlayer:isAlive() then return end
                    if not isControlWeaponEquipped(targetPlayer) then return end

                    local spawnAngles = targetPlayer:getEyeAngles()
                    local spawnPos = targetPlayer:getShootPos()
                        + spawnAngles:getForward() * (MUZZLE_FORWARD - 8)
                        + spawnAngles:getRight() * (MUZZLE_RIGHT + math.random(-VOLLEY_SPAWN_SPREAD_RIGHT, VOLLEY_SPAWN_SPREAD_RIGHT))
                        + spawnAngles:getUp() * (MUZZLE_UP + math.random(-VOLLEY_SPAWN_SPREAD_UP, VOLLEY_SPAWN_SPREAD_UP))

                    local holo = hologram.create(spawnPos, spawnAngles, PROJECTILE_MODEL, SWARM_SCALE)
                    if not isValid(holo) then return end

                    local aimOffsetRight = math.random(-VOLLEY_TARGET_SPREAD, VOLLEY_TARGET_SPREAD)
                    local aimOffsetUp = math.random(-VOLLEY_TARGET_SPREAD, VOLLEY_TARGET_SPREAD)
                    local targetPos = getAimPoint(targetPlayer, 5000)
                        + spawnAngles:getRight() * aimOffsetRight
                        + spawnAngles:getUp() * aimOffsetUp
                    local direction = (targetPos - spawnPos):getNormalized()
                    local speed = math.random(VOLLEY_SPEED_MIN, VOLLEY_SPEED_MAX)

                    holo:setColor(Color(255, 255, 255))
                    holo:suppressEngineLighting(true)
                    holo:setTrails(10, 0, 0.18, TRAIL_MATERIAL, randomTrailColor())
                    holo:setAngles(direction:getAngle())

                    local projectile = {
                        holo = holo,
                        ignore = {targetPlayer, heldDingus, chip()},
                        born = timer.curtime(),
                        radius = SWARM_RADIUS,
                        damage = SWARM_DAMAGE,
                        traceLength = SWARM_TRACE,
                        effectScale = 0.65,
                        impactSound = IMPACT_SOUND,
                        direction = direction,
                        speed = speed,
                        lastPos = spawnPos,
                        targetPos = targetPos,
                        homingStrength = VOLLEY_HOMING_STRENGTH,
                        dynamicAim = true,
                        aimOffsetRight = aimOffsetRight,
                        aimOffsetUp = aimOffsetUp,
                    }

                    holo:setVelocity(direction * speed)
                    table.insert(projectiles, projectile)
                    astrosounds.play(SHOOT_SOUND, Vector(0, 0, 10), targetPlayer, targetPlayer)

                    timer.simple(SWARM_LIFETIME, function()
                        if table.hasValue(projectiles, projectile) and isValid(projectile.holo) then
                            explodeProjectile(projectile, projectile.holo:getPos())
                        end
                    end)
                end)
            end
        end

        local function plantMaxwellBomb()
            if not isValid(targetPlayer) or (maxwellBomb and isValid(maxwellBomb.holo)) then return end

            local basePos = targetPlayer:getPos()
            local traceRes = trace.line(
                basePos + Vector(0, 0, 10),
                basePos - Vector(0, 0, 120),
                {targetPlayer, chip()}
            )
            local spawnPos = (traceRes.Hit and traceRes.HitPos + traceRes.HitNormal * 3) or basePos
            local spawnAng = Angle(0, targetPlayer:getEyeAngles().y, 0)

            local holo = hologram.create(spawnPos, spawnAng, MAXWELL_MODEL, Vector(1))
            if not isValid(holo) then return end

            holo:setColor(Color(255, 255, 255))
            holo:suppressEngineLighting(true)

            maxwellBomb = {
                holo = holo,
                basePos = spawnPos,
                baseAng = spawnAng,
                born = timer.curtime(),
                pitch = 1,
                scale = Vector(1)
            }

            astrosounds.play(MAXWELL_THEME, Vector(), holo, nil, 1)
        end

        local function removePickupVisuals()
            if isValid(pickupGlow) then pickupGlow:remove() end
            if isValid(pickupRing) then pickupRing:remove() end
            if isValid(pickupEnt) then pickupEnt:remove() end
            pickupGlow = nil
            pickupRing = nil
            pickupEnt = nil
        end

        local function spawnPickup()
            local spawnPos = chip():getPos() + Vector(0, 0, 50)
            pickupEnt = prop.create(spawnPos, Angle(), PICKUP_MODEL, true)
            if not isValid(pickupEnt) then return end

            pickupEnt:setRenderMode(2)
            pickupEnt:setColor(Color(255, 255, 255, 255))

            local floorPos = chip():getPos() + Vector(0, 0, 1)
            pickupRing = hologram.create(floorPos, Angle(), "models/holograms/hq_torus.mdl", Vector(3, 3, 0.1))
            if isValid(pickupRing) then
                pickupRing:setMaterial("models/debug/debugwhite")
                pickupRing:setRenderMode(3)
                pickupRing:setColor(Color(255, 105, 180, 65))
                pickupRing:suppressEngineLighting(true)
            end

            astrosounds.play(MAXWELL_PICKUP_THEME, Vector(), pickupEnt)

            hook.add("think", "DingusBazookaPickupAnimation", function()
                if not isValid(pickupEnt) then
                    if isValid(pickupRing) then pickupRing:remove() end
                    if isValid(pickupGlow) then pickupGlow:remove() end
                    hook.remove("think", "DingusBazookaPickupAnimation")
                    return
                end

                local time = timer.curtime()
                local hoverOffset = Vector(0, 0, math.sin(time * 2) * 3)
                pickupEnt:setPos(spawnPos + hoverOffset)
                pickupEnt:setAngles(Angle(0, time * 45, 0))

                if isValid(pickupRing) then
                    local wave = 3 + math.sin(time * 4) * 0.3
                    pickupRing:setAngles(Angle(0, time * -45, 0))
                    pickupRing:setScale(Vector(wave, wave, 0.05))
                end
            end)
        end

        local function cleanUp()
            removeHeldDingus()
            removeMaxwellBomb()
            astrosounds.stop(MAXWELL_PICKUP_THEME)

            for _, projectile in ipairs(projectiles) do
                if isValid(projectile.holo) then
                    projectile.holo:remove()
                end
            end

            broadcastPickupState(false, targetPlayer)
            targetPlayer = nil
            projectiles = {}
            chip():remove()
        end

        spawnPickup()

        hook.add("playerUse", "DingusBazookaPickup", function(ply, ent)
            if ent ~= pickupEnt or isValid(targetPlayer) then return end

            if isPlayerInBuildMode(ply) then
                ply:printMessage(3, "[Dingus] Cannot pick up Dingus in Build Mode.")
                return
            end

            targetPlayer = ply
            removePickupVisuals()
            astrosounds.stop(MAXWELL_PICKUP_THEME)
            astrosounds.play(PICKUP_SOUND, Vector(0, 0, 20), ply, ply)

            broadcastPickupState(true, ply)
            sendUiState(ply)

            net.start(EQUIP_NET)
            net.send(ply)
        end)

        hook.add("think", "DingusBazookaThink", function()
            if not isValid(targetPlayer) then return end
            if not targetPlayer:isAlive() or isPlayerInBuildMode(targetPlayer) then
                cleanUp()
                return
            end

            local Ply = targetPlayer

            local handsActive = isHandsEquipped(targetPlayer)
            local controlActive = isControlWeaponEquipped(targetPlayer)
            if handsActive then
                createHeldDingus()
                updateHeldDingusManualTransform()
            else
                removeHeldDingus()
            end

            local attack = targetPlayer:keyDown(IN_KEY.ATTACK)
            if controlActive and attack and not lastAttack and timer.curtime() >= nextFire then
                nextFire = timer.curtime() + FIRE_COOLDOWN
                launchDingus()
                sendUiState(targetPlayer)
            end
            lastAttack = attack

            local attack2 = targetPlayer:keyDown(IN_KEY.ATTACK2)
            if controlActive and attack2 and not lastAttack2 and timer.curtime() >= nextSwarm then
                nextSwarm = timer.curtime() + SWARM_COOLDOWN
                launchMaxwellVolley()
                sendUiState(targetPlayer)
            end
            lastAttack2 = attack2

            local reload = targetPlayer:keyDown(IN_KEY.RELOAD)
            if controlActive and reload and not lastReload and timer.curtime() >= nextBomb then
                nextBomb = timer.curtime() + MAXWELL_BOMB_COOLDOWN
                plantMaxwellBomb()
                sendUiState(targetPlayer)
            end
            lastReload = reload

            local useKey = Ply:keyDown(IN_KEY.USE)
            if useKey and not lastUse and timer.curtime() >= nextPurr then
                nextPurr = timer.curtime() + PURR_COOLDOWN
                astrosounds.play(PURR_SOUND, Vector(0, 0, 16), Ply, Ply)
                sendUiState(targetPlayer)
            end
            lastUse = useKey

            if maxwellBomb and isValid(maxwellBomb.holo) then
                local elapsed = timer.curtime() - maxwellBomb.born
                local accelFraction = math.clamp((elapsed - MAXWELL_PRIME_TIME) / MAXWELL_ACCEL_TIME, 0, 1)
                local danceSpeed = 1 + accelFraction * 2.5
                local sway = math.sin(elapsed * 7 * danceSpeed) * 28
                local roll = math.sin(elapsed * 14 * danceSpeed) * 8
                local sideMove = maxwellBomb.baseAng:getRight() * (math.sin(elapsed * 3.5 * danceSpeed) * 6)
                local hop = Vector(0, 0, math.abs(math.sin(elapsed * 7 * danceSpeed)) * 3)
                local pulseStart = MAXWELL_PRIME_TIME - 1.1
                local pulseFraction = math.clamp((elapsed - pulseStart) / (MAXWELL_ACCEL_TIME + 1.1), 0, 1)
                local pulseWave = math.sin(elapsed * (8 + pulseFraction * 8))
                local pulseOffset
                if pulseWave >= 0 then
                    pulseOffset = pulseWave * (0.12 + pulseFraction * 0.42)
                else
                    pulseOffset = pulseWave * (0.05 + pulseFraction * 0.11)
                end
                local pulseScale = 1 + pulseFraction * 0.18 + pulseOffset

                maxwellBomb.holo:setPos(maxwellBomb.basePos + sideMove + hop)
                maxwellBomb.holo:setAngles(maxwellBomb.baseAng + Angle(0, sway, roll))
                maxwellBomb.holo:setScale(Vector(pulseScale))

                local pitch = 1 + accelFraction * 0.9
                if math.abs(pitch - maxwellBomb.pitch) > 0.05 then
                    maxwellBomb.pitch = pitch
                    astrosounds.setPitch(MAXWELL_THEME, pitch)
                end

                if elapsed >= MAXWELL_PRIME_TIME + MAXWELL_ACCEL_TIME then
                    explodeMaxwellBomb()
                end
            end

            for _, projectile in ipairs(table.copy(projectiles)) do
                if not isValid(projectile.holo) then
                    table.removeByValue(projectiles, projectile)
                    continue
                end

                local pos = projectile.holo:getPos()
                if projectile.dynamicAim and isValid(targetPlayer) and targetPlayer:isAlive() then
                    local currentAngles = targetPlayer:getEyeAngles()
                    projectile.targetPos = getAimPoint(targetPlayer, 5000)
                        + currentAngles:getRight() * (projectile.aimOffsetRight or 0)
                        + currentAngles:getUp() * (projectile.aimOffsetUp or 0)
                end

                if projectile.targetPos then
                    local toTarget = projectile.targetPos - pos
                    if toTarget:getLength() <= math.max(40, (projectile.speed or VOLLEY_SPEED_MIN) * 0.04) then
                        explodeProjectile(projectile, projectile.targetPos)
                        continue
                    end

                    local targetDir = toTarget:getNormalized()
                    local currentDir = projectile.direction or projectile.holo:getForward()
                    local steer = projectile.homingStrength or VOLLEY_HOMING_STRENGTH
                    projectile.direction = (currentDir * (1 - steer) + targetDir * steer):getNormalized()
                    projectile.holo:setAngles(projectile.direction:getAngle())
                end
                if projectile.direction and projectile.speed then
                    projectile.holo:setVelocity(projectile.direction * projectile.speed)
                end

                local prevPos = projectile.lastPos or pos
                local moved = pos - prevPos
                local direction = moved:getLength() > 0.001 and moved:getNormalized() or (projectile.direction or projectile.holo:getForward())
                local extraTrace = math.max(16, ((projectile.speed or PROJECTILE_SPEED) / 25))
                local hit = trace.line(prevPos, pos + direction * extraTrace, projectile.ignore, MASK.SHOT_HULL)
                projectile.lastPos = pos

                if hit.Hit then
                    explodeProjectile(projectile, hit.HitPos)
                end
            end

            sendUiState(targetPlayer)
        end)

        hook.add("PlayerDeath", "DingusBazookaDeath", function(ply)
            if ply == targetPlayer then
                cleanUp()
            end
        end)

        hook.add("playerDisconnected", "DingusBazookaDisconnect", function(ply)
            if ply == targetPlayer then
                cleanUp()
            end
        end)

        hook.add("removed", "DingusBazookaRemoved", function()
            astrosounds.stop(MAXWELL_PICKUP_THEME)
            removePickupVisuals()
            removeHeldDingus()
            removeMaxwellBomb()

            for _, projectile in ipairs(projectiles) do
                if isValid(projectile.holo) then
                    projectile.holo:remove()
                end
            end
        end)
    else
        local animatedPlayer = nil
        local posedPlayer = nil
        local heldDingusEnt = nil
        local heldDingusHidden = false
        local poseApplied = false
        local poseBones = {}
        local poseBoneCount = 0
        local POSE_TIMER = "DingusBeggingPose"
        local hudLinked = false
        local POSE = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(10, -30, -20),
            ["ValveBiped.Bip01_R_Forearm"] = Angle(0, -70, 0),
            --    ,    :
            ["ValveBiped.Bip01_R_Hand"] = Angle(0, 0, 20), --  90,  0  -90

            ["ValveBiped.Bip01_L_UpperArm"] = Angle(10, -40, -20),
            ["ValveBiped.Bip01_L_Forearm"] = Angle(0, -70, 0),
            --    ,     :
            ["ValveBiped.Bip01_L_Hand"] = Angle(0, 0, 0)  --  -90,  0
        }

        local function getLocalWeaponClass(ply)
            local wep = ply:getActiveWeapon()
            if not isValid(wep) then return "" end
            return string.lower(wep:getClass())
        end

        local function showChat(col, prefix, msg)
            if chat and chat.addText then
                chat.addText(col, prefix, Color(255, 255, 255), msg)
            else
                print(prefix .. msg)
            end
        end

        local function setHudLinked(state)
            if hudLinked == state then return end
            hudLinked = state and true or false
            pcall(enableHud, nil, hudLinked)
        end

        uiSetTitle("")
        uiSetEnabled(false)

        local function shouldPoseDingus(ply)
            return isValid(ply)
                and ply == animatedPlayer
                and ply:isAlive()
                and isHandsWeaponClass(getLocalWeaponClass(ply))
        end

        local function shouldShowLocalUi()
            local ply = player()
            return isValid(ply)
                and ply == animatedPlayer
                and ply:isAlive()
                and isControlWeaponClass(getLocalWeaponClass(ply))
        end

        local function cachePoseBones(ply)
            poseBones = {}
            poseBoneCount = 0
            for boneName, targetAngle in pairs(POSE) do
                local bone = ply:lookupBone(boneName)
                if bone then
                    poseBones[bone] = targetAngle
                    poseBoneCount = poseBoneCount + 1
                end
            end
        end

        local function applyPose(ply)
            if not next(poseBones) then
                cachePoseBones(ply)
            end
            if poseBoneCount ~= POSE_BONE_TARGET_COUNT then
                poseApplied = false
                if posedPlayer == ply then
                    posedPlayer = nil
                end
                return
            end
            for bone, targetAngle in pairs(poseBones) do
                ply:manipulateBoneAngles(bone, targetAngle)
            end
            poseApplied = true
            posedPlayer = ply
        end

        local function resetPose(ply)
            if not isValid(ply) then return end
            if not next(poseBones) then
                cachePoseBones(ply)
            end
            for bone, _ in pairs(poseBones) do
                ply:manipulateBoneAngles(bone, Angle(0, 0, 0))
            end
            poseApplied = false
            if posedPlayer == ply then
                posedPlayer = nil
            end
        end

        local function updateHeldDingusVisibility()
            local ply = player()
            if heldDingusHidden and (not isValid(heldDingusEnt) or not isValid(ply) or ply ~= animatedPlayer) then
                if isValid(heldDingusEnt) and heldDingusEnt.setNoDraw then
                    heldDingusEnt:setNoDraw(false)
                end
                heldDingusHidden = false
                return
            end

            if not isValid(heldDingusEnt) or not isValid(ply) or ply ~= animatedPlayer then return end

            local shouldHide = ply.shouldDrawLocalPlayer and (not ply:shouldDrawLocalPlayer())
            if heldDingusEnt.setNoDraw then
                heldDingusEnt:setNoDraw(shouldHide)
            end
            heldDingusHidden = shouldHide and true or false
        end

        local function tryEquipHands()
            timer.create("DingusBazookaTryEquipHands", 0.15, 12, function()
                local ply = player()
                if not isValid(ply) then return end

                if isControlWeaponClass(getLocalWeaponClass(ply)) then
                    timer.remove("DingusBazookaTryEquipHands")
                    return
                end

                concmd("use none")
                concmd("use hands")
                concmd("use weapon_hands")
            end)
        end

        net.receive(PICKUP_NET, function()
            local enabled = net.readBool()
            net.readEntity(function(ent)
                if posedPlayer and posedPlayer ~= ent and isValid(posedPlayer) then
                    resetPose(posedPlayer)
                end
                poseBones = {}
                animatedPlayer = enabled and ent or nil

                local localPlayer = player()
                if enabled and ent == localPlayer then
                    timer.simple(0.1, function()
                        setHudLinked(true)
                        uiSetEnabled(false)
                    end)
                    uiSetEnabled(false)
                    uiShowEquipHint(6)
                    showChat(Color(255, 180, 80), "[Dingus] ", VERSION .. " by " .. AUTHOR .. " equipped.")
                    showChat(Color(255, 220, 140), "[Dingus] ", "Controls: LMB = shoot Dingus, RMB = dingus volley, E = purr, R = plant Maxwell bomb.")
                    showChat(Color(255, 220, 140), "[Dingus] ", "Use Hands or weapon_cat to control Dingus. Only Hands shows Dingus in your hands.")
                elseif localPlayer and ent ~= localPlayer then
                    setHudLinked(false)
                    uiSetEnabled(false)
                end
            end)
        end)

        net.receive(EQUIP_NET, function()
            tryEquipHands()
        end)

        net.receive(HELD_NET, function()
            local enabled = net.readBool()
            net.readEntity(function(ent)
                if heldDingusHidden and isValid(heldDingusEnt) and heldDingusEnt.setNoDraw then
                    heldDingusEnt:setNoDraw(false)
                end
                heldDingusEnt = enabled and ent or nil
                heldDingusHidden = false
                updateHeldDingusVisibility()
            end)
        end)

        net.receive(UI_NET, function()
            local nextFireAt = net.readFloat()
            local nextSwarmAt = net.readFloat()
            local nextPurrAt = net.readFloat()
            local nextBombAt = net.readFloat()
            local shouldEnable = net.readBool()

            setHudLinked(shouldEnable)
            uiSyncDingus(nextFireAt, nextSwarmAt, nextPurrAt, nextBombAt)
        end)

        timer.create(POSE_TIMER, 0.1, 0, function()
            local target = animatedPlayer
            if shouldPoseDingus(target) then
                applyPose(target)
            elseif poseApplied and isValid(posedPlayer) then
                resetPose(posedPlayer)
            end

            uiSetEnabled(shouldShowLocalUi())
            updateHeldDingusVisibility()
        end)

        hook.add("removed", "DingusBazookaResetPose", function()
            timer.remove(POSE_TIMER)

            if isValid(posedPlayer) then
                resetPose(posedPlayer)
            end
            setHudLinked(false)
            uiSetEnabled(false)
            if heldDingusHidden and isValid(heldDingusEnt) and heldDingusEnt.setNoDraw then
                heldDingusEnt:setNoDraw(false)
            end
        end)
    end
end

return M
