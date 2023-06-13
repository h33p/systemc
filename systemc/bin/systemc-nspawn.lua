local tArgs = { ... }

if systemc == nil then
	error ("SystemC not loaded")
end

local biosPath = fs.combine(systemc.libDir, "systemc.d/bios.lua")
local scPath = "/"

if #tArgs < 1 then
	print("Usage: systemc-nspawn [options]")
	print("")
	print("Options:")
	print("-D directory to use. Must be specified")
	print("-c[c] prepare the container. With second c it gets cleared first")
	print("-nR do not copy ROM")
	print("-nS do not copy SystemC")
	print("-scP SystemC path inside the container. Default is /")
	print("-b invoke init instead of shell")
	print("-p bios.lua path. Default is "..biosPath)
	error("Invalid arguments")
end

local create = false
local boot = false
local noROM = false
local noSC = false
local targetPath = "/../"
local clean = false
for i, v in ipairs(tArgs) do
	if tArgs[i] == "-D" then
		targetPath = shell.resolve(tArgs[i+1])
	elseif tArgs[i] == "-scP" then
		scPath = tArgs[i]
	elseif tArgs[i] == "-c" then
		create = true
	elseif tArgs[i] == "-cc" then
		clean = true
		create = true
	elseif tArgs[i] == "-b" then
		boot = true
	elseif tArgs[i] == "-nR" then
		noROM = true
	elseif tArgs[i] == "-nS" then
		noSC = true
	elseif tArgs[i] == "-p" then
		biosPath = tArgs[i+1]
	end
end

if boot and not fs.exists(fs.combine(targetPath, fs.combine(scPath, "/bin/init.lua"))) then
	error("Boot specified, but no init found!")
end

if clean == true then
	if fs.exists(targetPath) then
		fs.delete(targetPath)
	end
end

if create == true then
	
	if fs.exists(targetPath) and not fs.isDir(targetPath) then
		error("Not a directory")
	end

	if not fs.exists(targetPath) then
		fs.makeDir(targetPath)
	end
	
	if noROM == false then
		fs.copy("/rom", targetPath.."/rom")
	end
	
	if noSC == false then
		fs.copy(systemc.binDir, fs.combine(fs.combine(targetPath, scPath), "/bin"))
		fs.copy(systemc.libDir, fs.combine(fs.combine(targetPath, scPath), "/lib"))
		fs.copy(systemc.etcDir, fs.combine(fs.combine(targetPath, scPath), "/etc"))
	end
	error("Exit")
end


if not fs.isDir(targetPath) then
	error("Target is not a directory or doesn't exist!")
end

local mounts = {}
local function getRealPath(s)
	local index = 1
	local array = {}
	for path in string.gmatch(s,"[^/\\]*[/\\]?") do
		path = string.gsub(path,"[/\\]","")
		if path == ".." then
			if index ~= 1 then
				index = index - 1
				array[index] = nil
			else
				return "/.." -- This should do the trick...
			end
		elseif path == "" then
			--Ignore empty pathes
		else
			array[index] = path
			index = index + 1
		end
	end

	local path = ""
	if #array == 0 then
		path = targetPath
	else
		for k,string in ipairs(array) do
			if path == "" then
				if mounts[string] then
					path = mounts[string]
				else
					path = targetPath.."/"..string
				end
			else
				path = path .. "/" .. string
			end
		end
	end

	return path
end
local function mount(point,target)
	mounts[point] = target
	-- print("mounting "..point.."->"..target)
end

local function typeCheck(o,...)
	local list = {...}
	local t = type(o)
	local lt = nil
	for k,v in ipairs(list) do
		if t == v then
			return
		end
		lt = v
	end
	error("bad argument: "..lt.." expected, got "..t)
end

local terminate = false
local reboot = true

--Not copied: _G, fs, os, getfenv, setfenv, load, loadstring
local copied = {"getmetatable","unpack","__inext","_VERSION","redstone","ipairs","term",
                "coroutine","pcall","math","assert","tonumber","rawequal","write","table",
                "pairs","collectgarbage","xpcall","error","rawget","type","rs","rawset",
                "string","setmetatable","select", "settings", "tostring","next","disk", "bit"}
--Not copied: reboot, shutdown
local osCopied = {"getComputerLabel","setComputerLabel","day","queueEvent","getComputerID","time","clock","computerID","startTimer","cancelTimer","setAlarm","cancelAlarm"}
local function sandboxFunction(func)
	local table = {}
	for k,value in ipairs(copied) do
		table[value] = _G[value]
	end
	if http then
		table.http = http
	end

	local new_os = {}
	for k,value in ipairs(osCopied) do
		new_os[value] = os[value]
	end
	new_os.shutdown = function(...)	
		terminate = true
		error(1)
		while true do
			coroutine.yield()
		end
	end
	new_os.reboot = function(...)
		terminate = true
		reboot = true
		while true do
			coroutine.yield()
		end
	end
	table.os = new_os

	local new_fs = {}
	local function fsWrap(name,f,n)
		return function(...)
			local args = { ... }
			for k,v in ipairs(args) do
				if n == nil or k <= n then
					args[k] = getRealPath(v)
				end
			end
			return f(unpack(args))
		end
	end
	for k,v in pairs(fs) do
		new_fs[k] = fsWrap(k,v,nil)
	end
	new_fs.open = fsWrap("open",fs.open,1)
	new_fs.combine = fs.combine
	new_fs.complete = fsWrap("complete", fs.complete, nil)
	new_fs.list = fsWrap("list",function(f,...)
		if f == targetPath then
			local has = {}
			for k,v in ipairs(fs.list(f)) do
				has[v] = true
			end
			for k,v in pairs(mounts) do
				has[k] = true
			end
			local new = {}
			local i = 1
			for k,v in pairs(has) do
				if v then 
					new[i] = k
					i = i + 1
				end
			end
			return new
		else
			return fs.list(f)
		end
	end,nil)
	new_fs.find = fsWrap("find",function(inp)
		local output = fs.find(inp)
		for k,v in pairs(output) do
			v = fs.combine("", v)
			output[k] = fs.combine("",string.sub(v, #fs.combine("", targetPath) + 2, #v))
		end
		return output
	end,nil)
	table.fs = new_fs

	local chroot = {}
	if boot then
		chroot.init = fs.combine(scPath, fs.combine(scPath, "/bin/init.lua"))
	end
	chroot.rednet = rednet
	chroot.peripheral = peripheral
	table.__chroot = chroot

	local original = {}
	local safe_env = {}

	table.getfenv = function(f)
		if f == nil then f = 1 end
		typeCheck(f, "function", "number")
		local t = type(f)

		local env = nil
		if t == "function" then
			env = getfenv(f)
		elseif t == "number" then
			if f == 0 then
				return table
			elseif f < 0 then
				error("bad argument #1: level must be non-negative")
			else
				f = f + 1
				env = getfenv(f)
			end
		else
			error("unexpected code path reached!!")
		end

		if safe_env[env] then
			return env
		else
			return table
		end
	end
	table.setfenv = function(f,e)
		typeCheck(f, "function", "number")
		typeCheck(e, "table")

		local t = type(f)
		if t == "function" then
			-- Ignore
		elseif t == "number" then
			if f == 0 then
				error("'setfenv' cannot change environment of given object")
			elseif f < 0 then
				error("bad argument #1: level must be non-negative")
			else
				f = f + 1
			end
		else
			error("unexpected code path reached!!")
		end
		
		if safe_env[getfenv(f)] then
			safe_env[e] = true
			return setfenv(f,e)
		else
			error("'setfenv' cannot change environment of given object")
		end
	end
	safe_env[table] = true

	table.load = function(f,n)
		local fun = load(f,n)
		if fun then
			setfenv(fun,table)
		end
		return fun
	end
	table.loadstring = function(f,n)
		local fun = loadstring(f,n)
		if fun then
			setfenv(fun,table)
		end
		return fun
	end

	-- Debug functions

	-- table.dir = function(l) 
	-- 	for k,v in pairs(l) do
	-- 		write(k.." ")
	-- 	end
	-- 	print("")
	-- end
	-- table.dump = function(l) 
	-- 	for k,v in ipairs(l) do
	-- 		write(v.." ")
	-- 	end
	-- 	print("")
	-- end

	local lookup_table = {}
	local function protect(object)
		original[object] = true
		if lookup_table[object] then
			return lookup_table[object]
		elseif type(object) == "table" then
			local new_table = {}
			lookup_table[object] = new_table
			for index, value in pairs(object) do
				new_table[protect(index)] = protect(value)
			end
			return new_table
		else
			return object
		end
	end

	local copyKeys = {}
	local index = 1
	for k,v in pairs(table) do
		copyKeys[index] = k
		index = index + 1
	end
	for k,v in ipairs(copyKeys) do
		local value = table[v]
		table[v] = nil
		table[protect(v)] = protect(value)
	end

	table._G = table

	setfenv(func, table)
	return func
end

local sides = {"front","back","left","right","top","bottom"}

for k,side in ipairs(sides) do
	-- rednet.close(side)
	if disk.isPresent(side) then
		local path = disk.getMountPath(side)
		mount(fs.getName(path),"/"..path)
	end
end

while reboot do
	reboot = false
	terminate = false

	local bios = nil
	local cerr = nil
	if fs.exists(biosPath) then
		bios, cerr = loadstring(fs.open(biosPath,"r").readAll())
	else
		error("Bios not found!")
	end

	if not bios then
		error("BIOS failed to compile: "..cerr)
	end

	local co = coroutine.create(sandboxFunction(bios))

	local status = nil
	local err = nil
	status, err = coroutine.resume(co)
	while not terminate and coroutine.status(co) ~= "dead" do
		status, err = coroutine.resume(co,coroutine.yield(value))
	end

	if not status then
		print("BIOS crash: "..err)
	end
end
