-- Базовый «скин» бабочки. Стандартная схема модового персонажа: игре нужен скин
-- <персонаж>_none, чтобы показать персонажа в меню выбора и лобби.

local assets =
{
    Asset("ANIM", "anim/butterfly_basic.zip"),
}

return CreatePrefabSkin("trickster_none",
{
    base_prefab = "trickster",
    type = "base",
    assets = assets,
    skins =
    {
        normal_skin = "butterfly_basic",
        ghost_skin = "ghost_wilson_build",
    },
    bigportrait = { build = "bigportraits/trickster_none.xml", symbol = "trickster_none_oval.tex" },
    skin_tags = { "BASE", "TRICKSTER", "CHARACTER" },
    build_name_override = "butterfly_basic",
    rarity = "Character",
})
