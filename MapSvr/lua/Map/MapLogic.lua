-- MapLogic.lua logic script, reloadable
local Map = require("MapData")
local Log = require("Log")
local TimeMgr = require("TimeMgrLogic")

-- 构造新的Map对象
function Map.new(mapId)
    local self = setmetatable({}, Map); -- 本质是 setmetatable({}, {__index = Map})

    -- 模拟Map的DB字段
    self.MapDbData = {}
    self.MapDbData.id = mapId
    self.MapDbData.name = "Map_" .. tostring(mapId)

    -- 帧率
    self.MapDbData.TICK_RATE = 20
    -- 每帧时间间隔 毫秒
    self.MapDbData.DT_MS = 1000 // self.MapDbData.TICK_RATE
    -- 执行上一次tick的毫秒时间戳
    self.MapDbData.lastTickTimeMS = 0
    -- 帧时常累计时间毫秒
    self.MapDbData.durationAccumulator = 0

    -- 地图相关信息
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
    self.Players = {
        -- ["playerId"] = { ["payload"] = "data" }
    };

    return self
end

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

return Map;
