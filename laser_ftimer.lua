--@name Fractional timers
--@author AstricUnion
--@shared

-- TODO: Refactor FTimer class

local instances = {}

---@class FTimer
---@field loops number
---@field duration number
---@field paused boolean
---@field fractions table
---@field update_func thread
local FTimer =  {}
FTimer.__index = FTimer

---Fractional timer object.
---@param duration number Duration of timer
---@param loops number Time of loops in this timer. -1 to infinite looping
---@param fractions table Table with fractions. 
---                 As index you can use float number from 0 to 1 or range (as example, ["0.8-0.9"])
---                 As value you should use function. 
---                 Range function has 3 arguments (timer, fraction and relative fraction)
---                 Float function has 1 argument (timer)
---@return FTimer? object
function FTimer:new(duration, loops, fractions)
    -- Check fractions
    for index, _ in pairs(fractions) do
        if isnumber(index) and (index > 1 or index < 0) then
            throw(tostring(index) .. " in fractions is more than 1 or less than 0")
            return
        elseif isstring(index) then
            local range = string.split(index, "-")
            if #range ~= 2 then
                throw("Range is invalid!")
                return
            end
            for _, v in ipairs(range) do
                local num = tonumber(v)
                if !num then
                    throw("Range is invalid! One of values is not number")
                    return
                end
                if num > 1 or num < 0 then
                    throw("Range is invalid! One of values is more than 1 or less than 0")
                    return
                end
            end
            if tonumber(range[1]) >= tonumber(range[2]) then
                throw("Range is invalid! \"From\" value is more than \"to\" value")
                return
            end
        end
    end
    local timer = setmetatable(
        {
            loops = loops,
            duration = duration,
            paused = false,
            fractions = fractions,
            update_func = nil
        },
        FTimer
    )
    local func = coroutine.create(FTimer.update)
    coroutine.resume(func, timer)
    timer.update_func = func
    table.insert(instances, timer)
    return timer
end


---Remove timer
function FTimer:remove()
    table.removeByValue(instances, self)
    setmetatable(self, nil)
end


---Pause timer
function FTimer:pause()
    self.paused = true
end


---Starts timer
function FTimer:start()
    self.paused = false
end


---Update function, uses internally. Don't use it in your code
function FTimer.update(self)
    local ticks = 0
    local last_tick = 0
    while self.loops ~= 0 do
        coroutine.yield() -- Yielding, to pause until resume
        local time = ticks * game.getTickInterval() -- Gets ticks
        local process = math.timeFraction(0, self.duration, time) -- Get fraction of duration
        -- New loop
        if time >= self.duration then
            ticks = 0
            self.loops = self.loops - 1
        end
        -- Get fractions
        for second, callback in pairs(self.fractions) do
            -- If fraction with one number
            if isnumber(second) then
                if process >= second and last_tick <= second then
                    callback(self)
                end
            -- If fraction with range
            elseif isstring(second) then
                local dur = string.split(second, '-')
                local fr_start, fr_end = tonumber(dur[1]), tonumber(dur[2])
                if process >= fr_start and process <= fr_end then
                    local relative = math.timeFraction(fr_start, fr_end, process)
                    callback(self, process, relative)
                end
            end
        end
        last_tick = process
        ticks = ticks + 1
    end
end

hook.add("Tick", "fractionalTimers", function()
    for _, ftimer in ipairs(instances) do
        if !ftimer.paused then
            if coroutine.status(ftimer.update_func) == "dead" then
                ftimer:remove()
                continue
            end
            coroutine.resume(ftimer.update_func, ftimer)
        end
    end
end)


return FTimer
