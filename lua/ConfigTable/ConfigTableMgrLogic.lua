local ConfigTableMgr = require("ConfigTableMgrData");

ConfigTableMgr.Map2DConfig = {
    mapIdList = {
        1,
        2
    },
};

---@return integer
function ConfigTableMgr.Map2DConfig:GetMapIdCount()
    return #self.mapIdList
end

---@param iIdx integer
---@return integer
function ConfigTableMgr.Map2DConfig:GetMapIdAt(iIdx)
    ---@diagnostic disable-next-line: return-type-mismatch
    return self.mapIdList[iIdx];
end

ConfigTableMgr.Map3DConfig = {
    mapIdList = {
        4,
        5
    },
};

---@return integer
function ConfigTableMgr.Map3DConfig:GetMap3DIdCount()
    return #self.mapIdList
end

---@param iIdx integer
---@return integer
function ConfigTableMgr.Map3DConfig:GetMap3DIdAt(iIdx)
    ---@diagnostic disable-next-line: return-type-mismatch
    return self.mapIdList[iIdx];
end

ConfigTableMgr.FrameSyncRoomConfig = {
    roomIdList = {
        6,
        7
    },
};

---@return integer
function ConfigTableMgr.FrameSyncRoomConfig:GetRoomIdCount()
    return #self.roomIdList
end

---@param iIdx integer
---@return integer
function ConfigTableMgr.FrameSyncRoomConfig:GetRoomIdAt(iIdx)
    ---@diagnostic disable-next-line: return-type-mismatch
    return self.roomIdList[iIdx];
end

return ConfigTableMgr;
