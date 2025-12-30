-- MapLogic.lua logic script, reloadable

---@class QuadTreeType
---@field x number 节点左上角坐标x
---@field y number 节点左上角坐标y
---@field w number 节点宽度
---@field h number 阶段高度
---@field depth number 节点深度，根节点depth=0
---@field children table<integer,QuadTreeType> 子节点数组，初始为空 未分裂
---@field list table<integer,table> 存放直接属于此节点的对象

---@class MapPlayerType 地图内的玩家
---@field playerId string 连接sessionID
---@field userId string 用户ID
---@field x number 当前所在像素坐标x 左上角为原点 向右为x正轴向下为y正轴
---@field y number 当前所在像素坐标y 左上角为原点 向右为x正轴向下为y正轴
---@field vX number x轴速度
---@field vY number y轴速度
---@field dirX number 客户端输入方向x 归一化后的
---@field dirY number 客户端输入方向y 归一化后的
---@field maxSpeed number 目标最大速度 px/ms
---@field speedRatio number 速度放大比例
---@field accel number 加速度 px/ms^2
---@field bodyRadius number 角色碰撞半径
---@field bodyMass number 角色的碰撞半径
---@field friction number 每帧速度衰减系数
---@field bounce number 角色撞到障碍物时的反弹系数
---@field lastSeq number 最后收到并应用的客户端输入seq
---@field lastClientTime number 客户端发送该seq时的客户端时间(ms)
---@field quadTree QuadTreeType|nil 所在地图四叉树节点

---@class TileMapType
---@field tileSize integer 瓦片像素大小
---@field width integer 地图内宽有多少个瓦片
---@field height integer 地图内高有多少个瓦片
---@field data table<integer,integer> 瓦片像素数据

---@class MapDbDataType
---@field id integer 地图ID
---@field TICK_RATE integer 帧率
---@field DT_MS integer 每帧时间间隔 毫秒
---@field lastTickTimeMS integer 执行上一次tick的毫秒时间戳
---@field durationAccumulator number 帧时常累计时间毫秒

---@class MapType
---@field players table<string, MapPlayerType> 地图内的所有玩家
---@field tileMap TileMapType
---@field MapDbData MapDbDataType
---@field quadTree QuadTreeType 四叉树

---@class Map:MapType
local Map      = require("MapData")
local Log      = require("Log")

local TimeMgr  = require("TimeMgrLogic")

---@class QuadTree:QuadTreeType
local QuadTree = {
    MAX_DEPTH = 6,  -- 最大分裂深度，超过该深度不再继续分裂，防止无限分类
    MAX_OBJECTS = 0 -- 当节点对象数量超过该阈值时尝试分裂
};

---@param x number 节点左上角坐标x
---@param y number 节点左上角坐标y
---@param w number 节点宽度
---@param h number 节点高度
---@param depth number 节点深度
---@return QuadTree
function QuadTree.new(x, y, w, h, depth)
    ---@type QuadTree
    local newQuadTree = setmetatable({}, { __index = QuadTree });
    newQuadTree.x = x;
    newQuadTree.y = y;
    newQuadTree.w = w;
    newQuadTree.h = h;
    newQuadTree.depth = depth;
    newQuadTree.children = nil;
    newQuadTree.list = {};
    return newQuadTree;
end

--- 判断对象obj是否完全包含在候选节点qtNode的矩形范围内
---@param qtNode QuadTree
---@param obj table -- {x, y}
---@return boolean
function QuadTree.ContainsNode(qtNode, obj)
    return (
        obj.x >= qtNode.x and           -- 对象左边界在子节点左边界右侧或相等
        obj.y >= qtNode.y and           -- 对象上边界在子节点上边界下方或相等
        obj.x < qtNode.x + qtNode.w and -- 对象左边界小于子节点右边界（严格小于以避免边界冲突）
        obj.y < qtNode.y + qtNode.h     -- 对象上边界小于子节点底边界
    );
end

--- 判断两个矩形A与B是否相交
---@param rectA table 矩形A
---@param rectB table 矩形B
---@return boolean 返回true表示相交或相融false表示完全分离
function QuadTree.Intersect(rectA, rectB)
    return not (
        rectB.x > rectA.x + rectA.w or -- b 的左边在 a 的右边之外（不相交）
        rectB.x + rectB.w < rectA.x or -- b 的右边在 a 的左边之外（不相交）
        rectB.y > rectA.y + rectA.h or -- b 的上边在 a 的下边之外（不相交）
        rectB.y + rectB.h < rectA.y    -- b 的下边在 a 的上边之外（不相交）
    )
end

--- 将对象obj插入到四叉树qtNode中
---@param qtNode QuadTree
---@param obj table
function QuadTree.QtInert(qtNode, obj)
    if qtNode.children ~= nil then -- 如果已经有子节点（已分裂）
        -- 遍历四个子节点
        for i, v in ipairs(qtNode.children) do
            -- 如果某个子节点完全包含该对象
            if true == QuadTree.ContainsNode(v, obj) then
                QuadTree.QtInert(v, obj); --递归插入到该子节点（继续下沉）
                return;                   -- 插入后结束（对象只放入完全包含它的子节点）
            end
        end

        -- 如果没有任何子节点能包含该对象，就把对象放在当前节点的list中
        table.insert(qtNode.list, obj)
        obj.quadTree = qtNode;
        return
    end

    -- 如果没有子节点（未分裂），把对象加入当前节点的list
    table.insert(qtNode.list, obj);
    obj.quadTree = qtNode;

    -- 如果当前节点的对象数量超过阈值并且深度未达到限制，则分裂节点
    if #qtNode.list > QuadTree.MAX_OBJECTS and qtNode.depth < QuadTree.MAX_DEPTH then
        QuadTree.Subdivide(qtNode);
    end
end

--- 将节点qtNode分裂为四个子节点 象限划分
---@param qtNode QuadTree
function QuadTree.Subdivide(qtNode)
    if qtNode.w <= 4 or qtNode.h <= 4 then
        return
    end
    if qtNode.children ~= nil then
        return
    end
    -- 子节点宽=当前宽的一半
    local hw = qtNode.w // 2;
    -- 子节点高=当前高的一半
    local hh = qtNode.h // 2;

    -- 创建四个子节点（左上，右上，左下，右下）
    qtNode.children = {
        QuadTree.new(qtNode.x, qtNode.y, hw, hh, qtNode.depth + 1),           --左上象限
        QuadTree.new(qtNode.x + hw, qtNode.y, hw, hh, qtNode.depth + 1),      --右上象限
        QuadTree.new(qtNode.x, qtNode.y + hh, hw, hh, qtNode.depth + 1),      --左下象限
        QuadTree.new(qtNode.x + hw, qtNode.y + hh, hw, hh, qtNode.depth + 1), --右下象限
    };

    -- old=当前节点已有对象的副本
    local old = {}
    for i = 1, #qtNode.list do
        old[i] = qtNode.list[i];
        qtNode.list[i].quadTree = nil; -- 将对象上的绑定的所在节点移除
    end
    -- 清空当前节点对象列表
    qtNode.list = {}

    -- 遍历旧对象并重新分配
    for _, obj in ipairs(old) do
        local inserted = false; -- 是否被插入到了子节点中

        -- 尝试插入到四个子节点
        for _, child in ipairs(qtNode.children) do
            if QuadTree.ContainsNode(child, obj) then
                -- 递归插入
                QuadTree.QtInert(child, obj)
                inserted = true
                break;
            end
        end

        -- 如果没有子节点完全包住，则放回当前节点
        if not inserted then
            qtNode.list[#qtNode.list + 1] = obj;
            obj.quadTree = qtNode;
        end
    end
end

--- 在四叉树qtNode中查询与范围range相交的对象，结果加入out数组，seen是一个set（用table实现）
---@param qtNode QuadTree
---@param range table
---@param out table
---@param seen table
function QuadTree.QtQuery(qtNode, range, out, seen)
    -- 如果当前节点不与查询范围相交，直接返回
    if not QuadTree.Intersect(qtNode, range) then
        return
    end

    -- 遍历当前节点直接存储的对象
    for _, obj in ipairs(qtNode.list) do
        if obj.x >= range.x and
            obj.x < range.x + range.w and
            obj.y >= range.y and
            obj.y < range.y + range.h then
            -- 去重
            if not seen[obj.userId] then
                seen[obj.userId] = true
                table.insert(out, obj)
            end
        end
    end

    -- 递归查询子节点
    if qtNode.children ~= nil then
        for _, child in ipairs(qtNode.children) do
            QuadTree.QtQuery(child, range, out, seen);
        end
    end
end

-- 构造新的Map对象
---@param mapId integer 地图ID
---@return Map 新的地图对象
function Map.new(mapId)
    ---@type Map
    local self = setmetatable({}, Map); -- 本质是 setmetatable({}, {__index = Map})

    -- 模拟Map的DB字段
    self.MapDbData = {
        id = mapId,
        name = "Map_" .. tostring(mapId),
        TICK_RATE = 20,
        DT_MS = 1000 // 20,
        lastTickTimeMS = 0,
        durationAccumulator = 0
    };

    -- 地图相关信息
    ---@type TileMapType
    self.tileMap = {
        tileSize = 50,
        width = 4000,  -- 地图宽瓦片个数
        height = 4000, -- 地图高瓦片个数
        data = {}      -- 4000*4000=1600 0000
    };
    -- 初始化tileMap.data
    -- for i = 0, self.tileMap.width * self.tileMap.height do
    --     self.tileMap.data[i] = 0 -- 设为默认值
    -- end

    -- 地图内的Player
    ---@type table<string,MapPlayerType>
    self.players = {};

    -- 四叉树
    self.quadTree = QuadTree.new(0, 0, self.tileMap.width * self.tileMap.tileSize,
        self.tileMap.height * self.tileMap.tileSize, 0);

    return self
end

---@return MapDbDataType
function Map:GetMapDbData()
    return self.MapDbData;
end

---@return integer
function Map:GetLastTickTimeMS()
    return self:GetMapDbData().lastTickTimeMS;
end

---@return integer
function Map:GetMapId()
    return self:GetMapDbData().id;
end

---@return integer
function Map:GetTileSize()
    return self.tileMap.tileSize;
end

---@return integer
function Map:GetTileMapWidth()
    return self.tileMap.width;
end

---@return integer
function Map:GetTileMapHeight()
    return self.tileMap.height;
end

---@param userId string
---@return MapPlayerType
function Map:GetMapPlayerByUserId(userId)
    return self.players[userId]
end

function Map:OnTick()
    local timeMS = TimeMgr.GetMS()

    local frameTime = timeMS - self.MapDbData.lastTickTimeMS
    if frameTime > 250 then
        frameTime = 250 -- 防止卡顿时爆炸
    end
    self.MapDbData.lastTickTimeMS = timeMS
    self.MapDbData.durationAccumulator = self.MapDbData.durationAccumulator + frameTime

    while self.MapDbData.durationAccumulator >= self.MapDbData.DT_MS do
        -- 一次固定步长的逻辑更新
        self:FixedUpdate(timeMS)
        self.MapDbData.durationAccumulator = self.MapDbData.durationAccumulator - self.MapDbData.DT_MS
    end
end

-- 所有玩家出生点相同（地图中心）
function Map:FindSpawnPoint()
    local mapW = self.tileMap.width * self.tileMap.tileSize
    local mapH = self.tileMap.height * self.tileMap.tileSize
    return { x = mapW // 2, y = mapH // 2 }
end

-- 新玩家加入地图
---@param playerId string
---@param userId string
---@return boolean
function Map:PlayerJoinMap(playerId, userId)
    if self.players[userId] ~= nil then
        return false;
    end

    Log:Error("NewPlayerJoinMap id %d playerId %s userId %s", self.MapDbData.id, playerId, userId)

    local spawnPoint = self:FindSpawnPoint();

    ---@type MapPlayerType
    local newMapPlayer = {
        playerId = playerId,
        userId = userId,
        x = spawnPoint.x,
        y = spawnPoint.y,
        vX = 0,
        vY = 0,
        dirX = 0,
        dirY = 0,
        maxSpeed = 0.1,    -- 最大速度 目标最大速度 px/ms 100px/s
        accel = 1,         -- 加速度 px/ms^2
        speedRatio = 1000, -- 放大倍数

        bodyRadius = 12,
        bodyMass = 1,
        friction = 1.0, -- 无摩擦
        bounce = 0.40,

        lastSeq = 0,
        lastClientTime = 0,
        quadTree = nil
    };

    self.players[userId] = newMapPlayer;

    -- 加入地图四叉树
    QuadTree.QtInert(self.quadTree, newMapPlayer);

    return true
end

-- 玩家离开地图
---@param userId string
---@return boolean
function Map:PlayerExitMap(userId)
    Log:Error("PlayerExitMap id %d userId %s", self.MapDbData.id, userId)

    ---@type MapPlayerType
    local targetPlayer = self.players[userId]

    if targetPlayer ~= nil then
        -- 将玩家从地图四叉树中移除
        if targetPlayer.quadTree ~= nil then
            -- 从list移除userId为自己的obj 倒序遍历
            for i = #targetPlayer.quadTree.list, 1, -1 do
                if targetPlayer.quadTree.list[i].userId == targetPlayer.userId then
                    table.remove(targetPlayer.quadTree.list, i);
                end
            end
            targetPlayer.quadTree = nil;
        end

        self.players[userId] = nil
        return true
    end

    return false
end

---@param mapPlayer MapPlayerType
function Map:PlayerPhysicsMove(mapPlayer)
    --- 内联 math.sign：返回v的符号(1,-1,0)
    ---@return number
    local function sign(v)
        if v > 0 then
            return 1
        elseif v < 0 then
            return -1
        else
            return 0
        end
    end

    -- 计算目标速度（由方向输入 dirX、dirY 和 最大速度maxSpeed决定）
    -- 目标的X速度
    local targetVx = (mapPlayer.dirX * mapPlayer.speedRatio) * mapPlayer.maxSpeed
    -- 目标的Y速度
    local targetVy = (mapPlayer.dirY * mapPlayer.speedRatio) * mapPlayer.maxSpeed
    targetVx = math.floor(targetVx);
    targetVy = math.floor(targetVy);

    -- 当前速度到目标速度的差值
    local deltaVx = targetVx - mapPlayer.vX -- 当前vX需要朝哪个方向变化
    local deltaVy = targetVy - mapPlayer.vY -- 当前vY需要朝哪个方向变化

    -- 每帧最大可改变的速度（加速度限制）
    -- accel * DT = 每帧最多加多少速度
    local maxDeltaV = mapPlayer.accel * self:GetMapDbData().DT_MS;
    maxDeltaV = math.floor(maxDeltaV);

    local maxDeltaVX = math.abs(math.floor(maxDeltaV * mapPlayer.dirX));
    local maxDeltaVY = math.abs(math.floor(maxDeltaV * mapPlayer.dirY));

    -- X轴速度更新（带加速度限制）
    if maxDeltaVX ~= 0 and math.abs(deltaVx) > maxDeltaVX then
        -- 需要加速：按符号方向增加 maxDeltaV
        mapPlayer.vX = mapPlayer.vX + sign(deltaVx) * maxDeltaVX;
    else
        -- 可以直接到达目标速度
        mapPlayer.vX = targetVx;
    end

    -- Y轴速度更新（加速度限制）
    if maxDeltaVY ~= 0 and math.abs(deltaVy) > maxDeltaVY then
        mapPlayer.vY = mapPlayer.vY + sign(deltaVy) * maxDeltaVY;
    else
        mapPlayer.vY = targetVy;
    end

    -- 根据速度移动位置
    -- mapPlayer.x / mapPlayer.y 是坐标，速度 * DT_MS 是位移
    mapPlayer.x = mapPlayer.x + math.floor((mapPlayer.vX * self:GetMapDbData().DT_MS) / mapPlayer.speedRatio);
    mapPlayer.y = mapPlayer.y + math.floor((mapPlayer.vY * self:GetMapDbData().DT_MS) / mapPlayer.speedRatio);

    -- 摩擦力（阻尼）
    -- 每帧速度 *= friction，使速度逐渐衰减
    mapPlayer.vX = math.floor(mapPlayer.vX * mapPlayer.friction);
    mapPlayer.vY = math.floor(mapPlayer.vY * mapPlayer.friction);

    -- 地图边界控制：限制物体不允许跑出地图
    local mapPxWidth = self.tileMap.width * self.tileMap.tileSize                                 -- 地图像素宽度
    local mapPxHeight = self.tileMap.height * self.tileMap.tileSize                               -- 地图像素高度
    local playerRadius = mapPlayer.bodyRadius                                                     -- 玩家半径（防止部分穿出）

    if mapPlayer.x < playerRadius then mapPlayer.x = playerRadius end                             -- 左边界
    if mapPlayer.y < playerRadius then mapPlayer.y = playerRadius end                             -- 上边界
    if mapPlayer.x > mapPxWidth - playerRadius then mapPlayer.x = mapPxWidth - playerRadius end   -- 右边界
    if mapPlayer.y > mapPxHeight - playerRadius then mapPlayer.y = mapPxHeight - playerRadius end -- 下边界

    -- 从四叉树中先移除这个玩家 然后再插入 做到QuadTree更新
    if mapPlayer.quadTree ~= nil then
        -- 从list移除userId为自己的obj 倒序遍历
        for i = #mapPlayer.quadTree.list, 1, -1 do
            if mapPlayer.quadTree.list[i].userId == mapPlayer.userId then
                table.remove(mapPlayer.quadTree.list, i);
            end
        end
        mapPlayer.quadTree = nil;
    end

    QuadTree.QtInert(self.quadTree, mapPlayer);
end

---@param timeMS integer
function Map:FixedUpdate(timeMS)
    local MsgHandler = require("MsgHandlerLogic")
    local PlayerMgr = require("PlayerMgrLogic")

    -- Log:Error("MapId %d FixedUpdate FinSpawnPoint x %d y %d", self.MapDbData.id, self:FindSpawnPoint().x,
    --     self:FindSpawnPoint().y)

    for userId, mapPlayer in pairs(self.players) do
        self:PlayerPhysicsMove(mapPlayer);
    end

    -- 为地图中每个玩家同步状态
    for userId, mapPlayer in pairs(self.players) do
        local range = { x = mapPlayer.x - 600, y = mapPlayer.y - 600, w = 1200, h = 1200 };
        local list = {}
        local seen = {}

        QuadTree.QtQuery(self.quadTree, range, list, seen)

        ---@type table<integer,ProtoLua_ProtoMapPlayerPayload>
        local playersPayload = {}
        for _, o in ipairs(list) do
            ---@type MapPlayerType
            local pl = self.players[o.userId];

            -- Log:Error("pl x %s y %s vX %s vY %s", tostring(math.tointeger(pl.x)), tostring(math.tointeger(pl.y)),
            --     tostring(math.tointeger(pl.vX)), tostring(math.tointeger(pl.vY)));

            playersPayload[#playersPayload + 1] = {
                userId = o.userId,
                x = math.tointeger(pl.x) or 0,
                y = math.tointeger(pl.y) or 0,
                vX = math.tointeger(pl.vX) or 0,
                vY = math.tointeger(pl.vY) or 0,
                lastSeq = math.tointeger(pl.lastSeq) or 0,
                lastClientTime = math.tointeger(pl.lastClientTime) or 0
            };
        end

        if #playersPayload == 0 then
            Log:Error('players playersPayload len %d', #playersPayload)
        end

        ---@type ProtoLua_ProtoCSMapNotifyStateData
        local protoCSMapNotifyStateData = {
            serverTime = timeMS,
            players = playersPayload
        };

        local loopPlayer = PlayerMgr.GetPlayerByUserId(userId)
        if loopPlayer ~= nil then
            MsgHandler:Send2Client(loopPlayer:GetClientGID(), loopPlayer:GetWorkerIdx(),
                ProtoLua_ProtoCmd.PROTO_CMD_CS_MAP_NOTIFY_STATE_DATA, protoCSMapNotifyStateData);
        end
    end
end

---@param userId string
---@param dirX number
---@param dirY number
---@param seq number
---@param clientTime number
function Map:MapPlayerInput(userId, dirX, dirY, seq, clientTime)
    local mapPlayer = self:GetMapPlayerByUserId(userId);
    if mapPlayer == nil then
        return
    end

    if mapPlayer.lastSeq + 1 ~= seq then
        return
    end

    -- 计算向量长度
    local len = math.sqrt(dirX * dirX + dirY * dirY);

    if len > 0.0001 then
        -- 服务器强制归一化
        dirX = dirX / len;
        dirY = dirY / len;
    else
        dirX = 0;
        dirY = 0;
    end

    mapPlayer.dirX = dirX;
    mapPlayer.dirY = dirY;
    mapPlayer.lastSeq = seq;
    mapPlayer.lastClientTime = clientTime;
end

return Map;
