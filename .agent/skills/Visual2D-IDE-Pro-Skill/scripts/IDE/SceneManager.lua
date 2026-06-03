-- ============================================================
-- IDE/SceneManager.lua - 增强版场景管理器
-- 新增: 组件系统集成、对齐工具、多选、标签系统、场景树
-- ============================================================
local Config = require("IDE.Config")
local EventBus = require("IDE.EventBus")
local UndoManager = require("IDE.UndoManager")
local ComponentSystem = require("IDE.ComponentSystem")

local SceneManager = {}

SceneManager._data = {
  objects = {},
  layers = {},
  selectedIds = {}, -- 多选支持
  primarySelectedId = nil,
  nextId = 1,
  tags = {}, -- 标签系统
}

function SceneManager:init()
  self._data = {
    objects = {},
    layers = {
      {id = "bg", name = "背景层", visible = true, locked = false},
      {id = "game", name = "游戏层", visible = true, locked = false},
      {id = "ui", name = "UI层", visible = true, locked = false},
    },
    selectedIds = {},
    primarySelectedId = nil,
    nextId = 1,
    tags = {},
    activeLayerIdx = 2, -- 默认游戏层
  }
end

function SceneManager:createObject(objType, name, x, y, extra)
  local id = Config.generateId("obj")
  local sx, sy = Config.snapToGrid(x, y)
  local obj = {
    id = id,
    type = objType or "sprite",
    name = name or ("对象_" .. self._data.nextId),
    x = sx, y = sy,
    w = (extra and extra.w) or 64,
    h = (extra and extra.h) or 64,
    rotation = 0,
    scaleX = 1, scaleY = 1,
    layer = (extra and extra.layer) or self._data.layers[self._data.activeLayerIdx].id,
    visible = true,
    locked = false,
    tags = (extra and extra.tags) or {},
    components = {},
    meta = (extra and extra.meta) or {},
    zOrder = 0,
    opacity = 255,
    blendMode = "normal",
  }
  self._data.nextId = self._data.nextId + 1
  self._data.objects[id] = obj

  -- 注册标签
  for _, tag in ipairs(obj.tags) do
    self._data.tags[tag] = self._data.tags[tag] or {}
    table.insert(self._data.tags[tag], id)
  end

  UndoManager:record("create_object", {object = Config.deepcopy(obj)})
  EventBus:emit("scene.object_created", obj)
  return obj
end

function SceneManager:deleteObject(id)
  local obj = self._data.objects[id]
  if not obj then return false end

  -- 清理标签
  for _, tag in ipairs(obj.tags or {}) do
    local tagList = self._data.tags[tag]
    if tagList then
      for i = #tagList, 1, -1 do
        if tagList[i] == id then table.remove(tagList, i) end
      end
    end
  end

  UndoManager:record("delete_object", {object = Config.deepcopy(obj)})
  self._data.objects[id] = nil
  self._data.selectedIds[id] = nil
  if self._data.primarySelectedId == id then
    self._data.primarySelectedId = nil
  end
  EventBus:emit("scene.object_deleted", id)
  return true
end

function SceneManager:updateObject(id, props)
  local obj = self._data.objects[id]
  if not obj then return false end
  local oldProps = {}
  for k, v in pairs(props) do
    oldProps[k] = obj[k]
    obj[k] = v
  end
  UndoManager:record("update_object", {id = id, oldProps = oldProps, newProps = props})
  EventBus:emit("scene.object_updated", id, props)
  return true
end

function SceneManager:moveObject(id, dx, dy)
  local obj = self._data.objects[id]
  if not obj or obj.locked then return false end
  local newX = obj.x + dx
  local newY = obj.y + dy
  if Config.SNAP_TO_GRID then
    newX, newY = Config.snapToGrid(newX, newY)
  end
  obj.x = newX
  obj.y = newY
  EventBus:emit("scene.object_moved", id, newX, newY)
  return true
end

-- 多选支持
function SceneManager:selectObject(id, addToSelection)
  if addToSelection then
    if id then
      self._data.selectedIds[id] = true
      self._data.primarySelectedId = id
    end
  else
    self._data.selectedIds = {}
    if id then
      self._data.selectedIds[id] = true
      self._data.primarySelectedId = id
    else
      self._data.primarySelectedId = nil
    end
  end
  EventBus:emit("scene.selection_changed", self._data.primarySelectedId, self._data.selectedIds)
end

function SceneManager:toggleSelection(id)
  if self._data.selectedIds[id] then
    self._data.selectedIds[id] = nil
    if self._data.primarySelectedId == id then
      -- 找下一个选中的
      for selId, _ in pairs(self._data.selectedIds) do
        self._data.primarySelectedId = selId
        break
      end
    end
  else
    self._data.selectedIds[id] = true
    self._data.primarySelectedId = id
  end
  EventBus:emit("scene.selection_changed", self._data.primarySelectedId, self._data.selectedIds)
end

function SceneManager:selectAll()
  for id, _ in pairs(self._data.objects) do
    self._data.selectedIds[id] = true
  end
  EventBus:emit("scene.selection_changed", nil, self._data.selectedIds)
end

function SceneManager:clearSelection()
  self._data.selectedIds = {}
  self._data.primarySelectedId = nil
  EventBus:emit("scene.selection_changed", nil, {})
end

function SceneManager:getSelected()
  if self._data.primarySelectedId then
    return self._data.objects[self._data.primarySelectedId]
  end
  return nil
end

function SceneManager:getSelectedIds()
  local ids = {}
  for id, _ in pairs(self._data.selectedIds) do
    table.insert(ids, id)
  end
  return ids
end

function SceneManager:getSelectedObjects()
  local list = {}
  for id, _ in pairs(self._data.selectedIds) do
    if self._data.objects[id] then
      table.insert(list, self._data.objects[id])
    end
  end
  return list
end

function SceneManager:isSelected(id)
  return self._data.selectedIds[id] ~= nil
end

-- 对齐工具
function SceneManager:alignSelected(alignment)
  local selected = self:getSelectedObjects()
  if #selected < 2 then return end
  Config.alignObjects(selected, alignment)
  EventBus:emit("scene.objects_aligned", alignment, selected)
end

function SceneManager:distributeSelected(axis)
  local selected = self:getSelectedObjects()
  if #selected < 3 then return end
  Config.distributeObjects(selected, axis)
  EventBus:emit("scene.objects_distributed", axis, selected)
end

-- 标签系统
function SceneManager:addTag(id, tag)
  local obj = self._data.objects[id]
  if not obj then return false end
  for _, t in ipairs(obj.tags) do
    if t == tag then return false end
  end
  table.insert(obj.tags, tag)
  self._data.tags[tag] = self._data.tags[tag] or {}
  table.insert(self._data.tags[tag], id)
  return true
end

function SceneManager:removeTag(id, tag)
  local obj = self._data.objects[id]
  if not obj then return false end
  for i, t in ipairs(obj.tags) do
    if t == tag then
      table.remove(obj.tags, i)
      break
    end
  end
  local tagList = self._data.tags[tag]
  if tagList then
    for i = #tagList, 1, -1 do
      if tagList[i] == id then table.remove(tagList, i) end
    end
  end
  return true
end

function SceneManager:findByTag(tag)
  local ids = self._data.tags[tag] or {}
  local result = {}
  for _, id in ipairs(ids) do
    if self._data.objects[id] then
      table.insert(result, self._data.objects[id])
    end
  end
  return result
end

-- 组件系统集成
function SceneManager:addComponent(id, componentType)
  local obj = self._data.objects[id]
  if not obj then return nil end
  return ComponentSystem:AddComponent(obj, componentType)
end

function SceneManager:removeComponent(id, componentId)
  local obj = self._data.objects[id]
  if not obj then return false end
  return ComponentSystem:RemoveComponent(obj, componentId)
end

function SceneManager:getComponents(id)
  local obj = self._data.objects[id]
  if not obj then return {} end
  return ComponentSystem:GetAllComponents(obj)
end

function SceneManager:setComponentProperty(id, componentId, propName, value)
  local obj = self._data.objects[id]
  if not obj then return false end
  return ComponentSystem:SetProperty(obj, componentId, propName, value)
end

function SceneManager:getAllObjects()
  local list = {}
  for _, obj in pairs(self._data.objects) do
    table.insert(list, obj)
  end
  table.sort(list, function(a, b)
    if a.layer == b.layer then return (a.zOrder or 0) < (b.zOrder or 0) end
    return a.layer < b.layer
  end)
  return list
end

function SceneManager:getObjectCount()
  local count = 0
  for _ in pairs(self._data.objects) do count = count + 1 end
  return count
end

function SceneManager:getLayers()
  return self._data.layers
end

function SceneManager:addLayer(name)
  if #self._data.layers >= Config.MAX_LAYERS then return nil end
  local layer = {
    id = Config.generateId("layer"),
    name = name or "新图层",
    visible = true,
    locked = false,
  }
  table.insert(self._data.layers, layer)
  EventBus:emit("scene.layer_added", layer)
  return layer
end

function SceneManager:removeLayer(layerId)
  for i, layer in ipairs(self._data.layers) do
    if layer.id == layerId then
      -- 将该层对象移到默认层
      for _, obj in pairs(self._data.objects) do
        if obj.layer == layerId then
          obj.layer = self._data.layers[1] and self._data.layers[1].id or "game"
        end
      end
      table.remove(self._data.layers, i)
      EventBus:emit("scene.layer_removed", layerId)
      return true
    end
  end
  return false
end

function SceneManager:setLayerVisible(layerId, visible)
  for _, layer in ipairs(self._data.layers) do
    if layer.id == layerId then
      layer.visible = visible
      EventBus:emit("scene.layer_visibility_changed", layerId, visible)
      return true
    end
  end
  return false
end

function SceneManager:setLayerLocked(layerId, locked)
  for _, layer in ipairs(self._data.layers) do
    if layer.id == layerId then
      layer.locked = locked
      EventBus:emit("scene.layer_lock_changed", layerId, locked)
      return true
    end
  end
  return false
end

function SceneManager:hitTest(px, py)
  local objects = self:getAllObjects()
  for i = #objects, 1, -1 do
    local obj = objects[i]
    if obj.visible and not obj.locked then
      local hw = (obj.w or 64) / 2
      local hh = (obj.h or 64) / 2
      if px >= obj.x - hw and px <= obj.x + hw and py >= obj.y - hh and py <= obj.y + hh then
        return obj
      end
    end
  end
  return nil
end

function SceneManager:hitTestRect(x1, y1, x2, y2)
  local result = {}
  local minX, maxX = math.min(x1, x2), math.max(x1, x2)
  local minY, maxY = math.min(y1, y2), math.max(y1, y2)
  for _, obj in pairs(self._data.objects) do
    if obj.visible and not obj.locked then
      local hw = (obj.w or 64) / 2
      local hh = (obj.h or 64) / 2
      local ox1, ox2 = obj.x - hw, obj.x + hw
      local oy1, oy2 = obj.y - hh, obj.y + hh
      if ox1 < maxX and ox2 > minX and oy1 < maxY and oy2 > minY then
        table.insert(result, obj)
      end
    end
  end
  return result
end

-- 导出为Lua代码
function SceneManager:exportToLua()
  local lines = {}
  table.insert(lines, "-- ============================================")
  table.insert(lines, "-- 场景代码 (由 Visual2D IDE 自动生成)")
  table.insert(lines, "-- ============================================")
  table.insert(lines, "local Scene = {}")
  table.insert(lines, "")
  table.insert(lines, "function Scene:load()")

  local objects = self:getAllObjects()
  for _, obj in ipairs(objects) do
    local varName = obj.name:gsub("[^%w_]", "_")
    table.insert(lines, string.format(
      '  local %s = createNode("%s", %.1f, %.1f, %.1f, %.1f)',
      varName, obj.type, obj.x, obj.y, obj.w, obj.h
    ))
    if obj.rotation ~= 0 then
      table.insert(lines, string.format('  %s:setRotation(%.1f)', varName, obj.rotation))
    end
    if obj.scaleX ~= 1 or obj.scaleY ~= 1 then
      table.insert(lines, string.format('  %s:setScale(%.2f, %.2f)', varName, obj.scaleX, obj.scaleY))
    end
    if obj.opacity ~= 255 then
      table.insert(lines, string.format('  %s:setOpacity(%d)', varName, obj.opacity))
    end
    if obj.layer and obj.layer ~= "game" then
      table.insert(lines, string.format('  %s:setLayer("%s")', varName, obj.layer))
    end
    -- 导出组件
    if obj.components and #obj.components > 0 then
      for _, comp in ipairs(obj.components) do
        local compCode = ComponentSystem:ExportComponent(comp)
        if compCode ~= "" then
          for line in compCode:gmatch("[^
]+") do
            table.insert(lines, "  " .. line)
          end
        end
      end
    end
    -- 导出标签
    if obj.tags and #obj.tags > 0 then
      table.insert(lines, string.format('  %s:addTags({%s})', varName, table.concat(obj.tags, ", ")))
    end
  end

  table.insert(lines, "end")
  table.insert(lines, "")
  table.insert(lines, "return Scene")
  return table.concat(lines, "
")
end

-- 序列化
function SceneManager:serialize()
  return {
    version = Config.VERSION,
    objects = Config.deepcopy(self._data.objects),
    layers = Config.deepcopy(self._data.layers),
    nextId = self._data.nextId,
    tags = Config.deepcopy(self._data.tags),
  }
end

function SceneManager:deserialize(data)
  if not data then return false end
  self._data.objects = data.objects or {}
  self._data.layers = data.layers or self._data.layers
  self._data.nextId = data.nextId or 1
  self._data.tags = data.tags or {}
  self._data.selectedIds = {}
  self._data.primarySelectedId = nil
  EventBus:emit("scene.loaded")
  return true
end

function SceneManager:getObjectById(id)
  return self._data.objects[id]
end

function SceneManager:getActiveLayerIndex()
  return self._data.activeLayerIdx or 1
end

function SceneManager:setActiveLayer(idx)
  if idx >= 1 and idx <= #self._data.layers then
    self._data.activeLayerIdx = idx
    EventBus:emit("scene.active_layer_changed", idx)
  end
end

return SceneManager
