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
local OBJ_FLOWER = 3
local OBJ_PLANT = 4

-- 物件资产定义（名称 + 贴图路径）
local OBJ_ASSETS = {
    -- 树木 (2种)
    { type = "tree", name = "猪头树", icon = "image/资产绿植/xs1.png", variant = 1 },
    { type = "tree", name = "枯树红花", icon = "image/资产绿植/xs2.png", variant = 2 },
    -- 岩石 (5种)
    { type = "rock", name = "散落碎石", icon = "image/资产绿植/s2.png", variant = 1 },
    { type = "rock", name = "大圆石", icon = "image/资产绿植/s3.png", variant = 2 },
    { type = "rock", name = "高角岩", icon = "image/资产绿植/s4.png", variant = 3 },
    { type = "rock", name = "扁平石板", icon = "image/资产绿植/s5.png", variant = 4 },
    { type = "rock", name = "棱角碎石", icon = "image/资产绿植/s6.png", variant = 5 },
    -- 花朵 (4种)
    { type = "flower", name = "玫瑰", icon = "image/资产绿植/h1.png", variant = 1 },
    { type = "flower", name = "郁金香", icon = "image/资产绿植/h2.png", variant = 2 },
    { type = "flower", name = "蓟花", icon = "image/资产绿植/h3.png", variant = 3 },
    { type = "flower", name = "向日葵", icon = "image/资产绿植/h4.png", variant = 4 },
    -- 植物 (3种)
    { type = "plant", name = "高草", icon = "image/资产绿植/1.png", variant = 1 },
    { type = "plant", name = "浆果藤蔓", icon = "image/资产绿植/2.png", variant = 2 },
    { type = "plant", name = "枯灌木", icon = "image/资产绿植/3.png", variant = 3 },
}
local OBJ_ASSET_COUNT = #OBJ_ASSETS

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

    -- 网格原点: 以毒圈中心为网格中心
    local centerX = (config.mapCenter and config.mapCenter.x) or self.mapPixelSize / 2
    local centerY = (config.mapCenter and config.mapCenter.y) or self.mapPixelSize / 2
    self.mapOriginX = centerX - self.mapPixelSize / 2
    self.mapOriginY = centerY - self.mapPixelSize / 2

    -- 编辑模式
    self.mode = MODE_TERRAIN
    self.objType = OBJ_TREE
    self.objAssetIdx = 1       -- 当前选中的物件资产索引(对应OBJ_ASSETS)
    self.zoneType = ZONE_COMFORT
    self.comfortType = 1

    -- 地形瓦片(地形模式专用) — 每格64px, 以毒圈中心为基准
    local tilePixel = 64
    local tileCount = math.floor(self.mapPixelSize / tilePixel)
    self.tileMap = TerrainTileMap.New(vg, {
        mapWidth = tileCount,
        mapHeight = tileCount,
        tileSize = tilePixel,
        infinite = true,
    })
    self.tilePixel = tilePixel
    self.tileCount = tileCount

    -- 游戏启动时使用固定种子代码生成地形
    self.seedCode = ""
    self.lastGenerateSeed = 0
    self.terrainExported = false
    self:ImportSeedCode("3645817920687")

    -- 编辑器相机(编辑器激活时接管游戏相机, 定位到游戏地图中心)
    self.editorCamX = (config.mapCenter and config.mapCenter.x) or self.mapPixelSize / 2
    self.editorCamY = (config.mapCenter and config.mapCenter.y) or self.mapPixelSize / 2
    self.editorZoom = 1.0
    self.savedCamX = 0
    self.savedCamY = 0
    self.paletteScrollY = 0  -- 底部调色板滚动偏移

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

    -- 导入/导出功能状态
    self.seedCode = ""           -- 当前种子代码(13位)
    self.lastGenerateSeed = 0    -- 上次随机生成用的种子
    self.showImportDialog = false -- 是否显示导入对话框
    self.importInput = ""        -- 导入输入框内容
    self.importCursor = 0        -- 输入光标位置
    self.showExportDialog = false -- 是否显示导出对话框
    self.exportMessage = ""       -- 导出提示信息
    self.dialogTimer = 0          -- 对话框自动消失计时器
    self._copyFlash = 0           -- 复制按钮闪烁计时

    return self
end

-- 加载工具栏缩略图(需在 NanoVG 上下文可用后调用一次)
function LevelEditor:InitImages()
    if self.imagesLoaded then return end
    self.imagesLoaded = true

    -- 生成初始种子代码
    if self.lastGenerateSeed > 0 and self.seedCode == "" then
        self.seedCode = self:EncodeSeed(self.lastGenerateSeed, 18, 2.5, 0.7)
        print("[编辑器] 初始地形种子代码: " .. self.seedCode)
    end
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

    -- 物件贴图缩略图
    self.objectIcons = {}
    for i, asset in ipairs(OBJ_ASSETS) do
        local img = nvgCreateImage(ctx, asset.icon, 0)
        if img and img > 0 then
            self.objectIcons[i] = img
        end
    end
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

    -- 导入对话框激活时，拦截所有键盘输入
    if self.showImportDialog then
        return self:HandleImportDialogKey(key)
    end

    -- 导出对话框激活时，任意键关闭
    if self.showExportDialog then
        self.showExportDialog = false
        return true
    end

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
            self.lastGenerateSeed = os.time()
            self.tileMap:GenerateWithBiomes(self.lastGenerateSeed, {
                [T.GRASS] = 5, [T.MUD] = 2, [T.SWAMP] = 2,
                [T.FOREST] = 2, [T.SAND] = 1, [T.SNOW] = 1,
            }, {
                regionCount = 18,
                transitionWidth = 2.5,
                jitter = 0.7,
            })
            self.terrainExported = true
            -- 自动生成种子代码
            self.seedCode = self:EncodeSeed(self.lastGenerateSeed, 18, 2.5, 0.7)
            print("[编辑器] 随机地形已生成, 种子代码: " .. self.seedCode)
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
        -- 优先处理对话框点击
        if self.showImportDialog then
            if self:HandleImportDialogClick(localMX, localMY) then
                return true
            end
        end
        if self.showExportDialog then
            -- 检查复制按钮
            if self._exportCopyRect then
                local r = self._exportCopyRect
                if localMX >= r.x and localMX <= r.x + r.w and localMY >= r.y and localMY <= r.y + r.h then
                    -- 复制到剪贴板
                    if ui then
                        ui:SetClipboardText(self.exportMessage)
                    end
                    self._copyFlash = 1.0
                    print("[编辑器] 已复制种子代码: " .. self.exportMessage)
                    return true
                end
            end
            self.showExportDialog = false
            self._exportCopyRect = nil
            return true
        end

        -- 检查右上角按钮点击
        if self:HandleTopRightButtonClick(localMX, localMY) then
            return true
        end

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
-- 右上角导入/导出按钮点击
-- ============================================================================

function LevelEditor:HandleTopRightButtonClick(mx, my)
    -- 检测导出按钮
    if self._exportBtnRect then
        local r = self._exportBtnRect
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            self:ExportSeedCode()
            return true
        end
    end
    -- 检测导入按钮
    if self._importBtnRect then
        local r = self._importBtnRect
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            self.showImportDialog = true
            self.showExportDialog = false
            self.importInput = ""
            return true
        end
    end
    return false
end

function LevelEditor:HandleImportDialogKey(key)
    -- ESC: 取消
    if key == KEY_ESCAPE then
        self.showImportDialog = false
        self.importInput = ""
        return true
    end

    -- 回车: 确认
    if key == KEY_RETURN or key == KEY_KP_ENTER then
        if #self.importInput == 13 then
            local success = self:ImportSeedCode(self.importInput)
            if success then
                self.showImportDialog = false
                self.showExportDialog = true
                self.exportMessage = self.importInput
                self.dialogTimer = 5.0
            end
        end
        return true
    end

    -- 退格: 删除最后一个字符
    if key == KEY_BACKSPACE then
        if #self.importInput > 0 then
            self.importInput = self.importInput:sub(1, -2)
        end
        return true
    end

    -- 数字键 0-9 (主键盘)
    if key >= KEY_0 and key <= KEY_9 then
        if #self.importInput < 13 then
            local digit = key - KEY_0
            self.importInput = self.importInput .. tostring(digit)
        end
        return true
    end

    -- 数字键 0-9 (小键盘)
    if key >= KEY_KP_0 and key <= KEY_KP_9 then
        if #self.importInput < 13 then
            local digit = key - KEY_KP_0
            self.importInput = self.importInput .. tostring(digit)
        end
        return true
    end

    -- 其他键一律吃掉不传递
    return true
end

--- 处理文本输入事件（支持移动端虚拟键盘）
---@param text string 输入的文本字符
---@return boolean 是否消耗事件
function LevelEditor:HandleTextInput(text)
    if not self.active then return false end
    if not self.showImportDialog then return false end

    -- 只接受数字字符
    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch >= "0" and ch <= "9" then
            if #self.importInput < 13 then
                self.importInput = self.importInput .. ch
            end
        end
    end
    return true
end

function LevelEditor:HandleImportDialogClick(mx, my)
    -- 数字键盘按钮
    if self._numpadRects then
        for _, r in ipairs(self._numpadRects) do
            if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
                if #self.importInput < 13 then
                    self.importInput = self.importInput .. r.key
                end
                return true
            end
        end
    end

    -- 删除按钮
    if self._numpadDeleteRect then
        local r = self._numpadDeleteRect
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            if #self.importInput > 0 then
                self.importInput = self.importInput:sub(1, -2)
            end
            return true
        end
    end

    -- 确认按钮
    if self._importConfirmRect then
        local r = self._importConfirmRect
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            if #self.importInput == 13 then
                local success = self:ImportSeedCode(self.importInput)
                if success then
                    self.showImportDialog = false
                    self.showExportDialog = true
                    self.exportMessage = self.importInput
                    self.dialogTimer = 5.0
                else
                    print("[编辑器] 种子代码无效!")
                end
            end
            return true
        end
    end

    -- 取消按钮
    if self._importCancelRect then
        local r = self._importCancelRect
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            self.showImportDialog = false
            self.importInput = ""
            return true
        end
    end

    -- 点在对话框内但不是按钮,不关闭
    return true
end

-- ============================================================================
-- 工具栏点击
-- ============================================================================

function LevelEditor:HandleToolbarClick(mx, my, logW, logH)
    local barY = logH - TOOLBAR_H

    -- 左侧竖排模式切换Tab区域（80px宽）
    local tabAreaW = 80
    local tabH = 32
    local tabPad = 6
    local tabStartY = barY + 12
    if mx < tabAreaW then
        for i = 1, 3 do
            local by = tabStartY + (i - 1) * (tabH + tabPad)
            if my >= by and my < by + tabH then
                self.mode = i
                self.isPainting = false
                self.dragging = false
                self.selectedIdx = nil
                self.selectedType = nil
                self.paletteScrollY = 0  -- 切换模式重置滚动
                return
            end
        end
        return
    end

    -- 右侧内容区域
    local contentX = tabAreaW + 8
    local contentY = barY + 8
    local contentW = logW - contentX - 8
    local contentH = TOOLBAR_H - 16

    if self.mode == MODE_TERRAIN then
        local cellSize = 56
        local padX = 6
        local padY = 4
        local labelH = 14
        local cols = math.max(1, math.floor((contentW + padX) / (cellSize + padX)))
        local count = TERRAIN_BRUSH_COUNT
        local startX = contentX
        local startY = contentY - self.paletteScrollY

        for i = 1, count do
            local col = ((i - 1) % cols)
            local row = math.floor((i - 1) / cols)
            local cx = startX + col * (cellSize + padX)
            local cellY = startY + row * (cellSize + labelH + padY)
            if mx >= cx and mx < cx + cellSize and my >= cellY and my < cellY + cellSize + labelH then
                if my >= contentY and my < contentY + contentH then
                    self.currentBrush = i
                    return
                end
            end
        end
    elseif self.mode == MODE_OBJECT then
        local cellSize = 56
        local padX = 6
        local padY = 4
        local labelH = 14
        local cols = math.max(1, math.floor((contentW + padX) / (cellSize + padX)))
        local count = OBJ_ASSET_COUNT
        local startX = contentX
        local startY = contentY - self.paletteScrollY

        for i = 1, count do
            local col = ((i - 1) % cols)
            local row = math.floor((i - 1) / cols)
            local cx = startX + col * (cellSize + padX)
            local cellY = startY + row * (cellSize + labelH + padY)
            if mx >= cx and mx < cx + cellSize and my >= cellY and my < cellY + cellSize + labelH then
                if my >= contentY and my < contentY + contentH then
                    self.objAssetIdx = i
                    local asset = OBJ_ASSETS[i]
                    if asset.type == "tree" then self.objType = OBJ_TREE
                    elseif asset.type == "rock" then self.objType = OBJ_ROCK
                    elseif asset.type == "flower" then self.objType = OBJ_FLOWER
                    elseif asset.type == "plant" then self.objType = OBJ_PLANT
                    end
                    return
                end
            end
        end
    elseif self.mode == MODE_ZONE then
        -- 区域按钮: 左对齐网格布局
        local cellSize = 56
        local padX = 6
        local padY = 4
        local labelH = 14
        local zoneCount = 5
        local cols = math.max(1, math.floor((contentW + padX) / (cellSize + padX)))
        for i = 1, zoneCount do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cx = contentX + col * (cellSize + padX)
            local cy = contentY + row * (cellSize + labelH + padY) - self.paletteScrollY
            if mx >= cx and mx < cx + cellSize and my >= cy and my < cy + cellSize then
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

    -- 更新对话框计时器
    if self.showExportDialog and self.dialogTimer > 0 then
        self.dialogTimer = self.dialogTimer - dt
        if self.dialogTimer <= 0 then
            self.showExportDialog = false
            self._exportCopyRect = nil
        end
    end

    -- 复制按钮闪烁计时
    if self._copyFlash and self._copyFlash > 0 then
        self._copyFlash = self._copyFlash - dt
    end

    -- 对话框激活时不处理编辑器输入
    if self.showImportDialog then return end

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

    -- 滚轮: 底部面板区域滚动调色板，地图区域平滑缩放
    local wheel = inputRef.mouseMoveWheel or 0
    if wheel ~= 0 then
        local my = inputRef.mousePosition.y / dpr
        local barY = self._lastLogH and (self._lastLogH - TOOLBAR_H) or 0
        if self._lastLogH and my >= barY then
            -- 在底部面板区域 → 滚动调色板
            self.paletteScrollY = self.paletteScrollY - wheel * 30
            if self.paletteScrollY < 0 then self.paletteScrollY = 0 end
        else
            -- 在地图区域 → 平滑缩放
            local zoomSpeed = self.editorZoom * 0.1
            self.editorZoom = math.max(0.3, math.min(4.0, self.editorZoom + wheel * zoomSpeed))
        end
    end

    -- 同步编辑器相机到游戏相机
    self.gameCamera.x = self.editorCamX
    self.gameCamera.y = self.editorCamY

    -- 地形绘制(无限模式: 任意坐标均可绘制)
    if self.mode == MODE_TERRAIN and self.isPainting then
        local mx = inputRef.mousePosition.x / dpr
        local my = inputRef.mousePosition.y / dpr
        local wx, wy = self:ScreenToWorld(mx, my, dpr)
        local tx = math.floor((wx - self.mapOriginX) / self.tilePixel) + 1
        local ty = math.floor((wy - self.mapOriginY) / self.tilePixel) + 1
        local terrainValue = EDITOR_BRUSH_TO_TERRAIN[self.currentBrush] or 1
        if self.brushSize <= 1 then
            self.tileMap:SetTile(tx, ty, terrainValue)
        else
            self.tileMap:FillCircle(tx, ty, self.brushSize, terrainValue)
        end
        -- 实时生效: 绘制即应用
        self.terrainExported = true
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
        local asset = OBJ_ASSETS[self.objAssetIdx]
        local obj
        if asset.type == "tree" then
            obj = {
                type = "tree",
                x = wx, y = wy,
                height = 60 + math.random() * 80,
                twist = (math.random() - 0.5) * 0.6,
                branches = 2 + math.random(0, 3),
                seed = (asset.variant - 1) * 50000 + math.random(1, 49999),
            }
        elseif asset.type == "rock" then
            obj = {
                type = "rock",
                x = wx, y = wy,
                size = 8 + math.random() * 18,
                seed = (asset.variant - 1) * 50000 + math.random(1, 49999),
            }
        elseif asset.type == "flower" then
            obj = {
                type = "flower",
                x = wx, y = wy,
                variant = asset.variant,
                size = 24 + math.random() * 16,
                seed = math.random(1, 99999),
            }
        elseif asset.type == "plant" then
            obj = {
                type = "plant",
                x = wx, y = wy,
                variant = asset.variant,
                size = 30 + math.random() * 20,
                seed = math.random(1, 99999),
            }
        end
        if obj then
            table.insert(decos2, obj)
            self.selectedType = "object"
            self.selectedIdx = #decos2
            print("[编辑器] 放置" .. obj.type .. ":" .. asset.name .. " (" .. math.floor(wx) .. "," .. math.floor(wy) .. ")")
        end
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
        local tx = math.floor((wx - self.mapOriginX) / ts)
        local ty = math.floor((wy - self.mapOriginY) / ts)
        local drawX = tx * ts + self.mapOriginX
        local drawY = ty * ts + self.mapOriginY
        nvgBeginPath(ctx)
        if self.brushSize <= 1 then
            nvgRect(ctx, drawX, drawY, ts, ts)
        else
            nvgCircle(ctx, drawX + ts * 0.5, drawY + ts * 0.5, self.brushSize * ts)
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
    self:RenderDialogs(logW, logH)
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

    -- 网格以 mapOrigin 为基准对齐
    local ox, oy = self.mapOriginX, self.mapOriginY
    local startX = math.floor((viewL - ox) / gridSize) * gridSize + ox
    local startY = math.floor((viewT - oy) / gridSize) * gridSize + oy

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
-- 导入/导出对话框渲染
-- ============================================================================

function LevelEditor:RenderDialogs(logW, logH)
    local ctx = self.vg

    -- ===== 导出对话框 =====
    if self.showExportDialog and self.exportMessage ~= "" then
        local dlgW = 300
        local dlgH = 120
        local dlgX = (logW - dlgW) / 2
        local dlgY = (logH - dlgH) / 2 - 40

        -- 背景
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, dlgX, dlgY, dlgW, dlgH, 8)
        nvgFillColor(ctx, nvgRGBA(20, 25, 35, 240))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(80, 220, 120, 200))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)

        -- 标题
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 13)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(80, 220, 120, 255))
        nvgText(ctx, dlgX + dlgW / 2, dlgY + 20, "地图种子代码已生成")

        -- 种子代码(大字)
        nvgFontSize(ctx, 20)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgText(ctx, dlgX + dlgW / 2, dlgY + 48, self.exportMessage)

        -- 复制按钮
        local copyBtnW = 64
        local copyBtnH = 26
        local copyBtnX = dlgX + dlgW / 2 - copyBtnW / 2
        local copyBtnY = dlgY + 68
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, copyBtnX, copyBtnY, copyBtnW, copyBtnH, 5)
        if self._copyFlash and self._copyFlash > 0 then
            nvgFillColor(ctx, nvgRGBA(40, 180, 80, 240))
        else
            nvgFillColor(ctx, nvgRGBA(60, 130, 220, 220))
        end
        nvgFill(ctx)
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        if self._copyFlash and self._copyFlash > 0 then
            nvgText(ctx, copyBtnX + copyBtnW / 2, copyBtnY + copyBtnH / 2, "已复制!")
        else
            nvgText(ctx, copyBtnX + copyBtnW / 2, copyBtnY + copyBtnH / 2, "复制")
        end

        -- 保存复制按钮坐标
        self._exportCopyRect = { x = copyBtnX, y = copyBtnY, w = copyBtnW, h = copyBtnH }

        -- 底部提示
        nvgFontSize(ctx, 9)
        nvgFillColor(ctx, nvgRGBA(140, 140, 140, 180))
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(ctx, dlgX + dlgW / 2, dlgY + dlgH - 12, "点击空白处关闭")

        -- 倒计时条
        if self.dialogTimer > 0 then
            local progress = self.dialogTimer / 5.0
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, dlgX + 10, dlgY + dlgH - 5, (dlgW - 20) * progress, 3, 2)
            nvgFillColor(ctx, nvgRGBA(80, 220, 120, 150))
            nvgFill(ctx)
        end
    end

    -- ===== 导入对话框 =====
    if self.showImportDialog then
        local dlgW = 300
        local dlgH = 240
        local dlgX = (logW - dlgW) / 2
        local dlgY = (logH - dlgH) / 2 - 20

        -- 背景
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, dlgX, dlgY, dlgW, dlgH, 8)
        nvgFillColor(ctx, nvgRGBA(20, 25, 35, 245))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(80, 150, 240, 200))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)

        -- 标题
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 13)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(80, 150, 240, 255))
        nvgText(ctx, dlgX + dlgW / 2, dlgY + 18, "导入地图种子代码")

        -- 输入框背景
        local inputX = dlgX + 20
        local inputY = dlgY + 34
        local inputW = dlgW - 40
        local inputH = 30
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, inputX, inputY, inputW, inputH, 4)
        nvgFillColor(ctx, nvgRGBA(10, 12, 20, 255))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(100, 160, 255, 180))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)

        -- 输入文本
        nvgFontSize(ctx, 16)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if #self.importInput > 0 then
            nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
            nvgText(ctx, inputX + inputW / 2, inputY + inputH / 2, self.importInput)
        else
            nvgFillColor(ctx, nvgRGBA(100, 100, 120, 150))
            nvgText(ctx, inputX + inputW / 2, inputY + inputH / 2, "输入13位数字代码...")
        end

        -- 闪烁光标
        local cursorBlink = math.floor(os.clock() * 2) % 2 == 0
        if cursorBlink and #self.importInput < 13 then
            local textW = 0
            if #self.importInput > 0 then
                nvgFontSize(ctx, 16)
                local bounds = {}
                textW = nvgTextBounds(ctx, 0, 0, self.importInput, bounds)
            end
            local cursorX = inputX + inputW / 2 + textW / 2 + 2
            nvgBeginPath(ctx)
            nvgRect(ctx, cursorX, inputY + 6, 1.5, inputH - 12)
            nvgFillColor(ctx, nvgRGBA(100, 180, 255, 200))
            nvgFill(ctx)
        end

        -- 字符计数
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        local countColor = (#self.importInput == 13) and nvgRGBA(80, 220, 120, 200) or nvgRGBA(170, 170, 170, 150)
        nvgFillColor(ctx, countColor)
        nvgText(ctx, inputX + inputW, inputY + inputH + 10, #self.importInput .. "/13")

        -- ===== 数字键盘 =====
        local numpadStartY = inputY + inputH + 20
        local keyW = 38
        local keyH = 28
        local keyGapX = 6
        local keyGapY = 5
        local numpadW = 5 * keyW + 4 * keyGapX  -- 5列
        local numpadX = dlgX + (dlgW - numpadW) / 2

        -- 数字键盘布局: [1][2][3][4][5] / [6][7][8][9][0] / [⌫ 删除][确认]
        local numKeys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
        self._numpadRects = {}

        for idx, key in ipairs(numKeys) do
            local row = math.floor((idx - 1) / 5)
            local col = (idx - 1) % 5
            local kx = numpadX + col * (keyW + keyGapX)
            local ky = numpadStartY + row * (keyH + keyGapY)

            -- 按键背景
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, kx, ky, keyW, keyH, 4)
            nvgFillColor(ctx, nvgRGBA(50, 55, 70, 220))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(100, 120, 160, 120))
            nvgStrokeWidth(ctx, 1)
            nvgStroke(ctx)

            -- 按键文字
            nvgFontSize(ctx, 14)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(255, 255, 255, 230))
            nvgText(ctx, kx + keyW / 2, ky + keyH / 2, key)

            self._numpadRects[idx] = { x = kx, y = ky, w = keyW, h = keyH, key = key }
        end

        -- 第三行: [⌫ 删除] 和 [确认]
        local row3Y = numpadStartY + 2 * (keyH + keyGapY)
        local delBtnW = 2 * keyW + keyGapX
        local delBtnX = numpadX

        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, delBtnX, row3Y, delBtnW, keyH, 4)
        nvgFillColor(ctx, nvgRGBA(120, 50, 50, 200))
        nvgFill(ctx)
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 230))
        nvgText(ctx, delBtnX + delBtnW / 2, row3Y + keyH / 2, "删除")

        self._numpadDeleteRect = { x = delBtnX, y = row3Y, w = delBtnW, h = keyH }

        -- 确认按钮
        local canConfirm = (#self.importInput == 13)
        local confirmBtnW = 2 * keyW + keyGapX
        local confirmBtnX = numpadX + 3 * (keyW + keyGapX)

        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, confirmBtnX, row3Y, confirmBtnW, keyH, 4)
        if canConfirm then
            nvgFillColor(ctx, nvgRGBA(40, 160, 80, 220))
        else
            nvgFillColor(ctx, nvgRGBA(50, 55, 65, 150))
        end
        nvgFill(ctx)
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, canConfirm and 240 or 80))
        nvgText(ctx, confirmBtnX + confirmBtnW / 2, row3Y + keyH / 2, "确认")

        self._importConfirmRect = { x = confirmBtnX, y = row3Y, w = confirmBtnW, h = keyH }

        -- 取消按钮(在标题右侧)
        local cancelBtnW = 40
        local cancelBtnH = 20
        local cancelBtnX = dlgX + dlgW - cancelBtnW - 10
        local cancelBtnY = dlgY + 8

        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cancelBtnX, cancelBtnY, cancelBtnW, cancelBtnH, 4)
        nvgFillColor(ctx, nvgRGBA(100, 40, 40, 180))
        nvgFill(ctx)
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 200))
        nvgText(ctx, cancelBtnX + cancelBtnW / 2, cancelBtnY + cancelBtnH / 2, "取消")

        self._importCancelRect = { x = cancelBtnX, y = cancelBtnY, w = cancelBtnW, h = cancelBtnH }
    end
end

-- ============================================================================
-- 顶部模式切换栏
-- ============================================================================

function LevelEditor:RenderInfoBar(logW, logH, dpr)
    local ctx = self.vg
    local barH = 28

    -- 顶部提示条(与IDE面板统一配色)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, logW, barH)
    nvgFillColor(ctx, nvgRGBA(50, 50, 51, 255))
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

    -- ===== 右上角: 导入/导出按钮 =====
    local btnW = 52
    local btnH = 20
    local btnGap = 6
    local btnY = (barH - btnH) / 2

    -- 导出按钮
    local exportX = logW - btnW - 8
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, exportX, btnY, btnW, btnH, 4)
    nvgFillColor(ctx, nvgRGBA(40, 160, 80, 200))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(80, 220, 120, 200))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgFontSize(ctx, 11)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 240))
    nvgText(ctx, exportX + btnW / 2, btnY + btnH / 2, "导出")

    -- 导入按钮
    local importX = exportX - btnW - btnGap
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, importX, btnY, btnW, btnH, 4)
    nvgFillColor(ctx, nvgRGBA(40, 100, 180, 200))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(80, 150, 240, 200))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
    nvgFontSize(ctx, 11)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 240))
    nvgText(ctx, importX + btnW / 2, btnY + btnH / 2, "导入")

    -- 保存按钮坐标用于点击检测
    self._importBtnRect = { x = importX, y = btnY, w = btnW, h = btnH }
    self._exportBtnRect = { x = exportX, y = btnY, w = btnW, h = btnH }
end

-- ============================================================================
-- 底部工具栏(以贴图缩略图显示可放置资产)
-- ============================================================================

function LevelEditor:RenderBottomToolbar(logW, logH, dpr)
    local ctx = self.vg
    local barY = logH - TOOLBAR_H
    self._lastLogH = logH  -- 缓存供滚轮判断使用

    -- 背景(与IDE面板统一配色)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, barY, logW, TOOLBAR_H)
    nvgFillColor(ctx, nvgRGBA(37, 37, 38, 255))
    nvgFill(ctx)

    -- 上边缘线
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, 0, barY)
    nvgLineTo(ctx, logW, barY)
    nvgStrokeColor(ctx, nvgRGBA(68, 68, 68, 255))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    nvgFontFace(ctx, "sans")

    -- 左侧模式切换Tab栏（竖排，80px宽）
    local tabAreaW = 80
    local tabH = 32
    local tabPad = 6
    local tabStartY = barY + 12
    for i = 1, 3 do
        local bx = 8
        local by = tabStartY + (i - 1) * (tabH + tabPad)
        local bw = tabAreaW - 16
        local bh = tabH
        local isActive = (self.mode == i)

        -- Tab背景
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, bx, by, bw, bh, 4)
        if isActive then
            nvgFillColor(ctx, nvgRGBA(14, 99, 156, 255))
        else
            nvgFillColor(ctx, nvgRGBA(60, 60, 65, 200))
        end
        nvgFill(ctx)

        -- Tab文字
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, isActive and 255 or 160))
        nvgText(ctx, bx + bw / 2, by + bh / 2, MODE_NAMES[i])
    end

    -- 左侧分隔线
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, tabAreaW, barY + 4)
    nvgLineTo(ctx, tabAreaW, logH - 4)
    nvgStrokeColor(ctx, nvgRGBA(68, 68, 68, 255))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 右侧内容区域(缩略图网格)
    local contentX = tabAreaW + 8
    local contentY = barY + 8
    local contentW = logW - contentX - 8
    local contentH = TOOLBAR_H - 16

    if self.mode == MODE_TERRAIN then
        self:RenderTerrainToolbar(ctx, contentX, contentY, contentW, contentH)
    elseif self.mode == MODE_OBJECT then
        self:RenderObjectToolbar(ctx, contentX, contentY, contentW, contentH)
    elseif self.mode == MODE_ZONE then
        self:RenderZoneToolbar(ctx, contentX, contentY, contentW, contentH)
    end

    -- 坐标显示（右下角）
    local pmx = input.mousePosition.x / dpr
    local pmy = input.mousePosition.y / dpr
    local wx, wy = self:ScreenToWorld(pmx, pmy, dpr)
    nvgFontSize(ctx, 10)
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(130, 130, 255, 200))
    nvgText(ctx, logW - 8, logH - 14, string.format("(%d, %d)", math.floor(wx), math.floor(wy)))
end

-- 地形工具栏: 左对齐大图标网格 + 滚动
function LevelEditor:RenderTerrainToolbar(ctx, contentX, contentY, contentW, contentH)
    local count = TERRAIN_BRUSH_COUNT
    local cellSize = 56
    local padX = 6
    local padY = 4
    local labelH = 14
    local cols = math.max(1, math.floor((contentW + padX) / (cellSize + padX)))
    local rows = math.ceil(count / cols)
    local totalH = rows * (cellSize + labelH + padY)

    -- 限制滚动范围
    local maxScroll = math.max(0, totalH - contentH)
    if self.paletteScrollY > maxScroll then self.paletteScrollY = maxScroll end

    -- 裁剪区域
    nvgSave(ctx)
    nvgScissor(ctx, contentX, contentY, contentW, contentH)

    local startX = contentX
    local startY = contentY - self.paletteScrollY

    for i = 1, count do
        local col = ((i - 1) % cols)
        local row = math.floor((i - 1) / cols)
        local cx = startX + col * (cellSize + padX)
        local cellY = startY + row * (cellSize + labelH + padY)

        -- 跳过不可见行
        if cellY + cellSize + labelH < contentY then goto continue end
        if cellY > contentY + contentH then goto continue end

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
            local pat = nvgImagePattern(ctx, cx, cellY, cellSize, cellSize, 0, self.terrainIcons[i], isSelected and 1.0 or 0.75)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cx, cellY, cellSize, cellSize, 3)
            nvgFillPaint(ctx, pat)
            nvgFill(ctx)
        else
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
        nvgFontSize(ctx, 9)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, isSelected and 255 or 150))
        nvgText(ctx, cx + cellSize / 2, cellY + cellSize + 2, EDITOR_BRUSH_NAMES[i])

        ::continue::
    end

    nvgRestore(ctx)

    -- 滚动条（内容超出时显示）
    if maxScroll > 0 then
        local scrollBarX = contentX + contentW - 6
        local scrollBarH = contentH * (contentH / totalH)
        local scrollBarY = contentY + (self.paletteScrollY / maxScroll) * (contentH - scrollBarH)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, scrollBarX, scrollBarY, 4, scrollBarH, 2)
        nvgFillColor(ctx, nvgRGBA(150, 150, 150, 120))
        nvgFill(ctx)
    end
end

-- 物件工具栏: 左对齐大图标网格 + 滚动
function LevelEditor:RenderObjectToolbar(ctx, contentX, contentY, contentW, contentH)
    local count = OBJ_ASSET_COUNT
    local cellSize = 56
    local padX = 6
    local padY = 4
    local labelH = 14
    local cols = math.max(1, math.floor((contentW + padX) / (cellSize + padX)))
    local rows = math.ceil(count / cols)
    local totalH = rows * (cellSize + labelH + padY)

    -- 限制滚动范围
    local maxScroll = math.max(0, totalH - contentH)
    if self.paletteScrollY > maxScroll then self.paletteScrollY = maxScroll end

    -- 裁剪区域
    nvgSave(ctx)
    nvgScissor(ctx, contentX, contentY, contentW, contentH)

    local startX = contentX
    local startY = contentY - self.paletteScrollY

    for i = 1, count do
        local col = ((i - 1) % cols)
        local row = math.floor((i - 1) / cols)
        local cx = startX + col * (cellSize + padX)
        local cellY = startY + row * (cellSize + labelH + padY)

        -- 跳过不可见行
        if cellY + cellSize + labelH < contentY then goto continue end
        if cellY > contentY + contentH then goto continue end

        local isSelected = (self.objAssetIdx == i)

        -- 选中边框
        if isSelected then
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cx - 2, cellY - 2, cellSize + 4, cellSize + 4, 5)
            nvgStrokeColor(ctx, nvgRGBA(60, 200, 255, 255))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        end

        -- 背景
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx, cellY, cellSize, cellSize, 4)
        nvgFillColor(ctx, nvgRGBA(30, 35, 40, 220))
        nvgFill(ctx)

        -- 贴图缩略图
        if self.objectIcons[i] then
            local pat = nvgImagePattern(ctx, cx + 2, cellY + 2, cellSize - 4, cellSize - 4, 0, self.objectIcons[i], isSelected and 1.0 or 0.75)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cx + 2, cellY + 2, cellSize - 4, cellSize - 4, 3)
            nvgFillPaint(ctx, pat)
            nvgFill(ctx)
        end

        -- 边框
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx, cellY, cellSize, cellSize, 4)
        nvgStrokeColor(ctx, nvgRGBA(80, 80, 100, isSelected and 200 or 80))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)

        -- 名称标签
        nvgFontSize(ctx, 9)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, isSelected and 255 or 150))
        nvgText(ctx, cx + cellSize / 2, cellY + cellSize + 2, OBJ_ASSETS[i].name)

        ::continue::
    end

    nvgRestore(ctx)

    -- 滚动条（内容超出时显示）
    if maxScroll > 0 then
        local scrollBarX = contentX + contentW - 6
        local scrollBarH = contentH * (contentH / totalH)
        local scrollBarY = contentY + (self.paletteScrollY / maxScroll) * (contentH - scrollBarH)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, scrollBarX, scrollBarY, 4, scrollBarH, 2)
        nvgFillColor(ctx, nvgRGBA(150, 150, 150, 120))
        nvgFill(ctx)
    end
end

-- 区域工具栏: 舒适区类型/毒圈/出生点
function LevelEditor:RenderZoneToolbar(ctx, contentX, contentY, contentW, contentH)
    local cellSize = 56
    local padX = 6
    local padY = 4
    local labelH = 14
    local items = {
        { name = "篝火", type = "comfort", sub = 1, r = 255, g = 120, b = 30 },
        { name = "清泉", type = "comfort", sub = 2, r = 80, g = 180, b = 255 },
        { name = "圣坛", type = "comfort", sub = 3, r = 180, g = 100, b = 255 },
        { name = "毒圈", type = "circle", sub = 0, r = 255, g = 50, b = 50 },
        { name = "出生点", type = "spawn", sub = 0, r = 50, g = 150, b = 255 },
    }
    local count = #items
    local cols = math.max(1, math.floor((contentW + padX) / (cellSize + padX)))
    local rows = math.ceil(count / cols)
    local totalH = rows * (cellSize + labelH + padY)

    -- 滚动限制
    local maxScroll = math.max(0, totalH - contentH)
    if self.paletteScrollY > maxScroll then self.paletteScrollY = maxScroll end

    nvgSave(ctx)
    nvgScissor(ctx, contentX, contentY, contentW, contentH)

    for idx, item in ipairs(items) do
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local cx = contentX + col * (cellSize + padX)
        local cy = contentY + row * (cellSize + labelH + padY) - self.paletteScrollY

        -- 跳过不可见
        if cy + cellSize + labelH < contentY or cy > contentY + contentH then
            goto continue_zone
        end

        local isSelected = false
        if item.type == "comfort" then
            isSelected = (self.zoneType == ZONE_COMFORT and self.comfortType == item.sub)
        elseif item.type == "circle" then
            isSelected = (self.zoneType == ZONE_CIRCLE)
        elseif item.type == "spawn" then
            isSelected = (self.zoneType == ZONE_SPAWN)
        end

        -- 选中框
        if isSelected then
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cx - 3, cy - 3, cellSize + 6, cellSize + 6, 6)
            nvgStrokeColor(ctx, nvgRGBA(14, 99, 156, 255))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        end

        -- 色块背景
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx, cy, cellSize, cellSize, 4)
        nvgFillColor(ctx, nvgRGBA(50, 50, 51, 255))
        nvgFill(ctx)

        -- 图标(圆形)
        nvgBeginPath(ctx)
        nvgCircle(ctx, cx + cellSize / 2, cy + cellSize * 0.42, cellSize * 0.25)
        nvgFillColor(ctx, nvgRGBA(item.r, item.g, item.b, 220))
        nvgFill(ctx)

        -- 边框
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, cx, cy, cellSize, cellSize, 4)
        nvgStrokeColor(ctx, nvgRGBA(68, 68, 68, isSelected and 200 or 100))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)

        -- 名称
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, isSelected and 255 or 160))
        nvgText(ctx, cx + cellSize / 2, cy + cellSize + 2, item.name)

        ::continue_zone::
    end

    nvgRestore(ctx)

    -- 当前信息（显示在内容区右侧）
    local infoX = contentX + math.min(count, cols) * (cellSize + padX) + 12
    local infoY = contentY + contentH / 2
    if infoX < contentX + contentW - 60 then
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(170, 170, 170, 200))
        if self.zoneType == ZONE_CIRCLE then
            nvgText(ctx, infoX, infoY, string.format("毒圈半径: %.0f", self.gameCircle.radius))
        elseif self.zoneType == ZONE_SPAWN then
            nvgText(ctx, infoX, infoY, string.format("出生半径: %.0f", self.spawnConfig.radius))
        else
            local zones = self:GetComfortZones()
            local zoneCount = zones and #zones or 0
            nvgText(ctx, infoX, infoY, "舒适区数量: " .. zoneCount)
        end
    end

    -- 滚动条
    if maxScroll > 0 then
        local scrollBarH = math.max(20, contentH * (contentH / totalH))
        local scrollBarY = contentY + (self.paletteScrollY / maxScroll) * (contentH - scrollBarH)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, contentX + contentW - 6, scrollBarY, 4, scrollBarH, 2)
        nvgFillColor(ctx, nvgRGBA(120, 120, 120, 150))
        nvgFill(ctx)
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
    -- 世界坐标减去原点偏移后转为瓦片索引
    local tx = math.floor((worldX - self.mapOriginX) / self.tilePixel) + 1
    local ty = math.floor((worldY - self.mapOriginY) / self.tilePixel) + 1
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
    local tx = math.floor((worldX - self.mapOriginX) / self.tilePixel) + 1
    local ty = math.floor((worldY - self.mapOriginY) / self.tilePixel) + 1
    return self.tileMap:GetTile(tx, ty)
end

-- ============================================================================
-- 种子编码/解码 (13位数字代码)
-- 编码方案:
--   seed(32bit时间戳) + regionCount(5bit) + transWidth(3bit) + jitter(3bit)
--   总共 43 bits → 编码为 13 位十进制数 (10^13 = 约43.25 bits)
-- ============================================================================

--- 将地图生成参数编码为13位种子代码
---@param seed number 随机种子(时间戳)
---@param regionCount number 区块数量(1-31)
---@param transWidth number 过渡带宽度(1-7, 实际值*2)
---@param jitter number 扰动(0-7, 实际值*10)
---@return string 13位种子代码
function LevelEditor:EncodeSeed(seed, regionCount, transWidth, jitter)
    -- 将参数约束到合法范围
    seed = math.floor(seed) % (2^32)  -- 32位
    regionCount = math.max(1, math.min(31, math.floor(regionCount)))  -- 5位 (0-31)
    local tw = math.max(1, math.min(7, math.floor(transWidth * 2)))   -- 3位 (1-7)
    local jt = math.max(0, math.min(7, math.floor(jitter * 10)))      -- 3位 (0-7)

    -- 组合: seed(32) | regionCount(5) | tw(3) | jt(3) = 43 bits
    -- 用大整数运算 (Lua 5.4 支持 64位整数)
    local combined = seed * (32 * 8 * 8)  -- seed << 11
                   + regionCount * (8 * 8) -- regionCount << 6
                   + tw * 8                -- tw << 3
                   + jt                    -- jt

    -- 转为13位十进制字符串(不足13位前面补0)
    local code = string.format("%013d", combined % (10^13))
    return code
end

--- 从13位种子代码解码地图生成参数
---@param code string 13位种子代码
---@return number|nil seed, number regionCount, number transWidth, number jitter
function LevelEditor:DecodeSeed(code)
    -- 去除空格
    code = code:gsub("%s", "")

    -- 验证格式: 必须是13位数字
    if #code ~= 13 or not code:match("^%d+$") then
        return nil
    end

    local combined = tonumber(code)
    if not combined then return nil end

    -- 解码各字段
    local jt = combined % 8
    combined = math.floor(combined / 8)
    local tw = combined % 8
    combined = math.floor(combined / 8)
    local regionCount = combined % 32
    combined = math.floor(combined / 32)
    local seed = combined

    -- 还原实际参数值
    local transWidth = tw / 2
    local jitter = jt / 10

    -- 基本校验
    if regionCount < 1 then regionCount = 18 end
    if transWidth < 0.5 then transWidth = 2.5 end
    if jitter < 0.1 then jitter = 0.7 end

    return seed, regionCount, transWidth, jitter
end

--- 导出当前地图为种子代码
function LevelEditor:ExportSeedCode()
    local seed = self.lastGenerateSeed
    if seed == 0 then
        seed = os.time()
    end
    local code = self:EncodeSeed(seed, 18, 2.5, 0.7)
    self.seedCode = code
    self.showExportDialog = true
    self.exportMessage = code
    self.dialogTimer = 5.0  -- 5秒后自动关闭
    print("[编辑器] 导出种子代码: " .. code)
    return code
end

--- 从种子代码导入并重新生成地图
---@param code string 13位种子代码
---@return boolean 是否成功
function LevelEditor:ImportSeedCode(code)
    local seed, regionCount, transWidth, jitter = self:DecodeSeed(code)
    if not seed then
        print("[编辑器] 无效种子代码: " .. tostring(code))
        return false
    end

    -- 使用解码的参数重新生成地形
    self.lastGenerateSeed = seed
    local T = self.tileMap.TERRAIN
    self.tileMap:GenerateWithBiomes(seed, {
        [T.GRASS] = 5, [T.MUD] = 2, [T.SWAMP] = 2,
        [T.FOREST] = 2, [T.SAND] = 1, [T.SNOW] = 1,
    }, {
        regionCount = regionCount,
        transitionWidth = transWidth,
        jitter = jitter,
    })
    self.terrainExported = true
    self.seedCode = code

    -- 重新生成装饰物(只含地形物件: 树木/岩石/花朵/植物)
    if RegenerateMapDecorations then
        RegenerateMapDecorations()
    end

    print("[编辑器] 导入种子代码: " .. code .. " → seed=" .. seed .. " regions=" .. regionCount)
    return true
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
