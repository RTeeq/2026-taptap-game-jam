-- ============================================================
-- IDE/IDEMain.lua - Visual2D IDE Pro 主入口
-- 新增: 属性编辑、资源浏览器、控制台、复制粘贴、组件面板、对齐工具
-- 三栏布局: 左(层级树+节点库) | 中(画布+标签页) | 右(属性+组件+控制台)
-- ============================================================
local Config = require("IDE.Config")
local EventBus = require("IDE.EventBus")
local UndoManager = require("IDE.UndoManager")
local SceneManager = require("IDE.SceneManager")
local NodeEditor = require("IDE.NodeEditor")
local Console = require("IDE.Console")
local AssetBrowser = require("IDE.AssetBrowser")
local ComponentSystem = require("IDE.ComponentSystem")

local IDEMain = {}

-- 状态
IDEMain._mode = "scene"  -- "scene" | "node"
IDEMain._panels = {}
IDEMain._isDragging = false
IDEMain._dragTarget = nil
IDEMain._dragOffsetX = 0
IDEMain._dragOffsetY = 0
IDEMain._isConnecting = false
IDEMain._connectFrom = nil
IDEMain._connectLine = {x1 = 0, y1 = 0, x2 = 0, y2 = 0}
IDEMain._isBoxSelecting = false
IDEMain._boxSelectStart = {x = 0, y = 0}
IDEMain._boxSelectEnd = {x = 0, y = 0}
IDEMain._clipboard = nil
IDEMain._clipboardType = nil -- "scene" | "node"
IDEMain._showGrid = true
IDEMain._showConsole = false
IDEMain._showAssets = false
IDEMain._showComponents = false
IDEMain._consoleHeight = 180
IDEMain._assetPanelWidth = 220
IDEMain._componentPanelWidth = 220
IDEMain._rightPanelTab = "properties" -- "properties" | "components" | "console" | "assets"
IDEMain._leftPanelTab = "hierarchy"   -- "hierarchy" | "node_library" | "layers"
IDEMain._canvasOffsetX = 0
IDEMain._canvasOffsetY = 0
IDEMain._canvasZoom = 1.0
IDEMain._editingProperty = nil
IDEMain._editingValue = ""
IDEMain._propertyScrollY = 0
IDEMain._hierarchyScrollY = 0
IDEMain._assetScrollY = 0
IDEMain._consoleScrollY = 0
IDEMain._nodeLibraryScrollY = 0
IDEMain._componentScrollY = 0
IDEMain._lastClickTime = 0
IDEMain._lastClickId = nil
IDEMain._fps = 60
IDEMain._fpsTimer = 0
IDEMain._fpsCount = 0
IDEMain._statusMessage = "就绪"
IDEMain._statusTimer = 0

-- 面板布局常量
local LEFT_PANEL_W = 220
local RIGHT_PANEL_W = 260
local TOOLBAR_H = 36
local BOTTOM_BAR_H = 24
local TAB_H = 28

function IDEMain:init()
  Config.SNAP_TO_GRID = true
  Config.GRID_SIZE = 32

  UndoManager:init(SceneManager, NodeEditor)
  SceneManager:init()
  NodeEditor:init()
  Console:init()
  AssetBrowser:init()

  -- 注入控制台回调
  Console:SetFPSCallback(function()
    return string.format("FPS: %d | 对象: %d | 节点: %d",
      math.floor(self._fps or 60),
      SceneManager:getObjectCount(),
      NodeEditor:getNodeCount())
  end)
  Console:SetNodeStatsCallback(function()
    return string.format("节点总数: %d | 连接数: %d",
      NodeEditor:getNodeCount(), #NodeEditor:getConnections())
  end)
  Console:SetSceneStatsCallback(function()
    return string.format("对象总数: %d | 选中: %d | 图层: %d",
      SceneManager:getObjectCount(),
      #SceneManager:getSelectedIds(),
      #SceneManager:getLayers())
  end)

  -- 创建默认对象
  SceneManager:createObject("sprite", "背景", Config.CANVAS_W / 2, Config.CANVAS_H / 2, {w = Config.CANVAS_W, h = Config.CANVAS_H, layer = "bg"})
  SceneManager:createObject("player", "玩家", 200, 300)
  SceneManager:createObject("enemy", "敌人_1", 600, 200)

  -- 注册事件监听
  EventBus:on("scene.object_created", function(obj) self:_setStatus("创建对象: " .. obj.name) end)
  EventBus:on("scene.object_deleted", function(id) self:_setStatus("删除对象") end)
  EventBus:on("scene.selection_changed", function() self._propertyScrollY = 0 end)
  EventBus:on("node.created", function() self:_setStatus("创建节点") end)
  EventBus:on("node.connected", function() self:_setStatus("连接节点") end)
  EventBus:on("undo.state_changed", function(canUndo, canRedo)
    -- 状态栏更新
  end)

  print("[IDEMain] Visual2D IDE Pro v" .. Config.VERSION .. " 已启动")
  print("[IDEMain] 快捷键: Ctrl+S 保存 | Ctrl+Z 撤销 | Ctrl+Shift+Z 重做")
  print("[IDEMain] Ctrl+C/V 复制粘贴 | G 网格 | H 吸附 | F 聚焦")
end

-- 设置状态消息
function IDEMain:_setStatus(msg)
  self._statusMessage = msg
  self._statusTimer = 3.0
end

-- ==================== 快捷键处理 ====================
function IDEMain:_handleShortcuts()
  for _, sc in ipairs(Config.SHORTCUTS) do
    local keyDown = input:GetKeyDown(sc.key)
    local ctrl = input:GetKey(KEY_LCTRL) or input:GetKey(KEY_RCTRL)
    local shift = input:GetKey(KEY_LSHIFT) or input:GetKey(KEY_RSHIFT)
    if keyDown and ctrl == sc.ctrl and shift == sc.shift then
      self:_executeShortcut(sc.action)
    end
  end
end

function IDEMain:_executeShortcut(action)
  if action == "file.save" then
    self:saveProject()
  elseif action == "file.new" then
    self:newProject()
  elseif action == "edit.undo" then
    UndoManager:undo()
    self:_setStatus("撤销")
  elseif action == "edit.redo" then
    UndoManager:redo()
    self:_setStatus("重做")
  elseif action == "edit.copy" then
    self:_copySelection()
  elseif action == "edit.paste" then
    self:_pasteSelection()
  elseif action == "edit.cut" then
    self:_cutSelection()
  elseif action == "edit.duplicate" then
    self:_duplicateSelection()
  elseif action == "edit.select_all" then
    if self._mode == "scene" then SceneManager:selectAll() end
  elseif action == "edit.delete" then
    self:_deleteSelection()
  elseif action == "view.grid_toggle" then
    self._showGrid = not self._showGrid
    self:_setStatus(self._showGrid and "网格: 开" or "网格: 关")
  elseif action == "view.snap_toggle" then
    Config.SNAP_TO_GRID = not Config.SNAP_TO_GRID
    self:_setStatus(Config.SNAP_TO_GRID and "吸附: 开" or "吸附: 关")
  elseif action == "view.frame_selection" then
    self:_frameSelection()
  elseif action == "view.reset_zoom" then
    self._canvasZoom = 1.0
    self._canvasOffsetX = 0
    self._canvasOffsetY = 0
  elseif action == "align.left" then
    SceneManager:alignSelected("left")
    self:_setStatus("左对齐")
  elseif action == "align.right" then
    SceneManager:alignSelected("right")
    self:_setStatus("右对齐")
  elseif action == "align.top" then
    SceneManager:alignSelected("top")
    self:_setStatus("顶对齐")
  elseif action == "align.bottom" then
    SceneManager:alignSelected("bottom")
    self:_setStatus("底对齐")
  elseif action == "mode.switch" then
    self._mode = (self._mode == "scene") and "node" or "scene"
    self:_setStatus("模式: " .. (self._mode == "scene" and "场景编辑" or "节点编辑"))
  elseif action == "mode.play" then
    self:_setStatus("运行游戏...")
  elseif action == "build.compile" then
    self:_compileAndShow()
  end
end

-- ==================== 复制粘贴 ====================
function IDEMain:_copySelection()
  if self._mode == "scene" then
    local ids = SceneManager:getSelectedIds()
    if #ids > 0 then
      self._clipboard = SceneManager:getSelectedObjects()
      self._clipboardType = "scene"
      self:_setStatus("已复制 " .. #ids .. " 个对象")
    end
  elseif self._mode == "node" then
    local selected = {}
    for _, node in pairs(NodeEditor._data.nodes) do
      if NodeEditor._data.selectedNodeId == node.id then
        table.insert(selected, node.id)
      end
    end
    if #selected > 0 then
      self._clipboard = NodeEditor:copyNodes(selected)
      self._clipboardType = "node"
      self:_setStatus("已复制 " .. #selected .. " 个节点")
    end
  end
end

function IDEMain:_pasteSelection()
  if not self._clipboard then return end
  if self._clipboardType == "scene" then
    SceneManager:clearSelection()
    for _, obj in ipairs(self._clipboard) do
      local newObj = SceneManager:createObject(obj.type, obj.name .. "_副本", obj.x + 32, obj.y + 32, {
        w = obj.w, h = obj.h, layer = obj.layer
      })
      -- 复制属性
      for k, v in pairs(obj) do
        if k ~= "id" and k ~= "x" and k ~= "y" and k ~= "name" then
          newObj[k] = Config.deepcopy(v)
        end
      end
      SceneManager:selectObject(newObj.id, true)
    end
    self:_setStatus("已粘贴 " .. #self._clipboard .. " 个对象")
  elseif self._clipboardType == "node" then
    local mx, my = input.mousePosition.x, input.mousePosition.y
    local newNodes = NodeEditor:pasteNodes(self._clipboard, 20, 20)
    if #newNodes > 0 then
      NodeEditor:selectNode(newNodes[1].id)
      self:_setStatus("已粘贴 " .. #newNodes .. " 个节点")
    end
  end
end

function IDEMain:_cutSelection()
  self:_copySelection()
  self:_deleteSelection()
  self:_setStatus("剪切")
end

function IDEMain:_duplicateSelection()
  self:_copySelection()
  self:_pasteSelection()
end

function IDEMain:_deleteSelection()
  if self._mode == "scene" then
    for id, _ in pairs(SceneManager._data.selectedIds) do
      SceneManager:deleteObject(id)
    end
    SceneManager:clearSelection()
  elseif self._mode == "node" then
    local selected = NodeEditor:getSelectedNode()
    if selected then
      NodeEditor:deleteNode(selected.id)
    end
  end
end

function IDEMain:_frameSelection()
  if self._mode == "scene" then
    local selected = SceneManager:getSelectedObjects()
    if #selected > 0 then
      local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
      for _, obj in ipairs(selected) do
        minX = math.min(minX, obj.x - (obj.w or 64) / 2)
        minY = math.min(minY, obj.y - (obj.h or 64) / 2)
        maxX = math.max(maxX, obj.x + (obj.w or 64) / 2)
        maxY = math.max(maxY, obj.y + (obj.h or 64) / 2)
      end
      local cx = (minX + maxX) / 2
      local cy = (minY + maxY) / 2
      self._canvasOffsetX = Config.CANVAS_W / 2 - cx
      self._canvasOffsetY = Config.CANVAS_H / 2 - cy
    end
  end
end

function IDEMain:_compileAndShow()
  if self._mode == "node" then
    local code = NodeEditor:compileToLua()
    print("=== 编译输出 ===")
    print(code)
    print("================")
    self:_setStatus("节点编译完成")
  end
end

-- ==================== 更新 ====================
function IDEMain:update(dt)
  self._fpsCount = self._fpsCount + 1
  self._fpsTimer = self._fpsTimer + dt
  if self._fpsTimer >= 1.0 then
    self._fps = self._fpsCount
    self._fpsCount = 0
    self._fpsTimer = 0
  end

  if self._statusTimer > 0 then
    self._statusTimer = self._statusTimer - dt
  end

  self:_handleShortcuts()

  if self._mode == "scene" then
    self:_updateSceneMode(dt)
  else
    self:_updateNodeMode(dt)
  end

  -- 控制台更新
  if Console:IsVisible() then
    Console:update(dt)
  end
end

function IDEMain:_updateSceneMode(dt)
  local mx, my = input.mousePosition.x, input.mousePosition.y

  -- 判断鼠标是否在画布区域
  local inCanvas = mx > LEFT_PANEL_W and mx < Config.CANVAS_W - RIGHT_PANEL_W
    and my > TOOLBAR_H and my < Config.CANVAS_H - BOTTOM_BAR_H

  if inCanvas then
    local worldX = (mx - LEFT_PANEL_W - self._canvasOffsetX) / self._canvasZoom
    local worldY = (my - TOOLBAR_H - self._canvasOffsetY) / self._canvasZoom

    if input:GetMouseButtonDown(MOUSEB_LEFT) then
      local clicked = SceneManager:hitTest(worldX, worldY)
      if clicked then
        local now = os.clock()
        if clicked.id == self._lastClickId and (now - self._lastClickTime) < 0.3 then
          -- 双击：编辑名称
          self._editingProperty = {type = "name", id = clicked.id}
          self._editingValue = clicked.name
        else
          if input:GetKey(KEY_LSHIFT) or input:GetKey(KEY_RSHIFT) then
            SceneManager:toggleSelection(clicked.id)
          else
            SceneManager:selectObject(clicked.id, false)
          end
        end
        self._lastClickTime = now
        self._lastClickId = clicked.id
        self._isDragging = true
        self._dragTarget = clicked
        self._dragOffsetX = worldX - clicked.x
        self._dragOffsetY = worldY - clicked.y
      else
        if not (input:GetKey(KEY_LSHIFT) or input:GetKey(KEY_RSHIFT)) then
          SceneManager:clearSelection()
        end
        self._isBoxSelecting = true
        self._boxSelectStart = {x = worldX, y = worldY}
        self._boxSelectEnd = {x = worldX, y = worldY}
      end
    end

    if input:GetMouseButton(MOUSEB_LEFT) then
      if self._isDragging and self._dragTarget then
        local newX = worldX - self._dragOffsetX
        local newY = worldY - self._dragOffsetY
        if Config.SNAP_TO_GRID then
          newX, newY = Config.snapToGrid(newX, newY)
        end
        -- 移动所有选中的对象
        local dx = newX - self._dragTarget.x
        local dy = newY - self._dragTarget.y
        for id, _ in pairs(SceneManager._data.selectedIds) do
          local obj = SceneManager:getObjectById(id)
          if obj and not obj.locked then
            obj.x = obj.x + dx
            obj.y = obj.y + dy
          end
        end
      elseif self._isBoxSelecting then
        self._boxSelectEnd = {x = worldX, y = worldY}
      end
    end

    if input:GetMouseButtonUp(MOUSEB_LEFT) then
      if self._isBoxSelecting then
        local selected = SceneManager:hitTestRect(
          self._boxSelectStart.x, self._boxSelectStart.y,
          self._boxSelectEnd.x, self._boxSelectEnd.y
        )
        for _, obj in ipairs(selected) do
          SceneManager:selectObject(obj.id, true)
        end
      end
      self._isDragging = false
      self._dragTarget = nil
      self._isBoxSelecting = false
    end

    -- 中键平移画布
    if input:GetMouseButton(MOUSEB_MIDDLE) then
      self._canvasOffsetX = self._canvasOffsetX + input.mouseDelta.x
      self._canvasOffsetY = self._canvasOffsetY + input.mouseDelta.y
    end

    -- 滚轮缩放
    local scroll = input.mouseScroll
    if scroll ~= 0 then
      local zoomFactor = scroll > 0 and 1.1 or 0.9
      self._canvasZoom = math.max(0.1, math.min(5.0, self._canvasZoom * zoomFactor))
    end
  end
end

function IDEMain:_updateNodeMode(dt)
  local mx, my = input.mousePosition.x, input.mousePosition.y
  local inCanvas = mx > LEFT_PANEL_W and mx < Config.CANVAS_W - RIGHT_PANEL_W
    and my > TOOLBAR_H and my < Config.CANVAS_H - BOTTOM_BAR_H

  if inCanvas then
    local worldX = (mx - LEFT_PANEL_W - self._canvasOffsetX) / self._canvasZoom
    local worldY = (my - TOOLBAR_H - self._canvasOffsetY) / self._canvasZoom

    if input:GetMouseButtonDown(MOUSEB_LEFT) then
      local port = NodeEditor:hitTestPort(worldX, worldY)
      if port then
        if port.isOutput then
          self._isConnecting = true
          self._connectFrom = port
          self._connectLine = {x1 = worldX, y1 = worldY, x2 = worldX, y2 = worldY}
        end
      else
        local node = NodeEditor:hitTestNode(worldX, worldY)
        if node then
          NodeEditor:selectNode(node.id)
          self._isDragging = true
          self._dragTarget = node
          self._dragOffsetX = worldX - node.x
          self._dragOffsetY = worldY - node.y
        else
          NodeEditor:selectNode(nil)
        end
      end
    end

    if input:GetMouseButton(MOUSEB_LEFT) then
      if self._isConnecting then
        self._connectLine.x2 = worldX
        self._connectLine.y2 = worldY
      elseif self._isDragging and self._dragTarget then
        self._dragTarget.x = worldX - self._dragOffsetX
        self._dragTarget.y = worldY - self._dragOffsetY
      end
    end

    if input:GetMouseButtonUp(MOUSEB_LEFT) then
      if self._isConnecting then
        local port = NodeEditor:hitTestPort(worldX, worldY)
        if port and not port.isOutput then
          NodeEditor:connect(
            self._connectFrom.nodeId, self._connectFrom.portIdx,
            port.nodeId, port.portIdx
          )
        end
        self._isConnecting = false
        self._connectFrom = nil
      end
      self._isDragging = false
      self._dragTarget = nil
    end

    if input:GetMouseButton(MOUSEB_MIDDLE) then
      self._canvasOffsetX = self._canvasOffsetX + input.mouseDelta.x
      self._canvasOffsetY = self._canvasOffsetY + input.mouseDelta.y
    end

    local scroll = input.mouseScroll
    if scroll ~= 0 then
      local zoomFactor = scroll > 0 and 1.1 or 0.9
      self._canvasZoom = math.max(0.1, math.min(5.0, self._canvasZoom * zoomFactor))
    end
  end
end

-- ==================== 渲染 ====================
function IDEMain:render()
  self:_renderBackground()
  self:_renderToolbar()
  self:_renderLeftPanel()
  self:_renderCanvas()
  self:_renderRightPanel()
  self:_renderBottomBar()

  if self._showConsole then
    self:_renderConsoleOverlay()
  end
end

function IDEMain:_renderBackground()
  nvgFillColor(Config.COLORS.bg)
  nvgRect(0, 0, Config.CANVAS_W, Config.CANVAS_H)
  nvgFill()
end

function IDEMain:_renderToolbar()
  nvgFillColor(Config.COLORS.toolbar)
  nvgRect(0, 0, Config.CANVAS_W, TOOLBAR_H)
  nvgFill()
  nvgStrokeColor(Config.COLORS.border)
  nvgStrokeWidth(1)
  nvgRect(0, 0, Config.CANVAS_W, TOOLBAR_H)
  nvgStroke()

  nvgFontSize(14)
  nvgFillColor(Config.COLORS.text)
  nvgText(10, 24, "Visual2D IDE Pro v" .. Config.VERSION)

  -- 模式切换按钮
  local btnX = 220
  local sceneBtn = self._mode == "scene"
  nvgFillColor(sceneBtn and Config.COLORS.accent or Config.COLORS.panel)
  nvgRect(btnX, 6, 70, 24)
  nvgFill()
  nvgStrokeColor(Config.COLORS.border)
  nvgRect(btnX, 6, 70, 24)
  nvgStroke()
  nvgFillColor(Config.COLORS.text)
  nvgText(btnX + 8, 22, "场景")

  nvgFillColor(not sceneBtn and Config.COLORS.accent or Config.COLORS.panel)
  nvgRect(btnX + 72, 6, 70, 24)
  nvgFill()
  nvgStrokeColor(Config.COLORS.border)
  nvgRect(btnX + 72, 6, 70, 24)
  nvgStroke()
  nvgFillColor(Config.COLORS.text)
  nvgText(btnX + 80, 22, "节点")

  -- 工具按钮
  local toolsX = 380
  local tools = {"保存", "撤销", "重做", "复制", "粘贴", "删除", "网格", "编译"}
  for i, tool in ipairs(tools) do
    local tx = toolsX + (i - 1) * 50
    nvgFillColor(Config.COLORS.panel)
    nvgRect(tx, 6, 46, 24)
    nvgFill()
    nvgStrokeColor(Config.COLORS.border)
    nvgRect(tx, 6, 46, 24)
    nvgStroke()
    nvgFillColor(Config.COLORS.text)
    nvgText(tx + 6, 22, tool)
  end

  -- 对齐按钮 (场景模式)
  if self._mode == "scene" then
    local alignX = 790
    local aligns = {"左", "中", "右", "顶", "中", "底", "水平", "垂直"}
    for i, a in ipairs(aligns) do
      local ax = alignX + (i - 1) * 36
      nvgFillColor(Config.COLORS.panel)
      nvgRect(ax, 6, 34, 24)
      nvgFill()
      nvgStrokeColor(Config.COLORS.border)
      nvgRect(ax, 6, 34, 24)
      nvgStroke()
      nvgFontSize(11)
      nvgFillColor(Config.COLORS.text)
      nvgText(ax + 4, 21, a)
    end
    nvgFontSize(14)
  end

  -- 右侧面板切换按钮
  local rightBtns = {"属性", "组件", "控制台", "资源"}
  for i, btn in ipairs(rightBtns) do
    local bx = Config.CANVAS_W - RIGHT_PANEL_W - 10 + (i - 1) * 55
    local active = self._rightPanelTab == ({"properties", "components", "console", "assets"})[i]
    nvgFillColor(active and Config.COLORS.accent or Config.COLORS.panel)
    nvgRect(bx, 6, 52, 24)
    nvgFill()
    nvgStrokeColor(Config.COLORS.border)
    nvgRect(bx, 6, 52, 24)
    nvgStroke()
    nvgFontSize(11)
    nvgFillColor(Config.COLORS.text)
    nvgText(bx + 4, 21, btn)
  end
  nvgFontSize(14)
end

function IDEMain:_renderLeftPanel()
  local x = 0
  local y = TOOLBAR_H
  local w = LEFT_PANEL_W
  local h = Config.CANVAS_H - TOOLBAR_H - BOTTOM_BAR_H

  nvgFillColor(Config.COLORS.panel)
  nvgRect(x, y, w, h)
  nvgFill()
  nvgStrokeColor(Config.COLORS.border)
  nvgRect(x, y, w, h)
  nvgStroke()

  -- 标签页
  local tabs = self._mode == "scene" and {"层级树", "图层", "资源"} or {"节点库", "变量"}
  local tabW = w / #tabs
  for i, tab in ipairs(tabs) do
    local active = (self._mode == "scene" and (
      (i == 1 and self._leftPanelTab == "hierarchy") or
      (i == 2 and self._leftPanelTab == "layers") or
      (i == 3 and self._leftPanelTab == "assets")
    )) or (self._mode == "node" and (
      (i == 1 and self._leftPanelTab == "node_library") or
      (i == 2 and self._leftPanelTab == "variables")
    ))
    nvgFillColor(active and Config.COLORS.accent or Config.COLORS.panelHeader)
    nvgRect(x + (i - 1) * tabW, y, tabW, TAB_H)
    nvgFill()
    nvgStrokeColor(Config.COLORS.border)
    nvgRect(x + (i - 1) * tabW, y, tabW, TAB_H)
    nvgStroke()
    nvgFontSize(11)
    nvgFillColor(Config.COLORS.text)
    nvgText(x + (i - 1) * tabW + 6, y + 18, tab)
  end
  nvgFontSize(14)

  -- 内容区域
  local contentY = y + TAB_H
  local contentH = h - TAB_H

  if self._mode == "scene" then
    if self._leftPanelTab == "hierarchy" then
      self:_renderHierarchy(x, contentY, w, contentH)
    elseif self._leftPanelTab == "layers" then
      self:_renderLayers(x, contentY, w, contentH)
    elseif self._leftPanelTab == "assets" then
      self:_renderAssetBrowser(x, contentY, w, contentH)
    end
  else
    if self._leftPanelTab == "node_library" then
      self:_renderNodeLibrary(x, contentY, w, contentH)
    elseif self._leftPanelTab == "variables" then
      self:_renderVariables(x, contentY, w, contentH)
    end
  end
end

function IDEMain:_renderHierarchy(x, y, w, h)
  local objects = SceneManager:getAllObjects()
  local rowH = 22
  local scrollMax = math.max(0, #objects * rowH - h + 10)
  self._hierarchyScrollY = math.max(0, math.min(self._hierarchyScrollY, scrollMax))

  nvgScissor(x, y, w, h)
  local drawY = y + 5 - self._hierarchyScrollY

  for _, obj in ipairs(objects) do
    if drawY + rowH > y and drawY < y + h then
      local isSelected = SceneManager:isSelected(obj.id)
      if isSelected then
        nvgFillColor(Config.COLORS.selected)
        nvgRect(x + 2, drawY, w - 4, rowH)
        nvgFill()
      end

      nvgFillColor(obj.visible and Config.COLORS.text or Config.COLORS.textDim)
      local layerIcon = obj.layer == "bg" and "[B]" or obj.layer == "ui" and "[U]" or "[G]"
      nvgFontSize(12)
      nvgText(x + 6, drawY + 15, layerIcon .. " " .. obj.name)

      -- 可见性图标
      nvgFillColor(obj.visible and Config.COLORS.success or Config.COLORS.textDim)
      nvgText(x + w - 30, drawY + 15, obj.visible and "👁" or "🚫")
    end
    drawY = drawY + rowH
  end
  nvgResetScissor()

  -- 滚动条
  if scrollMax > 0 then
    local thumbH = math.max(20, h * h / (#objects * rowH + 10))
    local thumbY = y + (self._hierarchyScrollY / scrollMax) * (h - thumbH)
    nvgFillColor(Config.COLORS.border)
    nvgRect(x + w - 6, thumbY, 4, thumbH)
    nvgFill()
  end
end

function IDEMain:_renderLayers(x, y, w, h)
  local layers = SceneManager:getLayers()
  local rowH = 28
  local drawY = y + 5

  for i, layer in ipairs(layers) do
    local isActive = SceneManager:getActiveLayerIndex() == i
    if isActive then
      nvgFillColor(Config.COLORS.selected)
      nvgRect(x + 2, drawY, w - 4, rowH)
      nvgFill()
    end

    nvgFillColor(Config.COLORS.text)
    nvgFontSize(12)
    nvgText(x + 6, drawY + 17, (layer.visible and "👁" or "🚫") .. " " .. layer.name)

    if layer.locked then
      nvgFillColor(Config.COLORS.warning)
      nvgText(x + w - 20, drawY + 17, "🔒")
    end

    drawY = drawY + rowH + 2
  end
end

function IDEMain:_renderAssetBrowser(x, y, w, h)
  local assets = AssetBrowser:GetFilteredAssets()
  local rowH = 60
  local scrollMax = math.max(0, #assets * rowH - h + 10)
  self._assetScrollY = math.max(0, math.min(self._assetScrollY, scrollMax))

  nvgScissor(x, y, w, h)
  local drawY = y + 5 - self._assetScrollY

  for _, asset in ipairs(assets) do
    if drawY + rowH > y and drawY < y + h then
      local isSelected = AssetBrowser:GetSelectedAsset() and AssetBrowser:GetSelectedAsset().id == asset.id
      if isSelected then
        nvgFillColor(Config.COLORS.selected)
        nvgRect(x + 2, drawY, w - 4, rowH)
        nvgFill()
      end

      nvgFillColor(Config.COLORS.text)
      nvgFontSize(11)
      nvgText(x + 6, drawY + 14, asset.name)
      nvgFillColor(Config.COLORS.textDim)
      nvgFontSize(10)
      nvgText(x + 6, drawY + 28, asset.category .. " | " .. Config.formatFileSize(asset.size))
      nvgText(x + 6, drawY + 42, asset.path)
    end
    drawY = drawY + rowH + 2
  end
  nvgResetScissor()
end

function IDEMain:_renderNodeLibrary(x, y, w, h)
  local categories = NodeEditor:getCategories()
  local rowH = 24
  local drawY = y + 5 - self._nodeLibraryScrollY

  nvgScissor(x, y, w, h)
  for catName, typeNames in pairs(categories) do
    if drawY + 20 > y and drawY < y + h then
      nvgFillColor(Config.COLORS.accent)
      nvgFontSize(11)
      nvgText(x + 6, drawY + 14, catName)
    end
    drawY = drawY + 20

    for _, typeName in ipairs(typeNames) do
      if drawY + rowH > y and drawY < y + h then
        nvgFillColor(Config.COLORS.panel)
        nvgRect(x + 4, drawY, w - 8, rowH)
        nvgFill()
        nvgStrokeColor(Config.COLORS.border)
        nvgRect(x + 4, drawY, w - 8, rowH)
        nvgStroke()
        nvgFillColor(Config.COLORS.text)
        nvgFontSize(11)
        nvgText(x + 10, drawY + 16, typeName)
      end
      drawY = drawY + rowH + 2
    end
    drawY = drawY + 5
  end
  nvgResetScissor()
end

function IDEMain:_renderVariables(x, y, w, h)
  nvgFillColor(Config.COLORS.textDim)
  nvgFontSize(12)
  nvgText(x + 10, y + 20, "变量面板 (开发中)")
end

function IDEMain:_renderCanvas()
  local x = LEFT_PANEL_W
  local y = TOOLBAR_H
  local w = Config.CANVAS_W - LEFT_PANEL_W - RIGHT_PANEL_W
  local h = Config.CANVAS_H - TOOLBAR_H - BOTTOM_BAR_H

  -- 画布背景
  nvgFillColor(Config.COLORS.canvas)
  nvgRect(x, y, w, h)
  nvgFill()

  nvgScissor(x, y, w, h)

  nvgSave()
  nvgTranslate(x + self._canvasOffsetX, y + self._canvasOffsetY)
  nvgScale(self._canvasZoom, self._canvasZoom)

  if self._mode == "scene" then
    self:_renderSceneCanvas()
  else
    self:_renderNodeCanvas()
  end

  nvgRestore()
  nvgResetScissor()

  -- 画布边框
  nvgStrokeColor(Config.COLORS.border)
  nvgStrokeWidth(1)
  nvgRect(x, y, w, h)
  nvgStroke()
end

function IDEMain:_renderSceneCanvas()
  -- 网格
  if self._showGrid then
    local gs = Config.GRID_SIZE
    local startX = math.floor(-self._canvasOffsetX / self._canvasZoom / gs) * gs
    local startY = math.floor(-self._canvasOffsetY / self._canvasZoom / gs) * gs
    local endX = startX + (Config.CANVAS_W / self._canvasZoom) + gs * 2
    local endY = startY + (Config.CANVAS_H / self._canvasZoom) + gs * 2

    nvgStrokeColor(Config.COLORS.grid)
    nvgStrokeWidth(0.5)
    for gx = startX, endX, gs do
      nvgBeginPath()
      nvgMoveTo(gx, startY)
      nvgLineTo(gx, endY)
      nvgStroke()
    end
    for gy = startY, endY, gs do
      nvgBeginPath()
      nvgMoveTo(startX, gy)
      nvgLineTo(endX, gy)
      nvgStroke()
    end
  end

  -- 绘制所有对象
  local objects = SceneManager:getAllObjects()
  for _, obj in ipairs(objects) do
    if obj.visible then
      local hw = (obj.w or 64) / 2
      local hh = (obj.h or 64) / 2

      -- 对象矩形
      local alpha = obj.opacity or 255
      nvgFillColor({100, 100, 100, alpha})
      nvgRect(obj.x - hw, obj.y - hh, obj.w or 64, obj.h or 64)
      nvgFill()

      -- 选中高亮
      if SceneManager:isSelected(obj.id) then
        nvgStrokeColor(Config.COLORS.accent)
        nvgStrokeWidth(2)
        nvgRect(obj.x - hw - 2, obj.y - hh - 2, (obj.w or 64) + 4, (obj.h or 64) + 4)
        nvgStroke()

        -- 变换手柄
        local handleSize = 6
        nvgFillColor(Config.COLORS.accent)
        -- 四角
        nvgRect(obj.x - hw - handleSize, obj.y - hh - handleSize, handleSize * 2, handleSize * 2)
        nvgRect(obj.x + hw - handleSize, obj.y - hh - handleSize, handleSize * 2, handleSize * 2)
        nvgRect(obj.x - hw - handleSize, obj.y + hh - handleSize, handleSize * 2, handleSize * 2)
        nvgRect(obj.x + hw - handleSize, obj.y + hh - handleSize, handleSize * 2, handleSize * 2)
        nvgFill()
      end

      -- 对象名称
      nvgFillColor(Config.COLORS.text)
      nvgFontSize(10)
      nvgText(obj.x - hw, obj.y - hh - 12, obj.name)

      -- 类型标识
      nvgFillColor(Config.COLORS.textDim)
      nvgFontSize(9)
      nvgText(obj.x - hw, obj.y + hh + 12, obj.type)
    end
  end

  -- 框选框
  if self._isBoxSelecting then
    local bx1, bx2 = self._boxSelectStart.x, self._boxSelectEnd.x
    local by1, by2 = self._boxSelectStart.y, self._boxSelectEnd.y
    nvgStrokeColor(Config.COLORS.accent)
    nvgStrokeWidth(1)
    nvgFillColor({14, 99, 156, 50})
    nvgRect(math.min(bx1, bx2), math.min(by1, by2), math.abs(bx2 - bx1), math.abs(by2 - by1))
    nvgFill()
    nvgStroke()
  end
end

function IDEMain:_renderNodeCanvas()
  -- 网格
  if self._showGrid then
    local gs = Config.GRID_SIZE
    for gx = -5000, 5000, gs do
      nvgStrokeColor(Config.COLORS.grid)
      nvgStrokeWidth(0.5)
      nvgBeginPath()
      nvgMoveTo(gx, -5000)
      nvgLineTo(gx, 5000)
      nvgStroke()
    end
    for gy = -5000, 5000, gs do
      nvgBeginPath()
      nvgMoveTo(-5000, gy)
      nvgLineTo(5000, gy)
      nvgStroke()
    end
  end

  -- 连接线
  for _, conn in ipairs(NodeEditor:getConnections()) do
    local fromNode = NodeEditor:getNodeById(conn.fromId)
    local toNode = NodeEditor:getNodeById(conn.toId)
    if fromNode and toNode then
      local fromX = fromNode.x + (fromNode.w or 160)
      local fromY = fromNode.y + 30 + (conn.fromPort - 1) * 24
      local toX = toNode.x
      local toY = toNode.y + 30 + (conn.toPort - 1) * 24

      nvgStrokeColor(Config.COLORS.textDim)
      nvgStrokeWidth(2)
      nvgBeginPath()
      nvgMoveTo(fromX, fromY)
      local cp1x = fromX + 50
      local cp2x = toX - 50
      nvgBezierTo(cp1x, fromY, cp2x, toY, toX, toY)
      nvgStroke()
    end
  end

  -- 正在拖拽的连接线
  if self._isConnecting then
    nvgStrokeColor(Config.COLORS.accent)
    nvgStrokeWidth(2)
    nvgBeginPath()
    nvgMoveTo(self._connectLine.x1, self._connectLine.y1)
    nvgLineTo(self._connectLine.x2, self._connectLine.y2)
    nvgStroke()
  end

  -- 节点
  for _, node in ipairs(NodeEditor:getAllNodes()) do
    local def = NodeEditor.NODE_TYPES[node.type]
    local color = (def and def.color) or Config.NODE_COLORS.action

    -- 节点背景
    if node.id == NodeEditor._data.selectedNodeId then
      nvgStrokeColor(Config.COLORS.accent)
      nvgStrokeWidth(2)
    else
      nvgStrokeColor(Config.COLORS.border)
      nvgStrokeWidth(1)
    end
    nvgFillColor({color[1], color[2], color[3], 200})
    nvgRect(node.x, node.y, node.w or 160, node.h or 80)
    nvgFill()
    nvgStroke()

    -- 节点标题栏
    nvgFillColor({color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 255})
    nvgRect(node.x, node.y, node.w or 160, 24)
    nvgFill()

    nvgFillColor(Config.COLORS.text)
    nvgFontSize(11)
    nvgText(node.x + 6, node.y + 16, node.type)

    -- 输入端口
    if node.inputs then
      for i, inp in ipairs(node.inputs) do
        local py = node.y + 30 + (i - 1) * 24
        local portColor = inp.type == "exec" and {255, 255, 255, 255} or {100, 200, 255, 255}
        if inp.connected then
          portColor = {100, 255, 100, 255}
        end
        nvgFillColor(portColor)
        nvgCircle(node.x, py, 6)
        nvgFill()
        nvgFillColor(Config.COLORS.text)
        nvgFontSize(10)
        nvgText(node.x + 10, py + 3, inp.name)
      end
    end

    -- 输出端口
    if node.outputs then
      for i, out in ipairs(node.outputs) do
        local py = node.y + 30 + (i - 1) * 24
        local portColor = out.type == "exec" and {255, 255, 255, 255} or {255, 200, 100, 255}
        nvgFillColor(portColor)
        nvgCircle(node.x + (node.w or 160), py, 6)
        nvgFill()
        nvgFillColor(Config.COLORS.text)
        nvgFontSize(10)
        local tw = nvgTextBounds(out.name)
        nvgText(node.x + (node.w or 160) - 10 - tw, py + 3, out.name)
      end
    end
  end
end

function IDEMain:_renderRightPanel()
  local x = Config.CANVAS_W - RIGHT_PANEL_W
  local y = TOOLBAR_H
  local w = RIGHT_PANEL_W
  local h = Config.CANVAS_H - TOOLBAR_H - BOTTOM_BAR_H

  nvgFillColor(Config.COLORS.panel)
  nvgRect(x, y, w, h)
  nvgFill()
  nvgStrokeColor(Config.COLORS.border)
  nvgRect(x, y, w, h)
  nvgStroke()

  if self._rightPanelTab == "properties" then
    self:_renderPropertiesPanel(x, y, w, h)
  elseif self._rightPanelTab == "components" then
    self:_renderComponentsPanel(x, y, w, h)
  elseif self._rightPanelTab == "console" then
    self:_renderConsolePanel(x, y, w, h)
  elseif self._rightPanelTab == "assets" then
    self:_renderAssetsPanel(x, y, w, h)
  end
end

function IDEMain:_renderPropertiesPanel(x, y, w, h)
  local selected = nil
  if self._mode == "scene" then
    selected = SceneManager:getSelected()
  elseif self._mode == "node" then
    selected = NodeEditor:getSelectedNode()
  end

  if not selected then
    nvgFillColor(Config.COLORS.textDim)
    nvgFontSize(12)
    nvgText(x + 10, y + 30, "未选择对象")
    return
  end

  local drawY = y + 5 - self._propertyScrollY
  local rowH = 26

  nvgScissor(x, y, w, h)

  -- 名称
  nvgFillColor(Config.COLORS.text)
  nvgFontSize(12)
  nvgText(x + 6, drawY + 14, "名称")
  drawY = drawY + rowH
  nvgFillColor(Config.COLORS.panelHeader)
  nvgRect(x + 4, drawY, w - 8, 22)
  nvgFill()
  nvgStrokeColor(Config.COLORS.border)
  nvgRect(x + 4, drawY, w - 8, 22)
  nvgStroke()
  nvgFillColor(Config.COLORS.text)
  nvgFontSize(11)
  nvgText(x + 8, drawY + 15, selected.name or selected.type or "?")
  drawY = drawY + rowH + 4

  -- 属性列表
  local props = {}
  if self._mode == "scene" then
    props = {
      {key = "type", label = "类型", readonly = true},
      {key = "x", label = "X坐标", type = "number"},
      {key = "y", label = "Y坐标", type = "number"},
      {key = "w", label = "宽度", type = "number"},
      {key = "h", label = "高度", type = "number"},
      {key = "rotation", label = "旋转", type = "number"},
      {key = "scaleX", label = "缩放X", type = "number"},
      {key = "scaleY", label = "缩放Y", type = "number"},
      {key = "opacity", label = "不透明度", type = "number", min = 0, max = 255},
      {key = "visible", label = "可见", type = "boolean"},
      {key = "locked", label = "锁定", type = "boolean"},
      {key = "layer", label = "图层", type = "string"},
    }
  else
    props = {
      {key = "type", label = "类型", readonly = true},
      {key = "x", label = "X坐标", type = "number"},
      {key = "y", label = "Y坐标", type = "number"},
    }
    -- 节点自定义属性
    local def = NodeEditor.NODE_TYPES[selected.type]
    if def and def.props then
      for _, prop in ipairs(def.props) do
        table.insert(props, {key = prop.name, label = prop.name, type = prop.type, options = prop.options})
      end
    end
  end

  for _, prop in ipairs(props) do
    if drawY + rowH > y and drawY < y + h then
      nvgFillColor(Config.COLORS.textDim)
      nvgFontSize(11)
      nvgText(x + 6, drawY + 14, prop.label)

      local val = selected[prop.key]
      local valStr = ""
      if type(val) == "table" then
        valStr = "{" .. table.concat(val, ",") .. "}"
      elseif type(val) == "boolean" then
        valStr = val and "✓" or "✗"
      else
        valStr = tostring(val or "")
      end

      nvgFillColor(Config.COLORS.panelHeader)
      nvgRect(x + 4, drawY + 16, w - 8, 22)
      nvgFill()
      nvgStrokeColor(Config.COLORS.border)
      nvgRect(x + 4, drawY + 16, w - 8, 22)
      nvgStroke()
      nvgFillColor(prop.readonly and Config.COLORS.textDim or Config.COLORS.text)
      nvgFontSize(11)
      nvgText(x + 8, drawY + 31, valStr)
    end
    drawY = drawY + rowH + 18
  end

  nvgResetScissor()
end

function IDEMain:_renderComponentsPanel(x, y, w, h)
  if self._mode ~= "scene" then
    nvgFillColor(Config.COLORS.textDim)
    nvgFontSize(12)
    nvgText(x + 10, y + 30, "组件编辑仅在场景模式可用")
    return
  end

  local selected = SceneManager:getSelected()
  if not selected then
    nvgFillColor(Config.COLORS.textDim)
    nvgFontSize(12)
    nvgText(x + 10, y + 30, "未选择对象")
    return
  end

  local drawY = y + 5 - self._componentScrollY
  local rowH = 28

  nvgScissor(x, y, w, h)

  -- 当前组件列表
  local components = SceneManager:getComponents(selected.id)
  if #components > 0 then
    nvgFillColor(Config.COLORS.text)
    nvgFontSize(11)
    nvgText(x + 6, drawY + 12, "已挂载组件:")
    drawY = drawY + 18

    for _, comp in ipairs(components) do
      if drawY + rowH > y and drawY < y + h then
        nvgFillColor(Config.COLORS.panelHeader)
        nvgRect(x + 4, drawY, w - 8, rowH)
        nvgFill()
        nvgStrokeColor(Config.COLORS.border)
        nvgRect(x + 4, drawY, w - 8, rowH)
        nvgStroke()
        nvgFillColor(comp.enabled and Config.COLORS.text or Config.COLORS.textDim)
        nvgFontSize(11)
        nvgText(x + 8, drawY + 18, (comp.enabled and "✓" or "✗") .. " " .. comp.name)
      end
      drawY = drawY + rowH + 2
    end
    drawY = drawY + 10
  end

  -- 添加组件按钮
  local cats = ComponentSystem:GetTypesByCategory()
  for catName, types in pairs(cats) do
    if drawY + 20 > y and drawY < y + h then
      nvgFillColor(Config.COLORS.accent)
      nvgFontSize(11)
      nvgText(x + 6, drawY + 14, "+ " .. catName)
    end
    drawY = drawY + 20

    for _, typeInfo in ipairs(types) do
      if drawY + 24 > y and drawY < y + h then
        nvgFillColor(Config.COLORS.panel)
        nvgRect(x + 8, drawY, w - 16, 22)
        nvgFill()
        nvgStrokeColor(Config.COLORS.border)
        nvgRect(x + 8, drawY, w - 16, 22)
        nvgStroke()
        nvgFillColor(Config.COLORS.text)
        nvgFontSize(10)
        nvgText(x + 14, drawY + 15, typeInfo.icon .. " " .. typeInfo.name)
      end
      drawY = drawY + 24 + 2
    end
    drawY = drawY + 5
  end

  nvgResetScissor()
end

function IDEMain:_renderConsolePanel(x, y, w, h)
  local logs = Console:GetFilteredLogs()
  local rowH = 16
  local scrollMax = math.max(0, #logs * rowH - h + 30)
  self._consoleScrollY = math.max(0, math.min(self._consoleScrollY, scrollMax))

  nvgScissor(x, y, w, h)

  -- 日志
  local drawY = y + 5 - self._consoleScrollY
  for _, log in ipairs(logs) do
    if drawY + rowH > y and drawY < y + h then
      local levelInfo = Console.LEVELS[log.level] or Console.LEVELS.log
      nvgFillColor(levelInfo.color)
      nvgFontSize(10)
      nvgText(x + 4, drawY + 12, string.format("[%s] %s", log.timeStr, log.message))
    end
    drawY = drawY + rowH
  end

  nvgResetScissor()

  -- 输入框
  local inputY = y + h - 28
  nvgFillColor(Config.COLORS.panelHeader)
  nvgRect(x, inputY, w, 28)
  nvgFill()
  nvgStrokeColor(Config.COLORS.border)
  nvgRect(x, inputY, w, 28)
  nvgStroke()
  nvgFillColor(Config.COLORS.text)
  nvgFontSize(11)
  nvgText(x + 6, inputY + 18, "> " .. Console._input_text .. "_")
end

function IDEMain:_renderAssetsPanel(x, y, w, h)
  local assets = AssetBrowser:GetFilteredAssets()
  local rowH = 50
  local scrollMax = math.max(0, #assets * rowH - h + 10)

  nvgScissor(x, y, w, h)
  local drawY = y + 5

  for _, asset in ipairs(assets) do
    if drawY + rowH > y and drawY < y + h then
      nvgFillColor(Config.COLORS.panel)
      nvgRect(x + 4, drawY, w - 8, rowH)
      nvgFill()
      nvgStrokeColor(Config.COLORS.border)
      nvgRect(x + 4, drawY, w - 8, rowH)
      nvgStroke()
      nvgFillColor(Config.COLORS.text)
      nvgFontSize(10)
      nvgText(x + 8, drawY + 14, asset.name)
      nvgFillColor(Config.COLORS.textDim)
      nvgFontSize(9)
      nvgText(x + 8, drawY + 28, asset.category)
    end
    drawY = drawY + rowH + 2
  end
  nvgResetScissor()
end

function IDEMain:_renderConsoleOverlay()
  local x = LEFT_PANEL_W
  local y = Config.CANVAS_H - BOTTOM_BAR_H - self._consoleHeight
  local w = Config.CANVAS_W - LEFT_PANEL_W - RIGHT_PANEL_W
  local h = self._consoleHeight

  nvgFillColor(Config.COLORS.consoleBg)
  nvgRect(x, y, w, h)
  nvgFill()
  nvgStrokeColor(Config.COLORS.border)
  nvgRect(x, y, w, h)
  nvgStroke()

  local logs = Console:GetFilteredLogs()
  local rowH = 16
  local drawY = y + 5

  nvgScissor(x, y, w, h - 28)
  for i = #logs, math.max(1, #logs - math.floor((h - 30) / rowH)), -1 do
    local log = logs[i]
    local levelInfo = Console.LEVELS[log.level] or Console.LEVELS.log
    nvgFillColor(levelInfo.color)
    nvgFontSize(10)
    nvgText(x + 6, drawY + 12, string.format("[%s] %s", log.timeStr, log.message))
    drawY = drawY + rowH
  end
  nvgResetScissor()

  -- 输入
  local inputY = y + h - 26
  nvgFillColor(Config.COLORS.panelHeader)
  nvgRect(x, inputY, w, 26)
  nvgFill()
  nvgFillColor(Config.COLORS.text)
  nvgFontSize(11)
  nvgText(x + 6, inputY + 17, "> " .. Console._input_text)
end

function IDEMain:_renderBottomBar()
  local y = Config.CANVAS_H - BOTTOM_BAR_H

  nvgFillColor(Config.COLORS.toolbar)
  nvgRect(0, y, Config.CANVAS_W, BOTTOM_BAR_H)
  nvgFill()
  nvgStrokeColor(Config.COLORS.border)
  nvgRect(0, y, Config.CANVAS_W, BOTTOM_BAR_H)
  nvgStroke()

  nvgFillColor(Config.COLORS.text)
  nvgFontSize(11)

  -- 状态消息
  local statusText = self._statusTimer > 0 and self._statusMessage or (
    string.format("FPS:%d | 对象:%d | 节点:%d | 缩放:%.0f%% | 模式:%s",
      math.floor(self._fps or 60),
      SceneManager:getObjectCount(),
      NodeEditor:getNodeCount(),
      self._canvasZoom * 100,
      self._mode == "scene" and "场景" or "节点"
    )
  )
  nvgText(6, y + 16, statusText)

  -- 撤销/重做状态
  local undoText = (UndoManager:canUndo() and "↩" or "  ") .. " | " .. (UndoManager:canRedo() and "↪" or "  ")
  nvgText(Config.CANVAS_W - 60, y + 16, undoText)

  -- 网格/吸附状态
  local gridText = (self._showGrid and "⊞" or "⊡") .. " " .. (Config.SNAP_TO_GRID and "⌗" or "  ")
  nvgText(Config.CANVAS_W - 120, y + 16, gridText)
end

-- ==================== 文件操作 ====================
function IDEMain:saveProject()
  local data = {
    version = Config.VERSION,
    scene = SceneManager:serialize(),
    nodes = NodeEditor:serialize(),
    timestamp = os.time(),
  }
  local json = Config.toJSON(data)
  -- fileSystem:WriteFile("project.json", json)
  print("[IDEMain] 项目已保存")
  self:_setStatus("项目已保存")
end

function IDEMain:loadProject()
  -- local json = fileSystem:ReadFile("project.json")
  -- if json then
  --   local data = json.decode(json) -- 需要JSON解析器
  --   SceneManager:deserialize(data.scene)
  --   NodeEditor:deserialize(data.nodes)
  -- end
  print("[IDEMain] 项目已加载")
  self:_setStatus("项目已加载")
end

function IDEMain:newProject()
  SceneManager:init()
  NodeEditor:init()
  UndoManager:clear()
  self._canvasOffsetX = 0
  self._canvasOffsetY = 0
  self._canvasZoom = 1.0
  self:_setStatus("新建项目")
end

-- ==================== 输入处理 ====================
function IDEMain:onTextInput(text)
  if self._editingProperty then
    self._editingValue = self._editingValue .. text
  elseif Console:IsVisible() then
    Console._input_text = Console._input_text .. text
  end
end

function IDEMain:onKeyDown(key)
  if self._editingProperty then
    if key == KEY_RETURN then
      self:_commitPropertyEdit()
    elseif key == KEY_ESCAPE then
      self._editingProperty = nil
    elseif key == KEY_BACKSPACE then
      self._editingValue = self._editingValue:sub(1, -2)
    end
  elseif Console:IsVisible() then
    if key == KEY_RETURN then
      Console:ExecuteCommand(Console._input_text)
      Console._input_text = ""
    elseif key == KEY_BACKSPACE then
      Console._input_text = Console._input_text:sub(1, -2)
    elseif key == KEY_UP then
      local hist = Console:HistoryUp()
      if hist then Console._input_text = hist end
    elseif key == KEY_DOWN then
      local hist = Console:HistoryDown()
      if hist ~= nil then Console._input_text = hist end
    end
  end
end

function IDEMain:_commitPropertyEdit()
  if not self._editingProperty then return end
  local prop = self._editingProperty

  if self._mode == "scene" then
    local obj = SceneManager:getObjectById(prop.id)
    if obj then
      if prop.type == "name" then
        obj.name = self._editingValue
      else
        local numVal = tonumber(self._editingValue)
        if numVal then
          SceneManager:updateObject(prop.id, {[prop.key] = numVal})
        elseif self._editingValue == "true" then
          SceneManager:updateObject(prop.id, {[prop.key] = true})
        elseif self._editingValue == "false" then
          SceneManager:updateObject(prop.id, {[prop.key] = false})
        else
          SceneManager:updateObject(prop.id, {[prop.key] = self._editingValue})
        end
      end
    end
  end

  self._editingProperty = nil
  self._editingValue = ""
end

return IDEMain
