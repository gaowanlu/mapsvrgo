local PlayerCmptBase = require("PlayerCmptBaseLogic")
local Log = require("Log")
local PlayerCmptInfo = require("PlayerCmptInfoData")

function PlayerCmptInfo.new(owner)
    -- 本质是 setmetatable(PlayerCmptBase.new(owner), {__index=PlayerCmptInfo})
    local self = setmetatable(PlayerCmptBase.new(owner), PlayerCmptInfo)
    return self
end

function PlayerCmptInfo:GetInfoData()
    return self:GetPlayer():GetRoleDbData().Info
end

function PlayerCmptInfo:SetLevel(lv)
    local dbData = self:GetInfoData()
    dbData.level = lv
end

function PlayerCmptInfo:UpLevel()
    local dbData = self:GetInfoData()
    dbData.level = dbData.level + 1
end

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

    -- Log:Error("%s", tostring(PlayerCmptInfo))

    -- Log:Error("InfoOnTick playerID %s x %s y %s lv %d owner %s self %s", self:GetPlayer():GetRoleDbData().id,
    --     self:GetPlayer():GetRoleDbData().x, self:GetPlayer():GetRoleDbData().y, self:GetLevel(),
    --     tostring(self:GetPlayer()), tostring(self))

end

return PlayerCmptInfo
