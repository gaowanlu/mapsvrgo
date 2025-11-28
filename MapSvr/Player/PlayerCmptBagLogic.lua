local PlayerCmptBase = require("PlayerCmptBaseLogic")
local Log = require("Log")
local PlayerCmptBag = require("PlayerCmptBagData")

function PlayerCmptBag.new(owner)
    -- 本质是 setmetatable(PlayerCmptBase.new(owner), {__index=PlayerCmptBag})
    local self = setmetatable(PlayerCmptBase.new(owner), PlayerCmptBag)
    return self
end

function PlayerCmptBag:GetBagData()
    return self:GetPlayer():GetRoleDbData().Bag;
end

function PlayerCmptBag:AddItem(itemID, count)
    local dbData = self:GetBagData()
    dbData.items[itemID] = (dbData.items[itemID] or 0) + count
    return true
end

function PlayerCmptBag:GetItemCount(itemID)
    local dbData = self:GetBagData()
    return dbData.items[itemID] or 0
end

function PlayerCmptBag:OnTick()
    -- Log:Error("bag OnTick PlayerId %d itemID 1001 Cnt %d", self:GetPlayer():GetPlayerID(), self:GetItemCount(1001))
end

return PlayerCmptBag
