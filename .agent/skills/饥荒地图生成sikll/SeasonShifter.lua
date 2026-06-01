-- ============================================
-- 季节色调切换器 (Season Color Shifter)
-- 根据季节改变贴图色调
-- ============================================

local SeasonShifter = {}

-- 季节色调矩阵
SeasonShifter.seasons = {
    spring = {  -- 春季：更鲜艳、更绿
        r_mult = 0.9, r_add = 20,
        g_mult = 1.1, g_add = 30,
        b_mult = 0.95, b_add = 10,
        saturation = 1.15
    },
    summer = {  -- 夏季：更黄、更干
        r_mult = 1.05, r_add = 10,
        g_mult = 1.0, g_add = 0,
        b_mult = 0.8, b_add = -10,
        saturation = 1.0
    },
    autumn = {  -- 秋季：橙红、枯黄
        r_mult = 1.15, r_add = 30,
        g_mult = 0.9, g_add = -10,
        b_mult = 0.7, b_add = -20,
        saturation = 1.1
    },
    winter = {  -- 冬季：偏蓝、去饱和
        r_mult = 0.85, r_add = -10,
        g_mult = 0.9, g_add = 5,
        b_mult = 1.1, b_add = 20,
        saturation = 0.8
    }
}

-- 应用季节色调到贴图
function SeasonShifter.apply(pixels, width, height, season)
    local shift = SeasonShifter.seasons[season] or SeasonShifter.seasons.spring

    local result = {}
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            local p = pixels[y][x]

            -- 应用乘法和加法
            local r = p.r * shift.r_mult + shift.r_add
            local g = p.g * shift.g_mult + shift.g_add
            local b = p.b * shift.b_mult + shift.b_add

            -- 饱和度调整
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

-- 季节过渡（插值）
function SeasonShifter.blend(pixels, width, height, seasonA, seasonB, t)
    t = math.max(0, math.min(1, t))

    local shiftedA = SeasonShifter.apply(pixels, width, height, seasonA)
    local shiftedB = SeasonShifter.apply(pixels, width, height, seasonB)

    local result = {}
    for y = 1, height do
        result[y] = {}
        for x = 1, width do
            result[y][x] = {
                r = math.floor(shiftedA[y][x].r * (1 - t) + shiftedB[y][x].r * t),
                g = math.floor(shiftedA[y][x].g * (1 - t) + shiftedB[y][x].g * t),
                b = math.floor(shiftedA[y][x].b * (1 - t) + shiftedB[y][x].b * t),
                a = pixels[y][x].a
            }
        end
    end

    return result
end

-- 根据游戏天数自动计算季节
function SeasonShifter.getSeasonByDay(day)
    local dayInYear = day % 72  -- 假设一年72天
    if dayInYear < 18 then
        return "spring", dayInYear / 18
    elseif dayInYear < 36 then
        return "summer", (dayInYear - 18) / 18
    elseif dayInYear < 54 then
        return "autumn", (dayInYear - 36) / 18
    else
        return "winter", (dayInYear - 54) / 18
    end
end

return SeasonShifter
