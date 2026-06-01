---
name: dst-procedural-texture-generator
description: |
  饥荒风格（Don't Starve）程序化地形贴图生成器。
  触发条件：当用户需要生成饥荒风格的地形贴图、程序化纹理、草地/沼泽/泥地/碎石地/雪地/沙漠/火山岩贴图时自动触发。
  Use when: (1) 需要生成饥荒风格的手绘卡通地形贴图, (2) 需要程序化生成2D瓦片贴图, (3) 需要草地/沼泽/泥地/碎石地/雪地/沙漠/火山岩纹理。
  MUST trigger when: 用户提到"饥荒风格"、"Don't Starve风格"、"程序化地形贴图"、"草地贴图"、"沼泽贴图"、"泥地贴图"、"碎石地贴图"、"雪地贴图"、"沙漠贴图"、"火山岩贴图"。
---

# 饥荒风格程序化地形贴图生成器

> 编号: S-DST-001
> 版本: 1.1.0
> 类型: tool
> 作者: AI Assistant

## 触发条件

- 用户请求生成饥荒（Don't Starve）风格的地形贴图
- 用户需要程序化生成草地、沼泽、泥地、碎石地、雪地、沙漠、火山岩等贴图
- 用户提到"手绘卡通风格"、"哥特式卡通"、"暗黑卡通"等地形纹理需求
- 用户需要2D瓦片地图的地表贴图生成
- 用户需要地形混合过渡效果
- 用户需要瓦片地图（TileMap）集成方案

## 风格规范

### 饥荒风格视觉特征

饥荒（Don't Starve）的地形贴图具有以下核心视觉特征：

1. **手绘卡通风格**：边缘带有不规则的手绘笔触感，非完美几何形状
2. **暗黑哥特色调**：整体偏暗、饱和度适中偏低，带有诡异荒野氛围
3. **纹理粗糙感**：表面有明显的颗粒噪点，模拟手绘纸张质感
4. **不规则边缘**：地块边界不是直线，而是波浪状、撕裂状的自然过渡
5. **细节点缀**：草地有零星杂草、碎石地有散落石块、沼泽有气泡和枯枝
6. **色彩特征**：
   - 草地：深绿到黄绿渐变，带有枯黄斑块
   - 沼泽：深褐到暗绿，带有紫灰色调
   - 泥地：棕褐色系，带有湿润反光感
   - 碎石地：灰白到浅褐，碎石随机分布
   - 雪地：白灰基调，冰晶反光，雪地凹陷
   - 沙漠：暖黄沙土，风蚀纹理，沙丘明暗
   - 火山岩：深黑到暗红，熔岩裂缝发光，灰烬

## 执行步骤

### 第一步：确定贴图类型和参数

根据用户需求选择贴图类型，确认以下参数：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `texture_type` | 贴图类型：grass/swamp/mud/rocky/snow/desert/volcanic | grass |
| `width` | 贴图宽度（像素） | 256 |
| `height` | 贴图高度（像素） | 256 |
| `seed` | 随机种子 | os.time() |
| `style_intensity` | 风格强度(0.0-1.0) | 0.7 |
| `tileable` | 是否无缝平铺 | true |

### 第二步：调用程序化生成函数

使用以下Lua函数生成贴图数据：

```lua
-- ============================================
-- 饥荒风格程序化地形贴图生成器
-- ============================================

local TextureGenerator = {}

-- 基础噪声函数（Value Noise）
local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function hash(x, y, s)
    local h = s + x * 374761393 + y * 668265263
    h = (h ~ (h >> 13)) * 1274126177
    return (h % 1000) / 1000
end

function TextureGenerator.valueNoise2D(x, y, s)
    local ix, iy = math.floor(x), math.floor(y)
    local fx, fy = x - ix, y - iy
    local v00 = hash(ix, iy, s)
    local v10 = hash(ix + 1, iy, s)
    local v01 = hash(ix, iy + 1, s)
    local v11 = hash(ix + 1, iy + 1, s)
    return lerp(
        lerp(v00, v10, fade(fx)),
        lerp(v01, v11, fade(fx)),
        fade(fy)
    )
end

-- 分形噪声（多层叠加）
function TextureGenerator.fractalNoise(x, y, octaves, persistence, seed)
    local total, amplitude, frequency, maxValue = 0, 1, 1, 0
    for i = 1, octaves do
        total = total + TextureGenerator.valueNoise2D(x * frequency, y * frequency, seed + i * 1000) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    return total / maxValue
end

-- 无缝噪声（用于平铺贴图）
function TextureGenerator.seamlessNoise(x, y, scale, seed)
    local nx = math.cos(x * math.pi * 2) * scale
    local ny = math.cos(y * math.pi * 2) * scale
    local nz = math.sin(x * math.pi * 2) * scale
    local nw = math.sin(y * math.pi * 2) * scale

    local n1 = TextureGenerator.fractalNoise(nx + 100, ny + 100, 4, 0.5, seed)
    local n2 = TextureGenerator.fractalNoise(nz + 200, nw + 200, 4, 0.5, seed + 500)
    return (n1 + n2) / 2
end

-- ============================================
-- 草地贴图生成器
-- ============================================
function TextureGenerator.generateGrass(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            local baseNoise = TextureGenerator.seamlessNoise(nx, ny, 3, s)
            local detailNoise = TextureGenerator.seamlessNoise(nx, ny, 8, s + 100)
            local patchNoise = TextureGenerator.seamlessNoise(nx, ny, 1.5, s + 200)

            local r, g, b

            if patchNoise > 0.6 then
                r = 120 + baseNoise * 40 + detailNoise * 20
                g = 140 + baseNoise * 30 + detailNoise * 15
                b = 50 + baseNoise * 20
            elseif patchNoise < 0.3 then
                r = 40 + baseNoise * 30
                g = 100 + baseNoise * 40 + detailNoise * 20
                b = 30 + baseNoise * 15
            else
                r = 60 + baseNoise * 35 + detailNoise * 15
                g = 120 + baseNoise * 45 + detailNoise * 20
                b = 40 + baseNoise * 20
            end

            local grain = (math.random() - 0.5) * 30 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            local weedNoise = TextureGenerator.seamlessNoise(nx, ny, 12, s + 300)
            if weedNoise > 0.85 then
                r = math.min(255, r + 30)
                g = math.min(255, g + 40)
                b = math.min(255, b + 10)
            end

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 沼泽贴图生成器
-- ============================================
function TextureGenerator.generateSwamp(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            local baseNoise = TextureGenerator.seamlessNoise(nx, ny, 2.5, s)
            local detailNoise = TextureGenerator.seamlessNoise(nx, ny, 6, s + 100)
            local mudNoise = TextureGenerator.seamlessNoise(nx, ny, 1.2, s + 200)

            local r, g, b

            if mudNoise > 0.65 then
                r = 50 + baseNoise * 25
                g = 55 + baseNoise * 20
                b = 45 + baseNoise * 15
            elseif mudNoise < 0.35 then
                r = 55 + baseNoise * 25 + detailNoise * 10
                g = 75 + baseNoise * 30 + detailNoise * 15
                b = 45 + baseNoise * 15
            else
                r = 65 + baseNoise * 30 + detailNoise * 10
                g = 70 + baseNoise * 25 + detailNoise * 10
                b = 50 + baseNoise * 15
            end

            local grain = (math.random() - 0.5) * 25 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            local bubbleNoise = TextureGenerator.seamlessNoise(nx, ny, 15, s + 400)
            if bubbleNoise > 0.9 then
                r = math.min(255, r + 20)
                g = math.min(255, g + 25)
                b = math.min(255, b + 15)
            end

            local debrisNoise = TextureGenerator.seamlessNoise(nx, ny, 10, s + 500)
            if debrisNoise > 0.88 then
                r = math.max(0, r - 30)
                g = math.max(0, g - 25)
                b = math.max(0, b - 20)
            end

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 泥地贴图生成器
-- ============================================
function TextureGenerator.generateMud(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            local baseNoise = TextureGenerator.seamlessNoise(nx, ny, 3, s)
            local crackNoise = TextureGenerator.seamlessNoise(nx, ny, 7, s + 100)
            local wetNoise = TextureGenerator.seamlessNoise(nx, ny, 2, s + 200)

            local r, g, b

            if wetNoise > 0.6 then
                r = 90 + baseNoise * 30
                g = 70 + baseNoise * 25
                b = 45 + baseNoise * 15
            elseif wetNoise < 0.3 then
                r = 140 + baseNoise * 30 + crackNoise * 15
                g = 110 + baseNoise * 25 + crackNoise * 10
                b = 75 + baseNoise * 15
            else
                r = 115 + baseNoise * 35 + crackNoise * 10
                g = 90 + baseNoise * 30 + crackNoise * 8
                b = 60 + baseNoise * 15
            end

            local grain = (math.random() - 0.5) * 20 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            if crackNoise > 0.82 then
                r = math.max(0, r - 40)
                g = math.max(0, g - 35)
                b = math.max(0, b - 25)
            end

            local puddleNoise = TextureGenerator.seamlessNoise(nx, ny, 12, s + 300)
            if puddleNoise > 0.92 then
                r = math.min(255, r + 25)
                g = math.min(255, g + 20)
                b = math.min(255, b + 15)
            end

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 碎石地贴图生成器
-- ============================================
function TextureGenerator.generateRocky(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            local baseNoise = TextureGenerator.seamlessNoise(nx, ny, 4, s)
            local rockNoise = TextureGenerator.seamlessNoise(nx, ny, 8, s + 100)
            local groundNoise = TextureGenerator.seamlessNoise(nx, ny, 2, s + 200)

            local r, g, b

            r = 130 + groundNoise * 30
            g = 120 + groundNoise * 25
            b = 100 + groundNoise * 20

            if rockNoise > 0.7 then
                local rockSize = (rockNoise - 0.7) / 0.3
                r = 160 + baseNoise * 40 - rockSize * 20
                g = 155 + baseNoise * 35 - rockSize * 15
                b = 145 + baseNoise * 30 - rockSize * 10
            elseif rockNoise > 0.55 then
                r = 140 + baseNoise * 30
                g = 135 + baseNoise * 25
                b = 125 + baseNoise * 20
            end

            local grain = (math.random() - 0.5) * 25 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            local shadowNoise = TextureGenerator.seamlessNoise(nx, ny, 10, s + 300)
            if shadowNoise > 0.75 and shadowNoise < 0.8 then
                r = math.max(0, r - 25)
                g = math.max(0, g - 22)
                b = math.max(0, b - 18)
            end

            local sandNoise = TextureGenerator.seamlessNoise(nx, ny, 14, s + 400)
            if sandNoise > 0.9 then
                r = math.min(255, r + 15)
                g = math.min(255, g + 12)
                b = math.min(255, b + 8)
            end

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 雪地贴图生成器 (扩展)
-- ============================================
function TextureGenerator.generateSnow(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            local baseNoise = TextureGenerator.seamlessNoise(nx, ny, 3, s)
            local detailNoise = TextureGenerator.seamlessNoise(nx, ny, 8, s + 100)
            local driftNoise = TextureGenerator.seamlessNoise(nx, ny, 2, s + 200)

            local r, g, b

            if driftNoise > 0.7 then
                r = 230 + baseNoise * 20
                g = 235 + baseNoise * 15
                b = 245 + baseNoise * 10
            elseif driftNoise < 0.3 then
                r = 180 + baseNoise * 25 + detailNoise * 10
                g = 190 + baseNoise * 20 + detailNoise * 8
                b = 200 + baseNoise * 15 + detailNoise * 5
            else
                r = 210 + baseNoise * 25 + detailNoise * 10
                g = 215 + baseNoise * 20 + detailNoise * 8
                b = 225 + baseNoise * 15 + detailNoise * 5
            end

            local grain = (math.random() - 0.5) * 20 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            local iceNoise = TextureGenerator.seamlessNoise(nx, ny, 15, s + 300)
            if iceNoise > 0.92 then
                r = math.min(255, r + 15)
                g = math.min(255, g + 20)
                b = math.min(255, b + 25)
            end

            local footprintNoise = TextureGenerator.seamlessNoise(nx, ny, 10, s + 400)
            if footprintNoise > 0.85 and footprintNoise < 0.9 then
                r = math.max(0, r - 20)
                g = math.max(0, g - 18)
                b = math.max(0, b - 15)
            end

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 沙漠贴图生成器 (扩展)
-- ============================================
function TextureGenerator.generateDesert(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            local baseNoise = TextureGenerator.seamlessNoise(nx, ny, 2.5, s)
            local detailNoise = TextureGenerator.seamlessNoise(nx, ny, 7, s + 100)
            local duneNoise = TextureGenerator.seamlessNoise(nx, ny, 1.5, s + 200)

            local r, g, b

            if duneNoise > 0.65 then
                r = 220 + baseNoise * 25
                g = 195 + baseNoise * 20
                b = 140 + baseNoise * 15
            elseif duneNoise < 0.35 then
                r = 170 + baseNoise * 25 + detailNoise * 10
                g = 145 + baseNoise * 20 + detailNoise * 8
                b = 100 + baseNoise * 15
            else
                r = 195 + baseNoise * 30 + detailNoise * 10
                g = 170 + baseNoise * 25 + detailNoise * 8
                b = 120 + baseNoise * 20
            end

            local grain = (math.random() - 0.5) * 25 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            local windNoise = TextureGenerator.seamlessNoise(nx * 3, ny, 12, s + 300)
            if windNoise > 0.88 then
                r = math.max(0, r - 15)
                g = math.max(0, g - 12)
                b = math.max(0, b - 8)
            end

            local rockNoise = TextureGenerator.seamlessNoise(nx, ny, 14, s + 400)
            if rockNoise > 0.9 then
                r = math.min(255, r + 20)
                g = math.min(255, g + 18)
                b = math.min(255, b + 12)
            end

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 火山岩贴图生成器 (扩展)
-- ============================================
function TextureGenerator.generateVolcanic(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            local baseNoise = TextureGenerator.seamlessNoise(nx, ny, 3, s)
            local crackNoise = TextureGenerator.seamlessNoise(nx, ny, 8, s + 100)
            local lavaNoise = TextureGenerator.seamlessNoise(nx, ny, 1.5, s + 200)

            local r, g, b

            if lavaNoise > 0.75 then
                local lavaIntensity = (lavaNoise - 0.75) / 0.25
                r = 120 + baseNoise * 80 + lavaIntensity * 60
                g = 40 + baseNoise * 30 + lavaIntensity * 40
                b = 20 + baseNoise * 15
            elseif lavaNoise < 0.3 then
                r = 35 + baseNoise * 20
                g = 30 + baseNoise * 15
                b = 30 + baseNoise * 15
            else
                r = 65 + baseNoise * 30 + crackNoise * 10
                g = 45 + baseNoise * 20 + crackNoise * 5
                b = 40 + baseNoise * 15
            end

            local grain = (math.random() - 0.5) * 20 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            if crackNoise > 0.85 then
                local crackGlow = (crackNoise - 0.85) / 0.15
                r = math.min(255, r + 80 * crackGlow)
                g = math.min(255, g + 30 * crackGlow)
                b = math.min(255, b + 10 * crackGlow)
            end

            local ashNoise = TextureGenerator.seamlessNoise(nx, ny, 12, s + 300)
            if ashNoise > 0.9 then
                r = math.min(255, r + 20)
                g = math.min(255, g + 20)
                b = math.min(255, b + 20)
            end

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 主生成函数
-- ============================================
function TextureGenerator.generate(textureType, width, height, seed, styleIntensity)
    textureType = textureType or "grass"
    width = width or 256
    height = height or 256
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    if textureType == "grass" then
        return TextureGenerator.generateGrass(width, height, seed, styleIntensity)
    elseif textureType == "swamp" then
        return TextureGenerator.generateSwamp(width, height, seed, styleIntensity)
    elseif textureType == "mud" then
        return TextureGenerator.generateMud(width, height, seed, styleIntensity)
    elseif textureType == "rocky" then
        return TextureGenerator.generateRocky(width, height, seed, styleIntensity)
    elseif textureType == "snow" then
        return TextureGenerator.generateSnow(width, height, seed, styleIntensity)
    elseif textureType == "desert" then
        return TextureGenerator.generateDesert(width, height, seed, styleIntensity)
    elseif textureType == "volcanic" then
        return TextureGenerator.generateVolcanic(width, height, seed, styleIntensity)
    else
        error("Unknown texture type: " .. textureType .. ". Supported: grass, swamp, mud, rocky, snow, desert, volcanic")
    end
end

-- ============================================
-- UrhoX 引擎贴图创建辅助函数
-- ============================================
function TextureGenerator.createTexture2D(pixels, width, height)
    local data = {}
    for y = 1, height do
        for x = 1, width do
            local p = pixels[y][x]
            table.insert(data, p.r)
            table.insert(data, p.g)
            table.insert(data, p.b)
            table.insert(data, p.a)
        end
    end

    local texture = Texture2D()
    texture:SetSize(width, height, Graphics.RGBA8, TextureUsage.TEXTURE_STATIC)
    texture:SetData(0, 0, 0, width, height, data)

    return texture
end

-- ============================================
-- 性能优化：贴图缓存系统
-- ============================================
TextureGenerator._cache = {}
TextureGenerator._cacheEnabled = true

function TextureGenerator.setCacheEnabled(enabled)
    TextureGenerator._cacheEnabled = enabled
    if not enabled then
        TextureGenerator._cache = {}
    end
end

function TextureGenerator.generateCached(textureType, width, height, seed, styleIntensity)
    if not TextureGenerator._cacheEnabled then
        return TextureGenerator.generate(textureType, width, height, seed, styleIntensity)
    end

    local cacheKey = string.format("%s_%d_%d_%d_%.2f", textureType, width, height, seed, styleIntensity or 0.7)

    if TextureGenerator._cache[cacheKey] then
        return TextureGenerator._cache[cacheKey]
    end

    local pixels = TextureGenerator.generate(textureType, width, height, seed, styleIntensity)
    TextureGenerator._cache[cacheKey] = pixels

    local cacheCount = 0
    for _ in pairs(TextureGenerator._cache) do cacheCount = cacheCount + 1 end
    if cacheCount > 32 then
        TextureGenerator._cache = {}
    end

    return pixels
end

-- ============================================
-- 瓦片地图集成辅助函数
-- ============================================
function TextureGenerator.generateTileMapTextures(tileSize, seed)
    tileSize = tileSize or 256
    seed = seed or os.time()

    local textures = {
        grass = TextureGenerator.generateCached("grass", tileSize, tileSize, seed, 0.7),
        swamp = TextureGenerator.generateCached("swamp", tileSize, tileSize, seed + 1, 0.7),
        mud = TextureGenerator.generateCached("mud", tileSize, tileSize, seed + 2, 0.7),
        rocky = TextureGenerator.generateCached("rocky", tileSize, tileSize, seed + 3, 0.7),
        snow = TextureGenerator.generateCached("snow", tileSize, tileSize, seed + 4, 0.7),
        desert = TextureGenerator.generateCached("desert", tileSize, tileSize, seed + 5, 0.7),
        volcanic = TextureGenerator.generateCached("volcanic", tileSize, tileSize, seed + 6, 0.7)
    }

    return textures
end

function TextureGenerator.generateTileMapData(mapWidth, mapHeight, seed)
    mapWidth = mapWidth or 32
    mapHeight = mapHeight or 32
    seed = seed or os.time()

    local tileMap = {}
    local terrainTypes = {"grass", "swamp", "mud", "rocky", "snow", "desert", "volcanic"}

    for y = 1, mapHeight do
        tileMap[y] = {}
        for x = 1, mapWidth do
            local nx, ny = x / mapWidth, y / mapHeight
            local noise = TextureGenerator.seamlessNoise(nx, ny, 2, seed)

            local terrainIndex = math.floor(noise * #terrainTypes) + 1
            terrainIndex = math.max(1, math.min(#terrainTypes, terrainIndex))
            tileMap[y][x] = terrainTypes[terrainIndex]
        end
    end

    return tileMap
end

function TextureGenerator.createTileMapResources(tileSize, mapWidth, mapHeight, seed)
    tileSize = tileSize or 256
    mapWidth = mapWidth or 32
    mapHeight = mapHeight or 32
    seed = seed or os.time()

    local textures = TextureGenerator.generateTileMapTextures(tileSize, seed)
    local texture2Ds = {}
    local materials = {}

    for terrainType, pixels in pairs(textures) do
        local texture2D = TextureGenerator.createTexture2D(pixels, tileSize, tileSize)
        texture2Ds[terrainType] = texture2D

        local material = Material()
        material:SetTexture(TextureUnit.DIFFUSE, texture2D)
        materials[terrainType] = material
    end

    local tileMapData = TextureGenerator.generateTileMapData(mapWidth, mapHeight, seed)

    return {
        textures = texture2Ds,
        materials = materials,
        tileMapData = tileMapData
    }
end

return TextureGenerator
