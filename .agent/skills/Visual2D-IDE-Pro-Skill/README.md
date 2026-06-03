# Visual2D IDE Pro - TapTap制造 可视化编辑器 Skill

## 版本: 2.0.0

---

## 功能清单

### 核心模块

| 文件 | 功能 | 状态 |
|------|------|------|
| `Config.lua` | 全局配置、主题系统、快捷键映射、工具函数 | 增强 |
| `EventBus.lua` | 发布/订阅事件系统 | 保留 |
| `UndoManager.lua` | 完整撤销/重做，支持分组操作 | 重写 |
| `SceneManager.lua` | 场景管理、多选、对齐、图层、标签 | 增强 |
| `NodeEditor.lua` | 节点编辑器、数据流编译、40+节点类型 | 增强 |
| `IDEMain.lua` | 主界面、三栏布局、属性编辑 | 重写 |
| `Console.lua` | 控制台、日志捕获、命令执行、自动补全 | 新增 |
| `AssetBrowser.lua` | 资源浏览、分类、搜索 | 新增 |
| `ComponentSystem.lua` | 组件系统、10种组件类型 | 新增 |

### 新增功能

1. **属性编辑器** - 右面板可编辑对象属性（名称、坐标、旋转、缩放等）
2. **控制台系统** - 捕获print日志、执行命令、查看FPS/内存/节点统计
3. **资源浏览器** - 扫描assets目录、按类型分类、预览图片/音频
4. **组件系统** - 为对象挂载SpriteRenderer、Rigidbody、Collider、AudioSource等组件
5. **复制粘贴** - Ctrl+C/V 复制对象/节点，支持多选
6. **对齐工具** - 左/右/顶/底对齐，水平/垂直分布
7. **多选框选** - 拖拽框选多个对象，Shift加减选
8. **标签系统** - 对象可打标签，按标签查找
9. **节点数据流** - 编译时支持数据流连接（Math节点输出到Action节点输入）
10. **注释节点** - 节点图中添加注释说明
11. **主题切换** - 支持暗色/亮色主题
12. **快捷键系统** - 完整的快捷键映射表

---

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| Ctrl+S | 保存项目 |
| Ctrl+Z | 撤销 |
| Ctrl+Shift+Z | 重做 |
| Ctrl+C | 复制 |
| Ctrl+V | 粘贴 |
| Ctrl+X | 剪切 |
| Ctrl+D | 复制并粘贴 |
| Ctrl+A | 全选 |
| Delete | 删除选中 |
| G | 切换网格显示 |
| H | 切换吸附 |
| F | 聚焦选中对象 |
| Tab | 切换场景/节点模式 |
| F5 | 运行游戏 |
| F7 | 编译节点图 |
| ` | 切换控制台 |

---

## 安装方法

1. 将 `scripts/IDE/` 目录下的所有文件复制到你的项目 `scripts/IDE/` 中
2. 在 `main.lua` 中引入:

```lua
local IDEMain = require("IDE.IDEMain")
IDEMain:init()
```

3. 在 `Update` 中调用:
```lua
IDEMain:update(dt)
```

4. 在 `Render` 中调用:
```lua
IDEMain:render()
```

---

## 节点类型 (40+种)

### 事件节点
- `Event_Start` - 游戏开始
- `Event_Tick` - 每帧更新
- `Event_KeyPress` - 按键按下
- `Event_KeyRelease` - 按键释放
- `Event_Collision` - 碰撞触发
- `Event_Timer` - 定时器

### 动作节点
- `Action_Log` - 输出日志
- `Action_CreateUnit` - 创建对象
- `Action_DestroyUnit` - 销毁对象
- `Action_SetPos` - 设置位置
- `Action_SetScale` - 设置缩放
- `Action_SetRotation` - 设置旋转
- `Action_PlaySound` - 播放音效
- `Action_PlayAnimation` - 播放动画
- `Action_SpawnParticle` - 生成粒子
- `Action_LoadScene` - 加载场景
- `Action_Delay` - 延迟执行
- `Action_FadeScreen` - 屏幕淡入淡出

### 条件节点
- `Condition_If` - 条件分支
- `Condition_Compare` - 数值比较
- `Condition_StringCompare` - 字符串比较
- `Condition_And` - 逻辑与
- `Condition_Or` - 逻辑或
- `Condition_Not` - 逻辑非
- `Condition_RandomChance` - 随机概率

### 数学节点
- `Math_Add/Sub/Mul/Div/Mod/Pow` - 基础运算
- `Math_Random` - 随机数
- `Math_Clamp` - 限制范围
- `Math_Lerp` - 线性插值
- `Math_Distance` - 两点距离
- `Math_Angle` - 两点角度
- `Math_Sin/Cos` - 三角函数

### 变量节点
- `Variable_Get` - 获取变量
- `Variable_Set` - 设置变量
- `Variable_Increment` - 变量自增

### 输入节点
- `Input_GetAxis` - 方向轴
- `Input_GetMousePos` - 鼠标位置
- `Input_IsKeyDown` - 按键检测
- `Input_IsMouseDown` - 鼠标检测

### 流程控制
- `Flow_Sequence` - 顺序执行
- `Flow_ForLoop` - For循环
- `Flow_WhileLoop` - While循环
- `Flow_Break` - 跳出循环

### 对象操作
- `Object_GetPosition` - 获取位置
- `Object_GetDistance` - 获取距离
- `Object_FindByTag` - 按标签查找

### 字符串
- `String_Concat` - 拼接
- `String_Format` - 格式化
- `String_Length` - 长度

### 注释
- `Comment` - 注释节点

---

## 组件类型 (10种)

| 组件 | 功能 |
|------|------|
| SpriteRenderer | 精灵渲染、颜色、翻转 |
| Animator | 动画播放控制 |
| Rigidbody | 物理刚体、重力、摩擦 |
| Collider | 碰撞检测（Box/Circle/Polygon） |
| Script | 挂载Lua脚本 |
| AudioSource | 音频播放、音量、空间音效 |
| ParticleSystem | 粒子特效系统 |
| Camera | 相机跟随、缩放、边界 |
| UIElement | UI文本、按钮、背景 |
| TileMapRenderer | 瓦片地图渲染 |

---

## 编译输出

节点图编译为标准的 Lua 代码，包含:
- 变量初始化
- 事件处理函数（OnGameStart, OnUpdate, OnKeyPress等）
- 数据流表达式求值
- 完整的控制流（if/else, for, while）

---

## 作者
RTeeq
