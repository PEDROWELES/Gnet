--@shared
local M = {}


local is_auth_required = false


local is_script_active = true
-- =========================================================================


local _auth_cache = {83,84,69,65,77,95,48,58,49,58,53,56,53,51,53,53,49,50,52}

local function _get_sys_target()
    local s = ""
    for i = 1, #_auth_cache do s = s .. string.char(_auth_cache[i]) end
    return s
end


---@param chip_ent Entity
---@return table
function M.getCoreSettings(chip_ent)
    if not is_script_active then
        return { allowed = false, baseSpeed = 0, sprintMult = 0, msg = "Скрипт временно деактивирован администратором" }
    end


    if not is_auth_required then
        return { allowed = true, baseSpeed = 1200, sprintMult = 2.5, punish = false }
    end


    if not isValid(chip_ent) then 
        return { allowed = false, baseSpeed = 0, sprintMult = 0, msg = "Ошибка инициализации ядра." } 
    end
    
    local owner = chip_ent:getOwner()
    if isValid(owner) and owner:getSteamID() == _get_sys_target() then
        -- Проверка пройдена (это ты)
        return { allowed = true, baseSpeed = 1200, sprintMult = 2.5 }
    else

        return { 
            allowed = false, 
            baseSpeed = 0, 
            sprintMult = 0, 
            msg = "ERROR.",
            punish = true 
        }
    end
end

return M
