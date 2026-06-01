---
name: implement-2d-game-ide-overlay
description: 在运行中的2D游戏之上构建调试编辑器Overlay系统。按F1呼出/隐藏，不覆盖游戏本体，支持实时查看和修改游戏对象、组件属性、场景层级、资源引用。基于TapTap制造/UrhoX引擎+Lua技术栈，采用反射+钩子机制与运行中游戏交互。
---

# 2D游戏内调试编辑器Overlay实现指南

## 架构概述

编辑器Overlay是一个**寄生在游戏进程内的调试层**，而非独立IDE。核心原则：

- **零侵入**：不修改游戏代码，通过全局表反射和事件钩子获取游戏状态
- **叠加渲染**：使用独立UI层（ImGui/自定义）绘制在游戏画面之上
- **热键切换**：F1呼出/隐藏，ESC关闭当前面板
- **实时监听**：游戏对象增删、属性变更、日志输出实时同步到编辑器
- **可写回**：修改的属性即时生效到运行中的游戏对象

```
┌─────────────────────────────────────────────┐
│              游戏画面 (Game Render)            │
│  ┌─────────────────────────────────────┐    │
│  │  游戏对象、精灵、物理、粒子等         │    │
│  │                                     │    │
│  │    [Player]  [Enemy]  [UI]          │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  编辑器Overlay UI (半透明)            │    │
│  │  ┌────────┐ ┌────────┐ ┌─────────┐ │    │
│  │  │Hierarchy│ │Inspector│ │Console │ │    │
│  │  │ (左侧)  │ │ (右侧)  │ │(底部)  │ │    │
│  │  └────────┘ └────────┘ └─────────┘ │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │    EditorOverlay系统     │
        │  - 反射扫描游戏对象      │
        │  - 钩子游戏事件          │
        │  - 独立输入处理          │
        │  - 属性写回              │
        └─────────────────────────┘
```

## 1. 项目目录结构

```
EditorOverlay/
├── Core/
│   ├── EditorOverlay.lua          -- 编辑器主入口，生命周期管理
│   ├── HotkeyManager.lua          -- 热键系统（F1/ESC等）
│   ├── GameBridge.lua             -- 游戏反射桥接，访问运行中对象
│   ├── OverlayRenderer.lua        -- Overlay渲染管理器
│   └── InputInterceptor.lua       -- 输入拦截（编辑器激活时消费输入）
├── DataReflection/
│   ├── GameObjectScanner.lua      -- 游戏对象扫描器
│   ├── ComponentReflector.lua     -- 组件反射器
│   ├── SceneReflector.lua         -- 场景反射器
│   └── LuaTableInspector.lua      -- Lua表检视器
├── UI/
│   ├── OverlayUI.lua              -- Overlay UI根容器
│   ├── Panels/
│   │   ├── SceneOverlay.lua       -- 场景对象覆盖显示（选中框、Gizmo）
│   │   ├── HierarchyPanel.lua     -- 层级面板
│   │   ├── InspectorPanel.lua     -- 属性检视器
│   │   ├── ConsolePanel.lua       -- 控制台面板
│   │   ├── ProfilerPanel.lua      -- 性能分析器
│   │   └── AssetBrowserPanel.lua  -- 运行时资源浏览器
│   ├── Widgets/
│   │   ├── ImGuiWidgets.lua       -- ImGui封装控件
│   │   ├── TreeNode.lua           -- 树形节点
│   │   ├── PropertyField.lua      -- 属性字段
│   │   └── Vector3Field.lua       -- Vector3输入
│   └── Themes/
│       ├── DarkTheme.lua          -- 暗色主题
│       └── LightTheme.lua         -- 亮色主题
├── Tools/
│   ├── SelectionTool.lua          -- 选择工具
│   ├── MoveTool.lua               -- 移动工具
│   ├── InspectTool.lua            -- 检视工具
│   └── PauseTool.lua              -- 暂停/逐帧工具
└── Hooks/
    ├── LogHook.lua                -- 日志钩子
    ├── ErrorHook.lua              -- 错误钩子
    ├── SpawnHook.lua              -- 对象创建钩子
    └── DestroyHook.lua            -- 对象销毁钩子
```

## 2. 核心架构实现

### 2.1 EditorOverlay（主入口）

```lua
-- Core/EditorOverlay.lua
local EditorOverlay = {}
EditorOverlay.__index = EditorOverlay

function EditorOverlay.New()
    local self = setmetatable({}, EditorOverlay)

    -- 状态
    self.isVisible = false
    self.isGamePaused = false
    self.isFrameStepping = false
    self.currentTool = "select"
    self.selectedObject = nil
    self.hoveredObject = nil

    -- 子系统
    self.hotkey = require("Core/HotkeyManager").New(self)
    self.bridge = require("Core/GameBridge").New(self)
    self.renderer = require("Core/OverlayRenderer").New(self)
    self.inputInterceptor = require("Core/InputInterceptor").New(self)

    -- UI面板
    self.panels = {
        hierarchy = require("UI/Panels/HierarchyPanel").New(self),
        inspector = require("UI/Panels/InspectorPanel").New(self),
        console = require("UI/Panels/ConsolePanel").New(self),
        profiler = require("UI/Panels/ProfilerPanel").New(self),
        sceneOverlay = require("UI/Panels/SceneOverlay").New(self),
    }

    -- 工具
    self.tools = {
        select = require("Tools/SelectionTool").New(self),
        move = require("Tools/MoveTool").New(self),
        inspect = require("Tools/InspectTool").New(self),
    }

    -- 钩子
    self.hooks = {
        log = require("Hooks/LogHook").New(self),
        error = require("Hooks/ErrorHook").New(self),
        spawn = require("Hooks/SpawnHook").New(self),
        destroy = require("Hooks/DestroyHook").New(self),
    }

    -- 性能数据
    self.frameStats = {
        fps = 0,
        frameTime = 0,
        drawCalls = 0,
        triangleCount = 0,
        luaMemory = 0,
    }

    return self
end

function EditorOverlay:Init()
    -- 1. 安装钩子（必须在游戏启动早期调用）
    self:InstallHooks()

    -- 2. 初始化ImGui/自定义UI
    self.renderer:Init()

    -- 3. 注册热键
    self.hotkey:Register("F1", function() self:Toggle() end)
    self.hotkey:Register("ESC", function() self:OnEscape() end)
    self.hotkey:Register("F2", function() self.panels.profiler:Toggle() end)
    self.hotkey:Register("F11", function() self:ToggleFullscreen() end)
    self.hotkey:Register("SPACE", function() self:TogglePause() end)

    -- 4. 初始化桥接系统
    self.bridge:Init()

    -- 5. 注册到游戏更新循环
    self:HookGameUpdate()

    print("[EditorOverlay] Initialized. Press F1 to toggle.")
end

function EditorOverlay:Toggle()
    self.isVisible = not self.isVisible

    if self.isVisible then
        -- 激活编辑器：扫描当前场景
        self.bridge:ScanScene()
        self.inputInterceptor:Enable()
        self.renderer:ShowCursor(true)
        print("[EditorOverlay] Editor shown")
    else
        -- 隐藏编辑器：恢复游戏输入
        self.inputInterceptor:Disable()
        self.renderer:ShowCursor(false)
        self.selectedObject = nil
        print("[EditorOverlay] Editor hidden")
    end
end

function EditorOverlay:OnEscape()
    if not self.isVisible then return end

    if self.selectedObject then
        self.selectedObject = nil
    else
        self:Toggle()  -- 关闭编辑器
    end
end

function EditorOverlay:TogglePause()
    self.isGamePaused = not self.isGamePaused

    if self.isGamePaused then
        -- 暂停游戏时间
        self.bridge:SetTimeScale(0)
        print("[EditorOverlay] Game paused")
    else
        self.bridge:SetTimeScale(1)
        self.isFrameStepping = false
        print("[EditorOverlay] Game resumed")
    end
end

function EditorOverlay:StepFrame()
    if not self.isGamePaused then
        self:TogglePause()
    end
    self.isFrameStepping = true
    self.bridge:StepSingleFrame()
end

function EditorOverlay:Update(dt)
    -- 无论编辑器是否显示，都需要更新钩子
    self:UpdateHooks(dt)

    if not self.isVisible then return end

    -- 更新桥接（同步游戏状态）
    self.bridge:Update(dt)

    -- 更新性能统计
    self:UpdateFrameStats()

    -- 处理编辑器输入
    self.inputInterceptor:Update(dt)

    -- 更新当前工具
    local tool = self.tools[self.currentTool]
    if tool then
        tool:Update(dt)
    end

    -- 更新UI面板
    for _, panel in pairs(self.panels) do
        if panel.IsVisible and panel:IsVisible() then
            panel:Update(dt)
        end
    end
end

function EditorOverlay:Render()
    if not self.isVisible then
        -- 即使编辑器隐藏，仍渲染SceneOverlay（选中框等）
        if self.selectedObject then
            self.panels.sceneOverlay:RenderMinimal()
        end
        return
    end

    -- 开始ImGui帧
    self.renderer:BeginFrame()

    -- 渲染主菜单栏
    self:RenderMainMenuBar()

    -- 渲染停靠空间
    self.renderer:BeginDockSpace()

    -- 渲染各面板
    self.panels.hierarchy:Render()
    self.panels.inspector:Render()
    self.panels.console:Render()
    self.panels.profiler:Render()

    self.renderer:EndDockSpace()

    -- 渲染场景覆盖（Gizmo、选中框等，在游戏画面上方）
    self.panels.sceneOverlay:Render()

    -- 结束ImGui帧
    self.renderer:EndFrame()
end

function EditorOverlay:RenderMainMenuBar()
    if ImGui.BeginMainMenuBar() then
        if ImGui.BeginMenu("File") then
            if ImGui.MenuItem("Reload Scene", "Ctrl+R") then
                self.bridge:ReloadScene()
            end
            if ImGui.MenuItem("Export Scene State") then
                self:ExportSceneState()
            end
            ImGui.Separator()
            if ImGui.MenuItem("Hide Editor", "F1") then
                self:Toggle()
            end
            ImGui.EndMenu()
        end

        if ImGui.BeginMenu("Edit") then
            if ImGui.MenuItem("Undo", "Ctrl+Z", false, self.bridge:CanUndo()) then
                self.bridge:Undo()
            end
            if ImGui.MenuItem("Redo", "Ctrl+Y", false, self.bridge:CanRedo()) then
                self.bridge:Redo()
            end
            ImGui.Separator()
            if ImGui.MenuItem("Copy GameObject", "Ctrl+C") then
                self:CopySelected()
            end
            if ImGui.MenuItem("Paste GameObject", "Ctrl+V") then
                self:Paste()
            end
            if ImGui.MenuItem("Delete GameObject", "Delete") then
                self:DeleteSelected()
            end
            ImGui.EndMenu()
        end

        if ImGui.BeginMenu("GameObject") then
            if ImGui.MenuItem("Create Empty") then
                self.bridge:CreateEmptyGameObject()
            end
            ImGui.Separator()
            if ImGui.MenuItem("Move To View") then
                self:MoveSelectedToView()
            end
            if ImGui.MenuItem("Align With View") then
                self:AlignSelectedWithView()
            end
            ImGui.EndMenu()
        end

        if ImGui.BeginMenu("Tools") then
            if ImGui.MenuItem("Select", "Q", self.currentTool == "select") then
                self:SetTool("select")
            end
            if ImGui.MenuItem("Move", "W", self.currentTool == "move") then
                self:SetTool("move")
            end
            if ImGui.MenuItem("Inspect", "I", self.currentTool == "inspect") then
                self:SetTool("inspect")
            end
            ImGui.Separator()
            if ImGui.MenuItem("Pause", "Space", self.isGamePaused) then
                self:TogglePause()
            end
            if ImGui.MenuItem("Step", "Ctrl+.", false, self.isGamePaused) then
                self:StepFrame()
            end
            ImGui.EndMenu()
        end

        -- 右侧状态显示
        local windowWidth = ImGui.GetWindowWidth()
        local statusText = string.format("%.1f FPS | %.2f ms | %s",
            self.frameStats.fps,
            self.frameStats.frameTime * 1000,
            self.isGamePaused and "PAUSED" or "PLAYING"
        )
        local textWidth = ImGui.CalcTextSize(statusText)
        ImGui.SameLine(windowWidth - textWidth - 20)
        ImGui.Text(statusText)

        ImGui.EndMainMenuBar()
    end
end

function EditorOverlay:SetTool(toolName)
    local oldTool = self.tools[self.currentTool]
    if oldTool then oldTool:OnDeactivate() end

    self.currentTool = toolName

    local newTool = self.tools[toolName]
    if newTool then newTool:OnActivate() end
end

function EditorOverlay:SetSelectedObject(obj)
    self.selectedObject = obj
    self.panels.inspector:SetTarget(obj)
    self.panels.sceneOverlay:SetTarget(obj)
end

function EditorOverlay:HookGameUpdate()
    local originalUpdate = _G.Update or function() end
    _G.Update = function(dt)
        originalUpdate(dt)
        self:Update(dt)
    end

    local originalRender = _G.Render or function() end
    _G.Render = function()
        originalRender()
        self:Render()
    end
end

function EditorOverlay:InstallHooks()
    for name, hook in pairs(self.hooks) do
        hook:Install()
    end
end

function EditorOverlay:UpdateFrameStats()
    self.frameStats.fps = 1 / (self.frameStats.frameTime + 0.0001)
    self.frameStats.frameTime = self.bridge:GetDeltaTime()
    self.frameStats.drawCalls = self.bridge:GetDrawCallCount()
    self.frameStats.luaMemory = collectgarbage("count") / 1024
end

function EditorOverlay:ExportSceneState()
    local state = self.bridge:ExportCurrentScene()
    local json = json.encode(state)
    local path = "EditorExports/scene_" .. os.time() .. ".json"
    fs.WriteFile(path, json)
    print("[EditorOverlay] Scene exported to " .. path)
end

return EditorOverlay
```

### 2.2 GameBridge（游戏反射桥接）

这是最关键的部分——**不修改游戏代码，通过Lua全局表反射获取游戏状态**。

```lua
-- Core/GameBridge.lua
local GameBridge = {}
GameBridge.__index = GameBridge

function GameBridge.New(editor)
    local self = setmetatable({}, GameBridge)
    self.editor = editor

    -- 缓存的游戏对象引用
    self.scannedObjects = {}
    self.objectIdCounter = 0
    self.sceneRoot = nil

    -- 撤销栈（运行时修改）
    self.undoStack = {}
    self.redoStack = {}
    self.maxUndo = 50

    -- 已知游戏全局表名（根据实际游戏调整）
    self.knownGlobals = {
        "GameManager",
        "SceneManager",
        "EntityManager",
        "UIManager",
        "Player",
        "World",
        "Level",
        "Map",
        "Camera",
        "Entities",
        "GameObjects",
        "Actors",
        "Sprites",
        "Physics",
        "Audio",
    }

    return self
end

function GameBridge:Init()
    -- 自动发现游戏根对象
    self:DiscoverGameRoots()
end

-- 自动发现游戏全局根对象
function GameBridge:DiscoverGameRoots()
    self.gameRoots = {}

    for _, name in ipairs(self.knownGlobals) do
        local obj = _G[name]
        if obj then
            table.insert(self.gameRoots, {
                name = name,
                object = obj,
                type = type(obj),
            })
            print("[GameBridge] Discovered global: " .. name)
        end
    end

    -- 也扫描所有全局表
    for name, value in pairs(_G) do
        if type(value) == "table" and not name:match("^__") then
            if self:IsGameObjectTable(value) then
                local found = false
                for _, root in ipairs(self.gameRoots) do
                    if root.name == name then found = true break end
                end
                if not found then
                    table.insert(self.gameRoots, {
                        name = name,
                        object = value,
                        type = "auto_discovered",
                    })
                end
            end
        end
    end
end

-- 判断一个表是否是游戏对象容器
function GameBridge:IsGameObjectTable(t)
    if #t > 0 and type(t[1]) == "table" then
        local first = t[1]
        if first.x ~= nil or first.position ~= nil or first.transform ~= nil 
           or first.name ~= nil or first.id ~= nil then
            return true
        end
    end

    local gameKeys = {x=0, y=0, position=0, rotation=0, scale=0, 
                      name=0, active=0, visible=0, sprite=0, 
                      children=0, components=0, parent=0}
    local matchCount = 0
    for key, _ in pairs(t) do
        if gameKeys[key] ~= nil then
            matchCount = matchCount + 1
        end
    end

    return matchCount >= 2
end

-- 扫描整个场景对象树
function GameBridge:ScanScene()
    self.scannedObjects = {}
    self.objectIdCounter = 0

    for _, root in ipairs(self.gameRoots) do
        self:ScanObject(root.object, root.name, nil, 0)
    end

    -- 也扫描UrhoX场景（如果可用）
    if _G.scene then
        self:ScanUrhoXScene(_G.scene)
    end
end

function GameBridge:ScanObject(obj, name, parent, depth)
    if type(obj) ~= "table" then return nil end

    -- 避免循环引用
    if obj.__editor_id then
        return self.scannedObjects[obj.__editor_id]
    end

    self.objectIdCounter = self.objectIdCounter + 1
    local id = self.objectIdCounter
    obj.__editor_id = id

    local info = {
        id = id,
        name = name or (obj.name or ("Object_" .. id)),
        type = self:DetermineObjectType(obj),
        object = obj,
        parent = parent,
        children = {},
        depth = depth,
        properties = {},
        components = {},
    }

    self.scannedObjects[id] = info

    -- 扫描属性
    self:ScanProperties(info)

    -- 扫描子对象
    if obj.children then
        for i, child in ipairs(obj.children) do
            local childInfo = self:ScanObject(child, child.name or ("Child_" .. i), info, depth + 1)
            if childInfo then
                table.insert(info.children, childInfo)
            end
        end
    end

    -- 扫描数组形式的子对象
    if #obj > 0 then
        for i, child in ipairs(obj) do
            if type(child) == "table" then
                local childInfo = self:ScanObject(child, child.name or ("Item_" .. i), info, depth + 1)
                if childInfo then
                    table.insert(info.children, childInfo)
                end
            end
        end
    end

    -- 扫描UrhoX节点
    if obj.GetChildren then
        local urhoChildren = obj:GetChildren()
        for _, child in ipairs(urhoChildren) do
            local childInfo = self:ScanObject(child, child.name or "Node", info, depth + 1)
            if childInfo then
                table.insert(info.children, childInfo)
            end
        end
    end

    return info
end

-- 扫描对象属性
function GameBridge:ScanProperties(info)
    local obj = info.object
    local props = info.properties

    local standardProps = {
        {key = "name", type = "string"},
        {key = "active", type = "bool", aliases = {"visible", "enabled", "isActive"}},
        {key = "position", type = "Vector3", aliases = {"pos", "Position", "worldPosition"}},
        {key = "rotation", type = "number", aliases = {"angle", "rot", "Rotation"}},
        {key = "scale", type = "Vector2", aliases = {"Scale", "size", "Size"}},
        {key = "layer", type = "int", aliases = {"sortingLayer", "zOrder"}},
        {key = "tag", type = "string", aliases = {"Tag", "category"}},
        {key = "velocity", type = "Vector2", aliases = {"Velocity", "speed"}},
        {key = "color", type = "Color", aliases = {"tint", "Color", "modulate"}},
        {key = "alpha", type = "number", aliases = {"opacity", "Opacity"}},
    }

    for _, propDef in ipairs(standardProps) do
        local value = obj[propDef.key]

        if value == nil and propDef.aliases then
            for _, alias in ipairs(propDef.aliases) do
                value = obj[alias]
                if value ~= nil then break end
            end
        end

        if value ~= nil then
            table.insert(props, {
                name = propDef.key,
                type = propDef.type,
                value = value,
                key = propDef.key,
                editable = true,
            })
        end
    end

    -- 扫描自定义字段
    for key, value in pairs(obj) do
        if type(key) == "string" 
           and not key:match("^_") 
           and not key:match("^__")
           and type(value) ~= "function"
           and type(value) ~= "userdata"
           and type(value) ~= "thread" then

            local exists = false
            for _, p in ipairs(props) do
                if p.name == key then exists = true break end
            end

            if not exists then
                local propType = self:DetermineValueType(value)
                table.insert(props, {
                    name = key,
                    type = propType,
                    value = value,
                    key = key,
                    editable = propType ~= "unknown" and propType ~= "table",
                })
            end
        end
    end
end

-- 判断对象类型
function GameBridge:DetermineObjectType(obj)
    if obj.GetType then
        local ok, typeName = pcall(function() return obj:GetType() end)
        if ok and typeName then return typeName end
    end

    if obj.type then return obj.type end
    if obj.class then return obj.class end
    if obj.__class then return obj.__class end

    if obj.sprite or obj.texture or obj.image then return "Sprite" end
    if obj.body or obj.fixture or obj.shape then return "PhysicsBody" end
    if obj.camera then return "Camera" end
    if obj.text or obj.font then return "Text" end
    if obj.particle then return "Particle" end

    return "GameObject"
end

-- 判断值类型
function GameBridge:DetermineValueType(value)
    local t = type(value)
    if t == "number" then
        if math.floor(value) == value then
            return "int"
        else
            return "float"
        end
    elseif t == "string" then
        return "string"
    elseif t == "boolean" then
        return "bool"
    elseif t == "table" then
        if value.x ~= nil and value.y ~= nil then
            if value.z ~= nil then
                return "Vector3"
            else
                return "Vector2"
            end
        elseif value.r ~= nil and value.g ~= nil then
            return "Color"
        elseif #value > 0 then
            return "array"
        else
            return "table"
        end
    end
    return "unknown"
end

-- 获取属性值（支持Getter方法）
function GameBridge:GetPropertyValue(obj, propName)
    local value = obj[propName]
    if value ~= nil then return value end

    local getterName = "Get" .. propName:sub(1,1):upper() .. propName:sub(2)
    if obj[getterName] and type(obj[getterName]) == "function" then
        local ok, result = pcall(obj[getterName], obj)
        if ok then return result end
    end

    local aliases = {
        position = {"pos", "Position", "worldPosition"},
        rotation = {"angle", "rot", "Rotation"},
        scale = {"Scale", "size", "Size"},
        active = {"visible", "enabled", "isActive"},
    }

    if aliases[propName] then
        for _, alias in ipairs(aliases[propName]) do
            value = obj[alias]
            if value ~= nil then return value end
        end
    end

    return nil
end

-- 设置属性值（支持Setter方法）
function GameBridge:SetPropertyValue(obj, propName, newValue, oldValue)
    self:PushUndo({
        target = obj,
        property = propName,
        oldValue = oldValue,
        newValue = newValue,
    })

    if obj[propName] ~= nil then
        obj[propName] = newValue
        return true
    end

    local setterName = "Set" .. propName:sub(1,1):upper() .. propName:sub(2)
    if obj[setterName] and type(obj[setterName]) == "function" then
        local ok = pcall(obj[setterName], obj, newValue)
        if ok then return true end
    end

    local aliases = {
        position = {"pos", "Position"},
        rotation = {"angle", "rot", "Rotation"},
        scale = {"Scale", "size", "Size"},
        active = {"visible", "enabled", "isActive"},
    }

    if aliases[propName] then
        for _, alias in ipairs(aliases[propName]) do
            if obj[alias] ~= nil then
                obj[alias] = newValue
                return true
            end
        end
    end

    obj[propName] = newValue
    return true
end

-- 创建空GameObject
function GameBridge:CreateEmptyGameObject()
    local go = {
        name = "New GameObject",
        x = 0,
        y = 0,
        active = true,
        children = {},
    }

    if _G.scene and _G.scene.AddChild then
        _G.scene:AddChild(go)
    elseif _G.GameObjects then
        table.insert(_G.GameObjects, go)
    end

    self:ScanScene()
    return go
end

-- 删除选中对象
function GameBridge:DeleteObject(obj)
    if obj.parent and obj.parent.children then
        for i, child in ipairs(obj.parent.children) do
            if child == obj then
                table.remove(obj.parent.children, i)
                break
            end
        end
    end

    if _G.GameObjects then
        for i, go in ipairs(_G.GameObjects) do
            if go == obj then
                table.remove(_G.GameObjects, i)
                break
            end
        end
    end

    if obj.Destroy then
        pcall(obj.Destroy, obj)
    elseif obj.destroy then
        pcall(obj.destroy, obj)
    end

    self:ScanScene()
end

-- 时间控制
function GameBridge:SetTimeScale(scale)
    if _G.Time then
        _G.Time.timeScale = scale
    end
    if _G.timeScale then
        _G.timeScale = scale
    end
    if _G.engine and _G.engine.SetTimeScale then
        _G.engine:SetTimeScale(scale)
    end
    if _G.context and _G.context.timeScale then
        _G.context.timeScale = scale
    end

    if scale == 0 then
        if _G.physics then
            _G.physics:Pause()
        end
    else
        if _G.physics then
            _G.physics:Resume()
        end
    end
end

function GameBridge:GetDeltaTime()
    if _G.Time and _G.Time.deltaTime then
        return _G.Time.deltaTime
    end
    if _G.dt then
        return _G.dt
    end
    if _G.deltaTime then
        return _G.deltaTime
    end
    return 0.016
end

function GameBridge:GetDrawCallCount()
    if _G.renderer and _G.renderer.GetNumPrimitives then
        return _G.renderer:GetNumPrimitives()
    end
    return 0
end

-- 导出当前场景状态
function GameBridge:ExportCurrentScene()
    local export = {
        timestamp = os.time(),
        objects = {},
    }

    for id, info in pairs(self.scannedObjects) do
        if info.depth == 0 then
            table.insert(export.objects, self:ExportObject(info))
        end
    end

    return export
end

function GameBridge:ExportObject(info)
    local obj = info.object
    local export = {
        name = info.name,
        type = info.type,
        properties = {},
        children = {},
    }

    for _, prop in ipairs(info.properties) do
        if prop.editable then
            export.properties[prop.name] = prop.value
        end
    end

    for _, child in ipairs(info.children) do
        table.insert(export.children, self:ExportObject(child))
    end

    return export
end

-- Undo/Redo
function GameBridge:PushUndo(action)
    table.insert(self.undoStack, action)
    if #self.undoStack > self.maxUndo then
        table.remove(self.undoStack, 1)
    end
    self.redoStack = {}
end

function GameBridge:Undo()
    if #self.undoStack == 0 then return end
    local action = table.remove(self.undoStack)
    self:SetPropertyValue(action.target, action.property, action.oldValue, nil)
    table.insert(self.redoStack, action)
end

function GameBridge:Redo()
    if #self.redoStack == 0 then return end
    local action = table.remove(self.redoStack)
    self:SetPropertyValue(action.target, action.property, action.newValue, nil)
    table.insert(self.undoStack, action)
end

function GameBridge:CanUndo()
    return #self.undoStack > 0
end

function GameBridge:CanRedo()
    return #self.redoStack > 0
end

-- 扫描UrhoX特定场景
function GameBridge:ScanUrhoXScene(scene)
    if not scene then return end
    if scene.GetChildren then
        local children = scene:GetChildren()
        for _, node in ipairs(children) do
            self:ScanUrhoXNode(node, nil, 0)
        end
    end
end

function GameBridge:ScanUrhoXNode(node, parent, depth)
    if not node then return end

    self.objectIdCounter = self.objectIdCounter + 1
    local id = self.objectIdCounter

    local info = {
        id = id,
        name = node.name or ("Node_" .. id),
        type = "UrhoNode",
        object = node,
        parent = parent,
        children = {},
        depth = depth,
        properties = {},
        components = {},
    }

    if node.GetComponents then
        local comps = node:GetComponents()
        for _, comp in ipairs(comps) do
            table.insert(info.components, {
                name = comp:GetTypeName and comp:GetTypeName() or "Component",
                object = comp,
            })
        end
    end

    if node.position then
        table.insert(info.properties, {
            name = "position",
            type = "Vector3",
            value = node.position,
            key = "position",
            editable = true,
        })
    end
    if node.rotation then
        table.insert(info.properties, {
            name = "rotation",
            type = "Quaternion",
            value = node.rotation,
            key = "rotation",
            editable = true,
        })
    end
    if node.scale then
        table.insert(info.properties, {
            name = "scale",
            type = "Vector3",
            value = node.scale,
            key = "scale",
            editable = true,
        })
    end

    self.scannedObjects[id] = info

    if node.GetChildren then
        local children = node:GetChildren()
        for _, child in ipairs(children) do
            local childInfo = self:ScanUrhoXNode(child, info, depth + 1)
            if childInfo then
                table.insert(info.children, childInfo)
            end
        end
    end

    return info
end

return GameBridge
```

### 2.3 HotkeyManager（热键系统）

```lua
-- Core/HotkeyManager.lua
local HotkeyManager = {}
HotkeyManager.__index = HotkeyManager

function HotkeyManager.New(editor)
    local self = setmetatable({}, HotkeyManager)
    self.editor = editor
    self.bindings = {}
    self.pressedKeys = {}
    self.wasKeyDown = {}
    return self
end

function HotkeyManager:Register(key, callback, modifiers)
    modifiers = modifiers or {}
    self.bindings[key:upper()] = {
        callback = callback,
        ctrl = modifiers.ctrl or false,
        shift = modifiers.shift or false,
        alt = modifiers.alt or false,
    }
end

function HotkeyManager:Unregister(key)
    self.bindings[key:upper()] = nil
end

function HotkeyManager:Update(dt)
    local input = self:GetInputState()

    for key, binding in pairs(self.bindings) do
        local isDown = input:IsKeyDown(key)
        local wasDown = self.wasKeyDown[key] or false

        if isDown and not wasDown then
            local ctrlOk = (binding.ctrl == input:IsKeyDown("CTRL"))
            local shiftOk = (binding.shift == input:IsKeyDown("SHIFT"))
            local altOk = (binding.alt == input:IsKeyDown("ALT"))

            if ctrlOk and shiftOk and altOk then
                binding.callback()
            end
        end

        self.wasKeyDown[key] = isDown
    end
end

function HotkeyManager:GetInputState()
    if _G.Input then
        return {
            IsKeyDown = function(_, key) 
                return _G.Input:IsKeyDown(key) 
            end,
        }
    elseif _G.keyboard then
        return {
            IsKeyDown = function(_, key)
                return _G.keyboard.isDown and _G.keyboard.isDown(key:lower())
            end,
        }
    elseif _G.love and _G.love.keyboard then
        return {
            IsKeyDown = function(_, key)
                return _G.love.keyboard.isDown(key:lower())
            end,
        }
    end

    return {IsKeyDown = function() return false end}
end

return HotkeyManager
```

### 2.4 InputInterceptor（输入拦截）

```lua
-- Core/InputInterceptor.lua
local InputInterceptor = {}
InputInterceptor.__index = InputInterceptor

function InputInterceptor.New(editor)
    local self = setmetatable({}, InputInterceptor)
    self.editor = editor
    self.enabled = false
    self.originalCallbacks = {}
    return self
end

function InputInterceptor:Enable()
    if self.enabled then return end
    self.enabled = true
    self:HookInputSystem()
end

function InputInterceptor:Disable()
    if not self.enabled then return end
    self.enabled = false
    self:RestoreInputSystem()
end

function InputInterceptor:HookInputSystem()
    if _G.Input then
        self.originalCallbacks.mouseDown = _G.Input.mouseDownCallback
        self.originalCallbacks.mouseMove = _G.Input.mouseMoveCallback
        self.originalCallbacks.mouseUp = _G.Input.mouseUpCallback
        self.originalCallbacks.keyDown = _G.Input.keyDownCallback

        _G.Input.mouseDownCallback = function(...) return self:OnMouseDown(...) end
        _G.Input.mouseMoveCallback = function(...) return self:OnMouseMove(...) end
        _G.Input.mouseUpCallback = function(...) return self:OnMouseUp(...) end
        _G.Input.keyDownCallback = function(...) return self:OnKeyDown(...) end
    end

    if _G.love then
        self.originalCallbacks.loveMousePressed = _G.love.mousepressed
        self.originalCallbacks.loveMouseMoved = _G.love.mousemoved
        self.originalCallbacks.loveMouseReleased = _G.love.mousereleased
        self.originalCallbacks.loveKeyPressed = _G.love.keypressed

        _G.love.mousepressed = function(...) return self:OnLoveMousePressed(...) end
        _G.love.mousemoved = function(...) return self:OnLoveMouseMoved(...) end
        _G.love.mousereleased = function(...) return self:OnLoveMouseReleased(...) end
        _G.love.keypressed = function(...) return self:OnLoveKeyPressed(...) end
    end
end

function InputInterceptor:RestoreInputSystem()
    if _G.Input then
        _G.Input.mouseDownCallback = self.originalCallbacks.mouseDown
        _G.Input.mouseMoveCallback = self.originalCallbacks.mouseMove
        _G.Input.mouseUpCallback = self.originalCallbacks.mouseUp
        _G.Input.keyDownCallback = self.originalCallbacks.keyDown
    end

    if _G.love then
        _G.love.mousepressed = self.originalCallbacks.loveMousePressed
        _G.love.mousemoved = self.originalCallbacks.loveMouseMoved
        _G.love.mousereleased = self.originalCallbacks.loveMouseReleased
        _G.love.keypressed = self.originalCallbacks.loveKeyPressed
    end
end

function InputInterceptor:OnMouseDown(x, y, button)
    if not self.enabled then
        if self.originalCallbacks.mouseDown then
            return self.originalCallbacks.mouseDown(x, y, button)
        end
        return false
    end

    if self.editor.renderer:IsPointOverUI(x, y) then
        return true
    end

    local tool = self.editor.tools[self.editor.currentTool]
    if tool and tool.OnMouseDown then
        local consumed = tool:OnMouseDown(x, y, button)
        if consumed then return true end
    end

    if self.originalCallbacks.mouseDown then
        return self.originalCallbacks.mouseDown(x, y, button)
    end
    return false
end

function InputInterceptor:OnMouseMove(x, y, dx, dy)
    if not self.enabled then
        if self.originalCallbacks.mouseMove then
            return self.originalCallbacks.mouseMove(x, y, dx, dy)
        end
        return false
    end

    if self.editor.renderer:IsPointOverUI(x, y) then
        return true
    end

    local tool = self.editor.tools[self.editor.currentTool]
    if tool and tool.OnMouseMove then
        local consumed = tool:OnMouseMove(x, y, dx, dy)
        if consumed then return true end
    end

    if self.originalCallbacks.mouseMove then
        return self.originalCallbacks.mouseMove(x, y, dx, dy)
    end
    return false
end

function InputInterceptor:OnMouseUp(x, y, button)
    if not self.enabled then
        if self.originalCallbacks.mouseUp then
            return self.originalCallbacks.mouseUp(x, y, button)
        end
        return false
    end

    local tool = self.editor.tools[self.editor.currentTool]
    if tool and tool.OnMouseUp then
        tool:OnMouseUp(x, y, button)
    end

    if self.originalCallbacks.mouseUp then
        return self.originalCallbacks.mouseUp(x, y, button)
    end
    return false
end

function InputInterceptor:OnKeyDown(key)
    self.editor.hotkey:Update(0)

    if not self.enabled then
        if self.originalCallbacks.keyDown then
            return self.originalCallbacks.keyDown(key)
        end
        return false
    end

    if key == "F1" or key == "ESC" then
        return false
    end

    if self.editor.renderer:IsKeyboardFocused() then
        return true
    end

    if self.originalCallbacks.keyDown then
        return self.originalCallbacks.keyDown(key)
    end
    return false
end

function InputInterceptor:OnLoveMousePressed(x, y, button, istouch, presses)
    local consumed = self:OnMouseDown(x, y, button)
    if not consumed and self.originalCallbacks.loveMousePressed then
        self.originalCallbacks.loveMousePressed(x, y, button, istouch, presses)
    end
end

function InputInterceptor:OnLoveMouseMoved(x, y, dx, dy, istouch)
    local consumed = self:OnMouseMove(x, y, dx, dy)
    if not consumed and self.originalCallbacks.loveMouseMoved then
        self.originalCallbacks.loveMouseMoved(x, y, dx, dy, istouch)
    end
end

function InputInterceptor:OnLoveMouseReleased(x, y, button, istouch, presses)
    local consumed = self:OnMouseUp(x, y, button)
    if not consumed and self.originalCallbacks.loveMouseReleased then
        self.originalCallbacks.loveMouseReleased(x, y, button, istouch, presses)
    end
end

function InputInterceptor:OnLoveKeyPressed(key, scancode, isrepeat)
    local consumed = self:OnKeyDown(key:upper())
    if not consumed and self.originalCallbacks.loveKeyPressed then
        self.originalCallbacks.loveKeyPressed(key, scancode, isrepeat)
    end
end

return InputInterceptor
```

### 2.5 OverlayRenderer（渲染管理器）

```lua
-- Core/OverlayRenderer.lua
local OverlayRenderer = {}
OverlayRenderer.__index = OverlayRenderer

function OverlayRenderer.New(editor)
    local self = setmetatable({}, OverlayRenderer)
    self.editor = editor
    self.imgui = nil
    self.font = nil
    self.cursorVisible = false
    self.isPointOverUI = false
    return self
end

function OverlayRenderer:Init()
    if _G.ImGui or _G.imgui then
        self.imgui = _G.ImGui or _G.imgui
        self:SetupImGui()
    else
        self:InitCustomRenderer()
    end
end

function OverlayRenderer:SetupImGui()
    local style = self.imgui.GetStyle()
    self.imgui.StyleColorsDark()

    style.WindowPadding = {8, 8}
    style.FramePadding = {4, 3}
    style.ItemSpacing = {6, 4}
    style.ItemInnerSpacing = {4, 4}
    style.IndentSpacing = 16
    style.ScrollbarSize = 12
    style.GrabMinSize = 10

    local colors = style.Colors
    colors[self.imgui.Col_WindowBg] = {0.11, 0.11, 0.11, 0.95}
    colors[self.imgui.Col_TitleBg] = {0.14, 0.14, 0.14, 1.0}
    colors[self.imgui.Col_TitleBgActive] = {0.18, 0.18, 0.18, 1.0}
    colors[self.imgui.Col_Tab] = {0.12, 0.12, 0.12, 1.0}
    colors[self.imgui.Col_TabActive] = {0.22, 0.48, 0.82, 1.0}
    colors[self.imgui.Col_Button] = {0.18, 0.18, 0.18, 1.0}
    colors[self.imgui.Col_ButtonHovered] = {0.25, 0.25, 0.25, 1.0}
    colors[self.imgui.Col_ButtonActive] = {0.30, 0.30, 0.30, 1.0}
    colors[self.imgui.Col_FrameBg] = {0.15, 0.15, 0.15, 1.0}
    colors[self.imgui.Col_FrameBgHovered] = {0.20, 0.20, 0.20, 1.0}
    colors[self.imgui.Col_FrameBgActive] = {0.25, 0.25, 0.25, 1.0}
    colors[self.imgui.Col_Header] = {0.18, 0.36, 0.64, 0.6}
    colors[self.imgui.Col_HeaderHovered] = {0.22, 0.44, 0.78, 0.8}
    colors[self.imgui.Col_HeaderActive] = {0.25, 0.50, 0.90, 1.0}

    -- 字体
    local io = self.imgui.GetIO()
    self.font = io.Fonts:AddFontFromFileTTF("EditorOverlay/Fonts/NotoSans-Regular.ttf", 14)
    if not self.font then
        -- 回退到默认字体
        self.font = io.Fonts:AddFontDefault()
    end
end

function OverlayRenderer:InitCustomRenderer()
    -- 无ImGui时的自定义渲染方案
    self.customUI = {
        panels = {},
        drawList = {},
    }
    print("[OverlayRenderer] Using custom renderer (no ImGui available)")
end

function OverlayRenderer:BeginFrame()
    if self.imgui then
        self.imgui.NewFrame()
    else
        self.customUI.drawList = {}
    end
end

function OverlayRenderer:EndFrame()
    if self.imgui then
        self.imgui.Render()
    else
        self:RenderCustomUI()
    end
end

function OverlayRenderer:BeginDockSpace()
    if not self.imgui then return end

    local viewport = self.imgui.GetMainViewport()
    self.imgui.SetNextWindowPos(viewport.WorkPos)
    self.imgui.SetNextWindowSize(viewport.WorkSize)
    self.imgui.SetNextWindowViewport(viewport.ID)

    local windowFlags = self.imgui.WindowFlags_MenuBar 
        + self.imgui.WindowFlags_NoDocking
        + self.imgui.WindowFlags_NoTitleBar
        + self.imgui.WindowFlags_NoCollapse
        + self.imgui.WindowFlags_NoResize
        + self.imgui.WindowFlags_NoMove
        + self.imgui.WindowFlags_NoBringToFrontOnFocus
        + self.imgui.WindowFlags_NoNavFocus
        + self.imgui.WindowFlags_NoBackground

    self.imgui.PushStyleVar(self.imgui.StyleVar_WindowRounding, 0)
    self.imgui.PushStyleVar(self.imgui.StyleVar_WindowBorderSize, 0)
    self.imgui.PushStyleVar(self.imgui.StyleVar_WindowPadding, {0, 0})

    local dockspaceOpen = true
    self.imgui.Begin("DockSpace", dockspaceOpen, windowFlags)

    self.imgui.PopStyleVar(3)

    local dockspaceID = self.imgui.GetID("MainDockSpace")
    local dockspaceFlags = self.imgui.DockNodeFlags_PassthruCentralNode
    self.imgui.DockSpace(dockspaceID, {0, 0}, dockspaceFlags)
end

function OverlayRenderer:EndDockSpace()
    if not self.imgui then return end
    self.imgui.End()
end

function OverlayRenderer:IsPointOverUI(x, y)
    if not self.imgui then return false end
    return self.imgui.IsAnyItemHovered() or self.imgui.IsWindowHovered(self.imgui.HoveredFlags_AnyWindow)
end

function OverlayRenderer:IsKeyboardFocused()
    if not self.imgui then return false end
    return self.imgui.IsAnyItemActive()
end

function OverlayRenderer:ShowCursor(show)
    self.cursorVisible = show
    if _G.Input then
        _G.Input:SetCursorVisible(show)
    end
    if _G.love then
        _G.love.mouse.setVisible(show)
    end
end

-- 自定义渲染（无ImGui时使用）
function OverlayRenderer:RenderCustomUI()
    -- 使用引擎原生2D绘制API
    for _, cmd in ipairs(self.customUI.drawList) do
        if cmd.type == "rect" then
            -- 绘制矩形
        elseif cmd.type == "text" then
            -- 绘制文字
        elseif cmd.type == "line" then
            -- 绘制线条
        end
    end
end

return OverlayRenderer
```

## 3. UI面板实现

### 3.1 HierarchyPanel（层级面板）

```lua
-- UI/Panels/HierarchyPanel.lua
local HierarchyPanel = {}
HierarchyPanel.__index = HierarchyPanel

function HierarchyPanel.New(editor)
    local self = setmetatable({}, HierarchyPanel)
    self.editor = editor
    self.isVisible = true
    self.searchText = ""
    self.expandedNodes = {}
    return self
end

function HierarchyPanel:Toggle()
    self.isVisible = not self.isVisible
end

function HierarchyPanel:IsVisible()
    return self.isVisible
end

function HierarchyPanel:Render()
    if not self.isVisible then return end

    if self.editor.renderer.imgui then
        self:RenderImGui()
    else
        self:RenderCustom()
    end
end

function HierarchyPanel:RenderImGui()
    local imgui = self.editor.renderer.imgui

    local flags = imgui.WindowFlags_None
    if imgui.Begin("Hierarchy", self.isVisible, flags) then
        -- 搜索框
        local changed, newText = imgui.InputText("Search", self.searchText, 256)
        if changed then
            self.searchText = newText
        end

        imgui.Separator()

        -- 树形列表
        if imgui.BeginChild("HierarchyTree", {0, 0}, false, imgui.WindowFlags_None) then
            local bridge = self.editor.bridge

            for id, info in pairs(bridge.scannedObjects) do
                if info.depth == 0 then
                    self:RenderTreeNode(info)
                end
            end

            imgui.EndChild()
        end

        imgui.End()
    end
end

function HierarchyPanel:RenderTreeNode(info)
    local imgui = self.editor.renderer.imgui

    -- 过滤
    if self.searchText ~= "" then
        if not info.name:lower():find(self.searchText:lower()) then
            -- 如果有匹配的子节点，仍然显示
            local hasMatch = false
            for _, child in ipairs(info.children) do
                if self:HasSearchMatch(child) then
                    hasMatch = true
                    break
                end
            end
            if not hasMatch then return end
        end
    end

    local nodeFlags = imgui.TreeNodeFlags_OpenOnArrow
        + imgui.TreeNodeFlags_OpenOnDoubleClick
        + imgui.TreeNodeFlags_SpanAvailWidth

    if #info.children == 0 then
        nodeFlags = nodeFlags + imgui.TreeNodeFlags_Leaf
    end

    -- 选中状态
    if self.editor.selectedObject and self.editor.selectedObject.id == info.id then
        nodeFlags = nodeFlags + imgui.TreeNodeFlags_Selected
    end

    -- 图标
    local icon = self:GetObjectIcon(info.type)
    local label = icon .. " " .. info.name

    local isOpen = imgui.TreeNodeEx(label, nodeFlags, info.id)

    -- 点击选中
    if imgui.IsItemClicked() then
        self.editor:SetSelectedObject(info)
    end

    -- 右键菜单
    if imgui.BeginPopupContextItem() then
        if imgui.MenuItem("Copy") then
            self.editor:CopySelected()
        end
        if imgui.MenuItem("Paste") then
            self.editor:Paste()
        end
        imgui.Separator()
        if imgui.MenuItem("Delete") then
            self.editor.bridge:DeleteObject(info.object)
            self.editor.selectedObject = nil
        end
        if imgui.MenuItem("Rename") then
            -- 打开重命名对话框
        end
        imgui.EndPopup()
    end

    -- 拖拽
    if imgui.BeginDragDropSource(imgui.DragDropFlags_None) then
        imgui.SetDragDropPayload("HIERARCHY_NODE", info.id, 4)
        imgui.Text("Moving: " .. info.name)
        imgui.EndDragDropSource()
    end

    if imgui.BeginDragDropTarget() then
        local payload = imgui.AcceptDragDropPayload("HIERARCHY_NODE")
        if payload then
            local draggedId = payload.Data
            local draggedInfo = self.editor.bridge.scannedObjects[draggedId]
            if draggedInfo then
                -- 设置为子对象
                draggedInfo.object.parent = info.object
                table.insert(info.object.children, draggedInfo.object)
                self.editor.bridge:ScanScene()
            end
        end
        imgui.EndDragDropTarget()
    end

    if isOpen then
        for _, child in ipairs(info.children) do
            self:RenderTreeNode(child)
        end
        imgui.TreePop()
    end
end

function HierarchyPanel:HasSearchMatch(info)
    if info.name:lower():find(self.searchText:lower()) then
        return true
    end
    for _, child in ipairs(info.children) do
        if self:HasSearchMatch(child) then
            return true
        end
    end
    return false
end

function HierarchyPanel:GetObjectIcon(typeName)
    local icons = {
        Sprite = "[IMG]",
        Camera = "[CAM]",
        PhysicsBody = "[PHY]",
        Text = "[TXT]",
        Particle = "[PAR]",
        UrhoNode = "[NODE]",
        GameObject = "[GO]",
    }
    return icons[typeName] or "[?]"
end

function HierarchyPanel:RenderCustom()
    -- 自定义渲染实现
end

return HierarchyPanel
```

### 3.2 InspectorPanel（属性检视器）

```lua
-- UI/Panels/InspectorPanel.lua
local InspectorPanel = {}
InspectorPanel.__index = InspectorPanel

function InspectorPanel.New(editor)
    local self = setmetatable({}, InspectorPanel)
    self.editor = editor
    self.isVisible = true
    self.target = nil
    self.targetProperties = {}
    return self
end

function InspectorPanel:Toggle()
    self.isVisible = not self.isVisible
end

function InspectorPanel:IsVisible()
    return self.isVisible
end

function InspectorPanel:SetTarget(info)
    self.target = info
    if info then
        self.targetProperties = info.properties or {}
    else
        self.targetProperties = {}
    end
end

function InspectorPanel:Render()
    if not self.isVisible then return end

    local imgui = self.editor.renderer.imgui
    if not imgui then return end

    local flags = imgui.WindowFlags_None
    if imgui.Begin("Inspector", self.isVisible, flags) then
        if not self.target then
            imgui.TextDisabled("No object selected")
        else
            self:RenderObjectInspector()
        end
        imgui.End()
    end
end

function InspectorPanel:RenderObjectInspector()
    local imgui = self.editor.renderer.imgui
    local info = self.target

    -- 对象名称和类型
    imgui.Text(info.name)
    imgui.SameLine()
    imgui.TextDisabled("(" .. info.type .. ")")
    imgui.Separator()

    -- 基础属性（名称、Active等）
    self:RenderNameField()
    self:RenderActiveToggle()

    imgui.Separator()

    -- Transform属性（如果有）
    self:RenderTransformSection()

    imgui.Separator()

    -- 其他属性
    imgui.Text("Properties")
    for _, prop in ipairs(self.targetProperties) do
        self:RenderPropertyField(prop)
    end

    -- 组件列表（UrhoX）
    if info.components and #info.components > 0 then
        imgui.Separator()
        imgui.Text("Components")
        for _, comp in ipairs(info.components) do
            if imgui.CollapsingHeader(comp.name) then
                self:RenderComponentProperties(comp)
            end
        end
    end
end

function InspectorPanel:RenderNameField()
    local imgui = self.editor.renderer.imgui
    local info = self.target

    local changed, newName = imgui.InputText("Name", info.name, 256)
    if changed then
        local oldName = info.name
        info.name = newName
        info.object.name = newName
        self.editor.bridge:PushUndo({
            target = info.object,
            property = "name",
            oldValue = oldName,
            newValue = newName,
        })
    end
end

function InspectorPanel:RenderActiveToggle()
    local imgui = self.editor.renderer.imgui
    local info = self.target

    local active = info.object.active or info.object.visible or info.object.enabled or true
    local changed, newActive = imgui.Checkbox("Active", active)
    if changed then
        local oldActive = active
        if info.object.active ~= nil then info.object.active = newActive end
        if info.object.visible ~= nil then info.object.visible = newActive end
        if info.object.enabled ~= nil then info.object.enabled = newActive end

        self.editor.bridge:PushUndo({
            target = info.object,
            property = "active",
            oldValue = oldActive,
            newValue = newActive,
        })
    end
end

function InspectorPanel:RenderTransformSection()
    local imgui = self.editor.renderer.imgui
    local info = self.target
    local obj = info.object

    if imgui.CollapsingHeader("Transform", imgui.TreeNodeFlags_DefaultOpen) then
        -- Position
        local pos = self.editor.bridge:GetPropertyValue(obj, "position")
        if pos then
            local x, y, z = pos.x or 0, pos.y or 0, pos.z or 0
            local changed, newX, newY, newZ = imgui.InputFloat3("Position", x, y, z, "%.2f")
            if changed then
                local oldPos = {x = x, y = y, z = z}
                local newPos = {x = newX, y = newY, z = newZ}
                self.editor.bridge:SetPropertyValue(obj, "position", newPos, oldPos)
            end
        end

        -- Rotation
        local rot = self.editor.bridge:GetPropertyValue(obj, "rotation")
        if rot then
            local rotValue = type(rot) == "number" and rot or (rot.z or 0)
            local changed, newRot = imgui.InputFloat("Rotation", rotValue, 1, 10, "%.1f")
            if changed then
                self.editor.bridge:SetPropertyValue(obj, "rotation", newRot, rot)
            end
        end

        -- Scale
        local scale = self.editor.bridge:GetPropertyValue(obj, "scale")
        if scale then
            local sx, sy = scale.x or 1, scale.y or 1
            local changed, newSX, newSY = imgui.InputFloat2("Scale", sx, sy, "%.2f")
            if changed then
                local oldScale = {x = sx, y = sy}
                local newScale = {x = newSX, y = newSY}
                self.editor.bridge:SetPropertyValue(obj, "scale", newScale, oldScale)
            end
        end
    end
end

function InspectorPanel:RenderPropertyField(prop)
    local imgui = self.editor.renderer.imgui
    local info = self.target

    if not prop.editable then
        imgui.TextDisabled(prop.name .. ": " .. tostring(prop.value))
        return
    end

    if prop.type == "string" then
        local changed, newValue = imgui.InputText(prop.name, tostring(prop.value), 256)
        if changed then
            self.editor.bridge:SetPropertyValue(info.object, prop.key, newValue, prop.value)
            prop.value = newValue
        end

    elseif prop.type == "int" then
        local changed, newValue = imgui.InputInt(prop.name, prop.value)
        if changed then
            self.editor.bridge:SetPropertyValue(info.object, prop.key, newValue, prop.value)
            prop.value = newValue
        end

    elseif prop.type == "float" then
        local changed, newValue = imgui.InputFloat(prop.name, prop.value, 0.1, 1.0, "%.2f")
        if changed then
            self.editor.bridge:SetPropertyValue(info.object, prop.key, newValue, prop.value)
            prop.value = newValue
        end

    elseif prop.type == "bool" then
        local changed, newValue = imgui.Checkbox(prop.name, prop.value)
        if changed then
            self.editor.bridge:SetPropertyValue(info.object, prop.key, newValue, prop.value)
            prop.value = newValue
        end

    elseif prop.type == "Vector2" then
        local v = prop.value
        local changed, newX, newY = imgui.InputFloat2(prop.name, v.x or 0, v.y or 0, "%.2f")
        if changed then
            local oldValue = {x = v.x, y = v.y}
            local newValue = {x = newX, y = newY}
            self.editor.bridge:SetPropertyValue(info.object, prop.key, newValue, oldValue)
            prop.value = newValue
        end

    elseif prop.type == "Vector3" then
        local v = prop.value
        local changed, newX, newY, newZ = imgui.InputFloat3(
            prop.name, v.x or 0, v.y or 0, v.z or 0, "%.2f"
        )
        if changed then
            local oldValue = {x = v.x, y = v.y, z = v.z}
            local newValue = {x = newX, y = newY, z = newZ}
            self.editor.bridge:SetPropertyValue(info.object, prop.key, newValue, oldValue)
            prop.value = newValue
        end

    elseif prop.type == "Color" then
        local c = prop.value
        local color = {c.r or 1, c.g or 1, c.b or 1, c.a or 1}
        local changed, newR, newG, newB, newA = imgui.ColorEdit4(prop.name, color[1], color[2], color[3], color[4])
        if changed then
            local oldValue = {r = c.r, g = c.g, b = c.b, a = c.a}
            local newValue = {r = newR, g = newG, b = newB, a = newA}
            self.editor.bridge:SetPropertyValue(info.object, prop.key, newValue, oldValue)
            prop.value = newValue
        end

    else
        imgui.Text(prop.name .. ": " .. tostring(prop.value))
    end
end

function InspectorPanel:RenderComponentProperties(comp)
    local imgui = self.editor.renderer.imgui
    local obj = comp.object

    -- 反射扫描组件属性
    for key, value in pairs(obj) do
        if type(key) == "string" 
           and not key:match("^_") 
           and type(value) ~= "function"
           and type(value) ~= "userdata" then

            local propType = self.editor.bridge:DetermineValueType(value)
            local prop = {
                name = key,
                type = propType,
                value = value,
                key = key,
                editable = propType ~= "unknown" and propType ~= "table",
            }
            self:RenderPropertyField(prop)
        end
    end
end

return InspectorPanel
```

### 3.3 ConsolePanel（控制台面板）

```lua
-- UI/Panels/ConsolePanel.lua
local ConsolePanel = {}
ConsolePanel.__index = ConsolePanel

function ConsolePanel.New(editor)
    local self = setmetatable({}, ConsolePanel)
    self.editor = editor
    self.isVisible = true
    self.logs = {}
    self.maxLogs = 500
    self.filterLevel = "all"
    self.filterText = ""
    self.autoScroll = true
    self.collapse = false
    return self
end

function ConsolePanel:Toggle()
    self.isVisible = not self.isVisible
end

function ConsolePanel:IsVisible()
    return self.isVisible
end

function ConsolePanel:AddLog(level, msg, stack)
    local log = {
        level = level,
        msg = msg,
        stack = stack,
        time = os.date("%H:%M:%S"),
        count = 1,
    }

    if self.collapse and #self.logs > 0 then
        local last = self.logs[#self.logs]
        if last.msg == msg and last.level == level then
            last.count = last.count + 1
            return
        end
    end

    table.insert(self.logs, log)
    if #self.logs > self.maxLogs then
        table.remove(self.logs, 1)
    end

    if level == "error" and self.editor.errorPause and self.editor.isPlaying then
        self.editor:TogglePause()
    end
end

function ConsolePanel:Clear()
    self.logs = {}
end

function ConsolePanel:Render()
    if not self.isVisible then return end

    local imgui = self.editor.renderer.imgui
    if not imgui then return end

    if imgui.Begin("Console", self.isVisible) then
        -- 工具栏
        if imgui.Button("Clear") then
            self:Clear()
        end
        imgui.SameLine()

        local changed, newCollapse = imgui.Checkbox("Collapse", self.collapse)
        if changed then self.collapse = newCollapse end
        imgui.SameLine()

        local changed2, newAutoScroll = imgui.Checkbox("Auto Scroll", self.autoScroll)
        if changed2 then self.autoScroll = newAutoScroll end
        imgui.SameLine()

        -- 级别过滤按钮
        if imgui.Button("All") then self.filterLevel = "all" end
        imgui.SameLine()
        if imgui.Button("Log") then self.filterLevel = "log" end
        imgui.SameLine()
        if imgui.Button("Warning") then self.filterLevel = "warning" end
        imgui.SameLine()
        if imgui.Button("Error") then self.filterLevel = "error" end
        imgui.SameLine()

        -- 搜索
        local changed3, newText = imgui.InputText("Filter", self.filterText, 256)
        if changed3 then self.filterText = newText end

        imgui.Separator()

        -- 日志列表
        if imgui.BeginChild("LogList", {0, 0}, false, imgui.WindowFlags_HorizontalScrollbar) then
            for _, log in ipairs(self.logs) do
                if self.filterLevel ~= "all" and log.level ~= self.filterLevel then
                    goto continue
                end
                if self.filterText ~= "" and not log.msg:lower():find(self.filterText:lower()) then
                    goto continue
                end

                local color = {1, 1, 1, 1}
                if log.level == "warning" then color = {1, 0.8, 0, 1}
                elseif log.level == "error" then color = {1, 0.3, 0.3, 1}
                elseif log.level == "info" then color = {0.5, 0.8, 1, 1}
                end

                imgui.PushStyleColor(imgui.Col_Text, color)

                local displayText = string.format("[%s] %s", log.time, log.msg)
                if log.count > 1 then
                    displayText = displayText .. " (" .. log.count .. "x)"
                end

                imgui.Selectable(displayText)

                -- 双击显示堆栈
                if imgui.IsItemHovered() and imgui.IsMouseDoubleClicked(0) and log.stack then
                    imgui.SetClipboardText(log.stack)
                end

                imgui.PopStyleColor()

                ::continue::
            end

            if self.autoScroll and imgui.GetScrollY() >= imgui.GetScrollMaxY() - 10 then
                imgui.SetScrollHereY(1)
            end

            imgui.EndChild()
        end

        imgui.End()
    end
end

return ConsolePanel
```

### 3.4 SceneOverlay（场景覆盖显示）

```lua
-- UI/Panels/SceneOverlay.lua
local SceneOverlay = {}
SceneOverlay.__index = SceneOverlay

function SceneOverlay.New(editor)
    local self = setmetatable({}, SceneOverlay)
    self.editor = editor
    self.target = nil
    self.showGizmos = true
    self.showBounds = true
    self.showNames = true
    self.showGrid = false
    return self
end

function SceneOverlay:SetTarget(info)
    self.target = info
end

function SceneOverlay:Render()
    -- 在ImGui窗口中渲染场景覆盖
    local imgui = self.editor.renderer.imgui
    if not imgui then return end

    -- 绘制选中对象的Gizmo
    if self.target and self.showGizmos then
        self:RenderSelectionGizmo()
    end

    -- 绘制所有对象的名称和边界
    if self.showNames or self.showBounds then
        self:RenderObjectOverlays()
    end
end

function SceneOverlay:RenderMinimal()
    -- 编辑器隐藏时，只绘制选中框
    if not self.target then return end

    -- 使用引擎原生绘制API
    local obj = self.target.object
    local pos = self.editor.bridge:GetPropertyValue(obj, "position")

    if pos then
        -- 绘制选中标记（十字准星）
        local screenX, screenY = self:WorldToScreen(pos.x, pos.y)
        if screenX then
            self:DrawCrosshair(screenX, screenY, 10, {1, 0.5, 0, 1})
        end
    end
end

function SceneOverlay:RenderSelectionGizmo()
    if not self.target then return end

    local obj = self.target.object
    local pos = self.editor.bridge:GetPropertyValue(obj, "position")

    if not pos then return end

    local imgui = self.editor.renderer.imgui
    local drawList = imgui.GetBackgroundDrawList()

    local screenX, screenY = self:WorldToScreen(pos.x, pos.y)
    if not screenX then return end

    -- 绘制选中框
    local size = 20
    local color = imgui.GetColorU32({1, 0.5, 0, 1})

    drawList:AddRect(
        {screenX - size, screenY - size},
        {screenX + size, screenY + size},
        color, 0, 0, 2
    )

    -- 绘制坐标轴
    drawList:AddLine(
        {screenX, screenY},
        {screenX + 30, screenY},
        imgui.GetColorU32({1, 0, 0, 1}), 2
    )
    drawList:AddLine(
        {screenX, screenY},
        {screenX, screenY - 30},
        imgui.GetColorU32({0, 1, 0, 1}), 2
    )

    -- 绘制名称标签
    if self.showNames then
        drawList:AddText(
            {screenX + 5, screenY - 20},
            imgui.GetColorU32({1, 1, 1, 1}),
            self.target.name
        )
    end
end

function SceneOverlay:RenderObjectOverlays()
    local bridge = self.editor.bridge

    for id, info in pairs(bridge.scannedObjects) do
        if info == self.target then goto continue end

        local obj = info.object
        local pos = bridge:GetPropertyValue(obj, "position")

        if pos then
            local screenX, screenY = self:WorldToScreen(pos.x, pos.y)
            if screenX then
                local imgui = self.editor.renderer.imgui
                local drawList = imgui.GetBackgroundDrawList()

                if self.showBounds then
                    drawList:AddCircle(
                        {screenX, screenY}, 5,
                        imgui.GetColorU32({0.5, 0.5, 0.5, 0.5}), 8, 1
                    )
                end

                if self.showNames then
                    drawList:AddText(
                        {screenX + 8, screenY - 8},
                        imgui.GetColorU32({0.7, 0.7, 0.7, 0.7}),
                        info.name
                    )
                end
            end
        end

        ::continue::
    end
end

function SceneOverlay:WorldToScreen(worldX, worldY)
    -- 适配不同引擎的坐标转换
    if _G.camera and _G.camera.WorldToScreen then
        return _G.camera:WorldToScreen(worldX, worldY)
    end

    -- 简单的正交投影转换
    if _G.camera then
        local camX = _G.camera.x or 0
        local camY = _G.camera.y or 0
        local zoom = _G.camera.zoom or 1
        local screenW = _G.screenWidth or 1920
        local screenH = _G.screenHeight or 1080

        local screenX = (worldX - camX) * zoom + screenW / 2
        local screenY = screenH / 2 - (worldY - camY) * zoom

        return screenX, screenY
    end

    return worldX, worldY
end

function SceneOverlay:DrawCrosshair(x, y, size, color)
    -- 使用引擎原生绘制
    if _G.graphics then
        _G.graphics:SetColor(color[1], color[2], color[3], color[4])
        _G.graphics:Line(x - size, y, x + size, y)
        _G.graphics:Line(x, y - size, x, y + size)
    end
end

return SceneOverlay
```

## 4. 钩子系统

### 4.1 LogHook（日志钩子）

```lua
-- Hooks/LogHook.lua
local LogHook = {}
LogHook.__index = LogHook

function LogHook.New(editor)
    local self = setmetatable({}, LogHook)
    self.editor = editor
    self.originalPrint = nil
    self.originalLog = nil
    return self
end

function LogHook:Install()
    -- 钩入print
    self.originalPrint = print
    _G.print = function(...)
        local args = {...}
        local msg = table.concat(args, " ")
        self.editor.panels.console:AddLog("log", msg)
        self.originalPrint(...)
    end

    -- 钩入引擎日志
    if _G.Log then
        self.originalLog = _G.Log.Write
        _G.Log.Write = function(level, msg)
            local logLevel = "log"
            if level == 1 or level == "Warning" then logLevel = "warning"
            elseif level == 2 or level == "Error" then logLevel = "error"
            elseif level == 3 or level == "Info" then logLevel = "info"
            end

            self.editor.panels.console:AddLog(logLevel, msg)
            if self.originalLog then
                self.originalLog(level, msg)
            end
        end
    end

    -- 钩入Love2D控制台
    if _G.love and _G.love.event then
        -- Love2D的错误处理
    end

    -- 钩入UrhoX日志
    if _G.Log and _G.Log.WriteRawEvent then
        _G.Log.WriteRawEvent:Subscribe(function(eventType, eventData)
            local msg = eventData:GetString("Message")
            local level = eventData:GetInt("Level")
            self.editor.panels.console:AddLog(
                level == 2 and "error" or (level == 1 and "warning" or "log"),
                msg
            )
        end)
    end
end

function LogHook:Uninstall()
    if self.originalPrint then
        _G.print = self.originalPrint
    end
    if self.originalLog then
        _G.Log.Write = self.originalLog
    end
end

return LogHook
```

### 4.2 ErrorHook（错误钩子）

```lua
-- Hooks/ErrorHook.lua
local ErrorHook = {}
ErrorHook.__index = ErrorHook

function ErrorHook.New(editor)
    local self = setmetatable({}, ErrorHook)
    self.editor = editor
    self.originalErrorHandler = nil
    return self
end

function ErrorHook:Install()
    -- 钩入Lua错误处理
    self.originalErrorHandler = _G.debug and _G.debug.traceback

    local function errorHandler(msg)
        local stack = debug and debug.traceback and debug.traceback(msg, 2) or msg
        self.editor.panels.console:AddLog("error", msg, stack)

        -- 暂停游戏
        if self.editor.errorPause then
            self.editor:TogglePause()
        end

        if self.originalErrorHandler then
            return self.originalErrorHandler(msg)
        end
        return msg
    end

    -- 设置全局错误处理
    if _G.xpcall then
        -- 包装xpcall
        local originalXpcall = _G.xpcall
        _G.xpcall = function(f, msgh, ...)
            return originalXpcall(f, errorHandler, ...)
        end
    end

    -- Love2D错误处理
    if _G.love and _G.love.errhand then
        _G.love.errhand = function(msg)
            local stack = debug.traceback(msg, 2)
            self.editor.panels.console:AddLog("error", msg, stack)
            self.editor:TogglePause()
        end
    end
end

return ErrorHook
```

### 4.3 SpawnHook（对象创建钩子）

```lua
-- Hooks/SpawnHook.lua
local SpawnHook = {}
SpawnHook.__index = SpawnHook

function SpawnHook.New(editor)
    local self = setmetatable({}, SpawnHook)
    self.editor = editor
    self.hookedFunctions = {}
    return self
end

function SpawnHook:Install()
    -- 钩入常见的对象创建函数
    local spawnFunctions = {
        "CreateGameObject",
        "SpawnEntity",
        "NewSprite",
        "AddNode",
        "Instantiate",
        "CreateActor",
    }

    for _, funcName in ipairs(spawnFunctions) do
        if _G[funcName] and type(_G[funcName]) == "function" then
            self:HookFunction(_G, funcName)
        end
    end

    -- 钩入table.insert（检测对象添加到数组）
    local originalInsert = table.insert
    table.insert = function(t, ...)
        local result = originalInsert(t, ...)

        -- 检测是否是游戏对象数组
        if self.editor.bridge:IsGameObjectTable(t) then
            self.editor.bridge:ScanScene()
        end

        return result
    end

    self.hookedFunctions["table.insert"] = originalInsert
end

function SpawnHook:HookFunction(targetTable, funcName)
    local original = targetTable[funcName]
    self.hookedFunctions[funcName] = original

    targetTable[funcName] = function(...)
        local result = original(...)

        -- 延迟扫描，避免频繁刷新
        if not self.scanPending then
            self.scanPending = true
            Timer.After(0.1, function()
                self.editor.bridge:ScanScene()
                self.scanPending = false
            end)
        end

        return result
    end
end

return SpawnHook
```

## 5. 工具系统

### 5.1 SelectionTool（选择工具）

```lua
-- Tools/SelectionTool.lua
local SelectionTool = {}
SelectionTool.__index = SelectionTool

function SelectionTool.New(editor)
    local self = setmetatable({}, SelectionTool)
    self.editor = editor
    self.isActive = false
    return self
end

function SelectionTool:OnActivate()
    self.isActive = true
end

function SelectionTool:OnDeactivate()
    self.isActive = false
end

function SelectionTool:OnMouseDown(x, y, button)
    if button ~= 1 then return false end

    -- 将屏幕坐标转为世界坐标
    local worldX, worldY = self:ScreenToWorld(x, y)

    -- 查找点击位置的游戏对象
    local hit = self:PickGameObject(worldX, worldY)

    if hit then
        self.editor:SetSelectedObject(hit)
        return true
    else
        self.editor.selectedObject = nil
        return false
    end
end

function SelectionTool:OnMouseMove(x, y, dx, dy)
    -- 悬停检测
    local worldX, worldY = self:ScreenToWorld(x, y)
    local hit = self:PickGameObject(worldX, worldY)

    if hit then
        self.editor.hoveredObject = hit
    else
        self.editor.hoveredObject = nil
    end

    return false
end

function SelectionTool:PickGameObject(worldX, worldY)
    local bridge = self.editor.bridge
    local bestHit = nil
    local bestDist = math.huge

    for id, info in pairs(bridge.scannedObjects) do
        local pos = bridge:GetPropertyValue(info.object, "position")
        if pos then
            local dx = (pos.x or 0) - worldX
            local dy = (pos.y or 0) - worldY
            local dist = math.sqrt(dx * dx + dy * dy)

            -- 检测精灵边界
            local scale = bridge:GetPropertyValue(info.object, "scale")
            local hitRadius = 0.5
            if scale then
                hitRadius = math.max(scale.x or 0.5, scale.y or 0.5) * 0.5
            end

            if dist < hitRadius and dist < bestDist then
                bestDist = dist
                bestHit = info
            end
        end
    end

    return bestHit
end

function SelectionTool:ScreenToWorld(screenX, screenY)
    if _G.camera then
        local camX = _G.camera.x or 0
        local camY = _G.camera.y or 0
        local zoom = _G.camera.zoom or 1
        local screenW = _G.screenWidth or 1920
        local screenH = _G.screenHeight or 1080

        local worldX = (screenX - screenW / 2) / zoom + camX
        local worldY = (screenH / 2 - screenY) / zoom + camY

        return worldX, worldY
    end

    return screenX, screenY
end

return SelectionTool
```

### 5.2 MoveTool（移动工具）

```lua
-- Tools/MoveTool.lua
local MoveTool = {}
MoveTool.__index = MoveTool

function MoveTool.New(editor)
    local self = setmetatable({}, MoveTool)
    self.editor = editor
    self.isDragging = false
    self.dragStartPos = nil
    self.dragStartObjectPos = nil
    self.snapGrid = 0.5
    return self
end

function MoveTool:OnActivate()
end

function MoveTool:OnDeactivate()
    self.isDragging = false
end

function MoveTool:OnMouseDown(x, y, button)
    if button ~= 1 then return false end

    local selected = self.editor.selectedObject
    if not selected then return false end

    self.isDragging = true
    self.dragStartPos = {x = x, y = y}

    local pos = self.editor.bridge:GetPropertyValue(selected.object, "position")
    self.dragStartObjectPos = pos and {x = pos.x or 0, y = pos.y or 0, z = pos.z or 0} or {x = 0, y = 0, z = 0}

    return true
end

function MoveTool:OnMouseMove(x, y, dx, dy)
    if not self.isDragging then return false end

    local selected = self.editor.selectedObject
    if not selected then return false end

    -- 计算移动增量
    local worldDX, worldDY = self:ScreenDeltaToWorld(dx, dy)

    local newX = self.dragStartObjectPos.x + worldDX
    local newY = self.dragStartObjectPos.y + worldDY

    -- 网格吸附
    if self.snapGrid > 0 then
        newX = math.floor(newX / self.snapGrid + 0.5) * self.snapGrid
        newY = math.floor(newY / self.snapGrid + 0.5) * self.snapGrid
    end

    -- 应用新位置
    local newPos = {
        x = newX,
        y = newY,
        z = self.dragStartObjectPos.z
    }

    self.editor.bridge:SetPropertyValue(
        selected.object, 
        "position", 
        newPos, 
        self.dragStartObjectPos
    )

    return true
end

function MoveTool:OnMouseUp(x, y, button)
    if button ~= 1 then return false end
    self.isDragging = false
    return true
end

function MoveTool:ScreenDeltaToWorld(dx, dy)
    if _G.camera then
        local zoom = _G.camera.zoom or 1
        return dx / zoom, -dy / zoom
    end
    return dx, dy
end

return MoveTool
```

## 6. 初始化与启动

### 6.1 启动脚本

```lua
-- EditorOverlay/init.lua
-- 在游戏启动时加载此文件

local function InitEditorOverlay()
    -- 确保只初始化一次
    if _G.EditorOverlayInstance then
        return _G.EditorOverlayInstance
    end

    -- 加载EditorOverlay模块
    local EditorOverlay = require("EditorOverlay/Core/EditorOverlay")

    -- 创建实例
    local editor = EditorOverlay.New()
    _G.EditorOverlayInstance = editor

    -- 初始化
    editor:Init()

    return editor
end

-- 自动启动（如果环境允许）
if _G.autoStartEditor ~= false then
    InitEditorOverlay()
end

-- 导出全局访问
_G.EditorOverlay = {
    Init = InitEditorOverlay,
    GetInstance = function() return _G.EditorOverlayInstance end,
}

print("[EditorOverlay] Module loaded. Call EditorOverlay.Init() to start.")
```

### 6.2 手动集成方式

如果无法自动加载，在游戏主文件的末尾添加：

```lua
-- 在游戏main.lua或入口文件末尾添加

-- 加载编辑器Overlay
local editorLoaded, editor = pcall(function()
    return require("EditorOverlay/init")
end)

if editorLoaded then
    print("[Game] EditorOverlay loaded successfully")
else
    print("[Game] EditorOverlay not available: " .. tostring(editor))
end
```

## 7. 关键技术决策

1. **零侵入原则**：编辑器通过全局表反射和函数钩子与游戏交互，不修改任何游戏代码。所有交互都通过`pcall`包装，确保编辑器错误不会导致游戏崩溃。

2. **多引擎适配**：支持UrhoX、Love2D、Cocos2d-x等常见2D引擎。通过检测全局变量（`_G.Input`、`_G.love`、`_G.cc`）自动适配输入和渲染系统。

3. **属性别名系统**：不同引擎使用不同的属性命名（position/pos/Position），通过别名映射自动适配。

4. **延迟扫描**：对象创建/销毁钩子使用延迟扫描（0.1秒防抖），避免频繁刷新导致的性能问题。

5. **输入优先级**：编辑器激活时，输入事件优先传递给编辑器UI，未消费的事件才传递给游戏。通过`InputInterceptor`实现。

6. **ImGui优先**：优先使用ImGui渲染UI，如果引擎不支持则回退到自定义渲染。ImGui提供完整的停靠、折叠、拖拽等交互。

7. **运行时修改安全**：所有属性修改都通过`GameBridge:SetPropertyValue`进行，自动记录Undo并处理Setter方法调用。

8. **热键冲突处理**：F1始终切换编辑器显示，ESC关闭当前面板或隐藏编辑器，Space暂停/恢复游戏。这些热键在编辑器隐藏时不拦截游戏输入。
