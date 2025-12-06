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
    -- 每帧时间间隔
    self.MapDbData.DT_MS = 1000 // self.MapDbData.TICK_RATE
    self.MapDbData.lastTickTimeMS = 0

    return self
end

function Map:GetMapDbData()
    return self.MapDbData;
end

function Map:OnTick()
    local timeMS = TimeMgr.GetMS()
    if (timeMS - self.MapDbData.lastTickTimeMS) >= self.MapDbData.DT_MS then
        self.MapDbData.lastTickTimeMS = timeMS
        -- Log:Error("MapId %d MS %d", self.MapDbData.id, timeMS)
    end
end

return Map;
