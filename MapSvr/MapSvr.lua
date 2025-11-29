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

function MapSvr.OnLuaVMRecvMessage(cmd, message, param1, param2)

    function DebugTableToString(t, indent)
        if type(t) == "string" then
            return "\"" .. tostring(t) .. "\""
        end

        if type(t) ~= "table" then
            return tostring(t)
        end

        indent = indent or 0
        local prefix = string.rep("  ", indent)
        local str = "{\n"
        for k, v in pairs(t) do
            local key = tostring(k)
            local valueStr
            if type(v) == "table" then
                valueStr = DebugTableToString(v, indent + 1)
            else
                valueStr = DebugTableToString(v)
            end
            str = str .. prefix .. "  [\"" .. key .. "\"] = " .. valueStr .. ",\n"
        end
        str = str .. prefix .. "}"
        return str
    end

    -- Log:Error("OnLuaVMRecvMessage cmd[%d] param1[%d] param2[%d]", cmd, param1, param2)

    -- 客户端发来得消息
    if param1 ~= 0 then
        local clientGID = param1
        local workerIdx = param2
        -- ProtoCmd::PROTO_CMD_CS_REQ_EXAMPLE = 0;
        if cmd == 0 then
            -- Log:Error("OnLuaVMRecvMessage cmd[%d] clientGID[%d] workerIdx[%d] %s", cmd, clientGID, workerIdx,
            --     DebugTableToString(message));
            -- 向客户端发送消息 ProtoCmd::PROTO_CMD_CS_RES_EXAMPLE = 1;
            local t = {
                ["testContext"] = message["testContext"]
            };
            -- message cmd param1 param2
            avant.Lua2Protobuf(t, 1, clientGID, workerIdx);
        end
    end

end

return MapSvr
