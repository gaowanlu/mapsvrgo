local PlayerCmptBase = require("PlayerCmptBaseLogic")
local Log = require("Log")
local PlayerCmptMap = require("PlayerCmptMapData")
local MapMgr = require("MapMgrLogic")

function PlayerCmptMap.new(owner)
    -- 本质是 setmetatable(PlayerCmptBase.new(owner), {__index=PlayerCmptMap})
    local self = setmetatable(PlayerCmptBase.new(owner), PlayerCmptMap)

    -- 组件内数据
    self.nowMapId = -1

    return self
end

function PlayerCmptMap:OnTick()
end

function PlayerCmptMap:OnLogin()
    local joinMapId = 2
    local map = MapMgr.GetMap(joinMapId);
    if map == nil then
        return
    end
    if map:PlayerJoinMap(self:GetPlayer():GetPlayerID()) then
        self.nowMapId = joinMapId
    end
end

function PlayerCmptMap:OnLogout()
    if self.nowMapId > 0 then
        local map = MapMgr.GetMap(self.nowMapId);
        if map == nil then
            return
        end
        if map:PlayerExitMap(self:GetPlayer():GetPlayerID()) then
            self.nowMapId = -1
        end
    end
end

return PlayerCmptMap
