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
    for roomId, roomItem in pairs(FrameSyncRoomMgr.rooms) do
        ---@type FrameSyncRoom
        local roomObj = roomItem;

        roomObj:OnTick();
    end
end

function FrameSyncRoomMgr.OnStop()
    Log:Error("FrameSyncRoomMgr OnStop");
    for roomId, roomObj in pairs(FrameSyncRoomMgr.rooms) do
        FrameSyncRoomMgr.RemoveRoom(roomId);
    end
end

function FrameSyncRoomMgr.OnSafeStop()
    Log:Error("FrameSyncRoomMgr.OnSafeStop()");
end

function FrameSyncRoomMgr.OnReload()
    local ConfigTableMgr = require("ConfigTableMgrLogic");
    local roomCount = ConfigTableMgr.FrameSyncRoomConfig:GetRoomIdCount();

    for i = 1, roomCount, 1 do
        local roomId = ConfigTableMgr.FrameSyncRoomConfig:GetRoomIdAt(i);

        -- 初始化一个帧同步房间
        FrameSyncRoomMgr.CreateRoom(roomId);
    end
end

return FrameSyncRoomMgr;
