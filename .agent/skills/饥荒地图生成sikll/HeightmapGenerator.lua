-- ============================================
-- 地形高度图生成器 (Terrain Heightmap Generator)
-- 生成灰度高度图，可用于3D地形或法线贴图
-- ============================================

local HeightmapGenerator = {}

-- ============================================
-- 基础高度图生成
-- 使用多层分形噪声生成自然地形高度
-- ============================================
function HeightmapGenerator.generate(width, height, seed, roughness, octaves)
    seed = seed or os.time()
    roughness = roughness or 0.5
    octaves = octaves or 6

    local heightMap = {}
    local s = seed

    for y = 1, height do
        heightMap[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height

            -- 使用分形噪声生成高度
            local h = TextureGenerator.fractalNoise(nx * 4, ny * 4, octaves, roughness, s)

            -- 添加大型地形特征（山脉/山谷）
            local feature = TextureGenerator.seamlessNoise(nx, ny, 1.5, s + 1000)
            h = h * 0.7 + feature * 0.3

            -- 归一化到 0-255
            h = math.max(0, math.min(1, h))
            local gray = math.floor(h * 255)

            heightMap[y][x] = {r = gray, g = gray, b = gray, a = 255}
        end
    end

    return heightMap
end

-- ============================================
-- 河流侵蚀效果
-- 在高度图上添加河流通道
-- ============================================
function HeightmapGenerator.addRivers(heightMap, width, height, seed, riverCount)
    riverCount = riverCount or 3
    seed = seed or os.time()

    local result = {}
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            result[y][x] = heightMap[y][x]
        end
    end

    for r = 1, riverCount do
        -- 随机河流起点
        local cx = math.random(1, width)
        local cy = math.random(1, height)

        -- 河流路径
        for step = 1, math.max(width, height) do
            if cx < 1 or cx > width or cy < 1 or cy > height then break end

            -- 侵蚀河道
            local riverWidth = math.random(2, 5)
            for dy = -riverWidth, riverWidth do
                for dx = -riverWidth, riverWidth do
                    local nx, ny = cx + dx, cy + dy
                    if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                        local dist = math.sqrt(dx * dx + dy * dy)
                        if dist <= riverWidth then
                            local depth = (1 - dist / riverWidth) * 80
                            local p = result[ny][nx]
                            local newGray = math.max(0, p.r - depth)
                            result[ny][nx] = {r = newGray, g = newGray, b = newGray, a = 255}
                        end
                    end
                end
            end

            -- 河流流向（向低处流动）
            local flowNoise = TextureGenerator.valueNoise2D(cx * 0.1, cy * 0.1, seed + r * 100)
            cx = cx + math.floor(math.cos(flowNoise * math.pi * 2) * 2)
            cy = cy + math.floor(math.sin(flowNoise * math.pi * 2) * 2)
        end
    end

    return result
end

-- ============================================
-- 添加山峰
-- ============================================
function HeightmapGenerator.addPeaks(heightMap, width, height, seed, peakCount)
    peakCount = peakCount or 5
    seed = seed or os.time()

    local result = {}
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            result[y][x] = heightMap[y][x]
        end
    end

    for p = 1, peakCount do
        local px = math.random(width * 0.2, width * 0.8)
        local py = math.random(height * 0.2, height * 0.8)
        local peakHeight = math.random(100, 200)
        local peakRadius = math.random(20, 50)

        for y = 1, height do
            for x = 1, width do
                local dist = math.sqrt((x - px)^2 + (y - py)^2)
                if dist <= peakRadius then
                    local elevation = (1 - dist / peakRadius) * peakHeight
                    local current = result[y][x].r
                    local newGray = math.min(255, current + elevation)
                    result[y][x] = {r = newGray, g = newGray, b = newGray, a = 255}
                end
            end
        end
    end

    return result
end

-- ============================================
-- 平滑处理
-- ============================================
function HeightmapGenerator.smooth(heightMap, width, height, iterations)
    iterations = iterations or 1

    local result = heightMap

    for iter = 1, iterations do
        local smoothed = {}
        for y = 1, height do
            smoothed[y] = {}
            for x = 1, width do
                local sum = result[y][x].r
                local count = 1

                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local nx, ny = x + dx, y + dy
                        if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                            sum = sum + result[ny][nx].r
                            count = count + 1
                        end
                    end
                end

                local avg = math.floor(sum / count)
                smoothed[y][x] = {r = avg, g = avg, b = avg, a = 255}
            end
        end
        result = smoothed
    end

    return result
end

-- ============================================
-- 从高度图生成法线贴图
-- ============================================
function HeightmapGenerator.toNormalMap(heightMap, width, height, strength)
    strength = strength or 2.0

    local normals = {}
    for y = 1, height do
        normals[y] = {}
        for x = 1, width do
            local left = heightMap[y][math.max(1, x - 1)].r / 255
            local right = heightMap[y][math.min(width, x + 1)].r / 255
            local up = heightMap[math.max(1, y - 1)][x].r / 255
            local down = heightMap[math.min(height, y + 1)][x].r / 255

            local dx = (right - left) * strength
            local dy = (down - up) * strength
            local len = math.sqrt(dx * dx + dy * dy + 1)

            normals[y][x] = {
                r = math.floor((-dx / len * 0.5 + 0.5) * 255),
                g = math.floor((-dy / len * 0.5 + 0.5) * 255),
                b = math.floor((1 / len * 0.5 + 0.5) * 255),
                a = 255
            }
        end
    end

    return normals
end

-- ============================================
-- 创建 UrhoX Texture2D
-- ============================================
function HeightmapGenerator.createTexture2D(pixels, width, height)
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

return HeightmapGenerator
