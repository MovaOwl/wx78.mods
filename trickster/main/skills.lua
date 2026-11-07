-- Древо навыков облика (честный режим): у облика твоё настоящее древо этого персонажа
-- из профиля.
--
-- Как в игре:
-- * Профиль (TheSkillTree, skilltreedata.lua) хранит древо каждого персонажа:
--   activatedskills[персонаж], skillxp[персонаж].
-- * Сервер (components/skilltreeupdater.lua) проверяет навыки текущего персонажа.
--   «Рукопожатие» после активации игрока (PostActivateHandshake) вызывает
--   SendFromSkillTreeBlob: проверка по опыту и включение навыков с эффектами (onactivate).
-- * При смене облика TransferComponent переносит блоб СТАРОГО облика, а SendFromSkillTreeBlob
--   принимает только блоб своего персонажа — поэтому у нового облика навыков нет.
--
-- Что делаем: когда новый облик активируется у клиента (playeractivated — до начала
-- рукопожатия), берём из профиля древо этого персонажа (EncodeSkillTreeData) и отдаём серверу.
-- Дальше игра всё делает сама.

local GLOBAL = GLOBAL
local TRICKSTER = TRICKSTER

local MAX_BLOB_LENGTH = 4096

-- Профиль игрока есть только там, где есть игрок-клиент; на выделенном сервере его может не
-- быть вовсе, а чтение необъявленной глобальной переменной в строгом режиме — ошибка.
local function GetProfileSkillTree()
    return GLOBAL.rawget(GLOBAL, "TheSkillTree")
end

local function ApplySkillBlob(player, prefab, blob)
    if type(prefab) ~= "string" or type(blob) ~= "string" or #blob > MAX_BLOB_LENGTH then
        return
    end
    if player.prefab ~= prefab then
        return
    end
    local forms = player.components.trickster_forms
    if forms == nil or not forms:IsBased() then
        return -- обычный игрок: игра справится сама
    end
    local stu = player.components.skilltreeupdater
    if stu == nil then
        return
    end

    -- Опыт персонажа берём из того же блоба («навыки|опыт»). На хосте skilltree — это сам
    -- профиль (TheSkillTree), его не трогаем.
    local skilltree = stu.skilltree
    if skilltree ~= nil and skilltree ~= GetProfileSkillTree() then
        local xp = GLOBAL.tonumber(string.match(blob, "|(%-?%d+)$"))
        if xp ~= nil then
            -- Тот же потолок, что у SkillTreeData:AddSkillXP (skilltreedata.lua).
            local max = GLOBAL.TUNING.FIXME_DO_NOT_USE_FOR_MODS_OLD_MAX_XP_VALUE or xp
            xp = math.max(0, math.min(xp, max))
            skilltree.skillxp[prefab] = math.max(skilltree.skillxp[prefab] or 0, xp)
        end
    end

    stu.skilltreeblob = blob
    stu.skilltreeblobprefab = prefab

    -- Если рукопожатие уже применило блоб (наш запрос пришёл позже), применяем сами.
    local state = player._PostActivateHandshakeState_Server
    local HS = GLOBAL.POSTACTIVATEHANDSHAKE
    if state ~= nil and HS ~= nil and state >= HS.STC_SENDINGSTATE then
        stu:SendFromSkillTreeBlob(player)
    end
end

AddModRPCHandler("trickster", "skills", ApplySkillBlob)

-- Клиент: новый облик активирован.
AddPlayerPostInit(function(player)
    player:ListenForEvent("playeractivated", function(inst)
        local profile = GetProfileSkillTree()
        if inst ~= GLOBAL.ThePlayer or profile == nil then
            return
        end
        if not inst:HasTag(TRICKSTER.TAG_BASED) or inst.prefab == TRICKSTER.BASE then
            return
        end
        local blob = profile:EncodeSkillTreeData(inst.prefab)
        if blob == nil or blob == profile.NILDATA then
            return
        end
        if GLOBAL.TheWorld.ismastersim then
            ApplySkillBlob(inst, inst.prefab, blob)
        else
            SendModRPCToServer(GetModRPC("trickster", "skills"), inst.prefab, blob)
        end
    end)
end)
