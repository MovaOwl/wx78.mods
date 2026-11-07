-- Клавиши. Настраиваются у каждого игрока свои (client = true в modinfo).
--   * Прыжок к курсору: сервер проверяет место и запускает тот же прыжок, что по ПКМ.
--   * Открыть / закрыть Кодекс: ищем книгу в инвентаре и открываем колесо заклинаний
--     так же, как это делает игра (actions.lua, USESPELLBOOK.pre_action_cb).

local GLOBAL = GLOBAL
local WX1102 = WX1102 -- общая таблица мода из modmain.lua (окружение мода)
local cfg = WX1102.config

if GLOBAL.TheNet:IsDedicated() then
    return
end

local function GetKey(name)
    local value = GetModConfigData(name, true)
    if value == nil then
        value = GetModConfigData(name)
    end
    if value == nil or value == "NONE" then
        return nil
    end
    return GLOBAL.rawget(GLOBAL, value)
end

-- Клавиши работают только за WX-78, только в игре и не во время набора текста.
local function GetPlayerForKeys()
    local player = GLOBAL.ThePlayer
    if not WX1102.IsWX(player) or player.HUD == nil then
        return nil
    end
    if player.HUD:HasInputFocus() then
        return nil
    end
    local screen = GLOBAL.TheFrontEnd:GetActiveScreen()
    if screen == nil or screen.name ~= "HUD" then
        return nil
    end
    return player
end

--------------------------------------------------------------------------

local hop_key = GetKey("key_hop")
if hop_key ~= nil and cfg.hop_enabled then
    GLOBAL.TheInput:AddKeyDownHandler(hop_key, function()
        local player = GetPlayerForKeys()
        if player == nil or not player:HasTag(WX1102.HOP_TAG) then
            return
        end
        local pos = GLOBAL.TheInput:GetWorldPosition()
        if pos == nil then
            return
        end
        SendModRPCToServer(GetModRPC("wx1102", "hop"), pos.x, pos.z)
    end)
end

--------------------------------------------------------------------------

local function IsCodex(item)
    return item ~= nil and item.prefab == "waxwelljournal"
end

local function FindCodex(player)
    local inventory = player.replica.inventory
    if inventory == nil then
        return nil
    end
    local active = inventory:GetActiveItem()
    if IsCodex(active) then
        return active
    end
    for _, item in pairs(inventory:GetItems() or {}) do
        if IsCodex(item) then
            return item
        end
    end
    -- Рюкзак и другие открытые контейнеры.
    for container_inst in pairs(inventory:GetOpenContainers() or {}) do
        local container = container_inst.replica.container
        if container ~= nil then
            for _, item in pairs(container:GetItems() or {}) do
                if IsCodex(item) then
                    return item
                end
            end
        end
    end
    return nil
end

local codex_key = GetKey("key_codex")
if codex_key ~= nil and cfg.codex_enabled then
    GLOBAL.TheInput:AddKeyDownHandler(codex_key, function()
        local player = GetPlayerForKeys()
        if player == nil then
            return
        end
        local hud = player.HUD

        -- Колесо Кодекса уже открыто — закрываем.
        local open_book = hud.GetCurrentOpenSpellBook ~= nil and hud:GetCurrentOpenSpellBook() or nil
        if IsCodex(open_book) then
            hud:CloseSpellWheel()
            return
        end

        local book = FindCodex(player)
        if book == nil or book:HasTag("fueldepleted") then
            return
        end
        local spellbook = book.components.spellbook
        if spellbook == nil or not spellbook:CanBeUsedBy(player) or not spellbook:ShouldOpen(player) then
            return
        end

        local controller = player.components.playercontroller
        if controller ~= nil then
            local isenabled, ishudblocking = controller:IsEnabled()
            if ishudblocking then
                hud:CloseCrafting()
                isenabled = controller:IsEnabled()
            end
            if not isenabled then
                return
            end
        end
        spellbook:OpenSpellBook(player)
    end)
end
