-- ============================================
-- 饥荒风格程序化地形 - 完整项目示例
-- TapTap 制造 / UrhoX 引擎
-- ============================================

-- 引入贴图生成器（扩展版）
local TextureGenerator = require("DSTTextureGenerator_Extended")

-- 全局配置
local CONFIG = {
    TILE_SIZE = 256,           -- 瓦片尺寸
    MAP_WIDTH = 32,            -- 地图宽度（瓦片数）
    MAP_HEIGHT = 32,           -- 地图高度（瓦片数）
    SEED = 12345,              -- 随机种子
    STYLE_INTENSITY = 0.7,     -- 风格强度
    CAMERA_ZOOM = 1.5,         -- 相机缩放
}

-- 地形资源表
local terrainResources = {}
local tileMapData = {}

-- ============================================
-- 场景初始化
-- ============================================
function Start()
    -- 初始化随机种子
    math.randomseed(os.time())

    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 创建相机
    CreateCamera()

    -- 生成地形贴图资源
    GenerateTerrainResources()

    -- 创建瓦片地图
    CreateTileMap()

    -- 创建UI（显示地图信息）
    CreateUI()

    print("饥荒风格地形场景初始化完成！")
    print(string.format("地图大小: %d x %d 瓦片", CONFIG.MAP_WIDTH, CONFIG.MAP_HEIGHT))
    print(string.format("瓦片尺寸: %d x %d 像素", CONFIG.TILE_SIZE, CONFIG.TILE_SIZE))
end

-- ============================================
-- 创建相机
-- ============================================
function CreateCamera()
    local cameraNode = scene_:CreateChild("Camera")
    cameraNode.position = Vector3(CONFIG.MAP_WIDTH * CONFIG.TILE_SIZE / 2, 
                                   CONFIG.MAP_HEIGHT * CONFIG.TILE_SIZE / 2, 
                                   -10)

    local camera = cameraNode:CreateComponent("Camera")
    camera.orthographic = true
    camera.orthoSize = CONFIG.MAP_HEIGHT * CONFIG.TILE_SIZE / CONFIG.CAMERA_ZOOM

    -- 添加相机控制器脚本
    cameraNode:CreateScriptObject("CameraController")

    -- 创建视口
    local viewport = Viewport(scene_, camera)
    renderer:SetViewport(0, viewport)

    -- 设置背景色（饥荒风格暗色）
    renderer.defaultZone.fogColor = Color(0.1, 0.1, 0.12)
end

-- ============================================
-- 生成地形资源
-- ============================================
function GenerateTerrainResources()
    print("正在生成地形贴图...")

    -- 启用缓存以提高性能
    TextureGenerator.setCacheEnabled(true)

    -- 生成所有地形贴图
    local textures = TextureGenerator.generateTileMapTextures(CONFIG.TILE_SIZE, CONFIG.SEED)

    -- 为每种地形创建 Texture2D 和 Material
    for terrainType, pixels in pairs(textures) do
        -- 创建 Texture2D
        local texture2D = TextureGenerator.createTexture2D(pixels, CONFIG.TILE_SIZE, CONFIG.TILE_SIZE)
        texture2D:SetFilterMode(FILTER_BILINEAR)

        -- 创建 Material
        local material = Material()
        material:SetTexture(TextureUnit.DIFFUSE, texture2D)
        material:SetTechnique(0, cache:GetResource("Technique", "Techniques/Diff.xml"))

        terrainResources[terrainType] = {
            texture = texture2D,
            material = material
        }

        print(string.format("  ✓ 已生成: %s", terrainType))
    end

    -- 生成瓦片地图数据
    tileMapData = TextureGenerator.generateTileMapData(CONFIG.MAP_WIDTH, CONFIG.MAP_HEIGHT, CONFIG.SEED)

    print("地形资源生成完成！")
end

-- ============================================
-- 创建瓦片地图
-- ============================================
function CreateTileMap()
    print("正在创建瓦片地图...")

    local tileMapNode = scene_:CreateChild("TileMap")
    tileMapNode.position = Vector3(0, 0, 0)

    -- 使用 StaticSprite2D 批量创建瓦片（性能优化）
    for y = 1, CONFIG.MAP_HEIGHT do
        for x = 1, CONFIG.MAP_WIDTH do
            local terrainType = tileMapData[y][x]
            local resource = terrainResources[terrainType]

            if resource then
                local tileNode = tileMapNode:CreateChild(string.format("Tile_%d_%d", x, y))
                tileNode.position = Vector3((x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE, 0)

                local sprite = tileNode:CreateComponent("StaticSprite2D")
                sprite:SetMaterial(resource.material)
                sprite:SetSprite(cache:GetResource("Sprite2D", "Sprites/White.xml"))
                sprite:SetDrawRect(Rect(0, 0, CONFIG.TILE_SIZE, CONFIG.TILE_SIZE))
                sprite:SetUseHotSpot(false)
            end
        end
    end

    print("瓦片地图创建完成！")
end

-- ============================================
-- 创建UI
-- ============================================
function CreateUI()
    local uiRoot = ui.root

    -- 标题文本
    local titleText = uiRoot:CreateChild("Text")
    titleText:SetText("饥荒风格程序化地形")
    titleText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 24)
    titleText:SetColor(Color(0.9, 0.9, 0.9))
    titleText:SetAlignment(HA_CENTER, VA_TOP)
    titleText:SetPosition(0, 20)

    -- 信息面板
    local infoText = uiRoot:CreateChild("Text")
    infoText:SetText(string.format(
        "地图: %dx%d | 瓦片: %dx%d | 种子: %d | 风格: %.1f",
        CONFIG.MAP_WIDTH, CONFIG.MAP_HEIGHT,
        CONFIG.TILE_SIZE, CONFIG.TILE_SIZE,
        CONFIG.SEED, CONFIG.STYLE_INTENSITY
    ))
    infoText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 14)
    infoText:SetColor(Color(0.7, 0.7, 0.7))
    infoText:SetAlignment(HA_CENTER, VA_TOP)
    infoText:SetPosition(0, 50)

    -- 操作提示
    local hintText = uiRoot:CreateChild("Text")
    hintText:SetText("WASD/方向键: 移动相机 | 鼠标滚轮: 缩放 | R: 重新生成地图")
    hintText:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 12)
    hintText:SetColor(Color(0.5, 0.5, 0.5))
    hintText:SetAlignment(HA_CENTER, VA_BOTTOM)
    hintText:SetPosition(0, -20)
end

-- ============================================
-- 相机控制器
-- ============================================
CameraController = ScriptObject()

function CameraController:Start()
    self.moveSpeed = 500
    self.zoomSpeed = 0.1
    self.minZoom = 0.5
    self.maxZoom = 3.0
    self.currentZoom = 1.0
end

function CameraController:Update(timeStep)
    local camera = self.node:GetComponent("Camera")
    local pos = self.node.position

    -- 键盘移动
    if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then
        pos.y = pos.y + self.moveSpeed * timeStep
    end
    if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then
        pos.y = pos.y - self.moveSpeed * timeStep
    end
    if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then
        pos.x = pos.x - self.moveSpeed * timeStep
    end
    if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then
        pos.x = pos.x + self.moveSpeed * timeStep
    end

    -- 鼠标滚轮缩放
    local wheel = input:GetMouseMoveWheel()
    if wheel ~= 0 then
        self.currentZoom = self.currentZoom + wheel * self.zoomSpeed
        self.currentZoom = math.max(self.minZoom, math.min(self.maxZoom, self.currentZoom))
        camera.orthoSize = CONFIG.MAP_HEIGHT * CONFIG.TILE_SIZE / (CONFIG.CAMERA_ZOOM * self.currentZoom)
    end

    self.node.position = pos
end

-- ============================================
-- 输入处理
-- ============================================
function HandleUpdate(eventType, eventData)
    -- 按 R 键重新生成地图
    if input:GetKeyPress(KEY_R) then
        print("重新生成地图...")
        CONFIG.SEED = os.time()

        -- 清除旧地图
        local oldTileMap = scene_:GetChild("TileMap")
        if oldTileMap then
            oldTileMap:Remove()
        end

        -- 重新生成
        GenerateTerrainResources()
        CreateTileMap()

        -- 更新UI
        local infoText = ui.root:GetChild("Text", true)
        if infoText then
            infoText:SetText(string.format(
                "地图: %dx%d | 瓦片: %dx%d | 种子: %d | 风格: %.1f",
                CONFIG.MAP_WIDTH, CONFIG.MAP_HEIGHT,
                CONFIG.TILE_SIZE, CONFIG.TILE_SIZE,
                CONFIG.SEED, CONFIG.STYLE_INTENSITY
            ))
        end

        print("地图重新生成完成！")
    end
end

-- ============================================
-- 注册事件
-- ============================================
function Setup()
    SubscribeToEvent("Update", "HandleUpdate")
end

-- ============================================
-- 入口点
-- ============================================
Start()
Setup()
