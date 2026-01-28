---@class FSRoomMgr:FSRoomMgrType
local FSRoomMgr = require("FSRoomMgrData");
local FSRoom = require("FSRoomLogic");
local Log = require("Log");

FSRoomMgr["rooms"] = FSRoomMgr["rooms"] or {}

---@param roomId number 房间号
---@return FSRoom 房间
function FSRoomMgr.CreateRoom(roomId)
    if FSRoomMgr.rooms[roomId] then
        Log:Error("Already exists Room roomId %d", roomId)
        return FSRoomMgr.rooms[roomId]
    end

    Log:Error("Create new FSRoom roomId[%d]", roomId);
    local newRoom = FSRoom.new(roomId);
    FSRoomMgr.rooms[roomId] = newRoom;
    return newRoom;
end

---@param roomId number 房间号
---@return FSRoom 房间
function FSRoomMgr.GetRoom(roomId)
    return FSRoomMgr.rooms[roomId]
end

---@param roomId number 房间号
function FSRoomMgr.RemoveRoom(roomId)
    FSRoomMgr.rooms[roomId] = nil
    Log:Error("RemoveRoom from FSRoomMgr roomId %d", roomId)
end

function FSRoomMgr.OnTick()
    for roomId, roomItem in pairs(FSRoomMgr.rooms) do
        ---@type FSRoom
        local roomObj = roomItem;

        roomObj:OnTick();
    end
end

function FSRoomMgr.OnStop()
    Log:Error("FSRoomMgr OnStop");
    for roomId, roomObj in pairs(FSRoomMgr.rooms) do
        FSRoomMgr.RemoveRoom(roomId);
    end
end

function FSRoomMgr.OnSafeStop()
    Log:Error("FSRoomMgr.OnSafeStop()");
end

function FSRoomMgr.OnReload()
    local ConfigTableMgr = require("ConfigTableMgrLogic");
    local roomCount = ConfigTableMgr.FSRoomConfig:GetRoomIdCount();

    for i = 1, roomCount, 1 do
        local roomId = ConfigTableMgr.FSRoomConfig:GetRoomIdAt(i);

        -- 初始化一个帧同步房间
        FSRoomMgr.CreateRoom(roomId);
    end
end

return FSRoomMgr;
