-- reporters/tap.lua
-- TAP format writer

local M = {}

local function coalesce(...)
  for i = 1, select('#', ...) do
    local value = select(i, ...)
    if value ~= nil and value ~= '' then
      return value
    end
  end
  return nil
end

local function sanitize(text)
  local value = tostring(text or '')
  value = value:gsub('\r', ' ')
  value = value:gsub('\n', ' ')
  value = value:gsub('\t', ' ')
  value = value:gsub('#', '\\#')
  return value
end

local function append(lines, line)
  lines[#lines + 1] = line
end

local function add_diagnostics(lines, message, failure_kind)
  if not message and not failure_kind then
    return
  end

  append(lines, '  ---')
  if failure_kind then
    append(lines, '  failure_kind: ' .. sanitize(failure_kind))
  end
  if message then
    append(lines, '  message: |')
    for line in tostring(message):gmatch('[^\r\n]+') do
      append(lines, '    ' .. line)
    end
  end
  append(lines, '  ...')
end

function M.render(report)
  local lines = {}
  append(lines, 'TAP version 14')

  local tests = (report and report.tests) or {}
  local total = #tests
  append(lines, '1..' .. tostring(total))

  local index = 0
  for _, test in ipairs(tests) do
    index = index + 1
    local name = sanitize(coalesce(test.name, test.id, 'test_' .. tostring(index)))
    local status = tostring(test.status or 'fail'):lower()
    local ok = status == 'pass' or status == 'skipped' or status == 'xpass' or status == 'quarantined'

    local directive = ''
    local reason = coalesce(test.reason, test.skip_reason, test.todo_reason, test.message, test.failure_kind)
    if status == 'skipped' or status == 'quarantined' then
      directive = ' # SKIP'
      if reason then
        directive = directive .. ' ' .. sanitize(reason)
      end
    elseif status == 'xfail' or status == 'flaky' or status == 'xpass' then
      directive = ' # TODO'
      if reason then
        directive = directive .. ' ' .. sanitize(reason)
      end
    end

    local prefix = ok and 'ok ' or 'not ok '
    append(lines, prefix .. tostring(index) .. ' - ' .. name .. directive)

    if not ok then
      local message = coalesce(test.message, test.error, test.failure_message, test.failure)
      add_diagnostics(lines, message, test.failure_kind)
    end
  end

  return table.concat(lines, '\n') .. '\n'
end

function M.write(report, path)
  local output = M.render(report)
  if not path or path == '' then
    return output
  end

  local file, err = io.open(path, 'w')
  if not file then
    return false, err
  end

  file:write(output)
  file:close()
  return true
end

return M
