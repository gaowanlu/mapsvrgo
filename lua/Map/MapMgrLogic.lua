---@class MapMgrType
---@field maps table<integer,Map>

---@class MapMgr:MapMgrType
local MapMgr = require("MapMgrData");
local Map = require("MapLogic");
local Log = require("Log");

-- 热重载lua会被重新执行
MapMgr.maps = MapMgr.maps or {}

---@return Map
function MapMgr.CreateMap(mapId)
    if MapMgr.maps[mapId] ~= nil then
        Log:Error("Already exists Map mapId %d", mapId)
        return MapMgr.maps[mapId]
    end

    Log:Error("Create new Map mapId[%d]", mapId)
    local newMap = Map.new(mapId)

    MapMgr.maps[mapId] = newMap

    return MapMgr.maps[mapId]
end

---@param mapId integer
---@return Map
function MapMgr.GetMap(mapId)
    return MapMgr.maps[mapId]
end

---@param mapId integer
function MapMgr.RemoveMap(mapId)
    MapMgr.maps[mapId] = nil
    Log:Error("RemoveMap from MapMgr mapId %d", mapId)
end

function MapMgr.OnTick()
    for mapId, mapObj in pairs(MapMgr.maps) do
        mapObj:OnTick();
    end
end

function MapMgr.OnStop()
    Log:Error("MapMgr OnStop");
    for mapId, mapObj in pairs(MapMgr.maps) do
        MapMgr.RemoveMap(mapId);
    end
end

return MapMgr;
