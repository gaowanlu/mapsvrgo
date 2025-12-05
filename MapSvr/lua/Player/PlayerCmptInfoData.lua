PlayerCmptInfo = PlayerCmptInfo or {}
local PlayerCmptBase = require("PlayerCmptBaseLogic")

-- PlayerCmptInfo类继承PlayerCmptBase类
setmetatable(PlayerCmptInfo, {
    __index = PlayerCmptBase
})

PlayerCmptInfo.__index = PlayerCmptInfo

return PlayerCmptInfo
