MapSvr = MapSvr or {}
local Log = require("Log");
local Debug = require("DebugLogic")
local MsgHandler = require("MsgHandlerLogic")

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
    table.insert(reloadList, "MsgHandlerLogic")

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

function MapSvr.OnLuaVMRecvMessage(cmd, message, uint64_param1, int64_param2, str_param3)
    -- Log:Error("OnLuaVMRecvMessage cmd[%d] uint64_param1[%d] int64_param2[%d] str_param3[%s]", cmd, uint64_param1, int64_param2, str_param3)
    -- 客户端发来得消息
    if int64_param2 >= 0 then
        local clientGID = uint64_param1
        local workerIdx = int64_param2
        MsgHandler:HandlerMsgFromClient(clientGID, workerIdx, cmd, message);
    elseif int64_param2 == -1 then -- 进程间通过other通信
        MsgHandler:HandlerMsgFromOther(cmd, message, str_param3);
    else
        Log:Error("OnLuaVMRecvMessage Unknown int64_param2[%d]", int64_param2)
    end
end

return MapSvr
