local ConfigTableMgr = require("ConfigTableMgrData");

-- 在此定义你的配置数据
ConfigTableMgr.UserConfigs = {
    data = {
        ["1"] = { userId = 1, userName = "Alice", password = "alice123" },
        ["2"] = { userId = 2, userName = "Bob", password = "bob456" },
        ["3"] = { userId = 3, userName = "Charlie", password = "charlie789" }
    }
};

function ConfigTableMgr.UserConfigs:get(userId)
    return self.data[tostring(userId)];
end

return ConfigTableMgr;
