---@class FSRoom:FSRoomType
local FSRoom = require("FSRoomData")
local Log = require("Log")

-- 构造新的FSRoom对象
---@return FSRoom
function FSRoom.new(roomId)
    ---@type FSRoom
    local self = setmetatable({}, FSRoom); -- 本质是 setmetatable({},{_index=FSRoom})

    -- 模拟FSRoom的DB字段
    self.FSRoomDbData = {
        id = roomId,
        name = "FSRoom_" .. tostring(roomId)
    };

    self.roomPlayers = {};
    return self
end

---@return FSRoomDbDataType
function FSRoom:GetFSRoomDbData()
    return self.FSRoomDbData;
end

function FSRoom:OnTick()
    -- Log:Error("FSRoom %d", self:GetFSRoomDbData().id)
end

return FSRoom;
