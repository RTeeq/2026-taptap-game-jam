-- ============================================
-- 饥荒风格地形系统 - 综合使用示例
-- 整合：贴图生成 + 法线贴图 + 季节切换 + 天气效果 + 植被覆盖
-- ============================================

local TextureGenerator = require("DSTTextureGenerator_Extended")
local NormalMapGenerator = require("NormalMapGenerator")
local SeasonShifter = require("SeasonShifter")
local WeatherEffects = require("WeatherEffects")
local VegetationGenerator = require("VegetationGenerator")

-- ============================================
-- 场景配置
-- ============================================
local CONFIG = {
    TILE_SIZE = 256,
    MAP_WIDTH = 32,
    MAP_HEIGHT = 32,
    SEED = 12345,
    SEASON = "spring",      -- spring/summer/autumn/winter
    WEATHER = "clear",      -- clear/rain/snow/fog/night
    WEATHER_INTENSITY = 0.5,
    ENABLE_NORMAL_MAP = true,
    ENABLE_VEGETATION = true,
    VEGETATION_DENSITY = 0.3,
    FLOWER_DENSITY = 0.1,
}

-- ============================================
-- 地形材质管理器
-- ============================================
local TerrainMaterialManager = {}
TerrainMaterialManager.materials = {}

function TerrainMaterialManager.generateMaterials()
    print("=== 生成地形材质 ===")

    -- 1. 生成基础贴图
    local textures = TextureGenerator.generateTileMapTextures(CONFIG.TILE_SIZE, CONFIG.SEED)

    -- 2. 应用季节色调
    if CONFIG.SEASON ~= "spring" then
        print("  应用季节色调: " .. CONFIG.SEASON)
        for terrainType, pixels in pairs(textures) do
            textures[terrainType] = SeasonShifter.apply(
                pixels, CONFIG.TILE_SIZE, CONFIG.TILE_SIZE, CONFIG.SEASON
            )
        end
    end

    -- 3. 应用天气效果
    if CONFIG.WEATHER ~= "clear" then
        print("  应用天气效果: " .. CONFIG.WEATHER)
        for terrainType, pixels in pairs(textures) do
            textures[terrainType] = WeatherEffects.apply(
                pixels, CONFIG.TILE_SIZE, CONFIG.TILE_SIZE, CONFIG.WEATHER, CONFIG.WEATHER_INTENSITY
            )
        end
    end

    -- 4. 添加植被覆盖（仅草地）
    if CONFIG.ENABLE_VEGETATION and textures.grass then
        print("  添加植被覆盖")
        textures.grass = VegetationGenerator.generateVegetatedGrass(
            CONFIG.TILE_SIZE, CONFIG.TILE_SIZE, CONFIG.SEED,
            CONFIG.VEGETATION_DENSITY, CONFIG.FLOWER_DENSITY
        )
    end

    -- 5. 创建材质
    for terrainType, pixels in pairs(textures) do
        local material = Material()

        -- 基础贴图
        local diffuseTexture = TextureGenerator.createTexture2D(pixels, CONFIG.TILE_SIZE, CONFIG.TILE_SIZE)
        material:SetTexture(TextureUnit.DIFFUSE, diffuseTexture)

        -- 法线贴图
        if CONFIG.ENABLE_NORMAL_MAP then
            local normalPixels = NormalMapGenerator.generate(terrainType, CONFIG.TILE_SIZE, CONFIG.TILE_SIZE, CONFIG.SEED, 2.0)
            local normalTexture = NormalMapGenerator.createNormalTexture(normalPixels, CONFIG.TILE_SIZE, CONFIG.TILE_SIZE)
            material:SetTexture(TextureUnit.NORMAL, normalTexture)
        end

        material:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffNormal.xml"))

        TerrainMaterialManager.materials[terrainType] = material
        print("  ✓ 材质生成完成: " .. terrainType)
    end

    print("=== 材质生成完成 ===")
end

-- ============================================
-- 动态天气系统
-- ============================================
local WeatherSystem = {}
WeatherSystem.currentWeather = "clear"
WeatherSystem.targetWeather = "clear"
WeatherSystem.transitionTime = 0
WeatherSystem.transitionDuration = 5.0  -- 5秒过渡

function WeatherSystem.setWeather(weatherType, intensity)
    if WeatherSystem.currentWeather ~= weatherType then
        WeatherSystem.targetWeather = weatherType
        WeatherSystem.transitionTime = 0
        print("天气切换: " .. WeatherSystem.currentWeather .. " -> " .. weatherType)
    end
end

function WeatherSystem.update(timeStep)
    if WeatherSystem.currentWeather ~= WeatherSystem.targetWeather then
        WeatherSystem.transitionTime = WeatherSystem.transitionTime + timeStep
        local t = math.min(1, WeatherSystem.transitionTime / WeatherSystem.transitionDuration)

        if t >= 1 then
            WeatherSystem.currentWeather = WeatherSystem.targetWeather
            -- 重新生成材质
            CONFIG.WEATHER = WeatherSystem.currentWeather
            TerrainMaterialManager.generateMaterials()
        end
    end
end

-- ============================================
-- 季节系统
-- ============================================
local SeasonSystem = {}
SeasonSystem.currentDay = 1
SeasonSystem.daysPerSeason = 18  -- 每季节18天

function SeasonSystem.updateDay(day)
    SeasonSystem.currentDay = day
    local season, progress = SeasonShifter.getSeasonByDay(day)

    if CONFIG.SEASON ~= season then
        CONFIG.SEASON = season
        print("季节变更: " .. season .. " (第" .. day .. "天)")
        TerrainMaterialManager.generateMaterials()
    end
end

-- ============================================
-- 主场景
-- ============================================
function Start()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 生成材质
    TerrainMaterialManager.generateMaterials()

    -- 创建地图
    CreateTileMap()

    -- 创建相机
    CreateCamera()

    -- 创建UI
    CreateUI()

    print("饥荒风格地形系统初始化完成！")
end

function CreateTileMap()
    local tileMapData = TextureGenerator.generateTileMapData(CONFIG.MAP_WIDTH, CONFIG.MAP_HEIGHT, CONFIG.SEED)
    local tileMapNode = scene_:CreateChild("TileMap")

    for y = 1, CONFIG.MAP_HEIGHT do
        for x = 1, CONFIG.MAP_WIDTH do
            local terrainType = tileMapData[y][x]
            local material = TerrainMaterialManager.materials[terrainType]

            if material then
                local tileNode = tileMapNode:CreateChild(string.format("Tile_%d_%d", x, y))
                tileNode.position = Vector3((x - 1) * CONFIG.TILE_SIZE, (y - 1) * CONFIG.TILE_SIZE, 0)

                local sprite = tileNode:CreateComponent("StaticSprite2D")
                sprite:SetMaterial(material)
                sprite:SetSprite(cache:GetResource("Sprite2D", "Sprites/White.xml"))
                sprite:SetDrawRect(Rect(0, 0, CONFIG.TILE_SIZE, CONFIG.TILE_SIZE))
            end
        end
    end
end

function CreateCamera()
    local cameraNode = scene_:CreateChild("Camera")
    cameraNode.position = Vector3(
        CONFIG.MAP_WIDTH * CONFIG.TILE_SIZE / 2,
        CONFIG.MAP_HEIGHT * CONFIG.TILE_SIZE / 2,
        -10
    )

    local camera = cameraNode:CreateComponent("Camera")
    camera.orthographic = true
    camera.orthoSize = CONFIG.MAP_HEIGHT * CONFIG.TILE_SIZE / 1.5

    local viewport = Viewport(scene_, camera)
    renderer:SetViewport(0, viewport)
    renderer.defaultZone.fogColor = Color(0.1, 0.1, 0.12)
end

function CreateUI()
    local uiRoot = ui.root

    -- 标题
    local title = uiRoot:CreateChild("Text")
    title:SetText("饥荒风格地形系统 v1.1")
    title:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 24)
    title:SetColor(Color(0.9, 0.9, 0.9))
    title:SetAlignment(HA_CENTER, VA_TOP)
    title:SetPosition(0, 20)

    -- 状态信息
    local status = uiRoot:CreateChild("Text")
    status:SetText(string.format(
        "季节: %s | 天气: %s | 第%d天",
        CONFIG.SEASON, CONFIG.WEATHER, SeasonSystem.currentDay
    ))
    status:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 14)
    status:SetColor(Color(0.7, 0.7, 0.7))
    status:SetAlignment(HA_CENTER, VA_TOP)
    status:SetPosition(0, 50)

    -- 操作提示
    local hints = uiRoot:CreateChild("Text")
    hints:SetText(
        "1-4: 切换季节 | Q/W/E/R: 切换天气 | +/-: 调整天气强度 | N: 切换法线贴图 | V: 切换植被"
    )
    hints:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 12)
    hints:SetColor(Color(0.5, 0.5, 0.5))
    hints:SetAlignment(HA_CENTER, VA_BOTTOM)
    hints:SetPosition(0, -20)
end

-- ============================================
-- 输入处理
-- ============================================
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()

    -- 更新天气过渡
    WeatherSystem.update(timeStep)

    -- 季节切换
    if input:GetKeyPress(KEY_1) then SeasonSystem.updateDay(1) end   -- 春
    if input:GetKeyPress(KEY_2) then SeasonSystem.updateDay(19) end  -- 夏
    if input:GetKeyPress(KEY_3) then SeasonSystem.updateDay(37) end  -- 秋
    if input:GetKeyPress(KEY_4) then SeasonSystem.updateDay(55) end  -- 冬

    -- 天气切换
    if input:GetKeyPress(KEY_Q) then WeatherSystem.setWeather("clear", 0) end
    if input:GetKeyPress(KEY_W) then WeatherSystem.setWeather("rain", 0.6) end
    if input:GetKeyPress(KEY_E) then WeatherSystem.setWeather("snow", 0.7) end
    if input:GetKeyPress(KEY_R) then WeatherSystem.setWeather("fog", 0.5) end
    if input:GetKeyPress(KEY_T) then WeatherSystem.setWeather("night", 0.8) end

    -- 调整天气强度
    if input:GetKeyPress(KEY_KP_PLUS) or input:GetKeyPress(KEY_EQUALS) then
        CONFIG.WEATHER_INTENSITY = math.min(1.0, CONFIG.WEATHER_INTENSITY + 0.1)
        TerrainMaterialManager.generateMaterials()
    end
    if input:GetKeyPress(KEY_KP_MINUS) or input:GetKeyPress(KEY_MINUS) then
        CONFIG.WEATHER_INTENSITY = math.max(0.0, CONFIG.WEATHER_INTENSITY - 0.1)
        TerrainMaterialManager.generateMaterials()
    end

    -- 切换法线贴图
    if input:GetKeyPress(KEY_N) then
        CONFIG.ENABLE_NORMAL_MAP = not CONFIG.ENABLE_NORMAL_MAP
        TerrainMaterialManager.generateMaterials()
        print("法线贴图: " .. (CONFIG.ENABLE_NORMAL_MAP and "开启" or "关闭"))
    end

    -- 切换植被
    if input:GetKeyPress(KEY_V) then
        CONFIG.ENABLE_VEGETATION = not CONFIG.ENABLE_VEGETATION
        TerrainMaterialManager.generateMaterials()
        print("植被覆盖: " .. (CONFIG.ENABLE_VEGETATION and "开启" or "关闭"))
    end
end

function Setup()
    SubscribeToEvent("Update", "HandleUpdate")
end

Start()
Setup()
