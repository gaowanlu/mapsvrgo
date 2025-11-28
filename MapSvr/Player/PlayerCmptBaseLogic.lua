local PlayerCmptBase = require("Player.PlayerCmptBaseData")
local Log = require("Log")

function PlayerCmptBase.new(owner)
    -- 本质是 setmetatable({}, {__index=PlayerCmptBase})
    local self = setmetatable({}, PlayerCmptBase)
    self.owner = owner
    return self
end

function PlayerCmptBase:OnTick()
    -- 可选重写
    -- Log:Error("PlayerCmptBase:OnTick")
end

function PlayerCmptBase:OnLogin()
    -- 可选重写
end

function PlayerCmptBase:OnLogout()
    -- 可选重写
end

function PlayerCmptBase:OnSave()
    -- 可选重写
end

function PlayerCmptBase:GetPlayer()
    return self.owner
end

return PlayerCmptBase
