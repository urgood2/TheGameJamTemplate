-- Modified by Chugget
-- Deprecated!!!!!
-- Additional docs: https://hump.readthedocs.io/en/latest/camera.html

--[[
Copyright (c) 2010-2015 Matthias Richter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

local cos, sin = math.cos, math.sin

-- Fetch the raw Sol2-bound Camera2D userdata from C++
local function get_raw_camera()
  if not globals.camera then
    error("Camera2D binding missing: call globals.camera = <your Camera2D> in C++ before using")
  end
  local cam = globals.camera()
  if not cam then
    error("globals.camera() returned nil; ensure Camera2D is initialized in C++ before using Lua camera module")
  end
  return cam
end

-- Movement interpolators for smooth transitions
local smooth = {}

function smooth.none()
  return function(dx, dy) return dx, dy end
end

function smooth.linear(speed)
  assert(type(speed) == "number", "Invalid parameter: speed = "..tostring(speed))
  return function(dx, dy, s)
    local dist = math.sqrt(dx*dx + dy*dy)
    local delta = math.min((s or speed) * GetFrameTime(), dist)
    if dist > 0 then dx, dy = dx/dist, dy/dist end
    return dx * delta, dy * delta
  end
end

function smooth.damped(stiffness)
  assert(type(stiffness) == "number", "Invalid parameter: stiffness = "..tostring(stiffness))
  return function(dx, dy, s)
    local dt = GetFrameTime() * (s or stiffness)
    return dx * dt, dy * dt
  end
end

-- Table of instance methods; will be set as proxy metatable
local methods = {}

-- Begin scissor and camera transform
function methods:attach(x, y, w, h, noclip)
  local cam2d = self.raw
  x, y = x or 0, y or 0
  w, h = w or GetScreenWidth(), h or GetScreenHeight()
  if not noclip then BeginScissorMode(x, y, w, h) end
  cam2d.offset.x = w/2 + x
  cam2d.offset.y = h/2 + y
  BeginMode2D(cam2d)
end

-- End camera transform and optional scissor cleanup
function methods:detach(noclip)
  EndMode2D()
  if not noclip then EndScissorMode() end
end

-- Convenience draw wrapper: cam:draw(func) or cam:draw(x,y,w,h,func) or cam:draw(x,y,w,h,noclip,func)
function methods:draw(...)
  local nargs = select('#', ...)
  local func, x, y, w, h, noclip
  if nargs == 1 then
    func = ...
  elseif nargs == 5 then
    x,y,w,h,func = ...
  elseif nargs == 6 then
    x,y,w,h,noclip,func = ...
  else
    error("Invalid args to camera:draw()")
  end
  methods.attach(self, x, y, w, h, noclip)
  func()
  methods.detach(self, noclip)
end

-- Transform world coords to screen coords
function methods:cameraCoords(x, y, ox, oy, w, h)
  local cam2d = self.raw
  ox, oy = ox or 0, oy or 0
  w, h   = w or GetScreenWidth(), h or GetScreenHeight()
  local scr = GetWorldToScreen2D({ x=x, y=y }, cam2d)
  return scr.x + ox, scr.y + oy
end

-- Transform screen coords to world coords
function methods:worldCoords(x, y, ox, oy)
  local cam2d = self.raw
  ox, oy = ox or 0, oy or 0
  local wo = GetScreenToWorld2D({ x=x, y=y }, cam2d)
  return wo.x - ox, wo.y - oy
end

-- Get mouse position in world-space
function methods:mousePosition(ox, oy)
  local cam2d = self.raw
  ox, oy = ox or 0, oy or 0
  local mp = GetMousePosition()
  local wo = GetScreenToWorld2D(mp, cam2d)
  return wo.x - ox, wo.y - oy
end

-- Center camera on world point
function methods:lookAt(x, y)
  local cam2d = self.raw
  cam2d.target.x, cam2d.target.y = x, y
  return self
end

-- Pan camera by dx, dy
function methods:move(dx, dy)
  local cam2d = self.raw
  cam2d.target.x = cam2d.target.x + dx
  cam2d.target.y = cam2d.target.y + dy
  return self
end

-- Retrieve camera target position
function methods:position()
  local cam2d = self.raw
  return cam2d.target.x, cam2d.target.y
end

-- Rotate camera by phi radians
function methods:rotate(phi)
  local cam2d = self.raw
  cam2d.rotation = cam2d.rotation + (phi * 180/math.pi)
  return self
end

-- Set absolute rotation in radians
function methods:rotateTo(phi)
  local cam2d = self.raw
  cam2d.rotation = phi * (180/math.pi)
  return self
end

-- Zoom multiply by factor
function methods:zoom(f)
  local cam2d = self.raw
  cam2d.zoom = cam2d.zoom * f
  return self
end

-- Set absolute zoom
function methods:zoomTo(z)
  local cam2d = self.raw
  cam2d.zoom = z
  return self
end

-- Smoothly lock X coordinate
function methods:lockX(x, smoother, ...)
  local dx, _ = (smoother or self.smoother)(x - self.raw.target.x, 0, ...)
  self.raw.target.x = self.raw.target.x + dx
  return self
end

-- Smoothly lock Y coordinate
function methods:lockY(y, smoother, ...)
  local _, dy = (smoother or self.smoother)(0, y - self.raw.target.y, ...)
  self.raw.target.y = self.raw.target.y + dy
  return self
end

-- Smoothly lock both X and Y
function methods:lockPosition(x, y, smoother, ...)
  local dx, dy = (smoother or self.smoother)(x - self.raw.target.x, y - self.raw.target.y, ...)
  return methods.move(self, dx, dy)
end

-- Ensure a world point stays within a screen window
function methods:lockWindow(x, y, x_min, x_max, y_min, y_max, smoother, ...)
  local cam2d = self.raw
  local scr = GetWorldToScreen2D({ x=x, y=y }, cam2d)
  local dx, dy = 0, 0
  if scr.x < x_min then dx = scr.x - x_min
  elseif scr.x > x_max then dx = scr.x - x_max end
  if scr.y < y_min then dy = scr.y - y_min
  elseif scr.y > y_max then dy = scr.y - y_max end
  local rad = -cam2d.rotation * (math.pi/180)
  local c, s = cos(rad), sin(rad)
  dx, dy = (c*dx - s*dy)/cam2d.zoom, (s*dx + c*dy)/cam2d.zoom
  local mx, my = (smoother or self.smoother)(dx, dy, ...)
  return methods.move(self, mx, my)
end

-- Constructor: wrap the raw Camera2D in a proxy with only smoother in proxy
local function new(x, y, zoom, rot, smoother)
  local cam2d = get_raw_camera()
  -- initialize raw camera fields directly
  cam2d.target = cam2d.target or { x = 0, y = 0 }
  cam2d.offset = cam2d.offset or { x = 0, y = 0 }
  cam2d.target.x = x or GetScreenWidth()/2
  cam2d.target.y = y or GetScreenHeight()/2
  cam2d.offset.x = GetScreenWidth()/2
  cam2d.offset.y = GetScreenHeight()/2
  cam2d.rotation = (rot or 0) * (180/math.pi)
  cam2d.zoom     = zoom or 1
  -- build proxy that holds only 'smoother' alongside raw
  local proxy = { raw = cam2d, smoother = smoother or smooth.none() }
  return setmetatable(proxy, { __index = methods })
end

-- Module exports: constructor and smoothing utilities
return setmetatable({ new = new, smooth = smooth },
  { __call = function(_, ...) return new(...) end })
