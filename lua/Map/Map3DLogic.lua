---@class Map3D:Map3DType
local Map3D = require("Map3DData");
local Log = require("Log");
local TimeMgr = require("TimeMgrLogic");

---@class Octree:OctreeType
local Octree = {
    MAX_DEPTH = 6,   -- 最大分裂深度
    MAX_OBJECTS = 0, -- 节点最多对象数
};

--- 创建一个新的八叉树节点
---@param x number 左上前角x
---@param y number 左上前角y
---@param z number 左上前角z
---@param w number 宽度x方向
---@param h number 高度y方向
---@param d number 深度z方向
---@param depth number 当前深度
---@return Octree
function Octree.new(x, y, z, w, h, d, depth)
    ---@type Octree
    local newOctree = setmetatable({}, { __index = Octree });
    newOctree.x = x;
    newOctree.y = y;
    newOctree.z = z;
    newOctree.w = w;
    newOctree.h = h;
    newOctree.d = d;
    newOctree.depth = depth or 0;
    newOctree.children = nil;
    newOctree.list = {};
    return newOctree;
end

--- 判断obj是否完全被node包含（点对象）
---@param node Octree
---@param obj table -- {pos.x,pos.y,pos.z,octree}
---@return boolean
function Octree.ContainsNode(node, obj)
    return (
        obj.pos.x >= node.x and obj.pos.x < node.x + node.w and
        obj.pos.y >= node.y and obj.pos.y < node.y + node.h and
        obj.pos.z >= node.z and obj.pos.z < node.z + node.d
    );
end

--- 判断两个AABB盒是否相交
---@param a table -- {x, y, z, w, h, d}
---@param b table -- {x, y, z, w, h, d}
---@return boolean
function Octree.Intersect(a, b)
    return not (
        b.x > a.x + a.w or a.x > b.x + b.w or
        b.y > a.y + a.h or a.y > b.y + b.h or
        b.z > a.z + a.d or a.z > b.z + b.d
    );
end

--- 向八叉树节点中插入对象
---@param node Octree
---@param obj table -- {pos.x,pos.y,pos.z,octree}
function Octree.OcInsert(node, obj)
    -- 如果已经有子节点（已分裂）
    if node.children ~= nil then
        -- 遍历8个子节点
        for _, child in ipairs(node.children) do
            -- 如果某个子节点完全包含该对象
            if true == Octree.ContainsNode(child, obj) then
                Octree.OcInsert(child, obj); -- 递归插入到该子节点（继续下沉）
                return;                      -- 插入后结束（对象只放入完全包含它的子节点）
            end
        end

        -- 如果没有任何子节点能包含该对象，就把对象放在当前节点的list中
        table.insert(node.list, obj);
        obj.octree = node;
        return;
    end

    -- 如果没有子节点（未分裂），把对象加入当前节点的list
    table.insert(node.list, obj);
    obj.octree = node;

    -- 如果当前节点的对象数量超过阈值并且深度未达到限制，则分裂节点
    if #node.list > Octree.MAX_OBJECTS and node.depth < Octree.MAX_DEPTH then
        Octree.Subdivide(node);
    end
end

--- 分裂成8个子节点
---@param node Octree
function Octree.Subdivide(node)
    -- 分裂过了
    if node.children ~= nil then
        return;
    end
    -- 每个节点大小不能小于2
    if node.w <= 2 or node.h <= 2 or node.d <= 2 then
        return;
    end

    local hw = math.modf(node.w / 2);
    local hh = math.modf(node.h / 2);
    local hd = math.modf(node.d / 2);

    local x, y, z = node.x, node.y, node.z;
    local nd = node.depth + 1;

    -- 分裂成8个孩子
    node.children = {
        Octree.new(x, y, z, hw, hh, hd, nd),                -- 左上前
        Octree.new(x + hw, y, z, hw, hh, hd, nd),           -- 右上前
        Octree.new(x, y + hh, z, hw, hh, hd, nd),           -- 左下前
        Octree.new(x + hw, y + hh, z, hw, hh, hd, nd),      -- 右下前

        Octree.new(x, y, z + hd, hw, hh, hd, nd),           -- 左上后
        Octree.new(x + hw, y, z + hd, hw, hh, hd, nd),      -- 右上后
        Octree.new(x, y + hh, z + hd, hw, hh, hd, nd),      -- 左下后
        Octree.new(x + hw, y + hh, z + hd, hw, hh, hd, nd), -- 右下后
    };

    -- old=当前节点已有对象的副本
    local old = {};
    for i = 1, #node.list do
        old[i] = node.list[i];
        node.list[i].octree = nil; -- 将对象上的绑定的所在节点移除
    end
    -- 清空当前节点对象列表
    node.list = {};

    -- 遍历旧对象并重新分配到8个子节点中
    for _, obj in ipairs(old) do
        local inserted = false; -- 是否被插入到了子节点中

        -- 尝试插入到8个子节点
        for _, child in ipairs(node.children) do
            if Octree.ContainsNode(child, obj) then
                -- 递归插入
                Octree.OcInsert(child, obj);
                inserted = true;
                break;
            end
        end

        -- 如果没有子节点完全包住，则放回当前节点
        if not inserted then
            node.list[#node.list + 1] = obj;
            obj.octree = node;
        end
    end
end

--- 查询与范围相交的对象
---@param node Octree
---@param range table -- {x, y, z, w, h, d}
---@param out table
---@param seen table
function Octree.OcQuery(node, range, out, seen)
    -- 如果当前节点不与查询范围相交，直接返回
    if not Octree.Intersect(node, range) then
        return;
    end

    -- 遍历当前节点直接存储的对象
    for _, obj in ipairs(node.list) do
        if obj.pos.x >= range.x and obj.pos.x < range.x + range.w and
            obj.pos.y >= range.y and obj.pos.y < range.y + range.h and
            obj.pos.z >= range.z and obj.pos.z < range.z + range.d then
            -- 去重
            if not seen[obj.userId] then
                seen[obj.userId] = true;
                table.insert(out, obj);
            end
        end
    end

    -- 递归查询子节点
    if node.children ~= nil then
        for _, child in ipairs(node.children) do
            Octree.OcQuery(child, range, out, seen);
        end
    end
end

-- 构造新的3DMap对象
---@param mapId integer 地图ID
---@return Map3D 新的地图对象
function Map3D.new(mapId)
    ---@type Map3D
    local self = setmetatable({}, Map3D);

    self.MapDbData = {
        id = mapId,
        TICK_RATE = 20,
        DT_MS = 50,
        lastTickTimeMS = 0,
        durationAccumulator = 0,
        size = { x = 1000000, y = 1000000, z = 1000000 }
    };

    -- 地图内的player
    ---@type table<string,Map3DPlayerType>
    self.players = {};

    -- 八叉树
    self.octree = Octree.new(0, 0, 0, self:GetSize().x, self:GetSize().y, self:GetSize().z, 0);

    return self;
end

---@return Map3DDbDataType
function Map3D:GetMapDbData()
    return self.MapDbData;
end

---@return integer
function Map3D:GetLastTickTimeMS()
    return self:GetMapDbData().lastTickTimeMS;
end

---@return Vec3i
function Map3D:GetSize()
    return self:GetMapDbData().size;
end

---@return integer 地图ID
function Map3D:GetMapId()
    return self.MapDbData.id;
end

---@param userId string
---@return Map3DPlayerType|nil
function Map3D:GetMapPlayerByUserId(userId)
    return self.players[userId];
end

function Map3D:OnTick()
    local timeMS = TimeMgr.GetMS();
    -- Log:Error("MS %s", tostring(TimeMgr.GetMS()));
    -- Log:Error("S %s", tostring(TimeMgr.GetS()));
    -- Log:Error("NS %s", tostring(TimeMgr.GetNS()));

    local frameTime = timeMS - self.MapDbData.lastTickTimeMS;
    if frameTime > 250 then
        frameTime = 250 -- 防止卡顿时爆炸
    end

    self.MapDbData.lastTickTimeMS = timeMS;
    self.MapDbData.durationAccumulator = self.MapDbData.durationAccumulator + frameTime;

    while self.MapDbData.durationAccumulator >= self.MapDbData.DT_MS do
        -- 一次固定步长的逻辑更新
        self:FixedUpdate(timeMS);
        self.MapDbData.durationAccumulator = self.MapDbData.durationAccumulator - self.MapDbData.DT_MS;
    end
end

---计算出生点
---@return Vec3f
function Map3D:FindSpawnPoint()
    local x = math.modf(self.MapDbData.size.x / 2);
    local y = math.modf(self.MapDbData.size.y / 2);
    local z = math.modf(self.MapDbData.size.z / 2);
    return { x = x, y = y, z = z };
end

-- 新玩家加入地图
---@param playerId string
---@param userId string
---@return boolean
function Map3D:PlayerJoinMap(playerId, userId)
    if self.players[userId] ~= nil then
        return false;
    end

    Log:Error("Map3D PlayerJoinMap id %s playerId %s userId %s",
        tostring(self.MapDbData.id),
        tostring(playerId),
        tostring(userId));

    local spawnPoint = self:FindSpawnPoint();

    ---@type Map3DPlayerType
    local newMap3DPlayer = {
        userId = userId,
        pos = spawnPoint,
        v = { x = 0, y = 0, z = 0 },
        gravity = 1,
        weight = 1,
        lastSeq = 0,
        lastClientTime = 0,
        dir = { x = 0, y = 0, z = 0 },
        speedRatio = 1000,
        maxSpeed = 0.05, -- 最大速度 目标最大速度 px/ms 100px/s
        accel = 1,       -- 加速度 px/ms^2
        friction = 1.0,  -- 无摩擦
        bodyRadius = 12,
        octree = nil
    };

    self.players[userId] = newMap3DPlayer;

    -- 加入地图八叉树
    Octree.OcInsert(self.octree, newMap3DPlayer);

    return true;
end

-- 玩家离开地图
---@param userId string
---@return boolean
function Map3D:PlayerExitMap(userId)
    Log:Error("Map3D PlayerExitMap id %s userId %s",
        tostring(self.MapDbData.id),
        userId);

    ---@type Map3DPlayerType
    local targetPlayer = self.players[userId];
    if targetPlayer ~= nil then
        -- 将玩家从八叉树中移除
        if targetPlayer.octree ~= nil then
            -- 从list移除userId为自己的obj 倒序遍历
            for i = #targetPlayer.octree.list, 1, -1 do
                if targetPlayer.octree.list[i].userId == targetPlayer.userId then
                    table.remove(targetPlayer.octree.list, i);
                end
            end
            targetPlayer.octree = nil;
        end

        self.players[userId] = nil;
        return true;
    end

    return false;
end

---@param userId string
---@param dirX number
---@param dirY number
---@param dirZ number
---@param seq integer
---@param clientTime number
function Map3D:MapPlayerInput(userId,
                              dirX,
                              dirY,
                              dirZ,
                              seq,
                              clientTime)
    local map3DPlayer = self.players[userId];

    if map3DPlayer == nil then
        return;
    end

    if map3DPlayer.lastSeq >= avant.UINT32_MAX then
        map3DPlayer.lastSeq = 0;
    end

    if map3DPlayer.lastSeq + 1 ~= seq then
        Log:Error("userId %s map3DPlayer.lastSeq %s + 1 ~= seq %s in mapId %s",
            tostring(userId),
            tostring(map3DPlayer.lastSeq),
            tostring(seq),
            tostring(self:GetMapId())
        );
        return
    end

    -- 计算向量长度
    local len = math.sqrt(
        dirX * dirX +
        dirY * dirY +
        dirZ * dirZ);

    if len > 0.0001 then
        -- 服务器强制归一化
        dirX = dirX / len
        dirY = dirY / len
        dirZ = dirZ / len
    else
        dirX = 0
        dirY = 0
        dirZ = 0
    end

    map3DPlayer.dir.x = dirX;
    map3DPlayer.dir.y = dirY;
    map3DPlayer.dir.z = dirZ;
    map3DPlayer.lastSeq = seq;
    map3DPlayer.lastClientTime = clientTime;
end

---@param mapPlayer Map3DPlayerType
function Map3D:PlayerPhysicsMove(mapPlayer)
    --- 返回v的符号(1,-1,0)
    ---@return number
    local function sign(v)
        if v > 0 then
            return 1;
        elseif v < 0 then
            return -1;
        else
            return 0;
        end
    end

    -- 计算目标速度（由方向输入 dirX、dirY、dirZ 和 最大速度 maxSpeed 决定）
    -- 目标的X、Y、Z速度
    local targetVx = (mapPlayer.dir.x * mapPlayer.speedRatio) * mapPlayer.maxSpeed;
    local targetVy = (mapPlayer.dir.y * mapPlayer.speedRatio) * mapPlayer.maxSpeed;
    local targetVz = (mapPlayer.dir.z * mapPlayer.speedRatio) * mapPlayer.maxSpeed;

    targetVx = math.floor(targetVx);
    targetVy = math.floor(targetVy);
    targetVz = math.floor(targetVz);

    -- 当前速度到目标速度的差值
    local deltaVx = targetVx - mapPlayer.v.x -- 当前vX需要朝哪个方向变化
    local deltaVy = targetVy - mapPlayer.v.y -- 当前vY需要朝哪个方向变化
    local deltaVz = targetVz - mapPlayer.v.z -- 当前vZ需要朝哪个方向变化

    -- 每帧最大可改变的速度（加速度限制）
    -- accel * DT = 每帧最多加多少速度
    local maxDeltaV = mapPlayer.accel * self:GetMapDbData().DT_MS
    maxDeltaV = math.floor(maxDeltaV);

    local maxDeltaVX = math.abs(math.floor(maxDeltaV * mapPlayer.dir.x));
    local maxDeltaVY = math.abs(math.floor(maxDeltaV * mapPlayer.dir.y));
    local maxDeltaVZ = math.abs(math.floor(maxDeltaV * mapPlayer.dir.z));

    -- X轴速度更新（带加速度限制）
    if maxDeltaVX ~= 0 and math.abs(deltaVx) > maxDeltaVX then
        -- 需要加速，按符号方向增加 maxDeltaV
        mapPlayer.v.x = mapPlayer.v.x + sign(deltaVx) * maxDeltaVX;
    else
        -- 可以直接到达目标速度
        mapPlayer.v.x = targetVx;
    end

    -- Y轴速度更新（加速度限制）
    if maxDeltaVY ~= 0 and math.abs(deltaVy) > maxDeltaVY then
        mapPlayer.v.y = mapPlayer.v.y + sign(deltaVy) * maxDeltaVY;
    else
        mapPlayer.v.y = targetVy;
    end

    -- Z轴速度更新（加速度限制）
    if maxDeltaVZ ~= 0 and math.abs(deltaVz) > maxDeltaVZ then
        mapPlayer.v.z = mapPlayer.v.z + sign(deltaVz) * maxDeltaVZ;
    else
        mapPlayer.v.z = targetVz;
    end

    -- 根据速度移动位置
    -- mapPlayer.pos.x / mapPlayer.pos.y / mapPlayer.pos.z 是坐标，速度 * DT_MS 是位移
    mapPlayer.pos.x = mapPlayer.pos.x + math.floor((mapPlayer.v.x * self:GetMapDbData().DT_MS) / mapPlayer.speedRatio);
    mapPlayer.pos.y = mapPlayer.pos.y + math.floor((mapPlayer.v.y * self:GetMapDbData().DT_MS) / mapPlayer.speedRatio);
    mapPlayer.pos.z = mapPlayer.pos.z + math.floor((mapPlayer.v.z * self:GetMapDbData().DT_MS) / mapPlayer.speedRatio);

    -- 摩擦力（阻尼）
    -- 每帧速度*=friction,使速度逐渐衰减
    mapPlayer.v.x = math.floor(mapPlayer.v.x * mapPlayer.friction)
    mapPlayer.v.y = math.floor(mapPlayer.v.y * mapPlayer.friction)
    mapPlayer.v.z = math.floor(mapPlayer.v.z * mapPlayer.friction)

    -- 地图边界控制，限制物体不允许跑出地图
    local mapSize = self:GetSize();
    local playerRadius = mapPlayer.bodyRadius;                                                        -- 玩家半径（防止部分穿出）

    if mapPlayer.pos.x < playerRadius then mapPlayer.pos.x = playerRadius end                         -- 左边界
    if mapPlayer.pos.y < playerRadius then mapPlayer.pos.y = playerRadius end                         -- 上边界
    if mapPlayer.pos.z < playerRadius then mapPlayer.pos.z = playerRadius end                         -- 前边界
    if mapPlayer.pos.x > mapSize.x - playerRadius then mapPlayer.pos.x = mapSize.x - playerRadius end -- 右边界
    if mapPlayer.pos.y > mapSize.y - playerRadius then mapPlayer.pos.y = mapSize.y - playerRadius end -- 下边界
    if mapPlayer.pos.z > mapSize.z - playerRadius then mapPlayer.pos.z = mapSize.z - playerRadius end -- 后边界

    -- 从八叉树中先移除这个玩家 然后再插入 做到Octree更新
    if mapPlayer.octree ~= nil then
        -- 从list移除userId为自己的obj倒序遍历
        for i = #mapPlayer.octree.list, 1, -1 do
            if mapPlayer.octree.list[i].userId == mapPlayer.userId then
                table.remove(mapPlayer.octree.list, i);
            end
        end
        mapPlayer.octree = nil;
    end

    Octree.OcInsert(self.octree, mapPlayer);
end

---@param timeMS integer
function Map3D:FixedUpdate(timeMS)
    local MsgHandler = require("MsgHandlerLogic")
    local PlayerMgr = require("PlayerMgrLogic")

    -- Log:Error("Map3D:FixedUpdate mapId %s", tostring(self.MapDbData.id));
    for userId, mapPlayer in pairs(self.players) do
        self:PlayerPhysicsMove(mapPlayer);
    end

    -- 为地图中每个玩家同步状态 PROTO_CMD_CS_MAP3D_NOTIFY_STATE_DATA
    for userId, mapPlayer in pairs(self.players) do
        local range = { x = mapPlayer.pos.x - 600, y = mapPlayer.pos.y - 600, z = mapPlayer.pos.z - 600, w = 1200, h = 1200, d = 1200 };
        local list = {};
        local seen = {};
        Octree.OcQuery(self.octree, range, list, seen);

        ---@type table<integer, ProtoLua_ProtoMap3DPlayerPayload>
        local playersPayload = {}
        for _, o in ipairs(list) do
            ---@type Map3DPlayerType
            local pl = self.players[o.userId];

            playersPayload[#playersPayload + 1] = {
                userId = pl.userId,
                x = math.modf(pl.pos.x) or 0,
                y = math.modf(pl.pos.y) or 0,
                z = math.modf(pl.pos.z) or 0,
                vX = math.modf(pl.v.x) or 0,
                vY = math.modf(pl.v.y) or 0,
                vZ = math.modf(pl.v.z) or 0,
                lastSeq = pl.lastSeq or 0,
                lastClientTime = tostring(math.modf(pl.lastClientTime) or 0)
            };
        end

        if #playersPayload == 0 then
            Log:Error('players playersPayload len %d', #playersPayload)
        end

        ---@type ProtoLua_ProtoCSMap3DNotifyStateData
        local protoCSMap3DNotifyStateData = {
            serverTime = tostring(timeMS),
            players = playersPayload
        };

        local loopPlayer = PlayerMgr.GetPlayerByUserId(userId)
        if loopPlayer ~= nil then
            MsgHandler:Send2Client(loopPlayer:GetClientGID(), loopPlayer:GetWorkerIdx(),
                ProtoLua_ProtoCmd.PROTO_CMD_CS_MAP3D_NOTIFY_STATE_DATA, protoCSMap3DNotifyStateData);
        end
    end
end

return Map3D;
