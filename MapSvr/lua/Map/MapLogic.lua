-- MapLogic.lua logic script, reloadable
---@class MapPlayerType 地图内的玩家
---@field x number 当前所在像素坐标x
---@field y number 当前所在像素坐标y
---@field vX number x轴速度
---@field vY number y轴速度
---@field dirX number 客户端输入方向x
---@field dirY number 客户端输入方向y
---@field maxSpeed number 目标最大速度 px/s
---@field accel number 加速度 px/s^2
---@field bodyRadius number 角色碰撞半径
---@field bodyMass number 角色的碰撞半径
---@field friction number 每帧速度衰减系数
---@field bounce number 角色撞到障碍物时的反弹系数
---@field lastSeq number 最后收到并应用的客户端输入seq
---@field lastClientTime number 客户端发送该seq时的客户端时间(ms)

---@class TileMapType
---@field tileSize integer 瓦片数
---@field width integer 每个瓦片像素宽度
---@field height integer 每个瓦片像素高度
---@field data table<integer,integer> 瓦片像素数据

---@class MapDbDataType
---@field id integer 地图ID
---@field TICK_RATE integer 帧率
---@field DT_MS integer 每帧时间间隔 毫秒
---@field lastTickTimeMS number 执行上一次tick的毫秒时间戳
---@field durationAccumulator number 帧时常累计时间毫秒

---@class MapType
---@field players table<string, MapPlayerType> 地图内的所有玩家
---@field tileMap TileMapType
---@field MapDbData MapDbDataType

---@class Map:MapType
local Map = require("MapData")
local Log = require("Log")
local TimeMgr = require("TimeMgrLogic")

-- 构造新的Map对象
---@param mapId integer 地图ID
---@return Map 新的地图对象
function Map.new(mapId)
    ---@type Map
    local self = setmetatable({}, Map); -- 本质是 setmetatable({}, {__index = Map})

    -- 模拟Map的DB字段
    self.MapDbData = {
        id = mapId,
        name = "Map_" .. tostring(mapId),
        TICK_RATE = 20,
        DT_MS = 1000 // 20,
        lastTickTimeMS = 0,
        durationAccumulator = 0
    };

    -- 地图相关信息
    ---@type TileMapType
    self.tileMap = {
        tileSize = 50,
        width = 400,
        height = 400,
        data = {} -- 400*400
    };
    -- 初始化tileMap.data
    for i = 0, self.tileMap.width * self.tileMap.height do
        self.tileMap.data[i] = 0 -- 设为默认值
    end

    -- 地图内的Player
    ---@type table<string,MapPlayerType>
    self.players = {};

    return self
end

---@return MapDbDataType
function Map:GetMapDbData()
    return self.MapDbData;
end

function Map:OnTick()
    local timeMS = TimeMgr.GetMS()

    local frameTime = timeMS - self.MapDbData.lastTickTimeMS
    if frameTime > 250 then
        frameTime = 250 -- 防止卡顿时爆炸
    end
    self.MapDbData.lastTickTimeMS = timeMS
    self.MapDbData.durationAccumulator = self.MapDbData.durationAccumulator + frameTime

    while self.MapDbData.durationAccumulator >= self.MapDbData.DT_MS do
        -- 一次固定步长的逻辑更新
        self:FixedUpdate()
        self.MapDbData.durationAccumulator = self.MapDbData.durationAccumulator - self.MapDbData.DT_MS
    end
end

function Map:FixedUpdate()
    -- Log:Error("MapId %d FixedUpdate FinSpawnPoint x %d y %d", self.MapDbData.id, self:FindSpawnPoint().x,
    --     self:FindSpawnPoint().y)
end

-- 所有玩家出生点相同（地图中心）
function Map:FindSpawnPoint()
    local mapW = self.tileMap.width * self.tileMap.tileSize
    local mapH = self.tileMap.height * self.tileMap.tileSize
    return { x = mapW // 2, y = mapH // 2 }
end

-- 新玩家加入地图
---@param playerId string
---@return boolean
function Map:PlayerJoinMap(playerId)
    Log:Error("NewPlayerJoinMap id %d playerId %s", self.MapDbData.id, playerId)

    local spawnPoint = self:FindSpawnPoint();

    ---@type MapPlayerType
    local newMapPlayer = {
        x = spawnPoint.x,
        y = spawnPoint.y,
        vX = 0,
        vY = 0,
        dirX = 0,
        dirY = 0,
        maxSpeed = 200,
        accel = 1200,

        bodyRadius = 12,
        bodyMass = 1,
        friction = 0.90,
        bounce = 0.40,

        lastSeq = 0,
        lastClientTime = 0,
    };

    self.players[playerId] = newMapPlayer;

    return true
end

-- 玩家离开地图
---@param playerId string
---@return boolean
function Map:PlayerExitMap(playerId)
    Log:Error("PlayerExitMap id %d playerId %s", self.MapDbData.id, playerId)

    ---@type MapPlayerType
    local targetPlayer = self.players[playerId]

    if targetPlayer ~= nil then
        self.players[playerId] = nil
        return true
    end

    return false
end

return Map;
