# 饥荒风格程序化地形贴图生成器

> **Don't Starve Style Procedural Texture Generator** for TapTap 制造 (UrhoX)
> 版本: 1.1.0 | 地形类型: 7种 | 模块: 6个

## 简介

本项目为 TapTap 制造平台提供饥荒（Don't Starve）风格的程序化地形贴图生成能力，包含 **7种地形类型**，支持 **无缝平铺**、**贴图缓存**、**瓦片地图集成**、**季节切换**、**天气效果**、**植被覆盖**、**法线贴图生成** 等高级功能。

## 特性

- ✅ **7种地形类型**：草地、沼泽、泥地、碎石地、雪地、沙漠、火山岩
- ✅ **饥荒风格**：手绘卡通、暗黑哥特、低饱和、噪点质感
- ✅ **无缝平铺**：所有贴图支持 Tileable，无接缝
- ✅ **性能优化**：内置贴图缓存系统，避免重复生成
- ✅ **瓦片地图集成**：一键生成 TileMap2D 所需材质和数据
- ✅ **季节系统**：春/夏/秋/冬四季色调自动切换
- ✅ **天气效果**：雨/雪/雾/夜晚四种天气影响
- ✅ **植被覆盖**：程序化草丛和花朵覆盖层
- ✅ **法线贴图**：基于高度噪声生成配套法线贴图
- ✅ **可复现**：通过种子值复现完全相同的贴图
- ✅ **参数可调**：风格强度、分辨率、噪声层级均可配置

## 文件结构

```
├── SKILL.md                              # TapTap 制造 Skill 文件（AI 协作规范）
├── DSTTextureGenerator.lua              # 基础贴图生成模块（4种地形）
├── DSTTextureGenerator_Extended.lua       # 扩展模块（+3种地形 + 缓存 + TileMap）
├── NormalMapGenerator.lua               # 法线贴图生成器
├── SeasonShifter.lua                    # 季节色调切换器
├── WeatherEffects.lua                   # 天气效果生成器
├── VegetationGenerator.lua              # 植被覆盖层生成器
├── main.lua                             # 基础项目示例
├── comprehensive_example.lua            # 综合项目示例（整合所有模块）
├── README.md                            # 本文件
├── QUICK_REF.md                         # 快速参考卡片
├── MANIFEST.md                          # 文件清单
├── DST_Texture_Preview.png              # 基础地形预览图
├── DST_Texture_Extended_Preview.png     # 扩展地形预览图
├── DST_Season_Preview.png               # 季节效果预览图
├── DST_Weather_Preview.png              # 天气效果预览图
├── DST_Vegetation_Preview.png           # 植被覆盖预览图
└── DST_Application_Guide.png            # 应用指南和色卡
```

## 快速开始

### 1. 基础用法（单张贴图）

```lua
local TextureGenerator = require("DSTTextureGenerator")

-- 生成 256x256 的草地贴图
local grassPixels = TextureGenerator.generate("grass", 256, 256, 12345, 0.7)

-- 创建 UrhoX Texture2D
local texture = TextureGenerator.createTexture2D(grassPixels, 256, 256)

-- 应用到材质
local material = Material()
material:SetTexture(TextureUnit.DIFFUSE, texture)
```

### 2. 生成所有地形贴图

```lua
local TextureGenerator = require("DSTTextureGenerator_Extended")

-- 生成全部 7 种地形贴图（使用缓存）
local textures = TextureGenerator.generateTileMapTextures(256, 12345)

-- textures 包含:
-- textures.grass, textures.swamp, textures.mud, textures.rocky
-- textures.snow, textures.desert, textures.volcanic
```

### 3. 瓦片地图集成

```lua
local TextureGenerator = require("DSTTextureGenerator_Extended")

-- 一键生成 TileMap 资源
local resources = TextureGenerator.createTileMapResources(256, 32, 32, 12345)

-- resources.textures    -- Texture2D 表
-- resources.materials   -- Material 表
-- resources.tileMapData -- 2D 地形类型数组
```

### 4. 季节切换

```lua
local SeasonShifter = require("SeasonShifter")

-- 将春季草地变为秋季色调
local autumnGrass = SeasonShifter.apply(grassPixels, 256, 256, "autumn")

-- 季节过渡（从春季到夏季，进度 50%）
local blended = SeasonShifter.blend(grassPixels, 256, 256, "spring", "summer", 0.5)

-- 根据游戏天数获取季节
local season, progress = SeasonShifter.getSeasonByDay(25)  -- 返回 "summer", 0.39
```

### 5. 天气效果

```lua
local WeatherEffects = require("WeatherEffects")

-- 应用雨天效果
local rainyGrass = WeatherEffects.apply(grassPixels, 256, 256, "rain", 0.6)

-- 应用雪天效果
local snowyGrass = WeatherEffects.apply(grassPixels, 256, 256, "snow", 0.7)

-- 应用夜晚效果
local nightGrass = WeatherEffects.apply(grassPixels, 256, 256, "night", 0.8)
```

### 6. 植被覆盖

```lua
local VegetationGenerator = require("VegetationGenerator")

-- 生成带植被的草地
local vegetatedGrass = VegetationGenerator.generateVegetatedGrass(
    256, 256, 12345, 0.3, 0.1  -- 草丛密度0.3, 花朵密度0.1
)

-- 单独生成草丛覆盖层
local tufts = VegetationGenerator.generateGrassTufts(256, 256, 12345, 0.3)

-- 单独生成花朵覆盖层
local flowers = VegetationGenerator.generateFlowers(256, 256, 12345, 0.1)

-- 合并到基础贴图
local merged = VegetationGenerator.merge(grassPixels, tufts, 256, 256)
```

### 7. 法线贴图

```lua
local NormalMapGenerator = require("NormalMapGenerator")

-- 生成法线贴图
local normalPixels = NormalMapGenerator.generate("grass", 256, 256, 12345, 2.0)

-- 创建 UrhoX 法线贴图
local normalTexture = NormalMapGenerator.createNormalTexture(normalPixels, 256, 256)

-- 应用到材质
material:SetTexture(TextureUnit.NORMAL, normalTexture)
material:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffNormal.xml"))
```

## 地形类型说明

| 类型 | 英文名 | 特征描述 | 预览 |
|------|--------|----------|------|
| 🌿 草地 | grass | 深绿基调、枯黄斑块、零星杂草 | ![草地](DST_Texture_Preview.png) |
| 🪨 沼泽 | swamp | 暗褐带紫灰、气泡、枯枝腐殖质 | |
| 🟫 泥地 | mud | 棕褐色系、裂纹、水洼反光 | |
| ⬜ 碎石地 | rocky | 灰白到浅褐、碎石随机分布、沙砾 | |
| ❄️ 雪地 | snow | 白灰基调、冰晶反光、脚印凹陷 | ![扩展](DST_Texture_Extended_Preview.png) |
| 🏜️ 沙漠 | desert | 暖黄沙土、风蚀纹理、沙丘明暗 | |
| 🌋 火山岩 | volcanic | 深黑到暗红、熔岩裂缝发光、灰烬 | |

## 参数详解

```lua
TextureGenerator.generate(textureType, width, height, seed, styleIntensity)
```

| 参数 | 类型 | 范围 | 说明 |
|------|------|------|------|
| textureType | string | - | 地形类型：grass/swamp/mud/rocky/snow/desert/volcanic |
| width | int | 64~1024 | 贴图宽度（像素），推荐 256 |
| height | int | 64~1024 | 贴图高度（像素），推荐 256 |
| seed | int | - | 随机种子，相同种子生成相同贴图 |
| styleIntensity | float | 0.0~1.0 | 手绘噪点强度，推荐 0.6~0.8 |

## 性能优化

### 贴图缓存

```lua
-- 启用缓存（默认开启）
TextureGenerator.setCacheEnabled(true)

-- 使用缓存生成（如果相同参数已生成过，直接返回缓存）
local pixels = TextureGenerator.generateCached("grass", 256, 256, 12345, 0.7)

-- 禁用缓存
TextureGenerator.setCacheEnabled(false)
```

缓存会自动限制最多保留 32 张贴图，防止内存溢出。

### 分辨率建议

| 使用场景 | 推荐分辨率 | 内存占用 |
|----------|------------|----------|
| 移动端瓦片地图 | 128x128 | ~64KB/张 |
| 通用场景 | 256x256 | ~256KB/张 |
| 高清展示 | 512x512 | ~1MB/张 |

## 风格调优指南

### 调整饥荒风格强度

```lua
-- 低强度（0.3）：更平滑，适合背景远景
local smooth = TextureGenerator.generate("grass", 256, 256, 12345, 0.3)

-- 中强度（0.7）：标准饥荒风格
local standard = TextureGenerator.generate("grass", 256, 256, 12345, 0.7)

-- 高强度（1.0）：重手绘噪点，适合近景
local rough = TextureGenerator.generate("grass", 256, 256, 12345, 1.0)
```

### 自定义颜色（进阶）

直接修改生成器中的 RGB 基值，例如将草地调整为更鲜艳的春季风格：

```lua
-- 在 generateGrass 中修改颜色基值
-- 原值: r = 60 + baseNoise * 35
-- 改为: r = 80 + baseNoise * 40  (增加红色分量)
```

## 完整项目示例

### 基础示例 (main.lua)

```lua
-- 基础地形展示
local TextureGenerator = require("DSTTextureGenerator_Extended")

function Start()
    local resources = TextureGenerator.createTileMapResources(256, 16, 16, os.time())
    -- 创建 TileMap 节点并应用材质...
end
```

### 综合示例 (comprehensive_example.lua)

```lua
-- 整合所有模块的完整项目
-- 支持季节切换、天气变化、植被覆盖、法线贴图
-- 按键控制：1-4切换季节，Q/W/E/R/T切换天气，+/-调整强度

local TextureGenerator = require("DSTTextureGenerator_Extended")
local SeasonShifter = require("SeasonShifter")
local WeatherEffects = require("WeatherEffects")
local VegetationGenerator = require("VegetationGenerator")
local NormalMapGenerator = require("NormalMapGenerator")

-- 完整代码见 comprehensive_example.lua
```

## 注意事项

1. **种子复现**：相同 `seed` + `textureType` + `width` + `height` + `styleIntensity` 组合会生成完全相同的贴图
2. **内存管理**：高分辨率贴图（512x512+）会占用较多内存，建议配合缓存系统使用
3. **无缝平铺**：所有贴图默认支持无缝平铺，可直接用于 TileMap2D
4. **Lua 版本**：代码基于 Lua 5.4，兼容 TapTap 制造 / UrhoX 环境
5. **性能**：植被覆盖和法线贴图生成计算量较大，建议在加载时预生成并缓存

## 预览图

### 基础地形
![基础地形](DST_Texture_Preview.png)

### 扩展地形
![扩展地形](DST_Texture_Extended_Preview.png)

### 季节效果
![季节效果](DST_Season_Preview.png)

### 天气效果
![天气效果](DST_Weather_Preview.png)

### 植被覆盖
![植被覆盖](DST_Vegetation_Preview.png)

## 扩展方向

- [ ] 水体贴图生成（河流、湖泊）
- [ ] 动态地形侵蚀效果
- [ ] 更多植被类型（灌木、树木）
- [ ] 动物足迹系统
- [ ] 地形高度图生成

## 许可证

MIT License - 可自由用于商业和非商业项目。

## 致谢

- 饥荒（Don't Starve）- Klei Entertainment（风格参考）
- TapTap 制造 - 引擎平台
