local tArgs = {...}

print("Sudo. Currently no authentication is present. All users can run.")

local target_uid = tArgs[1]
--local old_uid = systemc.process.uid
local pArgs = {}

local i = 2
while i <= #tArgs do
	pArgs[i-1] = tArgs[i]
	i = i + 1
end

ok = pcall(function () systemc.setuid(target_uid) end)

if not ok then
	error("Seems that setuid is not allowed on this program. Please set the permission by running fs.setPerms(\""..fs.combine(systemc.binDir, "sudo").."\", {psuid = true}) in lua program")
end

shell.run(unpack(pArgs))
