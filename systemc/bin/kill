
local tArgs = { ... }

local signal = 15
local pid = -1

local argAdd = 1

for k, v in pairs(tArgs) do
	if string.sub(v, 1, 1) == "-" and string.len(v) > 1 then
		argAdd = argAdd + 1
		if string.sub(v, 2, 2) == "9" then
			signal = 9
		end
	end
end

pid = tonumber(tArgs[argAdd])

ok, err = systemc.kill(pid, signal)

if not ok then
	error(err)
end

