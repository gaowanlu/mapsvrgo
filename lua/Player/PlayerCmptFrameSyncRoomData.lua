PlayerCmptFrameSyncRoom = PlayerCmptFrameSyncRoom or {}
local PlayerCmptBase = require("PlayerCmptBaseLogic")

setmetatable(PlayerCmptFrameSyncRoom, {
    __index = PlayerCmptBase
})

PlayerCmptFrameSyncRoom.__index = PlayerCmptFrameSyncRoom

return PlayerCmptFrameSyncRoom;
