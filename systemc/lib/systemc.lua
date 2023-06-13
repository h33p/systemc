local _version = 6
local start_service_delay = 0.1

rootPath = "/systemc"

libDir = fs.combine(rootPath, "/lib")
binDir = fs.combine(rootPath, "/bin")
etcDir = fs.combine(rootPath, "/etc")
unitDir = fs.combine(etcDir, "/systemc/system")

local deadThreads = {}
local threads = {}

local _curthread = nil

services = {}
targets = {}
loaded = false

process = { uid = 0, pid = 1, parent = 0, exec = "" }
local _process = { uid = 0, pid = 1, parent = 0, exec = "" }

local lastid = 1

local function copyTable(t)
   local aux = textutils.serialize(t)
   local t2 = textutils.unserialize(aux)
   return t2
end

function getProcessSecure ()
	return copyTable(_process)
end

function getGid(num)
	return 1
end

function get_processes ()
	pr = {}
	for k, v in pairs(threads) do
		pr[v.pid] = v
	end
	return pr
end


local _pcall = pcall

local _load = load

--function load(x, mode, t, env)
--	return _load(x, mode, t, env)
--end
--_G.load = load

local _run = os.run

function os.run( _tEnv, _sPath, ... )
	local _uid = _process.uid
	local _exec = _process.exec
	if fs.isExecuteable ~= nil and not fs.isExecuteable(_sPath) then
		print(_sPath..": Access Denied")
		return false
	end
	if fs.getPerms ~= nil and fs.getPerms(_sPath).psuid then
		threads[_curthread].uid = fs.getPerms(_sPath).owner
		process.uid = threads[_curthread].uid
		_process.uid = threads[_curthread].uid
	end
	_process.exec = _sPath
	process.exec = _sPath
	threads[_curthread].exec = _sPath
	--print (process.uid.." "..process.exec)
	local ret = _run(_tEnv, _sPath, ...)
	threads[_curthread].uid = _uid
	process.uid = _uid
	_process.uid = _uid
	_process.exec = _exec
	process.exec = _exec
	threads[_curthread].exec = _exec
	return ret
end

local function tobool( val )
	if val == nil or val == false or val == 0 or val == "0" or val == "false" then return false end
	return true
end

local function get_virtual_term ()

	local vTerm = {}
	local output = {}
	vTerm.clear = function () end
	local color = colors.white
	local bcolor = colors.black
	local tx = 0
	local ty = 0
	vTerm.write = function (text) table.insert(output, text) end
	vTerm.blit = function (text, a, b) table.insert(output, text) end
	vTerm.getCursorPos = function () return tx, ty end
	vTerm.setCursorPos = function (ntx, nty) tx = ntx ty = nty end
	vTerm.setCursorBlink = function (a) end
	vTerm.isColor = function () return true end
	vTerm.isColour = vTerm.isColor
	vTerm.getSize = function () return 51, 19 end	
	vTerm.getTextColor = function () return color end
	vTerm.getTextColour = vTerm.getTextColor
	vTerm.setTextColor = function (c) color = c end
	vTerm.setTextColour = vTerm.setTextColor
	vTerm.getBackgroundColor = function () return bcolor end
	vTerm.getBackgroundColour = vTerm.getBackgroundColor
	vTerm.setBackgroundColor = function (c) bcolor = c end
	vTerm.setBackgroundColour = vTerm.setBackgroundColor

	return output, vTerm
end

local function get_unit_info (path)

	local description = ""
	local documentation = {}
	local after = {}
	local requires = {}
	local wants = {}
	local conflicts = {}


	local h = fs.open(path, "r")
	
	local cont = true
	local read = false

	while cont do
		local text = h.readLine()
		if text == nil then
			cont = false
		elseif string.sub(text, 1, 1) == "[" then
			if text == "[Unit]" then
				read = true
			else
				read = false
			end
		elseif read then
			local arg, a = text:match("([^=]+)=([^=]+)")
			if arg == "Type" then
				type = a
			elseif arg == "Description" then
				description = a
			elseif arg == "Documentation" then
				for word in a:gmatch("%S+") do table.insert(documentation, word) end	
			elseif arg == "Requires" then
				for word in a:gmatch("%S+") do table.insert(requires, word) end	
			elseif arg == "Wants" then
				for word in a:gmatch("%S+") do table.insert(wants, word) end	
			elseif arg == "Conflicts" then
				for word in a:gmatch("%S+") do table.insert(conflicts, word) end	
			end
		end
	end

	h.close()
	return description, documentation, after, requires, wants, conflicts
end

local function get_install_info (path)

	local requiredby = {}
	local wantedby = {}
	local also = {}


	local h = fs.open(path, "r")
	
	local cont = true
	local read = false

	while cont do
		local text = h.readLine()
		if text == nil then
			cont = false
		elseif string.sub(text, 1, 1) == "[" then
			if text == "[Install]" then
				read = true
			else
				read = false
			end
		elseif read then
			local arg, a = text:match("([^=]+)=([^=]+)")
			if arg == "RequiredBy" then
				for word in a:gmatch("%w+") do table.insert(requiredby, word) end	
			elseif arg == "WantedBy" then
				for word in a:gmatch("%w+") do table.insert(wantedby, word) end	
			elseif arg == "Also" then
				for word in a:gmatch("%w+") do table.insert(also, word) end	
			end
		end
	end

	h.close()
	return requiredby, wantedby, also
end
	
local function get_service_info (path)

	local stype = "simple"
	local execstart = ""
	local execstop = ""
	local execreload = ""
	local restart = false
	local remainafterexit = false

	local h = fs.open(path, "r")
	
	local cont = true
	local read = false

	while cont do
		local text = h.readLine()
		if text == nil then
			cont = false
		elseif string.sub(text, 1, 1) == "[" then
			if text == "[Service]" then
				read = true
			else
				read = false
			end
		elseif read then
			local arg, a = text:match("([^=]+)=([^=]+)")
			if arg == "Type" then
				stype = a
			elseif arg == "ExecStart" then
				execstart = a
			elseif arg == "ExecStop" then
				execstop = a
			elseif arg == "ExecReload" then
				execreload = a
			elseif arg == "Restart" then
				restart = tobool(a)
			elseif arg == "RemainAfterExit" then
				remainafterexit = tobool(a)
			end
		end
	end

	h.close()
	return stype, execstart, execstop, execreload, restart, remainafterexit
end

function load_targets()
	
	local h = fs.open(fs.combine(fs.combine(etcDir, "systemc"), "targets.conf"), "r")
	
	local i = 0
	while h ~= nil do
		local text = h.readLine()
		if text == nil then
			break
		end
		local a, b = text:match("([^=]+)=([^=]+)")
		targets[a] = {}
		for p in string.gmatch(b, '([^,]+)') do
			targets[a][p] = true
		end
		i = i + 1
	end

	table.sort(targets)

	if h ~= nil then
		h.close()
	end
	
end

function run_target (target)
		
	local stext = term.getTextColor()

	local normC = colors.white
	local okC = colors.lightGray
	local badC = colors.gray

	if term.isColor() then
		okC = colors.green
		badC = colors.red
	end

	if targets[target] == nil then
		term.setTextColor(normC)
		write("[ ")
		term.setTextColor(badC)
		write(" FAILED ")
		term.setTextColor(normC)
		print(" ] Target", target, "was not found!")
		sleep ()
		return
	end
	
	for k, v in pairs(targets[target]) do
		
		term.setTextColor(normC)
		write("[ ")
		term.setTextColor(okC)
		write(" OK ")
		term.setTextColor(normC)
		print(" ] Reached Target", k)
		sleep(start_service_delay)
		if fs.isDir(fs.combine(unitDir, k)) then
			local units = fs.list(fs.combine(unitDir, k))

			for p, o in pairs(units) do
				local i, u = o:match("([^.]+).([^.]+)")
				sleep()
				if services[i].status:match("inactive") == "inactive" then
					local ok, status = start_unit(i)
					services[i].enabled = "enabled"
					if not ok then
						term.setTextColor(normC)
						write("[ ")
						term.setTextColor(badC)
						write(" FAILED ")
						term.setTextColor(normC)
						print(" ] Failed to start", i, "Reason:", status)
					else
						term.setTextColor(normC)
						write("[ ")
						term.setTextColor(okC)
						write(" OK ")
						term.setTextColor(normC)
						print(" ] Started", i)
					end
				end
				sleep(start_service_delay)
			end
		end

	end
end

function reload_daemon (loud)
	for k, w in pairs(fs.list(unitDir)) do
		if not fs.isDir(fs.combine(unitDir, w)) then
			local name, utype = w:match("([^.]+).([^.]+)")

			if utype == "service" and services[name] == nil then
				services[name] = {}
			end
		end
	end
	for k, v in pairs(services) do
		services[k]["requiredby"] = {}
		services[k]["wantedby"] = {}
		services[k]["also"] = {}
		services[k]["after"] = {}
		services[k]["requires"] = {}
		services[k]["wants"] = {}
		services[k]["conflicts"] = {}
		if services[k]["enabled"] == nil then
			services[k]["enabled"] = "disabled"
		end
	end
	for k, w in pairs(fs.list(unitDir)) do
		if not fs.isDir(fs.combine(unitDir, w)) then
			local name, utype = w:match("([^.]+).([^.]+)")

			if utype == "service" then
				local stype, execstart, execstop, execreload, restart, remainafterexit = get_service_info (fs.combine(unitDir, w))
				local requiredby, wantedby, also = get_install_info (fs.combine(unitDir, w)) 
				local description, documentation, after, requires, wants, conflicts = get_unit_info (fs.combine(unitDir, w))
				if services[name] == nil then
					services[name] = {}
				end
				services[name]["stype"] = stype
				services[name]["execstart"] = execstart
				services[name]["execstop"] = execstop
				services[name]["execreload"] = execreload
				services[name]["restart"] = restart
				services[name]["remainafterexit"] = remainafterexit

				for k,t in pairs(requiredby) do
						services[name]["requiredby"][t] = true
						if services[t] == nil and loud then print(name.." Required By: Unit "..t.." not found!")
						else services[t]["requires"][name] = true end
				end
				for k,t in pairs(wantedby) do
						services[name]["wantedby"][t] = true
						if services[t] == nil and loud then print(name.." Wanted By: Unit "..t.." not found!")
						else services[t]["wants"][name] = true end
				end
				for k,t in pairs(requires) do
						services[name]["requires"][t] = true
						if services[t] == nil and loud then print(name.." Requires: Unit "..t.." not found!")
						else services[t]["requiredby"][name] = true end
				end
				for k,t in pairs(wants) do
						services[name]["wants"][t] = true
						if services[t] ~= nil then
							services[t]["wantedby"][name] = true
						else

							local c, d = t:match("([^.]+).([^.]+)")
							if loud and (t:match(".") ~= "." or (d == "target" and targets[c] == nil) or (d == "service" and services[c] == nil)) then
								print(name.." Wants: Unit "..t.." not found!")
							end
						end
				end
				services[name]["also"] = also
				services[name]["description"] = description
				services[name]["after"] = after
				services[name]["conflicts"] = conflicts
				if services[name]["status"] == nil then
					services[name]["status"] = "inactive (dead)"
				end
			end
		end
	end
end

function disable_unit(name)

	if fs.exists(fs.combine(unitDir, name)) then
		local name2, utype = name:match("([^.]+).([^.]+)")
		
		if utype == "service" then
			services[name2].enabled = "disabled"
			for k, v in pairs(fs.find(unitDir.."/*/"..name)) do
				print("Removed link",v)
				fs.delete(v)
			end
		end	
	elseif fs.exists(fs.combine(unitDir, name..".service")) then
		disable_unit(name..".service")
	end

end

function enable_unit(name)

	if fs.exists(fs.combine(unitDir, name)) then
		local name2, utype = name:match("([^.]+).([^.]+)")
		
		if utype == "service" then
			for k, v in pairs(services[name2].wants) do
				local name3, wtype = k:match("([^.]+).([^.]+)")
				if wtype == "target" then
					if not fs.exists(fs.combine(unitDir, k)) then
						fs.makeDir(fs.combine(unitDir, k))
					end

					if fs.isDir(fs.combine(unitDir, k)) then
						fs.makeDir(fs.combine(fs.combine(unitDir, k), name))
						services[name2].enabled = "enabled"
						print("Added link to target", k)
					end
				end
			end
		end	
	elseif fs.exists(fs.combine(unitDir, name..".service")) then
		enable_unit(name..".service")
	end
end

local function starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

local _fterm = {}

local function _start_unit(name, foreground)
	if fs.exists(fs.combine(unitDir, name)) then
		local name2, utype = name:match("([^.]+).([^.]+)")

		local a = services[name2].execstart:gmatch("%S+")
		local name3 = a()
		local args = {}
		if starts(name3, "/") == false then name3 = fs.combine(rootPath, name3) end
		for w in a do table.insert(args, w) end
		if utype == "service" and services[name2].thread == nil then
			local tTerm = {}
			services[name2].output, tTerm = get_virtual_term ()
			local ok = false
			if foreground then
				ok, services[name2].thread = coroutine.start(function () os.run( {term = _fterm}, name3, unpack(args)) end)
			else
				ok, services[name2].thread = coroutine.start(function () os.run( {uid = 0, term = tTerm, print = tTerm.write}, name3, unpack(args)) end)
			end
			if not ok then
				services[name2].status = "inactive (failed)"
				return false, "unspecified"
			else
				services[name2].pid = lastid
				services[name2].status = "active (running)"
				return true
			end
		else
			return false, name.." already running!"
		end
	elseif fs.exists(fs.combine(unitDir, name..".service")) and services[name].thread == nil then
		return _start_unit(name..".service", foreground)
	else
		return false, name..".service already running!"
	end

	return false, "unhandled"
end

function start_unit(name)
	return _start_unit(name, false)
end

function stop_unit(name)
	if fs.exists(fs.combine(unitDir, name)) then
		local name2, utype = name:match("([^.]+).([^.]+)")
		if utype == "service" and services[name2].thread ~= nil then
			services[name2].status = "inactive (stopped)"
			services[name2].thread = nil
		else
			error (name.." not running!")
		end
	elseif fs.exists(fs.combine(unitDir, name..".service")) and services[name].thread ~= nil then
		stop_unit(name..".service")
	else
		error (name..".service not running!")
	end
end

function _kill(thread, sig)
	if threads[thread] == nil then
		return
	end
	if threads[thread].events == nil then
		threads[thread].events = {}
	end
	local event = ""
	local queueChildren = false
	if sig == 1 then --SIGHUP
		queueChildren = true
		event = "SIGHUP"
	elseif sig == 2 then --SIGINT
		event = "SIGINT"
	elseif sig == 9 then --SIGKILL
		queueChildren = true
		event = "SIGKILL"
	elseif sig == 15 then --SIGTERM
		event = "terminate"
	elseif sig == 17 then --SIGCHLD
		event = "SIGCHLD"
	end
	
	if queueChildren and threads[thread].children ~= nil then
		for k, v in threads[thread].children do
			_kill(k, sig)
		end
	end

	table.insert(threads[thread].events, event)
	if event == "SIGKILL" then
		threads[thread] = nil
		deadThreads[thread] = true
	end

	return true
end

function kill(pid, sig)
	for k, v in pairs(threads) do
		if v.pid == pid and threads[k].uid == _process.uid then
			return _kill(k, sig)
		end
	end
	return false, "Operation not permitted"
end

local _status = coroutine.status
function coroutine.status (cor)
	if deadThreads[cor] ~= nil then
		return "dead"
	else
		return _status(cor)
	end
end
_G.coroutine.status = coroutine.status

local _create = coroutine.create
function coroutine.create (func, ...)
	lastid = lastid + 1
	local thread = _create(func, ...)
	threads[thread] = {}
	threads[thread].pid = lastid
	threads[thread].uid = _process.uid
	threads[thread].parent = _process.pid
	threads[thread].exec = "unknown"
	return thread
end
_G.coroutine.create = coroutine.create

local _resume = coroutine.resume
function coroutine.resume (cor, ...)

	if coroutine.status(cor) == "dead" then
		return false, "cannot resume dead coroutine"
	end

	if threads[cor] == nil then
		if _curthread == nil then
			_curthread = cor
		end
		return _resume(cor, ...)
	elseif threads[cor].pid == -1 then
		return 0, false
	end

	if threads[_curthread] ~= nil and threads[_curthread].pid ~= threads[cor].parent and threads[cor].parent > 1 then
	--	error(-1)
	end

	local pr = process
	local _pr = _process
	local _ot = _curthread

	process = {}
	_process = {}

	process.pid = threads[cor].pid
	_process.pid = process.pid
	process.uid = threads[cor].uid
	_process.uid = process.uid
	process.parent = threads[cor].parent
	_process.parent = process.parent
	process.exec = threads[cor].exec
	_process.exec = process.exec
	_curthread = cor

	if threads[cor].events ~= nil then
		for k, v in pairs(threads[cor].events) do
			--print(v)
			os.queueEvent(v)
		end
	end
	threads[cor].events = {}

	local ret = {_resume(cor, ...)}
	--for k, v in pairs(ret) do
	--	print (tostring(k))
	--	print (tostring(v))
	--end
	
	process = pr
	_process = _pr
	_curthread = _ot
	return unpack(ret)

end
_G.coroutine.resume = coroutine.resume

function coroutine.start(func, ...)
  if type(func) ~= "function" then return false end
  local cr = coroutine.create(func)
	return true, cr
end

local function getty()
	local stext = term.getTextColor()

	local normC = colors.white
	local okC = colors.lightGray
	local badC = colors.gray

	if term.isColor() then
		okC = colors.green
		badC = colors.red
	end

	for k, v in pairs(services) do
		if starts(k, "getty") then
			--[[term.setTextColor(normC)
			write("[ ")
			term.setTextColor(okC)
			write(" OK ")]]
			term.setTextColor(normC)
			print("Running", k)
			_start_unit(k, true)
		end
	end
end

function version ()
	return _version
end

function setuid (newuid)
	print(threads[_curthread].uid.." "..newuid)
	if tonumber(newuid) == nil then error ("Number Expected") end
	newuid = tonumber(newuid)
	if threads[_curthread] ~= nil and threads[_curthread].uid == 0 then
		process.uid = newuid
		_process.uid = newuid
		threads[_curthread].uid = newuid
	else
		error("Access Denied")
	end

end

local ofs = fs

local function loadLibs ()
	files = ofs.list(libDir)
	for k, v in pairs(files) do
		if not ofs.isDir (ofs.combine(libDir, v)) and string.sub(v, 1,1) ~= "." and v ~= "systemc" then
			os.loadAPI(ofs.combine(libDir, v))
		end
	end
end

function run(root, target)

	_G.systemc = _ENV
	--for k, v in pairs(_G.systemc) do
	--	_G.systemc[k] = _ENV[k]
	--end
	
	_fterm = term

	rootPath = tostring(root)
	
	libDir = fs.combine(rootPath, "/lib")
	binDir = fs.combine(rootPath, "/bin")
	etcDir = fs.combine(rootPath, "/etc")
	unitDir = fs.combine(etcDir, "/systemc/system")

	loadLibs()
	term.setCursorBlink(true)
	load_targets ()
	reload_daemon (false)
	run_target (target)

	getty()

	loaded = true

	while loaded do
		local eventData = {coroutine.yield()}
		local loaded2 = false
		for key, val in pairs(services) do
			if val.thread ~= nil then
				loaded2 = true
				coroutine.resume(val.thread, unpack(eventData))
				if val.thread == nil or coroutine.status(val.thread) == "dead" then
					val.status = "inactive (finished)"
					val.thread = nil
				end
			elseif val.thread == nil and val.status:match("inactive") ~= "active" then
				val.status = "inactive (killed)"
			end
		end
		loaded = loaded2
		--[[for k, v in pairs(threads) do
			if coroutine.status(k) == "dead" then
				threads[k] = nil
			end
		end]]
	end

end

