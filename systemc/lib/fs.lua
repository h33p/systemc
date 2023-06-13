local __fs = fs

local defaultInfo = function () return {owner = 0, group = 0, psuid = false, powner = 6, pgroup = 6, pothers = 4} end
local defaultInfoExec = function () return {owner = 0, group = 0, psuid = false, powner = 7, pgroup = 7, pothers = 5} end
local hiddenInfo = function () return {owner = 0, group = 0, psuid = false, powner = 0, pgroup = 0, pothers = 0} end

local function copyPerms(perms)
	return { owner = tonumber(perms.owner), group = tonumber(perms.group), psuid = perms.psuid, powner = tonumber(perms.powner), pgroup = tonumber(perms.pgroup), pothers = tonumber(perms.pothers) }
end

local getGid = systemc.getGid

local fsTable = {}

local curProcess = systemc.getProcessSecure

local tabPath = __fs.combine (systemc.etcDir, "fstable")

function canExec(num)
	return num == 1 or num == 3 or num == 5 or num == 7
end

function canWrite(num)
	return num == 2 or num == 3 or num == 6 or num == 7
end

function canRead(num)
	return num == 4 or num == 5 or num == 6 or num == 7
end

local queueSave = false

local function save()
	local file = __fs.open(tabPath, 'w')
	file.write(textutils.serialize(fsTable))
	file.close()
	if not __fs.exists(tabPath) then
		setPerms(tabPath, { pgroup = 0, pothers = 0 })
	end
	queueSave = false
end

function getPerms(path)
	if __fs.combine(path, "") == tabPath then
		error("Access Denied")
	end
	if __fs.getPerms ~= nil then
		return __fs.getPerms(path)
	end
	path = __fs.combine(path, "")
	if __fs.exists(path) and path ~= "" then
		if fsTable[__fs.getDir(path)] == nil then
			fsTable[__fs.getDir(path)] = {}
			if string.sub(__fs.getDir(path), 1, 4) == "rom/" or __fs.getDir(path) == systemc.binDir then
				fsTable[__fs.getDir(path)][__fs.getName(path)] = defaultInfoExec()
			elseif path == tabPath then
				fsTable[__fs.getDir(path)][__fs.getName(path)] = hiddenInfo()
			else
				fsTable[__fs.getDir(path)][__fs.getName(path)] = defaultInfo()
			end
			queueSave = true
		elseif fsTable[__fs.getDir(path)][__fs.getName(path)] == nil then
			if string.sub(__fs.getDir(path), 1, 4) == "rom/" or __fs.getDir(path) == systemc.binDir then
				fsTable[__fs.getDir(path)][__fs.getName(path)] = defaultInfoExec()
			elseif path == tabPath then
				fsTable[__fs.getDir(path)][__fs.getName(path)] = hiddenInfo()
			else
				fsTable[__fs.getDir(path)][__fs.getName(path)] = defaultInfo()
			end
			queueSave = true
		end
		return fsTable[__fs.getDir(path)][__fs.getName(path)]
	elseif not __fs.exists(path) then
		if fsTable[__fs.getDir(path)] == nil then
			fsTable[__fs.getDir(path)] = {}
		end
		if fsTable[__fs.getDir(path)][__fs.getName(path)] ~= nil then
			fsTable[__fs.getDir(path)][__fs.getName(path)] = nil
			queueSave = true
		end
		return {owner = 0, group = 0, psuid = false, powner = 0, pgroup = 0, pothers = 0}
	else
		if fsTable[""] == nil then fsTable[""] = {} end
		if fsTable[""]["/"] == nil then
			fsTable[""]["/"] = defaultInfo()
			fsTable[""]["/"].pothers = 6
			queueSave = true
		end
		return fsTable[""]["/"]
	end
end

function setPerms(path, perms)
	if __fs.combine(path, "") == tabPath then
		error("Access Denied")
	end
	if __fs.setPerms ~= nil then
		return __fs.setPerms(path, perms)
	end
	if curProcess().uid ~= 0 and getPerms(path).owner ~= curProcess().uid then
		error("Access Denied")
	else
		local dir = __fs.getDir(path)
		local name = __fs.getName(path)
		for k, v in pairs(perms) do
			if fsTable[dir][name][k] ~= nil then
				fsTable[dir][name][k] = v
				queueSave = true
			end
		end
	end
	if queueSave then save() end
end

function isExecuteable (path)
	if __fs.isExecuteable ~= nil then
		return __fs.isExecuteable(path)
	end
	if getPerms(path).owner == curProcess().uid and canExec(getPerms(path).powner) then
		return true
	elseif getPerms(path).group == curProcess().gid and canExec(getPerms(path).pgroup) then
		return true
	elseif canExec(getPerms(path).pothers) then
		return true
	else
		return false
	end
end

function isWriteable (path)
	if __fs.isWriteable ~= nil then
		return __fs.isWriteable(path)
	end
	if getPerms(path).owner == curProcess().uid and canWrite(getPerms(path).powner) then
		return true
	elseif getPerms(path).group == curProcess().gid and canWrite(getPerms(path).pgroup) then
		return true
	elseif canWrite(getPerms(path).pothers) then
		return true
	else
		return false
	end
end

function list (path)
	path = __fs.combine("", path)
	local returnTable = __fs.list(path)
	if returnTable then
		local ret = {}
		for k, v in pairs(returnTable) do
			fullPath = fs.combine(path, v)
			if fullPath ~= tabPath then
				local perms = getPerms(fullPath)
				if curProcess().uid == 0 or perms.owner == curProcess().uid or getGid(curProcess().uid) == perms.owner or canRead(perms.pothers) then
					ret[k] = v
				end
			end
		end
		if queueSave then save() end
		return ret
	else
		return {}
	end
end

function exists (path)
	if __fs.combine(path, "") == tabPath then
		return false
	end
	if __fs.getPerms ~= nil then
		return __fs.exists(path)
	end
	path = __fs.combine ("", path)
	local exists = __fs.exists(path)
	if not exists then
		return false
	else
		local perms = getPerms(path)
		if curProcess().uid == 0 or perms.owner == curProcess().uid or getGid(curProcess().uid) == perms.owner or perms.pothers ~= 0 then
			return true
		else
			return false
		end
	end
end

function isDir (path)
	return exists (path) and __fs.isDir(path)
end

function isReadOnly (path)
	if __fs.combine(path, "") == tabPath then
		return false
	end
	if __fs.getPerms ~= nil then
		return __fs.isReadOnly(path)
	end
	local read = __fs.isReadOnly (path)
	if not read then
		read = true
		local perms = getPerms(path)
		if curProcess().uid == 0 then
			read = false
		elseif perms.owner == curProcess().uid then
			read = not canWrite(perms.powner)
		elseif getGid(curProcess().uid) == perms.owner then
			read = not canWrite(perms.pgroup)
		else
			read = not canWrite(perms.pothers)
		end
	end
	if queueSave then save() end
	return read
end

getName = __fs.getName

function getDrive (path)
	if exists(path) then
		return __fs.getDrive(path)
	else
		return nil
	end
end

function getSize (path)
	if __fs.getPerms ~= nil then
		return __fs.getSize(path)
	end
	if exists(path) then
		return __fs.getSize (path)
	elseif not __fs.exists(path) then
		return __fs.getSize(path)
	elseif string.sub(__fs.combine(path), 1, 2) ~= ".." then
		error("No such file")
	else
		error("Invalid Path")
	end
end

getFreeSpace = __fs.getFreeSpace

function makeDir (path)
	if __fs.getPerms ~= nil then
		return __fs.makeDir(path)
	end
	if string.sub(__fs.combine(path, ""), 1, 2) == ".." then
		error("Invalid Path")
	elseif isReadOnly(__fs.getDir(path)) then
		error("Access Denied")
	else
		__fs.makeDir(path)
		getPerms(path)
		if queueSave then save() end
	end
end

function move (p1, p2)
	if __fs.combine(p1, "") == tabPath or __fs.combine(p2, "") == tabPath then
		return false
	end
	if __fs.getPerms ~= nil then
		return __fs.move(p1, p2)
	end
	if isReadOnly(p1) or isReadOnly(p2) then
		error("Access Denied")
	end
	getPerms(p1)
	d1 = __fs.getDir(p1)
	d2 = __fs.getDir(p2)
	--if d1 == "" then d1 = "" end
	--if d2 == "" then d2 = "" end
	__fs.move(p1, p2)
	p1 = __fs.getName(p1)
	p2 = __fs.getName(p2)
	fsTable[d2][p2] = fsTable[d1][p1]
	fsTable[d1][p1] = nil
	if queueSave then save() end
end

local function recursPermsCopy (p1, p2)
	p1 = __fs.combine("", p1)
	p2 = __fs.combine("", p2)
	local l1 = list(p1)
	local l2 = list(p2)
	getPerms(p1)
	if fsTable[p1] ~= nil then
		for k, v in pairs(fsTable[p1]) do
			if __fs.isDir(__fs.combine(p1, k)) and __fs.isDir(__fs.combine(p2, k)) then
				recursPermsCopy(__fs.combine(p1, k), __fs.combine(p2, k))
			end
			fullPathP1 = __fs.combine(p1, k)
			fullPathP2 = __fs.combine(p2, k)
			if __fs.exists(fullPathP2) and fullPathP1 ~= tabPath then
				getPerms(fullPathP1)
				fsTable[p2][k] = copyPerms(fsTable[p1][k])
				fsTable[p2][k].owner = curProcess().uid
				fsTable[p2][k].group = curProcess().gid
			end
		end
	end
end

function copy (p1, p2)
	if __fs.getPerms ~= nil then
		return __fs.copy(p1, p2)
	end
	if not exists(p1) then
		error("No such file")
	elseif __fs.exists(p2) then
		error("File exists")
	end
	local perms = getPerms(p1)
	if isReadOnly(__fs.getDir(p2)) then
		error("Access Denied")
	end
	local read = false
	if curProcess().uid == 0 then
		read = true
	elseif perms.owner == curProcess().uid then
		read = canRead(perms.powner)
	elseif getGid(curProcess().uid) == perms.owner then
		read = canRead(perms.pgroup)
	else
		read = canRead(perms.pothers)
	end
	if not read then error("Access Denied") end
	
	d1 = __fs.getDir(p1)
	d2 = __fs.getDir(p2)
	--if d1 == "/" then d1 = "" end
	--if d2 == "/" then d2 = "" end
	__fs.copy(p1, p2)
	local n1 = __fs.getName(p1)
	local n2 = __fs.getName(p2)
	fs.getPerms(p2)
	fsTable[d2][n2] = copyPerms(fsTable[d1][n1])
	fsTable[d2][n2].owner = curProcess().uid
	fsTable[d2][n2].group = curProcess().uid
	if fs.isDir(p1) then
		recursPermsCopy(p1, p2)
	end
	if queueSave then save() end
end

function delete(path)
	if __fs.getPerms ~= nil then
		return __fs.delete(path)
	end
	if isReadOnly(path) then
		error ("Access Deniad")
	end
	__fs.delete(path)
	if queueSave then save() end
end

combine = __fs.combine

function open (path, mode)
	if __fs.getPerms ~= nil then
		return __fs.open(path, mode)
	end
	if isReadOnly(path) then
		if mode == "w" or mode == "a" or mode == "bw" or mode == "wb" then
			return nil
		end
	end
	return __fs.open(path, mode)
end

function find(inp)
	if __fs.getPerms ~= nil then
		return __fs.find(inp)
	end
	local res = __fs.find(inp)
	local ret = {}
	for k, v in pairs(res) do
		if exists(v) then
			ret[k] = v
		end
	end
	if queueSave then save() end
	return ret
end

getDir = __fs.getDir

complete = __fs.complete

if __fs.getPerms == nil and __fs.exists(tabPath) then
	local file = __fs.open(tabPath, 'r')
	fsTable = textutils.unserialize(file.readAll())
	file.close()
end

if fsTable == nil then
	fsTable = {}
end

