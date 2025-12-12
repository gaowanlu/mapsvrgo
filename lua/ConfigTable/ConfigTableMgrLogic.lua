local ConfigTableMgr = require("ConfigTableMgrData");

---@class UserConfig
---@field userId string
---@field userName string
---@field password string

-- 在此定义你的配置数据
---@class ConfigTableMgr.UserConfigs
ConfigTableMgr.UserConfigs = {
    ---@type table<string,UserConfig>
    data = {
        ["1"] = { userId = "1", userName = "1", password = "1" },
        ["2"] = { userId = "2", userName = "2", password = "2" },
        ["3"] = { userId = "3", userName = "3", password = "3" },
        ["4"] = { userId = "4", userName = "4", password = "4" },
        ["5"] = { userId = "5", userName = "5", password = "5" },
        ["6"] = { userId = "6", userName = "6", password = "6" },
        ["7"] = { userId = "7", userName = "7", password = "7" },
        ["8"] = { userId = "8", userName = "8", password = "8" },
    }
};

---@param userId string 用户ID
---@return UserConfig
function ConfigTableMgr.UserConfigs:get(userId)
    return self.data[tostring(userId)];
end

return ConfigTableMgr;
