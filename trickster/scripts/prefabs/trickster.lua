-- Бабочка-трикстер: базовый облик игрока.
--
-- Устроена по образцу призрака игрока (prefabs/player_common_extensions.lua, OnMakePlayerGhost):
-- свой банк анимаций и свои стейтграфы — серверный SGtrickster и клиентский SGtrickster_client
-- для плавного движения. Игра в нескольких местах жёстко ставит стейтграф Уилсона
-- (EnableMovementPrediction, SetGhostMode, воскрешение) — эти места мы перехватываем.

local MakePlayerCharacter = require("prefabs/player_common")

local assets =
{
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("ANIM", "anim/butterfly_basic.zip"),
}

local prefabs = {}

local BUTTERFLY_BANK = "butterfly"
local BUTTERFLY_BUILD = "butterfly_basic"
local BUTTERFLY_SCALE = 2.2
local GHOST_BUILD = "ghost_wilson_build"

local function IsGhost(inst)
    return inst:HasTag("playerghost")
        or (inst.player_classified ~= nil and inst.player_classified.isghostmode:value())
end

local function ApplyButterflyLook(inst)
    inst.AnimState:SetBank(BUTTERFLY_BANK)
    inst.AnimState:SetBuild(BUTTERFLY_BUILD)
    inst.Transform:SetScale(BUTTERFLY_SCALE, BUTTERFLY_SCALE, BUTTERFLY_SCALE)
end

--------------------------------------------------------------------------
-- Действия: бабочка только летает и осматривает. Остальное (поднять, рубить, атаковать,
-- крафтить) ей недоступно — у бабочки из игры нет таких анимаций.

local ALLOWED_ACTIONS = {}
local function ButterflyActionFilter(inst, action)
    return ALLOWED_ACTIONS[action] == true
end

local function OnSetOwner(inst)
    if ALLOWED_ACTIONS[ACTIONS.WALKTO] == nil then
        ALLOWED_ACTIONS[ACTIONS.WALKTO] = true
        ALLOWED_ACTIONS[ACTIONS.LOOKAT] = true
    end
    local picker = inst.components.playeractionpicker
    if picker ~= nil and not inst._trickster_filter_pushed then
        picker:PushActionFilter(ButterflyActionFilter, 1000)
        inst._trickster_filter_pushed = true
    end
end

--------------------------------------------------------------------------
-- Клиент: игра ставит SGwilson_client — заменяем на клиентский стейтграф бабочки.

local function FixClientStategraph(inst)
    if inst.sg ~= nil and inst.sg.sg ~= nil and inst.sg.sg.name == "wilson_client" and not IsGhost(inst) then
        inst:SetStateGraph("SGtrickster_client")
    end
end

local function PatchClient(inst)
    local _EnableMovementPrediction = inst.EnableMovementPrediction
    if _EnableMovementPrediction ~= nil then
        inst.EnableMovementPrediction = function(inst, enable, ...)
            _EnableMovementPrediction(inst, enable, ...)
            FixClientStategraph(inst)
        end
    end
    local _SetGhostMode = inst.SetGhostMode
    if _SetGhostMode ~= nil then
        inst.SetGhostMode = function(inst, isghost, ...)
            _SetGhostMode(inst, isghost, ...)
            FixClientStategraph(inst)
        end
    end
end

--------------------------------------------------------------------------
-- Сервер: внешность ставит компонент skinner. Сборки персонажа у бабочки нет, поэтому
-- обычный облик — сборка бабочки, призрак — стандартная сборка призрака Уилсона.

local function PatchSkinner(inst)
    local skinner = inst.components.skinner
    if skinner == nil then
        return
    end
    local _SetSkinMode = skinner.SetSkinMode
    function skinner:SetSkinMode(skintype, default_build, ...)
        if skintype == "ghost_skin" then
            inst.Transform:SetScale(1, 1, 1)
            return _SetSkinMode(self, skintype, GHOST_BUILD, ...)
        end
        _SetSkinMode(self, skintype, default_build, ...)
        if not IsGhost(inst) then
            ApplyButterflyLook(inst)
        end
    end
    for _, name in ipairs({ "SetSkinName", "SetClothing", "ClearAllClothing", "ClearClothing" }) do
        local fn = skinner[name]
        if fn ~= nil then
            skinner[name] = function(self, ...)
                local result = fn(self, ...)
                if not IsGhost(inst) then
                    ApplyButterflyLook(inst)
                end
                return result
            end
        end
    end
end

local function OnRespawnedFromGhost(inst)
    ApplyButterflyLook(inst)
    -- Воскрешение ставит SGwilson (player_common_extensions.lua) — возвращаем свой.
    inst:SetStateGraph("SGtrickster")
    inst.sg:GoToState("idle")
end

local function OnBecameGhost(inst)
    inst.Transform:SetScale(1, 1, 1)
end

--------------------------------------------------------------------------

local function common_postinit(inst)
    inst:AddTag("trickster")
    inst:AddTag("trickster_based")

    inst.MiniMapEntity:SetIcon("trickster.tex")

    ApplyButterflyLook(inst)

    inst:ListenForEvent("setowner", OnSetOwner)

    if not TheWorld.ismastersim then
        PatchClient(inst)
    end
end

local function master_postinit(inst)
    inst.starting_inventory = {}
    inst.soundsname = "wilson"

    inst.components.health:SetMaxHealth(TUNING.TRICKSTER_HEALTH or 50)
    inst.components.hunger:SetMax(TUNING.WILSON_HUNGER)
    -- Голод у бабочки не идёт.
    inst.components.hunger.burnratemodifiers:SetModifier(inst, 0, "trickster_nohunger")
    inst.components.sanity:SetMax(TUNING.WILSON_SANITY)

    -- Крафт бабочке недоступен.
    if inst.components.builder ~= nil then
        inst.components.builder.MakeRecipeFromMenu = function() return false end
        inst.components.builder.MakeRecipeAtPoint = function() return false end
    end

    inst:SetStateGraph("SGtrickster")
    PatchSkinner(inst)

    inst:ListenForEvent("ms_respawnedfromghost", OnRespawnedFromGhost)
    inst:ListenForEvent("ms_becameghost", OnBecameGhost)
end

return MakePlayerCharacter("trickster", prefabs, assets, common_postinit, master_postinit)
