-- MapLogic.lua logic script, reloadable
local Map = require("MapData")
local Log = require("Log")

-- 构造新的Map对象
function Map.new(mapId)
    local self = setmetatable({}, Map); -- 本质是 setmetatable({}, {__index = Map})

    -- 模拟Map的DB字段
    self.MapDbData = {}
    self.MapDbData.id = mapId
    self.MapDbData.name = "Map_" .. tostring(mapId)

    return self
end

function Map:GetMapDbData()
    return self.MapDbData;
end

function Map:OnTick()
    -- Log:Error("MapId %d", self:GetMapDbData().id)
end

return Map;
