-- Trickster: новый персонаж-бабочка, который перевоплощается в любого персонажа DST.
-- Устройство и решения — в docs/TRANSFORM.md.

local GLOBAL = GLOBAL
local STRINGS = GLOBAL.STRINGS

local function Cfg(name, default)
    local v = GetModConfigData(name)
    if v == nil then
        return default
    end
    return v
end

-- Общая таблица мода. Живёт в окружении мода (env), а не в GLOBAL: там строгий режим
-- (scripts/strict.lua). Части мода подключаются через modimport и видят её.
TRICKSTER = {}
TRICKSTER.BASE = "trickster"          -- префаб бабочки
TRICKSTER.TAG_BASED = "trickster_based" -- у любого облика игрока, чей базовый облик — бабочка
TRICKSTER.config =
{
    butterfly_health = Cfg("butterfly_health", 50),
}

-- Облики в колесе: бабочка, все персонажи игры, Вонки.
function TRICKSTER.GetForms()
    local forms = { TRICKSTER.BASE }
    for _, prefab in ipairs(GLOBAL.DST_CHARACTERLIST) do
        table.insert(forms, prefab)
    end
    table.insert(forms, "wonkey")
    return forms
end

--------------------------------------------------------------------------
-- Персонаж

PrefabFiles =
{
    "trickster",
    "trickster_none",
}

Assets =
{
    Asset("IMAGE", "images/saveslot_portraits/trickster.tex"),
    Asset("ATLAS", "images/saveslot_portraits/trickster.xml"),

    Asset("IMAGE", "images/selectscreen_portraits/trickster.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/trickster.xml"),
    Asset("IMAGE", "images/selectscreen_portraits/trickster_silho.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/trickster_silho.xml"),

    Asset("IMAGE", "bigportraits/trickster.tex"),
    Asset("ATLAS", "bigportraits/trickster.xml"),
    Asset("IMAGE", "bigportraits/trickster_none.tex"),
    Asset("ATLAS", "bigportraits/trickster_none.xml"),

    Asset("IMAGE", "images/map_icons/trickster.tex"),
    Asset("ATLAS", "images/map_icons/trickster.xml"),

    Asset("IMAGE", "images/avatars/avatar_trickster.tex"),
    Asset("ATLAS", "images/avatars/avatar_trickster.xml"),
    Asset("IMAGE", "images/avatars/avatar_ghost_trickster.tex"),
    Asset("ATLAS", "images/avatars/avatar_ghost_trickster.xml"),
    Asset("IMAGE", "images/avatars/self_inspect_trickster.tex"),
    Asset("ATLAS", "images/avatars/self_inspect_trickster.xml"),

    Asset("IMAGE", "images/crafting_menu_avatars/avatar_trickster.tex"),
    Asset("ATLAS", "images/crafting_menu_avatars/avatar_trickster.xml"),

    Asset("IMAGE", "images/names_trickster.tex"),
    Asset("ATLAS", "images/names_trickster.xml"),
    Asset("IMAGE", "images/names_gold_trickster.tex"),
    Asset("ATLAS", "images/names_gold_trickster.xml"),
}

AddMinimapAtlas("images/map_icons/trickster.xml")

STRINGS.CHARACTER_TITLES.trickster = "Трикстер"
STRINGS.CHARACTER_NAMES.trickster = "Бабочка"
STRINGS.CHARACTER_DESCRIPTIONS.trickster = "*Перевоплощается в любого персонажа\n*Не голодает\n*Хрупкая"
STRINGS.CHARACTER_QUOTES.trickster = "\"Кем я буду сегодня?\""
STRINGS.CHARACTER_SURVIVABILITY.trickster = "Хрупкая"
STRINGS.CHARACTER_ABOUTME.trickster = "Никто не знает, как выглядит Трикстер на самом деле. Говорят, это просто бабочка."
STRINGS.CHARACTER_BIOS.trickster =
{
    { title = "День рождения", desc = "Каждый раз новый" },
    { title = "Любимая еда", desc = "Нектар" },
}
STRINGS.NAMES.TRICKSTER = "Бабочка"
STRINGS.CHARACTERS.TRICKSTER = GLOBAL.require("speech_wilson")

GLOBAL.TUNING.TRICKSTER_HEALTH = TRICKSTER.config.butterfly_health
GLOBAL.TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.TRICKSTER = {}

-- Превью в меню выбора: бабочка на своём банке анимаций, призрак — как у всех.
AddModCharacter("trickster", "NEUTRAL",
{
    { type = "normal_skin", anim_bank = "butterfly", idle_anim = "idle_flight_loop", scale = 1.6 },
    { type = "ghost_skin", anim_bank = "ghost", idle_anim = "idle", scale = 0.75, offset = { 0, -25 } },
})

--------------------------------------------------------------------------
-- Части мода

modimport("main/items.lua")      -- метка «особых предметов» облика
modimport("main/forms.lua")      -- перевоплощение
modimport("main/skills.lua")     -- древо навыков облика
modimport("main/wheel.lua")      -- колесо обликов и клавиша
