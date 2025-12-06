PlayerCmptMap = PlayerCmptMap or {}
local PlayerCmptBase = require("PlayerCmptBaseLogic")

-- PlayerCmptMap类继承PlayerCmptBase类中的方法
setmetatable(PlayerCmptMap, {
    __index = PlayerCmptBase
})

PlayerCmptMap.__index = PlayerCmptMap

return PlayerCmptMap
