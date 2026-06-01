-- ============================================
-- 法线贴图生成器 (Normal Map Generator)
-- 基于高度噪声生成配套法线贴图
-- ============================================

local NormalMapGenerator = {}

-- 从噪声生成高度图
function NormalMapGenerator.generateHeightMap(width, height, seed, scale)
    seed = seed or os.time()
    scale = scale or 4

    local heightMap = {}
    for y = 1, height do
        heightMap[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height
            heightMap[y][x] = TextureGenerator.seamlessNoise(nx, ny, scale, seed)
        end
    end

    return heightMap
end

-- 从高度图计算法线
function NormalMapGenerator.heightToNormal(heightMap, width, height, strength)
    strength = strength or 2.0

    local normals = {}
    for y = 1, height do
        normals[y] = {}
        for x = 1, width do
            -- 采样相邻像素
            local left = heightMap[y][math.max(1, x - 1)]
            local right = heightMap[y][math.min(width, x + 1)]
            local up = heightMap[math.max(1, y - 1)][x]
            local down = heightMap[math.min(height, y + 1)][x]

            -- 计算梯度
            local dx = (right - left) * strength
            local dy = (down - up) * strength

            -- 归一化法线
            local len = math.sqrt(dx * dx + dy * dy + 1)
            local nx = -dx / len
            local ny = -dy / len
            local nz = 1 / len

            -- 转换到 0-255 范围
            normals[y][x] = {
                r = math.floor((nx * 0.5 + 0.5) * 255),
                g = math.floor((ny * 0.5 + 0.5) * 255),
                b = math.floor((nz * 0.5 + 0.5) * 255),
                a = 255
            }
        end
    end

    return normals
end

-- 生成完整法线贴图
function NormalMapGenerator.generate(textureType, width, height, seed, strength)
    local heightMap = NormalMapGenerator.generateHeightMap(width, height, seed, 4)
    local normals = NormalMapGenerator.heightToNormal(heightMap, width, height, strength)
    return normals
end

-- 创建 UrhoX 法线贴图
function NormalMapGenerator.createNormalTexture(pixels, width, height)
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

return NormalMapGenerator
