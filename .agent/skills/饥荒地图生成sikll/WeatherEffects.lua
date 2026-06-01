-- ============================================
-- 天气效果生成器 (Weather Effect Generator)
-- 为贴图添加天气影响效果
-- ============================================

local WeatherEffects = {}

-- 雨天效果：增加湿润感、暗化、反光增强
function WeatherEffects.applyRain(pixels, width, height, intensity)
    intensity = intensity or 0.5

    local result = {}
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            local p = pixels[y][x]

            -- 整体暗化
            local darken = 1 - intensity * 0.15
            local r = p.r * darken
            local g = p.g * darken
            local b = p.b * darken

            -- 增加蓝色调（湿润感）
            b = math.min(255, b + intensity * 15)

            -- 随机雨滴痕迹
            if math.random() < intensity * 0.05 then
                local dropIntensity = math.random() * intensity
                r = math.min(255, r + dropIntensity * 30)
                g = math.min(255, g + dropIntensity * 30)
                b = math.min(255, b + dropIntensity * 40)
            end

            result[y][x] = {
                r = math.floor(r),
                g = math.floor(g),
                b = math.floor(b),
                a = p.a
            }
        end
    end

    return result
end

-- 雪天效果：增加白色覆盖、去饱和
function WeatherEffects.applySnow(pixels, width, height, intensity)
    intensity = intensity or 0.5

    local result = {}
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            local p = pixels[y][x]

            -- 去饱和
            local gray = (p.r + p.g + p.b) / 3
            local desat = 1 - intensity * 0.3
            local r = gray * (1 - desat) + p.r * desat
            local g = gray * (1 - desat) + p.g * desat
            local b = gray * (1 - desat) + p.b * desat

            -- 添加雪覆盖
            local snowCover = intensity * 0.4
            r = r * (1 - snowCover) + 240 * snowCover
            g = g * (1 - snowCover) + 245 * snowCover
            b = b * (1 - snowCover) + 250 * snowCover

            -- 随机雪花
            if math.random() < intensity * 0.03 then
                r = math.min(255, r + 40)
                g = math.min(255, g + 40)
                b = math.min(255, b + 40)
            end

            result[y][x] = {
                r = math.floor(r),
                g = math.floor(g),
                b = math.floor(b),
                a = p.a
            }
        end
    end

    return result
end

-- 雾天效果：增加灰雾、降低对比度
function WeatherEffects.applyFog(pixels, width, height, intensity)
    intensity = intensity or 0.5

    local result = {}
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            local p = pixels[y][x]

            -- 向灰色混合
            local fogColor = {r = 180, g = 185, b = 190}
            local t = intensity * 0.5

            local r = p.r * (1 - t) + fogColor.r * t
            local g = p.g * (1 - t) + fogColor.g * t
            local b = p.b * (1 - t) + fogColor.b * t

            -- 降低对比度
            local avg = (r + g + b) / 3
            local contrast = 1 - intensity * 0.2
            r = avg + (r - avg) * contrast
            g = avg + (g - avg) * contrast
            b = avg + (b - avg) * contrast

            result[y][x] = {
                r = math.floor(r),
                g = math.floor(g),
                b = math.floor(b),
                a = p.a
            }
        end
    end

    return result
end

-- 夜晚效果：大幅暗化、增加蓝色调
function WeatherEffects.applyNight(pixels, width, height, intensity)
    intensity = intensity or 0.7

    local result = {}
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            local p = pixels[y][x]

            -- 大幅暗化
            local darken = 1 - intensity * 0.6
            local r = p.r * darken
            local g = p.g * darken
            local b = p.b * darken

            -- 增加蓝色月光
            b = math.min(255, b + intensity * 20)
            g = math.min(255, g + intensity * 5)

            result[y][x] = {
                r = math.floor(r),
                g = math.floor(g),
                b = math.floor(b),
                a = p.a
            }
        end
    end

    return result
end

-- 通用天气应用
function WeatherEffects.apply(pixels, width, height, weatherType, intensity)
    if weatherType == "rain" then
        return WeatherEffects.applyRain(pixels, width, height, intensity)
    elseif weatherType == "snow" then
        return WeatherEffects.applySnow(pixels, width, height, intensity)
    elseif weatherType == "fog" then
        return WeatherEffects.applyFog(pixels, width, height, intensity)
    elseif weatherType == "night" then
        return WeatherEffects.applyNight(pixels, width, height, intensity)
    else
        return pixels  -- 无效果
    end
end

return WeatherEffects
