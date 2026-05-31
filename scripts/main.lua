-- ============================================================================
-- 《道友请留步》
-- 2.5D 俯视角生存对战游戏 MVP
-- 玩法: 6人开局中毒, 攻击他人解毒, 每轮淘汰中毒者, 最后1人存活胜利
-- ============================================================================

require "LuaScripts/Utilities/Sample"
local UI = require("urhox-libs/UI")

-- ============================================================================
-- 全局常量
-- ============================================================================
local CONFIG = {
    Title = "道友请留步",
    -- 地图
    MapSize = 1024,
    -- 相机
    ViewRadius = 800,
    -- 玩家
    PlayerCount = 5,
    PlayerRadius = 20,
    MoveSpeed = 200,         -- 像素/秒
    MoveSpeedMin = 50,       -- 能量耗尽时
    -- 属性
    PoisonMax = 100,
    PoisonMin = 0,
    EnergyMax = 100,
    EnergyMin = 0,
    -- 6.1 能量消耗
    MoveCostRate = 1,            -- 正常移动消耗: 1/秒
    SprintCostRate = 3,          -- 奔跑消耗: 3/秒
    SprintSpeedMultiplier = 1.8, -- 奔跑速度倍率(200*1.8=360)
    AttackCostEnergy = 5,        -- 攻击消耗能量
    DrinkCostEnergy = 10,        -- 喝药消耗能量(6.1)
    InteractCostEnergy = 5,      -- 交互消耗能量(6.1)
    -- 6.3 能量回复
    EnergyStealOnHit = 10,       -- 命中掠夺能量(从对方扣除)
    ComfortZoneRegenRate = 50,   -- 舒适区占领后回复速率: 50/秒
    ComfortZoneWaitTime = 3,     -- 需站立不动等待3秒才能占领成功
    ComfortZoneRadius = 75,      -- 舒适区判定半径(px) - 缩小为原来的一半
    ComfortZoneClaimEnergy = 100, -- 每次占领获得的能量配额
    ComfortZoneMinSpawnDist = 300, -- 距任何玩家出生点最小距离
    ComfortZoneSeparation = 400,   -- 多个舒适区之间最小距离
    -- 攻击(4.3)
    AttackRange = 120,       -- 像素(扇形半径)
    AttackAngle = 60,        -- 度(扇形角度)
    AttackWindup = 0.2,      -- 前摇(举臂)
    AttackRecovery = 0.3,    -- 后摇(收臂, 无法移动)
    AttackCooldown = 0.6,    -- 总冷却(前摇+后摇+余量)
    AttackPoisonReduce = 15, -- 命中自身减毒
    AttackPoisonAdd = 10,    -- 命中目标加毒
    AttackEnergyGain = 35,   -- [废弃,保留兼容] 改用EnergyStealOnHit
    PoisonDrinkAmount = 100, -- 误饮毒药增加量(直接满)
    -- 5.2 喝药系统
    DrinkDuration = 1.5,     -- 喝药读条时间(秒)
    DrinkStunDuration = 0.5, -- 被打断后硬直时间(秒)
    DrinkInterruptPoisonTransfer = 30, -- 5.5 毒药转移给攻击者的毒量
    GroundPotionPickupRange = 50,      -- 地面药剂拾取距离(像素)
    -- 8.1 交互系统
    InteractRange = 80,          -- 交互触发距离(像素)
    InteractDuration = 3.0,      -- 交互状态持续时间(秒)
    InteractAcceptTimeout = 2.0, -- 接受超时(秒, 默认接受)
    -- 回合(3.3 核心参数)
    TotalRounds = 5,             -- 总天数(5天)
    PrepareDuration = 10,        -- 准备阶段(仅开局一次)
    DayDuration = 60,            -- 白天阶段(主要战斗时间)
    NightfallDuration = 5,       -- 黑夜降临(黑屏+5秒倒计时)
    NightDuration = 0,           -- [废弃] 黑夜进行阶段已合并到nightfall
    SettleDuration = 3,          -- 黑夜结算(淘汰页面展示)
    PoisonPerRound = 30,         -- 每轮黑夜降临加毒
    AntidoteRatio = 0.5,         -- 黑夜降临时获得解药的存活玩家比例
    -- 9.1 毒圈
    CircleInitRadiusFactor = 0.8,  -- 初始半径=地图对角线*0.8(约2300px)
    CircleShrinkRatio = 3/5,       -- 每轮收缩至当前3/5(缩小2/5)
    CircleShrinkDuration = 1,      -- shrinking过渡阶段1秒(实际缩圈在day阶段60秒内完成)
    CirclePoisonRate = 10,         -- 9.2 毒圈外加毒速度: 10/秒
    CircleFogWidth = 50,           -- 9.3 雾霭带宽度(像素)
    -- AI
    AIUpdateInterval = 0.3,  -- AI决策间隔
}

-- ============================================================================
-- 游戏状态
-- ============================================================================
local nvgContext = nil
local fontId = -1

-- 游戏阶段: "menu", "prepare", "day", "settle", "shrinking", "victory", "defeat"
local gamePhase = "menu"
local currentRound = 0
local phaseTimer = 0        -- 当前阶段计时器
local eliminatedIdx = -1    -- 本轮被淘汰的玩家索引
local settleDeaths = {}     -- 结算阶段死亡的玩家索引列表
local settleSubPhase = "countdown"  -- "countdown"(5s黑屏倒计时) / "elimination"(3s淘汰展示)
local countdownLastSecond = -1      -- 倒计时音效追踪(每秒播放一次)
local backToMenuBtnRect = { x = 0, y = 0, w = 0, h = 0 }  -- 返回主页按钮点击区域
local isFirstRound = true   -- 是否第一轮(准备阶段标记)
local victoryWinnerIdx = nil -- 胜利玩家索引(最后存活者)
local victoryPotionGiven = false -- 是否已发放胜利药水

-- 状态特效
local statusEffects = {}    -- {playerIdx, type="poison"/"detox", timer}

-- 物品获取光效(2.5 UI)
local pickupGlows = {}      -- {playerIdx, type="antidote"/"poison", timer, maxTimer}

-- 9.1 毒圈(初始半径=地图对角线*80%≈2300px, 中心=地图几何中心)
local circleInitRadius = math.sqrt(CONFIG.MapSize * CONFIG.MapSize * 2) * CONFIG.CircleInitRadiusFactor
local circle = {
    cx = CONFIG.MapSize / 2,   -- 中心点: 1024
    cy = CONFIG.MapSize / 2,   -- 中心点: 1024
    radius = circleInitRadius,
    targetRadius = circleInitRadius,
    shrinkSpeed = 0,           -- 当前收缩速度(每次缩圈时计算)
}

-- 相机
local camera = {
    x = CONFIG.MapSize / 2,
    y = CONFIG.MapSize / 2,
}

-- 玩家数组
local players = {}
-- 玩家索引(自己)
local localPlayerIdx = 1

-- 背包系统
local inventoryOpen = false
-- 物品: nil, "poison", "antidote"
-- 每个玩家有一个背包格

-- 粒子效果
local particles = {}

-- 死亡纸片碎裂效果
local deathPieces = {}   -- {x, y, vx, vy, rot, rotV, w, h, life, color}
local deathStains = {}   -- {x, y, alpha} 死亡黑色污渍

-- 舒适区(圈内安全点, 有篝火/清泉/圣坛)
local comfortZones = {}  -- {x, y, type="campfire"/"spring"/"altar", playersInside={}}
-- 舒适区浮动数字
local comfortFloats = {}  -- {x, y, text, life, maxLife, color}

-- UI引用
local uiRoot_ = nil

-- 攻击动画
local attackEffects = {}

-- 浮动文字(4.3 命中反馈)
local floatingTexts = {}  -- {x, y, text, color={r,g,b}, timer, maxTimer}

-- 5.3 地面药剂(掉落的解药/毒药)
local groundPotions = {}  -- {x, y, type="antidote"/"poison", timer}

-- 屏幕震动(4.3 命中反馈)
local screenShake = { timer = 0, intensity = 0 }

-- ============================================================================
-- 辅助函数
-- ============================================================================

local function dist(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function angleBetween(x1, y1, x2, y2)
    return math.atan(y2 - y1, x2 - x1)
end

local function normalizeAngle(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

-- ============================================================================
-- 10.2 音效系统
-- ============================================================================
local sfxNode = nil  -- 音效播放节点(在Start中初始化)
local sfxCache = {}  -- 缓存已加载的Sound资源
local bgmSource = nil  -- 背景音乐播放源
local bgmPlaylist = {   -- 背景音乐播放列表
    "audio/游戏音乐/疯猪追月.ogg",
    "audio/游戏音乐/倒计时乱跑.ogg",
    "audio/游戏音乐/毒圈童话.ogg",
}
local bgmCurrentIdx = 0  -- 当前播放索引

local function playSound(name, gain, panning)
    if not sfxNode then return end
    local path = "audio/sfx/" .. name .. ".ogg"
    local sound = sfxCache[path]
    if not sound then
        sound = cache:GetResource("Sound", path)
        if not sound then return end
        sfxCache[path] = sound
    end
    local source = sfxNode:CreateComponent("SoundSource")
    source:SetSoundType("Effect")
    source:SetAutoRemoveMode(REMOVE_COMPONENT)
    source:SetGain(gain or 0.6)
    if panning then source:SetPanning(panning) end
    source:Play(sound)
end

-- 播放背景音乐指定曲目(最后一首循环)
local function playBgmTrack(idx)
    if not bgmSource then return end
    if idx < 1 or idx > #bgmPlaylist then return end
    bgmCurrentIdx = idx
    local path = bgmPlaylist[idx]
    local sound = cache:GetResource("Sound", path)
    if sound then
        -- 最后一首循环播放,其余播放一次
        sound.looped = (idx == #bgmPlaylist)
        bgmSource:Play(sound)
        print("[BGM] 播放第" .. idx .. "首: " .. path .. (sound.looped and " (循环)" or ""))
    else
        print("[BGM] WARNING: 无法加载: " .. path)
    end
end

-- 检测当前曲目播完并切换下一首
local function updateBgm()
    if not bgmSource then return end
    if not bgmSource:IsPlaying() then
        if bgmCurrentIdx == 0 then
            -- 特殊曲目(黑夜倒计时)播完,恢复播放列表第1首
            playBgmTrack(1)
        elseif bgmCurrentIdx < #bgmPlaylist then
            -- 播放列表中下一首
            playBgmTrack(bgmCurrentIdx + 1)
        end
    end
end

-- 毒值警告音cooldown(避免频繁播放)
local poisonWarnCooldown = 0

-- ============================================================================
-- 玩家初始化
-- ============================================================================

local function createPlayer(idx, x, y, isLocal)
    return {
        idx = idx,
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        facing = 0,  -- 朝向角度(弧度)
        poison = 0,
        energy = CONFIG.EnergyMax,
        alive = true,
        isLocal = isLocal,
        isGhost = false,  -- 死亡后变为鬼魂
        attackCooldown = 0,
        attacking = false,
        attackTimer = 0,
        attackState = "idle",    -- "idle"/"windup"/"recovery"
        attackStateTimer = 0,
        flipDir = 1,  -- 角色朝向翻转: 1=朝右, -1=朝左
        -- AI
        aiTimer = 0,
        aiTargetX = x,
        aiTargetY = y,
        aiWantsAttack = false,
        -- 5.1 药剂状态(不占道具栏, 以状态存在)
        potionState = nil,  -- nil / "antidote" / "poison"
        -- 5.2 喝药状态
        drinkingState = "idle",  -- "idle" / "drinking" / "stunned"
        drinkingTimer = 0,
        drinkingType = nil,      -- "antidote" / "poison" (正在喝什么)
        -- 6.1 奔跑(Shift键)
        sprinting = false,
        -- 8.1 交互
        interactState = "idle",   -- "idle"/"requesting"/"pending"/"interacting"/"giving"
        interactPartner = nil,    -- 交互对象idx
        interactTimer = 0,        -- 交互计时器
        interactGiveType = nil,   -- 正在给予的物品类型: "antidote"/"poison"
        interactReceived = nil,   -- 收到的物品: "antidote"/"poison"
        interactFlyAnim = nil,    -- 抛物线动画 {t, duration, fromX, fromY, toX, toY, type}
        -- 舒适区(站点占领机制)
        comfortStandTimer = 0,  -- 在舒适区站立不动的累计时间
        usingComfortZone = false, -- 是否正在使用舒适区(已占领,恢复中)
        isCapturingZone = false,  -- 是否正在占领中(等待3秒)
        comfortClaims = {},  -- {[zoneIdx]={claimed=bool, claimTimer=n, energyLeft=n}} 每个玩家对每个舒适区的占领状态
        -- 视觉
        color = {0, 0, 0},
        hitFlash = 0,
        avatarIdx = 1,  -- 猪角色图片索引(1-5, initPlayers中随机分配)
        -- 毒满暴走buff: 毒素达到100时激活, 毒素归零时解除
        poisonMaxBuff = false,  -- 是否处于暴走状态(毒素转移翻倍+吸取能量翻倍)
        -- 10.3 中毒加深骷髅
        poisonSkullTimer = 0,
        lastPoisonTick = 0,  -- 上次触发骷髅时的毒值(每+10触发)
    }
end

-- 角色配色: 主体灰白/暗褐, 无鲜艳颜色, 靠光效区分状态
local PLAYER_COLORS = {
    {160, 160, 160},  -- 灰白(玩家)
    {140, 110, 90},   -- 暗褐
    {120, 125, 130},  -- 冷灰
    {150, 140, 120},  -- 暖灰
    {130, 120, 135},  -- 灰紫
}

-- 猪角色图片路径(5个角色)
local PIG_IMAGE_PATHS = {
    "image/Image 16.png",        -- 小丑猪
    "image/pig_warrior.png",     -- 战士猪
    "image/pig_scientist.png",   -- 科学家猪
    "image/pig_miner.png",       -- 矿工猪
    "image/pig_thief.png",       -- 盗贼猪
}
local pigImages = {}  -- nvgCreateImage 返回的句柄数组

-- 小丑猪(avatarIdx=1)走路动画帧路径(16帧循环)
local JESTER_WALK_FRAME_PATHS = {}
for i = 1, 16 do
    JESTER_WALK_FRAME_PATHS[i] = string.format("image/jester_pig_anim/walk/walk_%02d.png", i)
end
local jesterWalkFrames = {}  -- nvgCreateImage 句柄数组(16帧)
local JESTER_WALK_FPS = 12   -- 走路动画帧率

-- 小丑猪(avatarIdx=1)待机动画帧路径(6帧循环)
local JESTER_IDLE_FRAME_PATHS = {}
for i = 1, 6 do
    JESTER_IDLE_FRAME_PATHS[i] = string.format("image/jester_pig_anim/idle/idle_%02d.png", i)
end
local jesterIdleFrames = {}  -- nvgCreateImage 句柄数组(6帧)
local JESTER_IDLE_FPS = 8    -- 待机动画帧率

-- 小丑猪(avatarIdx=1)奔跑动画帧路径(8帧循环)
local JESTER_RUN_FRAME_PATHS = {}
for i = 1, 8 do
    JESTER_RUN_FRAME_PATHS[i] = string.format("image/jester_pig_anim/run/run_%02d.png", i)
end
local jesterRunFrames = {}   -- nvgCreateImage 句柄数组(8帧)
local JESTER_RUN_FPS = 14    -- 奔跑动画帧率(比走路快)

-- 小丑猪(avatarIdx=1)喝药动画帧路径(16帧循环)
local JESTER_DRINK_FRAME_PATHS = {}
for i = 1, 16 do
    JESTER_DRINK_FRAME_PATHS[i] = string.format("image/jester_pig_anim/drink/drink_%02d.png", i)
end
local jesterDrinkFrames = {} -- nvgCreateImage 句柄数组(16帧)
local JESTER_DRINK_FPS = 10  -- 喝药动画帧率

-- 小丑猪(avatarIdx=1)打击动画帧路径(8帧)
local JESTER_ATTACK_FRAME_PATHS = {}
for i = 1, 8 do
    JESTER_ATTACK_FRAME_PATHS[i] = string.format("image/jester_pig_anim/attack/attack_%02d.png", i)
end
local jesterAttackFrames = {} -- nvgCreateImage 句柄数组(8帧)
local JESTER_ATTACK_FPS = 16  -- 打击动画帧率(快速播放)

-- 小丑猪(avatarIdx=1)受击动画帧路径(8帧)
local JESTER_HURT_FRAME_PATHS = {}
for i = 1, 8 do
    JESTER_HURT_FRAME_PATHS[i] = string.format("image/jester_pig_anim/hurt/hurt_%02d.png", i)
end
local jesterHurtFrames = {} -- nvgCreateImage 句柄数组(8帧)
local JESTER_HURT_FPS = 16  -- 受击动画帧率(快速播放)
-- 战士猪(avatarIdx=2)走路动画帧路径(8帧循环)
local WARRIOR_WALK_FRAME_PATHS = {}
for i = 1, 8 do
    WARRIOR_WALK_FRAME_PATHS[i] = string.format("image/warrior_pig_anim/walk/walk_%02d.png", i)
end
local warriorWalkFrames = {}  -- nvgCreateImage 句柄数组(8帧)
local WARRIOR_WALK_FPS = 10   -- 走路动画帧率

-- 战士猪(avatarIdx=2)待机动画帧路径(4帧循环)
local WARRIOR_IDLE_FRAME_PATHS = {}
for i = 1, 4 do
    WARRIOR_IDLE_FRAME_PATHS[i] = string.format("image/warrior_pig_anim/idle/idle_%02d.png", i)
end
local warriorIdleFrames = {}  -- nvgCreateImage 句柄数组(4帧)
local WARRIOR_IDLE_FPS = 6    -- 待机动画帧率(较慢，悠闲感)

-- 科学家猪(avatarIdx=3)走路动画帧路径(8帧循环)
local SCIENTIST_WALK_FRAME_PATHS = {}
for i = 1, 8 do
    SCIENTIST_WALK_FRAME_PATHS[i] = string.format("image/scientist_pig_anim/walk/walk_%02d.png", i)
end
local scientistWalkFrames = {}  -- nvgCreateImage 句柄数组(8帧)
local SCIENTIST_WALK_FPS = 10   -- 走路动画帧率

-- 矿工猪(avatarIdx=4)走路动画帧路径(16帧循环)
local MINER_WALK_FRAME_PATHS = {}
for i = 1, 16 do
    MINER_WALK_FRAME_PATHS[i] = string.format("image/miner_pig_anim/walk/walk_%02d.png", i)
end
local minerWalkFrames = {}   -- nvgCreateImage 句柄数组(16帧)
local MINER_WALK_FPS = 12    -- 走路动画帧率

-- 矿工猪(avatarIdx=4)打击动画帧路径(8帧)
local MINER_ATTACK_FRAME_PATHS = {}
for i = 1, 8 do
    MINER_ATTACK_FRAME_PATHS[i] = string.format("image/miner_pig_anim/attack/attack_%02d.png", i)
end
local minerAttackFrames = {} -- nvgCreateImage 句柄数组(8帧)
local MINER_ATTACK_FPS = 16  -- 打击动画帧率(快速播放)

-- 矿工猪(avatarIdx=4)待机动画帧路径(8帧循环)
local MINER_IDLE_FRAME_PATHS = {}
for i = 1, 8 do
    MINER_IDLE_FRAME_PATHS[i] = string.format("image/miner_pig_anim/idle/idle_%02d.png", i)
end
local minerIdleFrames = {}   -- nvgCreateImage 句柄数组(8帧)
local MINER_IDLE_FPS = 8     -- 待机动画帧率(较慢,呼吸感)

-- 盗贼猪(avatarIdx=5)走路动画帧路径(8帧循环)
local THIEF_WALK_FRAME_PATHS = {}
for i = 1, 8 do
    THIEF_WALK_FRAME_PATHS[i] = string.format("image/thief_pig_anim/walk/walk_%02d.png", i)
end
local thiefWalkFrames = {}   -- nvgCreateImage 句柄数组(8帧)
local THIEF_WALK_FPS = 10    -- 走路动画帧率

local GHOST_IMAGE_PATH = "image/Image 17.png"
local CURSOR_IMAGE_PATH = "image/ui/鼠标.png"
local cursorImage = nil  -- 自定义鼠标光标NVG句柄
local ghostImage = nil  -- 鬼魂图片句柄
local potionNvgImages = {}  -- {victory=handle, antidote=handle, poison=handle}
local POTION_IMAGE_PATHS = {
    victory = "image/游戏道具/胜利药水.png",
    antidote = "image/游戏道具/解药.png",
    poison = "image/游戏道具/毒药.png",
}

-- 环境装饰素材图片(饥荒风手绘)
local DECO_TREE_PATHS = {
    "image/资产绿植/xs1.png",  -- 猪头树
    "image/资产绿植/xs2.png",  -- 枯树红花
}
local DECO_ROCK_PATHS = {
    "image/资产绿植/s2.png",   -- 散落碎石
    "image/资产绿植/s3.png",   -- 大圆石
    "image/资产绿植/s4.png",   -- 高角岩
    "image/资产绿植/s5.png",   -- 扁平石板
    "image/资产绿植/s6.png",   -- 棱角碎石
}
local DECO_FLOWER_PATHS = {
    "image/资产绿植/h1.png",   -- 玫瑰
    "image/资产绿植/h2.png",   -- 郁金香
    "image/资产绿植/h3.png",   -- 蓟花
    "image/资产绿植/h4.png",   -- 向日葵
}
local DECO_PLANT_PATHS = {
    "image/资产绿植/1.png",    -- 高草
    "image/资产绿植/2.png",    -- 浆果藤蔓
    "image/资产绿植/3.png",    -- 枯灌木
}
local decoTreeImages = {}    -- nvgCreateImage 句柄数组
local decoRockImages = {}
local decoFlowerImages = {}
local decoPlantImages = {}

-- 关卡编辑器
local LevelEditor = require("TileMap.LevelEditor")
---@type table|nil
local levelEditor = nil  -- 在 Start() 中初始化
local editorSpawnConfig = nil  -- 编辑器出生点配置(应用后生效)

-- 地形贴图(饥荒风格)
local TERRAIN_PATHS = {
    -- 基础地形
    grass       = "image/地皮/terrain_grass_20260530170030.png",
    swamp       = "image/地皮/terrain_swamp_20260530165947.png",
    mud         = "image/地皮/terrain_mud_20260530165944.png",
    rocky       = "image/地皮/terrain_rocky_20260530165943.png",
    volcanic    = "image/地皮/terrain_volcanic_20260530165940.png",
    dead_grass  = "image/地皮/terrain_dead_grass_20260530170619.png",
    forest      = "image/地皮/terrain_forest_floor_20260530170620.png",
    sand        = "image/地皮/terrain_sand_20260530170620.png",
    snow        = "image/地皮/terrain_snow_20260530170624.png",
    cobblestone = "image/地皮/terrain_cobblestone_20260530170621.png",
    -- 过渡贴图(左右)
    grass_sand_lr      = "image/地皮/terrain_grass_sand_lr_20260530170624.png",
    grass_deadgrass_lr = "image/地皮/terrain_grass_deadgrass_lr_20260530170623.png",
    grass_rocky_lr     = "image/地皮/terrain_grass_rocky_lr_20260530170407.png",
    grass_swamp_lr     = "image/地皮/terrain_grass_swamp_lr_20260530170402.png",
    mud_rocky_lr       = "image/地皮/terrain_mud_rocky_lr_20260530170405.png",
    mud_swamp_lr       = "image/地皮/terrain_mud_swamp_lr_20260530170404.png",
    -- 过渡贴图(上下)
    grass_snow_tb      = "image/地皮/terrain_grass_snow_tb_20260530170622.png",
    grass_rocky_tb     = "image/地皮/terrain_grass_rocky_tb_20260530170412.png",
    grass_mud_tb       = "image/地皮/terrain_grass_mud_tb_20260530170406.png",
    mud_swamp_tb       = "image/地皮/terrain_mud_swamp_tb_20260530170405.png",
    rocky_volcanic_tb  = "image/地皮/terrain_rocky_volcanic_tb_20260530170414.png",
    -- 角落贴图
    corner_grass_in_mud_bl      = "image/地皮/terrain_corner_grass_in_mud_bl_20260530170523.png",
    corner_grass_in_mud_br      = "image/地皮/terrain_corner_grass_in_mud_br_20260530170508.png",
    corner_grass_in_mud_tl      = "image/地皮/terrain_corner_grass_in_mud_tl_20260530170508.png",
    corner_grass_in_mud_tr      = "image/地皮/terrain_corner_grass_in_mud_tr_20260530170512.png",
    corner_grass_in_swamp_tl    = "image/地皮/terrain_corner_grass_in_swamp_tl_20260530170508.png",
    corner_grass_in_swamp_tr    = "image/地皮/terrain_corner_grass_in_swamp_tr_20260530170508.png",
    corner_rocky_in_volcanic_tl = "image/地皮/terrain_corner_rocky_in_volcanic_tl_20260530170512.png",
    corner_rocky_in_volcanic_tr = "image/地皮/terrain_corner_rocky_in_volcanic_tr_20260530170512.png",
    -- 混合/渐变贴图
    grass_to_mud       = "image/地皮/terrain_grass_to_mud_20260530165951.png",
    grass_to_swamp     = "image/地皮/terrain_grass_to_swamp_20260530165942.png",
    rocky_to_volcanic  = "image/地皮/terrain_rocky_to_volcanic_20260530165943.png",
}
local terrainImages = {}  -- { name = nvgImageHandle }

local function initPlayers()
    players = {}
    -- 编辑器出生点配置优先
    local cx, cy, spawnRadius
    if editorSpawnConfig then
        cx = editorSpawnConfig.cx
        cy = editorSpawnConfig.cy
        spawnRadius = editorSpawnConfig.radius
    else
        cx = CONFIG.MapSize / 2
        cy = CONFIG.MapSize / 2
        spawnRadius = CONFIG.MapSize * 0.35
    end

    -- 随机打乱角色图片分配(Fisher-Yates shuffle)
    local avatarOrder = {}
    for i = 1, CONFIG.PlayerCount do
        avatarOrder[i] = i
    end
    for i = CONFIG.PlayerCount, 2, -1 do
        local j = math.random(1, i)
        avatarOrder[i], avatarOrder[j] = avatarOrder[j], avatarOrder[i]
    end

    for i = 1, CONFIG.PlayerCount do
        local angle = (i - 1) * (2 * math.pi / CONFIG.PlayerCount) - math.pi / 2
        local px = cx + math.cos(angle) * spawnRadius
        local py = cy + math.sin(angle) * spawnRadius
        local p = createPlayer(i, px, py, i == localPlayerIdx)
        p.color = PLAYER_COLORS[i]
        p.avatarIdx = avatarOrder[i]  -- 随机分配猪角色图片
        players[i] = p
    end
end

-- ============================================================================
-- 游戏逻辑
-- ============================================================================

local function getAliveCount()
    local count = 0
    for i = 1, #players do
        if players[i].alive then count = count + 1 end
    end
    return count
end

-- 辅助: 生成死亡纸片+污渍效果
local function spawnDeathEffect(playerIdx)
    local p = players[playerIdx]
    if not p then return end
    local pieceCount = 5 + math.random(0, 3)
    local pColor = p.color
    for j = 1, pieceCount do
        local angle = (j / pieceCount) * math.pi * 2 + (math.random() - 0.5) * 0.5
        local speed = 60 + math.random() * 80
        table.insert(deathPieces, {
            x = p.x + (math.random() - 0.5) * 10,
            y = p.y - 20 + (math.random() - 0.5) * 15,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 30,
            rot = math.random() * math.pi * 2,
            rotV = (math.random() - 0.5) * 8,
            w = 8 + math.random() * 6,
            h = 6 + math.random() * 5,
            life = 2.0,
            color = {pColor[1], pColor[2], pColor[3]},
        })
    end
    table.insert(deathStains, {
        x = p.x,
        y = p.y,
        alpha = 180,
    })
end

-- 3.1 准备阶段(仅开局一次, 10s, 只能移动)
local function enterPrepare()
    gamePhase = "prepare"
    phaseTimer = CONFIG.PrepareDuration
    isFirstRound = true
    currentRound = 0
    print("=== 准备阶段! 黑夜即将降临... " .. CONFIG.PrepareDuration .. "s ===")
end

-- 白天阶段(60s, 主要战斗时间)
local function enterDay()
    gamePhase = "day"
    phaseTimer = CONFIG.DayDuration

    -- 胜利药水已发放时不进入新一轮(等待玩家喝药)
    if victoryPotionGiven then
        print("=== 胜利药水阶段, 等待喝下... ===")
        phaseTimer = 30
        return
    end

    currentRound = currentRound + 1
    if currentRound > CONFIG.TotalRounds then
        local aliveCount = getAliveCount()
        if aliveCount > 0 and not victoryPotionGiven then
            -- 最大轮数到达, 给所有存活者中最后一人发胜利药水
            for i = 1, #players do
                if players[i].alive then
                    victoryWinnerIdx = i
                    players[i].potionState = "victory"
                    players[i].poison = 0
                    victoryPotionGiven = true
                    table.insert(statusEffects, { playerIdx = i, type = "detox", timer = 3.0 })
                    print("=== 最终轮! 玩家 " .. i .. " 获得胜利药水! ===")
                    break
                end
            end
            phaseTimer = 30
        elseif aliveCount == 0 then
            gamePhase = "defeat"
        end
        return
    end

    -- 每轮白天开始: 全员+30毒, 旧解药变毒, 50%发解药
    -- 5.4 旧解药变毒药 + 固定+30毒
    for i = 1, #players do
        if players[i].alive then
            if players[i].potionState == "antidote" then
                players[i].potionState = "poison"
                players[i].poison = clamp(players[i].poison + CONFIG.PoisonPerRound, CONFIG.PoisonMin, CONFIG.PoisonMax)
                print("玩家 " .. i .. " 解药变为毒药! +30毒")
                if players[i].isLocal then playSound("sfx_antidote_to_poison", 0.7) end
                table.insert(statusEffects, { playerIdx = i, type = "transform", timer = 1.5 })
                table.insert(floatingTexts, {
                    x = players[i].x, y = players[i].y - 30,
                    text = "+30毒(变质)", color = {180, 60, 200},
                    timer = 1.2, maxTimer = 1.2,
                })
            end
            players[i].poison = clamp(players[i].poison + CONFIG.PoisonPerRound, CONFIG.PoisonMin, CONFIG.PoisonMax)
            players[i].drinkingState = "idle"
            players[i].drinkingTimer = 0
            players[i].drinkingType = nil
        end
    end

    -- 5.4 地面未拾取的解药变为地面毒药
    for i = 1, #groundPotions do
        if groundPotions[i].type == "antidote" then
            groundPotions[i].type = "poison"
            print("地面解药变为毒药!")
        end
    end

    -- 5.1 50%存活玩家获得解药(向上取整)
    local aliveList = {}
    for i = 1, #players do
        if players[i].alive then table.insert(aliveList, i) end
    end
    for i = #aliveList, 2, -1 do
        local j = math.random(1, i)
        aliveList[i], aliveList[j] = aliveList[j], aliveList[i]
    end
    local giveCount = math.ceil(#aliveList * CONFIG.AntidoteRatio)
    for k = 1, giveCount do
        local idx = aliveList[k]
        players[idx].potionState = "antidote"
        table.insert(pickupGlows, { playerIdx = idx, type = "antidote", timer = 1.5, maxTimer = 1.5 })
        if players[idx].isLocal then playSound("sfx_antidote_get", 0.7) end
        print("玩家 " .. idx .. " 获得解药!")
    end

    -- 清除本轮地面药剂
    groundPotions = {}

    print("=== 第 " .. currentRound .. " 轮 白天开始! 全员+30毒, " .. giveCount .. "人获得解药, " .. CONFIG.DayDuration .. "s 战斗 ===")
end

-- 3.2/3.3 已废弃: nightfall阶段已合并到enterSettle()的countdown子阶段

-- 3.4 黑夜结算(先5s黑屏倒计时, 再3s淘汰展示)
local function enterSettle()
    gamePhase = "settle"
    settleSubPhase = "countdown"
    phaseTimer = CONFIG.NightfallDuration  -- 5s倒计时
    countdownLastSecond = -1  -- 重置倒计时音效追踪
    settleDeaths = {}
    isFirstRound = false

    -- 强制停止所有玩家
    for i = 1, #players do
        players[i].vx = 0
        players[i].vy = 0
    end

    playSound("sfx_night_transition", 0.9)  -- 画面切换音效
    playSound("sfx_nightfall", 0.8)

    -- 黑夜倒计时专属音乐
    if bgmSource then
        local nightBgm = cache:GetResource("Sound", "audio/游戏音乐/黑夜倒计时.ogg")
        if nightBgm then
            nightBgm.looped = false
            bgmSource:Play(nightBgm)
            bgmCurrentIdx = 0  -- 标记为特殊曲目,播完后恢复播放列表
        end
    end

    print("=== 黑夜降临! " .. CONFIG.NightfallDuration .. "s 黑屏倒计时 ===")
end

-- 倒计时结束后执行淘汰逻辑
local function enterSettleElimination()
    settleSubPhase = "elimination"
    phaseTimer = CONFIG.SettleDuration  -- 3s淘汰展示

    playSound("sfx_settle_kill", 0.7)

    -- 淘汰毒素最高的玩家（仅淘汰一人）
    local maxPoison = 0
    local maxIdx = nil
    for i = 1, #players do
        if players[i].alive and players[i].poison > maxPoison then
            maxPoison = players[i].poison
            maxIdx = i
        end
    end
    if maxIdx then
        players[maxIdx].alive = false
        players[maxIdx].isGhost = true
        players[maxIdx].vx = 0
        players[maxIdx].vy = 0
        table.insert(settleDeaths, maxIdx)
        spawnDeathEffect(maxIdx)
        print("玩家 " .. maxIdx .. " 毒素最高(" .. math.floor(players[maxIdx].poison) .. "), 被淘汰!")
    end

    -- 存活者提示"存活"
    if #settleDeaths > 0 then
        for i = 1, #players do
            if players[i].alive then
                table.insert(statusEffects, { playerIdx = i, type = "detox", timer = 2.0 })
            end
        end
    end

    -- 检查胜利/失败条件
    local aliveCount = getAliveCount()
    if aliveCount == 0 then
        -- 全员死亡 → 失败
        gamePhase = "defeat"
        print("=== 全员阵亡! 游戏失败! ===")
        return
    elseif aliveCount == 1 and not victoryPotionGiven then
        -- 最后1人存活 → 发放胜利药水
        for i = 1, #players do
            if players[i].alive then
                victoryWinnerIdx = i
                players[i].potionState = "victory"
                players[i].poison = 0  -- 清除毒素
                victoryPotionGiven = true
                table.insert(statusEffects, { playerIdx = i, type = "detox", timer = 3.0 })
                print("=== 玩家 " .. i .. " 获得胜利药水! ===")
                break
            end
        end
    end

    print("=== 黑夜结算! " .. #settleDeaths .. "人死亡, " .. aliveCount .. "人存活 ===")
end

-- 7.1 舒适区生成(距离约束: 300px离玩家出生点, 400px彼此分离)
local function generateComfortZones(cx, cy, safeRadius)
    local zoneTypes = {"campfire", "spring", "altar"}
    local zoneCount = math.random(1, 2)  -- 每轮1-2个
    local maxAttempts = 50

    for i = 1, zoneCount do
        local placed = false
        for attempt = 1, maxAttempts do
            local angle = math.random() * math.pi * 2
            local r = math.random() * (safeRadius - CONFIG.ComfortZoneRadius) * 0.8
            local zx = cx + math.cos(angle) * r
            local zy = cy + math.sin(angle) * r

            -- 约束1: 距离所有玩家出生点>=300px
            local tooCloseToSpawn = false
            for _, p in ipairs(players) do
                if not p.isGhost then
                    local spawnCX = CONFIG.MapSize / 2
                    local spawnCY = CONFIG.MapSize / 2
                    local spawnR = CONFIG.MapSize * 0.35
                    local spawnAngle = (p.idx - 1) * (2 * math.pi / CONFIG.PlayerCount) - math.pi / 2
                    local spX = spawnCX + math.cos(spawnAngle) * spawnR
                    local spY = spawnCY + math.sin(spawnAngle) * spawnR
                    if dist(zx, zy, spX, spY) < CONFIG.ComfortZoneMinSpawnDist then
                        tooCloseToSpawn = true
                        break
                    end
                end
            end
            if tooCloseToSpawn then goto continue end

            -- 约束2: 距离已生成的舒适区>=400px
            local tooCloseToOther = false
            for _, existing in ipairs(comfortZones) do
                if dist(zx, zy, existing.x, existing.y) < CONFIG.ComfortZoneSeparation then
                    tooCloseToOther = true
                    break
                end
            end
            if tooCloseToOther then goto continue end

            -- 约束3: 在安全区内
            if dist(zx, zy, cx, cy) > safeRadius - CONFIG.ComfortZoneRadius * 0.5 then
                goto continue
            end

            -- 通过所有约束, 放置舒适区
            table.insert(comfortZones, {
                x = zx, y = zy,
                type = zoneTypes[math.random(1, 3)],
                playersInside = {},
                zoneEnergy = 100,     -- 舒适区能量(最大100)
                zoneCooldown = 0,     -- 冷却倒计时(秒)
                zoneUsesLeft = 5,     -- 剩余可用次数
            })
            placed = true
            break

            ::continue::
        end
        -- 如果50次尝试都失败, 放宽条件随机放置
        if not placed then
            local angle = math.random() * math.pi * 2
            local r = math.random() * safeRadius * 0.5
            table.insert(comfortZones, {
                x = cx + math.cos(angle) * r,
                y = cy + math.sin(angle) * r,
                type = zoneTypes[math.random(1, 3)],
                playersInside = {},
                zoneEnergy = 100,
                zoneCooldown = 0,
                zoneUsesLeft = 5,
            })
        end
    end
    print("[舒适区] 生成 " .. #comfortZones .. " 个舒适区")
end

-- 9.1 缩圈过渡(3s, 毒圈收缩25%, 舒适区失效判定)
local function enterShrinking()
    gamePhase = "shrinking"
    phaseTimer = CONFIG.CircleShrinkDuration  -- 1秒过渡(缩圈在下一轮day阶段渐进完成)
    playSound("sfx_circle_shrink", 0.6)

    -- 计算下一轮目标半径(供舒适区腐化判断用)
    local nextTargetRadius = circle.radius * CONFIG.CircleShrinkRatio

    -- 9.4 标记下一轮毒圈外的舒适区为腐败状态(光效熄灭, 无法回复能量)
    for _, zone in ipairs(comfortZones) do
        local dToCenter = dist(zone.x, zone.y, circle.cx, circle.cy)
        if dToCenter > nextTargetRadius then
            zone.corrupted = true
        end
    end

    -- 在新安全区内补充新舒适区(反转机制: 前期少, 后期多)
    -- 第1轮不刷新; 第2轮只刷1个; 第3轮及以后补到3个
    local maxZonesThisRound = 3
    if currentRound <= 1 then
        maxZonesThisRound = 0
    elseif currentRound == 2 then
        maxZonesThisRound = 1
    end

    -- 每轮初始使用次数递增: 第1轮1次, 第2轮2次, 第3轮3次, 第4轮4次, 第5轮5次
    local roundUses = math.min(5, currentRound)

    local activeCount = 0
    for _, zone in ipairs(comfortZones) do
        if not zone.corrupted then activeCount = activeCount + 1 end
    end
    -- 补充舒适区到目标数量
    if maxZonesThisRound > 0 and activeCount < maxZonesThisRound then
        comfortFloats = {}
        local needed = maxZonesThisRound - activeCount
        for _ = 1, needed do
            local placed = false
            for attempt = 1, 50 do
                local angle = math.random() * math.pi * 2
                local r = math.random() * nextTargetRadius * 0.7
                local zx = circle.cx + math.cos(angle) * r
                local zy = circle.cy + math.sin(angle) * r
                -- 距离现有舒适区足够远
                local tooClose = false
                for _, existing in ipairs(comfortZones) do
                    if not existing.corrupted and dist(zx, zy, existing.x, existing.y) < CONFIG.ComfortZoneSeparation then
                        tooClose = true
                        break
                    end
                end
                if not tooClose then
                    local zoneTypes = {"campfire", "spring", "altar"}
                    table.insert(comfortZones, {
                        x = zx, y = zy,
                        type = zoneTypes[math.random(1, 3)],
                        playersInside = {},
                        corrupted = false,
                        zoneEnergy = 100,
                        zoneCooldown = 0,
                        zoneUsesLeft = roundUses,
                    })
                    placed = true
                    break
                end
            end
            if not placed then
                -- 放宽条件
                local angle = math.random() * math.pi * 2
                local r = math.random() * nextTargetRadius * 0.5
                local zoneTypes = {"campfire", "spring", "altar"}
                table.insert(comfortZones, {
                    x = circle.cx + math.cos(angle) * r,
                    y = circle.cy + math.sin(angle) * r,
                    type = zoneTypes[math.random(1, 3)],
                    playersInside = {},
                    corrupted = false,
                    zoneEnergy = 100,
                    zoneCooldown = 0,
                    zoneUsesLeft = roundUses,
                })
            end
        end
    end

    -- 设置缩圈目标(实际缩圈在下一轮day阶段60秒内渐进完成)
    circle.targetRadius = nextTargetRadius
    circle.shrinkSpeed = (circle.radius - circle.targetRadius) / CONFIG.DayDuration

    print("=== 缩圈过渡! 半径: " .. math.floor(circle.radius) .. " → " .. math.floor(nextTargetRadius) .. " (将在下轮60s内完成) ===")
end

-- 前向声明(供resolveAttackHit引用)
local interruptDrinking
local interruptInteract

-- 4.3 攻击判定(前摇结束后调用)
local function resolveAttackHit(attacker)
    local halfAngle = math.rad(CONFIG.AttackAngle / 2)
    local hitAny = false

    for i = 1, #players do
        local target = players[i]
        -- 已占领并使用中的玩家免疫攻击, 但正在占领中(isCapturingZone)的可以被打
        if target.idx ~= attacker.idx and target.alive and not target.usingComfortZone then
            local d = dist(attacker.x, attacker.y, target.x, target.y)
            if d <= CONFIG.AttackRange then
                local angleToTarget = angleBetween(attacker.x, attacker.y, target.x, target.y)
                local angleDiff = normalizeAngle(angleToTarget - attacker.facing)
                if math.abs(angleDiff) <= halfAngle then
                    -- 命中! 4.3: 自身-15毒, 目标+10毒
                    -- 毒满暴走buff: 毒素转移和能量掠夺翻倍
                    local buffMult = attacker.poisonMaxBuff and 2 or 1
                    local poisonAdd = CONFIG.AttackPoisonAdd * buffMult
                    local energySteal = CONFIG.EnergyStealOnHit * buffMult

                    -- 6.3: 掠夺目标能量(不超过目标剩余)
                    attacker.poison = clamp(attacker.poison - CONFIG.AttackPoisonReduce, CONFIG.PoisonMin, CONFIG.PoisonMax)
                    target.poison = clamp(target.poison + poisonAdd, CONFIG.PoisonMin, CONFIG.PoisonMax)
                    local stealAmount = math.min(energySteal, target.energy)
                    target.energy = clamp(target.energy - stealAmount, CONFIG.EnergyMin, CONFIG.EnergyMax)
                    attacker.energy = clamp(attacker.energy + stealAmount, CONFIG.EnergyMin, CONFIG.EnergyMax)
                    target.hitFlash = 0.3
                    hitAny = true
                    if attacker.isLocal or target.isLocal then playSound("sfx_attack_hit", 0.6) end

                    -- 5.3/5.5 检查是否打断喝药
                    interruptDrinking(target, attacker.idx)

                    -- 8.4 检查是否打断交互
                    interruptInteract(target)

                    -- 打断舒适区占领(正在占领中的玩家被攻击,重置占领进度)
                    if target.isCapturingZone then
                        target.isCapturingZone = false
                        target.comfortStandTimer = 0
                        local zi = target.currentComfortZoneIdx
                        if zi and target.comfortClaims and target.comfortClaims[zi] then
                            target.comfortClaims[zi].claimTimer = 0
                        end
                        if target.isLocal then
                            table.insert(floatingTexts, {
                                x = target.x, y = target.y - 50,
                                text = "占领被打断!",
                                color = {255, 100, 100},
                                timer = 1.0, maxTimer = 1.0,
                            })
                        end
                    end

                    -- 状态特效: 目标中毒, 攻击者减毒
                    table.insert(statusEffects, { playerIdx = target.idx, type = "poison", timer = 1.0 })
                    table.insert(statusEffects, { playerIdx = attacker.idx, type = "detox", timer = 0.8 })

                    -- 4.3 浮动文字: 显示实际数值(暴走时翻倍)
                    local poisonText = "+" .. poisonAdd .. "毒"
                    if attacker.poisonMaxBuff then poisonText = poisonText .. "(暴走!)" end
                    table.insert(floatingTexts, {
                        x = target.x, y = target.y - 30,
                        text = poisonText, color = {220, 50, 50},
                        timer = 1.0, maxTimer = 1.0,
                    })
                    table.insert(floatingTexts, {
                        x = attacker.x, y = attacker.y - 30,
                        text = "-15毒", color = {50, 200, 80},
                        timer = 1.0, maxTimer = 1.0,
                    })

                    -- 4.3 屏幕震动0.1秒
                    screenShake.timer = 0.1
                    screenShake.intensity = 4

                    -- 4.3 命中黑色墨汁粒子(溅射)
                    for j = 1, 8 do
                        table.insert(particles, {
                            x = target.x,
                            y = target.y,
                            vx = (math.random() - 0.5) * 200,
                            vy = (math.random() - 0.5) * 200,
                            life = 0.6,
                            color = {20, 20, 30},  -- 黑色墨汁
                        })
                    end
                    print("玩家 " .. attacker.idx .. " 命中玩家 " .. target.idx)
                end
            end
        end
    end
    return hitAny
end

-- 4.3 发起攻击(进入前摇)
local function performAttack(attacker)
    -- 只能在黑夜进行中阶段攻击
    if gamePhase ~= "day" then return end
    -- 5.2 喝药/硬直期间不能攻击
    if attacker.drinkingState ~= "idle" then return end
    -- 8.1 交互期间不能攻击
    if attacker.interactState ~= "idle" then return end
    if attacker.energy < CONFIG.AttackCostEnergy then return end
    if attacker.attackCooldown > 0 then return end
    if attacker.attackState ~= "idle" then return end

    -- 消耗能量, 进入前摇
    attacker.energy = attacker.energy - CONFIG.AttackCostEnergy
    attacker.attackCooldown = CONFIG.AttackCooldown
    attacker.attacking = true
    attacker.attackState = "windup"
    attacker.attackStateTimer = CONFIG.AttackWindup
    attacker.attackTimer = CONFIG.AttackWindup
    if attacker.isLocal then playSound("sfx_attack_swing", 0.5) end

    -- 前摇开始时的墨水拖尾特效(举臂)
    table.insert(attackEffects, {
        x = attacker.x,
        y = attacker.y,
        angle = attacker.facing,
        timer = CONFIG.AttackWindup + CONFIG.AttackRecovery,
        phase = "windup",
    })
end

-- 4.3 攻击状态更新(每帧在updatePlayers中调用)
local function updateAttackState(p, dt)
    if p.attackState == "windup" then
        p.attackStateTimer = p.attackStateTimer - dt
        if p.attackStateTimer <= 0 then
            -- 前摇结束 → 执行判定 → 进入后摇
            resolveAttackHit(p)
            p.attackState = "recovery"
            p.attackStateTimer = CONFIG.AttackRecovery

            -- 判定时刻的弧线特效
            table.insert(attackEffects, {
                x = p.x,
                y = p.y,
                angle = p.facing,
                timer = CONFIG.AttackRecovery,
                phase = "slash",
            })
        end
    elseif p.attackState == "recovery" then
        p.attackStateTimer = p.attackStateTimer - dt
        -- 后摇期间不能移动
        p.vx = 0
        p.vy = 0
        if p.attackStateTimer <= 0 then
            p.attackState = "idle"
            p.attacking = false
        end
    end
end

-- ============================================================================
-- 5.2-5.5 喝药系统
-- ============================================================================

-- 5.2 开始喝药(进入读条状态)
local function startDrinking(p, potionType)
    -- 胜利药水可在任何阶段喝(day/shrinking等)
    if potionType ~= "victory" and gamePhase ~= "day" then return false end
    if not p.alive then return false end
    if p.drinkingState ~= "idle" then return false end
    if p.attackState ~= "idle" then return false end
    if p.potionState ~= potionType then return false end
    -- 6.1 喝药前提: 能量>=10(胜利药水免费)
    if potionType ~= "victory" and p.energy < CONFIG.DrinkCostEnergy then return false end

    -- 6.1 扣除喝药能量(胜利药水不消耗)
    if potionType ~= "victory" then
        p.energy = p.energy - CONFIG.DrinkCostEnergy
    end
    p.drinkingState = "drinking"
    p.drinkingTimer = potionType == "victory" and 1.0 or CONFIG.DrinkDuration
    p.drinkingType = potionType
    -- 喝药期间不能移动/攻击
    p.vx = 0
    p.vy = 0
    if p.isLocal then playSound("sfx_drink_start", 0.5) end
    local typeName = potionType == "antidote" and "解药" or (potionType == "victory" and "胜利药水" or "毒药")
    print("玩家 " .. p.idx .. " 开始喝" .. typeName .. "!")
    return true
end

-- 5.3 打断喝药(被攻击命中时调用)
interruptDrinking = function(target, attackerIdx)
    if target.drinkingState ~= "drinking" then return false end

    local wasType = target.drinkingType

    -- 中断读条
    target.drinkingState = "stunned"
    target.drinkingTimer = CONFIG.DrinkStunDuration
    target.drinkingType = nil

    if target.isLocal then playSound("sfx_drink_interrupt", 0.6) end

    if wasType == "antidote" then
        -- 5.3 解药掉落至地面
        target.potionState = nil
        table.insert(groundPotions, {
            x = target.x + (math.random() - 0.5) * 30,
            y = target.y + (math.random() - 0.5) * 20,
            type = "antidote",
            timer = 999,  -- 持续到本轮黑夜结束
        })
        table.insert(floatingTexts, {
            x = target.x, y = target.y - 40,
            text = "打断! 解药掉落!", color = {100, 180, 255},
            timer = 1.2, maxTimer = 1.2,
        })
        print("玩家 " .. target.idx .. " 喝解药被打断! 解药掉落地面!")

    elseif wasType == "poison" then
        -- 5.5 毒药转移给攻击者
        target.potionState = nil
        local attacker = players[attackerIdx]
        if attacker and attacker.alive then
            attacker.potionState = "poison"
            attacker.poison = clamp(attacker.poison + CONFIG.DrinkInterruptPoisonTransfer, CONFIG.PoisonMin, CONFIG.PoisonMax)
            table.insert(floatingTexts, {
                x = attacker.x, y = attacker.y - 40,
                text = "+30毒(转移)!", color = {180, 60, 200},
                timer = 1.2, maxTimer = 1.2,
            })
            if attacker.isLocal then playSound("sfx_poison_transfer", 0.7) end
            print("玩家 " .. target.idx .. " 喝毒药被打断! 毒药转移给玩家 " .. attackerIdx .. "!")
        end
        table.insert(floatingTexts, {
            x = target.x, y = target.y - 40,
            text = "毒药转移!", color = {120, 255, 120},
            timer = 1.2, maxTimer = 1.2,
        })
    end

    -- 屏幕震动
    screenShake.timer = 0.15
    screenShake.intensity = 5
    return true
end

-- 5.2 喝药状态每帧更新
local function updateDrinkingState(p, dt)
    if p.drinkingState == "drinking" then
        p.drinkingTimer = p.drinkingTimer - dt
        -- 喝药期间强制不动
        p.vx = 0
        p.vy = 0
        if p.drinkingTimer <= 0 then
            -- 读条完成
            if p.drinkingType == "antidote" then
                -- 5.2 解药: 毒药值清零, 解药状态移除
                p.poison = CONFIG.PoisonMin
                p.potionState = nil
                table.insert(floatingTexts, {
                    x = p.x, y = p.y - 30,
                    text = "解毒成功!", color = {80, 220, 255},
                    timer = 1.0, maxTimer = 1.0,
                })
                table.insert(pickupGlows, { playerIdx = p.idx, type = "antidote", timer = 1.5, maxTimer = 1.5 })
                if p.isLocal then playSound("sfx_drink_complete", 0.7) end
                print("玩家 " .. p.idx .. " 成功喝下解药! 毒素清零!")
            elseif p.drinkingType == "poison" then
                -- 5.5 喝毒药成功: 毒药值+100, 立即死亡
                p.poison = clamp(p.poison + CONFIG.PoisonDrinkAmount, CONFIG.PoisonMin, CONFIG.PoisonMax)
                p.potionState = nil
                table.insert(floatingTexts, {
                    x = p.x, y = p.y - 30,
                    text = "+100毒! 毒发!", color = {255, 0, 0},
                    timer = 1.2, maxTimer = 1.2,
                })
                print("玩家 " .. p.idx .. " 成功喝下毒药! 毒发身亡!")
                -- 即时死亡(在updatePlayers中通过poison>=100检测触发)
            elseif p.drinkingType == "victory" then
                -- 胜利药水: 触发胜利!
                p.potionState = nil
                victoryWinnerIdx = p.idx
                gamePhase = "victory"
                playSound("sfx_nightfall", 1.0)  -- 用现有音效替代
                local hud = uiRoot_:FindById("hudPanel")
                if hud then hud:SetVisible(false) end
                table.insert(floatingTexts, {
                    x = p.x, y = p.y - 30,
                    text = "胜利!", color = {255, 215, 0},
                    timer = 2.0, maxTimer = 2.0,
                })
                print("=== 玩家 " .. p.idx .. " 喝下胜利药水! 游戏胜利! ===")
            end
            p.drinkingState = "idle"
            p.drinkingTimer = 0
            p.drinkingType = nil
        end
    elseif p.drinkingState == "stunned" then
        p.drinkingTimer = p.drinkingTimer - dt
        -- 硬直期间不能移动
        p.vx = 0
        p.vy = 0
        if p.drinkingTimer <= 0 then
            p.drinkingState = "idle"
            p.drinkingTimer = 0
        end
    end
end

-- 5.3 更新地面药剂(拾取检测)
local function updateGroundPotions(dt)
    local i = 1
    while i <= #groundPotions do
        local gp = groundPotions[i]
        local picked = false
        -- 检测存活玩家是否在拾取范围内
        for pi = 1, #players do
            local p = players[pi]
            if p.alive and p.potionState == nil and p.drinkingState == "idle" then
                local d = dist(p.x, p.y, gp.x, gp.y)
                if d <= CONFIG.GroundPotionPickupRange then
                    -- 拾取
                    p.potionState = gp.type
                    table.insert(pickupGlows, {
                        playerIdx = pi,
                        type = gp.type,
                        timer = 1.2, maxTimer = 1.2,
                    })
                    table.insert(floatingTexts, {
                        x = p.x, y = p.y - 30,
                        text = gp.type == "antidote" and "拾取解药" or "拾取毒药",
                        color = gp.type == "antidote" and {100, 200, 255} or {180, 60, 200},
                        timer = 1.0, maxTimer = 1.0,
                    })
                    if p.isLocal then playSound("sfx_antidote_get", 0.6) end
                    print("玩家 " .. pi .. " 拾取了地面" .. (gp.type == "antidote" and "解药" or "毒药"))
                    picked = true
                    break
                end
            end
        end
        if picked then
            table.remove(groundPotions, i)
        else
            i = i + 1
        end
    end
end

-- ============================================================================
-- 8.1-8.4 交互系统
-- ============================================================================

-- 8.4 中断交互(被攻击时调用)
interruptInteract = function(player)
    if player.interactState == "idle" then return false end
    local partnerIdx = player.interactPartner
    -- 重置自身
    player.interactState = "idle"
    player.interactPartner = nil
    player.interactTimer = 0
    player.interactGiveType = nil
    player.interactReceived = nil
    player.interactFlyAnim = nil
    -- 重置对方
    if partnerIdx then
        local partner = players[partnerIdx]
        if partner then
            partner.interactState = "idle"
            partner.interactPartner = nil
            partner.interactTimer = 0
            partner.interactGiveType = nil
            partner.interactReceived = nil
            partner.interactFlyAnim = nil
        end
    end
    table.insert(floatingTexts, {
        x = player.x, y = player.y - 40,
        text = "交互中断!", color = {255, 150, 50},
        timer = 1.0, maxTimer = 1.0,
    })
    print("玩家 " .. player.idx .. " 交互被中断!")
    return true
end

-- 8.1 发起交互请求
local function requestInteract(requester, targetIdx)
    if gamePhase ~= "day" then return false end
    if not requester.alive then return false end
    if requester.interactState ~= "idle" then return false end
    if requester.drinkingState ~= "idle" then return false end
    if requester.attackState ~= "idle" then return false end
    if requester.energy < CONFIG.InteractCostEnergy then return false end

    local target = players[targetIdx]
    if not target or not target.alive then return false end
    if target.interactState ~= "idle" then return false end
    if target.drinkingState ~= "idle" then return false end
    if target.attackState ~= "idle" then return false end

    -- 距离检测
    local d = dist(requester.x, requester.y, target.x, target.y)
    if d > CONFIG.InteractRange then return false end

    -- 8.1 消耗能量
    requester.energy = requester.energy - CONFIG.InteractCostEnergy

    -- 设置双方状态
    requester.interactState = "requesting"
    requester.interactPartner = targetIdx
    requester.interactTimer = CONFIG.InteractAcceptTimeout

    target.interactState = "pending"
    target.interactPartner = requester.idx
    target.interactTimer = CONFIG.InteractAcceptTimeout

    table.insert(floatingTexts, {
        x = requester.x, y = requester.y - 40,
        text = "请求交互...", color = {200, 200, 100},
        timer = 1.5, maxTimer = 1.5,
    })
    print("玩家 " .. requester.idx .. " 向玩家 " .. targetIdx .. " 发起交互请求")
    return true
end

-- 8.1 接受交互(或超时默认接受)
local function acceptInteract(player)
    if player.interactState ~= "pending" then return false end
    local partnerIdx = player.interactPartner
    local partner = players[partnerIdx]
    if not partner or partner.interactState ~= "requesting" then
        -- 对方已取消
        player.interactState = "idle"
        player.interactPartner = nil
        return false
    end

    -- 双方进入交互状态
    player.interactState = "interacting"
    player.interactTimer = CONFIG.InteractDuration
    player.interactGiveType = nil

    partner.interactState = "interacting"
    partner.interactTimer = CONFIG.InteractDuration
    partner.interactGiveType = nil

    -- 双方锁住速度
    player.vx = 0
    player.vy = 0
    partner.vx = 0
    partner.vy = 0

    table.insert(floatingTexts, {
        x = player.x, y = player.y - 40,
        text = "交互开始!", color = {100, 255, 200},
        timer = 1.0, maxTimer = 1.0,
    })
    print("玩家 " .. player.idx .. " 接受了玩家 " .. partnerIdx .. " 的交互")
    return true
end

-- 8.1 取消交互(主动取消/超出距离)
local function cancelInteract(player)
    if player.interactState == "idle" then return end
    local partnerIdx = player.interactPartner
    player.interactState = "idle"
    player.interactPartner = nil
    player.interactTimer = 0
    player.interactGiveType = nil
    player.interactReceived = nil
    player.interactFlyAnim = nil

    if partnerIdx then
        local partner = players[partnerIdx]
        if partner then
            partner.interactState = "idle"
            partner.interactPartner = nil
            partner.interactTimer = 0
            partner.interactGiveType = nil
            partner.interactReceived = nil
            partner.interactFlyAnim = nil
        end
    end
    print("玩家 " .. player.idx .. " 取消了交互")
end

-- 8.2 给予物品(选择给予解药/毒药)
local function giveItem(giver, itemType)
    if giver.interactState ~= "interacting" then return false end
    if not giver.potionState then return false end  -- 必须有药才能给
    local partnerIdx = giver.interactPartner
    local receiver = players[partnerIdx]
    if not receiver then return false end

    -- 8.3 欺骗机制: giver自己知道给什么, receiver看不到
    giver.interactGiveType = itemType
    giver.interactState = "giving"

    -- 抛物线动画
    giver.interactFlyAnim = {
        t = 0,
        duration = 0.6,
        fromX = giver.x,
        fromY = giver.y - 20,
        toX = receiver.x,
        toY = receiver.y - 20,
        type = itemType,
    }

    -- 消耗giver的药
    giver.potionState = nil
    if giver.isLocal then playSound("sfx_interact_give", 0.5) end

    print("玩家 " .. giver.idx .. " 给予玩家 " .. partnerIdx .. " " .. (itemType == "antidote" and "解药" or "毒药"))
    return true
end

-- 8.2 完成给予(抛物线动画结束后调用)
local function completeGive(giver, receiverIdx, itemType)
    local receiver = players[receiverIdx]
    if not receiver or not receiver.alive then return end

    -- 8.2 物品转移: 直接生效
    if itemType == "antidote" then
        -- 给予解药: 减少对方15毒
        receiver.poison = clamp(receiver.poison - 15, CONFIG.PoisonMin, CONFIG.PoisonMax)
        receiver.interactReceived = "antidote"
        table.insert(floatingTexts, {
            x = receiver.x, y = receiver.y - 40,
            text = "-15毒(解药)", color = {80, 220, 255},
            timer = 1.2, maxTimer = 1.2,
        })
        table.insert(statusEffects, { playerIdx = receiverIdx, type = "detox", timer = 0.8 })
    elseif itemType == "poison" then
        -- 8.3 欺骗: 给予毒药(伪装成解药)
        receiver.poison = clamp(receiver.poison + 25, CONFIG.PoisonMin, CONFIG.PoisonMax)
        receiver.interactReceived = "poison"
        table.insert(floatingTexts, {
            x = receiver.x, y = receiver.y - 40,
            text = "+25毒(被骗!)", color = {255, 60, 60},
            timer = 1.5, maxTimer = 1.5,
        })
        table.insert(statusEffects, { playerIdx = receiverIdx, type = "poison", timer = 1.0 })
        screenShake.timer = 0.15
        screenShake.intensity = 3
    end

    -- 重置双方交互状态
    giver.interactState = "idle"
    giver.interactPartner = nil
    giver.interactTimer = 0
    giver.interactGiveType = nil
    giver.interactFlyAnim = nil

    receiver.interactState = "idle"
    receiver.interactPartner = nil
    receiver.interactTimer = 0
    receiver.interactGiveType = nil
    receiver.interactFlyAnim = nil
end

-- 8.1 交互状态每帧更新
local function updateInteractionState(p, dt)
    if p.interactState == "idle" then return end

    if p.interactState == "requesting" then
        p.interactTimer = p.interactTimer - dt
        -- 请求期间不能移动
        p.vx = 0
        p.vy = 0
        -- 超时: 默认接受
        if p.interactTimer <= 0 then
            local partner = players[p.interactPartner]
            if partner and partner.interactState == "pending" then
                acceptInteract(partner)
            else
                cancelInteract(p)
            end
        end
        -- 距离检测: 超出范围取消
        if p.interactPartner then
            local partner = players[p.interactPartner]
            if partner then
                local d = dist(p.x, p.y, partner.x, partner.y)
                if d > CONFIG.InteractRange * 1.5 then
                    cancelInteract(p)
                end
            end
        end

    elseif p.interactState == "pending" then
        p.interactTimer = p.interactTimer - dt
        -- 等待期间不能移动
        p.vx = 0
        p.vy = 0
        -- 超时: 默认接受
        if p.interactTimer <= 0 then
            acceptInteract(p)
        end

    elseif p.interactState == "interacting" then
        p.interactTimer = p.interactTimer - dt
        -- 交互期间不能移动
        p.vx = 0
        p.vy = 0
        -- 超时: 交互失败, 双方恢复
        if p.interactTimer <= 0 then
            cancelInteract(p)
        end

    elseif p.interactState == "giving" then
        -- 播放抛物线动画
        p.vx = 0
        p.vy = 0
        if p.interactFlyAnim then
            p.interactFlyAnim.t = p.interactFlyAnim.t + dt
            if p.interactFlyAnim.t >= p.interactFlyAnim.duration then
                -- 动画完成, 应用效果
                completeGive(p, p.interactPartner, p.interactGiveType)
            end
        else
            -- 没有动画数据, 直接结束
            cancelInteract(p)
        end
    end
end

-- 8.5 找到最近可交互玩家(用于UI提示和交互触发)
local function findNearestInteractable(player)
    if not player.alive then return nil end
    if player.interactState ~= "idle" then return nil end
    if player.drinkingState ~= "idle" then return nil end
    if player.attackState ~= "idle" then return nil end

    local bestIdx = nil
    local bestDist = CONFIG.InteractRange
    for i = 1, #players do
        local other = players[i]
        if other.idx ~= player.idx and other.alive
            and other.interactState == "idle"
            and other.drinkingState == "idle"
            and other.attackState ~= "idle" == false then
            local d = dist(player.x, player.y, other.x, other.y)
            if d <= bestDist then
                bestDist = d
                bestIdx = i
            end
        end
    end
    return bestIdx
end

-- ============================================================================
-- AI 逻辑
-- ============================================================================

-- AI全局: 正在喝解药的玩家列表(所有AI共享优先攻击目标)
local aiPriorityTargets = {}  -- {playerIdx = true}

local function updateAI(p, dt)
    if p.isLocal or not p.alive then return end

    -- 5.2 喝药/硬直期间AI不做任何决策
    if p.drinkingState ~= "idle" then
        p.vx = 0
        p.vy = 0
        return
    end

    -- 8.1 交互期间AI不做其他决策
    if p.interactState ~= "idle" then
        p.vx = 0
        p.vy = 0
        -- 8.2 AI在interacting状态时选择给予
        if p.interactState == "interacting" and p.potionState then
            -- AI决策: 有毒药时50%概率欺骗(给毒药), 有解药时80%概率给解药
            if p.interactTimer < CONFIG.InteractDuration - 0.5 then
                -- 等0.5秒再做决定(模拟思考)
                if math.random() < 0.3 then  -- 每帧30%概率执行(避免瞬间)
                    if p.potionState == "poison" then
                        -- 有毒药: 总是伪装给"解药"(实际给毒药)
                        giveItem(p, "poison")
                    elseif p.potionState == "antidote" then
                        -- 有解药: 80%真给解药, 20%欺骗(不给, 等待超时)
                        if math.random() < 0.8 then
                            giveItem(p, "antidote")
                        end
                    end
                end
            end
        end
        -- 8.1 AI接受交互: pending时自动接受(模拟)
        if p.interactState == "pending" and p.interactTimer < CONFIG.InteractAcceptTimeout - 0.5 then
            -- 等0.5秒后自动接受
            if math.random() < 0.1 then
                acceptInteract(p)
            end
        end
        return
    end

    -- 8.1 AI发起交互决策: 有药且附近有人时考虑交互
    if p.potionState and gamePhase == "day" and p.energy >= CONFIG.InteractCostEnergy then
        -- 找最近的idle玩家
        for i = 1, #players do
            local other = players[i]
            if other.idx ~= p.idx and other.alive and other.interactState == "idle"
                and other.drinkingState == "idle" and other.attackState == "idle" then
                local d = dist(p.x, p.y, other.x, other.y)
                if d <= CONFIG.InteractRange then
                    -- 有毒药时更倾向交互(欺骗), 有解药时偶尔交互(帮助)
                    local chance = p.potionState == "poison" and 0.015 or 0.005
                    if math.random() < chance then
                        requestInteract(p, other.idx)
                        return
                    end
                end
            end
        end
    end

    -- AI胜利药水: 立刻喝
    if p.potionState == "victory" then
        startDrinking(p, "victory")
        return
    end

    -- 5.2 AI喝药决策: 有解药且有毒素时考虑喝
    if p.potionState == "antidote" and p.poison >= 20 and gamePhase == "day" then
        -- 附近没有敌人时才喝(安全距离)
        local nearestEnemyDist = math.huge
        for i = 1, #players do
            if players[i].alive and players[i].idx ~= p.idx then
                local d = dist(p.x, p.y, players[i].x, players[i].y)
                if d < nearestEnemyDist then nearestEnemyDist = d end
            end
        end
        -- 毒素越高越急切喝药, 安全距离随毒素降低
        local urgency = p.poison / CONFIG.PoisonMax  -- 0~1
        local safeDist = 150 * (1 - urgency * 0.7)  -- 毒素高时安全距离降低
        local drinkChance = 0.02 + urgency * 0.08   -- 毒素高时概率提高(2%~10%)
        if nearestEnemyDist > safeDist and math.random() < drinkChance then
            startDrinking(p, "antidote")
            return
        end
    end

    -- 5.5 AI喝毒药决策: 有毒药时小概率"佯装喝药"引诱对手攻击(策略性)
    if p.potionState == "poison" and gamePhase == "day" then
        local nearestEnemyDist = math.huge
        for i = 1, #players do
            if players[i].alive and players[i].idx ~= p.idx then
                local d = dist(p.x, p.y, players[i].x, players[i].y)
                if d < nearestEnemyDist then nearestEnemyDist = d end
            end
        end
        -- 只在有敌人靠近时才佯装喝毒药(吸引打断 → 转移毒素)
        if nearestEnemyDist < 80 and math.random() < 0.01 then
            startDrinking(p, "poison")
            return
        end
    end

    p.aiTimer = p.aiTimer - dt
    if p.aiTimer > 0 then
        -- 继续执行当前决策
        local dx = p.aiTargetX - p.x
        local dy = p.aiTargetY - p.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 5 then
            p.vx = (dx / d) * CONFIG.MoveSpeed
            p.vy = (dy / d) * CONFIG.MoveSpeed
            p.facing = math.atan(dy, dx)
            -- AI翻转方向跟随移动
            if p.vx > 0.1 then p.flipDir = 1 elseif p.vx < -0.1 then p.flipDir = -1 end
        else
            p.vx = 0
            p.vy = 0
        end

        -- 实时检测攻击：好战AI，随时攻击范围内目标
        if p.attackState == "idle" and p.attackCooldown <= 0 and p.energy >= CONFIG.AttackCostEnergy then
            -- 优先攻击正在喝解药的玩家(最高优先级)
            local priorityTarget = nil
            local priorityDist = math.huge
            for i = 1, #players do
                local other = players[i]
                if other.alive and other.idx ~= p.idx and aiPriorityTargets[other.idx] then
                    local dToOther = dist(p.x, p.y, other.x, other.y)
                    if dToOther <= CONFIG.AttackRange and dToOther < priorityDist then
                        priorityTarget = other
                        priorityDist = dToOther
                    end
                end
            end
            if priorityTarget then
                p.facing = angleBetween(p.x, p.y, priorityTarget.x, priorityTarget.y)
                performAttack(p)
            else
                -- 普通攻击: 范围内任何目标
                for i = 1, #players do
                    local other = players[i]
                    if other.alive and other.idx ~= p.idx then
                        local dToOther = dist(p.x, p.y, other.x, other.y)
                        if dToOther <= CONFIG.AttackRange then
                            p.facing = angleBetween(p.x, p.y, other.x, other.y)
                            performAttack(p)
                            break
                        end
                    end
                end
            end
        end
        return
    end

    -- 重新决策
    p.aiTimer = CONFIG.AIUpdateInterval + math.random() * 0.2

    -- ========== 好战AI目标选择(优先级从高到低) ==========
    -- 优先级1: 正在喝解药的玩家(最高优先攻击)
    -- 优先级2: 毒素低+能量高的玩家(肥羊目标)
    -- 优先级3: 最近的敌人

    -- 更新优先攻击列表: 正在喝解药的玩家
    aiPriorityTargets = {}
    for i = 1, #players do
        local other = players[i]
        if other.alive and other.idx ~= p.idx then
            if other.drinkingState == "drinking" and other.drinkingType == "antidote" then
                aiPriorityTargets[other.idx] = true
            end
        end
    end

    -- 检查是否有优先攻击目标(正在喝解药的)
    local bestPriorityTarget = nil
    local bestPriorityDist = math.huge
    for i = 1, #players do
        local other = players[i]
        if other.alive and other.idx ~= p.idx and aiPriorityTargets[other.idx] then
            local d = dist(p.x, p.y, other.x, other.y)
            if d < bestPriorityDist then
                bestPriorityDist = d
                bestPriorityTarget = other
            end
        end
    end

    -- 如果有玩家正在喝解药,全力追击!
    if bestPriorityTarget then
        p.aiTargetX = bestPriorityTarget.x + (math.random() - 0.5) * 15
        p.aiTargetY = bestPriorityTarget.y + (math.random() - 0.5) * 15
        p.aiWantsAttack = true
        p.sprinting = p.energy > 20  -- 冲刺追击
        -- 保持在毒圈内
        local dToCenter = dist(p.aiTargetX, p.aiTargetY, circle.cx, circle.cy)
        if dToCenter > circle.radius * 0.8 then
            p.aiTargetX = lerp(p.aiTargetX, circle.cx, 0.5)
            p.aiTargetY = lerp(p.aiTargetY, circle.cy, 0.5)
        end
        return
    end

    -- 找最近的未腐败舒适区(AI也受舒适区使用限制)
    local nearestZoneDist = math.huge
    local nearestZone = nil
    for zi, zone in ipairs(comfortZones) do
        if not zone.corrupted then
            -- 检查AI是否已占领并耗尽该舒适区
            local claim = p.comfortClaims and p.comfortClaims[zi]
            local depleted = claim and claim.claimed and claim.energyLeft <= 0
            if not depleted then
                local d = dist(p.x, p.y, zone.x, zone.y)
                if d < nearestZoneDist then
                    nearestZoneDist = d
                    nearestZone = zone
                end
            end
        end
    end

    -- 能量极低时才去舒适区(好战优先,能量<20才考虑恢复)
    if p.energy < 20 and nearestZone then
        -- 已在舒适区内 → 停下来恢复(但时间缩短,恢复一点就走)
        if nearestZoneDist <= CONFIG.ComfortZoneRadius * 0.5 then
            p.aiTargetX = p.x
            p.aiTargetY = p.y
            p.aiWantsAttack = false
            p.aiTimer = 2.0 + math.random() * 2.0  -- 只停留2~4秒就重新追击
            return
        else
            -- 前往最近舒适区
            p.aiTargetX = nearestZone.x + (math.random() - 0.5) * 20
            p.aiTargetY = nearestZone.y + (math.random() - 0.5) * 20
            p.aiWantsAttack = false
            return
        end
    end

    -- ========== AI毒素为0时逃跑(保命优先) ==========
    if p.poison <= 0 then
        -- 找离自己最近的敌人,反方向逃跑
        local nearestEnemy = nil
        local nearestDist = math.huge
        for i = 1, #players do
            local other = players[i]
            if other.alive and other.idx ~= p.idx then
                local d = dist(p.x, p.y, other.x, other.y)
                if d < nearestDist then
                    nearestDist = d
                    nearestEnemy = other
                end
            end
        end
        if nearestEnemy and nearestDist < 200 then
            -- 远离最近敌人
            local fleeAngle = math.atan(p.y - nearestEnemy.y, p.x - nearestEnemy.x)
            p.aiTargetX = p.x + math.cos(fleeAngle) * 200
            p.aiTargetY = p.y + math.sin(fleeAngle) * 200
            p.sprinting = p.energy > 15  -- 逃跑时冲刺
        else
            -- 没有近处敌人,随机游走保持距离
            p.aiTargetX = p.x + (math.random() - 0.5) * 250
            p.aiTargetY = p.y + (math.random() - 0.5) * 250
            p.sprinting = false
        end
        p.aiWantsAttack = false
        -- 保持在毒圈内
        local dToCenter = dist(p.aiTargetX, p.aiTargetY, circle.cx, circle.cy)
        if dToCenter > circle.radius * 0.8 then
            p.aiTargetX = lerp(p.aiTargetX, circle.cx, 0.5)
            p.aiTargetY = lerp(p.aiTargetY, circle.cy, 0.5)
        end
        return
    end

    -- ========== 好战目标选择(优先级: 喝解药>0毒药>满能量>好状态) ==========
    local bestTarget = nil
    local bestScore = -math.huge
    for i = 1, #players do
        local other = players[i]
        if other.alive and other.idx ~= p.idx and not other.usingComfortZone then
            local d = dist(p.x, p.y, other.x, other.y)
            local score = -d * 0.1  -- 基础: 距离近优先

            -- 优先级1(最高): 正在喝解药 +500
            if other.drinkingState == "drinking" and other.drinkingType == "antidote" then
                score = score + 500
            end
            -- 优先级2: 0毒素的玩家 +300 (打他加毒效果最好)
            if other.poison <= 0 then
                score = score + 300
            end
            -- 优先级3: 满能量的玩家 +150 (掠夺价值高)
            if other.energy >= CONFIG.EnergyMax then
                score = score + 150
            end
            -- 优先级4: 好状态(低毒+高能) +50~100
            local goodState = (CONFIG.PoisonMax - other.poison) / CONFIG.PoisonMax * 50
                            + (other.energy / CONFIG.EnergyMax) * 50
            score = score + goodState

            if score > bestScore then
                bestScore = score
                bestTarget = other
            end
        end
    end

    if bestTarget then
        local d = dist(p.x, p.y, bestTarget.x, bestTarget.y)
        -- 好战AI: 主动追击
        if p.energy >= CONFIG.AttackCostEnergy then
            p.aiTargetX = bestTarget.x + (math.random() - 0.5) * 20
            p.aiTargetY = bestTarget.y + (math.random() - 0.5) * 20
            p.aiWantsAttack = d < CONFIG.AttackRange * 1.5
            -- 目标较远时开启冲刺
            if d > CONFIG.AttackRange * 2 and p.energy > 30 then
                p.sprinting = true
            else
                p.sprinting = false
            end
        else
            -- 能量不足时短暂游走
            p.aiTargetX = p.x + (math.random() - 0.5) * 150
            p.aiTargetY = p.y + (math.random() - 0.5) * 150
            p.aiWantsAttack = false
        end
    else
        -- 没有目标，向地图中心移动
        p.aiTargetX = CONFIG.MapSize / 2 + (math.random() - 0.5) * 200
        p.aiTargetY = CONFIG.MapSize / 2 + (math.random() - 0.5) * 200
        p.aiWantsAttack = false
    end

    -- 保持在毒圈内
    local dToCenter = dist(p.aiTargetX, p.aiTargetY, circle.cx, circle.cy)
    if dToCenter > circle.radius * 0.8 then
        p.aiTargetX = lerp(p.aiTargetX, circle.cx, 0.5)
        p.aiTargetY = lerp(p.aiTargetY, circle.cy, 0.5)
    end

end

-- ============================================================================
-- 更新逻辑
-- ============================================================================

local function updatePlayers(dt)
    for i = 1, #players do
        local p = players[i]
        if not p.alive and not p.isGhost then goto continue end
        -- 鬼魂只能移动, 不能攻击/不受毒
        if p.isGhost then
            local moveX = p.vx * dt
            local moveY = p.vy * dt
            p.x = p.x + moveX
            p.y = p.y + moveY
            goto continue
        end

        -- 更新冷却
        p.attackCooldown = math.max(0, p.attackCooldown - dt)
        p.attackTimer = math.max(0, p.attackTimer - dt)
        p.hitFlash = math.max(0, p.hitFlash - dt)

        -- 4.3 攻击状态机更新(前摇/后摇)
        updateAttackState(p, dt)

        -- 5.2 喝药状态更新
        updateDrinkingState(p, dt)

        -- 8.1 交互状态更新
        updateInteractionState(p, dt)

        -- AI更新
        if not p.isLocal then
            updateAI(p, dt)
        end

        -- 6.1 移动不消耗能量(已移除移动耗能)

        -- 移动(后摇期间由updateAttackState强制归零vx/vy, 这里正常应用)
        local moveX = p.vx * dt
        local moveY = p.vy * dt

        p.x = p.x + moveX
        p.y = p.y + moveY

        -- 9.2 毒圈外加毒: 10点/秒(无额外能量消耗,无直接伤害)
        -- 只在 day 和 shrinking 阶段生效
        local dToCenter = dist(p.x, p.y, circle.cx, circle.cy)
        if dToCenter > circle.radius and (gamePhase == "day" or gamePhase == "shrinking") then
            -- 每轮毒圈更毒: 基础10/秒, 每轮+5/秒
            local poisonRate = CONFIG.CirclePoisonRate + (currentRound - 1) * 5
            p.poison = clamp(p.poison + poisonRate * dt, CONFIG.PoisonMin, CONFIG.PoisonMax)
            p.inPoisonZone = true
        else
            p.inPoisonZone = false
        end

        -- 7.2 舒适区能量回复(10/秒, 10秒回满, 需站立不动3秒后) - 9.4 失效区不回复
        -- 新增: 舒适区有自身能量条(100), 消耗完进入5秒冷却, 每个舒适区只能用5次
        -- 舒适区站点占领机制
        local wasInComfort = p.inComfortZone
        p.inComfortZone = false
        if p.usedZoneHintCD and p.usedZoneHintCD > 0 then p.usedZoneHintCD = p.usedZoneHintCD - dt end
        local isStanding = (p.vx == 0 and p.vy == 0)  -- 必须站着不动
        if not p.comfortClaims then p.comfortClaims = {} end
        p.isCapturingZone = false  -- 每帧重置
        p.currentComfortZoneIdx = nil  -- 当前所在舒适区索引
        for zi, zone in ipairs(comfortZones) do
            -- 跳过腐败/耗尽/冷却中的舒适区
            local zoneAvailable = not zone.corrupted
                and (zone.zoneUsesLeft or 5) > 0
                and (zone.zoneCooldown or 0) <= 0
                and (zone.zoneEnergy or 100) > 0
            if not zoneAvailable then goto nextZone end

            -- 初始化该玩家对此舒适区的占领记录
            if not p.comfortClaims[zi] then
                p.comfortClaims[zi] = { claimed = false, claimTimer = 0, energyLeft = 0 }
            end
            local claim = p.comfortClaims[zi]

            -- 检查该玩家是否已占领并耗尽此舒适区能量
            if claim.claimed and claim.energyLeft <= 0 then
                -- 本地玩家进入已耗尽的舒适区时给出提示
                if p.isLocal and dist(p.x, p.y, zone.x, zone.y) <= CONFIG.ComfortZoneRadius then
                    if not p.usedZoneHintCD or p.usedZoneHintCD <= 0 then
                        p.usedZoneHintCD = 3.0
                        table.insert(floatingTexts, {
                            x = p.x, y = p.y - 40,
                            text = "此舒适区能量已耗尽,请前往其他舒适区",
                            color = {200, 150, 80},
                            timer = 1.5, maxTimer = 1.5,
                        })
                    end
                end
                goto nextZone
            end

            if dist(p.x, p.y, zone.x, zone.y) <= CONFIG.ComfortZoneRadius then
                -- 舒适区独占: 如果已被其他玩家占用,本玩家不能使用
                if zone.occupiedBy and zone.occupiedBy ~= p.idx then
                    if p.isLocal then
                        if not p.usedZoneHintCD or p.usedZoneHintCD <= 0 then
                            p.usedZoneHintCD = 3.0
                            table.insert(floatingTexts, {
                                x = p.x, y = p.y - 40,
                                text = "舒适区被占用中",
                                color = {200, 150, 80},
                                timer = 1.2, maxTimer = 1.2,
                            })
                        end
                    end
                    goto nextZone
                end
                p.inComfortZone = true
                p.currentComfortZoneIdx = zi
                if not wasInComfort and p.isLocal then playSound("sfx_comfort_zone_enter", 0.4) end

                -- 已占领且有剩余能量 → 直接使用(无需等待)
                if claim.claimed and claim.energyLeft > 0 then
                    zone.occupiedBy = p.idx
                    p.usingComfortZone = true
                    if p.energy < CONFIG.EnergyMax then
                        local regenAmount = CONFIG.ComfortZoneRegenRate * dt
                        local actualRegen = math.min(regenAmount, claim.energyLeft)
                        actualRegen = math.min(actualRegen, zone.zoneEnergy)

                        local prevEnergy = p.energy
                        p.energy = clamp(p.energy + actualRegen, CONFIG.EnergyMin, CONFIG.EnergyMax)
                        claim.energyLeft = claim.energyLeft - actualRegen
                        zone.zoneEnergy = zone.zoneEnergy - actualRegen

                        -- 能量配额耗尽 → 需要重新占领
                        if claim.energyLeft <= 0 then
                            claim.energyLeft = 0
                            claim.claimed = false
                            claim.claimTimer = 0
                            zone.occupiedBy = nil
                            p.usingComfortZone = false
                            if p.isLocal then
                                table.insert(floatingTexts, {
                                    x = p.x, y = p.y - 50,
                                    text = "能量配额已用完,需重新占领!",
                                    color = {255, 200, 100},
                                    timer = 1.5, maxTimer = 1.5,
                                })
                            end
                        end

                        -- 舒适区总能量耗尽 → 进入5秒冷却
                        if zone.zoneEnergy <= 0 then
                            zone.zoneEnergy = 0
                            zone.zoneCooldown = 5.0
                            zone.zoneUsesLeft = zone.zoneUsesLeft - 1
                        end

                        -- 浮动+5数字(每积累5点触发一次)
                        local prevTick = math.floor(prevEnergy / 5)
                        local curTick = math.floor(p.energy / 5)
                        if curTick > prevTick then
                            table.insert(comfortFloats, {
                                x = p.x + (math.random() - 0.5) * 10,
                                y = p.y - 40,
                                text = "+5",
                                life = 1.0,
                                maxLife = 1.0,
                                color = {80, 200, 80},
                            })
                        end
                    end
                -- 未占领 → 需要站立等待3秒占领
                elseif not claim.claimed then
                    if isStanding then
                        claim.claimTimer = claim.claimTimer + dt
                        p.isCapturingZone = true  -- 标记正在占领(可被攻击打断)
                        p.comfortStandTimer = claim.claimTimer  -- 同步给UI显示

                        -- 占领成功!
                        if claim.claimTimer >= CONFIG.ComfortZoneWaitTime then
                            claim.claimed = true
                            claim.energyLeft = CONFIG.ComfortZoneClaimEnergy
                            claim.claimTimer = 0
                            zone.occupiedBy = p.idx
                            p.usingComfortZone = true
                            p.isCapturingZone = false
                            if p.isLocal then
                                playSound("sfx_comfort_zone_enter", 0.6)
                                table.insert(floatingTexts, {
                                    x = p.x, y = p.y - 50,
                                    text = "占领成功! +100能量配额",
                                    color = {80, 255, 80},
                                    timer = 1.5, maxTimer = 1.5,
                                })
                            end
                        end
                    else
                        -- 移动了，重置占领计时
                        claim.claimTimer = 0
                        p.comfortStandTimer = 0
                        p.isCapturingZone = false
                    end
                end
                break
            end
            ::nextZone::
        end
        -- 不在舒适区时重置状态并释放占用
        if not p.inComfortZone then
            p.comfortStandTimer = 0
            p.isCapturingZone = false
            if p.usingComfortZone then
                -- 释放之前占用的舒适区
                for _, z in ipairs(comfortZones) do
                    if z.occupiedBy == p.idx then z.occupiedBy = nil end
                end
                p.usingComfortZone = false
            end
        end

        -- 10.2 毒值≥80预警音效(本地玩家, cooldown限制)
        if p.isLocal and p.alive and p.poison >= 80 and poisonWarnCooldown <= 0 then
            playSound("sfx_poison_warning", 0.5)
            poisonWarnCooldown = 3.0  -- 每3秒最多一次
        end

        -- 10.3 中毒加深骷髅(每跨越+10阈值时闪现)
        if p.poisonSkullTimer > 0 then
            p.poisonSkullTimer = p.poisonSkullTimer - dt
        end
        local curTick10 = math.floor(p.poison / 10)
        if curTick10 > p.lastPoisonTick and p.poison > 0 then
            p.poisonSkullTimer = 0.8
            if p.isLocal then playSound("sfx_poison_tick", 0.4) end
        end
        p.lastPoisonTick = curTick10

        -- 4.2 毒素上限钳制（不再即时死亡，统一由结算阶段淘汰）
        if p.poison > CONFIG.PoisonMax then
            p.poison = CONFIG.PoisonMax
        end

        -- 4.3 毒满暴走buff检测
        if p.poison >= CONFIG.PoisonMax then
            if not p.poisonMaxBuff then
                p.poisonMaxBuff = true
                table.insert(floatingTexts, {
                    x = p.x, y = p.y - 60,
                    text = "毒满暴走! 攻击翻倍!",
                    color = {255, 0, 180},
                    timer = 2.0, maxTimer = 2.0,
                })
                if p.isLocal then playSound("sfx_poison_transfer", 0.8) end
            end
        elseif p.poison <= CONFIG.PoisonMin then
            if p.poisonMaxBuff then
                p.poisonMaxBuff = false
                table.insert(floatingTexts, {
                    x = p.x, y = p.y - 60,
                    text = "暴走结束",
                    color = {150, 150, 150},
                    timer = 1.5, maxTimer = 1.5,
                })
            end
        end

        ::continue::
    end
end

local function updateParticles(dt)
    local i = 1
    while i <= #particles do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt * 2
        if p.life <= 0 then
            table.remove(particles, i)
        else
            i = i + 1
        end
    end
end

-- 更新死亡纸片碎裂
local function updateDeathPieces(dt)
    local i = 1
    while i <= #deathPieces do
        local p = deathPieces[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 40 * dt  -- 轻微下坠
        p.vx = p.vx * 0.98     -- 空气阻力
        p.rot = p.rot + p.rotV * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(deathPieces, i)
        else
            i = i + 1
        end
    end
    -- 污渍缓慢淡出(很慢, 保留很久)
    for si = #deathStains, 1, -1 do
        deathStains[si].alpha = deathStains[si].alpha - dt * 3
        if deathStains[si].alpha <= 0 then
            table.remove(deathStains, si)
        end
    end
end

local function updateAttackEffects(dt)
    local i = 1
    while i <= #attackEffects do
        local e = attackEffects[i]
        e.timer = e.timer - dt
        if e.timer <= 0 then
            table.remove(attackEffects, i)
        else
            i = i + 1
        end
    end
end

-- 4.3 浮动文字更新(上飘+淡出)
local function updateFloatingTexts(dt)
    local i = 1
    while i <= #floatingTexts do
        local ft = floatingTexts[i]
        ft.timer = ft.timer - dt
        ft.y = ft.y - 40 * dt  -- 每秒上飘40像素
        if ft.timer <= 0 then
            table.remove(floatingTexts, i)
        else
            i = i + 1
        end
    end
end

-- 4.3 屏幕震动更新
local function updateScreenShake(dt)
    if screenShake.timer > 0 then
        screenShake.timer = screenShake.timer - dt
        if screenShake.timer <= 0 then
            screenShake.timer = 0
            screenShake.intensity = 0
        end
    end
end

local function updateCamera()
    local p = players[localPlayerIdx]
    if p and (p.alive or p.isGhost) then
        camera.x = p.x
        camera.y = p.y
    end
end

-- ============================================================================
-- 玩家输入
-- ============================================================================

-- ===== 触控按钮系统(手机适配) =====
local touchButtons = {
    attack = { pressed = false, touchId = -1 },
    item = { pressed = false, touchId = -1 },
    sprint = { pressed = false, touchId = -1 },
    interact = { pressed = false, touchId = -1 },
    reject = { pressed = false, touchId = -1 },
}
local touchJoystick = {
    active = false,
    touchId = -1,
    cx = 0, cy = 0,       -- 摇杆中心(触摸起始点)
    dx = 0, dy = 0,       -- 摇杆偏移
    radius = 50,          -- 摇杆最大半径
}
local isTouchDevice = false  -- 检测到触摸输入后自动开启

local moveInput = { x = 0, y = 0 }

-- ============================================================================
-- 手柄适配
-- ============================================================================
local GAMEPAD_DEADZONE = 0.2  -- 摇杆死区

local function applyDeadzone(value)
    if math.abs(value) < GAMEPAD_DEADZONE then return 0 end
    -- 平滑映射: 死区外的值归一化到 0~1
    local sign = value > 0 and 1 or -1
    return sign * (math.abs(value) - GAMEPAD_DEADZONE) / (1.0 - GAMEPAD_DEADZONE)
end

--- 获取当前连接的手柄(优先返回第一个 Controller 类型)
local function getGamepad()
    for i = 0, input.numJoysticks - 1 do
        local js = input:GetJoystickByIndex(i)
        if js and js:IsController() then
            return js
        end
    end
    return nil
end

local function handlePlayerInput(dt)
    local p = players[localPlayerIdx]
    if not p then return end
    -- 死亡且非鬼魂: 不可操作
    if not p.alive and not p.isGhost then return end

    -- 5.2 喝药/硬直期间禁止移动和攻击
    if not p.isGhost and (p.drinkingState == "drinking" or p.drinkingState == "stunned") then
        p.vx = 0
        p.vy = 0
        return
    end

    -- 8.1 交互期间禁止移动和攻击
    if not p.isGhost and p.interactState ~= "idle" then
        p.vx = 0
        p.vy = 0
        return
    end

    -- 获取手柄(每帧检测)
    local gamepad = getGamepad()

    -- 6.1 奔跑: 按住Shift键 或 触控奔跑键 或 手柄LB + 有能量时奔跑
    local sprintPressed = input:GetKeyDown(KEY_LSHIFT) or input:GetKeyDown(KEY_RSHIFT) or touchButtons.sprint.pressed
    if not sprintPressed and gamepad then
        sprintPressed = gamepad:GetButtonDown(CONTROLLER_BUTTON_LEFTSHOULDER)
    end
    if sprintPressed then
        if p.energy > 0 then
            p.sprinting = true
        else
            p.sprinting = false
        end
    else
        p.sprinting = false
    end

    -- WASD移动(鬼魂也可以移动)
    moveInput.x = 0
    moveInput.y = 0
    if input:GetKeyDown(KEY_W) then moveInput.y = -1 end
    if input:GetKeyDown(KEY_S) then moveInput.y = 1 end
    if input:GetKeyDown(KEY_A) then moveInput.x = -1 end
    if input:GetKeyDown(KEY_D) then moveInput.x = 1 end

    -- 手柄左摇杆移动输入合并
    if gamepad then
        local gpX = applyDeadzone(gamepad:GetAxisPosition(CONTROLLER_AXIS_LEFTX))
        local gpY = applyDeadzone(gamepad:GetAxisPosition(CONTROLLER_AXIS_LEFTY))
        if gpX ~= 0 or gpY ~= 0 then
            moveInput.x = gpX
            moveInput.y = gpY
        end
    end

    -- 触控摇杆输入合并
    if touchJoystick.active then
        local jLen = math.sqrt(touchJoystick.dx * touchJoystick.dx + touchJoystick.dy * touchJoystick.dy)
        if jLen > 5 then  -- 死区
            moveInput.x = touchJoystick.dx / touchJoystick.radius
            moveInput.y = touchJoystick.dy / touchJoystick.radius
        end
    end

    -- 根据移动输入更新角色翻转方向(PC用AD键, 触控/手柄用moveInput.x)
    if moveInput.x > 0.1 then
        p.flipDir = 1   -- 朝右
    elseif moveInput.x < -0.1 then
        p.flipDir = -1  -- 朝左
    end

    -- 没有移动输入时停止奔跑
    local len = math.sqrt(moveInput.x * moveInput.x + moveInput.y * moveInput.y)
    if len == 0 then
        p.sprinting = false
    end

    -- 归一化并计算速度
    if len > 0 then
        local speed = CONFIG.MoveSpeed
        if p.isGhost then
            speed = speed * 1.3  -- 鬼魂移动稍快
        elseif p.sprinting then
            speed = CONFIG.MoveSpeed * CONFIG.SprintSpeedMultiplier
            -- 6.1 奔跑消耗能量(准备阶段不消耗)
            if gamePhase ~= "prepare" then
                p.energy = clamp(p.energy - CONFIG.SprintCostRate * dt, CONFIG.EnergyMin, CONFIG.EnergyMax)
                if p.energy <= 0 then
                    p.sprinting = false
                    speed = CONFIG.MoveSpeed
                end
            end
        end
        p.vx = (moveInput.x / len) * speed
        p.vy = (moveInput.y / len) * speed
    else
        p.vx = 0
        p.vy = 0
    end

    -- 鬼魂不能朝向/攻击, 只做移动
    if p.isGhost then return end

    -- 朝向控制: 优先右摇杆 > 鼠标 > 左摇杆方向
    local facingSet = false

    -- 手柄右摇杆控制朝向(优先级最高)
    if gamepad then
        local rx = applyDeadzone(gamepad:GetAxisPosition(CONTROLLER_AXIS_RIGHTX))
        local ry = applyDeadzone(gamepad:GetAxisPosition(CONTROLLER_AXIS_RIGHTY))
        if rx ~= 0 or ry ~= 0 then
            p.facing = math.atan(ry, rx)
            facingSet = true
        end
    end

    -- 鼠标朝向(屏幕坐标转世界坐标) - 触控设备跳过,用移动方向控制攻击朝向
    if not facingSet and not isTouchDevice then
        local graphics = GetGraphics()
        local screenW = graphics:GetWidth()
        local screenH = graphics:GetHeight()
        local dpr = graphics:GetDPR()
        local logW = screenW / dpr
        local logH = screenH / dpr

        local mousePos = input:GetMousePosition()
        local mx = mousePos.x / dpr
        local my = mousePos.y / dpr

        -- 屏幕中心到鼠标的方向 = 玩家朝向
        local dx = mx - logW / 2
        local dy = my - logH / 2
        if dx ~= 0 or dy ~= 0 then
            p.facing = math.atan(dy, dx)
            facingSet = true
        end
    end

    -- 如果没有鼠标/右摇杆输入, 用左摇杆移动方向作为朝向
    if not facingSet and moveInput.x ~= 0 or moveInput.y ~= 0 then
        if not facingSet then
            local mLen = math.sqrt(moveInput.x * moveInput.x + moveInput.y * moveInput.y)
            if mLen > 0.3 then
                p.facing = math.atan(moveInput.y, moveInput.x)
            end
        end
    end

    -- 手柄按键: A=攻击, RT(右扳机)也可攻击
    if gamepad then
        if gamepad:GetButtonPress(CONTROLLER_BUTTON_A) then
            if gamePhase == "day" and not inventoryOpen then
                performAttack(p)
            end
        end
        -- RT 扳机攻击(值 > 0.5 视为按下)
        local rt = gamepad:GetAxisPosition(CONTROLLER_AXIS_TRIGGERRIGHT)
        if rt > 0.5 and p.attackCooldown <= 0 and p.attackState == "idle" then
            if gamePhase == "day" and not inventoryOpen then
                performAttack(p)
            end
        end
    end
end

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = CONFIG.Title
    SampleStart()

    -- 创建NanoVG
    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    fontId = nvgCreateFont(nvgContext, "sans", "Fonts/MiSans-Regular.ttf")
    if fontId == -1 then
        print("ERROR: Failed to load font")
    end

    -- 加载猪角色图片
    for i = 1, #PIG_IMAGE_PATHS do
        local img = nvgCreateImage(nvgContext, PIG_IMAGE_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load pig image: " .. PIG_IMAGE_PATHS[i])
        else
            print("Loaded pig image " .. i .. ": " .. PIG_IMAGE_PATHS[i])
        end
        pigImages[i] = img
    end

    -- 加载小丑猪走路动画帧(16帧)
    for i = 1, #JESTER_WALK_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, JESTER_WALK_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load walk frame " .. i .. ": " .. JESTER_WALK_FRAME_PATHS[i])
        else
            print("Loaded jester walk frame " .. i)
        end
        jesterWalkFrames[i] = img
    end

    -- 加载小丑猪待机动画帧(8帧)
    for i = 1, #JESTER_IDLE_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, JESTER_IDLE_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load idle frame " .. i .. ": " .. JESTER_IDLE_FRAME_PATHS[i])
        else
            print("Loaded jester idle frame " .. i)
        end
        jesterIdleFrames[i] = img
    end

    -- 加载小丑猪奔跑动画帧(8帧)
    for i = 1, #JESTER_RUN_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, JESTER_RUN_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load run frame " .. i .. ": " .. JESTER_RUN_FRAME_PATHS[i])
        else
            print("Loaded jester run frame " .. i)
        end
        jesterRunFrames[i] = img
    end

    -- 加载小丑猪喝药动画帧(16帧)
    for i = 1, #JESTER_DRINK_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, JESTER_DRINK_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load drink frame " .. i .. ": " .. JESTER_DRINK_FRAME_PATHS[i])
        else
            print("Loaded jester drink frame " .. i)
        end
        jesterDrinkFrames[i] = img
    end

    -- 加载小丑猪打击动画帧(8帧)
    for i = 1, #JESTER_ATTACK_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, JESTER_ATTACK_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load attack frame " .. i .. ": " .. JESTER_ATTACK_FRAME_PATHS[i])
        else
            print("Loaded jester attack frame " .. i)
        end
        jesterAttackFrames[i] = img
    end

    -- 加载小丑猪受击动画帧(8帧)
    for i = 1, #JESTER_HURT_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, JESTER_HURT_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load hurt frame " .. i .. ": " .. JESTER_HURT_FRAME_PATHS[i])
        else
            print("Loaded jester hurt frame " .. i)
        end
        jesterHurtFrames[i] = img
    end

    -- 加载战士猪走路动画帧(8帧)
    for i = 1, #WARRIOR_WALK_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, WARRIOR_WALK_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load warrior walk frame " .. i .. ": " .. WARRIOR_WALK_FRAME_PATHS[i])
        else
            print("Loaded warrior walk frame " .. i)
        end
        warriorWalkFrames[i] = img
    end

    -- 加载战士猪待机动画帧(4帧)
    for i = 1, #WARRIOR_IDLE_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, WARRIOR_IDLE_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load warrior idle frame " .. i .. ": " .. WARRIOR_IDLE_FRAME_PATHS[i])
        else
            print("Loaded warrior idle frame " .. i)
        end
        warriorIdleFrames[i] = img
    end

    -- 加载科学家猪走路动画帧(8帧)
    for i = 1, #SCIENTIST_WALK_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, SCIENTIST_WALK_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load scientist walk frame " .. i .. ": " .. SCIENTIST_WALK_FRAME_PATHS[i])
        else
            print("Loaded scientist walk frame " .. i)
        end
        scientistWalkFrames[i] = img
    end

    -- 加载矿工猪走路动画帧(16帧)
    for i = 1, #MINER_WALK_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, MINER_WALK_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load miner walk frame " .. i .. ": " .. MINER_WALK_FRAME_PATHS[i])
        else
            print("Loaded miner walk frame " .. i)
        end
        minerWalkFrames[i] = img
    end

    -- 加载矿工猪打击动画帧(8帧)
    for i = 1, #MINER_ATTACK_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, MINER_ATTACK_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load miner attack frame " .. i .. ": " .. MINER_ATTACK_FRAME_PATHS[i])
        else
            print("Loaded miner attack frame " .. i)
        end
        minerAttackFrames[i] = img
    end

    -- 加载矿工猪待机动画帧(8帧)
    for i = 1, #MINER_IDLE_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, MINER_IDLE_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load miner idle frame " .. i .. ": " .. MINER_IDLE_FRAME_PATHS[i])
        else
            print("Loaded miner idle frame " .. i)
        end
        minerIdleFrames[i] = img
    end

    -- 加载盗贼猪走路动画帧(8帧)
    for i = 1, #THIEF_WALK_FRAME_PATHS do
        local img = nvgCreateImage(nvgContext, THIEF_WALK_FRAME_PATHS[i], 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load thief walk frame " .. i .. ": " .. THIEF_WALK_FRAME_PATHS[i])
        else
            print("Loaded thief walk frame " .. i)
        end
        thiefWalkFrames[i] = img
    end

    -- 加载鬼魂图片
    ghostImage = nvgCreateImage(nvgContext, GHOST_IMAGE_PATH, 0)
    if ghostImage == 0 or ghostImage == -1 then
        print("WARNING: Failed to load ghost image: " .. GHOST_IMAGE_PATH)
        ghostImage = nil
    else
        print("Loaded ghost image: " .. GHOST_IMAGE_PATH)
    end

    -- 加载自定义鼠标光标图片
    cursorImage = nvgCreateImage(nvgContext, CURSOR_IMAGE_PATH, 0)
    if cursorImage == 0 or cursorImage == -1 then
        print("WARNING: Failed to load cursor image: " .. CURSOR_IMAGE_PATH)
        cursorImage = nil
    else
        print("Loaded cursor image: " .. CURSOR_IMAGE_PATH)
        input.mouseVisible = false  -- 隐藏系统光标
    end

    -- 加载药水图标图片(用于NanoVG手机端道具按钮和头顶指示器)
    for key, path in pairs(POTION_IMAGE_PATHS) do
        local img = nvgCreateImage(nvgContext, path, 0)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load potion image: " .. path)
            potionNvgImages[key] = nil
        else
            potionNvgImages[key] = img
            print("Loaded potion image: " .. key .. " -> " .. path)
        end
    end

    -- 加载地形贴图(NVG_IMAGE_REPEATX | NVG_IMAGE_REPEATY = 1|2 = 3)
    for name, path in pairs(TERRAIN_PATHS) do
        local img = nvgCreateImage(nvgContext, path, 3)
        if img == 0 or img == -1 then
            print("WARNING: Failed to load terrain: " .. path)
            terrainImages[name] = nil
        else
            terrainImages[name] = img
            print("Loaded terrain: " .. name)
        end
    end

    -- 加载环境装饰素材图片
    for i, path in ipairs(DECO_TREE_PATHS) do
        local img = nvgCreateImage(nvgContext, path, 0)
        if img and img > 0 then
            decoTreeImages[i] = img
            print("Loaded deco tree: " .. path)
        else
            print("WARNING: Failed to load deco tree: " .. path)
        end
    end
    for i, path in ipairs(DECO_ROCK_PATHS) do
        local img = nvgCreateImage(nvgContext, path, 0)
        if img and img > 0 then
            decoRockImages[i] = img
            print("Loaded deco rock: " .. path)
        else
            print("WARNING: Failed to load deco rock: " .. path)
        end
    end
    for i, path in ipairs(DECO_FLOWER_PATHS) do
        local img = nvgCreateImage(nvgContext, path, 0)
        if img and img > 0 then
            decoFlowerImages[i] = img
            print("Loaded deco flower: " .. path)
        else
            print("WARNING: Failed to load deco flower: " .. path)
        end
    end
    for i, path in ipairs(DECO_PLANT_PATHS) do
        local img = nvgCreateImage(nvgContext, path, 0)
        if img and img > 0 then
            decoPlantImages[i] = img
            print("Loaded deco plant: " .. path)
        else
            print("WARNING: Failed to load deco plant: " .. path)
        end
    end

    -- 初始化关卡编辑器
    levelEditor = LevelEditor.New(nvgContext, {
        mapPixelSize = math.ceil(circleInitRadius * 2),  -- 覆盖整个毒圈活动范围
        mapCenter = { x = CONFIG.MapSize / 2, y = CONFIG.MapSize / 2 },  -- 游戏地图中心
        camera = camera,
        circle = circle,
    })

    -- 初始化UI
    InitGameUI()

    -- 鼠标模式
    SampleInitMouseMode(MM_FREE)

    -- 10.2 初始化音效节点(纯2D游戏无scene_,手动创建)
    scene_ = Scene()
    sfxNode = scene_:CreateChild("SFX")

    -- 播放背景音乐(播放列表: 第一首播完后自动播第二首,第二首循环)
    local bgmNode = scene_:CreateChild("BGM")
    bgmSource = bgmNode:CreateComponent("SoundSource")
    bgmSource:SetSoundType("Music")
    bgmSource:SetGain(0.5)
    playBgmTrack(1)

    -- 订阅事件
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
    SubscribeToEvent("TouchMove", "HandleTouchMove")

    -- 手柄连接/断开事件
    SubscribeToEvent("JoystickConnected", "HandleJoystickConnected")
    SubscribeToEvent("JoystickDisconnected", "HandleJoystickDisconnected")

    -- 启动时检测已连接的手柄
    for i = 0, input.numJoysticks - 1 do
        local js = input:GetJoystickByIndex(i)
        if js and js:IsController() then
            print("[手柄] 检测到已连接手柄: " .. js.name)
        end
    end

    print("=== 《道友请留步》已启动 ===")
end

function Stop()
    UI.Shutdown()
    if nvgContext then
        nvgDelete(nvgContext)
        nvgContext = nil
    end
end

-- ============================================================================
-- UI 系统
-- ============================================================================

function InitGameUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    uiRoot_ = UI.Panel {
        id = "gameUI",
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            -- 开始菜单
            CreateMenuPanel(),
            -- HUD (游戏中显示)
            CreateHUDPanel(),
            -- 背包面板
            CreateInventoryPanel(),
        }
    }
    UI.SetRoot(uiRoot_)
end

function CreateMenuPanel()
    return UI.Panel {
        id = "menuPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "flex-end",
        alignItems = "center",
        backgroundImage = "image/封面.png",
        backgroundFit = "cover",
        onClick = function(self)
            startGame()
        end,
        children = {}
    }
end

function CreateHUDPanel()
    return UI.Panel {
        id = "hudPanel",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        pointerEvents = "box-none",
        children = {
            -- 左上: 毒药/能量条
            UI.Panel {
                position = "absolute",
                top = 12, left = 12,
                gap = 6,
                padding = 10,
                backgroundColor = { 0, 0, 0, 160 },
                borderRadius = 8,
                pointerEvents = "none",
                children = {
                    UI.Label { id = "poisonLabel", text = "毒药: 0/100", fontSize = 13, fontColor = { 180, 50, 255, 255 } },
                    UI.Label { id = "energyLabel", text = "能量: 100/100", fontSize = 13, fontColor = { 50, 200, 255, 255 } },
                },
            },
            -- 右上: 回合信息
            UI.Panel {
                position = "absolute",
                top = 12, right = 12,
                gap = 4,
                padding = 10,
                backgroundColor = { 0, 0, 0, 160 },
                borderRadius = 8,
                alignItems = "flex-end",
                pointerEvents = "none",
                children = {
                    UI.Label { id = "roundLabel", text = "剩余 5 天", fontSize = 14, fontColor = { 255, 220, 100, 255 } },
                    UI.Label { id = "timerLabel", text = "", fontSize = 20, fontColor = { 255, 80, 80, 255 } },
                    UI.Label { id = "aliveLabel", text = "存活: 6", fontSize = 12, fontColor = { 200, 200, 200, 200 } },
                },
            },
            -- 底部中央: 提示
            UI.Label {
                id = "tipLabel",
                text = "",
                fontSize = 14,
                fontColor = { 255, 255, 200, 220 },
                position = "absolute",
                bottom = 30,
                left = 0, right = 0,
                textAlign = "center",
                pointerEvents = "none",
            },
        }
    }
end

function CreateInventoryPanel()
    return UI.Panel {
        id = "inventoryPanel",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 120 },
        children = {
            -- 背包容器(使用背包图片作为背景)
            UI.Panel {
                width = 260, height = 300,
                alignItems = "center",
                justifyContent = "center",
                backgroundImage = "image/ui/背包.png",
                backgroundFit = "contain",
                children = {
                    -- 内容区域(偏移到背包图片的"口袋"区域)
                    UI.Panel {
                        width = 160, height = 180,
                        marginTop = 30,
                        gap = 8,
                        alignItems = "center",
                        justifyContent = "center",
                        children = {
                            UI.Label {
                                text = "药剂状态",
                                fontSize = 16,
                                fontColor = { 220, 200, 180, 255 },
                            },
                            -- 药剂图标槽
                            UI.Panel {
                                id = "invSlot",
                                width = 72, height = 72,
                                justifyContent = "center",
                                alignItems = "center",
                                backgroundColor = { 30, 25, 20, 160 },
                                borderRadius = 6,
                                borderWidth = 2,
                                borderColor = { 100, 80, 50, 180 },
                                children = {
                                    UI.Panel {
                                        id = "invPotionIcon",
                                        width = 56, height = 56,
                                        visible = false,
                                        backgroundFit = "contain",
                                    },
                                    UI.Label {
                                        id = "invItemLabel",
                                        text = "无药剂",
                                        fontSize = 13,
                                        fontColor = { 160, 140, 120, 200 },
                                    },
                                }
                            },
                            UI.Label {
                                id = "invDesc",
                                text = "黑夜时获得药剂",
                                fontSize = 10,
                                fontColor = { 140, 120, 100, 180 },
                            },
                            UI.Button {
                                id = "drinkAntidoteBtn",
                                text = "喝解药",
                                visible = false,
                                onClick = function(self)
                                    useItem()
                                end,
                            },
                            UI.Button {
                                id = "drinkPoisonBtn",
                                text = "喝毒药",
                                visible = false,
                                onClick = function(self)
                                    useItem()
                                end,
                            },
                            UI.Label {
                                text = "按 TAB 关闭",
                                fontSize = 10,
                                fontColor = { 120, 100, 80, 150 },
                            },
                        }
                    }
                }
            }
        }
    }
end

-- ============================================================================
-- 游戏流程控制
-- ============================================================================

function startGame()
    currentRound = 0
    circle.radius = circleInitRadius
    circle.targetRadius = circleInitRadius
    circle.shrinkSpeed = 0
    settleDeaths = {}
    victoryPotionGiven = false
    victoryWinnerIdx = nil

    initPlayers()

    -- 显示HUD，隐藏菜单
    local menu = uiRoot_:FindById("menuPanel")
    if menu then menu:SetVisible(false) end
    local hud = uiRoot_:FindById("hudPanel")
    if hud then hud:SetVisible(true) end


    -- 进入准备阶段(仅开局一次)
    enterPrepare()
end

function restartGame()
    startGame()
end

function useItem(potionType)
    local p = players[localPlayerIdx]
    if not p or not p.alive then return end
    -- 5.2 使用startDrinking开始读条
    local drinkType = potionType or p.potionState
    if not drinkType then return end
    -- 胜利药水可在任何阶段使用, 其他药只能白天
    if drinkType ~= "victory" and gamePhase ~= "day" then return end
    if startDrinking(p, drinkType) then
        updateInventoryUI()
    end
end

function updateInventoryUI()
    local p = players[localPlayerIdx]
    if not p then return end

    local itemLabel = uiRoot_:FindById("invItemLabel")
    local potionIcon = uiRoot_:FindById("invPotionIcon")
    local drinkAntidoteBtn = uiRoot_:FindById("drinkAntidoteBtn")
    local drinkPoisonBtn = uiRoot_:FindById("drinkPoisonBtn")
    local desc = uiRoot_:FindById("invDesc")

    local isDrinking = p.drinkingState == "drinking"
    local isStunned = p.drinkingState == "stunned"
    local isAttacking = p.attackState ~= "idle"
    local noEnergy = p.energy < CONFIG.DrinkCostEnergy
    -- 按钮不可用条件: 正在喝药/硬直/攻击中/能量不足(胜利药水不检查能量)
    local cantDrink = isDrinking or isStunned or isAttacking
    local cantDrinkNormal = cantDrink or noEnergy

    -- 显示/隐藏药水图标
    if p.potionState and POTION_IMAGE_PATHS[p.potionState] then
        if potionIcon then
            potionIcon:SetBackgroundImage(POTION_IMAGE_PATHS[p.potionState])
            potionIcon:SetVisible(true)
        end
        if itemLabel then itemLabel:SetVisible(false) end
    else
        if potionIcon then potionIcon:SetVisible(false) end
        if itemLabel then itemLabel:SetVisible(true) end
    end

    if p.potionState == "victory" then
        if itemLabel then itemLabel:SetText("胜利药水") end
        if drinkAntidoteBtn then
            drinkAntidoteBtn:SetVisible(true)
            drinkAntidoteBtn:SetText("喝下胜利药水")
            drinkAntidoteBtn:SetDisabled(cantDrink)
        end
        if drinkPoisonBtn then drinkPoisonBtn:SetVisible(false) end
        if desc then desc:SetText("喝下即可获胜! 右键/点击道具按钮使用") end
    elseif p.potionState == "antidote" then
        if itemLabel then itemLabel:SetText("解药") end
        if drinkAntidoteBtn then
            drinkAntidoteBtn:SetVisible(true)
            drinkAntidoteBtn:SetDisabled(cantDrinkNormal)
        end
        if drinkPoisonBtn then drinkPoisonBtn:SetVisible(false) end
        if noEnergy and not cantDrink then
            if desc then desc:SetText("能量不足(需要10)!") end
        else
            if desc then desc:SetText("读条1.5秒解毒! 被打断掉落") end
        end
    elseif p.potionState == "poison" then
        if itemLabel then itemLabel:SetText("毒药") end
        if drinkPoisonBtn then
            drinkPoisonBtn:SetVisible(true)
            drinkPoisonBtn:SetDisabled(cantDrinkNormal)
        end
        if drinkAntidoteBtn then drinkAntidoteBtn:SetVisible(false) end
        if noEnergy and not cantDrink then
            if desc then desc:SetText("能量不足(需要10)!") end
        else
            if desc then desc:SetText("喝毒药: 被打断可转移毒素!") end
        end
    else
        if itemLabel then itemLabel:SetText("无药剂") end
        if drinkAntidoteBtn then drinkAntidoteBtn:SetVisible(false) end
        if drinkPoisonBtn then drinkPoisonBtn:SetVisible(false) end
        if desc then
            if isDrinking then
                desc:SetText("读条中...")
            elseif isStunned then
                desc:SetText("硬直中!")
            else
                desc:SetText("黑夜时获得药剂")
            end
        end
    end
end

function updateHUD()
    local p = players[localPlayerIdx]
    if not p then return end

    -- settle阶段隐藏HUD(全黑屏幕只显示NanoVG倒计时/淘汰页面)
    local hudPanel = uiRoot_:FindById("hudPanel")
    if hudPanel then
        local shouldHide = (gamePhase == "settle")
        hudPanel:SetVisible(not shouldHide)
    end
    if gamePhase == "settle" then
        return
    end

    local poisonLabel = uiRoot_:FindById("poisonLabel")
    if poisonLabel then
        poisonLabel:SetText("毒药: " .. math.floor(p.poison) .. "/" .. CONFIG.PoisonMax)
    end
    local energyLabel = uiRoot_:FindById("energyLabel")
    if energyLabel then
        energyLabel:SetText("能量: " .. math.floor(p.energy) .. "/" .. CONFIG.EnergyMax)
    end
    local roundLabel = uiRoot_:FindById("roundLabel")
    if roundLabel then
        local phaseText = ""
        if gamePhase == "prepare" then
            phaseText = " [准备]"
        elseif gamePhase == "day" then
            phaseText = " [白天]"
        elseif gamePhase == "settle" then
            phaseText = " [结算]"
        elseif gamePhase == "shrinking" then
            phaseText = " [缩圈]"
        end
        local remainDays = CONFIG.TotalRounds - currentRound + 1
        roundLabel:SetText("剩余 " .. remainDays .. " 天" .. phaseText)
    end
    local timerLabel = uiRoot_:FindById("timerLabel")
    if timerLabel then
        if gamePhase == "prepare" or gamePhase == "day" or gamePhase == "shrinking" then
            timerLabel:SetText(math.ceil(phaseTimer) .. "s")
        else
            timerLabel:SetText("")
        end
    end
    local aliveLabel = uiRoot_:FindById("aliveLabel")
    if aliveLabel then
        aliveLabel:SetText("存活: " .. getAliveCount() .. "/" .. CONFIG.PlayerCount)
    end
end

-- ============================================================================
-- 事件处理
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 背景音乐切歌检测
    updateBgm()

    -- 关卡编辑器更新(激活时拦截游戏输入)
    if levelEditor and levelEditor:IsActive() then
        local dpr = graphics:GetDPR()
        levelEditor:Update(dt, input, dpr)
        return  -- 编辑器激活时暂停游戏逻辑
    end

    -- 10.2 毒值警告cooldown
    if poisonWarnCooldown > 0 then poisonWarnCooldown = poisonWarnCooldown - dt end

    -- 舒适区冷却计时器更新
    for _, zone in ipairs(comfortZones) do
        if (zone.zoneCooldown or 0) > 0 then
            zone.zoneCooldown = zone.zoneCooldown - dt
            if zone.zoneCooldown <= 0 then
                zone.zoneCooldown = 0
                -- 冷却结束, 如果还有剩余次数则恢复能量
                if (zone.zoneUsesLeft or 0) > 0 then
                    zone.zoneEnergy = 100
                end
            end
        end
    end

    if gamePhase == "menu" then
        return
    end

    if gamePhase == "victory" or gamePhase == "defeat" then
        return
    end

    -- 结算阶段: 强制停止, 只更新计时器
    if gamePhase == "settle" then
        phaseTimer = phaseTimer - dt
        -- 倒计时音效: 每秒播放一次tick
        if settleSubPhase == "countdown" then
            local curSec = math.ceil(phaseTimer)
            if curSec ~= countdownLastSecond and curSec >= 1 and curSec <= 5 then
                countdownLastSecond = curSec
                playSound("sfx_tick", 0.8)
            end
        end
        if phaseTimer <= 0 then
            if settleSubPhase == "countdown" then
                -- 倒计时结束 → 执行淘汰
                enterSettleElimination()
            else
                -- 淘汰展示结束
                if victoryPotionGiven then
                    -- 胜利药水已发放, 直接进入白天让玩家喝药(不走正常enterDay流程)
                    gamePhase = "day"
                    phaseTimer = 30  -- 给30秒喝药
                    print("=== 胜利药水已发放, 等待喝下... ===")
                else
                    enterShrinking()
                end
            end
        end
        -- settle阶段不接受移动/攻击输入, 但更新视觉
        updateParticles(dt)
        updateDeathPieces(dt)
        updateAttackEffects(dt)
        updateFloatingTexts(dt)
        updateScreenShake(dt)
        for i = #statusEffects, 1, -1 do
            statusEffects[i].timer = statusEffects[i].timer - dt
            if statusEffects[i].timer <= 0 then table.remove(statusEffects, i) end
        end
        for i = #pickupGlows, 1, -1 do
            pickupGlows[i].timer = pickupGlows[i].timer - dt
            if pickupGlows[i].timer <= 0 then table.remove(pickupGlows, i) end
        end
        updateCamera()
        updateHUD()
        return
    end



    -- 玩家输入(prepare/night/shrinking均可移动)
    if not inventoryOpen then
        handlePlayerInput(dt)
    else
        -- 背包打开时每帧刷新按钮disabled状态(攻击后摇结束后立即可点)
        updateInventoryUI()
    end

    -- 手柄按键轮询(非移动操作: 背包/交互/使用物品等)
    local gamepad = getGamepad()
    if gamepad then
        local p = players[localPlayerIdx]
        if p and p.alive then
            -- Y键 = 打开/关闭背包(TAB)
            if gamepad:GetButtonPress(CONTROLLER_BUTTON_Y) then
                if gamePhase ~= "menu" and gamePhase ~= "victory" then
                    inventoryOpen = not inventoryOpen
                    local invPanel = uiRoot_:FindById("inventoryPanel")
                    if invPanel then invPanel:SetVisible(inventoryOpen) end
                    if inventoryOpen then updateInventoryUI() end
                end
            end
            -- X键 = 交互(E键)
            if gamepad:GetButtonPress(CONTROLLER_BUTTON_X) then
                if gamePhase == "day" then
                    if p.interactState == "idle" then
                        local targetIdx = findNearestInteractable(p)
                        if targetIdx then requestInteract(p, targetIdx) end
                    elseif p.interactState == "pending" then
                        acceptInteract(p)
                    end
                end
            end
            -- B键 = 使用物品/取消交互
            if gamepad:GetButtonPress(CONTROLLER_BUTTON_B) then
                if p.interactState ~= "idle" then
                    cancelInteract(p)
                elseif p.potionState and gamePhase == "day" then
                    useItem()
                elseif inventoryOpen then
                    inventoryOpen = false
                    local invPanel = uiRoot_:FindById("inventoryPanel")
                    if invPanel then invPanel:SetVisible(false) end
                end
            end
            -- DPAD UP/DOWN = 交互中选择给予解药/毒药(1/2键)
            if p.interactState == "interacting" and p.potionState then
                if gamepad:GetButtonPress(CONTROLLER_BUTTON_DPAD_UP) then
                    giveItem(p, "antidote")
                elseif gamepad:GetButtonPress(CONTROLLER_BUTTON_DPAD_DOWN) then
                    giveItem(p, "poison")
                end
            end
            -- START键 = 开始游戏(菜单界面)
            if gamepad:GetButtonPress(CONTROLLER_BUTTON_START) then
                if gamePhase == "menu" then
                    startGame()
                end
            end
        elseif gamePhase == "menu" then
            -- 菜单界面任意按键开始
            if gamepad:GetButtonPress(CONTROLLER_BUTTON_A) or gamepad:GetButtonPress(CONTROLLER_BUTTON_START) then
                startGame()
            end
        end
    end

    -- 游戏阶段逻辑
    if gamePhase == "prepare" then
        phaseTimer = phaseTimer - dt
        if phaseTimer <= 0 then
            enterDay()
        end
    elseif gamePhase == "day" then
        phaseTimer = phaseTimer - dt
        -- 9.1 白天期间渐进缩圈(60秒内平滑收缩至目标半径)
        if circle.radius > circle.targetRadius and circle.shrinkSpeed > 0 then
            circle.radius = circle.radius - circle.shrinkSpeed * dt
            if circle.radius <= circle.targetRadius then
                circle.radius = circle.targetRadius
            end
        end
        if phaseTimer <= 0 then
            if victoryPotionGiven then
                -- 胜利药水阶段: 不进settle, 持续等待喝药
                phaseTimer = 30
            else
                enterSettle()
            end
        end
    elseif gamePhase == "shrinking" then
        phaseTimer = phaseTimer - dt
        -- shrinking阶段仅作过渡(1秒), 不再做半径变化
        -- 缩圈过渡结束 → 下一轮白天开始(缩圈在day阶段60s内渐进完成)
        if phaseTimer <= 0 then
            enterDay()
        end
    end

    -- 更新所有玩家
    updatePlayers(dt)
    -- 5.3 更新地面药剂(拾取检测, 仅day阶段)
    if gamePhase == "day" then
        updateGroundPotions(dt)
    end
    updateParticles(dt)
    updateDeathPieces(dt)
    updateAttackEffects(dt)
    updateFloatingTexts(dt)
    updateScreenShake(dt)
    -- 更新状态特效
    for i = #statusEffects, 1, -1 do
        statusEffects[i].timer = statusEffects[i].timer - dt
        if statusEffects[i].timer <= 0 then
            table.remove(statusEffects, i)
        end
    end
    -- 更新物品光效
    for i = #pickupGlows, 1, -1 do
        pickupGlows[i].timer = pickupGlows[i].timer - dt
        if pickupGlows[i].timer <= 0 then
            table.remove(pickupGlows, i)
        end
    end
    updateCamera()

    -- 更新HUD
    updateHUD()

    -- 检查胜利/失败
    if gamePhase ~= "victory" and gamePhase ~= "defeat" then
        local aliveCount = getAliveCount()
        if aliveCount == 0 then
            gamePhase = "defeat"
            local hud = uiRoot_:FindById("hudPanel")
            if hud then hud:SetVisible(false) end
        elseif aliveCount == 1 and not victoryPotionGiven then
            -- 发放胜利药水给最后存活者
            for i = 1, #players do
                if players[i].alive then
                    victoryWinnerIdx = i
                    players[i].potionState = "victory"
                    players[i].poison = 0
                    victoryPotionGiven = true
                    table.insert(statusEffects, { playerIdx = i, type = "detox", timer = 3.0 })
                    print("=== 玩家 " .. i .. " 获得胜利药水! ===")
                    break
                end
            end
        end
    end

    -- 玩家死亡检查
    local lp = players[localPlayerIdx]
    if lp and not lp.alive and gamePhase ~= "victory" and gamePhase ~= "defeat" then
        -- 玩家死了但游戏未结束，可以观战
        local tipLabel = uiRoot_:FindById("tipLabel")
        if tipLabel then tipLabel:SetText("你已被淘汰，观战中...") end
    end
end

---@param eventType string
---@param eventData MouseButtonDownEventData
function HandleMouseDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()

    -- 编辑器激活时拦截鼠标
    if levelEditor and levelEditor:IsActive() then
        levelEditor:HandleMouseDown(button)
        return
    end

    if button == MOUSEB_LEFT then
        -- 胜利/失败画面: 检测返回主页按钮点击
        if gamePhase == "victory" or gamePhase == "defeat" then
            local graphics = GetGraphics()
            local dpr = graphics:GetDPR()
            local mx = input:GetMousePosition().x / dpr
            local my = input:GetMousePosition().y / dpr
            local r = backToMenuBtnRect
            if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
                backToMenu()
            end
            return
        end

        if gamePhase == "day" then
            if not inventoryOpen then
                local p = players[localPlayerIdx]
                if p and p.alive then
                    performAttack(p)
                end
            end
        end
    elseif button == MOUSEB_RIGHT then
        -- 背包中右键使用物品
        if inventoryOpen then
            useItem()
        end
    end
end

function HandleMouseUp(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if levelEditor and levelEditor:IsActive() then
        levelEditor:HandleMouseUp(button)
    end
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- F3 键: 切换关卡编辑器
    if key == KEY_F3 then
        if levelEditor then
            local isOpen = levelEditor:Toggle()
            print(isOpen and "[编辑器] 已打开 - Tab切模式, Enter应用" or "[编辑器] 已关闭")
            -- 隐藏/显示游戏UI组件
            if uiRoot_ then
                local hud = uiRoot_:FindById("hudPanel")
                if hud then hud:SetVisible(not isOpen) end
                local inv = uiRoot_:FindById("inventoryPanel")
                if inv then inv:SetVisible(false) end
            end
        end
        return
    end

    -- 编辑器激活时, 优先处理编辑器按键
    if levelEditor and levelEditor:IsActive() then
        if levelEditor:HandleKeyDown(key) then return end
    end

    if key == KEY_TAB then
        if gamePhase ~= "menu" and gamePhase ~= "victory" then
            inventoryOpen = not inventoryOpen
            local invPanel = uiRoot_:FindById("inventoryPanel")
            if invPanel then invPanel:SetVisible(inventoryOpen) end
            if inventoryOpen then
                updateInventoryUI()
            end
        end
    elseif key == KEY_ESCAPE then
        if inventoryOpen then
            inventoryOpen = false
            local invPanel = uiRoot_:FindById("inventoryPanel")
            if invPanel then invPanel:SetVisible(false) end
        end
    elseif key == KEY_E then
        -- 8.1 交互键: E键发起/接受交互
        if gamePhase == "day" then
            local p = players[localPlayerIdx]
            if p and p.alive then
                if p.interactState == "idle" then
                    -- 寻找最近可交互玩家并发起请求
                    local targetIdx = findNearestInteractable(p)
                    if targetIdx then
                        requestInteract(p, targetIdx)
                    end
                elseif p.interactState == "pending" then
                    -- 接受交互请求
                    acceptInteract(p)
                end
            end
        end
    elseif key == KEY_Q then
        -- 8.1 取消交互
        if gamePhase == "day" then
            local p = players[localPlayerIdx]
            if p and p.alive and p.interactState ~= "idle" then
                cancelInteract(p)
            end
        end
    elseif key == KEY_1 then
        -- 8.2 交互中选择给予解药
        if gamePhase == "day" then
            local p = players[localPlayerIdx]
            if p and p.alive and p.interactState == "interacting" and p.potionState then
                giveItem(p, "antidote")
            end
        end
    elseif key == KEY_2 then
        -- 8.2 交互中选择给予毒药
        if gamePhase == "day" then
            local p = players[localPlayerIdx]
            if p and p.alive and p.interactState == "interacting" and p.potionState then
                giveItem(p, "poison")
            end
        end
    end
end

-- ============================================================================
-- 手柄连接/断开事件
-- ============================================================================

function HandleJoystickConnected(eventType, eventData)
    local id = eventData:GetInt("JoystickID")
    local js = input:GetJoystick(id)
    if js then
        if js:IsController() then
            print("[手柄] 手柄已连接: " .. js.name .. " (ID=" .. id .. ")")
        else
            print("[手柄] 摇杆设备已连接: " .. js.name .. " (非标准手柄)")
        end
    end
end

function HandleJoystickDisconnected(eventType, eventData)
    local id = eventData:GetInt("JoystickID")
    print("[手柄] 设备已断开 (ID=" .. id .. ")")
end

-- ============================================================================
-- 触摸事件处理(手机适配)
-- ============================================================================

-- 获取触控按钮区域(基于屏幕逻辑尺寸)
local function getTouchButtonRects(logW, logH)
    local btnSize = 60
    local itemBtnSize = 120  -- 道具按钮放大两倍
    local margin = 20
    local bottomY = logH - margin - btnSize
    -- 右侧: 攻击按钮(右下) + 道具按钮(攻击上方, 放大两倍)
    local rightX = logW - margin - btnSize
    local itemRightX = logW - margin - itemBtnSize
    -- 奔跑按钮(攻击按钮左侧)
    local sprintX = rightX - btnSize - 12
    local sprintY = bottomY
    -- 交换药水按钮(道具按钮左侧)
    local interactX = itemRightX - btnSize - 12
    local interactY = bottomY - itemBtnSize - 15
    -- 拒绝交换按钮(交换按钮左侧)
    local rejectX = interactX - btnSize - 8
    local rejectY = interactY
    return {
        attack = { x = rightX, y = bottomY, w = btnSize, h = btnSize },
        item = { x = itemRightX, y = bottomY - itemBtnSize - 15, w = itemBtnSize, h = itemBtnSize },
        sprint = { x = sprintX, y = sprintY, w = btnSize, h = btnSize },
        interact = { x = interactX, y = interactY, w = btnSize, h = btnSize },
        reject = { x = rejectX, y = rejectY, w = btnSize, h = btnSize },
    }
end

local function pointInRect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

---@param eventType string
---@param eventData TouchBeginEventData
function HandleTouchBegin(eventType, eventData)
    isTouchDevice = true
    local touchId = eventData["TouchID"]:GetInt()
    local rawX = eventData["X"]:GetInt()
    local rawY = eventData["Y"]:GetInt()

    local graphics = GetGraphics()
    local dpr = graphics:GetDPR()
    local logW = graphics:GetWidth() / dpr
    local logH = graphics:GetHeight() / dpr
    local tx = rawX / dpr
    local ty = rawY / dpr

    -- 胜利/失败画面: 检测返回主页按钮点击
    if gamePhase == "victory" or gamePhase == "defeat" then
        local r = backToMenuBtnRect
        if tx >= r.x and tx <= r.x + r.w and ty >= r.y and ty <= r.y + r.h then
            backToMenu()
        end
        return
    end

    -- 检查是否点击了右侧按钮
    local rects = getTouchButtonRects(logW, logH)

    if pointInRect(tx, ty, rects.attack) then
        touchButtons.attack.pressed = true
        touchButtons.attack.touchId = touchId
        -- 执行攻击
        if gamePhase == "day" then
            local p = players[localPlayerIdx]
            if p and p.alive and not p.isGhost then
                performAttack(p)
            end
        end
        return
    end

    if pointInRect(tx, ty, rects.item) then
        touchButtons.item.pressed = true
        touchButtons.item.touchId = touchId
        -- 使用背包道具
        if gamePhase == "day" then
            local p = players[localPlayerIdx]
            if p and p.alive and not p.isGhost then
                useItem()
            end
        end
        return
    end

    if pointInRect(tx, ty, rects.sprint) then
        touchButtons.sprint.pressed = true
        touchButtons.sprint.touchId = touchId
        return
    end

    if pointInRect(tx, ty, rects.interact) then
        touchButtons.interact.pressed = true
        touchButtons.interact.touchId = touchId
        -- 交换药水: 发起请求或接受请求
        if gamePhase == "day" then
            local p = players[localPlayerIdx]
            if p and p.alive and not p.isGhost then
                if p.interactState == "pending" then
                    -- 接受对方的交换请求
                    acceptInteract(p)
                elseif p.interactState == "idle" then
                    -- 发起交换请求(找最近的玩家)
                    local bestIdx = -1
                    local bestDist = CONFIG.InteractRange
                    for i = 1, #players do
                        local other = players[i]
                        if other.idx ~= p.idx and other.alive and other.interactState == "idle"
                            and other.drinkingState == "idle" then
                            local d = dist(p.x, p.y, other.x, other.y)
                            if d < bestDist then
                                bestDist = d
                                bestIdx = i
                            end
                        end
                    end
                    if bestIdx > 0 then
                        requestInteract(p, bestIdx)
                    end
                end
            end
        end
        return
    end

    if pointInRect(tx, ty, rects.reject) then
        touchButtons.reject.pressed = true
        touchButtons.reject.touchId = touchId
        -- 拒绝交换药水
        if gamePhase == "day" then
            local p = players[localPlayerIdx]
            if p and p.alive and p.interactState ~= "idle" then
                cancelInteract(p)
            end
        end
        return
    end

    -- 左半屏: 虚拟摇杆
    if tx < logW * 0.5 and not touchJoystick.active then
        touchJoystick.active = true
        touchJoystick.touchId = touchId
        touchJoystick.cx = tx
        touchJoystick.cy = ty
        touchJoystick.dx = 0
        touchJoystick.dy = 0
    end
end

---@param eventType string
---@diagnostic disable-next-line: undefined-doc-name
---@param eventData TouchMoveEventData
function HandleTouchMove(eventType, eventData)
    local touchId = eventData["TouchID"]:GetInt()
    local rawX = eventData["X"]:GetInt()
    local rawY = eventData["Y"]:GetInt()

    local graphics = GetGraphics()
    local dpr = graphics:GetDPR()
    local tx = rawX / dpr
    local ty = rawY / dpr

    -- 更新摇杆
    if touchJoystick.active and touchJoystick.touchId == touchId then
        touchJoystick.dx = tx - touchJoystick.cx
        touchJoystick.dy = ty - touchJoystick.cy
        -- 限制在最大半径内
        local jLen = math.sqrt(touchJoystick.dx * touchJoystick.dx + touchJoystick.dy * touchJoystick.dy)
        if jLen > touchJoystick.radius then
            touchJoystick.dx = touchJoystick.dx / jLen * touchJoystick.radius
            touchJoystick.dy = touchJoystick.dy / jLen * touchJoystick.radius
        end
    end
end

---@param eventType string
---@diagnostic disable-next-line: undefined-doc-name
---@param eventData TouchEndEventData
function HandleTouchEnd(eventType, eventData)
    local touchId = eventData["TouchID"]:GetInt()

    -- 释放按钮
    if touchButtons.attack.touchId == touchId then
        touchButtons.attack.pressed = false
        touchButtons.attack.touchId = -1
    end
    if touchButtons.item.touchId == touchId then
        touchButtons.item.pressed = false
        touchButtons.item.touchId = -1
    end
    if touchButtons.sprint.touchId == touchId then
        touchButtons.sprint.pressed = false
        touchButtons.sprint.touchId = -1
    end
    if touchButtons.interact.touchId == touchId then
        touchButtons.interact.pressed = false
        touchButtons.interact.touchId = -1
    end
    if touchButtons.reject.touchId == touchId then
        touchButtons.reject.pressed = false
        touchButtons.reject.touchId = -1
    end

    -- 释放摇杆
    if touchJoystick.touchId == touchId then
        touchJoystick.active = false
        touchJoystick.touchId = -1
        touchJoystick.dx = 0
        touchJoystick.dy = 0
    end
end

-- ============================================================================
-- 饥荒风格渲染系统
-- ============================================================================

-- 程序化地形数据(只在游戏开始时生成一次)
local mapDecorations = {}  -- 环境装饰物(树、石头、草丛)
local groundPatches = {}   -- 地面斑块(草地纹理碎片)
local decorationsGenerated = false

-- 编辑器应用时重置装饰生成标记(允许重新生成)
function ResetDecorations()
    decorationsGenerated = false
    mapDecorations = {}
    groundPatches = {}
end

-- 全局访问函数(供编辑器直接修改真实游戏数据)
function GetMapDecorations()
    return mapDecorations
end

function GetComfortZones()
    return comfortZones
end

-- 简单hash函数用于程序化生成(确定性随机)
local function hashPos(x, y, seed)
    local h = (x * 374761393 + y * 668265263 + seed * 1274126177) % 2147483647
    return (h % 1000) / 1000.0  -- 返回0~1
end

-- 生成环境装饰数据
local function generateMapDecorations()
    if decorationsGenerated then return end
    decorationsGenerated = true

    -- 生成草丛碎片(密集, 用于地面纹理感)
    local patchSpacing = 48
    for gx = 0, CONFIG.MapSize, patchSpacing do
        for gy = 0, CONFIG.MapSize, patchSpacing do
            local h = hashPos(gx, gy, 42)
            if h > 0.25 then
                local px = gx + (hashPos(gx, gy, 100) - 0.5) * patchSpacing
                local py = gy + (hashPos(gx, gy, 200) - 0.5) * patchSpacing
                local size = 12 + hashPos(gx, gy, 300) * 28
                local variant = math.floor(hashPos(gx, gy, 400) * 4) -- 0-3种草丛样式
                local shade = hashPos(gx, gy, 500) -- 色调变化
                table.insert(groundPatches, {
                    x = px, y = py, size = size, variant = variant, shade = shade,
                })
            end
        end
    end

    -- 生成树木(稀疏, 大型装饰)
    local treeSpacing = 200
    for gx = 100, CONFIG.MapSize - 100, treeSpacing do
        for gy = 100, CONFIG.MapSize - 100, treeSpacing do
            local h = hashPos(gx, gy, 777)
            if h > 0.6 then
                local tx = gx + (hashPos(gx, gy, 800) - 0.5) * treeSpacing * 0.7
                local ty = gy + (hashPos(gx, gy, 900) - 0.5) * treeSpacing * 0.7
                local height = 120 + hashPos(gx, gy, 1000) * 160
                local twist = (hashPos(gx, gy, 1100) - 0.5) * 0.6
                local branches = 2 + math.floor(hashPos(gx, gy, 1200) * 4)
                table.insert(mapDecorations, {
                    type = "tree",
                    x = tx, y = ty,
                    height = height, twist = twist, branches = branches,
                    seed = gx * 100 + gy,
                })
            end
        end
    end

    -- 生成岩石(中等密度)
    local rockSpacing = 300
    for gx = 50, CONFIG.MapSize - 50, rockSpacing do
        for gy = 50, CONFIG.MapSize - 50, rockSpacing do
            local h = hashPos(gx, gy, 1500)
            if h > 0.55 then
                local rx = gx + (hashPos(gx, gy, 1600) - 0.5) * rockSpacing * 0.6
                local ry = gy + (hashPos(gx, gy, 1700) - 0.5) * rockSpacing * 0.6
                local size = 16 + hashPos(gx, gy, 1800) * 36
                table.insert(mapDecorations, {
                    type = "rock",
                    x = rx, y = ry, size = size,
                    seed = gx * 100 + gy,
                })
            end
        end
    end

    -- 生成花朵(较密, 小型装饰)
    local flowerSpacing = 180
    for gx = 60, CONFIG.MapSize - 60, flowerSpacing do
        for gy = 60, CONFIG.MapSize - 60, flowerSpacing do
            local h = hashPos(gx, gy, 2100)
            if h > 0.45 then
                local fx = gx + (hashPos(gx, gy, 2200) - 0.5) * flowerSpacing * 0.7
                local fy = gy + (hashPos(gx, gy, 2300) - 0.5) * flowerSpacing * 0.7
                local variant = 1 + math.floor(hashPos(gx, gy, 2400) * #DECO_FLOWER_PATHS)
                variant = math.min(variant, #DECO_FLOWER_PATHS)
                table.insert(mapDecorations, {
                    type = "flower",
                    x = fx, y = fy,
                    variant = variant,
                    size = 24 + hashPos(gx, gy, 2500) * 16,
                    seed = gx * 100 + gy,
                })
            end
        end
    end

    -- 生成草丛/植物(中等密度)
    local plantSpacing = 150
    for gx = 40, CONFIG.MapSize - 40, plantSpacing do
        for gy = 40, CONFIG.MapSize - 40, plantSpacing do
            local h = hashPos(gx, gy, 2600)
            if h > 0.5 then
                local px = gx + (hashPos(gx, gy, 2700) - 0.5) * plantSpacing * 0.6
                local py = gy + (hashPos(gx, gy, 2800) - 0.5) * plantSpacing * 0.6
                local variant = 1 + math.floor(hashPos(gx, gy, 2900) * #DECO_PLANT_PATHS)
                variant = math.min(variant, #DECO_PLANT_PATHS)
                table.insert(mapDecorations, {
                    type = "plant",
                    x = px, y = py,
                    variant = variant,
                    size = 30 + hashPos(gx, gy, 3000) * 20,
                    seed = gx * 100 + gy,
                })
            end
        end
    end

    -- 7.1 生成初始舒适区(在初始安全区内, 满足距离约束)
    comfortZones = {}
    comfortFloats = {}
    generateComfortZones(CONFIG.MapSize / 2, CONFIG.MapSize / 2, circleInitRadius)

    -- 编辑器出生点配置同步(编辑器直接修改 mapDecorations/comfortZones 引用)
    if levelEditor then
        local spawnCfg = levelEditor:GetSpawnConfig()
        if spawnCfg then
            editorSpawnConfig = spawnCfg
        end
    end

    -- 按Y坐标排序(简单深度排序)
    table.sort(mapDecorations, function(a, b) return a.y < b.y end)

    print("[饥荒渲染] 生成装饰: 草丛=" .. #groundPatches .. " 树木/岩石=" .. #mapDecorations .. " 舒适区=" .. #comfortZones)
end

-- ============================================================================
-- NanoVG 渲染主入口
-- ============================================================================

function HandleRender(eventType, eventData)
    if nvgContext == nil then return end
    if gamePhase == "menu" then return end

    if gamePhase == "victory" or gamePhase == "defeat" then
        local graphics = GetGraphics()
        local screenW = graphics:GetWidth()
        local screenH = graphics:GetHeight()
        local dpr = graphics:GetDPR()
        local logW = screenW / dpr
        local logH = screenH / dpr
        nvgBeginFrame(nvgContext, logW, logH, dpr)
        if gamePhase == "victory" then
            drawVictoryScreen(logW, logH)
        else
            drawDefeatScreen(logW, logH)
        end
        nvgEndFrame(nvgContext)
        return
    end

    -- 确保装饰数据已生成
    generateMapDecorations()

    local graphics = GetGraphics()
    local screenW = graphics:GetWidth()
    local screenH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local logW = screenW / dpr
    local logH = screenH / dpr

    nvgBeginFrame(nvgContext, logW, logH, dpr)

    -- 坐标变换: 世界坐标 → 屏幕坐标(含4.3屏幕震动偏移)
    local shakeOX = 0
    local shakeOY = 0
    if screenShake.timer > 0 then
        shakeOX = (math.random() - 0.5) * 2 * screenShake.intensity
        shakeOY = (math.random() - 0.5) * 2 * screenShake.intensity
    end
    -- ===== 相机缩放(编辑器激活时使用编辑器缩放, 否则2x) =====
    local CAM_ZOOM = 2.0
    if levelEditor and levelEditor:IsActive() then
        CAM_ZOOM = 2.0 * levelEditor.editorZoom
    end
    local offsetX = logW / 2 / CAM_ZOOM - camera.x + shakeOX
    local offsetY = logH / 2 / CAM_ZOOM - camera.y + shakeOY

    -- 应用缩放变换(世界渲染区域)
    nvgSave(nvgContext)
    nvgTranslate(nvgContext, logW / 2, logH / 2)
    nvgScale(nvgContext, CAM_ZOOM, CAM_ZOOM)
    nvgTranslate(nvgContext, -logW / 2 / CAM_ZOOM, -logH / 2 / CAM_ZOOM)

    -- 所有游戏阶段正常渲染(不再有全屏黑/淘汰展示页)
    -- 1. 绘制地面(饥荒风格泥土/草地)
    drawGroundDST(logW / CAM_ZOOM, logH / CAM_ZOOM, offsetX, offsetY)

    -- 2. 绘制地面草丛纹理
    drawGroundPatches(logW / CAM_ZOOM, logH / CAM_ZOOM, offsetX, offsetY)

    -- 3. 绘制毒圈
    drawPoisonCircleDST(offsetX, offsetY)

    -- 3.5 绘制舒适区光圈
    drawComfortZones(offsetX, offsetY)

    -- 3.6 绘制死亡污渍和纸片
    drawDeathEffects(offsetX, offsetY)

    -- 4. 绘制环境装饰(树木、岩石 - 按深度与玩家交错)
    drawEnvironmentAndPlayers(logW / CAM_ZOOM, logH / CAM_ZOOM, offsetX, offsetY)

    -- 5. 绘制攻击特效
    drawAttackEffectsDST(offsetX, offsetY)

    -- 6. 绘制粒子
    drawParticlesDST(offsetX, offsetY)

    -- 6.5 绘制浮动文字(4.3 命中反馈)
    drawFloatingTexts(offsetX, offsetY)

    -- 8.2 绘制交互UI(按钮提示+选项面板+抛物线动画)
    drawInteractionUI(logW / CAM_ZOOM, logH / CAM_ZOOM, offsetX, offsetY)

    -- 恢复缩放变换(后续HUD在屏幕空间绘制)
    nvgRestore(nvgContext)

    -- 编辑器激活时: 跳过所有游戏UI, 只渲染编辑器覆盖
    if levelEditor and levelEditor:IsActive() then
        levelEditor:Render(logW, logH, dpr)
    else
        -- 7. 暗角效果(Vignette)
        drawVignette(logW, logH)

        -- 7.5 黑夜亮度下降(settle阶段全黑)
        if gamePhase == "settle" then
            nvgBeginPath(nvgContext)
            nvgRect(nvgContext, 0, 0, logW, logH)
            nvgFillColor(nvgContext, nvgRGBA(0, 0, 0, 255))
            nvgFill(nvgContext)
        end

        -- settle阶段: 倒计时子阶段只显示5秒倒计时, 淘汰子阶段显示死亡列表
        if gamePhase == "settle" and settleSubPhase == "countdown" then
            drawClockCountdown(logW, logH)
            drawPhaseHint(logW, logH)
        elseif gamePhase == "settle" and settleSubPhase == "elimination" then
            drawEliminationPage(logW, logH)
            drawPhaseHint(logW, logH)
        elseif gamePhase ~= "settle" then
            -- 正常阶段渲染
            drawPoisonScreenOverlay(logW, logH)
            drawClockCountdown(logW, logH)
            drawPhaseHint(logW, logH)
            drawOffscreenIndicators(logW, logH, offsetX, offsetY, CAM_ZOOM)
        end

        -- 11. 触控按钮(手机适配)
        if isTouchDevice and gamePhase ~= "menu" and gamePhase ~= "victory" and gamePhase ~= "defeat" then
            drawTouchControls(logW, logH)
        end
    end

    -- 自定义鼠标光标(最顶层绘制)
    if cursorImage and not isTouchDevice then
        local mousePos = input:GetMousePosition()
        local mx = mousePos.x / dpr
        local my = mousePos.y / dpr
        local cursorSize = 32
        nvgSave(nvgContext)
        nvgResetTransform(nvgContext)
        local imgPaint = nvgImagePattern(nvgContext, mx - 2, my - 2, cursorSize, cursorSize, 0, cursorImage, 1.0)
        nvgBeginPath(nvgContext)
        nvgRect(nvgContext, mx - 2, my - 2, cursorSize, cursorSize)
        nvgFillPaint(nvgContext, imgPaint)
        nvgFill(nvgContext)
        nvgRestore(nvgContext)
    end

    nvgEndFrame(nvgContext)
end

-- ============================================================================
-- 地面渲染(饥荒风 - 深色泥土地面)
-- ============================================================================

function drawGroundDST(logW, logH, ox, oy)
    local ctx = nvgContext
    local isDay = (gamePhase == "prepare" or gamePhase == "day" or gamePhase == "shrinking")

    -- 基础地面色
    local bgR, bgG, bgB
    if isDay then
        bgR, bgG, bgB = 38, 34, 26
    else
        bgR, bgG, bgB = 14, 12, 10
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, logW, logH)
    nvgFillColor(ctx, nvgRGBA(bgR, bgG, bgB, 255))
    nvgFill(ctx)

    -- 地形贴图铺地(64px chunk, 与编辑器网格对齐)
    local tileSize = 64
    local terrainOX = levelEditor and levelEditor.mapOriginX or 0
    local terrainOY = levelEditor and levelEditor.mapOriginY or 0
    local viewLeft = camera.x - logW / 2 - tileSize
    local viewRight = camera.x + logW / 2 + tileSize
    local viewTop = camera.y - logH / 2 - tileSize
    local viewBottom = camera.y + logH / 2 + tileSize

    local startCX = math.floor((viewLeft - terrainOX) / tileSize) * tileSize + terrainOX
    local startCY = math.floor((viewTop - terrainOY) / tileSize) * tileSize + terrainOY

    -- 根据位置确定地形类型(优先使用编辑器数据)
    local function getTerrainType(wx, wy)
        -- 编辑器已应用地形时, 使用编辑器瓦片数据
        if levelEditor and levelEditor:IsTerrainExported() then
            local editorKey = levelEditor:GetTerrainImageKey(wx, wy)
            if editorKey then return editorKey end
        end

        local dToCenter = dist(wx + tileSize * 0.5, wy + tileSize * 0.5, circle.cx, circle.cy)
        local inPoison = dToCenter > circle.radius

        if inPoison then
            -- 毒圈外: 沼泽/火山岩
            local h = hashPos(wx, wy, 77)
            if h > 0.6 then
                return "volcanic"
            else
                return "swamp"
            end
        else
            -- 安全区内: 草地/泥地/碎石/枯草/森林多种混合
            local h = hashPos(wx, wy, 33)
            if h > 0.82 then
                return "rocky"
            elseif h > 0.65 then
                return "mud"
            elseif h > 0.5 then
                return "dead_grass"
            elseif h > 0.35 then
                return "forest"
            else
                return "grass"
            end
        end
    end

    for cx = startCX, viewRight, tileSize do
        for cy = startCY, viewBottom, tileSize do
            local terrainType = getTerrainType(cx, cy)
            local img = terrainImages[terrainType]
            if img then
                local sx = cx + ox
                local sy = cy + oy

                -- 使用 imagePattern 铺贴图(世界坐标偏移实现无缝)
                local paint = nvgImagePattern(ctx, sx, sy, tileSize, tileSize, 0, img, 1.0)
                nvgBeginPath(ctx)
                nvgRect(ctx, sx, sy, tileSize, tileSize)
                nvgFillPaint(ctx, paint)
                nvgFill(ctx)

                -- 夜间降低亮度
                if not isDay then
                    nvgBeginPath(ctx)
                    nvgRect(ctx, sx, sy, tileSize, tileSize)
                    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 160))
                    nvgFill(ctx)
                end
            end
        end
    end

    -- 毒圈外冒绿色气泡(动态)
    if isDay then
        local time = GetTime():GetElapsedTime()
        local bubbleCount = 12
        for i = 1, bubbleCount do
            local angle = (i / bubbleCount) * math.pi * 2 + time * 0.3
            local bDist = circle.radius + 40 + hashPos(i, 0, 7777) * 200
            local bx = circle.cx + math.cos(angle) * bDist + ox
            local by = circle.cy + math.sin(angle) * bDist + oy
            if bx > -20 and bx < logW + 20 and by > -20 and by < logH + 20 then
                local bubbleR = 3 + math.sin(time * 2 + i) * 1.5
                local bubbleA = math.floor(80 + math.sin(time * 3 + i * 1.7) * 40)
                nvgBeginPath(ctx)
                nvgCircle(ctx, bx, by, bubbleR)
                nvgFillColor(ctx, nvgRGBA(46, 74, 62, bubbleA))
                nvgFill(ctx)
            end
        end
    end
end

-- ============================================================================
-- 草丛纹理(饥荒风 - 短草/枯叶散落)
-- ============================================================================

function drawGroundPatches(logW, logH, ox, oy)
    local ctx = nvgContext
    local isDay = (gamePhase == "prepare" or gamePhase == "day" or gamePhase == "shrinking")

    local viewLeft = camera.x - logW / 2 - 30
    local viewRight = camera.x + logW / 2 + 30
    local viewTop = camera.y - logH / 2 - 30
    local viewBottom = camera.y + logH / 2 + 30

    for i = 1, #groundPatches do
        local patch = groundPatches[i]
        if patch.x >= viewLeft and patch.x <= viewRight
           and patch.y >= viewTop and patch.y <= viewBottom then

            local sx = patch.x + ox
            local sy = patch.y + oy
            local size = patch.size

            -- 判断在圈内还是圈外
            local dToCenter = dist(patch.x, patch.y, circle.cx, circle.cy)
            local inPoison = dToCenter > circle.radius

            -- 颜色: 暗褐枯叶/碎石(饱和度<=40%)
            local gr, gg, gb, ga
            if inPoison then
                -- 毒圈外: 紫黑枯萎
                if isDay then
                    gr, gg, gb, ga = 35, 28, 42, 90    -- 暗紫枯
                else
                    gr, gg, gb, ga = 12, 10, 16, 70
                end
            else
                -- 安全区: 枯叶碎石
                if isDay then
                    if patch.shade > 0.7 then
                        gr, gg, gb, ga = 55, 48, 30, 100   -- 枯黄叶
                    elseif patch.shade > 0.4 then
                        gr, gg, gb, ga = 60, 55, 40, 85    -- 碎石灰
                    else
                        gr, gg, gb, ga = 45, 38, 25, 75    -- 暗泥
                    end
                else
                    gr, gg, gb, ga = 15, 12, 10, 70
                end
            end

            -- 根据variant绘制不同形状
            if patch.variant == 0 then
                -- 枯叶(弯曲短线)
                nvgStrokeColor(ctx, nvgRGBA(gr, gg, gb, ga))
                nvgStrokeWidth(ctx, 1.5)
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, sx - 2, sy + size * 0.2)
                nvgQuadTo(ctx, sx - 1, sy - size * 0.2, sx + 1, sy - size * 0.35)
                nvgMoveTo(ctx, sx + 1, sy + size * 0.2)
                nvgQuadTo(ctx, sx + 2, sy - size * 0.1, sx + 3, sy - size * 0.3)
                nvgStroke(ctx)
            elseif patch.variant == 1 then
                -- 碎石(小多边形)
                nvgBeginPath(ctx)
                nvgEllipse(ctx, sx, sy, size * 0.35, size * 0.25)
                nvgFillColor(ctx, nvgRGBA(gr + 10, gg + 8, gb + 5, ga - 20))
                nvgFill(ctx)
                nvgStrokeColor(ctx, nvgRGBA(gr - 15, gg - 15, gb - 10, ga - 10))
                nvgStrokeWidth(ctx, 1)
                nvgStroke(ctx)
            elseif patch.variant == 2 then
                -- 裂缝(交叉线)
                nvgStrokeColor(ctx, nvgRGBA(gr - 10, gg - 10, gb - 8, ga - 30))
                nvgStrokeWidth(ctx, 1)
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, sx - size * 0.25, sy - size * 0.1)
                nvgLineTo(ctx, sx + size * 0.2, sy + size * 0.1)
                nvgMoveTo(ctx, sx - size * 0.1, sy - size * 0.2)
                nvgLineTo(ctx, sx + size * 0.15, sy + size * 0.15)
                nvgStroke(ctx)
            else
                -- 碎屑点
                nvgBeginPath(ctx)
                nvgCircle(ctx, sx, sy, size * 0.15)
                nvgFillColor(ctx, nvgRGBA(gr, gg, gb, ga - 30))
                nvgFill(ctx)
            end
        end
    end
end

-- ============================================================================
-- 毒圈渲染(饥荒风 - 紫雾边界)
-- ============================================================================

function drawPoisonCircleDST(ox, oy)
    local ctx = nvgContext
    local time = GetTime():GetElapsedTime()

    local cx = circle.cx + ox
    local cy = circle.cy + oy
    local r = circle.radius
    local fogW = CONFIG.CircleFogWidth

    -- 9.3 外部: 紫黑色沼泽(边界外全屏半透明紫黑色覆盖)
    -- 用一个大矩形减去圆来模拟外部区域
    nvgSave(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, cx - 3000, cy - 3000, 6000, 6000)
    -- 以路径hole方式减去安全圈(内圆)
    nvgPathWinding(ctx, NVG_HOLE)
    nvgCircle(ctx, cx, cy, r + fogW * 0.5)
    nvgFillColor(ctx, nvgRGBA(30, 10, 40, 100))  -- 紫黑色覆盖
    nvgFill(ctx)
    nvgRestore(ctx)

    -- 9.3 边界: 50像素宽的翻滚暗绿色雾霭带(墨汁晕染效果)
    -- 多层渐变模拟雾霭
    for layer = 5, 1, -1 do
        local layerOffset = (layer - 3) * (fogW / 5)
        local layerR = r + layerOffset
        local width = fogW / 4 + layer * 2
        local waveOffset = math.sin(time * 0.8 + layer * 0.7) * 3

        nvgBeginPath(ctx)
        nvgCircle(ctx, cx, cy, layerR + waveOffset)
        nvgStrokeWidth(ctx, width)
        -- 从暗绿渐变到紫黑
        local t = (layer - 1) / 4
        local cr = math.floor(lerp(46, 60, t))
        local cg = math.floor(lerp(74, 30, t))
        local cb = math.floor(lerp(62, 80, t))
        local ca = math.floor(lerp(80, 40, t))
        nvgStrokeColor(ctx, nvgRGBA(cr, cg, cb, ca))
        nvgStroke(ctx)
    end

    -- 主边界线(暗绿脉动, 像墨汁边缘)
    local pulse = math.sin(time * 2.0) * 0.2 + 0.8
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r)
    nvgStrokeWidth(ctx, 3 + pulse)
    nvgStrokeColor(ctx, nvgRGBA(46, 100, 62, math.floor(200 * pulse)))
    nvgStroke(ctx)

    -- 内侧微弱绿光(安全区内侧)
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r - 3)
    nvgStrokeWidth(ctx, 1.5)
    nvgStrokeColor(ctx, nvgRGBA(46, 74, 62, 50))
    nvgStroke(ctx)

    -- 9.3 收缩动画特效: 缩圈时边界有腐蚀地面的效果(地面褐→紫黑)
    if circle.radius > circle.targetRadius and circle.shrinkSpeed > 0 then
        local totalShrinkDist = circle.shrinkSpeed * CONFIG.DayDuration
        local shrinkProgress = 1.0 - (circle.radius - circle.targetRadius) / (totalShrinkDist + 0.01)
        shrinkProgress = clamp(shrinkProgress, 0, 1)
        -- 腐蚀带: 在旧边界和新边界之间渐变
        local oldR = circle.radius
        local newR = circle.targetRadius
        local corrosionPaint = nvgRadialGradient(ctx,
            cx, cy, newR, oldR + 10,
            nvgRGBA(80, 40, 90, math.floor(60 * shrinkProgress)),  -- 紫黑(新区域)
            nvgRGBA(80, 60, 40, 0))  -- 褐色(旧区域, 渐隐)
        nvgBeginPath(ctx)
        nvgCircle(ctx, cx, cy, oldR + 10)
        nvgFillPaint(ctx, corrosionPaint)
        nvgFill(ctx)
    end

    -- 9.3 酸雨粒子效果(毒圈外区域下落的绿色粒子)
    -- 利用时间+位置生成伪随机粒子
    local viewL = camera.x - 500
    local viewR = camera.x + 500
    local viewT = camera.y - 400
    local viewB = camera.y + 400
    for i = 1, 30 do
        local seed = i * 137.5
        local px = viewL + math.fmod(seed * 7.13 + time * 40 * ((i % 3) + 1) * 0.3, viewR - viewL)
        local py = viewT + math.fmod(seed * 11.7 + time * 80 * ((i % 4) + 1) * 0.2, viewB - viewT)
        -- 仅在毒圈外绘制酸雨
        local pdist = dist(px, py, circle.cx, circle.cy)
        if pdist > r + fogW * 0.3 then
            local screenX = px + ox
            local screenY = py + oy
            local dropLen = 4 + (i % 3) * 2
            local alpha = 40 + (i % 5) * 10
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, screenX, screenY)
            nvgLineTo(ctx, screenX - 1, screenY + dropLen)
            nvgStrokeWidth(ctx, 1.2)
            nvgStrokeColor(ctx, nvgRGBA(80, 180, 60, alpha))
            nvgStroke(ctx)
        end
    end

    -- 9.2 屏幕边缘紫色波纹(当本地玩家在毒圈外时)
    local lp = players[localPlayerIdx]
    if lp and lp.alive and lp.inPoisonZone then
        local rippleT = math.fmod(time * 1.2, 1.0)
        local edgeAlpha = math.floor((1.0 - rippleT) * 80)
        -- 屏幕四边紫色渐变
        local screenW = graphics:GetWidth() / graphics:GetDPR()
        local screenH = graphics:GetHeight() / graphics:GetDPR()
        local edgeW = 60

        -- 上
        local paintT = nvgLinearGradient(ctx, 0, 0, 0, edgeW,
            nvgRGBA(100, 30, 120, edgeAlpha), nvgRGBA(100, 30, 120, 0))
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, 0, screenW, edgeW)
        nvgFillPaint(ctx, paintT)
        nvgFill(ctx)
        -- 下
        local paintB = nvgLinearGradient(ctx, 0, screenH - edgeW, 0, screenH,
            nvgRGBA(100, 30, 120, 0), nvgRGBA(100, 30, 120, edgeAlpha))
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, screenH - edgeW, screenW, edgeW)
        nvgFillPaint(ctx, paintB)
        nvgFill(ctx)
        -- 左
        local paintL = nvgLinearGradient(ctx, 0, 0, edgeW, 0,
            nvgRGBA(100, 30, 120, edgeAlpha), nvgRGBA(100, 30, 120, 0))
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, 0, edgeW, screenH)
        nvgFillPaint(ctx, paintL)
        nvgFill(ctx)
        -- 右
        local paintR = nvgLinearGradient(ctx, screenW - edgeW, 0, screenW, 0,
            nvgRGBA(100, 30, 120, 0), nvgRGBA(100, 30, 120, edgeAlpha))
        nvgBeginPath(ctx)
        nvgRect(ctx, screenW - edgeW, 0, edgeW, screenH)
        nvgFillPaint(ctx, paintR)
        nvgFill(ctx)
    end
end

-- ============================================================================
-- 环境装饰与玩家(深度排序交错绘制)
-- ============================================================================

function drawEnvironmentAndPlayers(logW, logH, ox, oy)
    local ctx = nvgContext
    local isDay = (gamePhase == "prepare" or gamePhase == "day" or gamePhase == "shrinking")

    local viewLeft = camera.x - logW / 2 - 100
    local viewRight = camera.x + logW / 2 + 100
    local viewTop = camera.y - logH / 2 - 150
    local viewBottom = camera.y + logH / 2 + 50

    -- 收集所有需要深度排序的对象
    local drawList = {}

    -- 添加装饰物
    for i = 1, #mapDecorations do
        local dec = mapDecorations[i]
        if dec.x >= viewLeft and dec.x <= viewRight
           and dec.y >= viewTop and dec.y <= viewBottom then
            table.insert(drawList, { type = "deco", data = dec, y = dec.y })
        end
    end

    -- 添加地面药剂(5.3)
    for i = 1, #groundPotions do
        local gp = groundPotions[i]
        if gp.x >= viewLeft and gp.x <= viewRight
           and gp.y >= viewTop and gp.y <= viewBottom then
            table.insert(drawList, { type = "groundPotion", data = gp, y = gp.y })
        end
    end

    -- 添加玩家(包括鬼魂)
    for i = 1, #players do
        if players[i].alive or players[i].isGhost then
            table.insert(drawList, { type = "player", data = players[i], y = players[i].y })
        end
    end

    -- 按Y排序(从远到近)
    table.sort(drawList, function(a, b) return a.y < b.y end)

    -- 逐个绘制
    for i = 1, #drawList do
        local item = drawList[i]
        if item.type == "deco" then
            if item.data.type == "tree" then
                drawTreeDST(ctx, item.data, ox, oy, isDay)
            elseif item.data.type == "rock" then
                drawRockDST(ctx, item.data, ox, oy, isDay)
            elseif item.data.type == "flower" then
                drawFlowerDST(ctx, item.data, ox, oy, isDay)
            elseif item.data.type == "plant" then
                drawPlantDST(ctx, item.data, ox, oy, isDay)
            elseif item.data.type == "deadtree" then
                drawDeadTreeDST(ctx, item.data, ox, oy)
            end
        elseif item.type == "groundPotion" then
            drawGroundPotion(ctx, item.data, ox, oy)
        elseif item.type == "player" then
            drawPlayerDST(ctx, item.data, ox, oy, isDay)
        end
    end
end

-- 5.3 绘制地面药剂(发光瓶子)
function drawGroundPotion(ctx, gp, ox, oy)
    local sx = gp.x + ox
    local sy = gp.y + oy
    local time = GetTime():GetElapsedTime()

    local isAntidote = gp.type == "antidote"
    local glowR, glowG, glowB = 80, 180, 255  -- 蓝色(解药)
    if not isAntidote then
        glowR, glowG, glowB = 60, 180, 80     -- 绿色(毒药)
    end

    -- 脉动光晕
    local pulse = 0.7 + math.sin(time * 3 + gp.x * 0.1) * 0.3
    local glowRadius = 12 + math.sin(time * 2) * 3

    -- 外层光晕
    local grad = nvgRadialGradient(ctx, sx, sy - 4, 2, glowRadius,
        nvgRGBA(glowR, glowG, glowB, math.floor(80 * pulse)),
        nvgRGBA(glowR, glowG, glowB, 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy - 4, glowRadius)
    nvgFillPaint(ctx, grad)
    nvgFill(ctx)

    -- 瓶子形状(简单的小瓶轮廓)
    local bw = 10  -- 瓶宽
    local bh = 20 -- 瓶高
    -- 瓶身
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx - bw, sy - bh, bw * 2, bh, 3)
    nvgFillColor(ctx, nvgRGBA(glowR, glowG, glowB, math.floor(180 * pulse)))
    nvgFill(ctx)
    -- 瓶颈
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx - 2, sy - bh - 4, 4, 5, 1)
    nvgFillColor(ctx, nvgRGBA(glowR, glowG, glowB, math.floor(200 * pulse)))
    nvgFill(ctx)
    -- 高光
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx - bw + 2, sy - bh + 2, 3, bh - 4, 1)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, math.floor(60 * pulse)))
    nvgFill(ctx)
end

-- ============================================================================
-- 绘制树木(使用饥荒风手绘素材图片)
-- ============================================================================

function drawTreeDST(ctx, tree, ox, oy, isDay)
    local sx = tree.x + ox
    local sy = tree.y + oy
    local h = tree.height

    -- 根据seed选择树木图片变体(2种)
    local variant = 1 + (tree.seed % #DECO_TREE_PATHS)
    local img = decoTreeImages[variant]
    if not img then return end

    -- 树木绘制尺寸(宽高比约1:1.2, 根据height缩放)
    local drawH = h * 1.2
    local drawW = drawH * 0.85

    -- 绘制阴影(地面椭圆)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, sx + 3, sy + 2, drawW * 0.3, drawH * 0.06)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, isDay and 45 or 25))
    nvgFill(ctx)

    -- 图片绘制(锚点在底部中心)
    local imgX = sx - drawW / 2
    local imgY = sy - drawH
    local alpha = isDay and 255 or 180

    nvgSave(ctx)
    nvgGlobalAlpha(ctx, alpha / 255.0)
    local paint = nvgImagePattern(ctx, imgX, imgY, drawW, drawH, 0, img, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, imgX, imgY, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- ============================================================================
-- 绘制岩石(饥荒风 - 图片素材)
-- ============================================================================

function drawRockDST(ctx, rock, ox, oy, isDay)
    local sx = rock.x + ox
    local sy = rock.y + oy
    local size = rock.size

    -- 根据seed选择岩石图片变体(5种)
    local variant = 1 + (rock.seed % #DECO_ROCK_PATHS)
    local img = decoRockImages[variant]
    if not img then return end

    -- 岩石绘制尺寸(基于size缩放)
    local drawW = size * 1.2
    local drawH = size * 1.0

    -- 绘制阴影
    nvgBeginPath(ctx)
    nvgEllipse(ctx, sx + 2, sy + 2, drawW * 0.35, drawH * 0.1)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, isDay and 40 or 25))
    nvgFill(ctx)

    -- 图片绘制(锚点在底部中心)
    local imgX = sx - drawW / 2
    local imgY = sy - drawH * 0.8
    local alpha = isDay and 255 or 180

    nvgSave(ctx)
    nvgGlobalAlpha(ctx, alpha / 255.0)
    local paint = nvgImagePattern(ctx, imgX, imgY, drawW, drawH, 0, img, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, imgX, imgY, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- ============================================================================
-- 绘制花朵(饥荒风 - 图片素材)
-- ============================================================================

function drawFlowerDST(ctx, flower, ox, oy, isDay)
    local sx = flower.x + ox
    local sy = flower.y + oy
    local size = flower.size or 30

    local variant = flower.variant or 1
    local img = decoFlowerImages[variant]
    if not img then return end

    local drawW = size
    local drawH = size * 1.1

    -- 图片绘制(锚点在底部中心)
    local imgX = sx - drawW / 2
    local imgY = sy - drawH * 0.85
    local alpha = isDay and 255 or 160

    nvgSave(ctx)
    nvgGlobalAlpha(ctx, alpha / 255.0)
    local paint = nvgImagePattern(ctx, imgX, imgY, drawW, drawH, 0, img, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, imgX, imgY, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- ============================================================================
-- 绘制草丛/植物(饥荒风 - 图片素材)
-- ============================================================================

function drawPlantDST(ctx, plant, ox, oy, isDay)
    local sx = plant.x + ox
    local sy = plant.y + oy
    local size = plant.size or 36

    local variant = plant.variant or 1
    local img = decoPlantImages[variant]
    if not img then return end

    local drawW = size * 0.9
    local drawH = size * 1.3

    -- 轻微阴影
    nvgBeginPath(ctx)
    nvgEllipse(ctx, sx + 1, sy + 1, drawW * 0.25, drawH * 0.05)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, isDay and 30 or 15))
    nvgFill(ctx)

    -- 图片绘制(锚点在底部中心)
    local imgX = sx - drawW / 2
    local imgY = sy - drawH * 0.9
    local alpha = isDay and 255 or 165

    nvgSave(ctx)
    nvgGlobalAlpha(ctx, alpha / 255.0)
    local paint = nvgImagePattern(ctx, imgX, imgY, drawW, drawH, 0, img, 1.0)
    nvgBeginPath(ctx)
    nvgRect(ctx, imgX, imgY, drawW, drawH)
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
    nvgRestore(ctx)
end

-- ============================================================================
-- 绘制边界枯树(扭曲黑色枯树 - 天然围墙)
-- ============================================================================

function drawDeadTreeDST(ctx, tree, ox, oy)
    local sx = tree.x + ox
    local sy = tree.y + oy
    local h = tree.height
    local twist = tree.twist

    -- 纯黑色树干(无叶, 扭曲, 恐怖感)
    nvgStrokeColor(ctx, nvgRGBA(8, 5, 3, 240))
    nvgStrokeWidth(ctx, 5)
    nvgLineCap(ctx, NVG_ROUND)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, sx, sy)
    local midX = sx + twist * h * 0.5
    local midY = sy - h * 0.5
    local topX = sx + twist * h * 0.3
    local topY = sy - h
    nvgQuadTo(ctx, midX, midY, topX, topY)
    nvgStroke(ctx)

    -- 扭曲分支(纯黑, 无叶)
    nvgStrokeWidth(ctx, 3)
    local seed = tree.seed or 0
    for b = 1, 3 do
        local bh = 0.3 + (b / 3) * 0.5
        local startX = sx + twist * h * 0.5 * bh
        local startY = sy - h * bh
        local dir = (hashPos(seed, b, 5555) - 0.5) * 2.5
        local branchLen = h * 0.3 + hashPos(seed, b, 6666) * h * 0.2

        nvgBeginPath(ctx)
        nvgMoveTo(ctx, startX, startY)
        -- 更扭曲的分支
        local endX = startX + dir * branchLen
        local endY = startY - branchLen * 0.3
        nvgQuadTo(ctx, startX + dir * branchLen * 0.7, startY - branchLen * 0.1, endX, endY)
        nvgStroke(ctx)

        -- 细小末梢
        nvgStrokeWidth(ctx, 1.5)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, endX, endY)
        nvgLineTo(ctx, endX + dir * 8, endY - 10)
        nvgStroke(ctx)
        nvgStrokeWidth(ctx, 3)
    end
end

-- ============================================================================
-- 7.4 绘制舒适区(微弱光圈 + 篝火/清泉/圣坛 + 玩家进入高亮 + 浮动数字)
-- ============================================================================

function drawComfortZones(ox, oy)
    local ctx = nvgContext
    local time = GetTime():GetElapsedTime()

    for _, zone in ipairs(comfortZones) do
        local sx = zone.x + ox
        local sy = zone.y + oy
        local lightR = CONFIG.ComfortZoneRadius

        -- 9.4 腐败舒适区: 不同视觉(黑烟/绿池/暗淡)
        if zone.corrupted then
            -- 腐败光圈(暗紫色, 微弱)
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, lightR * 0.8)
            nvgStrokeColor(ctx, nvgRGBA(60, 30, 60, 30))
            nvgStrokeWidth(ctx, 0.8)
            nvgStroke(ctx)

            -- 腐败中心装饰
            if zone.type == "campfire" then
                -- 熄灭篝火: 黑色木炭 + 冒黑烟
                nvgStrokeColor(ctx, nvgRGBA(20, 15, 10, 200))
                nvgStrokeWidth(ctx, 3)
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, sx - 7, sy + 2)
                nvgLineTo(ctx, sx + 7, sy - 1)
                nvgStroke(ctx)
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, sx + 5, sy + 3)
                nvgLineTo(ctx, sx - 5, sy)
                nvgStroke(ctx)
                -- 黑烟(上升的暗色粒子)
                for smoke = 1, 3 do
                    local smokeT = math.fmod(time * 0.5 + smoke * 0.7, 2.0)
                    local smokeX = sx + math.sin(time + smoke * 2) * 3
                    local smokeY = sy - 8 - smokeT * 20
                    local smokeAlpha = math.floor((1.0 - smokeT / 2.0) * 60)
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, smokeX, smokeY, 2 + smokeT * 2)
                    nvgFillColor(ctx, nvgRGBA(20, 15, 20, smokeAlpha))
                    nvgFill(ctx)
                end
            elseif zone.type == "spring" then
                -- 变绿池: 毒绿色水洼
                nvgBeginPath(ctx)
                nvgEllipse(ctx, sx, sy, 14, 9)
                nvgFillColor(ctx, nvgRGBA(30, 80, 20, 150))
                nvgFill(ctx)
                -- 毒泡泡
                for bubble = 1, 2 do
                    local bubbleT = math.fmod(time * 0.7 + bubble * 1.1, 1.5)
                    local bx = sx + math.sin(bubble * 3.7 + time) * 5
                    local by = sy - bubbleT * 8
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, bx, by, 1.5 + (1.0 - bubbleT / 1.5) * 1.5)
                    nvgFillColor(ctx, nvgRGBA(60, 150, 30, math.floor((1.0 - bubbleT / 1.5) * 100)))
                    nvgFill(ctx)
                end
            elseif zone.type == "altar" then
                -- 腐败圣坛: 碎石 + 暗紫光
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, sx - 8, sy + 2)
                nvgLineTo(ctx, sx - 5, sy - 2)
                nvgLineTo(ctx, sx + 6, sy - 1)
                nvgLineTo(ctx, sx + 8, sy + 3)
                nvgClosePath(ctx)
                nvgFillColor(ctx, nvgRGBA(40, 35, 30, 180))
                nvgFill(ctx)
                -- 暗紫光点
                local flicker = math.sin(time * 2) * 0.3 + 0.5
                nvgBeginPath(ctx)
                nvgCircle(ctx, sx, sy - 5, 2 * flicker)
                nvgFillColor(ctx, nvgRGBA(80, 30, 100, math.floor(80 * flicker)))
                nvgFill(ctx)
            end
            goto continueZone
        end

        -- 检测是否有玩家在此舒适区内
        local hasPlayerInside = false
        for _, p in ipairs(players) do
            if p.alive and not p.isGhost and dist(p.x, p.y, zone.x, zone.y) <= lightR then
                hasPlayerInside = true
                break
            end
        end

        -- 7.4 边缘光圈(默认30%透明度, 有玩家时高亮)
        local baseAlpha = hasPlayerInside and 60 or 25
        local pulse = 1.0 + math.sin(time * 1.5) * 0.05

        -- 边缘圆环(微弱虚线感)
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, sy, lightR * pulse)
        nvgStrokeColor(ctx, nvgRGBA(139, 105, 20, baseAlpha + 15))
        nvgStrokeWidth(ctx, hasPlayerInside and 1.5 or 0.8)
        nvgStroke(ctx)

        -- 径向渐变光圈
        local paint = nvgRadialGradient(ctx,
            sx, sy, lightR * 0.15 * pulse, lightR * pulse,
            nvgRGBA(139, 105, 20, baseAlpha),
            nvgRGBA(139, 105, 20, 0))
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, sy, lightR * pulse)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)

        -- 有玩家时额外暖光层
        if hasPlayerInside then
            local glowPaint = nvgRadialGradient(ctx,
                sx, sy, 0, lightR * 0.6,
                nvgRGBA(200, 150, 50, 30),
                nvgRGBA(200, 150, 50, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, lightR * 0.6)
            nvgFillPaint(ctx, glowPaint)
            nvgFill(ctx)
        end

        -- 中心装饰物
        if zone.type == "campfire" then
            -- 篝火: 木材堆 + 火焰
            nvgStrokeColor(ctx, nvgRGBA(50, 30, 15, 200))
            nvgStrokeWidth(ctx, 3)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx - 8, sy + 3)
            nvgLineTo(ctx, sx + 8, sy - 2)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx + 6, sy + 4)
            nvgLineTo(ctx, sx - 6, sy - 1)
            nvgStroke(ctx)
            -- 第三根木柴
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx - 3, sy + 5)
            nvgLineTo(ctx, sx + 5, sy + 1)
            nvgStroke(ctx)
            -- 火焰(暗黄色, 跳动)
            local flicker = math.sin(time * 8) * 2
            nvgBeginPath(ctx)
            nvgEllipse(ctx, sx + flicker * 0.3, sy - 6 + flicker * 0.2, 4, 7 + flicker)
            nvgFillColor(ctx, nvgRGBA(180, 110, 20, 160))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgEllipse(ctx, sx, sy - 9, 2.5, 4 + math.sin(time * 12) * 1.5)
            nvgFillColor(ctx, nvgRGBA(220, 160, 30, 180))
            nvgFill(ctx)
            -- 火星粒子
            for spark = 1, 3 do
                local sparkT = math.fmod(time * 2 + spark * 1.3, 2.0)
                if sparkT < 1.0 then
                    local sparkX = sx + math.sin(time * 3 + spark) * 4
                    local sparkY = sy - 12 - sparkT * 15
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, sparkX, sparkY, 1.2 * (1.0 - sparkT))
                    nvgFillColor(ctx, nvgRGBA(240, 180, 40, math.floor((1.0 - sparkT) * 150)))
                    nvgFill(ctx)
                end
            end

        elseif zone.type == "spring" then
            -- 腐败清泉: 绿色水池 + 中央清水 + 白光
            -- 外层绿色水洼
            nvgBeginPath(ctx)
            nvgEllipse(ctx, sx, sy, 14, 9)
            nvgFillColor(ctx, nvgRGBA(50, 80, 60, 130))
            nvgFill(ctx)
            -- 中央清水
            nvgBeginPath(ctx)
            nvgEllipse(ctx, sx, sy, 6, 4)
            nvgFillColor(ctx, nvgRGBA(120, 180, 200, 150))
            nvgFill(ctx)
            -- 白光点
            local glow = 0.6 + math.sin(time * 3) * 0.3
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy - 2, 2.5 * glow)
            nvgFillColor(ctx, nvgRGBA(220, 240, 255, math.floor(180 * glow)))
            nvgFill(ctx)
            -- 涟漪
            local ripple = math.fmod(time * 0.5, 1.0)
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, 4 + ripple * 12)
            nvgStrokeColor(ctx, nvgRGBA(100, 160, 140, math.floor((1.0 - ripple) * 60)))
            nvgStrokeWidth(ctx, 1)
            nvgStroke(ctx)

        elseif zone.type == "altar" then
            -- 破碎圣坛: 石块堆砌 + 暗红蜡烛
            -- 石座(不规则)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx - 10, sy + 3)
            nvgLineTo(ctx, sx - 7, sy - 2)
            nvgLineTo(ctx, sx + 8, sy - 3)
            nvgLineTo(ctx, sx + 10, sy + 2)
            nvgLineTo(ctx, sx + 5, sy + 5)
            nvgLineTo(ctx, sx - 6, sy + 5)
            nvgClosePath(ctx)
            nvgFillColor(ctx, nvgRGBA(75, 68, 55, 210))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(30, 25, 20, 180))
            nvgStrokeWidth(ctx, 1.5)
            nvgStroke(ctx)
            -- 碎石块
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, sx - 12, sy + 1, 5, 4, 1)
            nvgFillColor(ctx, nvgRGBA(60, 55, 45, 180))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, sx + 8, sy, 4, 3, 1)
            nvgFillColor(ctx, nvgRGBA(65, 58, 48, 170))
            nvgFill(ctx)
            -- 蜡烛(暗红色)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, sx - 2, sy - 12, 4, 10, 1)
            nvgFillColor(ctx, nvgRGBA(100, 30, 25, 200))
            nvgFill(ctx)
            -- 蜡烛火焰
            local candleFlicker = math.sin(time * 6) * 0.8
            nvgBeginPath(ctx)
            nvgEllipse(ctx, sx + candleFlicker * 0.5, sy - 14, 2, 3 + candleFlicker)
            nvgFillColor(ctx, nvgRGBA(180, 80, 30, 180))
            nvgFill(ctx)
            nvgBeginPath(ctx)
            nvgEllipse(ctx, sx, sy - 15, 1, 2)
            nvgFillColor(ctx, nvgRGBA(240, 160, 50, 200))
            nvgFill(ctx)
        end
        -- ===== 舒适区指示标志(浮动菱形信标 + 类型图标) =====
        if not zone.corrupted then
            local bobY = math.sin(time * 2.5 + zone.x * 0.1) * 4  -- 上下浮动
            local beaconY = sy - CONFIG.ComfortZoneRadius - 20 + bobY
            local beaconAlpha = 180 + math.floor(math.sin(time * 3) * 50)

            -- 发光菱形信标
            local bSize = 8
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx, beaconY - bSize)
            nvgLineTo(ctx, sx + bSize * 0.6, beaconY)
            nvgLineTo(ctx, sx, beaconY + bSize)
            nvgLineTo(ctx, sx - bSize * 0.6, beaconY)
            nvgClosePath(ctx)

            -- 根据类型上色
            local bR, bG, bB = 255, 180, 50  -- 篝火: 暖黄
            if zone.type == "spring" then
                bR, bG, bB = 100, 200, 240   -- 清泉: 蓝色
            elseif zone.type == "altar" then
                bR, bG, bB = 200, 160, 255   -- 圣坛: 紫色
            end

            nvgFillColor(ctx, nvgRGBA(bR, bG, bB, beaconAlpha))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, math.floor(beaconAlpha * 0.6)))
            nvgStrokeWidth(ctx, 1.5)
            nvgStroke(ctx)

            -- 光柱(从信标向下延伸到舒适区中心)
            local pillarGrad = nvgLinearGradient(ctx, sx, beaconY + bSize, sx, sy,
                nvgRGBA(bR, bG, bB, 60), nvgRGBA(bR, bG, bB, 0))
            nvgBeginPath(ctx)
            nvgRect(ctx, sx - 2, beaconY + bSize, 4, sy - beaconY - bSize)
            nvgFillPaint(ctx, pillarGrad)
            nvgFill(ctx)

            -- 类型图标文字(在信标上方)
            if fontId ~= -1 then
                nvgFontFaceId(ctx, fontId)
                nvgFontSize(ctx, 12)
                nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                nvgFillColor(ctx, nvgRGBA(bR, bG, bB, beaconAlpha))
                local label = "🔥"
                if zone.type == "spring" then label = "💧"
                elseif zone.type == "altar" then label = "⛩" end
                nvgText(ctx, sx, beaconY - bSize - 2, label)
            end
        end

        -- ===== 舒适区能量条 + 冷却/次数显示 =====
        if not zone.corrupted then
            local barW = 60
            local barH = 6
            local barX = sx - barW / 2
            local barY = sy + 20

            local energy = zone.zoneEnergy or 100
            local cooldown = zone.zoneCooldown or 0
            local usesLeft = zone.zoneUsesLeft or 5

            if usesLeft <= 0 then
                -- 已耗尽: 显示"已耗尽"文字
                nvgFontFace(ctx, "sans")
                nvgFontSize(ctx, 10)
                nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(ctx, nvgRGBA(180, 60, 60, 200))
                nvgText(ctx, sx, barY + barH / 2, "已耗尽")
            elseif cooldown > 0 then
                -- 冷却中: 灰色背景条 + 冷却倒计时
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, barX, barY, barW, barH, 3)
                nvgFillColor(ctx, nvgRGBA(40, 40, 40, 160))
                nvgFill(ctx)
                -- 冷却进度(从右往左缩减)
                local cdRatio = cooldown / 5.0
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, barX, barY, barW * cdRatio, barH, 3)
                nvgFillColor(ctx, nvgRGBA(100, 100, 120, 180))
                nvgFill(ctx)
                -- 冷却时间文字
                nvgFontFace(ctx, "sans")
                nvgFontSize(ctx, 9)
                nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(ctx, nvgRGBA(200, 200, 200, 220))
                nvgText(ctx, sx, barY + barH / 2, string.format("%.1fs", cooldown))
            else
                -- 正常: 能量条
                -- 背景
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, barX, barY, barW, barH, 3)
                nvgFillColor(ctx, nvgRGBA(30, 30, 30, 150))
                nvgFill(ctx)
                -- 能量填充
                local ratio = energy / 100
                local eR = math.floor(80 + (1 - ratio) * 150)
                local eG = math.floor(200 * ratio)
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, barX, barY, barW * ratio, barH, 3)
                nvgFillColor(ctx, nvgRGBA(eR, eG, 40, 200))
                nvgFill(ctx)
                -- 边框
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, barX, barY, barW, barH, 3)
                nvgStrokeColor(ctx, nvgRGBA(139, 105, 20, 80))
                nvgStrokeWidth(ctx, 0.8)
                nvgStroke(ctx)
            end

            -- 剩余次数(小点)
            if usesLeft > 0 then
                local dotR = 2.5
                local dotGap = 8
                local dotsW = usesLeft * dotGap
                local dotStartX = sx - dotsW / 2 + dotGap / 2
                for di = 1, usesLeft do
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, dotStartX + (di - 1) * dotGap, barY + barH + 7, dotR)
                    nvgFillColor(ctx, nvgRGBA(139, 105, 20, 180))
                    nvgFill(ctx)
                end
            end
        end

        ::continueZone::
    end

    -- 7.4 绘制浮动数字(+5)
    local i = 1
    while i <= #comfortFloats do
        local f = comfortFloats[i]
        f.life = f.life - GetTime():GetTimeStep()
        if f.life <= 0 then
            table.remove(comfortFloats, i)
        else
            local alpha = math.floor((f.life / f.maxLife) * 220)
            local drawX = f.x + ox
            local drawY = f.y + oy - (1.0 - f.life / f.maxLife) * 20  -- 向上飘

            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, 13)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(f.color[1], f.color[2], f.color[3], alpha))
            nvgText(ctx, drawX, drawY, f.text)
            i = i + 1
        end
    end
end

-- ============================================================================
-- 绘制玩家(饥荒风 - 纸偶角色: 大圆头+细身体+手绘描边)
-- ============================================================================

function drawPlayerDST(ctx, p, ox, oy, isDay)
    local sx = p.x + ox
    local sy = p.y + oy

    -- 鬼魂: 使用鬼魂图片渲染
    local isGhost = p.isGhost
    if isGhost then
        local ghostW = 64
        local ghostH = 64
        local ghostX = sx - ghostW / 2
        local ghostY = sy - ghostH + 4  -- 脚底对齐

        -- 上下浮动动画
        local time = GetTime():GetElapsedTime()
        local floatOffset = math.sin(time * 2.5 + p.idx * 1.2) * 4
        ghostY = ghostY + floatOffset

        -- 半透明绘制鬼魂图片
        nvgSave(ctx)
        nvgGlobalAlpha(ctx, 0.55)

        if ghostImage then
            -- 根据移动方向翻转
            local flipX = (p.flipDir < 0)
            if flipX then
                nvgTranslate(ctx, ghostX + ghostW / 2, 0)
                nvgScale(ctx, -1, 1)
                nvgTranslate(ctx, -(ghostX + ghostW / 2), 0)
            end
            local paint = nvgImagePattern(ctx, ghostX, ghostY, ghostW, ghostH, 0, ghostImage, 1.0)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, ghostX, ghostY, ghostW, ghostH, 4)
            nvgFillPaint(ctx, paint)
            nvgFill(ctx)
        else
            -- fallback: 半透明圆形
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy - ghostH / 2, 20)
            nvgFillColor(ctx, nvgRGBA(200, 200, 255, 120))
            nvgFill(ctx)
        end

        nvgRestore(ctx)

        -- 绘制玩家名字(鬼魂头顶)
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(200, 200, 255, 140))
        nvgText(ctx, sx, ghostY - 8, p.name)

        return  -- 鬼魂不再绘制正常角色体
    end

    -- ===== 尺寸定义(1:2头身比 - Q版恐怖纸片人) =====
    local headR = 16          -- 头半径(大头)
    local bodyW = 9           -- 身体宽度(纤细)
    local bodyH = 20          -- 身体高度
    local legLen = 12         -- 腿长(细长条)
    local totalH = headR * 2 + bodyH + legLen

    -- 角色中心偏移(脚底在世界坐标点)
    local baseY = sy
    local bodyTop = baseY - legLen - bodyH
    local headY = bodyTop - headR

    -- ===== 颜色系统(灰白/暗褐, 状态靠光效区分) =====
    local color = p.color
    local poisonRatio = p.poison / CONFIG.PoisonMax
    local energyRatio = p.energy / CONFIG.EnergyMax

    -- 基础体色(A0A0A0正常, 中毒时不变色, 能量耗尽变暗至505050)
    local cr, cg, cb = color[1], color[2], color[3]

    -- 6.2 能量枯竭: 身体变暗至505050
    if p.energy <= 0 then
        cr = 80
        cg = 80
        cb = 80
    end

    -- hitFlash 不再改变基础颜色,白闪通过叠加层实现(见下方)

    -- 描边颜色(3-5px粗黑描边 - 核心视觉特征)
    local outR, outG, outB = 10, 8, 6
    if not isDay then outR, outG, outB = 5, 4, 3 end
    local outlineW = 4  -- 粗黑描边宽度

    -- ===== 阴影(纸片投影: 模糊黑色椭圆, 随朝向轻微变形) =====
    local shadowOffX = math.cos(p.facing) * 2
    local shadowScaleX = 14 + math.abs(math.cos(p.facing)) * 3
    local shadowScaleY = 5 + math.abs(math.sin(p.facing)) * 2
    nvgBeginPath(ctx)
    nvgEllipse(ctx, sx + shadowOffX, baseY + 3, shadowScaleX, shadowScaleY)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, isDay and 70 or 40))
    nvgFill(ctx)

    -- ===== 9.2 毒圈外效果: 紫黑涟漪 + 绿色气泡 =====
    local distToCircle = dist(p.x, p.y, circle.cx, circle.cy)
    if distToCircle > circle.radius and not isGhost then
        local time = GetTime():GetElapsedTime()
        local ripple1 = math.fmod(time * 0.8 + p.idx * 0.3, 1.0)
        local ripple2 = math.fmod(time * 0.8 + p.idx * 0.3 + 0.5, 1.0)
        -- 紫色波纹
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, baseY + 2, 8 + ripple1 * 12)
        nvgStrokeColor(ctx, nvgRGBA(100, 40, 120, math.floor((1.0 - ripple1) * 60)))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, baseY + 2, 5 + ripple2 * 10)
        nvgStrokeColor(ctx, nvgRGBA(74, 50, 80, math.floor((1.0 - ripple2) * 40)))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
        -- 绿色气泡(脚下冒出)
        for bubble = 1, 3 do
            local bubbleT = math.fmod(time * 0.6 + bubble * 0.9 + p.idx * 0.4, 1.5)
            local bx = sx + math.sin(time * 1.5 + bubble * 2.1 + p.idx) * 6
            local by = baseY - bubbleT * 15
            local bAlpha = math.floor((1.0 - bubbleT / 1.5) * 120)
            local bSize = 1.5 + (1.0 - bubbleT / 1.5) * 1.5
            nvgBeginPath(ctx)
            nvgCircle(ctx, bx, by, bSize)
            nvgFillColor(ctx, nvgRGBA(60, 180, 40, bAlpha))
            nvgFill(ctx)
        end
    end

    -- ===== 6.2 能量枯竭弯腰效果 =====
    local bendOffset = 0
    if p.energy <= 0 then
        bendOffset = 4  -- 弯腰下沉
    end

    -- ===== 猪角色图片渲染(替代原始纸片人) =====
    local isMoving = (p.vx ~= 0 or p.vy ~= 0)
    local imgHandle = pigImages[p.avatarIdx]

    -- 小丑猪(avatarIdx=1)动画帧系统
    local useAnimFrame = false
    if p.avatarIdx == 1 then
        local time = GetTime():GetElapsedTime()
        if p.drinkingState == "drinking" and #jesterDrinkFrames > 0 then
            -- 喝药时: 喝药动画(16帧, 最高优先级)
            local drinkProgress = p.drinkingTimer / CONFIG.DrinkDuration  -- 0~1
            local frameIdx = math.min(math.floor(drinkProgress * #jesterDrinkFrames) + 1, #jesterDrinkFrames)
            local drinkHandle = jesterDrinkFrames[frameIdx]
            if drinkHandle and drinkHandle ~= 0 and drinkHandle ~= -1 then
                imgHandle = drinkHandle
                useAnimFrame = true
            end
        elseif p.drinkingState == "stunned" and #jesterHurtFrames > 0 then
            -- 受击/硬直时: 受击动画(8帧, 按硬直进度播放)
            local hurtProgress = 1.0 - (p.drinkingTimer / CONFIG.DrinkStunDuration)  -- 0~1
            hurtProgress = math.max(0, math.min(hurtProgress, 1.0))
            local frameIdx = math.min(math.floor(hurtProgress * #jesterHurtFrames) + 1, #jesterHurtFrames)
            local hurtHandle = jesterHurtFrames[frameIdx]
            if hurtHandle and hurtHandle ~= 0 and hurtHandle ~= -1 then
                imgHandle = hurtHandle
                useAnimFrame = true
            end
        elseif p.attacking and #jesterAttackFrames > 0 then
            -- 攻击时: 打击动画(8帧, 按攻击进度播放)
            local totalDur = CONFIG.AttackWindup + CONFIG.AttackRecovery
            local elapsed = totalDur - p.attackTimer
            local progress = math.min(elapsed / totalDur, 1.0)
            local frameIdx = math.min(math.floor(progress * #jesterAttackFrames) + 1, #jesterAttackFrames)
            local attackHandle = jesterAttackFrames[frameIdx]
            if attackHandle and attackHandle ~= 0 and attackHandle ~= -1 then
                imgHandle = attackHandle
                useAnimFrame = true
            end
        elseif isMoving and p.sprinting and #jesterRunFrames > 0 then
            -- 奔跑时: 奔跑动画(8帧, 更快帧率)
            local frameIdx = math.floor(time * JESTER_RUN_FPS) % #jesterRunFrames + 1
            local runHandle = jesterRunFrames[frameIdx]
            if runHandle and runHandle ~= 0 and runHandle ~= -1 then
                imgHandle = runHandle
                useAnimFrame = true
            end
        elseif isMoving and #jesterWalkFrames > 0 then
            -- 走路时: 走路动画(16帧)
            local frameIdx = math.floor(time * JESTER_WALK_FPS) % #jesterWalkFrames + 1
            local walkHandle = jesterWalkFrames[frameIdx]
            if walkHandle and walkHandle ~= 0 and walkHandle ~= -1 then
                imgHandle = walkHandle
                useAnimFrame = true
            end
        elseif #jesterIdleFrames > 0 then
            -- 静止时: 待机动画(8帧)
            local frameIdx = math.floor(time * JESTER_IDLE_FPS) % #jesterIdleFrames + 1
            local idleHandle = jesterIdleFrames[frameIdx]
            if idleHandle and idleHandle ~= 0 and idleHandle ~= -1 then
                imgHandle = idleHandle
                useAnimFrame = true
            end
        end
    elseif p.avatarIdx == 2 then
        -- 战士猪(avatarIdx=2)动画帧系统
        local time = GetTime():GetElapsedTime()
        if isMoving and #warriorWalkFrames > 0 then
            -- 走路时: 走路动画(8帧循环)
            local frameIdx = math.floor(time * WARRIOR_WALK_FPS) % #warriorWalkFrames + 1
            local walkHandle = warriorWalkFrames[frameIdx]
            if walkHandle and walkHandle ~= 0 and walkHandle ~= -1 then
                imgHandle = walkHandle
                useAnimFrame = true
            end
        elseif not isMoving and #warriorIdleFrames > 0 then
            -- 待机时: 待机动画(4帧循环)
            local frameIdx = math.floor(time * WARRIOR_IDLE_FPS) % #warriorIdleFrames + 1
            local idleHandle = warriorIdleFrames[frameIdx]
            if idleHandle and idleHandle ~= 0 and idleHandle ~= -1 then
                imgHandle = idleHandle
                useAnimFrame = true
            end
        end
    elseif p.avatarIdx == 3 then
        -- 科学家猪(avatarIdx=3)动画帧系统
        local time = GetTime():GetElapsedTime()
        if isMoving and #scientistWalkFrames > 0 then
            -- 走路时: 走路动画(8帧循环)
            local frameIdx = math.floor(time * SCIENTIST_WALK_FPS) % #scientistWalkFrames + 1
            local walkHandle = scientistWalkFrames[frameIdx]
            if walkHandle and walkHandle ~= 0 and walkHandle ~= -1 then
                imgHandle = walkHandle
                useAnimFrame = true
            end
        end
    elseif p.avatarIdx == 4 then
        -- 矿工猪(avatarIdx=4)动画帧系统
        local time = GetTime():GetElapsedTime()
        if p.attacking and #minerAttackFrames > 0 then
            -- 攻击时: 打击动画(8帧, 按攻击进度播放)
            local totalDur = CONFIG.AttackWindup + CONFIG.AttackRecovery
            local elapsed = totalDur - p.attackTimer
            local progress = math.min(elapsed / totalDur, 1.0)
            local frameIdx = math.min(math.floor(progress * #minerAttackFrames) + 1, #minerAttackFrames)
            local attackHandle = minerAttackFrames[frameIdx]
            if attackHandle and attackHandle ~= 0 and attackHandle ~= -1 then
                imgHandle = attackHandle
                useAnimFrame = true
            end
        elseif isMoving and #minerWalkFrames > 0 then
            -- 走路时: 走路动画(16帧循环)
            local frameIdx = math.floor(time * MINER_WALK_FPS) % #minerWalkFrames + 1
            local walkHandle = minerWalkFrames[frameIdx]
            if walkHandle and walkHandle ~= 0 and walkHandle ~= -1 then
                imgHandle = walkHandle
                useAnimFrame = true
            end
        elseif #minerIdleFrames > 0 then
            -- 待机时: 待机动画(8帧循环,呼吸感)
            local frameIdx = math.floor(time * MINER_IDLE_FPS) % #minerIdleFrames + 1
            local idleHandle = minerIdleFrames[frameIdx]
            if idleHandle and idleHandle ~= 0 and idleHandle ~= -1 then
                imgHandle = idleHandle
                useAnimFrame = true
            end
        end
    elseif p.avatarIdx == 5 then
        -- 盗贼猪(avatarIdx=5)动画帧系统
        local time = GetTime():GetElapsedTime()
        if isMoving and #thiefWalkFrames > 0 then
            -- 走路时: 走路动画(8帧循环)
            local frameIdx = math.floor(time * THIEF_WALK_FPS) % #thiefWalkFrames + 1
            local walkHandle = thiefWalkFrames[frameIdx]
            if walkHandle and walkHandle ~= 0 and walkHandle ~= -1 then
                imgHandle = walkHandle
                useAnimFrame = true
            end
        end
    end

    -- 统一所有动画帧与静态立绘使用相同渲染尺寸(保持初始帧比例一致)
    local imgW = 72
    local imgH = 72
    local imgX = sx - imgW / 2
    local imgY = baseY - imgH + bendOffset  -- 脚底对齐世界坐标

    -- 行走动画: 轻微上下弹跳
    local walkBounce = 0
    if isMoving then
        local speed = (p.energy <= 0) and 5 or 8
        walkBounce = math.abs(math.sin(GetTime():GetElapsedTime() * speed + p.idx)) * 3
    end
    imgY = imgY - walkBounce

    -- 攻击时前冲效果
    local attackLunge = 0
    if p.attacking then attackLunge = 4 end
    imgX = imgX + math.cos(p.facing) * attackLunge
    imgY = imgY + math.sin(p.facing) * attackLunge

    -- 能量枯竭时变暗(叠加半透明黑色)
    local imgAlpha = 1.0
    if p.energy <= 0 then
        imgAlpha = 0.6
    end

    -- hitFlash 白闪: 在图片绘制后叠加(见下方)

    -- 绘制猪角色图片(根据移动方向左右翻转: PC用AD键, 触控/手柄用摇杆方向)
    local flipX = (p.flipDir < 0)  -- flipDir=-1时翻转(朝左)
    if imgHandle and imgHandle ~= 0 and imgHandle ~= -1 then
        nvgSave(ctx)
        if flipX then
            -- 水平翻转: 以图片中心为轴
            nvgTranslate(ctx, imgX + imgW / 2, 0)
            nvgScale(ctx, -1, 1)
            nvgTranslate(ctx, -(imgX + imgW / 2), 0)
        end
        local paint = nvgImagePattern(ctx, imgX, imgY, imgW, imgH, 0, imgHandle, imgAlpha)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, imgX, imgY, imgW, imgH, 4)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
        nvgRestore(ctx)
    else
        -- fallback: 绘制一个彩色圆形代替
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, baseY - imgH / 2 + bendOffset, 20)
        nvgFillColor(ctx, nvgRGBA(cr, cg, cb, 230))
        nvgFill(ctx)
    end



    -- 中毒时叠加绿色斑纹效果(覆盖在图片上)
    if poisonRatio > 0.2 then
        local spotA = math.floor(poisonRatio * 80)
        for sp = 1, 4 do
            local spX = sx + math.sin(sp * 2.3 + p.idx) * 12
            local spY = baseY - imgH * (0.3 + sp * 0.15) + bendOffset
            nvgBeginPath(ctx)
            nvgCircle(ctx, spX, spY, 3 + poisonRatio * 2)
            nvgFillColor(ctx, nvgRGBA(46, 74, 62, spotA))
            nvgFill(ctx)
        end
    end

    -- headDrawY 用于后续效果定位(头顶位置)
    local headDrawY = imgY + 4

    -- ===== 中毒绿色粒子(头顶飘出) =====
    if poisonRatio > 0.1 then
        local time = GetTime():GetElapsedTime()
        for k = 1, 3 do
            local pLife = math.fmod(time * 0.8 + k * 0.33, 1.0)
            local px = sx + math.sin(time * 2 + k * 2.1) * 6
            local py = headDrawY - headR - pLife * 18
            local pa = math.floor((1.0 - pLife) * poisonRatio * 180)
            nvgBeginPath(ctx)
            nvgCircle(ctx, px, py, 1.5 + (1.0 - pLife) * 1.5)
            nvgFillColor(ctx, nvgRGBA(46, 74, 62, pa))
            nvgFill(ctx)
        end
    end

    -- ===== 玩家标识(本地玩家: 微弱暖黄光圈 #8B6914) =====
    if p.isLocal then
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, baseY - totalH * 0.5, totalH * 0.55)
        nvgStrokeColor(ctx, nvgRGBA(139, 105, 20, 50))  -- #8B6914 暖黄
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
    end

    -- ===== 能量心脏(脚下常驻 - 2.5 UI) =====
    do
        local heartCX = sx - 18
        local heartCY = baseY + 16
        local heartSize = 7  -- 心脏半径参考

        -- 心脏形状路径(手绘感, 用贝塞尔)
        local function drawHeartPath(hcx, hcy, hs)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, hcx, hcy + hs * 0.4)
            -- 左瓣
            nvgBezierTo(ctx,
                hcx - hs * 0.05, hcy + hs * 0.1,
                hcx - hs * 0.7, hcy - hs * 0.2,
                hcx - hs * 0.7, hcy - hs * 0.55)
            nvgBezierTo(ctx,
                hcx - hs * 0.7, hcy - hs * 0.9,
                hcx - hs * 0.1, hcy - hs * 1.0,
                hcx, hcy - hs * 0.6)
            -- 右瓣
            nvgBezierTo(ctx,
                hcx + hs * 0.1, hcy - hs * 1.0,
                hcx + hs * 0.7, hcy - hs * 0.9,
                hcx + hs * 0.7, hcy - hs * 0.55)
            nvgBezierTo(ctx,
                hcx + hs * 0.7, hcy - hs * 0.2,
                hcx + hs * 0.05, hcy + hs * 0.1,
                hcx, hcy + hs * 0.4)
            nvgClosePath(ctx)
        end

        -- 6.5 能量UI: <30闪烁, <=0灰色+感叹号
        local heartR, heartG, heartB, heartA = 180, 30, 30, 220
        if p.energy <= 0 then
            -- 灰色心脏
            heartR, heartG, heartB = 90, 80, 80
            -- 缓慢闪烁
            local flicker = math.sin(GetTime():GetElapsedTime() * 4) > 0 and 1 or 0.5
            heartA = math.floor(200 * flicker)
        elseif p.energy < 30 then
            -- 快速闪烁(警告)
            local flicker = math.sin(GetTime():GetElapsedTime() * 10) > 0 and 1 or 0.4
            heartA = math.floor(220 * flicker)
        end

        -- 外轮廓(粗描边)
        drawHeartPath(heartCX, heartCY, heartSize)
        nvgStrokeColor(ctx, nvgRGBA(outR, outG, outB, 200))
        nvgStrokeWidth(ctx, 2.5)
        nvgStroke(ctx)

        -- 背景灰色心脏(底层)
        drawHeartPath(heartCX, heartCY, heartSize)
        nvgFillColor(ctx, nvgRGBA(60, 55, 50, 180))
        nvgFill(ctx)

        -- 红色填充(裁剪模拟: 用矩形遮挡上部分)
        -- 从底部填充到 energyRatio 高度
        if energyRatio > 0 then
            nvgSave(ctx)
            -- 使用 scissor 裁剪: 只显示下方 energyRatio 部分
            local heartTop = heartCY - heartSize * 1.0
            local heartBot = heartCY + heartSize * 0.4
            local heartH = heartBot - heartTop
            local fillTop = heartBot - heartH * energyRatio
            nvgScissor(ctx, heartCX - heartSize, fillTop, heartSize * 2, heartBot - fillTop + 1)

            drawHeartPath(heartCX, heartCY, heartSize)
            nvgFillColor(ctx, nvgRGBA(heartR, heartG, heartB, heartA))
            nvgFill(ctx)

            nvgResetScissor(ctx)
            nvgRestore(ctx)
        end

        -- 6.5 能量枯竭: "!" 感叹号图标
        if p.energy <= 0 then
            local exX = heartCX + heartSize + 4
            local exY = heartCY + 2
            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, 14)
            nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            -- 闪烁同步
            local flicker = math.sin(GetTime():GetElapsedTime() * 4) > 0 and 220 or 110
            nvgFillColor(ctx, nvgRGBA(240, 200, 50, flicker))
            nvgText(ctx, exX, exY, "!")
        end
    end

    -- ===== 毒药条(脚下) =====
    if p.poison > 0 then
        local barW = 26
        local barH = 4
        local barX = sx - 2
        local barY = baseY + 13

        -- 背景
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, barX - 1, barY - 1, barW + 2, barH + 2, 3)
        nvgFillColor(ctx, nvgRGBA(10, 8, 6, 180))
        nvgFill(ctx)

        -- 毒量(暗绿渐变 #2E4A3E → #4A7C59)
        local fillW = (p.poison / CONFIG.PoisonMax) * barW
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, barX, barY, fillW, barH, 2)
        nvgFillColor(ctx, nvgRGBA(
            math.floor(46 + poisonRatio * 28),
            math.floor(74 + poisonRatio * 50),
            math.floor(62 + poisonRatio * 27), 230))
        nvgFill(ctx)
    end

    -- ===== 毒满暴走buff指示(头顶闪烁紫色光环) =====
    if p.poisonMaxBuff then
        local time = GetTime():GetElapsedTime()
        local pulse = 0.6 + 0.4 * math.sin(time * 8)
        local alpha = math.floor(180 * pulse)
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, headDrawY - headR - 6, headR + 6)
        nvgStrokeColor(ctx, nvgRGBA(255, 0, 180, alpha))
        nvgStrokeWidth(ctx, 2.5)
        nvgStroke(ctx)
        -- 暴走文字
        nvgFontSize(ctx, 9)
        nvgFontFace(ctx, "sans")
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(ctx, nvgRGBA(255, 80, 200, alpha))
        nvgText(ctx, sx, headDrawY - headR - 14, "暴走", nil)
    end

    -- ===== 5.2 喝药读条(头顶进度条) =====
    if p.drinkingState == "drinking" then
        local barW = 32
        local barH = 5
        local barX = sx - barW / 2
        local barY = headDrawY - headR - 32
        local progress = 1.0 - (p.drinkingTimer / CONFIG.DrinkDuration)

        local isAntidote = p.drinkingType == "antidote"
        local fillR, fillG, fillB = 80, 200, 255  -- 蓝色(解药)
        if not isAntidote then
            fillR, fillG, fillB = 180, 60, 200  -- 紫色(毒药)
        end

        -- 背景
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, barX - 1, barY - 1, barW + 2, barH + 2, 3)
        nvgFillColor(ctx, nvgRGBA(10, 8, 6, 200))
        nvgFill(ctx)
        -- 进度填充
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, barX, barY, barW * progress, barH, 2)
        nvgFillColor(ctx, nvgRGBA(fillR, fillG, fillB, 230))
        nvgFill(ctx)
        -- 进度条边框
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, barX, barY, barW, barH, 2)
        nvgStrokeColor(ctx, nvgRGBA(fillR, fillG, fillB, 150))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
        -- 文字标识
        if fontId ~= -1 then
            nvgFontFaceId(ctx, fontId)
            nvgFontSize(ctx, 8)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(255, 255, 255, 200))
            nvgText(ctx, sx, barY + barH / 2, isAntidote and "解毒中" or "饮毒中", nil)
        end
    end

    -- ===== 5.6 药剂状态视觉指示(自己看到明确颜色, 他人看到模糊色) =====
    if p.potionState and p.drinkingState == "idle" then
        local time = GetTime():GetElapsedTime()
        local pulse = 0.6 + math.sin(time * 4 + p.idx * 1.7) * 0.4
        local auraR, auraG, auraB, auraA

        if p.isLocal then
            -- 自己看: 明确颜色
            if p.potionState == "antidote" then
                auraR, auraG, auraB, auraA = 100, 200, 255, math.floor(45 * pulse) -- 蓝白
            else
                auraR, auraG, auraB, auraA = 80, 180, 80, math.floor(45 * pulse)  -- 暗绿
            end
        else
            -- 他人看: 模糊色(蓝绿之间, 难以分辨)
            if p.potionState == "antidote" then
                auraR, auraG, auraB, auraA = 100, 190, 200, math.floor(30 * pulse) -- 青蓝
            else
                auraR, auraG, auraB, auraA = 90, 200, 170, math.floor(30 * pulse)  -- 青绿
            end
        end

        -- 身体周围柔和光晕
        local auraGrad = nvgRadialGradient(ctx, sx, bodyTop + bodyH * 0.5 + bendOffset,
            bodyW, totalH * 0.5,
            nvgRGBA(auraR, auraG, auraB, auraA),
            nvgRGBA(auraR, auraG, auraB, 0))
        nvgBeginPath(ctx)
        nvgEllipse(ctx, sx, bodyTop + bodyH * 0.5 + bendOffset, totalH * 0.4, totalH * 0.5)
        nvgFillPaint(ctx, auraGrad)
        nvgFill(ctx)
    end

    -- ===== 编号标签(头顶) =====
    if fontId ~= -1 then
        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(ctx, nvgRGBA(220, 210, 190, 180))
        nvgText(ctx, sx, headDrawY - 2, "P" .. tostring(p.idx), nil)
    end

    -- ===== 状态特效 =====
    for _, eff in ipairs(statusEffects) do
        if eff.playerIdx == p.idx then
            local alpha = math.floor(180 * (eff.timer / 1.0))
            if eff.type == "poison" then
                -- 中毒: 暗绿毒雾环绕角色(#2E4A3E)
                local pulse = math.sin(GetTime():GetElapsedTime() * 10) * 3
                nvgBeginPath(ctx)
                nvgCircle(ctx, sx, baseY - totalH * 0.4, totalH * 0.6 + pulse)
                nvgStrokeColor(ctx, nvgRGBA(46, 74, 62, alpha))
                nvgStrokeWidth(ctx, 2.5)
                nvgStroke(ctx)
                -- 毒雾粒子(暗绿色小圆点 #4A7C59)
                for k = 1, 3 do
                    local angle = GetTime():GetElapsedTime() * 3 + k * 2.1
                    local r = totalH * 0.45 + math.sin(angle * 2) * 5
                    local px = sx + math.cos(angle) * r
                    local py = (baseY - totalH * 0.4) + math.sin(angle) * r * 0.5
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, px, py, 3)
                    nvgFillColor(ctx, nvgRGBA(74, 124, 89, math.floor(alpha * 0.7)))
                    nvgFill(ctx)
                end
            elseif eff.type == "detox" then
                -- 减毒: 暖黄色光环向上扩散(#8B6914)
                local progress = 1.0 - (eff.timer / 0.8)
                local radius = totalH * 0.4 + progress * 15
                local a = math.floor(200 * (1.0 - progress))
                nvgBeginPath(ctx)
                nvgCircle(ctx, sx, baseY - totalH * 0.4, radius)
                nvgStrokeColor(ctx, nvgRGBA(139, 105, 20, a))
                nvgStrokeWidth(ctx, 3)
                nvgStroke(ctx)
                -- 上升暖黄光点
                for k = 1, 4 do
                    local yOff = progress * 20 * k * 0.5
                    local xOff = math.sin(k * 1.5 + progress * 6) * 8
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, sx + xOff, baseY - totalH * 0.3 - yOff, 2.5 - progress * 1.5)
                    nvgFillColor(ctx, nvgRGBA(160, 130, 40, a))
                    nvgFill(ctx)
                end
            elseif eff.type == "transform" then
                -- 10.3 解药→毒药转化: 紫色波纹扩散
                local progress = 1.0 - (eff.timer / 1.5)
                local ring1R = totalH * 0.3 + progress * 35
                local ring2R = totalH * 0.3 + progress * 55
                local a1 = math.floor(220 * (1.0 - progress))
                local a2 = math.floor(140 * math.max(0, 1.0 - progress * 1.5))
                -- 内环(亮紫)
                nvgBeginPath(ctx)
                nvgCircle(ctx, sx, baseY - totalH * 0.4, ring1R)
                nvgStrokeColor(ctx, nvgRGBA(180, 60, 200, a1))
                nvgStrokeWidth(ctx, 2.5)
                nvgStroke(ctx)
                -- 外环(暗紫)
                nvgBeginPath(ctx)
                nvgCircle(ctx, sx, baseY - totalH * 0.4, ring2R)
                nvgStrokeColor(ctx, nvgRGBA(120, 40, 160, a2))
                nvgStrokeWidth(ctx, 1.5)
                nvgStroke(ctx)
                -- 紫色粒子散射
                for k = 1, 5 do
                    local angle = progress * 6 + k * 1.26
                    local pDist = ring1R * 0.6 + progress * 20
                    local px = sx + math.cos(angle) * pDist
                    local py = (baseY - totalH * 0.4) + math.sin(angle) * pDist * 0.6
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, px, py, 2.5 - progress * 1.5)
                    nvgFillColor(ctx, nvgRGBA(160, 80, 220, a1))
                    nvgFill(ctx)
                end
            end
        end
    end

    -- ===== 解药/毒药获取光效(2.5 UI) =====
    for _, glow in ipairs(pickupGlows) do
        if glow.playerIdx == p.idx then
            local progress = 1.0 - (glow.timer / glow.maxTimer)
            local glowAlpha = math.floor(200 * (1.0 - progress))

            if glow.type == "antidote" then
                -- 解药: 蓝白光效(头顶向上扩散)
                local radius1 = 12 + progress * 20
                local radius2 = 8 + progress * 15
                -- 外圈蓝白光环
                nvgBeginPath(ctx)
                nvgCircle(ctx, sx, headDrawY - headR - 5, radius1)
                nvgStrokeColor(ctx, nvgRGBA(180, 220, 255, glowAlpha))
                nvgStrokeWidth(ctx, 2.5)
                nvgStroke(ctx)
                -- 内圈白光
                nvgBeginPath(ctx)
                nvgCircle(ctx, sx, headDrawY - headR - 5, radius2)
                nvgStrokeColor(ctx, nvgRGBA(240, 250, 255, math.floor(glowAlpha * 0.7)))
                nvgStrokeWidth(ctx, 1.5)
                nvgStroke(ctx)
                -- 上升蓝白光粒子
                for k = 1, 5 do
                    local kProgress = math.fmod(progress * 2 + k * 0.2, 1.0)
                    local kx = sx + math.sin(k * 1.8 + progress * 8) * 10
                    local ky = headDrawY - headR - 10 - kProgress * 25
                    local ka = math.floor(glowAlpha * (1.0 - kProgress))
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, kx, ky, 2.5 - kProgress * 1.5)
                    nvgFillColor(ctx, nvgRGBA(200, 235, 255, ka))
                    nvgFill(ctx)
                end
            elseif glow.type == "poison" then
                -- 毒药: 暗绿光效(头顶暗绿脉动)
                local radius1 = 10 + progress * 18
                local pulse = math.sin(GetTime():GetElapsedTime() * 15) * 3
                -- 暗绿毒雾脉动
                nvgBeginPath(ctx)
                nvgCircle(ctx, sx, headDrawY - headR - 5, radius1 + pulse)
                nvgStrokeColor(ctx, nvgRGBA(30, 80, 40, glowAlpha))
                nvgStrokeWidth(ctx, 3)
                nvgStroke(ctx)
                -- 内部暗绿填充(半透明)
                local innerGrad = nvgRadialGradient(ctx, sx, headDrawY - headR - 5,
                    0, radius1 * 0.6,
                    nvgRGBA(20, 60, 30, math.floor(glowAlpha * 0.4)),
                    nvgRGBA(30, 80, 40, 0))
                nvgBeginPath(ctx)
                nvgCircle(ctx, sx, headDrawY - headR - 5, radius1 * 0.6)
                nvgFillPaint(ctx, innerGrad)
                nvgFill(ctx)
                -- 下沉暗绿粒子
                for k = 1, 4 do
                    local kProgress = math.fmod(progress * 2 + k * 0.25, 1.0)
                    local kx = sx + math.cos(k * 2.1 + progress * 6) * 8
                    local ky = headDrawY - headR + kProgress * 15
                    local ka = math.floor(glowAlpha * (1.0 - kProgress) * 0.8)
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, kx, ky, 2 + kProgress)
                    nvgFillColor(ctx, nvgRGBA(40, 100, 50, ka))
                    nvgFill(ctx)
                end
            end
        end
    end

    -- ===== 10.3 持药光效(蓝=解药/绿=毒药, 持续脉动) =====
    if not isGhost and p.potionState then
        local time = GetTime():GetElapsedTime()
        local pulse = 0.5 + 0.5 * math.sin(time * 4)
        local auraR = 22 + pulse * 6
        local auraAlpha = math.floor(60 + pulse * 40)
        if p.potionState == "antidote" then
            -- 蓝色解药光环
            local grad = nvgRadialGradient(ctx, sx, sy, auraR * 0.3, auraR,
                nvgRGBA(100, 180, 255, auraAlpha), nvgRGBA(80, 150, 255, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, auraR)
            nvgFillPaint(ctx, grad)
            nvgFill(ctx)
        else
            -- 绿色毒药光环
            local grad = nvgRadialGradient(ctx, sx, sy, auraR * 0.3, auraR,
                nvgRGBA(60, 200, 80, auraAlpha), nvgRGBA(40, 160, 60, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, auraR)
            nvgFillPaint(ctx, grad)
            nvgFill(ctx)
        end
    end

    -- ===== 10.3 中毒加深骷髅图标(每+10毒闪现) =====
    if not isGhost and p.poisonSkullTimer and p.poisonSkullTimer > 0 then
        local skullAlpha = math.floor(255 * (p.poisonSkullTimer / 0.8))
        local skullScale = 1.0 + (1.0 - p.poisonSkullTimer / 0.8) * 0.3
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 18 * skullScale)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(200, 50, 255, skullAlpha))
        nvgText(ctx, sx + 20, headDrawY - headR - 15, "💀")
    end

    -- ===== 10.3 满毒预警(≥80毒时红色脉动边框) =====
    if not isGhost and p.alive and p.poison >= 80 then
        local time = GetTime():GetElapsedTime()
        local warnPulse = 0.5 + 0.5 * math.sin(time * 8)
        local warnAlpha = math.floor(80 + warnPulse * 100)
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, sy, 28 + warnPulse * 4)
        nvgStrokeColor(ctx, nvgRGBA(255, 30, 30, warnAlpha))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
    end

    -- ===== 携带药水玩家头顶图标(使用实际药水图片) =====
    if not isGhost and p.alive and p.potionState then
        local potionImg = potionNvgImages[p.potionState]
        if potionImg then
            local time = GetTime():GetElapsedTime()
            local pulse = 0.7 + 0.3 * math.sin(time * 5)
            local bobY = math.sin(time * 3) * 3
            local indicatorY = headDrawY - headR - 35 + bobY

            -- 根据药水类型设置光晕颜色
            local glowR, glowG, glowB = 80, 180, 255  -- 默认蓝色(解药)
            if p.potionState == "poison" then
                glowR, glowG, glowB = 80, 200, 60
            elseif p.potionState == "victory" then
                glowR, glowG, glowB = 220, 180, 50
            end

            -- 外层发光圆环
            local ringR = 18 + pulse * 4
            local ringAlpha = math.floor(100 + pulse * 80)
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, indicatorY, ringR)
            nvgStrokeColor(ctx, nvgRGBA(glowR, glowG, glowB, ringAlpha))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)

            -- 绘制药水图片
            local iconSize = 24
            local potionIX = sx - iconSize / 2
            local potionIY = indicatorY - iconSize / 2
            local imgPaint = nvgImagePattern(ctx, potionIX, potionIY, iconSize, iconSize, 0, potionImg, pulse)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, potionIX, potionIY, iconSize, iconSize, 4)
            nvgFillPaint(ctx, imgPaint)
            nvgFill(ctx)

            -- 向下小箭头(指向玩家)
            local arrowY = indicatorY + iconSize / 2 + 4
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx, arrowY + 6)
            nvgLineTo(ctx, sx - 4, arrowY)
            nvgLineTo(ctx, sx + 4, arrowY)
            nvgClosePath(ctx)
            nvgFillColor(ctx, nvgRGBA(glowR, glowG, glowB, math.floor(200 * pulse)))
            nvgFill(ctx)

            -- 光粒子环绕
            for k = 1, 4 do
                local angle = time * 3 + k * (math.pi / 2)
                local particleR = ringR * 0.85
                local pkx = sx + math.cos(angle) * particleR
                local pky = indicatorY + math.sin(angle) * particleR * 0.6
                nvgBeginPath(ctx)
                nvgCircle(ctx, pkx, pky, 2 * pulse)
                nvgFillColor(ctx, nvgRGBA(glowR, glowG, glowB, math.floor(150 * pulse)))
                nvgFill(ctx)
            end
        end
    end

end

-- ============================================================================
-- 攻击特效(饥荒风 - 暗色弧形挥砍)
-- ============================================================================

function drawAttackEffectsDST(ox, oy)
    local ctx = nvgContext

    for i = 1, #attackEffects do
        local e = attackEffects[i]
        local sx = e.x + ox
        local sy = e.y + oy
        local halfAngle = math.rad(CONFIG.AttackAngle / 2)

        if e.phase == "windup" then
            -- 4.3 前摇: 墨水拖尾(手臂举起, 淡墨弧线)
            local totalDur = CONFIG.AttackWindup + CONFIG.AttackRecovery
            local progress = 1.0 - (e.timer / totalDur)
            local alpha = math.floor((1.0 - progress) * 120)
            local range = CONFIG.AttackRange * 0.4 * (0.5 + progress * 0.5)

            -- 淡墨水蓄力弧
            nvgBeginPath(ctx)
            nvgArc(ctx, sx, sy, range, e.angle - halfAngle * 0.5, e.angle + halfAngle * 0.5, 1)
            nvgStrokeWidth(ctx, 2 + progress * 2)
            nvgStrokeColor(ctx, nvgRGBA(20, 20, 30, alpha))
            nvgStroke(ctx)

        elseif e.phase == "slash" then
            -- 4.3 挥击: 黑色墨水扇形弧(主攻击视觉)
            local progress = 1.0 - (e.timer / CONFIG.AttackRecovery)
            local alpha = math.floor((1.0 - progress) * 220)
            local range = CONFIG.AttackRange * (0.6 + progress * 0.4)

            -- 扇形填充(深黑墨水)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx, sy)
            nvgArc(ctx, sx, sy, range, e.angle - halfAngle, e.angle + halfAngle, 1)
            nvgClosePath(ctx)
            nvgFillColor(ctx, nvgRGBA(10, 10, 20, math.floor(alpha * 0.5)))
            nvgFill(ctx)

            -- 弧线描边(黑色墨水边缘)
            nvgBeginPath(ctx)
            nvgArc(ctx, sx, sy, range, e.angle - halfAngle, e.angle + halfAngle, 1)
            nvgStrokeWidth(ctx, 3 + (1.0 - progress) * 2)
            nvgStrokeColor(ctx, nvgRGBA(20, 20, 40, alpha))
            nvgStroke(ctx)

            -- 墨水飞溅线条(3条从扇形边缘向外延伸)
            for j = 1, 3 do
                local a = e.angle - halfAngle + (j / 4) * (halfAngle * 2)
                local startR = range * 0.8
                local endR = range * (1.0 + progress * 0.3)
                nvgBeginPath(ctx)
                nvgMoveTo(ctx, sx + math.cos(a) * startR, sy + math.sin(a) * startR)
                nvgLineTo(ctx, sx + math.cos(a) * endR, sy + math.sin(a) * endR)
                nvgStrokeWidth(ctx, 2)
                nvgStrokeColor(ctx, nvgRGBA(30, 30, 40, math.floor(alpha * 0.7)))
                nvgStroke(ctx)
            end

        else
            -- 兼容旧格式
            local progress = 1.0 - (e.timer / 0.3)
            local alpha = math.floor((1.0 - progress) * 200)
            local range = CONFIG.AttackRange * (0.5 + progress * 0.5)

            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx, sy)
            nvgArc(ctx, sx, sy, range, e.angle - halfAngle, e.angle + halfAngle, 1)
            nvgClosePath(ctx)
            nvgFillColor(ctx, nvgRGBA(20, 20, 30, math.floor(alpha * 0.4)))
            nvgFill(ctx)
        end
    end
end

-- ============================================================================
-- 粒子(饥荒风 - 暗色毒雾碎片)
-- ============================================================================

function drawParticlesDST(ox, oy)
    local ctx = nvgContext

    for i = 1, #particles do
        local p = particles[i]
        local sx = p.x + ox
        local sy = p.y + oy
        local alpha = math.floor(p.life * 200)
        local size = p.life * 6

        -- 不规则形状(旋转的菱形)
        nvgSave(ctx)
        nvgTranslate(ctx, sx, sy)
        nvgRotate(ctx, p.life * 3.14)

        nvgBeginPath(ctx)
        nvgMoveTo(ctx, 0, -size)
        nvgLineTo(ctx, size * 0.6, 0)
        nvgLineTo(ctx, 0, size)
        nvgLineTo(ctx, -size * 0.6, 0)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
        nvgFill(ctx)

        nvgRestore(ctx)
    end
end

-- ============================================================================
-- 4.3 浮动文字绘制(命中反馈: "+10毒"/"-15毒" 等)
-- ============================================================================

function drawFloatingTexts(ox, oy)
    local ctx = nvgContext
    if #floatingTexts == 0 then return end

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    for i = 1, #floatingTexts do
        local ft = floatingTexts[i]
        local sx = ft.x + ox
        local sy = ft.y + oy
        local alpha = math.floor((ft.timer / ft.maxTimer) * 255)
        local scale = 0.8 + 0.4 * (1.0 - ft.timer / ft.maxTimer)  -- 略微放大

        nvgFontSize(ctx, 14 * scale)
        -- 阴影
        nvgFillColor(ctx, nvgRGBA(0, 0, 0, math.floor(alpha * 0.6)))
        nvgText(ctx, sx + 1, sy + 1, ft.text)
        -- 正文
        nvgFillColor(ctx, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], alpha))
        nvgText(ctx, sx, sy, ft.text)
    end
end

-- ============================================================================
-- 8.2 交互UI(按钮提示+选项面板+抛物线动画)
-- ============================================================================

function drawInteractionUI(logW, logH, ox, oy)
    local ctx = nvgContext
    local p = players[localPlayerIdx]
    if not p or not p.alive then return end
    if gamePhase ~= "day" then return end

    local time = GetTime():GetElapsedTime()

    -- 8.2a 交互按钮提示: 靠近可交互玩家时显示 [E] 图标
    if p.interactState == "idle" then
        local targetIdx = findNearestInteractable(p)
        if targetIdx then
            local target = players[targetIdx]
            local sx = target.x + ox
            local sy = target.y + oy - 60
            local pulse = 0.7 + math.sin(time * 4) * 0.3

            -- 背景圆形
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, 12)
            nvgFillColor(ctx, nvgRGBA(200, 180, 50, math.floor(160 * pulse)))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(255, 220, 80, math.floor(220 * pulse)))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)

            -- E字
            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, 14)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(20, 15, 10, 255))
            nvgText(ctx, sx, sy, "E")
        end
    end

    -- 8.2b 等待接受提示(pending状态)
    if p.interactState == "pending" then
        local panelW = 160
        local panelH = 40
        local px = logW / 2 - panelW / 2
        local py = logH * 0.3

        -- 背景面板
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, px, py, panelW, panelH, 6)
        nvgFillColor(ctx, nvgRGBA(20, 18, 15, 200))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(200, 180, 50, 180))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)

        -- 提示文字
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(240, 220, 100, 240))
        nvgText(ctx, logW / 2, py + 14, "收到交互请求!")
        nvgFontSize(ctx, 10)
        nvgFillColor(ctx, nvgRGBA(180, 180, 160, 200))
        local remain = math.max(0, p.interactTimer)
        nvgText(ctx, logW / 2, py + 28, string.format("[E]接受  [Q]拒绝  %.1fs", remain))
    end

    -- 8.2c 交互选项面板(interacting状态: 选择给予什么)
    if p.interactState == "interacting" then
        local panelW = 180
        local panelH = 60
        local px = logW / 2 - panelW / 2
        local py = logH * 0.25

        -- 背景面板
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, px, py, panelW, panelH, 8)
        nvgFillColor(ctx, nvgRGBA(15, 12, 10, 220))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(100, 200, 150, 150))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)

        -- 标题
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(100, 255, 200, 240))
        local remain = math.max(0, p.interactTimer)
        nvgText(ctx, logW / 2, py + 14, string.format("交互中 (%.1fs)", remain))

        -- 选项提示
        nvgFontSize(ctx, 11)
        if p.potionState then
            nvgFillColor(ctx, nvgRGBA(200, 200, 180, 220))
            nvgText(ctx, logW / 2, py + 32, "[1]给予解药  [2]给予毒药")
            nvgFontSize(ctx, 9)
            nvgFillColor(ctx, nvgRGBA(150, 150, 130, 160))
            nvgText(ctx, logW / 2, py + 48, "[Q]取消  对方看不到你给的是什么")
        else
            nvgFillColor(ctx, nvgRGBA(180, 120, 80, 200))
            nvgText(ctx, logW / 2, py + 32, "无药可给  等待对方...")
            nvgFontSize(ctx, 9)
            nvgFillColor(ctx, nvgRGBA(150, 150, 130, 160))
            nvgText(ctx, logW / 2, py + 48, "[Q]取消")
        end
    end

    -- 8.2d 抛物线动画(所有玩家的giving状态)
    for i = 1, #players do
        local giver = players[i]
        if giver.interactState == "giving" and giver.interactFlyAnim then
            local anim = giver.interactFlyAnim
            local progress = clamp(anim.t / anim.duration, 0, 1)

            -- 抛物线计算: x线性插值, y加抛物线弧度
            local fx = lerp(anim.fromX, anim.toX, progress)
            local fy = lerp(anim.fromY, anim.toY, progress)
            -- 抛物线高度(中间最高)
            local arcHeight = -40 * (4 * progress * (1 - progress))
            fy = fy + arcHeight

            local sx = fx + ox
            local sy = fy + oy

            -- 绘制飞行物(小光球)
            local glowR, glowG, glowB = 200, 200, 150  -- 模糊色(他人不知道是什么)
            if giver.isLocal then
                -- 自己给的东西自己知道颜色
                if anim.type == "antidote" then
                    glowR, glowG, glowB = 80, 200, 255
                else
                    glowR, glowG, glowB = 180, 60, 200
                end
            end

            -- 光晕
            local grad = nvgRadialGradient(ctx, sx, sy, 2, 12,
                nvgRGBA(glowR, glowG, glowB, 200),
                nvgRGBA(glowR, glowG, glowB, 0))
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, 12)
            nvgFillPaint(ctx, grad)
            nvgFill(ctx)

            -- 核心光球
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, 4)
            nvgFillColor(ctx, nvgRGBA(glowR, glowG, glowB, 240))
            nvgFill(ctx)

            -- 拖尾
            for k = 1, 3 do
                local tp = clamp(progress - k * 0.08, 0, 1)
                local tx = lerp(anim.fromX, anim.toX, tp) + ox
                local ty = lerp(anim.fromY, anim.toY, tp) + (-40 * (4 * tp * (1 - tp))) + oy
                local ta = math.floor(120 - k * 35)
                nvgBeginPath(ctx)
                nvgCircle(ctx, tx, ty, 3 - k * 0.7)
                nvgFillColor(ctx, nvgRGBA(glowR, glowG, glowB, ta))
                nvgFill(ctx)
            end
        end
    end

    -- 8.2e 交互连接线(requesting/pending/interacting时, 双方之间虚线)
    if p.interactState ~= "idle" and p.interactPartner then
        local partner = players[p.interactPartner]
        if partner then
            local sx1 = p.x + ox
            local sy1 = p.y + oy - 20
            local sx2 = partner.x + ox
            local sy2 = partner.y + oy - 20

            -- 虚线连接
            local pulse = 0.5 + math.sin(time * 6) * 0.5
            nvgStrokeColor(ctx, nvgRGBA(200, 180, 80, math.floor(100 * pulse)))
            nvgStrokeWidth(ctx, 1.5)
            nvgLineCap(ctx, NVG_ROUND)
            -- 用多段短线模拟虚线
            local dx = sx2 - sx1
            local dy = sy2 - sy1
            local length = math.sqrt(dx * dx + dy * dy)
            if length > 1 then
                local segments = math.floor(length / 8)
                for seg = 0, segments - 1, 2 do
                    local t1 = seg / segments
                    local t2 = math.min((seg + 1) / segments, 1.0)
                    nvgBeginPath(ctx)
                    nvgMoveTo(ctx, sx1 + dx * t1, sy1 + dy * t1)
                    nvgLineTo(ctx, sx1 + dx * t2, sy1 + dy * t2)
                    nvgStroke(ctx)
                end
            end
        end
    end
end

-- ============================================================================
-- 死亡纸片碎裂 + 黑色污渍
-- ============================================================================

function drawDeathEffects(ox, oy)
    local ctx = nvgContext

    -- 绘制黑色污渍(死亡原地留下)
    for i = 1, #deathStains do
        local s = deathStains[i]
        local sx = s.x + ox
        local sy = s.y + oy
        local a = math.floor(s.alpha)
        nvgBeginPath(ctx)
        nvgEllipse(ctx, sx, sy, 18, 8)
        nvgFillColor(ctx, nvgRGBA(15, 10, 8, a))
        nvgFill(ctx)
        -- 边缘更暗的小椭圆
        nvgBeginPath(ctx)
        nvgEllipse(ctx, sx + 3, sy + 1, 10, 5)
        nvgFillColor(ctx, nvgRGBA(5, 3, 2, math.floor(a * 0.6)))
        nvgFill(ctx)
    end

    -- 绘制飘散纸片
    for i = 1, #deathPieces do
        local p = deathPieces[i]
        local sx = p.x + ox
        local sy = p.y + oy
        local alpha = math.floor((p.life / 2.0) * 220)

        nvgSave(ctx)
        nvgTranslate(ctx, sx, sy)
        nvgRotate(ctx, p.rot)

        -- 纸片形状(不规则四边形)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, -p.w * 0.5, -p.h * 0.4)
        nvgLineTo(ctx, p.w * 0.4, -p.h * 0.5)
        nvgLineTo(ctx, p.w * 0.5, p.h * 0.3)
        nvgLineTo(ctx, -p.w * 0.3, p.h * 0.5)
        nvgClosePath(ctx)
        -- 纸片颜色(角色体色, 逐渐变暗)
        local fade = p.life / 2.0
        nvgFillColor(ctx, nvgRGBA(
            math.floor(p.color[1] * fade),
            math.floor(p.color[2] * fade),
            math.floor(p.color[3] * fade), alpha))
        nvgFill(ctx)
        -- 纸片粗描边
        nvgStrokeColor(ctx, nvgRGBA(10, 8, 6, alpha))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)

        nvgRestore(ctx)
    end
end

-- ============================================================================
-- 暗角效果(Vignette - 饥荒标志性边缘暗化)
-- ============================================================================

function drawVignette(logW, logH)
    local ctx = nvgContext
    local isDay = (gamePhase == "prepare" or gamePhase == "day" or gamePhase == "shrinking")

    -- 暗角强度(黑夜更强)
    local vignetteAlpha = isDay and 120 or 200

    -- 用四个大渐变矩形模拟暗角
    -- 顶部暗角
    local topGrad = nvgLinearGradient(ctx, 0, 0, 0, logH * 0.25,
        nvgRGBA(0, 0, 0, vignetteAlpha), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, logW, logH * 0.25)
    nvgFillPaint(ctx, topGrad)
    nvgFill(ctx)

    -- 底部暗角
    local botGrad = nvgLinearGradient(ctx, 0, logH * 0.75, 0, logH,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, vignetteAlpha))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, logH * 0.75, logW, logH * 0.25)
    nvgFillPaint(ctx, botGrad)
    nvgFill(ctx)

    -- 左侧暗角
    local leftGrad = nvgLinearGradient(ctx, 0, 0, logW * 0.2, 0,
        nvgRGBA(0, 0, 0, vignetteAlpha), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, logW * 0.2, logH)
    nvgFillPaint(ctx, leftGrad)
    nvgFill(ctx)

    -- 右侧暗角
    local rightGrad = nvgLinearGradient(ctx, logW * 0.8, 0, logW, 0,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, vignetteAlpha))
    nvgBeginPath(ctx)
    nvgRect(ctx, logW * 0.8, 0, logW * 0.2, logH)
    nvgFillPaint(ctx, rightGrad)
    nvgFill(ctx)

    -- 四角额外加深(对角线暗角增强)
    local cornerSize = logW * 0.3
    local cornerAlpha = isDay and 80 or 140

    -- 左上角
    local cGrad1 = nvgRadialGradient(ctx, 0, 0, 0, cornerSize,
        nvgRGBA(0, 0, 0, cornerAlpha), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, cornerSize, cornerSize)
    nvgFillPaint(ctx, cGrad1)
    nvgFill(ctx)

    -- 右上角
    local cGrad2 = nvgRadialGradient(ctx, logW, 0, 0, cornerSize,
        nvgRGBA(0, 0, 0, cornerAlpha), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, logW - cornerSize, 0, cornerSize, cornerSize)
    nvgFillPaint(ctx, cGrad2)
    nvgFill(ctx)

    -- 左下角
    local cGrad3 = nvgRadialGradient(ctx, 0, logH, 0, cornerSize,
        nvgRGBA(0, 0, 0, cornerAlpha), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, logH - cornerSize, cornerSize, cornerSize)
    nvgFillPaint(ctx, cGrad3)
    nvgFill(ctx)

    -- 右下角
    local cGrad4 = nvgRadialGradient(ctx, logW, logH, 0, cornerSize,
        nvgRGBA(0, 0, 0, cornerAlpha), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, logW - cornerSize, logH - cornerSize, cornerSize, cornerSize)
    nvgFillPaint(ctx, cGrad4)
    nvgFill(ctx)
end

-- ============================================================================
-- 毒药值屏幕边缘绿色液体覆盖(2.5 UI)
-- ============================================================================

function drawPoisonScreenOverlay(logW, logH)
    local p = players[localPlayerIdx]
    if not p or not p.alive then return end

    local poisonRatio = p.poison / CONFIG.PoisonMax
    if poisonRatio <= 0.01 then return end

    local ctx = nvgContext
    local time = GetTime():GetElapsedTime()

    -- 液体蔓延程度: 0%毒素=不显示, 100%毒素=覆盖全屏
    -- 边缘厚度从 15% 到 50% 随毒素增加
    local edgeRatio = 0.15 + poisonRatio * 0.35
    local baseAlpha = math.floor(40 + poisonRatio * 160)  -- 40~200

    -- 四个边缘的液体渐变(带波浪边缘)
    -- 顶部液体
    local topH = logH * edgeRatio
    -- 波浪形边缘(用多段 rect 模拟不规则滴落)
    for seg = 0, 7 do
        local segX = seg * logW / 8
        local segW = logW / 8 + 2
        -- 每段高度有波浪偏移
        local wave = math.sin(time * 1.2 + seg * 1.7) * topH * 0.15
        local drip = math.sin(time * 0.8 + seg * 2.3) * topH * 0.1  -- 滴落感
        local segH = topH + wave + drip
        local grad = nvgLinearGradient(ctx, segX, 0, segX, segH,
            nvgRGBA(20, 60, 30, baseAlpha),
            nvgRGBA(30, 80, 40, 0))
        nvgBeginPath(ctx)
        nvgRect(ctx, segX, 0, segW, segH)
        nvgFillPaint(ctx, grad)
        nvgFill(ctx)
    end

    -- 底部液体
    local botH = logH * edgeRatio * 0.8
    for seg = 0, 7 do
        local segX = seg * logW / 8
        local segW = logW / 8 + 2
        local wave = math.sin(time * 1.0 + seg * 1.3 + 5.0) * botH * 0.12
        local segH = botH + wave
        local grad = nvgLinearGradient(ctx, segX, logH, segX, logH - segH,
            nvgRGBA(15, 55, 25, baseAlpha), nvgRGBA(25, 70, 35, 0))
        nvgBeginPath(ctx)
        nvgRect(ctx, segX, logH - segH, segW, segH)
        nvgFillPaint(ctx, grad)
        nvgFill(ctx)
    end

    -- 左侧液体
    local leftW = logW * edgeRatio * 0.7
    for seg = 0, 5 do
        local segY = seg * logH / 6
        local segHH = logH / 6 + 2
        local wave = math.sin(time * 0.9 + seg * 2.0 + 3.0) * leftW * 0.18
        local segW = leftW + wave
        local grad = nvgLinearGradient(ctx, 0, segY, segW, segY,
            nvgRGBA(18, 58, 28, baseAlpha), nvgRGBA(28, 75, 38, 0))
        nvgBeginPath(ctx)
        nvgRect(ctx, 0, segY, segW, segHH)
        nvgFillPaint(ctx, grad)
        nvgFill(ctx)
    end

    -- 右侧液体
    local rightW = logW * edgeRatio * 0.7
    for seg = 0, 5 do
        local segY = seg * logH / 6
        local segHH = logH / 6 + 2
        local wave = math.sin(time * 1.1 + seg * 1.8 + 7.0) * rightW * 0.15
        local segW = rightW + wave
        local grad = nvgLinearGradient(ctx, logW, segY, logW - segW, segY,
            nvgRGBA(18, 58, 28, baseAlpha), nvgRGBA(28, 75, 38, 0))
        nvgBeginPath(ctx)
        nvgRect(ctx, logW - segW, segY, segW, segHH)
        nvgFillPaint(ctx, grad)
        nvgFill(ctx)
    end

    -- 四角加深液体(圆角堆积)
    local cornerR = math.min(logW, logH) * edgeRatio * 0.6
    local cornerAlpha = math.floor(baseAlpha * 0.8)
    -- 左上
    local cg1 = nvgRadialGradient(ctx, 0, 0, 0, cornerR,
        nvgRGBA(12, 50, 20, cornerAlpha), nvgRGBA(20, 60, 30, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, cornerR, cornerR)
    nvgFillPaint(ctx, cg1)
    nvgFill(ctx)
    -- 右上
    local cg2 = nvgRadialGradient(ctx, logW, 0, 0, cornerR,
        nvgRGBA(12, 50, 20, cornerAlpha), nvgRGBA(20, 60, 30, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, logW - cornerR, 0, cornerR, cornerR)
    nvgFillPaint(ctx, cg2)
    nvgFill(ctx)
    -- 左下
    local cg3 = nvgRadialGradient(ctx, 0, logH, 0, cornerR,
        nvgRGBA(12, 50, 20, cornerAlpha), nvgRGBA(20, 60, 30, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, logH - cornerR, cornerR, cornerR)
    nvgFillPaint(ctx, cg3)
    nvgFill(ctx)
    -- 右下
    local cg4 = nvgRadialGradient(ctx, logW, logH, 0, cornerR,
        nvgRGBA(12, 50, 20, cornerAlpha), nvgRGBA(20, 60, 30, 0))
    nvgBeginPath(ctx)
    nvgRect(ctx, logW - cornerR, logH - cornerR, cornerR, cornerR)
    nvgFillPaint(ctx, cg4)
    nvgFill(ctx)

    -- 高毒素时添加小气泡粒子(点缀)
    if poisonRatio > 0.3 then
        local bubbleCount = math.floor(poisonRatio * 6)
        for b = 1, bubbleCount do
            local bx = math.fmod(time * 15 + b * 137.5, logW)
            local by = logH - math.fmod(time * 20 + b * 89.3, logH * edgeRatio * 1.5)
            local br = 2 + math.sin(time * 3 + b) * 1.5
            local ba = math.floor(poisonRatio * 100 * (0.5 + math.sin(time * 2 + b * 1.1) * 0.5))
            nvgBeginPath(ctx)
            nvgCircle(ctx, bx, by, br)
            nvgFillColor(ctx, nvgRGBA(60, 180, 80, ba))
            nvgFill(ctx)
        end
    end
end

-- ============================================================================
-- 淘汰页面绘制(settle阶段: 黑屏上显示本轮死亡玩家)
-- ============================================================================

function drawEliminationPage(logW, logH)
    local ctx = nvgContext
    if not ctx then return end
    if #settleDeaths == 0 then return end

    -- 淘汰页面(与胜利页面相同大小, 全屏绘制)
    local eLogW = logW
    local eLogH = logH

    local time = GetTime():GetElapsedTime()

    -- 标题: "本轮淘汰"
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 28)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(220, 60, 60, 240))
    nvgText(ctx, eLogW / 2, eLogH * 0.25, "本轮淘汰")

    -- 死亡玩家列表(居中排列)
    local count = #settleDeaths
    local cardW = 140
    local cardH = 180
    local gap = 20
    local totalW = count * cardW + (count - 1) * gap
    local startX = (eLogW - totalW) / 2
    local startY = eLogH * 0.35

    for idx = 1, count do
        local pIdx = settleDeaths[idx]
        local p = players[pIdx]
        if p then
            local cx = startX + (idx - 1) * (cardW + gap) + cardW / 2
            local cy = startY + cardH / 2

            -- 卡片背景(暗色半透明)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cx - cardW / 2, cy - cardH / 2, cardW, cardH, 8)
            nvgFillColor(ctx, nvgRGBA(30, 20, 20, 180))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(180, 50, 50, 200))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)

            -- 猪角色头像(放大三倍)
            local avatarSize = 108
            local avatarX = cx - avatarSize / 2
            local avatarY = cy - 50
            local pImgHandle = pigImages[p.avatarIdx]
            if pImgHandle and pImgHandle ~= 0 and pImgHandle ~= -1 then
                local paint = nvgImagePattern(ctx, avatarX, avatarY, avatarSize, avatarSize, 0, pImgHandle, 0.8)
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, avatarX, avatarY, avatarSize, avatarSize, 6)
                nvgFillPaint(ctx, paint)
                nvgFill(ctx)
            end

            -- 死亡标记(红色X)
            local headY = avatarY + avatarSize / 2
            local xSize = 24
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, cx - xSize, headY - xSize)
            nvgLineTo(ctx, cx + xSize, headY + xSize)
            nvgMoveTo(ctx, cx + xSize, headY - xSize)
            nvgLineTo(ctx, cx - xSize, headY + xSize)
            nvgStrokeColor(ctx, nvgRGBA(240, 40, 40, 240))
            nvgStrokeWidth(ctx, 3)
            nvgStroke(ctx)

            -- 玩家编号
            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, 20)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(200, 200, 200, 220))
            local label = (pIdx == localPlayerIdx) and "你" or ("P" .. pIdx)
            nvgText(ctx, cx, cy + 70, label)

            -- 死因标注
            nvgFontSize(ctx, 11)
            nvgFillColor(ctx, nvgRGBA(100, 200, 100, 180))
            nvgText(ctx, cx, cy + 42, "中毒")
        end
    end

    -- 存活人数提示
    local aliveCount = getAliveCount()
    nvgFontSize(ctx, 16)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(180, 180, 180, 200))
    nvgText(ctx, eLogW / 2, eLogH * 0.72, "剩余存活: " .. aliveCount .. " 人")
end

-- ============================================================================
-- 触控按钮绘制(手机适配)
-- ============================================================================

function drawTouchControls(logW, logH)
    local ctx = nvgContext
    if not ctx then return end

    local rects = getTouchButtonRects(logW, logH)
    local p = players[localPlayerIdx]

    -- ===== 右侧按钮 =====

    -- 攻击按钮
    local atkRect = rects.attack
    local atkCx = atkRect.x + atkRect.w / 2
    local atkCy = atkRect.y + atkRect.h / 2
    local atkAlpha = touchButtons.attack.pressed and 200 or 120

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, atkRect.x, atkRect.y, atkRect.w, atkRect.h, 12)
    nvgFillColor(ctx, nvgRGBA(180, 50, 50, atkAlpha))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(240, 80, 80, 180))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 16)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 230))
    nvgText(ctx, atkCx, atkCy, "攻击")

    -- 道具按钮(药水图标, 放大两倍)
    local itemRect = rects.item
    local itemCx = itemRect.x + itemRect.w / 2
    local itemCy = itemRect.y + itemRect.h / 2
    local itemAlpha = touchButtons.item.pressed and 220 or 140

    -- 确定药水类型和对应图片
    local potionR, potionG, potionB = 120, 120, 160  -- 默认灰色
    local potionLabel = "道具"
    local itemPotionImg = nil
    if p and p.alive and p.potionState then
        if p.potionState == "antidote" then
            potionR, potionG, potionB = 80, 180, 255
            potionLabel = "解药"
        elseif p.potionState == "poison" then
            potionR, potionG, potionB = 120, 200, 60
            potionLabel = "毒药"
        elseif p.potionState == "victory" then
            potionR, potionG, potionB = 220, 180, 50
            potionLabel = "胜利"
        end
        itemPotionImg = potionNvgImages[p.potionState]
    end

    -- 圆形背景
    nvgBeginPath(ctx)
    nvgCircle(ctx, itemCx, itemCy, itemRect.w / 2)
    nvgFillColor(ctx, nvgRGBA(20, 20, 30, itemAlpha))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(potionR, potionG, potionB, 200))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)

    -- 绘制药水图片或文字
    if itemPotionImg then
        local iconSize = math.min(itemRect.w, itemRect.h) * 0.7
        local iconX = itemCx - iconSize / 2
        local iconY = itemCy - iconSize / 2
        local imgPaint = nvgImagePattern(ctx, iconX, iconY, iconSize, iconSize, 0, itemPotionImg, 1.0)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, iconX, iconY, iconSize, iconSize, 4)
        nvgFillPaint(ctx, imgPaint)
        nvgFill(ctx)
    else
        -- 无药水时显示文字
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 20)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(150, 150, 150, 180))
        nvgText(ctx, itemCx, itemCy, potionLabel)
    end

    -- 底部文字标签
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 14)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 200))
    nvgText(ctx, itemCx, itemCy + itemRect.h / 2 - 18, potionLabel)

    -- ===== 奔跑按钮(左下, 摇杆右侧, 常驻) =====
    local sprintRect = rects.sprint
    local sprintCx = sprintRect.x + sprintRect.w / 2
    local sprintCy = sprintRect.y + sprintRect.h / 2
    local sprintAlpha = touchButtons.sprint.pressed and 200 or 110
    local sprintActive = p and p.alive and p.sprinting

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sprintRect.x, sprintRect.y, sprintRect.w, sprintRect.h, 12)
    if sprintActive then
        nvgFillColor(ctx, nvgRGBA(220, 160, 30, sprintAlpha))
    else
        nvgFillColor(ctx, nvgRGBA(100, 100, 60, sprintAlpha))
    end
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(220, 180, 60, sprintActive and 220 or 140))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 14)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 230))
    nvgText(ctx, sprintCx, sprintCy, "奔跑")

    -- ===== 交换药水按钮(靠近其他玩家或收到请求时显示) =====
    local showInteract = false
    local interactLabel = "交换"
    if p and p.alive and not p.isGhost and gamePhase == "day" then
        if p.interactState == "pending" then
            -- 收到交换请求时显示"接受"
            showInteract = true
            interactLabel = "接受"
        elseif p.interactState == "idle" then
            -- 靠近其他玩家时显示"交换"
            for i = 1, #players do
                local other = players[i]
                if other.idx ~= p.idx and other.alive and other.interactState == "idle"
                    and other.drinkingState == "idle" then
                    local d = dist(p.x, p.y, other.x, other.y)
                    if d <= CONFIG.InteractRange then
                        showInteract = true
                        break
                    end
                end
            end
        end
    end

    if showInteract then
        local intRect = rects.interact
        local intCx = intRect.x + intRect.w / 2
        local intCy = intRect.y + intRect.h / 2
        local intAlpha = touchButtons.interact.pressed and 200 or 120

        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, intRect.x, intRect.y, intRect.w, intRect.h, 12)
        nvgFillColor(ctx, nvgRGBA(60, 120, 180, intAlpha))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(100, 180, 240, 180))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)

        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 14)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 230))
        nvgText(ctx, intCx, intCy, interactLabel)
    end

    -- ===== 拒绝交换按钮(收到请求或交互中时显示) =====
    local showReject = p and p.alive and not p.isGhost and gamePhase == "day"
        and (p.interactState == "pending" or p.interactState == "requesting" or p.interactState == "interacting")
    if showReject then
        local rejRect = rects.reject
        local rejCx = rejRect.x + rejRect.w / 2
        local rejCy = rejRect.y + rejRect.h / 2
        local rejAlpha = touchButtons.reject.pressed and 200 or 120

        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, rejRect.x, rejRect.y, rejRect.w, rejRect.h, 12)
        nvgFillColor(ctx, nvgRGBA(160, 50, 50, rejAlpha))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(220, 80, 80, 180))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)

        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 14)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 230))
        nvgText(ctx, rejCx, rejCy, "拒绝")
    end

    -- ===== 左侧虚拟摇杆 =====
    if touchJoystick.active then
        -- 外圈
        nvgBeginPath(ctx)
        nvgCircle(ctx, touchJoystick.cx, touchJoystick.cy, touchJoystick.radius)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 30))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 80))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)

        -- 内圈(摇杆位置)
        local knobX = touchJoystick.cx + touchJoystick.dx
        local knobY = touchJoystick.cy + touchJoystick.dy
        nvgBeginPath(ctx)
        nvgCircle(ctx, knobX, knobY, 18)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 100))
        nvgFill(ctx)
    end
end

-- ============================================================================
-- 倒计时钟表绘制(2.5 UI - 老式钟表样式)
-- ============================================================================

function drawClockCountdown(logW, logH)
    local ctx = nvgContext
    local time = GetTime():GetElapsedTime()

    -- 仅在 settle 倒计时子阶段显示倒计时钟表(5秒黑屏倒计时)
    if not (gamePhase == "settle" and settleSubPhase == "countdown") then
        return
    end

    local countdown = phaseTimer
    if countdown <= 0 then return end

    local seconds = math.ceil(countdown)

    -- 位置: 屏幕正中央
    local cx = logW / 2
    local cy = logH / 2

    -- 最后2秒放大1.5倍 + 震动
    local scale = 1.0
    local shakeX, shakeY = 0, 0
    if countdown <= 2.0 then
        scale = 1.0 + (1.0 - countdown / 2.0) * 0.5  -- 1.0 → 1.5
        shakeX = math.sin(time * 30) * 3 * (1.0 - countdown / 2.0)
        shakeY = math.cos(time * 25) * 2 * (1.0 - countdown / 2.0)
    end

    nvgSave(ctx)
    nvgTranslate(ctx, cx + shakeX, cy + shakeY)
    nvgScale(ctx, scale, scale)

    local clockR = 44

    -- 钟表外壳(老式铜色圆环)
    -- 外环
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, 0, clockR + 5)
    nvgStrokeColor(ctx, nvgRGBA(120, 85, 40, 220))
    nvgStrokeWidth(ctx, 4.5)
    nvgStroke(ctx)

    -- 内环
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, 0, clockR)
    nvgStrokeColor(ctx, nvgRGBA(90, 65, 30, 200))
    nvgStrokeWidth(ctx, 2.5)
    nvgStroke(ctx)

    -- 表盘背景(泛黄纸质感)
    local facePaint = nvgRadialGradient(ctx, 0, 0, 0, clockR,
        nvgRGBA(240, 225, 190, 220), nvgRGBA(210, 195, 155, 200))
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, 0, clockR - 1)
    nvgFillPaint(ctx, facePaint)
    nvgFill(ctx)

    -- 刻度线(12个小刻度)
    for tick = 1, 12 do
        local angle = (tick / 12) * math.pi * 2 - math.pi / 2
        local inner = clockR - 6
        local outer = clockR - 2
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, math.cos(angle) * inner, math.sin(angle) * inner)
        nvgLineTo(ctx, math.cos(angle) * outer, math.sin(angle) * outer)
        nvgStrokeColor(ctx, nvgRGBA(60, 45, 20, 200))
        nvgStrokeWidth(ctx, tick % 3 == 0 and 2 or 1)
        nvgStroke(ctx)
    end

    -- 秒针(基于倒计时的小数部分旋转)
    local secFrac = 1.0 - (countdown - math.floor(countdown))
    local secAngle = secFrac * math.pi * 2 - math.pi / 2
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, 0, 0)
    nvgLineTo(ctx, math.cos(secAngle) * (clockR - 8), math.sin(secAngle) * (clockR - 8))
    nvgStrokeColor(ctx, nvgRGBA(180, 30, 20, 230))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 中心铆钉
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, 0, 4)
    nvgFillColor(ctx, nvgRGBA(80, 60, 30, 240))
    nvgFill(ctx)

    -- 顶部小环(老式挂表的挂环)
    nvgBeginPath(ctx)
    nvgCircle(ctx, 0, -(clockR + 10), 7)
    nvgStrokeColor(ctx, nvgRGBA(120, 85, 40, 200))
    nvgStrokeWidth(ctx, 2.5)
    nvgStroke(ctx)

    nvgRestore(ctx)

    -- 倒计时数字(钟表下方, 手绘字体感)
    if fontId ~= -1 then
        nvgSave(ctx)
        nvgTranslate(ctx, cx + shakeX, cy + shakeY)
        nvgScale(ctx, scale, scale)

        nvgFontFaceId(ctx, fontId)
        nvgFontSize(ctx, 32)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

        -- 文字阴影
        nvgFillColor(ctx, nvgRGBA(40, 30, 15, 150))
        nvgText(ctx, 1, clockR + 10 + 1, tostring(seconds) .. "s", nil)
        -- 正文(泛黄墨水色)
        local urgency = countdown <= 2.0 and 255 or 200
        nvgFillColor(ctx, nvgRGBA(urgency, math.floor(urgency * 0.4), 20, 240))
        nvgText(ctx, 0, clockR + 10, tostring(seconds) .. "s", nil)

        nvgRestore(ctx)
    end
end

-- ============================================================================
-- 屏幕边缘方向指示标(指向视野外的舒适区和携带解药玩家)
-- ============================================================================

function drawOffscreenIndicators(logW, logH, offsetX, offsetY, zoom)
    local ctx = nvgContext
    zoom = zoom or 1.0
    if gamePhase == "menu" or gamePhase == "victory" or gamePhase == "defeat" then return end
    if gamePhase == "settle" then return end

    local time = GetTime():GetElapsedTime()
    local padding = 40       -- 距离屏幕边缘的内边距
    local arrowSize = 14     -- 箭头大小
    local iconSize = 22      -- 图标圆圈大小

    local centerX = logW / 2
    local centerY = logH / 2

    -- 收集需要指示的目标: {screenX, screenY, type, color}
    local targets = {}

    -- 1. 非腐化舒适区
    for _, zone in ipairs(comfortZones) do
        if not zone.corrupted then
            local sx = (zone.x - camera.x) * zoom + logW / 2
            local sy = (zone.y - camera.y) * zoom + logH / 2
            -- 判断是否在屏幕外
            if sx < -20 or sx > logW + 20 or sy < -20 or sy > logH + 20 then
                local r, g, b = 255, 200, 60  -- 默认黄色(campfire)
                if zone.type == "spring" then
                    r, g, b = 80, 200, 255
                elseif zone.type == "altar" then
                    r, g, b = 180, 100, 255
                end
                table.insert(targets, {sx = sx, sy = sy, kind = "zone", r = r, g = g, b = b, label = "☀"})
            end
        end
    end

    -- 2. 携带解药的存活玩家(排除自己)
    for i, p in ipairs(players) do
        if i ~= localPlayerIdx and p.alive and p.potionState == "antidote" then
            local sx = (p.x - camera.x) * zoom + logW / 2
            local sy = (p.y - camera.y) * zoom + logH / 2
            if sx < -20 or sx > logW + 20 or sy < -20 or sy > logH + 20 then
                table.insert(targets, {sx = sx, sy = sy, kind = "antidote", r = 60, g = 200, b = 255, label = "✚"})
            end
        end
    end

    if #targets == 0 then return end

    -- 绘制每个屏幕边缘指示标
    for _, t in ipairs(targets) do
        -- 计算从屏幕中心到目标的方向
        local dx = t.sx - centerX
        local dy = t.sy - centerY
        local angle = math.atan(dy, dx)

        -- 将指示标钳制到屏幕边缘(带内边距)
        local edgeX, edgeY
        local halfW = centerX - padding
        local halfH = centerY - padding

        -- 用射线与矩形边界求交
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)
        local scaleX = (cosA ~= 0) and math.abs(halfW / cosA) or 99999
        local scaleY = (sinA ~= 0) and math.abs(halfH / sinA) or 99999
        local scale = math.min(scaleX, scaleY)

        edgeX = centerX + cosA * scale
        edgeY = centerY + sinA * scale

        -- 钳制确保不超出屏幕
        edgeX = math.max(padding, math.min(logW - padding, edgeX))
        edgeY = math.max(padding, math.min(logH - padding, edgeY))

        -- 计算到目标的距离(用于透明度脉动)
        local distToTarget = math.sqrt(dx * dx + dy * dy)
        local pulse = 0.7 + 0.3 * math.sin(time * 3 + angle * 2)
        local alpha = math.floor(220 * pulse)

        -- 绘制箭头形指示标
        nvgSave(ctx)
        nvgTranslate(ctx, edgeX, edgeY)
        nvgRotate(ctx, angle)

        -- 外发光
        nvgBeginPath(ctx)
        nvgCircle(ctx, 0, 0, iconSize + 4)
        nvgFillColor(ctx, nvgRGBA(t.r, t.g, t.b, math.floor(alpha * 0.3)))
        nvgFill(ctx)

        -- 圆形背景
        nvgBeginPath(ctx)
        nvgCircle(ctx, 0, 0, iconSize)
        nvgFillColor(ctx, nvgRGBA(0, 0, 0, math.floor(alpha * 0.7)))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(t.r, t.g, t.b, alpha))
        nvgStrokeWidth(ctx, 2.0)
        nvgStroke(ctx)

        -- 箭头尖端(指向目标方向)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, iconSize + arrowSize, 0)
        nvgLineTo(ctx, iconSize - 2, -arrowSize * 0.6)
        nvgLineTo(ctx, iconSize - 2, arrowSize * 0.6)
        nvgClosePath(ctx)
        nvgFillColor(ctx, nvgRGBA(t.r, t.g, t.b, alpha))
        nvgFill(ctx)

        -- 内部图标(旋转回正，让文字不歪)
        nvgRotate(ctx, -angle)
        if fontId ~= -1 then
            nvgFontFaceId(ctx, fontId)
            nvgFontSize(ctx, 14)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(t.r, t.g, t.b, alpha))
            nvgText(ctx, 0, 0, t.label)
        end

        nvgRestore(ctx)

        -- 距离文字(在图标下方)
        local distMeters = math.floor(distToTarget / 10)  -- 粗略距离
        if distMeters > 0 and fontId ~= -1 then
            nvgFontFaceId(ctx, fontId)
            nvgFontSize(ctx, 11)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(ctx, nvgRGBA(t.r, t.g, t.b, math.floor(alpha * 0.8)))
            nvgText(ctx, edgeX, edgeY + iconSize + 4, tostring(distMeters) .. "m")
        end
    end
end

-- ============================================================================
-- 阶段提示文字(3.x 新状态机)
-- ============================================================================

function drawPhaseHint(logW, logH)
    local ctx = nvgContext
    if fontId == -1 then return end

    local time = GetTime():GetElapsedTime()
    local hint = nil
    local timerText = nil
    local hintColor = {200, 200, 200, 220}
    local fontSize = 22

    if gamePhase == "prepare" then
        hint = "战斗即将开始..."
        timerText = tostring(math.ceil(phaseTimer))
        hintColor = {200, 140, 30, 220}  -- 暗橙色
    elseif gamePhase == "settle" and settleSubPhase == "countdown" then
        hint = "黑夜降临!"
        hintColor = {200, 20, 20, 255}  -- 血红色
        fontSize = 28
    elseif gamePhase == "day" then
        -- 白天最后5秒显示红色倒计时警告
        if phaseTimer <= 5.0 then
            hint = "黑夜即将来临!"
            local pulse = math.sin(time * 8)
            local a = math.floor(180 + 75 * pulse)
            hintColor = {220, 40, 40, a}
        end
    elseif gamePhase == "settle" and settleSubPhase == "elimination" then
        if #settleDeaths > 0 then
            hint = #settleDeaths .. " 人被毒素吞噬..."
        else
            hint = "全员存活!"
        end
        hintColor = {180, 60, 60, 220}
    elseif gamePhase == "shrinking" then
        hint = "下一轮准备..."
        timerText = tostring(math.ceil(phaseTimer))
        hintColor = {150, 150, 180, 200}
    end

    if not hint then return end

    local cx = logW / 2
    local cy = (gamePhase == "settle" and settleSubPhase == "countdown") and (logH * 0.33) or (logH * 0.15)

    nvgFontFaceId(ctx, fontId)
    nvgFontSize(ctx, fontSize)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 文字阴影
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, math.floor(hintColor[4] * 0.6)))
    nvgText(ctx, cx + 2, cy + 2, hint, nil)
    -- 文字本体
    nvgFillColor(ctx, nvgRGBA(hintColor[1], hintColor[2], hintColor[3], hintColor[4]))
    nvgText(ctx, cx, cy, hint, nil)

    -- 阶段计时器数字(大号)
    if timerText then
        nvgFontSize(ctx, 36)
        nvgFillColor(ctx, nvgRGBA(0, 0, 0, 150))
        nvgText(ctx, cx + 2, cy + 32, timerText, nil)
        nvgFillColor(ctx, nvgRGBA(hintColor[1], hintColor[2], hintColor[3], hintColor[4]))
        nvgText(ctx, cx, cy + 30, timerText, nil)
    end
end

-- ============================================================================
-- 返回主页按钮(胜利/失败画面共用)
-- ============================================================================


function drawBackToMenuButton(ctx, cx, cy, color)
    local btnW = 140
    local btnH = 36
    local btnX = cx - btnW / 2
    local btnY = cy - btnH / 2
    -- 记录按钮区域
    backToMenuBtnRect.x = btnX
    backToMenuBtnRect.y = btnY
    backToMenuBtnRect.w = btnW
    backToMenuBtnRect.h = btnH

    -- 按钮背景
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, btnX, btnY, btnW, btnH, 18)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 200))
    nvgFill(ctx)
    -- 边框
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, btnX, btnY, btnW, btnH, 18)
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, 120))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    -- 文字
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 16)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgText(ctx, cx, cy, "返回主页", nil)
end

function backToMenu()
    gamePhase = "menu"
    -- 显示菜单，隐藏HUD
    local menu = uiRoot_:FindById("menuPanel")
    if menu then menu:SetVisible(true) end
    local hud = uiRoot_:FindById("hudPanel")
    if hud then hud:SetVisible(false) end
    -- 隐藏背包
    inventoryOpen = false
    local invPanel = uiRoot_:FindById("inventoryPanel")
    if invPanel then invPanel:SetVisible(false) end
end

-- ============================================================================
-- 胜利画面
-- ============================================================================
function drawVictoryScreen(logW, logH)
    local ctx = nvgContext
    if not ctx then return end

    -- 背景: 深色渐变
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, logW, logH)
    local bgPaint = nvgLinearGradient(ctx, 0, 0, 0, logH,
        nvgRGBA(10, 15, 30, 255), nvgRGBA(5, 8, 15, 255))
    nvgFillPaint(ctx, bgPaint)
    nvgFill(ctx)

    -- 获胜玩家
    local winner = victoryWinnerIdx and players[victoryWinnerIdx] or nil
    if not winner then return end

    local time = GetTime():GetElapsedTime()
    local cx = logW / 2
    local cy = logH / 2

    -- 光芒放射效果(背景)
    local rayCount = 12
    for i = 1, rayCount do
        local angle = (i / rayCount) * math.pi * 2 + time * 0.3
        local rayLen = 200 + math.sin(time * 2 + i) * 30
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, cx, cy + 20)
        nvgLineTo(ctx, cx + math.cos(angle) * rayLen, cy + 20 + math.sin(angle) * rayLen)
        nvgStrokeColor(ctx, nvgRGBA(255, 215, 80, 25))
        nvgStrokeWidth(ctx, 8)
        nvgStroke(ctx)
    end

    -- 光圈(脉动)
    local pulseR = 100 + math.sin(time * 3) * 10
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy + 20, pulseR)
    local glowPaint = nvgRadialGradient(ctx, cx, cy + 20, pulseR * 0.3, pulseR,
        nvgRGBA(255, 200, 50, 60), nvgRGBA(255, 200, 50, 0))
    nvgFillPaint(ctx, glowPaint)
    nvgFill(ctx)

    -- === 全身角色展示(猪角色图片放大) ===
    local victoryImgW = 160
    local victoryImgH = 160
    local victoryImgX = cx - victoryImgW / 2
    local victoryImgY = cy - victoryImgH / 2 + 10

    -- 阴影
    nvgBeginPath(ctx)
    nvgEllipse(ctx, cx, victoryImgY + victoryImgH + 5, 50, 12)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 80))
    nvgFill(ctx)

    -- 胜利弹跳动画
    local bounce = math.abs(math.sin(time * 3)) * 8
    victoryImgY = victoryImgY - bounce

    -- 绘制猪角色图片(放大)
    local winImgHandle = pigImages[winner.avatarIdx]
    if winImgHandle and winImgHandle ~= 0 and winImgHandle ~= -1 then
        local paint = nvgImagePattern(ctx, victoryImgX, victoryImgY, victoryImgW, victoryImgH, 0, winImgHandle, 1.0)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, victoryImgX, victoryImgY, victoryImgW, victoryImgH, 12)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
        -- 金色边框
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, victoryImgX, victoryImgY, victoryImgW, victoryImgH, 12)
        nvgStrokeColor(ctx, nvgRGBA(255, 215, 50, 200))
        nvgStrokeWidth(ctx, 4)
        nvgStroke(ctx)
    end

    -- === 标题文字 ===
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- "胜利!" 大字
    nvgFontSize(ctx, 48)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 200))
    nvgText(ctx, cx + 3, logH * 0.1 + 3, "胜利!", nil)
    nvgFillColor(ctx, nvgRGBA(255, 215, 50, 255))
    nvgText(ctx, cx, logH * 0.1, "胜利!", nil)

    -- 玩家标识
    local isLocal = (victoryWinnerIdx == localPlayerIdx)
    local nameText = isLocal and "你获得了最终胜利!" or ("玩家 P" .. victoryWinnerIdx .. " 获胜")
    nvgFontSize(ctx, 22)
    nvgFillColor(ctx, nvgRGBA(220, 220, 220, 230))
    nvgText(ctx, cx, logH * 0.88, nameText, nil)

    -- 金色粒子装饰
    for i = 1, 20 do
        local px = cx + math.sin(time * 1.2 + i * 1.7) * (80 + i * 8)
        local py = logH * 0.2 + math.fmod(time * 40 + i * 35, logH * 0.7)
        local pAlpha = math.floor(180 - (py / logH) * 120)
        local pSize = 2 + math.sin(time + i) * 1.5
        nvgBeginPath(ctx)
        nvgCircle(ctx, px, py, pSize)
        nvgFillColor(ctx, nvgRGBA(255, 200, 50, pAlpha))
        nvgFill(ctx)
    end

    -- 返回主页按钮
    drawBackToMenuButton(ctx, cx, logH * 0.95, {255, 215, 50})
end

-- ============================================================================
-- 失败画面
-- ============================================================================
function drawDefeatScreen(logW, logH)
    local ctx = nvgContext
    if not ctx then return end

    -- 背景: 暗红渐变
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, logW, logH)
    local bgPaint = nvgLinearGradient(ctx, 0, 0, 0, logH,
        nvgRGBA(20, 5, 5, 255), nvgRGBA(8, 2, 2, 255))
    nvgFillPaint(ctx, bgPaint)
    nvgFill(ctx)

    local time = GetTime():GetElapsedTime()
    local cx = logW / 2

    -- 标题: "全军覆没"
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, 42)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 180))
    nvgText(ctx, cx + 2, logH * 0.12 + 2, "全军覆没", nil)
    nvgFillColor(ctx, nvgRGBA(200, 50, 50, 255))
    nvgText(ctx, cx, logH * 0.12, "全军覆没", nil)

    -- 副标题
    nvgFontSize(ctx, 18)
    nvgFillColor(ctx, nvgRGBA(160, 140, 140, 200))
    nvgText(ctx, cx, logH * 0.2, "无人生还...", nil)

    -- 所有玩家死亡头像排列
    local count = #players
    local cardW = 70
    local cardH = 100
    local gap = 12
    local cols = math.min(count, 3)  -- 最多3列
    local rows = math.ceil(count / cols)
    local totalW = cols * cardW + (cols - 1) * gap
    local totalH = rows * cardH + (rows - 1) * gap
    local startX = (logW - totalW) / 2
    local startY = (logH - totalH) / 2 + 10

    for idx = 1, count do
        local p = players[idx]
        if p then
            local col = ((idx - 1) % cols)
            local row = math.floor((idx - 1) / cols)
            local cardCX = startX + col * (cardW + gap) + cardW / 2
            local cardCY = startY + row * (cardH + gap) + cardH / 2

            -- 卡片背景(暗色半透明, 红边)
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cardCX - cardW / 2, cardCY - cardH / 2, cardW, cardH, 8)
            nvgFillColor(ctx, nvgRGBA(25, 10, 10, 200))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(120, 30, 30, 180))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)

            -- 猪角色头像(缩小显示)
            local avatarSize = 40
            local avatarX = cardCX - avatarSize / 2
            local avatarY = cardCY - 24
            local pImgHandle = pigImages[p.avatarIdx]
            if pImgHandle and pImgHandle ~= 0 and pImgHandle ~= -1 then
                local paint = nvgImagePattern(ctx, avatarX, avatarY, avatarSize, avatarSize, 0, pImgHandle, 0.5)
                nvgBeginPath(ctx)
                nvgRoundedRect(ctx, avatarX, avatarY, avatarSize, avatarSize, 6)
                nvgFillPaint(ctx, paint)
                nvgFill(ctx)
            end

            -- 死亡X标记
            local xSize = 10
            local headCY = avatarY + avatarSize / 2
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, cardCX - xSize, headCY - xSize)
            nvgLineTo(ctx, cardCX + xSize, headCY + xSize)
            nvgMoveTo(ctx, cardCX + xSize, headCY - xSize)
            nvgLineTo(ctx, cardCX - xSize, headCY + xSize)
            nvgStrokeColor(ctx, nvgRGBA(200, 40, 40, 220))
            nvgStrokeWidth(ctx, 3)
            nvgStroke(ctx)

            -- 玩家编号
            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, 14)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(180, 160, 160, 200))
            local label = (idx == localPlayerIdx) and "你" or ("P" .. idx)
            nvgText(ctx, cardCX, cardCY + 30, label, nil)
        end
    end

    -- 底部暗红烟雾效果
    for i = 1, 8 do
        local fogX = cx + math.sin(time * 0.5 + i * 2.3) * (logW * 0.4)
        local fogY = logH * 0.85 + math.sin(time * 0.3 + i) * 15
        local fogR = 60 + math.sin(time + i) * 20
        nvgBeginPath(ctx)
        nvgCircle(ctx, fogX, fogY, fogR)
        local fogPaint = nvgRadialGradient(ctx, fogX, fogY, 0, fogR,
            nvgRGBA(80, 10, 10, 30), nvgRGBA(80, 10, 10, 0))
        nvgFillPaint(ctx, fogPaint)
        nvgFill(ctx)
    end

    -- 返回主页按钮
    drawBackToMenuButton(ctx, cx, logH * 0.95, {200, 80, 80})
end
