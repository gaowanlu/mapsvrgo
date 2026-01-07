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
    local integer_part, number_part = math.modf(nanoseconds / 1000)
    return integer_part;
end

---@return integer 返回毫秒时间戳
function TimeMgr.GetMS()
    local seconds, nanoseconds = avant.HighresTime()
    local integer_part, number_part = math.modf(nanoseconds / 1000000)
    return integer_part;
end

---@return number 返回秒时间戳
function TimeMgr.GetS()
    local seconds, nanoseconds = avant.HighresTime()
    return seconds
end

return TimeMgr;
