-- FrameSyncRoomLogic.lua logic script, reloadable

---@class FrameSyncRoomDbDataType
---@field id number 房间号
---@field name string 房间名

---@class FrameSyncRoomType
---@field FrameSyncRoomDbData FrameSyncRoomDbDataType

---@class FrameSyncRoom:FrameSyncRoomType
local FrameSyncRoom = require("FrameSyncRoomData")
local Log = require("Log")

-- 构造新的FrameSyncRoom对象
---@return FrameSyncRoom
function FrameSyncRoom.new(roomId)
    local self = setmetatable({}, FrameSyncRoom); -- 本质是 setmetatable({},{_index=FrameSyncRoom})

    -- 模拟FrameSyncRoom的DB字段
    self.FrameSyncRoomDbData = {}
    self.FrameSyncRoomDbData.id = roomId
    self.FrameSyncRoomDbData.name = "FrameSyncRoom_" .. tostring(roomId)
    return self
end

---@return FrameSyncRoomDbDataType
function FrameSyncRoom:GetFrameSyncRoomDbData()
    return self.FrameSyncRoomDbData;
end

function FrameSyncRoom:OnTick()
    -- Log:Error("FrameSyncRoom %d", self:GetFrameSyncRoomDbData().id)
end

return FrameSyncRoom;
