---@class FSRoomPlayer:FSRoomPlayerType
local FSRoomPlayer = require("FSRoomPlayerData")
local Log = require("Log")

---构造新的FSRoomPlayer对象
---@param userId string
---@param room FSRoom
---@return FSRoomPlayer
function FSRoomPlayer.new(userId, room)
    ---@type FSRoomPlayer
    local self = setmetatable({}, FSRoomPlayer);
    self.userId = userId;
    self.room = room;
    return self;
end

function FSRoomPlayer:OnTick()
end

return FSRoomPlayer;
