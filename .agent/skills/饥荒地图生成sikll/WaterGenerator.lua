-- ============================================
-- 水体贴图生成器 (Water Texture Generator)
-- 适用于 TapTap 制造 / UrhoX 引擎
-- ============================================

local WaterGenerator = {}

-- ============================================
-- 基础水面贴图
-- 特征: 深蓝到 turquoise、波纹、反光
-- ============================================
function WaterGenerator.generateWater(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            -- 多层波纹噪声
            local wave1 = TextureGenerator.seamlessNoise(nx, ny, 4, s)
            local wave2 = TextureGenerator.seamlessNoise(nx, ny, 8, s + 100)
            local wave3 = TextureGenerator.seamlessNoise(nx, ny, 16, s + 200)
            local depth = TextureGenerator.seamlessNoise(nx, ny, 2, s + 300)

            local r, g, b

            if depth > 0.7 then
                -- 深水区（深蓝）
                r = 20 + wave1 * 15 + wave2 * 10
                g = 50 + wave1 * 20 + wave2 * 15
                b = 100 + wave1 * 30 + wave2 * 20
            elseif depth < 0.3 then
                -- 浅水区（turquoise）
                r = 40 + wave1 * 25 + wave2 * 15
                g = 140 + wave1 * 35 + wave2 * 20
                b = 160 + wave1 * 25 + wave2 * 15
            else
                -- 过渡区
                r = 30 + wave1 * 20 + wave2 * 12
                g = 95 + wave1 * 30 + wave2 * 18
                b = 130 + wave1 * 28 + wave2 * 18
            end

            -- 波纹高光
            local ripple = wave3 * wave2
            if ripple > 0.6 then
                local highlight = (ripple - 0.6) / 0.4
                r = math.min(255, r + highlight * 40)
                g = math.min(255, g + highlight * 50)
                b = math.min(255, b + highlight * 45)
            end

            -- 手绘噪点
            local grain = (math.random() - 0.5) * 15 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 泥泞水域（沼泽水）
-- 特征: 暗绿褐色、浑浊、漂浮物
-- ============================================
function WaterGenerator.generateSwampWater(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            local base = TextureGenerator.seamlessNoise(nx, ny, 3, s)
            local detail = TextureGenerator.seamlessNoise(nx, ny, 6, s + 100)
            local murky = TextureGenerator.seamlessNoise(nx, ny, 2, s + 200)

            local r, g, b

            if murky > 0.6 then
                -- 浑浊深水
                r = 35 + base * 15
                g = 50 + base * 15
                b = 35 + base * 10
            else
                -- 较清区域
                r = 45 + base * 20 + detail * 10
                g = 65 + base * 20 + detail * 10
                b = 45 + base * 15 + detail * 8
            end

            -- 漂浮物/气泡
            local debris = TextureGenerator.seamlessNoise(nx, ny, 12, s + 300)
            if debris > 0.9 then
                r = math.min(255, r + 15)
                g = math.min(255, g + 20)
                b = math.min(255, b + 10)
            end

            -- 手绘噪点
            local grain = (math.random() - 0.5) * 20 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 冰面贴图
-- 特征: 白蓝、裂纹、冰晶反光
-- ============================================
function WaterGenerator.generateIce(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            local base = TextureGenerator.seamlessNoise(nx, ny, 3, s)
            local crack = TextureGenerator.seamlessNoise(nx, ny, 8, s + 100)
            local crystal = TextureGenerator.seamlessNoise(nx, ny, 12, s + 200)

            local r, g, b

            -- 基础冰色
            r = 200 + base * 30
            g = 220 + base * 25
            b = 240 + base * 15

            -- 裂纹（深色）
            if crack > 0.85 then
                local crackDepth = (crack - 0.85) / 0.15
                r = math.max(0, r - 80 * crackDepth)
                g = math.max(0, g - 70 * crackDepth)
                b = math.max(0, b - 50 * crackDepth)
            end

            -- 冰晶反光
            if crystal > 0.92 then
                r = math.min(255, r + 25)
                g = math.min(255, g + 30)
                b = math.min(255, b + 35)
            end

            -- 手绘噪点
            local grain = (math.random() - 0.5) * 15 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 熔岩贴图
-- 特征: 深红到亮橙、热浪扭曲、冷却外壳
-- ============================================
function WaterGenerator.generateLava(width, height, seed, styleIntensity)
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local pixels = {}
    local s = seed

    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            local flow = TextureGenerator.seamlessNoise(nx, ny, 2, s)
            local heat = TextureGenerator.seamlessNoise(nx, ny, 6, s + 100)
            local crust = TextureGenerator.seamlessNoise(nx, ny, 10, s + 200)

            local r, g, b

            if flow > 0.65 then
                -- 活跃熔岩流（亮橙红）
                local intensity = (flow - 0.65) / 0.35
                r = 180 + heat * 60 + intensity * 40
                g = 60 + heat * 40 + intensity * 30
                b = 15 + heat * 15
            elseif flow < 0.3 then
                -- 冷却外壳（深黑红）
                r = 50 + heat * 20
                g = 25 + heat * 10
                b = 20 + heat * 8
            else
                -- 过渡区
                r = 110 + heat * 40
                g = 40 + heat * 25
                b = 15 + heat * 10
            end

            -- 冷却裂纹
            if crust > 0.88 then
                local crustThickness = (crust - 0.88) / 0.12
                r = math.max(0, r - 40 * crustThickness)
                g = math.max(0, g - 20 * crustThickness)
                b = math.max(0, b - 10 * crustThickness)
            end

            -- 手绘噪点
            local grain = (math.random() - 0.5) * 25 * styleIntensity
            r = math.max(0, math.min(255, r + grain))
            g = math.max(0, math.min(255, g + grain))
            b = math.max(0, math.min(255, b + grain))

            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- 主生成函数
-- ============================================
function WaterGenerator.generate(waterType, width, height, seed, styleIntensity)
    waterType = waterType or "water"
    width = width or 256
    height = height or 256
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    if waterType == "water" then
        return WaterGenerator.generateWater(width, height, seed, styleIntensity)
    elseif waterType == "swamp" then
        return WaterGenerator.generateSwampWater(width, height, seed, styleIntensity)
    elseif waterType == "ice" then
        return WaterGenerator.generateIce(width, height, seed, styleIntensity)
    elseif waterType == "lava" then
        return WaterGenerator.generateLava(width, height, seed, styleIntensity)
    else
        error("Unknown water type: " .. waterType .. ". Supported: water, swamp, ice, lava")
    end
end

-- ============================================
-- UrhoX 贴图创建
-- ============================================
function WaterGenerator.createTexture2D(pixels, width, height)
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

return WaterGenerator
