-- «Особые предметы» облика: стартовый набор персонажа, который приходит вместе с обликом
-- и уходит вместе с ним — где бы ни лежал (инвентарь, сундук, земля, у другого игрока).
--
-- Метка: хозяин (userid) и «эпоха» — номер облика, который растёт при каждом превращении.
-- * Хранится в компоненте inventoryitem (у него нет своего OnSave, поэтому добавляем).
-- * Помеченный предмет не складывается в стопку с чужим или непомеченным: все стопки игры
--   идут через stackable:CanStackWith (components/inventory.lua). Иначе «особое» мясо
--   слилось бы с твоим, и при уходе облика пропало бы твоё мясо.

local GLOBAL = GLOBAL
local TRICKSTER = TRICKSTER

local function GetMark(item)
    local ii = item ~= nil and item.components.inventoryitem or nil
    if ii ~= nil and ii._trickster_owner ~= nil then
        return ii._trickster_owner, ii._trickster_epoch
    end
end

function TRICKSTER.MarkItem(item, owner, epoch)
    local ii = item.components.inventoryitem
    if ii ~= nil then
        ii._trickster_owner = owner
        ii._trickster_epoch = epoch
    end
end

-- Удалить предметы игрока: все (epoch == nil) или все, кроме текущей эпохи (keep_epoch).
function TRICKSTER.RemoveMarkedItems(owner, keep_epoch)
    local toremove = {}
    for _, ent in pairs(GLOBAL.Ents) do
        if ent:IsValid() then
            local item_owner, item_epoch = GetMark(ent)
            if item_owner == owner and (keep_epoch == nil or item_epoch ~= keep_epoch) then
                table.insert(toremove, ent)
            end
        end
    end
    for _, ent in ipairs(toremove) do
        if ent:IsValid() then
            ent:Remove()
        end
    end
    return #toremove
end

AddComponentPostInit("inventoryitem", function(self)
    local _OnSave = self.OnSave
    local _OnLoad = self.OnLoad

    function self:OnSave(...)
        local data, refs
        if _OnSave ~= nil then
            data, refs = _OnSave(self, ...)
        end
        if self._trickster_owner ~= nil then
            data = data or {}
            data.trickster_owner = self._trickster_owner
            data.trickster_epoch = self._trickster_epoch
        end
        return data, refs
    end

    function self:OnLoad(data, ...)
        if data ~= nil and data.trickster_owner ~= nil then
            self._trickster_owner = data.trickster_owner
            self._trickster_epoch = data.trickster_epoch
        end
        if _OnLoad ~= nil then
            return _OnLoad(self, data, ...)
        end
    end
end)

AddComponentPostInit("stackable", function(self)
    local _CanStackWith = self.CanStackWith
    if _CanStackWith == nil then
        return
    end
    function self:CanStackWith(other, ...)
        local o1, e1 = GetMark(self.inst)
        local o2, e2 = GetMark(other)
        if o1 ~= o2 or e1 ~= e2 then
            return false
        end
        return _CanStackWith(self, other, ...)
    end
end)
