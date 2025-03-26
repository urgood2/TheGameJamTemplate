-- The default initialization script for entities. It is called when an entity is created and has no other initialization script.
-- There can be multiple initialization files in this directory. Just make sure they have the right table name
-- from scripting_config.json and they will be loaded in automatically.
-- The name of the function should match the name of the string identifier for whatever entity type this is.

init_blackboard = {}

function init_blackboard.default(entity) -- default initialization script for entities. "default" should be replaced with the string identifier for the entity type.
    setBlackboardString(entity, "Name", "Mysterious Bob")
end
