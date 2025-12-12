local PlayerCmptBase = require("PlayerCmptBaseLogic")
local Log = require("Log")

---@class PlayerCmptInfoType:PlayerCmptBase

---@class PlayerCmptInfo:PlayerCmptInfoType
local PlayerCmptInfo = require("PlayerCmptInfoData")

---@param owner Player
---@return PlayerCmptInfo
function PlayerCmptInfo.new(owner)
    -- 本质是 setmetatable(PlayerCmptBase.new(owner), {__index=PlayerCmptInfo})
    local self = setmetatable(PlayerCmptBase.new(owner), PlayerCmptInfo)
    return self
end

---@return RoleDbDataInfoType
function PlayerCmptInfo:GetInfoData()
    return self:GetPlayer():GetRoleDbData().Info
end

---@param lv number
function PlayerCmptInfo:SetLevel(lv)
    local dbData = self:GetInfoData()
    dbData.level = lv
end

function PlayerCmptInfo:UpLevel()
    local dbData = self:GetInfoData()
    dbData.level = dbData.level + 1
end

---@return number
function PlayerCmptInfo:GetLevel()
    local dbData = self:GetInfoData()
    return dbData.level
end

-- PlayerCmptInfo.OnTick = nil
-- 如果热更新把OnTick置为nil则会调用PlayerCmptBase的OnTick
function PlayerCmptInfo:OnTick()
    -- 玩家升一级
    self:UpLevel()

    if (self:GetLevel() > 100) then
        self:SetLevel(0)
    end

    -- Log:Error("PlayerCmptInfo userId %s Level %d", self:GetPlayer():GetUserId(), self:GetLevel())
end

function PlayerCmptInfo:OnLogin()
    Log:Error("PlayerCmptInfo:OnLogin userId %s Level %d", self:GetPlayer():GetUserId(), self:GetLevel())
end

function PlayerCmptInfo:OnLogout()
    Log:Error("PlayerCmptInfo:OnLogout userId %s Level %d", self:GetPlayer():GetUserId(), self:GetLevel())
end

return PlayerCmptInfo
