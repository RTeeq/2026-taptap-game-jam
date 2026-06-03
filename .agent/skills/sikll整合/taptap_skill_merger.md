# Skill: TapTap制造 - Skill合并与游戏系统整合专家

## 1. 技能概述

本Skill专为TapTap制造AI智能体设计，核心能力是将多个独立Skill的功能合并、整合并转化为可执行的游戏机制与系统。通过解析Skill内容、提取功能模块、设计游戏化实现方案，最终输出可直接部署到TapTap制造引擎的完整代码与配置。

**适用场景**：
- 将多个独立Skill（如战斗系统Skill、UI设计Skill、音效管理Skill）合并为统一的游戏系统
- 将Skill中的设计理念转化为具体的游戏机制、数值系统、交互逻辑
- 参考已有Skill的最佳实践，在新项目中复用并优化功能模块
- 跨Skill数据流转与状态同步

---

## 2. 核心能力矩阵

| 能力层级 | 功能描述 | 输出物 |
|---------|---------|--------|
| **Skill解析** | 读取并理解Skill文件的结构、功能模块、API调用 | 功能模块清单、依赖关系图 |
| **功能合并** | 将多个Skill的同类功能去重合并，异类功能串联整合 | 合并后的统一接口与事件流 |
| **游戏化转换** | 将抽象Skill功能转化为具体的游戏机制（如将"存档Skill"转化为"检查点+自动存档系统"） | 机制设计文档 + 实现代码 |
| **系统架构** | 设计Skill间的数据流、状态机、事件总线 | 系统架构图 + 核心代码框架 |
| **代码生成** | 输出可直接在TapTap制造引擎运行的Lua/TS代码 | 完整可运行代码文件 |

---

## 3. 工作流程

### 阶段一：Skill解析与 inventory（清单化）

当用户提供多个Skill文件时，按以下步骤处理：

```
1. 读取每个Skill的元数据（名称、版本、作者、依赖）
2. 提取所有功能模块（函数、类、配置项）
3. 识别每个模块的输入/输出接口
4. 标记模块间的依赖关系
5. 生成Skill Inventory清单
```

**Inventory输出格式**：
```markdown
## Skill Inventory

### Skill A: [战斗系统Skill]
- 模块1: initCombat() → 初始化战斗场景
- 模块2: spawnEnemy(type, position) → 生成敌人
- 模块3: calculateDamage(attacker, defender) → 伤害计算
- 依赖: [物理引擎Skill], [音效管理Skill]

### Skill B: [UI设计Skill]
- 模块1: createHUD() → 创建HUD界面
- 模块2: showDamageNumber(value, position) → 显示伤害数字
- 模块3: updateHealthBar(entity) → 更新血条
- 依赖: [战斗系统Skill]

### 冲突检测
- Skill A.calculateDamage() 与 Skill B.showDamageNumber() 存在数据耦合
- 建议: 通过事件总线解耦
```

### 阶段二：功能合并策略

根据模块特性选择合并策略：

| 策略类型 | 适用场景 | 操作方式 |
|---------|---------|---------|
| **覆盖合并** | 同名同功能模块，取最新版本 | 保留高版本，废弃低版本 |
| **串联合并** | 功能互补的模块 | 设计数据流，A的输出作为B的输入 |
| **并行合并** | 独立功能模块 | 保留全部，统一入口分发 |
| **融合合并** | 相似但有差异的模块 | 提取共性抽象层，差异部分保留分支 |

**合并决策树**：
```
模块A vs 模块B
├── 名称相同？
│   ├── 功能相同？ → 覆盖合并（取版本高者）
│   └── 功能不同？ → 融合合并（抽象共性 + 保留差异）
└── 名称不同？
    ├── 功能互补？ → 串联合并
    └── 功能独立？ → 并行合并
```

### 阶段三：游戏机制设计

将合并后的功能模块转化为具体的游戏系统：

**转换原则**：
1. **机制映射**：每个Skill功能对应一个游戏机制（如"存档"→"检查点机制"）
2. **数值化**：将抽象概念转化为可量化的游戏数值（如"难度"→"敌人攻击力系数"）
3. **交互化**：将后台逻辑转化为玩家可感知的交互（如"数据同步"→"进度条动画"）
4. **反馈闭环**：确保每个机制都有输入→处理→反馈的完整闭环

**机制设计模板**：
```markdown
## 机制设计: [机制名称]

### 来源Skill
- [Skill名称].[模块名]

### 游戏化描述
[用玩家能理解的语言描述这个机制]

### 核心规则
1. [规则1]
2. [规则2]

### 数值参数
| 参数名 | 默认值 | 范围 | 说明 |
|-------|-------|------|------|
| param1 | 100 | 50-200 | [说明] |

### 状态机
```
[State A] --event--> [State B]
```

### 代码实现
```lua
-- [代码位置]
```
```

### 阶段四：系统架构与代码生成

**架构设计原则**：
- **模块化**：每个系统独立为Module，通过EventBus通信
- **数据驱动**：配置与逻辑分离，支持运行时调整
- **可扩展**：预留接口，方便后续新增Skill功能

**核心架构**：
```
┌─────────────────────────────────────────┐
│           EventBus (全局事件总线)         │
├─────────────┬─────────────┬─────────────┤
│  战斗系统    │   UI系统     │   存档系统   │
│  CombatSys   │   UISys      │   SaveSys    │
├─────────────┴─────────────┴─────────────┤
│         SkillAdapter (Skill适配层)         │
├─────────────────────────────────────────┤
│      TapTap制造引擎 (Spark Engine)        │
└─────────────────────────────────────────┘
```

---

## 4. 关键实现规范

### 4.1 Skill解析规范

读取Skill文件时，必须提取以下信息：

```lua
-- Skill解析器伪代码
function parseSkill(skillContent)
    local skill = {
        metadata = {
            name = extractBetween(skillContent, "## Skill:", "\n"),
            version = extractVersion(skillContent),
            author = extractAuthor(skillContent),
            dependencies = extractDependencies(skillContent)
        },
        modules = {},
        apis = {},
        configs = {}
    }

    -- 提取所有函数/模块定义
    for match in skillContent:gmatch("### .-") do
        table.insert(skill.modules, {
            name = extractName(match),
            description = extractDescription(match),
            inputs = extractInputs(match),
            outputs = extractOutputs(match),
            code = extractCodeBlock(match)
        })
    end

    return skill
end
```

### 4.2 合并冲突解决规范

当检测到冲突时，按优先级自动解决：

```lua
-- 冲突解决优先级
CONFLICT_RESOLUTION_PRIORITY = {
    [1] = "版本号高者优先",
    [2] = "官方Skill优先于社区Skill",
    [3] = "最近修改者优先",
    [4] = "功能完整度高者优先",
    [5] = "标记为@override的Skill优先"
}

function resolveConflict(moduleA, moduleB)
    -- 检查是否有@override标记
    if moduleA.metadata.hasOverride then return moduleA end
    if moduleB.metadata.hasOverride then return moduleB end

    -- 比较版本号
    if moduleA.metadata.version > moduleB.metadata.version then
        return moduleA
    elseif moduleB.metadata.version > moduleA.metadata.version then
        return moduleB
    end

    -- 默认：保留两者，通过命名空间隔离
    return mergeWithNamespace(moduleA, moduleB)
end
```

### 4.3 游戏机制代码生成规范

生成的代码必须符合TapTap制造引擎规范：

```typescript
// 示例：将"战斗Skill"转化为"回合制战斗系统"

// 1. 定义系统接口
interface ICombatSystem {
    initBattle(players: Entity[], enemies: Entity[]): void;
    startTurn(entity: Entity): void;
    executeSkill(caster: Entity, skillId: string, targets: Entity[]): CombatResult;
    endBattle(): BattleResult;
}

// 2. 实现核心战斗循环
class TurnBasedCombatSystem implements ICombatSystem {
    private turnQueue: Entity[] = [];
    private currentTurn: number = 0;
    private eventBus: EventBus;

    initBattle(players: Entity[], enemies: Entity[]): void {
        // 合并Skill中的初始化逻辑
        this.turnQueue = [...players, ...enemies].sort((a, b) => 
            b.getSpeed() - a.getSpeed()
        );
        this.eventBus.emit("BATTLE_START", { players, enemies });
    }

    startTurn(entity: Entity): void {
        // 触发回合开始事件，供UI Skill监听
        this.eventBus.emit("TURN_START", { entity, turnNumber: this.currentTurn });

        // 自动触发AI或等待玩家输入
        if (entity.isAI) {
            this.executeAI(entity);
        }
    }

    executeSkill(caster: Entity, skillId: string, targets: Entity[]): CombatResult {
        // 调用Skill中的伤害计算模块
        const skillData = SkillAdapter.getSkillData(skillId);
        const damage = DamageCalculator.calculate(caster, targets[0], skillData);

        // 应用伤害并触发视觉反馈
        targets[0].takeDamage(damage);
        this.eventBus.emit("DAMAGE_DEALT", { caster, target: targets[0], damage, skillId });

        return { success: true, damage, effects: skillData.effects };
    }
}
```

### 4.4 事件总线规范

所有Skill模块间通信必须通过EventBus：

```lua
-- EventBus实现（TapTap制造引擎兼容）
local EventBus = {
    listeners = {},

    -- 订阅事件
    on = function(self, eventName, callback, priority)
        if not self.listeners[eventName] then
            self.listeners[eventName] = {}
        end
        table.insert(self.listeners[eventName], {
            callback = callback,
            priority = priority or 0
        })
        -- 按优先级排序
        table.sort(self.listeners[eventName], function(a, b)
            return a.priority > b.priority
        end)
    end,

    -- 发布事件
    emit = function(self, eventName, data)
        if self.listeners[eventName] then
            for _, listener in ipairs(self.listeners[eventName]) do
                listener.callback(data)
            end
        end
    end,

    -- 取消订阅
    off = function(self, eventName, callback)
        if self.listeners[eventName] then
            for i, listener in ipairs(self.listeners[eventName]) do
                if listener.callback == callback then
                    table.remove(self.listeners[eventName], i)
                    break
                end
            end
        end
    end
}

-- 标准事件列表（所有Skill应遵守）
STANDARD_EVENTS = {
    "GAME_INIT",           -- 游戏初始化
    "SCENE_LOAD",          -- 场景加载
    "ENTITY_SPAWN",        -- 实体生成
    "ENTITY_DESTROY",      -- 实体销毁
    "INPUT_ACTION",        -- 玩家输入
    "COMBAT_START",        -- 战斗开始
    "COMBAT_END",          -- 战斗结束
    "TURN_START",          -- 回合开始
    "TURN_END",            -- 回合结束
    "DAMAGE_DEALT",        -- 造成伤害
    "HEAL_RECEIVED",       -- 受到治疗
    "ITEM_USED",           -- 使用物品
    "QUEST_UPDATE",        -- 任务更新
    "SAVE_GAME",           -- 存档
    "LOAD_GAME",           -- 读档
    "UI_OPEN",             -- 打开UI
    "UI_CLOSE",            -- 关闭UI
    "AUDIO_PLAY",          -- 播放音效
    "AUDIO_STOP",          -- 停止音效
}
```

---

## 5. 典型应用场景

### 场景1：合并"战斗Skill"+"UI Skill"→完整战斗系统

**输入**：
- 战斗Skill：提供伤害计算、技能释放、状态效果
- UI Skill：提供血条显示、伤害数字、技能按钮

**处理流程**：
```
1. Inventory提取
   - 战斗Skill: 3个模块（CombatCore, SkillManager, BuffSystem）
   - UI Skill: 3个模块（HUD, DamageText, SkillBar）

2. 依赖分析
   - UI Skill依赖战斗Skill的数据输出
   - 冲突：无

3. 串联合并
   - CombatCore.damageDealt → EventBus.emit("DAMAGE_DEALT") → HUD.updateHealthBar()
   - SkillManager.skillUsed → EventBus.emit("SKILL_USED") → SkillBar.cooldownAnimation()

4. 游戏机制设计
   - 实时战斗系统（非回合制）
   - 连击机制：3秒内连续命中触发伤害加成
   - 技能冷却：可视化CD进度条

5. 代码生成
   - 输出: combat_system.lua + combat_ui.lua + event_config.json
```

### 场景2：合并"存档Skill"+"成就Skill"→进度系统

**输入**：
- 存档Skill：提供本地/云端存档读写
- 成就Skill：提供成就解锁、进度追踪

**处理流程**：
```
1. 功能互补识别
   - 存档Skill缺少"进度统计"功能
   - 成就Skill缺少"数据持久化"功能

2. 融合合并
   - 抽象共性：数据存储接口（SaveDataInterface）
   - 保留差异：存档Skill专注完整状态保存，成就Skill专注增量进度

3. 游戏机制设计
   - 检查点机制：关卡内自动存档 + 手动存档点
   - 成就系统：与存档绑定，防止SL刷成就
   - 云端同步：多设备进度同步

4. 代码生成
   - 输出: progress_system.lua + achievement_data.json
```

### 场景3：参考Skill优化现有游戏

**输入**：
- 现有游戏代码
- 参考Skill（如"优化过的战斗系统Skill"）

**处理流程**：
```
1. 差异分析
   - 对比现有代码与Skill的功能差异
   - 识别Skill中的优化点（如更高效的算法、更好的设计模式）

2. 选择性合并
   - 保留现有游戏的核心逻辑
   - 引入Skill中的优化模块（如新的伤害公式、更流畅的动画触发）

3. 兼容性处理
   - 通过Adapter模式适配接口差异
   - 确保现有存档数据兼容

4. 输出增量更新代码
```

---

## 6. Skill内容提取与复用规范

### 6.1 提取指令模板

当用户要求"参考某Skill的内容"时，按以下模板提取：

```markdown
## 内容提取报告: [Skill名称]

### 核心设计理念
[提取Skill中的设计哲学、最佳实践]

### 可复用代码模块
| 模块名 | 功能 | 复用建议 |
|-------|------|---------|
| [模块1] | [描述] | [直接复用/修改后复用/仅参考思路] |

### 关键配置参数
| 参数名 | 值 | 说明 |
|-------|-----|------|
| [参数1] | [值] | [说明] |

### 注意事项
- [依赖项]
- [已知问题]
- [版本兼容性]
```

### 6.2 复用决策矩阵

| Skill内容类型 | 复用策略 | 示例 |
|-------------|---------|------|
| 算法/公式 | 直接复用，适配变量名 | 伤害计算公式 |
| 设计模式 | 参考思路，重新实现 | 状态机设计 |
| UI布局 | 提取结构，替换素材 | HUD布局方案 |
| 配置数据 | 直接复用，验证范围 | 角色属性表 |
| 完整系统 | 整体复用，增量修改 | 背包系统 |

---

## 7. 输出格式规范

### 7.1 合并报告格式

```markdown
# Skill合并报告

## 合并概览
- 输入Skill数量: [N]
- 合并后模块数量: [M]
- 冲突数量: [K]（已自动解决）
- 生成文件数量: [P]

## 合并详情
### 模块: [模块名]
- 来源: [Skill A] + [Skill B]
- 合并策略: [覆盖/串联/并行/融合]
- 冲突解决: [描述]
- 输出文件: [文件名]

## 游戏机制清单
| 机制名 | 来源Skill | 游戏化描述 | 关键参数 |
|-------|---------|-----------|---------|
| [机制1] | [Skill] | [描述] | [参数] |

## 架构图
[Mermaid图表或文字描述]

## 生成文件列表
- [文件1]: [说明]
- [文件2]: [说明]
```

### 7.2 代码文件格式

每个生成的代码文件必须包含：

```lua
--[[
    文件: [文件名]
    生成时间: [时间戳]
    来源Skill: [Skill列表]
    功能: [简要描述]
    依赖: [依赖模块]

    @auto-generated by TapTap制造 Skill合并器
--]]

local ModuleName = {}

-- 配置区（可外部修改）
ModuleName.CONFIG = {
    -- [配置项]
}

-- 初始化
function ModuleName.init(config)
    -- [初始化逻辑]
end

-- 核心功能
function ModuleName.coreFunction(params)
    -- [实现逻辑]
end

-- 事件处理
function ModuleName.onEvent(eventData)
    -- [事件响应]
end

return ModuleName
```

---

## 8. 使用示例

### 示例1：基础合并指令

**用户输入**：
```
合并以下Skill：
1. 战斗系统Skill（提供回合制战斗逻辑）
2. UI设计Skill（提供战斗界面）
3. 音效管理Skill（提供战斗音效）

目标：生成一个完整的回合制RPG战斗系统
```

**Skill处理流程**：

1. **Inventory提取**
   - 识别3个Skill共9个模块，无命名冲突
   - 依赖关系：UI依赖战斗，音效依赖两者

2. **合并策略**
   - 战斗Skill：保留全部（核心系统）
   - UI Skill：串联合并（依赖战斗数据）
   - 音效Skill：并行合并（独立触发）

3. **机制设计**
   - 回合制战斗：速度决定行动顺序
   - 技能系统：消耗MP，有冷却回合
   - 连携攻击：特定角色组合触发额外伤害
   - UI反馈：伤害数字浮动、血条动画、技能特效
   - 音效反馈：攻击音效、受击音效、技能音效、BGM切换

4. **代码生成**
   - 生成5个代码文件 + 1个配置文件

5. **输出报告**
   - 完整合并报告 + 可直接运行的代码

### 示例2：参考复用指令

**用户输入**：
```
参考"星际歌姬"的内置动画Skill，在我的新游戏中实现角色换装系统
```

**Skill处理流程**：

1. **内容提取**
   - 提取核心原理：Delaunay三角化 + 仿射变换
   - 提取图层系统：多层独立网格 + 关键帧
   - 提取换装流程：替换图片 → 复用变形参数

2. **适配分析**
   - 原Skill针对2D角色动画，新游戏需求：3D角色换装
   - 保留：图层概念、参数复用思路
   - 修改：网格变形改为骨骼蒙皮，2D图层改为3D材质层

3. **机制设计**
   - 3D角色换装系统：材质层替换 + 骨骼动画复用
   - AI微调：相似服装共享骨骼权重
   - 实时预览：编辑器内直接查看换装效果

4. **代码生成**
   - 输出适配后的3D换装系统代码

---



### 场景4：通过Skill从零开发游戏

**用户输入**：
```
我想开发一个[游戏类型]游戏，请帮我：
1. 设计核心Skill清单
2. 生成基础Skill框架
3. 通过Skill迭代完善游戏
```

**Skill处理流程**：

1. **需求分析**
   - 确定游戏类型（RPG/ACT/SLG/Roguelike等）
   - 识别核心系统需求（战斗、UI、存档、音效等）
   - 评估Skill拆分粒度

2. **Skill清单设计**
   - 核心Skill：游戏机制核心逻辑
   - 辅助Skill：UI、音效、特效等表现层
   - 工具Skill：编辑器扩展、调试工具
   - 数据Skill：配置表、资源管理

3. **基础框架生成**
   - 生成主入口Skill（MainGameSkill）
   - 生成事件总线Skill（EventBusSkill）
   - 生成配置管理Skill（ConfigSkill）
   - 生成各子系统Skill骨架

4. **迭代开发**
   - 按优先级逐个实现Skill功能
   - 通过本Skill合并器整合各子Skill
   - 持续测试与优化

---

## 11. 通过Skill开发游戏的完整流程

### 11.1 Skill驱动的游戏开发方法论

**核心理念**：将游戏开发拆解为可独立开发、测试、复用的Skill模块，通过本合并器整合为完整游戏。

```
传统开发: 需求 → 设计 → 编码 → 测试 → 发布
Skill开发: 需求 → Skill清单 → 并行Skill开发 → Skill合并 → 集成测试 → 发布
```

### 11.2 游戏Skill分层架构

```
┌─────────────────────────────────────────┐
│  Layer 4: 表现层 Skill                  │
│  - UI Skill（界面、HUD、菜单）           │
│  - VFX Skill（特效、动画）               │
│  - Audio Skill（音效、音乐）             │
│  - Localization Skill（多语言）          │
├─────────────────────────────────────────┤
│  Layer 3: 玩法层 Skill                  │
│  - Combat Skill（战斗系统）              │
│  - Quest Skill（任务系统）               │
│  - Inventory Skill（背包系统）           │
│  - Dialog Skill（对话系统）              │
├─────────────────────────────────────────┤
│  Layer 2: 系统层 Skill                  │
│  - SaveLoad Skill（存档系统）            │
│  - EventBus Skill（事件总线）            │
│  - StateMachine Skill（状态机）          │
│  - Resource Skill（资源管理）            │
├─────────────────────────────────────────┤
│  Layer 1: 引擎层 Skill                  │
│  - Input Skill（输入处理）               │
│  - Physics Skill（物理系统）             │
│  - Render Skill（渲染管线）              │
│  - Network Skill（网络同步）             │
├─────────────────────────────────────────┤
│  Layer 0: 基础层 Skill                  │
│  - Math Skill（数学工具）                │
│  - DataStruct Skill（数据结构）          │
│  - Utils Skill（通用工具）               │
│  - Debug Skill（调试工具）               │
└─────────────────────────────────────────┘
```

### 11.3 Skill开发工作流

#### 阶段一：需求拆解为Skill清单

**输入**：游戏设计文档（GDD）
**输出**：Skill开发清单

```markdown
## Skill开发清单: [游戏名称]

### 核心玩法Skill（必须）
| 优先级 | Skill名称 | 功能描述 | 预估工时 | 依赖 |
|-------|----------|---------|---------|------|
| P0 | CombatSkill | 实时战斗系统 | 3天 | InputSkill, StateMachineSkill |
| P0 | PlayerSkill | 角色控制 | 2天 | InputSkill, PhysicsSkill |
| P0 | EnemySkill | AI敌人行为 | 2天 | CombatSkill, StateMachineSkill |

### 系统支撑Skill（必须）
| 优先级 | Skill名称 | 功能描述 | 预估工时 | 依赖 |
|-------|----------|---------|---------|------|
| P0 | EventBusSkill | 全局事件总线 | 1天 | 无 |
| P0 | SaveLoadSkill | 存档读档 | 1天 | EventBusSkill |
| P1 | QuestSkill | 任务追踪 | 2天 | EventBusSkill, SaveLoadSkill |

### 表现层Skill（可延后）
| 优先级 | Skill名称 | 功能描述 | 预估工时 | 依赖 |
|-------|----------|---------|---------|------|
| P1 | UISkill | 游戏界面 | 2天 | EventBusSkill |
| P2 | VFXSkill | 视觉特效 | 3天 | CombatSkill |
| P2 | AudioSkill | 音效管理 | 1天 | EventBusSkill |
```

#### 阶段二：基础Skill先行开发

**必须先完成的基础Skill**（其他所有Skill依赖它们）：

```lua
-- EventBusSkill.lua（所有系统的通信基础）
--[[
    Skill: EventBusSkill
    层级: Layer 2（系统层）
    依赖: 无
    被依赖: 所有其他Skill
--]]

local EventBusSkill = {
    VERSION = "1.0.0",
    listeners = {},
    eventQueue = {},
    isProcessing = false,
}

-- 订阅事件（带优先级，数字越大优先级越高）
function EventBusSkill.on(eventName, callback, priority)
    priority = priority or 0
    if not EventBusSkill.listeners[eventName] then
        EventBusSkill.listeners[eventName] = {}
    end
    table.insert(EventBusSkill.listeners[eventName], {
        callback = callback,
        priority = priority,
        id = #EventBusSkill.listeners[eventName] + 1
    })
    -- 按优先级排序
    table.sort(EventBusSkill.listeners[eventName], function(a, b)
        return a.priority > b.priority
    end)
end

-- 发布事件（支持异步队列）
function EventBusSkill.emit(eventName, data, immediate)
    if immediate then
        EventBusSkill._processEvent(eventName, data)
    else
        table.insert(EventBusSkill.eventQueue, {
            eventName = eventName,
            data = data,
            timestamp = os.time()
        })
    end
end

-- 处理事件队列
function EventBusSkill.processQueue()
    if EventBusSkill.isProcessing then return end
    EventBusSkill.isProcessing = true

    while #EventBusSkill.eventQueue > 0 do
        local event = table.remove(EventBusSkill.eventQueue, 1)
        EventBusSkill._processEvent(event.eventName, event.data)
    end

    EventBusSkill.isProcessing = false
end

-- 内部事件处理
function EventBusSkill._processEvent(eventName, data)
    local listeners = EventBusSkill.listeners[eventName]
    if not listeners then return end

    for _, listener in ipairs(listeners) do
        local success, result = pcall(listener.callback, data)
        if not success then
            EventBusSkill.emit("EVENT_ERROR", {
                eventName = eventName,
                error = result,
                listenerId = listener.id
            })
        end
    end
end

-- 取消订阅
function EventBusSkill.off(eventName, callback)
    local listeners = EventBusSkill.listeners[eventName]
    if not listeners then return end
    for i, listener in ipairs(listeners) do
        if listener.callback == callback then
            table.remove(listeners, i)
            break
        end
    end
end

-- 标准事件定义（所有Skill应使用这些事件名）
EventBusSkill.STANDARD_EVENTS = {
    -- 生命周期
    GAME_INIT = "GAME_INIT",
    GAME_START = "GAME_START",
    GAME_PAUSE = "GAME_PAUSE",
    GAME_RESUME = "GAME_RESUME",
    GAME_QUIT = "GAME_QUIT",

    -- 场景
    SCENE_LOAD_START = "SCENE_LOAD_START",
    SCENE_LOAD_COMPLETE = "SCENE_LOAD_COMPLETE",
    SCENE_UNLOAD = "SCENE_UNLOAD",

    -- 实体
    ENTITY_SPAWN = "ENTITY_SPAWN",
    ENTITY_DESTROY = "ENTITY_DESTROY",
    ENTITY_DAMAGED = "ENTITY_DAMAGED",
    ENTITY_HEALED = "ENTITY_HEALED",
    ENTITY_DIED = "ENTITY_DIED",

    -- 输入
    INPUT_ACTION = "INPUT_ACTION",
    INPUT_MOVE = "INPUT_MOVE",
    INPUT_ATTACK = "INPUT_ATTACK",
    INPUT_INTERACT = "INPUT_INTERACT",

    -- 战斗
    COMBAT_START = "COMBAT_START",
    COMBAT_END = "COMBAT_END",
    TURN_START = "TURN_START",
    TURN_END = "TURN_END",
    SKILL_CAST = "SKILL_CAST",
    DAMAGE_DEALT = "DAMAGE_DEALT",

    -- UI
    UI_OPEN = "UI_OPEN",
    UI_CLOSE = "UI_CLOSE",
    UI_UPDATE = "UI_UPDATE",

    -- 存档
    SAVE_GAME = "SAVE_GAME",
    LOAD_GAME = "LOAD_GAME",
    SAVE_COMPLETE = "SAVE_COMPLETE",
    LOAD_COMPLETE = "LOAD_COMPLETE",

    -- 音频
    AUDIO_PLAY = "AUDIO_PLAY",
    AUDIO_STOP = "AUDIO_STOP",
    AUDIO_VOLUME_CHANGE = "AUDIO_VOLUME_CHANGE",

    -- 错误
    EVENT_ERROR = "EVENT_ERROR",
    SYSTEM_ERROR = "SYSTEM_ERROR",
}

return EventBusSkill
```

```lua
-- ConfigSkill.lua（配置管理基础）
--[[
    Skill: ConfigSkill
    层级: Layer 2（系统层）
    依赖: EventBusSkill
    被依赖: 所有需要配置的Skill
--]]

local ConfigSkill = {
    VERSION = "1.0.0",
    configs = {},
    hotReload = false,
}

-- 加载配置表
function ConfigSkill.load(configName, defaultConfig)
    -- 从TapTap制造资源系统加载
    local config = Resources.Load(configName .. "_config")
    if config then
        ConfigSkill.configs[configName] = config
        EventBusSkill.emit("CONFIG_LOADED", { name = configName, config = config })
        return config
    else
        ConfigSkill.configs[configName] = defaultConfig or {}
        return ConfigSkill.configs[configName]
    end
end

-- 获取配置值（支持嵌套路径）
function ConfigSkill.get(configName, path, defaultValue)
    local config = ConfigSkill.configs[configName]
    if not config then return defaultValue end

    if not path then return config end

    local keys = {}
    for key in string.gmatch(path, "[^.]+") do
        table.insert(keys, key)
    end

    local current = config
    for _, key in ipairs(keys) do
        current = current[key]
        if current == nil then return defaultValue end
    end

    return current
end

-- 设置配置值（运行时修改）
function ConfigSkill.set(configName, path, value)
    local config = ConfigSkill.configs[configName]
    if not config then
        config = {}
        ConfigSkill.configs[configName] = config
    end

    local keys = {}
    for key in string.gmatch(path, "[^.]+") do
        table.insert(keys, key)
    end

    local current = config
    for i = 1, #keys - 1 do
        if not current[keys[i]] then
            current[keys[i]] = {}
        end
        current = current[keys[i]]
    end

    current[keys[#keys]] = value

    EventBusSkill.emit("CONFIG_CHANGED", {
        name = configName,
        path = path,
        value = value
    })
end

-- 批量加载（用于游戏启动时）
function ConfigSkill.batchLoad(configList)
    for _, configName in ipairs(configList) do
        ConfigSkill.load(configName)
    end
    EventBusSkill.emit("CONFIG_ALL_LOADED", { count = #configList })
end

return ConfigSkill
```

#### 阶段三：并行开发子系统Skill

**开发规范**：

```markdown
## Skill开发规范

### 文件结构
每个Skill必须包含以下部分：

```lua
--[[
    Skill: [Skill名称]
    版本: [版本号]
    作者: [作者]
    层级: [Layer层级]
    依赖: [依赖的Skill列表]
    被依赖: [被哪些Skill依赖]
    功能: [简要描述]

    变更日志:
    v1.0.0 - 初始版本
--]]

local SkillName = {
    VERSION = "1.0.0",
    -- 配置区
    CONFIG = {
        -- 所有可外部调整的参数
    },
    -- 状态区
    state = {},
    -- 接口区
}

-- 初始化（必须实现）
function SkillName.init(config)
    -- 合并外部配置
    if config then
        for k, v in pairs(config) do
            SkillName.CONFIG[k] = v
        end
    end
    -- 初始化状态
    SkillName.state = {}
    -- 注册事件监听
    EventBusSkill.on("GAME_INIT", SkillName._onGameInit)
end

-- 核心功能函数
function SkillName.coreFunction(params)
    -- 实现逻辑
    -- 发布事件通知其他Skill
    EventBusSkill.emit("EVENT_NAME", { data = data })
end

-- 事件处理函数（私有）
function SkillName._onEvent(data)
    -- 响应事件
end

-- 销毁（必须实现，用于资源释放）
function SkillName.destroy()
    -- 取消事件监听
    EventBusSkill.off("EVENT_NAME", SkillName._onEvent)
    -- 清理状态
    SkillName.state = {}
end

return SkillName
```

### 接口契约
每个Skill必须明确定义：
1. **输入接口**：哪些函数/事件可以被外部调用
2. **输出接口**：会触发哪些事件/回调
3. **数据格式**：输入输出数据的结构定义
4. **错误处理**：异常情况的返回方式

### 测试要求
每个Skill必须附带单元测试：
```lua
-- SkillName_test.lua
local SkillName = require("SkillName")

function test_init()
    SkillName.init({ param = 100 })
    assert(SkillName.CONFIG.param == 100, "配置合并失败")
    print("✓ test_init passed")
end

function test_coreFunction()
    local result = SkillName.coreFunction({ input = "test" })
    assert(result.success == true, "核心功能失败")
    print("✓ test_coreFunction passed")
end

-- 运行所有测试
function runAllTests()
    test_init()
    test_coreFunction()
    print("所有测试通过!")
end
```

### 版本管理
- Skill版本号遵循语义化版本（SemVer）：MAJOR.MINOR.PATCH
- MAJOR：不兼容的API变更
- MINOR：向下兼容的功能新增
- PATCH：向下兼容的问题修复
```

#### 阶段四：Skill合并与整合

使用本Skill的合并能力，将所有子系统Skill整合为完整游戏：

```lua
-- MainGameSkill.lua（游戏主入口，合并所有子Skill）
--[[
    Skill: MainGameSkill
    层级: Layer 4+（整合层）
    依赖: 所有子系统Skill
    功能: 游戏主入口，负责初始化所有子系统并协调运行
--]]

local MainGameSkill = {
    VERSION = "1.0.0",
    subSkills = {},
    isRunning = false,
}

-- Skill清单（按初始化顺序）
MainGameSkill.SKILL_REGISTRY = {
    -- Layer 0: 基础层
    { name = "UtilsSkill", path = "Skills/UtilsSkill", layer = 0 },
    { name = "MathSkill", path = "Skills/MathSkill", layer = 0 },
    { name = "DebugSkill", path = "Skills/DebugSkill", layer = 0 },

    -- Layer 1: 引擎层
    { name = "InputSkill", path = "Skills/InputSkill", layer = 1 },
    { name = "PhysicsSkill", path = "Skills/PhysicsSkill", layer = 1 },
    { name = "RenderSkill", path = "Skills/RenderSkill", layer = 1 },

    -- Layer 2: 系统层
    { name = "EventBusSkill", path = "Skills/EventBusSkill", layer = 2 },
    { name = "ConfigSkill", path = "Skills/ConfigSkill", layer = 2 },
    { name = "SaveLoadSkill", path = "Skills/SaveLoadSkill", layer = 2 },
    { name = "StateMachineSkill", path = "Skills/StateMachineSkill", layer = 2 },
    { name = "ResourceSkill", path = "Skills/ResourceSkill", layer = 2 },

    -- Layer 3: 玩法层
    { name = "PlayerSkill", path = "Skills/PlayerSkill", layer = 3 },
    { name = "CombatSkill", path = "Skills/CombatSkill", layer = 3 },
    { name = "EnemySkill", path = "Skills/EnemySkill", layer = 3 },
    { name = "QuestSkill", path = "Skills/QuestSkill", layer = 3 },
    { name = "InventorySkill", path = "Skills/InventorySkill", layer = 3 },

    -- Layer 4: 表现层
    { name = "UISkill", path = "Skills/UISkill", layer = 4 },
    { name = "VFXSkill", path = "Skills/VFXSkill", layer = 4 },
    { name = "AudioSkill", path = "Skills/AudioSkill", layer = 4 },
}

-- 游戏初始化
function MainGameSkill.init()
    print("[MainGameSkill] 开始初始化游戏...")

    -- 按层级顺序加载所有Skill
    for layer = 0, 4 do
        print("[MainGameSkill] 初始化 Layer " .. layer)
        for _, skillInfo in ipairs(MainGameSkill.SKILL_REGISTRY) do
            if skillInfo.layer == layer then
                local skill = require(skillInfo.path)
                MainGameSkill.subSkills[skillInfo.name] = skill

                -- 调用Skill初始化
                if skill.init then
                    skill.init(ConfigSkill.get("game", skillInfo.name, {}))
                end

                print("  ✓ " .. skillInfo.name .. " 初始化完成")
            end
        end
    end

    -- 注册游戏生命周期事件
    EventBusSkill.on("GAME_START", MainGameSkill._onGameStart)
    EventBusSkill.on("GAME_PAUSE", MainGameSkill._onGamePause)
    EventBusSkill.on("GAME_RESUME", MainGameSkill._onGameResume)
    EventBusSkill.on("GAME_QUIT", MainGameSkill._onGameQuit)

    -- 发布游戏初始化完成事件
    EventBusSkill.emit("GAME_INIT", { timestamp = os.time() })

    print("[MainGameSkill] 游戏初始化完成!")
end

-- 游戏主循环
function MainGameSkill.update(dt)
    if not MainGameSkill.isRunning then return end

    -- 处理事件队列
    EventBusSkill.processQueue()

    -- 更新各子系统
    for name, skill in pairs(MainGameSkill.subSkills) do
        if skill.update then
            skill.update(dt)
        end
    end
end

-- 游戏开始
function MainGameSkill._onGameStart(data)
    MainGameSkill.isRunning = true
    print("[MainGameSkill] 游戏开始运行")
end

-- 游戏暂停
function MainGameSkill._onGamePause(data)
    MainGameSkill.isRunning = false
    print("[MainGameSkill] 游戏暂停")
end

-- 游戏恢复
function MainGameSkill._onGameResume(data)
    MainGameSkill.isRunning = true
    print("[MainGameSkill] 游戏恢复")
end

-- 游戏退出
function MainGameSkill._onGameQuit(data)
    MainGameSkill.isRunning = false

    -- 按反向层级顺序销毁Skill
    for layer = 4, 0, -1 do
        for _, skillInfo in ipairs(MainGameSkill.SKILL_REGISTRY) do
            if skillInfo.layer == layer then
                local skill = MainGameSkill.subSkills[skillInfo.name]
                if skill and skill.destroy then
                    skill.destroy()
                end
            end
        end
    end

    print("[MainGameSkill] 游戏已退出")
end

-- 获取指定Skill
function MainGameSkill.getSkill(name)
    return MainGameSkill.subSkills[name]
end

-- 热重载Skill（开发调试用）
function MainGameSkill.hotReload(skillName)
    print("[MainGameSkill] 热重载: " .. skillName)
    local skill = MainGameSkill.subSkills[skillName]
    if skill and skill.destroy then
        skill.destroy()
    end

    -- 重新加载
    package.loaded[skillName] = nil
    local newSkill = require(MainGameSkill._getPath(skillName))
    MainGameSkill.subSkills[skillName] = newSkill

    if newSkill.init then
        newSkill.init(ConfigSkill.get("game", skillName, {}))
    end

    EventBusSkill.emit("SKILL_HOT_RELOADED", { name = skillName })
end

function MainGameSkill._getPath(name)
    for _, info in ipairs(MainGameSkill.SKILL_REGISTRY) do
        if info.name == name then
            return info.path
        end
    end
    return nil
end

return MainGameSkill
```

#### 阶段五：迭代与优化

**迭代开发流程**：

```
迭代周期:
├── 规划（1天）
│   └── 确定本轮要完善/新增的Skill
├── 开发（2-3天）
│   └── 并行开发各Skill
├── 合并（0.5天）
│   └── 使用本Skill合并器整合
├── 测试（1天）
│   └── 单元测试 + 集成测试
├── 调优（1天）
│   └── 性能优化 + Bug修复
└── 发布（0.5天）
    └── 版本更新 + 文档更新
```

**Skill版本迭代策略**：

| 迭代类型 | 操作方式 | 示例 |
|---------|---------|------|
| **功能增强** | 在现有Skill中新增模块 | CombatSkill新增"连击系统"模块 |
| **Bug修复** | 修改现有Skill的特定函数 | 修复DamageCalculator的暴击计算 |
| **性能优化** | 替换Skill中的低效算法 | 将O(n²)碰撞检测改为空间哈希 |
| **架构重构** | 拆分过大的Skill为多个 | 将UISkill拆分为HUDSkill + MenuSkill |
| **新增系统** | 开发全新Skill并合并 | 新增"锻造系统Skill" |

### 11.4 Skill模板库

为常见游戏类型提供预置Skill模板：

#### RPG游戏Skill模板

```markdown
### RPG核心Skill清单

1. **CharacterSkill**（角色系统）
   - 属性管理（HP/MP/攻击力/防御力等）
   - 等级与经验值
   - 职业/种族特性
   - 装备槽位管理

2. **CombatSkill**（回合制战斗）
   - 回合顺序计算（速度/敏捷）
   - 技能/魔法系统
   - 状态效果（Buff/Debuff）
   - 战斗AI

3. **InventorySkill**（背包系统）
   - 物品分类与堆叠
   - 装备穿戴/卸下
   - 物品使用/丢弃
   - 商店交易

4. **QuestSkill**（任务系统）
   - 主线/支线/日常任务
   - 任务目标追踪
   - 奖励发放
   - 任务链

5. **DialogSkill**（对话系统）
   - 分支对话树
   - NPC好感度
   - 对话选项条件判断
   - 剧情演出

6. **MapSkill**（地图系统）
   - 场景切换
   - 小地图显示
   - 传送点
   - 区域探索度
```

#### Roguelike游戏Skill模板

```markdown
### Roguelike核心Skill清单

1. **DungeonSkill**（地牢生成）
   - 程序化地图生成（房间+走廊）
   - 房间类型（战斗/商店/事件/BOSS）
   - 迷雾系统
   - 地图种子管理

2. **LootSkill**（战利品系统）
   - 随机掉落表
   - 装备词缀系统
   - 稀有度分级
   - 套装效果

3. **PermadeathSkill**（永久死亡）
   - 死亡判定
   - 进度保留策略（元进度）
   - 排行榜记录
   - 成就解锁

4. **UpgradeSkill**（局外成长）
   - 天赋/技能树
   - 解锁新角色/武器
   - 难度调节（Heat系统）
   - 元货币管理
```

#### ACT动作游戏Skill模板

```markdown
### ACT核心Skill清单

1. **MovementSkill**（动作系统）
   - 基础移动（走/跑/跳/冲刺）
   - 连招输入缓冲
   - 动作取消与派生
   - 无敌帧管理

2. **HitboxSkill**（碰撞与受击）
   - 攻击判定框（Hitbox/Hurtbox）
   - 受击硬直与击退
   - 霸体/超级护甲
   - 完美闪避判定

3. **CameraSkill**（镜头系统）
   - 跟随与平滑
   - 战斗镜头（锁定/缩放）
   - 震动反馈
   - 过场动画控制

4. **ComboSkill**（连击系统）
   - 连击计数与评分
   - 风格等级（D→C→B→A→S）
   - 连击奖励倍率
   - 连击中断保护
```

### 11.5 Skill测试与调试

#### 单元测试框架

```lua
-- TestFramework.lua（Skill测试框架）
local TestFramework = {
    tests = {},
    results = { passed = 0, failed = 0, errors = {} }
}

function TestFramework.register(testName, testFunc)
    table.insert(TestFramework.tests, {
        name = testName,
        func = testFunc
    })
end

function TestFramework.assert(condition, message)
    if not condition then
        error(message or "Assertion failed")
    end
end

function TestFramework.assertEquals(expected, actual, message)
    if expected ~= actual then
        error((message or "Assertion failed") .. 
              " Expected: " .. tostring(expected) .. 
              " Actual: " .. tostring(actual))
    end
end

function TestFramework.runAll()
    print("========== 开始运行测试 ==========")
    for _, test in ipairs(TestFramework.tests) do
        local success, err = pcall(test.func)
        if success then
            TestFramework.results.passed = TestFramework.results.passed + 1
            print("✓ " .. test.name)
        else
            TestFramework.results.failed = TestFramework.results.failed + 1
            table.insert(TestFramework.results.errors, {
                test = test.name,
                error = err
            })
            print("✗ " .. test.name .. " - " .. err)
        end
    end

    print("========== 测试完成 ==========")
    print("通过: " .. TestFramework.results.passed)
    print("失败: " .. TestFramework.results.failed)
    print("总计: " .. #TestFramework.tests)

    return TestFramework.results.failed == 0
end

return TestFramework
```

#### 集成测试流程

```lua
-- IntegrationTest.lua（集成测试示例）
local TestFramework = require("TestFramework")
local EventBusSkill = require("EventBusSkill")
local CombatSkill = require("CombatSkill")
local UISkill = require("UISkill")

-- 测试：战斗系统与UI系统的集成
TestFramework.register("Combat_UI_Integration", function()
    -- 初始化
    EventBusSkill.init()
    CombatSkill.init()
    UISkill.init()

    local damageReceived = false
    local uiUpdated = false

    -- 监听UI更新事件
    EventBusSkill.on("UI_UPDATE", function(data)
        if data.type == "HEALTH_BAR" then
            uiUpdated = true
        end
    end)

    -- 模拟战斗事件
    EventBusSkill.emit("ENTITY_DAMAGED", {
        target = { id = "player", hp = 80, maxHp = 100 },
        damage = 20,
        source = { id = "enemy" }
    })

    -- 处理事件队列
    EventBusSkill.processQueue()

    -- 验证
    TestFramework.assert(uiUpdated, "UI未响应战斗伤害事件")
end)

-- 运行所有集成测试
TestFramework.runAll()
```

#### 调试工具Skill

```lua
-- DebugSkill.lua（调试工具）
local DebugSkill = {
    enabled = false,
    logLevel = "INFO", -- DEBUG/INFO/WARN/ERROR
    profiler = {},
    watchList = {},
}

function DebugSkill.init(config)
    DebugSkill.enabled = config.enabled or false
    DebugSkill.logLevel = config.logLevel or "INFO"

    if DebugSkill.enabled then
        -- 注册调试快捷键
        InputSkill.onKeyDown("F1", DebugSkill.toggleProfiler)
        InputSkill.onKeyDown("F2", DebugSkill.toggleWatchList)
        InputSkill.onKeyDown("F3", DebugSkill.hotReloadAll)
    end
end

-- 日志输出
function DebugSkill.log(level, message, data)
    local levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }
    if levels[level] < levels[DebugSkill.logLevel] then return end

    local timestamp = os.date("%H:%M:%S")
    print(string.format("[%s][%s] %s", timestamp, level, message))
    if data then
        print("  Data: " .. json.encode(data))
    end
end

-- 性能分析
function DebugSkill.startProfiler(label)
    DebugSkill.profiler[label] = { startTime = os.clock() }
end

function DebugSkill.endProfiler(label)
    local prof = DebugSkill.profiler[label]
    if prof then
        prof.endTime = os.clock()
        prof.duration = prof.endTime - prof.startTime
        print(string.format("[Profiler] %s: %.4f ms", label, prof.duration * 1000))
    end
end

-- 变量监视
function DebugSkill.watch(name, getter)
    DebugSkill.watchList[name] = getter
end

function DebugSkill.toggleWatchList()
    print("========== 监视列表 ==========")
    for name, getter in pairs(DebugSkill.watchList) do
        local value = getter()
        print(string.format("%s = %s", name, tostring(value)))
    end
end

-- 一键热重载所有Skill
function DebugSkill.hotReloadAll()
    print("[Debug] 热重载所有Skill...")
    MainGameSkill.hotReload("CombatSkill")
    MainGameSkill.hotReload("UISkill")
    MainGameSkill.hotReload("PlayerSkill")
    print("[Debug] 热重载完成")
end

-- 可视化调试信息
function DebugSkill.drawDebugInfo()
    if not DebugSkill.enabled then return end

    -- 绘制FPS
    local fps = 1 / Time.deltaTime
    RenderSkill.drawText(string.format("FPS: %.1f", fps), 10, 10, "white")

    -- 绘制实体数量
    local entityCount = EntityManager.getCount()
    RenderSkill.drawText(string.format("Entities: %d", entityCount), 10, 30, "white")

    -- 绘制事件队列长度
    local queueLength = #EventBusSkill.eventQueue
    RenderSkill.drawText(string.format("EventQueue: %d", queueLength), 10, 50, queueLength > 50 and "red" or "white")
end

return DebugSkill
```

### 11.6 Skill发布与版本管理

#### Skill版本发布流程

```markdown
## Skill发布检查清单

### 代码质量
- [ ] 所有函数有注释说明
- [ ] 配置参数有默认值和范围说明
- [ ] 错误处理完善（pcall保护）
- [ ] 无全局变量污染（除显式导出的接口）
- [ ] 内存泄漏检查（事件监听已注销）

### 测试覆盖
- [ ] 单元测试通过率100%
- [ ] 集成测试通过
- [ ] 边界条件测试（空值、极大值、负值）
- [ ] 性能测试（帧率影响<1ms）

### 文档完整
- [ ] Skill头部注释完整（版本/作者/依赖/功能）
- [ ] 接口文档（输入/输出/异常）
- [ ] 使用示例代码
- [ ] 变更日志（CHANGELOG.md）

### 兼容性
- [ ] 与依赖Skill的版本兼容
- [ ] 向下兼容（旧存档可读）
- [ ] 热重载支持（开发模式）
```

#### Skill依赖版本管理

```lua
-- 在Skill头部声明依赖版本
--[[
    依赖:
    - EventBusSkill >= 1.0.0
    - ConfigSkill >= 1.2.0
    - MathSkill >= 0.5.0 (optional)
--]]

-- 运行时版本检查
function SkillName._checkDependencies()
    local required = {
        { name = "EventBusSkill", minVersion = "1.0.0" },
        { name = "ConfigSkill", minVersion = "1.2.0" },
    }

    for _, dep in ipairs(required) do
        local skill = MainGameSkill.getSkill(dep.name)
        if not skill then
            error("缺少必要依赖: " .. dep.name)
        end
        if skill.VERSION then
            local current = SkillName._parseVersion(skill.VERSION)
            local required = SkillName._parseVersion(dep.minVersion)
            if current.major < required.major or 
               (current.major == required.major and current.minor < required.minor) then
                error(string.format("依赖版本不兼容: %s 需要 >= %s, 当前 %s", 
                    dep.name, dep.minVersion, skill.VERSION))
            end
        end
    end
end

function SkillName._parseVersion(versionStr)
    local major, minor, patch = versionStr:match("(%d+)%.(%d+)%.(%d+)")
    return {
        major = tonumber(major),
        minor = tonumber(minor),
        patch = tonumber(patch)
    }
end
```

## 9. 注意事项与限制

1. **Skill版本兼容性**：合并前检查所有Skill的版本，不兼容版本需先升级
2. **命名空间隔离**：合并后的模块使用`SkillName_ModuleName`命名，避免冲突
3. **性能考虑**：避免过度合并导致单文件过大，建议按系统拆分
4. **测试覆盖**：每个合并后的模块需附带基础测试用例
5. **文档同步**：合并后的代码必须同步更新注释和文档
6. **TapTap制造引擎限制**：
   - 单文件代码行数建议不超过2000行
   - 全局变量需通过`_G`表显式声明
   - 网络相关操作必须使用TDS提供的API
   - 资源加载必须使用引擎的异步加载接口

---

## 10. 扩展接口

本Skill预留以下扩展点，方便后续增强：

```lua
-- 自定义合并策略注册
SkillMerger.registerStrategy("custom", function(moduleA, moduleB)
    -- 用户自定义合并逻辑
end)

-- 自定义游戏机制模板注册
SkillMerger.registerMechanicTemplate("roguelike", {
    -- 肉鸽游戏特有的机制模板
})

-- 后处理钩子
SkillMerger.addPostProcessHook(function(mergedCode)
    -- 对生成的代码进行最终调整
end)
```

---

*本Skill遵循TapTap制造引擎规范，兼容Spark Editor v2.x+ 和 AI Native Engine。*
*生成时间: 2026-06-03*
*版本: v1.0*

        -- 传送效果
        if targetPosition then
            caster.setPosition(targetPosition.x, targetPosition.y)
            result.newPosition = targetPosition
        end

    elseif effect.type == "summon" then
        -- 召唤效果
        if effect.summonId then
            local summon = EntityManager.spawn(effect.summonId, caster.getPosition())
            result.summonId = summon.id
        end
    end

    return result
end

-- 检查连招触发
function SkillSystemSkill._checkComboTrigger()
    local history = SkillSystemSkill.state.comboHistory
    if #history < 2 then return end

    -- 检查最后N个技能是否匹配连招配方
    local combos = ConfigSkill.get("combos", "all") or {}
    for comboId, comboConfig in pairs(combos) do
        local sequence = comboConfig.sequence
        if #sequence <= #history then
            local match = true
            for i = 1, #sequence do
                local historyIndex = #history - #sequence + i
                if history[historyIndex].skillId ~= sequence[i] then
                    match = false
                    break
                end
            end

            if match then
                -- 触发连招奖励
                EventBusSkill.emit("COMBO_TRIGGERED", {
                    comboId = comboId,
                    comboName = comboConfig.name,
                    bonusDamage = comboConfig.bonusDamage or 0,
                    bonusEffect = comboConfig.bonusEffect
                })

                -- 应用连招效果
                if comboConfig.bonusEffect then
                    SkillSystemSkill._executeEffect(comboConfig.bonusEffect, 
                        PlayerSkill.getEntity(), nil, nil, 1)
                end

                EventBusSkill.emit("AUDIO_PLAY", { soundId = "combo_triggered" })
                break
            end
        end
    end
end

-- 清理过期连招记录
function SkillSystemSkill._cleanComboHistory()
    local now = os.clock()
    local window = SkillSystemSkill.CONFIG.comboWindow
    local i = 1
    while i <= #SkillSystemSkill.state.comboHistory do
        if now - SkillSystemSkill.state.comboHistory[i].timestamp > window then
            table.remove(SkillSystemSkill.state.comboHistory, i)
        else
            i = i + 1
        end
    end
end

-- 升级技能
function SkillSystemSkill.upgradeSkill(skillId)
    local skillData = SkillSystemSkill.state.skills[skillId]
    if not skillData then
        return false, "未学会该技能"
    end

    local skillConfig = ConfigSkill.get("skills", skillId)
    local maxLevel = skillConfig.maxLevel or 5

    if skillData.level >= maxLevel then
        return false, "技能已达最高等级"
    end

    if SkillSystemSkill.state.skillPoints < 1 then
        return false, "技能点不足"
    end

    -- 消耗技能点
    SkillSystemSkill.state.skillPoints = SkillSystemSkill.state.skillPoints - 1
    skillData.level = skillData.level + 1

    EventBusSkill.emit("SKILL_UPGRADED", {
        skillId = skillId,
        newLevel = skillData.level,
        remainingPoints = SkillSystemSkill.state.skillPoints
    })

    return true
end

-- 检查技能是否就绪
function SkillSystemSkill.isSkillReady(skillId)
    local skillData = SkillSystemSkill.state.skills[skillId]
    if not skillData then return false end

    local now = os.clock()
    if now < skillData.cooldownEndTime then return false end
    if now < SkillSystemSkill.state.globalCooldownEnd then return false end
    if SkillSystemSkill.state.castingSkill then return false end

    return true
end

-- 获取技能信息
function SkillSystemSkill.getSkillInfo(skillId)
    local skillData = SkillSystemSkill.state.skills[skillId]
    local skillConfig = ConfigSkill.get("skills", skillId)
    if not skillConfig then return nil end

    local info = {
        id = skillId,
        name = skillConfig.name,
        description = skillConfig.description,
        icon = skillConfig.icon,
        type = skillConfig.type,
        learned = skillData ~= nil,
        level = skillData and skillData.level or 0,
        maxLevel = skillConfig.maxLevel or 5,
        cooldown = skillConfig.cooldown or 0,
        castTime = skillConfig.castTime or 0,
        cost = skillConfig.cost,
        effects = skillConfig.effects,
        prerequisites = skillConfig.prerequisites,
    }

    if skillData then
        local now = os.clock()
        info.remainingCooldown = math.max(0, skillData.cooldownEndTime - now)
        info.isReady = info.remainingCooldown <= 0 and 
                       now >= SkillSystemSkill.state.globalCooldownEnd and
                       not SkillSystemSkill.state.castingSkill
    else
        info.isReady = false
        info.remainingCooldown = 0
    end

    return info
end

-- 获取所有已学技能
function SkillSystemSkill.getLearnedSkills()
    local result = {}
    for skillId, _ in pairs(SkillSystemSkill.state.skills) do
        table.insert(result, SkillSystemSkill.getSkillInfo(skillId))
    end
    return result
end

-- 获取可用技能（已学会且就绪的）
function SkillSystemSkill.getAvailableSkills()
    local result = {}
    for skillId, _ in pairs(SkillSystemSkill.state.skills) do
        if SkillSystemSkill.isSkillReady(skillId) then
            table.insert(result, SkillSystemSkill.getSkillInfo(skillId))
        end
    end
    return result
end

-- 每帧更新（处理持续施法、冷却显示等）
function SkillSystemSkill.update(dt)
    -- 处理持续施法进度
    if SkillSystemSkill.state.castingSkill then
        local skillConfig = ConfigSkill.get("skills", SkillSystemSkill.state.castingSkill)
        if skillConfig and skillConfig.castTime then
            local elapsed = os.clock() - SkillSystemSkill.state.castStartTime
            local progress = math.min(1.0, elapsed / skillConfig.castTime)

            EventBusSkill.emit("SKILL_CAST_PROGRESS", {
                skillId = SkillSystemSkill.state.castingSkill,
                progress = progress,
                remainingTime = skillConfig.castTime - elapsed
            })
        end
    end

    -- 清理过期连招记录
    SkillSystemSkill._cleanComboHistory()
end

-- 事件处理
function SkillSystemSkill._onInputAction(data)
    -- 技能快捷键
    if data.action:match("^SKILL_SLOT_%d$") then
        local slotIndex = tonumber(data.action:match("%d"))
        local availableSkills = SkillSystemSkill.getAvailableSkills()
        if availableSkills[slotIndex] then
            SkillSystemSkill.castSkill(availableSkills[slotIndex].id, data.target, data.targetPosition)
        end
    end
end

function SkillSystemSkill._onEntityDied(data)
    -- 击杀获得技能点
    if data.killer == PlayerSkill.getEntity() then
        SkillSystemSkill.state.skillPoints = SkillSystemSkill.state.skillPoints + 1
        EventBusSkill.emit("SKILL_POINT_GAINED", {
            amount = 1,
            total = SkillSystemSkill.state.skillPoints
        })
    end
end

function SkillSystemSkill._onSaveGame(data)
    data.skillSystem = {
        skills = SkillSystemSkill.state.skills,
        skillPoints = SkillSystemSkill.state.skillPoints,
        comboHistory = SkillSystemSkill.state.comboHistory,
    }
end

function SkillSystemSkill._onLoadGame(data)
    if data.skillSystem then
        SkillSystemSkill.state.skills = data.skillSystem.skills or {}
        SkillSystemSkill.state.skillPoints = data.skillSystem.skillPoints or 0
        SkillSystemSkill.state.comboHistory = data.skillSystem.comboHistory or {}
    end
end

function SkillSystemSkill.destroy()
    EventBusSkill.off("INPUT_ACTION", SkillSystemSkill._onInputAction)
    EventBusSkill.off("ENTITY_DIED", SkillSystemSkill._onEntityDied)
    EventBusSkill.off("SAVE_GAME", SkillSystemSkill._onSaveGame)
    EventBusSkill.off("LOAD_GAME", SkillSystemSkill._onLoadGame)
end

return SkillSystemSkill
```

### 12.3 场景：开发一个任务系统

#### 需求分析

**功能需求**：
- 任务类型（主线/支线/日常/成就）
- 任务状态（未接取/进行中/可完成/已完成）
- 任务目标（击杀/收集/对话/探索/护送/限时）
- 任务奖励（经验/金币/物品/技能点）
- 任务链（前置任务解锁）
- 自动追踪（显示当前任务目标）
- 任务日志（历史任务记录）

#### 核心代码实现

```lua
--[[
    Skill: QuestSkill
    版本: 1.0.0
    层级: Layer 3（玩法层）
    依赖: EventBusSkill, ConfigSkill, SaveLoadSkill, InventorySkill
    功能: 任务系统 - 任务管理、目标追踪、奖励发放
--]]

local QuestSkill = {
    VERSION = "1.0.0",

    CONFIG = {
        maxActiveQuests = 10,    -- 最大同时追踪任务数
        autoTrackMainQuest = true, -- 自动追踪主线任务
        dailyResetHour = 4,       -- 日常任务重置时间（凌晨4点）
    },

    state = {
        activeQuests = {},       -- 进行中的任务 {questId, progress, objectives}
        completedQuests = {},    -- 已完成的任务 {questId, completeTime, rating}
        availableQuests = {},    -- 可接取的任务列表
        trackedQuests = {},      -- 当前追踪的任务ID列表
        dailyQuests = {},        -- 日常任务状态
        questHistory = {},       -- 任务历史记录
    },

    QUEST_STATUS = {
        LOCKED = "locked",       -- 未解锁
        AVAILABLE = "available",   -- 可接取
        ACTIVE = "active",       -- 进行中
        COMPLETABLE = "completable", -- 可完成（条件满足但未提交）
        COMPLETED = "completed", -- 已完成
        FAILED = "failed",       -- 失败
    },

    QUEST_TYPE = {
        MAIN = "main",           -- 主线
        SIDE = "side",           -- 支线
        DAILY = "daily",         -- 日常
        EVENT = "event",         -- 活动
        ACHIEVEMENT = "achievement", -- 成就
    },

    OBJECTIVE_TYPE = {
        KILL = "kill",           -- 击杀目标
        COLLECT = "collect",     -- 收集物品
        TALK = "talk",           -- 与NPC对话
        REACH = "reach",         -- 到达地点
        ESCORT = "escort",       -- 护送NPC
        DEFEND = "defend",       -- 防守
        TIMED = "timed",         -- 限时完成
        CUSTOM = "custom",       -- 自定义（通过事件触发）
    },
}

function QuestSkill.init(config)
    if config then
        for k, v in pairs(config) do
            QuestSkill.CONFIG[k] = v
        end
    end

    -- 注册事件监听
    EventBusSkill.on("ENTITY_DIED", QuestSkill._onEntityDied)
    EventBusSkill.on("ITEM_COLLECTED", QuestSkill._onItemCollected)
    EventBusSkill.on("NPC_INTERACT", QuestSkill._onNPCInteract)
    EventBusSkill.on("AREA_ENTERED", QuestSkill._onAreaEntered)
    EventBusSkill.on("SAVE_GAME", QuestSkill._onSaveGame)
    EventBusSkill.on("LOAD_GAME", QuestSkill._onLoadGame)
    EventBusSkill.on("DAILY_RESET", QuestSkill._onDailyReset)

    -- 加载可用任务列表
    QuestSkill._loadAvailableQuests()

    print("[QuestSkill] 初始化完成")
end

-- 接取任务
function QuestSkill.acceptQuest(questId)
    local questConfig = ConfigSkill.get("quests", questId)
    if not questConfig then
        return false, "任务配置不存在"
    end

    -- 检查是否已接取或已完成
    if QuestSkill.state.activeQuests[questId] then
        return false, "任务已在进行中"
    end

    if QuestSkill.state.completedQuests[questId] and not questConfig.repeatable then
        return false, "任务已完成且不可重复"
    end

    -- 检查任务上限
    if #QuestSkill.state.trackedQuests >= QuestSkill.CONFIG.maxActiveQuests then
        return false, "追踪任务数量已达上限"
    end

    -- 创建任务进度数据
    local objectives = {}
    for i, objConfig in ipairs(questConfig.objectives) do
        objectives[i] = {
            type = objConfig.type,
            target = objConfig.target,
            required = objConfig.required or 1,
            current = 0,
            completed = false,
            description = objConfig.description,
        }
    end

    QuestSkill.state.activeQuests[questId] = {
        id = questId,
        acceptedTime = os.time(),
        objectives = objectives,
        status = QuestSkill.QUEST_STATUS.ACTIVE,
        tracked = true,
    }

    table.insert(QuestSkill.state.trackedQuests, questId)

    -- 如果是限时任务，启动计时器
    if questConfig.timeLimit then
        QuestSkill._startQuestTimer(questId, questConfig.timeLimit)
    end

    EventBusSkill.emit("QUEST_ACCEPTED", {
        questId = questId,
        questName = questConfig.name,
        objectives = objectives
    })

    EventBusSkill.emit("AUDIO_PLAY", { soundId = "quest_accepted" })

    return true
end

-- 更新任务目标进度
function QuestSkill.updateObjective(questId, objectiveIndex, progressDelta)
    local questData = QuestSkill.state.activeQuests[questId]
    if not questData then return false end

    local objective = questData.objectives[objectiveIndex]
    if not objective or objective.completed then return false end

    objective.current = math.min(objective.required, objective.current + progressDelta)

    -- 检查是否完成
    if objective.current >= objective.required then
        objective.completed = true
        EventBusSkill.emit("QUEST_OBJECTIVE_COMPLETED", {
            questId = questId,
            objectiveIndex = objectiveIndex,
            description = objective.description
        })
    end

    -- 检查整个任务是否完成
    QuestSkill._checkQuestCompletion(questId)

    EventBusSkill.emit("QUEST_PROGRESS_UPDATED", {
        questId = questId,
        objectiveIndex = objectiveIndex,
        current = objective.current,
        required = objective.required,
        progress = objective.current / objective.required
    })

    return true
end

-- 提交/完成任务
function QuestSkill.completeQuest(questId)
    local questData = QuestSkill.state.activeQuests[questId]
    if not questData then
        return false, "任务不在进行中"
    end

    -- 检查所有目标是否完成
    local allCompleted = true
    for _, obj in ipairs(questData.objectives) do
        if not obj.completed then
            allCompleted = false
            break
        end
    end

    if not allCompleted then
        return false, "任务目标尚未全部完成"
    end

    local questConfig = ConfigSkill.get("quests", questId)

    -- 发放奖励
    QuestSkill._giveRewards(questConfig.rewards)

    -- 从活跃任务移除
    QuestSkill.state.activeQuests[questId] = nil

    -- 从追踪列表移除
    for i, id in ipairs(QuestSkill.state.trackedQuests) do
        if id == questId then
            table.remove(QuestSkill.state.trackedQuests, i)
            break
        end
    end

    -- 记录完成
    QuestSkill.state.completedQuests[questId] = {
        completedTime = os.time(),
        acceptedTime = questData.acceptedTime,
        duration = os.time() - questData.acceptedTime,
    }

    -- 记录历史
    table.insert(QuestSkill.state.questHistory, {
        questId = questId,
        completedTime = os.time(),
        questName = questConfig.name,
    })

    -- 解锁后续任务
    if questConfig.unlocks then
        for _, unlockQuestId in ipairs(questConfig.unlocks) do
            QuestSkill._unlockQuest(unlockQuestId)
        end
    end

    EventBusSkill.emit("QUEST_COMPLETED", {
        questId = questId,
        questName = questConfig.name,
        rewards = questConfig.rewards
    })

    EventBusSkill.emit("AUDIO_PLAY", { soundId = "quest_completed" })

    return true
end

-- 放弃任务
function QuestSkill.abandonQuest(questId)
    local questData = QuestSkill.state.activeQuests[questId]
    if not questData then
        return false, "任务不在进行中"
    end

    QuestSkill.state.activeQuests[questId] = nil

    for i, id in ipairs(QuestSkill.state.trackedQuests) do
        if id == questId then
            table.remove(QuestSkill.state.trackedQuests, i)
            break
        end
    end

    EventBusSkill.emit("QUEST_ABANDONED", { questId = questId })

    return true
end

-- 追踪/取消追踪任务
function QuestSkill.toggleTrack(questId)
    local questData = QuestSkill.state.activeQuests[questId]
    if not questData then return false end

    questData.tracked = not questData.tracked

    if questData.tracked then
        if not QuestSkill._isTracked(questId) then
            table.insert(QuestSkill.state.trackedQuests, questId)
        end
    else
        for i, id in ipairs(QuestSkill.state.trackedQuests) do
            if id == questId then
                table.remove(QuestSkill.state.trackedQuests, i)
                break
            end
        end
    end

    EventBusSkill.emit("QUEST_TRACK_TOGGLED", {
        questId = questId,
        tracked = questData.tracked
    })

    return true
end

-- 获取任务信息
function QuestSkill.getQuestInfo(questId)
    local questConfig = ConfigSkill.get("quests", questId)
    if not questConfig then return nil end

    local activeData = QuestSkill.state.activeQuests[questId]
    local completedData = QuestSkill.state.completedQuests[questId]

    local status = QuestSkill.QUEST_STATUS.LOCKED
    if completedData then
        status = QuestSkill.QUEST_STATUS.COMPLETED
    elseif activeData then
        status = activeData.status
    elseif QuestSkill._isQuestAvailable(questId) then
        status = QuestSkill.QUEST_STATUS.AVAILABLE
    end

    return {
        id = questId,
        name = questConfig.name,
        description = questConfig.description,
        type = questConfig.type,
        status = status,
        objectives = activeData and activeData.objectives or questConfig.objectives,
        rewards = questConfig.rewards,
        tracked = activeData and activeData.tracked or false,
        timeLimit = questConfig.timeLimit,
        giver = questConfig.giver,
        completer = questConfig.completer,
    }
end

-- 获取当前追踪的任务列表
function QuestSkill.getTrackedQuests()
    local result = {}
    for _, questId in ipairs(QuestSkill.state.trackedQuests) do
        table.insert(result, QuestSkill.getQuestInfo(questId))
    end
    return result
end

-- 获取可接取的任务列表
function QuestSkill.getAvailableQuests()
    local result = {}
    for questId, _ in pairs(QuestSkill.state.availableQuests) do
        table.insert(result, QuestSkill.getQuestInfo(questId))
    end
    return result
end

-- ==================== 私有方法 ====================

function QuestSkill._checkQuestCompletion(questId)
    local questData = QuestSkill.state.activeQuests[questId]
    if not questData then return end

    local allCompleted = true
    for _, obj in ipairs(questData.objectives) do
        if not obj.completed then
            allCompleted = false
            break
        end
    end

    if allCompleted then
        questData.status = QuestSkill.QUEST_STATUS.COMPLETABLE
        EventBusSkill.emit("QUEST_COMPLETABLE", { questId = questId })
    end
end

function QuestSkill._giveRewards(rewards)
    if not rewards then return end

    if rewards.exp then
        PlayerSkill.addExp(rewards.exp)
    end

    if rewards.gold then
        InventorySkill.addGold(rewards.gold)
    end

    if rewards.items then
        for _, itemReward in ipairs(rewards.items) do
            InventorySkill.addItem(itemReward.itemId, itemReward.count or 1)
        end
    end

    if rewards.skillPoints then
        SkillSystemSkill.state.skillPoints = SkillSystemSkill.state.skillPoints + rewards.skillPoints
    end

    if rewards.reputation then
        for faction, amount in pairs(rewards.reputation) do
            PlayerSkill.addReputation(faction, amount)
        end
    end
end

function QuestSkill._isQuestAvailable(questId)
    local questConfig = ConfigSkill.get("quests", questId)
    if not questConfig then return false end

    -- 检查前置条件
    if questConfig.prerequisites then
        for _, prereqId in ipairs(questConfig.prerequisites) do
            if not QuestSkill.state.completedQuests[prereqId] then
                return false
            end
        end
    end

    -- 检查等级要求
    if questConfig.minLevel then
        if PlayerSkill.getLevel() < questConfig.minLevel then
            return false
        end
    end

    return true
end

function QuestSkill._unlockQuest(questId)
    if QuestSkill._isQuestAvailable(questId) then
        QuestSkill.state.availableQuests[questId] = true
        EventBusSkill.emit("QUEST_UNLOCKED", { questId = questId })
    end
end

function QuestSkill._isTracked(questId)
    for _, id in ipairs(QuestSkill.state.trackedQuests) do
        if id == questId then return true end
    end
    return false
end

function QuestSkill._loadAvailableQuests()
    local allQuests = ConfigSkill.get("quests", "all") or {}
    for questId, _ in pairs(allQuests) do
        if QuestSkill._isQuestAvailable(questId) then
            QuestSkill.state.availableQuests[questId] = true
        end
    end
end

function QuestSkill._startQuestTimer(questId, timeLimit)
    Timer.delay(timeLimit, function()
        local questData = QuestSkill.state.activeQuests[questId]
        if questData and questData.status ~= QuestSkill.QUEST_STATUS.COMPLETED then
            questData.status = QuestSkill.QUEST_STATUS.FAILED
            QuestSkill.state.activeQuests[questId] = nil
            EventBusSkill.emit("QUEST_FAILED", {
                questId = questId,
                reason = "time_limit"
            })
        end
    end)
end

-- ==================== 事件处理 ====================

function QuestSkill._onEntityDied(data)
    -- 检查是否有击杀目标
    for questId, questData in pairs(QuestSkill.state.activeQuests) do
        for i, objective in ipairs(questData.objectives) do
            if objective.type == QuestSkill.OBJECTIVE_TYPE.KILL then
                if data.entityId == objective.target or 
                   (objective.targetType and data.entityType == objective.targetType) then
                    QuestSkill.updateObjective(questId, i, 1)
                end
            end
        end
    end
end

function QuestSkill._onItemCollected(data)
    -- 检查收集目标
    for questId, questData in pairs(QuestSkill.state.activeQuests) do
        for i, objective in ipairs(questData.objectives) do
            if objective.type == QuestSkill.OBJECTIVE_TYPE.COLLECT then
                if data.itemId == objective.target then
                    QuestSkill.updateObjective(questId, i, data.count or 1)
                end
            end
        end
    end
end

function QuestSkill._onNPCInteract(data)
    -- 检查对话目标
    for questId, questData in pairs(QuestSkill.state.activeQuests) do
        for i, objective in ipairs(questData.objectives) do
            if objective.type == QuestSkill.OBJECTIVE_TYPE.TALK then
                if data.npcId == objective.target then
                    QuestSkill.updateObjective(questId, i, 1)
                end
            end
        end
    end
end

function QuestSkill._onAreaEntered(data)
    -- 检查到达目标
    for questId, questData in pairs(QuestSkill.state.activeQuests) do
        for i, objective in ipairs(questData.objectives) do
            if objective.type == QuestSkill.OBJECTIVE_TYPE.REACH then
                if data.areaId == objective.target then
                    QuestSkill.updateObjective(questId, i, 1)
                end
            end
        end
    end
end

function QuestSkill._onDailyReset(data)
    -- 重置日常任务
    for questId, questData in pairs(QuestSkill.state.activeQuests) do
        local questConfig = ConfigSkill.get("quests", questId)
        if questConfig and questConfig.type == QuestSkill.QUEST_TYPE.DAILY then
            QuestSkill.abandonQuest(questId)
        end
    end

    -- 重新加载日常任务
    QuestSkill.state.dailyQuests = {}
    local dailyQuestPool = ConfigSkill.get("daily_quest_pool", "all") or {}
    -- 随机选择日常任务
    -- ...
end

function QuestSkill._onSaveGame(data)
    data.questSystem = {
        activeQuests = QuestSkill.state.activeQuests,
        completedQuests = QuestSkill.state.completedQuests,
        trackedQuests = QuestSkill.state.trackedQuests,
        questHistory = QuestSkill.state.questHistory,
        dailyQuests = QuestSkill.state.dailyQuests,
    }
end

function QuestSkill._onLoadGame(data)
    if data.questSystem then
        QuestSkill.state.activeQuests = data.questSystem.activeQuests or {}
        QuestSkill.state.completedQuests = data.questSystem.completedQuests or {}
        QuestSkill.state.trackedQuests = data.questSystem.trackedQuests or {}
        QuestSkill.state.questHistory = data.questSystem.questHistory or {}
        QuestSkill.state.dailyQuests = data.questSystem.dailyQuests or {}
    end
end

function QuestSkill.destroy()
    EventBusSkill.off("ENTITY_DIED", QuestSkill._onEntityDied)
    EventBusSkill.off("ITEM_COLLECTED", QuestSkill._onItemCollected)
    EventBusSkill.off("NPC_INTERACT", QuestSkill._onNPCInteract)
    EventBusSkill.off("AREA_ENTERED", QuestSkill._onAreaEntered)
    EventBusSkill.off("SAVE_GAME", QuestSkill._onSaveGame)
    EventBusSkill.off("LOAD_GAME", QuestSkill._onLoadGame)
    EventBusSkill.off("DAILY_RESET", QuestSkill._onDailyReset)
end

return QuestSkill
```

### 12.4 场景：开发一个对话系统

#### 核心代码实现

```lua
--[[
    Skill: DialogSkill
    版本: 1.0.0
    层级: Layer 3（玩法层）
    依赖: EventBusSkill, ConfigSkill, QuestSkill
    功能: 对话系统 - 分支对话、NPC好感度、剧情演出
--]]

local DialogSkill = {
    VERSION = "1.0.0",

    CONFIG = {
        textSpeed = 50,          -- 文字显示速度（字符/秒）
        autoSkipDelay = 2.0,     -- 自动跳过延迟（秒）
        choiceTimeout = 0,       -- 选项超时时间（0=无限制）
    },

    state = {
        isActive = false,
        currentDialogId = nil,
        currentNodeId = nil,
        dialogHistory = {},
        npcFavor = {},           -- NPC好感度 {npcId, value}
        textProgress = 0,        -- 当前文字显示进度
        isTyping = false,
        currentChoices = {},
    },
}

function DialogSkill.init(config)
    if config then
        for k, v in pairs(config) do
            DialogSkill.CONFIG[k] = v
        end
    end

    EventBusSkill.on("NPC_INTERACT", DialogSkill._onNPCInteract)
    EventBusSkill.on("INPUT_ACTION", DialogSkill._onInputAction)
    EventBusSkill.on("SAVE_GAME", DialogSkill._onSaveGame)
    EventBusSkill.on("LOAD_GAME", DialogSkill._onLoadGame)
end

-- 开始对话
function DialogSkill.startDialog(dialogId, npcId)
    local dialogConfig = ConfigSkill.get("dialogs", dialogId)
    if not dialogConfig then
        return false, "对话配置不存在"
    end

    DialogSkill.state.isActive = true
    DialogSkill.state.currentDialogId = dialogId
    DialogSkill.state.currentNodeId = dialogConfig.startNode or "start"
    DialogSkill.state.textProgress = 0
    DialogSkill.state.isTyping = true
    DialogSkill.state.currentChoices = {}

    -- 记录对话历史
    table.insert(DialogSkill.state.dialogHistory, {
        dialogId = dialogId,
        npcId = npcId,
        startTime = os.time(),
    })

    EventBusSkill.emit("DIALOG_STARTED", {
        dialogId = dialogId,
        npcId = npcId
    })

    -- 显示第一个节点
    DialogSkill._showNode(DialogSkill.state.currentNodeId)

    return true
end

-- 显示对话节点
function DialogSkill._showNode(nodeId)
    local dialogConfig = ConfigSkill.get("dialogs", DialogSkill.state.currentDialogId)
    local node = dialogConfig.nodes[nodeId]
    if not node then
        DialogSkill.endDialog()
        return
    end

    DialogSkill.state.currentNodeId = nodeId
    DialogSkill.state.textProgress = 0
    DialogSkill.state.isTyping = true

    -- 处理节点事件
    if node.events then
        for _, event in ipairs(node.events) do
            EventBusSkill.emit(event.name, event.data or {})
        end
    end

    -- 处理条件分支
    if node.conditions then
        for _, condition in ipairs(node.conditions) do
            local met = DialogSkill._checkCondition(condition)
            if met then
                DialogSkill._showNode(condition.targetNode)
                return
            end
        end
    end

    -- 处理选项
    if node.choices then
        local validChoices = {}
        for _, choice in ipairs(node.choices) do
            if not choice.condition or DialogSkill._checkCondition(choice.condition) then
                table.insert(validChoices, choice)
            end
        end
        DialogSkill.state.currentChoices = validChoices
    else
        DialogSkill.state.currentChoices = {}
    end

    -- 计算文字显示时间
    local textLength = string.len(node.text or "")
    local displayTime = textLength / DialogSkill.CONFIG.textSpeed

    EventBusSkill.emit("DIALOG_NODE_CHANGED", {
        dialogId = DialogSkill.state.currentDialogId,
        nodeId = nodeId,
        speaker = node.speaker,
        text = node.text,
        choices = DialogSkill.state.currentChoices,
        displayTime = displayTime,
        hasChoices = #DialogSkill.state.currentChoices > 0
    })

    -- 自动播放文字效果
    Timer.delay(displayTime, function()
        DialogSkill.state.isTyping = false
        DialogSkill.state.textProgress = 1.0
        EventBusSkill.emit("DIALOG_TEXT_COMPLETE", {
            nodeId = nodeId,
            hasChoices = #DialogSkill.state.currentChoices > 0
        })
    end)
end

-- 选择选项
function DialogSkill.selectChoice(choiceIndex)
    if not DialogSkill.state.isActive then return false end
    if DialogSkill.state.isTyping then return false end

    local choice = DialogSkill.state.currentChoices[choiceIndex]
    if not choice then return false end

    -- 处理选项效果
    if choice.effects then
        for _, effect in ipairs(choice.effects) do
            DialogSkill._applyEffect(effect)
        end
    end

    -- 处理好感度变化
    if choice.favorChange then
        local npcId = DialogSkill.state.dialogHistory[#DialogSkill.state.dialogHistory].npcId
        DialogSkill._changeFavor(npcId, choice.favorChange)
    end

    -- 跳转到下一个节点
    if choice.targetNode then
        DialogSkill._showNode(choice.targetNode)
    else
        DialogSkill.endDialog()
    end

    EventBusSkill.emit("DIALOG_CHOICE_SELECTED", {
        choiceIndex = choiceIndex,
        choiceText = choice.text,
        effects = choice.effects
    })

    return true
end

-- 跳过文字动画
function DialogSkill.skipTyping()
    if not DialogSkill.state.isActive then return end
    DialogSkill.state.isTyping = false
    DialogSkill.state.textProgress = 1.0
    EventBusSkill.emit("DIALOG_TEXT_COMPLETE", {
        nodeId = DialogSkill.state.currentNodeId,
        hasChoices = #DialogSkill.state.currentChoices > 0
    })
end

-- 结束对话
function DialogSkill.endDialog()
    if not DialogSkill.state.isActive then return end

    local history = DialogSkill.state.dialogHistory[#DialogSkill.state.dialogHistory]
    if history then
        history.endTime = os.time()
        history.duration = history.endTime - history.startTime
    end

    DialogSkill.state.isActive = false
    DialogSkill.state.currentDialogId = nil
    DialogSkill.state.currentNodeId = nil
    DialogSkill.state.textProgress = 0
    DialogSkill.state.isTyping = false
    DialogSkill.state.currentChoices = {}

    EventBusSkill.emit("DIALOG_ENDED", {})
    EventBusSkill.emit("AUDIO_PLAY", { soundId = "dialog_end" })
end

-- 获取NPC好感度
function DialogSkill.getFavor(npcId)
    return DialogSkill.state.npcFavor[npcId] or 0
end

-- 改变好感度
function DialogSkill._changeFavor(npcId, delta)
    local current = DialogSkill.state.npcFavor[npcId] or 0
    DialogSkill.state.npcFavor[npcId] = math.max(-100, math.min(100, current + delta))

    EventBusSkill.emit("NPC_FAVOR_CHANGED", {
        npcId = npcId,
        delta = delta,
        newValue = DialogSkill.state.npcFavor[npcId]
    })
end

-- 检查条件
function DialogSkill._checkCondition(condition)
    if condition.type == "quest_completed" then
        return QuestSkill.state.completedQuests[condition.questId] ~= nil
    elseif condition.type == "quest_active" then
        return QuestSkill.state.activeQuests[condition.questId] ~= nil
    elseif condition.type == "favor_min" then
        return DialogSkill.getFavor(condition.npcId) >= condition.value
    elseif condition.type == "favor_max" then
        return DialogSkill.getFavor(condition.npcId) <= condition.value
    elseif condition.type == "level_min" then
        return PlayerSkill.getLevel() >= condition.value
    elseif condition.type == "item_has" then
        return InventorySkill.hasItem(condition.itemId, condition.count or 1)
    elseif condition.type == "custom" then
        -- 通过事件检查自定义条件
        local result = false
        EventBusSkill.emit("DIALOG_CHECK_CONDITION", {
            condition = condition,
            callback = function(r) result = r end
        })
        return result
    end
    return false
end

-- 应用效果
function DialogSkill._applyEffect(effect)
    if effect.type == "give_item" then
        InventorySkill.addItem(effect.itemId, effect.count or 1)
    elseif effect.type == "remove_item" then
        -- 从背包移除物品
    elseif effect.type == "give_quest" then
        QuestSkill.acceptQuest(effect.questId)
    elseif effect.type == "complete_quest" then
        QuestSkill.completeQuest(effect.questId)
    elseif effect.type == "teleport" then
        PlayerSkill.teleport(effect.targetPosition)
    elseif effect.type == "change_favor" then
        DialogSkill._changeFavor(effect.npcId, effect.value)
    elseif effect.type == "trigger_event" then
        EventBusSkill.emit(effect.eventName, effect.data or {})
    end
end

-- 每帧更新
function DialogSkill.update(dt)
    if DialogSkill.state.isActive and DialogSkill.state.isTyping then
        DialogSkill.state.textProgress = math.min(1.0, 
            DialogSkill.state.textProgress + dt * DialogSkill.CONFIG.textSpeed / 100)

        EventBusSkill.emit("DIALOG_TEXT_PROGRESS", {
            progress = DialogSkill.state.textProgress,
            nodeId = DialogSkill.state.currentNodeId
        })
    end
end

-- 事件处理
function DialogSkill._onNPCInteract(data)
    -- 检查NPC是否有默认对话
    local npcConfig = ConfigSkill.get("npcs", data.npcId)
    if npcConfig and npcConfig.defaultDialog then
        DialogSkill.startDialog(npcConfig.defaultDialog, data.npcId)
    end
end

function DialogSkill._onInputAction(data)
    if not DialogSkill.state.isActive then return end

    if data.action == "DIALOG_NEXT" then
        if DialogSkill.state.isTyping then
            DialogSkill.skipTyping()
        elseif #DialogSkill.state.currentChoices == 0 then
            -- 无选项，进入下一个节点或结束
            local dialogConfig = ConfigSkill.get("dialogs", DialogSkill.state.currentDialogId)
            local node = dialogConfig.nodes[DialogSkill.state.currentNodeId]
            if node.nextNode then
                DialogSkill._showNode(node.nextNode)
            else
                DialogSkill.endDialog()
            end
        end
    end
end

function DialogSkill._onSaveGame(data)
    data.dialogSystem = {
        dialogHistory = DialogSkill.state.dialogHistory,
        npcFavor = DialogSkill.state.npcFavor,
    }
end

function DialogSkill._onLoadGame(data)
    if data.dialogSystem then
        DialogSkill.state.dialogHistory = data.dialogSystem.dialogHistory or {}
        DialogSkill.state.npcFavor = data.dialogSystem.npcFavor or {}
    end
end

function DialogSkill.destroy()
    EventBusSkill.off("NPC_INTERACT", DialogSkill._onNPCInteract)
    EventBusSkill.off("INPUT_ACTION", DialogSkill._onInputAction)
    EventBusSkill.off("SAVE_GAME", DialogSkill._onSaveGame)
    EventBusSkill.off("LOAD_GAME", DialogSkill._onLoadGame)
end

return DialogSkill
```

### 12.5 场景：通过Skill合并器整合完整RPG游戏

#### 整合流程

```lua
-- MainGameSkill.lua（整合所有子系统Skill）

local MainGameSkill = {
    VERSION = "1.0.0",
    subSkills = {},
}

MainGameSkill.SKILL_REGISTRY = {
    -- Layer 0: 基础层
    { name = "UtilsSkill", path = "Skills/UtilsSkill", layer = 0, init = true },
    { name = "MathSkill", path = "Skills/MathSkill", layer = 0, init = true },
    { name = "DebugSkill", path = "Skills/DebugSkill", layer = 0, init = true },

    -- Layer 1: 引擎层
    { name = "InputSkill", path = "Skills/InputSkill", layer = 1, init = true },
    { name = "PhysicsSkill", path = "Skills/PhysicsSkill", layer = 1, init = true },
    { name = "RenderSkill", path = "Skills/RenderSkill", layer = 1, init = true },

    -- Layer 2: 系统层
    { name = "EventBusSkill", path = "Skills/EventBusSkill", layer = 2, init = true },
    { name = "ConfigSkill", path = "Skills/ConfigSkill", layer = 2, init = true },
    { name = "SaveLoadSkill", path = "Skills/SaveLoadSkill", layer = 2, init = true },
    { name = "StateMachineSkill", path = "Skills/StateMachineSkill", layer = 2, init = true },

    -- Layer 3: 玩法层
    { name = "PlayerSkill", path = "Skills/PlayerSkill", layer = 3, init = true },
    { name = "CombatSkill", path = "Skills/CombatSkill", layer = 3, init = true },
    { name = "EnemySkill", path = "Skills/EnemySkill", layer = 3, init = true },
    { name = "InventorySkill", path = "Skills/InventorySkill", layer = 3, init = true },
    { name = "QuestSkill", path = "Skills/QuestSkill", layer = 3, init = true },
    { name = "DialogSkill", path = "Skills/DialogSkill", layer = 3, init = true },
    { name = "SkillSystemSkill", path = "Skills/SkillSystemSkill", layer = 3, init = true },

    -- Layer 4: 表现层
    { name = "UISkill", path = "Skills/UISkill", layer = 4, init = true },
    { name = "InventoryUISkill", path = "Skills/InventoryUISkill", layer = 4, init = true },
    { name = "VFXSkill", path = "Skills/VFXSkill", layer = 4, init = true },
    { name = "AudioSkill", path = "Skills/AudioSkill", layer = 4, init = true },
}

function MainGameSkill.init()
    print("[MainGameSkill] RPG游戏初始化开始...")

    -- 按层级顺序加载所有Skill
    for layer = 0, 4 do
        print("[MainGameSkill] 初始化 Layer " .. layer)
        for _, skillInfo in ipairs(MainGameSkill.SKILL_REGISTRY) do
            if skillInfo.layer == layer and skillInfo.init then
                local skill = require(skillInfo.path)
                MainGameSkill.subSkills[skillInfo.name] = skill

                if skill.init then
                    skill.init(ConfigSkill.get("game", skillInfo.name, {}))
                end

                print("  ✓ " .. skillInfo.name .. " v" .. (skill.VERSION or "?") .. " 初始化完成")
            end
        end
    end

    -- 注册游戏生命周期事件
    EventBusSkill.on("GAME_START", MainGameSkill._onGameStart)
    EventBusSkill.on("GAME_PAUSE", MainGameSkill._onGamePause)
    EventBusSkill.on("GAME_RESUME", MainGameSkill._onGameResume)
    EventBusSkill.on("GAME_QUIT", MainGameSkill._onGameQuit)

    -- 发布游戏初始化完成事件
    EventBusSkill.emit("GAME_INIT", { timestamp = os.time() })

    print("[MainGameSkill] RPG游戏初始化完成!")
    print("[MainGameSkill] 已加载 " .. #MainGameSkill.SKILL_REGISTRY .. " 个Skill模块")
end

-- 游戏主循环
function MainGameSkill.update(dt)
    -- 处理事件队列
    EventBusSkill.processQueue()

    -- 更新各子系统
    for name, skill in pairs(MainGameSkill.subSkills) do
        if skill.update then
            skill.update(dt)
        end
    end

    -- 绘制调试信息
    if DebugSkill.enabled then
        DebugSkill.drawDebugInfo()
    end
end

-- 游戏开始
function MainGameSkill._onGameStart(data)
    print("[MainGameSkill] 游戏开始!")
    -- 加载初始场景
    StateMachineSkill.changeState("Gameplay")
end

function MainGameSkill._onGamePause(data)
    print("[MainGameSkill] 游戏暂停")
end

function MainGameSkill._onGameResume(data)
    print("[MainGameSkill] 游戏恢复")
end

function MainGameSkill._onGameQuit(data)
    print("[MainGameSkill] 游戏退出")
    -- 保存游戏
    EventBusSkill.emit("SAVE_GAME", {})

    -- 按反向层级销毁Skill
    for layer = 4, 0, -1 do
        for _, skillInfo in ipairs(MainGameSkill.SKILL_REGISTRY) do
            if skillInfo.layer == layer then
                local skill = MainGameSkill.subSkills[skillInfo.name]
                if skill and skill.destroy then
                    skill.destroy()
                end
            end
        end
    end
end

-- 获取指定Skill
function MainGameSkill.getSkill(name)
    return MainGameSkill.subSkills[name]
end

-- 热重载Skill（开发调试用）
function MainGameSkill.hotReload(skillName)
    print("[MainGameSkill] 热重载: " .. skillName)
    local skill = MainGameSkill.subSkills[skillName]
    if skill and skill.destroy then
        skill.destroy()
    end

    package.loaded[skillName] = nil
    local newSkill = require(MainGameSkill._getPath(skillName))
    MainGameSkill.subSkills[skillName] = newSkill

    if newSkill.init then
        newSkill.init(ConfigSkill.get("game", skillName, {}))
    end

    EventBusSkill.emit("SKILL_HOT_RELOADED", { name = skillName })
    print("[MainGameSkill] 热重载完成: " .. skillName)
end

function MainGameSkill._getPath(name)
    for _, info in ipairs(MainGameSkill.SKILL_REGISTRY) do
        if info.name == name then
            return info.path
        end
    end
    return nil
end

return MainGameSkill
```

### 12.6 Skill开发最佳实践

#### 1. 单一职责原则
每个Skill只负责一个明确的系统功能，避免功能混杂。

```lua
-- ❌ 错误：一个Skill做太多事情
local BadSkill = {
    -- 同时处理战斗、背包、UI...
}

-- ✅ 正确：拆分为多个专注的Skill
local CombatSkill = { -- 只处理战斗 }
local InventorySkill = { -- 只处理背包 }
local UISkill = { -- 只处理UI }
```

#### 2. 事件驱动通信
Skill之间不直接调用，通过EventBus解耦。

```lua
-- ❌ 错误：直接依赖其他Skill
function CombatSkill.onEnemyDied(enemy)
    InventorySkill.addItem(enemy.dropItem) -- 直接调用
    UISkill.showLoot(enemy.dropItem)      -- 直接调用
end

-- ✅ 正确：通过事件通信
function CombatSkill.onEnemyDied(enemy)
    EventBusSkill.emit("ENTITY_DIED", {
        entity = enemy,
        drops = enemy.drops,
        killer = enemy.lastAttacker
    })
    -- InventorySkill和UISkill各自监听ENTITY_DIED事件
end
```

#### 3. 配置驱动设计
将可变数据提取到配置表，逻辑代码保持通用。

```lua
-- ❌ 错误：硬编码数值
function calculateDamage()
    return 100 * 1.5 -- 伤害数值写死在代码里
end

-- ✅ 正确：从配置读取
function calculateDamage(skillId, level)
    local config = ConfigSkill.get("skills", skillId)
    local baseDamage = config.damage[level] or config.damage[1]
    return baseDamage * (1 + (level - 1) * config.levelScaling)
end
```

#### 4. 状态隔离
每个Skill管理自己的状态，不直接修改其他Skill的状态。

```lua
-- ❌ 错误：直接修改其他Skill状态
function QuestSkill.completeQuest(questId)
    PlayerSkill.exp = PlayerSkill.exp + 100 -- 直接修改
end

-- ✅ 正确：通过事件通知
function QuestSkill.completeQuest(questId)
    EventBusSkill.emit("QUEST_COMPLETED", {
        questId = questId,
        rewards = { exp = 100 }
    })
    -- PlayerSkill监听QUEST_COMPLETED事件，自行处理经验增加
end
```

#### 5. 完善的错误处理
所有对外接口都要有错误返回值，内部使用pcall保护。

```lua
function SkillName.publicFunction(params)
    -- 参数校验
    if not params or not params.requiredField then
        return false, nil, "缺少必要参数: requiredField"
    end

    -- 内部逻辑用pcall保护
    local success, result, err = pcall(function()
        -- 核心逻辑
        return doSomething(params)
    end)

    if not success then
        EventBusSkill.emit("SYSTEM_ERROR", {
            source = "SkillName.publicFunction",
            error = result
        })
        return false, nil, "内部错误: " .. tostring(result)
    end

    return true, result, nil
end
```

#### 6. 完整的生命周期管理
每个Skill必须有init和destroy，正确注册和注销事件监听。

```lua
local MySkill = {
    eventListeners = {}, -- 记录所有注册的事件监听
}

function MySkill.init(config)
    -- 注册事件时记录引用
    local listener1 = function(data) ... end
    EventBusSkill.on("EVENT_NAME", listener1)
    table.insert(MySkill.eventListeners, { event = "EVENT_NAME", callback = listener1 })

    -- 或者使用闭包但确保能正确注销
end

function MySkill.destroy()
    -- 注销所有事件监听
    for _, listener in ipairs(MySkill.eventListeners) do
        EventBusSkill.off(listener.event, listener.callback)
    end
    MySkill.eventListeners = {}

    -- 清理状态
    MySkill.state = {}
end
```

#### 7. 版本兼容性
Skill更新时保持向后兼容，或明确标记破坏性变更。

```lua
local MySkill = {
    VERSION = "2.0.0", -- MAJOR版本变更表示不兼容
    -- 提供兼容层
    legacyAPI = {
        oldFunctionName = function(...) 
            -- 调用新API
            return MySkill.newFunctionName(...)
        end
    }
}
```

### 12.7 Skill性能优化指南

#### 事件队列优化
```lua
-- 批量处理事件，避免每帧多次遍历
function EventBusSkill.processQueue()
    if EventBusSkill.isProcessing then return end
    EventBusSkill.isProcessing = true

    -- 一次性处理所有队列中的事件
    local queue = EventBusSkill.eventQueue
    EventBusSkill.eventQueue = {} -- 清空队列

    for _, event in ipairs(queue) do
        EventBusSkill._processEvent(event.eventName, event.data)
    end

    EventBusSkill.isProcessing = false
end
```

#### 对象池优化
```lua
-- 使用对象池避免频繁创建/销毁
local ObjectPool = {
    pools = {},
}

function ObjectPool.get(poolName, createFunc)
    if not ObjectPool.pools[poolName] then
        ObjectPool.pools[poolName] = {}
    end

    local pool = ObjectPool.pools[poolName]
    if #pool > 0 then
        return table.remove(pool)
    else
        return createFunc()
    end
end

function ObjectPool.recycle(poolName, obj, resetFunc)
    if resetFunc then resetFunc(obj) end
    if not ObjectPool.pools[poolName] then
        ObjectPool.pools[poolName] = {}
    end
    table.insert(ObjectPool.pools[poolName], obj)
end
```

#### 配置缓存
```lua
-- 缓存配置读取结果，避免重复解析
local ConfigCache = {
    cache = {},
    maxSize = 100,
}

function ConfigCache.get(category, key)
    local cacheKey = category .. ":" .. key
    if ConfigCache.cache[cacheKey] then
        return ConfigCache.cache[cacheKey].value
    end

    local value = ConfigSkill.get(category, key)
    ConfigCache.cache[cacheKey] = {
        value = value,
        timestamp = os.time()
    }

    -- 清理过期缓存
    if #ConfigCache.cache > ConfigCache.maxSize then
        ConfigCache._cleanup()
    end

    return value
end
```


---

## 13. 通过Skill完善已有游戏功能

本章节展示如何将 Skill 开发模式应用于**已有游戏项目的增量开发**——无论是将现有代码重构为 Skill 模块，还是通过新增 Skill 来完善游戏某个子系统的功能。

### 13.1 场景分析：何时使用 Skill 完善已有功能

| 场景类型 | 描述 | 适用策略 |
|---------|------|---------|
| **功能增强** | 已有系统基础可用，需要增加新特性 | 新增专注 Skill，通过 EventBus 接入 |
| **代码重构** | 现有代码耦合严重，难以维护 | 逐步拆分为独立 Skill 模块 |
| **Bug修复** | 现有功能有缺陷，需要修复 | 提取问题模块为 Skill，独立测试修复 |
| **性能优化** | 现有系统性能不足 | 替换为优化版 Skill，保持接口兼容 |
| **跨项目复用** | 在多个项目中使用相同功能 | 将功能封装为独立 Skill，通过本合并器复用 |
| **A/B测试** | 测试不同实现方案 | 开发多个版本的 Skill，运行时切换 |

### 13.2 实战：为已有游戏添加存档系统

#### 现状分析

假设你有一个已有的 RPG 游戏，战斗、背包、任务系统都已经写好，但**没有存档功能**。玩家每次退出游戏都要从头开始。

**现有代码结构**：
```lua
-- 现有游戏代码（未Skill化）
local Game = {
    player = { hp = 100, mp = 50, level = 1, exp = 0 },
    inventory = {},
    currentScene = "village",
    questProgress = {},
}

function Game.saveGame()
    -- ❌ 没有实现，或者写死在Game模块里
end
```

#### 方案：开发 SaveLoadSkill 接入现有系统

**核心思路**：不修改现有游戏的核心逻辑，而是通过 **EventBus + 数据快照** 的方式，让 SaveLoadSkill 监听游戏状态变化，在存档时收集所有需要保存的数据。

**步骤1：定义存档数据结构**

```lua
-- save_schema.lua（存档数据结构定义）
--[[
    存档数据结构 - 定义每个系统需要保存的数据
    SaveLoadSkill 会根据这个结构自动收集和恢复数据
--]]

local SaveSchema = {
    VERSION = 1, -- 存档格式版本，用于兼容性处理

    -- 定义每个模块的存档数据
    modules = {
        player = {
            -- 玩家基础属性
            fields = {
                "hp", "mp", "maxHp", "maxMp",
                "level", "exp", "nextLevelExp",
                "strength", "agility", "intelligence",
                "gold", "position", "currentScene"
            },
            -- 获取数据的接口
            getter = function()
                return {
                    hp = Game.player.hp,
                    mp = Game.player.mp,
                    maxHp = Game.player.maxHp,
                    maxMp = Game.player.maxMp,
                    level = Game.player.level,
                    exp = Game.player.exp,
                    nextLevelExp = Game.player.nextLevelExp,
                    strength = Game.player.strength,
                    agility = Game.player.agility,
                    intelligence = Game.player.intelligence,
                    gold = Game.player.gold,
                    position = { x = Game.player.x, y = Game.player.y },
                    currentScene = Game.currentScene,
                }
            end,
            -- 恢复数据的接口
            setter = function(data)
                Game.player.hp = data.hp
                Game.player.mp = data.mp
                Game.player.maxHp = data.maxHp
                Game.player.maxMp = data.maxMp
                Game.player.level = data.level
                Game.player.exp = data.exp
                Game.player.nextLevelExp = data.nextLevelExp
                Game.player.strength = data.strength
                Game.player.agility = data.agility
                Game.player.intelligence = data.intelligence
                Game.player.gold = data.gold
                Game.player.x = data.position.x
                Game.player.y = data.position.y
                Game.currentScene = data.currentScene
            end,
        },

        inventory = {
            fields = { "items", "equipped", "quickBar" },
            getter = function()
                return {
                    items = Game.inventory.items,
                    equipped = Game.inventory.equipped,
                    quickBar = Game.inventory.quickBar,
                }
            end,
            setter = function(data)
                Game.inventory.items = data.items or {}
                Game.inventory.equipped = data.equipped or {}
                Game.inventory.quickBar = data.quickBar or {}
            end,
        },

        quests = {
            fields = { "activeQuests", "completedQuests", "trackedQuests" },
            getter = function()
                return {
                    activeQuests = Game.questSystem.activeQuests,
                    completedQuests = Game.questSystem.completedQuests,
                    trackedQuests = Game.questSystem.trackedQuests,
                }
            end,
            setter = function(data)
                Game.questSystem.activeQuests = data.activeQuests or {}
                Game.questSystem.completedQuests = data.completedQuests or {}
                Game.questSystem.trackedQuests = data.trackedQuests or {}
            end,
        },

        world = {
            fields = { "unlockedAreas", "discoveredLocations", "npcStates", "chestStates" },
            getter = function()
                return {
                    unlockedAreas = Game.world.unlockedAreas,
                    discoveredLocations = Game.world.discoveredLocations,
                    npcStates = Game.world.npcStates,
                    chestStates = Game.world.chestStates,
                }
            end,
            setter = function(data)
                Game.world.unlockedAreas = data.unlockedAreas or {}
                Game.world.discoveredLocations = data.discoveredLocations or {}
                Game.world.npcStates = data.npcStates or {}
                Game.world.chestStates = data.chestStates or {}
            end,
        },

        settings = {
            fields = { "volume", "difficulty", "language", "keyBindings" },
            getter = function()
                return {
                    volume = Game.settings.volume,
                    difficulty = Game.settings.difficulty,
                    language = Game.settings.language,
                    keyBindings = Game.settings.keyBindings,
                }
            end,
            setter = function(data)
                Game.settings.volume = data.volume or 1.0
                Game.settings.difficulty = data.difficulty or "normal"
                Game.settings.language = data.language or "zh"
                Game.settings.keyBindings = data.keyBindings or {}
            end,
        },
    },
}

return SaveSchema
```

**步骤2：开发 SaveLoadSkill**

```lua
--[[
    Skill: SaveLoadSkill
    版本: 1.0.0
    层级: Layer 2（系统层）
    依赖: EventBusSkill, ConfigSkill
    功能: 存档读档系统 - 支持多存档槽位、自动存档、云端同步

    适用场景: 为已有游戏添加存档功能，无需修改现有代码结构
--]]

local SaveLoadSkill = {
    VERSION = "1.0.0",

    CONFIG = {
        maxSaveSlots = 10,           -- 最大存档槽位
        autoSaveInterval = 300,      -- 自动存档间隔（秒）
        autoSaveOnSceneChange = true, -- 切换场景时自动存档
        autoSaveOnImportantEvent = true, -- 重要事件后自动存档
        cloudSyncEnabled = false,     -- 是否启用云端同步
        compressionEnabled = true,    -- 是否压缩存档数据
        encryptionEnabled = false,    -- 是否加密存档
        backupCount = 3,             -- 每个存档保留的备份数量
    },

    state = {
        saveSlots = {},              -- 存档槽位数据 {slotIndex, saveData}
        lastSaveTime = 0,            -- 上次存档时间
        lastAutoSaveTime = 0,        -- 上次自动存档时间
        isSaving = false,            -- 是否正在存档中
        isLoading = false,           -- 是否正在读档中
        currentSlot = 1,             -- 当前使用的存档槽位
        saveSchema = nil,            -- 存档数据结构
    },

    -- 重要事件列表（触发自动存档）
    IMPORTANT_EVENTS = {
        "BOSS_DEFEATED",
        "QUEST_COMPLETED",
        "LEVEL_UP",
        "RARE_ITEM_OBTAINED",
        "STORY_MILESTONE",
    },
}

function SaveLoadSkill.init(config)
    if config then
        for k, v in pairs(config) do
            SaveLoadSkill.CONFIG[k] = v
        end
    end

    -- 加载存档数据结构
    SaveLoadSkill.state.saveSchema = require("save_schema")

    -- 加载存档索引（存档列表信息，不包含完整数据）
    SaveLoadSkill._loadSaveIndex()

    -- 注册事件监听
    EventBusSkill.on("SAVE_GAME", SaveLoadSkill._onSaveGame)
    EventBusSkill.on("LOAD_GAME", SaveLoadSkill._onLoadGame)
    EventBusSkill.on("SCENE_LOAD_COMPLETE", SaveLoadSkill._onSceneChanged)
    EventBusSkill.on("GAME_QUIT", SaveLoadSkill._onGameQuit)

    -- 注册重要事件监听（自动存档）
    for _, eventName in ipairs(SaveLoadSkill.IMPORTANT_EVENTS) do
        EventBusSkill.on(eventName, SaveLoadSkill._onImportantEvent)
    end

    -- 注册输入监听（快速存档/读档）
    EventBusSkill.on("INPUT_ACTION", SaveLoadSkill._onInputAction)

    print("[SaveLoadSkill] 初始化完成，存档槽位: " .. SaveLoadSkill.CONFIG.maxSaveSlots)
end

-- ==================== 核心功能：存档 ====================

-- 保存到指定槽位
-- @param slotIndex: 存档槽位（1-maxSaveSlots），nil表示当前槽位
-- @param saveName: 存档名称（可选）
-- @param isAutoSave: 是否为自动存档
-- @return success: boolean, saveInfo: table|nil
function SaveLoadSkill.save(slotIndex, saveName, isAutoSave)
    if SaveLoadSkill.state.isSaving then
        return false, nil, "正在存档中，请稍后再试"
    end

    slotIndex = slotIndex or SaveLoadSkill.state.currentSlot
    if slotIndex < 1 or slotIndex > SaveLoadSkill.CONFIG.maxSaveSlots then
        return false, nil, "存档槽位超出范围"
    end

    SaveLoadSkill.state.isSaving = true

    local startTime = os.clock()

    -- 1. 收集所有模块数据
    local saveData = {
        version = SaveLoadSkill.state.saveSchema.VERSION,
        timestamp = os.time(),
        playTime = SaveLoadSkill._getTotalPlayTime(),
        slotIndex = slotIndex,
        saveName = saveName or (isAutoSave and "自动存档" or "存档 " .. slotIndex),
        isAutoSave = isAutoSave or false,
        modules = {},
    }

    -- 遍历存档结构定义，收集各模块数据
    for moduleName, moduleSchema in pairs(SaveLoadSkill.state.saveSchema.modules) do
        if moduleSchema.getter then
            local success, moduleData = pcall(moduleSchema.getter)
            if success then
                saveData.modules[moduleName] = moduleData
            else
                print("[SaveLoadSkill] 警告: 收集模块 '" .. moduleName .. "' 数据失败: " .. tostring(moduleData))
                saveData.modules[moduleName] = {} -- 保存空数据，避免读档失败
            end
        end
    end

    -- 2. 压缩数据（可选）
    local finalData = saveData
    if SaveLoadSkill.CONFIG.compressionEnabled then
        finalData = SaveLoadSkill._compressData(saveData)
    end

    -- 3. 加密数据（可选）
    if SaveLoadSkill.CONFIG.encryptionEnabled then
        finalData = SaveLoadSkill._encryptData(finalData)
    end

    -- 4. 创建备份
    SaveLoadSkill._createBackup(slotIndex)

    -- 5. 写入存档文件
    local savePath = SaveLoadSkill._getSavePath(slotIndex)
    local writeSuccess = SaveLoadSkill._writeFile(savePath, finalData)

    if not writeSuccess then
        SaveLoadSkill.state.isSaving = false
        return false, nil, "存档文件写入失败"
    end

    -- 6. 更新存档索引
    SaveLoadSkill.state.saveSlots[slotIndex] = {
        slotIndex = slotIndex,
        saveName = saveData.saveName,
        timestamp = saveData.timestamp,
        playTime = saveData.playTime,
        isAutoSave = saveData.isAutoSave,
        scene = saveData.modules.player and saveData.modules.player.currentScene or "unknown",
        level = saveData.modules.player and saveData.modules.player.level or 1,
        fileSize = SaveLoadSkill._getFileSize(savePath),
    }

    SaveLoadSkill._saveSaveIndex()

    local saveTime = os.clock() - startTime
    SaveLoadSkill.state.lastSaveTime = os.time()
    SaveLoadSkill.state.isSaving = false

    -- 发送存档完成事件
    EventBusSkill.emit("SAVE_COMPLETE", {
        slotIndex = slotIndex,
        saveName = saveData.saveName,
        duration = saveTime,
        fileSize = SaveLoadSkill.state.saveSlots[slotIndex].fileSize,
    })

    print(string.format("[SaveLoadSkill] 存档完成: 槽位%d, 耗时%.3fs, 大小%dKB",
        slotIndex, saveTime, SaveLoadSkill.state.saveSlots[slotIndex].fileSize / 1024))

    return true, SaveLoadSkill.state.saveSlots[slotIndex]
end

-- 快速存档（F5）
function SaveLoadSkill.quickSave()
    return SaveLoadSkill.save(SaveLoadSkill.state.currentSlot, "快速存档", false)
end

-- 自动存档
function SaveLoadSkill.autoSave()
    -- 自动存档使用特殊槽位（最后一个槽位作为自动存档专用）
    local autoSaveSlot = SaveLoadSkill.CONFIG.maxSaveSlots
    return SaveLoadSkill.save(autoSaveSlot, nil, true)
end

-- ==================== 核心功能：读档 ====================

-- 从指定槽位读取存档
-- @param slotIndex: 存档槽位
-- @param showLoadingScreen: 是否显示加载画面
-- @return success: boolean, loadInfo: table|nil
function SaveLoadSkill.load(slotIndex, showLoadingScreen)
    if SaveLoadSkill.state.isLoading then
        return false, nil, "正在读档中"
    end

    slotIndex = slotIndex or SaveLoadSkill.state.currentSlot
    if slotIndex < 1 or slotIndex > SaveLoadSkill.CONFIG.maxSaveSlots then
        return false, nil, "存档槽位超出范围"
    end

    local savePath = SaveLoadSkill._getSavePath(slotIndex)

    -- 检查存档是否存在
    if not SaveLoadSkill._fileExists(savePath) then
        return false, nil, "存档不存在"
    end

    SaveLoadSkill.state.isLoading = true

    if showLoadingScreen then
        EventBusSkill.emit("SHOW_LOADING_SCREEN", { progress = 0 })
    end

    local startTime = os.clock()

    -- 1. 读取存档文件
    local fileData = SaveLoadSkill._readFile(savePath)
    if not fileData then
        SaveLoadSkill.state.isLoading = false
        return false, nil, "存档文件读取失败"
    end

    if showLoadingScreen then
        EventBusSkill.emit("SHOW_LOADING_SCREEN", { progress = 20 })
    end

    -- 2. 解密数据（可选）
    if SaveLoadSkill.CONFIG.encryptionEnabled then
        fileData = SaveLoadSkill._decryptData(fileData)
    end

    -- 3. 解压数据（可选）
    if SaveLoadSkill.CONFIG.compressionEnabled then
        fileData = SaveLoadSkill._decompressData(fileData)
    end

    if showLoadingScreen then
        EventBusSkill.emit("SHOW_LOADING_SCREEN", { progress = 40 })
    end

    -- 4. 验证存档版本
    if not fileData.version then
        SaveLoadSkill.state.isLoading = false
        return false, nil, "存档格式无效"
    end

    if fileData.version > SaveLoadSkill.state.saveSchema.VERSION then
        SaveLoadSkill.state.isLoading = false
        return false, nil, "存档版本过高，请更新游戏"
    end

    -- 5. 版本兼容性处理
    if fileData.version < SaveLoadSkill.state.saveSchema.VERSION then
        fileData = SaveLoadSkill._migrateSaveData(fileData, fileData.version, SaveLoadSkill.state.saveSchema.VERSION)
    end

    if showLoadingScreen then
        EventBusSkill.emit("SHOW_LOADING_SCREEN", { progress = 60 })
    end

    -- 6. 恢复各模块数据
    local restoredModules = {}
    local totalModules = 0
    local successModules = 0

    for moduleName, moduleData in pairs(fileData.modules or {}) do
        totalModules = totalModules + 1
        local moduleSchema = SaveLoadSkill.state.saveSchema.modules[moduleName]

        if moduleSchema and moduleSchema.setter then
            local success, err = pcall(function()
                moduleSchema.setter(moduleData)
            end)

            if success then
                successModules = successModules + 1
                restoredModules[moduleName] = true
            else
                print("[SaveLoadSkill] 警告: 恢复模块 '" .. moduleName .. "' 失败: " .. tostring(err))
                restoredModules[moduleName] = false
            end
        end
    end

    if showLoadingScreen then
        EventBusSkill.emit("SHOW_LOADING_SCREEN", { progress = 80 })
    end

    -- 7. 更新当前槽位
    SaveLoadSkill.state.currentSlot = slotIndex

    -- 8. 发送读档完成事件
    EventBusSkill.emit("LOAD_COMPLETE", {
        slotIndex = slotIndex,
        restoredModules = restoredModules,
        successCount = successModules,
        totalCount = totalModules,
    })

    -- 9. 加载场景
    local playerModule = fileData.modules and fileData.modules.player
    if playerModule and playerModule.currentScene then
        EventBusSkill.emit("SCENE_LOAD_REQUEST", {
            sceneName = playerModule.currentScene,
            isLoadGame = true,
        })
    end

    if showLoadingScreen then
        EventBusSkill.emit("SHOW_LOADING_SCREEN", { progress = 100 })
        EventBusSkill.emit("HIDE_LOADING_SCREEN", {})
    end

    local loadTime = os.clock() - startTime
    SaveLoadSkill.state.isLoading = false

    print(string.format("[SaveLoadSkill] 读档完成: 槽位%d, 耗时%.3fs, 恢复%d/%d模块",
        slotIndex, loadTime, successModules, totalModules))

    return true, {
        slotIndex = slotIndex,
        restoredModules = restoredModules,
        loadTime = loadTime,
    }
end

-- 快速读档（F9）
function SaveLoadSkill.quickLoad()
    return SaveLoadSkill.load(SaveLoadSkill.state.currentSlot, true)
end

-- ==================== 存档管理 ====================

-- 获取存档列表
function SaveLoadSkill.getSaveList()
    local list = {}
    for i = 1, SaveLoadSkill.CONFIG.maxSaveSlots do
        if SaveLoadSkill.state.saveSlots[i] then
            table.insert(list, SaveLoadSkill.state.saveSlots[i])
        end
    end
    return list
end

-- 删除存档
function SaveLoadSkill.deleteSave(slotIndex)
    if slotIndex < 1 or slotIndex > SaveLoadSkill.CONFIG.maxSaveSlots then
        return false, "存档槽位超出范围"
    end

    local savePath = SaveLoadSkill._getSavePath(slotIndex)
    SaveLoadSkill._deleteFile(savePath)

    -- 删除备份
    for i = 1, SaveLoadSkill.CONFIG.backupCount do
        local backupPath = savePath .. ".backup" .. i
        SaveLoadSkill._deleteFile(backupPath)
    end

    SaveLoadSkill.state.saveSlots[slotIndex] = nil
    SaveLoadSkill._saveSaveIndex()

    EventBusSkill.emit("SAVE_DELETED", { slotIndex = slotIndex })

    return true
end

-- 复制存档
function SaveLoadSkill.copySave(fromSlot, toSlot)
    if fromSlot == toSlot then
        return false, "源槽位和目标槽位相同"
    end

    local fromPath = SaveLoadSkill._getSavePath(fromSlot)
    if not SaveLoadSkill._fileExists(fromPath) then
        return false, "源存档不存在"
    end

    local toPath = SaveLoadSkill._getSavePath(toSlot)
    SaveLoadSkill._copyFile(fromPath, toPath)

    -- 复制索引信息
    SaveLoadSkill.state.saveSlots[toSlot] = SaveLoadSkill.state.saveSlots[fromSlot] and 
        SaveLoadSkill._deepCopy(SaveLoadSkill.state.saveSlots[fromSlot]) or nil
    if SaveLoadSkill.state.saveSlots[toSlot] then
        SaveLoadSkill.state.saveSlots[toSlot].slotIndex = toSlot
    end

    SaveLoadSkill._saveSaveIndex()

    return true
end

-- 获取存档详细信息
function SaveLoadSkill.getSaveInfo(slotIndex)
    return SaveLoadSkill.state.saveSlots[slotIndex]
end

-- ==================== 私有方法 ====================

-- 获取存档文件路径
function SaveLoadSkill._getSavePath(slotIndex)
    return "saves/save_" .. slotIndex .. ".dat"
end

-- 加载存档索引
function SaveLoadSkill._loadSaveIndex()
    local indexPath = "saves/save_index.json"
    if SaveLoadSkill._fileExists(indexPath) then
        local data = SaveLoadSkill._readFile(indexPath)
        if data and data.slots then
            SaveLoadSkill.state.saveSlots = data.slots
        end
    end
end

-- 保存存档索引
function SaveLoadSkill._saveSaveIndex()
    local indexPath = "saves/save_index.json"
    local data = { slots = SaveLoadSkill.state.saveSlots }
    SaveLoadSkill._writeFile(indexPath, data)
end

-- 创建备份
function SaveLoadSkill._createBackup(slotIndex)
    local savePath = SaveLoadSkill._getSavePath(slotIndex)
    if not SaveLoadSkill._fileExists(savePath) then
        return
    end

    -- 轮转备份
    for i = SaveLoadSkill.CONFIG.backupCount, 2, -1 do
        local from = savePath .. ".backup" .. (i - 1)
        local to = savePath .. ".backup" .. i
        if SaveLoadSkill._fileExists(from) then
            SaveLoadSkill._moveFile(from, to)
        end
    end

    -- 创建最新备份
    SaveLoadSkill._copyFile(savePath, savePath .. ".backup1")
end

-- 获取总游戏时长
function SaveLoadSkill._getTotalPlayTime()
    -- 从玩家数据或全局统计中获取
    return Game.stats and Game.stats.totalPlayTime or 0
end

-- 数据压缩
function SaveLoadSkill._compressData(data)
    -- 使用TapTap制造引擎提供的压缩API
    -- 或者使用简单的Lua序列化压缩
    local jsonStr = json.encode(data)
    -- 这里可以接入实际的压缩算法
    return { compressed = true, data = jsonStr }
end

-- 数据解压
function SaveLoadSkill._decompressData(data)
    if data.compressed then
        return json.decode(data.data)
    end
    return data
end

-- 数据加密
function SaveLoadSkill._encryptData(data)
    -- 使用TapTap制造引擎提供的加密API
    -- 或者使用简单的异或加密
    return { encrypted = true, data = data }
end

-- 数据解密
function SaveLoadSkill._decryptData(data)
    if data.encrypted then
        return data.data
    end
    return data
end

-- 存档数据迁移（版本兼容性）
function SaveLoadSkill._migrateSaveData(data, fromVersion, toVersion)
    -- 定义迁移规则
    local migrations = {
        [1] = function(d)
            -- v1 -> v2 的迁移
            -- 例如：新增了一个模块，给旧存档补充默认值
            if not d.modules.settings then
                d.modules.settings = {
                    volume = 1.0,
                    difficulty = "normal",
                    language = "zh",
                }
            end
            return d
        end,
        [2] = function(d)
            -- v2 -> v3 的迁移
            return d
        end,
    }

    for v = fromVersion, toVersion - 1 do
        if migrations[v] then
            data = migrations[v](data)
        end
    end

    data.version = toVersion
    return data
end

-- 文件操作封装
function SaveLoadSkill._fileExists(path)
    -- TapTap制造引擎文件API
    return FileSystem.exists(path)
end

function SaveLoadSkill._writeFile(path, data)
    -- 确保目录存在
    FileSystem.createDirectory("saves")
    return FileSystem.write(path, json.encode(data))
end

function SaveLoadSkill._readFile(path)
    local content = FileSystem.read(path)
    if content then
        return json.decode(content)
    end
    return nil
end

function SaveLoadSkill._deleteFile(path)
    FileSystem.delete(path)
end

function SaveLoadSkill._copyFile(from, to)
    FileSystem.copy(from, to)
end

function SaveLoadSkill._moveFile(from, to)
    FileSystem.move(from, to)
end

function SaveLoadSkill._getFileSize(path)
    return FileSystem.getSize(path) or 0
end

-- 深拷贝
function SaveLoadSkill._deepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in next, orig, nil do
            copy[SaveLoadSkill._deepCopy(k)] = SaveLoadSkill._deepCopy(v)
        end
        setmetatable(copy, SaveLoadSkill._deepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- ==================== 事件处理 ====================

function SaveLoadSkill._onSaveGame(data)
    -- 响应外部存档请求
    SaveLoadSkill.save(data.slotIndex, data.saveName, data.isAutoSave)
end

function SaveLoadSkill._onLoadGame(data)
    -- 响应外部读档请求
    SaveLoadSkill.load(data.slotIndex, data.showLoadingScreen)
end

function SaveLoadSkill._onSceneChanged(data)
    -- 场景切换时自动存档
    if SaveLoadSkill.CONFIG.autoSaveOnSceneChange then
        SaveLoadSkill.autoSave()
    end
end

function SaveLoadSkill._onImportantEvent(data)
    -- 重要事件后自动存档
    if SaveLoadSkill.CONFIG.autoSaveOnImportantEvent then
        SaveLoadSkill.autoSave()
    end
end

function SaveLoadSkill._onGameQuit(data)
    -- 退出游戏前自动存档
    SaveLoadSkill.autoSave()
end

function SaveLoadSkill._onInputAction(data)
    -- 快速存档/读档快捷键
    if data.action == "QUICK_SAVE" then
        SaveLoadSkill.quickSave()
    elseif data.action == "QUICK_LOAD" then
        SaveLoadSkill.quickLoad()
    end
end

-- 每帧更新（处理自动存档计时）
function SaveLoadSkill.update(dt)
    -- 自动存档计时
    if SaveLoadSkill.CONFIG.autoSaveInterval > 0 then
        SaveLoadSkill.state.lastAutoSaveTime = SaveLoadSkill.state.lastAutoSaveTime + dt
        if SaveLoadSkill.state.lastAutoSaveTime >= SaveLoadSkill.CONFIG.autoSaveInterval then
            SaveLoadSkill.state.lastAutoSaveTime = 0
            SaveLoadSkill.autoSave()
        end
    end
end

function SaveLoadSkill.destroy()
    EventBusSkill.off("SAVE_GAME", SaveLoadSkill._onSaveGame)
    EventBusSkill.off("LOAD_GAME", SaveLoadSkill._onLoadGame)
    EventBusSkill.off("SCENE_LOAD_COMPLETE", SaveLoadSkill._onSceneChanged)
    EventBusSkill.off("GAME_QUIT", SaveLoadSkill._onGameQuit)

    for _, eventName in ipairs(SaveLoadSkill.IMPORTANT_EVENTS) do
        EventBusSkill.off(eventName, SaveLoadSkill._onImportantEvent)
    end

    EventBusSkill.off("INPUT_ACTION", SaveLoadSkill._onInputAction)

    print("[SaveLoadSkill] 已销毁")
end

return SaveLoadSkill
```

**步骤3：接入现有游戏**

```lua
-- 在游戏的初始化代码中加入SaveLoadSkill

-- 原有游戏初始化
function Game.init()
    -- ... 原有初始化代码 ...

    -- 新增：初始化SaveLoadSkill
    local SaveLoadSkill = require("Skills/SaveLoadSkill")
    SaveLoadSkill.init({
        maxSaveSlots = 10,
        autoSaveInterval = 300, -- 5分钟自动存档
        autoSaveOnSceneChange = true,
        autoSaveOnImportantEvent = true,
    })

    -- 注册到主Skill管理器
    Game.subSkills = Game.subSkills or {}
    Game.subSkills.SaveLoadSkill = SaveLoadSkill

    print("[Game] 存档系统已接入")
end

-- 在游戏主循环中更新SaveLoadSkill
function Game.update(dt)
    -- ... 原有更新代码 ...

    -- 新增：更新SaveLoadSkill（用于自动存档计时）
    if Game.subSkills.SaveLoadSkill and Game.subSkills.SaveLoadSkill.update then
        Game.subSkills.SaveLoadSkill.update(dt)
    end
end
```

**关键设计要点**：
1. **零侵入**：SaveLoadSkill 不修改任何现有代码，只通过 `getter/setter` 接口读写数据
2. **声明式配置**：通过 `save_schema.lua` 声明哪些数据需要保存，新增系统只需在 schema 中注册即可
3. **版本兼容**：存档格式版本管理，自动迁移旧版本存档
4. **自动存档**：支持定时、场景切换、重要事件触发自动存档
5. **多槽位**：支持多个存档槽位、备份、复制、删除

---

### 13.3 实战：为已有战斗系统添加连击评分系统

#### 现状分析

已有游戏有一个基础的实时战斗系统，可以攻击、受击、死亡。但**缺少战斗反馈和评分机制**，玩家无法感受到战斗的爽快感。

**现有代码**：
```lua
-- 现有战斗系统（简化版）
local CombatSystem = {
    player = nil,
    enemies = {},
}

function CombatSystem.attack(target)
    local damage = CombatSystem.player.attack - target.defense
    target.hp = target.hp - damage

    -- ❌ 只有简单的伤害数字，没有连击、评分等反馈
    FloatingText.show(damage, target.x, target.y)

    if target.hp <= 0 then
        target:die()
    end
end
```

#### 方案：开发 ComboScoreSkill 增强战斗反馈

**核心思路**：不修改 CombatSystem 的核心逻辑，而是通过监听战斗事件，在**表现层**叠加连击评分系统。

```lua
--[[
    Skill: ComboScoreSkill
    版本: 1.0.0
    层级: Layer 4（表现层）
    依赖: EventBusSkill, UISkill, AudioSkill
    功能: 连击评分系统 - 为已有战斗系统添加连击、评分、风格等级

    适用场景: 已有战斗系统，需要增强战斗反馈和爽快感
--]]

local ComboScoreSkill = {
    VERSION = "1.0.0",

    CONFIG = {
        comboWindow = 3.0,           -- 连击窗口时间（秒）
        maxComboDisplay = 999,       -- 最大显示连击数
        styleRankDecay = 5.0,        -- 风格等级衰减时间（秒）

        -- 评分权重
        scoreWeights = {
            damage = 10,             -- 每点伤害的基础分
            kill = 500,              -- 击杀加分
            airHit = 200,            -- 空中连击加分
            variety = 100,           -- 招式多样性加分
            noDamage = 1000,         -- 无伤加分
            speed = 50,              -- 快速击杀加分
        },

        -- 风格等级阈值
        styleRanks = {
            { name = "D", minScore = 0, color = "#888888" },
            { name = "C", minScore = 1000, color = "#4ade80" },
            { name = "B", minScore = 3000, color = "#60a5fa" },
            { name = "A", minScore = 6000, color = "#a78bfa" },
            { name = "S", minScore = 10000, color = "#fbbf24" },
            { name = "SS", minScore = 15000, color = "#f97316" },
            { name = "SSS", minScore = 25000, color = "#ef4444" },
        },

        -- 连击语音触发阈值
        comboVoiceThresholds = { 10, 25, 50, 100 },
    },

    state = {
        comboCount = 0,              -- 当前连击数
        comboTimer = 0,              -- 连击计时器
        totalScore = 0,              -- 当前战斗总评分
        currentRank = "D",           -- 当前风格等级
        rankTimer = 0,               -- 风格等级计时器

        -- 统计
        battleStats = {
            maxCombo = 0,
            totalDamage = 0,
            killCount = 0,
            hitCount = 0,
            skillVariety = {},         -- 使用的技能种类
            startTime = 0,
            lastHitTime = 0,
            tookDamage = false,
        },

        -- 显示状态
        isDisplaying = false,
        displayTimer = 0,
        lastVoiceCombo = 0,
    },
}

function ComboScoreSkill.init(config)
    if config then
        for k, v in pairs(config) do
            ComboScoreSkill.CONFIG[k] = v
        end
    end

    -- 注册战斗事件监听
    EventBusSkill.on("DAMAGE_DEALT", ComboScoreSkill._onDamageDealt)
    EventBusSkill.on("ENTITY_DIED", ComboScoreSkill._onEntityDied)
    EventBusSkill.on("ENTITY_DAMAGED", ComboScoreSkill._onPlayerDamaged)
    EventBusSkill.on("COMBAT_START", ComboScoreSkill._onCombatStart)
    EventBusSkill.on("COMBAT_END", ComboScoreSkill._onCombatEnd)
    EventBusSkill.on("SKILL_CAST_COMPLETE", ComboScoreSkill._onSkillCast)

    print("[ComboScoreSkill] 连击评分系统已初始化")
end

-- ==================== 核心评分逻辑 ====================

function ComboScoreSkill._onCombatStart(data)
    ComboScoreSkill.state.battleStats.startTime = os.clock()
    ComboScoreSkill.state.battleStats.tookDamage = false
    ComboScoreSkill._resetCombo()
    ComboScoreSkill._resetScore()
end

function ComboScoreSkill._onDamageDealt(data)
    -- 更新连击
    ComboScoreSkill.state.comboCount = ComboScoreSkill.state.comboCount + 1
    ComboScoreSkill.state.comboTimer = ComboScoreSkill.CONFIG.comboWindow

    -- 更新统计
    ComboScoreSkill.state.battleStats.hitCount = ComboScoreSkill.state.battleStats.hitCount + 1
    ComboScoreSkill.state.battleStats.totalDamage = ComboScoreSkill.state.battleStats.totalDamage + (data.damage or 0)
    ComboScoreSkill.state.battleStats.lastHitTime = os.clock()

    if ComboScoreSkill.state.comboCount > ComboScoreSkill.state.battleStats.maxCombo then
        ComboScoreSkill.state.battleStats.maxCombo = ComboScoreSkill.state.comboCount
    end

    -- 计算本次攻击得分
    local hitScore = 0

    -- 基础伤害分
    hitScore = hitScore + (data.damage or 0) * ComboScoreSkill.CONFIG.scoreWeights.damage

    -- 连击倍率（连击越高，每次攻击得分倍率越高）
    local comboMultiplier = 1 + (ComboScoreSkill.state.comboCount * 0.1)
    hitScore = hitScore * comboMultiplier

    -- 空中连击加分
    if data.isAirHit then
        hitScore = hitScore + ComboScoreSkill.CONFIG.scoreWeights.airHit
    end

    -- 招式多样性加分
    if data.skillId then
        if not ComboScoreSkill.state.battleStats.skillVariety[data.skillId] then
            ComboScoreSkill.state.battleStats.skillVariety[data.skillId] = true
            hitScore = hitScore + ComboScoreSkill.CONFIG.scoreWeights.variety
        end
    end

    -- 快速击杀加分（3秒内击杀）
    if data.target and data.target.hp and data.target.hp <= 0 then
        local killTime = os.clock() - (data.target.combatStartTime or ComboScoreSkill.state.battleStats.startTime)
        if killTime < 3.0 then
            hitScore = hitScore + ComboScoreSkill.CONFIG.scoreWeights.speed
        end
    end

    ComboScoreSkill.state.totalScore = ComboScoreSkill.state.totalScore + math.floor(hitScore)

    -- 更新风格等级
    ComboScoreSkill._updateRank()

    -- 显示连击UI
    ComboScoreSkill._showComboUI()

    -- 触发连击语音
    ComboScoreSkill._checkComboVoice()

    -- 发送连击事件
    EventBusSkill.emit("COMBO_UPDATED", {
        combo = ComboScoreSkill.state.comboCount,
        score = ComboScoreSkill.state.totalScore,
        rank = ComboScoreSkill.state.currentRank,
        isNewRecord = ComboScoreSkill.state.comboCount > ComboScoreSkill.state.battleStats.maxCombo,
    })
end

function ComboScoreSkill._onEntityDied(data)
    if data.killer and data.killer.isPlayer then
        ComboScoreSkill.state.battleStats.killCount = ComboScoreSkill.state.battleStats.killCount + 1

        -- 击杀加分
        ComboScoreSkill.state.totalScore = ComboScoreSkill.state.totalScore + ComboScoreSkill.CONFIG.scoreWeights.kill

        -- 更新风格等级
        ComboScoreSkill._updateRank()

        EventBusSkill.emit("AUDIO_PLAY", { soundId = "combo_kill" })
    end
end

function ComboScoreSkill._onPlayerDamaged(data)
    if data.entity and data.entity.isPlayer then
        ComboScoreSkill.state.battleStats.tookDamage = true

        -- 受击中断连击（可选：可以改为只减少连击数而不是清零）
        -- ComboScoreSkill._resetCombo()

        -- 或者：受击降低风格等级
        ComboScoreSkill.state.totalScore = math.max(0, ComboScoreSkill.state.totalScore - 500)
        ComboScoreSkill._updateRank()

        EventBusSkill.emit("AUDIO_PLAY", { soundId = "combo_break" })
    end
end

function ComboScoreSkill._onSkillCast(data)
    -- 记录技能使用，用于多样性评分
    if data.skillId then
        ComboScoreSkill.state.battleStats.skillVariety[data.skillId] = true
    end
end

function ComboScoreSkill._onCombatEnd(data)
    -- 战斗结束，计算最终评分
    local finalScore = ComboScoreSkill.state.totalScore

    -- 无伤加分
    if not ComboScoreSkill.state.battleStats.tookDamage then
        finalScore = finalScore + ComboScoreSkill.CONFIG.scoreWeights.noDamage
    end

    -- 显示结算界面
    ComboScoreSkill._showResultScreen(finalScore)

    -- 保存战斗记录
    EventBusSkill.emit("BATTLE_RECORDED", {
        score = finalScore,
        maxCombo = ComboScoreSkill.state.battleStats.maxCombo,
        killCount = ComboScoreSkill.state.battleStats.killCount,
        rank = ComboScoreSkill.state.currentRank,
        duration = os.clock() - ComboScoreSkill.state.battleStats.startTime,
        tookDamage = ComboScoreSkill.state.battleStats.tookDamage,
    })
end

-- ==================== 风格等级系统 ====================

function ComboScoreSkill._updateRank()
    local newRank = "D"
    for _, rankInfo in ipairs(ComboScoreSkill.CONFIG.styleRanks) do
        if ComboScoreSkill.state.totalScore >= rankInfo.minScore then
            newRank = rankInfo.name
        else
            break
        end
    end

    -- 风格等级提升
    if newRank ~= ComboScoreSkill.state.currentRank then
        local oldRank = ComboScoreSkill.state.currentRank
        ComboScoreSkill.state.currentRank = newRank

        -- 播放风格等级提升特效
        EventBusSkill.emit("RANK_UP", {
            oldRank = oldRank,
            newRank = newRank,
            score = ComboScoreSkill.state.totalScore,
        })

        EventBusSkill.emit("AUDIO_PLAY", { 
            soundId = "rank_up_" .. newRank,
            priority = 10 
        })

        -- 显示风格等级UI动画
        ComboScoreSkill._showRankUpAnimation(oldRank, newRank)
    end

    -- 重置风格等级衰减计时
    ComboScoreSkill.state.rankTimer = ComboScoreSkill.CONFIG.styleRankDecay
end

-- ==================== UI显示 ====================

function ComboScoreSkill._showComboUI()
    ComboScoreSkill.state.isDisplaying = true
    ComboScoreSkill.state.displayTimer = 2.0

    -- 连击数字显示
    EventBusSkill.emit("UI_SHOW_COMBO", {
        combo = math.min(ComboScoreSkill.state.comboCount, ComboScoreSkill.CONFIG.maxComboDisplay),
        score = ComboScoreSkill.state.totalScore,
        rank = ComboScoreSkill.state.currentRank,
        rankColor = ComboScoreSkill._getRankColor(ComboScoreSkill.state.currentRank),
    })

    -- 连击数达到里程碑时播放特效
    if ComboScoreSkill.state.comboCount % 10 == 0 then
        EventBusSkill.emit("VFX_PLAY", {
            effectId = "combo_milestone_" .. ComboScoreSkill.state.comboCount,
            position = { x = 0.5, y = 0.3 }, -- 屏幕坐标
        })
    end
end

function ComboScoreSkill._showRankUpAnimation(oldRank, newRank)
    EventBusSkill.emit("UI_SHOW_RANK_UP", {
        oldRank = oldRank,
        newRank = newRank,
        color = ComboScoreSkill._getRankColor(newRank),
    })

    EventBusSkill.emit("VFX_PLAY", {
        effectId = "rank_up_" .. newRank,
        position = { x = 0.5, y = 0.5 },
    })

    -- 屏幕震动
    EventBusSkill.emit("SCREEN_SHAKE", {
        intensity = 0.5,
        duration = 0.3,
    })
end

function ComboScoreSkill._showResultScreen(finalScore)
    local rankInfo = ComboScoreSkill._getRankInfo(ComboScoreSkill.state.currentRank)

    EventBusSkill.emit("UI_SHOW_BATTLE_RESULT", {
        score = finalScore,
        maxCombo = ComboScoreSkill.state.battleStats.maxCombo,
        killCount = ComboScoreSkill.state.battleStats.killCount,
        hitCount = ComboScoreSkill.state.battleStats.hitCount,
        rank = ComboScoreSkill.state.currentRank,
        rankColor = rankInfo and rankInfo.color or "#ffffff",
        duration = os.clock() - ComboScoreSkill.state.battleStats.startTime,
        tookDamage = ComboScoreSkill.state.battleStats.tookDamage,
        skillVariety = ComboScoreSkill._countSkillVariety(),
    })
end

-- ==================== 连击语音 ====================

function ComboScoreSkill._checkComboVoice()
    local combo = ComboScoreSkill.state.comboCount

    for _, threshold in ipairs(ComboScoreSkill.CONFIG.comboVoiceThresholds) do
        if combo == threshold and combo > ComboScoreSkill.state.lastVoiceCombo then
            ComboScoreSkill.state.lastVoiceCombo = combo

            EventBusSkill.emit("AUDIO_PLAY", {
                soundId = "combo_voice_" .. combo,
                priority = 5,
            })

            break
        end
    end
end

-- ==================== 工具方法 ====================

function ComboScoreSkill._resetCombo()
    if ComboScoreSkill.state.comboCount > 0 then
        EventBusSkill.emit("COMBO_BROKEN", {
            finalCombo = ComboScoreSkill.state.comboCount,
            maxCombo = ComboScoreSkill.state.battleStats.maxCombo,
        })
    end

    ComboScoreSkill.state.comboCount = 0
    ComboScoreSkill.state.comboTimer = 0
    ComboScoreSkill.state.lastVoiceCombo = 0
end

function ComboScoreSkill._resetScore()
    ComboScoreSkill.state.totalScore = 0
    ComboScoreSkill.state.currentRank = "D"
    ComboScoreSkill.state.rankTimer = 0
    ComboScoreSkill.state.battleStats = {
        maxCombo = 0,
        totalDamage = 0,
        killCount = 0,
        hitCount = 0,
        skillVariety = {},
        startTime = 0,
        lastHitTime = 0,
        tookDamage = false,
    }
end

function ComboScoreSkill._getRankColor(rank)
    for _, rankInfo in ipairs(ComboScoreSkill.CONFIG.styleRanks) do
        if rankInfo.name == rank then
            return rankInfo.color
        end
    end
    return "#ffffff"
end

function ComboScoreSkill._getRankInfo(rank)
    for _, rankInfo in ipairs(ComboScoreSkill.CONFIG.styleRanks) do
        if rankInfo.name == rank then
            return rankInfo
        end
    end
    return nil
end

function ComboScoreSkill._countSkillVariety()
    local count = 0
    for _ in pairs(ComboScoreSkill.state.battleStats.skillVariety) do
        count = count + 1
    end
    return count
end

-- ==================== 更新 ====================

function ComboScoreSkill.update(dt)
    -- 连击计时器衰减
    if ComboScoreSkill.state.comboCount > 0 then
        ComboScoreSkill.state.comboTimer = ComboScoreSkill.state.comboTimer - dt
        if ComboScoreSkill.state.comboTimer <= 0 then
            ComboScoreSkill._resetCombo()
            EventBusSkill.emit("UI_HIDE_COMBO", {})
        end
    end

    -- 风格等级衰减
    if ComboScoreSkill.state.rankTimer > 0 then
        ComboScoreSkill.state.rankTimer = ComboScoreSkill.state.rankTimer - dt
        if ComboScoreSkill.state.rankTimer <= 0 then
            -- 风格等级衰减一级
            local currentIndex = 1
            for i, rankInfo in ipairs(ComboScoreSkill.CONFIG.styleRanks) do
                if rankInfo.name == ComboScoreSkill.state.currentRank then
                    currentIndex = i
                    break
                end
            end

            if currentIndex > 1 then
                local newRank = ComboScoreSkill.CONFIG.styleRanks[currentIndex - 1].name
                ComboScoreSkill.state.currentRank = newRank
                ComboScoreSkill.state.rankTimer = ComboScoreSkill.CONFIG.styleRankDecay

                EventBusSkill.emit("UI_UPDATE_RANK", {
                    rank = newRank,
                    color = ComboScoreSkill._getRankColor(newRank),
                })
            end
        end
    end

    -- UI显示计时
    if ComboScoreSkill.state.isDisplaying then
        ComboScoreSkill.state.displayTimer = ComboScoreSkill.state.displayTimer - dt
        if ComboScoreSkill.state.displayTimer <= 0 then
            ComboScoreSkill.state.isDisplaying = false
        end
    end
end

function ComboScoreSkill.destroy()
    EventBusSkill.off("DAMAGE_DEALT", ComboScoreSkill._onDamageDealt)
    EventBusSkill.off("ENTITY_DIED", ComboScoreSkill._onEntityDied)
    EventBusSkill.off("ENTITY_DAMAGED", ComboScoreSkill._onPlayerDamaged)
    EventBusSkill.off("COMBAT_START", ComboScoreSkill._onCombatStart)
    EventBusSkill.off("COMBAT_END", ComboScoreSkill._onCombatEnd)
    EventBusSkill.off("SKILL_CAST_COMPLETE", ComboScoreSkill._onSkillCast)

    print("[ComboScoreSkill] 已销毁")
end

return ComboScoreSkill
```

**接入方式**：

```lua
-- 在已有战斗系统的攻击代码中，只需添加事件触发

function CombatSystem.attack(target, skillId)
    local damage = CombatSystem.player.attack - target.defense
    target.hp = target.hp - damage

    -- 原有代码
    FloatingText.show(damage, target.x, target.y)

    -- ✅ 新增：触发战斗事件（ComboScoreSkill会自动监听并处理）
    EventBusSkill.emit("DAMAGE_DEALT", {
        damage = damage,
        attacker = CombatSystem.player,
        target = target,
        skillId = skillId,
        isAirHit = target.isAirborne, -- 是否空中连击
    })

    if target.hp <= 0 then
        target:die()

        -- ✅ 新增：触发击杀事件
        EventBusSkill.emit("ENTITY_DIED", {
            entity = target,
            killer = CombatSystem.player,
        })
    end
end

-- 在战斗开始/结束时触发事件
function CombatSystem.startBattle()
    EventBusSkill.emit("COMBAT_START", { enemies = CombatSystem.enemies })
end

function CombatSystem.endBattle()
    EventBusSkill.emit("COMBAT_END", { 
        victory = #CombatSystem.enemies == 0,
        duration = os.clock() - CombatSystem.battleStartTime,
    })
end
```

**效果**：
- 无需修改战斗核心逻辑，只需在关键节点添加 `EventBusSkill.emit()`
- 自动获得：连击计数、风格等级（D→SSS）、评分系统、结算界面
- 可配置：连击窗口时间、评分权重、风格等级阈值、语音触发条件

---

### 13.4 实战：将现有代码重构为Skill模块

#### 重构策略

当你的游戏代码已经写了一段时间，变得难以维护时，可以逐步将其重构为 Skill 模块。

**重构步骤**：

```
Step 1: 识别可Skill化的功能模块
├── 找出游戏中相对独立的功能（战斗、背包、任务等）
├── 标记模块间的数据依赖关系
└── 确定重构优先级（从耦合度最低的模块开始）

Step 2: 提取接口层
├── 为现有功能模块定义清晰的输入/输出接口
├── 用EventBus替代直接的函数调用
└── 保持原有代码运行，新增EventBus事件触发

Step 3: 开发独立Skill
├── 复制现有功能到新Skill文件
├── 将硬编码数据提取到ConfigSkill
├── 将直接调用改为EventBus事件
└── 添加完整的init/destroy生命周期

Step 4: 渐进式替换
├── 同时保留原有代码和新Skill
├── 通过配置开关切换使用哪个实现
├── 对比测试确保功能一致
└── 确认稳定后移除旧代码

Step 5: 清理和优化
├── 移除旧代码
├── 优化新Skill的性能
├── 补充单元测试
└── 更新文档
```

#### 重构示例：将现有背包代码重构为 InventorySkill

**原有代码**：
```lua
-- 原有背包代码（耦合严重）
local Backpack = {
    items = {},
    maxSlots = 50,
}

function Backpack.addItem(itemId, count)
    -- 直接操作UI
    UIManager.showItemAdded(itemId, count)

    -- 直接修改玩家属性
    if itemId == "exp_potion" then
        Player.exp = Player.exp + 100
        UIManager.updateExpBar()
    end

    -- 直接播放音效
    AudioManager.play("item_get")

    table.insert(Backpack.items, {id = itemId, count = count})
end

function Backpack.useItem(slot)
    local item = Backpack.items[slot]
    if item.id == "hp_potion" then
        Player.hp = math.min(Player.maxHp, Player.hp + 50)
        UIManager.updateHpBar()
        AudioManager.play("heal")
    end
    -- ... 其他物品效果直接写在这里
end
```

**问题分析**：
1. 直接调用 `UIManager`、`AudioManager`、`Player` —— 强耦合
2. 物品效果硬编码在 `useItem` 中 —— 难以扩展
3. 没有存档支持
4. 无法单元测试（依赖太多外部系统）

**重构后的 Skill 化代码**：

```lua
-- Step 1: 先添加EventBus事件到原有代码（过渡阶段）

function Backpack.addItem(itemId, count)
    -- 原有逻辑
    table.insert(Backpack.items, {id = itemId, count = count})

    -- ✅ 新增：触发事件（让其他系统自行响应）
    EventBusSkill.emit("INVENTORY_ITEM_CHANGED", {
        slotIndex = #Backpack.items,
        itemId = itemId,
        count = count,
        operation = "ADD"
    })
end

function Backpack.useItem(slot)
    local item = Backpack.items[slot]

    -- ✅ 新增：触发使用事件，由专门的EffectSkill处理
    EventBusSkill.emit("ITEM_USED", {
        itemId = item.id,
        slotIndex = slot,
        user = Player,
    })

    -- 移除物品
    table.remove(Backpack.items, slot)

    EventBusSkill.emit("INVENTORY_ITEM_CHANGED", {
        slotIndex = slot,
        itemId = item.id,
        count = 0,
        operation = "REMOVE"
    })
end

-- Step 2: 开发独立的 InventorySkill（基于原有代码）
-- 见12.1节的完整InventorySkill实现

-- Step 3: 开发 ItemEffectSkill（处理物品效果）

local ItemEffectSkill = {
    VERSION = "1.0.0",

    effectHandlers = {},
}

function ItemEffectSkill.init(config)
    -- 注册物品效果处理器
    ItemEffectSkill.registerEffect("heal", ItemEffectSkill._healEffect)
    ItemEffectSkill.registerEffect("restore_mp", ItemEffectSkill._restoreMpEffect)
    ItemEffectSkill.registerEffect("buff", ItemEffectSkill._buffEffect)
    ItemEffectSkill.registerEffect("teleport", ItemEffectSkill._teleportEffect)

    -- 监听物品使用事件
    EventBusSkill.on("ITEM_USED", ItemEffectSkill._onItemUsed)
end

function ItemEffectSkill.registerEffect(effectType, handler)
    ItemEffectSkill.effectHandlers[effectType] = handler
end

function ItemEffectSkill._onItemUsed(data)
    local itemConfig = ConfigSkill.get("items", data.itemId)
    if not itemConfig or not itemConfig.effect then return end

    local effect = itemConfig.effect
    local handler = ItemEffectSkill.effectHandlers[effect.type]

    if handler then
        handler(effect, data.user, data)
    else
        print("[ItemEffectSkill] 未知效果类型: " .. effect.type)
    end
end

function ItemEffectSkill._healEffect(effect, user, data)
    local healAmount = effect.value or 50
    -- 通过EventBus通知治疗，而不是直接修改Player
    EventBusSkill.emit("HEAL_REQUEST", {
        target = user,
        amount = healAmount,
        source = "item",
        itemId = data.itemId,
    })
end

function ItemEffectSkill._buffEffect(effect, user, data)
    EventBusSkill.emit("BUFF_APPLY_REQUEST", {
        target = user,
        buffId = effect.buffId,
        duration = effect.duration,
        source = "item",
        itemId = data.itemId,
    })
end

-- Step 4: 开发 InventoryUISkill（处理UI表现）
-- 见12.1节的完整InventoryUISkill实现

-- Step 5: 渐进替换
-- 在Game.init中通过开关控制使用哪个实现

function Game.init()
    if Game.USE_SKILL_SYSTEM then
        -- 使用新的Skill系统
        local InventorySkill = require("Skills/InventorySkill")
        local ItemEffectSkill = require("Skills/ItemEffectSkill")
        local InventoryUISkill = require("Skills/InventoryUISkill")

        InventorySkill.init({ maxSlots = 50 })
        ItemEffectSkill.init()
        InventoryUISkill.init()

        Game.inventory = InventorySkill
    else
        -- 使用原有系统
        Backpack.init()
        Game.inventory = Backpack
    end
end
```

**重构收益**：
1. **解耦**：各系统通过 EventBus 通信，不再直接依赖
2. **可测试**：每个 Skill 可以独立单元测试
3. **可扩展**：新增物品效果只需注册新的 effect handler
4. **可复用**：InventorySkill 可以在其他项目中直接使用
5. **可维护**：配置驱动，修改物品效果只需改配置表

---

### 13.5 实战：通过Skill添加新功能到已有游戏

#### 场景：为已有平台跳跃游戏添加"时间回溯"功能

**现有游戏**：一个平台跳跃游戏，有角色移动、跳跃、敌人、关卡等基础功能。

**新需求**：添加"时间回溯"技能——玩家可以按下按钮回溯最近5秒内的状态。

**方案**：开发 RewindSkill，通过快照系统实现时间回溯。

```lua
--[[
    Skill: RewindSkill
    版本: 1.0.0
    层级: Layer 3（玩法层）
    依赖: EventBusSkill, ConfigSkill, VFXSkill, AudioSkill
    功能: 时间回溯系统 - 记录游戏状态快照，支持回溯到过去

    适用场景: 为已有游戏添加时间操控机制，无需修改核心玩法代码
--]]

local RewindSkill = {
    VERSION = "1.0.0",

    CONFIG = {
        maxRewindSeconds = 5.0,      -- 最大回溯时间（秒）
        snapshotInterval = 0.1,      -- 快照间隔（秒）
        rewindSpeed = 2.0,           -- 回溯播放速度倍率
        cooldown = 10.0,             -- 回溯冷却时间（秒）
        energyCost = 50,             -- 能量消耗
        ghostEffect = true,          -- 是否显示回溯幽灵效果
    },

    state = {
        snapshots = {},              -- 状态快照队列 {timestamp, data}
        isRewinding = false,         -- 是否正在回溯中
        rewindProgress = 0,          -- 回溯进度（0-1）
        cooldownEndTime = 0,         -- 冷却结束时间
        snapshotTimer = 0,           -- 快照计时器
        maxSnapshots = 0,            -- 最大快照数量（根据配置计算）
    },
}

function RewindSkill.init(config)
    if config then
        for k, v in pairs(config) do
            RewindSkill.CONFIG[k] = v
        end
    end

    RewindSkill.state.maxSnapshots = math.ceil(
        RewindSkill.CONFIG.maxRewindSeconds / RewindSkill.CONFIG.snapshotInterval
    )

    -- 注册事件监听
    EventBusSkill.on("INPUT_ACTION", RewindSkill._onInputAction)
    EventBusSkill.on("GAME_PAUSE", RewindSkill._onGamePause)
    EventBusSkill.on("GAME_RESUME", RewindSkill._onGameResume)

    -- 注册状态收集器（其他Skill可以注册自己的状态收集/恢复函数）
    RewindSkill.stateCollectors = {}
    RewindSkill.stateRestorers = {}

    print("[RewindSkill] 时间回溯系统已初始化，最大回溯: " .. RewindSkill.CONFIG.maxRewindSeconds .. "秒")
end

-- 注册状态收集器（供其他Skill调用）
function RewindSkill.registerStateCollector(moduleName, collectorFunc)
    RewindSkill.stateCollectors[moduleName] = collectorFunc
end

-- 注册状态恢复器（供其他Skill调用）
function RewindSkill.registerStateRestorer(moduleName, restorerFunc)
    RewindSkill.stateRestorers[moduleName] = restorerFunc
end

-- ==================== 核心功能：快照与回溯 ====================

-- 创建当前状态快照
function RewindSkill._createSnapshot()
    local snapshot = {
        timestamp = os.clock(),
        data = {},
    }

    -- 收集所有已注册模块的状态
    for moduleName, collector in pairs(RewindSkill.stateCollectors) do
        local success, moduleData = pcall(collector)
        if success then
            snapshot.data[moduleName] = moduleData
        else
            print("[RewindSkill] 警告: 收集模块 '" .. moduleName .. "' 状态失败")
        end
    end

    -- 添加到队列
    table.insert(RewindSkill.state.snapshots, snapshot)

    -- 保持队列长度不超过最大值
    while #RewindSkill.state.snapshots > RewindSkill.state.maxSnapshots do
        table.remove(RewindSkill.state.snapshots, 1)
    end
end

-- 开始回溯
function RewindSkill.startRewind()
    if RewindSkill.state.isRewinding then
        return false, "正在回溯中"
    end

    if #RewindSkill.state.snapshots < 2 then
        return false, "没有可回溯的历史"
    end

    local now = os.clock()
    if now < RewindSkill.state.cooldownEndTime then
        return false, "技能冷却中"
    end

    -- 检查能量（如果游戏有能量系统）
    if PlayerSkill.getResource and PlayerSkill.getResource("energy") < RewindSkill.CONFIG.energyCost then
        return false, "能量不足"
    end

    -- 消耗能量
    if PlayerSkill.spendResource then
        PlayerSkill.spendResource("energy", RewindSkill.CONFIG.energyCost)
    end

    RewindSkill.state.isRewinding = true
    RewindSkill.state.rewindProgress = 1.0  -- 从最新快照开始回溯

    -- 暂停正常游戏逻辑
    EventBusSkill.emit("GAME_PAUSE", { reason = "rewind", allowUpdate = true })

    -- 播放回溯特效
    EventBusSkill.emit("VFX_PLAY", {
        effectId = "rewind_start",
        fullScreen = true,
    })

    EventBusSkill.emit("AUDIO_PLAY", {
        soundId = "rewind_start",
        pitch = 0.5,
    })

    -- 显示幽灵效果（可选）
    if RewindSkill.CONFIG.ghostEffect then
        RewindSkill._showGhostEffect()
    end

    EventBusSkill.emit("REWIND_STARTED", {
        maxRewindTime = RewindSkill.CONFIG.maxRewindSeconds,
        snapshotCount = #RewindSkill.state.snapshots,
    })

    return true
end

-- 停止回溯（恢复到当前进度对应的状态）
function RewindSkill.stopRewind()
    if not RewindSkill.state.isRewinding then
        return false
    end

    -- 计算目标快照索引
    local targetIndex = math.ceil(
        RewindSkill.state.rewindProgress * #RewindSkill.state.snapshots
    )
    targetIndex = math.max(1, math.min(targetIndex, #RewindSkill.state.snapshots))

    local targetSnapshot = RewindSkill.state.snapshots[targetIndex]

    -- 恢复所有模块状态
    for moduleName, restorer in pairs(RewindSkill.stateRestorers) do
        if targetSnapshot.data[moduleName] then
            local success, err = pcall(function()
                restorer(targetSnapshot.data[moduleName])
            end)
            if not success then
                print("[RewindSkill] 警告: 恢复模块 '" .. moduleName .. "' 状态失败: " .. tostring(err))
            end
        end
    end

    -- 清除回溯后的快照（防止循环回溯）
    -- 保留目标快照及之前的快照
    local newSnapshots = {}
    for i = 1, targetIndex do
        table.insert(newSnapshots, RewindSkill.state.snapshots[i])
    end
    RewindSkill.state.snapshots = newSnapshots

    RewindSkill.state.isRewinding = false
    RewindSkill.state.rewindProgress = 0
    RewindSkill.state.cooldownEndTime = os.clock() + RewindSkill.CONFIG.cooldown

    -- 恢复游戏
    EventBusSkill.emit("GAME_RESUME", { reason = "rewind" })

    -- 播放恢复特效
    EventBusSkill.emit("VFX_PLAY", {
        effectId = "rewind_end",
        fullScreen = true,
    })

    EventBusSkill.emit("AUDIO_PLAY", {
        soundId = "rewind_end",
        pitch = 1.0,
    })

    EventBusSkill.emit("REWIND_ENDED", {
        rewindTime = os.clock() - targetSnapshot.timestamp,
        targetSnapshot = targetIndex,
    })

    return true
end

-- 取消回溯（放弃回溯，恢复到最新状态）
function RewindSkill.cancelRewind()
    if not RewindSkill.state.isRewinding then
        return false
    end

    RewindSkill.state.isRewinding = false
    RewindSkill.state.rewindProgress = 0

    EventBusSkill.emit("GAME_RESUME", { reason = "rewind_cancel" })

    EventBusSkill.emit("AUDIO_PLAY", {
        soundId = "rewind_cancel",
    })

    return true
end

-- ==================== 其他模块接入示例 ====================

-- 玩家模块注册状态收集/恢复
function PlayerSkill.registerForRewind()
    -- 注册状态收集器
    RewindSkill.registerStateCollector("player", function()
        return {
            position = { x = Player.x, y = Player.y },
            velocity = { x = Player.vx, y = Player.vy },
            hp = Player.hp,
            mp = Player.mp,
            isGrounded = Player.isGrounded,
            isJumping = Player.isJumping,
            facing = Player.facing,
            animation = Player.currentAnimation,
            animationFrame = Player.animationFrame,
        }
    end)

    -- 注册状态恢复器
    RewindSkill.registerStateRestorer("player", function(data)
        Player.x = data.position.x
        Player.y = data.position.y
        Player.vx = data.velocity.x
        Player.vy = data.velocity.y
        Player.hp = data.hp
        Player.mp = data.mp
        Player.isGrounded = data.isGrounded
        Player.isJumping = data.isJumping
        Player.facing = data.facing
        Player.currentAnimation = data.animation
        Player.animationFrame = data.animationFrame

        -- 更新物理体位置
        if Player.physicsBody then
            Player.physicsBody:setPosition(Player.x, Player.y)
            Player.physicsBody:setLinearVelocity(Player.vx, Player.vy)
        end
    end)
end

-- 敌人模块注册状态收集/恢复
function EnemyManager.registerForRewind()
    RewindSkill.registerStateCollector("enemies", function()
        local enemyStates = {}
        for _, enemy in ipairs(EnemyManager.enemies) do
            table.insert(enemyStates, {
                id = enemy.id,
                type = enemy.type,
                position = { x = enemy.x, y = enemy.y },
                velocity = { x = enemy.vx, y = enemy.vy },
                hp = enemy.hp,
                isAlive = enemy.isAlive,
                state = enemy.aiState,
                patrolIndex = enemy.patrolIndex,
            })
        end
        return enemyStates
    end)

    RewindSkill.registerStateRestorer("enemies", function(data)
        -- 恢复敌人状态
        for _, enemyData in ipairs(data) do
            local enemy = EnemyManager.getEnemyById(enemyData.id)
            if enemy then
                enemy.x = enemyData.position.x
                enemy.y = enemyData.position.y
                enemy.vx = enemyData.velocity.x
                enemy.vy = enemyData.velocity.y
                enemy.hp = enemyData.hp
                enemy.isAlive = enemyData.isAlive
                enemy.aiState = enemyData.state
                enemy.patrolIndex = enemyData.patrolIndex

                if enemy.physicsBody then
                    enemy.physicsBody:setPosition(enemy.x, enemy.y)
                    enemy.physicsBody:setLinearVelocity(enemy.vx, enemy.vy)
                end

                -- 如果敌人已死亡但快照中存活，复活敌人
                if enemyData.isAlive and not enemy.isAlive then
                    enemy:respawn()
                end
            end
        end
    end)
end

-- 关卡对象注册状态收集/恢复
function WorldManager.registerForRewind()
    RewindSkill.registerStateCollector("world", function()
        local objectStates = {}
        for _, obj in ipairs(WorldManager.dynamicObjects) do
            table.insert(objectStates, {
                id = obj.id,
                type = obj.type,
                position = { x = obj.x, y = obj.y },
                velocity = { x = obj.vx, y = obj.vy },
                state = obj.state,  -- 开关状态、移动平台位置等
                isActive = obj.isActive,
            })
        end
        return objectStates
    end)

    RewindSkill.registerStateRestorer("world", function(data)
        for _, objData in ipairs(data) do
            local obj = WorldManager.getObjectById(objData.id)
            if obj then
                obj.x = objData.position.x
                obj.y = objData.position.y
                obj.vx = objData.velocity.x
                obj.vy = objData.velocity.y
                obj.state = objData.state
                obj.isActive = objData.isActive

                if obj.physicsBody then
                    obj.physicsBody:setPosition(obj.x, obj.y)
                    obj.physicsBody:setLinearVelocity(obj.vx, obj.vy)
                end
            end
        end
    end)
end

-- ==================== UI显示 ====================

function RewindSkill._showGhostEffect()
    -- 显示回溯过程中的幽灵轨迹
    local ghostSnapshots = {}
    for i = 1, #RewindSkill.state.snapshots do
        local snap = RewindSkill.state.snapshots[i]
        if snap.data.player then
            table.insert(ghostSnapshots, snap.data.player.position)
        end
    end

    EventBusSkill.emit("VFX_SHOW_GHOST_TRAIL", {
        positions = ghostSnapshots,
        color = "#60a5fa",
        alpha = 0.3,
    })
end

-- ==================== 更新 ====================

function RewindSkill.update(dt)
    if RewindSkill.state.isRewinding then
        -- 回溯模式：倒放快照
        local rewindDt = dt * RewindSkill.CONFIG.rewindSpeed
        RewindSkill.state.rewindProgress = RewindSkill.state.rewindProgress - 
            (rewindDt / RewindSkill.CONFIG.maxRewindSeconds)

        if RewindSkill.state.rewindProgress <= 0 then
            -- 回溯到最旧的状态，自动停止
            RewindSkill.stopRewind()
            return
        end

        -- 计算当前应该显示的快照
        local currentIndex = math.ceil(
            RewindSkill.state.rewindProgress * #RewindSkill.state.snapshots
        )
        currentIndex = math.max(1, math.min(currentIndex, #RewindSkill.state.snapshots))

        -- 显示回溯进度UI
        EventBusSkill.emit("UI_UPDATE_REWIND_BAR", {
            progress = RewindSkill.state.rewindProgress,
            currentTime = RewindSkill.state.snapshots[currentIndex].timestamp,
        })

        -- 播放回溯音效（倒放效果）
        EventBusSkill.emit("AUDIO_UPDATE_PITCH", {
            soundId = "rewind_loop",
            pitch = 0.5 + RewindSkill.state.rewindProgress * 0.5,
        })

    else
        -- 正常模式：定期创建快照
        RewindSkill.state.snapshotTimer = RewindSkill.state.snapshotTimer + dt
        if RewindSkill.state.snapshotTimer >= RewindSkill.CONFIG.snapshotInterval then
            RewindSkill.state.snapshotTimer = 0
            RewindSkill._createSnapshot()
        end

        -- 更新冷却UI
        local now = os.clock()
        if now < RewindSkill.state.cooldownEndTime then
            local remaining = RewindSkill.state.cooldownEndTime - now
            EventBusSkill.emit("UI_UPDATE_REWIND_COOLDOWN", {
                remaining = remaining,
                total = RewindSkill.CONFIG.cooldown,
                progress = 1 - (remaining / RewindSkill.CONFIG.cooldown),
            })
        else
            EventBusSkill.emit("UI_UPDATE_REWIND_COOLDOWN", {
                remaining = 0,
                total = RewindSkill.CONFIG.cooldown,
                progress = 1,
            })
        end
    end
end

-- ==================== 事件处理 ====================

function RewindSkill._onInputAction(data)
    if data.action == "REWIND" then
        if RewindSkill.state.isRewinding then
            -- 再次按下停止回溯
            RewindSkill.stopRewind()
        else
            -- 开始回溯
            RewindSkill.startRewind()
        end
    elseif data.action == "REWIND_CANCEL" and RewindSkill.state.isRewinding then
        RewindSkill.cancelRewind()
    end
end

function RewindSkill._onGamePause(data)
    if data.reason ~= "rewind" then
        -- 正常暂停时停止快照
        RewindSkill.state.snapshotTimer = 0
    end
end

function RewindSkill._onGameResume(data)
    -- 恢复时继续快照
end

function RewindSkill.destroy()
    EventBusSkill.off("INPUT_ACTION", RewindSkill._onInputAction)
    EventBusSkill.off("GAME_PAUSE", RewindSkill._onGamePause)
    EventBusSkill.off("GAME_RESUME", RewindSkill._onGameResume)

    RewindSkill.stateCollectors = {}
    RewindSkill.stateRestorers = {}
    RewindSkill.state.snapshots = {}

    print("[RewindSkill] 已销毁")
end

return RewindSkill
```

**接入方式**：

```lua
-- 在游戏初始化中加入RewindSkill
function Game.init()
    -- ... 原有初始化 ...

    -- 初始化RewindSkill
    local RewindSkill = require("Skills/RewindSkill")
    RewindSkill.init({
        maxRewindSeconds = 5.0,
        snapshotInterval = 0.05, -- 20fps快照，更平滑
        rewindSpeed = 3.0,       -- 3倍速回溯
        cooldown = 8.0,
        energyCost = 30,
        ghostEffect = true,
    })

    -- 注册各模块的快照收集/恢复
    PlayerSkill.registerForRewind()
    EnemyManager.registerForRewind()
    WorldManager.registerForRewind()

    -- 添加到主Skill管理器
    Game.subSkills.RewindSkill = RewindSkill
end

-- 在游戏主循环中更新RewindSkill
function Game.update(dt)
    -- ... 原有更新 ...

    if Game.subSkills.RewindSkill then
        Game.subSkills.RewindSkill.update(dt)
    end
end
```

**关键设计要点**：
1. **注册式接入**：其他模块通过 `registerStateCollector/Restorer` 主动注册，RewindSkill 不主动依赖任何模块
2. **零侵入**：现有代码只需添加几行注册代码，核心逻辑完全不变
3. **物理状态恢复**：恢复位置的同时恢复物理体的速度和位置
4. **敌人复活**：如果敌人在回溯区间内被击杀，回溯后可以复活
5. **幽灵轨迹**：回溯时显示玩家过去位置的幽灵轨迹，增强视觉效果
6. **能量系统**：与玩家能量系统联动，消耗能量使用回溯

---

### 13.6 Skill增量开发检查清单

当你需要通过 Skill 完善已有游戏时，使用以下检查清单确保开发质量：

```markdown
## Skill增量开发检查清单

### 需求分析
- [ ] 明确要完善的功能范围和目标
- [ ] 分析现有代码结构，确定接入点
- [ ] 评估是否需要重构现有代码
- [ ] 确定Skill的层级和依赖关系

### 接口设计
- [ ] 定义清晰的输入接口（EventBus事件、函数调用）
- [ ] 定义清晰的输出接口（EventBus事件、回调函数）
- [ ] 设计配置参数，保持可调整性
- [ ] 考虑与现有系统的数据兼容性

### 开发实现
- [ ] 遵循Skill开发规范（版本号、init/destroy、事件注销）
- [ ] 使用EventBus进行跨模块通信
- [ ] 避免直接修改其他模块的状态
- [ ] 提供getter/setter接口供存档系统使用
- [ ] 处理边界情况（空数据、异常输入）

### 接入测试
- [ ] 在现有游戏中测试Skill功能
- [ ] 测试与现有系统的兼容性
- [ ] 测试存档/读档功能
- [ ] 测试性能影响（帧率、内存）
- [ ] 测试错误恢复（Skill异常时游戏不崩溃）

### 文档更新
- [ ] 更新Skill的接口文档
- [ ] 记录接入步骤和配置说明
- [ ] 记录已知问题和限制
- [ ] 更新游戏整体设计文档
```

---

### 13.7 常见增量开发模式

| 模式名称 | 适用场景 | 实现方式 | 示例 |
|---------|---------|---------|------|
| **事件叠加** | 已有系统缺少反馈 | 监听现有事件，添加新效果 | ComboScoreSkill |
| **数据快照** | 需要状态回溯/存档 | 定期收集状态，支持恢复 | SaveLoadSkill、RewindSkill |
| **配置扩展** | 现有系统功能不足 | 新增配置项，扩展原有逻辑 | 新增物品类型、技能效果 |
| **代理包装** | 现有接口不完善 | 包装原有接口，提供更友好的API | 包装原有UI系统为UISkill |
| **并行系统** | 需要全新功能 | 开发独立Skill，通过EventBus通信 | 新增成就系统、排行榜系统 |
| **替换升级** | 现有系统性能不足 | 开发优化版Skill，保持接口兼容 | 替换碰撞检测算法 |

---

*本章节展示了如何通过Skill开发模式，在不破坏现有代码的前提下，为已有游戏添加新功能、完善现有功能、或将现有代码重构为可维护的Skill模块。核心原则是：通过EventBus解耦、配置驱动、注册式接入。*
