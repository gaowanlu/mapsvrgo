local Other = {};
local Log = require("Log");
local MapSvr = require("MapSvr")

function Other:OnInit()
    local log = "OnOtherInit";
    Log:Error(log);
    MapSvr.OnInit()
    Other:OnReload();
end

function Other:OnStop()
    local log = "OnOtherStop";
    Log:Error(log);
    MapSvr.OnStop()
end

function Other:OnTick()
    MapSvr.OnTick()
end

-- kill -10 {avant PID}
function Other:OnReload()
    Log:Error("luavm Other:OnReload");

    local reloadList = {}
    table.insert(reloadList, "MapSvr")

    for i, name in ipairs(reloadList) do
        package.loaded[name] = nil;
    end

    for i, name in ipairs(reloadList) do
        local ok, module = pcall(require, name)
        if ok then
            Log:Error("%s.lua Reloaded", name);
        else
            Log:Error("%s.lua Reload Err %s ", tostring(module or ""));
        end
    end

    MapSvr.OnReload()
end

function Other:OnLuaVMRecvMessage(cmd, message, param1, param2)
    MapSvr.OnLuaVMRecvMessage(cmd, message, param1, param2)
end

return Other;
