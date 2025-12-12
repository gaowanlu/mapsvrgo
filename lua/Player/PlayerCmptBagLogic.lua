local PlayerCmptBase = require("PlayerCmptBaseLogic")
local Log = require("Log")

---@class PlayerCmptBagType:PlayerCmptBase

---@class PlayerCmptBag:PlayerCmptBagType
local PlayerCmptBag = require("PlayerCmptBagData")

---@param owner Player
---@return PlayerCmptBag
function PlayerCmptBag.new(owner)
    -- 本质是 setmetatable(PlayerCmptBase.new(owner), {__index=PlayerCmptBag})
    local self = setmetatable(PlayerCmptBase.new(owner), PlayerCmptBag)
    return self
end

---@return RoleDbDataBagType
function PlayerCmptBag:GetBagData()
    return self:GetPlayer():GetRoleDbData().Bag;
end

---@param itemID number
---@param count number
---@return boolean
function PlayerCmptBag:AddItem(itemID, count)
    local dbData = self:GetBagData()
    dbData.items[itemID] = (dbData.items[itemID] or 0) + count
    return true
end

---@param itemID number
---@return number
function PlayerCmptBag:GetItemCount(itemID)
    local dbData = self:GetBagData()
    return dbData.items[itemID] or 0
end

function PlayerCmptBag:OnTick()
    -- Log:Error("bag OnTick PlayerId %s itemID 1001 Cnt %d", self:GetPlayer():GetPlayerID(), self:GetItemCount(1001))
end

return PlayerCmptBag
