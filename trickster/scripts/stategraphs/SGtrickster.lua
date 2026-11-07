-- Серверный стейтграф бабочки-трикстера.
-- Анимации — из бабочки игры (stategraphs/SGbutterfly.lua): idle_flight_loop, flight_cycle,
-- take_off, land, death. Смерть — как у игрока (SGwilson, состояние death): по окончании
-- анимации событие makeplayerghost, дальше игра сама делает призрака.

require("stategraphs/commonstates")

local actionhandlers = {}

local events =
{
    EventHandler("locomote", function(inst)
        if inst.sg:HasStateTag("busy") then
            return
        end
        local is_moving = inst.sg:HasStateTag("moving")
        local should_move = inst.components.locomotor:WantsToMoveForward()
        if is_moving and not should_move then
            inst.sg:GoToState("idle")
        elseif not is_moving and should_move then
            inst.sg:GoToState("run")
        end
    end),

    EventHandler("attacked", function(inst)
        if not inst.sg:HasStateTag("dead") and not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("hit")
        end
    end),

    EventHandler("death", function(inst)
        if not inst.sg:HasStateTag("dead") then
            inst.sg:GoToState("death")
        end
    end),
}

local function PlayLoop(inst, anim)
    if not inst.AnimState:IsCurrentAnimation(anim) then
        inst.AnimState:PlayAnimation(anim, true)
    end
end

local states =
{
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst:ClearBufferedAction()
            PlayLoop(inst, "idle_flight_loop")
        end,
    },

    State{
        name = "run",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            PlayLoop(inst, "flight_cycle")
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,
    },

    State{
        name = "hit",
        tags = { "busy", "pausepredict" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            inst.AnimState:PlayAnimation("take_off")
            inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:RemotePausePrediction(5)
            end
            inst.sg:SetTimeout(5 * FRAMES)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },

    State{
        name = "death",
        tags = { "busy", "dead", "pausepredict", "nomorph" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
            inst:ClearBufferedAction()
            inst.SoundEmitter:PlaySound("dontstarve/wilson/death")
            inst.AnimState:PlayAnimation("death")
            inst.AnimState:Hide("swap_arm_carry")
            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:RemotePausePrediction()
                inst.components.playercontroller:Enable(false)
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() and not inst.sg.statemem.done then
                    inst.sg.statemem.done = true
                    local x, y, z = inst.Transform:GetWorldPosition()
                    if inst.ghostenabled then
                        inst:PushEvent("makeplayerghost", { skeleton = false })
                    else
                        inst:PushEvent("playerdied", { skeleton = TheWorld.Map:IsPassableAtPoint(x, y, z) })
                    end
                end
            end),
        },
    },

    -- Вызывается, если в бабочку превратились уже мёртвым (components/seamlessplayerswapper.lua).
    State{
        name = "seamlessplayerswap_death",
        tags = { "busy", "dead", "noattack", "nopredict", "nomorph" },

        onenter = function(inst)
            if inst.ghostenabled then
                inst:PushEvent("makeplayerghost", { skeleton = false })
            else
                inst.AnimState:SetPercent("death", 1)
                local x, y, z = inst.Transform:GetWorldPosition()
                inst:PushEvent("playerdied", { skeleton = TheWorld.Map:IsPassableAtPoint(x, y, z) })
            end
        end,
    },
}

return StateGraph("trickster", states, events, "idle", actionhandlers)
