---@class MsgHandlerType
---@field ProtoCmd table<string,number> 协议号

---@class MsgHandler:MsgHandlerType
local MsgHandler = require("MsgHandlerData");

local Log = require("Log")

local PlayerMgr = require("PlayerMgrLogic")
local ConfigTableMgr = require("ConfigTableMgrLogic")
local ErrCode = require("ErrCode")

-- 协议号
MsgHandler.ProtoCmd = {
    PROTO_CMD_CS_REQ_EXAMPLE = 0,
    PROTO_CMD_CS_RES_EXAMPLE = 1,
    PROTO_CMD_TUNNEL_MAIN2WORKER_NEW_CLIENT = 2,
    PROTO_CMD_TUNNEL_PACKAGE = 3,
    PROTO_CMD_TUNNEL_CLIENT_FORWARD_MESSAGE = 4,
    PROTO_CMD_TUNNEL_WEBSOCKET_BROADCAST = 5,
    PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_NEW_CLIENT_CONNECTION = 6,
    PROTO_CMD_TUNNEL_OTHER2WORKER_TEST = 7,
    PROTO_CMD_LUA_TEST = 8,
    PROTO_CMD_IPC_STREAM_AUTH_HANDSHAKE = 9,

    PROOT_CMD_TUNNEL_WORKER2OTHER_LUAVM = 1001,
    PROTO_CMD_TUNNEL_OTHERLUAVM2WORKERCONN = 1002,
    PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_CLOSE_CLIENT_CONNECTION = 1003,
    PROTO_CMD_TUNNEL_OTHERLUAVM2WORKER_CLOSE_CLIENT_CONNECTION = 1004,

    PROTO_CMD_CS_REQ_LOGIN = 2001,
    PROTO_CMD_CS_RES_LOGIN = 2002,

    PROTO_CMD_CS_MAP_NOTIFY_INIT_DATA = 2003,
    PROTO_CMD_CS_REQ_MAP_PING = 2004,
    PROTO_CMD_CS_RES_MAP_PONG = 2005,
    PROTO_CMD_CS_REQ_MAP_INPUT = 2006,
    PROTO_CMD_CS_MAP_NOTIFY_STATE_DATA = 2007,
    PROTO_CMD_CS_MAP_ENTER_REQ = 2008,
    PROTO_CMD_CS_MAP_ENTER_RES = 2009,
    PROTO_CMD_CS_MAP_LEAVE_REQ = 2010,
    PROTO_CMD_CS_MAP_LEAVE_RES = 2011,

    PROTO_CMD_CS_MAP3D_NOTIFY_INIT_DATA = 2012,
    PROTO_CMD_CS_REQ_MAP3D_PING = 2013,
    PROTO_CMD_CS_RES_MAP3D_PONG = 2014,
    PROTO_CMD_CS_REQ_MAP3D_INPUT = 2015,
    PROTO_CMD_CS_MAP3D_NOTIFY_STATE_DATA = 2016,
    PROTO_CMD_CS_MAP3D_ENTER_REQ = 2017,
    PROTO_CMD_CS_MAP3D_ENTER_RES = 2018,
    PROTO_CMD_CS_MAP3D_LEAVE_REQ = 2019,
    PROTO_CMD_CS_MAP3D_LEAVE_RES = 2020,

    PROTO_CMD_DBSVRGO_WRITE_DBUSERRECORD_REQ = 3000,
};

function MsgHandler:DebugTableToString(t, indent)
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
            valueStr = self:DebugTableToString(v, indent + 1)
        else
            valueStr = self:DebugTableToString(v)
        end
        str = str .. prefix .. "  [\"" .. key .. "\"] = " .. valueStr .. ",\n"
    end
    str = str .. prefix .. "}"
    return str
end

--- 发送协议到客户端
---@param clientGID number 客户端连接gid
---@param workerIdx number 客户端连接所在worker下标
---@param cmd number 协议号
---@param message table protobufMessage
function MsgHandler:Send2Client(clientGID, workerIdx, cmd, message)
    avant.Lua2Protobuf(message, 1, cmd, clientGID, workerIdx, "");
end

--- 发送协议到其他进程
---@param appId string 远程进程appid
---@param cmd number 协议号
---@param message table protobufMessage
function MsgHandler:Send2IPC(appId, cmd, message)
    avant.Lua2Protobuf(message, 2, cmd, 0, -1, appId);
end

--- 发送UDP数据
---@param ip string 目标UDP字符串
---@param port number 目标UDP端口
---@param cmd number 协议号
---@param message table protobufMessage
function MsgHandler:Send2UDP(ip, port, cmd, message)
    avant.Lua2Protobuf(message, 3, cmd, 0, port, ip);
end

---@type table<number,function>
MsgHandler.MsgFromClientCmd2Func = {
    -- 有新的客户端连接
    [MsgHandler.ProtoCmd.PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_NEW_CLIENT_CONNECTION] = function(playerId, clientGID,
                                                                                               workerIdx, cmd, message)
        if message["gid"] ~= clientGID then
            Log:Error('PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_NEW_CLIENT_CONNECTION message["gid"]%d ~= clientGID[%d]',
                message["gid"], clientGID)
            return
        end
        -- Log:Error("New Client Connection gid[%d] workerIdx[%d]", clientGID, workerIdx)

        local player = PlayerMgr.GetPlayerByPlayerId(playerId)

        if player ~= nil then
            Log:Error("Fatal Player already exists for gid[%d] workerIdx[%d]", clientGID, workerIdx)
            -- 关闭客户端的连接
            local ProtoTunnelOtherLuaVM2WorkerCloseClientConnection = {
                gid = clientGID,
                workerIdx = workerIdx
            };
            MsgHandler:Send2Client(clientGID, workerIdx,
                MsgHandler.ProtoCmd.PROTO_CMD_TUNNEL_OTHERLUAVM2WORKER_CLOSE_CLIENT_CONNECTION,
                ProtoTunnelOtherLuaVM2WorkerCloseClientConnection);
            return
        end
    end,

    -- 客户端连接关闭
    [MsgHandler.ProtoCmd.PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_CLOSE_CLIENT_CONNECTION] = function(playerId, clientGID,
                                                                                                 workerIdx, cmd, message)
        if message["gid"] ~= clientGID then
            Log:Error(
                'PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_CLOSE_CLIENT_CONNECTION message["gid"]%d ~= clientGID[%d]',
                message["gid"], clientGID)
            return
        end
        -- Log:Error("Close Client Connection gid[%d] workerIdx[%d]", clientGID, workerIdx)

        local player = PlayerMgr.GetPlayerByPlayerId(playerId)
        if player ~= nil then
            player:OnLogout()
            PlayerMgr.RemovePlayerByPlayerId(playerId)
        else
            -- Log:Error("Player does not exist for gid[%d] workerIdx[%d]", clientGID, workerIdx)
        end
    end,

    -- 示例请求处理
    [MsgHandler.ProtoCmd.PROTO_CMD_CS_REQ_EXAMPLE] = function(playerId, clientGID, workerIdx, cmd, message)
        local player = PlayerMgr.GetPlayerByPlayerId(playerId)

        local t = {
            testContext = message["testContext"]
        }

        if player == nil then
            t.testContext = "Not Logined In";
            MsgHandler:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_RES_EXAMPLE, t)

            -- 关闭客户端的连接
            local ProtoTunnelOtherLuaVM2WorkerCloseClientConnection = {
                gid = clientGID,
                workerIdx = workerIdx
            };
            MsgHandler:Send2Client(clientGID, workerIdx,
                MsgHandler.ProtoCmd.PROTO_CMD_TUNNEL_OTHERLUAVM2WORKER_CLOSE_CLIENT_CONNECTION,
                ProtoTunnelOtherLuaVM2WorkerCloseClientConnection);

            return
        end

        -- Log:Error("Recv Player from clientGID[%d] workerIdx[%d] PROTO_CMD_CS_REQ_EXAMPLE message: %s", clientGID,
        --     workerIdx, self:DebugTableToString(message));

        t.testContext = message["testContext"];
        MsgHandler:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_RES_EXAMPLE, t)
    end,

    -- 登录请求处理
    [MsgHandler.ProtoCmd.PROTO_CMD_CS_REQ_LOGIN] = function(playerId, clientGID, workerIdx, cmd, message)
        -- 检查其是否有了玩家对象 有玩家对象的肯定是重复登录了
        local player = PlayerMgr.GetPlayerByPlayerId(playerId)
        if player ~= nil then
            Log:Error("Player already exists for gid[%d] workerIdx[%d]", clientGID, workerIdx)
            return
        end

        -- Log:Error("Login Request from clientGID[%d] workerIdx[%d] message: %s", clientGID,
        --     workerIdx, self:DebugTableToString(message));

        local userConfig = ConfigTableMgr.UserConfigs:get(message["userId"])
        if userConfig == nil then
            Log:Error("UserConfig not found for userId[%s]", message["userId"])
            return
        end
        -- 验证密码
        if userConfig.password ~= message["password"] then
            Log:Error("Password incorrect for userId[%s]", message["userId"])
            return
        end

        -- 查userId是否已经有了玩家对象 有的话说明重复登录了
        local playerByUserId = PlayerMgr.GetPlayerByUserId(userConfig.userId)
        if playerByUserId ~= nil then
            Log:Error("UserId[%s] already logged in", userConfig.userId)
            return
        end

        -- 测试发向dbsvrgo
        MsgHandler:Send2IPC("1.1.2.1", MsgHandler.ProtoCmd.PROTO_CMD_DBSVRGO_WRITE_DBUSERRECORD_REQ, {
            op = 1,
            id = 1,
            userId = userConfig.userId,
            password = userConfig.password,
            baseInfo = {
                level = math.random(0, 100)
            }
        });

        -- 创建玩家对象
        local createPlayer = PlayerMgr.CreatePlayer(playerId)
        if createPlayer == nil then
            Log:Error("Failed to create player for gid[%d] workerIdx[%d]", clientGID, workerIdx)
            return
        end

        -- 将 gid_workerIdx 和 userId 关联到 Player 对象上
        -- PlayerMgr 的 userId 与 playerId的双向映射
        PlayerMgr.BindUserIdAndPlayerId(userConfig.userId, playerId);
        -- 设置 Player 的 userId、clientGID、workerIdx
        createPlayer:SetUserId(userConfig.userId)
        createPlayer:SetClientGID(clientGID)
        createPlayer:SetWorkerIdx(workerIdx)

        MsgHandler:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_RES_LOGIN, {
            ret = ErrCode.OK,
            sessionId = playerId
        });

        createPlayer:OnLogin()
    end,

    -- PROTO_CMD_CS_REQ_MAP_PING 地图内客户端心跳请求
    [MsgHandler.ProtoCmd.PROTO_CMD_CS_REQ_MAP_PING] = function(playerId, clientGID, workerIdx, cmd, message)
        local player = PlayerMgr.GetPlayerByPlayerId(playerId);
        if player == nil then
            return
        end

        local serverTimeMS = player:GetComponents().map:PingReq();

        MsgHandler:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_RES_MAP_PONG, {
            clientTime = message.clientTime,
            serverTime = serverTimeMS
        });
    end,

    --- ROTO_CMD_CS_REQ_MAP_INPUT 地图内客户端上报输入
    [MsgHandler.ProtoCmd.PROTO_CMD_CS_REQ_MAP_INPUT] = function(playerId, clientGID, workerIdx, cmd, message)
        local player = PlayerMgr.GetPlayerByPlayerId(playerId);
        if player == nil then
            return
        end

        player:GetComponents().map:MapInputReq(message);
    end,

    --- PROTO_CMD_CS_MAP_ENTER_REQ 进入地图请求
    [MsgHandler.ProtoCmd.PROTO_CMD_CS_MAP_ENTER_REQ] = function(playerId, clientGID, workerIdx, cmd, message)
        local player = PlayerMgr.GetPlayerByPlayerId(playerId);
        if player == nil then
            return
        end
        local enterMapRet = player:GetComponents().map:MapEnterReq(message.mapId);
        MsgHandler:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_MAP_ENTER_RES, {
            ret = enterMapRet,
            mapId = message.mapId
        });
    end,

    --- PROTO_CMD_CS_MAP_LEAVE_REQ 离开地图请求
    [MsgHandler.ProtoCmd.PROTO_CMD_CS_MAP_LEAVE_REQ] = function(playerId, clientGID, workerIdx, cmd, message)
        local player = PlayerMgr.GetPlayerByPlayerId(playerId);
        if player == nil then
            return
        end
        local leaveMapRet = player:GetComponents().map:MapLeaveReq();
        MsgHandler:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_MAP_LEAVE_RES, {
            ret = leaveMapRet
        });
    end,

    --- PROTO_CMD_CS_REQ_MAP3D_PING 地图3D内心跳请求
    [MsgHandler.ProtoCmd.PROTO_CMD_CS_REQ_MAP3D_PING] = function(playerId, clientGID, workerIdx, cmd, message)
        local player = PlayerMgr.GetPlayerByPlayerId(playerId);
        if player == nil then
            return
        end

        local serverTimeMS = player:GetComponents().map3d:PingReq();

        MsgHandler:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_RES_MAP3D_PONG, {
            clientTime = message.clientTime,
            serverTime = serverTimeMS
        });
    end,

    --- PROTO_CMD_CS_REQ_MAP3D_INPUT 地图3D内客户端上报输入
    [MsgHandler.ProtoCmd.PROTO_CMD_CS_REQ_MAP3D_INPUT] = function(playerId, clientGID, workerIdx, cmd, message)
        local player = PlayerMgr.GetPlayerByPlayerId(playerId);
        if player == nil then
            return
        end

        player:GetComponents().map3d:MapInputReq(message);
    end,

    --- PROTO_CMD_CS_MAP3D_ENTER_REQ 进入地图3D请求
    [MsgHandler.ProtoCmd.PROTO_CMD_CS_MAP3D_ENTER_REQ] = function(playerId, clientGID, workerIdx, cmd, message)
        local player = PlayerMgr.GetPlayerByPlayerId(playerId);
        if player == nil then
            return
        end
        local enterMapRet = player:GetComponents().map3d:MapEnterReq(message.mapId);
        MsgHandler:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_MAP3D_ENTER_RES, {
            ret = enterMapRet,
            mapId = message.mapId
        });
    end,

    --- PROTO_CMD_CS_MAP3D_LEAVE_REQ 离开地图3D请求
    [MsgHandler.ProtoCmd.PROTO_CMD_CS_MAP3D_LEAVE_REQ] = function(playerId, clientGID, workerIdx, cmd, message)
        local player = PlayerMgr.GetPlayerByPlayerId(playerId);
        if player == nil then
            return
        end
        local leaveMapRet = player:GetComponents().map3d:MapLeaveReq();
        MsgHandler:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_MAP3D_LEAVE_RES, {
            ret = leaveMapRet
        });
    end,

};

--- 客户端来新消息了
---@param clientGID number 客户端连接gid
---@param workerIdx number 客户端连接所在worker下标
---@param cmd number 协议号
---@param message table protobufMessage
function MsgHandler:HandlerMsgFromClient(clientGID, workerIdx, cmd, message)
    local playerId = tostring(clientGID) .. "_" .. tostring(workerIdx);

    -- 执行对应的 handler（默认什么都不做）
    local fn = MsgHandler.MsgFromClientCmd2Func[cmd]
    if fn ~= nil then
        return fn(playerId, clientGID, workerIdx, cmd, message)
    end
end

--- 其他进程来新消息了
---@param cmd number 协议号
---@param message table 协议
---@param app_id string 从哪个进程appid来的消息
function MsgHandler:HandlerMsgFromOther(cmd, message, app_id)
    local handlers = {
        [MsgHandler.ProtoCmd.PROTO_CMD_CS_REQ_EXAMPLE] = function()
            local t = {
                testContext = message["testContext"]
            }
            -- 原逻辑是 Send2IPC 但发送的是 message，而不是 t
            self:Send2IPC(app_id, MsgHandler.ProtoCmd.PROTO_CMD_CS_RES_EXAMPLE, message)
        end
    }

    local fn = handlers[cmd]
    if fn then
        return fn()
    end
end

--- 接收到了新的UDP消息
---@param cmd number 协议号
---@param message table 协议
---@param ip string UDP客户端的IP
---@param port number UDP客户端的端口
function MsgHandler:HandlerMsgFromUDP(cmd, message, ip, port)
    local handlers = {
        [MsgHandler.ProtoCmd.PROTO_CMD_CS_REQ_EXAMPLE] = function()
            local t = {
                testContext = message["testContext"]
            }
            self:Send2UDP(ip, port, MsgHandler.ProtoCmd.PROTO_CMD_CS_RES_EXAMPLE, t);
        end
    }

    local fn = handlers[cmd]
    if fn then
        return fn()
    end
end

return MsgHandler;
