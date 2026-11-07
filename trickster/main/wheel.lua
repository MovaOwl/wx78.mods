-- Колесо обликов (клиент). Клавиша (по умолчанию C) открывает и закрывает колесо.
--
-- Колесо — штатное колесо заклинаний: PlayerHud:OpenSpellWheel(предмет, пункты, ...)
-- (screens/playerhud.lua). «Предмет» — наш локальный объект с компонентом spellbook
-- (у Уиллоу, Виноны и Уолтера spellbook уже стоит на самом игроке, поэтому на игрока его
-- не вешаем).
-- HUD каждый кадр проверяет «книгу»: у предмета — replica.inventoryitem:IsGrandOwner(игрок),
-- иначе — видит ли игрок её (в темноте не видит, колесо бы закрылось). Поэтому даём нашему
-- объекту маленькую замену inventoryitem.

local GLOBAL = GLOBAL
local STRINGS = GLOBAL.STRINGS
local TRICKSTER = TRICKSTER

if GLOBAL.TheNet:IsDedicated() then
    return
end

local WHEEL_RADIUS = 230
local ICON_SCALE = 0.55
local ICON_RADIUS = 40

local function GetFormName(prefab)
    return STRINGS.CHARACTER_NAMES[prefab]
        or STRINGS.NAMES[string.upper(prefab)]
        or prefab
end

local function FindIcon(prefab)
    local candidates =
    {
        { "images/crafting_menu_avatars/avatar_" .. prefab .. ".xml", "avatar_" .. prefab .. ".tex" },
        { "images/crafting_menu_avatars.xml", "avatar_" .. prefab .. ".tex" },
        { "images/avatars.xml", "avatar_" .. prefab .. ".tex" },
    }
    for _, c in ipairs(candidates) do
        local atlas = GLOBAL.softresolvefilepath(c[1])
        if atlas ~= nil and GLOBAL.TheSim:AtlasContains(atlas, c[2]) then
            return atlas, c[2]
        end
    end
    return GLOBAL.softresolvefilepath("images/crafting_menu_avatars.xml"), "avatar_mod.tex"
end

local function BuildItems()
    local items = {}
    for i, prefab in ipairs(TRICKSTER.GetForms()) do
        local atlas, tex = FindIcon(prefab)
        items[i] =
        {
            label = GetFormName(prefab),
            execute = function()
                SendModRPCToServer(GetModRPC("trickster", "transform"), i)
            end,
            atlas = atlas,
            normal = tex,
            widget_scale = ICON_SCALE,
            hit_radius = ICON_RADIUS,
        }
    end
    return items
end

local wheel_book = nil

local function GetWheelBook()
    if wheel_book ~= nil and wheel_book:IsValid() then
        return wheel_book
    end
    local book = GLOBAL.CreateEntity()
    book.entity:AddTransform()
    book.persists = false
    book:AddTag("CLASSIFIED")

    book:AddComponent("spellbook")
    book.components.spellbook:SetRequiredTag(TRICKSTER.TAG_BASED)
    book.components.spellbook:SetRadius(WHEEL_RADIUS)
    book.components.spellbook:SetFocusRadius(WHEEL_RADIUS + 3)
    book.components.spellbook:SetItems(BuildItems())
    book.components.spellbook.opensound = "dontstarve/HUD/craft_open"
    book.components.spellbook.closesound = "dontstarve/HUD/craft_close"

    -- Замена replica.inventoryitem: HUD спрашивает, держит ли игрок «книгу».
    book:AddTag("_inventoryitem")
    GLOBAL.rawget(book.replica, "_").inventoryitem =
    {
        IsGrandOwner = function(self, owner)
            return owner ~= nil and owner == GLOBAL.ThePlayer
        end,
        IsHeld = function() return true end,
        IsHeldBy = function(self, owner) return owner ~= nil and owner == GLOBAL.ThePlayer end,
        IsWet = function() return false end,
        IsAcidSizzling = function() return false end,
        CanBePickedUp = function() return false end,
    }

    wheel_book = book
    return book
end

local function GetKey()
    local value = GetModConfigData("key_wheel", true)
    if value == nil then
        value = GetModConfigData("key_wheel")
    end
    if value == nil then
        value = "KEY_C"
    end
    return GLOBAL.rawget(GLOBAL, value)
end

local function ToggleWheel()
    local player = GLOBAL.ThePlayer
    if player == nil or player.HUD == nil or not player:HasTag(TRICKSTER.TAG_BASED) then
        return
    end
    local hud = player.HUD
    if hud:HasInputFocus() then
        return
    end
    local screen = GLOBAL.TheFrontEnd:GetActiveScreen()
    if screen == nil or screen.name ~= "HUD" then
        return
    end

    local book = GetWheelBook()
    if hud.GetCurrentOpenSpellBook ~= nil and hud:GetCurrentOpenSpellBook() == book then
        hud:CloseSpellWheel()
        return
    end
    if player:HasTag("playerghost") then
        return
    end
    local spellbook = book.components.spellbook
    if not spellbook:CanBeUsedBy(player) then
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
end

local key = GetKey()
if key ~= nil then
    GLOBAL.TheInput:AddKeyDownHandler(key, ToggleWheel)
end
