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
        ["1"] = { userId = "1", userName = "Alice", password = "alice123" },
        ["2"] = { userId = "2", userName = "Bob", password = "bob456" },
        ["3"] = { userId = "3", userName = "Charlie", password = "charlie789" }
    }
};

---@param userId string 用户ID
---@return UserConfig
function ConfigTableMgr.UserConfigs:get(userId)
    return self.data[tostring(userId)];
end

return ConfigTableMgr;
