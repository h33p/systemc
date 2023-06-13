

local tArgs = { ... }

if systemc == nil then
	error("SystemC not running")
end

if tArgs[1] == "status" then
	if string.match(tArgs[2], ".") == "." then
		name, utype = tArgs[2]:match("([^.]+).([^.]+)")
	else
		utype = "service"
		name = tArgs[2]
	end
	if utype == "service" then
		print(" *", tostring(name)..".service -", systemc.services[name].description)
		print("    Loaded: ("..name..".service,",tostring(systemc.services[name].enabled)..")")  
		print("    Active:", systemc.services[name].status)
	end
elseif tArgs[1] == "start" then
	systemc.start_unit(tArgs[2])
elseif tArgs[1] == "stop" then
	systemc.stop_unit(tArgs[2])
elseif tArgs[1] == "enable" then
	systemc.enable_unit(tArgs[2])
elseif tArgs[1] == "disable" then
	systemc.disable_unit(tArgs[2])
elseif tArgs[1] == "daemon-reload" then
	systemc.reload_daemon (true)
else
	error("Unknown operation "..tArgs[1]..".")
end

