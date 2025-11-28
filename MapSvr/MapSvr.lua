MapSvr = MapSvr or {}
local Log = require("Log");
local Debug = require("DebugLogic")

function MapSvr.OnInit()

end

function MapSvr.OnStop()
    PlayerMgr.OnStop()
    MapMgr.OnStop()
    FrameSyncRoomMgr.OnStop()
end

function MapSvr.OnTick()
    PlayerMgr.OnTick()
    MapMgr.OnTick()
    FrameSyncRoomMgr.OnTick()
end

function MapSvr.OnReload()
    -- hot load PlayerLogic script
    local reloadList = {}
    table.insert(reloadList, "DebugLogic")
    table.insert(reloadList, "PlayerLogic")
    table.insert(reloadList, "PlayerMgrLogic")
    table.insert(reloadList, "PlayerCmptBaseLogic")
    table.insert(reloadList, "PlayerCmptInfoLogic")
    table.insert(reloadList, "PlayerCmptBagLogic")
    table.insert(reloadList, "MapLogic")
    table.insert(reloadList, "MapMgrLogic")
    table.insert(reloadList, "FrameSyncRoomLogic")
    table.insert(reloadList, "FrameSyncRoomMgrLogic")

    for i, name in ipairs(reloadList) do
        package.loaded[name] = nil;
    end

    for i, name in ipairs(reloadList) do
        local ok, module = pcall(require, name)
        if ok then
            Log:Error("%s.lua Reloaded", name);
        else
            Log:Error("%s.lua Reload Err %s ", tostring(module or ""));
        end
    end

    -- 初始化一个玩家Player
    PlayerMgr.CreatePlayer(1)
    -- 初始化一张地图
    MapMgr.CreateMap(2)
    -- 初始化一个帧同步房间
    FrameSyncRoomMgr.CreateRoom(3)

end

function MapSvr.OnLuaVMRecvMessage(cmd, message)
    -- ProtoCmd::PROTO_CMD_DB_PLAYER = 10;
    -- if cmd == 10 then
    --     -- Log:Error("PROTO_CMD_DB_PLAYER cmd %d message %s", cmd, Debug:DebugTableToString(message))
    -- end
end

return MapSvr
