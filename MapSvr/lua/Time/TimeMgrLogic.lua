local TimeMgr = require("TimeMgrData")

function TimeMgr.GetNS()
    local seconds, nanoseconds = avant.HighresTime()
    return nanoseconds
end

function TimeMgr.GetUS()
    local seconds, nanoseconds = avant.HighresTime()
    return nanoseconds // 1000
end

function TimeMgr.GetMS()
    local seconds, nanoseconds = avant.HighresTime()
    return nanoseconds // 1000000
end

function TimeMgr.GetS()
    local seconds, nanoseconds = avant.HighresTime()
    return nanoseconds // 1000000000
end

return TimeMgr;
