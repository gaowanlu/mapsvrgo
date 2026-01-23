---@class PlayerCmptFrameSyncRoomType:PlayerCmptBase
---@field nowRoomId integer

local PlayerCmptBase = require("PlayerCmptBaseLogic")

---@class PlayerCmptFrameSyncRoom:PlayerCmptFrameSyncRoomType
local PlayerCmptFrameSyncRoom = require("PlayerCmptFrameSyncRoomData")

local Log = require("Log")
local TimeMgr = require("TimeMgrLogic")

---@param owner Player
---@return PlayerCmptFrameSyncRoom
function PlayerCmptFrameSyncRoom.new(owner)
    local self = setmetatable(PlayerCmptBase.new(owner), PlayerCmptFrameSyncRoom)

    -- 组件内数据
    self.nowRoomId = -1

    return self
end

function PlayerCmptFrameSyncRoom:OnTick()
    -- Log:Error("PlayerCmptFrameSyncRoom userId %s", self:GetPlayer():GetUserId())
end

function PlayerCmptFrameSyncRoom:OnLogin()
end

function PlayerCmptFrameSyncRoom:OnLogout()
end

return PlayerCmptFrameSyncRoom;
