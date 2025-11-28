local PlayerMgr = require("PlayerMgrData");
local Player = require("PlayerLogic")
local Log = require("Log")

PlayerMgr["players"] = PlayerMgr["players"] or {}

function PlayerMgr.CreatePlayer(playerId)
    if PlayerMgr.players[playerId] then
        Log:Error("Already exists Player playerId %d", playerId)
        return PlayerMgr.players[playerId]
    end

    Log:Error("Create new Player playerId[%d]", playerId)
    local player = Player.new(playerId)
    PlayerMgr.players[playerId] = player
    return player
end

function PlayerMgr.GetPlayer(playerId)
    return PlayerMgr.players[playerId]
end

function PlayerMgr.RemovePlayer(playerId)
    PlayerMgr.players[playerId] = nil
    Log:Error("RemovePlayer from PlayerMgr playerId %d", playerId);
end

function PlayerMgr.OnTick()
    -- Log:Error("OnTickAll Player")
    for _, player in pairs(PlayerMgr.players) do
        player:OnTick()
    end
end

function PlayerMgr.OnStop()
    Log:Error("PlayerMgr OnStop")
    for playerId, player in pairs(PlayerMgr.players) do
        PlayerMgr.RemovePlayer(playerId);
    end
end

return PlayerMgr
