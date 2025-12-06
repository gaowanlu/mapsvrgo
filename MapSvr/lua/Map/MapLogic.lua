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
    -- Log:Error("MapId %d FixedUpdate", self.MapDbData.id)
end

return Map;
