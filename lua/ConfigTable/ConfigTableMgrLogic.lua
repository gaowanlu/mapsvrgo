local ConfigTableMgr = require("ConfigTableMgrData");

---@class Map2DConfig
---@field mapIdList table<string,integer>

-- 在此定义你的配置数据
---@class ConfigTableMgr.Map2DConfig
ConfigTableMgr.Map2DConfig = {
    mapIdList = {
        ["2"] = 2
    }
};

---@class ConfigTableMgr.Map3DConfig
ConfigTableMgr.Map3DConfig = {
    mapIdList = {
        ["4"] = 4
    }
};

---@class ConfigTableMgr.FrameSyncRoomConfig
ConfigTableMgr.FrameSyncRoomConfig = {
    roomIdList = {
        ["3"] = 3
    }
};

return ConfigTableMgr;
