package.path = avant.LuaDir .. "/?.lua;" .. package.path
package.path = avant.LuaDir .. "/Player/?.lua;" .. package.path
package.path = avant.LuaDir .. "/Debug/?.lua;" .. package.path
package.path = avant.LuaDir .. "/Map/?.lua;" .. package.path
package.path = avant.LuaDir .. "/FrameSync/?.lua;" .. package.path
package.path = avant.LuaDir .. "/Msg/?.lua;" .. package.path
package.path = avant.LuaDir .. "/ConfigTable/?.lua;" .. package.path
package.path = avant.LuaDir .. "/Time/?.lua;" .. package.path
package.path = avant.LuaDir .. "/ErrCode/?.lua;" .. package.path
package.path = avant.LuaDir .. "/ProtoLua/?.lua;" .. package.path

local avant = require("Avant")
local Log = require("Log")
local Main = require("Main")
local Worker = require("Worker")
local Other = require("Other")

function OnMainInit()
    Main:OnInit();
end

function OnMainStop()
    Main:OnStop();
end

function OnMainTick()
    Main:OnTick();
end

function OnMainReload()
    Main:OnReload();
end

function OnWorkerInit(workerIdx)
    Worker:OnInit(workerIdx);
end

function OnWorkerStop(workerIdx)
    Worker:OnStop(workerIdx);
end

function OnWorkerTick(workerIdx)
    Worker:OnTick(workerIdx);
end

function OnWorkerReload(workerIdx)
    Worker:OnReload(workerIdx);
end

function OnOtherInit()
    Other:OnInit();
end

function OnOtherStop()
    Other:OnStop();
end

function OnOtherTick()
    Other:OnTick();
end

function OnOtherReload()
    Other:OnReload();
end

function OnLuaVMRecvMessage(isMainVM, isOtherVM, isWorkerVM, workerIdx, msg_type, cmd, message, uint64_param1,
                            int64_param2, str_param3)
    if isOtherVM then
        Other:OnLuaVMRecvMessage(msg_type, cmd, message, uint64_param1, int64_param2, str_param3);
    end
end
