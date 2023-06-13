local tArgs = { ... }

local nu = tonumber(string.match(tArgs[1], "([^=]+):"))
local ng = tonumber(string.match(tArgs[1], ":([^=]+)"))

local perms = {}
if nu ~= nil then print(nu) perms.owner = nu end
if ng ~= nil then perms.group = ng end

local i = 2
while i <= #tArgs do
	if string.sub(tArgs[i], 1, 1) ~= "/" then tArgs[i] = fs.combine(shell.dir(), tArgs[i]) end
	print(tArgs[i])
	fs.setPerms(tArgs[i], perms)
	i = i + 1
end
