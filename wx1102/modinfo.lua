name = "wx1102"
description = [[WX-78 получает:
• прыжок Вортокса (по ПКМ, по клавише и через карту) — бесплатно;
• Кодекс Умбра Максвелла в стартовом инвентаре — бесплатно, до 6 слуг;
• крафт без станций — ресурсы тратятся как обычно.

Всё работает только для WX-78. Остальные персонажи играют как обычно.]]
author = "MovaOwl"
version = "0.1.2"

api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

-- Прыжок и меню крафта работают и на клиенте, поэтому мод нужен всем игрокам.
all_clients_require_mod = true
client_only_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "wx78", "wx1102" }

local function OnOff(default)
    return {
        { description = "Вкл", data = true },
        { description = "Выкл", data = false },
    }, default
end

-- В modinfo.lua нет стандартной библиотеки (string, ipairs и т.д.), только чистый Lua.
local KEY_NAMES = {
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
}
local KEYS = {
    { description = "Нет", data = "NONE" },
}
for i = 1, #KEY_NAMES do
    KEYS[#KEYS + 1] = { description = KEY_NAMES[i], data = "KEY_" .. KEY_NAMES[i] }
end

local function Toggle(name, label, hover, default)
    local options, def = OnOff(default)
    return { name = name, label = label, hover = hover, options = options, default = def }
end

local function Header(label)
    return { name = "", label = label, hover = "", options = { { description = "", data = 0 } }, default = 0 }
end

configuration_options =
{
    Header("Прыжок Вортокса"),
    Toggle("hop_enabled", "Прыжок", "WX-78 умеет прыгать, как Вортокс. Бесплатно.", true),
    Toggle("hop_rmb", "Прыжок по ПКМ", "Прыгать правой кнопкой мыши по земле.", true),
    Toggle("hop_map", "Прыжок через карту", "Прыгать в любое открытое место на карте. Бесплатно.", true),

    Header("Кодекс Умбра"),
    Toggle("codex_enabled", "Кодекс Умбра", "WX-78 читает Кодекс Максвелла. Заклинания бесплатны, до 6 слуг.", true),
    Toggle("codex_starting", "Кодекс в начале игры", "Новый WX-78 появляется с Кодексом в инвентаре.", true),

    Header("Крафт без станций"),
    Toggle("craft_stations", "Станции", "Рецепты станций (наука, магия, древние, кузницы, картография и т.д.) доступны везде. Ресурсы тратятся.", true),
    Toggle("craft_shops", "Магазины", "Товары Отшельницы, Короля кроликов, ярмарки и т.д. доступны везде. Цена та же.", true),
    Toggle("craft_events", "Ивентовые станции", "Подношения «Года …», Зимний пир, Хэллоуин. Рецепты появляются, только когда ивент идёт.", true),

    Header("Клавиши (у каждого игрока свои)"),
    {
        name = "key_hop",
        label = "Прыжок к курсору",
        hover = "Прыгнуть туда, где стоит курсор мыши.",
        options = KEYS,
        default = "KEY_Z",
        client = true,
    },
    {
        name = "key_codex",
        label = "Открыть Кодекс",
        hover = "Открыть или закрыть Кодекс Умбра из инвентаря.",
        options = KEYS,
        default = "KEY_X",
        client = true,
    },
}
