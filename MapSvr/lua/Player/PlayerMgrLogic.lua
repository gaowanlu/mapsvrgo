local PlayerMgr = require("PlayerMgrData");
local Player = require("PlayerLogic")
local Log = require("Log")

PlayerMgr["players"] = PlayerMgr["players"] or {}
PlayerMgr["userIdToPlayerId"] = PlayerMgr["userIdToPlayerId"] or {}
PlayerMgr["playerIdToUserId"] = PlayerMgr["playerIdToUserId"] or {}

function PlayerMgr.CreatePlayer(playerId)
    if PlayerMgr.players[playerId] then
        Log:Error("Already exists Player playerId %s", playerId)
        return PlayerMgr.players[playerId]
    end

    Log:Error("Create new Player playerId[%s]", playerId)
    local player = Player.new(playerId)
    PlayerMgr.players[playerId] = player
    return player
end

function PlayerMgr.GetPlayerByPlayerId(playerId)
    return PlayerMgr.players[playerId]
end

function PlayerMgr.RemovePlayerByPlayerId(playerId)
    PlayerMgr.players[playerId] = nil
    local userId = PlayerMgr.playerIdToUserId[playerId]
    if userId ~= nil then
        PlayerMgr.userIdToPlayerId[userId] = nil
        PlayerMgr.playerIdToUserId[playerId] = nil
    end

    Log:Error("RemovePlayerByPlayerId from PlayerMgr playerId %s userId %s", playerId, userId or "nil");
end

function PlayerMgr.BindUserIdAndPlayerId(userId, playerId)
    if nil == PlayerMgr.GetPlayerByPlayerId(playerId) then
        Log:Error("BindUserIdAndPlayerId failed, playerId %s not exists", playerId);
        return
    end

    PlayerMgr.userIdToPlayerId[userId] = playerId
    PlayerMgr.playerIdToUserId[playerId] = userId
end

function PlayerMgr.GetPlayerByUserId(userId)
    local playerId = PlayerMgr.userIdToPlayerId[userId]
    if playerId == nil then
        return nil
    end
    return PlayerMgr.GetPlayerByPlayerId(playerId)
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
        PlayerMgr.RemovePlayerByPlayerId(playerId);
    end
end

return PlayerMgr
