--@name SuperSpeed Serum v3 (Base)
--@author vertihluy
--@shared

--@include https://raw.githubusercontent.com/PEDROWELES/MyStarfallLibs/refs/heads/main/speedtest.lua as speedtest
--@include https://raw.githubusercontent.com/PEDROWELES/MyStarfallLibs/refs/heads/main/speedsound.lua as speedsound

local M = {}

function M.init()
  local SpeedAuth = require("speedtest")
  local astrosounds = require("speedsound")

  if SERVER then
    local targetPlayer = nil
    local enabled = false
    local lastToggle = false

    local authData = SpeedAuth.getCoreSettings(chip())

    if not authData.allowed then
      local owner = chip():getOwner()
      if isValid(owner) then
        owner:printMessage(3, "[SF-Error] " .. (authData.msg or " ."))
        if authData.punish then
          owner:ignite(3)
          sound.play("ambient/creatures/chicken_panic_04.wav", owner:getShootPos(), 100, 130, 1)
          owner:setVelocity(owner:getForward() * -450 + Vector(0, 0, 180))
        end
      end
      chip():remove()
      return
    end

    local baseSpeed = authData.baseSpeed
    local sprintMult = authData.sprintMult

    local serum = nil
    local ring = nil
    local mainTrail = nil
    local lightningTrail = nil

    local EVENT_NET = "superspeed_serum_event_v1"
    local spawnPos = chip():getPos() + Vector(0, 0, 50)

    local function sendEvent(eventType, target, message)
      net.start(EVENT_NET)
      net.writeInt(eventType, 4)
      if message ~= nil then net.writeString(message) end
      if target then net.send(target) else net.send(find.allPlayers()) end
    end

    local function isPlayerInBuildMode(ply)
      if isValid(ply) and ply.isBUILD then
        local res = ply:isBUILD()
        if res == true or res == 1 then return true end
      end
      return false
    end

    local function removeTrails()
      if isValid(mainTrail) then mainTrail:remove() end
      if isValid(lightningTrail) then lightningTrail:remove() end
      mainTrail = nil
      lightningTrail = nil
    end

    local function createTrails()
      if not isValid(targetPlayer) then return end

      if not isValid(mainTrail) then
        mainTrail = hologram.create(targetPlayer:getPos(), Angle(), "models/hunter/misc/sphere025x025.mdl", Vector(0.01))
        if isValid(mainTrail) then
          mainTrail:setParent(targetPlayer)
          mainTrail:setLocalPos(Vector(0, 0, 45))
          mainTrail:setColor(Color(0, 100, 255, 0))
          mainTrail:suppressEngineLighting(true)
          mainTrail:setTrails(350, 0, 28, "trails/laser", Color(0, 150, 255))
        end
      end

      if not isValid(lightningTrail) then
        lightningTrail = hologram.create(targetPlayer:getPos(), Angle(), "models/hunter/misc/sphere025x025.mdl", Vector(0.01))
        if isValid(lightningTrail) then
          lightningTrail:setParent(targetPlayer)
          lightningTrail:setLocalPos(Vector(0, 0, 45))
          lightningTrail:setColor(Color(255, 255, 255, 0))
          lightningTrail:suppressEngineLighting(true)
          lightningTrail:setTrails(35, 0, 10, "trails/electric", Color(120, 220, 255))
        end
      end
    end

    local function cleanUp(ply)
      if isValid(ply) then
        sendEvent(2, nil, ply:getName())
      end

      enabled = false
      targetPlayer = nil
      removeTrails()

      if isValid(serum) then serum:remove() end
      if isValid(ring) then ring:remove() end

      chip():remove()
    end

    serum = prop.create(spawnPos, Angle(0, 0, 0), "models/healthvial.mdl", true)
    if isValid(serum) then
      serum:setRenderMode(2)
      serum:setColor(Color(0, 140, 255, 200))
      serum:setMaterial("models/debug/debugwhite")

      local light = hologram.create(spawnPos, Angle(), "models/holograms/hq_sphere.mdl", Vector(1.5))
      if isValid(light) then
        light:setParent(serum)
        light:setMaterial("models/debug/debugwhite")
        light:setRenderMode(3)
        light:setColor(Color(100, 180, 255, 12))
        light:suppressEngineLighting(true)
      end

      local floorPos = chip():getPos() + Vector(0, 0, 1)
      ring = hologram.create(floorPos, Angle(0, 0, 0), "models/holograms/hq_torus.mdl", Vector(3, 3, 0.1))
      if isValid(ring) then
        ring:setMaterial("models/debug/debugwhite")
        ring:setRenderMode(3)
        ring:setColor(Color(0, 150, 255, 45))
        ring:suppressEngineLighting(true)
      end

      hook.add("think", "SuperSpeedSerumAnimation", function()
        if not isValid(serum) then
          if isValid(ring) then ring:remove() end
          hook.remove("think", "SuperSpeedSerumAnimation")
          return
        end

        local time = timer.curtime()
        local hoverOffset = Vector(0, 0, math.sin(time * 2) * 3)
        serum:setPos(spawnPos + hoverOffset)
        serum:setAngles(Angle(0, time * 45, 0))

        if isValid(ring) then
          local wave = 3 + math.sin(time * 4) * 0.3
          ring:setAngles(Angle(0, time * -45, 0))
          ring:setScale(Vector(wave, wave, 0.05))
        end
      end)
    end

    hook.add("playerUse", "SuperSpeedSerumInjection", function(ply, ent)
      if ent == serum and not targetPlayer then
        if isPlayerInBuildMode(ply) then
          sendEvent(0, ply)
          return
        end

        targetPlayer = ply
        enabled = false
        lastToggle = false

        if isValid(serum) then serum:remove() end
        if isValid(ring) then ring:remove() end

        sendEvent(1, nil, ply:getName())
        sendEvent(3, ply)
      end
    end)

    local isCurrentlyMoving = false

    hook.add("think", "SuperSpeedSerumThink", function()
      if not targetPlayer then return end
      if not isValid(targetPlayer) then cleanUp(nil) return end
      if not targetPlayer:isAlive() then cleanUp(targetPlayer) return end
      if isPlayerInBuildMode(targetPlayer) then cleanUp(targetPlayer) return end

      local pressed = targetPlayer:keyDown(IN_KEY.USE)
      if pressed and not lastToggle then
        enabled = not enabled
        if enabled then
          createTrails()
        else
          removeTrails()
          if isCurrentlyMoving then
            isCurrentlyMoving = false
            astrosounds.play("superspeed_stop", Vector(0,0,30), targetPlayer) --
          end
        end
      end
      lastToggle = pressed

      if not enabled then removeTrails() return end

      local eye = targetPlayer:getEyeAngles()
      local forward = eye:getForward()
      local right = eye:getRight()
      local move = Vector()

      if targetPlayer:keyDown(IN_KEY.FORWARD) then move = move + forward end
      if targetPlayer:keyDown(IN_KEY.BACK) then move = move - forward end
      if targetPlayer:keyDown(IN_KEY.MOVELEFT) then move = move - right end
      if targetPlayer:keyDown(IN_KEY.MOVERIGHT) then move = move + right end

      move.z = 0

      -- :
      if move:getLength() <= 0 then
        removeTrails()
        if isCurrentlyMoving then
          isCurrentlyMoving = false
          astrosounds.play("superspeed_stop", Vector(0,0,30), targetPlayer) --
        end
        return
      end

      --
      if not isCurrentlyMoving then
        isCurrentlyMoving = true
        astrosounds.play("superspeed_start", Vector(0,0,30), targetPlayer) --
      end

      createTrails()
      move = move:getNormalized()

      if targetPlayer:keyDown(IN_KEY.ATTACK) then
        local pos = targetPlayer:getPos()
        local min = pos + move * 40 - Vector(20, 20, 10)
        local max = pos + move * 80 + Vector(20, 20, 70)
        local victims = find.inBox(min, max)

        for _, ent in ipairs(victims) do
          if ent ~= targetPlayer and isValid(ent) and ent:getHealth() > 0 then
            if ent:isPlayer() then
              targetPlayer:emitSound("physics/body/body_medium_break2.wav", 80, 100)
              targetPlayer:emitSound("physics/flesh/flesh_impact_bullet3.wav", 75, 120)
              targetPlayer:emitSound("player/bhit_helmet-1.wav", 90, 110)
              game.blastDamage(ent:getPos(), 20, 500)
              local velocityPermitted = hasPermission("entities.setVelocity", ent)
              if velocityPermitted then ent:setVelocity(move * 2000) end
              break
            elseif ent:isNPC() or ent:isValidPhys() then
              targetPlayer:emitSound("physics/body/body_medium_break2.wav", 80, 100)
              targetPlayer:emitSound("physics/flesh/flesh_impact_bullet3.wav", 75, 120)
              local damagePermitted = hasPermission("entities.applyDamage", ent)
              if damagePermitted then ent:applyDamage(500, nil, targetPlayer, DAMAGE.CRUSH) end
              local velocityPermitted = hasPermission("entities.setVelocity", ent)
              if velocityPermitted then
                local phys = ent:getPhysicsObject()
                if isValid(phys) then phys:setVelocity(move * 1000) else ent:setVelocity(move * 1500) end
              end
              break
            end
          end
        end
      end

      local speed = baseSpeed
      if targetPlayer:keyDown(IN_KEY.SPEED) then speed = speed * sprintMult end

      local desired = move * speed
      local vel = targetPlayer:getVelocity()
      local push = desired - Vector(vel.x, vel.y, 0)
      targetPlayer:setVelocity(push)
    end)

    hook.add("PlayerDeath", "SuperSpeedSerumDeath", function(ply)
      if ply == targetPlayer then cleanUp(ply) end
    end)

    hook.add("playerDisconnected", "SuperSpeedSerumDisconnect", function(ply)
      if ply == targetPlayer then cleanUp(ply) end
    end)

    hook.add("removed", "SuperSpeedSerumCleanup", function()
      removeTrails()
    end)

  else
    net.receive("superspeed_serum_event_v1", function()
      local eventType = net.readInt(4)
      local text = (eventType == 1 or eventType == 2) and net.readString() or ""

      local function showChat(col, prefix, msg)
        if chat and chat.addText then
          chat.addText(col, prefix, Color(255, 255, 255), msg)
        else
          print(prefix .. msg)
        end
      end

      if eventType == 1 then
        showChat(Color(0, 170, 255), "[Vought News] ", text .. " has accepted Serum V! The speed demon is loose.")
      elseif eventType == 2 then
        showChat(Color(255, 50, 0), "[Vought News] ", text .. " has died and lost the power of Compound V.")
      elseif eventType == 0 then
        showChat(Color(255, 0, 0), "[Vought] ", "Error! Cannot accept serum in Build Mode.")
      elseif eventType == 3 then
        showChat(Color(120, 220, 255), "[Vought] ", "You injected V. Press E to toggle super speed. Hold Shift to sprint. LMB rams targets.")
      end
    end)
  end
end

return M
