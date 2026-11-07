-- Перевоплощение. Основа — штатная бесшовная смена персонажа, как у Вонки:
--   TheNet:SpawnSeamlessPlayerReplacement(...) (components/seamlessplayerswapper.lua)
--   -> на новом игроке OnSeamlessCharacterSwap(old_player) (networking.lua):
--      ms_playerreroll у старого (персонаж убирает своё: Вуби, Абигейл, слуги),
--      SaveForReroll/LoadForReroll (рецепты, карта, питомцы),
--      SwapAllCharacteristics (инвентарь; здоровье, голод, рассудок в процентах),
--      событие ms_playerseamlessswaped у нового.
-- Своя логика: базовый облик всегда бабочка, а штатный swapper при цепочке превращений
-- запомнил бы базовым промежуточного персонажа. Поэтому функцию движка зовём сами.

local GLOBAL = GLOBAL
local TUNING = GLOBAL.TUNING
local TRICKSTER = TRICKSTER

--------------------------------------------------------------------------
-- WX-78: модули и шестерёнки.
-- От ms_playerreroll WX выполняет «последствия смерти»: модули выпадают, заряд обнуляется
-- (wx78.lua, OnDeath/DoDeathConsequences), и сыплются съеденные шестерёнки
-- (wx78_common.lua, DropEatenGears). Флаг wx78_backupbody_save — штатный («запасное тело»):
-- он отключает последствия смерти. Модули запоминаем через upgrademoduleowner:OnSave и
-- восстанавливаем через OnLoad, когда игрок снова станет WX.

local WX78Common = GLOBAL.require("prefabs/wx78_common")
if WX78Common ~= nil and WX78Common.DropEatenGears ~= nil then
    local _DropEatenGears = WX78Common.DropEatenGears
    WX78Common.DropEatenGears = function(inst, ...)
        if inst ~= nil and inst._trickster_swapping then
            return
        end
        return _DropEatenGears(inst, ...)
    end
end

local function SaveWX(player, forms)
    local umo = player.components.upgrademoduleowner
    forms.wx =
    {
        modules = umo ~= nil and umo:OnSave() or nil,
        gears = player._gears_eaten,
    }
    player.wx78_backupbody_save = true
    player._trickster_swapping = true
end

local function RestoreWX(player, forms)
    local data = forms.wx
    forms.wx = nil
    if data == nil then
        return
    end
    local umo = player.components.upgrademoduleowner
    if umo ~= nil and data.modules ~= nil then
        umo:OnLoad(data.modules, {})
    end
    if data.gears ~= nil then
        player._gears_eaten = data.gears
    end
end

--------------------------------------------------------------------------
-- Стартовый набор облика (как при старте игры), помеченный как «особые предметы».

local function GiveStartingItems(player, forms)
    local items = TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT[string.upper(player.prefab)]
    if items == nil or player.components.inventory == nil then
        return
    end
    -- Одинаковые предметы собираем в одну стопку: так они не займут лишних ячеек.
    local counts, order = {}, {}
    for _, prefab in ipairs(items) do
        if counts[prefab] == nil then
            counts[prefab] = 0
            table.insert(order, prefab)
        end
        counts[prefab] = counts[prefab] + 1
    end
    for _, prefab in ipairs(order) do
        local left = counts[prefab]
        while left > 0 do
            local item = GLOBAL.SpawnPrefab(prefab)
            if item == nil then
                break
            end
            TRICKSTER.MarkItem(item, player.userid, forms.epoch)
            local stack = item.components.stackable
            if stack ~= nil then
                local n = math.min(left, stack.maxsize or left)
                stack:SetStackSize(n)
                left = left - n
            else
                left = left - 1
            end
            player.components.inventory:GiveItem(item, nil, player:GetPosition())
        end
    end
end

--------------------------------------------------------------------------

local function SpawnFx(player)
    local fx = GLOBAL.SpawnPrefab("spawn_fx_medium")
    if fx ~= nil then
        fx.Transform:SetPosition(player.Transform:GetWorldPosition())
    end
end

local function GetForms()
    if TRICKSTER._forms == nil then
        TRICKSTER._forms = TRICKSTER.GetForms()
    end
    return TRICKSTER._forms
end

local function CanTransform(player, target)
    local forms = player.components.trickster_forms
    return forms ~= nil and forms:IsBased()
        and player.userid ~= nil and player.userid ~= ""
        and target ~= nil and target ~= player.prefab
        and GLOBAL.Prefabs[target] ~= nil
        and player.components.health ~= nil and not player.components.health:IsDead()
        and not player:HasTag("playerghost")
        and not (player.sg ~= nil and (player.sg:HasStateTag("busy") or player.sg:HasStateTag("dead")))
        and not (player.components.rider ~= nil and player.components.rider:IsRiding())
        and not player._trickster_swapping
end

local function DoTransform(player, target)
    local forms = player.components.trickster_forms

    -- Уходящий облик: его «особые предметы» исчезают где бы ни были.
    TRICKSTER.RemoveMarkedItems(player.userid)
    forms.epoch = forms.epoch + 1

    local clothing = player.components.skinner:GetClothing()
    forms.skins[player.prefab] = clothing.base
    local skin_base = forms.skins[target]

    if player.prefab == "wx78" then
        SaveWX(player, forms)
    end
    player._trickster_swapping = true

    SpawnFx(player)
    GLOBAL.TheNet:SpawnSeamlessPlayerReplacement(player.userid, target, skin_base,
        clothing.body, clothing.hand, clothing.legs, clothing.feet)

    -- Если движок по какой-то причине не сменил облик, игрок остался прежним — снимаем флаги,
    -- иначе следующая настоящая смерть WX прошла бы без последствий. Если облик сменился,
    -- старый игрок уже отключён, и флаги на нём ни на что не влияют.
    player:DoTaskInTime(1, function(inst)
        if inst:IsValid() and not inst._trickster_replaced then
            inst._trickster_swapping = nil
            inst.wx78_backupbody_save = nil
            -- Модули остались на WX — сохранённую копию забываем, иначе они задвоятся.
            if inst.components.trickster_forms ~= nil then
                inst.components.trickster_forms.wx = nil
            end
        end
    end)
end

AddModRPCHandler("trickster", "transform", function(player, index)
    if type(index) ~= "number" then
        return
    end
    local target = GetForms()[index]
    if target ~= nil and CanTransform(player, target) then
        DoTransform(player, target)
    end
end)

--------------------------------------------------------------------------
-- Каждый игрок получает компонент данных. Бабочка — базовый облик.

local function OnSeamlessSwapped(player)
    local forms = player.components.trickster_forms
    if forms == nil or not forms:IsBased() or not forms.just_swapped then
        return
    end
    forms.just_swapped = nil

    -- Штатный swapper подменяет реплики облика на реплики базового персонажа (speechproxy)
    -- — нам это не нужно: каждый облик говорит своими репликами.
    if player.components.talker ~= nil then
        player.components.talker.speechproxy = nil
    end

    if player.prefab == "wx78" then
        RestoreWX(player, forms)
    end
    GiveStartingItems(player, forms)
    SpawnFx(player)
end

local function CleanupStaleItems(player)
    local forms = player.components.trickster_forms
    if forms ~= nil and forms:IsBased() and player.userid ~= nil and player.userid ~= "" then
        -- Предметы прошлых обликов, оставшиеся в этом мире (например, пока игрок был в пещерах).
        TRICKSTER.RemoveMarkedItems(player.userid, forms.epoch)
    end
end

AddPlayerPostInit(function(player)
    if not GLOBAL.TheWorld.ismastersim then
        return
    end
    if player.components.trickster_forms == nil then
        player:AddComponent("trickster_forms")
    end
    if player.prefab == TRICKSTER.BASE then
        player.components.trickster_forms:SetBased(true)
    end
    player:ListenForEvent("ms_playerseamlessswaped", OnSeamlessSwapped)
    player:DoTaskInTime(0, CleanupStaleItems)
end)
