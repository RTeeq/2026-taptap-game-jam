-- ============================================================
-- IDE/UndoManager.lua - 完整版撤销/重做系统
-- 新增: 实际撤销执行、分组操作、操作描述、历史浏览
-- ============================================================
local Config = require("IDE.Config")
local EventBus = require("IDE.EventBus")

local UndoManager = {}

UndoManager._undo_stack = {}
UndoManager._redo_stack = {}
UndoManager._max_size = 100
UndoManager._grouping = false
UndoManager._group_buffer = {}
UndoManager._sceneManager = nil
UndoManager._nodeEditor = nil

-- 操作执行器映射表
UndoManager.EXECUTORS = {}

function UndoManager:init(sceneMgr, nodeEditor)
  self._undo_stack = {}
  self._redo_stack = {}
  self._grouping = false
  self._group_buffer = {}
  self._sceneManager = sceneMgr
  self._nodeEditor = nodeEditor
  self:_registerExecutors()
end

-- 注册所有操作类型的执行器
function UndoManager:_registerExecutors()
  -- 场景对象操作
  self.EXECUTORS["create_object"] = {
    undo = function(data)
      if self._sceneManager then
        self._sceneManager:deleteObject(data.object.id)
      end
    end,
    redo = function(data)
      if self._sceneManager then
        self._sceneManager._data.objects[data.object.id] = Config.deepcopy(data.object)
        EventBus:emit("scene.object_created", data.object)
      end
    end,
    desc = function(data) return "创建对象: " .. (data.object.name or "?") end,
  }

  self.EXECUTORS["delete_object"] = {
    undo = function(data)
      if self._sceneManager then
        self._sceneManager._data.objects[data.object.id] = Config.deepcopy(data.object)
        EventBus:emit("scene.object_created", data.object)
      end
    end,
    redo = function(data)
      if self._sceneManager then
        self._sceneManager:deleteObject(data.object.id)
      end
    end,
    desc = function(data) return "删除对象: " .. (data.object.name or "?") end,
  }

  self.EXECUTORS["move_object"] = {
    undo = function(data)
      if self._sceneManager then
        local obj = self._sceneManager:getObjectById(data.id)
        if obj then obj.x, obj.y = data.fromX, data.fromY end
      end
    end,
    redo = function(data)
      if self._sceneManager then
        local obj = self._sceneManager:getObjectById(data.id)
        if obj then obj.x, obj.y = data.toX, data.toY end
      end
    end,
    desc = function(data) return "移动对象" end,
  }

  self.EXECUTORS["update_object"] = {
    undo = function(data)
      if self._sceneManager then
        local obj = self._sceneManager:getObjectById(data.id)
        if obj then
          for k, v in pairs(data.oldProps) do obj[k] = v end
        end
      end
    end,
    redo = function(data)
      if self._sceneManager then
        local obj = self._sceneManager:getObjectById(data.id)
        if obj then
          for k, v in pairs(data.newProps) do obj[k] = v end
        end
      end
    end,
    desc = function(data) return "修改属性" end,
  }

  -- 节点操作
  self.EXECUTORS["create_node"] = {
    undo = function(data)
      if self._nodeEditor then
        self._nodeEditor._data.nodes[data.node.id] = nil
        EventBus:emit("node.deleted", data.node.id)
      end
    end,
    redo = function(data)
      if self._nodeEditor then
        self._nodeEditor._data.nodes[data.node.id] = Config.deepcopy(data.node)
        EventBus:emit("node.created", data.node)
      end
    end,
    desc = function(data) return "创建节点: " .. (data.node.type or "?") end,
  }

  self.EXECUTORS["delete_node"] = {
    undo = function(data)
      if self._nodeEditor then
        self._nodeEditor._data.nodes[data.node.id] = Config.deepcopy(data.node)
        EventBus:emit("node.created", data.node)
      end
    end,
    redo = function(data)
      if self._nodeEditor then
        self._nodeEditor:deleteNode(data.node.id)
      end
    end,
    desc = function(data) return "删除节点: " .. (data.node.type or "?") end,
  }

  self.EXECUTORS["move_node"] = {
    undo = function(data)
      if self._nodeEditor then
        local node = self._nodeEditor:getNodeById(data.id)
        if node then node.x, node.y = data.fromX, data.fromY end
      end
    end,
    redo = function(data)
      if self._nodeEditor then
        local node = self._nodeEditor:getNodeById(data.id)
        if node then node.x, node.y = data.toX, data.toY end
      end
    end,
    desc = function(data) return "移动节点" end,
  }

  self.EXECUTORS["connect"] = {
    undo = function(data)
      if self._nodeEditor then
        local conns = self._nodeEditor._data.connections
        for i = #conns, 1, -1 do
          local c = conns[i]
          if c.fromId == data.fromId and c.fromPort == data.fromPort
             and c.toId == data.toId and c.toPort == data.toPort then
            table.remove(conns, i)
            break
          end
        end
      end
    end,
    redo = function(data)
      if self._nodeEditor then
        table.insert(self._nodeEditor._data.connections, {
          fromId = data.fromId, fromPort = data.fromPort,
          toId = data.toId, toPort = data.toPort
        })
      end
    end,
    desc = function(data) return "连接节点" end,
  }

  self.EXECUTORS["disconnect"] = {
    undo = function(data)
      if self._nodeEditor then
        table.insert(self._nodeEditor._data.connections, Config.deepcopy(data.conn))
      end
    end,
    redo = function(data)
      if self._nodeEditor then
        local conns = self._nodeEditor._data.connections
        for i = #conns, 1, -1 do
          if conns[i].fromId == data.conn.fromId and conns[i].toId == data.conn.toId then
            table.remove(conns, i)
            break
          end
        end
      end
    end,
    desc = function(data) return "断开连接" end,
  }
end

-- 记录操作
function UndoManager:record(action_type, data)
  local action = {
    type = action_type,
    data = Config.deepcopy(data),
    timestamp = os.time(),
  }
  if self._grouping then
    table.insert(self._group_buffer, action)
    return
  end
  table.insert(self._undo_stack, action)
  if #self._undo_stack > self._max_size then
    table.remove(self._undo_stack, 1)
  end
  self._redo_stack = {}
  EventBus:emit("undo.state_changed", self:canUndo(), self:canRedo())
end

-- 开始分组操作
function UndoManager:beginGroup(name)
  self._grouping = true
  self._group_name = name or "分组操作"
  self._group_buffer = {}
end

-- 结束分组操作
function UndoManager:endGroup()
  self._grouping = false
  if #self._group_buffer > 0 then
    table.insert(self._undo_stack, {
      type = "group",
      data = { actions = Config.deepcopy(self._group_buffer), name = self._group_name },
      timestamp = os.time(),
    })
    if #self._undo_stack > self._max_size then
      table.remove(self._undo_stack, 1)
    end
    self._redo_stack = {}
    EventBus:emit("undo.state_changed", self:canUndo(), self:canRedo())
  end
  self._group_buffer = {}
  self._group_name = nil
end

-- 撤销
function UndoManager:undo()
  if #self._undo_stack == 0 then return nil end
  local action = table.remove(self._undo_stack)
  table.insert(self._redo_stack, action)
  self:_executeUndo(action)
  EventBus:emit("undo.state_changed", self:canUndo(), self:canRedo())
  return action
end

-- 重做
function UndoManager:redo()
  if #self._redo_stack == 0 then return nil end
  local action = table.remove(self._redo_stack)
  table.insert(self._undo_stack, action)
  self:_executeRedo(action)
  EventBus:emit("undo.state_changed", self:canUndo(), self:canRedo())
  return action
end

-- 执行撤销
function UndoManager:_executeUndo(action)
  if action.type == "group" then
    -- 分组操作：逆序撤销每个子操作
    local group = action.data.actions
    for i = #group, 1, -1 do
      local sub = group[i]
      local exec = self.EXECUTORS[sub.type]
      if exec and exec.undo then
        local ok, err = pcall(exec.undo, sub.data)
        if not ok then print("[UndoManager] 撤销错误: " .. tostring(err)) end
      end
    end
  else
    local exec = self.EXECUTORS[action.type]
    if exec and exec.undo then
      local ok, err = pcall(exec.undo, action.data)
      if not ok then print("[UndoManager] 撤销错误: " .. tostring(err)) end
    else
      print("[UndoManager] 警告: 未注册的操作类型 " .. action.type)
    end
  end
end

-- 执行重做
function UndoManager:_executeRedo(action)
  if action.type == "group" then
    local group = action.data.actions
    for _, sub in ipairs(group) do
      local exec = self.EXECUTORS[sub.type]
      if exec and exec.redo then
        local ok, err = pcall(exec.redo, sub.data)
        if not ok then print("[UndoManager] 重做错误: " .. tostring(err)) end
      end
    end
  else
    local exec = self.EXECUTORS[action.type]
    if exec and exec.redo then
      local ok, err = pcall(exec.redo, action.data)
      if not ok then print("[UndoManager] 重做错误: " .. tostring(err)) end
    end
  end
end

-- 获取操作描述
function UndoManager:getActionDescription(action)
  if not action then return "" end
  if action.type == "group" then
    return action.data.name or "分组操作"
  end
  local exec = self.EXECUTORS[action.type]
  if exec and exec.desc then
    return exec.desc(action.data)
  end
  return action.type
end

-- 获取历史列表
function UndoManager:getHistory()
  local list = {}
  for i = #self._undo_stack, 1, -1 do
    table.insert(list, {
      index = i,
      desc = self:getActionDescription(self._undo_stack[i]),
      type = self._undo_stack[i].type,
    })
  end
  return list
end

function UndoManager:canUndo()
  return #self._undo_stack > 0
end

function UndoManager:canRedo()
  return #self._redo_stack > 0
end

function UndoManager:clear()
  self._undo_stack = {}
  self._redo_stack = {}
  EventBus:emit("undo.state_changed", false, false)
end

return UndoManager
