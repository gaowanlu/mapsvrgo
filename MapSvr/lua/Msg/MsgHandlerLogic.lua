---@class MsgHandlerType
---@field ProtoCmd table<string,number> 协议号

---@class MsgHandler:MsgHandlerType
local MsgHandler = require("MsgHandlerData");

local Log = require("Log")
local PlayerMgr = require("PlayerMgrLogic")
local ConfigTableMgr = require("ConfigTableMgrLogic")

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
    PROOT_CMD_TUNNEL_WORKER2OTHER_LUAVM = 10,
    PROTO_CMD_TUNNEL_OTHERLUAVM2WORKERCONN = 11,
    PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_CLOSE_CLIENT_CONNECTION = 12,
    PROTO_CMD_TUNNEL_OTHERLUAVM2WORKER_CLOSE_CLIENT_CONNECTION = 13,
    PROTO_CMD_CS_REQ_LOGIN = 14,
    PROTO_CMD_CS_RES_LOGIN = 15,
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

--- 客户端来新消息了
---@param clientGID number 客户端连接gid
---@param workerIdx number 客户端连接所在worker下标
---@param cmd number 协议号
---@param message table protobufMessage
function MsgHandler:HandlerMsgFromClient(clientGID, workerIdx, cmd, message)
    local playerId = tostring(clientGID) .. "_" .. tostring(workerIdx);
    local handlers = {
        -- 有新的客户端连接
        [MsgHandler.ProtoCmd.PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_NEW_CLIENT_CONNECTION] = function()
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
                self:Send2Client(clientGID, workerIdx,
                    MsgHandler.ProtoCmd.PROTO_CMD_TUNNEL_OTHERLUAVM2WORKER_CLOSE_CLIENT_CONNECTION,
                    ProtoTunnelOtherLuaVM2WorkerCloseClientConnection);
                return
            end
        end,

        -- 客户端连接关闭
        [MsgHandler.ProtoCmd.PROTO_CMD_TUNNEL_WORKER2OTHER_EVENT_CLOSE_CLIENT_CONNECTION] = function()
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
        [MsgHandler.ProtoCmd.PROTO_CMD_CS_REQ_EXAMPLE] = function()
            local player = PlayerMgr.GetPlayerByPlayerId(playerId)

            local t = {
                testContext = message["testContext"]
            }

            if player == nil then
                t.testContext = "Not Logined In";
                self:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_RES_EXAMPLE, t)

                -- 关闭客户端的连接
                local ProtoTunnelOtherLuaVM2WorkerCloseClientConnection = {
                    gid = clientGID,
                    workerIdx = workerIdx
                };
                self:Send2Client(clientGID, workerIdx,
                    MsgHandler.ProtoCmd.PROTO_CMD_TUNNEL_OTHERLUAVM2WORKER_CLOSE_CLIENT_CONNECTION,
                    ProtoTunnelOtherLuaVM2WorkerCloseClientConnection);

                return
            end

            -- Log:Error("Recv Player from clientGID[%d] workerIdx[%d] PROTO_CMD_CS_REQ_EXAMPLE message: %s", clientGID,
            --     workerIdx, self:DebugTableToString(message));

            t.testContext = message["testContext"];
            self:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_RES_EXAMPLE, t)
        end,

        -- 登录请求处理
        [MsgHandler.ProtoCmd.PROTO_CMD_CS_REQ_LOGIN] = function()
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

            self:Send2Client(clientGID, workerIdx, MsgHandler.ProtoCmd.PROTO_CMD_CS_RES_LOGIN, {
                ret = 0,
                sessionId = playerId
            });

            createPlayer:OnLogin()
        end
    }

    -- 执行对应的 handler（默认什么都不做）
    local fn = handlers[cmd]
    if fn then
        return fn()
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
