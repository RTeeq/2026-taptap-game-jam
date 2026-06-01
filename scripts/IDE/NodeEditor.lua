-- ============================================================
-- IDE/NodeEditor.lua
-- 可视化节点编辑器：节点管理、连接、序列化、Lua编译器
-- ============================================================
local Config = require("IDE.Config")
local EventBus = require("IDE.EventBus")
local UndoManager = require("IDE.UndoManager")

local NodeEditor = {}

-- 节点类型定义
NodeEditor.NODE_TYPES = {
    Event_Start = {
        category = "事件", color = Config.NODE_COLORS.event,
        inputs = {},
        outputs = {{name = "执行", type = "exec"}},
        props = {},
    },
    Event_Tick = {
        category = "事件", color = Config.NODE_COLORS.event,
        inputs = {},
        outputs = {{name = "执行", type = "exec"}, {name = "dt", type = "number"}},
        props = {},
    },
    Event_KeyPress = {
        category = "事件", color = Config.NODE_COLORS.event,
        inputs = {},
        outputs = {{name = "执行", type = "exec"}},
        props = {{name = "按键", type = "string", default = "Space"}},
    },
    Action_Log = {
        category = "动作", color = Config.NODE_COLORS.action,
        inputs = {{name = "执行", type = "exec"}, {name = "内容", type = "string"}},
        outputs = {{name = "执行", type = "exec"}},
        props = {{name = "文本", type = "string", default = "Hello"}},
    },
    Action_CreateUnit = {
        category = "动作", color = Config.NODE_COLORS.action,
        inputs = {{name = "执行", type = "exec"}, {name = "类型", type = "string"}, {name = "X", type = "number"}, {name = "Y", type = "number"}},
        outputs = {{name = "执行", type = "exec"}, {name = "单位", type = "any"}},
        props = {},
    },
    Action_SetPos = {
        category = "动作", color = Config.NODE_COLORS.action,
        inputs = {{name = "执行", type = "exec"}, {name = "对象", type = "any"}, {name = "X", type = "number"}, {name = "Y", type = "number"}},
        outputs = {{name = "执行", type = "exec"}},
        props = {},
    },
    Action_PlaySound = {
        category = "动作", color = Config.NODE_COLORS.action,
        inputs = {{name = "执行", type = "exec"}, {name = "路径", type = "string"}},
        outputs = {{name = "执行", type = "exec"}},
        props = {{name = "音效", type = "string", default = "sfx.ogg"}},
    },
    Condition_If = {
        category = "条件", color = Config.NODE_COLORS.condition,
        inputs = {{name = "执行", type = "exec"}, {name = "条件", type = "boolean"}},
        outputs = {{name = "True", type = "exec"}, {name = "False", type = "exec"}},
        props = {},
    },
    Condition_Compare = {
        category = "条件", color = Config.NODE_COLORS.condition,
        inputs = {{name = "A", type = "number"}, {name = "B", type = "number"}},
        outputs = {{name = "结果", type = "boolean"}},
        props = {{name = "比较", type = "string", default = "=="}},
    },
    Math_Add = {
        category = "数学", color = Config.NODE_COLORS.math,
        inputs = {{name = "A", type = "number"}, {name = "B", type = "number"}},
        outputs = {{name = "结果", type = "number"}},
        props = {},
    },
    Math_Sub = {
        category = "数学", color = Config.NODE_COLORS.math,
        inputs = {{name = "A", type = "number"}, {name = "B", type = "number"}},
        outputs = {{name = "结果", type = "number"}},
        props = {},
    },
    Math_Mul = {
        category = "数学", color = Config.NODE_COLORS.math,
        inputs = {{name = "A", type = "number"}, {name = "B", type = "number"}},
        outputs = {{name = "结果", type = "number"}},
        props = {},
    },
    Math_Random = {
        category = "数学", color = Config.NODE_COLORS.math,
        inputs = {{name = "最小", type = "number"}, {name = "最大", type = "number"}},
        outputs = {{name = "结果", type = "number"}},
        props = {},
    },
    Variable_Get = {
        category = "变量", color = Config.NODE_COLORS.variable,
        inputs = {},
        outputs = {{name = "值", type = "any"}},
        props = {{name = "变量名", type = "string", default = "score"}},
    },
    Variable_Set = {
        category = "变量", color = Config.NODE_COLORS.variable,
        inputs = {{name = "执行", type = "exec"}, {name = "值", type = "any"}},
        outputs = {{name = "执行", type = "exec"}},
        props = {{name = "变量名", type = "string", default = "score"}},
    },
    Input_GetAxis = {
        category = "输入", color = Config.NODE_COLORS.input,
        inputs = {},
        outputs = {{name = "X", type = "number"}, {name = "Y", type = "number"}},
        props = {},
    },
}

NodeEditor._data = {nodes = {}, connections = {}, variables = {}, nextId = 1, selectedNodeId = nil}

function NodeEditor:init()
    self._data = {nodes = {}, connections = {}, variables = {}, nextId = 1, selectedNodeId = nil}
end

function NodeEditor:createNode(typeName, x, y)
    local def = self.NODE_TYPES[typeName]
    if not def then
        print("[NodeEditor] 未知节点类型: " .. tostring(typeName))
        return nil
    end
    local id = self._data.nextId
    self._data.nextId = id + 1
    local node = {
        id = id,
        type = typeName,
        x = x or 100,
        y = y or 100,
        w = 160,
        h = 40 + math.max(#def.inputs, #def.outputs) * 24,
        inputs = {},
        outputs = {},
        props = {},
    }
    for i, inp in ipairs(def.inputs) do
        node.inputs[i] = {name = inp.name, type = inp.type, value = nil, connected = false}
    end
    for i, out in ipairs(def.outputs) do
        node.outputs[i] = {name = out.name, type = out.type}
    end
    for _, p in ipairs(def.props) do
        node.props[p.name] = p.default
    end
    self._data.nodes[id] = node
    UndoManager:record("create_node", {node = Config.deepcopy(node)})
    EventBus:emit("node.created", node)
    return node
end

function NodeEditor:deleteNode(id)
    if not self._data.nodes[id] then return false end
    UndoManager:record("delete_node", {node = Config.deepcopy(self._data.nodes[id])})
    -- 移除关联连接
    local newConns = {}
    for _, c in ipairs(self._data.connections) do
        if c.fromId ~= id and c.toId ~= id then
            table.insert(newConns, c)
        end
    end
    self._data.connections = newConns
    self._data.nodes[id] = nil
    if self._data.selectedNodeId == id then
        self._data.selectedNodeId = nil
    end
    EventBus:emit("node.deleted", id)
    return true
end

function NodeEditor:connect(fromId, fromPort, toId, toPort)
    local fromNode = self._data.nodes[fromId]
    local toNode = self._data.nodes[toId]
    if not fromNode or not toNode then return false end
    if not fromNode.outputs[fromPort] or not toNode.inputs[toPort] then return false end
    -- 类型检查
    local fromType = fromNode.outputs[fromPort].type
    local toType = toNode.inputs[toPort].type
    if fromType ~= toType and fromType ~= "any" and toType ~= "any" and fromType ~= "exec" then
        return false
    end
    -- 移除目标端口旧连接
    local newConns = {}
    for _, c in ipairs(self._data.connections) do
        if not (c.toId == toId and c.toPort == toPort) then
            table.insert(newConns, c)
        end
    end
    table.insert(newConns, {fromId = fromId, fromPort = fromPort, toId = toId, toPort = toPort})
    self._data.connections = newConns
    toNode.inputs[toPort].connected = true
    UndoManager:record("connect", {fromId = fromId, fromPort = fromPort, toId = toId, toPort = toPort})
    EventBus:emit("node.connected", fromId, toId)
    return true
end

function NodeEditor:selectNode(id)
    self._data.selectedNodeId = id
end

function NodeEditor:getSelectedNode()
    if self._data.selectedNodeId then
        return self._data.nodes[self._data.selectedNodeId]
    end
    return nil
end

function NodeEditor:getAllNodes()
    local list = {}
    for _, node in pairs(self._data.nodes) do
        table.insert(list, node)
    end
    return list
end

function NodeEditor:getConnections()
    return self._data.connections
end

function NodeEditor:getNodeCount()
    local count = 0
    for _ in pairs(self._data.nodes) do count = count + 1 end
    return count
end

-- 点击测试
function NodeEditor:hitTestNode(px, py)
    for _, node in pairs(self._data.nodes) do
        if Config.pointInRect(px, py, node.x, node.y, node.w, node.h) then
            return node
        end
    end
    return nil
end

-- 序列化
function NodeEditor:serialize()
    return {
        version = Config.VERSION,
        nodes = Config.deepcopy(self._data.nodes),
        connections = Config.deepcopy(self._data.connections),
        variables = Config.deepcopy(self._data.variables),
        nextId = self._data.nextId,
    }
end

function NodeEditor:deserialize(data)
    if not data then return false end
    self._data.nodes = data.nodes or {}
    self._data.connections = data.connections or {}
    self._data.variables = data.variables or {}
    self._data.nextId = data.nextId or 1
    self._data.selectedNodeId = nil
    EventBus:emit("node.loaded")
    return true
end

-- ============================================
-- 编译器：节点图 → Lua代码
-- ============================================
function NodeEditor:compileToLua()
    local code = {}
    table.insert(code, "-- ============================================")
    table.insert(code, "-- 由 Visual2D IDE 节点编辑器自动生成")
    table.insert(code, "-- ============================================")
    table.insert(code, "")

    -- 变量声明
    local vars = {}
    for _, node in pairs(self._data.nodes) do
        if node.type == "Variable_Set" or node.type == "Variable_Get" then
            local varName = node.props["变量名"] or "temp"
            vars[varName] = true
        end
    end
    if next(vars) then
        table.insert(code, "-- 变量")
        for name, _ in pairs(vars) do
            table.insert(code, string.format("local var_%s = 0", name))
        end
        table.insert(code, "")
    end

    -- 查找事件节点作为入口
    local eventNodes = {}
    for _, node in pairs(self._data.nodes) do
        if node.type:sub(1, 6) == "Event_" then
            table.insert(eventNodes, node)
        end
    end

    for _, eventNode in ipairs(eventNodes) do
        self:_compileEventHandler(eventNode, code)
    end

    return table.concat(code, "\n")
end

function NodeEditor:_compileEventHandler(node, code)
    if node.type == "Event_Start" then
        table.insert(code, "-- 游戏开始")
        table.insert(code, "function OnGameStart()")
        self:_compileNodeChain(node, 1, code, 1)
        table.insert(code, "end")
    elseif node.type == "Event_Tick" then
        table.insert(code, "-- 每帧更新")
        table.insert(code, "function OnUpdate(dt)")
        self:_compileNodeChain(node, 1, code, 1)
        table.insert(code, "end")
    elseif node.type == "Event_KeyPress" then
        local key = node.props["按键"] or "Space"
        table.insert(code, string.format("-- 按键: %s", key))
        table.insert(code, string.format('function OnKeyPress_%s()', key))
        self:_compileNodeChain(node, 1, code, 1)
        table.insert(code, "end")
    end
    table.insert(code, "")
end

function NodeEditor:_compileNodeChain(fromNode, fromPort, code, indent)
    local prefix = string.rep("    ", indent)
    for _, conn in ipairs(self._data.connections) do
        if conn.fromId == fromNode.id and conn.fromPort == fromPort then
            local nextNode = self._data.nodes[conn.toId]
            if nextNode then
                self:_compileNodeBody(nextNode, code, indent)
            end
        end
    end
end

function NodeEditor:_compileNodeBody(node, code, indent)
    local prefix = string.rep("    ", indent)
    if node.type == "Action_Log" then
        local text = node.props["文本"] or "Hello"
        table.insert(code, prefix .. string.format('print("%s")', text))
        self:_compileNodeChain(node, 1, code, indent)
    elseif node.type == "Action_CreateUnit" then
        local varName = "unit_" .. node.id
        table.insert(code, prefix .. string.format('local %s = createUnit("sprite", 0, 0)', varName))
        self:_compileNodeChain(node, 1, code, indent)
    elseif node.type == "Action_SetPos" then
        table.insert(code, prefix .. '-- setPosition(obj, x, y)')
        self:_compileNodeChain(node, 1, code, indent)
    elseif node.type == "Action_PlaySound" then
        local sfx = node.props["音效"] or "sfx.ogg"
        table.insert(code, prefix .. string.format('playSound("%s")', sfx))
        self:_compileNodeChain(node, 1, code, indent)
    elseif node.type == "Condition_If" then
        table.insert(code, prefix .. "if condition then")
        self:_compileNodeChain(node, 1, code, indent + 1)
        table.insert(code, prefix .. "else")
        self:_compileNodeChain(node, 2, code, indent + 1)
        table.insert(code, prefix .. "end")
    elseif node.type == "Variable_Set" then
        local varName = node.props["变量名"] or "temp"
        table.insert(code, prefix .. string.format('var_%s = value', varName))
        self:_compileNodeChain(node, 1, code, indent)
    end
end

-- 通过id获取节点
function NodeEditor:getNodeById(id)
    return self._data.nodes[id]
end

-- 端口点击测试
function NodeEditor:hitTestPort(px, py)
    local PORT_RADIUS = 8
    local PORT_SPACING = 24
    for _, node in pairs(self._data.nodes) do
        -- 检测输入端口
        if node.inputs then
            for i, _ in ipairs(node.inputs) do
                local portX = node.x
                local portY = node.y + 30 + (i - 1) * PORT_SPACING
                local dx = px - portX
                local dy = py - portY
                if dx * dx + dy * dy <= PORT_RADIUS * PORT_RADIUS then
                    return { nodeId = node.id, portIdx = i, isOutput = false }
                end
            end
        end
        -- 检测输出端口
        if node.outputs then
            for i, _ in ipairs(node.outputs) do
                local portX = node.x + (node.w or 160)
                local portY = node.y + 30 + (i - 1) * PORT_SPACING
                local dx = px - portX
                local dy = py - portY
                if dx * dx + dy * dy <= PORT_RADIUS * PORT_RADIUS then
                    return { nodeId = node.id, portIdx = i, isOutput = true }
                end
            end
        end
    end
    return nil
end

-- 获取节点类型分类
function NodeEditor:getCategories()
    local cats = {}
    for typeName, def in pairs(self.NODE_TYPES) do
        local cat = def.category or "其他"
        if not cats[cat] then cats[cat] = {} end
        table.insert(cats[cat], typeName)
    end
    return cats
end

return NodeEditor
