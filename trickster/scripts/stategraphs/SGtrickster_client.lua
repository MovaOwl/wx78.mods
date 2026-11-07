-- Клиентский стейтграф бабочки для плавного движения (предсказание движения).
-- По образцу stategraphs/SGwilsonghost_client.lua: только зависание и полёт,
-- имена состояний совпадают с серверными (idle, run).

local actionhandlers = {}

local events =
{
    EventHandler("sg_cancelmovementprediction", function(inst)
        inst.sg:GoToState("idle", "cancel")
    end),

    EventHandler("locomote", function(inst, data)
        if inst.sg:HasStateTag("busy") or inst:HasTag("busy") then
            return
        end
        local is_moving = inst.sg:HasStateTag("moving")
        local should_move = inst.components.locomotor:WantsToMoveForward()

        if not inst.entity:CanPredictMovement() then
            if not inst.sg:HasStateTag("idle") then
                inst.sg:GoToState("idle")
            end
        elseif is_moving and not should_move then
            inst.sg:GoToState("idle")
        elseif not is_moving and should_move then
            if data and data.dir then
                inst.Transform:SetRotation(data.dir)
            end
            inst.sg:GoToState("run")
        end
    end),
}

local states =
{
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            inst.entity:SetIsPredictingMovement(false)

            if pushanim == "cancel" or inst:HasTag("nopredict") or inst:HasTag("pausepredict") then
                inst.components.locomotor:Stop()
                inst.components.locomotor:Clear()
                inst:ClearBufferedAction()
                return
            end

            if inst.sg.lasttags and not inst.sg.lasttags["busy"] then
                inst.components.locomotor:StopMoving()
            else
                inst.components.locomotor:Stop()
                inst.components.locomotor:Clear()
            end
            inst:ClearBufferedAction()

            if not inst.AnimState:IsCurrentAnimation("idle_flight_loop") then
                inst.AnimState:PlayAnimation("idle_flight_loop", true)
            end
        end,

        onexit = function(inst)
            inst.entity:SetIsPredictingMovement(true)
        end,
    },

    State{
        name = "run",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            if not inst.AnimState:IsCurrentAnimation("flight_cycle") then
                inst.AnimState:PlayAnimation("flight_cycle", true)
            end
        end,

        onupdate = function(inst)
            inst.components.locomotor:RunForward()
        end,
    },
}

return StateGraph("trickster_client", states, events, "idle", actionhandlers)
