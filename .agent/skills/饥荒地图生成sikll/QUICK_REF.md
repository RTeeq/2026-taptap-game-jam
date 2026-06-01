# 饥荒风格地形贴图生成器 - 快速参考卡片

## 一键生成

```lua
local TG = require("DSTTextureGenerator_Extended")

-- 单张贴图
local pixels = TG.generate("grass", 256, 256, 12345, 0.7)
local texture = TG.createTexture2D(pixels, 256, 256)

-- 全部贴图（带缓存）
local all = TG.generateTileMapTextures(256, 12345)

-- 完整 TileMap 资源
local res = TG.createTileMapResources(256, 32, 32, 12345)
-- res.textures, res.materials, res.tileMapData
```

## 地形类型速查

| 类型 | 英文名 | 颜色基调 | 关键特征 |
|------|--------|----------|----------|
| 🌿 草地 | grass | #3C7828 | 枯黄斑块、杂草点缀 |
| 🪨 沼泽 | swamp | #3D4632 | 气泡、枯枝、腐殖质 |
| 🟫 泥地 | mud | #735A3A | 裂纹、水洼反光 |
| ⬜ 碎石地 | rocky | #827D73 | 碎石分布、沙砾 |
| ❄️ 雪地 | snow | #DCDEE6 | 冰晶反光、脚印凹陷 |
| 🏜️ 沙漠 | desert | #C4AA78 | 风蚀纹理、沙丘明暗 |
| 🌋 火山岩 | volcanic | #412820 | 熔岩裂缝发光、灰烬 |

## 参数速查

```lua
TG.generate(type, width, height, seed, styleIntensity)
--     type: "grass" | "swamp" | "mud" | "rocky" | "snow" | "desert" | "volcanic"
--   width: 64 ~ 1024 (推荐 256)
--  height: 64 ~ 1024 (推荐 256)
--    seed: 任意整数 (相同种子 = 相同贴图)
--  styleIntensity: 0.0 ~ 1.0 (推荐 0.6~0.8)
```

## 缓存控制

```lua
TG.setCacheEnabled(true)   -- 开启缓存（默认）
TG.setCacheEnabled(false)  -- 关闭缓存
TG.generateCached(...)     -- 使用缓存生成
```

## 混合地形

```lua
-- 使用噪声遮罩混合多种地形
local mask_grass = math.max(0, 1 - math.abs(n1 - 0.3) * 3)
local mask_swamp = math.max(0, 1 - math.abs(n1 - 0.7) * 3)
-- 加权混合 RGB 值
```

## 性能建议

| 场景 | 分辨率 | 缓存 |
|------|--------|------|
| 移动端 | 128x128 | 必开 |
| 通用 | 256x256 | 推荐 |
| 高清 | 512x512 | 必开 |

## 风格公式

**饥荒风格 = 低饱和 + 手绘噪点 + 不规则斑块 + 暗黑基调**

```lua
-- 颜色调整公式
r = baseR + noise * variation + grain * styleIntensity
-- baseR: 基色（偏暗）
-- noise: 分形噪声 (0~1)
-- variation: 变化范围（20~40）
-- grain: 随机噪点 (-15~15)
-- styleIntensity: 风格强度 (0.6~0.8)
```
