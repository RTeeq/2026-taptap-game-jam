-- ============================================
-- 植被覆盖层生成器 (Vegetation Overlay Generator)
-- 在草地贴图上叠加程序化花朵、草丛
-- ============================================

local VegetationGenerator = {}

-- 生成草丛覆盖层
function VegetationGenerator.generateGrassTufts(width, height, seed, density)
    seed = seed or os.time()
    density = density or 0.3  -- 0.0 ~ 1.0

    local overlay = {}
    for y = 1, height do
        overlay[y] = {}
        for x = 1, width do
            overlay[y][x] = {r = 0, g = 0, b = 0, a = 0}  -- 透明
        end
    end

    local s = seed
    local tuftCount = math.floor(width * height * density * 0.01)

    for i = 1, tuftCount do
        local cx = math.random(1, width)
        local cy = math.random(1, height)
        local tuftSize = math.random(3, 8)

        -- 草丛颜色变化
        local grassR = math.random(40, 80)
        local grassG = math.random(100, 160)
        local grassB = math.random(20, 50)

        -- 绘制草丛（圆形区域）
        for dy = -tuftSize, tuftSize do
            for dx = -tuftSize, tuftSize do
                local nx, ny = cx + dx, cy + dy
                if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist <= tuftSize then
                        local alpha = (1 - dist / tuftSize) * 200
                        local noise = TextureGenerator.valueNoise2D(nx * 0.5, ny * 0.5, s + i)

                        overlay[ny][nx] = {
                            r = math.floor(grassR + noise * 30),
                            g = math.floor(grassG + noise * 20),
                            b = math.floor(grassB + noise * 15),
                            a = math.floor(alpha)
                        }
                    end
                end
            end
        end
    end

    return overlay
end

-- 生成花朵覆盖层
function VegetationGenerator.generateFlowers(width, height, seed, density)
    seed = seed or os.time()
    density = density or 0.1

    local overlay = {}
    for y = 1, height do
        overlay[y] = {}
        for x = 1, width do
            overlay[y][x] = {r = 0, g = 0, b = 0, a = 0}
        end
    end

    local flowerColors = {
        {r = 220, g = 80, b = 80},   -- 红花
        {r = 220, g = 200, b = 50},  -- 黄花
        {r = 180, g = 100, b = 200}, -- 紫花
        {r = 240, g = 150, b = 80},  -- 橙花
        {r = 100, g = 150, b = 220}, -- 蓝花
    }

    local s = seed
    local flowerCount = math.floor(width * height * density * 0.005)

    for i = 1, flowerCount do
        local cx = math.random(1, width)
        local cy = math.random(1, height)
        local flowerSize = math.random(2, 4)
        local color = flowerColors[math.random(1, #flowerColors)]

        for dy = -flowerSize, flowerSize do
            for dx = -flowerSize, flowerSize do
                local nx, ny = cx + dx, cy + dy
                if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist <= flowerSize then
                        local alpha = (1 - dist / flowerSize) * 255
                        overlay[ny][nx] = {
                            r = color.r,
                            g = color.g,
                            b = color.b,
                            a = math.floor(alpha)
                        }
                    end
                end
            end
        end
    end

    return overlay
end

-- 合并覆盖层到基础贴图
function VegetationGenerator.merge(basePixels, overlay, width, height)
    local result = {}
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            local base = basePixels[y][x]
            local over = overlay[y][x]

            if over.a > 0 then
                local t = over.a / 255
                result[y][x] = {
                    r = math.floor(base.r * (1 - t) + over.r * t),
                    g = math.floor(base.g * (1 - t) + over.g * t),
                    b = math.floor(base.b * (1 - t) + over.b * t),
                    a = 255
                }
            else
                result[y][x] = base
            end
        end
    end

    return result
end

-- 一键生成带植被的草地
function VegetationGenerator.generateVegetatedGrass(width, height, seed, grassDensity, flowerDensity)
    -- 生成基础草地
    local grass = TextureGenerator.generate("grass", width, height, seed, 0.7)

    -- 生成草丛覆盖层
    local tufts = VegetationGenerator.generateGrassTufts(width, height, seed + 1000, grassDensity)
    grass = VegetationGenerator.merge(grass, tufts, width, height)

    -- 生成花朵覆盖层
    local flowers = VegetationGenerator.generateFlowers(width, height, seed + 2000, flowerDensity)
    grass = VegetationGenerator.merge(grass, flowers, width, height)

    return grass
end

return VegetationGenerator
