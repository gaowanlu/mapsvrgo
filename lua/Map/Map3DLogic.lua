---@class Vec3i
---@field x integer
---@field y integer
---@field z integer

---@class Vec3f
---@field x number
---@field y number
---@field z number

---@class Map3DDbDataType
---@field id integer 地图ID
---@field TICK_RATE integer 帧率
---@field DT_MS integer 每帧时间间隔 毫秒
---@field lastTickTimeMS number 执行上一次tick的毫秒时间戳
---@field durationAccumulator number 帧时常累计时间毫秒
---@field size Vec3i 地图大小

---@class Map3DPlayerType
---@field userId string 用户ID
---@field pos Vec3f 位置坐标
---@field v Vec3f 速度
---@field gravity integer 重力
---@field weight integer 重量
---@field lastSeq integer 最后收到并应用的客户端输入seq
---@field lastClientTime number 客户端发送该seq时的客户端时间(ms)
---@field dir Vec3f 方向
---@field speedRatio number 速度放大比例
---@field maxSpeed number 目标最大速度 px/ms
---@field accel number 加速度 px/ms^2
---@field friction number 每帧速度衰减系数
---@field bodyRadius number 角色碰撞半径

---@class Map3DType
---@field MapDbData Map3DDbDataType
---@field players table<string,Map3DPlayerType>

---@class Map3D:Map3DType
local Map3D = require("Map3DData");
local Log = require("Log");
local TimeMgr = require("TimeMgrLogic");

-- 构造新的3DMap对象
---@param mapId integer 地图ID
---@return Map3D 新的地图对象
function Map3D.new(mapId)
    ---@type Map3D
    local self = setmetatable({}, Map3D);

    self.MapDbData = {
        id = mapId,
        TICK_RATE = 20,
        DT_MS = 1000 // 20,
        lastTickTimeMS = 0,
        durationAccumulator = 0,
        size = { x = 1000000, y = 1000000, z = 1000000 }
    };

    self.players = {};

    return self;
end

---@return Map3DDbDataType
function Map3D:GetMapDbData()
    return self.MapDbData;
end

---@return number
function Map3D:GetLastTickTimeMS()
    return self:GetMapDbData().lastTickTimeMS;
end

---@return Vec3i
function Map3D:GetSize()
    return self:GetMapDbData().size;
end

---@return integer 地图ID
function Map3D:GetMapId()
    return self.MapDbData.id;
end

---@param userId string
---@return Map3DPlayerType|nil
function Map3D:GetMapPlayerByUserId(userId)
    return self.players[userId];
end

function Map3D:OnTick()
    local timeMS = TimeMgr.GetMS();

    local frameTime = timeMS - self.MapDbData.lastTickTimeMS;
    if frameTime > 250 then
        frameTime = 250 -- 防止卡顿时爆炸
    end

    self.MapDbData.lastTickTimeMS = timeMS;
    self.MapDbData.durationAccumulator = self.MapDbData.durationAccumulator + frameTime;

    while self.MapDbData.durationAccumulator >= self.MapDbData.DT_MS do
        -- 一次固定步长的逻辑更新
        self:FixedUpdate(timeMS);
        self.MapDbData.durationAccumulator = self.MapDbData.durationAccumulator - self.MapDbData.DT_MS;
    end
end

---计算出生点
---@return Vec3f
function Map3D:FindSpawnPoint()
    local x = self.MapDbData.size.x // 2;
    local y = 0;
    local z = self.MapDbData.size.z // 2;
    return { x = x, y = y, z = z };
end

-- 新玩家加入地图
---@param playerId string
---@param userId string
---@return boolean
function Map3D:PlayerJoinMap(playerId, userId)
    if self.players[userId] ~= nil then
        return false;
    end

    Log:Error("Map3D PlayerJoinMap id %s playerId %s userId %s",
        tostring(self.MapDbData.id),
        tostring(playerId),
        tostring(userId));

    local spawnPoint = self:FindSpawnPoint();

    ---@type Map3DPlayerType
    local newMap3DPlayer = {
        userId = userId,
        pos = spawnPoint,
        v = { x = 0, y = 0, z = 0 },
        gravity = 1,
        weight = 1,
        lastSeq = 0,
        lastClientTime = 0,
        dir = { x = 0, y = 0, z = 0 },
        speedRatio = 1000,
        maxSpeed = 0.1, -- 最大速度 目标最大速度 px/ms 100px/s
        accel = 1,      -- 加速度 px/ms^2
        friction = 1.0, -- 无摩擦
        bodyRadius = 12,
    };

    self.players[userId] = newMap3DPlayer;

    -- TODO: 加入地图八叉树

    return true;
end

-- 玩家离开地图
---@param userId string
---@return boolean
function Map3D:PlayerExitMap(userId)
    Log:Error("Map3D PlayerExitMap id %s userId %s",
        tostring(self.MapDbData.id),
        userId);

    ---@type Map3DPlayerType
    local targetPlayer = self.players[userId];
    if targetPlayer ~= nil then
        -- TODO: 将玩家从八叉树中移除

        self.players[userId] = nil;
        return true;
    end

    return false;
end

---@param userId string
---@param dirX number
---@param dirY number
---@param dirZ number
---@param seq integer
---@param clientTime number
function Map3D:MapPlayerInput(userId,
                              dirX,
                              dirY,
                              dirZ,
                              seq,
                              clientTime)
    local map3DPlayer = self.players[userId];

    if map3DPlayer == nil then
        return;
    end

    if map3DPlayer.lastSeq + 1 ~= seq then
        return
    end

    -- 计算向量长度
    local len = math.sqrt(
        dirX * dirX +
        dirY * dirY +
        dirZ * dirZ);

    if len > 0.0001 then
        -- 服务器强制归一化
        dirX = dirX / len
        dirY = dirY / len
        dirZ = dirZ / len
    else
        dirX = 0
        dirY = 0
        dirZ = 0
    end

    map3DPlayer.dir.x = dirX;
    map3DPlayer.dir.y = dirY;
    map3DPlayer.dir.z = dirZ;
    map3DPlayer.lastSeq = seq;
    map3DPlayer.lastClientTime = clientTime;
end

---@param mapPlayer Map3DPlayerType
function Map3D:PlayerPhysicsMove(mapPlayer)
    --- 返回v的符号(1,-1,0)
    ---@return number
    local function sign(v)
        if v > 0 then
            return 1;
        elseif v < 0 then
            return -1;
        else
            return 0;
        end
    end

    -- 计算目标速度（由方向输入 dirX、dirY、dirZ 和 最大速度 maxSpeed 决定）
    -- 目标的X、Y、Z速度
    local targetVx = (mapPlayer.dir.x * mapPlayer.speedRatio) * mapPlayer.maxSpeed;
    local targetVy = (mapPlayer.dir.y * mapPlayer.speedRatio) * mapPlayer.maxSpeed;
    local targetVz = (mapPlayer.dir.z * mapPlayer.speedRatio) * mapPlayer.maxSpeed;

    targetVx = math.floor(targetVx);
    targetVy = math.floor(targetVy);
    targetVz = math.floor(targetVz);

    -- 当前速度到目标速度的差值
    local deltaVx = targetVx - mapPlayer.v.x -- 当前vX需要朝哪个方向变化
    local deltaVy = targetVy - mapPlayer.v.y -- 当前vY需要朝哪个方向变化
    local deltaVz = targetVz - mapPlayer.v.z -- 当前vZ需要朝哪个方向变化

    -- 每帧最大可改变的速度（加速度限制）
    -- accel * DT = 每帧最多加多少速度
    local maxDeltaV = mapPlayer.accel * self:GetMapDbData().DT_MS
    maxDeltaV = math.floor(maxDeltaV);

    local maxDeltaVX = math.abs(math.floor(maxDeltaV * mapPlayer.dir.x));
    local maxDeltaVY = math.abs(math.floor(maxDeltaV * mapPlayer.dir.y));
    local maxDeltaVZ = math.abs(math.floor(maxDeltaV * mapPlayer.dir.z));

    -- X轴速度更新（带加速度限制）
    if maxDeltaVX ~= 0 and math.abs(deltaVx) > maxDeltaVX then
        -- 需要加速，按符号方向增加 maxDeltaV
        mapPlayer.v.x = mapPlayer.v.x + sign(deltaVx) * maxDeltaVX;
    else
        -- 可以直接到达目标速度
        mapPlayer.v.x = targetVx;
    end

    -- Y轴速度更新（加速度限制）
    if maxDeltaVY ~= 0 and math.abs(deltaVy) > maxDeltaVY then
        mapPlayer.v.y = mapPlayer.v.y + sign(deltaVy) * maxDeltaVY;
    else
        mapPlayer.v.y = targetVy;
    end

    -- Z轴速度更新（加速度限制）
    if maxDeltaVZ ~= 0 and math.abs(deltaVz) > maxDeltaVZ then
        mapPlayer.v.z = mapPlayer.v.z + sign(deltaVz) * maxDeltaVZ;
    else
        mapPlayer.v.z = targetVz;
    end

    -- 根据速度移动位置
    -- mapPlayer.pos.x / mapPlayer.pos.y / mapPlayer.pos.z 是坐标，速度 * DT_MS 是位移
    mapPlayer.pos.x = mapPlayer.pos.x + math.floor((mapPlayer.v.x * self:GetMapDbData().DT_MS) / mapPlayer.speedRatio);
    mapPlayer.pos.y = mapPlayer.pos.y + math.floor((mapPlayer.v.y * self:GetMapDbData().DT_MS) / mapPlayer.speedRatio);
    mapPlayer.pos.z = mapPlayer.pos.z + math.floor((mapPlayer.v.z * self:GetMapDbData().DT_MS) / mapPlayer.speedRatio);

    -- 摩擦力（阻尼）
    -- 每帧速度*=friction,使速度逐渐衰减
    mapPlayer.v.x = math.floor(mapPlayer.v.x * mapPlayer.friction)
    mapPlayer.v.y = math.floor(mapPlayer.v.y * mapPlayer.friction)
    mapPlayer.v.z = math.floor(mapPlayer.v.z * mapPlayer.friction)

    -- 地图边界控制，限制物体不允许跑出地图
    local mapSize = self:GetSize();
    local playerRadius = mapPlayer.bodyRadius;                                                        -- 玩家半径（防止部分穿出）

    if mapPlayer.pos.x < playerRadius then mapPlayer.pos.x = playerRadius end                         -- 左边界
    if mapPlayer.pos.y < playerRadius then mapPlayer.pos.y = playerRadius end                         -- 上边界
    if mapPlayer.pos.z < playerRadius then mapPlayer.pos.z = playerRadius end                         -- 前边界
    if mapPlayer.pos.x > mapSize.x - playerRadius then mapPlayer.pos.x = mapSize.x - playerRadius end -- 右边界
    if mapPlayer.pos.y > mapSize.y - playerRadius then mapPlayer.pos.y = mapSize.y - playerRadius end -- 下边界
    if mapPlayer.pos.z > mapSize.z - playerRadius then mapPlayer.pos.z = mapSize.z - playerRadius end -- 后边界
end

---@param timeMS number
function Map3D:FixedUpdate(timeMS)
    local MsgHandler = require("MsgHandlerLogic")
    local PlayerMgr = require("PlayerMgrLogic")

    -- Log:Error("Map3D:FixedUpdate mapId %s", tostring(self.MapDbData.id));
    for userId, mapPlayer in pairs(self.players) do
        self:PlayerPhysicsMove(mapPlayer);
    end

    -- 为地图中每个玩家同步状态 PROTO_CMD_CS_MAP3D_NOTIFY_STATE_DATA
    local playersPayload = {}
    for userId, mapPlayer in pairs(self.players) do
        playersPayload[#playersPayload + 1] = {
            userId = mapPlayer.userId,
            x = math.tointeger(mapPlayer.pos.x),
            y = math.tointeger(mapPlayer.pos.y),
            z = math.tointeger(mapPlayer.pos.z),
            vX = math.tointeger(mapPlayer.v.x),
            vY = math.tointeger(mapPlayer.v.y),
            vZ = math.tointeger(mapPlayer.v.z),
            lastSeq = math.tointeger(mapPlayer.lastSeq),
            lastClientTime = math.tointeger(mapPlayer.lastClientTime)
        };
    end

    -- if #playersPayload == 0 then
    --     Log:Error('players playersPayload len %d', #playersPayload)
    -- end

    local protoCSMap3DNotifyStateData = {
        serverTime = timeMS,
        players = playersPayload
    };

    for userId, mapPlayer in pairs(self.players) do
        local loopPlayer = PlayerMgr.GetPlayerByUserId(userId)
        if loopPlayer ~= nil then
            MsgHandler:Send2Client(loopPlayer:GetClientGID(), loopPlayer:GetWorkerIdx(),
                MsgHandler.ProtoCmd.PROTO_CMD_CS_MAP3D_NOTIFY_STATE_DATA, protoCSMap3DNotifyStateData);
        end
    end
end

return Map3D;
