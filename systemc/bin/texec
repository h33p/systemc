local args = { ... }
local name = args[1]
args[1] = ""
local tArgs = ""
for k, v in pairs(args) do
  tArgs = tArgs.." "..v
end
local tEnv = {}
setmetatable(tEnv, {__index = _G})
res, err = loadstring(tArgs, name)
if res then
  tEnv._ENV = tEnv
  setfenv(res, tEnv)
  res()
else
  error(err)
end
