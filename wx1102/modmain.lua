-- wx1102: WX-78 + прыжок Вортокса + Кодекс Умбра + крафт без станций.
-- Устройство мода и решения — в docs/DESIGN.md.

local function Cfg(name, default)
    local v = GetModConfigData(name)
    if v == nil then
        return default
    end
    return v
end

-- Общие настройки и утилиты для всех частей мода. Части подключаются через
-- modimport и видят эту таблицу как глобальную переменную WX1102.
GLOBAL.WX1102 = GLOBAL.WX1102 or {}
local WX1102 = GLOBAL.WX1102
WX1102.TAG = "wx1102"                -- есть у WX-78, когда мод включён
WX1102.HOP_TAG = "wx1102_hop"        -- WX-78 умеет прыгать
WX1102.CODEX_TAG = "wx1102_codex"    -- WX-78 колдует Кодексом бесплатно

WX1102.config =
{
    hop_enabled = Cfg("hop_enabled", true),
    hop_rmb = Cfg("hop_rmb", true),
    hop_map = Cfg("hop_map", true),
    codex_enabled = Cfg("codex_enabled", true),
    codex_starting = Cfg("codex_starting", true),
    craft_stations = Cfg("craft_stations", true),
    craft_shops = Cfg("craft_shops", true),
    craft_events = Cfg("craft_events", true),
}

-- Наш ли это WX-78 (а не другой персонаж).
function WX1102.IsWX(inst)
    return inst ~= nil and inst.prefab == "wx78" and inst:HasTag(WX1102.TAG)
end

-- Анимация прыжка (anim/wortox_portal.zip) входит в ассеты Вортокса, а игра загружает
-- ассеты всех персонажей. Отдельно её не подключаем.
Assets = {}

PrefabFiles = {}

AddPrefabPostInit("wx78", function(inst)
    inst:AddTag(WX1102.TAG)
end)

if WX1102.config.hop_enabled then
    modimport("main/hop.lua")
end

if WX1102.config.codex_enabled then
    modimport("main/codex.lua")
end

if WX1102.config.craft_stations or WX1102.config.craft_shops or WX1102.config.craft_events then
    modimport("main/crafting.lua")
end

modimport("main/keybinds.lua")
