MapSvr = MapSvr or {}
local Log = require("Log");
local Debug = require("DebugLogic")
local MsgHandler = require("MsgHandlerLogic")
local PlayerMgr = require("PlayerMgrLogic")
local MapMgr = require("MapMgrLogic")
local FrameSyncRoomMgr = require("FrameSyncRoomMgrLogic")
local Map3DMgr = require("Map3DMgrLogic")

function MapSvr.OnInit()
end

function MapSvr.OnStop()
    PlayerMgr.OnStop()
    MapMgr.OnStop()
    FrameSyncRoomMgr.OnStop()
    Map3DMgr.OnStop();
end

function MapSvr.OnTick()
    PlayerMgr.OnTick()
    MapMgr.OnTick()
    FrameSyncRoomMgr.OnTick()
    Map3DMgr.OnTick();
end

function MapSvr.OnReload()
    -- hot load PlayerLogic scriptss
    local reloadList = {}
    table.insert(reloadList, "DebugLogic")
    table.insert(reloadList, "PlayerLogic")
    table.insert(reloadList, "PlayerMgrLogic")
    table.insert(reloadList, "PlayerCmptBaseLogic")
    table.insert(reloadList, "PlayerCmptInfoLogic")
    table.insert(reloadList, "PlayerCmptBagLogic")
    table.insert(reloadList, "PlayerCmptMapLogic")
    table.insert(reloadList, "PlayerCmptMap3DLogic");
    table.insert(reloadList, "MapLogic")
    table.insert(reloadList, "MapMgrLogic")
    table.insert(reloadList, "FrameSyncRoomLogic")
    table.insert(reloadList, "FrameSyncRoomMgrLogic")
    table.insert(reloadList, "MsgHandlerLogic")
    table.insert(reloadList, "ConfigTableMgrLogic")
    table.insert(reloadList, "TimeMgrLogic")
    table.insert(reloadList, "Map3DLogic");
    table.insert(reloadList, "Map3DMgrLogic");


    for i, name in ipairs(reloadList) do
        package.loaded[name] = nil;
    end

    for i, name in ipairs(reloadList) do
        local ok, module = pcall(require, name)
        if ok then
            Log:Error("%s.lua Reloaded", name);
        else
            Log:Error("%s.lua Reload Err %s", name, tostring(module))
        end
    end

    -- 初始化一张地图
    MapMgr.CreateMap(2)
    -- 初始化一个帧同步房间
    FrameSyncRoomMgr.CreateRoom(3)
    -- 初始化一个3D地图
    Map3DMgr.CreateMap(4);
end

function MapSvr.OnLuaVMRecvMessage(msg_type, cmd, message, uint64_param1, int64_param2, str_param3)
    -- Log:Error("OnLuaVMRecvMessage cmd[%d] uint64_param1[%d] int64_param2[%d] str_param3[%s]", cmd, uint64_param1, int64_param2, str_param3)
    if msg_type == 1 then -- 客户端
        local clientGID = uint64_param1
        local workerIdx = int64_param2
        MsgHandler:HandlerMsgFromClient(clientGID, workerIdx, cmd, message);
    elseif msg_type == 2 then -- ipc
        MsgHandler:HandlerMsgFromOther(cmd, message, str_param3);
    elseif msg_type == 3 then -- udp
        MsgHandler:HandlerMsgFromUDP(cmd, message, str_param3, int64_param2);
    else
        Log:Error("OnLuaVMRecvMessage Unknown msg_type %d", msg_type)
    end
end

return MapSvr;
