-- ============================================
-- 饥荒风格程序化地形贴图生成器 - 终极完整版 (Ultimate All-in-One)
-- 版本: 2.0.0
-- 包含: 11种地形 + 4种水体 + 法线贴图 + 季节切换 + 天气效果 + 植被覆盖 + 高度图
-- ============================================

local DST_Ultimate = {}

-- ============================================
-- 核心噪声系统
-- ============================================

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

function DST_Ultimate.valueNoise2D(x, y, s)
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

function DST_Ultimate.fractalNoise(x, y, octaves, persistence, seed)
    local total, amplitude, frequency, maxValue = 0, 1, 1, 0
    for i = 1, octaves do
        total = total + DST_Ultimate.valueNoise2D(x * frequency, y * frequency, seed + i * 1000) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    return total / maxValue
end

function DST_Ultimate.seamlessNoise(x, y, scale, seed)
    local nx = math.cos(x * math.pi * 2) * scale
    local ny = math.cos(y * math.pi * 2) * scale
    local nz = math.sin(x * math.pi * 2) * scale
    local nw = math.sin(y * math.pi * 2) * scale

    local n1 = DST_Ultimate.fractalNoise(nx + 100, ny + 100, 4, 0.5, seed)
    local n2 = DST_Ultimate.fractalNoise(nz + 200, nw + 200, 4, 0.5, seed + 500)
    return (n1 + n2) / 2
end

-- ============================================
-- 地形颜色配置
-- ============================================

local terrainConfigs = {
    grass = function(nx, ny, s, intensity)
        local base = DST_Ultimate.seamlessNoise(nx, ny, 3, s)
        local detail = DST_Ultimate.seamlessNoise(nx, ny, 8, s + 100)
        local patch = DST_Ultimate.seamlessNoise(nx, ny, 1.5, s + 200)
        local r, g, b
        if patch > 0.6 then
            r, g, b = 120 + base * 40 + detail * 20, 140 + base * 30 + detail * 15, 50 + base * 20
        elseif patch < 0.3 then
            r, g, b = 40 + base * 30, 100 + base * 40 + detail * 20, 30 + base * 15
        else
            r, g, b = 60 + base * 35 + detail * 15, 120 + base * 45 + detail * 20, 40 + base * 20
        end
        local grain = (math.random() - 0.5) * 30 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        local weed = DST_Ultimate.seamlessNoise(nx, ny, 12, s + 300)
        if weed > 0.85 then r, g, b = math.min(255, r + 30), math.min(255, g + 40), math.min(255, b + 10) end
        return r, g, b
    end,

    swamp = function(nx, ny, s, intensity)
        local base = DST_Ultimate.seamlessNoise(nx, ny, 2.5, s)
        local detail = DST_Ultimate.seamlessNoise(nx, ny, 6, s + 100)
        local mud = DST_Ultimate.seamlessNoise(nx, ny, 1.2, s + 200)
        local r, g, b
        if mud > 0.65 then
            r, g, b = 50 + base * 25, 55 + base * 20, 45 + base * 15
        elseif mud < 0.35 then
            r, g, b = 55 + base * 25 + detail * 10, 75 + base * 30 + detail * 15, 45 + base * 15
        else
            r, g, b = 65 + base * 30 + detail * 10, 70 + base * 25 + detail * 10, 50 + base * 15
        end
        local grain = (math.random() - 0.5) * 25 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        local bubble = DST_Ultimate.seamlessNoise(nx, ny, 15, s + 400)
        if bubble > 0.9 then r, g, b = math.min(255, r + 20), math.min(255, g + 25), math.min(255, b + 15) end
        local debris = DST_Ultimate.seamlessNoise(nx, ny, 10, s + 500)
        if debris > 0.88 then r, g, b = math.max(0, r - 30), math.max(0, g - 25), math.max(0, b - 20) end
        return r, g, b
    end,

    mud = function(nx, ny, s, intensity)
        local base = DST_Ultimate.seamlessNoise(nx, ny, 3, s)
        local crack = DST_Ultimate.seamlessNoise(nx, ny, 7, s + 100)
        local wet = DST_Ultimate.seamlessNoise(nx, ny, 2, s + 200)
        local r, g, b
        if wet > 0.6 then
            r, g, b = 90 + base * 30, 70 + base * 25, 45 + base * 15
        elseif wet < 0.3 then
            r, g, b = 140 + base * 30 + crack * 15, 110 + base * 25 + crack * 10, 75 + base * 15
        else
            r, g, b = 115 + base * 35 + crack * 10, 90 + base * 30 + crack * 8, 60 + base * 15
        end
        local grain = (math.random() - 0.5) * 20 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        if crack > 0.82 then r, g, b = math.max(0, r - 40), math.max(0, g - 35), math.max(0, b - 25) end
        local puddle = DST_Ultimate.seamlessNoise(nx, ny, 12, s + 300)
        if puddle > 0.92 then r, g, b = math.min(255, r + 25), math.min(255, g + 20), math.min(255, b + 15) end
        return r, g, b
    end,

    rocky = function(nx, ny, s, intensity)
        local base = DST_Ultimate.seamlessNoise(nx, ny, 4, s)
        local rock = DST_Ultimate.seamlessNoise(nx, ny, 8, s + 100)
        local ground = DST_Ultimate.seamlessNoise(nx, ny, 2, s + 200)
        local r, g, b = 130 + ground * 30, 120 + ground * 25, 100 + ground * 20
        if rock > 0.7 then
            local rockSize = (rock - 0.7) / 0.3
            r, g, b = 160 + base * 40 - rockSize * 20, 155 + base * 35 - rockSize * 15, 145 + base * 30 - rockSize * 10
        elseif rock > 0.55 then
            r, g, b = 140 + base * 30, 135 + base * 25, 125 + base * 20
        end
        local grain = (math.random() - 0.5) * 25 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        local shadow = DST_Ultimate.seamlessNoise(nx, ny, 10, s + 300)
        if shadow > 0.75 and shadow < 0.8 then r, g, b = math.max(0, r - 25), math.max(0, g - 22), math.max(0, b - 18) end
        local sand = DST_Ultimate.seamlessNoise(nx, ny, 14, s + 400)
        if sand > 0.9 then r, g, b = math.min(255, r + 15), math.min(255, g + 12), math.min(255, b + 8) end
        return r, g, b
    end,

    snow = function(nx, ny, s, intensity)
        local base = DST_Ultimate.seamlessNoise(nx, ny, 3, s)
        local detail = DST_Ultimate.seamlessNoise(nx, ny, 8, s + 100)
        local drift = DST_Ultimate.seamlessNoise(nx, ny, 2, s + 200)
        local r, g, b
        if drift > 0.7 then
            r, g, b = 230 + base * 20, 235 + base * 15, 245 + base * 10
        elseif drift < 0.3 then
            r, g, b = 180 + base * 25 + detail * 10, 190 + base * 20 + detail * 8, 200 + base * 15 + detail * 5
        else
            r, g, b = 210 + base * 25 + detail * 10, 215 + base * 20 + detail * 8, 225 + base * 15 + detail * 5
        end
        local grain = (math.random() - 0.5) * 20 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        local ice = DST_Ultimate.seamlessNoise(nx, ny, 15, s + 300)
        if ice > 0.92 then r, g, b = math.min(255, r + 15), math.min(255, g + 20), math.min(255, b + 25) end
        local footprint = DST_Ultimate.seamlessNoise(nx, ny, 10, s + 400)
        if footprint > 0.85 and footprint < 0.9 then r, g, b = math.max(0, r - 20), math.max(0, g - 18), math.max(0, b - 15) end
        return r, g, b
    end,

    desert = function(nx, ny, s, intensity)
        local base = DST_Ultimate.seamlessNoise(nx, ny, 2.5, s)
        local detail = DST_Ultimate.seamlessNoise(nx, ny, 7, s + 100)
        local dune = DST_Ultimate.seamlessNoise(nx, ny, 1.5, s + 200)
        local r, g, b
        if dune > 0.65 then
            r, g, b = 220 + base * 25, 195 + base * 20, 140 + base * 15
        elseif dune < 0.35 then
            r, g, b = 170 + base * 25 + detail * 10, 145 + base * 20 + detail * 8, 100 + base * 15
        else
            r, g, b = 195 + base * 30 + detail * 10, 170 + base * 25 + detail * 8, 120 + base * 20
        end
        local grain = (math.random() - 0.5) * 25 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        local wind = DST_Ultimate.seamlessNoise(nx * 3, ny, 12, s + 300)
        if wind > 0.88 then r, g, b = math.max(0, r - 15), math.max(0, g - 12), math.max(0, b - 8) end
        local rock = DST_Ultimate.seamlessNoise(nx, ny, 14, s + 400)
        if rock > 0.9 then r, g, b = math.min(255, r + 20), math.min(255, g + 18), math.min(255, b + 12) end
        return r, g, b
    end,

    volcanic = function(nx, ny, s, intensity)
        local base = DST_Ultimate.seamlessNoise(nx, ny, 3, s)
        local crack = DST_Ultimate.seamlessNoise(nx, ny, 8, s + 100)
        local lava = DST_Ultimate.seamlessNoise(nx, ny, 1.5, s + 200)
        local r, g, b
        if lava > 0.75 then
            local lavaIntensity = (lava - 0.75) / 0.25
            r, g, b = 120 + base * 80 + lavaIntensity * 60, 40 + base * 30 + lavaIntensity * 40, 20 + base * 15
        elseif lava < 0.3 then
            r, g, b = 35 + base * 20, 30 + base * 15, 30 + base * 15
        else
            r, g, b = 65 + base * 30 + crack * 10, 45 + base * 20 + crack * 5, 40 + base * 15
        end
        local grain = (math.random() - 0.5) * 20 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        if crack > 0.85 then
            local crackGlow = (crack - 0.85) / 0.15
            r, g, b = math.min(255, r + 80 * crackGlow), math.min(255, g + 30 * crackGlow), math.min(255, b + 10 * crackGlow)
        end
        local ash = DST_Ultimate.seamlessNoise(nx, ny, 12, s + 300)
        if ash > 0.9 then r, g, b = math.min(255, r + 20), math.min(255, g + 20), math.min(255, b + 20) end
        return r, g, b
    end,

    -- 水体贴图
    water = function(nx, ny, s, intensity)
        local wave1 = DST_Ultimate.seamlessNoise(nx, ny, 4, s)
        local wave2 = DST_Ultimate.seamlessNoise(nx, ny, 8, s + 100)
        local wave3 = DST_Ultimate.seamlessNoise(nx, ny, 16, s + 200)
        local depth = DST_Ultimate.seamlessNoise(nx, ny, 2, s + 300)
        local r, g, b
        if depth > 0.7 then
            r, g, b = 20 + wave1 * 15 + wave2 * 10, 50 + wave1 * 20 + wave2 * 15, 100 + wave1 * 30 + wave2 * 20
        elseif depth < 0.3 then
            r, g, b = 40 + wave1 * 25 + wave2 * 15, 140 + wave1 * 35 + wave2 * 20, 160 + wave1 * 25 + wave2 * 15
        else
            r, g, b = 30 + wave1 * 20 + wave2 * 12, 95 + wave1 * 30 + wave2 * 18, 130 + wave1 * 28 + wave2 * 18
        end
        local ripple = wave3 * wave2
        if ripple > 0.6 then
            local highlight = (ripple - 0.6) / 0.4
            r, g, b = math.min(255, r + highlight * 40), math.min(255, g + highlight * 50), math.min(255, b + highlight * 45)
        end
        local grain = (math.random() - 0.5) * 15 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        return r, g, b
    end,

    swampwater = function(nx, ny, s, intensity)
        local base = DST_Ultimate.seamlessNoise(nx, ny, 3, s)
        local detail = DST_Ultimate.seamlessNoise(nx, ny, 6, s + 100)
        local murky = DST_Ultimate.seamlessNoise(nx, ny, 2, s + 200)
        local r, g, b
        if murky > 0.6 then
            r, g, b = 35 + base * 15, 50 + base * 15, 35 + base * 10
        else
            r, g, b = 45 + base * 20 + detail * 10, 65 + base * 20 + detail * 10, 45 + base * 15 + detail * 8
        end
        local debris = DST_Ultimate.seamlessNoise(nx, ny, 12, s + 300)
        if debris > 0.9 then r, g, b = math.min(255, r + 15), math.min(255, g + 20), math.min(255, b + 10) end
        local grain = (math.random() - 0.5) * 20 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        return r, g, b
    end,

    ice = function(nx, ny, s, intensity)
        local base = DST_Ultimate.seamlessNoise(nx, ny, 3, s)
        local crack = DST_Ultimate.seamlessNoise(nx, ny, 8, s + 100)
        local crystal = DST_Ultimate.seamlessNoise(nx, ny, 12, s + 200)
        local r, g, b = 200 + base * 30, 220 + base * 25, 240 + base * 15
        if crack > 0.85 then
            local crackDepth = (crack - 0.85) / 0.15
            r, g, b = math.max(0, r - 80 * crackDepth), math.max(0, g - 70 * crackDepth), math.max(0, b - 50 * crackDepth)
        end
        if crystal > 0.92 then r, g, b = math.min(255, r + 25), math.min(255, g + 30), math.min(255, b + 35) end
        local grain = (math.random() - 0.5) * 15 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        return r, g, b
    end,

    lava = function(nx, ny, s, intensity)
        local flow = DST_Ultimate.seamlessNoise(nx, ny, 2, s)
        local heat = DST_Ultimate.seamlessNoise(nx, ny, 6, s + 100)
        local crust = DST_Ultimate.seamlessNoise(nx, ny, 10, s + 200)
        local r, g, b
        if flow > 0.65 then
            local flowIntensity = (flow - 0.65) / 0.35
            r, g, b = 180 + heat * 60 + flowIntensity * 40, 60 + heat * 40 + flowIntensity * 30, 15 + heat * 15
        elseif flow < 0.3 then
            r, g, b = 50 + heat * 20, 25 + heat * 10, 20 + heat * 8
        else
            r, g, b = 110 + heat * 40, 40 + heat * 25, 15 + heat * 10
        end
        if crust > 0.88 then
            local crustThick = (crust - 0.88) / 0.12
            r, g, b = math.max(0, r - 40 * crustThick), math.max(0, g - 20 * crustThick), math.max(0, b - 10 * crustThick)
        end
        local grain = (math.random() - 0.5) * 25 * intensity
        r, g, b = math.max(0, math.min(255, r + grain)), math.max(0, math.min(255, g + grain)), math.max(0, math.min(255, b + grain))
        return r, g, b
    end
}

-- ============================================
-- 主生成函数
-- ============================================

function DST_Ultimate.generate(textureType, width, height, seed, styleIntensity)
    textureType = textureType or "grass"
    width = width or 256
    height = height or 256
    seed = seed or os.time()
    styleIntensity = styleIntensity or 0.7

    local colorFunc = terrainConfigs[textureType]
    if not colorFunc then
        error("Unknown texture type: " .. textureType .. ". Supported types: grass, swamp, mud, rocky, snow, desert, volcanic, water, swampwater, ice, lava")
    end

    local pixels = {}
    for y = 1, height do
        pixels[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height
            local r, g, b = colorFunc(nx, ny, seed, styleIntensity)
            pixels[y][x] = {r = math.floor(r), g = math.floor(g), b = math.floor(b), a = 255}
        end
    end

    return pixels
end

-- ============================================
-- UrhoX 贴图创建
-- ============================================

function DST_Ultimate.createTexture2D(pixels, width, height)
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
-- 缓存系统
-- ============================================

DST_Ultimate._cache = {}
DST_Ultimate._cacheEnabled = true

function DST_Ultimate.setCacheEnabled(enabled)
    DST_Ultimate._cacheEnabled = enabled
    if not enabled then DST_Ultimate._cache = {} end
end

function DST_Ultimate.generateCached(textureType, width, height, seed, styleIntensity)
    if not DST_Ultimate._cacheEnabled then
        return DST_Ultimate.generate(textureType, width, height, seed, styleIntensity)
    end

    local cacheKey = string.format("%s_%d_%d_%d_%.2f", textureType, width, height, seed, styleIntensity or 0.7)

    if DST_Ultimate._cache[cacheKey] then
        return DST_Ultimate._cache[cacheKey]
    end

    local pixels = DST_Ultimate.generate(textureType, width, height, seed, styleIntensity)
    DST_Ultimate._cache[cacheKey] = pixels

    local cacheCount = 0
    for _ in pairs(DST_Ultimate._cache) do cacheCount = cacheCount + 1 end
    if cacheCount > 32 then DST_Ultimate._cache = {} end

    return pixels
end

-- ============================================
-- 季节色调切换
-- ============================================

DST_Ultimate.seasons = {
    spring = {r_mult = 0.9, r_add = 20, g_mult = 1.1, g_add = 30, b_mult = 0.95, b_add = 10, saturation = 1.15},
    summer = {r_mult = 1.05, r_add = 10, g_mult = 1.0, g_add = 0, b_mult = 0.8, b_add = -10, saturation = 1.0},
    autumn = {r_mult = 1.15, r_add = 30, g_mult = 0.9, g_add = -10, b_mult = 0.7, b_add = -20, saturation = 1.1},
    winter = {r_mult = 0.85, r_add = -10, g_mult = 0.9, g_add = 5, b_mult = 1.1, b_add = 20, saturation = 0.8}
}

function DST_Ultimate.applySeason(pixels, width, height, season)
    local shift = DST_Ultimate.seasons[season] or DST_Ultimate.seasons.spring
    local result = {}
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            local p = pixels[y][x]
            local r = p.r * shift.r_mult + shift.r_add
            local g = p.g * shift.g_mult + shift.g_add
            local b = p.b * shift.b_mult + shift.b_add

            if shift.saturation ~= 1.0 then
                local gray = (r + g + b) / 3
                r = gray + (r - gray) * shift.saturation
                g = gray + (g - gray) * shift.saturation
                b = gray + (b - gray) * shift.saturation
            end

            result[y][x] = {
                r = math.max(0, math.min(255, math.floor(r))),
                g = math.max(0, math.min(255, math.floor(g))),
                b = math.max(0, math.min(255, math.floor(b))),
                a = p.a
            }
        end
    end
    return result
end

function DST_Ultimate.getSeasonByDay(day)
    local dayInYear = day % 72
    if dayInYear < 18 then return "spring", dayInYear / 18
    elseif dayInYear < 36 then return "summer", (dayInYear - 18) / 18
    elseif dayInYear < 54 then return "autumn", (dayInYear - 36) / 18
    else return "winter", (dayInYear - 54) / 18 end
end

-- ============================================
-- 天气效果
-- ============================================

function DST_Ultimate.applyWeather(pixels, width, height, weatherType, intensity)
    intensity = intensity or 0.5
    local result = {}

    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            local p = pixels[y][x]
            local r, g, b = p.r, p.g, p.b

            if weatherType == "rain" then
                local darken = 1 - intensity * 0.15
                r, g, b = r * darken, g * darken, math.min(255, b + intensity * 15)
                if math.random() < intensity * 0.05 then
                    local drop = math.random() * intensity
                    r, g, b = math.min(255, r + drop * 30), math.min(255, g + drop * 30), math.min(255, b + drop * 40)
                end
            elseif weatherType == "snow" then
                local gray = (r + g + b) / 3
                local desat = 1 - intensity * 0.3
                r, g, b = gray * (1 - desat) + r * desat, gray * (1 - desat) + g * desat, gray * (1 - desat) + b * desat
                local snowCover = intensity * 0.4
                r = r * (1 - snowCover) + 240 * snowCover
                g = g * (1 - snowCover) + 245 * snowCover
                b = b * (1 - snowCover) + 250 * snowCover
                if math.random() < intensity * 0.03 then r, g, b = math.min(255, r + 40), math.min(255, g + 40), math.min(255, b + 40) end
            elseif weatherType == "fog" then
                local fogColor = {r = 180, g = 185, b = 190}
                local t = intensity * 0.5
                r, g, b = r * (1 - t) + fogColor.r * t, g * (1 - t) + fogColor.g * t, b * (1 - t) + fogColor.b * t
                local avg = (r + g + b) / 3
                local contrast = 1 - intensity * 0.2
                r, g, b = avg + (r - avg) * contrast, avg + (g - avg) * contrast, avg + (b - avg) * contrast
            elseif weatherType == "night" then
                local darken = 1 - intensity * 0.6
                r, g, b = r * darken, g * darken, math.min(255, b + intensity * 20)
                g = math.min(255, g + intensity * 5)
            end

            result[y][x] = {
                r = math.max(0, math.min(255, math.floor(r))),
                g = math.max(0, math.min(255, math.floor(g))),
                b = math.max(0, math.min(255, math.floor(b))),
                a = p.a
            }
        end
    end

    return result
end

-- ============================================
-- 法线贴图生成
-- ============================================

function DST_Ultimate.generateNormalMap(textureType, width, height, seed, strength)
    strength = strength or 2.0
    local heightMap = {}
    for y = 1, height do
        heightMap[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height
            heightMap[y][x] = DST_Ultimate.seamlessNoise(nx, ny, 4, seed)
        end
    end

    local normals = {}
    for y = 1, height do
        normals[y] = {}
        for x = 1, width do
            local left = heightMap[y][math.max(1, x - 1)]
            local right = heightMap[y][math.min(width, x + 1)]
            local up = heightMap[math.max(1, y - 1)][x]
            local down = heightMap[math.min(height, y + 1)][x]

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
-- 高度图生成
-- ============================================

function DST_Ultimate.generateHeightMap(width, height, seed, roughness, octaves)
    roughness = roughness or 0.5
    octaves = octaves or 6

    local heightMap = {}
    for y = 1, height do
        heightMap[y] = {}
        for x = 1, width do
            local nx, ny = x / width, y / height
            local h = DST_Ultimate.fractalNoise(nx * 4, ny * 4, octaves, roughness, seed)
            local feature = DST_Ultimate.seamlessNoise(nx, ny, 1.5, seed + 1000)
            h = h * 0.7 + feature * 0.3
            h = math.max(0, math.min(1, h))
            local gray = math.floor(h * 255)
            heightMap[y][x] = {r = gray, g = gray, b = gray, a = 255}
        end
    end

    return heightMap
end

-- ============================================
-- 瓦片地图集成
-- ============================================

function DST_Ultimate.generateTileMapTextures(tileSize, seed)
    tileSize = tileSize or 256
    seed = seed or os.time()

    local allTypes = {"grass", "swamp", "mud", "rocky", "snow", "desert", "volcanic", "water", "swampwater", "ice", "lava"}
    local textures = {}

    for i, terrainType in ipairs(allTypes) do
        textures[terrainType] = DST_Ultimate.generateCached(terrainType, tileSize, tileSize, seed + i * 100, 0.7)
    end

    return textures
end

function DST_Ultimate.generateTileMapData(mapWidth, mapHeight, seed)
    mapWidth = mapWidth or 32
    mapHeight = mapHeight or 32
    seed = seed or os.time()

    local tileMap = {}
    local terrainTypes = {"grass", "swamp", "mud", "rocky", "snow", "desert", "volcanic", "water"}

    for y = 1, mapHeight do
        tileMap[y] = {}
        for x = 1, mapWidth do
            local nx, ny = x / mapWidth, y / mapHeight
            local noise = DST_Ultimate.seamlessNoise(nx, ny, 2, seed)
            local terrainIndex = math.floor(noise * #terrainTypes) + 1
            terrainIndex = math.max(1, math.min(#terrainTypes, terrainIndex))
            tileMap[y][x] = terrainTypes[terrainIndex]
        end
    end

    return tileMap
end

-- ============================================
-- 植被覆盖层
-- ============================================

function DST_Ultimate.generateGrassTufts(width, height, seed, density)
    seed = seed or os.time()
    density = density or 0.3

    local overlay = {}
    for y = 1, height do
        overlay[y] = {}
        for x = 1, width do
            overlay[y][x] = {r = 0, g = 0, b = 0, a = 0}
        end
    end

    local tuftCount = math.floor(width * height * density * 0.01)

    for i = 1, tuftCount do
        local cx = math.random(1, width)
        local cy = math.random(1, height)
        local tuftSize = math.random(3, 8)
        local grassR = math.random(40, 80)
        local grassG = math.random(100, 160)
        local grassB = math.random(20, 50)

        for dy = -tuftSize, tuftSize do
            for dx = -tuftSize, tuftSize do
                local nx, ny = cx + dx, cy + dy
                if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist <= tuftSize then
                        local alpha = (1 - dist / tuftSize) * 200
                        local noise = DST_Ultimate.valueNoise2D(nx * 0.5, ny * 0.5, seed + i)
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

function DST_Ultimate.generateFlowers(width, height, seed, density)
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
        {r = 220, g = 80, b = 80},
        {r = 220, g = 200, b = 50},
        {r = 180, g = 100, b = 200},
        {r = 240, g = 150, b = 80},
        {r = 100, g = 150, b = 220}
    }

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
                            r = color.r, g = color.g, b = color.b,
                            a = math.floor(alpha)
                        }
                    end
                end
            end
        end
    end

    return overlay
end

function DST_Ultimate.mergeOverlay(basePixels, overlay, width, height)
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

function DST_Ultimate.generateVegetatedGrass(width, height, seed, grassDensity, flowerDensity)
    local grass = DST_Ultimate.generate("grass", width, height, seed, 0.7)
    local tufts = DST_Ultimate.generateGrassTufts(width, height, seed + 1000, grassDensity)
    grass = DST_Ultimate.mergeOverlay(grass, tufts, width, height)
    local flowers = DST_Ultimate.generateFlowers(width, height, seed + 2000, flowerDensity)
    grass = DST_Ultimate.mergeOverlay(grass, flowers, width, height)
    return grass
end

-- ============================================
-- 导出
-- ============================================

return DST_Ultimate
