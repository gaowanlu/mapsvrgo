local Other = {};
local Log = require("Log");
local MapSvr = require("MapSvr")

-- Other_dbg = {};

function Other:OnInit()
    -- Other_dbg = require("emmy_core")
    -- Other_dbg.tcpListen("127.0.0.1", 9966)
    -- Other_dbg.waitIDE()

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

function Other:OnLuaVMRecvMessage(msg_type, cmd, message, uint64_param1, int64_param2, str_param3)
    --Log:Error("msg_type %d cmd %d uint64_param1 %d int64_param2 %d str_param3 %s", msg_type, cmd, uint64_param1,
    --    int64_param2, str_param3);

    MapSvr.OnLuaVMRecvMessage(msg_type, cmd, message, uint64_param1, int64_param2, str_param3)
end

return Other;
