---@class Vec3i
---@field x integer
---@field y integer
---@field z integer

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
    local y = self.MapDbData.size.y // 2;
    local z = 0;
    return { x = x, y = y, z = z };
end

-- 新玩家加入地图
---@param playerId string
---@param userId string
---@return boolean
function Map3D:PlayerJoinMap(playerId, userId)
    return false;
end

-- 玩家离开地图
---@param userId string
---@return boolean
function Map3D:PlayerExitMap(userId)
    return false;
end

---@param userId string
---@param dirX number
---@param dirY number
---@param dirZ number
---@param seq number
---@param clientTime number
function Map3D:MapPlayerInput(userId,
                              dirX,
                              dirY,
                              dirZ,
                              seq,
                              clientTime)
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
