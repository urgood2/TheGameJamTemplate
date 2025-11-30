-- Minimal message queue for tests/debug output
local MessageQueue = {}

local queue = {}

function MessageQueue.push(kind, payload)
    table.insert(queue, { kind = kind, payload = payload })
end

function MessageQueue.get()
    return queue
end

function MessageQueue.clear()
    queue = {}
end

function MessageQueue.dump()
    for i, msg in ipairs(queue) do
        local kind = msg.kind or "unknown"
        if type(msg.payload) == "table" then
            -- shallow serialize for readability
            local parts = {}
            for k, v in pairs(msg.payload) do
                table.insert(parts, string.format("%s=%s", tostring(k), tostring(v)))
            end
            print(string.format("[MSG %d] %s {%s}", i, kind, table.concat(parts, ", ")))
        else
            print(string.format("[MSG %d] %s %s", i, kind, tostring(msg.payload)))
        end
    end
    MessageQueue.clear()
end

return MessageQueue
