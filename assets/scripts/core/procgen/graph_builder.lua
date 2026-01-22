-- assets/scripts/core/procgen/graph_builder.lua
-- Fluent builder pattern for Graph operations
--
-- Usage:
--   local GraphBuilder = require("core.procgen.graph_builder")
--   local graph = GraphBuilder.new()
--     :node("start", {type = "room", x = 0, y = 0})
--     :node("boss", {type = "room", x = 100, y = 100})
--     :edge("start", "boss")
--     :build()

local vendor = require("core.procgen.vendor")
local Graph = vendor.Graph

local GraphBuilder = {}
GraphBuilder.__index = GraphBuilder

--- Create a new GraphBuilder
-- @return GraphBuilder
function GraphBuilder.new()
    local self = setmetatable({}, GraphBuilder)
    self._graph = Graph()
    self._nodes = {}  -- Maps string IDs to node objects
    return self
end

--- Add a node to the graph
-- @param id string Unique identifier for the node
-- @param data table? Optional data to attach to node
-- @return GraphBuilder self for chaining
function GraphBuilder:node(id, data)
    local nodeObj
    if data then
        nodeObj = data
        nodeObj._id = id
    else
        nodeObj = {_id = id}
    end
    self._nodes[id] = nodeObj
    self._graph:add_node(nodeObj)
    return self
end

--- Add an edge between two nodes
-- Note: Silently ignores if either node doesn't exist. Call node() first.
-- @param id1 string First node ID
-- @param id2 string Second node ID
-- @return GraphBuilder self for chaining
function GraphBuilder:edge(id1, id2)
    local node1 = self._nodes[id1]
    local node2 = self._nodes[id2]
    if node1 and node2 then
        self._graph:add_edge(node1, node2)
    else
        -- Warn in debug mode about missing nodes
        if _G.DEBUG_PROCGEN then
            if not node1 then
                print("[GraphBuilder] Warning: edge() - node '" .. tostring(id1) .. "' not found")
            end
            if not node2 then
                print("[GraphBuilder] Warning: edge() - node '" .. tostring(id2) .. "' not found")
            end
        end
    end
    return self
end

--- Build and return the final Graph instance
-- @return Graph The constructed graph
function GraphBuilder:build()
    return self._graph
end

--- Find shortest path between two nodes by ID
-- @param fromId string Starting node ID
-- @param toId string Target node ID
-- @return table Array of node objects in path
function GraphBuilder:shortestPath(fromId, toId)
    local fromNode = self._nodes[fromId]
    local toNode = self._nodes[toId]
    if fromNode and toNode then
        return self._graph:shortest_path_bfs(fromNode, toNode)
    end
    return {}
end

--- Get neighbors of a node by ID
-- @param id string Node ID
-- @return table Array of neighbor node objects
function GraphBuilder:neighbors(id)
    local node = self._nodes[id]
    if node then
        return self._graph:get_node_neighbors(node) or {}
    end
    return {}
end

--- Get node by ID
-- @param id string Node ID
-- @return table Node object or nil
function GraphBuilder:getNode(id)
    return self._nodes[id]
end

--- Reset the builder for reuse
-- @return GraphBuilder self for chaining
function GraphBuilder:reset()
    self._graph = Graph()
    self._nodes = {}
    return self
end

return GraphBuilder
