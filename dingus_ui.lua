--@name Dingus Cute UI v2 - pixel battery
--@author vertihluy
--@client

local ui = {}

local fontTitle = render.createFont("Terminal", 28, 700, false, false, false, false, 0, false, 0)
local fontBody = render.createFont("Terminal", 18, 600, false, false, false, false, 0, false, 0)
local fontTiny = render.createFont("Small Fonts", 18, 400, false, false, false, false, 0, false, 0)
local fontFace = render.createFont("Consolas", 22, 700, true, false, false, false, 0, true, 0)

local PANEL_BG = Color(34, 14, 33, 205)
local PANEL_BG_INNER = Color(59, 21, 56, 220)
local PANEL_BORDER = Color(255, 130, 212, 255)
local PANEL_BORDER_SOFT = Color(255, 198, 236, 255)
local TEXT_MAIN = Color(255, 228, 246, 255)
local TEXT_DIM = Color(255, 183, 229, 230)
local BAR_FILL = Color(255, 114, 194, 255)
local BAR_FILL_ALT = Color(255, 164, 222, 255)
local BAR_READY = Color(255, 238, 248, 255)
local BAR_BG = Color(88, 36, 85, 255)
local BAR_OFF = Color(57, 22, 54, 255)

local abilities = {
    shot = { id = "shot", key = "LMB", label = "АТАКА", cooldown = 0.9, readyAt = 0 },
    volley = { id = "volley", key = "RMB", label = "УЛЬТА", cooldown = 3.2, readyAt = 0 },
    purr = { id = "purr", key = "E", label = "МУР :3", cooldown = 1.8, readyAt = 0 },
    bomb = { id = "bomb", key = "R", label = "ДОП.", cooldown = 1.2, readyAt = 0 },
}

local order = { "shot", "volley", "purr", "bomb" }
local enabled = true
local title = "ДИНГУС"
local face = "(＾• ω •＾)"
local promptText = nil
local promptExpire = 0

local function now()
    return timer.curtime()
end

local function clamp01(value)
    return math.max(0, math.min(1, value))
end

local function getPercent(entry)
    if entry.cooldown <= 0 then return 1 end
    return clamp01(1 - math.max(entry.readyAt - now(), 0) / entry.cooldown)
end

local function getTimeLeft(entry)
    return math.max(entry.readyAt - now(), 0)
end

local function drawPanel(x, y, w, h)
    render.setColor(PANEL_BG)
    render.drawRect(x, y, w, h)
    render.setColor(PANEL_BG_INNER)
    render.drawRect(x + 4, y + 4, w - 8, h - 8)
    render.setColor(PANEL_BORDER_SOFT)
    render.drawRect(x + 4, y + 4, w - 8, 2)
    render.setColor(PANEL_BORDER)
    render.drawRectOutline(x, y, w, h, 2)
end

local function formatTime(seconds)
    if seconds <= 0 then
        return "ГОТОВО"
    end
    return string.format("%.3fs", seconds)
end

local function drawBattery(x, y, w, h, percent, fillColor)
    local segments = 10
    local nubW = 6
    local innerPad = 4
    local segmentGap = 3
    local usableW = w - nubW - innerPad * 2
    local segmentW = math.floor((usableW - ((segments - 1) * segmentGap)) / segments)
    local filled = math.floor(clamp01(percent) * segments + 0.0001)

    render.setColor(PANEL_BORDER)
    render.drawRectOutline(x, y, w, h, 2)
    render.drawRect(x + w, y + math.floor(h * 0.32), nubW, math.floor(h * 0.36))

    for i = 1, segments do
        local segX = x + innerPad + ((i - 1) * (segmentW + segmentGap))
        local color = i <= filled and fillColor or BAR_OFF
        render.setColor(color)
        render.drawRect(segX, y + innerPad, segmentW, h - innerPad * 2)
    end
end

local function drawAsciiCat(screenW)
    local x = 26
    local y = 24

    render.setFont(fontTitle)
    render.setColor(TEXT_MAIN)
    render.drawSimpleText(x, y, title, TEXT_ALIGN.LEFT)

    render.setFont(fontTiny)
    render.setColor(TEXT_DIM)
    render.drawSimpleText(x, y + 24, "by вертихлюй", TEXT_ALIGN.LEFT)

    render.setFont(fontFace)
    render.setColor(TEXT_MAIN)
    render.drawSimpleText(x, y + 48, face, TEXT_ALIGN.LEFT)
end

local function drawCooldowns(screenW, screenH)
    local panelW = 384
    local panelH = 164
    local x = screenW - panelW - 26
    local y = screenH - panelH - 26

    drawPanel(x, y, panelW, panelH)

    for index, id in ipairs(order) do
        local entry = abilities[id]
        local percent = getPercent(entry)
        local timeLeft = getTimeLeft(entry)
        local rowY = y + 18 + ((index - 1) * 35)
        local fillColor = percent >= 1 and BAR_READY or (index % 2 == 0 and BAR_FILL_ALT or BAR_FILL)

        render.setFont(fontTiny)
        render.setColor(TEXT_DIM)
        render.drawSimpleText(x + 16, rowY, entry.key, TEXT_ALIGN.LEFT)

        render.setColor(TEXT_MAIN)
        render.drawSimpleText(x + 56, rowY, entry.label:upper(), TEXT_ALIGN.LEFT)

        drawBattery(x + 144, rowY - 2, 170, 20, percent, fillColor)

        render.setFont(fontBody)
        render.setColor(percent >= 1 and BAR_READY or TEXT_MAIN)
        render.drawSimpleText(x + panelW - 16, rowY - 4, formatTime(timeLeft), TEXT_ALIGN.RIGHT)
    end
end

local function drawPrompt(screenW, screenH)
    if not promptText or promptExpire <= now() then return end

    local alphaFrac = math.min(promptExpire - now(), 1)
    local alpha = math.floor(255 * math.max(alphaFrac, 0))
    local panelW = 560
    local panelH = 34
    local x = math.floor((screenW - panelW) * 0.5)
    local y = screenH - 86

    render.setColor(Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, math.floor(alpha * 0.82)))
    render.drawRect(x, y, panelW, panelH)
    render.setColor(Color(PANEL_BORDER.r, PANEL_BORDER.g, PANEL_BORDER.b, alpha))
    render.drawRectOutline(x, y, panelW, panelH, 2)

    render.setFont(fontTiny)
    render.setColor(Color(TEXT_MAIN.r, TEXT_MAIN.g, TEXT_MAIN.b, alpha))
    render.drawSimpleText(screenW * 0.5, y + 10, promptText, TEXT_ALIGN.CENTER)
end

function ui.setEnabled(state)
    enabled = state and true or false
end

function ui.setTitle(newTitle)
    title = tostring(newTitle or title)
end

function ui.defineAbility(id, key, label, cooldown)
    if not id then return end
    abilities[id] = abilities[id] or {}
    abilities[id].id = id
    abilities[id].key = key or abilities[id].key or "?"
    abilities[id].label = label or abilities[id].label or id
    abilities[id].cooldown = cooldown or abilities[id].cooldown or 1
    abilities[id].readyAt = abilities[id].readyAt or 0
end

function ui.setCooldown(id, readyAt, cooldown)
    local entry = abilities[id]
    if not entry then return end
    entry.readyAt = readyAt or 0
    if cooldown then
        entry.cooldown = cooldown
    end
end

function ui.use(id, cooldown)
    local entry = abilities[id]
    if not entry then return end
    entry.readyAt = now() + (cooldown or entry.cooldown or 0)
end

function ui.setCooldowns(state)
    if not state then return end
    for id, data in pairs(state) do
        if abilities[id] then
            if data.readyAt then
                abilities[id].readyAt = data.readyAt
            end
            if data.cooldown then
                abilities[id].cooldown = data.cooldown
            end
        end
    end
end

function ui.syncDingus(nextFire, nextSwarm, nextPurr, nextBomb)
    ui.setCooldown("shot", nextFire, abilities.shot.cooldown)
    ui.setCooldown("volley", nextSwarm, abilities.volley.cooldown)
    ui.setCooldown("purr", nextPurr, abilities.purr.cooldown)
    ui.setCooldown("bomb", nextBomb, abilities.bomb.cooldown)
end

function ui.showPrompt(text, duration)
    promptText = tostring(text or "")
    promptExpire = now() + (duration or 5)
end

function ui.showEquipHint(duration)
    ui.showPrompt("Чтобы взять кота Дингуса: Q > Оружие > Прочее > Hands", duration or 6)
end

local function drawCuteUi()
    local screenW, screenH = render.getGameResolution()
    if not screenW or not screenH then return end

    drawPrompt(screenW, screenH)
    if not enabled then return end

    drawAsciiCat(screenW)
    drawCooldowns(screenW, screenH)
end

hook.add("DrawHUD", "dingus_cute_ascii_ui", drawCuteUi)

return ui
