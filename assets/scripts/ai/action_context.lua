local ActionContext = {}
ActionContext.__index = ActionContext

function ActionContext.new(entity)
    local self = setmetatable({}, ActionContext)
    self.entity = entity
    self.blackboard = ai.get_blackboard(entity)
    self.dt = 0
    return self
end

function ActionContext:get_target()
    if self.blackboard:contains("target_entity") then
        return self.blackboard:get_int("target_entity")
    end
    return nil
end

return ActionContext
