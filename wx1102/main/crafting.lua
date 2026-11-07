-- Крафт без станций для WX-78. Ресурсы тратятся как обычно.
--
-- Как устроено в игре (components/builder.lua):
--   * Вдали от станций уровень каждой ветки технологий = бонус персонажа
--     (поля builder.<ветка>_bonus) — для ВСЕХ веток (EvaluateTechTrees, KnowsRecipe).
--   * Рядом со станцией уровень = уровень станции + бонус, но бонус прибавляется только
--     для 5 веток из TechTree.BONUS_TECH (наука, магия, древние, мореходство, болотный дёрн).
--     Без доработки рядом с научной машиной пропадали бы картография, кузницы и т.д.
--   * Итоговые уровни сервер сам отправляет клиенту (builder_replica:SetTechTrees),
--     поэтому меню крафта у игрока не серое.
--
-- Что делаем:
--   * Ставим WX бонус до максимального уровня каждой нужной ветки. Уровень берём из самих
--     рецептов игры (так мод сам подстроится под обновления).
--   * Рецепты по чертежам (уровень 10) и ивентовые рецепты науки 10 не трогаем: иначе
--     открылись бы все чертежи.
--   * На время пересчёта технологий у WX расширяем список BONUS_TECH нашими ветками.

local GLOBAL = GLOBAL
local TechTree = GLOBAL.require("techtree")
local WX1102 = GLOBAL.WX1102
local cfg = WX1102.config

-- Чем выше 9, тем это чертёж или ивент без станции — не открываем.
local MAX_REAL_LEVEL = 9

local GROUP_OF =
{
    -- магазины
    HERMITCRABSHOP = "craft_shops",
    RABBITKINGSHOP = "craft_shops",
    WANDERINGTRADERSHOP = "craft_shops",

    -- ивенты
    PERDOFFERING = "craft_events",
    WARGOFFERING = "craft_events",
    PIGOFFERING = "craft_events",
    CARRATOFFERING = "craft_events",
    BEEFOFFERING = "craft_events",
    CATCOONOFFERING = "craft_events",
    RABBITOFFERING = "craft_events",
    DRAGONOFFERING = "craft_events",
    WORMOFFERING = "craft_events",
    KNIGHTOFFERING = "craft_events",
    MADSCIENCE = "craft_events",
    WINTERSFEASTCOOKING = "craft_events",
    CARNIVAL_PRIZESHOP = "craft_events",
    CARNIVAL_HOSTSHOP = "craft_events",
    CARNIVAL_GOLFPROPS = "craft_events",

    -- чужие персональные ветки: Уэббер, Уикерботтом, Уорли
    SPIDERCRAFT = false,
    BOOKCRAFT = false,
    FOODPROCESSING = false,
    -- устаревшая ветка, все рецепты переехали в CELESTIAL
    MOON_ALTAR = false,
}

local function IsWanted(tech)
    local group = GROUP_OF[tech]
    if group == false then
        return false
    end
    return cfg[group or "craft_stations"] == true
end

local levels_cache = nil
local function GetLevels()
    if levels_cache ~= nil then
        return levels_cache
    end
    local wanted = {}
    for _, tech in ipairs(TechTree.AVAILABLE_TECH) do
        if IsWanted(tech) then
            wanted[tech] = true
        end
    end
    local levels = {}
    for _, recipe in pairs(GLOBAL.AllRecipes) do
        if recipe.level ~= nil then
            for tech, lvl in pairs(recipe.level) do
                if wanted[tech] and type(lvl) == "number" and lvl > 0 and lvl <= MAX_REAL_LEVEL
                    and lvl > (levels[tech] or 0)
                then
                    levels[tech] = lvl
                end
            end
        end
    end
    levels_cache = levels
    return levels
end

local function BonusKey(tech)
    return (TechTree.AVAILABLE_TECH_BONUS ~= nil and TechTree.AVAILABLE_TECH_BONUS[tech]) or (string.lower(tech) .. "_bonus")
end

AddPrefabPostInit("wx78", function(inst)
    if not GLOBAL.TheWorld.ismastersim then
        return
    end
    local builder = inst.components.builder
    if builder == nil then
        return
    end

    local levels = GetLevels()

    -- Бонусы. Для 5 штатных веток поле — это сеттер, он сам синхронизирует клиента.
    local extended_bonus_tech = {}
    local in_list = {}
    for _, tech in ipairs(TechTree.BONUS_TECH) do
        table.insert(extended_bonus_tech, tech)
        in_list[tech] = true
    end
    for tech, lvl in pairs(levels) do
        local key = BonusKey(tech)
        if (builder[key] or 0) < lvl then
            builder[key] = lvl
        end
        if not in_list[tech] then
            table.insert(extended_bonus_tech, tech)
            in_list[tech] = true
        end
    end

    -- Рядом со станцией игра прибавляет бонус только для TechTree.BONUS_TECH.
    -- На время пересчёта у WX подставляем расширенный список.
    local _EvaluateTechTrees = builder.EvaluateTechTrees
    function builder:EvaluateTechTrees(...)
        local saved = TechTree.BONUS_TECH
        TechTree.BONUS_TECH = extended_bonus_tech
        local result = { GLOBAL.pcall(_EvaluateTechTrees, self, ...) }
        TechTree.BONUS_TECH = saved
        if not result[1] then
            GLOBAL.error(result[2], 0)
        end
        return GLOBAL.unpack(result, 2, GLOBAL.table.maxn(result))
    end
end)
