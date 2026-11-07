-- Данные перевоплощения, которые живут на игроке и переезжают в каждый новый облик.
-- Переезд: при бесшовной смене облика игра вызывает TransferComponent у каждого компонента
-- старого игрока (prefabs/player_common.lua, SwapAllCharacteristics).

local TricksterForms = Class(function(self, inst)
    self.inst = inst
    self.based = false   -- базовый облик этого игрока — бабочка
    self.epoch = 0       -- номер текущего облика; растёт при каждом превращении
    self.skins = {}      -- скин, в котором игрок был каждым персонажем: { prefab = skin }
    self.wx = nil        -- модули и шестерёнки WX-78, пока игрок не в облике WX
end)

function TricksterForms:SetBased(based)
    self.based = based and true or false
    if self.based then
        self.inst:AddTag("trickster_based")
    else
        self.inst:RemoveTag("trickster_based")
    end
end

function TricksterForms:IsBased()
    return self.based
end

function TricksterForms:TransferComponent(newinst)
    self.inst._trickster_replaced = true -- старый игрок: облик действительно сменился
    local other = newinst.components.trickster_forms
    if other == nil then
        return
    end
    other:SetBased(self.based)
    other.epoch = self.epoch
    other.skins = self.skins
    other.wx = self.wx
    other.just_swapped = true
end

function TricksterForms:OnSave()
    if not self.based then
        return nil
    end
    return
    {
        based = true,
        epoch = self.epoch,
        skins = self.skins,
        wx = self.wx,
    }
end

function TricksterForms:OnLoad(data)
    if data == nil then
        return
    end
    self:SetBased(data.based)
    self.epoch = data.epoch or 0
    self.skins = data.skins or {}
    self.wx = data.wx
end

return TricksterForms
