-- ============================================================================
-- TerrainTileMap.lua - 饥荒风格地形瓦片地图系统
-- 功能: 地形数据管理、自动过渡选择、NanoVG 瓦片渲染
-- ============================================================================

local TerrainTileMap = {}
TerrainTileMap.__index = TerrainTileMap

-- ============================================================================
-- 地形类型枚举
-- ============================================================================
TerrainTileMap.TERRAIN = {
    GRASS       = 1,  -- 草地
    MUD         = 2,  -- 泥地
    SWAMP       = 3,  -- 沼泽
    ROCKY       = 4,  -- 碎石
    VOLCANIC    = 5,  -- 火山岩
    SAND        = 6,  -- 沙地
    SNOW        = 7,  -- 雪地
    DEAD_GRASS  = 8,  -- 枯草地
    FOREST      = 9,  -- 森林地面
    COBBLESTONE = 10, -- 鹅卵石路
    -- 过渡贴图(左右)
    GRASS_SAND_LR       = 11,
    GRASS_DEADGRASS_LR  = 12,
    GRASS_ROCKY_LR      = 13,
    GRASS_SWAMP_LR      = 14,
    MUD_ROCKY_LR        = 15,
    MUD_SWAMP_LR        = 16,
    -- 过渡贴图(上下)
    GRASS_SNOW_TB       = 17,
    GRASS_ROCKY_TB      = 18,
    GRASS_MUD_TB        = 19,
    MUD_SWAMP_TB        = 20,
    ROCKY_VOLCANIC_TB   = 21,
    -- 角落贴图
    CORNER_GRASS_IN_MUD_BL      = 22,
    CORNER_GRASS_IN_MUD_BR      = 23,
    CORNER_GRASS_IN_MUD_TL      = 24,
    CORNER_GRASS_IN_MUD_TR      = 25,
    CORNER_GRASS_IN_SWAMP_TL    = 26,
    CORNER_GRASS_IN_SWAMP_TR    = 27,
    CORNER_ROCKY_IN_VOLCANIC_TL = 28,
    CORNER_ROCKY_IN_VOLCANIC_TR = 29,
    -- 混合/渐变贴图
    GRASS_TO_MUD        = 30,
    GRASS_TO_SWAMP      = 31,
    ROCKY_TO_VOLCANIC   = 32,
}

-- 地形名称映射（用于调试）
TerrainTileMap.TERRAIN_NAMES = {
    [1] = "草地", [2] = "泥地", [3] = "沼泽", [4] = "碎石", [5] = "火山岩",
    [6] = "沙地", [7] = "雪地", [8] = "枯草地", [9] = "森林", [10] = "鹅卵石",
    [11] = "草沙LR", [12] = "草枯LR", [13] = "草石LR", [14] = "草沼LR",
    [15] = "泥石LR", [16] = "泥沼LR",
    [17] = "草雪TB", [18] = "草石TB", [19] = "草泥TB", [20] = "泥沼TB",
    [21] = "石火TB",
    [22] = "草泥角BL", [23] = "草泥角BR", [24] = "草泥角TL", [25] = "草泥角TR",
    [26] = "草沼角TL", [27] = "草沼角TR", [28] = "石火角TL", [29] = "石火角TR",
    [30] = "草渐泥", [31] = "草渐沼", [32] = "石渐火",
}

-- ============================================================================
-- 贴图路径配置
-- ============================================================================

-- 基础地形贴图
local BASE_TEXTURES = {
    [1]  = "image/地皮/terrain_grass_20260530170030.png",
    [2]  = "image/地皮/terrain_mud_20260530165944.png",
    [3]  = "image/地皮/terrain_swamp_20260530165947.png",
    [4]  = "image/地皮/terrain_rocky_20260530165943.png",
    [5]  = "image/地皮/terrain_volcanic_20260530165940.png",
    [6]  = "image/地皮/terrain_sand_20260530170620.png",
    [7]  = "image/地皮/terrain_snow_20260530170624.png",
    [8]  = "image/地皮/terrain_dead_grass_20260530170619.png",
    [9]  = "image/地皮/terrain_forest_floor_20260530170620.png",
    [10] = "image/地皮/terrain_cobblestone_20260530170621.png",
    -- 过渡贴图（LR）
    [11] = "image/地皮/terrain_grass_sand_lr_20260530170624.png",
    [12] = "image/地皮/terrain_grass_deadgrass_lr_20260530170623.png",
    [13] = "image/地皮/terrain_grass_rocky_lr_20260530170407.png",
    [14] = "image/地皮/terrain_grass_swamp_lr_20260530170402.png",
    [15] = "image/地皮/terrain_mud_rocky_lr_20260530170405.png",
    [16] = "image/地皮/terrain_mud_swamp_lr_20260530170404.png",
    -- 过渡贴图（TB）
    [17] = "image/地皮/terrain_grass_snow_tb_20260530170622.png",
    [18] = "image/地皮/terrain_grass_rocky_tb_20260530170412.png",
    [19] = "image/地皮/terrain_grass_mud_tb_20260530170406.png",
    [20] = "image/地皮/terrain_mud_swamp_tb_20260530170405.png",
    [21] = "image/地皮/terrain_rocky_volcanic_tb_20260530170414.png",
    -- 角落贴图
    [22] = "image/地皮/terrain_corner_grass_in_mud_bl_20260530170523.png",
    [23] = "image/地皮/terrain_corner_grass_in_mud_br_20260530170508.png",
    [24] = "image/地皮/terrain_corner_grass_in_mud_tl_20260530170508.png",
    [25] = "image/地皮/terrain_corner_grass_in_mud_tr_20260530170512.png",
    [26] = "image/地皮/terrain_corner_grass_in_swamp_tl_20260530170508.png",
    [27] = "image/地皮/terrain_corner_grass_in_swamp_tr_20260530170508.png",
    [28] = "image/地皮/terrain_corner_rocky_in_volcanic_tl_20260530170512.png",
    [29] = "image/地皮/terrain_corner_rocky_in_volcanic_tr_20260530170512.png",
    -- 渐变/混合贴图
    [30] = "image/地皮/terrain_grass_to_mud_20260530165951.png",
    [31] = "image/地皮/terrain_grass_to_swamp_20260530165942.png",
    [32] = "image/地皮/terrain_rocky_to_volcanic_20260530165943.png",
}

-- 边缘过渡贴图: [fromTerrain][toTerrain][direction] = path
-- direction: "lr" = 左到右, "tb" = 上到下
local EDGE_TEXTURES = {}

-- 草地过渡
EDGE_TEXTURES[1] = {
    [2] = {
        lr = "image/地皮/terrain_grass_to_mud_20260530165951.png",
        tb = "image/地皮/terrain_grass_mud_tb_20260530170406.png",
    },
    [3] = {
        lr = "image/地皮/terrain_grass_swamp_lr_20260530170402.png",
        tb = "image/地皮/terrain_grass_to_swamp_20260530165942.png",
    },
    [4] = {
        lr = "image/地皮/terrain_grass_rocky_lr_20260530170407.png",
        tb = "image/地皮/terrain_grass_rocky_tb_20260530170412.png",
    },
    [6] = {
        lr = "image/地皮/terrain_grass_sand_lr_20260530170624.png",
    },
    [7] = {
        tb = "image/地皮/terrain_grass_snow_tb_20260530170622.png",
    },
    [8] = {
        lr = "image/地皮/terrain_grass_deadgrass_lr_20260530170623.png",
    },
}

-- 碎石过渡
EDGE_TEXTURES[4] = {
    [5] = {
        lr = "image/地皮/terrain_rocky_to_volcanic_20260530165943.png",
        tb = "image/地皮/terrain_rocky_volcanic_tb_20260530170414.png",
    },
}

-- 泥地过渡
EDGE_TEXTURES[2] = {
    [3] = {
        lr = "image/地皮/terrain_mud_swamp_lr_20260530170404.png",
        tb = "image/地皮/terrain_mud_swamp_tb_20260530170405.png",
    },
    [4] = {
        lr = "image/地皮/terrain_mud_rocky_lr_20260530170405.png",
    },
}

-- 角落过渡贴图: [fromTerrain][toTerrain][corner] = path
-- corner: "tl" "tr" "bl" "br" (表示 from 地形所在角落)
local CORNER_TEXTURES = {}

CORNER_TEXTURES[1] = {
    [2] = {
        tl = "image/地皮/terrain_corner_grass_in_mud_tl_20260530170508.png",
        tr = "image/地皮/terrain_corner_grass_in_mud_tr_20260530170512.png",
        bl = "image/地皮/terrain_corner_grass_in_mud_bl_20260530170523.png",
        br = "image/地皮/terrain_corner_grass_in_mud_br_20260530170508.png",
    },
    [3] = {
        tl = "image/地皮/terrain_corner_grass_in_swamp_tl_20260530170508.png",
        tr = "image/地皮/terrain_corner_grass_in_swamp_tr_20260530170508.png",
    },
}

CORNER_TEXTURES[4] = {
    [5] = {
        tl = "image/地皮/terrain_corner_rocky_in_volcanic_tl_20260530170512.png",
        tr = "image/地皮/terrain_corner_rocky_in_volcanic_tr_20260530170512.png",
    },
}

-- ============================================================================
-- 构造函数
-- ============================================================================

--- 创建新的地形瓦片地图
---@param vg userdata NanoVG 上下文
---@param config table 配置: { mapWidth, mapHeight, tileSize }
---@return table TerrainTileMap 实例
function TerrainTileMap.New(vg, config)
    local self = setmetatable({}, TerrainTileMap)

    self.vg = vg
    self.mapWidth = config.mapWidth or 20      -- 初始地图宽度（瓦片数）
    self.mapHeight = config.mapHeight or 15    -- 初始地图高度（瓦片数）
    self.tileSize = config.tileSize or 64      -- 每个瓦片渲染尺寸（像素）
    self.infinite = config.infinite or false    -- 是否无边界模式

    -- 相机偏移（用于滚动）
    self.cameraX = 0
    self.cameraY = 0

    -- 地图数据 [y][x] = terrainType
    self.data = {}
    for y = 1, self.mapHeight do
        self.data[y] = {}
        for x = 1, self.mapWidth do
            self.data[y][x] = TerrainTileMap.TERRAIN.GRASS  -- 默认草地
        end
    end

    -- NanoVG 图片缓存 { path = imageId }
    self.imageCache = {}

    -- 预加载基础贴图
    self:PreloadTextures()

    return self
end

--- 无边界模式下动态扩展地图到指定坐标
function TerrainTileMap:EnsureTile(x, y)
    if not self.infinite then return end
    if x < 1 or y < 1 then return end
    -- 扩展宽度
    if x > self.mapWidth then
        for row = 1, self.mapHeight do
            if not self.data[row] then self.data[row] = {} end
            for col = self.mapWidth + 1, x do
                self.data[row][col] = TerrainTileMap.TERRAIN.GRASS
            end
        end
        self.mapWidth = x
    end
    -- 扩展高度
    if y > self.mapHeight then
        for row = self.mapHeight + 1, y do
            self.data[row] = {}
            for col = 1, self.mapWidth do
                self.data[row][col] = TerrainTileMap.TERRAIN.GRASS
            end
        end
        self.mapHeight = y
    end
end

-- ============================================================================
-- 贴图管理
-- ============================================================================

--- 获取或加载贴图的 NanoVG imageId
function TerrainTileMap:GetImage(path)
    if not path then return nil end
    if self.imageCache[path] then
        return self.imageCache[path]
    end

    local imgId = nvgCreateImage(self.vg, path, 0)
    if imgId and imgId >= 0 then
        self.imageCache[path] = imgId
        return imgId
    end

    return nil
end

--- 预加载所有基础地形贴图
function TerrainTileMap:PreloadTextures()
    for _, path in pairs(BASE_TEXTURES) do
        self:GetImage(path)
    end
    print("[TerrainTileMap] 预加载完成, 缓存贴图数: " .. self:GetCachedCount())
end

--- 获取缓存贴图数量
function TerrainTileMap:GetCachedCount()
    local count = 0
    for _ in pairs(self.imageCache) do count = count + 1 end
    return count
end

-- ============================================================================
-- 地图数据操作
-- ============================================================================

--- 设置单个瓦片地形
function TerrainTileMap:SetTile(x, y, terrainType)
    if self.infinite then
        -- 无限模式: 允许任意坐标(包括负数和0)
        if not self.data[y] then self.data[y] = {} end
        self.data[y][x] = terrainType
        -- 更新边界追踪
        if x > self.mapWidth then self.mapWidth = x end
        if y > self.mapHeight then self.mapHeight = y end
    else
        if x < 1 or y < 1 or x > self.mapWidth or y > self.mapHeight then return end
        if not self.data[y] then self.data[y] = {} end
        self.data[y][x] = terrainType
    end
end

--- 获取单个瓦片地形
function TerrainTileMap:GetTile(x, y)
    if not self.infinite then
        if x < 1 or y < 1 or x > self.mapWidth or y > self.mapHeight then
            return nil
        end
    end
    if self.data[y] then
        return self.data[y][x]
    end
    return nil
end

--- 用矩形区域填充地形
function TerrainTileMap:FillRect(x1, y1, x2, y2, terrainType)
    if self.infinite then
        -- 无限模式: 不限制坐标范围
        for y = y1, y2 do
            if not self.data[y] then self.data[y] = {} end
            for x = x1, x2 do
                self.data[y][x] = terrainType
            end
        end
    else
        local maxY = math.min(self.mapHeight, y2)
        local maxX = math.min(self.mapWidth, x2)
        for y = math.max(1, y1), maxY do
            if not self.data[y] then self.data[y] = {} end
            for x = math.max(1, x1), maxX do
                self.data[y][x] = terrainType
            end
        end
    end
end

--- 用圆形区域填充地形
function TerrainTileMap:FillCircle(cx, cy, radius, terrainType)
    local r2 = radius * radius
    local startY = math.floor(cy - radius)
    local startX = math.floor(cx - radius)
    local maxY = math.ceil(cy + radius)
    local maxX = math.ceil(cx + radius)
    if not self.infinite then
        startY = math.max(1, startY)
        startX = math.max(1, startX)
        maxY = math.min(self.mapHeight, maxY)
        maxX = math.min(self.mapWidth, maxX)
    end
    for y = startY, maxY do
        if not self.data[y] then self.data[y] = {} end
        for x = startX, maxX do
            local dx = x - cx
            local dy = y - cy
            if dx * dx + dy * dy <= r2 then
                self.data[y][x] = terrainType
            end
        end
    end
end

--- 用噪声生成随机地形（保留兼容，内部方法）
---@param seed number 随机种子
---@param terrainWeights table 各地形权重，例如 { [1]=5, [2]=2, [3]=1 }
function TerrainTileMap:GenerateRandom(seed, terrainWeights)
    math.randomseed(seed or os.time())

    -- 构建权重表
    local totalWeight = 0
    local weightList = {}
    for terrain, weight in pairs(terrainWeights) do
        totalWeight = totalWeight + weight
        weightList[#weightList + 1] = { terrain = terrain, threshold = totalWeight }
    end

    -- 填充地图
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            local roll = math.random() * totalWeight
            for _, entry in ipairs(weightList) do
                if roll <= entry.threshold then
                    self.data[y][x] = entry.terrain
                    break
                end
            end
        end
    end
end

-- ============================================================================
-- 优化的地皮生成算法（Voronoi 大区块 + 过渡带）
-- ============================================================================

--- 简单哈希噪声（用于边缘扰动）
local function hashNoise(x, y, seed)
    local n = x * 374761393 + y * 668265263 + seed * 1274126177
    n = (n ~ (n >> 13)) * 1274126177
    n = n ~ (n >> 16)
    return (n % 1000) / 1000.0  -- 返回 0~1
end

--- Voronoi 分区生成大区块地形
---@param seed number 随机种子
---@param biomes table 地形权重表 { [terrainType] = weight }
---@param config table|nil 可选配置 { regionCount, transitionWidth, jitter }
function TerrainTileMap:GenerateWithBiomes(seed, biomes, config)
    math.randomseed(seed or os.time())

    -- 解析配置（兼容旧 API：第3个参数如果是数字则忽略，使用默认配置）
    if type(config) == "number" or config == nil then
        config = {}
    end
    local regionCount = config.regionCount or math.max(5, math.floor(self.mapWidth * self.mapHeight / 40))
    local transitionWidth = config.transitionWidth or 2  -- 过渡带宽度（瓦片数）
    local jitter = config.jitter or 0.6  -- 边缘扰动强度 0~1

    -- ===== 第1步：生成 Voronoi 种子点 =====
    local seeds = {}
    local biomeList = {}   -- 按权重展开的地形列表
    local totalWeight = 0
    for terrain, weight in pairs(biomes) do
        totalWeight = totalWeight + weight
    end
    -- 构建累积分布
    local cdf = {}
    local cumulative = 0
    for terrain, weight in pairs(biomes) do
        cumulative = cumulative + weight
        cdf[#cdf + 1] = { terrain = terrain, threshold = cumulative / totalWeight }
    end

    -- 放置种子点（带最小间距约束，避免两个种子点过于接近）
    local minDist = math.min(self.mapWidth, self.mapHeight) / math.sqrt(regionCount) * 0.5
    for i = 1, regionCount do
        local sx, sy
        local attempts = 0
        repeat
            sx = math.random(1, self.mapWidth)
            sy = math.random(1, self.mapHeight)
            -- 检查与已有种子点的距离
            local tooClose = false
            for _, s in ipairs(seeds) do
                local dx = sx - s.x
                local dy = sy - s.y
                if math.sqrt(dx * dx + dy * dy) < minDist then
                    tooClose = true
                    break
                end
            end
            attempts = attempts + 1
            if not tooClose or attempts > 20 then break end
        until false

        -- 按权重分配地形类型
        local roll = math.random()
        local terrain = cdf[1].terrain
        for _, entry in ipairs(cdf) do
            if roll <= entry.threshold then
                terrain = entry.terrain
                break
            end
        end

        seeds[#seeds + 1] = { x = sx, y = sy, terrain = terrain }
    end

    -- ===== 第2步：Voronoi 分区（每个瓦片归属最近的种子点）=====
    -- 同时记录到最近种子点的距离和到第二近种子点的距离（用于过渡带判定）
    local distMap = {}       -- [y][x] = { nearest, secondNearest, nearestTerrain, secondTerrain }
    for y = 1, self.mapHeight do
        distMap[y] = {}
        for x = 1, self.mapWidth do
            local minD1 = math.huge
            local minD2 = math.huge
            local terrain1 = nil
            local terrain2 = nil

            for _, s in ipairs(seeds) do
                -- 加入扰动使边界不规则
                local noise = hashNoise(x, y, seed + s.x * 100 + s.y) * jitter * 3
                local dx = x - s.x
                local dy = y - s.y
                local d = math.sqrt(dx * dx + dy * dy) + noise

                if d < minD1 then
                    minD2 = minD1
                    terrain2 = terrain1
                    minD1 = d
                    terrain1 = s.terrain
                elseif d < minD2 then
                    minD2 = d
                    terrain2 = s.terrain
                end
            end

            distMap[y][x] = {
                nearest = minD1,
                secondNearest = minD2,
                nearestTerrain = terrain1,
                secondTerrain = terrain2,
            }
            -- 先填充为最近区域的地形
            self.data[y][x] = terrain1
        end
    end

    -- ===== 第3步：边缘平滑（1次轻度平滑消除噪点，只对基础地形）=====
    local newData = {}
    for y = 1, self.mapHeight do
        newData[y] = {}
        for x = 1, self.mapWidth do
            newData[y][x] = self:GetDominantNeighbor(x, y)
        end
    end
    self.data = newData

    -- ===== 第4步：生成方向性过渡带（LR/TB/Corner）=====
    -- 基于平滑后的地图数据，检测每个边界瓦片的邻居方向来放置正确的过渡类型
    local T = TerrainTileMap.TERRAIN
    local transitionData = {}  -- 临时过渡层，避免修改影响后续检测
    for y = 1, self.mapHeight do
        transitionData[y] = {}
    end

    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            local current = self.data[y][x]
            -- 只处理基础地形（ID <= 10）
            if current > 10 then goto continue end

            local left   = (x > 1) and self.data[y][x-1] or current
            local right  = (x < self.mapWidth) and self.data[y][x+1] or current
            local top    = (y > 1) and self.data[y-1][x] or current
            local bottom = (y < self.mapHeight) and self.data[y+1][x] or current
            local topLeft  = (x > 1 and y > 1) and self.data[y-1][x-1] or current
            local topRight = (x < self.mapWidth and y > 1) and self.data[y-1][x+1] or current
            local botLeft  = (x > 1 and y < self.mapHeight) and self.data[y+1][x-1] or current
            local botRight = (x < self.mapWidth and y < self.mapHeight) and self.data[y+1][x+1] or current

            -- 只关注基础地形邻居
            if left > 10 then left = current end
            if right > 10 then right = current end
            if top > 10 then top = current end
            if bottom > 10 then bottom = current end
            if topLeft > 10 then topLeft = current end
            if topRight > 10 then topRight = current end
            if botLeft > 10 then botLeft = current end
            if botRight > 10 then botRight = current end

            -- 检查是否处于边界
            local hasHorizontalEdge = (left ~= current) or (right ~= current)
            local hasVerticalEdge = (top ~= current) or (bottom ~= current)

            -- 确定相邻的"另一种地形"
            local otherTerrain = nil
            if left ~= current and left <= 10 then otherTerrain = left
            elseif right ~= current and right <= 10 then otherTerrain = right
            elseif top ~= current and top <= 10 then otherTerrain = top
            elseif bottom ~= current and bottom <= 10 then otherTerrain = bottom
            end

            if not otherTerrain then goto continue end

            -- 标准化查找方向（确保 from < to）
            local from, to = current, otherTerrain
            if from > to then from, to = to, from end

            -- === 角落检测（优先级最高）===
            -- 角落条件：对角线方向有不同地形，但相邻的两个正交方向是当前地形
            local cornerPlaced = false

            -- 左上角有 other，但 top 和 left 是 current → 当前瓦片是 BR 角落
            if topLeft ~= current and topLeft <= 10 and top == current and left == current then
                local cFrom, cTo = current, topLeft
                if cFrom > cTo then cFrom, cTo = cTo, cFrom end
                local cornerType = self:FindCornerTerrain(cFrom, cTo, "br")
                if cornerType then
                    transitionData[y][x] = cornerType
                    cornerPlaced = true
                end
            end
            -- 右上角
            if not cornerPlaced and topRight ~= current and topRight <= 10 and top == current and right == current then
                local cFrom, cTo = current, topRight
                if cFrom > cTo then cFrom, cTo = cTo, cFrom end
                local cornerType = self:FindCornerTerrain(cFrom, cTo, "bl")
                if cornerType then
                    transitionData[y][x] = cornerType
                    cornerPlaced = true
                end
            end
            -- 左下角
            if not cornerPlaced and botLeft ~= current and botLeft <= 10 and bottom == current and left == current then
                local cFrom, cTo = current, botLeft
                if cFrom > cTo then cFrom, cTo = cTo, cFrom end
                local cornerType = self:FindCornerTerrain(cFrom, cTo, "tr")
                if cornerType then
                    transitionData[y][x] = cornerType
                    cornerPlaced = true
                end
            end
            -- 右下角
            if not cornerPlaced and botRight ~= current and botRight <= 10 and bottom == current and right == current then
                local cFrom, cTo = current, botRight
                if cFrom > cTo then cFrom, cTo = cTo, cFrom end
                local cornerType = self:FindCornerTerrain(cFrom, cTo, "tl")
                if cornerType then
                    transitionData[y][x] = cornerType
                    cornerPlaced = true
                end
            end

            if cornerPlaced then goto continue end

            -- === 边缘过渡检测 ===
            if hasHorizontalEdge and not hasVerticalEdge then
                -- 纯水平边界 → 使用 LR 过渡
                local lrType = self:FindEdgeTerrain(from, to, "lr")
                if lrType then
                    transitionData[y][x] = lrType
                end
            elseif hasVerticalEdge and not hasHorizontalEdge then
                -- 纯垂直边界 → 使用 TB 过渡
                local tbType = self:FindEdgeTerrain(from, to, "tb")
                if tbType then
                    transitionData[y][x] = tbType
                end
            elseif hasHorizontalEdge and hasVerticalEdge then
                -- 同时有水平和垂直边界 → 优先使用渐变过渡
                local gradType = self:FindGradientTerrain(from, to)
                if gradType then
                    transitionData[y][x] = gradType
                else
                    -- 没有渐变则尝试 LR
                    local lrType = self:FindEdgeTerrain(from, to, "lr")
                    if lrType then
                        transitionData[y][x] = lrType
                    end
                end
            end

            ::continue::
        end
    end

    -- 将过渡数据合并到主地图
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            if transitionData[y][x] then
                self.data[y][x] = transitionData[y][x]
            end
        end
    end

    print("[TerrainTileMap] Voronoi 生成完成: " .. regionCount .. " 个区块, 过渡宽度 " .. transitionWidth)
end

--- 查找两种地形之间的渐变/混合地形类型（用于对角线边界或无方向性的混合区域）
---@param t1 number 地形类型1（较小值）
---@param t2 number 地形类型2（较大值）
---@return number|nil 过渡地形类型，无则返回 nil
function TerrainTileMap:FindGradientTerrain(t1, t2)
    local T = TerrainTileMap.TERRAIN

    -- 渐变/混合贴图映射（只包含真正的渐变贴图 ID 30-32）
    local GRADIENT_MAP = {
        [T.GRASS] = {
            [T.MUD]      = T.GRASS_TO_MUD,
            [T.SWAMP]    = T.GRASS_TO_SWAMP,
        },
        [T.ROCKY] = {
            [T.VOLCANIC] = T.ROCKY_TO_VOLCANIC,
        },
    }

    -- 正向查找
    if GRADIENT_MAP[t1] and GRADIENT_MAP[t1][t2] then
        return GRADIENT_MAP[t1][t2]
    end
    -- 反向查找
    if GRADIENT_MAP[t2] and GRADIENT_MAP[t2][t1] then
        return GRADIENT_MAP[t2][t1]
    end

    return nil
end

--- 查找两种地形之间的方向性边缘过渡地形类型（LR 或 TB）
---@param t1 number 地形类型1（较小值）
---@param t2 number 地形类型2（较大值）
---@param direction string "lr" 或 "tb"
---@return number|nil 过渡地形类型
function TerrainTileMap:FindEdgeTerrain(t1, t2, direction)
    local T = TerrainTileMap.TERRAIN

    -- 方向性边缘映射：[from][to][direction] = terrainType
    local EDGE_MAP = {
        [T.GRASS] = {
            [T.MUD]       = { lr = T.GRASS_TO_MUD,       tb = T.GRASS_MUD_TB },
            [T.SWAMP]     = { lr = T.GRASS_SWAMP_LR,     tb = T.GRASS_TO_SWAMP },
            [T.ROCKY]     = { lr = T.GRASS_ROCKY_LR,     tb = T.GRASS_ROCKY_TB },
            [T.SAND]      = { lr = T.GRASS_SAND_LR,      tb = T.GRASS_SAND_LR },  -- 只有LR素材，TB复用
            [T.SNOW]      = { lr = T.GRASS_SNOW_TB,      tb = T.GRASS_SNOW_TB },  -- 只有TB素材，LR复用
            [T.DEAD_GRASS]= { lr = T.GRASS_DEADGRASS_LR, tb = T.GRASS_DEADGRASS_LR },  -- 只有LR素材
        },
        [T.MUD] = {
            [T.SWAMP]     = { lr = T.MUD_SWAMP_LR,      tb = T.MUD_SWAMP_TB },
            [T.ROCKY]     = { lr = T.MUD_ROCKY_LR,      tb = T.MUD_ROCKY_LR },  -- 只有LR素材
        },
        [T.ROCKY] = {
            [T.VOLCANIC]  = { lr = T.ROCKY_TO_VOLCANIC,  tb = T.ROCKY_VOLCANIC_TB },
        },
    }

    -- 正向查找
    if EDGE_MAP[t1] and EDGE_MAP[t1][t2] then
        return EDGE_MAP[t1][t2][direction]
    end
    -- 反向查找
    if EDGE_MAP[t2] and EDGE_MAP[t2][t1] then
        return EDGE_MAP[t2][t1][direction]
    end

    return nil
end

--- 查找两种地形之间的角落过渡地形类型
---@param t1 number 地形类型1（较小值）
---@param t2 number 地形类型2（较大值）
---@param corner string "tl" | "tr" | "bl" | "br"
---@return number|nil 角落地形类型
function TerrainTileMap:FindCornerTerrain(t1, t2, corner)
    local T = TerrainTileMap.TERRAIN

    -- 角落映射：[from][to][corner] = terrainType
    local CORNER_MAP = {
        [T.GRASS] = {
            [T.MUD] = {
                tl = T.CORNER_GRASS_IN_MUD_TL,
                tr = T.CORNER_GRASS_IN_MUD_TR,
                bl = T.CORNER_GRASS_IN_MUD_BL,
                br = T.CORNER_GRASS_IN_MUD_BR,
            },
            [T.SWAMP] = {
                tl = T.CORNER_GRASS_IN_SWAMP_TL,
                tr = T.CORNER_GRASS_IN_SWAMP_TR,
            },
        },
        [T.ROCKY] = {
            [T.VOLCANIC] = {
                tl = T.CORNER_ROCKY_IN_VOLCANIC_TL,
                tr = T.CORNER_ROCKY_IN_VOLCANIC_TR,
            },
        },
    }

    -- 正向查找
    if CORNER_MAP[t1] and CORNER_MAP[t1][t2] and CORNER_MAP[t1][t2][corner] then
        return CORNER_MAP[t1][t2][corner]
    end
    -- 反向查找
    if CORNER_MAP[t2] and CORNER_MAP[t2][t1] and CORNER_MAP[t2][t1][corner] then
        return CORNER_MAP[t2][t1][corner]
    end

    return nil
end

--- 获取邻域中出现最多的地形类型
function TerrainTileMap:GetDominantNeighbor(x, y)
    local counts = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            local nx, ny = x + dx, y + dy
            local t = self:GetTile(nx, ny)
            if t then
                counts[t] = (counts[t] or 0) + 1
            end
        end
    end

    local maxCount = 0
    local dominant = self.data[y][x]
    for t, c in pairs(counts) do
        if c > maxCount then
            maxCount = c
            dominant = t
        end
    end
    return dominant
end

-- ============================================================================
-- 自动过渡选择
-- ============================================================================

--- 获取瓦片应使用的贴图路径（考虑过渡）
---@return string 贴图路径
---@return string 过渡类型: "base" | "edge_lr" | "edge_tb" | "corner" | "gradient"
function TerrainTileMap:GetTileTexture(x, y)
    local current = self:GetTile(x, y)
    if not current then return nil, "base" end

    -- 如果瓦片已经是过渡类型（数据层已处理），直接返回对应贴图
    if current > 10 then
        local texPath = BASE_TEXTURES[current]
        if texPath then
            if current >= 22 and current <= 29 then
                return texPath, "corner"
            elseif current >= 17 and current <= 21 then
                return texPath, "edge_tb"
            elseif current >= 11 and current <= 16 then
                return texPath, "edge_lr"
            else
                return texPath, "gradient"
            end
        end
        -- 如果没有对应贴图（不应发生），fallback 到草地
        return BASE_TEXTURES[1], "base"
    end

    -- 基础地形：尝试渲染时邻居检测（兼容手动编辑的地图）
    local left   = self:GetTile(x - 1, y)
    local right  = self:GetTile(x + 1, y)
    local top    = self:GetTile(x, y - 1)
    local bottom = self:GetTile(x, y + 1)

    -- 只对基础地形邻居做检测（过渡类型邻居视为同类）
    if left and left > 10 then left = current end
    if right and right > 10 then right = current end
    if top and top > 10 then top = current end
    if bottom and bottom > 10 then bottom = current end

    -- 检查左右过渡
    if left and left ~= current and left <= 10 then
        local edgeData = EDGE_TEXTURES[left] and EDGE_TEXTURES[left][current]
        if edgeData and edgeData.lr then
            return edgeData.lr, "edge_lr"
        end
    end

    -- 检查上下过渡
    if top and top ~= current and top <= 10 then
        local edgeData = EDGE_TEXTURES[top] and EDGE_TEXTURES[top][current]
        if edgeData and edgeData.tb then
            return edgeData.tb, "edge_tb"
        end
    end

    -- 检查角落过渡 (左上角是不同地形)
    local topLeft = self:GetTile(x - 1, y - 1)
    if topLeft and topLeft > 10 then topLeft = current end
    if topLeft and topLeft ~= current and top == current and left == current then
        local cornerData = CORNER_TEXTURES[topLeft] and CORNER_TEXTURES[topLeft][current]
        if cornerData and cornerData.br then
            return cornerData.br, "corner"
        end
    end

    -- 检查角落过渡 (右上角)
    local topRight = self:GetTile(x + 1, y - 1)
    if topRight and topRight > 10 then topRight = current end
    if topRight and topRight ~= current and top == current and right == current then
        local cornerData = CORNER_TEXTURES[topRight] and CORNER_TEXTURES[topRight][current]
        if cornerData and cornerData.bl then
            return cornerData.bl, "corner"
        end
    end

    -- 默认：基础贴图
    return BASE_TEXTURES[current], "base"
end

-- ============================================================================
-- 渲染
-- ============================================================================

--- 渲染可见区域的瓦片地图
---@param screenWidth number 屏幕宽度
---@param screenHeight number 屏幕高度
function TerrainTileMap:Render(screenWidth, screenHeight)
    local vg = self.vg
    local ts = self.tileSize

    -- 计算可见范围
    local startX = math.max(1, math.floor(self.cameraX / ts) + 1)
    local startY = math.max(1, math.floor(self.cameraY / ts) + 1)
    local endX = math.ceil((self.cameraX + screenWidth) / ts) + 1
    local endY = math.ceil((self.cameraY + screenHeight) / ts) + 1
    if not self.infinite then
        endX = math.min(self.mapWidth, endX)
        endY = math.min(self.mapHeight, endY)
    else
        endX = math.min(self.mapWidth, endX)
        endY = math.min(self.mapHeight, endY)
    end

    -- 渲染可见瓦片
    for y = startY, endY do
        for x = startX, endX do
            local texPath, _ = self:GetTileTexture(x, y)
            if texPath then
                local imgId = self:GetImage(texPath)
                if imgId then
                    local px = (x - 1) * ts - self.cameraX
                    local py = (y - 1) * ts - self.cameraY

                    local paint = nvgImagePattern(vg, px, py, ts, ts, 0, imgId, 1.0)
                    nvgBeginPath(vg)
                    nvgRect(vg, px, py, ts, ts)
                    nvgFillPaint(vg, paint)
                    nvgFill(vg)
                end
            end
        end
    end
end

--- 渲染网格线（调试用）
function TerrainTileMap:RenderGrid(screenWidth, screenHeight)
    local vg = self.vg
    local ts = self.tileSize

    local startX = math.max(1, math.floor(self.cameraX / ts) + 1)
    local startY = math.max(1, math.floor(self.cameraY / ts) + 1)
    local endX = math.min(self.mapWidth, math.ceil((self.cameraX + screenWidth) / ts) + 1)
    local endY = math.min(self.mapHeight, math.ceil((self.cameraY + screenHeight) / ts) + 1)

    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 40))
    nvgStrokeWidth(vg, 1.0)

    for y = startY, endY do
        for x = startX, endX do
            local px = (x - 1) * ts - self.cameraX
            local py = (y - 1) * ts - self.cameraY
            nvgBeginPath(vg)
            nvgRect(vg, px, py, ts, ts)
            nvgStroke(vg)
        end
    end
end

--- 设置相机位置
function TerrainTileMap:SetCamera(x, y)
    self.cameraX = math.max(0, x)
    self.cameraY = math.max(0, y)
end

--- 移动相机
function TerrainTileMap:MoveCamera(dx, dy)
    self.cameraX = math.max(0, self.cameraX + dx)
    self.cameraY = math.max(0, self.cameraY + dy)
end

--- 屏幕坐标转地图坐标
function TerrainTileMap:ScreenToTile(screenX, screenY)
    local tileX = math.floor((screenX + self.cameraX) / self.tileSize) + 1
    local tileY = math.floor((screenY + self.cameraY) / self.tileSize) + 1
    return tileX, tileY
end

--- 清理所有 NanoVG 图片资源
function TerrainTileMap:Destroy()
    for path, imgId in pairs(self.imageCache) do
        nvgDeleteImage(self.vg, imgId)
    end
    self.imageCache = {}
    print("[TerrainTileMap] 资源已清理")
end

return TerrainTileMap
