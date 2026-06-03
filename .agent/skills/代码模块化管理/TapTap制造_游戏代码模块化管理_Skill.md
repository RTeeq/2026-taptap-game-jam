# TapTap制造 · 游戏代码模块化管理 Skill

> 专为 TapTap 制造可视化编辑器设计的代码架构规范，帮助你实现清晰、可维护、可扩展的游戏项目。

---

## 1. 核心原则

| 原则 | 说明 |
|------|------|
| **单一职责** | 每个模块只负责一个明确的功能领域 |
| **高内聚低耦合** | 模块内部紧密相关，模块间依赖最小化 |
| **接口隔离** | 模块间通过明确的接口/事件通信，不直接访问内部实现 |
| **可复用性** | 通用功能抽象为独立模块，避免重复代码 |

---

## 2. 推荐目录结构

```
📁 项目根目录
├── 📁 core/                    # 核心框架层（全局单例）
│   ├── GameManager.ts          # 游戏主控制器
│   ├── EventBus.ts             # 全局事件总线
│   ├── DataStore.ts            # 数据持久化
│   └── AudioManager.ts         # 音频管理
│
├── 📁 systems/                 # 游戏系统层
│   ├── CombatSystem.ts         # 战斗系统
│   ├── InventorySystem.ts      # 背包系统
│   ├── QuestSystem.ts          # 任务系统
│   └── EconomySystem.ts        # 经济系统
│
├── 📁 entities/                # 实体层
│   ├── Player.ts               # 玩家角色
│   ├── Enemy.ts                # 敌人基类
│   ├── NPC.ts                  # NPC
│   └── Item.ts                 # 物品基类
│
├── 📁 ui/                      # UI层
│   ├── HUD.ts                  # 主界面
│   ├── MenuPanel.ts            # 菜单面板
│   └── DialogSystem.ts         # 对话框系统
│
├── 📁 utils/                   # 工具层
│   ├── MathUtils.ts            # 数学工具
│   ├── Vector2.ts              # 向量运算
│   └── Logger.ts               # 日志工具
│
└── 📁 config/                  # 配置层
    ├── GameConfig.ts           # 全局配置
    ├── Constants.ts            # 常量定义
    └── BalanceData.ts          # 数值平衡表
```

---

## 3. 模块设计模式

### 3.1 单例模式（全局管理器）

用于需要全局唯一实例的管理器：

```typescript
// core/EventBus.ts
class EventBus {
  private static instance: EventBus;
  private listeners: Map<string, Function[]> = new Map();

  private constructor() {}

  static getInstance(): EventBus {
    if (!EventBus.instance) {
      EventBus.instance = new EventBus();
    }
    return EventBus.instance;
  }

  on(event: string, callback: Function): void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event)!.push(callback);
  }

  off(event: string, callback: Function): void {
    const list = this.listeners.get(event);
    if (list) {
      const idx = list.indexOf(callback);
      if (idx > -1) list.splice(idx, 1);
    }
  }

  emit(event: string, ...args: any[]): void {
    const list = this.listeners.get(event);
    if (list) {
      list.forEach(cb => cb(...args));
    }
  }
}

export default EventBus.getInstance();
```

### 3.2 组件-实体模式（ECS 简化版）

适合实体较多的游戏类型：

```typescript
// entities/Entity.ts
class Entity {
  private components: Map<string, Component> = new Map();

  addComponent<T extends Component>(type: string, component: T): void {
    this.components.set(type, component);
    component.entity = this;
  }

  getComponent<T extends Component>(type: string): T | undefined {
    return this.components.get(type) as T;
  }

  removeComponent(type: string): void {
    this.components.delete(type);
  }

  update(deltaTime: number): void {
    this.components.forEach(comp => comp.update(deltaTime));
  }
}

// entities/components/Component.ts
abstract class Component {
  entity: Entity | null = null;
  abstract update(deltaTime: number): void;
}

// entities/components/MovementComponent.ts
class MovementComponent extends Component {
  velocity = { x: 0, y: 0 };
  speed: number = 100;

  update(deltaTime: number): void {
    if (!this.entity) return;
    const transform = this.entity.getComponent<TransformComponent>('transform');
    if (transform) {
      transform.x += this.velocity.x * this.speed * deltaTime;
      transform.y += this.velocity.y * this.speed * deltaTime;
    }
  }
}
```

### 3.3 状态机模式（角色/游戏状态管理）

```typescript
// systems/StateMachine.ts
type StateAction = () => void;

class StateMachine<T extends string> {
  private states: Map<T, { enter?: StateAction; update: StateAction; exit?: StateAction }> = new Map();
  private currentState: T | null = null;

  register(state: T, config: { enter?: StateAction; update: StateAction; exit?: StateAction }): void {
    this.states.set(state, config);
  }

  transitionTo(newState: T): void {
    const old = this.states.get(this.currentState!);
    if (old?.exit) old.exit();

    this.currentState = newState;
    const next = this.states.get(newState);
    if (next?.enter) next.enter();
  }

  update(): void {
    if (this.currentState) {
      const state = this.states.get(this.currentState);
      if (state) state.update();
    }
  }

  getCurrentState(): T | null {
    return this.currentState;
  }
}

// 使用示例：Player.ts
class Player extends Entity {
  private stateMachine: StateMachine<'idle' | 'run' | 'attack' | 'hurt' | 'dead'>;

  constructor() {
    super();
    this.stateMachine = new StateMachine();
    this.setupStates();
  }

  private setupStates(): void {
    this.stateMachine.register('idle', {
      enter: () => this.playAnimation('idle'),
      update: () => this.handleIdle()
    });
    this.stateMachine.register('run', {
      enter: () => this.playAnimation('run'),
      update: () => this.handleMovement()
    });
    this.stateMachine.register('attack', {
      enter: () => {
        this.playAnimation('attack');
        this.performAttack();
      },
      update: () => {},
      exit: () => this.attackCooldown = 0.5
    });
  }

  update(deltaTime: number): void {
    super.update(deltaTime);
    this.stateMachine.update();
  }
}
```

---

## 4. 模块间通信规范

### 4.1 事件总线（松耦合推荐）

```typescript
// 定义事件常量（避免魔法字符串）
// config/GameEvents.ts
export const GameEvents = {
  PLAYER_DAMAGED: 'player:damaged',
  ENEMY_KILLED: 'enemy:killed',
  ITEM_COLLECTED: 'item:collected',
  QUEST_COMPLETED: 'quest:completed',
  GAME_PAUSED: 'game:paused',
  SCORE_CHANGED: 'score:changed'
} as const;

// 使用示例
import EventBus from '../core/EventBus';
import { GameEvents } from '../config/GameEvents';

// 发送事件
EventBus.emit(GameEvents.PLAYER_DAMAGED, {
  damage: 10,
  source: enemyId,
  isCritical: false
});

// 监听事件
EventBus.on(GameEvents.PLAYER_DAMAGED, (data) => {
  console.log(`Player took ${data.damage} damage`);
  UIManager.showDamageNumber(data.damage);
});
```

### 4.2 依赖注入（紧耦合但可控）

```typescript
// core/ServiceLocator.ts
class ServiceLocator {
  private services: Map<string, any> = new Map();

  register<T>(name: string, instance: T): void {
    this.services.set(name, instance);
  }

  resolve<T>(name: string): T {
    const service = this.services.get(name);
    if (!service) throw new Error(`Service ${name} not registered`);
    return service as T;
  }
}

export const Services = new ServiceLocator();

// 初始化时注册
Services.register('combat', new CombatSystem());
Services.register('inventory', new InventorySystem());

// 使用时解析
const combat = Services.resolve<CombatSystem>('combat');
```

---

## 5. 数据管理模块

### 5.1 数据存储与持久化

```typescript
// core/DataStore.ts
class DataStore {
  private static instance: DataStore;
  private data: Map<string, any> = new Map();
  private autoSaveInterval: number = 30; // 秒

  static getInstance(): DataStore {
    if (!DataStore.instance) DataStore.instance = new DataStore();
    return DataStore.instance;
  }

  set<T>(key: string, value: T): void {
    this.data.set(key, value);
  }

  get<T>(key: string, defaultValue?: T): T | undefined {
    return this.data.has(key) ? this.data.get(key) : defaultValue;
  }

  // 存档
  save(slot: number = 0): void {
    const saveData = Object.fromEntries(this.data);
    const json = JSON.stringify(saveData);
    localStorage.setItem(`save_${slot}`, json);
    EventBus.emit('game:saved', { slot, timestamp: Date.now() });
  }

  // 读档
  load(slot: number = 0): boolean {
    const json = localStorage.getItem(`save_${slot}`);
    if (!json) return false;
    const saveData = JSON.parse(json);
    this.data = new Map(Object.entries(saveData));
    EventBus.emit('game:loaded', { slot });
    return true;
  }

  // 清空
  clear(): void {
    this.data.clear();
  }
}

export default DataStore.getInstance();
```

### 5.2 配置表驱动

```typescript
// config/BalanceData.ts
export const EnemyStats = {
  slime: { hp: 30, atk: 5, def: 2, exp: 10, gold: 5 },
  goblin: { hp: 50, atk: 8, def: 3, exp: 20, gold: 12 },
  boss_dragon: { hp: 500, atk: 30, def: 15, exp: 500, gold: 200 }
} as const;

export const WeaponData = {
  wooden_sword: { atk: 10, speed: 1.0, crit: 0.05 },
  iron_sword: { atk: 25, speed: 0.9, crit: 0.08 },
  legendary_blade: { atk: 100, speed: 1.2, crit: 0.25 }
} as const;

// 使用：避免硬编码数值，便于平衡调整
const enemyType = 'goblin';
const stats = EnemyStats[enemyType];
```

---

## 6. 模块化最佳实践

### ✅ 应该做的

1. **按功能域划分模块**：战斗、UI、音频、数据 各自独立
2. **使用命名空间/前缀避免冲突**：`Combat_`、`UI_`、`Audio_`
3. **每个模块暴露最小接口**：只导出必要的函数/类
4. **利用 TapTap 制造的 自定义节点/脚本 分离逻辑**：将不同系统放在不同脚本节点下
5. **统一初始化顺序**：在 GameManager 中按依赖顺序初始化各系统

```typescript
// core/GameManager.ts
class GameManager {
  private systems: Array<{ name: string; instance: GameSystem; priority: number }> = [];

  registerSystem(name: string, system: GameSystem, priority: number = 0): void {
    this.systems.push({ name, instance: system, priority });
    this.systems.sort((a, b) => a.priority - b.priority);
  }

  async initialize(): Promise<void> {
    for (const sys of this.systems) {
      console.log(`Initializing ${sys.name}...`);
      await sys.instance.init();
    }
    EventBus.emit('game:ready');
  }

  update(deltaTime: number): void {
    for (const sys of this.systems) {
      sys.instance.update(deltaTime);
    }
  }
}

interface GameSystem {
  init(): Promise<void> | void;
  update(deltaTime: number): void;
}
```

### ❌ 避免的做法

1. **全局变量污染**：避免 `window.myData = ...`，使用模块导出
2. **循环依赖**：A 依赖 B，B 又依赖 A。通过事件总线或接口抽象解耦
3. **上帝类**：一个类处理所有功能，应拆分为多个小模块
4. **硬编码路径**：资源路径、配置值应集中管理
5. **在 Update 中频繁创建对象**：使用对象池复用

---

## 7. 对象池模块（性能优化）

```typescript
// utils/ObjectPool.ts
class ObjectPool<T> {
  private available: T[] = [];
  private inUse: Set<T> = new Set();
  private factory: () => T;
  private reset: (obj: T) => void;

  constructor(factory: () => T, reset: (obj: T) => void, initialSize: number = 10) {
    this.factory = factory;
    this.reset = reset;
    for (let i = 0; i < initialSize; i++) {
      this.available.push(factory());
    }
  }

  acquire(): T {
    let obj: T;
    if (this.available.length > 0) {
      obj = this.available.pop()!;
    } else {
      obj = this.factory();
    }
    this.inUse.add(obj);
    return obj;
  }

  release(obj: T): void {
    if (this.inUse.has(obj)) {
      this.inUse.delete(obj);
      this.reset(obj);
      this.available.push(obj);
    }
  }

  clear(): void {
    this.available.length = 0;
    this.inUse.clear();
  }
}

// 使用示例：子弹对象池
const bulletPool = new ObjectPool<Bullet>(
  () => new Bullet(),
  (bullet) => {
    bullet.x = 0;
    bullet.y = 0;
    bullet.active = false;
    bullet.damage = 0;
  },
  50
);
```

---

## 8. 调试与日志模块

```typescript
// utils/Logger.ts
enum LogLevel { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 }

class Logger {
  private static level: LogLevel = LogLevel.DEBUG;
  private static moduleFilter: string | null = null;

  static setLevel(level: LogLevel): void {
    Logger.level = level;
  }

  static setModuleFilter(filter: string | null): void {
    Logger.moduleFilter = filter;
  }

  private static log(level: LogLevel, module: string, message: string, ...args: any[]): void {
    if (level < Logger.level) return;
    if (Logger.moduleFilter && module !== Logger.moduleFilter) return;

    const timestamp = new Date().toISOString();
    const prefix = `[${timestamp}][${LogLevel[level]}][${module}]`;

    switch (level) {
      case LogLevel.DEBUG: console.debug(prefix, message, ...args); break;
      case LogLevel.INFO: console.info(prefix, message, ...args); break;
      case LogLevel.WARN: console.warn(prefix, message, ...args); break;
      case LogLevel.ERROR: console.error(prefix, message, ...args); break;
    }
  }

  static debug(module: string, message: string, ...args: any[]): void {
    Logger.log(LogLevel.DEBUG, module, message, ...args);
  }
  static info(module: string, message: string, ...args: any[]): void {
    Logger.log(LogLevel.INFO, module, message, ...args);
  }
  static warn(module: string, message: string, ...args: any[]): void {
    Logger.log(LogLevel.WARN, module, message, ...args);
  }
  static error(module: string, message: string, ...args: any[]): void {
    Logger.log(LogLevel.ERROR, module, message, ...args);
  }
}

// 使用
Logger.info('CombatSystem', 'Player attacked enemy', { damage: 25 });
Logger.debug('InventorySystem', 'Item added', itemId);
```

---

## 9. 快速参考：模块拆分决策树

```
这个逻辑应该放在哪里？
│
├─ 是否涉及全局游戏状态控制？ → core/GameManager.ts
│
├─ 是否处理用户输入/界面？ → ui/
│
├─ 是否管理游戏核心规则（战斗/经济/任务）？ → systems/
│
├─ 是否表示游戏中的具体对象（玩家/敌人/物品）？ → entities/
│
├─ 是否提供通用辅助功能（数学/格式化/验证）？ → utils/
│
├─ 是否定义常量/配置/平衡数值？ → config/
│
└─ 是否需要跨模块通信？ → 通过 core/EventBus.ts 或接口抽象
```

---

## 10. 在 TapTap 制造编辑器中的实践建议

1. **利用节点树组织模块**：在场景树中按功能创建空节点作为"文件夹"
   ```
   📁 GameRoot
   ├── 📁 CoreSystems (空节点)
   │   ├── GameManager (脚本)
   │   ├── EventBus (脚本)
   │   └── DataStore (脚本)
   ├── 📁 Combat (空节点)
   │   ├── CombatSystem (脚本)
   │   └── SpawnManager (脚本)
   └── 📁 UI (空节点)
       ├── HUD (脚本 + UI节点)
       └── MenuManager (脚本)
   ```

2. **脚本命名规范**：`模块名_功能.ts`，如 `Combat_DamageCalculator.ts`、`UI_HealthBar.ts`

3. **利用编辑器自定义属性暴露配置**：将平衡数值、特效路径等作为可配置属性，避免硬编码

4. **生命周期管理**：在 `onStart`、`onUpdate`、`onDestroy` 中正确调用各模块的对应方法

---

## 附录：完整模块初始化模板

```typescript
// 新模块创建模板
// 文件路径：systems/YourSystem.ts

import EventBus from '../core/EventBus';
import { GameEvents } from '../config/GameEvents';
import Logger from '../utils/Logger';

interface YourSystemConfig {
  // 配置项定义
}

class YourSystem {
  private static instance: YourSystem;
  private isInitialized: boolean = false;
  private config: YourSystemConfig;

  private constructor(config: YourSystemConfig) {
    this.config = config;
  }

  static getInstance(config?: YourSystemConfig): YourSystem {
    if (!YourSystem.instance) {
      YourSystem.instance = new YourSystem(config || {});
    }
    return YourSystem.instance;
  }

  async init(): Promise<void> {
    if (this.isInitialized) return;

    Logger.info('YourSystem', 'Initializing...');

    // 注册事件监听
    EventBus.on(GameEvents.GAME_PAUSED, this.onGamePaused.bind(this));

    this.isInitialized = true;
    Logger.info('YourSystem', 'Initialized successfully');
  }

  update(deltaTime: number): void {
    if (!this.isInitialized) return;
    // 每帧更新逻辑
  }

  private onGamePaused(): void {
    // 处理暂停逻辑
  }

  destroy(): void {
    EventBus.off(GameEvents.GAME_PAUSED, this.onGamePaused.bind(this));
    this.isInitialized = false;
    Logger.info('YourSystem', 'Destroyed');
  }
}

export default YourSystem.getInstance();
```

---

> 本 Skill 涵盖 **模块划分原则、设计模式、通信机制、数据管理、性能优化和调试工具**，可作为 TapTap 制造项目代码架构的参考规范。
