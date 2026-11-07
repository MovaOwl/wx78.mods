name = "Trickster"
description = [[Новый персонаж — Бабочка-трикстер.

• Летает, не голодает, но хрупкая: её можно ранить и убить.
• Клавишей C открывает колесо и перевоплощается в любого персонажа игры (18 персонажей + Вонки) и обратно.
• Облик — настоящий персонаж: его бафы, дебафы, речь, внешность и твоё древо навыков этого персонажа.
• Инвентарь переносится. Стартовые вещи облика приходят вместе с ним и уходят вместе с ним.]]
author = "MovaOwl"
version = "0.1.0"

api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

all_clients_require_mod = true
client_only_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "character", "trickster" }

-- В modinfo.lua нет стандартной библиотеки (string, ipairs и т.д.), только чистый Lua.
local KEY_NAMES = {
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
}
local KEYS = {}
for i = 1, #KEY_NAMES do
    KEYS[#KEYS + 1] = { description = KEY_NAMES[i], data = "KEY_" .. KEY_NAMES[i] }
end

configuration_options =
{
    {
        name = "key_wheel",
        label = "Колесо обликов",
        hover = "Клавиша, которая открывает и закрывает колесо обликов (у каждого игрока своя).",
        options = KEYS,
        default = "KEY_C",
        client = true,
    },
    {
        name = "butterfly_health",
        label = "Здоровье бабочки",
        hover = "Сколько здоровья у бабочки (базового облика).",
        options =
        {
            { description = "25", data = 25 },
            { description = "50", data = 50 },
            { description = "75", data = 75 },
            { description = "100", data = 100 },
            { description = "150", data = 150 },
        },
        default = 50,
    },
}
