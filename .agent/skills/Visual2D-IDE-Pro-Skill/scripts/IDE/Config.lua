-- ============================================================
-- IDE/Config.lua - 增强版 IDE 全局配置与工具函数
-- 新增: 动态主题、快捷键映射、对齐工具、版本控制
-- ============================================================
local M = {}

M.GRID_SIZE = 32
M.SNAP_TO_GRID = true
M.MAX_LAYERS = 8
M.VERSION = "2.0.0"
M.CANVAS_W = 1280
M.CANVAS_H = 720

-- 颜色主题系统 (支持动态切换)
M.THEMES = {
  dark = {
    bg = {30, 30, 30, 255},
    toolbar = {50, 50, 51, 255},
    panel = {37, 37, 38, 255},
    panelHeader = {60, 60, 65, 255},
    canvas = {45, 45, 48, 255},
    text = {204, 204, 204, 255},
    textDim = {128, 128, 128, 255},
    accent = {14, 99, 156, 255},
    accentHover = {17, 119, 187, 255},
    success = {76, 175, 80, 255},
    danger = {231, 76, 60, 255},
    warning = {243, 156, 18, 255},
    border = {68, 68, 68, 255},
    selected = {9, 71, 113, 255},
    grid = {60, 60, 65, 100},
    gridMajor = {80, 80, 85, 150},
    consoleBg = {25, 25, 25, 255},
    consoleText = {220, 220, 220, 255},
    consoleError = {255, 100, 100, 255},
    consoleWarn = {255, 200, 100, 255},
    consoleInfo = {100, 180, 255, 255},
  },
  light = {
    bg = {245, 245, 245, 255},
    toolbar = {230, 230, 230, 255},
    panel = {255, 255, 255, 255},
    panelHeader = {220, 220, 220, 255},
    canvas = {250, 250, 250, 255},
    text = {50, 50, 50, 255},
    textDim = {120, 120, 120, 255},
    accent = {0, 122, 204, 255},
    accentHover = {0, 100, 170, 255},
    success = {34, 139, 34, 255},
    danger = {200, 50, 50, 255},
    warning = {200, 150, 0, 255},
    border = {200, 200, 200, 255},
    selected = {180, 215, 255, 255},
    grid = {200, 200, 200, 80},
    gridMajor = {180, 180, 180, 120},
    consoleBg = {240, 240, 240, 255},
    consoleText = {50, 50, 50, 255},
    consoleError = {200, 50, 50, 255},
    consoleWarn = {180, 130, 0, 255},
    consoleInfo = {0, 100, 200, 255},
  },
}

M.COLORS = M.THEMES.dark -- 默认暗色主题

-- 节点编辑器颜色
M.NODE_COLORS = {
  event = {231, 76, 60, 255},
  action = {52, 152, 219, 255},
  condition = {243, 156, 18, 255},
  math = {155, 89, 182, 255},
  variable = {26, 188, 156, 255},
  input = {52, 73, 94, 255},
  flow = {149, 165, 166, 255},
  animation = {230, 126, 34, 255},
  audio = {241, 196, 15, 255},
  ui = {52, 73, 94, 255},
}

-- 快捷键映射表
M.SHORTCUTS = {
  -- 文件操作
  { key = KEY_N, ctrl = true, shift = false, action = "file.new" },
  { key = KEY_S, ctrl = true, shift = false, action = "file.save" },
  { key = KEY_S, ctrl = true, shift = true, action = "file.save_as" },
  { key = KEY_O, ctrl = true, shift = false, action = "file.load" },
  -- 编辑操作
  { key = KEY_Z, ctrl = true, shift = false, action = "edit.undo" },
  { key = KEY_Z, ctrl = true, shift = true, action = "edit.redo" },
  { key = KEY_C, ctrl = true, shift = false, action = "edit.copy" },
  { key = KEY_V, ctrl = true, shift = false, action = "edit.paste" },
  { key = KEY_X, ctrl = true, shift = false, action = "edit.cut" },
  { key = KEY_D, ctrl = true, shift = false, action = "edit.duplicate" },
  { key = KEY_A, ctrl = true, shift = false, action = "edit.select_all" },
  { key = KEY_DELETE, ctrl = false, shift = false, action = "edit.delete" },
  -- 视图操作
  { key = KEY_G, ctrl = false, shift = false, action = "view.grid_toggle" },
  { key = KEY_H, ctrl = false, shift = false, action = "view.snap_toggle" },
  { key = KEY_F, ctrl = false, shift = false, action = "view.frame_selection" },
  { key = KEY_0, ctrl = true, shift = false, action = "view.reset_zoom" },
  -- 对齐操作
  { key = KEY_LEFT, ctrl = false, shift = false, action = "align.left" },
  { key = KEY_RIGHT, ctrl = false, shift = false, action = "align.right" },
  { key = KEY_UP, ctrl = false, shift = false, action = "align.top" },
  { key = KEY_DOWN, ctrl = false, shift = false, action = "align.bottom" },
  -- 模式切换
  { key = KEY_TAB, ctrl = false, shift = false, action = "mode.switch" },
  { key = KEY_F5, ctrl = false, shift = false, action = "mode.play" },
  -- 编译
  { key = KEY_F7, ctrl = false, shift = false, action = "build.compile" },
}

-- 切换主题
function M.SetTheme(themeName)
  if M.THEMES[themeName] then
    M.COLORS = M.THEMES[themeName]
    print("[Config] 主题已切换: " .. themeName)
    return true
  end
  return false
end

-- 深度拷贝
function M.deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[M.deepcopy(orig_key)] = M.deepcopy(orig_value)
    end
    setmetatable(copy, getmetatable(orig))
  else
    copy = orig
  end
  return copy
end

-- 浅拷贝
function M.shallowcopy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do copy[k] = v end
  return copy
end

-- 生成唯一ID
local id_counter = 0
function M.generateId(prefix)
  id_counter = id_counter + 1
  return (prefix or "obj") .. "_" .. id_counter .. "_" .. os.time()
end

-- 网格对齐
function M.snapToGrid(x, y)
  if not M.SNAP_TO_GRID then return x, y end
  local gs = M.GRID_SIZE
  return math.floor(x / gs + 0.5) * gs, math.floor(y / gs + 0.5) * gs
end

-- 点是否在矩形内
function M.pointInRect(px, py, rx, ry, rw, rh)
  return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- 点是否在圆内
function M.pointInCircle(px, py, cx, cy, r)
  local dx, dy = px - cx, py - cy
  return dx * dx + dy * dy <= r * r
end

-- 序列化为Lua字符串(增强版，支持循环引用检测)
function M.serialize(obj, indent, visited)
  indent = indent or 0
  visited = visited or {}
  local prefix = string.rep("  ", indent)

  if type(obj) == "table" then
    if visited[obj] then return '"<circular>"' end
    visited[obj] = true
    local s = "{
"
    for k, v in pairs(obj) do
      local key
      if type(k) == "number" then
        key = "[" .. k .. "]"
      elseif type(k) == "string" and k:match("^[%a_][%w_]*$") then
        key = k
      else
        key = '["' .. tostring(k) .. '"]' 
      end
      s = s .. prefix .. "  " .. key .. " = " .. M.serialize(v, indent + 1, visited) .. ",
"
    end
    return s .. prefix .. "}"
  elseif type(obj) == "string" then
    return '"' .. obj:gsub('\', '\\'):gsub('"', '\"'):gsub("
", "\n") .. '"'
  elseif type(obj) == "boolean" then
    return obj and "true" or "false"
  elseif type(obj) == "nil" then
    return "nil"
  elseif type(obj) == "number" then
    -- 处理 inf/nan
    if obj ~= obj then return "0/0" end
    if obj == math.huge then return "1/0" end
    if obj == -math.huge then return "-1/0" end
    return tostring(obj)
  else
    return '"' .. tostring(obj) .. '"'
  end
end

-- JSON 序列化 (简化版)
function M.toJSON(obj, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  if type(obj) == "table" then
    local isArray = #obj > 0
    for k, _ in pairs(obj) do
      if type(k) ~= "number" then isArray = false; break end
    end
    if isArray then
      local parts = {}
      for _, v in ipairs(obj) do
        table.insert(parts, M.toJSON(v, indent + 1))
      end
      return "[
" .. prefix .. "  " .. table.concat(parts, ",
" .. prefix .. "  ") .. "
" .. prefix .. "]"
    else
      local parts = {}
      for k, v in pairs(obj) do
        local key = type(k) == "string" and ('"' .. k .. '"') or tostring(k)
        table.insert(parts, prefix .. "  " .. key .. ": " .. M.toJSON(v, indent + 1))
      end
      return "{
" .. table.concat(parts, ",
") .. "
" .. prefix .. "}"
    end
  elseif type(obj) == "string" then
    return '"' .. obj:gsub('\', '\\'):gsub('"', '\"'):gsub("
", "\n") .. '"'
  elseif type(obj) == "number" then
    return tostring(obj)
  elseif type(obj) == "boolean" then
    return obj and "true" or "false"
  elseif obj == nil then
    return "null"
  end
  return "null"
end

-- 对齐工具函数
function M.alignObjects(objects, alignment)
  if #objects < 2 then return end
  local first = objects[1]
  for i = 2, #objects do
    local obj = objects[i]
    if alignment == "left" then obj.x = first.x - (first.w or 64) / 2 + (obj.w or 64) / 2
    elseif alignment == "right" then obj.x = first.x + (first.w or 64) / 2 - (obj.w or 64) / 2
    elseif alignment == "top" then obj.y = first.y - (first.h or 64) / 2 + (obj.h or 64) / 2
    elseif alignment == "bottom" then obj.y = first.y + (first.h or 64) / 2 - (obj.h or 64) / 2
    elseif alignment == "center_h" then obj.x = first.x
    elseif alignment == "center_v" then obj.y = first.y
    end
  end
end

-- 等距分布
function M.distributeObjects(objects, axis)
  if #objects < 3 then return end
  table.sort(objects, function(a, b)
    return (axis == "x" and a.x < b.x) or (axis == "y" and a.y < b.y)
  end)
  local start = objects[1][axis]
  local finish = objects[#objects][axis]
  local step = (finish - start) / (#objects - 1)
  for i = 2, #objects - 1 do
    objects[i][axis] = start + step * (i - 1)
  end
end

-- 颜色插值
function M.lerpColor(c1, c2, t)
  return {
    math.floor(c1[1] + (c2[1] - c1[1]) * t),
    math.floor(c1[2] + (c2[2] - c1[2]) * t),
    math.floor(c1[3] + (c2[3] - c1[3]) * t),
    math.floor((c1[4] or 255) + ((c2[4] or 255) - (c1[4] or 255)) * t),
  }
end

-- 格式化文件大小
function M.formatFileSize(bytes)
  if bytes < 1024 then return bytes .. " B"
  elseif bytes < 1024 * 1024 then return string.format("%.1f KB", bytes / 1024)
  elseif bytes < 1024 * 1024 * 1024 then return string.format("%.1f MB", bytes / 1024 / 1024)
  else return string.format("%.1f GB", bytes / 1024 / 1024 / 1024)
  end
end

return M
