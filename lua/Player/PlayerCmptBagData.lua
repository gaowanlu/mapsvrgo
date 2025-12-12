PlayerCmptBag = PlayerCmptBag or {}
local PlayerCmptBase = require("PlayerCmptBaseLogic")

-- PlayerCmptBag类继承PlayerCmptBase类
setmetatable(PlayerCmptBag, {
    __index = PlayerCmptBase
})

PlayerCmptBag.__index = PlayerCmptBag

return PlayerCmptBag
