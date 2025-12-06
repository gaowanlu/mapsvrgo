---@class TimeMgr
local TimeMgr = require("TimeMgrData")

---@return number 返回纳秒时间戳
function TimeMgr.GetNS()
    local seconds, nanoseconds = avant.HighresTime()
    return nanoseconds
end

---@return number 返回微秒时间戳
function TimeMgr.GetUS()
    local seconds, nanoseconds = avant.HighresTime()
    return nanoseconds // 1000
end

---@return number 返回纳秒时间戳
function TimeMgr.GetMS()
    local seconds, nanoseconds = avant.HighresTime()
    return nanoseconds // 1000000
end

---@return number 返回秒时间戳
function TimeMgr.GetS()
    local seconds, nanoseconds = avant.HighresTime()
    return nanoseconds // 1000000000
end

return TimeMgr;
