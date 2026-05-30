-- ============================================================================
-- LevelEditor.lua - 关卡编辑器(透明覆盖, 直接修改真实游戏场景)
-- F3 打开/关闭, 编辑器接管相机, 可拖拽/放置/删除真实游戏物件
-- 底部工具栏以游戏贴图缩略图展示可放置资产
-- ============================================================================

local TerrainTileMap = require("TileMap.TerrainTileMap")

local LevelEditor = {}
LevelEditor.__index = LevelEditor

-- ============================================================================
-- 编辑模式
-- ============================================================================
local MODE_TERRAIN = 1    -- 地形绘制
local MODE_OBJECT  = 2    -- 物件(树/石头)
local MODE_ZONE    = 3    -- 区域(舒适区/毒圈/出生点)

local MODE_NAMES = { "地形", "物件", "区域" }

-- 物件子类型
local OBJ_TREE = 1
local OBJ_ROCK = 2
local OBJ_NAMES = { "树木", "岩石" }

-- 区域子类型
local ZONE_COMFORT = 1
local ZONE_CIRCLE  = 2
local ZONE_SPAWN   = 3
local ZONE_NAMES = { "舒适区", "毒圈", "出生点" }

local COMFORT_TYPES = { "campfire", "spring", "altar" }
local COMFORT_NAMES = { "篝火", "清泉", "圣坛" }

-- 底部工具栏高度（包含模式切换+贴图选择区域，黄色箭头位置）
local TOOLBAR_H = 300
-- 顶部模式栏高度（已移到底部，设为0隐藏）
local TOPBAR_H = 0

-- 编辑器工具栏的地形 → 对应 TerrainTileMap.TERRAIN 枚举值
local EDITOR_BRUSH_TO_TERRAIN = {
    -- 基础地形 (1-10)
    1,   -- 草地
    2,   -- 泥地
    3,   -- 沼泽
    4,   -- 碎石
    5,   -- 火山岩
    8,   -- 枯草
    9,   -- 森林
    6,   -- 沙地
    7,   -- 雪地
    10,  -- 鹅卵石
    -- 过渡贴图LR (11-16)
    11,  -- 草沙LR
    12,  -- 草枯LR
    13,  -- 草石LR
    14,  -- 草沼LR
    15,  -- 泥石LR
    16,  -- 泥沼LR
    -- 过渡贴图TB (17-21)
    17,  -- 草雪TB
    18,  -- 草石TB
    19,  -- 草泥TB
    20,  -- 泥沼TB
    21,  -- 石火TB
    -- 角落贴图 (22-29)
    22,  -- 草泥角BL
    23,  -- 草泥角BR
    24,  -- 草泥角TL
    25,  -- 草泥角TR
    26,  -- 草沼角TL
    27,  -- 草沼角TR
    28,  -- 石火角TL
    29,  -- 石火角TR
    -- 混合/渐变 (30-32)
    30,  -- 草渐泥
    31,  -- 草渐沼
    32,  -- 石渐火
}

-- 地形笔刷名称（与 EDITOR_BRUSH_TO_TERRAIN 一一对应）
local EDITOR_BRUSH_NAMES = {
    "草地", "泥地", "沼泽", "碎石", "火山岩", "枯草", "森林", "沙地", "雪地", "鹅卵石",
    "草沙LR", "草枯LR", "草石LR", "草沼LR", "泥石LR", "泥沼LR",
    "草雪TB", "草石TB", "草泥TB", "泥沼TB", "石火TB",
    "草泥角BL", "草泥角BR", "草泥角TL", "草泥角TR", "草沼角TL", "草沼角TR", "石火角TL", "石火角TR",
    "草渐泥", "草渐沼", "石渐火",
}

-- 地形笔刷总数
local TERRAIN_BRUSH_COUNT = #EDITOR_BRUSH_TO_TERRAIN

-- TerrainTileMap 枚举值 → 游戏 terrainType 字符串
local TERRAIN_ENUM_TO_KEY = {
    [1] = "grass", [2] = "mud", [3] = "swamp", [4] = "rocky",
    [5] = "volcanic", [6] = "sand", [7] = "snow",
    [8] = "dead_grass", [9] = "forest", [10] = "cobblestone",
    [11] = "grass_sand_lr", [12] = "grass_deadgrass_lr", [13] = "grass_rocky_lr",
    [14] = "grass_swamp_lr", [15] = "mud_rocky_lr", [16] = "mud_swamp_lr",
    [17] = "grass_snow_tb", [18] = "grass_rocky_tb", [19] = "grass_mud_tb",
    [20] = "mud_swamp_tb", [21] = "rocky_volcanic_tb",
    [22] = "corner_grass_in_mud_bl", [23] = "corner_grass_in_mud_br",
    [24] = "corner_grass_in_mud_tl", [25] = "corner_grass_in_mud_tr",
    [26] = "corner_grass_in_swamp_tl", [27] = "corner_grass_in_swamp_tr",
    [28] = "corner_rocky_in_volcanic_tl", [29] = "corner_rocky_in_volcanic_tr",
    [30] = "grass_to_mud", [31] = "grass_to_swamp", [32] = "rocky_to_volcanic",
}

-- ============================================================================
-- 构造
-- ============================================================================

---@param vg userdata NanoVG 上下文
---@param config table { mapPixelSize, camera(引用), circle(引用) }
function LevelEditor.New(vg, config)
    local self = setmetatable({}, LevelEditor)

    self.vg = vg
    self.active = false
    self.mapPixelSize = config.mapPixelSize or 1024

    -- 编辑模式
    self.mode = MODE_TERRAIN
    self.objType = OBJ_TREE
    self.zoneType = ZONE_COMFORT
    self.comfortType = 1

    -- 地形瓦片(地形模式专用) — 32×32格, 每格32px, 地图1024px
    local tilePixel = 64  -- 1024 / 64 = 16格
    local tileCount = 16
    self.tileMap = TerrainTileMap.New(vg, {
        mapWidth = tileCount,
        mapHeight = tileCount,
        tileSize = tilePixel,
    })
    self.tilePixel = tilePixel
    self.tileCount = tileCount

    -- 编辑器相机(编辑器激活时接管游戏相机)
    self.editorCamX = self.mapPixelSize / 2
    self.editorCamY = self.mapPixelSize / 2
    self.editorZoom = 1.0
    self.savedCamX = 0
    self.savedCamY = 0

    -- 画笔状态(地形)
    self.currentBrush = 1
    self.brushSize = 1
    self.isPainting = false
    self.showGrid = true  -- 默认显示网格

    -- 引用游戏真实数据
    self.gameCamera = config.camera
    self.gameCircle = config.circle

    -- 拖拽
    self.dragging = false
    self.dragTarget = nil
    self.dragIdx = nil
    self.dragOffX = 0
    self.dragOffY = 0
    self.selectedType = nil
    self.selectedIdx = nil

    -- 出生点配置
    self.spawnConfig = {
        cx = self.mapPixelSize / 2,
        cy = self.mapPixelSize / 2,
        radius = self.mapPixelSize * 0.35,
    }

    -- 地形是否已导出
    self.terrainExported = false

    -- 工具栏贴图(在 InitImages 中加载)
    self.terrainIcons = {}   -- { [1..7] = nvgImageHandle }
    self.objectIcons = {}    -- { tree=handle, rock=handle }
    self.zoneIcons = {}      -- { campfire=handle, spring=handle, altar=handle, circle=handle, spawn=handle }
    self.imagesLoaded = false

    return self
end

-- 加载工具栏缩略图(需在 NanoVG 上下文可用后调用一次)
function LevelEditor:InitImages()
    if self.imagesLoaded then return end
    self.imagesLoaded = true
    local ctx = self.vg

    -- 地形贴图缩略图(顺序与 EDITOR_BRUSH_TO_TERRAIN 一一对应)
    local terrainPaths = {
        -- 基础地形 (1-10)
        "image/地皮/terrain_grass_20260530170030.png",
        "image/地皮/terrain_mud_20260530165944.png",
        "image/地皮/terrain_swamp_20260530165947.png",
        "image/地皮/terrain_rocky_20260530165943.png",
        "image/地皮/terrain_volcanic_20260530165940.png",
        "image/地皮/terrain_dead_grass_20260530170619.png",
        "image/地皮/terrain_forest_floor_20260530170620.png",
        "image/地皮/terrain_sand_20260530170620.png",
        "image/地皮/terrain_snow_20260530170624.png",
        "image/地皮/terrain_cobblestone_20260530170621.png",
        -- 过渡贴图LR (11-16)
        "image/地皮/terrain_grass_sand_lr_20260530170624.png",
        "image/地皮/terrain_grass_deadgrass_lr_20260530170623.png",
        "image/地皮/terrain_grass_rocky_lr_20260530170407.png",
        "image/地皮/terrain_grass_swamp_lr_20260530170402.png",
        "image/地皮/terrain_mud_rocky_lr_20260530170405.png",
        "image/地皮/terrain_mud_swamp_lr_20260530170404.png",
        -- 过渡贴图TB (17-21)
        "image/地皮/terrain_grass_snow_tb_20260530170622.png",
        "image/地皮/terrain_grass_rocky_tb_20260530170412.png",
        "image/地皮/terrain_grass_mud_tb_20260530170406.png",
        "image/地皮/terrain_mud_swamp_tb_20260530170405.png",
        "image/地皮/terrain_rocky_volcanic_tb_20260530170414.png",
        -- 角落贴图 (22-29)
        "image/地皮/terrain_corner_grass_in_mud_bl_20260530170523.png",
        "image/地皮/terrain_corner_grass_in_mud_br_20260530170508.png",
        "image/地皮/terrain_corner_grass_in_mud_tl_20260530170508.png",
        "image/地皮/terrain_corner_grass_in_mud_tr_20260530170512.png",
        "image/地皮/terrain_corner_grass_in_swamp_tl_20260530170508.png",
        "image/地皮/terrain_corner_grass_in_swamp_tr_20260530170508.png",
        "image/地皮/terrain_corner_rocky_in_volcanic_tl_20260530170512.png",
        "image/地皮/terrain_corner_rocky_in_volcanic_tr_20260530170512.png",
        -- 混合/渐变 (30-32)
        "image/地皮/terrain_grass_to_mud_20260530165951.png",
        "image/地皮/terrain_grass_to_swamp_20260530165942.png",
        "image/地皮/terrain_rocky_to_volcanic_20260530165943.png",
    }
    for i, path in ipairs(terrainPaths) do
        local img = nvgCreateImage(ctx, path, 0)
        if img and img > 0 then
            self.terrainIcons[i] = img
        end
    end

    -- 物件不用贴图(使用绘制图标)
    -- 区域也使用绘制图标
end

-- ============================================================================
-- 开关
-- ============================================================================

function LevelEditor:Toggle()
    self.active = not self.active
    if self.active then
        self:InitImages()
        self.savedCamX = self.gameCamera.x
        self.savedCamY = self.gameCamera.y
        self.editorCamX = self.gameCamera.x
        self.editorCamY = self.gameCamera.y
    else
        self.gameCamera.x = self.savedCamX
        self.gameCamera.y = self.savedCamY
        self.dragging = false
        self.selectedIdx = nil
    end
    return self.active
end

function LevelEditor:IsActive()
    return self.active
end

-- ============================================================================
-- 输入
-- ============================================================================

function LevelEditor:HandleKeyDown(key)
    if not self.active then return false end

    if key == KEY_F3 then
        self:Toggle()
        return true
    end

    -- Tab: 切换模式
    if key == KEY_TAB then
        self.mode = self.mode % 3 + 1
        self.isPainting = false
        self.dragging = false
        self.selectedIdx = nil
        self.selectedType = nil
        return true
    end

    -- 地形模式
    if self.mode == MODE_TERRAIN then
        if key == KEY_G then
            self.showGrid = not self.showGrid
            return true
        end
        if key == KEY_R then
            local T = self.tileMap.TERRAIN
            self.tileMap:GenerateWithBiomes(os.time(), {
                [T.GRASS] = 5, [T.MUD] = 2, [T.SWAMP] = 2,
                [T.ROCKY] = 2, [T.DEAD_GRASS] = 2, [T.FOREST] = 2,
                [T.VOLCANIC] = 1,
            }, 2)
            self.terrainExported = true
            print("[编辑器] 随机地形已生成并应用")
            return true
        end
        if key == KEY_LEFTBRACKET then
            self.brushSize = math.max(1, self.brushSize - 1)
            return true
        end
        if key == KEY_RIGHTBRACKET then
            self.brushSize = math.min(4, self.brushSize + 1)
            return true
        end
        -- Enter: 应用地形
        if key == KEY_RETURN then
            self.terrainExported = true
            print("[编辑器] 地形已应用")
            return true
        end
    end

    -- 物件模式
    if self.mode == MODE_OBJECT then
        if key == KEY_DELETE or key == KEY_BACKSPACE then
            self:DeleteSelected()
            return true
        end
    end

    -- 区域模式
    if self.mode == MODE_ZONE then
        if key == KEY_DELETE or key == KEY_BACKSPACE then
            self:DeleteSelected()
            return true
        end
    end

    return false
end

function LevelEditor:HandleMouseDown(button, mx, my)
    if not self.active then return false end

    -- 检查是否点击在底部工具栏区域
    local dpr = graphics:GetDPR()
    local logW = graphics:GetWidth() / dpr
    local logH = graphics:GetHeight() / dpr
    local localMX = mx or (input.mousePosition.x / dpr)
    local localMY = my or (input.mousePosition.y / dpr)

    if button == MOUSEB_LEFT then
        -- 底部工具栏点击（包含模式切换和贴图选择）
        if localMY >= logH - TOOLBAR_H then
            self:HandleToolbarClick(localMX, localMY, logW, logH)
            return true
        end

        -- 世界区域操作
        if self.mode == MODE_TERRAIN then
            self.isPainting = true
        elseif self.mode == MODE_OBJECT then
            self:HandleObjectMouseDown()
        elseif self.mode == MODE_ZONE then
            self:HandleZoneMouseDown()
        end
        return true
    elseif button == MOUSEB_RIGHT then
        if self.mode == MODE_OBJECT then
            self:DeleteAtCursor()
        elseif self.mode == MODE_ZONE and self.zoneType == ZONE_COMFORT then
            self:DeleteComfortAtCursor()
        end
        return true
    end
    return false
end

function LevelEditor:HandleMouseUp(button)
    if not self.active then return false end
    if button == MOUSEB_LEFT then
        self.isPainting = false
        self.dragging = false
        self.dragTarget = nil
        return true
    end
    return false
end

-- ============================================================================
-- 工具栏点击
-- ============================================================================

function LevelEditor:HandleToolbarClick(mx, my, logW, logH)
    local barY = logH - TOOLBAR_H
    local relY = my - barY

    -- 底部模式切换Tab区域（左下角36px）
    local modeBarY = logH - 36
    if my >= modeBarY then
        local tabW = 64
        local tabStartX = 8
        for i = 1, 3 do
            local bx = tabStartX + (i - 1) * tabW + 2
            local bw = tabW - 4
            if mx >= bx and mx < bx + bw then
                self.mode = i
                self.isPainting = false
                self.dragging = false
                self.selectedIdx = nil
                self.selectedType = nil
                return
            end
        end
        return
    end

    if self.mode == MODE_TERRAIN then
        -- 地形格子（8列布局，与渲染一致）
        local cols = 8
        local count = TERRAIN_BRUSH_COUNT
        local rows = math.ceil(count / cols)
        local cellSize = 36
        local padX = 4
        local padY = 3
        local labelH = 11
        local totalW = cols * cellSize + (cols - 1) * padX
        local totalH = rows * (cellSize + labelH) + (rows - 1) * padY
        local startX = (logW - totalW) / 2
        local availH = TOOLBAR_H - 36
        local startY = barY + (availH - totalH) / 2

        for i = 1, count do
            local col = ((i - 1) % cols)
            local row = math.floor((i - 1) / cols)
            local cx = startX + col * (cellSize + padX)
            local cellY = startY + row * (cellSize + labelH + padY)
            if mx >= cx and mx < cx + cellSize and my >= cellY and my < cellY + cellSize + labelH then
                self.currentBrush = i
                return
            end
        end
    elseif self.mode == MODE_OBJECT then
        -- 2个物件按钮
        local cellW = 64
        local startX = (logW - cellW * 2 - 10) / 2
        for i = 1, 2 do
            local cx = startX + (i - 1) * (cellW + 10)
            if mx >= cx and mx < cx + cellW then
                self.objType = i
                return
            end
        end
    elseif self.mode == MODE_ZONE then
        -- 5个区域按钮: 篝火/清泉/圣坛/毒圈/出生点
        local cellW = 64
        local totalW = cellW * 5 + 10 * 4
        local startX = (logW - totalW) / 2
        for i = 1, 5 do
            local cx = startX + (i - 1) * (cellW + 10)
            if mx >= cx and mx < cx + cellW then
                if i <= 3 then
                    self.zoneType = ZONE_COMFORT
                    self.comfortType = i
                elseif i == 4 then
                    self.zoneType = ZONE_CIRCLE
                else
                    self.zoneType = ZONE_SPAWN
                end
                return
            end
        end
    end
end

function LevelEditor:HandleTopbarClick(mx, my, logW, logH)
    -- 模式切换Tab
    local tabW = 72
    for i = 1, 3 do
        local bx = (i - 1) * tabW + 6
        if mx >= bx and mx < bx + tabW - 4 then
            self.mode = i
            self.isPainting = false
            self.dragging = false
            self.selectedIdx = nil
            self.selectedType = nil
            return
        end
    end
end

-- ============================================================================
-- 更新(每帧)
-- ============================================================================

function LevelEditor:Update(dt, inputRef, dpr)
    if not self.active then return end

    -- WASD/方向键 移动编辑器相机
    local speed = 300 * dt / self.editorZoom
    if inputRef:GetKeyDown(KEY_W) or inputRef:GetKeyDown(KEY_UP) then
        self.editorCamY = self.editorCamY - speed
    end
    if inputRef:GetKeyDown(KEY_S) or inputRef:GetKeyDown(KEY_DOWN) then
        self.editorCamY = self.editorCamY + speed
    end
    if inputRef:GetKeyDown(KEY_A) or inputRef:GetKeyDown(KEY_LEFT) then
        self.editorCamX = self.editorCamX - speed
    end
    if inputRef:GetKeyDown(KEY_D) or inputRef:GetKeyDown(KEY_RIGHT) then
        self.editorCamX = self.editorCamX + speed
    end

    -- 滚轮缩放
    local wheel = inputRef.mouseMoveWheel or 0
    if wheel ~= 0 then
        self.editorZoom = math.max(0.3, math.min(4.0, self.editorZoom + wheel * 0.15))
    end

    -- 同步编辑器相机到游戏相机
    self.gameCamera.x = self.editorCamX
    self.gameCamera.y = self.editorCamY

    -- 地形绘制
    if self.mode == MODE_TERRAIN and self.isPainting then
        local mx = inputRef.mousePosition.x / dpr
        local my = inputRef.mousePosition.y / dpr
        local wx, wy = self:ScreenToWorld(mx, my, dpr)
        local tx = math.floor(wx / self.tilePixel) + 1
        local ty = math.floor(wy / self.tilePixel) + 1
        if tx >= 1 and tx <= self.tileCount and ty >= 1 and ty <= self.tileCount then
            -- currentBrush (1-7) → TerrainTileMap 枚举值
            local terrainValue = EDITOR_BRUSH_TO_TERRAIN[self.currentBrush] or 1
            if self.brushSize <= 1 then
                self.tileMap:SetTile(tx, ty, terrainValue)
            else
                self.tileMap:FillCircle(tx, ty, self.brushSize, terrainValue)
            end
            -- 实时生效: 绘制即应用
            self.terrainExported = true
        end
    end

    -- 物件/区域拖拽
    if self.dragging then
        local mx = inputRef.mousePosition.x / dpr
        local my = inputRef.mousePosition.y / dpr
        local wx, wy = self:ScreenToWorld(mx, my, dpr)
        self:HandleDrag(wx, wy)
    end
end

-- ============================================================================
-- 坐标转换
-- ============================================================================

function LevelEditor:ScreenToWorld(sx, sy, dpr)
    local logW = graphics:GetWidth() / dpr
    local logH = graphics:GetHeight() / dpr
    local totalZoom = 2.0 * self.editorZoom
    local wx = (sx - logW / 2) / totalZoom + self.editorCamX
    local wy = (sy - logH / 2) / totalZoom + self.editorCamY
    return wx, wy
end

function LevelEditor:WorldToScreen(wx, wy, logW, logH)
    local totalZoom = 2.0 * self.editorZoom
    local sx = (wx - self.editorCamX) * totalZoom + logW / 2
    local sy = (wy - self.editorCamY) * totalZoom + logH / 2
    return sx, sy
end

-- ============================================================================
-- 物件操作
-- ============================================================================

function LevelEditor:HandleObjectMouseDown()
    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr
    local wx, wy = self:ScreenToWorld(mx, my, dpr)

    local decos = self:GetMapDecorations()
    if decos then
        for i = #decos, 1, -1 do
            local obj = decos[i]
            local dx = obj.x - wx
            local dy = obj.y - wy
            local hitR = (obj.type == "tree") and 30 or (obj.size or 15)
            if dx*dx + dy*dy < hitR * hitR then
                self.selectedType = "object"
                self.selectedIdx = i
                self.dragging = true
                self.dragTarget = "object"
                self.dragIdx = i
                self.dragOffX = obj.x - wx
                self.dragOffY = obj.y - wy
                return
            end
        end
    end

    -- 放置新物件
    self.selectedIdx = nil
    self.selectedType = nil
    local decos2 = self:GetMapDecorations()
    if decos2 then
        local obj
        if self.objType == OBJ_TREE then
            obj = {
                type = "tree",
                x = wx, y = wy,
                height = 60 + math.random() * 80,
                twist = (math.random() - 0.5) * 0.6,
                branches = 2 + math.random(0, 3),
                seed = math.random(1, 99999),
            }
        else
            obj = {
                type = "rock",
                x = wx, y = wy,
                size = 8 + math.random() * 18,
                seed = math.random(1, 99999),
            }
        end
        table.insert(decos2, obj)
        self.selectedType = "object"
        self.selectedIdx = #decos2
        print("[编辑器] 放置" .. obj.type .. " (" .. math.floor(wx) .. "," .. math.floor(wy) .. ")")
    end
end

function LevelEditor:HandleZoneMouseDown()
    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr
    local wx, wy = self:ScreenToWorld(mx, my, dpr)

    if self.zoneType == ZONE_COMFORT then
        local zones = self:GetComfortZones()
        if zones then
            for i = #zones, 1, -1 do
                local z = zones[i]
                local dx = z.x - wx
                local dy = z.y - wy
                if dx*dx + dy*dy < 50*50 then
                    self.selectedType = "comfort"
                    self.selectedIdx = i
                    self.dragging = true
                    self.dragTarget = "comfort"
                    self.dragIdx = i
                    self.dragOffX = z.x - wx
                    self.dragOffY = z.y - wy
                    return
                end
            end
        end
        -- 放置新舒适区
        if zones then
            table.insert(zones, {
                x = wx, y = wy,
                type = COMFORT_TYPES[self.comfortType],
                playersInside = {},
                zoneEnergy = 100,
                zoneCooldown = 0,
                zoneUsesLeft = 5,
            })
            self.selectedType = "comfort"
            self.selectedIdx = #zones
            print("[编辑器] 放置舒适区:" .. COMFORT_TYPES[self.comfortType] .. " (" .. math.floor(wx) .. "," .. math.floor(wy) .. ")")
        end

    elseif self.zoneType == ZONE_CIRCLE then
        local circ = self.gameCircle
        local dx = wx - circ.cx
        local dy = wy - circ.cy
        local d = math.sqrt(dx*dx + dy*dy)
        if d < 50 then
            self.dragging = true
            self.dragTarget = "circle_center"
        elseif math.abs(d - circ.radius) < 40 then
            self.dragging = true
            self.dragTarget = "circle_radius"
        else
            self.dragging = true
            self.dragTarget = "circle_center"
            circ.cx = wx
            circ.cy = wy
        end

    elseif self.zoneType == ZONE_SPAWN then
        local sp = self.spawnConfig
        local dx = wx - sp.cx
        local dy = wy - sp.cy
        local d = math.sqrt(dx*dx + dy*dy)
        if d < 50 then
            self.dragging = true
            self.dragTarget = "spawn_center"
        elseif math.abs(d - sp.radius) < 40 then
            self.dragging = true
            self.dragTarget = "spawn_radius"
        else
            self.dragging = true
            self.dragTarget = "spawn_center"
            sp.cx = wx
            sp.cy = wy
        end
    end
end

function LevelEditor:HandleDrag(wx, wy)
    if self.dragTarget == "object" then
        local decos = self:GetMapDecorations()
        if decos and self.dragIdx and decos[self.dragIdx] then
            decos[self.dragIdx].x = wx + self.dragOffX
            decos[self.dragIdx].y = wy + self.dragOffY
        end
    elseif self.dragTarget == "comfort" then
        local zones = self:GetComfortZones()
        if zones and self.dragIdx and zones[self.dragIdx] then
            zones[self.dragIdx].x = wx + self.dragOffX
            zones[self.dragIdx].y = wy + self.dragOffY
        end
    elseif self.dragTarget == "circle_center" then
        self.gameCircle.cx = wx
        self.gameCircle.cy = wy
        self.gameCircle.targetRadius = self.gameCircle.radius
    elseif self.dragTarget == "circle_radius" then
        local dx = wx - self.gameCircle.cx
        local dy = wy - self.gameCircle.cy
        self.gameCircle.radius = math.max(100, math.sqrt(dx*dx + dy*dy))
        self.gameCircle.targetRadius = self.gameCircle.radius
    elseif self.dragTarget == "spawn_center" then
        self.spawnConfig.cx = wx
        self.spawnConfig.cy = wy
    elseif self.dragTarget == "spawn_radius" then
        local dx = wx - self.spawnConfig.cx
        local dy = wy - self.spawnConfig.cy
        self.spawnConfig.radius = math.max(50, math.sqrt(dx*dx + dy*dy))
    end
end

function LevelEditor:DeleteSelected()
    if self.selectedType == "object" and self.selectedIdx then
        local decos = self:GetMapDecorations()
        if decos and decos[self.selectedIdx] then
            table.remove(decos, self.selectedIdx)
            print("[编辑器] 删除物件#" .. self.selectedIdx)
        end
    elseif self.selectedType == "comfort" and self.selectedIdx then
        local zones = self:GetComfortZones()
        if zones and zones[self.selectedIdx] then
            table.remove(zones, self.selectedIdx)
            print("[编辑器] 删除舒适区#" .. self.selectedIdx)
        end
    end
    self.selectedIdx = nil
    self.selectedType = nil
end

function LevelEditor:DeleteAtCursor()
    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr
    local wx, wy = self:ScreenToWorld(mx, my, dpr)
    local decos = self:GetMapDecorations()
    if not decos then return end
    for i = #decos, 1, -1 do
        local obj = decos[i]
        local dx = obj.x - wx
        local dy = obj.y - wy
        local hitR = (obj.type == "tree") and 30 or (obj.size or 15)
        if dx*dx + dy*dy < hitR * hitR then
            table.remove(decos, i)
            self.selectedIdx = nil
            self.selectedType = nil
            print("[编辑器] 右键删除物件")
            return
        end
    end
end

function LevelEditor:DeleteComfortAtCursor()
    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr
    local wx, wy = self:ScreenToWorld(mx, my, dpr)
    local zones = self:GetComfortZones()
    if not zones then return end
    for i = #zones, 1, -1 do
        local z = zones[i]
        local dx = z.x - wx
        local dy = z.y - wy
        if dx*dx + dy*dy < 60*60 then
            table.remove(zones, i)
            self.selectedIdx = nil
            self.selectedType = nil
            print("[编辑器] 右键删除舒适区")
            return
        end
    end
end

-- ============================================================================
-- 访问游戏真实数据
-- ============================================================================

function LevelEditor:GetMapDecorations()
    if GetMapDecorations then
        return GetMapDecorations()
    end
    return nil
end

function LevelEditor:GetComfortZones()
    if GetComfortZones then
        return GetComfortZones()
    end
    return nil
end

-- ============================================================================
-- 渲染(透明覆盖层)
-- ============================================================================

function LevelEditor:Render(logW, logH, dpr)
    if not self.active then return end

    local ctx = self.vg
    local totalZoom = 2.0 * self.editorZoom

    -- ===== 世界空间标记 =====
    nvgSave(ctx)
    nvgTranslate(ctx, logW / 2, logH / 2)
    nvgScale(ctx, totalZoom, totalZoom)
    nvgTranslate(ctx, -self.editorCamX, -self.editorCamY)

    -- 地图网格(始终在编辑器激活时绘制, G切换)
    if self.showGrid then
        self:RenderGrid(ctx, totalZoom, logW, logH)
    end

    -- 物件选中框
    if self.mode == MODE_OBJECT then
        local decos = self:GetMapDecorations()
        if decos then
            for i, obj in ipairs(decos) do
                nvgBeginPath(ctx)
                if obj.type == "tree" then
                    nvgCircle(ctx, obj.x, obj.y, 20)
                    nvgStrokeColor(ctx, nvgRGBA(50, 200, 50, 80))
                else
                    nvgCircle(ctx, obj.x, obj.y, obj.size or 12)
                    nvgStrokeColor(ctx, nvgRGBA(150, 150, 200, 80))
                end
                nvgStrokeWidth(ctx, 1.0 / totalZoom)
                nvgStroke(ctx)

                if self.selectedType == "object" and i == self.selectedIdx then
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, obj.x, obj.y, 28)
                    nvgStrokeColor(ctx, nvgRGBA(255, 255, 0, 255))
                    nvgStrokeWidth(ctx, 2.5 / totalZoom)
                    nvgStroke(ctx)
                end
            end
        end
    end

    -- 舒适区选中框
    if self.mode == MODE_ZONE and self.zoneType == ZONE_COMFORT then
        local zones = self:GetComfortZones()
        if zones then
            for i, zone in ipairs(zones) do
                nvgBeginPath(ctx)
                nvgCircle(ctx, zone.x, zone.y, 15)
                nvgStrokeColor(ctx, nvgRGBA(255, 200, 50, 200))
                nvgStrokeWidth(ctx, 2.0 / totalZoom)
                nvgStroke(ctx)

                if self.selectedType == "comfort" and i == self.selectedIdx then
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, zone.x, zone.y, 25)
                    nvgStrokeColor(ctx, nvgRGBA(255, 255, 0, 255))
                    nvgStrokeWidth(ctx, 2.5 / totalZoom)
                    nvgStroke(ctx)
                end
            end
        end
    end

    -- 毒圈手柄
    if self.mode == MODE_ZONE and self.zoneType == ZONE_CIRCLE then
        local circ = self.gameCircle
        nvgBeginPath(ctx)
        nvgCircle(ctx, circ.cx, circ.cy, 12)
        nvgFillColor(ctx, nvgRGBA(255, 60, 60, 180))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgStrokeWidth(ctx, 2.0 / totalZoom)
        nvgStroke(ctx)
        local handleX = circ.cx + circ.radius
        nvgBeginPath(ctx)
        nvgCircle(ctx, handleX, circ.cy, 10)
        nvgFillColor(ctx, nvgRGBA(255, 100, 100, 200))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 200))
        nvgStrokeWidth(ctx, 1.5 / totalZoom)
        nvgStroke(ctx)
    end

    -- 出生点手柄
    if self.mode == MODE_ZONE and self.zoneType == ZONE_SPAWN then
        local sp = self.spawnConfig
        nvgBeginPath(ctx)
        nvgCircle(ctx, sp.cx, sp.cy, sp.radius)
        nvgStrokeColor(ctx, nvgRGBA(50, 150, 255, 180))
        nvgStrokeWidth(ctx, 2.5 / totalZoom)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, sp.cx, sp.cy, 12)
        nvgFillColor(ctx, nvgRGBA(50, 150, 255, 180))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgStrokeWidth(ctx, 2.0 / totalZoom)
        nvgStroke(ctx)
        for i = 1, 5 do
            local angle = (i - 1) * (2 * math.pi / 5) - math.pi / 2
            local px = sp.cx + math.cos(angle) * sp.radius
            local py = sp.cy + math.sin(angle) * sp.radius
            nvgBeginPath(ctx)
            nvgCircle(ctx, px, py, 8)
            nvgFillColor(ctx, nvgRGBA(80, 180, 255, 200))
            nvgFill(ctx)
        end
    end

    -- 地形画笔光标
    if self.mode == MODE_TERRAIN then
        local pmx = input.mousePosition.x / dpr
        local pmy = input.mousePosition.y / dpr
        local wx, wy = self:ScreenToWorld(pmx, pmy, dpr)
        local ts = self.tilePixel
        local tx = math.floor(wx / ts)
        local ty = math.floor(wy / ts)
        nvgBeginPath(ctx)
        if self.brushSize <= 1 then
            nvgRect(ctx, tx * ts, ty * ts, ts, ts)
        else
            nvgCircle(ctx, (tx + 0.5) * ts, (ty + 0.5) * ts, self.brushSize * ts)
        end
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 0, 200))
        nvgStrokeWidth(ctx, 2.0 / totalZoom)
        nvgStroke(ctx)
    end

    -- 物件放置光标
    if self.mode == MODE_OBJECT and not self.dragging then
        local pmx = input.mousePosition.x / dpr
        local pmy = input.mousePosition.y / dpr
        local wx, wy = self:ScreenToWorld(pmx, pmy, dpr)
        nvgBeginPath(ctx)
        if self.objType == OBJ_TREE then
            nvgCircle(ctx, wx, wy, 20)
            nvgStrokeColor(ctx, nvgRGBA(100, 255, 100, 150))
        else
            nvgCircle(ctx, wx, wy, 12)
            nvgStrokeColor(ctx, nvgRGBA(180, 180, 255, 150))
        end
        nvgStrokeWidth(ctx, 1.5 / totalZoom)
        nvgStroke(ctx)
    end

    -- 舒适区放置光标
    if self.mode == MODE_ZONE and self.zoneType == ZONE_COMFORT and not self.dragging then
        local pmx = input.mousePosition.x / dpr
        local pmy = input.mousePosition.y / dpr
        local wx, wy = self:ScreenToWorld(pmx, pmy, dpr)
        nvgBeginPath(ctx)
        nvgCircle(ctx, wx, wy, 75)
        nvgStrokeColor(ctx, nvgRGBA(255, 200, 50, 100))
        nvgStrokeWidth(ctx, 1.5 / totalZoom)
        nvgStroke(ctx)
    end

    nvgRestore(ctx)

    -- ===== 屏幕空间 HUD =====
    self:RenderInfoBar(logW, logH, dpr)
    self:RenderBottomToolbar(logW, logH, dpr)
end

-- ============================================================================
-- 网格渲染(世界空间)
-- ============================================================================

function LevelEditor:RenderGrid(ctx, totalZoom, logW, logH)
    -- 网格间距 = 游戏地形瓦片大小(128px)
    local gridSize = self.tilePixel

    -- 计算可见区域
    local halfW = logW / 2 / totalZoom
    local halfH = logH / 2 / totalZoom
    local viewL = self.editorCamX - halfW
    local viewR = self.editorCamX + halfW
    local viewT = self.editorCamY - halfH
    local viewB = self.editorCamY + halfH

    -- 网格覆盖整个可见区域
    local startX = math.floor(viewL / gridSize) * gridSize
    local startY = math.floor(viewT / gridSize) * gridSize

    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 40))
    nvgStrokeWidth(ctx, 1.0 / totalZoom)

    -- 竖线
    for x = startX, viewR, gridSize do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, viewT)
        nvgLineTo(ctx, x, viewB)
        nvgStroke(ctx)
    end
    -- 横线
    for y = startY, viewB, gridSize do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, viewL, y)
        nvgLineTo(ctx, viewR, y)
        nvgStroke(ctx)
    end
end

-- ============================================================================
-- 顶部模式切换栏
-- ============================================================================

function LevelEditor:RenderInfoBar(logW, logH, dpr)
    local ctx = self.vg
    local barH = 24

    -- 顶部半透明提示条（不含按钮，仅显示信息）
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, logW, barH)
    nvgFillColor(ctx, nvgRGBA(15, 15, 25, 180))
    nvgFill(ctx)

    nvgFontFace(ctx, "sans")

    -- 左侧标记
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(255, 200, 50, 255))
    nvgText(ctx, 10, barH / 2, "[关卡编辑器] F3关闭")

    -- 中间提示
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(170, 170, 170, 200))
    local hint = "WASD移动 | 滚轮缩放(x" .. string.format("%.1f", self.editorZoom) .. ") | Tab切模式"
    if self.mode == MODE_TERRAIN then
        hint = hint .. " | [/]画笔(" .. self.brushSize .. ") G网格 R随机"
    elseif self.mode == MODE_OBJECT then
        hint = hint .. " | 左键放置 右键删除"
    elseif self.mode == MODE_ZONE then
        hint = hint .. " | 左键放置/拖拽 右键删除"
    end
    nvgText(ctx, logW / 2, barH / 2, hint)
end

-- ============================================================================
-- 底部工具栏(以贴图缩略图显示可放置资产)
-- ============================================================================

function LevelEditor:RenderBottomToolbar(logW, logH, dpr)
    local ctx = self.vg
    local barY = logH - TOOLBAR_H

    -- 半透明背景
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, barY, logW, TOOLBAR_H)
    nvgFillColor(ctx, nvgRGBA(15, 15, 25, 220))
    nvgFill(ctx)

    -- 上边缘线
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, 0, barY)
    nvgLineTo(ctx, logW, barY)
    nvgStrokeColor(ctx, nvgRGBA(60, 130, 255, 150))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    nvgFontFace(ctx, "sans")

    if self.mode == MODE_TERRAIN then
        self:RenderTerrainToolbar(ctx, logW, logH, barY)
    elseif self.mode == MODE_OBJECT then
        self:RenderObjectToolbar(ctx, logW, logH, barY)
    elseif self.mode == MODE_ZONE then
        self:RenderZoneToolbar(ctx, logW, logH, barY)
    end

    -- 底部模式切换Tab栏（左下角，36px高）
    local modeBarY = logH - 36
    -- Tab栏分隔线
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, 0, modeBarY)
    nvgLineTo(ctx, logW, modeBarY)
    nvgStrokeColor(ctx, nvgRGBA(60, 100, 200, 100))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    local tabW = 64
    local tabStartX = 8  -- 左对齐
    for i = 1, 3 do
        local bx = tabStartX + (i - 1) * tabW + 2
        local bw = tabW - 4
        local by = modeBarY + 4
        local bh = 28
        local isActive = (self.mode == i)

        -- Tab背景
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, bx, by, bw, bh, 4)
        if isActive then
            nvgFillColor(ctx, nvgRGBA(60, 130, 255, 200))
        else
            nvgFillColor(ctx, nvgRGBA(40, 40, 60, 150))
        end
        nvgFill(ctx)

        -- Tab文字
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, isActive and 255 or 160))
        nvgText(ctx, bx + bw / 2, by + bh / 2, MODE_NAMES[i])
    end

    -- 坐标显示（右下角）
    local pmx = input.mousePosition.x / dpr
    local pmy = input.mousePosition.y / dpr
    local wx, wy = self:ScreenToWorld(pmx, pmy, dpr)
    nvgFontSize(ctx, 10)
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(130, 130, 255, 200))
    nvgText(ctx, logW - 8, modeBarY + 18, string.format("(%d, %d)", math.floor(wx), math.floor(wy)))
end

-- 地形工具栏: 地形贴图缩略图（8列多行布局）
function LevelEditor:RenderTerrainToolbar(ctx, logW, logH, barY)
    local count = TERRAIN_BRUSH_COUNT
    local cols = 8
    local rows = math.ceil(count / cols)
    local cellSize = 36
    local padX = 4
    local padY = 3
    local labelH = 11
    local totalW = cols * cellSize + (cols - 1) * padX
    local totalH = rows * (cellSize + labelH) + (rows - 1) * padY
    local startX = (logW - totalW) / 2
    -- 将贴图区域在工具栏内居中（排除底部36px模式栏）
    local availH = TOOLBAR_H - 36
    local startY = barY + (availH - totalH) / 2

    for i = 1, count do
        local col = ((i - 1) % cols)
        local row = math.floor((i - 1) / cols)
        local cx = startX + col * (cellSize + padX)
        local cellY = startY + row * (cellSize + labelH + padY)
        local isSelected = (self.currentBrush == i)

        -- 选中边框
        if isSelected then
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cx - 2, cellY - 2, cellSize + 4, cellSize + 4, 4)
            nvgStrokeColor(ctx, nvgRGBA(60, 200, 255, 255))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        end

        -- 贴图缩略图
        if self.terrainIcons[i] then
            local pat = nvgImagePattern(ctx, cx, cellY, cellSize, cellSize, 0, self.terrainIcons[i], isSelected and 1.0 or 0.7)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cx, cellY, cellSize, cellSize, 3)
            nvgFillPaint(ctx, pat)
            nvgFill(ctx)
        else
            -- 无贴图时用色块
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cx, cellY, cellSize, cellSize, 3)
            nvgFillColor(ctx, nvgRGBA(40 + i * 6, 50, 30, 200))
            nvgFill(ctx)
        end

        -- 边框
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx, cellY, cellSize, cellSize, 3)
        nvgStrokeColor(ctx, nvgRGBA(80, 80, 100, isSelected and 255 or 120))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)

        -- 名称标签
        nvgFontSize(ctx, 7)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, isSelected and 255 or 150))
        nvgText(ctx, cx + cellSize / 2, cellY + cellSize + 1, EDITOR_BRUSH_NAMES[i])
    end
end

-- 物件工具栏: 树木/岩石图标
function LevelEditor:RenderObjectToolbar(ctx, logW, logH, barY)
    local cellSize = 56
    local padding = 16
    local availH = TOOLBAR_H - 36  -- 排除底部模式栏
    local totalW = 2 * cellSize + padding
    local startX = (logW - totalW) / 2
    local cellY = barY + (availH - cellSize) / 2

    -- 树木
    local cx1 = startX
    local isTree = (self.objType == OBJ_TREE)
    if isTree then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx1 - 3, cellY - 3, cellSize + 6, cellSize + 6, 6)
        nvgStrokeColor(ctx, nvgRGBA(60, 200, 255, 255))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
    end
    -- 画树图标
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx1, cellY, cellSize, cellSize, 4)
    nvgFillColor(ctx, nvgRGBA(25, 45, 20, 220))
    nvgFill(ctx)
    -- 树干
    nvgBeginPath(ctx)
    nvgRect(ctx, cx1 + cellSize/2 - 3, cellY + cellSize * 0.55, 6, cellSize * 0.35)
    nvgFillColor(ctx, nvgRGBA(100, 70, 40, 255))
    nvgFill(ctx)
    -- 树冠
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx1 + cellSize/2, cellY + cellSize * 0.38, cellSize * 0.28)
    nvgFillColor(ctx, nvgRGBA(60, 140, 50, 255))
    nvgFill(ctx)
    nvgFontSize(ctx, 9)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, isTree and 255 or 150))
    nvgText(ctx, cx1 + cellSize / 2, cellY + cellSize + 2, "树木")

    -- 岩石
    local cx2 = startX + cellSize + padding
    local isRock = (self.objType == OBJ_ROCK)
    if isRock then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx2 - 3, cellY - 3, cellSize + 6, cellSize + 6, 6)
        nvgStrokeColor(ctx, nvgRGBA(60, 200, 255, 255))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
    end
    -- 画石头图标
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx2, cellY, cellSize, cellSize, 4)
    nvgFillColor(ctx, nvgRGBA(35, 35, 40, 220))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, cx2 + cellSize/2, cellY + cellSize * 0.5, cellSize * 0.3, cellSize * 0.22)
    nvgFillColor(ctx, nvgRGBA(120, 120, 130, 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, cx2 + cellSize*0.38, cellY + cellSize * 0.6, cellSize * 0.18, cellSize * 0.14)
    nvgFillColor(ctx, nvgRGBA(90, 90, 100, 255))
    nvgFill(ctx)
    nvgFontSize(ctx, 9)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, isRock and 255 or 150))
    nvgText(ctx, cx2 + cellSize / 2, cellY + cellSize + 2, "岩石")

    -- 数量提示
    local decos = self:GetMapDecorations()
    local count = decos and #decos or 0
    nvgFontSize(ctx, 10)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(170, 170, 170, 200))
    nvgText(ctx, startX + totalW + 20, barY + TOOLBAR_H / 2, "物件总数: " .. count)
end

-- 区域工具栏: 舒适区类型/毒圈/出生点
function LevelEditor:RenderZoneToolbar(ctx, logW, logH, barY)
    local cellSize = 52
    local padding = 10
    local items = {
        { name = "篝火", type = "comfort", sub = 1, r = 255, g = 120, b = 30 },
        { name = "清泉", type = "comfort", sub = 2, r = 80, g = 180, b = 255 },
        { name = "圣坛", type = "comfort", sub = 3, r = 180, g = 100, b = 255 },
        { name = "毒圈", type = "circle", sub = 0, r = 255, g = 50, b = 50 },
        { name = "出生点", type = "spawn", sub = 0, r = 50, g = 150, b = 255 },
    }
    local availH = TOOLBAR_H - 36  -- 排除底部模式栏
    local totalW = #items * cellSize + (#items - 1) * padding
    local startX = (logW - totalW) / 2
    local cellY = barY + (availH - cellSize) / 2

    for idx, item in ipairs(items) do
        local cx = startX + (idx - 1) * (cellSize + padding)
        local isSelected = false
        if item.type == "comfort" then
            isSelected = (self.zoneType == ZONE_COMFORT and self.comfortType == item.sub)
        elseif item.type == "circle" then
            isSelected = (self.zoneType == ZONE_CIRCLE)
        elseif item.type == "spawn" then
            isSelected = (self.zoneType == ZONE_SPAWN)
        end

        if isSelected then
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cx - 3, cellY - 3, cellSize + 6, cellSize + 6, 6)
            nvgStrokeColor(ctx, nvgRGBA(60, 200, 255, 255))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        end

        -- 色块背景
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx, cellY, cellSize, cellSize, 4)
        nvgFillColor(ctx, nvgRGBA(20, 20, 30, 220))
        nvgFill(ctx)

        -- 图标(圆形)
        nvgBeginPath(ctx)
        nvgCircle(ctx, cx + cellSize/2, cellY + cellSize * 0.42, cellSize * 0.25)
        nvgFillColor(ctx, nvgRGBA(item.r, item.g, item.b, 200))
        nvgFill(ctx)

        -- 边框
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx, cellY, cellSize, cellSize, 4)
        nvgStrokeColor(ctx, nvgRGBA(80, 80, 100, isSelected and 200 or 80))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)

        -- 名称
        nvgFontSize(ctx, 9)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, isSelected and 255 or 150))
        nvgText(ctx, cx + cellSize / 2, cellY + cellSize + 2, item.name)
    end

    -- 当前信息
    nvgFontSize(ctx, 10)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(170, 170, 170, 200))
    local infoX = startX + totalW + 16
    local infoY = barY + availH / 2
    if self.zoneType == ZONE_CIRCLE then
        nvgText(ctx, infoX, infoY, string.format("毒圈半径: %.0f", self.gameCircle.radius))
    elseif self.zoneType == ZONE_SPAWN then
        nvgText(ctx, infoX, infoY, string.format("出生半径: %.0f", self.spawnConfig.radius))
    else
        local zones = self:GetComfortZones()
        local count = zones and #zones or 0
        nvgText(ctx, infoX, infoY, "舒适区数量: " .. count)
    end
end

-- ============================================================================
-- 地形导出接口
-- ============================================================================

function LevelEditor:IsTerrainExported()
    return self.terrainExported
end

function LevelEditor:GetTerrainImageKey(worldX, worldY)
    if not self.terrainExported then return nil end
    -- worldX/worldY 是游戏传入的瓦片左上角坐标(0,32,64...)
    -- 转换为 1-based 瓦片索引
    local tx = math.floor(worldX / self.tilePixel) + 1
    local ty = math.floor(worldY / self.tilePixel) + 1
    if tx < 1 or tx > self.tileCount or ty < 1 or ty > self.tileCount then return nil end
    local t = self.tileMap:GetTile(tx, ty)
    if t then
        return TERRAIN_ENUM_TO_KEY[t]
    end
    return nil
end

function LevelEditor:GetSpawnConfig()
    return self.spawnConfig
end

function LevelEditor:GetTerrainAt(worldX, worldY)
    if not self.terrainExported then return nil end
    local tx = math.floor(worldX / self.tilePixel) + 1
    local ty = math.floor(worldY / self.tilePixel) + 1
    if tx < 1 or ty < 1 then return nil end
    return self.tileMap:GetTile(tx, ty)
end

-- ============================================================================
-- 清理
-- ============================================================================

function LevelEditor:Destroy()
    if self.tileMap then
        self.tileMap:Destroy()
        self.tileMap = nil
    end
end

return LevelEditor
