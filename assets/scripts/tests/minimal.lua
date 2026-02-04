local harness = rawget(_G, "test_harness")
if not harness then
  error("test_harness missing")
end

print("minimal test start")
if type(harness.wait_frames) == "function" then
  harness.wait_frames(1)
end
print("minimal test exit")
if type(harness.exit) == "function" then
  harness.exit(0)
end

return true
