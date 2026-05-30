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
    if x < 1 or y < 1 then return end
    if self.infinite then
        self:EnsureTile(x, y)
    elseif x > self.mapWidth or y > self.mapHeight then
        return
    end
    if not self.data[y] then self.data[y] = {} end
    self.data[y][x] = terrainType
end

--- 获取单个瓦片地形
function TerrainTileMap:GetTile(x, y)
    if x < 1 or y < 1 then return nil end
    if not self.infinite and (x > self.mapWidth or y > self.mapHeight) then
        return nil
    end
    if self.data[y] then
        return self.data[y][x]
    end
    return nil
end

--- 用矩形区域填充地形
function TerrainTileMap:FillRect(x1, y1, x2, y2, terrainType)
    if self.infinite then
        self:EnsureTile(math.max(1, x2), math.max(1, y2))
    end
    local maxY = self.infinite and math.max(1, y2) or math.min(self.mapHeight, y2)
    local maxX = self.infinite and math.max(1, x2) or math.min(self.mapWidth, x2)
    for y = math.max(1, y1), maxY do
        if not self.data[y] then self.data[y] = {} end
        for x = math.max(1, x1), maxX do
            self.data[y][x] = terrainType
        end
    end
end

--- 用圆形区域填充地形
function TerrainTileMap:FillCircle(cx, cy, radius, terrainType)
    local r2 = radius * radius
    local maxY = math.ceil(cy + radius)
    local maxX = math.ceil(cx + radius)
    if self.infinite then
        self:EnsureTile(math.max(1, maxX), math.max(1, maxY))
    else
        maxY = math.min(self.mapHeight, maxY)
        maxX = math.min(self.mapWidth, maxX)
    end
    for y = math.max(1, math.floor(cy - radius)), maxY do
        for x = math.max(1, math.floor(cx - radius)), maxX do
            local dx = x - cx
            local dy = y - cy
            if dx * dx + dy * dy <= r2 then
                self.data[y][x] = terrainType
            end
        end
    end
end

--- 用噪声生成随机地形
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

--- 用简易柏林噪声风格生成地形（基于邻域平滑）
---@param seed number 随机种子
---@param biomes table 地形生物群落定义
---@param smoothPasses number 平滑迭代次数
function TerrainTileMap:GenerateWithBiomes(seed, biomes, smoothPasses)
    -- 先随机填充
    self:GenerateRandom(seed, biomes)

    -- 多次平滑：让同类地形聚集
    smoothPasses = smoothPasses or 3
    for _ = 1, smoothPasses do
        local newData = {}
        for y = 1, self.mapHeight do
            newData[y] = {}
            for x = 1, self.mapWidth do
                newData[y][x] = self:GetDominantNeighbor(x, y)
            end
        end
        self.data = newData
    end
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
---@return string 过渡类型: "base" | "edge_lr" | "edge_tb" | "corner"
function TerrainTileMap:GetTileTexture(x, y)
    local current = self:GetTile(x, y)
    if not current then return nil, "base" end

    local left   = self:GetTile(x - 1, y)
    local right  = self:GetTile(x + 1, y)
    local top    = self:GetTile(x, y - 1)
    local bottom = self:GetTile(x, y + 1)

    -- 检查左右过渡
    if left and left ~= current then
        local edgeData = EDGE_TEXTURES[left] and EDGE_TEXTURES[left][current]
        if edgeData and edgeData.lr then
            return edgeData.lr, "edge_lr"
        end
    end

    -- 检查上下过渡
    if top and top ~= current then
        local edgeData = EDGE_TEXTURES[top] and EDGE_TEXTURES[top][current]
        if edgeData and edgeData.tb then
            return edgeData.tb, "edge_tb"
        end
    end

    -- 检查角落过渡 (左上角是不同地形)
    local topLeft = self:GetTile(x - 1, y - 1)
    if topLeft and topLeft ~= current and top == current and left == current then
        local cornerData = CORNER_TEXTURES[topLeft] and CORNER_TEXTURES[topLeft][current]
        if cornerData and cornerData.br then
            return cornerData.br, "corner"
        end
    end

    -- 检查角落过渡 (右上角)
    local topRight = self:GetTile(x + 1, y - 1)
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
