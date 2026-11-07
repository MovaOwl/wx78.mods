-- Прыжок Вортокса для WX-78. Бесплатно, без душ.
--
-- Как устроено в игре (скрипты игры):
--   * ПКМ по земле даёт действие BLINK через playeractionpicker.pointspecialactionsfn
--     (prefabs/wortox.lua, GetPointSpecialActions).
--   * Стейтграф ведёт BLINK без предмета в анимацию прыжка, только если у игрока тег
--     "soulstealer" (stategraphs/SGwilson.lua и SGwilson_client.lua, ActionHandler BLINK).
--   * Сам прыжок спрашивает у персонажа doer:CanSoulhop() и doer:TryToPortalHop()
--     (actions.lua, TryToSoulhop / ActionCanMapSoulhop).
--
-- Что делаем:
--   * Тег "soulstealer" WX НЕ даём: с ним к WX летели бы души, выбитые настоящим
--     Вортоксом (prefabs/wortox_soul_spawn.lua, SeekSoulStealer). Вместо тега патчим
--     обработчик BLINK в стейтграфах — только для WX.
--   * Даём WX свои CanSoulhop / TryToPortalHop, которые ничего не списывают.
--   * ПКМ: не заменяем функцию WX (на ней висят его навыки на карте), а добавляем BLINK
--     после его действий.

local GLOBAL = GLOBAL
local ACTIONS = GLOBAL.ACTIONS
local TheWorld_ismastersim = function() return GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim end
local WX1102 = WX1102 -- общая таблица мода из modmain.lua (окружение мода)
local cfg = WX1102.config

local function CanHop(inst)
    return inst ~= nil and inst.prefab == "wx78" and inst:HasTag(WX1102.HOP_TAG)
end

--------------------------------------------------------------------------
-- Проверки места — те же, что у Вортокса (prefabs/wortox.lua: IsNotBlocked, CanBlinkTo).

local function IsNotBlocked(pt)
    local map = GLOBAL.TheWorld.Map
    return map:IsPassableAtPoint(pt:Get()) and not map:IsGroundTargetBlocked(pt)
end

local function CanBlinkTo(inst, pt)
    local x, y, z = inst.Transform:GetWorldPosition()
    return IsNotBlocked(pt) and GLOBAL.IsTeleportingPermittedFromPointToPoint(x, y, z, pt.x, pt.y, pt.z)
end

local function CanBlinkFromWithMap(inst, pt)
    local x, y, z = inst.Transform:GetWorldPosition()
    return GLOBAL.IsTeleportingPermittedFromPointToPoint(x, y, z, pt.x, pt.y, pt.z)
end

-- Вызывается и для обычного прыжка, и для прыжка через карту (там передаётся число душ).
local function CanSoulhop(inst, souls)
    local rider = inst.replica.rider
    return rider == nil or not rider:IsRiding()
end

-- Сервер: ничего не списываем. Вортокс здесь тратит души и ставит перезарядку.
local function TryToPortalHop(inst, souls, consumeall)
    return true
end

--------------------------------------------------------------------------
-- ПКМ: добавляем BLINK к действиям WX, не ломая его собственные.

local function ShouldOfferBlink(inst, pos, useitem, right)
    if not right or useitem ~= nil or not CanHop(inst) then
        return false
    end
    if inst.checkingmapactions then
        if not cfg.hop_map then
            return false
        end
        return inst:CanBlinkFromWithMap(inst.checkingmapactions_pos or inst:GetPosition())
    end
    if not cfg.hop_rmb then
        return false
    end
    return pos ~= nil and inst:CanBlinkTo(pos) and inst:CanSoulhop()
end

AddComponentPostInit("playeractionpicker", function(self)
    local _GetPointSpecialActions = self.GetPointSpecialActions
    function self:GetPointSpecialActions(pos, useitem, right, usereticulepos, ...)
        if not CanHop(self.inst) then
            return _GetPointSpecialActions(self, pos, useitem, right, usereticulepos, ...)
        end
        local original_fn = self.pointspecialactionsfn
        self.pointspecialactionsfn = function(inst, p, ui, r, urp)
            local actions, pos2
            if original_fn ~= nil then
                actions, pos2 = original_fn(inst, p, ui, r, urp)
            end
            local result = {}
            if actions ~= nil then
                for i, v in ipairs(actions) do
                    result[i] = v
                end
            end
            -- Навыки WX идут первыми, прыжок — последним.
            if ShouldOfferBlink(inst, p, ui, r) then
                table.insert(result, ACTIONS.BLINK)
            end
            return result, pos2
        end
        local ok, a, b = GLOBAL.pcall(_GetPointSpecialActions, self, pos, useitem, right, usereticulepos, ...)
        self.pointspecialactionsfn = original_fn
        if not ok then
            GLOBAL.error(a, 0)
        end
        return a, b
    end
end)

--------------------------------------------------------------------------
-- Стейтграфы: BLINK без предмета у WX ведём в анимацию прыжка Вортокса.

local function PatchBlinkHandlers(sg)
    for _, action in ipairs({ ACTIONS.BLINK, ACTIONS.BLINK_MAP }) do
        local handler = sg.actionhandlers[action]
        if handler ~= nil then
            local old_deststate = handler.deststate
            handler.deststate = function(inst, act, ...)
                if act.invobject == nil and CanHop(inst) then
                    return "portal_jumpin_pre"
                end
                if type(old_deststate) == "function" then
                    return old_deststate(inst, act, ...)
                end
                return old_deststate
            end
        end
    end
end

AddStategraphPostInit("wilson", PatchBlinkHandlers)
AddStategraphPostInit("wilson_client", PatchBlinkHandlers)

--------------------------------------------------------------------------

AddPrefabPostInit("wx78", function(inst)
    inst:AddTag(WX1102.HOP_TAG)

    inst.CanSoulhop = CanSoulhop
    inst.CanBlinkTo = CanBlinkTo
    inst.CanBlinkFromWithMap = CanBlinkFromWithMap

    if not TheWorld_ismastersim() then
        return
    end

    inst.TryToPortalHop = TryToPortalHop
end)

--------------------------------------------------------------------------
-- Прыжок к курсору по клавише (клавишу ловит main/keybinds.lua, сюда приходит RPC).

local function HopTo(player, x, z)
    if not CanHop(player)
        or type(x) ~= "number" or type(z) ~= "number"
        or x ~= x or z ~= z -- NaN
        or player.components.health == nil or player.components.health:IsDead()
        or player:HasTag("playerghost")
        or player.sg == nil or player.sg:HasStateTag("busy")
        or player.components.locomotor == nil
    then
        return
    end
    local pt = GLOBAL.Vector3(x, 0, z)
    if not (player:CanBlinkTo(pt) and player:CanSoulhop()) then
        return
    end
    player.components.locomotor:PushAction(GLOBAL.BufferedAction(player, nil, ACTIONS.BLINK, nil, pt), true)
end

AddModRPCHandler("wx1102", "hop", HopTo)
