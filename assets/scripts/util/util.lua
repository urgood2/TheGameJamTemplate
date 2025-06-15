-- Recursively prints any table (with cycle detection)
function print_table(tbl, indent, seen)
    indent = indent or ""                 -- current indentation
    seen   = seen   or {}                 -- tables we’ve already visited
  
    if seen[tbl] then
      print(indent .. "*<recursion>–")    -- cycle detected
      return
    end
    seen[tbl] = true
  
    -- iterate all entries
    for k, v in pairs(tbl) do
      local key = type(k) == "string" and ("%q"):format(k) or tostring(k)
      if type(v) == "table" then
        print(indent .. "["..key.."] = {")
        print_table(v, indent.."  ", seen)
        print(indent .. "}")
      else
        -- primitive: just tostring it
        print(indent .. "["..key.."] = " .. tostring(v))
      end
    end
  end
  
  -- convenience wrapper
  function dump(t)
    assert(type(t) == "table", "dump expects a table")
    print_table(t)
  end

-- somewhere in your init.lua, before loading ai.entity_types…
function deep_copy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    copy = {}
    for k,v in pairs(orig) do
      copy[deep_copy(k)] = deep_copy(v)
    end
    setmetatable(copy, deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end