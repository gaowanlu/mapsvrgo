---@class FrameSyncRoomMgrType
---@field rooms FrameSyncRoom

---@class FrameSyncRoomMgr:FrameSyncRoomMgrType
local FrameSyncRoomMgr = require("FrameSyncRoomMgrData");
local FrameSyncRoom = require("FrameSyncRoomLogic");
local Log = require("Log");

FrameSyncRoomMgr["rooms"] = FrameSyncRoomMgr["rooms"] or {}

---@param roomId number 房间号
---@return FrameSyncRoom 房间
function FrameSyncRoomMgr.CreateRoom(roomId)
    if FrameSyncRoomMgr.rooms[roomId] then
        Log:Error("Already exists Room roomId %d", roomId)
        return FrameSyncRoomMgr.rooms[roomId]
    end

    Log:Error("Create new FrameSyncRoom roomId[%d]", roomId);
    local newRoom = FrameSyncRoom.new(roomId);
    FrameSyncRoomMgr.rooms[roomId] = newRoom;
    return newRoom;
end

---@param roomId number 房间号
---@return FrameSyncRoom 房间
function FrameSyncRoomMgr.GetRoom(roomId)
    return FrameSyncRoomMgr.rooms[roomId]
end

---@param roomId number 房间号
function FrameSyncRoomMgr.RemoveRoom(roomId)
    FrameSyncRoomMgr.rooms[roomId] = nil
    Log:Error("RemoveRoom from FrameSyncRoomMgr roomId %d", roomId)
end

function FrameSyncRoomMgr.OnTick()
    for roomId, roomObj in pairs(FrameSyncRoomMgr.rooms) do
        roomObj:OnTick();
    end
end

function FrameSyncRoomMgr.OnStop()
    Log:Error("FrameSyncRoomMgr OnStop");
    for roomId, roomObj in pairs(FrameSyncRoomMgr.rooms) do
        FrameSyncRoomMgr.RemoveRoom(roomId);
    end
end

return FrameSyncRoomMgr;
