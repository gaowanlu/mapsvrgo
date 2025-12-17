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
---@field pos Vec3i 位置坐标
---@field v Vec3i 速度
---@field gravity integer 重力
---@field weight integer 重量
---@field lastSeq integer 最后收到并应用的客户端输入seq
---@field lastClientTime number 客户端发送该seq时的客户端时间(ms)
---@field dir Vec3f 方向

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
---@return Vec3i
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

end

---@param timeMS number
function Map3D:FixedUpdate(timeMS)
    --Log:Error("Map3D:FixedUpdate mapId %s", tostring(self.MapDbData.id));
    for userId, mapPlayer in pairs(self.players) do
        self:PlayerPhysicsMove(mapPlayer);
    end

    -- 同步数据
    -- PROTO_CMD_CS_MAP3D_NOTIFY_STATE_DATA
end

return Map3D;
