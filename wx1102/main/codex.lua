-- Кодекс Умбра для WX-78. Бесплатно, до 6 слуг, как у Максвелла.
--
-- Как устроено в игре (скрипты игры):
--   * Книгу открывает только игрок с тегом "shadowmagic" (prefabs/waxwelljournal.lua,
--     spellbook:SetRequiredTag).
--   * Заклинания тратят топливо книги (fueled:DoDelta), ловушка и столбы ещё и −15
--     рассудка (sanity:DoDelta). Пустую книгу открыть нельзя (тег "fueldepleted",
--     actions.lua, USESPELLBOOK.pre_action_cb).
--   * Слуги призываются через petleash игрока. Максвелл за каждого слугу получает
--     штраф к максимуму рассудка (prefabs/waxwell.lua, OnSpawnPet) и лимит +6 к поводку.
--
-- Что делаем:
--   * Тег "shadowmagic" для WX (книга + вкладка теневого крафта).
--   * Когда колдует WX: топливо не тратится, рассудок не отнимается, пустая книга работает.
--     Если колдует Максвелл — всё как в игре.
--   * Слуги WX не режут рассудок. Лимит +6 к поводку, как у Максвелла. Дроны WX
--     лимитируются отдельно (по префабу), поэтому не мешают.
--   * Шляпу и Сундук фокусника WX не видит: для них нужна способность Максвелла "magician".
--   * Книга в стартовом наборе WX.

local GLOBAL = GLOBAL
local TUNING = GLOBAL.TUNING
local WX1102 = WX1102 -- общая таблица мода из modmain.lua (окружение мода)
local cfg = WX1102.config

local function IsFreeCaster(doer)
    return doer ~= nil and doer.prefab == "wx78" and doer:HasTag(WX1102.CODEX_TAG)
end

--------------------------------------------------------------------------
-- Стартовый набор. wx78.lua берёт таблицу TUNING.GAMEMODE_STARTING_ITEMS.<режим>.WX78
-- по ссылке, поэтому достаточно дописать в неё книгу.

if cfg.codex_starting then
    local default_items = TUNING.GAMEMODE_STARTING_ITEMS and TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT
    if default_items ~= nil then
        default_items.WX78 = default_items.WX78 or {}
        table.insert(default_items.WX78, "waxwelljournal")
    end
end

--------------------------------------------------------------------------
-- Шляпа и Сундук фокусника: прячем от WX штатным полем рецепта no_builder_tag
-- (components/builder.lua и builder_replica.lua, KnowsRecipe). Максвелл их видит как раньше.

for _, name in ipairs({ "tophat_magician", "magician_chest" }) do
    AddRecipePostInit(name, function(recipe)
        if recipe.no_builder_tag == nil then
            recipe.no_builder_tag = WX1102.CODEX_TAG
        end
    end)
end

--------------------------------------------------------------------------
-- Бесплатные заклинания. На время заклинания WX подменяем у книги трату топлива
-- и проверку пустоты, а у WX — потерю рассудка. После заклинания всё возвращаем.

local function TempOverride(tbl, key, value)
    local had_own = GLOBAL.rawget(tbl, key) ~= nil
    local old = GLOBAL.rawget(tbl, key)
    GLOBAL.rawset(tbl, key, value)
    return function()
        if had_own then
            GLOBAL.rawset(tbl, key, old)
        else
            GLOBAL.rawset(tbl, key, nil)
        end
    end
end

local function WrapFree(fn)
    return function(book, doer, ...)
        if not IsFreeCaster(doer) then
            return fn(book, doer, ...)
        end

        local restores = {}
        local fueled = book.components.fueled
        if fueled ~= nil then
            table.insert(restores, TempOverride(fueled, "DoDelta", function() end))
            table.insert(restores, TempOverride(fueled, "IsEmpty", function() return false end))
        end
        local sanity = doer.components.sanity
        if sanity ~= nil then
            local original_dodelta = sanity.DoDelta
            table.insert(restores, TempOverride(sanity, "DoDelta", function(self, delta, ...)
                if delta ~= nil and delta < 0 then
                    return
                end
                return original_dodelta(self, delta, ...)
            end))
        end

        local result = { GLOBAL.pcall(fn, book, doer, ...) }
        for i = #restores, 1, -1 do
            restores[i]()
        end
        if not result[1] then
            GLOBAL.error(result[2], 0)
        end
        return GLOBAL.unpack(result, 2, GLOBAL.table.maxn(result))
    end
end

-- Держим книгу у WX полной: так её всегда можно открыть, даже если её опустошил Максвелл.
local function RefillBook(book)
    if book ~= nil and book:IsValid() and book.prefab == "waxwelljournal"
        and book.components.fueled ~= nil and book.components.fueled:GetPercent() < 1
    then
        book.components.fueled:SetPercent(1)
    end
end

AddPrefabPostInit("waxwelljournal", function(book)
    if not GLOBAL.TheWorld.ismastersim then
        return
    end
    local aoespell = book.components.aoespell
    if aoespell ~= nil and aoespell.SetSpellFn ~= nil then
        local _SetSpellFn = aoespell.SetSpellFn
        function aoespell:SetSpellFn(fn, ...)
            return _SetSpellFn(self, fn ~= nil and WrapFree(fn) or nil, ...)
        end
    end
    local spellbook = book.components.spellbook
    if spellbook ~= nil and spellbook.SetSpellFn ~= nil then
        local _SetSpellFn = spellbook.SetSpellFn
        function spellbook:SetSpellFn(fn, ...)
            return _SetSpellFn(self, fn ~= nil and WrapFree(fn) or nil, ...)
        end
    end
end)

--------------------------------------------------------------------------
-- Слуги. Повторяем поведение Максвелла (prefabs/waxwell.lua), но без штрафа к рассудку.

local SHADOW_MINION_SLOTS = 6

local function KillPet(pet)
    if pet.components.health:IsInvincible() then
        pet._killtask = pet:DoTaskInTime(.5, KillPet)
    else
        pet.components.health:Kill()
    end
end

local function KillAllMinions(inst)
    for _, pet in pairs(inst.components.petleash:GetPets()) do
        if pet:HasTag("shadowminion") and pet._killtask == nil then
            pet._killtask = pet:DoTaskInTime(math.random(), KillPet)
        end
    end
end

local function ForceDespawnMinions(inst)
    local todespawn = {}
    for _, pet in pairs(inst.components.petleash:GetPets()) do
        if pet:HasTag("shadowminion") then
            table.insert(todespawn, pet)
        end
    end
    for _, pet in ipairs(todespawn) do
        inst.components.petleash:DespawnPet(pet)
    end
end

local function SetupPetLeash(inst)
    local petleash = inst.components.petleash
    if petleash == nil then
        inst:AddComponent("petleash")
        petleash = inst.components.petleash
        petleash:SetMaxPets(0)
    end
    petleash:SetMaxPets(petleash:GetMaxPets() + SHADOW_MINION_SLOTS)

    local _onspawnfn = petleash.onspawnfn
    local _ondespawnfn = petleash.ondespawnfn

    petleash:SetOnSpawnFn(function(owner, pet)
        if pet:HasTag("shadowminion") then
            if not (owner.components.health:IsDead() or owner:HasTag("playerghost")) then
                if pet.components.skinner ~= nil then
                    pet.components.skinner:CopySkinsFromPlayer(owner)
                end
            elseif pet._killtask == nil then
                pet._killtask = pet:DoTaskInTime(math.random(), KillPet)
            end
        elseif _onspawnfn ~= nil then
            _onspawnfn(owner, pet)
        end
    end)

    petleash:SetOnDespawnFn(function(owner, pet)
        if pet:HasTag("shadowminion") then
            if not owner.is_snapshot_user_session and not owner.is_despawning then
                if pet.components.inventory ~= nil then
                    pet.components.inventory:DropEverything()
                end
            end
            if not owner.is_snapshot_user_session and pet.sg ~= nil then
                pet.sg:GoToState("quickdespawn")
            else
                pet:Remove()
            end
        elseif _ondespawnfn ~= nil then
            _ondespawnfn(owner, pet)
        end
    end)
end

AddPrefabPostInit("wx78", function(inst)
    inst:AddTag("shadowmagic")
    inst:AddTag(WX1102.CODEX_TAG)

    if not GLOBAL.TheWorld.ismastersim then
        return
    end

    SetupPetLeash(inst)

    inst:ListenForEvent("death", KillAllMinions)
    inst:ListenForEvent("ms_becameghost", KillAllMinions)
    inst:ListenForEvent("ms_playerreroll", ForceDespawnMinions)

    -- Переход в пещеры и обратно: слуги исчезают, как у Максвелла.
    -- player_common вызывает inst._OnDespawn из своего OnDespawn.
    local _OnDespawn = inst._OnDespawn
    inst._OnDespawn = function(inst, migrationdata, ...)
        inst.is_despawning = true
        if migrationdata ~= nil then
            ForceDespawnMinions(inst)
        end
        if _OnDespawn ~= nil then
            return _OnDespawn(inst, migrationdata, ...)
        end
    end

    inst:ListenForEvent("itemget", function(inst, data)
        if data ~= nil then
            RefillBook(data.item)
        end
    end)
    inst:DoTaskInTime(0, function(inst)
        if inst.components.inventory ~= nil then
            inst.components.inventory:ForEachItem(RefillBook)
        end
    end)
end)
